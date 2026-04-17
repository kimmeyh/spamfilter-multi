import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/default_rule_set_service.dart';
import '../../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseTestHelper testHelper;
  late DefaultRuleSetService service;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    service = DefaultRuleSetService(testHelper.dbHelper);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('DefaultRuleSetService', () {
    group('seedIfEmpty', () {
      test('skips seeding when rules already exist', () async {
        // Pre-populate with one rule
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'Existing rule',
          'enabled': 1,
          'is_local': 0,
          'execution_order': 1,
          'condition_type': 'OR',
          'action_delete': 0,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });

        final result = await service.seedIfEmpty();

        expect(result.rules, 0);
        expect(result.safeSenders, 0);

        // Verify only the original rule exists (no seeding occurred)
        final rules = await db.query('rules');
        expect(rules, hasLength(1));
        expect(rules[0]['name'], 'Existing rule');
      });

      test('skips seeding when safe senders already exist', () async {
        // Pre-populate with one safe sender (include all NOT NULL fields)
        final db = await testHelper.dbHelper.database;
        await db.insert('safe_senders', {
          'pattern': '^existing@test\\.com\$',
          'pattern_type': 'regex',
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });

        final result = await service.seedIfEmpty();

        expect(result.rules, 0);
        expect(result.safeSenders, 0);

        // Verify only the original safe sender exists
        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, hasLength(1));
        expect(safeSenders[0]['pattern'], '^existing@test\\.com\$');
      });

      test('skips seeding when both rules and safe senders exist', () async {
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'Existing rule',
          'enabled': 1,
          'is_local': 0,
          'execution_order': 1,
          'condition_type': 'OR',
          'action_delete': 0,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });
        await db.insert('safe_senders', {
          'pattern': '^existing@test\\.com\$',
          'pattern_type': 'regex',
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });

        final result = await service.seedIfEmpty();

        expect(result.rules, 0);
        expect(result.safeSenders, 0);
      });

      test('seeds rules and safe senders on empty database', () async {
        final result = await service.seedIfEmpty();

        expect(result.rules, 5);
        expect(result.safeSenders, greaterThan(0));

        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules, hasLength(5));

        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);
      });
    });

    group('resetToDefaults', () {
      test('seeds rules and safe senders from bundled YAML assets', () async {
        final result = await service.resetToDefaults();

        expect(result.rules, 5);
        expect(result.safeSenders, greaterThan(0));

        // Verify rules were inserted into the database
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules', orderBy: 'execution_order');
        expect(rules, hasLength(5));

        // Verify safe senders were inserted
        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);

        // Verify first rule structure
        final firstRule = rules[0];
        expect(firstRule['name'], isNotNull);
        expect(firstRule['enabled'], isIn([0, 1]));
        expect(firstRule['is_local'], isIn([0, 1]));
        expect(firstRule['execution_order'], isNotNull);
        expect(firstRule['condition_type'], isNotNull);
        expect(firstRule['created_by'], 'default');
        expect(firstRule['date_added'], isNotNull);
      });

      test('clears existing user rules before seeding defaults', () async {
        // Pre-populate with user data
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'User custom rule',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 99,
          'condition_type': 'AND',
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });
        await db.insert('safe_senders', {
          'pattern': '^user@custom\\.com\$',
          'pattern_type': 'regex',
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'user',
        });

        // Verify pre-populated data exists
        var rules = await db.query('rules');
        expect(rules, hasLength(1));
        expect(rules[0]['name'], 'User custom rule');

        // Reset to defaults
        final result = await service.resetToDefaults();

        expect(result.rules, 5);

        // Verify user rules were replaced by defaults
        rules = await db.query('rules');
        expect(rules, hasLength(5));
        // None of the rules should be the user's custom rule
        expect(
          rules.every((r) => r['name'] != 'User custom rule'),
          isTrue,
        );
        // All rules should be created_by 'default'
        expect(
          rules.every((r) => r['created_by'] == 'default'),
          isTrue,
        );

        // User safe sender was replaced by defaults
        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);
        // None should be the user's custom sender
        expect(
          safeSenders.every((s) => s['pattern'] != '^user@custom\\.com\$'),
          isTrue,
        );
      });

      test('verifies correct rule field mapping from YAML to database', () async {
        await service.resetToDefaults();

        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules', orderBy: 'execution_order');

        // Verify first rule has expected structure from the bundled YAML
        // The first rule is SpamAutoDeleteHeader with header conditions
        final rule1 = rules[0];
        expect(rule1['name'], 'SpamAutoDeleteHeader');
        expect(rule1['enabled'], 1); // True -> 1
        expect(rule1['is_local'], 1); // True -> 1
        expect(rule1['execution_order'], 1);
        expect(rule1['condition_type'], 'OR');

        // Should have header conditions (JSON array)
        expect(rule1['condition_header'], isNotNull);
        final headerPatterns = jsonDecode(rule1['condition_header'] as String);
        expect(headerPatterns, isList);
        expect(headerPatterns, isNotEmpty);

        // Should have delete action set
        expect(rule1['action_delete'], 1);

        // Optional exception fields should be null for this rule
        expect(rule1['exception_from'], isNull);

        // Metadata may be present if the bundled YAML includes it
        if (rule1['metadata'] != null) {
          final metadata = jsonDecode(rule1['metadata'] as String);
          expect(metadata, isA<Map>());
        }
      });

      test('can be called multiple times without duplicate rules', () async {
        // First reset
        var result = await service.resetToDefaults();
        expect(result.rules, 5);

        // Second reset should clear and re-seed (no duplicates)
        result = await service.resetToDefaults();
        expect(result.rules, 5);

        // Verify no duplicates
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules, hasLength(5));
      });

      test('works on already empty database', () async {
        final result = await service.resetToDefaults();

        expect(result.rules, 5);
        expect(result.safeSenders, greaterThan(0));

        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules, hasLength(5));
        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);
      });

      test('safe senders have correct pattern_type classification', () async {
        await service.resetToDefaults();

        final db = await testHelper.dbHelper.database;
        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);

        // All safe senders should have a non-null pattern_type
        for (final ss in safeSenders) {
          expect(ss['pattern_type'], isNotNull);
          expect(
            ss['pattern_type'],
            isIn(['exact_email', 'exact_domain', 'entire_domain']),
          );
        }
      });
    });

    group('ensureTldBlockRules (F53 Sprint 33 migration)', () {
      test('adds .cc and .ne patterns to existing SpamAutoDeleteHeader rule',
          () async {
        // Simulate an existing install that has the rule but is missing the
        // post-seed TLD patterns. We seed the real rule, then strip the
        // two patterns to mimic a pre-Sprint-33 database.
        await service.resetToDefaults();
        final db = await testHelper.dbHelper.database;

        // Strip .cc and .ne from the seeded rule to simulate pre-migration state
        final row = (await db.query('rules',
                columns: ['id', 'condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single;
        final ruleId = row['id'] as int;
        final headers =
            List<String>.from(jsonDecode(row['condition_header'] as String));
        headers.removeWhere((p) => p == r'@.*\.cc$' || p == r'@.*\.ne$');
        await db.update(
          'rules',
          {'condition_header': jsonEncode(headers)},
          where: 'id = ?',
          whereArgs: [ruleId],
        );

        // Verify preconditions: patterns are missing
        final pre = jsonDecode((await db.query('rules',
                columns: ['condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single['condition_header'] as String) as List;
        expect(pre.contains(r'@.*\.cc$'), isFalse);
        expect(pre.contains(r'@.*\.ne$'), isFalse);

        // Run migration
        final added = await service.ensureTldBlockRules();
        expect(added, 2);

        // Verify patterns are now present
        final post = jsonDecode((await db.query('rules',
                columns: ['condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single['condition_header'] as String) as List;
        expect(post.contains(r'@.*\.cc$'), isTrue);
        expect(post.contains(r'@.*\.ne$'), isTrue);
      });

      test('is idempotent when patterns already present', () async {
        await service.resetToDefaults();

        // Fresh seed already contains the patterns (rules.yaml has them)
        final first = await service.ensureTldBlockRules();
        expect(first, 0, reason: 'fresh seed already has the patterns');

        // Second call is also a no-op
        final second = await service.ensureTldBlockRules();
        expect(second, 0);
      });

      test('adds only the missing pattern when one is already present',
          () async {
        await service.resetToDefaults();
        final db = await testHelper.dbHelper.database;

        // Strip only .cc, leaving .ne in place
        final row = (await db.query('rules',
                columns: ['id', 'condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single;
        final ruleId = row['id'] as int;
        final headers =
            List<String>.from(jsonDecode(row['condition_header'] as String))
              ..remove(r'@.*\.cc$');
        await db.update(
          'rules',
          {'condition_header': jsonEncode(headers)},
          where: 'id = ?',
          whereArgs: [ruleId],
        );

        final added = await service.ensureTldBlockRules();
        expect(added, 1);

        final post = jsonDecode((await db.query('rules',
                columns: ['condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single['condition_header'] as String) as List;
        expect(post.contains(r'@.*\.cc$'), isTrue);
        expect(post.contains(r'@.*\.ne$'), isTrue);
      });

      test('returns 0 when target rule does not exist', () async {
        // Empty database; rule is missing entirely
        final added = await service.ensureTldBlockRules();
        expect(added, 0);
      });

      test('TLD pattern @.*\\.cc\$ matches target domains but not near-misses',
          () {
        final cc = RegExp(r'@.*\.cc$', caseSensitive: false);
        expect(cc.hasMatch('spam@example.cc'), isTrue);
        expect(cc.hasMatch('spam@sub.example.cc'), isTrue);
        expect(cc.hasMatch('spam@example.cca'), isFalse,
            reason: 'anchored \$ should reject .cca');
        expect(cc.hasMatch('spam@cc.com'), isFalse,
            reason: '.cc must be the TLD, not a label before .com');
        expect(cc.hasMatch('user@example.com'), isFalse);
      });

      test('TLD pattern @.*\\.ne\$ matches target domains but not near-misses',
          () {
        final ne = RegExp(r'@.*\.ne$', caseSensitive: false);
        expect(ne.hasMatch('spam@example.ne'), isTrue);
        expect(ne.hasMatch('spam@sub.example.ne'), isTrue);
        expect(ne.hasMatch('spam@example.net'), isFalse,
            reason: 'anchored \$ should reject .net');
        expect(ne.hasMatch('spam@ne.com'), isFalse,
            reason: '.ne must be the TLD, not a label before .com');
        expect(ne.hasMatch('user@example.com'), isFalse);
      });

      test('bundled rules.yaml already contains both .cc and .ne', () async {
        await service.resetToDefaults();
        final db = await testHelper.dbHelper.database;

        final headers = jsonDecode((await db.query('rules',
                columns: ['condition_header'],
                where: 'name = ?',
                whereArgs: ['SpamAutoDeleteHeader']))
            .single['condition_header'] as String) as List;

        expect(headers.contains(r'@.*\.cc$'), isTrue,
            reason: 'assets/rules/rules.yaml should include .cc');
        expect(headers.contains(r'@.*\.ne$'), isTrue,
            reason: 'assets/rules/rules.yaml should include .ne');
      });
    });

    group('seedIfEmpty and resetToDefaults interaction', () {
      test('seedIfEmpty skips after resetToDefaults has populated data', () async {
        // Reset seeds the database with rules
        final resetResult = await service.resetToDefaults();
        expect(resetResult.rules, 5);

        // seedIfEmpty should skip since rules exist
        final seedResult = await service.seedIfEmpty();
        expect(seedResult.rules, 0);
        expect(seedResult.safeSenders, 0);

        // Verify only 5 rules exist (no duplicates from attempted seed)
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules, hasLength(5));
      });
    });
  });
}
