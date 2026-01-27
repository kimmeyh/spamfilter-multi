import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/background_scan_log_store.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for desktop testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late BackgroundScanLogStore logStore;

  setUp(() async {
    dbHelper = DatabaseHelper();
    logStore = BackgroundScanLogStore(dbHelper);
    // Initialize database
    await dbHelper.database;
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('BackgroundScanLogStore', () {
    test('insertLog creates a new log entry and returns ID', () async {
      final entry = BackgroundScanLogEntry(
        accountId: 'test-account-001',
        scheduledTime: DateTime.now().millisecondsSinceEpoch,
        actualStartTime: DateTime.now().millisecondsSinceEpoch,
        status: 'success',
      );

      final logId = await logStore.insertLog(entry);

      expect(logId, greaterThan(0));
    });

    test('insertLog with all fields includes optional data', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = BackgroundScanLogEntry(
        accountId: 'test-account-002',
        scheduledTime: now,
        actualStartTime: now + 1000,
        actualEndTime: now + 5000,
        status: 'success',
        emailsProcessed: 150,
        unmatchedCount: 23,
      );

      await logStore.insertLog(entry);
      final retrieved = await logStore.getLatestLog('test-account-002');

      expect(retrieved, isNotNull);
      expect(retrieved!.emailsProcessed, 150);
      expect(retrieved.unmatchedCount, 23);
    });

    test('updateLog modifies existing entry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = BackgroundScanLogEntry(
        accountId: 'test-account-003',
        scheduledTime: now,
        actualStartTime: now,
        status: 'in_progress',
      );

      final logId = await logStore.insertLog(entry);

      final updated = BackgroundScanLogEntry(
        id: logId,
        accountId: 'test-account-003',
        scheduledTime: now,
        actualStartTime: now,
        actualEndTime: now + 10000,
        status: 'success',
        emailsProcessed: 50,
        unmatchedCount: 5,
        errorMessage: null,
      );

      await logStore.updateLog(updated);
      final retrieved = await logStore.getLatestLog('test-account-003');

      expect(retrieved!.status, 'success');
      expect(retrieved.actualEndTime, now + 10000);
      expect(retrieved.emailsProcessed, 50);
    });

    test('getLatestLog returns null if no logs exist for account', () async {
      final result = await logStore.getLatestLog('nonexistent-account');
      expect(result, isNull);
    });

    test('getLatestLog returns most recent entry for account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final entry1 = BackgroundScanLogEntry(
        accountId: 'test-account-004',
        scheduledTime: now,
        actualStartTime: now,
        status: 'success',
      );

      final entry2 = BackgroundScanLogEntry(
        accountId: 'test-account-004',
        scheduledTime: now + 60000,
        actualStartTime: now + 60000,
        status: 'success',
      );

      await logStore.insertLog(entry1);
      await Future.delayed(Duration(milliseconds: 100));
      await logStore.insertLog(entry2);

      final latest = await logStore.getLatestLog('test-account-004');

      expect(latest, isNotNull);
      expect(latest!.scheduledTime, now + 60000);
    });

    test('getLogsForAccount returns all logs for specified account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'test-account-005',
        scheduledTime: now,
        actualStartTime: now,
        status: 'success',
      ));

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'test-account-005',
        scheduledTime: now + 60000,
        actualStartTime: now + 60000,
        status: 'failed',
      ));

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'other-account',
        scheduledTime: now,
        actualStartTime: now,
        status: 'success',
      ));

      final logs = await logStore.getLogsForAccount('test-account-005');

      expect(logs.length, 2);
      expect(logs.every((log) => log.accountId == 'test-account-005'), true);
    });

    test('getLogsForAccount returns empty list if no logs exist', () async {
      final logs = await logStore.getLogsForAccount('nonexistent-account');
      expect(logs, isEmpty);
    });

    test('getLogsByStatus returns logs filtered by status', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'test-account-006',
        scheduledTime: now,
        actualStartTime: now,
        status: 'success',
      ));

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'test-account-007',
        scheduledTime: now + 60000,
        actualStartTime: now + 60000,
        status: 'success',
      ));

      await logStore.insertLog(BackgroundScanLogEntry(
        accountId: 'test-account-008',
        scheduledTime: now + 120000,
        actualStartTime: now + 120000,
        status: 'failed',
      ));

      final successLogs = await logStore.getLogsByStatus('success');

      expect(successLogs.length, 2);
      expect(successLogs.every((log) => log.status == 'success'), true);
    });

    test('getLogsByStatus returns empty list if no logs match status', () async {
      final logs = await logStore.getLogsByStatus('never_existed_status');
      expect(logs, isEmpty);
    });

    test('cleanupOldLogs removes entries beyond retention limit', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create 5 logs for one account
      for (int i = 0; i < 5; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'test-account-cleanup',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      final logsBefore = await logStore.getLogsForAccount('test-account-cleanup');
      expect(logsBefore.length, 5);

      // Keep only 2 most recent
      await logStore.cleanupOldLogs(keepPerAccount: 2);

      final logsAfter = await logStore.getLogsForAccount('test-account-cleanup');
      expect(logsAfter.length, 2);
    });

    test('cleanupOldLogs preserves logs for different accounts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create logs for account 1
      for (int i = 0; i < 3; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'account-a',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      // Create logs for account 2
      for (int i = 0; i < 3; i++) {
        await logStore.insertLog(BackgroundScanLogEntry(
          accountId: 'account-b',
          scheduledTime: now + (i * 60000),
          actualStartTime: now + (i * 60000),
          status: 'success',
        ));
      }

      // Keep only 2 per account
      await logStore.cleanupOldLogs(keepPerAccount: 2);

      final logsA = await logStore.getLogsForAccount('account-a');
      final logsB = await logStore.getLogsForAccount('account-b');

      expect(logsA.length, 2);
      expect(logsB.length, 2);
    });

    test('BackgroundScanLogEntry.fromMap correctly deserializes data', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final data = {
        'id': 42,
        'account_id': 'test-account',
        'scheduled_time': now,
        'actual_start_time': now + 1000,
        'actual_end_time': now + 5000,
        'status': 'success',
        'error_message': null,
        'emails_processed': 100,
        'unmatched_count': 10,
      };

      final entry = BackgroundScanLogEntry.fromMap(data);

      expect(entry.id, 42);
      expect(entry.accountId, 'test-account');
      expect(entry.scheduledTime, now);
      expect(entry.actualStartTime, now + 1000);
      expect(entry.actualEndTime, now + 5000);
      expect(entry.status, 'success');
      expect(entry.errorMessage, isNull);
      expect(entry.emailsProcessed, 100);
      expect(entry.unmatchedCount, 10);
    });

    test('BackgroundScanLogEntry.toMap correctly serializes data', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = BackgroundScanLogEntry(
        id: 42,
        accountId: 'test-account',
        scheduledTime: now,
        actualStartTime: now + 1000,
        actualEndTime: now + 5000,
        status: 'success',
        errorMessage: 'Test error',
        emailsProcessed: 100,
        unmatchedCount: 10,
      );

      final map = entry.toMap();

      expect(map['account_id'], 'test-account');
      expect(map['scheduled_time'], now);
      expect(map['status'], 'success');
      expect(map['error_message'], 'Test error');
      expect(map['emails_processed'], 100);
    });
  });
}
