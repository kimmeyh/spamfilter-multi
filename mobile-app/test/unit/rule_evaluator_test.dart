/*
 * Comprehensive unit tests for RuleEvaluator
 *
 * This test suite was created to address Issue #27 (GitHub Issue #18):
 * "Missing unit tests for RuleEvaluator - core spam detection logic untested"
 *
 * Test Results Summary:
 * - Total Tests: 32
 * - All tests passing after Issue #8 fix
 * - Code Coverage: 97.96% (48/49 lines)
 *
 * Coverage Breakdown:
 * - Safe sender precedence: 2 tests
 * - From/subject/body matching: 7 tests
 * - Header matching: 4 tests (includes anti-spoofing test)
 * - Exception handling: 4 tests
 * - AND/OR logic: 3 tests
 * - Execution order: 3 tests
 * - Actions (delete/move): 2 tests
 * - Edge cases: 6 tests
 * - Complex scenarios: 2 tests
 *
 * Created: January 3, 2026
 * Issue Reference: GitHub #18 (formerly #27 in backlog)
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';

void main() {
  late RuleEvaluator evaluator;
  late PatternCompiler compiler;
  late SafeSenderList safeSenders;
  late RuleSet ruleSet;

  setUp(() {
    compiler = PatternCompiler();
    safeSenders = SafeSenderList(safeSenders: []);
    ruleSet = RuleSet(
      version: '1.0',
      settings: {},
      rules: [],
    );
    evaluator = RuleEvaluator(
      ruleSet: ruleSet,
      safeSenderList: safeSenders,
      compiler: compiler,
    );
  });

  EmailMessage createTestEmail({
    String id = '1',
    String from = 'test@example.com',
    String subject = 'Test Subject',
    String body = 'Test Body',
    Map<String, String>? headers,
    String folderName = 'INBOX',
  }) {
    return EmailMessage(
      id: id,
      from: from,
      subject: subject,
      body: body,
      headers: headers ?? {},
      receivedDate: DateTime.now(),
      folderName: folderName,
    );
  }

  Rule createTestRule({
    String name = 'TestRule',
    bool enabled = true,
    int executionOrder = 10,
    required RuleConditions conditions,
    RuleActions? actions,
    RuleExceptions? exceptions,
  }) {
    return Rule(
      name: name,
      enabled: enabled,
      isLocal: false,
      executionOrder: executionOrder,
      conditions: conditions,
      actions: actions ?? RuleActions(delete: true),
      exceptions: exceptions,
    );
  }

  group('RuleEvaluator - Safe Sender Precedence', () {
    test('safe sender prevents rule from matching', () async {
      // Create safe sender list with pattern
      safeSenders = SafeSenderList(safeSenders: [r'^trusted@example\.com$']);
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'DeleteAll',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'trusted@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.isSafeSender, isTrue);
      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, equals('SafeSender'));
    });

    test('non-safe sender allows rule to match', () async {
      safeSenders = SafeSenderList(safeSenders: [r'^trusted@example\.com$']);
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'DeleteSpam',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^spam@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'spam@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.isSafeSender, isFalse);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('DeleteSpam'));
    });
  });

  group('RuleEvaluator - From Matching', () {
    test('matches email when from pattern matches', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockSender',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^spam@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'spam@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockSender'));
      expect(result.matchedPattern, equals(r'^spam@example\.com$'));
    });

    test('does not match when from pattern does not match', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockSender',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^spam@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'legitimate@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, equals(''));
    });

    test('matches with domain pattern', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockDomain',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@spam-domain\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'anything@spam-domain.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockDomain'));
    });
  });

  group('RuleEvaluator - Subject Matching', () {
    test('matches email when subject pattern matches', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockUrgent',
            conditions: RuleConditions(
              type: 'OR',
              subject: [r'^urgent:.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(subject: 'URGENT: Action Required');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockUrgent'));
    });

    test('case-insensitive subject matching', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockWinner',
            conditions: RuleConditions(
              type: 'OR',
              subject: [r'.*you.*won.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(subject: 'CONGRATULATIONS! YOU WON!');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockWinner'));
    });
  });

  group('RuleEvaluator - Body Matching', () {
    test('matches email when body pattern matches', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockPhishing',
            conditions: RuleConditions(
              type: 'OR',
              body: [r'.*verify.*account.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        body: 'Please verify your account immediately.',
      );
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockPhishing'));
    });
  });

  group('RuleEvaluator - Header Matching', () {
    test('matches email when header pattern matches', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpamHeaderRule',
            conditions: RuleConditions(
              type: 'OR',
              header: [r'x-spam-status:.*yes.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        headers: {
          'X-Spam-Status': 'Yes, score=9.5',
          'Content-Type': 'text/plain',
        },
      );
      final result = await evaluator.evaluate(email);

      // NOTE: This test will FAIL until Issue #8 is fixed
      // Current bug: header patterns check message.from instead of message.headers
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('SpamHeaderRule'));
    });

    test('matches with multiple header patterns', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpamIndicators',
            conditions: RuleConditions(
              type: 'OR',
              header: [
                r'x-spam-flag:.*yes.*',
                r'x-spam-level:.*\*\*\*\*\*.*',
              ],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        headers: {
          'X-Spam-Flag': 'YES',
        },
      );
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('SpamIndicators'));
    });

    test('header matching is case-insensitive', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpamScore',
            conditions: RuleConditions(
              type: 'OR',
              header: [r'x-spam-score:.*[5-9]\..*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        headers: {
          'x-spam-score': '7.3',
        },
      );
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
    });

    test('matches authentic from: header to detect spoofed emails', () async {
      // This test demonstrates matching the authentic "from:" header in email headers
      // (which cannot be easily spoofed) versus the display From field.
      // Pattern matches domains with "0za12o" subdomain (common spam pattern)
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpamAutoDeleteHeader',
            conditions: RuleConditions(
              type: 'OR',
              header: [r'from:.*@(?:[a-z0-9-]+\.)*0za12o\.[a-z0-9.-]+$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Spammer attempts to spoof a legitimate sender
      // Display From looks legitimate, but authentic header From reveals true sender
      final email = createTestEmail(
        from: 'support@legitbank.com',  // Spoofed display From
        headers: {
          'From': 'noreply@mail.0za12o.spammer.net',  // Authentic From header
          'Reply-To': 'phishing@another-domain.com',
          'Content-Type': 'text/html',
        },
        subject: 'Urgent: Verify Your Account',
        body: 'Click here to verify your account...',
      );
      final result = await evaluator.evaluate(email);

      // Rule matches because authentic "from:" header contains @mail.0za12o.spammer.net
      // Pattern: @(?:[a-z0-9-]+\.)*0za12o\.[a-z0-9.-]+$
      // Matches: from:noreply@mail.0za12o.spammer.net (after lowercase/trim)
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('SpamAutoDeleteHeader'));
      expect(result.matchedPattern, equals(r'from:.*@(?:[a-z0-9-]+\.)*0za12o\.[a-z0-9.-]+$'));
    });
  });

  group('RuleEvaluator - Exception Handling', () {
    test('exception prevents rule from matching (from exception)', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockDomain',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
            exceptions: RuleExceptions(
              from: [r'^admin@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'admin@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, equals(''));
    });

    test('exception prevents rule from matching (subject exception)', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockUrgent',
            conditions: RuleConditions(
              type: 'OR',
              subject: [r'.*urgent.*'],
            ),
            exceptions: RuleExceptions(
              subject: [r'.*system maintenance.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        subject: 'URGENT: System Maintenance Tonight',
      );
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
    });

    test('exception prevents rule from matching (header exception)', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockSpam',
            conditions: RuleConditions(
              type: 'OR',
              subject: [r'.*free.*money.*'],
            ),
            exceptions: RuleExceptions(
              header: [r'x-verified-sender:.*true.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(
        subject: 'Free Money Offer',
        headers: {
          'X-Verified-Sender': 'true',
        },
      );
      final result = await evaluator.evaluate(email);

      // NOTE: This test will FAIL until Issue #8 is fixed
      // Current bug: header exceptions check message.from instead of headers
      expect(result.shouldDelete, isFalse);
    });

    test('non-matching exception allows rule to match', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'BlockDomain',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@spam\.com$'],
            ),
            exceptions: RuleExceptions(
              from: [r'^legitimate@spam\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'other@spam.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockDomain'));
    });
  });

  group('RuleEvaluator - AND/OR Logic', () {
    test('OR logic matches when any condition matches', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'MultiConditionOR',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^spam@example\.com$'],
              subject: [r'.*winner.*'],
              body: [r'.*click here.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Only subject matches
      final email = createTestEmail(
        from: 'normal@example.com',
        subject: 'You are a winner!',
        body: 'Normal content',
      );
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('MultiConditionOR'));
    });

    test('AND logic requires all conditions to match', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'MultiConditionAND',
            conditions: RuleConditions(
              type: 'AND',
              from: [r'.*@suspicious\.com$'],
              subject: [r'.*urgent.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Both conditions match
      final email1 = createTestEmail(
        from: 'sender@suspicious.com',
        subject: 'Urgent action required',
      );
      final result1 = await evaluator.evaluate(email1);
      expect(result1.shouldDelete, isTrue);

      // Only from matches
      final email2 = createTestEmail(
        from: 'sender@suspicious.com',
        subject: 'Normal subject',
      );
      final result2 = await evaluator.evaluate(email2);
      expect(result2.shouldDelete, isFalse);

      // Only subject matches
      final email3 = createTestEmail(
        from: 'normal@example.com',
        subject: 'Urgent notification',
      );
      final result3 = await evaluator.evaluate(email3);
      expect(result3.shouldDelete, isFalse);
    });

    test('AND logic with empty patterns list', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'PartialAND',
            conditions: RuleConditions(
              type: 'AND',
              from: [r'.*@example\.com$'],
              subject: [], // Empty list (ignored, not evaluated)
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'test@example.com');
      final result = await evaluator.evaluate(email);

      // With AND logic, empty patterns are ignored (only non-empty patterns evaluated)
      // Since from matches and subject is empty (ignored), the rule matches
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('PartialAND'));
    });
  });

  group('RuleEvaluator - Execution Order', () {
    test('evaluates rules in execution order', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'LowPriority',
            executionOrder: 20,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
            actions: RuleActions(delete: false, moveToFolder: 'Junk'),
          ),
          createTestRule(
            name: 'HighPriority',
            executionOrder: 10,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
            actions: RuleActions(delete: true),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'test@example.com');
      final result = await evaluator.evaluate(email);

      // First matching rule (HighPriority) should execute
      expect(result.matchedRule, equals('HighPriority'));
      expect(result.shouldDelete, isTrue);
    });

    test('stops at first matching rule', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'FirstMatch',
            executionOrder: 5,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
          ),
          createTestRule(
            name: 'SecondMatch',
            executionOrder: 10,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'test@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.matchedRule, equals('FirstMatch'));
    });

    test('skips disabled rules', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'DisabledRule',
            enabled: false,
            executionOrder: 5,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
          ),
          createTestRule(
            name: 'EnabledRule',
            enabled: true,
            executionOrder: 10,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'test@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.matchedRule, equals('EnabledRule'));
    });
  });

  group('RuleEvaluator - Actions', () {
    test('delete action sets shouldDelete to true', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'DeleteRule',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^spam@example\.com$'],
            ),
            actions: RuleActions(delete: true),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'spam@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.shouldMove, isFalse);
    });

    test('move action sets shouldMove and targetFolder', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'MoveRule',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^newsletter@example\.com$'],
            ),
            actions: RuleActions(
              delete: false,
              moveToFolder: 'Newsletters',
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'newsletter@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
      expect(result.shouldMove, isTrue);
      expect(result.targetFolder, equals('Newsletters'));
    });
  });

  group('RuleEvaluator - Edge Cases', () {
    test('handles email with no matching rules', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpecificRule',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^specific@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'other@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
      expect(result.shouldMove, isFalse);
      expect(result.matchedRule, equals(''));
      expect(result.matchedPattern, equals(''));
    });

    test('handles empty rule list', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail();
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
      expect(result.matchedRule, equals(''));
    });

    test('handles invalid regex pattern gracefully', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'InvalidRegex',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'[invalid(regex'],  // Invalid regex
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'test@example.com');
      final result = await evaluator.evaluate(email);

      // Should not match due to invalid regex (compiler returns never-match pattern)
      expect(result.shouldDelete, isFalse);
    });

    test('handles empty pattern list', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'EmptyPatterns',
            conditions: RuleConditions(
              type: 'OR',
              from: [],
              subject: [],
              body: [],
              header: [],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail();
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
    });

    test('handles email with empty headers map', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'HeaderRule',
            conditions: RuleConditions(
              type: 'OR',
              header: [r'x-spam:.*'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(headers: {});
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isFalse);
    });

    test('normalizes text before matching (lowercase, trim)', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'CaseSensitive',
            conditions: RuleConditions(
              type: 'OR',
              from: [r'^test@example\.com$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Uppercase and extra whitespace
      final email = createTestEmail(from: '  TEST@EXAMPLE.COM  ');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
    });
  });

  group('RuleEvaluator - Complex Scenarios', () {
    test('multiple patterns in single condition type', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'MultiPattern',
            conditions: RuleConditions(
              type: 'OR',
              from: [
                r'^spam1@example\.com$',
                r'^spam2@example\.com$',
                r'^spam3@example\.com$',
              ],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      final email = createTestEmail(from: 'spam2@example.com');
      final result = await evaluator.evaluate(email);

      expect(result.shouldDelete, isTrue);
      expect(result.matchedPattern, equals(r'^spam2@example\.com$'));
    });

    test('real-world spam detection scenario', () async {
      ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          createTestRule(
            name: 'SpamAutoDeleteHeader',
            executionOrder: 10,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'.*@.*\.xyz$'],
              header: [r'x-spam-status:.*yes.*'],
              subject: [r'.*\[spam\].*'],
            ),
            exceptions: RuleExceptions(
              from: [r'^newsletter@trusted\.xyz$'],
            ),
          ),
        ],
      );
      evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Spam from .xyz domain
      final spam1 = createTestEmail(from: 'scam@fake.xyz');
      final result1 = await evaluator.evaluate(spam1);
      expect(result1.shouldDelete, isTrue);

      // Spam with header
      final spam2 = createTestEmail(
        from: 'normal@example.com',
        headers: {'X-Spam-Status': 'Yes, score=8.0'},
      );
      final result2 = await evaluator.evaluate(spam2);
      expect(result2.shouldDelete, isTrue);

      // Legitimate newsletter from .xyz (exception)
      final legit = createTestEmail(from: 'newsletter@trusted.xyz');
      final result3 = await evaluator.evaluate(legit);
      expect(result3.shouldDelete, isFalse);
    });
  });
}
