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

import 'package:logger/logger.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../storage/settings_store.dart';
import 'email_scanner.dart';

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

  const AccountScanOutcome({
    required this.emailsProcessed,
    required this.deletedCount,
    required this.movedCount,
    required this.safeCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.scanProvider,
  });
}

class BackgroundScanCore {
  BackgroundScanCore._();

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
  }) async {
    _logger.i(
        'Scanning account: ${Redact.accountId(accountId)} (platform: $platformId)');

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

    await scanner.scanInbox(
      daysBack: daysBack,
      folderNames: folders,
      scanType: 'background',
    );

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
