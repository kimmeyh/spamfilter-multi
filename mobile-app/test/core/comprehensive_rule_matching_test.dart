import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';

/// Comprehensive RuleEvaluator test suite for complex scenarios
///
/// Tests advanced rule matching scenarios including:
/// - Multi-condition rules (AND/OR logic)
/// - Exception handling
/// - Priority and execution order
/// - Edge cases and boundary conditions
/// - Safe sender interactions with rules
/// - Pattern matching complexity
void main() {
  late RuleEvaluator evaluator;
  late PatternCompiler compiler;

  setUp(() {
    compiler = PatternCompiler();
  });

  group('Multi-Condition Rules with AND Logic', () {
    test('should match email when all AND conditions are met', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MultiConditionAND',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'AND',
              from: ['@spam\\.com\$'],
              subject: ['urgent'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches both conditions
      final email = EmailMessage(
        id: 'msg-1',
        from: 'spammer@spam.com',
        subject: 'URGENT: Act Now',
        body: 'Limited offer',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('MultiConditionAND'));
    });

    test('should not match email when only one AND condition is met', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MultiConditionAND',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'AND',
              from: ['@spam\\.com\$'],
              subject: ['urgent'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches from but not subject
      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@spam.com',
        subject: 'Newsletter',
        body: 'Regular content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should match email with three AND conditions all met', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'TripleConditionAND',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'AND',
              from: ['@phishing\\.net\$'],
              subject: ['verify.*account'],
              body: ['click.*link'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'admin@phishing.net',
        subject: 'Verify your account now',
        body: 'Please click this link to verify your account',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('TripleConditionAND'));
    });
  });

  group('Multi-Condition Rules with OR Logic', () {
    test('should match email when any OR condition is met', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MultiConditionOR',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@spam\\.com\$'],
              subject: ['viagra', 'cialis'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches subject but not from
      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@legitimate.com',
        subject: 'Buy viagra online',
        body: 'Advertisement',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('MultiConditionOR'));
    });

    test('should match email when multiple OR conditions are met', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MultiConditionOR',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@spam\\.com\$'],
              subject: ['urgent'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches both conditions
      final email = EmailMessage(
        id: 'msg-1',
        from: 'admin@spam.com',
        subject: 'URGENT: Important Notice',
        body: 'Act now',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('MultiConditionOR'));
    });
  });

  group('Exception Handling', () {
    test('should skip rule when exception matches', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockDomainWithException',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            exceptions: RuleExceptions(
              from: ['^trusted@example\\.com\$'],
            ),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches condition but also matches exception
      final email = EmailMessage(
        id: 'msg-1',
        from: 'trusted@example.com',
        subject: 'Important notification',
        body: 'Please read this',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should apply rule when exception does not match', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockDomainWithException',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            exceptions: RuleExceptions(
              from: ['^trusted@example\\.com\$'],
            ),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches condition and does not match exception
      final email = EmailMessage(
        id: 'msg-1',
        from: 'spammer@example.com',
        subject: 'Spam message',
        body: 'Buy now',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockDomainWithException'));
    });

    test('should handle multiple exception patterns', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockWithMultipleExceptions',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['offer', 'deal', 'discount'],
            ),
            actions: RuleActions(delete: true),
            exceptions: RuleExceptions(
              from: ['^newsletter@store\\.com\$', '^sales@trusted\\.com\$'],
            ),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email from first exception
      final email1 = EmailMessage(
        id: 'msg-1',
        from: 'newsletter@store.com',
        subject: 'Special offer for you',
        body: 'Limited time deal',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result1 = await evaluator.evaluate(email1);
      expect(result1.shouldDelete, isFalse);

      // Email from second exception
      final email2 = EmailMessage(
        id: 'msg-2',
        from: 'sales@trusted.com',
        subject: 'Discount code inside',
        body: 'Get 50% off',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result2 = await evaluator.evaluate(email2);
      expect(result2.shouldDelete, isFalse);
    });
  });

  group('Rule Execution Order and Priority', () {
    test('should evaluate rules in execution order', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'LowPriorityRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: false, moveToFolder: 'Junk'),
            executionOrder: 20,
          ),
          Rule(
            name: 'HighPriorityRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Email matches both rules
      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: 'Test',
        body: 'Content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('HighPriorityRule'));
    });

    test('should stop at first matching rule', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'FirstRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['test'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
          Rule(
            name: 'SecondRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['test'],
            ),
            actions: RuleActions(delete: false, moveToFolder: 'Archive'),
            executionOrder: 20,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: 'Test message',
        body: 'Content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.shouldMove, isFalse);
      expect(result.matchedRule, equals('FirstRule'));
    });
  });

  group('Safe Sender Integration', () {
    test('should bypass rules for safe senders', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'DeleteAll',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@.*\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(
          safeSenders: ['^trusted@company\\.com\$'],
        ),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'trusted@company.com',
        subject: 'Important message',
        body: 'Please read',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.isSafeSender, isTrue);
      expect(result.shouldDelete, isFalse);
    });

    test('should apply rules to non-safe senders', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockSpam',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@spam\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(
          safeSenders: ['^trusted@company\\.com\$'],
        ),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'spammer@spam.com',
        subject: 'Spam message',
        body: 'Buy now',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.isSafeSender, isFalse);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockSpam'));
    });
  });

  group('Complex Pattern Matching', () {
    test('should match complex regex patterns in subject', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'ComplexSubjectPattern',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['^re:\\s*\\[external\\].*urgent'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'external@example.com',
        subject: 'RE: [EXTERNAL] URGENT: Action Required',
        body: 'Click here',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('ComplexSubjectPattern'));
    });

    test('should match domain patterns with subdomains', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockSubdomains',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@(?:[a-z0-9-]+\\.)*spam\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      // Test subdomain matching
      final emails = [
        'user@spam.com',
        'user@mail.spam.com',
        'user@secure.mail.spam.com',
      ];

      for (final from in emails) {
        final email = EmailMessage(
          id: 'msg-$from',
          from: from,
          subject: 'Test',
          body: 'Content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = await evaluator.evaluate(email);
        expect(result.shouldDelete, isTrue,
            reason: 'Should match $from');
        expect(result.matchedRule, equals('BlockSubdomains'));
      }
    });

    test('should match multiple patterns in same condition list', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MultiplePatterns',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['viagra', 'cialis', 'pills', 'pharmacy'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final subjects = [
        'Buy viagra now',
        'Cheap cialis online',
        'Diet pills for sale',
        'Online pharmacy store',
      ];

      for (final subject in subjects) {
        final email = EmailMessage(
          id: 'msg-$subject',
          from: 'spammer@example.com',
          subject: subject,
          body: 'Advertisement',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = await evaluator.evaluate(email);
        expect(result.shouldDelete, isTrue,
            reason: 'Should match "$subject"');
        expect(result.matchedRule, equals('MultiplePatterns'));
      }
    });
  });

  group('Edge Cases and Boundary Conditions', () {
    test('should handle empty rule set', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: 'Test',
        body: 'Content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.shouldMove, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should handle disabled rules', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'DisabledRule',
            enabled: false,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@spam\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@spam.com',
        subject: 'Test',
        body: 'Content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should handle empty email fields', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'TestRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['spam'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: '',
        body: '',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should handle rule with empty condition lists', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'EmptyConditions',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: [],
              subject: [],
              body: [],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: 'Test',
        body: 'Content',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, isEmpty);
    });

    test('should handle case-insensitive matching', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'CaseInsensitive',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['spam'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final subjects = ['spam', 'SPAM', 'Spam', 'SpAm'];

      for (final subject in subjects) {
        final email = EmailMessage(
          id: 'msg-$subject',
          from: 'user@example.com',
          subject: subject,
          body: 'Content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = await evaluator.evaluate(email);
        expect(result.shouldDelete, isTrue,
            reason: 'Should match case-insensitive "$subject"');
      }
    });

    test('should handle whitespace in email fields', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'WhitespaceTest',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['test'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: '  user@example.com  ',
        subject: '  test  ',
        body: '  content  ',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
    });
  });

  group('Header Matching', () {
    test('should match custom headers', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'SpamHeaderRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              header: ['x-spam-status:yes'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'user@example.com',
        subject: 'Test',
        body: 'Content',
        headers: {'X-Spam-Status': 'Yes'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('SpamHeaderRule'));
    });

    test('should match from header via header patterns', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'FromHeaderRule',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              header: ['@spam\\.com\$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'spammer@spam.com',
        subject: 'Test',
        body: 'Content',
        headers: {'From': 'spammer@spam.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('FromHeaderRule'));
    });
  });

  group('Move to Folder Actions', () {
    test('should mark email for move to specific folder', () async {
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'MoveToArchive',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              subject: ['newsletter'],
            ),
            actions: RuleActions(delete: false, moveToFolder: 'Archive'),
            executionOrder: 10,
          ),
        ],
      );

      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final email = EmailMessage(
        id: 'msg-1',
        from: 'newsletter@company.com',
        subject: 'Monthly newsletter',
        body: 'Updates',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await evaluator.evaluate(email);
      expect(result.shouldMove, isTrue);
      expect(result.targetFolder, equals('Archive'));
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, equals('MoveToArchive'));
    });
  });
}
