/// Delete-to-trash behavior (Sprint 11 Critical Fix) -- UN-SKIPPED F163 R-2
/// (Sprint 62). These guard the product's delete-RECOVERABILITY promise:
/// a spam-filter mistake must be recoverable, so delete means "move to
/// Trash", never a permanent delete/EXPUNGE.
///
/// The trio had been skipped since Sprint 11 as "requires adapter
/// refactoring for DI" -- the old file even contained mock classes that were
/// never wired to anything (a test of a mock of nothing). The DI seams now
/// exist: `GenericIMAPAdapter.debugSetImapClient` (F177) and
/// `GmailApiAdapter.debugSetGmailApi` (added for this remediation) -- so the
/// REAL adapters' takeAction paths run against scripted clients.
///
/// Mutation-verified at authoring: switching the IMAP delete branch to
/// `uidExpunge` semantics (recording client) turns the trash test red.
library;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

/// Fake ImapClient recording move/expunge calls issued by the REAL adapter.
class _RecordingImapClient extends ImapClient {
  _RecordingImapClient() : super(isLogEnabled: false);

  final List<String> moveTargets = [];
  bool expungeCalled = false;

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async =>
      Mailbox(
        encodedName: path,
        encodedPath: path,
        pathSeparator: '/',
        flags: [],
      );

  @override
  Future<GenericImapResult> uidMove(
    MessageSequence sequence, {
    Mailbox? targetMailbox,
    String? targetMailboxPath,
  }) async {
    moveTargets.add(targetMailboxPath ?? targetMailbox?.path ?? '?');
    return GenericImapResult();
  }

  @override
  Future<Mailbox?> uidExpunge(MessageSequence sequence) async {
    expungeCalled = true;
    return null;
  }

  @override
  Future<Mailbox> expunge() async {
    expungeCalled = true;
    return Mailbox(
        encodedName: 'INBOX',
        encodedPath: 'INBOX',
        pathSeparator: '/',
        flags: []);
  }
}

/// Fake HTTP client recording every Gmail API request the REAL GmailApi
/// issues -- the standard googleapis testing pattern: assert WHICH endpoint
/// was hit (POST .../trash is recoverable; DELETE .../messages/{id} is not).
class _RecordingHttpClient extends http.BaseClient {
  final List<String> requests = []; // "METHOD path"

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add('${request.method} ${request.url.path}');
    return http.StreamedResponse(
      Stream.value('{}'.codeUnits),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

EmailMessage _email(String id) => EmailMessage(
      id: id,
      from: 'spammer@test.com',
      subject: 'Test',
      body: 'Test',
      headers: const {},
      receivedDate: DateTime.now(),
      folderName: 'INBOX',
    );

void main() {
  group('Delete-to-Trash Behavior (Sprint 11 Critical Fix)', () {
    test('IMAP delete moves to Trash via UID MOVE -- never expunges',
        () async {
      final client = _RecordingImapClient();
      final adapter =
          GenericIMAPAdapter(imapHost: 'imap.example.com', platformId: 'aol')
            ..debugSetImapClient(client);

      await adapter.takeAction(
          message: _email('123'), action: FilterAction.delete);

      expect(client.moveTargets, ['Trash'],
          reason: 'CRITICAL: delete must be a recoverable move to Trash');
      expect(client.expungeCalled, isFalse,
          reason: 'CRITICAL: expunge is irreversible and must never be '
              'part of the delete path');
    });

    test('IMAP delete honors a configured deleted-rule folder', () async {
      final client = _RecordingImapClient();
      final adapter =
          GenericIMAPAdapter(imapHost: 'imap.example.com', platformId: 'aol')
            ..debugSetImapClient(client)
            ..setDeletedRuleFolder('MySpamArchive');

      await adapter.takeAction(
          message: _email('124'), action: FilterAction.delete);

      expect(client.moveTargets, ['MySpamArchive']);
      expect(client.expungeCalled, isFalse);
    });

    test('IMAP moveToJunk uses UID MOVE to Junk (not copy+delete)', () async {
      final client = _RecordingImapClient();
      final adapter =
          GenericIMAPAdapter(imapHost: 'imap.example.com', platformId: 'aol')
            ..debugSetImapClient(client);

      await adapter.takeAction(
          message: _email('456'), action: FilterAction.moveToJunk);

      expect(client.moveTargets, ['Junk']);
      expect(client.expungeCalled, isFalse);
    });

    test('Gmail delete calls the trash endpoint -- never the permanent '
        'delete endpoint', () async {
      final httpClient = _RecordingHttpClient();
      final adapter = GmailApiAdapter()
        ..debugSetGmailApi(gmail.GmailApi(httpClient));

      await adapter.takeAction(
          message: _email('gmail-message-id-123'),
          action: FilterAction.delete);

      expect(httpClient.requests, hasLength(1));
      expect(httpClient.requests.single,
          'POST /gmail/v1/users/me/messages/gmail-message-id-123/trash',
          reason: 'Gmail delete must use the recoverable trash API');
      expect(
          httpClient.requests
              .where((r) => r.startsWith('DELETE ')),
          isEmpty,
          reason: 'CRITICAL: the permanent-delete endpoint must never be '
              'called');
    });
  });
}
