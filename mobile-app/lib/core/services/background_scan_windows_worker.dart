import 'package:logger/logger.dart';

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/account_store.dart';
import '../providers/rule_set_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/storage/app_paths.dart';

/// Windows-specific background scan worker
///
/// Executes background email scans for all enabled accounts on Windows desktop.
/// Similar to BackgroundScanWorker but adapted for Windows Task Scheduler execution.
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
      final credStore = SecureCredentialsStore();

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
        try {
          // Check if background scans enabled for this account
          final isBackgroundEnabled = await _isBackgroundScanEnabled(
            accountId: account['account_id'] as String,
            dbHelper: dbHelper,
          );

          if (!isBackgroundEnabled) {
            _logger.d('Background scans disabled for account ${account['account_id']}');
            continue;
          }

          // Log the scheduled execution
          final logEntry = BackgroundScanLogEntry(
            accountId: account['account_id'] as String,
            scheduledTime: DateTime.now().millisecondsSinceEpoch,
            actualStartTime: DateTime.now().millisecondsSinceEpoch,
            status: 'success', // Will be updated if fails
          );

          final logId = await logStore.insertLog(logEntry);

          // Execute scan for this account
          try {
            await _scanAccount(
              accountId: account['account_id'] as String,
              platformId: account['platform_id'] as String,
              dbHelper: dbHelper,
              logId: logId,
              logStore: logStore,
              ruleSetProvider: ruleSetProvider,
              credStore: credStore,
            );
            successCount++;
          } catch (e) {
            _logger.e(
              'Failed to scan account ${account['account_id']}',
              error: e,
            );

            // Update log with failure
            final failedLog = BackgroundScanLogEntry(
              id: logId,
              accountId: account['account_id'] as String,
              scheduledTime: DateTime.now().millisecondsSinceEpoch,
              actualStartTime: DateTime.now().millisecondsSinceEpoch,
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

  /// Check if background scanning is enabled for an account
  static Future<bool> _isBackgroundScanEnabled({
    required String accountId,
    required DatabaseHelper dbHelper,
  }) async {
    try {
      final db = await dbHelper.database;
      final result = await db.query(
        'account_settings',
        where: 'account_id = ? AND setting_key = ?',
        whereArgs: [accountId, 'background_scan_enabled'],
        limit: 1,
      );

      if (result.isEmpty) {
        return false;
      }

      final value = result.first['setting_value'] as String;
      return value.toLowerCase() == 'true';
    } catch (e) {
      _logger.e('Failed to check background scan enabled status', error: e);
      return false;
    }
  }

  /// Scan a single account
  static Future<void> _scanAccount({
    required String accountId,
    required String platformId,
    required DatabaseHelper dbHelper,
    required int logId,
    required BackgroundScanLogStore logStore,
    required RuleSetProvider ruleSetProvider,
    required SecureCredentialsStore credStore,
  }) async {
    _logger.i('Scanning account: $accountId (platform: $platformId)');

    try {
      // Get account details
      final db = await dbHelper.database;
      final accountResult = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (accountResult.isEmpty) {
        throw Exception('Account not found: $accountId');
      }

      final account = accountResult.first;
      // final email = account['email'] as String; // Reserved for future logging

      // Get folders to scan (default to INBOX if not configured)
      final folders = await _getScannedFolders(accountId, dbHelper);
      _logger.d('Scanning folders: $folders');

      // Note: Full email scanning logic would integrate with EmailScanner here
      // For Sprint 8, we are focusing on Task Scheduler integration
      // The actual scanning will reuse the EmailScanner from Sprint 4

      // Update log with success
      final successLog = BackgroundScanLogEntry(
        id: logId,
        accountId: accountId,
        scheduledTime: DateTime.now().millisecondsSinceEpoch,
        actualStartTime: DateTime.now().millisecondsSinceEpoch,
        actualEndTime: DateTime.now().millisecondsSinceEpoch,
        status: 'success',
        emailsProcessed: 0, // Placeholder - actual scan would update this
        unmatchedCount: 0,  // Placeholder
      );

      await logStore.updateLog(successLog);
      _logger.i('Account scan completed: $accountId');
    } catch (e) {
      _logger.e('Failed to scan account: $accountId', error: e);
      rethrow;
    }
  }

  /// Get folders configured for scanning
  static Future<List<String>> _getScannedFolders(
    String accountId,
    DatabaseHelper dbHelper,
  ) async {
    try {
      final db = await dbHelper.database;
      final result = await db.query(
        'account_settings',
        where: 'account_id = ? AND setting_key = ?',
        whereArgs: [accountId, 'scanned_folders'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        // final foldersJson = result.first['setting_value'] as String;
        // TODO: Parse JSON array of folder names
        // For now, return default
        return ['INBOX'];
      }

      return ['INBOX']; // Default
    } catch (e) {
      _logger.w('Failed to get scanned folders, using default', error: e);
      return ['INBOX'];
    }
  }
}
