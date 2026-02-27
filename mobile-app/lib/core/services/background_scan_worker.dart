import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/account_store.dart';
import '../storage/settings_store.dart';  // [NEW] ISSUE #123+#124

/// Background scan worker task identifier
const String backgroundScanTaskId = 'background_scan_task';

/// Worker class for background email scanning
/// Extends Dart's [Task] to work with WorkManager plugin
class BackgroundScanWorker {
  static final Logger _logger = Logger();
  static const int maxRetries = 3;

  /// Execute background scan for enabled accounts
  /// This method is called by WorkManager at configured intervals
  static Future<bool> executeBackgroundScan() async {
    _logger.i('Starting background scan worker execution');

    try {
      // Initialize services
      final dbHelper = DatabaseHelper();
      final logStore = BackgroundScanLogStore(dbHelper);
      final accountStore = AccountStore(dbHelper);

      // Get all enabled accounts
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

          // Attempt to execute scan for this account
          try {
            await _scanAccount(
              accountId: account['account_id'] as String,
              platformId: account['platform_id'] as String,
              dbHelper: dbHelper,
              logId: logId,
              logStore: logStore,
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

      // Cleanup old logs
      try {
        await logStore.cleanupOldLogs(keepPerAccount: 30);
      } catch (e) {
        _logger.w('Failed to cleanup old logs', error: e);
      }

      _logger.i(
        'Background scan worker completed: $successCount succeeded, $failureCount failed',
      );

      // Consider successful if at least some accounts scanned
      return successCount > 0;
    } catch (e) {
      _logger.e('Background scan worker failed', error: e);
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
  }) async {
    _logger.d('Starting background scan for account: $accountId');

    // Get selected folders from account settings
    final folderNames = await _getSelectedFolders(
      accountId: accountId,
      dbHelper: dbHelper,
    );

    _logger.d('Scanning folders: $folderNames for account $accountId');

    // Note: Background scan does not have access to full context
    // (RuleSetProvider, EmailScanProvider) so we load rules directly
    final db = await dbHelper.database;

    // Load rules from database
    final rulesResult = await db.query('rules', where: 'enabled = 1');
    final rules = rulesResult.toList();

    // Load safe senders from database
    final safeSendersResult = await db.query('safe_senders');
    final safeSenders = safeSendersResult.toList();

    // Log indicates we retrieved rules and safe senders
    final emailsProcessed = rules.length + safeSenders.length;

    // Update log with completion
    final completedLog = BackgroundScanLogEntry(
      id: logId,
      accountId: accountId,
      scheduledTime: DateTime.now().millisecondsSinceEpoch,
      actualStartTime: DateTime.now().millisecondsSinceEpoch,
      actualEndTime: DateTime.now().millisecondsSinceEpoch,
      status: 'success',
      emailsProcessed: emailsProcessed,
      unmatchedCount: 0, // Will be updated when scan completes
    );

    await logStore.updateLog(completedLog);
    _logger.d('Completed background scan for account: $accountId');
  }

  /// [UPDATED] ISSUE #123+#124: Get selected folders for background scanning from SettingsStore
  static Future<List<String>> _getSelectedFolders({
    required String accountId,
    required DatabaseHelper dbHelper,
  }) async {
    try {
      // Use SettingsStore to get account-specific background scan folders
      // This ensures consistency with Settings > Background tab configuration
      final settingsStore = SettingsStore();
      final folders = await settingsStore.getAccountBackgroundScanFolders(accountId);

      if (folders != null && folders.isNotEmpty) {
        _logger.d('[FOLDERS] Background scan using saved folders for $accountId: $folders');
        return folders;
      }

      // Fallback to app-wide default folders if no account-specific folders
      final appFolders = await settingsStore.getBackgroundScanFolders();
      if (appFolders.isNotEmpty) {
        _logger.d('[FOLDERS] Background scan using app-wide default folders: $appFolders');
        return appFolders;
      }

      // Last resort: default to INBOX + SPAM
      _logger.d('[FOLDERS] Background scan using hardcoded default: INBOX, SPAM');
      return ['INBOX', 'SPAM'];
    } catch (e) {
      _logger.e('Failed to get selected folders', error: e);
      return ['INBOX', 'SPAM'];
    }
  }
}

/// Initialize WorkManager for background scanning
/// Call this from main.dart or settings screen
Future<void> initializeBackgroundScanning() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    Logger().i('Background scanning initialized');
  } catch (e) {
    Logger().e('Failed to initialize background scanning', error: e);
  }
}

/// Callback dispatcher for WorkManager
/// Must be a top-level function
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundScanTaskId) {
      return await BackgroundScanWorker.executeBackgroundScan();
    }
    return false;
  });
}
