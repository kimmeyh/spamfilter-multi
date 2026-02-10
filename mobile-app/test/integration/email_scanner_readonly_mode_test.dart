import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';

import 'package:spam_filter_mobile/core/models/evaluation_result.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import 'package:spam_filter_mobile/core/providers/rule_set_provider.dart';
import 'package:spam_filter_mobile/core/services/email_scanner.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';

/// Integration test for readonly mode enforcement (Sprint 11 - Issue #9 regression prevention)
///
/// CRITICAL: This test prevents regression of Issue #9 where readonly mode was bypassed,
/// causing 526 emails to be deleted during testing.
///
/// Test coverage:
/// - ScanMode.readonly prevents platform.takeAction() calls
/// - ScanMode.fullScan allows platform.takeAction() calls
/// - ScanMode.testLimit respects email limit
/// - Actions are logged but not executed in readonly mode
///
/// TODO: Issue #117 - Complete this test once RuleSetProvider supports loadRulesFromString
/// or use DatabaseTestHelper pattern with database-loaded rules.
void main() {
  group('EmailScanner Readonly Mode Enforcement (Issue #9 Prevention)', skip: 'Pending Issue #117 - requires RuleSetProvider refactoring', () {
    late EmailScanProvider scanProvider;
    late RuleSetProvider ruleProvider;
    late MockSpamFilterPlatform mockPlatform;
    late EmailScanner scanner;

    setUp(() {
      scanProvider = EmailScanProvider();
      ruleProvider = RuleSetProvider();
      mockPlatform = MockSpamFilterPlatform();

      // TODO: Issue #117 - Load minimal rule set once RuleSetProvider.loadRulesFromString is implemented
      // For now this test is skipped because the method does not exist.
      // ruleProvider.loadRulesFromString(r'''
      // rules:
      //   - name: TestDeleteRule
      //     enabled: true
      //     conditions:
      //       subject: ["SPAM"]
      //     action: delete
      // ''');

      scanner = EmailScanner(
        platformId: 'test',
        accountId: 'test-account',
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
      );
    });

    test('ScanMode.readonly prevents platform.takeAction() calls', () async {
      // Arrange: Set readonly mode
      scanProvider.initializeScanMode(mode: ScanMode.readonly);

      // Create test email matching delete rule
      final testEmail = EmailMessage(
        id: '1',
        from: 'spammer@test.com',
        subject: 'SPAM - Test Email',
        body: 'Test body',
        headers: {'From': 'spammer@test.com', 'Subject': 'SPAM - Test Email'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      // Mock platform to track takeAction calls
      mockPlatform.setTestEmails([testEmail]);
      int takeActionCallCount = 0;
      mockPlatform.onTakeAction = () {
        takeActionCallCount++;
      };

      // Act: Scan with readonly mode
      await scanner.scanInbox(daysBack: 7);

      // Assert: platform.takeAction() was NEVER called
      expect(takeActionCallCount, 0,
        reason: 'CRITICAL: Readonly mode MUST NOT call platform.takeAction(). Issue #9 regression detected!');

      // Verify result was recorded with delete action
      expect(scanProvider.results.length, 1);
      expect(scanProvider.results.first.action, EmailActionType.delete);
      expect(scanProvider.deletedCount, 1,
        reason: 'Deleted count should increment (proposed action tracked)');
    });

    test('ScanMode.fullScan allows platform.takeAction() calls', () async {
      // Arrange: Set full scan mode
      scanProvider.initializeScanMode(mode: ScanMode.fullScan);

      // Create test email matching delete rule
      final testEmail = EmailMessage(
        id: '1',
        from: 'spammer@test.com',
        subject: 'SPAM - Test Email',
        body: 'Test body',
        headers: {'From': 'spammer@test.com', 'Subject': 'SPAM - Test Email'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      // Mock platform to track takeAction calls
      mockPlatform.setTestEmails([testEmail]);
      int takeActionCallCount = 0;
      mockPlatform.onTakeAction = () {
        takeActionCallCount++;
      };

      // Act: Scan with full scan mode
      await scanner.scanInbox(daysBack: 7);

      // Assert: platform.takeAction() WAS called
      expect(takeActionCallCount, 1,
        reason: 'Full scan mode MUST call platform.takeAction()');

      // Verify result was recorded
      expect(scanProvider.results.length, 1);
      expect(scanProvider.results.first.action, EmailActionType.delete);
      expect(scanProvider.deletedCount, 1);
    });

    test('ScanMode.testLimit respects email limit', () async {
      // Arrange: Set test limit mode (max 2 emails)
      scanProvider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 2);

      // Create 5 test emails matching delete rule
      final testEmails = List.generate(5, (i) => EmailMessage(
        id: '$i',
        from: 'spammer@test.com',
        subject: 'SPAM - Test Email $i',
        body: 'Test body',
        headers: {'From': 'spammer@test.com', 'Subject': 'SPAM - Test Email $i'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      ));

      // Mock platform to track takeAction calls
      mockPlatform.setTestEmails(testEmails);
      int takeActionCallCount = 0;
      mockPlatform.onTakeAction = () {
        takeActionCallCount++;
      };

      // Act: Scan with test limit mode
      await scanner.scanInbox(daysBack: 7);

      // Assert: platform.takeAction() called exactly 2 times (limit respected)
      expect(takeActionCallCount, 2,
        reason: 'Test limit mode must respect email limit');

      // Verify all 5 results were recorded (but only 2 executed)
      expect(scanProvider.results.length, 5);
      expect(scanProvider.deletedCount, 5,
        reason: 'All proposed deletes counted, but only 2 executed');
    });

    test('Readonly mode logs proposed actions without executing', () async {
      // Arrange: Set readonly mode
      scanProvider.initializeScanMode(mode: ScanMode.readonly);

      // Create test emails with different rule matches
      final testEmails = [
        EmailMessage(
          id: '1',
          from: 'spammer@test.com',
          subject: 'SPAM - Delete Me',
          body: 'Test',
          headers: {'From': 'spammer@test.com', 'Subject': 'SPAM - Delete Me'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        EmailMessage(
          id: '2',
          from: 'safe@example.com',
          subject: 'Normal Email',
          body: 'Test',
          headers: {'From': 'safe@example.com', 'Subject': 'Normal Email'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
      ];

      mockPlatform.setTestEmails(testEmails);
      int takeActionCallCount = 0;
      mockPlatform.onTakeAction = () {
        takeActionCallCount++;
      };

      // Act: Scan
      await scanner.scanInbox(daysBack: 7);

      // Assert: No actions executed
      expect(takeActionCallCount, 0, reason: 'Readonly mode must not execute actions');

      // Verify results recorded
      expect(scanProvider.results.length, 2);
      expect(scanProvider.results[0].action, EmailActionType.delete,
        reason: 'First email should be marked for deletion');
      expect(scanProvider.results[1].action, EmailActionType.none,
        reason: 'Second email has no rule match');
    });
  });
}

/// Mock platform for testing
class MockSpamFilterPlatform implements SpamFilterPlatform {
  List<EmailMessage> _testEmails = [];
  Function()? onTakeAction;

  void setTestEmails(List<EmailMessage> emails) {
    _testEmails = emails;
  }

  @override
  String get platformId => 'test';

  @override
  String get displayName => 'Test Platform';

  @override
  AuthMethod get supportedAuthMethod => AuthMethod.appPassword;

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    // No-op for testing
  }

  @override
  void setDeletedRuleFolder(String? folderName) {
    // No-op for testing
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    return _testEmails;
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    // Track that takeAction was called
    if (onTakeAction != null) {
      onTakeAction!();
    }
  }

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {
    // No-op for testing
  }

  @override
  Future<void> markAsRead({
    required EmailMessage message,
  }) async {
    // No-op for testing
  }

  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {
    // No-op for testing
  }

  @override
  Future<List<FolderInfo>> listFolders() async {
    return [
      FolderInfo(
        id: 'INBOX',
        displayName: 'Inbox',
        canonicalName: CanonicalFolder.inbox,
        messageCount: 0,
        isWritable: true,
      ),
    ];
  }

  @override
  Future<ConnectionStatus> testConnection() async {
    return ConnectionStatus.success();
  }

  @override
  Future<void> disconnect() async {
    // No-op for testing
  }

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async {
    // Not used in this test flow
    return [];
  }
}
