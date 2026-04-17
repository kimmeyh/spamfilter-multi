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

    group('ensureTldBlockRules (F53/F73 individual-row migration)', () {
      test('adds .cc and .ne as individual rows on empty database', () async {
        // Empty database -- no monolithic rule, no individual rows.
        // ensureTldBlockRules should insert 2 individual TLD rows.
        final added = await service.ensureTldBlockRules();
        expect(added, 2);

        final db = await testHelper.dbHelper.database;

        // Verify .cc individual row exists
        final ccRows = await db.query('rules',
            where: 'pattern_category = ? AND pattern_sub_type = ? '
                "AND condition_header LIKE ?",
            whereArgs: ['header_from', 'top_level_domain', '%\\.cc\$%']);
        expect(ccRows, hasLength(1));
        expect(ccRows.first['execution_order'], 10);
        expect(ccRows.first['action_delete'], 1);
        expect(ccRows.first['created_by'], 'migration_f53');

        // Verify .ne individual row exists
        final neRows = await db.query('rules',
            where: 'pattern_category = ? AND pattern_sub_type = ? '
                "AND condition_header LIKE ?",
            whereArgs: ['header_from', 'top_level_domain', '%\\.ne\$%']);
        expect(neRows, hasLength(1));
      });

      test('is idempotent when individual TLD rows already present', () async {
        // First call inserts them
        final first = await service.ensureTldBlockRules();
        expect(first, 2);

        // Second call is a no-op
        final second = await service.ensureTldBlockRules();
        expect(second, 0, reason: 'individual rows already present');

        // Third call is still a no-op
        final third = await service.ensureTldBlockRules();
        expect(third, 0);
      });

      test('adds only the missing pattern when one already exists', () async {
        final db = await testHelper.dbHelper.database;

        // Manually insert .ne as an individual row
        await db.insert('rules', {
          'name': '.*..ne',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 10,
          'condition_type': 'OR',
          'condition_header': jsonEncode([r'@.*\.ne$']),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'test',
          'pattern_category': 'header_from',
          'pattern_sub_type': 'top_level_domain',
          'source_domain': '.*..ne',
        });

        // Should add only .cc (not .ne)
        final added = await service.ensureTldBlockRules();
        expect(added, 1);

        // Verify both exist
        final tldRows = await db.query('rules',
            where: 'pattern_category = ? AND pattern_sub_type = ?',
            whereArgs: ['header_from', 'top_level_domain']);
        expect(tldRows.length, greaterThanOrEqualTo(2));
      });

      test('detects patterns in legacy monolithic SpamAutoDeleteHeader',
          () async {
        // Simulate a pre-split database with the monolithic row
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'SpamAutoDeleteHeader',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 1,
          'condition_type': 'OR',
          'condition_header': jsonEncode([r'@.*\.cc$', r'@.*\.ne$']),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
        });

        // Should detect both patterns in the monolithic row and skip
        final added = await service.ensureTldBlockRules();
        expect(added, 0,
            reason: 'patterns exist in monolithic row -- backwards compat');
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

        // After seeding from bundled YAML, the .cc and .ne patterns should
        // exist either as individual rows (new YAML format) or inside the
        // monolithic SpamAutoDeleteHeader (old YAML format). Check both.
        final ccIndividual = await db.query('rules',
            where: "condition_header LIKE ?",
            whereArgs: ['%\\.cc\$%']);
        final neIndividual = await db.query('rules',
            where: "condition_header LIKE ?",
            whereArgs: ['%\\.ne\$%']);

        expect(ccIndividual.isNotEmpty, isTrue,
            reason: 'assets/rules/rules.yaml should include .cc pattern');
        expect(neIndividual.isNotEmpty, isTrue,
            reason: 'assets/rules/rules.yaml should include .ne pattern');
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
