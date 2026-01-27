import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/account_store.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for desktop testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late AccountStore accountStore;

  setUp(() async {
    dbHelper = DatabaseHelper();
    accountStore = AccountStore(dbHelper);
    // Initialize database
    await dbHelper.database;
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('AccountStore', () {
    test('insertAccount creates new account and can be retrieved', () async {
      await accountStore.insertAccount(
        accountId: 'test-account-001',
        platformId: 'gmail',
        email: 'test@gmail.com',
        displayName: 'Test User',
      );

      final account = await accountStore.getAccount('test-account-001');

      expect(account, isNotNull);
      expect(account!['account_id'], 'test-account-001');
      expect(account['platform_id'], 'gmail');
      expect(account['email'], 'test@gmail.com');
      expect(account['display_name'], 'Test User');
    });

    test('insertAccount without displayName sets it to null', () async {
      await accountStore.insertAccount(
        accountId: 'test-account-002',
        platformId: 'aol',
        email: 'user@aol.com',
      );

      final account = await accountStore.getAccount('test-account-002');

      expect(account, isNotNull);
      expect(account!['display_name'], isNull);
    });

    test('getAccount returns null for non-existent account', () async {
      final account = await accountStore.getAccount('nonexistent');
      expect(account, isNull);
    });

    test('getAllAccounts returns all inserted accounts', () async {
      await accountStore.insertAccount(
        accountId: 'gmail-account',
        platformId: 'gmail',
        email: 'user1@gmail.com',
      );

      await accountStore.insertAccount(
        accountId: 'aol-account',
        platformId: 'aol',
        email: 'user2@aol.com',
      );

      await accountStore.insertAccount(
        accountId: 'yahoo-account',
        platformId: 'yahoo',
        email: 'user3@yahoo.com',
      );

      final accounts = await accountStore.getAllAccounts();

      expect(accounts.length, 3);
      expect(
        accounts.map((a) => a['account_id']).toList(),
        containsAll(['gmail-account', 'aol-account', 'yahoo-account']),
      );
    });

    test('getAllAccounts returns empty list when no accounts exist', () async {
      final accounts = await accountStore.getAllAccounts();
      expect(accounts, isEmpty);
    });

    test('deleteAccount removes account from database', () async {
      await accountStore.insertAccount(
        accountId: 'delete-test',
        platformId: 'gmail',
        email: 'delete@gmail.com',
      );

      var account = await accountStore.getAccount('delete-test');
      expect(account, isNotNull);

      await accountStore.deleteAccount('delete-test');

      account = await accountStore.getAccount('delete-test');
      expect(account, isNull);
    });

    test('deleteAccount does not affect other accounts', () async {
      await accountStore.insertAccount(
        accountId: 'keep-this-1',
        platformId: 'gmail',
        email: 'keep1@gmail.com',
      );

      await accountStore.insertAccount(
        accountId: 'delete-this',
        platformId: 'aol',
        email: 'delete@aol.com',
      );

      await accountStore.insertAccount(
        accountId: 'keep-this-2',
        platformId: 'yahoo',
        email: 'keep2@yahoo.com',
      );

      await accountStore.deleteAccount('delete-this');

      final accounts = await accountStore.getAllAccounts();

      expect(accounts.length, 2);
      expect(
        accounts.map((a) => a['account_id']).toList(),
        containsAll(['keep-this-1', 'keep-this-2']),
      );
      expect(
        accounts.map((a) => a['account_id']).toList(),
        isNot(contains('delete-this')),
      );
    });

    test('deleteAccount succeeds even if account does not exist', () async {
      // Should not throw
      await accountStore.deleteAccount('nonexistent-account');
    });

    test('insertAccount stores date_added timestamp', () async {
      final beforeInsert = DateTime.now().millisecondsSinceEpoch;
      
      await accountStore.insertAccount(
        accountId: 'timestamp-test',
        platformId: 'gmail',
        email: 'timestamp@gmail.com',
      );

      final afterInsert = DateTime.now().millisecondsSinceEpoch;
      final account = await accountStore.getAccount('timestamp-test');

      expect(account, isNotNull);
      expect(account!['date_added'], greaterThanOrEqualTo(beforeInsert));
      expect(account['date_added'], lessThanOrEqualTo(afterInsert + 1000));
    });

    test('multiple accounts with same email but different platforms', () async {
      final email = 'shared@example.com';

      await accountStore.insertAccount(
        accountId: 'gmail-shared',
        platformId: 'gmail',
        email: email,
      );

      await accountStore.insertAccount(
        accountId: 'aol-shared',
        platformId: 'aol',
        email: email,
      );

      final gmailAccount = await accountStore.getAccount('gmail-shared');
      final aolAccount = await accountStore.getAccount('aol-shared');

      expect(gmailAccount!['email'], email);
      expect(aolAccount!['email'], email);
      expect(gmailAccount['account_id'], 'gmail-shared');
      expect(aolAccount['account_id'], 'aol-shared');
    });

    test('getAllAccounts includes all account fields', () async {
      await accountStore.insertAccount(
        accountId: 'full-test',
        platformId: 'gmail',
        email: 'full@test.com',
        displayName: 'Full Test Account',
      );

      final accounts = await accountStore.getAllAccounts();
      final account = accounts.firstWhere((a) => a['account_id'] == 'full-test');

      expect(account.keys, containsAll([
        'account_id',
        'platform_id',
        'email',
        'display_name',
        'date_added',
      ]));
    });
  });
}
