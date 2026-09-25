/// F161 (Sprint 61): the SHARED per-account background-scan core, used by both
/// platform workers (Windows Task Scheduler worker, Android WorkManager worker).
///
/// Extracted VERBATIM from `BackgroundScanWindowsWorker._scanAccount` rather
/// than duplicated into the Android worker. The duplication would have been
/// exactly where the Sprint 60 failure class breeds: two orchestrations of the
/// same scan drift apart one edit at a time until one platform silently skips
/// a step the other performs (the accounts-FK bug lived in precisely such a
/// platform-local orchestration for months). One core, two thin platform
/// wrappers (ADR-0042: fork at the narrowest possible point).
///
/// What this core deliberately does NOT contain: scheduling (per-platform by
/// necessity -- the factory in `background_scan_scheduler.dart`), platform
/// notifications, the Windows per-account file log, and the Windows Excel
/// export. Those stay in the platform workers.
library;

import 'dart:async';

import 'package:logger/logger.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../storage/database_helper.dart';
import '../storage/scan_result_store.dart';
import '../storage/settings_store.dart';
import 'email_scanner.dart';
import 'scan_coordinator.dart';

/// Result of scanning a single account in the background.
///
/// Public equivalent of the Windows worker's former private `_ScanResult`,
/// promoted so both platform workers consume the same type.
class AccountScanOutcome {
  final int emailsProcessed;
  final int deletedCount;
  final int movedCount;
  final int safeCount;
  final int unmatchedCount;
  final int errorCount;

  /// The provider the scan ran through -- exposed because the Windows worker
  /// reads auth failures and the Excel exporter off it after the scan.
  final EmailScanProvider scanProvider;

  /// MV74-2 (Sprint 74): non-null when the account was deliberately NOT
  /// scanned because an interactive scan was live on it (ADR-0039 amendment).
  /// All counts are zero. Not a failure: the run did what it should.
  final String? skippedReason;

  bool get skipped => skippedReason != null;

  const AccountScanOutcome({
    required this.emailsProcessed,
    required this.deletedCount,
    required this.movedCount,
    required this.safeCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.scanProvider,
    this.skippedReason,
  });

  /// A deliberate skip -- see [skippedReason].
  AccountScanOutcome.skipped(String reason, EmailScanProvider provider)
      : emailsProcessed = 0,
        deletedCount = 0,
        movedCount = 0,
        safeCount = 0,
        unmatchedCount = 0,
        errorCount = 0,
        scanProvider = provider,
        skippedReason = reason;
}

class BackgroundScanCore {
  BackgroundScanCore._();

  /// What a worker does AFTER an account scan (review I-1, Sprint 74) -- a
  /// seam so both branches are testable rather than guarded by source text:
  ///   - a deliberate SKIP (a live interactive scan on the account) exports
  ///     nothing and notifies nothing -- otherwise the user would get a
  ///     "0 processed" notification every cycle while scanning by hand;
  ///   - a real scan runs the export (F206: this call is what makes Android's
  ///     background export exist at all) and then the notification.
  static Future<void> completeAccount(
    AccountScanOutcome outcome, {
    required Future<void> Function() export,
    required Future<void> Function() notify,
  }) async {
    if (outcome.skipped) return;
    await export();
    await notify();
  }

  static final Logger _logger = Logger();

  /// Resolve an account's platform id from the credential store, falling back
  /// to inference from the `{platform}-{email}` accountId form.
  ///
  /// Shared because BOTH workers need it before they can construct a scanner.
  /// The inference guard (dash must precede the '@') is the PR #335 rule: a
  /// dash inside a plain email ("my-name@gmail.com") must never be read as a
  /// platform prefix. Returns null when no platform can be determined -- the
  /// caller skips the account rather than guessing.
  static Future<String?> resolvePlatformId(
    SecureCredentialsStore credStore,
    String accountId,
  ) async {
    final stored = await credStore.getPlatformId(accountId);
    if (stored != null && stored.isNotEmpty) return stored;

    final atIndex = accountId.indexOf('@');
    final dashIndex = accountId.indexOf('-');
    if (dashIndex > 0 && (atIndex < 0 || dashIndex < atIndex)) {
      return accountId.substring(0, dashIndex);
    }
    return null;
  }

  /// Scan one account with its effective BACKGROUND settings.
  ///
  /// Body extracted verbatim from `BackgroundScanWindowsWorker._scanAccount`
  /// (F161): effective scan mode / folders / days-back resolved with
  /// `isBackground: true`, a headless [EmailScanProvider] (no UI listeners),
  /// and the shared [EmailScanner] pipeline with `scanType: 'background'`.
  /// Persistence happens INSIDE the shared scanner (it initializes the
  /// provider's persistence with the database helper), so both platforms
  /// persist scan_results, email_actions, and unmatched_emails identically --
  /// the invariant Sprint 60's accounts-FK bug taught us to guard.
  static Future<AccountScanOutcome> scanAccount({
    required String accountId,
    required String platformId,
    required RuleSetProvider ruleSetProvider,
    required SettingsStore settingsStore,
    ScanResultStore? scanResultStore,
  }) async {
    _logger.i(
        'Scanning account: ${Redact.accountId(accountId)} (platform: $platformId)');

    // MV74-2 (Sprint 74, Harold Q3 -- ADR-0039 amendment): YIELD to a live
    // interactive scan on this account. The UI's ScanCoordinator cannot see
    // this scan -- it runs in a separate isolate (Android WorkManager) or
    // process (Windows Task Scheduler) -- so without this check a manual scan
    // and a background scan could hold two IMAP sessions on one account, the
    // Sprint 61 session-cap failure. The shared database row's heartbeat is
    // the only signal both sides can read. Checked BEFORE any connection.
    final store = scanResultStore ?? ScanResultStore(DatabaseHelper());
    final live = await store.getActiveInteractiveScanForAccount(accountId);
    if (live != null) {
      final reason = 'a ${live.scanType} scan is in progress on this account '
          '(scan id ${live.id})';
      _logger.i('Background scan SKIPPED for ${Redact.accountId(accountId)}: '
          '$reason');
      return AccountScanOutcome.skipped(reason, EmailScanProvider());
    }

    // Get effective background scan settings for this account
    final scanMode = await settingsStore.getEffectiveScanMode(
      accountId,
      isBackground: true,
    );
    final folders = await settingsStore.getEffectiveFolders(
      accountId,
      isBackground: true,
    );

    // [NEW] ISSUE #153: Load days-back setting for background scans
    final daysBack = await settingsStore.getEffectiveDaysBack(
      accountId,
      isBackground: true,
    );

    _logger.d(
        'Scan mode: ${scanMode.name}, folders: $folders, daysBack: $daysBack');

    // Create a headless scan provider (no UI listeners in background mode)
    final scanProvider = EmailScanProvider();
    scanProvider.initializeScanMode(mode: scanMode);

    // Create and run the email scanner
    final scanner = EmailScanner(
      platformId: platformId,
      accountId: accountId,
      ruleSetProvider: ruleSetProvider,
      scanProvider: scanProvider,
    );

    // F175 (Sprint 62): hard timeout on the whole background scan. A hung
    // scan (dead socket, provider stall) used to sit `in_progress` forever
    // with no error; now it is failed loudly. Dart's timeout does not
    // cancel the underlying work -- if the zombie scan later completes it
    // will honestly overwrite the row to completed -- but the WORKER is
    // unblocked and the row records the timeout.
    //
    // F221 (Sprint 70) -- SUPERSEDED: this comment used to read *"Manual
    // scans deliberately have no timeout wrap: a user is watching and can
    // cancel."* That premise was wrong once the user navigates away, and
    // Harold reversed the decision on 2026-09-17 (Class-2). Manual scans now
    // take the SAME 30-minute timeout, applied in `startRealScan`
    // (`scan_progress_screen.dart`) -- a top-level function, so the timeout
    // survives the screen being left. Both paths read
    // ScanCoordinator.scanTimeout, so they tighten together.
    try {
      await scanner
          .scanInbox(
            daysBack: daysBack,
            folderNames: folders,
            scanType: 'background',
          )
          .timeout(ScanCoordinator.scanTimeout);
    } on TimeoutException {
      final minutes = ScanCoordinator.scanTimeout.inMinutes;
      _logger.e('Background scan TIMED OUT after $minutes minutes for '
          '${Redact.accountId(accountId)} -- marking failed (F175)');
      // Sprint 62 code review (C-2): the hung scanInbox still holds the
      // coordinator lease -- its `finally` cannot run until the hang
      // resolves, which may be never. Without this, every queued scan
      // waits its full limit and then fails, defeating exactly the
      // hung-scan case F175 exists for. Owner-matched, so a timeout that
      // fired while this scan was still QUEUED cannot evict a different
      // live scan.
      ScanCoordinator.instance.releaseActiveByOwner(
        scanType: 'background',
        accountId: accountId,
      );
      await scanProvider
          .errorScan('Scan timed out after $minutes minutes (F175)');
      rethrow;
    }

    // Extract results from the scan provider
    final outcome = AccountScanOutcome(
      emailsProcessed: scanProvider.processedCount,
      deletedCount: scanProvider.deletedCount,
      movedCount: scanProvider.movedCount,
      safeCount: scanProvider.safeSendersCount,
      unmatchedCount: scanProvider.noRuleCount,
      errorCount: scanProvider.errorCount,
      scanProvider: scanProvider,
    );

    _logger.i(
      'Account scan completed: ${Redact.accountId(accountId)} - '
      'Processed: ${outcome.emailsProcessed}, Deleted: ${outcome.deletedCount}, '
      'Moved: ${outcome.movedCount}, Safe: ${outcome.safeCount}, '
      'No Rule: ${outcome.unmatchedCount}, Errors: ${outcome.errorCount}',
    );

    return outcome;
  }
}
