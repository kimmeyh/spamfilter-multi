import 'package:logger/logger.dart';

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/account_store.dart';
import '../storage/settings_store.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../services/email_scanner.dart';
import '../../adapters/storage/app_paths.dart';

/// Windows-specific background scan worker
///
/// Executes background email scans for all enabled accounts on Windows desktop.
/// Launched by Windows Task Scheduler with --background-scan flag.
/// Integrates with EmailScanner for full rule evaluation and batch processing.
class BackgroundScanWindowsWorker {
  static final Logger _logger = Logger();

  /// Execute background scan for all enabled accounts
  ///
  /// This method is called when the app is launched with --background-scan flag
  /// by Windows Task Scheduler. It scans all enabled accounts and logs results.
  static Future<bool> executeBackgroundScan() async {
    _logger.i('Starting Windows background scan worker execution');

    try {
      // Initialize app paths first
      final appPaths = AppPaths();
      await appPaths.initialize();
      _logger.d('AppPaths initialized');

      // Initialize services
      final dbHelper = DatabaseHelper();
      dbHelper.setAppPaths(appPaths);

      final logStore = BackgroundScanLogStore(dbHelper);
      final accountStore = AccountStore(dbHelper);
      final settingsStore = SettingsStore();

      // Initialize rule set provider
      final ruleSetProvider = RuleSetProvider();
      await ruleSetProvider.initialize();
      _logger.d('RuleSetProvider initialized with ${ruleSetProvider.rules.rules.length} rules');

      // Get all accounts
      final accounts = await accountStore.getAllAccounts();
      _logger.d('Found ${accounts.length} total accounts');

      int successCount = 0;
      int failureCount = 0;

      // Scan each enabled account
      for (final account in accounts) {
        final accountId = account['account_id'] as String;
        try {
          // Check if background scans enabled for this account
          final isBackgroundEnabled =
              await settingsStore.getEffectiveBackgroundEnabled(accountId);

          if (!isBackgroundEnabled) {
            _logger.d('Background scans disabled for account $accountId');
            continue;
          }

          // Log the scheduled execution
          final startTime = DateTime.now().millisecondsSinceEpoch;
          final logEntry = BackgroundScanLogEntry(
            accountId: accountId,
            scheduledTime: startTime,
            actualStartTime: startTime,
            status: 'running',
          );

          final logId = await logStore.insertLog(logEntry);

          // Execute scan for this account
          try {
            final result = await _scanAccount(
              accountId: accountId,
              platformId: account['platform_id'] as String,
              dbHelper: dbHelper,
              ruleSetProvider: ruleSetProvider,
              settingsStore: settingsStore,
            );

            // Update log with success
            final successLog = BackgroundScanLogEntry(
              id: logId,
              accountId: accountId,
              scheduledTime: startTime,
              actualStartTime: startTime,
              actualEndTime: DateTime.now().millisecondsSinceEpoch,
              status: 'success',
              emailsProcessed: result.emailsProcessed,
              unmatchedCount: result.unmatchedCount,
            );
            await logStore.updateLog(successLog);
            successCount++;
          } catch (e) {
            _logger.e('Failed to scan account $accountId', error: e);

            // Update log with failure
            final failedLog = BackgroundScanLogEntry(
              id: logId,
              accountId: accountId,
              scheduledTime: startTime,
              actualStartTime: startTime,
              actualEndTime: DateTime.now().millisecondsSinceEpoch,
              status: 'failed',
              errorMessage: e.toString(),
            );
            await logStore.updateLog(failedLog);
            failureCount++;
          }
        } catch (e) {
          _logger.e('Error processing account in background scan', error: e);
          failureCount++;
        }
      }

      // Cleanup old logs (keep last 30 per account)
      try {
        await logStore.cleanupOldLogs(keepPerAccount: 30);
      } catch (e) {
        _logger.w('Failed to cleanup old logs', error: e);
      }

      _logger.i(
        'Windows background scan worker completed: $successCount succeeded, $failureCount failed',
      );

      // Consider successful if at least some accounts scanned
      return successCount > 0;
    } catch (e) {
      _logger.e('Windows background scan worker failed', error: e);
      return false;
    }
  }

  /// Scan a single account using EmailScanner
  static Future<_ScanResult> _scanAccount({
    required String accountId,
    required String platformId,
    required DatabaseHelper dbHelper,
    required RuleSetProvider ruleSetProvider,
    required SettingsStore settingsStore,
  }) async {
    _logger.i('Scanning account: $accountId (platform: $platformId)');

    // Get effective background scan settings for this account
    final scanMode = await settingsStore.getEffectiveScanMode(
      accountId,
      isBackground: true,
    );
    final folders = await settingsStore.getEffectiveFolders(
      accountId,
      isBackground: true,
    );

    _logger.d('Scan mode: ${scanMode.name}, folders: $folders');

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
      folderNames: folders,
      scanType: 'background',
    );

    // Extract results from the scan provider
    final emailsProcessed = scanProvider.processedCount;
    final unmatchedCount = scanProvider.noRuleCount;

    _logger.i(
      'Account scan completed: $accountId - '
      'processed $emailsProcessed, unmatched $unmatchedCount',
    );

    return _ScanResult(
      emailsProcessed: emailsProcessed,
      unmatchedCount: unmatchedCount,
    );
  }
}

/// Internal result holder for a single account scan
class _ScanResult {
  final int emailsProcessed;
  final int unmatchedCount;

  const _ScanResult({
    required this.emailsProcessed,
    required this.unmatchedCount,
  });
}
