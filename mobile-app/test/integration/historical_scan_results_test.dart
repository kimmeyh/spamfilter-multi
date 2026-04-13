/// Integration tests for historical scan result loading
///
/// Validates that when viewing scan results from Scan History,
/// the correct scan's results are displayed -- not stale results
/// from a previous live scan for the same account.
///
/// Bug found: Sprint 31 manual testing. ResultsDisplayScreen
/// preferred stale EmailScanProvider results over the historically-
/// loaded results when historicalScanId was provided.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import '../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('Historical Scan Results - Correct Scan Loaded', () {
    late DatabaseTestHelper testHelper;
    late DatabaseHelper databaseHelper;
    late ScanResultStore scanResultStore;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      databaseHelper = testHelper.dbHelper;
      scanResultStore = ScanResultStore(databaseHelper);
      await testHelper.createTestAccount('aol-user@aol.com', platformId: 'aol');
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    test('getScanResultById returns the specific scan, not the latest', () async {
      // Create two scans for the same account: manual then background
      final manualScanId = await testHelper.createTestScanResult(
        'aol-user@aol.com',
        scanType: 'manual',
        totalEmails: 223,
      );

      final backgroundScanId = await testHelper.createTestScanResult(
        'aol-user@aol.com',
        scanType: 'background',
        totalEmails: 155,
      );

      // Verify they are different scans
      expect(manualScanId, isNot(equals(backgroundScanId)));

      // Load the background scan by ID (simulating Scan History tap)
      final backgroundScan = await scanResultStore.getScanResultById(backgroundScanId);
      expect(backgroundScan, isNotNull);
      expect(backgroundScan!.scanType, equals('background'));
      expect(backgroundScan.totalEmails, equals(155));

      // Load the manual scan by ID
      final manualScan = await scanResultStore.getScanResultById(manualScanId);
      expect(manualScan, isNotNull);
      expect(manualScan!.scanType, equals('manual'));
      expect(manualScan.totalEmails, equals(223));
    });

    test('getLatestCompletedScan returns the most recent, not a specific one', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create manual scan first (older timestamp)
      final manualScanId = await databaseHelper.insertScanResult({
        'account_id': 'aol-user@aol.com',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': now - 60000, // 1 minute ago
        'completed_at': now - 59000,
        'total_emails': 223,
        'processed_count': 223,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });

      // Create background scan second (newer timestamp)
      final backgroundScanId = await databaseHelper.insertScanResult({
        'account_id': 'aol-user@aol.com',
        'scan_type': 'background',
        'scan_mode': 'readonly',
        'started_at': now - 30000, // 30 seconds ago
        'completed_at': now - 29000,
        'total_emails': 155,
        'processed_count': 155,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });

      // getLatestCompletedScan should return the background scan (most recent)
      final latestScan = await scanResultStore.getLatestCompletedScan('aol-user@aol.com');
      expect(latestScan, isNotNull);
      expect(latestScan!.id, equals(backgroundScanId));
      expect(latestScan.scanType, equals('background'));

      // But getScanResultById with manual ID should still return the manual scan
      final specificScan = await scanResultStore.getScanResultById(manualScanId);
      expect(specificScan, isNotNull);
      expect(specificScan!.id, equals(manualScanId));
      expect(specificScan.scanType, equals('manual'));
    });

    test('email actions are loaded for the correct scan ID', () async {
      // Create two scans
      final manualScanId = await testHelper.createTestScanResult(
        'aol-user@aol.com',
        scanType: 'manual',
        totalEmails: 223,
      );
      final backgroundScanId = await testHelper.createTestScanResult(
        'aol-user@aol.com',
        scanType: 'background',
        totalEmails: 155,
      );

      // Insert email actions for the manual scan
      final now = DateTime.now().millisecondsSinceEpoch;
      await databaseHelper.insertEmailActionBatch([
        {
          'scan_result_id': manualScanId,
          'email_id': '1001',
          'email_from': 'spam@example.com',
          'email_subject': 'Manual scan email',
          'email_received_date': now,
          'email_folder': 'INBOX',
          'action_type': 'deleted',
          'matched_rule_name': 'Block_example_com',
          'matched_pattern': '@example\\.com\$',
          'is_safe_sender': 0,
          'success': 1,
        },
      ]);

      // Insert email actions for the background scan
      await databaseHelper.insertEmailActionBatch([
        {
          'scan_result_id': backgroundScanId,
          'email_id': '2001',
          'email_from': 'spam@other.com',
          'email_subject': 'Background scan email',
          'email_received_date': now,
          'email_folder': 'Bulk',
          'action_type': 'deleted',
          'matched_rule_name': 'Block_other_com',
          'matched_pattern': '@other\\.com\$',
          'is_safe_sender': 0,
          'success': 1,
        },
        {
          'scan_result_id': backgroundScanId,
          'email_id': '2002',
          'email_from': 'friend@safe.com',
          'email_subject': 'Background safe email',
          'email_received_date': now,
          'email_folder': 'Bulk',
          'action_type': 'none',
          'matched_rule_name': null,
          'matched_pattern': null,
          'is_safe_sender': 1,
          'success': 1,
        },
      ]);

      // Query actions for the background scan specifically
      final backgroundActions = await databaseHelper.queryEmailActions(
        scanResultId: backgroundScanId,
      );
      expect(backgroundActions.length, equals(2));
      expect(backgroundActions[0]['email_subject'], equals('Background scan email'));

      // Query actions for the manual scan specifically
      final manualActions = await databaseHelper.queryEmailActions(
        scanResultId: manualScanId,
      );
      expect(manualActions.length, equals(1));
      expect(manualActions[0]['email_subject'], equals('Manual scan email'));

      // Verify no cross-contamination: background scan does not contain manual results
      final backgroundSubjects = backgroundActions.map((a) => a['email_subject']).toList();
      expect(backgroundSubjects, isNot(contains('Manual scan email')));
    });
  });
}
