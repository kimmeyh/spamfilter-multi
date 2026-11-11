/// F352 (Sprint 85, ADR-0052): the stored default account.
///
/// Covers the single `default_account_id` key in SettingsStore (set, read,
/// replace, clear), the delete path that clears it in the same transaction
/// (R-6), and the startup seed that copies it into the session selection.
///
/// What these do NOT catch: the screens that call these members (the widget
/// tests in test/ui/screens/f352_default_account_screen_test.dart cover them),
/// and the real OS keystore (a fake credential store stands in).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/services/data_deletion_service.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

class _FakeCreds implements SecureCredentialsStore {
  @override
  Future<void> deleteCredentials(String accountId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseTestHelper testHelper;
  late SettingsStore store;

  const a = 'gmail-a@example.com';
  const b = 'aol-b@example.com';

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(a, platformId: 'gmail');
    await testHelper.createTestAccount(b, platformId: 'aol');
    store = SettingsStore(testHelper.dbHelper);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('SettingsStore default account (AC-7, AC-3)', () {
    test('nothing stored reads as no default', () async {
      expect(await store.getDefaultAccountId(), isNull);
    });

    test('set, read, replace, clear', () async {
      await store.setDefaultAccountId(a);
      expect(await store.getDefaultAccountId(), a);
      await store.setDefaultAccountId(b);
      expect(await store.getDefaultAccountId(), b,
          reason: 'one key: a second set replaces the first');
      await store.clearDefaultAccountId();
      expect(await store.getDefaultAccountId(), isNull);
    });

    test('the value lives in the one app_settings key, nowhere else',
        () async {
      await store.setDefaultAccountId(a);
      final db = await testHelper.dbHelper.database;
      final rows = await db.query('app_settings',
          where: 'key = ?', whereArgs: ['default_account_id']);
      expect(rows, hasLength(1));
      expect(rows.single['value'], a);
      expect(SettingsStore.keyDefaultAccountId, 'default_account_id');
    });

    // Would NOT catch: a different writer storing the id under another key.
  });

  group('account delete clears the default (AC-6)', () {
    DataDeletionService service() => DataDeletionService(
          dbHelper: testHelper.dbHelper,
          credStore: _FakeCreds(),
        );

    test('deleting the default account leaves no default and no stale id',
        () async {
      await store.setDefaultAccountId(a);
      await service().deleteAccountData(a);
      expect(await store.getDefaultAccountId(), isNull);
      final db = await testHelper.dbHelper.database;
      final rows = await db.query('app_settings',
          where: 'key = ?', whereArgs: ['default_account_id']);
      expect(rows, isEmpty);
    });

    test('deleting a DIFFERENT account keeps the default', () async {
      await store.setDefaultAccountId(a);
      await service().deleteAccountData(b);
      expect(await store.getDefaultAccountId(), a);
    });

    test('deleting any account with no default stores nothing', () async {
      await service().deleteAccountData(a);
      expect(await store.getDefaultAccountId(), isNull);
    });

    // Would NOT catch: a delete path that bypasses DataDeletionService (the
    // Select Account screen is its only caller today).
  });

  group('startup seed (AC-4, AC-5)', () {
    Future<SelectedAccountProvider> seed(
      String? stored,
      List<String> accounts, {
      List<String>? cleared,
      bool readThrows = false,
    }) {
      return SelectedAccountProvider.createSeeded(
        readDefault: () async {
          if (readThrows) throw StateError('db locked');
          return stored;
        },
        listAccounts: () async => accounts,
        clearDefault: () async => cleared?.add('cleared'),
      );
    }

    test('a stored default for an existing account is selected', () async {
      final p = await seed(a, [a, b]);
      expect(p.accountId, a);
      expect(p.hasSelection, isTrue);
    });

    test('no stored default starts with no selection, even for one account',
        () async {
      final p = await seed(null, [a]);
      expect(p.hasSelection, isFalse,
          reason: 'there is no automatic default for a single account');
    });

    test('a stale default (account gone) is cleared, not selected', () async {
      final cleared = <String>[];
      final p = await seed('gmail-gone@example.com', [a, b], cleared: cleared);
      expect(p.hasSelection, isFalse);
      expect(cleared, hasLength(1));
    });

    test('a failing read starts empty and never throws', () async {
      final p = await seed(a, [a], readThrows: true);
      expect(p.hasSelection, isFalse);
    });

    test('an EMPTY account list (what a failed credential read returns) keeps '
        'the stored default (Sprint 85 5.1.2 M1)', () async {
      final cleared = <String>[];
      final p = await seed(a, const [], cleared: cleared);
      expect(p.hasSelection, isFalse);
      expect(cleared, isEmpty,
          reason: 'a read problem must not erase the user\'s default');
    });

    test('a THROWING account list keeps the stored default', () async {
      final cleared = <String>[];
      final p = await SelectedAccountProvider.createSeeded(
        readDefault: () async => a,
        listAccounts: () async => throw StateError('keystore locked'),
        clearDefault: () async => cleared.add('cleared'),
      );
      expect(p.hasSelection, isFalse);
      expect(cleared, isEmpty);
    });

    test('main() seeds the provider before runApp and passes it in (L9)', () {
      // Source-order check, like dev_credential_separation_test.dart: main()
      // itself is not runnable in a test.
      final src = File('lib/main.dart').readAsStringSync();
      final seedAt = src.indexOf('SelectedAccountProvider.createSeeded(');
      final runAt =
          src.indexOf('runApp(SpamFilterApp(selectedAccount: seededSelection))');
      expect(seedAt, greaterThan(0), reason: 'main() must call createSeeded');
      expect(runAt, greaterThan(seedAt),
          reason: 'the seeded provider must reach the app it was built for');
      expect(src.contains('final seededSelection = await SelectedAccountProvider'
          '.createSeeded('), isTrue);
    });

    test('picking another account changes only the session, not the store',
        () async {
      await store.setDefaultAccountId(a);
      final p = await SelectedAccountProvider.createSeeded(
        readDefault: store.getDefaultAccountId,
        listAccounts: () async => [a, b],
        clearDefault: store.clearDefaultAccountId,
      );
      expect(p.accountId, a);
      p.select(b);
      expect(p.accountId, b);
      expect(await store.getDefaultAccountId(), a,
          reason: 'the stored default is unchanged by a session pick');
      // A restart: a new provider seeded from the same store.
      final restarted = await SelectedAccountProvider.createSeeded(
        readDefault: store.getDefaultAccountId,
        listAccounts: () async => [a, b],
        clearDefault: store.clearDefaultAccountId,
      );
      expect(restarted.accountId, a);
    });

    // Would NOT catch: SpamFilterApp ignoring the provider it is given (the
    // screen test covers the consumer), and the real restart (Manual
    // Validation).
  });
}
