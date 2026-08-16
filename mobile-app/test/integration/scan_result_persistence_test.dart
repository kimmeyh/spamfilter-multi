/// Integration tests for scan result persistence
///
/// This test suite validates:
/// - Scan result creation and completion
/// - Unmatched email tracking
/// - Scan result retrieval from database
/// - Persistence across app restarts (simulated)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
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

    test(
        'F156/Sprint 60 REGRESSION: persistence works with NO pre-existing '
        'accounts row (the Android state that silently dropped every scan)',
        () async {
      // The exact production shape found on Android: the accounts table is
      // EMPTY (only the Windows background worker ever created the row), so
      // scan_results' FK failed on every interactive scan and persistence
      // silently no-op'd. The shared path now ensures the row itself.
      // NOTE: deliberately NO createTestAccount here -- every sibling test
      // pre-creates the row ("required for FK constraints" in the harness),
      // which is precisely why this class of failure never showed in tests.
      const freshAccountId = 'aol-fresh@aol.com';
      final freshProvider = EmailScanProvider();
      freshProvider.initializePersistence(
        scanResultStore: scanResultStore,
        unmatchedEmailStore: unmatchedEmailStore,
        databaseHelper: databaseHelper,
      );
      freshProvider.setCurrentAccountId(freshAccountId);

      await freshProvider.startScan(
        totalEmails: 5,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
        platformId: 'aol',
      );

      final results =
          await scanResultStore.getScanResultsByAccount(freshAccountId);
      expect(results.isNotEmpty, true,
          reason: 'the scan result MUST persist even when no accounts row '
              'pre-exists -- the shared path now creates it (previously only '
              'the Windows background worker did, so Android lost every '
              'scan: no history, no no-rule items)');

      final db = await databaseHelper.database;
      final account = await db.query('accounts',
          where: 'account_id = ?', whereArgs: [freshAccountId]);
      expect(account, hasLength(1),
          reason: 'the ensure step must have created the accounts row');
      expect(account.first['platform_id'], 'aol',
          reason: 'platform id comes from the EXPLICIT startScan platformId '
              '(PR #335 review: no accountId guess-parsing)');
      expect(account.first['email'], 'fresh@aol.com',
          reason: 'email recovered by stripping the known "aol-" prefix');
    });

    test(
        'ensured accounts row never guess-parses: a dash-containing plain '
        'email stays intact, and a platform prefix strips exactly (PR #335 '
        'Copilot finding)', () async {
      // Case 1: plain-email accountId containing a dash, no platform known.
      // The old dash-split would have produced platform "my", email
      // "name@gmail.com" -- corrupted. Now it stays whole.
      const dashEmailId = 'my-name@gmail.com';
      final p1 = EmailScanProvider();
      p1.initializePersistence(
        scanResultStore: scanResultStore,
        unmatchedEmailStore: unmatchedEmailStore,
        databaseHelper: databaseHelper,
      );
      p1.setCurrentAccountId(dashEmailId);
      await p1.startScan(
          totalEmails: 1, scanType: 'manual', foldersScanned: ['INBOX']);

      final db = await databaseHelper.database;
      var row = await db.query('accounts',
          where: 'account_id = ?', whereArgs: [dashEmailId]);
      expect(row, hasLength(1));
      expect(row.first['email'], dashEmailId,
          reason: 'a dash inside a plain email must NOT be split');
      expect(row.first['platform_id'], 'unknown',
          reason: 'no platform passed -> unknown, never a guessed fragment');

      // Case 2: platform-email form where the EMAIL ITSELF contains a dash.
      const prefixedId = 'aol-my-name@aol.com';
      final p2 = EmailScanProvider();
      p2.initializePersistence(
        scanResultStore: scanResultStore,
        unmatchedEmailStore: unmatchedEmailStore,
        databaseHelper: databaseHelper,
      );
      p2.setCurrentAccountId(prefixedId);
      await p2.startScan(
          totalEmails: 1,
          scanType: 'manual',
          foldersScanned: ['INBOX'],
          platformId: 'aol');

      row = await db.query('accounts',
          where: 'account_id = ?', whereArgs: [prefixedId]);
      expect(row, hasLength(1));
      expect(row.first['platform_id'], 'aol');
      expect(row.first['email'], 'my-name@aol.com',
          reason: 'only the known "aol-" prefix strips; the email keeps its '
              'own dash');
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

      // Simulate progress updates and record results
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
        // processedCount increments via recordResult, not updateProgress
        scanProvider.recordResult(EmailActionResult(
          email: email,
          action: EmailActionType.none,
          success: true,
        ));
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

    // F39 (Sprint 46) regression: unmatched_emails MUST be written at scan
    // completion. Manual validation found the table had NO production writer
    // (a Sprint 4 placeholder only logged "will persist in Task D"), so the
    // cross-account Review No Rule Items screen always showed 0 items
    // while scan_results.no_rule_count said otherwise.
    test('F39: "No rule" results persist to unmatched_emails at completion',
        () async {
      // Re-init WITH databaseHelper -- _persistEmailActions requires it and
      // it is an optional param the other tests omit.
      scanProvider.initializePersistence(
        scanResultStore: scanResultStore,
        unmatchedEmailStore: unmatchedEmailStore,
        databaseHelper: databaseHelper,
      );
      scanProvider.setCurrentAccountId('test@gmail.com');

      await scanProvider.startScan(
        totalEmails: 2,
        scanType: 'manual',
        foldersScanned: ['INBOX'],
      );

      EmailMessage msg(String id, String from) => EmailMessage(
            id: id,
            from: from,
            subject: 'Subject $id',
            body: 'Body',
            headers: const {},
            receivedDate: DateTime.now(),
            folderName: 'INBOX',
          );

      scanProvider.recordResult(EmailActionResult(
        email: msg('u1', 'norule@biz.example'),
        action: EmailActionType.none,
        success: true,
      ));
      scanProvider.recordResult(EmailActionResult(
        email: msg('u2', 'bad@spam.example'),
        action: EmailActionType.delete,
        success: true,
      ));

      await scanProvider.completeScan();

      final latest =
          await scanResultStore.getLatestCompletedScan('test@gmail.com');
      expect(latest, isNotNull);
      final rows = await unmatchedEmailStore.getUnmatchedEmailsByScanFiltered(
        latest!.id!,
        unprocessedOnly: true,
      );
      expect(rows, hasLength(1),
          reason: 'exactly the No-rule result (not the delete) must persist');
      expect(rows.first.fromEmail, 'norule@biz.example');
      expect(rows.first.processed, isFalse);
      expect(rows.first.providerIdentifierValue, 'u1');
    });
  });
}
