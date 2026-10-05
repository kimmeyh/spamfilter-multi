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
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

import '../../adapters/email_providers/spam_filter_platform.dart'
    show GmailSignInRequiredException;
import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../storage/database_helper.dart';
import '../storage/scan_result_store.dart';
import '../storage/settings_store.dart';
import 'diagnostic_logger.dart';
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

  /// F239 (Sprint 75): the skip is because Gmail needs the user to sign in
  /// again -- NOT because the account was busy. [BackgroundScanCore.scanAccount]
  /// must not wait and retry this one: only the user can fix it.
  final bool needsSignIn;

  /// F238 (Sprint 75): the scan was STOPPED on request (so a manual scan
  /// could start). Like [needsSignIn], never retried after the busy wait --
  /// the user is scanning this account by hand right now.
  final bool stopped;

  const AccountScanOutcome({
    required this.emailsProcessed,
    required this.deletedCount,
    required this.movedCount,
    required this.safeCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.scanProvider,
    this.skippedReason,
    this.needsSignIn = false,
    this.stopped = false,
  });

  /// A deliberate skip -- see [skippedReason].
  AccountScanOutcome.skipped(String reason, EmailScanProvider provider,
      {this.needsSignIn = false, this.stopped = false})
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
  /// Sprint 74 MV review (finding 2): is a scan-lock refusal a SKIP? Only
  /// when another scan actually holds the account. A lock that could not be
  /// checked (a database error) is a failure, and is rethrown so the workers
  /// count it as one -- and the Windows "database is locked" retry sees it.
  @visibleForTesting
  static bool isSkipRefusal(ScanAccountBusyException e) =>
      e.blockingScan != null;

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
  ///
  /// Harold, Sprint 74 MV round 4 (2026-09-28): *"if either of the N account
  /// scans finds the DB busy it waits random number of minutes between 2 and
  /// 6 minutes then starts (won't worry about conflict if they still
  /// conflict)"*. "Busy" is either case below, on the FIRST attempt:
  ///   - another scan holds this account (the early check or the scan lock
  ///     refused it -- both return a skip), or
  ///   - SQLite reported "database is locked" anywhere in the attempt.
  /// The scan then waits [busyRetryDelay] (random, 2:00 to 6:00) and runs
  /// ONCE more, through the same lock -- "starts" never means bypassing the
  /// lock, which would reopen two sessions on one account. If that attempt is
  /// busy too, its outcome stands (a skip, or the lock error rethrown).
  /// The random delay also spreads out the Doze batch, which delivers every
  /// account's alarm at the same moment.
  ///
  /// Replaces the Windows-only F98/F101 loop (15 attempts, 1 minute apart);
  /// one shared rule for both platforms (ADR-0042).
  ///
  /// Android caveat: a WorkManager worker has about 10 minutes without a
  /// foreground service, so a 6-minute wait leaves about 4 for the scan.
  static Future<AccountScanOutcome> scanAccount({
    required String accountId,
    required String platformId,
    required RuleSetProvider ruleSetProvider,
    required SettingsStore settingsStore,
    ScanResultStore? scanResultStore,
  }) async {
    Future<AccountScanOutcome> attempt() => _scanAccountOnce(
          accountId: accountId,
          platformId: platformId,
          ruleSetProvider: ruleSetProvider,
          settingsStore: settingsStore,
          scanResultStore: scanResultStore,
        );

    String busyBecause;
    try {
      final first = await attempt();
      // F239 / F238: a sign-in skip or a stopped scan is not "busy" --
      // waiting and scanning again cannot be what the user wants.
      if (!first.skipped || first.needsSignIn || first.stopped) return first;
      busyBecause = first.skippedReason!;
    } catch (e) {
      if (!isDatabaseLocked(e)) rethrow;
      busyBecause = 'database is locked';
    }
    final wait = busyRetryDelay();
    _logger.i('Background scan of ${Redact.accountId(accountId)} found it '
        'busy ($busyBecause); waiting ${wait.inSeconds}s, then one more '
        'attempt');
    unawaited(DiagnosticLogger.scanEvent(
      scanType: 'background',
      accountId: accountId,
      stage: 'busy-retry',
      detail: 'waiting ${wait.inSeconds}s (${DiagnosticLogger.scrub(busyBecause)})',
    ));
    await busyWait(wait);
    return attempt();
  }

  /// The wait before the one retry: random, 2:00 to 6:00 (Harold). A seam so
  /// tests need not wait minutes.
  @visibleForTesting
  static Duration Function() busyRetryDelay = randomBusyRetryDelay;

  /// How the wait is taken. A seam for tests.
  @visibleForTesting
  static Future<void> Function(Duration) busyWait =
      (d) => Future<void>.delayed(d);

  static final Random _random = Random();

  /// A uniformly random delay from 2:00 to 6:00 inclusive, to the second.
  static Duration randomBusyRetryDelay() =>
      Duration(seconds: 120 + _random.nextInt(241));

  /// True if [error] is (or wraps) a SQLite "database is locked" error.
  /// Moved here from the Windows worker (F98) so both platforms share it.
  static bool isDatabaseLocked(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('database is locked') || s.contains('(code 5)');
  }

  static Future<AccountScanOutcome> _scanAccountOnce({
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
    //
    // Harold Q4 (Sprint 74 MV): widened to a live scan of ANY type, including
    // another BACKGROUND scan -- the periodic task, the F235 Doze one-off and
    // Test Background Scan are separate WorkManager chains, and four ran on
    // one account inside a minute on the Fold8. This is only the cheap early
    // skip; the atomic claim in EmailScanProvider.startScan decides.
    final store = scanResultStore ?? ScanResultStore(DatabaseHelper());
    final live = await store.getActiveScanForAccount(accountId);
    if (live != null) {
      final reason = 'a ${live.scanType} scan is in progress on this account '
          '(scan id ${live.id})';
      _logger.i('Background scan SKIPPED for ${Redact.accountId(accountId)}: '
          '$reason');
      unawaited(DiagnosticLogger.scanEvent(
          scanType: 'background',
          accountId: accountId,
          stage: 'skip',
          detail: reason));
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
    } on ScanAccountBusyException catch (e) {
      // Harold Q4 (Sprint 74 MV): the claim was refused -- another scan took
      // the account between the early check above and the claim. A skip,
      // exactly like the early check: not an error, no row written.
      //
      // ONLY when another scan actually holds the account (review finding
      // 2). A lock that could not be CHECKED is a database failure and must
      // read as one: mapped to a skip, the workers counted it as success,
      // so a persistent database error would have stopped background
      // scanning while every run reported success -- and the Windows
      // worker's "database is locked" retry never saw the error.
      if (!isSkipRefusal(e)) rethrow;
      _logger.i('Background scan SKIPPED for ${Redact.accountId(accountId)} '
          'at the scan lock: $e');
      return AccountScanOutcome.skipped(e.userMessage, scanProvider);
    } on GmailSignInRequiredException {
      // F239 R-3 (Sprint 75): Gmail could not renew this account's sign-in
      // without the user. A SKIP -- not a failure, so Android does not
      // retry it on a timer and Windows does not report the run failed --
      // with the reason the account list repeats ("Sign In Again"). The
      // adapter has already flagged the account and kept its tokens.
      //
      // Known limit: the scan row was created by the claim before the
      // sign-in failed, and the scanner closed it as `error` with this same
      // reason. There is no `skipped` row status; adding one would change
      // what a stored value means (Class 1), so it was not done here.
      _logger.i('Background scan SKIPPED for ${Redact.accountId(accountId)}: '
          '${GmailSignInRequiredException.reason}');
      unawaited(DiagnosticLogger.scanEvent(
          scanType: 'background',
          accountId: accountId,
          stage: 'skip',
          detail: 'needs sign-in: ${GmailSignInRequiredException.reason}'));
      return AccountScanOutcome.skipped(
          GmailSignInRequiredException.reason, scanProvider,
          needsSignIn: true);
    } on TimeoutException {
      final minutes = ScanCoordinator.scanTimeout.inMinutes;
      _logger.e('Background scan TIMED OUT after $minutes minutes for '
          '${Redact.accountId(accountId)} -- marking failed (F175)');
      unawaited(DiagnosticLogger.scanEvent(
          scanType: 'background',
          accountId: accountId,
          stage: 'outcome',
          detail: 'timed out after $minutes minutes'));
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

    // F238 (Sprint 75): the scanner swallows a cancel (a normal outcome for
    // a MANUAL scan), so a background scan stopped for a manual scan arrives
    // here looking finished. Without this, the worker exported partial
    // results and notified "scan complete" for a scan the user had just
    // stopped. The row already records it as interrupted with the reason.
    if (scanProvider.wasCancelled) {
      _logger.i('Background scan STOPPED for ${Redact.accountId(accountId)} '
          'after ${scanProvider.processedCount} emails: '
          '${ScanResultStore.stoppedForManualScanReason}');
      return AccountScanOutcome.skipped(
          ScanResultStore.stoppedForManualScanReason, scanProvider,
          stopped: true);
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
