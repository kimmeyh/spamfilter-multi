import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/rule_conflict_resolver.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/providers/rule_set_provider.dart';

/// Minimal in-memory RuleSetProvider for testing conflict resolution.
///
/// Provides direct control over rules and safe senders without database
/// dependencies. Uses the real RuleSetProvider API surface that
/// RuleConflictResolver depends on.
class TestableRuleSetProvider extends RuleSetProvider {
  final List<Rule> _testRules = [];
  final List<String> _testSafeSenders = [];
  final List<String> removedRules = [];
  final List<String> removedSafeSenders = [];

  void addTestRule(Rule rule) {
    _testRules.add(rule);
  }

  void addTestSafeSender(String pattern) {
    _testSafeSenders.add(pattern);
  }

  @override
  RuleSet get rules => RuleSet(
    version: '1.0',
    settings: {},
    rules: List.from(_testRules),
  );

  @override
  SafeSenderList get safeSenders => SafeSenderList(
    safeSenders: List.from(_testSafeSenders),
  );

  @override
  Future<void> removeRule(String ruleName) async {
    removedRules.add(ruleName);
    _testRules.removeWhere((r) => r.name == ruleName);
  }

  @override
  Future<void> removeSafeSender(String pattern) async {
    removedSafeSenders.add(pattern);
    _testSafeSenders.remove(pattern);
  }
}

Rule _createRule({
  required String name,
  List<String> from = const [],
  List<String> header = const [],
  List<String> subject = const [],
}) {
  return Rule(
    name: name,
    enabled: true,
    isLocal: true,
    executionOrder: 100,
    conditions: RuleConditions(
      type: 'OR',
      from: from,
      subject: subject,
      header: header,
    ),
    actions: RuleActions(delete: true),
  );
}

void main() {
  late RuleConflictResolver resolver;
  late TestableRuleSetProvider provider;

  setUp(() {
    resolver = RuleConflictResolver();
    provider = TestableRuleSetProvider();
  });

  group('removeConflictingSafeSenders', () {
    test('removes exact email safe sender when creating block rule', () async {
      provider.addTestSafeSender(r'^spammer@spam\.com$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'spammer@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsFound, 1);
      expect(result.conflictsRemoved, 1);
      expect(provider.removedSafeSenders, [r'^spammer@spam\.com$']);
    });

    test('removes exact domain safe sender when creating block rule', () async {
      provider.addTestSafeSender(r'^[^@\s]+@spam\.com$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
    });

    test('removes entire domain safe sender when creating block rule', () async {
      provider.addTestSafeSender(r'^[^@\s]+@(?:[a-z0-9-]+\.)*spam\.com$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'user@newsletter.spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
    });

    test('does not remove non-matching safe senders', () async {
      provider.addTestSafeSender(r'^friendly@good\.com$');
      provider.addTestSafeSender(r'^[^@\s]+@safe\.org$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'spammer@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.conflictsRemoved, 0);
      expect(provider.removedSafeSenders, isEmpty);
    });

    test('removes multiple matching safe senders', () async {
      // Both patterns match the same email
      provider.addTestSafeSender(r'^user@notification\.circle\.so$');
      provider.addTestSafeSender(r'^[^@\s]+@(?:[a-z0-9-]+\.)*circle\.so$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'user@notification.circle.so',
        ruleProvider: provider,
      );

      expect(result.conflictsFound, 2);
      expect(result.conflictsRemoved, 2);
    });

    test('returns empty result when no safe senders exist', () async {
      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'anyone@example.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.conflictsFound, 0);
    });

    test('reproduces Issue #154: circle.so safe sender blocks block rule', () async {
      // User-reported reproduction case: no-reply@notification.circle.so
      // User had safe sender for entire domain, then tried to block
      provider.addTestSafeSender(r'^[^@\s]+@(?:[a-z0-9-]+\.)*circle\.so$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'no-reply@notification.circle.so',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
      expect(provider.removedSafeSenders.first, r'^[^@\s]+@(?:[a-z0-9-]+\.)*circle\.so$');
    });

    test('handles case-insensitive email matching', () async {
      provider.addTestSafeSender(r'^User@Example\.COM$');

      final result = await resolver.removeConflictingSafeSenders(
        emailAddress: 'user@example.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
    });
  });

  group('removeConflictingRules', () {
    test('removes block rule with from condition when adding safe sender', () async {
      provider.addTestRule(_createRule(
        name: 'Block_spam_com',
        from: [r'@spam\.com$'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
      expect(provider.removedRules, ['Block_spam_com']);
    });

    test('removes block rule with header condition when adding safe sender', () async {
      provider.addTestRule(_createRule(
        name: 'Block_header',
        header: [r'@spam\.com$'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
    });

    test('does not remove rules with only subject conditions', () async {
      provider.addTestRule(_createRule(
        name: 'Block_subject',
        subject: ['buy cheap'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.conflictsRemoved, 0);
    });

    test('does not remove non-matching rules', () async {
      provider.addTestRule(_createRule(
        name: 'Block_other',
        from: [r'@other\.com$'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.conflictsRemoved, 0);
    });

    test('removes multiple matching rules', () async {
      provider.addTestRule(_createRule(
        name: 'Block_exact',
        from: [r'^user@spam\.com$'],
      ));
      provider.addTestRule(_createRule(
        name: 'Block_domain',
        header: [r'@spam\.com$'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'user@spam.com',
        ruleProvider: provider,
      );

      expect(result.conflictsFound, 2);
      expect(result.conflictsRemoved, 2);
    });

    test('returns empty result when no rules exist', () async {
      final result = await resolver.removeConflictingRules(
        emailAddress: 'anyone@example.com',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isFalse);
      expect(result.conflictsFound, 0);
    });

    test('handles entire domain rule pattern', () async {
      provider.addTestRule(_createRule(
        name: 'Block_EntireDomain_circle_so',
        header: [r'@(?:[a-z0-9-]+\.)*circle\.so$'],
      ));

      final result = await resolver.removeConflictingRules(
        emailAddress: 'no-reply@notification.circle.so',
        ruleProvider: provider,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsRemoved, 1);
    });
  });

  group('ConflictResolutionResult', () {
    test('empty result has no conflicts', () {
      expect(ConflictResolutionResult.empty.hasConflicts, isFalse);
      expect(ConflictResolutionResult.empty.conflictsFound, 0);
      expect(ConflictResolutionResult.empty.conflictsRemoved, 0);
    });
  });
}
