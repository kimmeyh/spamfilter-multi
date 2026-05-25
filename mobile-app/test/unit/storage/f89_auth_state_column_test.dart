/// F89 (Sprint 39) Phase 2 test: the v6 migration adds the nullable
/// created_with_auth_state column to BOTH the rules and safe_senders tables,
/// and the stores round-trip the value (and tolerate null).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('F89 -- created_with_auth_state column on a fresh v6 database', () {
    test('rules table has created_with_auth_state column', () async {
      final db = await testHelper.dbHelper.database;
      final info = await db.rawQuery('PRAGMA table_info(rules)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns, contains('created_with_auth_state'));
    });

    test('safe_senders table has created_with_auth_state column', () async {
      final db = await testHelper.dbHelper.database;
      final info = await db.rawQuery('PRAGMA table_info(safe_senders)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns, contains('created_with_auth_state'));
    });
  });

  group('F89 -- safe sender auth-state round-trip', () {
    test('persists and reads back a RED auth snapshot', () async {
      final store = SafeSenderDatabaseStore(testHelper.dbHelper);
      await store.addSafeSender(SafeSenderPattern(
        pattern: r'^[^@\s]+@example\.com$',
        patternType: 'domain',
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'quick_add',
        createdWithAuthState: 'red',
      ));

      final loaded = await store.getSafeSender(r'^[^@\s]+@example\.com$');
      expect(loaded, isNotNull);
      expect(loaded!.createdWithAuthState, 'red');
    });

    test('stores null when auth state was not supplied', () async {
      final store = SafeSenderDatabaseStore(testHelper.dbHelper);
      await store.addSafeSender(SafeSenderPattern(
        pattern: r'^[^@\s]+@nostate\.com$',
        patternType: 'domain',
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      ));

      final loaded = await store.getSafeSender(r'^[^@\s]+@nostate\.com$');
      expect(loaded, isNotNull);
      expect(loaded!.createdWithAuthState, isNull);
    });
  });

  group('F89 -- rule auth-state round-trip via metadata', () {
    test('persists auth state from rule.metadata into the column', () async {
      final store = RuleDatabaseStore(testHelper.dbHelper);
      await store.addRule(Rule(
        name: 'BlockGreenSender',
        enabled: true,
        isLocal: true,
        executionOrder: 10,
        conditions: RuleConditions(
          type: 'OR',
          from: [r'@spammer\.com$'],
          header: const [],
          subject: const [],
          body: const [],
        ),
        actions: RuleActions(delete: true),
        metadata: const {'created_with_auth_state': 'green'},
      ));

      // Read the raw column directly to confirm persistence.
      final db = await testHelper.dbHelper.database;
      final rows = await db.query(
        'rules',
        columns: ['created_with_auth_state'],
        where: 'name = ?',
        whereArgs: ['BlockGreenSender'],
      );
      expect(rows, isNotEmpty);
      expect(rows.first['created_with_auth_state'], 'green');
    });
  });
}
