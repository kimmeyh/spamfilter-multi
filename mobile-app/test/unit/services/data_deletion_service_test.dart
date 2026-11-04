import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart'
    show ScanMode;
import 'package:my_email_spam_filter/core/security/auth_rate_limiter.dart';
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

    test('F324 (Q3 = 3): keeps the account\'s choices, deletes its sign-in '
        'state, and leaves app-wide settings and other accounts alone',
        () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await settings.setManualScanDaysBack(14); // app-wide
      await settings.setAccountManualDaysBack(accountA, 7);
      await settings.setAccountManualDaysBack(accountB, 21);
      await settings.setAccountBackgroundEnabled(accountA, true);
      await settings.setAccountBackgroundFrequency(accountA, 30);
      await settings.setAccountFolders(accountA, ['INBOX', 'Junk']);
      await settings.setAccountBackgroundScanMode(accountA, ScanMode.readOnly);
      await settings.setAccountNewMailTrigger(accountA, true);
      await settings.setAccountSafeSenderFolder(accountA, 'Safe');
      await settings.setAccountDeletedRuleFolder(accountA, 'Bin');
      await settings.setGmailSignInRequired(accountA, true);
      await settings.setGmailSignInNotifiedAt(accountA, DateTime(2026, 11, 1));
      await settings.getOrAllocateScheduleSlot(accountA);

      final report = await service.deleteAccountData(accountA);

      // KEEP: the user's choices survive.
      expect(await settings.getManualScanDaysBack(), 14);
      expect(await settings.getAccountManualDaysBack(accountA), 7);
      expect(await settings.getAccountBackgroundEnabled(accountA), isTrue);
      expect(await settings.getAccountBackgroundFrequency(accountA), 30);
      expect(await settings.getAccountFolders(accountA), ['INBOX', 'Junk']);
      expect(await settings.getAccountBackgroundScanMode(accountA),
          ScanMode.readOnly);
      expect(await settings.getAccountNewMailTrigger(accountA), isTrue);
      expect(await settings.getAccountSafeSenderFolder(accountA), 'Safe');
      expect(await settings.getAccountDeletedRuleFolder(accountA), 'Bin');
      expect(await settings.getAccountManualDaysBack(accountB), 21);
      // REFRESH: the old sign-in state does not survive.
      expect(await settings.getGmailSignInRequired(accountA), isFalse);
      expect(await settings.getGmailSignInNotifiedAt(accountA), isNull);
      final left = (await settings.getAccountOverrides(accountA)).keys.toSet();
      expect(left.difference(accountSettingKeysKept), isEmpty,
          reason: 'only classified KEEP keys may remain');
      expect(report.accountSettingsDeleted, 3);
      expect(report.accountSettingsKept, 8);
    });

    test('F324: scan positions, schedule rows and the lockout count are '
        'cleared on removal', () async {
      await testHelper.dbHelper.setGmailHistoryCursor(accountA, 'INBOX', '123');
      final db = await testHelper.dbHelper.database;
      await db.insert('background_scan_schedule', {
        'account_id': accountA,
        'folders': '[]',
      });
      await AuthRateLimiter(testHelper.dbHelper).recordFailure('aol-$accountA');
      await AuthRateLimiter(testHelper.dbHelper).recordFailure(accountA);

      await service.deleteAccountData(accountA);

      expect(
          await testHelper.dbHelper.getGmailHistoryCursor(accountA, 'INBOX'),
          isNull);
      expect(await db.query('background_scan_schedule'), isEmpty);
      // The adapter keys the lockout by 'platform-address'; the bare address
      // key is the older shape. Both go.
      expect(await db.query('auth_rate_limit'), isEmpty);
    });

    test('F324: the lockout count of ANOTHER account survives', () async {
      final db = await testHelper.dbHelper.database;
      await AuthRateLimiter(testHelper.dbHelper).recordFailure('aol-$accountB');
      await service.deleteAccountData(accountA);
      final rows = await db.query('auth_rate_limit');
      expect(rows.map((r) => r['account_id']), ['aol-$accountB']);
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

  group('refreshForReAdd (F324)', () {
    Future<void> seed(SettingsStore settings) async {
      await settings.setGmailSignInRequired(accountA, true);
      await settings.setGmailSignInNotifiedAt(accountA, DateTime(2026, 11, 1));
      await settings.setAccountBackgroundEnabled(accountA, true);
      await testHelper.dbHelper.setGmailHistoryCursor(accountA, 'INBOX', '99');
      await AuthRateLimiter(testHelper.dbHelper).recordFailure('icloud-$accountA');
    }

    test('a replaced account loses the old sign-in state and scan positions, '
        'and keeps the user\'s choices', () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await seed(settings);
      await service.refreshForReAdd(accountA, resetServerState: true);

      expect(await settings.getGmailSignInRequired(accountA), isFalse);
      expect(await settings.getGmailSignInNotifiedAt(accountA), isNull);
      expect(
          await testHelper.dbHelper.getGmailHistoryCursor(accountA, 'INBOX'),
          isNull);
      final db = await testHelper.dbHelper.database;
      expect(await db.query('auth_rate_limit'), isEmpty);
      expect(await settings.getAccountBackgroundEnabled(accountA), isTrue,
          reason: 'a user choice is not a re-add refresh');
    });

    test('a plain password repair keeps the scan positions', () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await seed(settings);
      await service.refreshForReAdd(accountA, resetServerState: false);

      expect(await settings.getGmailSignInRequired(accountA), isFalse);
      final db = await testHelper.dbHelper.database;
      expect(await db.query('auth_rate_limit'), isEmpty,
          reason: 'a new password must not start locked out');
      expect(
          await testHelper.dbHelper.getGmailHistoryCursor(accountA, 'INBOX'),
          '99');
    });

    test('another account is untouched', () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await settings.setGmailSignInRequired(accountB, true);
      await service.refreshForReAdd(accountA, resetServerState: true);
      expect(await settings.getGmailSignInRequired(accountB), isTrue);
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
