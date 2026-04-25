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
      'source_domain': 'example.com',
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
