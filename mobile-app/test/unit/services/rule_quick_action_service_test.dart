import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import '../../helpers/database_test_helper.dart';

/// F39 (Sprint 46): RuleQuickActionService is the extracted, screen-agnostic
/// rule-creation core shared by ResultsDisplayScreen's per-email quick-add
/// flow and the new cross-account "No rule" review screen's bulk actions.
/// These tests exercise the service directly (no widget/screen needed),
/// verifying it persists correctly and matches the pre-extraction behavior
/// documented in results_display_screen.dart's history (BUG-S39-1 rule-name
/// collisions, Issue #154 conflict removal).
void main() {
  late DatabaseTestHelper testHelper;
  late RuleSetProvider provider;
  late RuleQuickActionService service;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();

    final ruleStore = RuleDatabaseStore(testHelper.dbHelper);
    final safeSenderStore = SafeSenderDatabaseStore(testHelper.dbHelper);

    provider = RuleSetProvider();
    provider.initializeForTesting(
      databaseStore: ruleStore,
      safeSenderStore: safeSenderStore,
    );
    await provider.loadRules();
    await provider.loadSafeSenders();

    service = RuleQuickActionService(ruleProvider: provider);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('addSafeSender', () {
    test('exact type creates an anchored exact-email pattern', () async {
      final result = await service.addSafeSender(
        value: 'friend@trusted.com',
        type: 'exact',
        senderEmailForConflictCheck: 'friend@trusted.com',
      );

      expect(result.success, isTrue);
      expect(provider.safeSenders.safeSenders, hasLength(1));
      expect(
        provider.safeSenders.safeSenders.first,
        equals(r'^friend@trusted\.com$'),
      );
    });

    test('entireDomain type creates a subdomain-matching pattern', () async {
      final result = await service.addSafeSender(
        value: 'trusted.com',
        type: 'entireDomain',
        senderEmailForConflictCheck: 'someone@trusted.com',
      );

      expect(result.success, isTrue);
      expect(
        provider.safeSenders.safeSenders.first,
        equals(r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$'),
      );
    });

    test('unknown type returns a failure result without persisting', () async {
      final result = await service.addSafeSender(
        value: 'x@y.com',
        type: 'bogus',
        senderEmailForConflictCheck: 'x@y.com',
      );

      expect(result.success, isFalse);
      expect(provider.safeSenders.safeSenders, isEmpty);
    });

    test('empty value is rejected (would match every address) -- Copilot',
        () async {
      final result = await service.addSafeSender(
        value: '  ',
        type: 'entireDomain',
        senderEmailForConflictCheck: 'x@y.com',
      );
      expect(result.success, isFalse);
      expect(provider.safeSenders.safeSenders, isEmpty);
    });

    test('regex metacharacters in the address are escaped literally -- Copilot',
        () async {
      final result = await service.addSafeSender(
        value: 'bob+tag@x.com',
        type: 'exact',
        senderEmailForConflictCheck: 'bob+tag@x.com',
      );
      expect(result.success, isTrue);
      final pattern = provider.safeSenders.safeSenders.first;
      expect(pattern, r'^bob\+tag@x\.com$');
      final rx = RegExp(pattern);
      expect(rx.hasMatch('bob+tag@x.com'), isTrue);
      expect(rx.hasMatch('bobbbtag@x.com'), isFalse,
          reason: 'unescaped + would have made the b repeatable');
    });

    test('removes conflicting block rule when adding a safe sender (Issue #154)',
        () async {
      await service.createBlockRule(type: 'from', value: 'friend@trusted.com');
      expect(provider.rules.rules, hasLength(1));

      final result = await service.addSafeSender(
        value: 'friend@trusted.com',
        type: 'exact',
        senderEmailForConflictCheck: 'friend@trusted.com',
      );

      expect(result.success, isTrue);
      expect(result.conflictsRemoved, equals(1));
      expect(provider.rules.rules, isEmpty);
    });
  });

  group('createBlockRule', () {
    test('from type creates an exact-email block rule', () async {
      final result = await service.createBlockRule(
        type: 'from',
        value: 'spam@bad.com',
      );

      expect(result.success, isTrue);
      expect(provider.rules.rules, hasLength(1));
      expect(provider.rules.rules.first.conditions.header, isNotEmpty);
      expect(
        provider.rules.rules.first.conditions.header.first,
        equals(r'^spam@bad\.com$'),
      );
    });

    test('subject type does not require a conflict check email', () async {
      final result = await service.createBlockRule(
        type: 'subject',
        value: 'Win a prize',
      );

      expect(result.success, isTrue);
      expect(provider.rules.rules, hasLength(1));
      expect(provider.rules.rules.first.conditions.subject, isNotEmpty);
    });

    test(
        'distinct emails differing only by _ vs - produce distinct rule names (BUG-S39-1)',
        () async {
      final r1 = await service.createBlockRule(
        type: 'from',
        value: 'account_update@amazon.com',
      );
      final r2 = await service.createBlockRule(
        type: 'from',
        value: 'account-update@amazon.com',
      );

      expect(r1.success, isTrue);
      expect(r2.success, isTrue);
      expect(provider.rules.rules, hasLength(2));
      expect(
        provider.rules.rules.map((r) => r.name).toSet(),
        hasLength(2),
        reason: 'rule names must not collide for distinct email addresses',
      );
    });

    test('unknown type returns a failure result without persisting', () async {
      final result = await service.createBlockRule(type: 'bogus', value: 'x');

      expect(result.success, isFalse);
      expect(provider.rules.rules, isEmpty);
    });

    test('empty and degenerate values are rejected -- Copilot', () async {
      for (final bad in ['', '  ', '@', '@null']) {
        final result =
            await service.createBlockRule(type: 'entireDomain', value: bad);
        expect(result.success, isFalse, reason: 'value "$bad" must be rejected');
      }
      expect(provider.rules.rules, isEmpty);
    });

    test('removes conflicting safe sender when adding a block rule (Issue #154)',
        () async {
      await service.addSafeSender(
        value: 'spam@bad.com',
        type: 'exact',
        senderEmailForConflictCheck: 'spam@bad.com',
      );
      expect(provider.safeSenders.safeSenders, hasLength(1));

      final result = await service.createBlockRule(
        type: 'from',
        value: 'spam@bad.com',
        senderEmailForConflictCheck: 'spam@bad.com',
      );

      expect(result.success, isTrue);
      expect(result.conflictsRemoved, equals(1));
      expect(provider.safeSenders.safeSenders, isEmpty);
    });
  });
}
