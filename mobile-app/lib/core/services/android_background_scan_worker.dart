/// F161 (Sprint 61): the Android WorkManager background-scan worker -- the
/// Android counterpart of `BackgroundScanWindowsWorker`, mirroring the
/// per-account architecture of ADR-0039 via the shared `BackgroundScanCore`.
///
/// Division of labor (ADR-0042):
///   - SHARED: settings resolution, the scan pipeline, and persistence all live
///     in `BackgroundScanCore.scanAccount` -- the identical code the Windows
///     worker runs, so both platforms persist scan_results / email_actions /
///     unmatched_emails the same way (the Sprint 60 accounts-FK lesson).
///   - ANDROID-ONLY (declared exceptions): the WorkManager entry point (a
///     background isolate needs its own binding + plugin initialization), and
///     the completion notification via Android notification channels. These are
///     this file; the Windows equivalents (Task Scheduler CLI entry, per-account
///     file log, Excel export) stay in the Windows worker.
library;

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';

import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../providers/rule_set_provider.dart';
import '../storage/database_helper.dart';
import '../storage/settings_store.dart';
import 'background_scan_core.dart';

/// Prefix for the per-account WorkManager task name, mirroring the Windows
/// `SpamFilterBackgroundScan_<sanitizedAccountId><envSuffix>` convention so
/// the two platforms' scheduled entries are recognizably the same thing.
const String kAndroidScanTaskName = 'spamfilter_background_scan';

/// One-off variant used by the Settings "Test" button (parity with the Windows
/// test path, which runs the worker once immediately).
const String kAndroidScanTestTaskName = 'spamfilter_background_scan_test';

/// The WorkManager entry point. Registered once at app startup
/// (`Workmanager().initialize(androidBackgroundScanDispatcher)` in main.dart,
/// Android only) and invoked by the OS when a scheduled task fires.
///
/// Runs in a BACKGROUND ISOLATE: it must set up its own binding and plugin
/// registrations before any plugin-backed service (path_provider, sqflite,
/// secure storage, notifications) is touched. This is an Android-platform
/// requirement, not an architectural fork -- the Windows equivalent is the
/// `--background-scan` CLI entry in main.dart, which gets a full engine for
/// free.
@pragma('vm:entry-point')
void androidBackgroundScanDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final accountId = inputData?['accountId'] as String?;
    final isTest = taskName == kAndroidScanTestTaskName;
    return AndroidBackgroundScanWorker.executeScan(
      accountId: accountId,
      isTest: isTest,
    );
  });
}

class AndroidBackgroundScanWorker {
  AndroidBackgroundScanWorker._();

  static final Logger _logger = Logger();

  /// Execute a background scan for [accountId] (or, defensively, all enabled
  /// accounts when null -- a scheduled task always carries its account in
  /// inputData, so null means something unexpected happened; scanning enabled
  /// accounts beats silently doing nothing).
  ///
  /// Returns true when every attempted account scan succeeded -- WorkManager
  /// uses the return value to decide whether to retry per the task's backoff
  /// policy.
  static Future<bool> executeScan({
    String? accountId,
    bool isTest = false,
  }) async {
    _logger.i('Android background scan started'
        '${accountId != null ? ' for ${Redact.accountId(accountId)}' : ' (all accounts)'}'
        '${isTest ? ' [TEST]' : ''}');

    try {
      // Environment setup mirrors the Windows worker's executeBackgroundScan
      // preamble: paths, database, stores, rules.
      final appPaths = AppPaths();
      await appPaths.initialize();

      final dbHelper = DatabaseHelper();
      dbHelper.setAppPaths(appPaths);

      final credStore = SecureCredentialsStore();
      final settingsStore = SettingsStore(dbHelper);

      final ruleSetProvider = RuleSetProvider();
      await ruleSetProvider.initialize();

      var accountIds = await credStore.getSavedAccounts();
      if (accountId != null) {
        accountIds = accountIds.where((id) => id == accountId).toList();
        if (accountIds.isEmpty) {
          _logger.w('Account ${Redact.accountId(accountId)} not found among '
              'saved accounts; nothing to scan (orphaned schedule -- the next '
              'foreground startup cleans these up)');
          // Not a retryable failure: retrying cannot make the account exist.
          return true;
        }
      }

      var allSucceeded = true;
      for (final id in accountIds) {
        // Skip disabled accounts unless this is a test run (same rule as the
        // Windows worker).
        if (!isTest) {
          final enabled = await settingsStore.getEffectiveBackgroundEnabled(id);
          if (!enabled) continue;
        }

        final platformId =
            await BackgroundScanCore.resolvePlatformId(credStore, id);
        if (platformId == null) {
          _logger.w('Cannot determine platform for ${Redact.accountId(id)}, '
              'skipping');
          allSucceeded = false;
          continue;
        }

        try {
          final outcome = await BackgroundScanCore.scanAccount(
            accountId: id,
            platformId: platformId,
            ruleSetProvider: ruleSetProvider,
            settingsStore: settingsStore,
          );
          await _notifyScanComplete(accountId: id, outcome: outcome);
        } catch (e) {
          _logger.e('Background scan failed for ${Redact.accountId(id)}',
              error: e);
          allSucceeded = false;
        }
      }
      return allSucceeded;
    } catch (e) {
      _logger.e('Android background scan worker failed', error: e);
      return false;
    }
  }

  /// Completion notification -- the POST_NOTIFICATIONS call site (F161 R-2:
  /// the runtime permission request in Settings is gated on THIS existing,
  /// not added speculatively). Mirrors the summary content of the Windows
  /// worker's per-account result line.
  ///
  /// Best-effort by design: a notification failure (permission denied, channel
  /// unavailable) must never fail the scan itself -- the scan's persistence is
  /// the record; the notification is a courtesy.
  static Future<void> _notifyScanComplete({
    required String accountId,
    required AccountScanOutcome outcome,
  }) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await plugin.initialize(initSettings);

      const androidDetails = AndroidNotificationDetails(
        'background_scan_channel',
        'Background Scans',
        channelDescription: 'Results of scheduled background email scans',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: true,
      );

      // The user's OWN address is masked per the ADR-0030 redaction rule; the
      // counts are the useful signal.
      await plugin.show(
        accountId.hashCode,
        'Background scan complete',
        'Processed ${outcome.emailsProcessed}: '
            '${outcome.deletedCount} deleted, ${outcome.safeCount} safe, '
            '${outcome.unmatchedCount} no rule'
            '${outcome.errorCount > 0 ? ', ${outcome.errorCount} errors' : ''}',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _logger.w('Completion notification failed (scan itself succeeded): $e');
    }
  }
}
