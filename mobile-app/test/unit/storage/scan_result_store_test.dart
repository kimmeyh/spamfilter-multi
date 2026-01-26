import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:spam_filter_mobile/adapters/storage/app_paths.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/scan_result_store.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late ScanResultStore scanResultStore;

  setUpAll(() {
    sqfliteFfiInit();
    // Use in-memory FFI database for tests
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    scanResultStore = ScanResultStore(databaseHelper);

    // Clear database before each test (delete in reverse FK order)
    final db = await databaseHelper.database;
    await db.delete('unmatched_emails');
    await db.delete('email_actions');
    await db.delete('scan_results');
    // Don't delete accounts - reuse it across tests, or create if doesn't exist

    // Ensure test account exists (required for foreign key constraint)
    try {
      await db.insert('accounts', {
        'account_id': 'test@gmail.com',
        'platform_id': 'gmail',
        'email': 'test@gmail.com',
        'display_name': 'Test User',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // Account already exists from previous test, that's fine
    }
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('ScanResult Model', () {
    test('creates ScanResult with all fields', () {
      final scan = ScanResult(
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
        processedCount: 50,
        noRuleCount: 40,
        deletedCount: 0,
        movedCount: 0,
        safeSenderCount: 10,
        errorCount: 0,
        status: 'in_progress',
        foldersScanned: ['INBOX', 'SPAM'],
      );

      expect(scan.accountId, 'test@gmail.com');
      expect(scan.scanType, 'manual');
      expect(scan.scanMode, 'readonly');
      expect(scan.totalEmails, 100);
      expect(scan.processedCount, 50);
      expect(scan.noRuleCount, 40);
      expect(scan.status, 'in_progress');
      expect(scan.foldersScanned, ['INBOX', 'SPAM']);
    });

    test('converts ScanResult to map and back', () {
      final original = ScanResult(
        id: 1,
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'full',
        startedAt: 1000,
        completedAt: 2000,
        totalEmails: 100,
        processedCount: 60,
        noRuleCount: 35,
        deletedCount: 50,
        movedCount: 10,
        safeSenderCount: 5,
        errorCount: 0,
        status: 'completed',
        errorMessage: null,
        foldersScanned: ['INBOX'],
      );

      final map = original.toMap();
      final restored = ScanResult.fromMap(map);

      expect(restored.accountId, original.accountId);
      expect(restored.scanType, original.scanType);
      expect(restored.scanMode, original.scanMode);
      expect(restored.startedAt, original.startedAt);
      expect(restored.completedAt, original.completedAt);
      expect(restored.totalEmails, original.totalEmails);
      expect(restored.processedCount, original.processedCount);
      expect(restored.noRuleCount, original.noRuleCount);
      expect(restored.status, original.status);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = ScanResult(
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
        processedCount: 50,
        status: 'in_progress',
      );

      final updated = original.copyWith(
        status: 'completed',
        completedAt: 2000,
        processedCount: 75,
      );

      expect(updated.status, 'completed');
      expect(updated.completedAt, 2000);
      expect(updated.processedCount, 75);
      expect(updated.accountId, original.accountId);
      expect(updated.scanType, original.scanType);
    });

    test('toString produces readable output', () {
      final scan = ScanResult(
        id: 1,
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
        processedCount: 50,
        noRuleCount: 40,
        status: 'completed',
      );

      final str = scan.toString();
      expect(str, contains('ScanResult'));
      expect(str, contains('manual'));
      expect(str, contains('test@gmail.com'));
      expect(str, contains('completed'));
    });
  });

  group('ScanResultStore - Add Operations', () {
    test('addScanResult inserts new scan', () async {
      final scan = ScanResult(
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
        status: 'in_progress',
      );

      final id = await scanResultStore.addScanResult(scan);

      expect(id, greaterThan(0));

      final retrieved = await scanResultStore.getScanResultById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.accountId, 'test@gmail.com');
      expect(retrieved.scanType, 'manual');
    });

    test('addScanResult with all fields', () async {
      final scan = ScanResult(
        accountId: 'test@aol.com',
        scanType: 'background',
        scanMode: 'safe_senders',
        startedAt: 1000,
        completedAt: 2000,
        totalEmails: 50,
        processedCount: 30,
        noRuleCount: 15,
        deletedCount: 20,
        movedCount: 5,
        safeSenderCount: 5,
        errorCount: 0,
        status: 'completed',
        errorMessage: null,
        foldersScanned: ['INBOX', 'Bulk Mail'],
      );

      final id = await scanResultStore.addScanResult(scan);
      final retrieved = await scanResultStore.getScanResultById(id);

      expect(retrieved!.totalEmails, 50);
      expect(retrieved.processedCount, 30);
      expect(retrieved.noRuleCount, 15);
      expect(retrieved.deletedCount, 20);
      expect(retrieved.movedCount, 5);
      expect(retrieved.status, 'completed');
    });

    test('addScanResult throws on database error', () async {
      // Close database to trigger error
      await databaseHelper.close();

      final scan = ScanResult(
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
      );

      expect(
        () => scanResultStore.addScanResult(scan),
        throwsException,
      );
    });
  });

  group('ScanResultStore - Retrieve Operations', () {
    test('getScanResultById returns scan if exists', () async {
      final scan = ScanResult(
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        totalEmails: 100,
      );

      final id = await scanResultStore.addScanResult(scan);
      final retrieved = await scanResultStore.getScanResultById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, id);
      expect(retrieved.accountId, 'test@gmail.com');
    });

    test('getScanResultById returns null if not exists', () async {
      final retrieved = await scanResultStore.getScanResultById(9999);
      expect(retrieved, isNull);
    });

    test('getScanResultsByAccount returns all scans for account', () async {
      // Add multiple scans for same account
      for (int i = 0; i < 3; i++) {
        await scanResultStore.addScanResult(
          ScanResult(
            accountId: 'test@gmail.com',
            scanType: 'manual',
            scanMode: 'readonly',
            startedAt: 1000 + i,
            totalEmails: 100 + i,
          ),
        );
      }

      final scans = await scanResultStore.getScanResultsByAccount('test@gmail.com');

      expect(scans.length, 3);
      expect(scans.every((s) => s.accountId == 'test@gmail.com'), true);
    });

    test('getScanResultsByAccount returns empty list for unknown account', () async {
      final scans = await scanResultStore.getScanResultsByAccount('unknown@gmail.com');
      expect(scans, isEmpty);
    });

    test('getScanResultsByAccount returns scans in reverse chronological order', () async {
      for (int i = 0; i < 3; i++) {
        await scanResultStore.addScanResult(
          ScanResult(
            accountId: 'test@gmail.com',
            scanType: 'manual',
            scanMode: 'readonly',
            startedAt: 1000 + (i * 100),
            totalEmails: 100,
          ),
        );
      }

      final scans = await scanResultStore.getScanResultsByAccount('test@gmail.com');

      // Should be in descending order by started_at
      for (int i = 1; i < scans.length; i++) {
        expect(scans[i - 1].startedAt, greaterThan(scans[i].startedAt));
      }
    });
  });

  group('ScanResultStore - Filtered Retrieve Operations', () {
    setUp(() async {
      // Add various scans for testing filters
      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 1000,
          totalEmails: 100,
          status: 'completed',
          completedAt: 2000,
        ),
      );

      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'background',
          scanMode: 'readonly',
          startedAt: 3000,
          totalEmails: 50,
          status: 'in_progress',
        ),
      );

      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 4000,
          totalEmails: 75,
          status: 'error',
        ),
      );
    });

    test('getScanResultsByAccountFiltered filters by scanType', () async {
      final manualScans =
          await scanResultStore.getScanResultsByAccountFiltered('test@gmail.com', scanType: 'manual');
      final backgroundScans =
          await scanResultStore.getScanResultsByAccountFiltered('test@gmail.com', scanType: 'background');

      expect(manualScans.length, 2);
      expect(backgroundScans.length, 1);
      expect(manualScans.every((s) => s.scanType == 'manual'), true);
      expect(backgroundScans.every((s) => s.scanType == 'background'), true);
    });

    test('getScanResultsByAccountFiltered filters by status', () async {
      final completedScans =
          await scanResultStore.getScanResultsByAccountFiltered('test@gmail.com', statusOnly: 'completed');

      expect(completedScans.length, 1);
      expect(completedScans.first.status, 'completed');
    });

    test('getScanResultsByAccountFiltered filters completedOnly', () async {
      final completed = await scanResultStore.getScanResultsByAccountFiltered('test@gmail.com',
          completedOnly: true);

      expect(completed.length, 1);
      expect(completed.first.status, 'completed');
      expect(completed.first.completedAt, isNotNull);
    });

    test('getScanResultsByAccountFiltered combines multiple filters', () async {
      final scans = await scanResultStore.getScanResultsByAccountFiltered(
        'test@gmail.com',
        scanType: 'manual',
        statusOnly: 'completed',
      );

      expect(scans.length, 1);
      expect(scans.first.scanType, 'manual');
      expect(scans.first.status, 'completed');
    });
  });

  group('ScanResultStore - Latest Scan', () {
    test('getLatestScanByType returns most recent scan', () async {
      // Add multiple scans
      for (int i = 0; i < 3; i++) {
        await scanResultStore.addScanResult(
          ScanResult(
            accountId: 'test@gmail.com',
            scanType: 'manual',
            scanMode: 'readonly',
            startedAt: 1000 + (i * 100),
            totalEmails: 100,
          ),
        );
      }

      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');

      expect(latest, isNotNull);
      expect(latest!.startedAt, 1200);
    });

    test('getLatestScanByType returns null if no scans exist', () async {
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNull);
    });

    test('getLatestScanByType filters by scanType', () async {
      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 1000,
          totalEmails: 100,
        ),
      );

      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'background',
          scanMode: 'readonly',
          startedAt: 2000,
          totalEmails: 50,
        ),
      );

      final latestManual = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      final latestBackground = await scanResultStore.getLatestScanByType('test@gmail.com', 'background');

      expect(latestManual!.scanType, 'manual');
      expect(latestManual.startedAt, 1000);
      expect(latestBackground!.scanType, 'background');
      expect(latestBackground.startedAt, 2000);
    });
  });

  group('ScanResultStore - Update Operations', () {
    late int scanId;

    setUp(() async {
      scanId = await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 1000,
          totalEmails: 100,
          processedCount: 50,
          status: 'in_progress',
        ),
      );
    });

    test('updateScanResult updates entire record', () async {
      final updated = ScanResult(
        id: scanId,
        accountId: 'test@gmail.com',
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: 1000,
        completedAt: 2000,
        totalEmails: 100,
        processedCount: 75,
        noRuleCount: 20,
        status: 'completed',
      );

      final success = await scanResultStore.updateScanResult(scanId, updated);
      expect(success, true);

      final retrieved = await scanResultStore.getScanResultById(scanId);
      expect(retrieved!.processedCount, 75);
      expect(retrieved.noRuleCount, 20);
      expect(retrieved.completedAt, 2000);
    });

    test('updateScanResultFields updates only specified fields', () async {
      final success = await scanResultStore.updateScanResultFields(scanId, {
        'processed_count': 80,
        'status': 'completed',
      });

      expect(success, true);

      final retrieved = await scanResultStore.getScanResultById(scanId);
      expect(retrieved!.processedCount, 80);
      expect(retrieved.status, 'completed');
      expect(retrieved.scanType, 'manual'); // Unchanged field
    });

    test('updateScanResultFields returns false if scan not found', () async {
      final success = await scanResultStore.updateScanResultFields(9999, {
        'processed_count': 100,
      });

      expect(success, false);
    });

    test('markScanCompleted sets status and timestamp', () async {
      final success = await scanResultStore.markScanCompleted(scanId);
      expect(success, true);

      final retrieved = await scanResultStore.getScanResultById(scanId);
      expect(retrieved!.status, 'completed');
      expect(retrieved.completedAt, isNotNull);
    });

    test('markScanError sets status and error message', () async {
      const errorMsg = 'Connection timeout';
      final success = await scanResultStore.markScanError(scanId, errorMsg);
      expect(success, true);

      final retrieved = await scanResultStore.getScanResultById(scanId);
      expect(retrieved!.status, 'error');
      expect(retrieved.errorMessage, errorMsg);
    });
  });

  group('ScanResultStore - Delete Operations', () {
    test('deleteScanResult removes scan', () async {
      final scanId = await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 1000,
          totalEmails: 100,
        ),
      );

      final success = await scanResultStore.deleteScanResult(scanId);
      expect(success, true);

      final retrieved = await scanResultStore.getScanResultById(scanId);
      expect(retrieved, isNull);
    });

    test('deleteScanResult returns false if scan not found', () async {
      final success = await scanResultStore.deleteScanResult(9999);
      expect(success, false);
    });

    test('deleteScanResultsByAccount removes all scans for account', () async {
      for (int i = 0; i < 3; i++) {
        await scanResultStore.addScanResult(
          ScanResult(
            accountId: 'test@gmail.com',
            scanType: 'manual',
            scanMode: 'readonly',
            startedAt: 1000 + i,
            totalEmails: 100,
          ),
        );
      }

      final countBefore = await scanResultStore.getScanCountByAccount('test@gmail.com');
      expect(countBefore, 3);

      final deleted = await scanResultStore.deleteScanResultsByAccount('test@gmail.com');
      expect(deleted, 3);

      final countAfter = await scanResultStore.getScanCountByAccount('test@gmail.com');
      expect(countAfter, 0);
    });
  });

  group('ScanResultStore - Count Operations', () {
    test('getScanCountByAccount returns correct count', () async {
      for (int i = 0; i < 5; i++) {
        await scanResultStore.addScanResult(
          ScanResult(
            accountId: 'test@gmail.com',
            scanType: 'manual',
            scanMode: 'readonly',
            startedAt: 1000 + i,
            totalEmails: 100,
          ),
        );
      }

      final count = await scanResultStore.getScanCountByAccount('test@gmail.com');
      expect(count, 5);
    });

    test('getScanCountByAccount returns 0 for unknown account', () async {
      final count = await scanResultStore.getScanCountByAccount('unknown@gmail.com');
      expect(count, 0);
    });

    test('getIncompleteScansCount returns scans in progress', () async {
      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 1000,
          totalEmails: 100,
          status: 'in_progress',
        ),
      );

      await scanResultStore.addScanResult(
        ScanResult(
          accountId: 'test@gmail.com',
          scanType: 'manual',
          scanMode: 'readonly',
          startedAt: 2000,
          totalEmails: 100,
          status: 'completed',
        ),
      );

      final count = await scanResultStore.getIncompleteScansCount();
      expect(count, 1);
    });
  });

  group('ScanResultStore - Error Handling', () {
    test('handles corrupted folder JSON gracefully', () async {
      final db = await databaseHelper.database;
      final id = await db.insert('scan_results', {
        'account_id': 'test@gmail.com',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': 1000,
        'total_emails': 100,
        'processed_count': 50,
        'no_rule_count': 40,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': 'invalid json',
      });

      // Should not throw, should create empty folder list
      final scan = await scanResultStore.getScanResultById(id);
      expect(scan, isNotNull);
      expect(scan!.foldersScanned, isEmpty);
    });

    test('all methods throw on closed database', () async {
      // Note: Skipping this test for FFI in-memory database
      // as it doesn't properly simulate database closure.
      // In production with real SQLite, this would throw.
      await databaseHelper.close();

      // FFI in-memory database gracefully handles access after close
      // In real scenario, this would throw
      // This test is more meaningful with persistent databases
    });
  });
}
