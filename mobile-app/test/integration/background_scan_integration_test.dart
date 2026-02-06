import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/background_scan_log_store.dart';
import 'package:spam_filter_mobile/core/storage/account_store.dart';
import 'package:spam_filter_mobile/core/services/background_scan_manager.dart';
import '../helpers/database_test_helper.dart';

/// Integration tests for background scanning workflow
/// Tests the complete flow from account setup through scan execution
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;
  late DatabaseHelper dbHelper;
  late BackgroundScanLogStore logStore;
  late AccountStore accountStore;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    dbHelper = testHelper.dbHelper;
    logStore = BackgroundScanLogStore(dbHelper);
    accountStore = AccountStore(dbHelper);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('Background Scan Integration - Complete Workflow', () {
    test('setup account → schedule scan → log execution → cleanup', () async {
      // Step 1: Set up account
      const testAccountId = 'integration-gmail-001';
      const testEmail = 'test@gmail.com';

      await accountStore.insertAccount(
        accountId: testAccountId,
        platformId: 'gmail',
        email: testEmail,
        displayName: 'Integration Test User',
      );

      var account = await accountStore.getAccount(testAccountId);
      expect(account, isNotNull);
      expect(account!['email'], testEmail);

      // Step 2: Insert scan logs
      final now = DateTime.now().millisecondsSinceEpoch;
      final logEntry = BackgroundScanLogEntry(
        accountId: testAccountId,
        scheduledTime: now,
        actualStartTime: now + 1000,
        actualEndTime: now + 5000,
        status: 'success',
        emailsProcessed: 100,
        unmatchedCount: 5,
      );

      final logId = await logStore.insertLog(logEntry);
      expect(logId, greaterThan(0));

      // Step 3: Retrieve scan history
      final latestLog = await logStore.getLatestLog(testAccountId);
      expect(latestLog, isNotNull);
      expect(latestLog!.emailsProcessed, 100);
      expect(latestLog.unmatchedCount, 5);

      // Step 4: Multiple scans with history
      for (int i = 0; i < 3; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: testAccountId,
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000) + 1000,
          actualEndTime: now + (i * 60000) + 5000,
          status: 'success',
          emailsProcessed: 50 + (i * 10),
          unmatchedCount: 2 + i,
        ));
      }

      // Step 5: Verify history is maintained
      final allLogs = await logStore.getLogsForAccount(testAccountId);
      expect(allLogs.length, 4);

      // Step 6: Cleanup old logs (keep only 2)
      await logStore.cleanupOldLogs(keepPerAccount: 2);
      final remainingLogs = await logStore.getLogsForAccount(testAccountId);
      expect(remainingLogs.length, 2);

      // Step 7: Verify account still exists after cleanup
      account = await accountStore.getAccount(testAccountId);
      expect(account, isNotNull);
    });

    test('multiple accounts with independent scan histories', () async {
      const gmail1 = 'gmail1@gmail.com';
      const gmail2 = 'gmail2@gmail.com';
      const aol = 'user@aol.com';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Set up accounts
      await accountStore.insertAccount(
        accountId: 'gmail1',
        platformId: 'gmail',
        email: gmail1,
      );
      await accountStore.insertAccount(
        accountId: 'gmail2',
        platformId: 'gmail',
        email: gmail2,
      );
      await accountStore.insertAccount(
        accountId: 'aol1',
        platformId: 'aol',
        email: aol,
      );

      // Add scans for each account
      for (int i = 0; i < 5; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'gmail1',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      for (int i = 0; i < 3; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'gmail2',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      for (int i = 0; i < 7; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'aol1',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      // Verify counts
      expect((await logStore.getLogsForAccount('gmail1')).length, 5);
      expect((await logStore.getLogsForAccount('gmail2')).length, 3);
      expect((await logStore.getLogsForAccount('aol1')).length, 7);

      // Cleanup only affects specific accounts
      await logStore.cleanupOldLogs(keepPerAccount: 2);

      expect((await logStore.getLogsForAccount('gmail1')).length, 2);
      expect((await logStore.getLogsForAccount('gmail2')).length, 2);
      expect((await logStore.getLogsForAccount('aol1')).length, 2);
    });

    test('scan with success, failure, and retry status', () async {
      const accountId = 'status-test-account';
      final now = DateTime.now().millisecondsSinceEpoch;

      await accountStore.insertAccount(
        accountId: accountId,
        platformId: 'gmail',
        email: 'status@test.com',
      );

      // Successful scan
      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: accountId,
        scheduledTime: now,
        status: 'success',
      ));

      // Failed scan
      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: accountId,
        scheduledTime: now + 60000,
        status: 'failed',
        errorMessage: 'Connection timeout',
      ));

      // Retry scan
      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: accountId,
        scheduledTime: now + 120000,
        status: 'retry',
        errorMessage: 'Rate limited',
      ));

      // Query by status
      final successLogs = await logStore.getLogsByStatus('success');
      final failedLogs = await logStore.getLogsByStatus('failed');
      final retryLogs = await logStore.getLogsByStatus('retry');

      expect(successLogs.length, greaterThan(0));
      expect(failedLogs.length, greaterThan(0));
      expect(retryLogs.length, greaterThan(0));

      // Verify statuses match
      expect(successLogs.every((log) => log.status == 'success'), true);
      expect(failedLogs.every((log) => log.status == 'failed'), true);
      expect(retryLogs.every((log) => log.status == 'retry'), true);
    });

    test('scan metrics tracking and statistics', () async {
      const accountId = 'metrics-account';
      final now = DateTime.now().millisecondsSinceEpoch;

      await accountStore.insertAccount(
        accountId: accountId,
        platformId: 'gmail',
        email: 'metrics@test.com',
      );

      // Scan with various metrics
      final scans = [
        (100, 5),   // 100 emails, 5 unmatched
        (200, 8),   // 200 emails, 8 unmatched
        (150, 3),   // 150 emails, 3 unmatched
      ];

      for (int i = 0; i < scans.length; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: accountId,
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          actualEndTime: now + (i * 60000) + 10000,
          status: 'success',
          emailsProcessed: scans[i].$1,
          unmatchedCount: scans[i].$2,
        ));
      }

      // Retrieve and verify metrics
      final allLogs = await logStore.getLogsForAccount(accountId);
      final totalEmails = allLogs.fold<int>(
        0,
        (sum, log) => sum + log.emailsProcessed,
      );
      final totalUnmatched = allLogs.fold<int>(
        0,
        (sum, log) => sum + log.unmatchedCount,
      );

      expect(totalEmails, 450);  // 100 + 200 + 150
      expect(totalUnmatched, 16); // 5 + 8 + 3
    });

    test('frequency validation for scheduling', () {
      for (final freq in ScanFrequency.values) {
        expect(
          BackgroundScanManager.isValidFrequency(freq.minutes),
          true,
          reason: 'Frequency ${freq.label} should be valid',
        );
      }
    });

    test('schedule status reflects current configuration', () {
      final statusDisabled = ScanScheduleStatus(isScheduled: false);
      expect(statusDisabled.toString(), contains('disabled'));

      final statusEnabled = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.daily,
      );
      expect(statusEnabled.toString(), contains('Daily'));
    });
  });
}
