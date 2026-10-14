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

import 'dart:async' show unawaited;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';

import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../providers/rule_set_provider.dart';
import '../storage/database_helper.dart';
import '../storage/scan_result_store.dart';
import '../storage/settings_store.dart';
import 'background_mode_service.dart';
import 'background_scan_core.dart';
import 'background_scan_trigger.dart';
import 'diagnostic_logger.dart';
import 'f264_upgrade_migration.dart';
import 'notification_account_filter.dart';
import 'scan_complete_notifier.dart';
import 'scan_sheet_export.dart';

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
    // F239 (Sprint 75): this isolate is a background worker -- no interactive
    // sign-in may start from it (BackgroundModeService.isBackgroundMode).
    BackgroundModeService.markBackgroundIsolate();

    final accountId = inputData?['accountId'] as String?;
    final isTest = taskName == kAndroidScanTestTaskName;
    // F252: computed HERE, at entry, so the delay measures how long Android
    // held the work back -- not the worker's own setup time.
    final trigger = describeBackgroundTrigger(
      isTest: isTest,
      inputData: inputData,
      now: DateTime.now(),
    );
    _runningWork =
        '${accountId != null ? Redact.accountId(accountId) : '(all accounts)'} '
        '$trigger';
    return AndroidBackgroundScanWorker.executeScan(
      accountId: accountId,
      isTest: isTest,
      retryOnFailure: retryOnFailureFor(inputData),
      notificationProviders: notificationProvidersFor(inputData),
      dozeAlarm: inputData?[kTriggerSourceKey] == 'doze-alarm',
      trigger: trigger,
    );
  }, onTaskStopped: onWorkerStopped);
}

/// Sprint 79 Task 1 R-8 (class B): 11 scans stopped within 30 s of their
/// start with no heartbeat and no outcome line, and in three of them the same
/// Doze request ran again exactly 30 s later -- so something STOPPED the
/// worker, and the log could not say what. WorkManager tells the worker why
/// (Android 12+; `unknown` before). Bounded: the plugin tears the engine down
/// when this returns, so a slow write must not hold it. [write] is the test
/// seam; production writes to the diagnostic log.
@visibleForTesting
Future<void> onWorkerStopped(
  String taskName,
  StopReason reason, {
  Future<void> Function(String detail)? write,
}) async {
  final detail = describeWorkerStop(running: _runningWork, reason: reason);
  try {
    await (write ??
            (d) => DiagnosticLogger.log(
                  kind: DiagnosticLogger.kindScan,
                  context: 'worker/android',
                  detail: d,
                ))(detail)
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    // Nothing to report to: the log write itself is what failed.
  }
}

/// What this isolate's worker is running, for the stop line. One worker per
/// isolate, so a single value is enough.
String? _runningWork;

/// Sprint 79 Task 1 R-8: the diagnostic line for a worker WorkManager stopped
/// before it finished, e.g. `stopped by WorkManager before it finished:
/// reason=deviceIdle (k***@aol.com trigger=doze-alarm delay=0s)`.
@visibleForTesting
String describeWorkerStop({required String? running, required StopReason reason}) =>
    'stopped by WorkManager before it finished: reason=${reason.name}'
    '${running != null ? ' ($running)' : ''}';

/// Sprint 76 review H-1: whether a failed run may ask WorkManager to RETRY.
///
/// The plugin maps a `false` result to `Result.retry()` with WorkManager's
/// default backoff (30 s doubling to 5 h, no attempt limit). For the F253
/// new-mail trigger that is a trap: its unique work uses KEEP, so while a
/// retry waits in backoff every later notification is dropped -- one account
/// that always fails would turn "scan when new mail arrives" into "scan every
/// few hours", with Settings still reading "On". The next notification IS the
/// retry, so a notification-triggered run never asks for one.
///
/// The Doze one-off is the same trap (Sprint 76 7.7.1 review H-1): it also
/// uses KEEP since the Manual Validation decision, so a failed alarm run (for
/// example offline in Doze, which now counts as a failure) would sit in
/// backoff and swallow every later alarm. The next alarm IS its retry too.
/// The periodic task keeps the existing retry behavior (F175 R-6).
@visibleForTesting
bool retryOnFailureFor(Map<String, dynamic>? inputData) {
  final source = inputData?[kTriggerSourceKey];
  return source != 'notification' && source != 'doze-alarm';
}

/// F264 (Sprint 77): the providers a NOTIFICATION-started run may scan, or null
/// when the run is not a notification run (periodic, Doze alarm, test), which
/// keeps its own rules. A notification run whose payload carries no provider
/// set (a build that did not send one) reads as "every provider".
@visibleForTesting
String? notificationProvidersFor(Map<String, dynamic>? inputData) {
  if (inputData?[kTriggerSourceKey] != 'notification') return null;
  final providers = inputData?[kTriggerProvidersKey];
  return providers is String ? providers : kAnyProvider;
}

/// Sprint 78 MV-7 (Harold, Fold logs 2026-10-09..13): whether a DOZE-ALARM
/// or (Sprint 79) PERIODIC run skips an account because a scan of it started
/// recently.
///
/// Sprint 79 (Task 1 R-5, Harold Q1 = 1): the periodic run now applies the
/// same rule. With the skip on the alarm side only, a 15-minute account was
/// still scanned about twice per interval (Yahoo 6.25/hour overnight
/// 2026-10-14): the alarm fired 10-13 minutes after a periodic scan -- past
/// this window -- and scanned, and the periodic run about 5 minutes later
/// never checked. The periodic run counts only COMPLETED scans
/// (`getLatestScanStart(completedOnly: true)`), so its retry after a failure
/// still scans; see [checksRecentScan].
///
/// The F235 alarm exists to wake the phone when Doze holds WorkManager back
/// (ADR-0039 amendment, Sprint 73). It was scanning on its own schedule even
/// when the periodic job was running fine, so each account was scanned about
/// twice per interval: 558 AOL scans in 3.4 days at 15 minutes, against about
/// 320 expected.
///
/// Skips when a scan of the account (manual or background, any outcome)
/// started less than two-thirds of [interval] before [now]. Not the full
/// interval: the alarm re-arms when it fires and its scan starts about a
/// second later, so in Doze the next alarm finds the previous ALARM scan
/// slightly LESS than one interval old -- a full-interval rule would skip
/// every second alarm in exactly the state the alarm is for.
@visibleForTesting
bool recentScanShouldSkip({
  required DateTime now,
  required DateTime? lastScanStart,
  required Duration interval,
}) {
  if (lastScanStart == null) return false;
  final window = interval * 2 ~/ 3;
  final age = now.difference(lastScanStart);
  return !age.isNegative && age < window;
}

/// Sprint 79: which runs check for a recent scan. The Doze alarm and the
/// periodic schedule do; a Test run never does (the user asked for a scan
/// now), and neither does a new-mail notification run (new mail arrived, so
/// the last scan cannot have seen it).
@visibleForTesting
bool checksRecentScan({
  required bool isTest,
  required String? notificationProviders,
}) =>
    !isTest && notificationProviders == null;

/// The value handed back to WorkManager: `true` = done, `false` = retry.
@visibleForTesting
bool workerResult({required bool allSucceeded, required bool retryOnFailure}) =>
    allSucceeded || !retryOnFailure;

class AndroidBackgroundScanWorker {
  AndroidBackgroundScanWorker._();

  static final Logger _logger = Logger();

  /// Execute a background scan for [accountId], or for every saved account
  /// whose background scanning is on when [accountId] is null. Null is the
  /// normal case for the F253 new-mail trigger (one scan of all accounts) and
  /// a defensive fallback for anything else -- a scheduled task always carries
  /// its account.
  ///
  /// Returns what WorkManager should do: true = done, false = retry per the
  /// task's backoff policy. A failure retries only when [retryOnFailure] is
  /// true (see [retryOnFailureFor]); per-account failures are always logged.
  static Future<bool> executeScan({
    String? accountId,
    bool isTest = false,
    String? trigger,
    bool retryOnFailure = true,
    String? notificationProviders,
    bool dozeAlarm = false,
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

      // F248: AFTER the database paths are set -- the logger reads its
      // on/off setting from the database. Proves the worker ran at all,
      // which is one of the two F249 candidates.
      void workerLog(String detail) => unawaited(DiagnosticLogger.log(
            kind: DiagnosticLogger.kindScan,
            context: 'worker/android',
            detail: detail,
          ));
      // F248: the worker is its own isolate -- name the build it runs.
      unawaited(DiagnosticLogger.appEvent('background worker start (android)'));
      workerLog('start ${isTest ? '[TEST] ' : ''}'
          '${accountId != null ? Redact.accountId(accountId) : '(all accounts)'}'
          '${trigger != null ? ' $trigger' : ''}');

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

      // F264 (Q9 = 1): a notification run proves the native app-wide flag was
      // ON. If the upgrade conversion has not yet run (the user has not opened
      // the app since updating), do it here so the first notification does not
      // find every per-account switch unset and scan nothing.
      if (notificationProviders != null) {
        await NewMailSwitchMigration(
          settingsStore: settingsStore,
          getAccountIds: credStore.getSavedAccounts,
        ).runIfNeeded(nativeFlagWasOn: true);
      }

      var allSucceeded = true;
      for (final id in accountIds) {
        // Skip disabled accounts unless this is a test run (same rule as the
        // Windows worker).
        var backgroundEnabled = true;
        if (!isTest) {
          backgroundEnabled =
              await settingsStore.getEffectiveBackgroundEnabled(id);
          if (!backgroundEnabled) continue;
        }

        // Sprint 78 MV-7 + Sprint 79: a Doze-alarm or periodic run skips an
        // account scanned recently (see recentScanShouldSkip). The periodic
        // run counts only COMPLETED scans, so its retry after a failure still
        // scans. A failed check never skips: making sure a scan happens wins.
        if (checksRecentScan(
            isTest: isTest, notificationProviders: notificationProviders)) {
          final runKind = dozeAlarm ? 'doze alarm' : 'periodic';
          try {
            final last = await ScanResultStore(dbHelper)
                .getLatestScanStart(id, completedOnly: !dozeAlarm);
            final minutes =
                await settingsStore.getEffectiveBackgroundFrequency(id);
            final now = DateTime.now();
            if (recentScanShouldSkip(
                now: now,
                lastScanStart: last,
                interval: Duration(minutes: minutes))) {
              workerLog('account ${Redact.accountId(id)} skipped: a '
                  '${dozeAlarm ? '' : 'completed '}scan started '
                  '${now.difference(last!).inSeconds}s ago '
                  '(interval ${minutes}m; $runKind)');
              continue;
            }
          } catch (e) {
            workerLog('account ${Redact.accountId(id)} $runKind recent-scan '
                'check failed, scanning anyway: '
                '${DiagnosticLogger.describeError(e)}');
          }
        }

        // F264: a notification run scans only accounts whose OWN new-mail
        // switch is on (checked before the platform lookup so a switched-off
        // account is never counted as a failure).
        final newMailSwitch =
            notificationProviders == null ||
                await settingsStore.getAccountNewMailTrigger(id) == true;

        final platformId =
            await BackgroundScanCore.resolvePlatformId(credStore, id);

        if (platformId == null) {
          if (!newMailSwitch) continue;
          _logger.w('Cannot determine platform for ${Redact.accountId(id)}, '
              'skipping');
          allSucceeded = false;
          continue;
        }

        if (notificationProviders != null &&
            !accountSelectedByNotification(
              providers: notificationProviders,
              platformId: platformId,
              newMailSwitch: newMailSwitch,
              backgroundEnabled: backgroundEnabled,
            )) {
          workerLog('account ${Redact.accountId(id)} not selected by this '
              'notification (provider or new-mail switch)');
          continue;
        }

        try {
          final outcome = await BackgroundScanCore.scanAccount(
            accountId: id,
            platformId: platformId,
            ruleSetProvider: ruleSetProvider,
            settingsStore: settingsStore,
          );
          // MV74-2 + F206: skip -> nothing; scan -> export, then notify.
          // Branches tested through BackgroundScanCore.completeAccount.
          await BackgroundScanCore.completeAccount(
            outcome,
            export: () => BackgroundScanExport.exportIfEnabled(
              scanProvider: outcome.scanProvider,
              accountId: id,
              settingsStore: settingsStore,
              log: (m) async => _logger.i(m),
            ),
            notify: () => _notifyScanComplete(accountId: id, outcome: outcome),
          );
        } catch (e) {
          _logger.e('Background scan failed for ${Redact.accountId(id)}',
              error: e);
          workerLog('account ${Redact.accountId(id)} FAILED: '
              '${DiagnosticLogger.describeError(e)}');
          allSucceeded = false;
        }
      }
      // Awaited: the worker's isolate can end as soon as this returns, and
      // the logger chains its writes, so awaiting the last one also flushes
      // every scan line queued before it.
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'worker/android',
        detail: 'exit ${allSucceeded ? 'success' : 'with failures'}'
            '${!allSucceeded && !retryOnFailure ? ' (no retry: the next notification or alarm retries)' : ''}',
      );
      return workerResult(
          allSucceeded: allSucceeded, retryOnFailure: retryOnFailure);
    } catch (e) {
      _logger.e('Android background scan worker failed', error: e);
      // Review MEDIUM-5: awaited, like the exit line above -- the isolate can
      // end as soon as this returns, and this is the line most worth keeping.
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'worker/android',
        detail: 'worker FAILED: ${DiagnosticLogger.describeError(e)}',
      );
      return workerResult(allSucceeded: false, retryOnFailure: retryOnFailure);
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
  ///
  /// F286/F287 (Sprint 79): posted through the shared [ScanCompleteNotifier]
  /// (the Windows worker uses the same one): the title names the account, the
  /// body lists "No rule" first, the ID is per account, and a count the scan
  /// mode did not act on is struck through.
  static Future<void> _notifyScanComplete({
    required String accountId,
    required AccountScanOutcome outcome,
  }) =>
      ScanCompleteNotifier.post(
        accountId: accountId,
        mode: outcome.scanProvider.scanMode,
        noRule: outcome.unmatchedCount,
        deleted: outcome.deletedCount,
        safe: outcome.safeCount,
        errors: outcome.errorCount,
      );
}
