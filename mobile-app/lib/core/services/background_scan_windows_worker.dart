import 'dart:io';
import 'package:logger/logger.dart';

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/settings_store.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../services/email_scanner.dart';
import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/secure_credentials_store.dart';

/// Windows-specific background scan worker
///
/// Executes background email scans for all enabled accounts on Windows desktop.
/// Launched by Windows Task Scheduler with --background-scan flag.
/// Integrates with EmailScanner for full rule evaluation and batch processing.
class BackgroundScanWindowsWorker {
  static final Logger _logger = Logger();

  /// File-based logger for headless background mode diagnostics
  static Future<void> _bgLog(String message) async {
    try {
      final logFile = File(
        '${Platform.environment['APPDATA']}\\com.example\\spam_filter_mobile\\logs\\background_scan.log',
      );
      final timestamp = DateTime.now().toIso8601String();
      await logFile.parent.create(recursive: true);
      await logFile.writeAsString(
        '[$timestamp] [WORKER] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  /// Execute background scan for all enabled accounts
  ///
  /// This method is called when the app is launched with --background-scan flag
  /// by Windows Task Scheduler. It scans all enabled accounts and logs results.
  static Future<bool> executeBackgroundScan() async {
    _logger.i('Starting Windows background scan worker execution');
    await _bgLog('executeBackgroundScan() started');

    try {
      // Initialize app paths first
      await _bgLog('Initializing AppPaths...');
      final appPaths = AppPaths();
      await appPaths.initialize();
      _logger.d('AppPaths initialized');
      await _bgLog('AppPaths initialized: ${appPaths.appSupportDirectory.path}');

      // Initialize services
      await _bgLog('Initializing DatabaseHelper...');
      final dbHelper = DatabaseHelper();
      dbHelper.setAppPaths(appPaths);

      final logStore = BackgroundScanLogStore(dbHelper);
      final credStore = SecureCredentialsStore();
      final settingsStore = SettingsStore();
      await _bgLog('Stores initialized');

      // Initialize rule set provider
      await _bgLog('Initializing RuleSetProvider...');
      final ruleSetProvider = RuleSetProvider();
      await ruleSetProvider.initialize();
      _logger.d('RuleSetProvider initialized with ${ruleSetProvider.rules.rules.length} rules');
      await _bgLog('RuleSetProvider initialized: ${ruleSetProvider.rules.rules.length} rules');

      // Get all accounts from SecureCredentialsStore (not SQLite - accounts are stored
      // in flutter_secure_storage / Windows Credential Manager)
      await _bgLog('Loading accounts from SecureCredentialsStore...');
      final accountIds = await credStore.getSavedAccounts();
      _logger.d('Found ${accountIds.length} total accounts');
      await _bgLog('Found ${accountIds.length} total accounts: $accountIds');

      int successCount = 0;
      int failureCount = 0;

      // Scan each enabled account
      for (final accountId in accountIds) {
        await _bgLog('Processing account: $accountId');
        try {
          // Check if background scans enabled for this account
          final isBackgroundEnabled =
              await settingsStore.getEffectiveBackgroundEnabled(accountId);

          if (!isBackgroundEnabled) {
            _logger.d('Background scans disabled for account $accountId');
            await _bgLog('Background scans disabled for $accountId, skipping');
            continue;
          }

          // Resolve platform ID from credential store or infer from account ID
          String? platformId = await credStore.getPlatformId(accountId);
          if (platformId == null || platformId.isEmpty) {
            // Infer from account ID format: "{platform}-{email}"
            final dashIndex = accountId.indexOf('-');
            if (dashIndex > 0) {
              platformId = accountId.substring(0, dashIndex);
              await _bgLog('Inferred platformId: $platformId from accountId: $accountId');
            } else {
              await _bgLog('Cannot determine platformId for $accountId, skipping');
              failureCount++;
              continue;
            }
          }
          await _bgLog('Account $accountId -> platform: $platformId');

          // Ensure account exists in SQLite accounts table (required for FK constraints).
          // Accounts are primarily stored in flutter_secure_storage but SQLite tables
          // like background_scan_log have FK references to the accounts table.
          await _ensureAccountInDatabase(
            dbHelper: dbHelper,
            accountId: accountId,
            platformId: platformId,
          );

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
          await _bgLog('Executing scan for $accountId (platform: $platformId)');
          try {
            final result = await _scanAccount(
              accountId: accountId,
              platformId: platformId,
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
            await _bgLog('Account $accountId scan SUCCESS: ${result.emailsProcessed} processed, ${result.unmatchedCount} unmatched');
            successCount++;
          } catch (e, stackTrace) {
            _logger.e('Failed to scan account $accountId', error: e);
            await _bgLog('Account $accountId scan FAILED: $e');
            await _bgLog('Stack trace: $stackTrace');

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
        } catch (e, stackTrace) {
          _logger.e('Error processing account in background scan', error: e);
          await _bgLog('OUTER catch for $accountId: $e');
          await _bgLog('Stack trace: $stackTrace');
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
      await _bgLog('Worker completed: $successCount succeeded, $failureCount failed');

      // Consider successful if at least some accounts scanned
      return successCount > 0;
    } catch (e, stackTrace) {
      _logger.e('Windows background scan worker failed', error: e);
      await _bgLog('Worker EXCEPTION: $e');
      await _bgLog('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Ensure the account exists in the SQLite accounts table.
  ///
  /// The primary account list lives in flutter_secure_storage, but
  /// background_scan_log has a FOREIGN KEY to accounts(account_id).
  /// This method inserts the account row if it does not already exist.
  static Future<void> _ensureAccountInDatabase({
    required DatabaseHelper dbHelper,
    required String accountId,
    required String platformId,
  }) async {
    try {
      final db = await dbHelper.database;
      final existing = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // Extract email from accountId (format varies: "email" or "platform-email")
        String email = accountId;
        final dashIndex = accountId.indexOf('-');
        if (dashIndex > 0 && dashIndex < accountId.length - 1) {
          final afterDash = accountId.substring(dashIndex + 1);
          if (afterDash.contains('@')) {
            email = afterDash;
          }
        }

        await db.insert('accounts', {
          'account_id': accountId,
          'platform_id': platformId,
          'email': email,
          'date_added': DateTime.now().millisecondsSinceEpoch,
        });
        await _bgLog('Inserted account $accountId into SQLite accounts table');
      }
    } catch (e) {
      await _bgLog('Failed to ensure account in database: $e');
      // Do not rethrow - best effort to maintain FK integrity
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
