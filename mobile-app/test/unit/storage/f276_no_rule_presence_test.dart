/// F276 (Sprint 80): No Rule Review does not list mail that is gone.
///
/// A scan checks, in its open session, whether the listed No Rule rows of the
/// folder it just fetched still exist ([MessagePresenceChecker]); rows found
/// deleted or moved are hidden from Review, and a later sighting lists them
/// again.
///
/// What these tests do NOT catch (one line each):
///   - store/reconciler: a real server's UID SEARCH answer for UIDs after a
///     UIDVALIDITY change (all UIDs read absent; the next scan re-lists them as
///     new rows -- by design, not exercised);
///   - IMAP adapter: SEARCH syntax a real server rejects (the fake accepts any
///     criteria; the criteria string is asserted instead);
///   - Gmail adapter: a real 404 body shape (the fake throws the same
///     DetailedApiRequestError type the googleapis client throws);
///   - scanner wiring: Gmail incremental (history) scans -- the check runs
///     after any successful folder fetch, so the path is the same, but only
///     the full-fetch fake is driven here.
library;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/services/no_rule_presence_reconciler.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

/// Answers presence from a fixed map; records what it was asked.
class _FakeChecker implements MessagePresenceChecker {
  _FakeChecker(this.answers, {this.error});

  final Map<String, MessagePresence> answers;
  final Object? error;
  final List<List<String>> asked = [];

  @override
  Future<Map<String, MessagePresence>> checkMessagesPresent({
    required String folderName,
    required List<String> ids,
  }) async {
    asked.add(List.of(ids));
    if (error != null) throw error!;
    return {
      for (final id in ids)
        if (answers.containsKey(id)) id: answers[id]!,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  late DatabaseTestHelper testHelper;
  late UnmatchedEmailStore store;
  const account = 'aol-a@b.com';

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = UnmatchedEmailStore(testHelper.dbHelper);
    for (final a in [account, 'aol-other@b.com', 'test-account@test.com']) {
      await testHelper.createTestAccount(a);
    }
  });

  tearDown(() async => testHelper.tearDown());

  UnmatchedEmail row(int scanId, String id, {String folder = 'INBOX'}) =>
      UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'email_id',
        providerIdentifierValue: id,
        fromEmail: 'sender@spam.example',
        subject: 'Hello $id',
        folderName: folder,
        createdAt: DateTime.now(),
      );

  // A sighting stamps the row checked (upsertUnmatchedEmails). Clearing the
  // stamp makes the rows due, as rows written before F276 are.
  Future<void> makeDue() async {
    final db = await testHelper.dbHelper.database;
    await db.update('unmatched_emails', {'availability_checked_at': null});
  }

  Future<Set<String>> listed(String accountId) async =>
      (await store.getUnprocessedForAccount(accountId))
          .map((e) => e.providerIdentifierValue)
          .toSet();

  group('reconciler + store', () {
    test('absent and moved rows leave Review; present stays and is marked '
        'available', () async {
      final scan = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails(
          [row(scan, '1'), row(scan, '2'), row(scan, '3')]);
      await makeDue();
      final checker = _FakeChecker({
        '1': MessagePresence.present,
        '2': MessagePresence.absent,
        '3': MessagePresence.moved,
      });

      final out = await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);

      expect(out.checked, 3);
      expect(out.deleted, 1);
      expect(out.moved, 1);
      expect(await listed(account), {'1'});
      final rows = await store.getUnprocessedForAccount(account);
      expect(rows.single.availabilityStatus,
          UnmatchedEmailStore.availabilityAvailable);
    });

    test('a later sighting lists a hidden row again', () async {
      final scan = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan, '7')]);
      await makeDue();
      await reconcileNoRulePresence(
          checker: _FakeChecker({'7': MessagePresence.absent}),
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);
      expect(await listed(account), isEmpty);

      final scan2 = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan2, '7')]);
      expect(await listed(account), {'7'});
    });

    test('a row checked within the hour is not asked again; one checked '
        'earlier is', () async {
      final scan = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan, '9')]);
      await makeDue();
      final checker = _FakeChecker({'9': MessagePresence.present});
      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);
      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);
      expect(checker.asked, hasLength(1));

      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500,
          now: DateTime.now().add(const Duration(hours: 2)));
      expect(checker.asked, hasLength(2));
    });

    // Found in the 5.1.9 rehearsal on the DEV database: a re-sighting wrote
    // toMap's 'unknown' / never-checked, so every scan re-asked every row it
    // had just seen. What this does NOT catch: a scan that fetches a folder
    // but does not upsert a seen row (rule-matched mail is not a No Rule row
    // and never reaches this table).
    test('a re-sighting records the row present and checked: the next scan '
        'does not ask about it', () async {
      final scan = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan, '5')]);
      await makeDue();
      final checker = _FakeChecker({'5': MessagePresence.present});
      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);
      expect(checker.asked, hasLength(1));

      final scan2 = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan2, '5')]);
      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 500);
      expect(checker.asked, hasLength(1));
      final kept = (await store.getUnprocessedForAccount(account)).single;
      expect(kept.availabilityStatus, UnmatchedEmailStore.availabilityAvailable);
      expect(kept.availabilityCheckedAt, isNotNull);
    });

    test('only this account and folder are asked; the limit is honored',
        () async {
      final scanA = await testHelper.createTestScanResult(account);
      final scanB = await testHelper.createTestScanResult('aol-other@b.com');
      await store.upsertUnmatchedEmails([
        row(scanA, '1'),
        row(scanA, '2'),
        row(scanA, '3'),
        row(scanA, 's1', folder: 'Bulk'),
        row(scanB, 'b1'),
      ]);
      await makeDue();
      final checker = _FakeChecker({});
      await reconcileNoRulePresence(
          checker: checker,
          store: store,
          accountId: account,
          folderName: 'INBOX',
          limit: 2);
      expect(checker.asked.single, hasLength(2));
      expect(checker.asked.single.toSet().difference({'1', '2', '3'}), isEmpty);
    });

    test('a checker failure propagates and leaves every row listed', () async {
      final scan = await testHelper.createTestScanResult(account);
      await store.upsertUnmatchedEmails([row(scan, '1')]);
      await makeDue();
      await expectLater(
          reconcileNoRulePresence(
              checker: _FakeChecker({}, error: StateError('network')),
              store: store,
              accountId: account,
              folderName: 'INBOX',
              limit: 500),
          throwsStateError);
      expect(await listed(account), {'1'});
    });
  });

  group('IMAP adapter', () {
    test('one UID SEARCH for the listed UIDs; UIDs not returned are absent; '
        'non-UID ids get no answer', () async {
      final client = _SearchClient(found: [1, 3]);
      final adapter = GenericIMAPAdapter(
          imapHost: 'imap.example.com', platformId: 'aol')
        ..debugSetImapClient(client);

      final result = await adapter.checkMessagesPresent(
          folderName: 'Bulk', ids: ['1', '2', '3', 'abc']);

      expect(client.selected, ['Bulk']);
      expect(client.criteria, ['UID 1,2,3']);
      expect(result, {
        '1': MessagePresence.present,
        '2': MessagePresence.absent,
        '3': MessagePresence.present,
      });
    });
  });

  group('Gmail adapter', () {
    test('label kept = present, label gone = moved, 404 = absent, other error '
        '= no answer, 401 throws', () async {
      final api = _FakeGmailApi({
        'a': ['INBOX', 'UNREAD'],
        'b': ['TRASH'],
      }, errors: {
        'c': 404,
        'd': 500,
      });
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);

      final result = await adapter.checkMessagesPresent(
          folderName: 'INBOX', ids: ['a', 'b', 'c', 'd']);
      expect(result, {
        'a': MessagePresence.present,
        'b': MessagePresence.moved,
        'c': MessagePresence.absent,
      });

      final refused = _FakeGmailApi({}, errors: {'x': 401});
      final adapter2 = GmailApiAdapter()..debugSetGmailApi(refused);
      await expectLater(
          adapter2.checkMessagesPresent(folderName: 'INBOX', ids: ['x']),
          throwsA(isA<gmail.DetailedApiRequestError>()));
    });
  });

  group('scanner wiring', () {
    late RuleSetProvider ruleProvider;
    const scanAccount = 'test-account@test.com';

    setUp(() async {
      ruleProvider = RuleSetProvider();
      ruleProvider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();
    });

    Future<EmailScanProvider> scanWith(_PresencePlatform platform) async {
      final previous =
          PlatformRegistry.overrideFactoryForTest('test', () => platform);
      addTearDown(
          () => PlatformRegistry.overrideFactoryForTest('test', previous));
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      await EmailScanner(
        platformId: 'test',
        accountId: scanAccount,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
        credStore: _FakeCredStore(),
      ).scanInbox(daysBack: 7).catchError((Object _) {});
      return scanProvider;
    }

    test('a read-only scan marks a listed row of the scanned folder gone',
        () async {
      final scan = await testHelper.createTestScanResult(scanAccount);
      await store.upsertUnmatchedEmails([row(scan, 'gone1')]);
      await makeDue();
      expect(await listed(scanAccount), {'gone1'});

      final platform =
          _PresencePlatform({'gone1': MessagePresence.absent});
      await scanWith(platform);

      expect(platform.asked, isNotEmpty);
      expect(await listed(scanAccount), isEmpty);
    });

    test('a non-fatal check failure leaves the row listed and the scan '
        'completes', () async {
      final scan = await testHelper.createTestScanResult(scanAccount);
      await store.upsertUnmatchedEmails([row(scan, 'keep1')]);
      await makeDue();

      final platform = _PresencePlatform({}, error: StateError('boom'));
      await scanWith(platform);

      expect(platform.asked, isNotEmpty);
      expect(await listed(scanAccount), {'keep1'});
    });

    // Sprint 75 IMP-3 walk: the check's catch must not swallow a session
    // failure (a refused sign-in mid-scan), or the scan would read as
    // completed. What this does NOT catch: which message the user then sees.
    test('a session-fatal check error is not swallowed: the scan ends in error',
        () async {
      final scan = await testHelper.createTestScanResult(scanAccount);
      await store.upsertUnmatchedEmails([row(scan, 'x1')]);
      await makeDue();

      final platform = _PresencePlatform({},
          error: AuthenticationException('refused'));
      final provider = await scanWith(platform);

      expect(platform.asked, isNotEmpty);
      expect(provider.status, ScanStatus.error);
    });
  });
}

class _SearchClient extends ImapClient {
  _SearchClient({required this.found}) : super(isLogEnabled: false);

  final List<int> found;
  final List<String> selected = [];
  final List<String> criteria = [];

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async {
    selected.add(path);
    return Mailbox(
        encodedName: path, encodedPath: path, pathSeparator: '/', flags: []);
  }

  @override
  Future<SearchImapResult> uidSearchMessages({
    String searchCriteria = 'UNSEEN',
    List<ReturnOption>? returnOptions,
    Duration? responseTimeout,
  }) async {
    criteria.add(searchCriteria);
    return SearchImapResult()
      ..matchingSequence = MessageSequence.fromIds(found, isUid: true);
  }
}

class _FakeGmailApi implements gmail.GmailApi {
  _FakeGmailApi(this.labelsById, {this.errors = const {}});

  final Map<String, List<String>> labelsById;
  final Map<String, int> errors;

  @override
  late final users = _FakeUsers(this);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeUsers implements gmail.UsersResource {
  _FakeUsers(this.api);
  final _FakeGmailApi api;

  @override
  late final messages = _FakeMessages(api);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeMessages implements gmail.UsersMessagesResource {
  _FakeMessages(this.api);
  final _FakeGmailApi api;

  @override
  Future<gmail.Message> get(
    String userId,
    String id, {
    String? format,
    List<String>? metadataHeaders,
    String? $fields,
  }) async {
    final status = api.errors[id];
    if (status != null) {
      throw gmail.DetailedApiRequestError(status, 'status $status');
    }
    return gmail.Message(id: id, labelIds: api.labelsById[id]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeCredStore extends SecureCredentialsStore {
  @override
  Future<Credentials?> getCredentials(String accountId) async =>
      Credentials(email: 'test@test.com', password: 'irrelevant');
}

/// A scan platform with no mail that answers presence from a map.
class _PresencePlatform
    with BatchOperationsMixin
    implements SpamFilterPlatform, MessagePresenceChecker {
  _PresencePlatform(this.answers, {this.error});

  final Map<String, MessagePresence> answers;
  final Object? error;
  final List<List<String>> asked = [];

  @override
  Future<Map<String, MessagePresence>> checkMessagesPresent({
    required String folderName,
    required List<String> ids,
  }) async {
    asked.add(List.of(ids));
    if (error != null) throw error!;
    return {
      for (final id in ids)
        if (answers.containsKey(id)) id: answers[id]!,
    };
  }

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
      [];
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
