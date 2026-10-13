/// R76-4 (Sprint 78, ADR-0047): the content history captured by the REAL scan
/// pipeline -- `EmailScanner.scanInbox` end to end, through the platform
/// registry seam (the same harness as `email_scanner_readonly_mode_test.dart`).
///
/// Proves the WIRING the policy test only reads: with the history on, a scan
/// stores one row per email with its outcome and fetches each body once; a
/// second scan of the same mail stores and fetches nothing; with the switch
/// off nothing is fetched and no file is created.
///
/// What this does NOT catch: a real IMAP/Gmail content fetch (fixtures in
/// `r76_4_content_history_test.dart` cover the extraction), or the Windows
/// background worker launching the scan (it calls the same `scanInbox`).
library;

import 'package:flutter/material.dart';
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
import 'package:my_email_spam_filter/core/services/content_history.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/storage/content_history_store.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/widgets/content_history_row.dart';

import '../helpers/database_test_helper.dart';

class _FakeCredStore extends SecureCredentialsStore {
  @override
  Future<Credentials?> getCredentials(String accountId) async =>
      Credentials(email: 'test@test.com', password: 'irrelevant');
}

class _TextPlatform with BatchOperationsMixin implements SpamFilterPlatform {
  static List<EmailMessage> testEmails = [];
  static int textFetches = 0;

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
  Future<String?> fetchContentText(EmailMessage message) async {
    textFetches++;
    return 'Text of ${message.id}';
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {}
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
  Future<ConnectionStatus> testConnection() async => ConnectionStatus.success();
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async =>
      [];
}

EmailMessage _email(String id, String from) => EmailMessage(
      id: id,
      from: from,
      subject: 'Subject $id',
      body: '',
      headers: {'From': from, 'Subject': 'Subject $id'},
      receivedDate: DateTime.now(),
      folderName: 'INBOX',
      messageIdHeader: '<$id@test.example>',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;
  late RuleSetProvider ruleProvider;
  const accountId = 'test-account@test.com';

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
    ruleProvider = RuleSetProvider();
    ruleProvider.initializeForTesting(
      databaseStore: RuleDatabaseStore(testHelper.dbHelper),
      safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
    );
    await ruleProvider.loadRules();
    await ruleProvider.loadSafeSenders();
    await ruleProvider.addRule(Rule(
      name: 'Block_spam',
      enabled: true,
      isLocal: true,
      executionOrder: 10,
      conditions: RuleConditions(type: 'OR', header: [r'@spam\.example$']),
      actions: RuleActions(delete: true),
    ));
    _TextPlatform.testEmails = [
      _email('1', 'a@spam.example'),
      _email('2', 'friend@example.com'),
    ];
    _TextPlatform.textFetches = 0;
    final previous =
        PlatformRegistry.overrideFactoryForTest('test', () => _TextPlatform());
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('test', previous));
    ContentHistory.debugIsDevOverride = true;
  });

  tearDown(() async {
    ContentHistory.debugIsDevOverride = null;
    await ContentHistoryStore.instance.deleteAll();
    await testHelper.tearDown();
  });

  Future<void> scan() => EmailScanner(
        platformId: 'test',
        accountId: accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: EmailScanProvider()
          ..initializeScanMode(mode: ScanMode.readOnly),
        credStore: _FakeCredStore(),
      ).scanInbox(daysBack: 7);

  test('with the history on, a scan stores one row per email with its outcome; '
      'a second scan stores and fetches nothing', () async {
    await SettingsStore().setContentHistoryEnabled(true);

    await scan();
    final store = ContentHistoryStore.instance;
    expect(await store.count(), 2);
    expect(_TextPlatform.textFetches, 2);
    final db = await store.database;
    final outcomes = {
      for (final r in await db.query('content_history'))
        r['from_address']: r['outcome']
    };
    expect(outcomes, {'a@spam.example': 'delete', 'friend@example.com': 'no_rule'});

    await scan();
    expect(await store.count(), 2, reason: 'a repeat scan writes no row');
    expect(_TextPlatform.textFetches, 2,
        reason: 'a repeat scan fetches no body (ADR-0047 item 4)');
  });

  // 5.1.9 rehearsal of MV step W4: after a capturing scan, Settings >
  // General shows the switch on and "<N> stored.", with Delete enabled.
  testWidgets('Settings > General shows the switch on and "2 stored." after '
      'a capturing scan', (tester) async {
    await tester.runAsync(() async {
      await SettingsStore().setContentHistoryEnabled(true);
      await scan();
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ContentHistoryRow())));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining('2 stored.'), findsOneWidget);
    expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('content_history_switch')))
            .value,
        isTrue);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('content_history_delete')))
            .onPressed,
        isNotNull);
  });

  test('with the switch off, nothing is fetched and no file is created',
      () async {
    await scan();
    expect(_TextPlatform.textFetches, 0);
    expect(ContentHistoryStore.instance.fileExists(), isFalse);
  });

  test('a prod build captures nothing even with the switch on', () async {
    await SettingsStore().setContentHistoryEnabled(true);
    ContentHistory.debugIsDevOverride = false;
    await scan();
    expect(_TextPlatform.textFetches, 0);
    expect(ContentHistoryStore.instance.fileExists(), isFalse);
  });
}
