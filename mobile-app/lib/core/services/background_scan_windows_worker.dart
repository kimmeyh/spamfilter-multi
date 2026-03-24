import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../storage/database_helper.dart';
import '../storage/background_scan_log_store.dart';
import '../storage/settings_store.dart';
import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../services/app_environment.dart';
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
      final envSuffix = AppEnvironment.dataDirSuffix;
      final logPrefix = AppEnvironment.logPrefix;
      final logFile = File(
        '${Platform.environment['APPDATA']}\\MyEmailSpamFilter\\MyEmailSpamFilter$envSuffix\\logs\\${logPrefix}background_scan_v0.5.1.log',
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
            await _bgLog('Account $accountId scan SUCCESS: Processed: ${result.emailsProcessed}, Deleted: ${result.deletedCount}, Moved: ${result.movedCount}, Safe: ${result.safeCount}, No Rule: ${result.unmatchedCount}, Errors: ${result.errorCount}');

            // Export debug CSV if enabled
            await _exportDebugCsvIfEnabled(
              scanProvider: result.scanProvider,
              accountId: accountId,
              settingsStore: settingsStore,
            );

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

  /// F45: Export debug Excel file if the setting is enabled
  ///
  /// Writes scan results to a daily Excel (.xlsx) file in the configured export
  /// directory (or the app logs directory as fallback). Uses a companion CSV
  /// file (.data.csv) to accumulate rows across multiple runs in a day, then
  /// regenerates the Excel file from the accumulated data.
  ///
  /// Field order: Scan Date/Time, Received Date/Time, Status, Folder, Action,
  /// Rule, From, Subject, Match Condition, Email ID
  static Future<void> _exportDebugCsvIfEnabled({
    required EmailScanProvider scanProvider,
    required String accountId,
    required SettingsStore settingsStore,
  }) async {
    try {
      final debugCsvEnabled = await settingsStore.getBackgroundScanDebugCsv();
      if (!debugCsvEnabled) return;

      // Export to environment-aware AppData directory (ADR-0035)
      final envSuffix = AppEnvironment.dataDirSuffix;
      final exportDir = '${Platform.environment['APPDATA']}'
          '\\MyEmailSpamFilter\\MyEmailSpamFilter$envSuffix\\logs';

      // Ensure directory exists
      final dir = Directory(exportDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // F45: Daily filename (no time component), with _dev suffix per ADR-0035
      final safeAccountId = accountId
          .replaceAll('@', '_at_')
          .replaceAll('.', '_');
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final devSuffix = AppEnvironment.isDev ? '_dev' : '';
      final xlsxFilename = 'background_scan_${safeAccountId}_$dateStr$devSuffix.xlsx';
      final dataFilename = 'background_scan_${safeAccountId}_$dateStr$devSuffix.data.csv';
      final xlsxPath = path.join(exportDir, xlsxFilename);
      final dataPath = path.join(exportDir, dataFilename);

      // Get new rows from this scan run
      final newRows = scanProvider.getExcelRows();

      // F45: Append new rows to the daily data file (CSV accumulator)
      final dataFile = File(dataPath);
      final buffer = StringBuffer();

      if (newRows.isEmpty) {
        // Placeholder row for empty scan runs
        final scanDate = DateTime.now().toIso8601String();
        buffer.writeln('$scanDate\t$scanDate\t\t\t\t\t<no records to process>\t\t\t');
      } else {
        for (final row in newRows) {
          buffer.writeln(row.join('\t'));
        }
      }

      // Append to existing data file or create new
      await dataFile.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
      );

      // Read all accumulated rows and generate Excel
      final allDataLines = (await dataFile.readAsString())
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      const headers = [
        'Scan Date and Time',
        'Received Date and Time',
        'Status',
        'Folder',
        'Action',
        'Rule',
        'From',
        'Subject',
        'Match Condition',
        'Email ID',
      ];

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Background Scan';

      // Write header row with formatting
      for (var col = 0; col < headers.length; col++) {
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(headers[col]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#D9E2F3';
      }

      // Write all accumulated data rows
      for (var row = 0; row < allDataLines.length; row++) {
        final cells = allDataLines[row].split('\t');
        for (var col = 0; col < cells.length && col < headers.length; col++) {
          sheet.getRangeByIndex(row + 2, col + 1).setText(cells[col]);
        }
      }

      // Auto-fit column widths
      for (var col = 1; col <= headers.length; col++) {
        sheet.autoFitColumn(col);
      }

      // Save Excel file
      final bytes = workbook.saveAsStream();
      await File(xlsxPath).writeAsBytes(bytes);
      workbook.dispose();

      final addedRows = newRows.isEmpty ? 1 : newRows.length;
      await _bgLog('Debug Excel exported: $xlsxPath ($addedRows new rows, ${allDataLines.length} total)');
    } catch (e) {
      await _bgLog('Debug Excel export failed: $e');
      // Not critical - do not rethrow
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

    // [NEW] ISSUE #153: Load days-back setting for background scans
    final daysBack = await settingsStore.getEffectiveDaysBack(
      accountId,
      isBackground: true,
    );

    _logger.d('Scan mode: ${scanMode.name}, folders: $folders, daysBack: $daysBack');
    await _bgLog('Scan settings for $accountId: mode=${scanMode.name}, folders=$folders, daysBack=$daysBack');

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
    final emailsProcessed = scanProvider.processedCount;
    final deletedCount = scanProvider.deletedCount;
    final movedCount = scanProvider.movedCount;
    final safeCount = scanProvider.safeSendersCount;
    final unmatchedCount = scanProvider.noRuleCount;
    final errorCount = scanProvider.errorCount;

    _logger.i(
      'Account scan completed: $accountId - '
      'Processed: $emailsProcessed, Deleted: $deletedCount, Moved: $movedCount, '
      'Safe: $safeCount, No Rule: $unmatchedCount, Errors: $errorCount',
    );

    return _ScanResult(
      emailsProcessed: emailsProcessed,
      deletedCount: deletedCount,
      movedCount: movedCount,
      safeCount: safeCount,
      unmatchedCount: unmatchedCount,
      errorCount: errorCount,
      scanProvider: scanProvider,
    );
  }
}

/// Internal result holder for a single account scan
class _ScanResult {
  final int emailsProcessed;
  final int deletedCount;
  final int movedCount;
  final int safeCount;
  final int unmatchedCount;
  final int errorCount;
  final EmailScanProvider scanProvider;

  const _ScanResult({
    required this.emailsProcessed,
    required this.deletedCount,
    required this.movedCount,
    required this.safeCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.scanProvider,
  });
}
