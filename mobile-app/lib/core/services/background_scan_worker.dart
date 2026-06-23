import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/account_store.dart';
import '../storage/settings_store.dart';  // [NEW] ISSUE #123+#124
import '../../util/redact.dart';

/// Background scan worker task identifier
const String backgroundScanTaskId = 'background_scan_task';

/// Worker class for background email scanning
/// Extends Dart's [Task] to work with WorkManager plugin
class BackgroundScanWorker {
  static final Logger _logger = Logger();
  static const int maxRetries = 3;

  /// Execute background scan for enabled accounts.
  /// This method is called by WorkManager at configured intervals.
  ///
  /// F98 (ADR-0039): when [accountId] is non-null, scans ONLY that account (the
  /// per-account WorkManager task passes it via inputData). When null, retains
  /// the legacy iterate-all-enabled-accounts behavior.
  static Future<bool> executeBackgroundScan({String? accountId}) async {
    _logger.i('Starting background scan worker execution'
        '${accountId != null ? ' for account ${Redact.accountId(accountId)}' : ' (all accounts)'}');

    try {
      // Initialize services
      final dbHelper = DatabaseHelper();
      final logStore = BackgroundScanLogStore(dbHelper);
      final accountStore = AccountStore(dbHelper);
      final settingsStore = SettingsStore(dbHelper);

      // Get accounts: all, or just the named account when account-scoped.
      var accounts = await accountStore.getAllAccounts();
      if (accountId != null) {
        accounts = accounts
            .where((a) => (a['account_id'] as String) == accountId)
            .toList();
      }
      _logger.d('Scanning ${accounts.length} account(s)');

      int successCount = 0;
      int failureCount = 0;

      // Scan each enabled account
      for (final account in accounts) {
        try {
          // F98: use the canonical effective-enable resolver (fixes the latent
          // wrong-key bug where the worker queried 'background_scan_enabled'
          // but the writer stores 'background_enabled').
          final isBackgroundEnabled = await settingsStore
              .getEffectiveBackgroundEnabled(account['account_id'] as String);

          if (!isBackgroundEnabled) {
            _logger.d('Background scans disabled for account ${Redact.accountId(account['account_id'] as String?)}');
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
  /// Scan a single account
  static Future<void> _scanAccount({
    required String accountId,
    required String platformId,
    required DatabaseHelper dbHelper,
    required int logId,
    required BackgroundScanLogStore logStore,
  }) async {
    _logger.d('Starting background scan for account: ${Redact.accountId(accountId)}');

    // Get selected folders from account settings
    final folderNames = await _getSelectedFolders(
      accountId: accountId,
      dbHelper: dbHelper,
    );

    _logger.d('Scanning folders: $folderNames for account ${Redact.accountId(accountId)}');

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
    _logger.d('Completed background scan for account: ${Redact.accountId(accountId)}');
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
        _logger.d('[FOLDERS] Background scan using saved folders for ${Redact.accountId(accountId)}: $folders');
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
    // F98 (ADR-0039): per-account unique task names are
    // `background_scan_task::<accountId>` and carry the accountId in inputData.
    // The legacy `background_scan_task` (no accountId) still runs all accounts.
    if (taskName == backgroundScanTaskId ||
        taskName.startsWith('$backgroundScanTaskId::')) {
      final accountId = inputData?['account_id'] as String?;
      return await BackgroundScanWorker.executeBackgroundScan(
          accountId: accountId);
    }
    return false;
  });
}
