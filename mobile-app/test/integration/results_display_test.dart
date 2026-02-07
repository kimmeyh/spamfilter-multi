// ignore_for_file: avoid_print

/// Integration tests for Results Display functionality
///
/// Tests Phase 3.4 requirements:
/// - Result tiles display format: <folder> • <subject> • <rule>
/// - Summary statistics display
/// - Scan mode display in summary

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/evaluation_result.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';

void main() {
  group('Results Display - EmailActionResult Data Model', () {
    test('EmailActionResult should contain folder name from email', () {
      final email = EmailMessage(
        id: 'msg-001',
        from: 'spam@example.com',
        subject: 'Win a free prize!',
        body: 'Click here to claim your prize...',
        headers: {'from': 'spam@example.com'},
        receivedDate: DateTime.now(),
        folderName: 'Bulk Mail',  // [NEW] Phase 3.4: Folder name is critical
      );

      final evalResult = EvaluationResult(
        shouldDelete: true,
        shouldMove: false,
        targetFolder: null,
        matchedRule: 'SpamAutoDeleteHeader',
        matchedPattern: '@example\\.com\$',
      );

      final actionResult = EmailActionResult(
        email: email,
        evaluationResult: evalResult,
        action: EmailActionType.delete,
        success: true,
      );

      // Verify folder name is accessible from the result
      expect(actionResult.email.folderName, equals('Bulk Mail'));
      expect(actionResult.evaluationResult?.matchedRule, equals('SpamAutoDeleteHeader'));
      expect(actionResult.action, equals(EmailActionType.delete));

      print('[OK] EmailActionResult contains:');
      print('   Folder: ${actionResult.email.folderName}');
      print('   Subject: ${actionResult.email.subject}');
      print('   Rule: ${actionResult.evaluationResult?.matchedRule}');
    });

    test('Result tile subtitle should include folder, subject, and rule', () {
      final email = EmailMessage(
        id: 'msg-002',
        from: 'newsletter@company.com',
        subject: 'Weekly Newsletter',
        body: 'This week in news...',
        headers: {'from': 'newsletter@company.com'},
        receivedDate: DateTime.now(),
        folderName: 'Inbox',
      );

      final evalResult = EvaluationResult(
        shouldDelete: false,
        shouldMove: false,
        targetFolder: null,
        matchedRule: 'SafeSender',
        matchedPattern: '^newsletter@company\\.com\$',
      );

      final actionResult = EmailActionResult(
        email: email,
        evaluationResult: evalResult,
        action: EmailActionType.safeSender,
        success: true,
      );

      // Phase 3.4: Build the new subtitle format
      // Old format: "<from-email-address> • <rule>"
      // New format: "<folder> • <subject> • <rule>"
      final oldSubtitle = '${actionResult.email.from} • ${actionResult.evaluationResult?.matchedRule ?? 'No rule'}';
      final newSubtitle = '${actionResult.email.folderName} • ${actionResult.email.subject} • ${actionResult.evaluationResult?.matchedRule ?? 'No rule'}';

      expect(oldSubtitle, equals('newsletter@company.com • SafeSender'));
      expect(newSubtitle, equals('Inbox • Weekly Newsletter • SafeSender'));

      print('[OK] Subtitle format comparison:');
      print('   Old format: $oldSubtitle');
      print('   New format: $newSubtitle');
    });

    test('Results from different folders should be distinguishable', () {
      final results = [
        EmailActionResult(
          email: EmailMessage(
            id: 'msg-001',
            from: 'spam@domain1.com',
            subject: 'Spam from Inbox',
            body: 'Spam content',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: 'Inbox',
          ),
          evaluationResult: EvaluationResult(
            shouldDelete: true,
            shouldMove: false,
            matchedRule: 'SpamAutoDeleteHeader',
            matchedPattern: '@domain1\\.com\$',
          ),
          action: EmailActionType.delete,
          success: true,
        ),
        EmailActionResult(
          email: EmailMessage(
            id: 'msg-002',
            from: 'spam@domain2.com',
            subject: 'Spam from Bulk Mail',
            body: 'More spam',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: 'Bulk Mail',
          ),
          evaluationResult: EvaluationResult(
            shouldDelete: true,
            shouldMove: false,
            matchedRule: 'SpamAutoDeleteHeader',
            matchedPattern: '@domain2\\.com\$',
          ),
          action: EmailActionType.delete,
          success: true,
        ),
        EmailActionResult(
          email: EmailMessage(
            id: 'msg-003',
            from: 'spam@domain3.com',
            subject: 'Spam from Spam folder',
            body: 'Even more spam',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: 'Spam',
          ),
          evaluationResult: EvaluationResult(
            shouldDelete: true,
            shouldMove: false,
            matchedRule: 'SpamAutoDeleteHeader',
            matchedPattern: '@domain3\\.com\$',
          ),
          action: EmailActionType.delete,
          success: true,
        ),
      ];

      // Verify each result has distinct folder name
      final folders = results.map((r) => r.email.folderName).toSet();
      expect(folders.length, equals(3), reason: 'All results should have distinct folders');
      expect(folders, contains('Inbox'));
      expect(folders, contains('Bulk Mail'));
      expect(folders, contains('Spam'));

      print('[OK] Results from different folders verified:');
      for (var result in results) {
        print('   ${result.email.folderName} • ${result.email.subject}');
      }
    });
  });

  group('Results Display - Summary Statistics', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Summary should display correct counts for each action type', () {
      // Initialize scan
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 10);

      // Add various results
      _recordResult(provider, EmailActionType.delete, 'spam1@test.com', 'Spam 1');
      _recordResult(provider, EmailActionType.delete, 'spam2@test.com', 'Spam 2');
      _recordResult(provider, EmailActionType.delete, 'spam3@test.com', 'Spam 3');
      _recordResult(provider, EmailActionType.moveToJunk, 'move1@test.com', 'Move 1');
      _recordResult(provider, EmailActionType.moveToJunk, 'move2@test.com', 'Move 2');
      _recordResult(provider, EmailActionType.safeSender, 'safe1@test.com', 'Safe 1');
      _recordResult(provider, EmailActionType.none, 'norule1@test.com', 'No Rule 1');
      _recordResult(provider, EmailActionType.none, 'norule2@test.com', 'No Rule 2');
      _recordResult(provider, EmailActionType.none, 'norule3@test.com', 'No Rule 3');
      _recordResult(provider, EmailActionType.none, 'norule4@test.com', 'No Rule 4');

      // Verify counts
      expect(provider.deletedCount, equals(3));
      expect(provider.movedCount, equals(2));
      expect(provider.safeSendersCount, equals(1));
      expect(provider.noRuleCount, equals(4));
      expect(provider.processedCount, equals(10));
      expect(provider.totalEmails, equals(10));

      print('[OK] Summary statistics verified:');
      print('   Deleted: ${provider.deletedCount}');
      print('   Moved: ${provider.movedCount}');
      print('   Safe Senders: ${provider.safeSendersCount}');
      print('   No Rule: ${provider.noRuleCount}');
      print('   Total Processed: ${provider.processedCount}');
    });

    test('Scan mode display name should be correct for each mode', () {
      // Test all scan modes
      final modeDisplayNames = {
        ScanMode.readonly: 'Read-Only',
        ScanMode.testLimit: 'Test Limited Emails',
        ScanMode.testAll: 'Full Scan with Revert',
        ScanMode.fullScan: 'Full Scan',
      };

      for (var entry in modeDisplayNames.entries) {
        provider.initializeScanMode(mode: entry.key, testLimit: 10);
        expect(provider.getScanModeDisplayName(), equals(entry.value),
          reason: '${entry.key.name} should display as "${entry.value}"');
      }

      print('[OK] Scan mode display names verified');
    });

    test('getSummary should return correct summary map', () {
      provider.initializeScanMode(mode: ScanMode.testAll);
      provider.startScan(totalEmails: 5);

      _recordResult(provider, EmailActionType.delete, 'spam@test.com', 'Spam');
      _recordResult(provider, EmailActionType.safeSender, 'safe@test.com', 'Safe');
      _recordResult(provider, EmailActionType.none, 'norule@test.com', 'NoRule');

      provider.completeScan();

      final summary = provider.getSummary();

      expect(summary['total_emails'], equals(5));
      expect(summary['processed'], equals(3));
      expect(summary['deleted'], equals(1));
      expect(summary['safe_senders'], equals(1));
      expect(summary['status'], equals('ScanStatus.completed'));

      print('[OK] Summary map verified:');
      print('   $summary');
    });
  });

  group('Results Display - Rule Name Display (Issue #51)', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Results with matched rule should display rule name, not "no rule"', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 3);

      // Add result with matched rule for delete
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'spam@test.com',
          subject: 'Spam Email',
          body: 'Spam content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        evaluationResult: EvaluationResult(
          shouldDelete: true,
          shouldMove: false,
          matchedRule: 'SpamAutoDeleteHeader',
          matchedPattern: '@test\\.com\$',
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      // Add result with matched rule for move
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '2',
          from: 'marketing@company.com',
          subject: 'Marketing Email',
          body: 'Marketing content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        evaluationResult: EvaluationResult(
          shouldDelete: false,
          shouldMove: true,
          targetFolder: 'Junk',
          matchedRule: 'MarketingBulkMove',
          matchedPattern: 'marketing@.*',
        ),
        action: EmailActionType.moveToJunk,
        success: true,
      ));

      // Add result with safe sender rule
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '3',
          from: 'trusted@safe.com',
          subject: 'Trusted Email',
          body: 'Safe content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        evaluationResult: EvaluationResult.safeSender('^trusted@safe\\.com\$'),
        action: EmailActionType.safeSender,
        success: true,
      ));

      // Verify rule names are displayed
      expect(provider.results[0].evaluationResult?.matchedRule, equals('SpamAutoDeleteHeader'));
      expect(provider.results[0].evaluationResult?.matchedRule, isNot('No rule'));

      expect(provider.results[1].evaluationResult?.matchedRule, equals('MarketingBulkMove'));
      expect(provider.results[1].evaluationResult?.matchedRule, isNot('No rule'));

      expect(provider.results[2].evaluationResult?.matchedRule, equals('SafeSender'));
      expect(provider.results[2].evaluationResult?.matchedRule, isNot('No rule'));

      print('[OK] All results display actual rule names:');
      for (var i = 0; i < provider.results.length; i++) {
        final rule = provider.results[i].evaluationResult?.matchedRule ?? 'No rule';
        print('   Result $i: Rule = $rule');
      }
    });

    test('Result display should show: folder • subject • matched_rule', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 1);

      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'spam@domain.com',
          subject: 'Phishing Attempt',
          body: 'Click here to verify account',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Bulk Mail',
        ),
        evaluationResult: EvaluationResult(
          shouldDelete: true,
          shouldMove: false,
          matchedRule: 'PhishingDetected',
          matchedPattern: 'verify account',
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      final result = provider.results.first;
      final folder = result.email.folderName;
      final subject = result.email.subject.isNotEmpty ? result.email.subject : 'No subject';
      final rule = result.evaluationResult?.matchedRule ?? 'No rule';
      final displayFormat = '$folder • $subject • $rule';

      expect(displayFormat, equals('Bulk Mail • Phishing Attempt • PhishingDetected'));
      expect(rule, isNot('No rule'));

      print('[OK] Result display format verified:');
      print('   Display: $displayFormat');
    });

    test('Results with no matching rule should have empty string, not "no rule"', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 1);

      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'unknown@example.com',
          subject: 'Regular Email',
          body: 'Regular content',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',
        ),
        evaluationResult: EvaluationResult.noMatch(),
        action: EmailActionType.none,
        success: true,
      ));

      final result = provider.results.first;
      final rawRule = result.evaluationResult?.matchedRule ?? '';
      // Empty string needs special handling - display shows "No rule" for empty
      final displayedRule = rawRule.isEmpty ? 'No rule' : rawRule;

      // When no rule matched, matchedRule is empty string
      expect(result.evaluationResult?.matchedRule, isEmpty);
      // Display should show "No rule" as fallback
      expect(displayedRule, equals('No rule'));

      print('[OK] No-rule case verified:');
      print('   evaluationResult.matchedRule = "${result.evaluationResult?.matchedRule}"');
      print('   Display (empty -> "No rule") = "$displayedRule"');
    });

    test('Multiple emails with different rules should display correctly', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 4);

      final testCases = [
        ('rule_1@spam.com', 'Email 1', 'FirstSpamRule'),
        ('rule_2@bad.com', 'Email 2', 'SecondBadRule'),
        ('rule_3@phish.com', 'Email 3', 'PhishingRule'),
        ('safe@trusted.com', 'Email 4', 'SafeSender'),
      ];

      for (var i = 0; i < testCases.length; i++) {
        final (from, subject, ruleName) = testCases[i];
        final isSafe = ruleName == 'SafeSender';

        provider.recordResult(EmailActionResult(
          email: EmailMessage(
            id: 'msg-$i',
            from: from,
            subject: subject,
            body: 'Content',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: 'Inbox',
          ),
          evaluationResult: isSafe
              ? EvaluationResult.safeSender('^$from\$')
              : EvaluationResult(
                  shouldDelete: true,
                  shouldMove: false,
                  matchedRule: ruleName,
                  matchedPattern: '@.*',
                ),
          action: isSafe ? EmailActionType.safeSender : EmailActionType.delete,
          success: true,
        ));
      }

      // Verify each result has correct rule
      for (var i = 0; i < provider.results.length; i++) {
        final (_, _, expectedRule) = testCases[i];
        final actualRule = provider.results[i].evaluationResult?.matchedRule;
        expect(actualRule, equals(expectedRule),
          reason: 'Result $i should have rule: $expectedRule');
      }

      print('[OK] Multiple rules displayed correctly:');
      for (var i = 0; i < provider.results.length; i++) {
        final rule = provider.results[i].evaluationResult?.matchedRule ?? 'No rule';
        print('   Email $i: $rule');
      }
    });
  });

  group('Results Display - Error Handling', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Error results should be tracked correctly', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 3);

      // Record a successful result
      _recordResult(provider, EmailActionType.delete, 'spam@test.com', 'Spam');

      // Record an error result (need to call updateProgress first to increment processedCount)
      final errorEmail = EmailMessage(
        id: 'err-001',
        from: 'error@test.com',
        subject: 'Error Email',
        body: 'Body',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'Inbox',
      );
      provider.updateProgress(email: errorEmail, message: 'Processing: Error Email');
      provider.recordResult(EmailActionResult(
        email: errorEmail,
        action: EmailActionType.delete,
        success: false,
        error: 'Network timeout',
      ));

      // Record another successful result
      _recordResult(provider, EmailActionType.safeSender, 'safe@test.com', 'Safe');

      expect(provider.errorCount, equals(1));
      expect(provider.processedCount, equals(3));

      // Verify error is in results
      final errorResults = provider.results.where((r) => !r.success).toList();
      expect(errorResults.length, equals(1));
      expect(errorResults.first.error, equals('Network timeout'));

      print('[OK] Error tracking verified');
      print('   Errors: ${provider.errorCount}');
      print('   Error message: ${errorResults.first.error}');
    });
  });

  group('Results Display - Folder Name in Results', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Results should preserve folder name from scanned email', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 3);

      // Record results from different folders
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'test1@example.com',
          subject: 'Email from Inbox',
          body: 'Body',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Inbox',  // [NEW] Phase 3.4: Folder tracked
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '2',
          from: 'test2@example.com',
          subject: 'Email from Bulk Mail',
          body: 'Body',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Bulk Mail',  // [NEW] Phase 3.4: Folder tracked
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '3',
          from: 'test3@example.com',
          subject: 'Email from Spam',
          body: 'Body',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Spam',  // [NEW] Phase 3.4: Folder tracked
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      // Verify folder names are preserved in results
      expect(provider.results[0].email.folderName, equals('Inbox'));
      expect(provider.results[1].email.folderName, equals('Bulk Mail'));
      expect(provider.results[2].email.folderName, equals('Spam'));

      print('[OK] Folder names preserved in results:');
      for (var result in provider.results) {
        print('   ${result.email.folderName} • ${result.email.subject}');
      }
    });

    test('Phase 3.4 result tile format should include folder • subject • rule', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 1);

      final evalResult = EvaluationResult(
        shouldDelete: true,
        shouldMove: false,
        matchedRule: 'SpamAutoDeleteHeader',
        matchedPattern: '@spammer\\.com\$',
      );

      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'spam@spammer.com',
          subject: 'You won a million dollars!',
          body: 'Click here...',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'Bulk Mail',
        ),
        evaluationResult: evalResult,
        action: EmailActionType.delete,
        success: true,
      ));

      final result = provider.results.first;

      // Build Phase 3.4 format
      final folder = result.email.folderName;
      final subject = result.email.subject.isNotEmpty ? result.email.subject : 'No subject';
      final rule = result.evaluationResult?.matchedRule ?? 'No rule';

      final newFormat = '$folder • $subject • $rule';

      expect(newFormat, equals('Bulk Mail • You won a million dollars! • SpamAutoDeleteHeader'));

      print('[OK] Phase 3.4 result tile format verified:');
      print('   $newFormat');
    });
  });
}

/// Helper function to record a simple result
///
/// Mirrors the actual workflow: updateProgress() then recordResult()
void _recordResult(
  EmailScanProvider provider,
  EmailActionType action,
  String from,
  String subject, {
  String folderName = 'Inbox',
}) {
  final email = EmailMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    from: from,
    subject: subject,
    body: 'Test body',
    headers: {'from': from},
    receivedDate: DateTime.now(),
    folderName: folderName,
  );

  // First update progress (like the real scanner does)
  provider.updateProgress(email: email, message: 'Processing: $subject');

  // Always create an EvaluationResult (even for no match cases)
  // This ensures the rule name is always available for display
  final String ruleName;
  final String pattern;

  if (action == EmailActionType.none) {
    ruleName = '';  // No rule matched
    pattern = '';
  } else if (action == EmailActionType.safeSender) {
    ruleName = 'SafeSender';
    pattern = 'safe-sender-pattern';
  } else {
    ruleName = 'TestRule';
    pattern = 'test-pattern';
  }

  final evalResult = EvaluationResult(
    shouldDelete: action == EmailActionType.delete,
    shouldMove: action == EmailActionType.moveToJunk,
    matchedRule: ruleName,
    matchedPattern: pattern,
    isSafeSender: action == EmailActionType.safeSender,
  );

  // Then record the result
  provider.recordResult(EmailActionResult(
    email: email,
    evaluationResult: evalResult,
    action: action,
    success: true,
  ));
}
