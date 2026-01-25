import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/services/safe_sender_evaluator.dart';

/// Mock database provider for testing
class MockRuleDatabaseProvider implements RuleDatabaseProvider {
  final Map<String, Map<String, dynamic>> safeSendersMap = {};

  @override
  Future<Database> get database => Future.error('Not implemented');

  @override
  Future<int> deleteRule(String ruleName) => Future.error('Not implemented');

  @override
  Future<void> deleteAllRules() => Future.error('Not implemented');

  @override
  Future<int> deleteSafeSender(String pattern) async {
    if (safeSendersMap.containsKey(pattern)) {
      safeSendersMap.remove(pattern);
      return 1;
    }
    return 0;
  }

  @override
  Future<void> deleteAllSafeSenders() async {
    safeSendersMap.clear();
  }

  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) => Future.error('Not implemented');

  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async {
    return safeSendersMap[pattern];
  }

  @override
  Future<int> insertRule(Map<String, dynamic> rule) => Future.error('Not implemented');

  @override
  Future<int> insertSafeSender(Map<String, dynamic> safeSender) async {
    final pattern = safeSender['pattern'] as String;
    if (safeSendersMap.containsKey(pattern)) {
      throw Exception('UNIQUE constraint failed');
    }
    safeSendersMap[pattern] = safeSender;
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) => Future.error('Not implemented');

  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async {
    return safeSendersMap.values.toList();
  }

  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) => Future.error('Not implemented');

  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async {
    if (!safeSendersMap.containsKey(pattern)) {
      return 0;
    }
    safeSendersMap[pattern] = values;
    return 1;
  }
}

void main() {
  group('SafeSenderEvaluator', () {
    late MockRuleDatabaseProvider mockProvider;
    late SafeSenderDatabaseStore store;
    late PatternCompiler compiler;
    late SafeSenderEvaluator evaluator;

    setUp(() {
      mockProvider = MockRuleDatabaseProvider();
      store = SafeSenderDatabaseStore(mockProvider);
      compiler = PatternCompiler();
      evaluator = SafeSenderEvaluator(store, compiler);
    });

    group('Simple Email Patterns', () {
      setUp(() async {
        // Add exact email as safe sender
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'trusted@example.com',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should return true for exact email match', () async {
        final result = await evaluator.isSafe('trusted@example.com');
        expect(result, true);
      });

      test('should return true for case-insensitive match', () async {
        final result = await evaluator.isSafe('TRUSTED@EXAMPLE.COM');
        expect(result, true);
      });

      test('should return false for different email', () async {
        final result = await evaluator.isSafe('untrusted@example.com');
        expect(result, false);
      });

      test('should return evaluation result with pattern', () async {
        final result = await evaluator.evaluateSafeSenders('trusted@example.com');
        expect(result.isSafe, true);
        expect(result.matchedPattern, 'trusted@example.com');
        expect(result.matchedException, isNull);
      });
    });

    group('Domain Patterns', () {
      setUp(() async {
        // Add domain pattern as safe sender (regex)
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$',
          patternType: 'subdomain',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should match any email from domain', () async {
        final result1 = await evaluator.isSafe('user@company.com');
        expect(result1, true);

        final result2 = await evaluator.isSafe('admin@company.com');
        expect(result2, true);
      });

      test('should match subdomains', () async {
        final result = await evaluator.isSafe('user@mail.company.com');
        expect(result, true);
      });

      test('should not match different domain', () async {
        final result = await evaluator.isSafe('user@notcompany.com');
        expect(result, false);
      });
    });

    group('Domain with Email Exception', () {
      setUp(() async {
        // Add domain safe sender with email exception
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$',
          patternType: 'subdomain',
          exceptionPatterns: ['spammer@company.com'],
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should allow trusted user from domain', () async {
        final result = await evaluator.isSafe('user@company.com');
        expect(result, true);
      });

      test('should reject exception email', () async {
        final result = await evaluator.isSafe('spammer@company.com');
        expect(result, false);
      });

      test('should have exception in result', () async {
        final result = await evaluator.evaluateSafeSenders('spammer@company.com');
        expect(result.isSafe, false);
        expect(result.matchedPattern, isNotNull);
        expect(result.matchedException, 'spammer@company.com');
      });

      test('should allow case-insensitive exception', () async {
        final result = await evaluator.isSafe('SPAMMER@COMPANY.COM');
        expect(result, false);
      });
    });

    group('Domain with Subdomain Exception', () {
      setUp(() async {
        // Add domain safe sender with subdomain exception
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$',
          patternType: 'subdomain',
          exceptionPatterns: [r'^[^@\s]+@marketing\.company\.com$'],
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should allow main domain', () async {
        final result = await evaluator.isSafe('user@company.com');
        expect(result, true);
      });

      test('should reject exception subdomain', () async {
        final result = await evaluator.isSafe('user@marketing.company.com');
        expect(result, false);
      });

      test('should allow other subdomains', () async {
        final result = await evaluator.isSafe('user@support.company.com');
        expect(result, true);
      });
    });

    group('Multiple Exceptions', () {
      setUp(() async {
        // Add safe sender with multiple exceptions
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$',
          patternType: 'subdomain',
          exceptionPatterns: [
            'spammer1@company.com',
            'spammer2@company.com',
            r'^[^@\s]+@temp\.company\.com$',
          ],
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should match all email exceptions', () async {
        final result1 = await evaluator.isSafe('spammer1@company.com');
        expect(result1, false);

        final result2 = await evaluator.isSafe('spammer2@company.com');
        expect(result2, false);
      });

      test('should match subdomain exception', () async {
        final result = await evaluator.isSafe('user@temp.company.com');
        expect(result, false);
      });

      test('should allow non-exception emails', () async {
        final result = await evaluator.isSafe('trusted@company.com');
        expect(result, true);
      });
    });

    group('Multiple Safe Senders', () {
      setUp(() async {
        // Add multiple safe sender patterns
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'admin@company1.com',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@company2\.com$',
          patternType: 'subdomain',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should match first pattern', () async {
        final result = await evaluator.isSafe('admin@company1.com');
        expect(result, true);
      });

      test('should match second pattern', () async {
        final result = await evaluator.isSafe('user@company2.com');
        expect(result, true);
      });

      test('should not match unlisted address', () async {
        final result = await evaluator.isSafe('user@company3.com');
        expect(result, false);
      });
    });

    group('No Safe Senders', () {
      test('should return false when no patterns configured', () async {
        final result = await evaluator.isSafe('any@email.com');
        expect(result, false);
      });

      test('should provide reason in result', () async {
        final result = await evaluator.evaluateSafeSenders('any@email.com');
        expect(result.isSafe, false);
        expect(result.reason, contains('No safe sender patterns'));
      });
    });

    group('Pattern Type Detection', () {
      setUp(() async {
        // Add various pattern types
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'exact@example.com',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@example.com',
          patternType: 'domain',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should handle email type patterns', () async {
        final result = await evaluator.isSafe('exact@example.com');
        expect(result, true);
      });

      test('should handle domain type patterns', () async {
        final result = await evaluator.isSafe('user@example.com');
        expect(result, true);
      });
    });

    group('Evaluation Result Details', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^[^@\s]+@company\.com$',
          patternType: 'subdomain',
          exceptionPatterns: ['blocked@company.com'],
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should include email address in result', () async {
        final result = await evaluator.evaluateSafeSenders('user@company.com');
        expect(result.emailAddress, 'user@company.com');
      });

      test('should include matched pattern in result', () async {
        final result = await evaluator.evaluateSafeSenders('user@company.com');
        expect(result.matchedPattern, isNotNull);
        expect(result.matchedPattern, contains('company'));
      });

      test('should include exception in result', () async {
        final result = await evaluator.evaluateSafeSenders('blocked@company.com');
        expect(result.matchedException, 'blocked@company.com');
      });

      test('should provide reason for result', () async {
        final result = await evaluator.evaluateSafeSenders('user@company.com');
        expect(result.reason, isNotNull);
        expect(result.reason.isNotEmpty, true);
      });

      test('should format result as string', () async {
        final result = await evaluator.evaluateSafeSenders('user@company.com');
        final str = result.toString();
        expect(str, contains('SafeSenderEvaluationResult'));
        expect(str, contains('isSafe'));
      });
    });

    group('Case Insensitivity', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'Admin@Company.Com',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should match lowercase', () async {
        final result = await evaluator.isSafe('admin@company.com');
        expect(result, true);
      });

      test('should match uppercase', () async {
        final result = await evaluator.isSafe('ADMIN@COMPANY.COM');
        expect(result, true);
      });

      test('should match mixed case', () async {
        final result = await evaluator.isSafe('AdMiN@CoMpAnY.cOm');
        expect(result, true);
      });
    });

    group('Invalid Patterns', () {
      setUp(() async {
        // Add a safe sender with invalid regex pattern
        // PatternCompiler should handle this gracefully
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'[invalid(regex',
          patternType: 'subdomain',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should handle invalid regex gracefully', () async {
        // Should not throw, should return false (pattern will not match)
        final result = await evaluator.isSafe('any@email.com');
        expect(result, false);
      });
    });

    group('Pattern Compiler Caching', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: r'^test@example\.com$',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should cache compiled patterns', () async {
        await evaluator.isSafe('test@example.com');
        await evaluator.isSafe('test@example.com');

        final stats = evaluator.getStatistics();
        expect(stats['pattern_compiler']['cache_hits'], greaterThanOrEqualTo(1));
      });

      test('should provide statistics', () async {
        await evaluator.isSafe('test@example.com');
        final stats = evaluator.getStatistics();

        expect(stats['pattern_compiler'], isNotNull);
        expect(stats['pattern_compiler']['cached_patterns'], isNotNull);
        expect(stats['pattern_compiler']['cache_hits'], isNotNull);
      });

      test('should clear cache', () async {
        await evaluator.isSafe('test@example.com');
        evaluator.clearCache();

        final stats = evaluator.getStatistics();
        expect(stats['pattern_compiler']['cached_patterns'], 0);
      });
    });

    group('Exception Handling', () {
      test('SafeSenderEvaluationException formats message correctly', () {
        final exception = SafeSenderEvaluationException(
          'Test error',
          Exception('Root cause'),
        );

        expect(
          exception.toString(),
          contains('SafeSenderEvaluationException: Test error'),
        );
        expect(exception.toString(), contains('Root cause'));
      });

      test('SafeSenderEvaluationException without cause', () {
        final exception = SafeSenderEvaluationException('Test error');
        expect(exception.toString(), 'SafeSenderEvaluationException: Test error');
      });
    });

    group('Edge Cases', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'user@example.com',
          patternType: 'email',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      test('should handle whitespace in email', () async {
        final result = await evaluator.isSafe('  user@example.com  ');
        expect(result, true);
      });

      test('should handle empty email gracefully', () async {
        final result = await evaluator.isSafe('');
        expect(result, false);
      });

      test('should handle null-like string', () async {
        // Shouldn't crash, just return false
        final result = await evaluator.isSafe('');
        expect(result, isFalse);
      });
    });
  });
}
