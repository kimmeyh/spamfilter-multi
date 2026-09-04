import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/manual_rule_duplicate_checker.dart';

import '../../helpers/database_test_helper.dart';

/// Sprint 36 BUG-S35-1: verify the pre-insert duplicate checker rejects
/// block-rule and safe-sender duplicates at every normalization level
/// (exact, case, whitespace) and across all relevant sub-type combinations.
void main() {
  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  Future<void> seedBlockRule({
    required String pattern,
    required String subType,
    String category = 'header_from',
    String name = 'seeded_rule',
    String sourceDomain = 'example.com',
  }) async {
    final db = await testHelper.dbHelper.database;
    await db.insert('rules', {
      'name': name,
      'enabled': 1,
      'is_local': 1,
      'execution_order': 10,
      'condition_type': 'OR',
      'condition_header': jsonEncode([pattern]),
      'action_delete': 1,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'manual',
      'pattern_category': category,
      'pattern_sub_type': subType,
      'source_domain': sourceDomain,
    });
  }

  /// F186 body rule shape: pattern lives in condition_body, condition_header
  /// is NULL (exactly what _saveBlockRule writes for ManualRuleType.bodyPhrase
  /// and what the legacy body keyword imports look like).
  Future<void> seedBodyRule({
    required String pattern,
    String name = 'seeded_body_rule',
  }) async {
    final db = await testHelper.dbHelper.database;
    await db.insert('rules', {
      'name': name,
      'enabled': 1,
      'is_local': 1,
      'execution_order': 50,
      'condition_type': 'OR',
      'condition_body': jsonEncode([pattern]),
      'action_delete': 1,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'manual',
      'pattern_category': 'body',
      'pattern_sub_type': 'keyword',
      'source_domain': pattern,
    });
  }

  Future<void> seedSafeSender({
    required String pattern,
    required String patternType,
  }) async {
    final db = await testHelper.dbHelper.database;
    await db.insert('safe_senders', {
      'pattern': pattern,
      'pattern_type': patternType,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'manual',
    });
  }

  group('ManualRuleDuplicateChecker - block rules', () {
    test('returns false when no rules exist', () async {
      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: r'@.*\.xyz$',
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );

      expect(result, isFalse);
    });

    test('detects exact duplicate TLD rule', () async {
      await seedBlockRule(
        pattern: r'@.*\.xyz$',
        subType: 'top_level_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: r'@.*\.xyz$',
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );

      expect(result, isTrue);
    });

    test('detects case-insensitive duplicate (.XYZ vs .xyz)', () async {
      await seedBlockRule(
        pattern: r'@.*\.xyz$',
        subType: 'top_level_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: r'@.*\.XYZ$',
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );

      expect(result, isTrue);
    });

    test('detects whitespace-trimmed duplicate', () async {
      await seedBlockRule(
        pattern: r'@.*\.xyz$',
        subType: 'top_level_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: '  @.*\\.xyz\$  ',
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );

      expect(result, isTrue);
    });

    test('different sub_type is NOT a duplicate even if pattern matches', () async {
      // Same text, but one is a TLD rule, the other is an entire_domain rule.
      // These are semantically different because their sub_type drives display
      // and conflict-resolution logic.
      await seedBlockRule(
        pattern: r'@(?:[a-z0-9-]+\.)*example\.com$',
        subType: 'entire_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: r'@(?:[a-z0-9-]+\.)*example\.com$',
        patternCategory: 'header_from',
        patternSubType: 'exact_domain',
      );

      expect(result, isFalse);
    });

    test('different pattern is NOT a duplicate', () async {
      await seedBlockRule(
        pattern: r'@.*\.xyz$',
        subType: 'top_level_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.blockRuleExists(
        pattern: r'@.*\.cc$',
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );

      expect(result, isFalse);
    });

    test('detects duplicate across each of the 4 block-rule sub-types', () async {
      final subTypes = [
        ('top_level_domain', r'@.*\.zzz$'),
        ('entire_domain', r'@(?:[a-z0-9-]+\.)*aaa\.com$'),
        ('exact_domain', r'@bbb\.com$'),
        ('exact_email', r'^user@ccc\.com$'),
      ];

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      for (final (subType, pattern) in subTypes) {
        await seedBlockRule(
          pattern: pattern,
          subType: subType,
          name: 'seeded_$subType',
        );

        expect(
          await checker.blockRuleExists(
            pattern: pattern,
            patternCategory: 'header_from',
            patternSubType: subType,
          ),
          isTrue,
          reason: 'sub-type $subType should detect duplicate',
        );
      }
    });
  });

  group('ManualRuleDuplicateChecker - body phrases (F186, Sprint 64 MV finding)', () {
    // Before the fix the query compared condition_header for every category,
    // which is NULL on body rules, so body duplicates were never detected.
    test('detects an exact duplicate body phrase (escaped-space form)', () async {
      await seedBodyRule(pattern: r'a\ local\ girl');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'a\ local\ girl',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isTrue,
      );
    });

    test('detects a legacy bare-space row from the generator\'s escaped form '
        '(Android dev DB shape)', () async {
      await seedBodyRule(pattern: 'a local girl');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'a\ local\ girl',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isTrue,
        reason: r'`\ ` and ` ` are regex-equivalent and must compare equal',
      );
    });

    test('detects an escaped-space row from a bare-space query '
        '(Windows DB shape, 84 of 85 legacy body rules)', () async {
      await seedBodyRule(pattern: r'a\ local\ girl');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: 'A Local Girl',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isTrue,
      );
    });

    test('a different body phrase is NOT a duplicate', () async {
      await seedBodyRule(pattern: r'a\ local\ girl');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'local\ girls',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isFalse,
      );
    });

    test('a body query does NOT match a header rule carrying the same text '
        '(column follows the category)', () async {
      await seedBlockRule(
        pattern: r'a\ local\ girl',
        subType: 'keyword',
        category: 'header_from',
      );
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'a\ local\ girl',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isFalse,
      );
    });

    // Sprint 64 Phase 5.1.1 review finding: `%` and `_` are SQL LIKE
    // wildcards and RegExp.escape leaves both untouched, so an unescaped
    // phrase widened the match and REJECTED a genuinely distinct rule as a
    // duplicate -- with no way for the user to force it through.
    test('an underscore in the phrase does not wildcard-match a space', () async {
      await seedBodyRule(pattern: r'act\ now', name: 'seeded_act_now');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'act_now',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isFalse,
        reason: r'`act_now` is a DIFFERENT phrase from `act now`; the `_` must '
            'not match the space as a LIKE wildcard',
      );
    });

    test('a percent sign in the phrase does not wildcard-match', () async {
      await seedBodyRule(
          pattern: r'save\ 50\ percent', name: 'seeded_save_percent');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'save%percent',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isFalse,
        reason: 'a literal % must not match "50 " as a LIKE wildcard',
      );
    });

    test('escaping the wildcards does not break real duplicate detection',
        () async {
      // The escaping must not over-correct: a phrase that genuinely contains
      // an underscore still matches an existing rule for the SAME phrase.
      await seedBodyRule(pattern: r'act_now', name: 'seeded_underscore');
      final checker = ManualRuleDuplicateChecker(await testHelper.dbHelper.database);

      expect(
        await checker.blockRuleExists(
          pattern: r'act_now',
          patternCategory: 'body',
          patternSubType: 'keyword',
        ),
        isTrue,
      );
    });
  });

  group('ManualRuleDuplicateChecker - safe senders', () {
    test('returns false when no safe senders exist', () async {
      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.safeSenderExists(
        pattern: r'@trusted\.com$',
        patternType: 'exact_domain',
      );

      expect(result, isFalse);
    });

    test('detects exact duplicate safe sender', () async {
      await seedSafeSender(
        pattern: r'@trusted\.com$',
        patternType: 'exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.safeSenderExists(
        pattern: r'@trusted\.com$',
        patternType: 'exact_domain',
      );

      expect(result, isTrue);
    });

    test('detects case-insensitive duplicate safe sender', () async {
      await seedSafeSender(
        pattern: r'@trusted\.com$',
        patternType: 'exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.safeSenderExists(
        pattern: r'@TRUSTED\.COM$',
        patternType: 'exact_domain',
      );

      expect(result, isTrue);
    });

    test('different pattern_type is NOT a duplicate', () async {
      await seedSafeSender(
        pattern: r'@trusted\.com$',
        patternType: 'exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.safeSenderExists(
        pattern: r'@trusted\.com$',
        patternType: 'entire_domain',
      );

      expect(result, isFalse);
    });

    test('detects duplicate across each of the 3 safe-sender sub-types', () async {
      final subTypes = [
        ('entire_domain', r'@(?:[a-z0-9-]+\.)*safe1\.com$'),
        ('exact_domain', r'@safe2\.com$'),
        ('exact_email', r'^user@safe3\.com$'),
      ];

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      for (final (subType, pattern) in subTypes) {
        await seedSafeSender(pattern: pattern, patternType: subType);

        expect(
          await checker.safeSenderExists(
            pattern: pattern,
            patternType: subType,
          ),
          isTrue,
          reason: 'pattern_type $subType should detect duplicate',
        );
      }
    });
  });

  group('ManualRuleDuplicateChecker - BUG-S36-1 block-rule subsumption', () {
    test('exact_email is covered by existing exact_domain (same domain)', () async {
      await seedBlockRule(
        pattern: r'@cwru\.edu$',
        subType: 'exact_domain',
        sourceDomain: 'cwru.edu',
        name: 'seeded_block_exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'bob@cwru.edu',
        patternSubType: 'exact_email',
        patternCategory: 'header_from',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'exact_domain');
      expect(result.sourceDomain, 'cwru.edu');
      expect(result.displayLabel, 'exact_domain cwru.edu');
    });

    test('exact_email is covered by existing entire_domain (same base)', () async {
      await seedBlockRule(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        subType: 'entire_domain',
        sourceDomain: 'cwru.edu',
        name: 'seeded_block_entire_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'bob@cwru.edu',
        patternSubType: 'exact_email',
        patternCategory: 'header_from',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'entire_domain');
    });

    test('exact_domain is covered by existing entire_domain (same base)', () async {
      await seedBlockRule(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        subType: 'entire_domain',
        sourceDomain: 'cwru.edu',
        name: 'seeded_block_entire_domain_2',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'cwru.edu',
        patternSubType: 'exact_domain',
        patternCategory: 'header_from',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'entire_domain');
      expect(result.sourceDomain, 'cwru.edu');
    });

    test('entire_domain is NOT covered by existing exact_domain (broader)', () async {
      await seedBlockRule(
        pattern: r'@cwru\.edu$',
        subType: 'exact_domain',
        sourceDomain: 'cwru.edu',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'cwru.edu',
        patternSubType: 'entire_domain',
        patternCategory: 'header_from',
      );

      expect(result, isNull);
    });

    test('entire_domain is NOT covered by existing exact_email (broader)', () async {
      await seedBlockRule(
        pattern: r'^bob@cwru\.edu$',
        subType: 'exact_email',
        sourceDomain: 'bob@cwru.edu',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'cwru.edu',
        patternSubType: 'entire_domain',
        patternCategory: 'header_from',
      );

      expect(result, isNull);
    });

    test('different base domain is not subsumption', () async {
      await seedBlockRule(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        subType: 'entire_domain',
        sourceDomain: 'cwru.edu',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'mit.edu',
        patternSubType: 'exact_domain',
        patternCategory: 'header_from',
      );

      expect(result, isNull);
    });

    test('top_level_domain has no subsumption with domain types', () async {
      await seedBlockRule(
        pattern: r'@.*\.edu$',
        subType: 'top_level_domain',
        sourceDomain: '.*.edu',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'cwru.edu',
        patternSubType: 'exact_domain',
        patternCategory: 'header_from',
      );

      // TLD rules do NOT subsume domain rules even though semantically the
      // TLD covers the domain. Coverage matrix in the issue intentionally
      // excludes this case because the user expression spaces are different.
      expect(result, isNull);
    });

    test('case-insensitive base domain match', () async {
      await seedBlockRule(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        subType: 'entire_domain',
        sourceDomain: 'CWRU.EDU',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingBlockRule(
        sourceDomain: 'cwru.edu',
        patternSubType: 'exact_domain',
        patternCategory: 'header_from',
      );

      expect(result, isNotNull);
    });
  });

  group('ManualRuleDuplicateChecker - BUG-S36-1 safe-sender subsumption', () {
    test('exact_email is covered by existing exact_domain safe sender', () async {
      await seedSafeSender(
        pattern: r'@cwru\.edu$',
        patternType: 'exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingSafeSender(
        sourceDomain: 'bob@cwru.edu',
        patternType: 'exact_email',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'exact_domain');
      expect(result.sourceDomain, 'cwru.edu');
    });

    test('exact_email is covered by existing entire_domain safe sender', () async {
      await seedSafeSender(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        patternType: 'entire_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingSafeSender(
        sourceDomain: 'bob@cwru.edu',
        patternType: 'exact_email',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'entire_domain');
      expect(result.sourceDomain, 'cwru.edu');
    });

    test('exact_domain is covered by existing entire_domain safe sender', () async {
      await seedSafeSender(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        patternType: 'entire_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingSafeSender(
        sourceDomain: 'cwru.edu',
        patternType: 'exact_domain',
      );

      expect(result, isNotNull);
      expect(result!.subType, 'entire_domain');
    });

    test('entire_domain is NOT covered by existing exact_domain safe sender', () async {
      await seedSafeSender(
        pattern: r'@cwru\.edu$',
        patternType: 'exact_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingSafeSender(
        sourceDomain: 'cwru.edu',
        patternType: 'entire_domain',
      );

      expect(result, isNull);
    });

    test('different base domain is not subsumption (safe sender)', () async {
      await seedSafeSender(
        pattern: r'@(?:[a-z0-9-]+\.)*cwru\.edu$',
        patternType: 'entire_domain',
      );

      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      final result = await checker.findSubsumingSafeSender(
        sourceDomain: 'mit.edu',
        patternType: 'exact_domain',
      );

      expect(result, isNull);
    });
  });

  group('ManualRuleDuplicateChecker - empty input', () {
    test('empty block-rule pattern returns false', () async {
      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      expect(
        await checker.blockRuleExists(
          pattern: '',
          patternCategory: 'header_from',
          patternSubType: 'top_level_domain',
        ),
        isFalse,
      );
    });

    test('empty safe-sender pattern returns false', () async {
      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      expect(
        await checker.safeSenderExists(
          pattern: '',
          patternType: 'exact_domain',
        ),
        isFalse,
      );
    });

    test('whitespace-only pattern returns false', () async {
      final db = await testHelper.dbHelper.database;
      final checker = ManualRuleDuplicateChecker(db);

      expect(
        await checker.blockRuleExists(
          pattern: '   ',
          patternCategory: 'header_from',
          patternSubType: 'top_level_domain',
        ),
        isFalse,
      );
    });
  });
}
