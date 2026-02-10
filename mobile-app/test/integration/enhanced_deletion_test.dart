/// Integration tests for Issue #138: Enhanced Deleted Email Processing
///
/// Tests that deleted emails are:
/// 1. Moved to configured folder
/// 2. Marked as read
/// 3. Flagged/labeled with rule name
///
library;

/// Sprint 14

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/adapters/email_providers/mock_email_provider.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';

void main() {
  group('Enhanced Deleted Email Processing (Issue #138)', () {
    late MockEmailProvider mockProvider;
    late RuleEvaluator evaluator;
    late PatternCompiler compiler;

    setUp(() {
      mockProvider = MockEmailProvider(operationDelayMs: 10);
      compiler = PatternCompiler();

      // Create test rule set with deletion rule
      final ruleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'BlockSpamDomain',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'@spam\.com$'],
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
    });

    test('Mock provider logs markAsRead action', () async {
      final testEmail = EmailMessage(
        id: 'test-001',
        from: 'spammer@spam.com',
        subject: 'Test Spam',
        body: 'Spam content',
        headers: {'From': 'spammer@spam.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      // Verify email matches deletion rule
      final result = await evaluator.evaluate(testEmail);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('BlockSpamDomain'));

      // Simulate deletion workflow
      await mockProvider.takeAction(
        message: testEmail,
        action: FilterAction.delete,
      );

      await mockProvider.markAsRead(message: testEmail);

      await mockProvider.applyFlag(
        message: testEmail,
        flagName: result.matchedRule,
      );

      // Verify actions logged
      final actions = mockProvider.actionLog;
      expect(actions.length, equals(3));

      // Check delete action
      expect(actions[0]['action'], equals('delete'));
      expect(actions[0]['emailId'], equals('test-001'));

      // Check mark as read action
      expect(actions[1]['action'], equals('markAsRead'));
      expect(actions[1]['emailId'], equals('test-001'));

      // Check apply flag action
      expect(actions[2]['action'], equals('applyFlag'));
      expect(actions[2]['emailId'], equals('test-001'));
      expect(actions[2]['flagName'], equals('BlockSpamDomain'));
    });

    test('Flagging includes sanitized rule name', () async {
      // Create rule with special characters
      final specialRuleSet = RuleSet(
        version: '1.0',
        settings: {'defaultExecutionOrderIncrement': 10},
        rules: [
          Rule(
            name: 'Block: Spam/Phishing (2024)',
            enabled: true,
            isLocal: false,
            conditions: RuleConditions(
              type: 'OR',
              from: [r'@phishing\.com$'],
            ),
            actions: RuleActions(delete: true),
            executionOrder: 10,
          ),
        ],
      );

      final specialEvaluator = RuleEvaluator(
        ruleSet: specialRuleSet,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: compiler,
      );

      final testEmail = EmailMessage(
        id: 'test-002',
        from: 'scam@phishing.com',
        subject: 'Phishing Test',
        body: 'Phishing content',
        headers: {'From': 'scam@phishing.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = await specialEvaluator.evaluate(testEmail);
      expect(result.shouldDelete, isTrue);
      expect(result.matchedRule, equals('Block: Spam/Phishing (2024)'));

      // Apply flag with special character rule name
      await mockProvider.applyFlag(
        message: testEmail,
        flagName: result.matchedRule,
      );

      // Verify action logged with original rule name
      final actions = mockProvider.actionLog;
      expect(actions.length, equals(1));
      expect(actions[0]['action'], equals('applyFlag'));
      expect(actions[0]['flagName'], equals('Block: Spam/Phishing (2024)'));

      // Note: Provider implementations will sanitize the name
      // Gmail: 'Block: Spam-Phishing (2024)' (replaces / with -)
      // IMAP: 'Block__Spam_Phishing__2024_' (replaces special chars with _)
    });

    test('Multiple deletions log all actions', () async {
      final emails = [
        EmailMessage(
          id: 'spam-001',
          from: 'user1@spam.com',
          subject: 'Spam 1',
          body: 'Content',
          headers: {'From': 'user1@spam.com'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        EmailMessage(
          id: 'spam-002',
          from: 'user2@spam.com',
          subject: 'Spam 2',
          body: 'Content',
          headers: {'From': 'user2@spam.com'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        EmailMessage(
          id: 'spam-003',
          from: 'user3@spam.com',
          subject: 'Spam 3',
          body: 'Content',
          headers: {'From': 'user3@spam.com'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
      ];

      for (final email in emails) {
        final result = await evaluator.evaluate(email);
        expect(result.shouldDelete, isTrue);

        await mockProvider.takeAction(message: email, action: FilterAction.delete);
        await mockProvider.markAsRead(message: email);
        await mockProvider.applyFlag(message: email, flagName: result.matchedRule);
      }

      // Verify 9 actions logged (3 emails × 3 actions each)
      final actions = mockProvider.actionLog;
      expect(actions.length, equals(9));

      // Verify sequence
      expect(actions[0]['action'], equals('delete'));
      expect(actions[1]['action'], equals('markAsRead'));
      expect(actions[2]['action'], equals('applyFlag'));
      expect(actions[3]['action'], equals('delete'));
      expect(actions[4]['action'], equals('markAsRead'));
      expect(actions[5]['action'], equals('applyFlag'));
      expect(actions[6]['action'], equals('delete'));
      expect(actions[7]['action'], equals('markAsRead'));
      expect(actions[8]['action'], equals('applyFlag'));
    });

    test('Mock provider clears action log on disconnect', () async {
      final testEmail = EmailMessage(
        id: 'test-999',
        from: 'test@spam.com',
        subject: 'Test',
        body: 'Content',
        headers: {'From': 'test@spam.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      await mockProvider.takeAction(message: testEmail, action: FilterAction.delete);
      expect(mockProvider.actionLog.length, equals(1));

      await mockProvider.disconnect();
      expect(mockProvider.actionLog.length, equals(0));
    });
  });
}
