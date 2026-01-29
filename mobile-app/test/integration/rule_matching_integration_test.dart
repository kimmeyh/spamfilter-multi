import 'package:flutter_test/flutter_test.dart';

import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';

/// Integration tests for rule matching with test emails
///
/// Tests all regex pattern types:
/// 1. Exact email match (^user@domain\\.com$)
/// 2. Domain match (@(?:[a-z0-9-]+\\.)*domain\\.com$)
/// 3. Subdomain match
/// 4. Subject patterns
/// 5. Header patterns
/// 6. Body patterns
/// 7. AND/OR conditions
/// 8. Exceptions
/// 9. Safe sender whitelist
void main() {
  group('Rule Matching Integration Tests - Regex Patterns', () {
    late PatternCompiler compiler;

    setUp(() {
      compiler = PatternCompiler();
    });

    EmailMessage createTestEmail({
      String from = 'test@example.com',
      String subject = 'Test Subject',
      String body = 'Test Body',
      Map<String, String>? headers,
    }) {
      return EmailMessage(
        id: '1',
        from: from,
        subject: subject,
        body: body,
        headers: headers ?? {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );
    }

    group('Exact Email Match Patterns', () {
      test('Matches exact email address', () async {
        // Arrange: Rule with exact email pattern
        final rule = Rule(
          name: 'ExactEmailRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['^spammer@example\\.com\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Create test email
        final email = createTestEmail(from: 'spammer@example.com');
        final result = await evaluator.evaluate(email);

        // Assert: Rule matches
        expect(result.shouldDelete, isTrue);
        expect(result.matchedRule, equals('ExactEmailRule'));
      });

      test('Does not match different email in same domain', () async {
        // Arrange
        final rule = Rule(
          name: 'ExactEmailRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['^spammer@example\\.com\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Different user, same domain
        final email = createTestEmail(from: 'legitimate@example.com');
        final result = await evaluator.evaluate(email);

        // Assert: No match
        expect(result.shouldDelete, isFalse);
        expect(result.shouldMove, isFalse);
      });
    });

    group('Domain Match Patterns', () {
      test('Matches domain and all subdomains', () async {
        // Arrange: Domain pattern
        final rule = Rule(
          name: 'DomainRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@(?:[a-z0-9-]+\\.)*spam\\.com\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Test emails
        final testCases = [
          'user@spam.com',                    // Base domain
          'user@mail.spam.com',               // Subdomain
          'user@newsletter.mail.spam.com',    // Deep subdomain
        ];

        for (final from in testCases) {
          // Act
          final email = createTestEmail(from: from);
          final result = await evaluator.evaluate(email);

          // Assert
          expect(
            result.shouldDelete,
            isTrue,
            reason: 'Should match: $from',
          );
        }
      });

      test('Does not match different domain', () async {
        // Arrange
        final rule = Rule(
          name: 'DomainRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@(?:[a-z0-9-]+\\.)*spam\\.com\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act
        final email = createTestEmail(from: 'user@different.com');
        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isFalse);
      });
    });

    group('Subject Pattern Matching', () {
      test('Matches subject with regex pattern', () async {
        // Arrange: Subject pattern (starts with "urgent")
        final rule = Rule(
          name: 'UrgentSubjectRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            subject: ['^urgent.*\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Test subjects
        final matchingSubjects = [
          'urgent: please respond',
          'urgent action required',
          'urgent',
        ];

        for (final subject in matchingSubjects) {
          // Act
          final email = createTestEmail(subject: subject);
          final result = await evaluator.evaluate(email);

          // Assert
          expect(
            result.shouldDelete,
            isTrue,
            reason: 'Should match: $subject',
          );
        }
      });

      test('Does not match subject without pattern', () async {
        // Arrange
        final rule = Rule(
          name: 'UrgentSubjectRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            subject: ['^urgent.*\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Subject without "urgent"
        final email = createTestEmail(subject: 'normal message');
        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isFalse);
      });
    });

    group('Header Pattern Matching', () {
      test('Matches custom header pattern', () async {
        // Arrange: Header pattern
        final rule = Rule(
          name: 'SpamHeaderRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            header: ['^X-Spam-Flag: YES\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Email with spam header
        final email = createTestEmail(
          headers: {
            'X-Spam-Flag': 'YES',
            'X-Spam-Score': '9.5',
          },
        );

        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isTrue);
        expect(result.matchedRule, equals('SpamHeaderRule'));
      });
    });

    group('Body Pattern Matching', () {
      test('Matches body content pattern', () async {
        // Arrange: Body pattern
        final rule = Rule(
          name: 'SuspiciousBodyRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            body: ['click here.*prize'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act
        final email = createTestEmail(
          subject: 'You won!',
          body: 'Dear user, click here to claim your prize!',
        );

        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isTrue);
      });
    });

    group('AND Condition Matching', () {
      test('Matches when all AND conditions are met', () async {
        // Arrange: AND rule (must match subject AND from)
        final rule = Rule(
          name: 'ANDRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'AND',
            from: ['@spam\\.com\$'],
            subject: ['^promotional.*\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Email matching both conditions
        final email = createTestEmail(
          from: 'newsletter@spam.com',
          subject: 'promotional offer',
          body: 'Buy now!',
        );

        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isTrue);
      });

      test('Does not match when only one AND condition is met', () async {
        // Arrange
        final rule = Rule(
          name: 'ANDRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'AND',
            from: ['@spam\\.com\$'],
            subject: ['^promotional.*\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Only subject matches
        final email = createTestEmail(
          from: 'legit@company.com',
          subject: 'promotional offer',
          body: 'Buy now!',
        );

        final result = await evaluator.evaluate(email);

        // Assert: No match
        expect(result.shouldDelete, isFalse);
      });
    });

    group('OR Condition Matching', () {
      test('Matches when any OR condition is met', () async {
        // Arrange: OR rule
        final rule = Rule(
          name: 'ORRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@spam\\.com\$'],
            subject: ['^winner.*\$'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Test cases: Each matches one OR condition
        final testEmails = [
          createTestEmail(from: 'user@spam.com', subject: 'normal subject'),
          createTestEmail(from: 'user@legit.com', subject: 'winner announcement'),
        ];

        for (final email in testEmails) {
          // Act
          final result = await evaluator.evaluate(email);

          // Assert
          expect(
            result.shouldDelete,
            isTrue,
            reason: 'Should match: ${email.from} - ${email.subject}',
          );
        }
      });
    });

    group('Exception Handling', () {
      test('Rule does not match when exception is met', () async {
        // Arrange: Rule with exception
        final rule = Rule(
          name: 'ExceptionRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@marketing\\.com\$'],
          ),
          actions: RuleActions(delete: true),
          exceptions: RuleExceptions(
            subject: ['^important.*\$'],
          ),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Email matches condition but also exception
        final email = createTestEmail(
          from: 'user@marketing.com',
          subject: 'important announcement',
        );

        final result = await evaluator.evaluate(email);

        // Assert: Exception prevents match
        expect(result.shouldDelete, isFalse);
      });

      test('Rule matches when exception is not met', () async {
        // Arrange
        final rule = Rule(
          name: 'ExceptionRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@marketing\\.com\$'],
          ),
          actions: RuleActions(delete: true),
          exceptions: RuleExceptions(
            subject: ['^important.*\$'],
          ),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: No exception match
        final email = createTestEmail(
          from: 'user@marketing.com',
          subject: 'promotional offer',
        );

        final result = await evaluator.evaluate(email);

        // Assert: Rule matches
        expect(result.shouldDelete, isTrue);
      });
    });

    group('Safe Sender Whitelist', () {
      test('Safe sender bypasses all rules', () async {
        // Arrange: Rule that would delete
        final rule = Rule(
          name: 'DeleteRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['@.*\\.com\$'], // Match all .com domains
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        // Safe sender list
        final safeSenders = SafeSenderList(
          safeSenders: ['^trusted@company\\.com\$'],
        );

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act: Email from safe sender
        final email = createTestEmail(from: 'trusted@company.com');
        final result = await evaluator.evaluate(email);

        // Assert: Safe sender bypasses delete rule
        expect(result.isSafeSender, isTrue);
        expect(result.shouldDelete, isFalse);
      });

      test('Safe sender domain pattern matches all addresses in domain', () async {
        // Arrange
        final rule = Rule(
          name: 'DeleteRule',
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            from: ['.*'],
          ),
          actions: RuleActions(delete: true),
        );

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [rule],
        );

        // Domain safe sender pattern
        final safeSenders = SafeSenderList(
          safeSenders: ['^[^@\\s]+@(?:[a-z0-9-]+\\.)*trusted\\.com\$'],
        );

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Test emails
        final testEmails = [
          'user1@trusted.com',
          'user2@mail.trusted.com',
          'admin@subdomain.trusted.com',
        ];

        for (final from in testEmails) {
          // Act
          final email = createTestEmail(from: from);
          final result = await evaluator.evaluate(email);

          // Assert
          expect(
            result.isSafeSender,
            isTrue,
            reason: 'Should mark as safe: $from',
          );
        }
      });
    });

    group('Rule Execution Order', () {
      test('Rules execute in order and first match wins', () async {
        // Arrange: Two rules with different execution orders
        final rules = [
          Rule(
            name: 'SecondRule',
            enabled: true,
            isLocal: false,
            executionOrder: 20,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: false, moveToFolder: 'Folder2'),
          ),
          Rule(
            name: 'FirstRule',
            enabled: true,
            isLocal: false,
            executionOrder: 10,
            conditions: RuleConditions(
              type: 'OR',
              from: ['@example\\.com\$'],
            ),
            actions: RuleActions(delete: true),
          ),
        ];

        final ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: rules,
        );

        final safeSenders = SafeSenderList(safeSenders: []);

        final evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: safeSenders,
          compiler: compiler,
        );

        // Act
        final email = createTestEmail(from: 'test@example.com');
        final result = await evaluator.evaluate(email);

        // Assert: First rule (executionOrder=10) wins
        expect(result.shouldDelete, isTrue);
        expect(result.matchedRule, equals('FirstRule'));
      });
    });
  });
}
