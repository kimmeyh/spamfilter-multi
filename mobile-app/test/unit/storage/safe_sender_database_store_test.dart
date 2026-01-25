import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart';

/// Mock database provider for testing
class MockRuleDatabaseProvider implements RuleDatabaseProvider {
  final Map<String, Map<String, dynamic>> safeSendersMap = {};
  final Map<String, Map<String, dynamic>> rulesMap = {};

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
    // This operation is handled by the actual store, not the provider
    // The mock just returns the map value
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
  group('SafeSenderDatabaseStore', () {
    late MockRuleDatabaseProvider mockProvider;
    late SafeSenderDatabaseStore store;

    setUp(() {
      mockProvider = MockRuleDatabaseProvider();
      store = SafeSenderDatabaseStore(mockProvider);
    });

    group('Add Safe Sender', () {
      test('should add simple email pattern', () async {
        final pattern = SafeSenderPattern(
          pattern: 'user@example.com',
          patternType: 'email',
          dateAdded: 1000,
        );

        await store.addSafeSender(pattern);

        final loaded = await store.getSafeSender('user@example.com');
        expect(loaded, isNotNull);
        expect(loaded!.pattern, 'user@example.com');
        expect(loaded.patternType, 'email');
      });

      test('should add domain pattern', () async {
        final pattern = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1000,
        );

        await store.addSafeSender(pattern);

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.pattern, '@company.com');
        expect(loaded.patternType, 'domain');
      });

      test('should add pattern with exceptions', () async {
        final pattern = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spammer@company.com'],
          dateAdded: 1000,
        );

        await store.addSafeSender(pattern);

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, ['spammer@company.com']);
      });

      test('should add pattern with multiple exceptions', () async {
        final pattern = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: [
            'spammer@company.com',
            '@marketing.company.com',
            'noreply@company.com'
          ],
          dateAdded: 1000,
        );

        await store.addSafeSender(pattern);

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, hasLength(3));
        expect(loaded.exceptionPatterns, contains('spammer@company.com'));
        expect(loaded.exceptionPatterns, contains('@marketing.company.com'));
      });

      test('should fail when adding duplicate pattern', () async {
        final pattern = SafeSenderPattern(
          pattern: 'user@example.com',
          patternType: 'email',
          dateAdded: 1000,
        );

        await store.addSafeSender(pattern);

        expect(
          () => store.addSafeSender(pattern),
          throwsA(isA<SafeSenderDatabaseException>()),
        );
      });
    });

    group('Load Safe Senders', () {
      test('should load empty list when no patterns', () async {
        final senders = await store.loadSafeSenders();
        expect(senders, isEmpty);
      });

      test('should load all patterns', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'user1@example.com',
          patternType: 'email',
          dateAdded: 1000,
        ));
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1001,
        ));

        final senders = await store.loadSafeSenders();
        expect(senders, hasLength(2));
      });

      test('should load patterns with exceptions', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spammer@company.com'],
          dateAdded: 1000,
        ));

        final senders = await store.loadSafeSenders();
        expect(senders[0].exceptionPatterns, isNotNull);
        expect(senders[0].exceptionPatterns, contains('spammer@company.com'));
      });

      test('should handle gracefully malformed exception JSON', () async {
        // Manually insert malformed data to test error handling
        mockProvider.safeSendersMap['@company.com'] = {
          'pattern': '@company.com',
          'pattern_type': 'domain',
          'exception_patterns': 'not-valid-json[',
          'date_added': 1000,
          'created_by': 'manual',
        };

        // Should not throw, just skip loading exceptions for that pattern
        final senders = await store.loadSafeSenders();
        expect(senders, hasLength(1));
        expect(senders[0].pattern, '@company.com');
      });
    });

    group('Get Safe Sender', () {
      test('should return null when pattern not found', () async {
        final loaded = await store.getSafeSender('nonexistent@example.com');
        expect(loaded, isNull);
      });

      test('should return pattern with exceptions', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spam@company.com'],
          dateAdded: 1000,
        ));

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded, isNotNull);
        expect(loaded!.exceptionPatterns, ['spam@company.com']);
      });
    });

    group('Update Safe Sender', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1000,
        ));
      });

      test('should update pattern type', () async {
        final updated = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'subdomain',
          dateAdded: 1000,
        );

        await store.updateSafeSender('@company.com', updated);

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.patternType, 'subdomain');
      });

      test('should update exceptions', () async {
        final updated = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spam1@company.com', 'spam2@company.com'],
          dateAdded: 1000,
        );

        await store.updateSafeSender('@company.com', updated);

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, hasLength(2));
      });

      test('should fail when updating nonexistent pattern', () async {
        final updated = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1000,
        );

        expect(
          () => store.updateSafeSender('nonexistent@example.com', updated),
          throwsA(isA<SafeSenderDatabaseException>()),
        );
      });
    });

    group('Remove Safe Sender', () {
      test('should remove pattern completely', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'user@example.com',
          patternType: 'email',
          dateAdded: 1000,
        ));

        await store.removeSafeSender('user@example.com');

        final loaded = await store.getSafeSender('user@example.com');
        expect(loaded, isNull);
      });

      test('should remove pattern with exceptions', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spam@company.com'],
          dateAdded: 1000,
        ));

        await store.removeSafeSender('@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded, isNull);
      });

      test('should fail when removing nonexistent pattern', () async {
        expect(
          () => store.removeSafeSender('nonexistent@example.com'),
          throwsA(isA<SafeSenderDatabaseException>()),
        );
      });
    });

    group('Add Exception', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1000,
        ));
      });

      test('should add exception to existing pattern', () async {
        await store.addException('@company.com', 'spammer@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, ['spammer@company.com']);
      });

      test('should add multiple exceptions', () async {
        await store.addException('@company.com', 'spammer1@company.com');
        await store.addException('@company.com', 'spammer2@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, hasLength(2));
        expect(loaded.exceptionPatterns, contains('spammer1@company.com'));
        expect(loaded.exceptionPatterns, contains('spammer2@company.com'));
      });

      test('should not duplicate exceptions', () async {
        await store.addException('@company.com', 'spammer@company.com');
        await store.addException('@company.com', 'spammer@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, hasLength(1));
      });

      test('should fail when safe sender does not exist', () async {
        expect(
          () => store.addException('nonexistent@example.com', 'exception@example.com'),
          throwsA(isA<SafeSenderDatabaseException>()),
        );
      });

      test('should add domain exception to domain pattern', () async {
        await store.addException('@company.com', '@marketing.company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, contains('@marketing.company.com'));
      });
    });

    group('Remove Exception', () {
      setUp(() async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spam1@company.com', 'spam2@company.com'],
          dateAdded: 1000,
        ));
      });

      test('should remove exception from pattern', () async {
        await store.removeException('@company.com', 'spam1@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, ['spam2@company.com']);
      });

      test('should clear exceptions when removing last one', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'user@example.com',
          patternType: 'email',
          exceptionPatterns: ['noreply@example.com'],
          dateAdded: 1000,
        ));

        await store.removeException('user@example.com', 'noreply@example.com');

        final loaded = await store.getSafeSender('user@example.com');
        expect(loaded!.exceptionPatterns, isNull);
      });

      test('should be idempotent (silent if exception not found)', () async {
        // Should not throw
        await store.removeException('@company.com', 'nonexistent@company.com');

        final loaded = await store.getSafeSender('@company.com');
        expect(loaded!.exceptionPatterns, hasLength(2));
      });

      test('should fail when safe sender does not exist', () async {
        expect(
          () => store.removeException('nonexistent@example.com', 'exception@example.com'),
          throwsA(isA<SafeSenderDatabaseException>()),
        );
      });
    });

    group('Delete All Safe Senders', () {
      test('should delete all patterns', () async {
        await store.addSafeSender(SafeSenderPattern(
          pattern: 'user1@example.com',
          patternType: 'email',
          dateAdded: 1000,
        ));
        await store.addSafeSender(SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          dateAdded: 1001,
        ));

        await store.deleteAllSafeSenders();

        final senders = await store.loadSafeSenders();
        expect(senders, isEmpty);
      });
    });

    group('Pattern Type Detection', () {
      test('should detect email pattern', () {
        expect(
          SafeSenderDatabaseStore.determinePatternType('user@example.com'),
          'email',
        );
      });

      test('should detect domain pattern', () {
        expect(
          SafeSenderDatabaseStore.determinePatternType('@company.com'),
          'domain',
        );
      });

      test('should detect subdomain pattern with regex', () {
        expect(
          SafeSenderDatabaseStore.determinePatternType(
            r'^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$'
          ),
          'subdomain',
        );
      });

      test('should handle empty pattern', () {
        expect(
          SafeSenderDatabaseStore.determinePatternType(''),
          'unknown',
        );
      });
    });

    group('SafeSenderPattern Serialization', () {
      test('should serialize to database format', () {
        final pattern = SafeSenderPattern(
          pattern: '@company.com',
          patternType: 'domain',
          exceptionPatterns: ['spam@company.com'],
          dateAdded: 1000,
          createdBy: 'manual',
        );

        final db = pattern.toDatabase();
        expect(db['pattern'], '@company.com');
        expect(db['pattern_type'], 'domain');
        expect(db['exception_patterns'], contains('spam@company.com'));
        expect(db['date_added'], 1000);
      });

      test('should deserialize from database format', () {
        final row = {
          'pattern': '@company.com',
          'pattern_type': 'domain',
          'exception_patterns': '["spam@company.com"]',
          'date_added': 1000,
          'created_by': 'manual',
        };

        final pattern = SafeSenderPattern.fromDatabase(row);
        expect(pattern.pattern, '@company.com');
        expect(pattern.exceptionPatterns, ['spam@company.com']);
      });

      test('should handle null exception_patterns', () {
        final row = {
          'pattern': 'user@example.com',
          'pattern_type': 'email',
          'exception_patterns': null,
          'date_added': 1000,
          'created_by': 'manual',
        };

        final pattern = SafeSenderPattern.fromDatabase(row);
        expect(pattern.exceptionPatterns, isNull);
      });
    });

    group('Exception Handling', () {
      test('SafeSenderDatabaseException should format message correctly', () {
        final exception = SafeSenderDatabaseException(
          'Test error',
          Exception('Root cause'),
        );

        expect(
          exception.toString(),
          contains('SafeSenderDatabaseException: Test error'),
        );
        expect(exception.toString(), contains('Root cause'));
      });

      test('SafeSenderDatabaseException without cause', () {
        final exception = SafeSenderDatabaseException('Test error');

        expect(exception.toString(), 'SafeSenderDatabaseException: Test error');
      });
    });
  });
}
