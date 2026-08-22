/// Read-only mode enforcement (Issue #9 regression prevention) -- REBUILT
/// F163 R-3 (Sprint 62) against the current architecture, per Harold's
/// approved F160 verdict. The group had been skipped since Issue #117: it
/// waited on a `loadRulesFromString` that was never built, while the
/// product's CORE safety promise (read-only scans never touch the mailbox)
/// sat uncovered. Issue #9 context: a read-only bypass once deleted 526
/// real emails during testing.
///
/// What changed in the rebuild:
/// - Rules load through the real database path (DatabaseTestHelper +
///   RuleSetProvider.initializeForTesting + addRule) -- the F160-recommended
///   pattern -- instead of the never-built string loader.
/// - Credentials come from a fake SecureCredentialsStore via the new
///   EmailScanner `credStore` seam (platform-channel storage cannot run in
///   unit tests); the platform is registered through
///   PlatformRegistry.overrideFactoryForTest, so the REAL full scanInbox
///   pipeline runs end to end.
/// - Action counting hooks the mixin's takeActionBatch fallback (the batch
///   architecture routes per-message takeAction through it), replacing the
///   pre-#144 per-email assumptions.
///
/// Mutation-verified at authoring: forcing canExecuteRules to true in the
/// scanner turns the read-only test red.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../helpers/database_test_helper.dart';

class _FakeCredStore extends SecureCredentialsStore {
  @override
  Future<Credentials?> getCredentials(String accountId) async =>
      Credentials(email: 'test@test.com', password: 'irrelevant');
}

class _CountingPlatform with BatchOperationsMixin implements SpamFilterPlatform {
  static List<EmailMessage> testEmails = [];
  static int takeActionCallCount = 0;

  @override
  String get platformId => 'test';
  @override
  String get displayName => 'Test Platform';
  @override
  AuthMethod get supportedAuthMethod => AuthMethod.appPassword;

  @override
  Future<void> loadCredentials(Credentials credentials) async {}

  @override
  void setDeletedRuleFolder(String? folderName) {}

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async =>
      testEmails;

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    takeActionCallCount++;
  }

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {}

  @override
  Future<void> markAsRead({required EmailMessage message}) async {}

  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {}

  @override
  Future<List<FolderInfo>> listFolders() async => [
        FolderInfo(
          id: 'INBOX',
          displayName: 'Inbox',
          canonicalName: CanonicalFolder.inbox,
          messageCount: 0,
          isWritable: true,
        ),
      ];

  @override
  Future<ConnectionStatus> testConnection() async =>
      ConnectionStatus.success();

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async =>
      [];
}

EmailMessage _spamEmail(String id) => EmailMessage(
      id: id,
      from: 'spammer@blockedspam.example',
      subject: 'SPAM - Test Email $id',
      body: 'Test body',
      headers: {
        'From': 'spammer@blockedspam.example',
        'Subject': 'SPAM - Test Email $id',
      },
      receivedDate: DateTime.now(),
      folderName: 'INBOX',
    );

EmailMessage _cleanEmail(String id) => EmailMessage(
      id: id,
      from: 'friend@example.com',
      subject: 'Normal Email $id',
      body: 'Test body',
      headers: {
        'From': 'friend@example.com',
        'Subject': 'Normal Email $id',
      },
      receivedDate: DateTime.now(),
      folderName: 'INBOX',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('EmailScanner read-only enforcement (Issue #9 prevention)', () {
    late DatabaseTestHelper testHelper;
    late RuleSetProvider ruleProvider;
    const accountId = 'test-account@test.com';

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();

      ruleProvider = RuleSetProvider();
      ruleProvider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();
      await ruleProvider.addRule(Rule(
        name: 'Block_EntireDomain_blockedspam.example',
        enabled: true,
        isLocal: true,
        executionOrder: 10,
        conditions: RuleConditions(
            type: 'OR', header: [r'@(?:[a-z0-9-]+\.)*blockedspam\.example$']),
        actions: RuleActions(delete: true),
      ));

      _CountingPlatform.testEmails = [];
      _CountingPlatform.takeActionCallCount = 0;
      final previous = PlatformRegistry.overrideFactoryForTest(
          'test', () => _CountingPlatform());
      addTearDown(
          () => PlatformRegistry.overrideFactoryForTest('test', previous));
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    EmailScanner makeScanner(EmailScanProvider scanProvider) => EmailScanner(
          platformId: 'test',
          accountId: accountId,
          ruleSetProvider: ruleProvider,
          scanProvider: scanProvider,
          credStore: _FakeCredStore(),
        );

    test(
        'ScanMode.readOnly NEVER calls platform.takeAction, while still '
        'recording the proposed delete', () async {
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      _CountingPlatform.testEmails = [_spamEmail('1')];

      await makeScanner(scanProvider).scanInbox(daysBack: 7);

      expect(_CountingPlatform.takeActionCallCount, 0,
          reason: 'CRITICAL: read-only mode MUST NOT touch the mailbox -- '
              'the Issue #9 bypass deleted 526 real emails');
      expect(scanProvider.deletedCount, 1,
          reason: 'the proposed (simulated) delete is still counted so the '
              'user sees what a real run WOULD do');
      expect(_CountingPlatform.takeActionCallCount, 0,
          reason: 're-checked after counting: recording must not execute');
    });

    test('ScanMode.safeSendersAndRules DOES execute the delete', () async {
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.safeSendersAndRules);
      _CountingPlatform.testEmails = [_spamEmail('1')];

      await makeScanner(scanProvider).scanInbox(daysBack: 7);

      expect(_CountingPlatform.takeActionCallCount, 1,
          reason: 'full-scan mode must execute the matched delete (through '
              'the takeActionBatch -> takeAction mixin fallback)');
      expect(scanProvider.deletedCount, 1);
    });

    test(
        'read-only with mixed emails: proposals recorded per email, nothing '
        'executed', () async {
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      _CountingPlatform.testEmails = [_spamEmail('1'), _cleanEmail('2')];

      await makeScanner(scanProvider).scanInbox(daysBack: 7);

      expect(_CountingPlatform.takeActionCallCount, 0);
      expect(scanProvider.deletedCount, 1,
          reason: 'the spam email records a simulated delete');
      expect(scanProvider.noRuleCount, 1,
          reason: 'the clean email records as no-rule');
    });
  });
}
