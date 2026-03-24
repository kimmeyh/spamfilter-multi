import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import '../../helpers/database_test_helper.dart';

/// Tests for RuleSetProvider state management
///
/// Tests the provider's ability to load, add, remove, and update rules
/// and safe senders using a real test database. Does not test initialize()
/// (which requires AppPaths and MigrationManager) but tests all state
/// management methods after manual setup.
void main() {
  late DatabaseTestHelper testHelper;
  late RuleSetProvider provider;
  late RuleDatabaseStore ruleStore;
  late SafeSenderDatabaseStore safeSenderStore;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();

    ruleStore = RuleDatabaseStore(testHelper.dbHelper);
    safeSenderStore = SafeSenderDatabaseStore(testHelper.dbHelper);

    provider = RuleSetProvider();
    // Manually inject stores via test-accessible method
    provider.initializeForTesting(
      databaseStore: ruleStore,
      safeSenderStore: safeSenderStore,
    );
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('Initial state', () {
    test('starts with idle loading state', () {
      final fresh = RuleSetProvider();
      expect(fresh.loadingState, equals(RuleLoadingState.idle));
      expect(fresh.isLoading, isFalse);
      expect(fresh.isError, isFalse);
      expect(fresh.error, isNull);
    });

    test('returns empty rules when not loaded', () {
      final fresh = RuleSetProvider();
      expect(fresh.rules.rules, isEmpty);
    });

    test('returns empty safe senders when not loaded', () {
      final fresh = RuleSetProvider();
      expect(fresh.safeSenders.safeSenders, isEmpty);
    });
  });

  group('loadRules', () {
    test('loads rules from empty database', () async {
      await provider.loadRules();
      expect(provider.rules.rules, isEmpty);
      expect(provider.loadingState, equals(RuleLoadingState.success));
    });

    test('loads rules from database with data', () async {
      // Seed database with a rule
      final rule = Rule(
        name: 'Test Rule',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: [r'^spam@example\.com$']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );
      await ruleStore.addRule(rule);

      await provider.loadRules();
      expect(provider.rules.rules.length, equals(1));
      expect(provider.rules.rules.first.name, equals('Test Rule'));
    });
  });

  group('loadSafeSenders', () {
    test('loads safe senders from empty database', () async {
      await provider.loadSafeSenders();
      expect(provider.safeSenders.safeSenders, isEmpty);
    });

    test('loads safe senders from database with data', () async {
      final pattern = SafeSenderPattern(
        pattern: r'^user@example\.com$',
        patternType: 'email',
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      );
      await safeSenderStore.addSafeSender(pattern);

      await provider.loadSafeSenders();
      expect(provider.safeSenders.safeSenders.length, equals(1));
      expect(provider.safeSenders.safeSenders.first, equals(r'^user@example\.com$'));
    });
  });

  group('addRule', () {
    test('adds rule to database and local cache', () async {
      await provider.loadRules();
      expect(provider.rules.rules, isEmpty);

      final rule = Rule(
        name: 'New Block Rule',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: [r'@spam\.com$']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );
      await provider.addRule(rule);

      expect(provider.rules.rules.length, equals(1));
      expect(provider.rules.rules.first.name, equals('New Block Rule'));

      // Verify persisted to database
      final dbRules = await ruleStore.loadRules();
      expect(dbRules.rules.length, equals(1));
    });

    test('does nothing if rules not loaded', () async {
      // Do not call loadRules() - _rules is null
      final rule = Rule(
        name: 'Test',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: ['test']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );
      await provider.addRule(rule);

      // Should not throw, just silently return
      final dbRules = await ruleStore.loadRules();
      expect(dbRules.rules, isEmpty);
    });
  });

  group('removeRule', () {
    test('removes rule from database and local cache', () async {
      // Add a rule first
      final rule = Rule(
        name: 'To Remove',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: ['test']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );
      await ruleStore.addRule(rule);
      await provider.loadRules();
      expect(provider.rules.rules.length, equals(1));

      // Remove it
      await provider.removeRule('To Remove');
      expect(provider.rules.rules, isEmpty);

      // Verify removed from database
      final dbRules = await ruleStore.loadRules();
      expect(dbRules.rules, isEmpty);
    });
  });

  group('updateRule', () {
    test('updates rule in database and local cache', () async {
      final rule = Rule(
        name: 'Original',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: ['test']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );
      await ruleStore.addRule(rule);
      await provider.loadRules();

      // Update the rule
      final updated = Rule(
        name: 'Original',
        enabled: false,
        conditions: RuleConditions(type: 'OR', header: ['updated']),
        actions: RuleActions(delete: false, moveToFolder: 'Junk'),
        isLocal: true,
        executionOrder: 50,
      );
      await provider.updateRule('Original', updated);

      expect(provider.rules.rules.first.enabled, isFalse);
    });

    test('throws for non-existent rule', () async {
      await provider.loadRules();
      final rule = Rule(
        name: 'NonExistent',
        enabled: true,
        conditions: RuleConditions(type: 'OR', header: ['test']),
        actions: RuleActions(delete: true),
        isLocal: true,
        executionOrder: 50,
      );

      await provider.updateRule('NonExistent', rule);
      // Should set error state
      expect(provider.error, isNotNull);
    });
  });

  group('addSafeSender', () {
    test('adds safe sender with auto-detected type', () async {
      await provider.loadSafeSenders();
      expect(provider.safeSenders.safeSenders, isEmpty);

      await provider.addSafeSender(r'^user@example\.com$');

      expect(provider.safeSenders.safeSenders.length, equals(1));
      expect(provider.safeSenders.safeSenders.first, equals(r'^user@example\.com$'));

      // Verify persisted with detected type
      final dbSenders = await safeSenderStore.loadSafeSenders();
      expect(dbSenders.length, equals(1));
      expect(dbSenders.first.patternType, equals('email'));
    });

    test('detects domain pattern type', () async {
      await provider.loadSafeSenders();
      await provider.addSafeSender('@example.com');

      final dbSenders = await safeSenderStore.loadSafeSenders();
      expect(dbSenders.first.patternType, equals('domain'));
    });

    test('detects subdomain pattern type', () async {
      await provider.loadSafeSenders();
      await provider.addSafeSender(r'^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$');

      final dbSenders = await safeSenderStore.loadSafeSenders();
      expect(dbSenders.first.patternType, equals('subdomain'));
    });
  });

  group('removeSafeSender', () {
    test('removes safe sender from database and local cache', () async {
      final pattern = SafeSenderPattern(
        pattern: '@test.com',
        patternType: 'domain',
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      );
      await safeSenderStore.addSafeSender(pattern);
      await provider.loadSafeSenders();
      expect(provider.safeSenders.safeSenders.length, equals(1));

      await provider.removeSafeSender('@test.com');
      expect(provider.safeSenders.safeSenders, isEmpty);
    });
  });

  group('getCompilerStats', () {
    test('returns stats map', () {
      final stats = provider.getCompilerStats();
      expect(stats, isA<Map<String, dynamic>>());
    });
  });
}
