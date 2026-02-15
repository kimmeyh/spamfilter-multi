import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/rule_conflict_detector.dart';

void main() {
  late RuleConflictDetector detector;

  setUp(() {
    detector = RuleConflictDetector();
  });

  EmailMessage createTestEmail({
    String from = 'spammer@spam.com',
    String subject = 'Buy cheap products',
    String body = 'Click here to buy now',
    Map<String, String>? headers,
  }) {
    return EmailMessage(
      id: 'test-1',
      from: from,
      subject: subject,
      body: body,
      headers: headers ?? {'From': from, 'Subject': subject},
      receivedDate: DateTime.now(),
      folderName: 'INBOX',
    );
  }

  Rule createTestRule({
    String name = 'TestRule',
    int executionOrder = 10,
    List<String> from = const [],
    List<String> subject = const [],
    List<String> body = const [],
    List<String> header = const [],
    bool delete = true,
    String? moveToFolder,
    bool enabled = true,
  }) {
    return Rule(
      name: name,
      enabled: enabled,
      isLocal: true,
      executionOrder: executionOrder,
      conditions: RuleConditions(
        type: 'OR',
        from: from,
        subject: subject,
        body: body,
        header: header,
      ),
      actions: RuleActions(
        delete: delete,
        moveToFolder: moveToFolder,
      ),
    );
  }

  group('RuleConflictDetector', () {
    group('No conflicts', () {
      test('returns empty list when no rules exist', () {
        final email = createTestEmail();
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 10,
          from: [r'@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: []),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, isEmpty);
      });

      test('returns empty list when existing rules do not match email', () {
        final email = createTestEmail(from: 'user@example.com');
        final existingRule = createTestRule(
          name: 'ExistingRule',
          executionOrder: 5,
          from: [r'@spam\.com$'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 10,
          from: [r'@example\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, isEmpty);
      });

      test('returns empty list when matching rule has lower priority', () {
        final email = createTestEmail(from: 'spammer@spam.com');
        final existingRule = createTestRule(
          name: 'ExistingRule',
          executionOrder: 20,
          from: [r'@spam\.com$'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 10,
          from: [r'@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, isEmpty);
      });

      test('returns empty list when matching rule is disabled', () {
        final email = createTestEmail(from: 'spammer@spam.com');
        final existingRule = createTestRule(
          name: 'DisabledRule',
          executionOrder: 5,
          from: [r'@spam\.com$'],
          enabled: false,
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 10,
          from: [r'@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, isEmpty);
      });
    });

    group('Rule-to-rule conflicts', () {
      test('detects conflict when higher-priority rule matches email', () {
        final email = createTestEmail(from: 'spammer@spam.com');
        final existingRule = createTestRule(
          name: 'BlockSpam',
          executionOrder: 5,
          from: [r'@spam\.com$'],
        );
        final newRule = createTestRule(
          name: 'AllowMarketing',
          executionOrder: 20,
          from: [r'spammer@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.conflictingRuleName, 'BlockSpam');
        expect(conflicts.first.conflictingOrder, 5);
        expect(conflicts.first.newRuleOrder, 20);
        expect(conflicts.first.isSafeSenderConflict, isFalse);
        expect(conflicts.first.conflictingAction, 'Delete');
      });

      test('detects multiple conflicts from multiple rules', () {
        final email = createTestEmail(
          from: 'spammer@spam.com',
          subject: 'Buy cheap products',
        );
        final rule1 = createTestRule(
          name: 'BlockDomain',
          executionOrder: 5,
          from: [r'@spam\.com$'],
        );
        final rule2 = createTestRule(
          name: 'BlockSubject',
          executionOrder: 10,
          subject: ['cheap'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 30,
          from: [r'spammer@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [rule1, rule2]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, hasLength(2));
        expect(conflicts[0].conflictingRuleName, 'BlockDomain');
        expect(conflicts[1].conflictingRuleName, 'BlockSubject');
      });

      test('describes move action correctly', () {
        final email = createTestEmail(from: 'spammer@spam.com');
        final existingRule = createTestRule(
          name: 'MoveToJunk',
          executionOrder: 5,
          from: [r'@spam\.com$'],
          delete: false,
          moveToFolder: 'Junk Email',
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 20,
          from: [r'spammer@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.conflictingAction, 'Move to Junk Email');
      });
    });

    group('Safe sender conflicts', () {
      test('detects safe sender conflict', () {
        final email = createTestEmail(from: 'user@trusted.com');
        final newRule = createTestRule(
          name: 'BlockTrusted',
          executionOrder: 10,
          from: [r'@trusted\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: []),
          safeSenderList: SafeSenderList(
            safeSenders: [r'^[^@\s]+@trusted\.com$'],
          ),
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.isSafeSenderConflict, isTrue);
        expect(conflicts.first.conflictingRuleName, 'Safe Sender');
        expect(conflicts.first.conflictingAction, 'Allow (whitelist)');
      });

      test('safe sender conflict appears before rule conflicts', () {
        final email = createTestEmail(from: 'user@trusted.com');
        final existingRule = createTestRule(
          name: 'SomeRule',
          executionOrder: 5,
          from: [r'@trusted\.com$'],
        );
        final newRule = createTestRule(
          name: 'BlockTrusted',
          executionOrder: 20,
          from: [r'@trusted\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(
            safeSenders: [r'^[^@\s]+@trusted\.com$'],
          ),
        );

        // Safe sender conflict is first, then rule conflict
        expect(conflicts.length, greaterThanOrEqualTo(2));
        expect(conflicts.first.isSafeSenderConflict, isTrue);
        expect(conflicts[1].isSafeSenderConflict, isFalse);
      });

      test('no safe sender conflict when pattern does not match', () {
        final email = createTestEmail(from: 'user@other.com');
        final newRule = createTestRule(
          name: 'BlockOther',
          executionOrder: 10,
          from: [r'@other\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: []),
          safeSenderList: SafeSenderList(
            safeSenders: [r'^[^@\s]+@trusted\.com$'],
          ),
        );

        expect(conflicts, isEmpty);
      });
    });

    group('Exception handling', () {
      test('skips existing rule if exception matches email', () {
        final email = createTestEmail(from: 'user@spam.com');
        final existingRule = Rule(
          name: 'BlockSpamWithException',
          enabled: true,
          isLocal: true,
          executionOrder: 5,
          conditions: RuleConditions(type: 'OR', from: [r'@spam\.com$']),
          actions: RuleActions(delete: true),
          exceptions: RuleExceptions(
            from: [r'^user@spam\.com$'],
          ),
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 20,
          from: [r'user@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, isEmpty);
      });
    });

    group('RuleConflict model', () {
      test('description for safe sender conflict', () {
        final conflict = RuleConflict(
          conflictingRuleName: 'Safe Sender',
          conflictingOrder: 0,
          newRuleOrder: 10,
          conflictingAction: 'Allow (whitelist)',
          isSafeSenderConflict: true,
          conflictingPattern: r'^user@trusted\.com$',
        );

        expect(conflict.description, contains('safe sender'));
        expect(conflict.description, contains('always take priority'));
      });

      test('description for rule conflict', () {
        final conflict = RuleConflict(
          conflictingRuleName: 'BlockSpam',
          conflictingOrder: 5,
          newRuleOrder: 20,
          conflictingAction: 'Delete',
          conflictingPattern: r'@spam\.com$',
        );

        expect(conflict.description, contains('BlockSpam'));
        expect(conflict.description, contains('order=5'));
        expect(conflict.description, contains('order=20'));
        expect(conflict.description, contains('Delete'));
      });
    });

    group('Subject and body matching', () {
      test('detects conflict on subject pattern match', () {
        final email = createTestEmail(
          from: 'user@example.com',
          subject: 'Buy cheap products now',
        );
        final existingRule = createTestRule(
          name: 'BlockCheap',
          executionOrder: 5,
          subject: ['cheap'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 20,
          from: [r'@example\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.conflictingRuleName, 'BlockCheap');
      });

      test('detects conflict on body pattern match', () {
        final email = createTestEmail(
          from: 'user@example.com',
          body: 'Click this suspicious link http://malware.com',
        );
        final existingRule = createTestRule(
          name: 'BlockMalware',
          executionOrder: 5,
          body: [r'malware\.com'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 20,
          from: [r'@example\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.conflictingRuleName, 'BlockMalware');
      });
    });

    group('Same execution order', () {
      test('does not flag rule with same execution order as conflict', () {
        final email = createTestEmail(from: 'spammer@spam.com');
        final existingRule = createTestRule(
          name: 'ExistingRule',
          executionOrder: 10,
          from: [r'@spam\.com$'],
        );
        final newRule = createTestRule(
          name: 'NewRule',
          executionOrder: 10,
          from: [r'spammer@spam\.com$'],
        );

        final conflicts = detector.detectConflicts(
          email: email,
          newRule: newRule,
          ruleSet: RuleSet(version: '1.0', settings: {}, rules: [existingRule]),
          safeSenderList: SafeSenderList(safeSenders: []),
        );

        // Same order is not a conflict (only strictly lower order counts)
        expect(conflicts, isEmpty);
      });
    });
  });
}
