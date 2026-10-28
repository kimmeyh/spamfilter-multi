/// F259 (Sprint 81): a missing Gmail label is visible, and the Gmail history
/// cursor is kept per account AND folder.
///
/// Before F259 a label that did not exist scanned as "0 messages" with no
/// trace (the null was cached for the whole connection, and the lookup was
/// case-sensitive), and INBOX saved the account's current historyId first, so
/// a later folder (SPAM, a custom label) read changes "since now" and never
/// saw the mail already waiting there.
///
/// Drives the REAL `GmailApiAdapter` against a fake `GmailApi`, the REAL
/// `DatabaseHelper` cursor store, and the REAL `EmailScanner` (Gmail
/// subclass that skips only the sign-in).
///
/// What these tests do NOT catch (one line each):
///   - Gmail itself: a real `labels.list` answer (label names with nesting,
///     system labels listed by name) and a real `history.list` 404 on a stale
///     cursor are modeled by the fake, not exercised;
///   - the migration: v15 is tested in `f259_history_cursor_migration_test`;
///   - background workers: they call the same `EmailScanner.scanInbox`, so
///     they are covered by the scanner test here, not driven separately.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';

/// Fake Gmail API. [labels] is mutable: a test adds a label between calls.
class _FakeGmail implements gmail.GmailApi {
  _FakeGmail({List<gmail.Label>? labels})
      : labels = labels ??
            [
              gmail.Label(name: 'Archive', id: 'Label_10'),
              gmail.Label(name: 'Unwanted', id: 'Label_7'),
            ];

  final List<gmail.Label> labels;
  int labelsListCalls = 0;
  final List<String?> historyLabelIds = [];
  final List<String?> historyStartIds = [];
  final List<String?> messageQueries = [];
  final List<gmail.ModifyMessageRequest> modifies = [];
  int messageGets = 0;
  String profileHistoryId = '500';
  String historyResponseId = '300';

  @override
  late final users = _FakeUsers(this);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeUsers implements gmail.UsersResource {
  _FakeUsers(this.api);
  final _FakeGmail api;

  @override
  late final labels = _FakeLabels(api);
  @override
  late final history = _FakeHistory(api);
  @override
  late final messages = _FakeMessages(api);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getProfile) {
      return Future.value(gmail.Profile(historyId: api.profileHistoryId));
    }
    throw UnimplementedError('${invocation.memberName}');
  }
}

class _FakeLabels implements gmail.UsersLabelsResource {
  _FakeLabels(this.api);
  final _FakeGmail api;

  @override
  Future<gmail.ListLabelsResponse> list(String userId, {String? $fields}) async {
    api.labelsListCalls++;
    return gmail.ListLabelsResponse(labels: List.of(api.labels));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHistory implements gmail.UsersHistoryResource {
  _FakeHistory(this.api);
  final _FakeGmail api;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #list) {
      api.historyLabelIds.add(invocation.namedArguments[#labelId] as String?);
      api.historyStartIds
          .add(invocation.namedArguments[#startHistoryId] as String?);
      return Future.value(
          gmail.ListHistoryResponse(historyId: api.historyResponseId));
    }
    throw UnimplementedError('${invocation.memberName}');
  }
}

class _FakeMessages implements gmail.UsersMessagesResource {
  _FakeMessages(this.api);
  final _FakeGmail api;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #list) {
      api.messageQueries.add(invocation.namedArguments[#q] as String?);
      return Future.value(gmail.ListMessagesResponse());
    }
    if (invocation.memberName == #modify) {
      api.modifies.add(invocation.positionalArguments[0]
          as gmail.ModifyMessageRequest);
      return Future.value(gmail.Message(
          id: invocation.positionalArguments[2] as String));
    }
    if (invocation.memberName == #get) {
      api.messageGets++;
      return Future.value(gmail.Message(id: 'x'));
    }
    throw UnimplementedError('${invocation.memberName}');
  }
}

/// The real Gmail adapter with only the sign-in skipped (the scanner calls
/// `loadCredentials`; the fake API is already set).
class _TestGmailAdapter extends GmailApiAdapter {
  @override
  Future<void> loadCredentials(Credentials credentials) async {}
}

class _FakeCredStore extends SecureCredentialsStore {
  @override
  Future<Credentials?> getCredentials(String accountId) async =>
      Credentials(email: 'test@test.com', password: 'irrelevant');
}

EmailMessage _msg(String id, String folder) => EmailMessage(
      id: id,
      from: 'sender@example.com',
      subject: 'subject',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 10, 23),
      folderName: folder,
    );

void main() {
  late Directory diagDir;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() {
    diagDir = Directory.systemTemp.createTempSync('f259_diag_');
    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(diagDir.path);
  });

  tearDown(() {
    DiagnosticLogger.debugSetEnabled(null);
    DiagnosticLogger.debugSetDir(null);
    try {
      diagDir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  String diag() => diagDir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.readAsStringSync())
      .join('\n');

  /// Up to 10 s (see f302_no_valid_imap_uid_test: a 3 s limit failed once
  /// under a loaded parallel run). Returns as soon as [text] shows.
  Future<String> diagWith(String text) async {
    for (var i = 0; i < 200 && !diag().contains(text); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return diag();
  }

  group('T-1: a missing label is visible (R-1, R-2)', () {
    test('incremental fetch of a label that does not exist throws and logs; '
        'history.list is never called', () async {
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);

      await expectLater(
          adapter.fetchMessagesIncremental(
              startHistoryId: '90', folderForLabel: 'Gone'),
          throwsA(isA<GmailLabelNotFoundException>()));

      expect(api.historyLabelIds, isEmpty);
      final log = await diagWith('Gmail/labelIdFor');
      expect(log, contains('label "Gone" not found'));
    });

    test('a miss is trusted for labelMissTtl only: a label added later is '
        'found on retry after it, then the hit IS cached', () async {
      var now = DateTime(2026, 10, 24, 1, 0);
      GmailApiAdapter.debugClock = () => now;
      addTearDown(() => GmailApiAdapter.debugClock = DateTime.now);
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);

      await expectLater(
          adapter.fetchMessagesIncremental(
              startHistoryId: '90', folderForLabel: 'Renamed'),
          throwsA(isA<GmailLabelNotFoundException>()));
      expect(api.labelsListCalls, 1);

      // The user renames a label to the configured name (different case).
      api.labels.add(gmail.Label(name: 'RENAMED', id: 'Label_9'));

      // F-PRECHECK (Sprint 81): inside the window the miss is answered from
      // the cache -- no second account-wide labels.list call.
      await expectLater(
          adapter.fetchMessagesIncremental(
              startHistoryId: '90', folderForLabel: 'Renamed'),
          throwsA(isA<GmailLabelNotFoundException>()));
      expect(api.labelsListCalls, 1, reason: 'a fresh miss is cached');

      now = now.add(GmailApiAdapter.labelMissTtl);

      final result = await adapter.fetchMessagesIncremental(
          startHistoryId: '90', folderForLabel: 'Renamed');
      expect(result.isExpired, isFalse);
      expect(api.labelsListCalls, 2, reason: 'the miss asked Gmail again');
      expect(api.historyLabelIds, ['Label_9']);

      await adapter.fetchMessagesIncremental(
          startHistoryId: '91', folderForLabel: 'Renamed');
      expect(api.labelsListCalls, 2, reason: 'the hit is cached');
      expect(api.historyLabelIds, ['Label_9', 'Label_9']);
    });

    test('the lookup ignores case in both directions', () async {
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);
      await adapter.fetchMessagesIncremental(
          startHistoryId: '1', folderForLabel: 'unwanted');
      await adapter.fetchMessagesIncremental(
          startHistoryId: '1', folderForLabel: 'UNWANTED');
      expect(api.historyLabelIds, ['Label_7', 'Label_7']);
      expect(api.labelsListCalls, 1);
    });

    test('7.7.1: two labels that differ only in case -- the exact name wins, '
        'and a case-only match is not guessed', () async {
      // Whether Gmail allows this is unverified; the lookup must not pick
      // the wrong one if it does.
      final api = _FakeGmail(labels: [
        gmail.Label(name: 'Foo', id: 'Label_1'),
        gmail.Label(name: 'foo', id: 'Label_2'),
      ]);
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);
      await adapter.fetchMessagesIncremental(
          startHistoryId: '1', folderForLabel: 'foo');
      await adapter.fetchMessagesIncremental(
          startHistoryId: '1', folderForLabel: 'Foo');
      expect(api.historyLabelIds, ['Label_2', 'Label_1']);
      await expectLater(
          adapter.fetchMessagesIncremental(
              startHistoryId: '1', folderForLabel: 'FOO'),
          throwsA(isA<GmailLabelNotFoundException>()));
    });

    test('the full fetch of a missing custom label throws before any query',
        () async {
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);
      await expectLater(
          adapter.fetchMessages(daysBack: 7, folderNames: ['Gone']),
          throwsA(isA<GmailLabelNotFoundException>()));
      expect(api.messageQueries, isEmpty,
          reason: 'label:Gone would have answered zero messages with no trace');
    });

    test('the full fetch of a system folder needs no label lookup', () async {
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);
      final r = await adapter.fetchMessages(daysBack: 7, folderNames: ['SPAM']);
      expect(r, isEmpty);
      expect(api.labelsListCalls, 0);
      expect(api.messageQueries.single, contains('in:spam'));
    });

    test('the other callers of the lookup, on a missing label', () async {
      final api = _FakeGmail();
      final adapter = GmailApiAdapter()..debugSetGmailApi(api);

      // moveMessage (target): throws, as before.
      await expectLater(adapter.moveMessage(_msg('m1', 'INBOX'), 'Gone'),
          throwsA(isA<GmailLabelNotFoundException>()));
      // _resolvedMoveLabels (target): throws, as before.
      await expectLater(
          adapter.moveToFolder(message: _msg('m2', 'INBOX'), targetFolder: 'Gone'),
          throwsA(isA<GmailLabelNotFoundException>()));
      expect(api.modifies, isEmpty);

      // _resolvedMoveLabels (SOURCE): tolerated, as before -- the move goes
      // ahead and only the lookup is logged.
      await adapter.moveToFolder(
          message: _msg('m3', 'GoneSource'), targetFolder: 'Archive');
      expect(api.modifies.single.addLabelIds, ['Label_10']);
      expect(api.modifies.single.removeLabelIds,
          unorderedEquals(['INBOX', 'UNREAD']));

      // checkMessagesPresent: no answer for the folder's rows, as before.
      final present =
          await adapter.checkMessagesPresent(folderName: 'Gone', ids: ['a']);
      expect(present, isEmpty);
      expect(api.messageGets, 0);

      final log = await diagWith('label "GoneSource" not found');
      expect(log, contains('label "Gone" not found'));
    });
  });

  group('T-2: the history cursor is per account AND folder (R-3)', () {
    late DatabaseTestHelper testHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
    });
    tearDown(() async => testHelper.tearDown());

    test('INBOX saving does not advance SPAM or a label', () async {
      final db = testHelper.dbHelper;
      await db.setGmailHistoryCursor('acct', 'INBOX', '100');
      expect(await db.getGmailHistoryCursor('acct', 'INBOX'), '100');
      expect(await db.getGmailHistoryCursor('acct', 'SPAM'), isNull);
      expect(await db.getGmailHistoryCursor('acct', 'Unwanted'), isNull);

      await db.setGmailHistoryCursor('acct', 'SPAM', '250');
      await db.setGmailHistoryCursor('acct', 'INBOX', '400');
      expect(await db.getGmailHistoryCursor('acct', 'INBOX'), '400');
      expect(await db.getGmailHistoryCursor('acct', 'SPAM'), '250');
    });

    test('clearing one folder leaves the others; accounts are independent; '
        'the folder key ignores case', () async {
      final db = testHelper.dbHelper;
      await db.setGmailHistoryCursor('a', 'INBOX', '1');
      await db.setGmailHistoryCursor('a', 'SPAM', '2');
      await db.setGmailHistoryCursor('b', 'INBOX', '3');

      await db.setGmailHistoryCursor('a', 'inbox', null);
      expect(await db.getGmailHistoryCursor('a', 'INBOX'), isNull);
      expect(await db.getGmailHistoryCursor('a', 'SPAM'), '2');
      expect(await db.getGmailHistoryCursor('b', 'Inbox'), '3');
    });

    test('the history cursor is a separate row from the IMAP backlog cursor',
        () async {
      final db = testHelper.dbHelper;
      await db.setFolderCursor('acct', 'INBOX', '77'); // oldest-no-rule type
      await db.setGmailHistoryCursor('acct', 'INBOX', '100');
      expect(await db.getFolderCursor('acct', 'INBOX'), '77');
      expect(await db.getGmailHistoryCursor('acct', 'INBOX'), '100');
      await db.setGmailHistoryCursor('acct', 'INBOX', null);
      expect(await db.getFolderCursor('acct', 'INBOX'), '77');
    });
  });

  group('scanner: the real EmailScanner with a Gmail platform', () {
    late DatabaseTestHelper testHelper;
    late RuleSetProvider ruleProvider;
    const account = 'gmail-test@test.com';

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      // The database set-up clears the logger's cache; set the seam again.
      DiagnosticLogger.debugSetEnabled(true);
      DiagnosticLogger.debugSetDir(diagDir.path);
      ruleProvider = RuleSetProvider();
      ruleProvider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();
    });
    tearDown(() async => testHelper.tearDown());

    Future<EmailScanProvider> scan(_FakeGmail api, List<String> folders) async {
      final adapter = _TestGmailAdapter()..debugSetGmailApi(api);
      final previous =
          PlatformRegistry.overrideFactoryForTest('test', () => adapter);
      addTearDown(
          () => PlatformRegistry.overrideFactoryForTest('test', previous));
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      await EmailScanner(
        platformId: 'test',
        accountId: account,
        ruleSetProvider: ruleProvider,
        scanProvider: provider,
        credStore: _FakeCredStore(),
      )
          .scanInbox(daysBack: 7, folderNames: folders)
          .catchError((Object _) {});
      return provider;
    }

    test('a folder with no cursor of its own gets a FULL fetch even though '
        'INBOX has a cursor; each folder saves only its own', () async {
      final api = _FakeGmail();
      final db = testHelper.dbHelper;
      await db.setGmailHistoryCursor(account, 'INBOX', '100');

      await scan(api, ['INBOX', 'SPAM']);

      expect(api.historyStartIds, ['100'],
          reason: 'INBOX read changes since its own cursor');
      expect(api.messageQueries.single, contains('in:spam'),
          reason: 'SPAM had no cursor, so it was fetched in full');
      expect(await db.getGmailHistoryCursor(account, 'INBOX'), '300',
          reason: 'INBOX took the history answer');
      expect(await db.getGmailHistoryCursor(account, 'SPAM'), '500',
          reason: 'SPAM took the profile historyId after its full fetch');
    });

    test('a folder that is not on the account is skipped, not an error; its '
        'cursor stays absent and the skip reaches the diagnostic log',
        () async {
      final api = _FakeGmail();
      final db = testHelper.dbHelper;
      await db.setGmailHistoryCursor(account, 'INBOX', '100');
      await db.setGmailHistoryCursor(account, 'Gone', '90');

      final provider = await scan(api, ['INBOX', 'Gone']);

      expect(provider.status, ScanStatus.completed,
          reason: 'a missing folder is not a failed scan (F202)');
      expect(api.historyStartIds, ['100'],
          reason: 'history.list ran for INBOX only');
      expect(await db.getGmailHistoryCursor(account, 'INBOX'), '300');
      expect(await db.getGmailHistoryCursor(account, 'Gone'), '90',
          reason: 'a skipped folder does not move its cursor');
      expect(await diagWith('F202/missing-folder'),
          contains('folder "Gone" is not on this account'));
    });
  });
}
