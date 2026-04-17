import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/services/data_deletion_service.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

/// In-memory stand-in for SecureCredentialsStore so tests do not touch
/// the real OS keystore. Implements just the two methods DataDeletionService
/// actually calls.
class FakeCredentialsStore implements SecureCredentialsStore {
  final Set<String> accounts = <String>{};
  int deleteCalls = 0;
  int deleteAllCalls = 0;

  @override
  Future<void> deleteCredentials(String accountId) async {
    deleteCalls++;
    accounts.remove(accountId);
  }

  @override
  Future<void> deleteAllCredentials() async {
    deleteAllCalls++;
    accounts.clear();
  }

  // Unused methods -- throw so any accidental call is loud.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseTestHelper testHelper;
  late DataDeletionService service;
  late FakeCredentialsStore creds;

  const accountA = 'a@example.com';
  const accountB = 'b@example.com';

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(accountA, platformId: 'aol');
    await testHelper.createTestAccount(accountB, platformId: 'aol');
    creds = FakeCredentialsStore();
    creds.accounts.addAll({accountA, accountB});
    service = DataDeletionService(
      dbHelper: testHelper.dbHelper,
      credStore: creds,
    );
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  Future<int> insertScanForAccount(String accountId) async {
    final store = ScanResultStore(testHelper.dbHelper);
    return store.addScanResult(
      ScanResult(
        accountId: accountId,
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: DateTime.now().millisecondsSinceEpoch,
        totalEmails: 10,
      ),
    );
  }

  Future<void> insertUnmatchedForScan(int scanId) async {
    final store = UnmatchedEmailStore(testHelper.dbHelper);
    await store.addUnmatchedEmail(
      UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'gmail_message_id',
        providerIdentifierValue: 'abc',
        fromEmail: 'spammer@example.com',
        folderName: 'INBOX',
        createdAt: DateTime.now(),
      ),
    );
  }

  group('deleteAccountData', () {
    test('removes scan results and unmatched emails for the target account only',
        () async {
      final scanA = await insertScanForAccount(accountA);
      final scanB = await insertScanForAccount(accountB);
      await insertUnmatchedForScan(scanA);
      await insertUnmatchedForScan(scanB);

      final report = await service.deleteAccountData(accountA);

      expect(report.scanResultsDeleted, 1);
      expect(report.unmatchedEmailsDeleted, 1);
      expect(report.credentialsDeleted, isTrue);

      final scanStore = ScanResultStore(testHelper.dbHelper);
      final remainingScans = await scanStore.getScanResultsByAccount(accountB);
      expect(remainingScans, hasLength(1));
      expect(remainingScans.first.id, scanB);
    });

    test('removes per-account settings but preserves app-wide settings',
        () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await settings.setManualScanDaysBack(14); // app-wide
      await settings.setAccountManualDaysBack(accountA, 7);
      await settings.setAccountManualDaysBack(accountB, 21);

      await service.deleteAccountData(accountA);

      expect(await settings.getManualScanDaysBack(), 14);
      expect(await settings.getAccountManualDaysBack(accountA), isNull);
      expect(await settings.getAccountManualDaysBack(accountB), 21);
    });

    test('deletes credentials for the target account only', () async {
      await service.deleteAccountData(accountA);
      expect(creds.deleteCalls, 1);
      expect(creds.accounts.contains(accountA), isFalse);
      expect(creds.accounts.contains(accountB), isTrue);
    });

    test('is safe when the account has no scan history', () async {
      // accountA has never scanned; no scan_results / unmatched_emails rows
      final report = await service.deleteAccountData(accountA);
      expect(report.scanResultsDeleted, 0);
      expect(report.unmatchedEmailsDeleted, 0);
      expect(report.credentialsDeleted, isTrue);
    });
  });

  group('wipeAllData', () {
    test('clears every table and deletes all credentials', () async {
      // Seed data across multiple tables
      final scanA = await insertScanForAccount(accountA);
      await insertUnmatchedForScan(scanA);
      final settings = SettingsStore(testHelper.dbHelper);
      await settings.setManualScanDaysBack(30);
      await settings.setAccountManualDaysBack(accountA, 7);

      await service.wipeAllData();

      final scanStore = ScanResultStore(testHelper.dbHelper);
      expect(await scanStore.getScanResultsByAccount(accountA), isEmpty);
      expect(await settings.getManualScanDaysBack(),
          SettingsStore.defaultManualScanDaysBack);
      expect(await settings.getAccountManualDaysBack(accountA), isNull);
      expect(creds.deleteAllCalls, 1);
      expect(creds.accounts, isEmpty);
    });
  });
}
