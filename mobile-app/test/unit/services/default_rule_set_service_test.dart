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
    group('splitMonolithicRules F121 idempotency guard (Sprint 49)', () {
      Map<String, Object?> monolithic(String name) => {
            'name': name,
            'enabled': 1,
            'is_local': 1,
            'execution_order': 30,
            'condition_type': 'OR',
            // Multi-pattern header condition -> a split candidate.
            'condition_header': jsonEncode([r'@spam-a\.com$', r'@spam-b\.com$']),
            'action_delete': 1,
            'date_added': DateTime.now().millisecondsSinceEpoch,
            'created_by': 'user',
            // pattern_category NULL == monolithic candidate.
          };

      test('duplicate monolithic source rows do NOT mint duplicate '
          'individual rules (the 12,539-rule prod-DB bloat class)', () async {
        final db = await testHelper.dbHelper.database;
        // The pre-F73 import ran multiple times on the prod DB, leaving
        // content-identical monolithic rows. Before the guard, the split
        // created suffixed (_2/_3) duplicates for every pattern of every
        // copy.
        await db.insert('rules', monolithic('legacy_import'));
        await db.insert('rules', monolithic('legacy_import_2'));

        await service.splitMonolithicRules();

        final individual = await db.query('rules',
            where: "pattern_category IS NOT NULL AND created_by = 'migration_f73'");
        // 2 patterns total -- NOT 4. Each pattern exactly once.
        expect(individual, hasLength(2),
            reason: 'Content-identical patterns from duplicate monolithic '
                'sources must be inserted exactly once.');
        // Both monolithic originals are consumed either way.
        final monolithicLeft =
            await db.query('rules', where: 'pattern_category IS NULL');
        expect(monolithicLeft, isEmpty);
      });

      test('re-running the split is a no-op (idempotent)', () async {
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', monolithic('legacy_import'));
        await service.splitMonolithicRules();
        final afterFirst = (await db.query('rules')).length;

        final createdSecondRun = await service.splitMonolithicRules();
        expect(createdSecondRun, 0);
        expect((await db.query('rules')).length, afterFirst);
      });
    });

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

        // After F73 rebuild, bundled YAML has individual rules (1638 header_from rules)
        expect(result.rules, greaterThan(0));
        expect(result.safeSenders, greaterThan(0));

        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules.isNotEmpty, isTrue);

        final safeSenders = await db.query('safe_senders');
        expect(safeSenders, isNotEmpty);
      });
    });

    group('resetToDefaults', () {
      test('seeds rules and safe senders from bundled YAML assets', () async {
        final result = await service.resetToDefaults();

        // After F73 rebuild, bundled YAML has individual rules (1638 header_from rules)
        expect(result.rules, greaterThan(100));
        expect(result.safeSenders, greaterThan(0));

        // Verify rules were inserted into the database
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules', orderBy: 'execution_order');
        expect(rules.length, greaterThan(100));

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

        expect(result.rules, greaterThan(100)); // After F73: 1638 rules

        // Verify user rules were replaced by defaults
        rules = await db.query('rules');
        expect(rules.length, greaterThan(100));
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

        // After F73 rebuild, verify individual rules have correct structure
        expect(rules.isNotEmpty, isTrue);

        // Find a sample header_from rule
        final headerRule = rules.firstWhere(
          (r) => r['pattern_category'] == 'header_from',
          orElse: () => rules[0],
        );

        expect(headerRule['enabled'], 1); // True -> 1
        expect(headerRule['is_local'], 1); // True -> 1
        expect(headerRule['execution_order'], isNotNull);
        expect(headerRule['condition_type'], 'OR');

        // Should have header conditions (JSON array)
        expect(headerRule['condition_header'], isNotNull);
        final headerPatterns = jsonDecode(headerRule['condition_header'] as String);
        expect(headerPatterns, isList);
        expect(headerPatterns, isNotEmpty);

        // Should have delete action set
        expect(headerRule['action_delete'], 1);

        // Classification fields should be present
        expect(headerRule['pattern_category'], 'header_from');
        expect(headerRule['pattern_sub_type'], isNotNull);
        expect(headerRule['source_domain'], isNotNull);
      });

      test('can be called multiple times without duplicate rules', () async {
        // First reset
        var result = await service.resetToDefaults();
        final firstCount = result.rules;
        expect(firstCount, greaterThan(100));

        // Second reset should clear and re-seed (no duplicates)
        result = await service.resetToDefaults();
        expect(result.rules, firstCount);

        // Verify no duplicates
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules, hasLength(firstCount));
      });

      test('works on already empty database', () async {
        final result = await service.resetToDefaults();

        expect(result.rules, greaterThan(100));
        expect(result.safeSenders, greaterThan(0));

        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules.length, greaterThan(100));
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
      // Total post-seed TLD patterns ensured by the migration:
      //   2 legacy F53 patterns (.cc, .ne)
      //   + 194 BUG-S37-2 (Sprint 39) ccTLD gap-fill patterns.
      const expectedPostSeedTldCount = 196;
      const gapFillCcTldCount = 194;

      test('adds legacy + gap-fill TLD rows as individual rows on empty '
          'database', () async {
        // Empty database -- no monolithic rule, no individual rows.
        // ensureTldBlockRules should insert all post-seed TLD rows.
        final added = await service.ensureTldBlockRules();
        expect(added, expectedPostSeedTldCount);

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

        // Verify a representative gap-fill ccTLD row exists (.za, South Africa)
        final zaRows = await db.query('rules',
            where: 'pattern_category = ? AND pattern_sub_type = ? '
                "AND condition_header LIKE ?",
            whereArgs: ['header_from', 'top_level_domain', '%\\.za\$%']);
        expect(zaRows, hasLength(1));
      });

      test('is idempotent when individual TLD rows already present', () async {
        // First call inserts them
        final first = await service.ensureTldBlockRules();
        expect(first, expectedPostSeedTldCount);

        // Second call is a no-op
        final second = await service.ensureTldBlockRules();
        expect(second, 0, reason: 'individual rows already present');

        // Third call is still a no-op
        final third = await service.ensureTldBlockRules();
        expect(third, 0);
      });

      test('adds only the missing patterns when some already exist', () async {
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

        // Should add all post-seed patterns except the pre-existing .ne.
        final added = await service.ensureTldBlockRules();
        expect(added, expectedPostSeedTldCount - 1);

        // Verify multiple TLD rows exist
        final tldRows = await db.query('rules',
            where: 'pattern_category = ? AND pattern_sub_type = ?',
            whereArgs: ['header_from', 'top_level_domain']);
        expect(tldRows.length, greaterThanOrEqualTo(expectedPostSeedTldCount));
      });

      test('BUG-S37-2: gap-fill covers every ISO 3166-1 ccTLD except '
          'us/uk/ca after migration', () async {
        // Seed from the bundled YAML asset (fresh-install path), then run the
        // existing-install migration. Together these must yield a
        // top_level_domain block rule for every ISO 3166-1 alpha-2 ccTLD,
        // except the three that stay allowed (.us, .uk, .ca).
        TestWidgetsFlutterBinding.ensureInitialized();
        await service.seedIfEmpty();
        await service.splitMonolithicRules();
        await service.ensureTldBlockRules();

        final db = await testHelper.dbHelper.database;
        final tldRows = await db.query('rules',
            columns: ['condition_header'],
            where: 'pattern_category = ? AND pattern_sub_type = ?',
            whereArgs: ['header_from', 'top_level_domain']);

        // Extract the TLD token from each '@.*\.<tld>$' pattern.
        final tldTokenRe = RegExp(r'@\.\*\\\.([a-z0-9.-]+)\$');
        final coveredTlds = <String>{};
        for (final row in tldRows) {
          final headerJson = row['condition_header'] as String?;
          if (headerJson == null) continue;
          for (final p in (jsonDecode(headerJson) as List)) {
            final m = tldTokenRe.firstMatch(p as String);
            if (m != null) coveredTlds.add(m.group(1)!);
          }
        }

        const excluded = {'us', 'uk', 'ca'};
        final missing = _isoCcTldsForTest
            .where((cc) => !excluded.contains(cc) && !coveredTlds.contains(cc))
            .toList();
        expect(missing, isEmpty,
            reason: 'ccTLDs missing after gap-fill: ${missing.join(', ')}');

        // Sanity: gap-fill count matches the documented number.
        expect(gapFillCcTldCount, 194);
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

        // The two legacy patterns (.cc, .ne) are found in the monolithic row
        // and skipped (backwards compat). The remaining gap-fill ccTLD
        // patterns (BUG-S37-2) are not present and are added.
        final added = await service.ensureTldBlockRules();
        expect(added, gapFillCcTldCount,
            reason: 'legacy .cc/.ne skipped via monolithic row; gap-fill '
                'ccTLDs added');
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

      test('BUG-S37-2: malformed TLD rules are absent after a fresh seed',
          () async {
        // The typo / miscategorized TLD rules were removed from the bundled
        // rules.yaml. A fresh seed must not contain any of them. Sprint 42
        // (BUG-S37-2, decision 2a) additionally removes .sho and .sweeps --
        // neither is a real IANA TLD (the Sprint-39 note that .sweeps was the
        // "correct spelling" was wrong; it is not registered).
        await service.resetToDefaults();
        final db = await testHelper.dbHelper.database;

        const badPatterns = <String>[
          r'@.*\.c$',
          r'@.*\.giw$',
          r'@.*\.nwm$',
          r'@.*\.xd$',
          r'@.*\.sweepss$',
          r'@.*\.qzz.io$',
          r'@.*\.sho$', // Sprint 42 BUG-S37-2
          r'@.*\.sweeps$', // Sprint 42 BUG-S37-2 (not a real IANA TLD)
        ];
        final tldRules = await db.query('rules',
            columns: ['condition_header'],
            where: "pattern_sub_type = 'top_level_domain'");
        final allHeaders = <String>{};
        for (final row in tldRules) {
          final raw = row['condition_header'];
          if (raw is String) {
            allHeaders.addAll((jsonDecode(raw) as List).cast<String>());
          }
        }
        for (final bad in badPatterns) {
          expect(allHeaders.contains(bad), isFalse,
              reason: 'Malformed TLD pattern "$bad" must not be seeded');
        }
        // Positive control: an allowlisted real ccTLD remains.
        expect(allHeaders.contains(r'@.*\.ca$'), isTrue,
            reason: '.ca is a real ccTLD and must remain');
      });
    });

    group('seedIfEmpty and resetToDefaults interaction', () {
      test('seedIfEmpty skips after resetToDefaults has populated data', () async {
        // Reset seeds the database with rules from bundled rules.yaml
        // (post-Sprint 34 F73: ~1638 individual per-pattern rules from
        // monolithic split). Use greaterThan(100) to match sibling
        // assertions in this file (lines 105, 122, 173).
        final resetResult = await service.resetToDefaults();
        expect(resetResult.rules, greaterThan(100));

        // seedIfEmpty should skip since rules exist
        final seedResult = await service.seedIfEmpty();
        expect(seedResult.rules, 0);
        expect(seedResult.safeSenders, 0);

        // Verify rules were not duplicated (no duplicates from attempted seed)
        final db = await testHelper.dbHelper.database;
        final rules = await db.query('rules');
        expect(rules.length, greaterThan(100));
      });
    });
  });
}

/// Canonical ISO 3166-1 alpha-2 ccTLDs (with the `uk` and `eu` DNS aliases),
/// used by the BUG-S37-2 coverage test. Kept independent of production code so
/// the test fails loudly if a future edit silently drops a ccTLD.
const List<String> _isoCcTldsForTest = <String>[
  'ad', 'ae', 'af', 'ag', 'ai', 'al', 'am', 'ao', 'aq', 'ar', 'as', 'at',
  'au', 'aw', 'ax', 'az', 'ba', 'bb', 'bd', 'be', 'bf', 'bg', 'bh', 'bi',
  'bj', 'bl', 'bm', 'bn', 'bo', 'bq', 'br', 'bs', 'bt', 'bv', 'bw', 'by',
  'bz', 'ca', 'cc', 'cd', 'cf', 'cg', 'ch', 'ci', 'ck', 'cl', 'cm', 'cn',
  'co', 'cr', 'cu', 'cv', 'cw', 'cx', 'cy', 'cz', 'de', 'dj', 'dk', 'dm',
  'do', 'dz', 'ec', 'ee', 'eg', 'eh', 'er', 'es', 'et', 'fi', 'fj', 'fk',
  'fm', 'fo', 'fr', 'ga', 'gb', 'gd', 'ge', 'gf', 'gg', 'gh', 'gi', 'gl',
  'gm', 'gn', 'gp', 'gq', 'gr', 'gs', 'gt', 'gu', 'gw', 'gy', 'hk', 'hm',
  'hn', 'hr', 'ht', 'hu', 'id', 'ie', 'il', 'im', 'in', 'io', 'iq', 'ir',
  'is', 'it', 'je', 'jm', 'jo', 'jp', 'ke', 'kg', 'kh', 'ki', 'km', 'kn',
  'kp', 'kr', 'kw', 'ky', 'kz', 'la', 'lb', 'lc', 'li', 'lk', 'lr', 'ls',
  'lt', 'lu', 'lv', 'ly', 'ma', 'mc', 'md', 'me', 'mf', 'mg', 'mh', 'mk',
  'ml', 'mm', 'mn', 'mo', 'mp', 'mq', 'mr', 'ms', 'mt', 'mu', 'mv', 'mw',
  'mx', 'my', 'mz', 'na', 'nc', 'ne', 'nf', 'ng', 'ni', 'nl', 'no', 'np',
  'nr', 'nu', 'nz', 'om', 'pa', 'pe', 'pf', 'pg', 'ph', 'pk', 'pl', 'pm',
  'pn', 'pr', 'ps', 'pt', 'pw', 'py', 'qa', 're', 'ro', 'rs', 'ru', 'rw',
  'sa', 'sb', 'sc', 'sd', 'se', 'sg', 'sh', 'si', 'sj', 'sk', 'sl', 'sm',
  'sn', 'so', 'sr', 'ss', 'st', 'sv', 'sx', 'sy', 'sz', 'tc', 'td', 'tf',
  'tg', 'th', 'tj', 'tk', 'tl', 'tm', 'tn', 'to', 'tr', 'tt', 'tv', 'tw',
  'tz', 'ua', 'ug', 'uk', 'um', 'us', 'uy', 'uz', 'va', 'vc', 've', 'vg',
  'vi', 'vn', 'vu', 'wf', 'ws', 'ye', 'yt', 'za', 'zm', 'zw', 'eu',
];
