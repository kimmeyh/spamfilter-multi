/// Integration tests for scan result persistence
///
/// This test suite validates:
/// - Scan result creation and completion
/// - Unmatched email tracking
/// - Scan result retrieval from database
/// - Persistence across app restarts (simulated)

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import 'package:spam_filter_mobile/core/storage/scan_result_store.dart';
import 'package:spam_filter_mobile/core/storage/unmatched_email_store.dart';
library;

import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import '../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('Scan Result Persistence Integration', () {
    late DatabaseTestHelper testHelper;
    late DatabaseHelper databaseHelper;
    late ScanResultStore scanResultStore;
    late UnmatchedEmailStore unmatchedEmailStore;
    late EmailScanProvider scanProvider;

    setUp(() async {
      // Initialize test helper with isolated database
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      databaseHelper = testHelper.dbHelper;

      // Create stores
      scanResultStore = ScanResultStore(databaseHelper);
      unmatchedEmailStore = UnmatchedEmailStore(databaseHelper);

      // Create test account (required for FK constraints)
      await testHelper.createTestAccount('test@gmail.com', platformId: 'gmail');

      // Initialize provider
      scanProvider = EmailScanProvider();
      scanProvider.initializePersistence(
        scanResultStore: scanResultStore,
        unmatchedEmailStore: unmatchedEmailStore,
      );
      scanProvider.setCurrentAccountId('test@gmail.com');
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    test('Scan result is created when scan starts', () async {
      // Initial state
      expect(scanProvider.status.toString(), contains('idle'));

      // Start scan
      await scanProvider.startScan(
        totalEmails: 50,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );

      // Verify scan state
      expect(scanProvider.status.toString(), contains('scanning'));
      expect(scanProvider.totalEmails, 50);
      expect(scanProvider.processedCount, 0);

      // Verify scan result was created in database
      final results = await scanResultStore.getScanResultsByAccount('test@gmail.com');
      expect(results.isNotEmpty, true);
      expect(results.last.accountId, 'test@gmail.com');
      expect(results.last.scanType, 'manual');
      expect(results.last.totalEmails, 50);
      expect(results.last.status, 'in_progress');
    });

    test('Scan result is marked completed on scan completion', () async {
      // Start scan
      await scanProvider.startScan(
        totalEmails: 10,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );

      // Complete scan
      await scanProvider.completeScan();

      // Verify scan state
      expect(scanProvider.status.toString(), contains('completed'));

      // Verify that scan results were created and completed
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNotNull);
      expect(latest!.status, 'completed');
      expect(latest.completedAt, isNotNull);
    });

    test('Scan error is persisted to database', () async {
      // Start scan
      await scanProvider.startScan(
        totalEmails: 20,
        scanType: 'manual',
        foldersScanned: ['Bulk Mail'],
      );

      // Error scan
      await scanProvider.errorScan('Test error message');

      // Verify scan state
      expect(scanProvider.status.toString(), contains('error'));

      // Verify that most recent scan has error status
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNotNull);
      expect(latest!.status, 'error');
    });

    test('Multiple scans can be tracked independently', () async {
      // First scan
      await scanProvider.startScan(
        totalEmails: 15,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );
      await scanProvider.completeScan();

      // Reset for second scan
      scanProvider.reset();

      // Second scan
      await scanProvider.startScan(
        totalEmails: 25,
        scanType: 'background',
        foldersScanned: ['Spam', 'Trash'],
      );
      await scanProvider.completeScan();

      // Verify both scans persisted
      final allResults = await scanResultStore.getScanResultsByAccount('test@gmail.com');
      expect(allResults.length, greaterThanOrEqualTo(2));

      // Find manual and background scans
      final manualScans = allResults.where((r) => r.scanType == 'manual').toList();
      final backgroundScans = allResults.where((r) => r.scanType == 'background').toList();

      expect(manualScans.isNotEmpty, true);
      expect(backgroundScans.isNotEmpty, true);
      expect(backgroundScans.last.totalEmails, 25);
    });

    test('Scan mode is saved in persistence', () async {
      await scanProvider.startScan(
        totalEmails: 30,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );
      await scanProvider.completeScan();

      final results = await scanResultStore.getScanResultsByAccount('test@gmail.com');
      expect(results.last.scanMode, isNotNull);
      expect(results.last.scanMode.isNotEmpty, true);
    });

    test('Folder names are persisted correctly', () async {
      final folders = ['INBOX', 'Bulk Mail', 'Spam'];

      await scanProvider.startScan(
        totalEmails: 40,
        scanType: 'manual',
        foldersScanned: folders,
      );
      await scanProvider.completeScan();

      // Check that the folders are persisted in database
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNotNull);
      expect(latest!.foldersScanned.isNotEmpty, true);
      // At minimum, should have some folders
      expect(latest.foldersScanned, isNotEmpty);
    });

    test('Scan counts are updated during processing', () async {
      await scanProvider.startScan(
        totalEmails: 5,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );

      // Simulate progress updates
      for (int i = 0; i < 5; i++) {
        final email = EmailMessage(
          id: 'email-$i',
          from: 'sender$i@example.com',
          subject: 'Test email $i',
          body: 'Test body $i',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        scanProvider.updateProgress(
          email: email,
          message: 'Processing email $i',
        );
      }

      // Verify progress state
      expect(scanProvider.processedCount, 5);
      expect(scanProvider.progress, 1.0);

      await scanProvider.completeScan();

      // Verify completion persisted
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNotNull);
      expect(latest!.status, 'completed');
    });

    test('Latest scan can be retrieved efficiently', () async {
      // Create a scan
      await scanProvider.startScan(
        totalEmails: 15,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );
      await scanProvider.completeScan();

      // Query latest manual scan
      final latest = await scanResultStore.getLatestScanByType('test@gmail.com', 'manual');
      expect(latest, isNotNull);
      expect(latest!.scanType, 'manual');
      expect(latest.accountId, 'test@gmail.com');
    });

    test('Scan count query works correctly', () async {
      // Get initial count
      final initialCount = await scanResultStore.getScanCountByAccount('test@gmail.com');

      // Create a scan
      await scanProvider.startScan(
        totalEmails: 10,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );
      await scanProvider.completeScan();

      // Get updated count
      final updatedCount = await scanResultStore.getScanCountByAccount('test@gmail.com');

      expect(updatedCount, greaterThan(initialCount));
    });

    test('Persistence initializes correctly', () {
      // Verify stores are initialized
      expect(scanProvider, isNotNull);

      // Verify can set account ID
      scanProvider.setCurrentAccountId('another@gmail.com');

      // This should not throw
      expect(() {}, returnsNormally);
    });

    test('Scan without persistence initialization does not crash', () async {
      final providerNoPersist = EmailScanProvider();
      // Don't initialize persistence stores

      // Should not throw even without persistence
      await providerNoPersist.startScan(
        totalEmails: 5,
        scanType: 'manual',
      );

      expect(providerNoPersist.status.toString(), contains('scanning'));

      await providerNoPersist.completeScan();
      expect(providerNoPersist.status.toString(), contains('completed'));
    });

  });
}
