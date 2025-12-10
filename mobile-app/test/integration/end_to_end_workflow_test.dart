import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';
import 'package:spam_filter_mobile/core/services/yaml_service.dart';
import 'dart:io';

void main() {
  group('End-to-End Email Processing Workflow', () {
    late YamlService yamlService;
    late PatternCompiler compiler;
    late RuleSet ruleSet;
    late SafeSenderList safeSenders;

    setUpAll(() async {
      yamlService = YamlService();
      compiler = PatternCompiler();

      // Load production rules
      final rulesPath = '../rules.yaml';
      final safeSendersPath = '../rules_safe_senders.yaml';

      if (await File(rulesPath).exists()) {
        ruleSet = await yamlService.loadRules(rulesPath);
        print('Loaded ${ruleSet.rules.length} rules');
      } else {
        print('Warning: rules.yaml not found, using empty rule set');
        ruleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [],
        );
      }

      if (await File(safeSendersPath).exists()) {
        safeSenders = await yamlService.loadSafeSenders(safeSendersPath);
        print('Loaded ${safeSenders.safeSenders.length} safe senders');
      } else {
        print('Warning: rules_safe_senders.yaml not found, using empty list');
        safeSenders = SafeSenderList(safeSenders: []);
      }
    });

    test('evaluate safe sender email', () {
      final evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Test with a known safe sender pattern
      final safeEmail = EmailMessage(
        id: '1',
        from: 'admin@example.com',
        subject: 'Test email',
        body: 'This is a test',
        headers: {'from': 'admin@example.com'},
        receivedDate: DateTime.now(),
        folderName: 'Inbox',
      );

      final result = evaluator.evaluate(safeEmail);
      
      // If the email matches a safe sender, it should be whitelisted
      if (safeSenders.isSafe(safeEmail.from)) {
        expect(result, completes);
      }
    });

    test('evaluate spam email against rules', () async {
      final evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Create test spam email
      final spamEmail = EmailMessage(
        id: '2',
        from: 'spam@suspicious-domain.xyz',
        subject: 'Win a prize!!!',
        body: 'Click here now for urgent action!',
        headers: {'from': 'spam@suspicious-domain.xyz'},
        receivedDate: DateTime.now(),
        folderName: 'Inbox',
      );

      final result = await evaluator.evaluate(spamEmail);
      
      print('Spam evaluation result:');
      if (result.shouldDelete) {
        print('  Action: DELETE');
        print('  Matched rule: ${result.matchedRule}');
        print('  Matched pattern: ${result.matchedPattern}');
      } else if (result.shouldMove) {
        print('  Action: MOVE to ${result.targetFolder}');
        print('  Matched rule: ${result.matchedRule}');
      } else {
        print('  Action: No match (would prompt user in interactive mode)');
      }
    });

    test('batch email evaluation performance', () async {
      final evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      // Create batch of test emails
      final testEmails = List.generate(100, (i) {
        return EmailMessage(
          id: '$i',
          from: 'sender${i % 10}@test${i % 5}.com',
          subject: 'Test email $i',
          body: 'Body content $i',
          headers: {'from': 'sender${i % 10}@test${i % 5}.com'},
          receivedDate: DateTime.now().subtract(Duration(days: i)),
          folderName: 'Inbox',
        );
      });

      final stopwatch = Stopwatch()..start();
      
      int safeCount = 0;
      int spamCount = 0;
      int unknownCount = 0;

      for (final email in testEmails) {
        final result = await evaluator.evaluate(email);
        
        if (safeSenders.isSafe(email.from)) {
          safeCount++;
        } else if (result.shouldDelete || result.shouldMove) {
          spamCount++;
        } else {
          unknownCount++;
        }
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / testEmails.length;

      print('✅ Batch evaluation complete:');
      print('   Total emails: ${testEmails.length}');
      print('   Safe senders: $safeCount');
      print('   Spam detected: $spamCount');
      print('   Unknown: $unknownCount');
      print('   Total time: ${stopwatch.elapsedMilliseconds}ms');
      print('   Average per email: ${avgTime.toStringAsFixed(2)}ms');

      // Performance target: <100ms per email
      expect(avgTime, lessThan(100), 
        reason: 'Average evaluation time should be <100ms per email');
    });

    test('simulate full inbox scan workflow', () async {
      final evaluator = RuleEvaluator(
        ruleSet: ruleSet,
        safeSenderList: safeSenders,
        compiler: compiler,
      );

      print('\n📧 Simulating full inbox scan workflow:');
      print('━' * 60);

      // Simulate inbox with mixed emails
      final inbox = [
        EmailMessage(
          id: '1',
          from: 'friend@gmail.com',
          subject: 'Lunch tomorrow?',
          body: 'Hey, want to grab lunch?',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        EmailMessage(
          id: '2',
          from: 'marketing@suspicious.com',
          subject: 'FREE OFFER - CLICK NOW!!!',
          body: 'Limited time offer! Click here immediately!',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        EmailMessage(
          id: '3',
          from: 'billing@legitimate-company.com',
          subject: 'Your invoice',
          body: 'Please find your invoice attached.',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
      ];

      final actions = <String, int>{
        'safe': 0,
        'delete': 0,
        'move': 0,
        'prompt': 0,
      };

      for (final email in inbox) {
        print('\nProcessing: ${email.subject}');
        print('  From: ${email.from}');

        if (safeSenders.isSafe(email.from)) {
          print('  ✅ Safe sender - keeping in inbox');
          actions['safe'] = (actions['safe'] ?? 0) + 1;
        } else {
          final result = await evaluator.evaluate(email);
          
          if (result.shouldDelete) {
            print('  🗑️  SPAM - deleting (rule: ${result.matchedRule})');
            actions['delete'] = (actions['delete'] ?? 0) + 1;
          } else if (result.shouldMove) {
            print('  📁 Moving to ${result.targetFolder} (rule: ${result.matchedRule})');
            actions['move'] = (actions['move'] ?? 0) + 1;
          } else {
            print('  ❓ No rule match - would prompt user');
            actions['prompt'] = (actions['prompt'] ?? 0) + 1;
          }
        }
      }

      print('\n' + '━' * 60);
      print('📊 Scan Summary:');
      print('   Total processed: ${inbox.length}');
      print('   Safe senders: ${actions['safe']}');
      print('   Deleted: ${actions['delete']}');
      print('   Moved: ${actions['move']}');
      print('   Needs review: ${actions['prompt']}');
      print('━' * 60);
    });
  });
}
