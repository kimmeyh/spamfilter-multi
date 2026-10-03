/// Sprint 74 Manual Validation (Harold, 2026-09-29): Manage Rules labeled
/// every subject rule "Subject - Exact Domain" and counted it under the
/// Header / From "Exact Domain" chip (46 shown, 14 real). All three
/// subject-rule creators stored pattern_sub_type 'exact_domain'. A subject
/// pattern is a phrase: 'keyword', like body phrase rules.
///
/// What these tests do NOT catch: a FOURTH creator of subject rules added
/// later with the old value (the three known ones are pinned below), and
/// Harold's real database -- the v10 migration runs on his next launch of
/// the rebuilt app.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  test('a subject rule from the quick action is stored as keyword', () async {
    final provider = RuleSetProvider()
      ..initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
    await provider.loadRules();
    await provider.loadSafeSenders();
    final r = await RuleQuickActionService(ruleProvider: provider)
        .createBlockRule(type: 'subject', value: 'Your next backup may fail');
    expect(r.success, isTrue);
    final db = await testHelper.dbHelper.database;
    final row = (await db.query('rules',
            where: 'pattern_category = ?', whereArgs: ['subject']))
        .single;
    expect(row['pattern_sub_type'], 'keyword');
  });

  test('the other two subject-rule creators use keyword too (source gate)',
      () {
    final quickAdd =
        File('lib/ui/screens/rule_quick_add_screen.dart').readAsStringSync();
    expect(
        RegExp(r"patternCategory = 'subject';\s*//[^\n]*\n\s*patternSubType = 'keyword';")
            .hasMatch(quickAdd),
        isTrue);
    final split =
        File('lib/core/services/default_rule_set_service.dart').readAsStringSync();
    expect(
        RegExp(r"category = 'subject';(\s*//[^\n]*\n)*\s*subType = 'keyword';")
            .hasMatch(split),
        isTrue);
  });

  test('the REAL v10 upgrade reclassifies subject rules and leaves header '
      'rules alone', () async {
    await testHelper.dbHelper.close();
    final dbFile = File(testHelper.testDbPath);
    if (await dbFile.exists()) await dbFile.delete();
    final v9 = await databaseFactoryFfi.openDatabase(
      testHelper.testDbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE rules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              pattern_category TEXT,
              pattern_sub_type TEXT
            );''');
          await db.insert('rules', {
            'name': 'subj', 'pattern_category': 'subject',
            'pattern_sub_type': 'exact_domain',
          });
          await db.insert('rules', {
            'name': 'hdr', 'pattern_category': 'header_from',
            'pattern_sub_type': 'exact_domain',
          });
          await db.insert('rules', {
            'name': 'body', 'pattern_category': 'body',
            'pattern_sub_type': 'keyword',
          });
        },
      ),
    );
    await v9.close();

    final upgraded = await testHelper.dbHelper.database;
    Future<String?> subTypeOf(String name) async => (await upgraded.query(
            'rules',
            where: 'name = ?', whereArgs: [name]))
        .single['pattern_sub_type'] as String?;
    expect(await subTypeOf('subj'), 'keyword');
    expect(await subTypeOf('hdr'), 'exact_domain',
        reason: 'header exact-domain rules really are exact-domain');
    expect(await subTypeOf('body'), 'keyword');
    expect(await upgraded.getVersion(), 10);
  });
}
