import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart'
    show Rule, RuleConditions, RuleActions;
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

  group('MT-2 (Sprint 50): idempotent quick actions', () {
    test(
        'createBlockRule for an already-covered domain reports success with '
        'alreadyExisted and the EXISTING rule as delta -- not a UNIQUE '
        'constraint failure', () async {
      final first = await service.createBlockRule(
        type: 'entireDomain',
        value: 'spam.example',
        senderEmailForConflictCheck: 'a@spam.example',
      );
      expect(first.success, isTrue);
      expect(first.alreadyExisted, isFalse);

      final second = await service.createBlockRule(
        type: 'entireDomain',
        value: 'spam.example',
        senderEmailForConflictCheck: 'b@spam.example',
      );

      expect(second.success, isTrue,
          reason: 'the sender is covered -- the caller must mark the item '
              'resolved instead of surfacing a failure (Harold, Sprint 50 '
              'manual validation)');
      expect(second.alreadyExisted, isTrue);
      expect(second.createdRule, isNotNull);
      expect(second.createdRule!.name, equals(first.createdRule!.name));
      // Exactly ONE rule persisted.
      expect(
        provider.rules.rules.where((r) => r.name == first.createdRule!.name),
        hasLength(1),
      );
    });

    test(
        'addSafeSender for an already-present pattern reports success with '
        'alreadyExisted and does not duplicate the pattern', () async {
      final first = await service.addSafeSender(
        value: 'trusted.com',
        type: 'entireDomain',
        senderEmailForConflictCheck: 'a@trusted.com',
      );
      expect(first.success, isTrue);

      final second = await service.addSafeSender(
        value: 'trusted.com',
        type: 'entireDomain',
        senderEmailForConflictCheck: 'b@trusted.com',
      );

      expect(second.success, isTrue);
      expect(second.alreadyExisted, isTrue);
      expect(second.createdSafeSenderPattern,
          equals(first.createdSafeSenderPattern));
      expect(provider.safeSenders.safeSenders, hasLength(1));
    });

    // Copilot review (PR #278): the idempotent fast-path must still run
    // conflict resolution. An existing safe sender does not imply the
    // conflicting block rules are gone -- rules can be imported/restored
    // after the safe sender was created, and a surviving block rule keeps
    // deleting mail the user has explicitly whitelisted.
    test(
        'addSafeSender fast-path still removes conflicting block rules '
        'when the safe sender already exists (Copilot PR #278)', () async {
      // Safe sender exists first...
      final first = await service.addSafeSender(
        value: 'spam@bad.com',
        type: 'exact',
        senderEmailForConflictCheck: 'spam@bad.com',
      );
      expect(first.success, isTrue);

      // ...then a conflicting block rule appears (import / restore / manual).
      await provider.addRule(Rule(
        name: 'Block_spam@bad.com',
        enabled: true,
        isLocal: true,
        executionOrder: 40,
        conditions: RuleConditions(type: 'OR', header: [r'^spam@bad\.com$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'exact_email',
        sourceDomain: 'spam@bad.com',
      ));
      expect(provider.rules.rules.where((r) => r.name == 'Block_spam@bad.com'),
          hasLength(1));

      // Re-running the quick action hits the idempotent path -- and must
      // still clean up the conflict.
      final second = await service.addSafeSender(
        value: 'spam@bad.com',
        type: 'exact',
        senderEmailForConflictCheck: 'spam@bad.com',
      );

      expect(second.success, isTrue);
      expect(second.alreadyExisted, isTrue);
      expect(second.conflictsRemoved, greaterThan(0),
          reason: 'the fast-path must report the cleanup it performed');
      expect(provider.rules.rules.where((r) => r.name == 'Block_spam@bad.com'),
          isEmpty,
          reason: 'the conflicting block rule must be gone, otherwise the '
              'whitelisted sender keeps being deleted');
    });

    // F128 (Copilot review round 4, PR #278): the provider's rules/safeSenders
    // getters return EMPTY collections when the cache is unloaded, and
    // addRule/addSafeSender used to no-op silently in that state -- so the
    // service could report success having persisted nothing, and the
    // idempotency check could miss an existing rule. Both are now guarded.
    test(
        'createBlockRule against an UNLOADED provider persists the rule '
        'instead of silently no-oping (F128)', () async {
      // A fresh provider that has never had loadRules() called.
      final unloaded = RuleSetProvider();
      unloaded.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      expect(unloaded.isRulesLoaded, isFalse,
          reason: 'precondition: the cache must start unloaded');

      final unloadedService = RuleQuickActionService(ruleProvider: unloaded);
      final result = await unloadedService.createBlockRule(
        type: 'entireDomain',
        value: 'unloaded.example',
        senderEmailForConflictCheck: 'x@unloaded.example',
      );

      expect(result.success, isTrue);
      expect(unloaded.isRulesLoaded, isTrue,
          reason: 'the service must load the cache before deciding');

      // The rule must actually be in the DATABASE, not just the cache.
      final reloaded = RuleSetProvider();
      reloaded.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await reloaded.loadRules();
      expect(
        reloaded.rules.rules
            .where((r) => r.name == 'Block_EntireDomain_unloaded.example'),
        hasLength(1),
        reason: 'reporting success while persisting nothing is the F128 bug',
      );
    });

    test(
        'addSafeSender against an UNLOADED provider persists the pattern '
        'instead of silently no-oping (F128)', () async {
      final unloaded = RuleSetProvider();
      unloaded.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      expect(unloaded.isSafeSendersLoaded, isFalse);

      final unloadedService = RuleQuickActionService(ruleProvider: unloaded);
      final result = await unloadedService.addSafeSender(
        value: 'friend@unloaded.example',
        type: 'exact',
        senderEmailForConflictCheck: 'friend@unloaded.example',
      );

      expect(result.success, isTrue);

      final reloaded = RuleSetProvider();
      reloaded.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await reloaded.loadSafeSenders();
      expect(reloaded.safeSenders.safeSenders,
          contains(r'^friend@unloaded\.example$'));
    });

    test(
        'createBlockRule fast-path still removes conflicting safe senders '
        'when the rule already exists (Copilot PR #278)', () async {
      final first = await service.createBlockRule(
        type: 'entireDomain',
        value: 'spam.example',
        senderEmailForConflictCheck: 'a@spam.example',
      );
      expect(first.success, isTrue);

      // A conflicting safe sender appears afterwards. Safe senders WIN over
      // block rules in RuleEvaluator, so this would silently defeat the rule.
      await provider.addSafeSender(r'^a@spam\.example$');
      expect(provider.safeSenders.safeSenders, isNotEmpty);

      final second = await service.createBlockRule(
        type: 'entireDomain',
        value: 'spam.example',
        senderEmailForConflictCheck: 'a@spam.example',
      );

      expect(second.success, isTrue);
      expect(second.alreadyExisted, isTrue);
      expect(second.conflictsRemoved, greaterThan(0));
      expect(provider.safeSenders.safeSenders, isEmpty,
          reason: 'the conflicting safe sender must be removed, otherwise it '
              'overrides the block rule the user just re-applied');
    });
  });
}
