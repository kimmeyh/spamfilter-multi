/// Sprint 77 final review: a refused IMAP LOGIN, at the first connection and
/// at a mid-scan reconnect.
///
/// Two findings:
/// 1. A sign-in refused at a RECONNECT (a password changed during a scan) was
///    absorbed by the per-chunk catch of the bulk move and by
///    searchByMessageId, and the adapter kept a connected but signed-out
///    client, so every later chunk sent LOGIN again.
/// 2. EVERY refused LOGIN was a sign-in failure, including a server that was
///    busy or unavailable with a correct password ([UNAVAILABLE], [LIMIT],
///    [INUSE], [SERVERBUG], BAD), which moved the account toward the SEC-22
///    lockout.
///
/// Real sockets: the in-process [FakeImapServer] answers LOGIN as configured.
///
/// What these tests do NOT catch: a refusal that is not an `ImapException`
/// (the socket dropped mid-LOGIN still goes through the Socket/Timeout
/// mapping); the four Step 6b batch catches inside `scanInbox` (same
/// predicate, no unit seam); and the background core's end-to-end mapping of
/// the rethrown exception.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/security/auth_rate_limiter.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/fake_imap_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyLoginRefusal (the table)', () {
    const credentials = LoginRefusal.credentials;
    const unavailable = LoginRefusal.serverUnavailable;
    // enough_mail strips "NO " from a NO reply; a BAD reply keeps "BAD".
    const table = <String?, LoginRefusal>{
      '[AUTHENTICATIONFAILED] Invalid credentials': credentials,
      '[AUTHORIZATIONFAILED] not allowed': credentials,
      '[EXPIRED] password expired': credentials,
      'LOGIN failed': credentials, // NO with no response code
      'NO': credentials, // a bare NO reply (no text after it)
      '[ALERT] Application-specific password required': credentials,
      '[UNAVAILABLE] try again later': unavailable,
      '[LIMIT] too many logins': unavailable,
      '[INUSE] mailbox in use': unavailable,
      '[SERVERBUG] internal error': unavailable,
      'Too many connections from your IP': unavailable,
      '[ALERT] Too many simultaneous connections. (Failure)': unavailable,
      'BAD [CLIENTBUG] invalid command': unavailable,
      'BAD Command syntax error': unavailable,
      'timeout': unavailable,
      '': unavailable,
      null: unavailable,
    };
    for (final row in table.entries) {
      test('"${row.key}" -> ${row.value.name}', () {
        expect(GenericIMAPAdapter.classifyLoginRefusal(row.key), row.value);
      });
    }
  });

  const fixtureDir = 'test/fixtures/tls';
  late SecurityContext serverContext;
  late DatabaseTestHelper db;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
    serverContext = SecurityContext()
      ..useCertificateChain('$fixtureDir/cert.pem')
      ..usePrivateKey('$fixtureDir/key.pem');
    SecurityContext.defaultContext
        .setTrustedCertificates('$fixtureDir/cert.pem');
  });

  setUp(() async {
    db = DatabaseTestHelper();
    await db.setUp();
  });

  tearDown(() async {
    await db.tearDown();
  });

  Credentials creds(int port) => Credentials(
        email: 'person@example.test',
        password: 'pw',
        additionalParams: CustomImapSettings(
          host: 'localhost',
          port: port,
          encryption: ImapEncryption.sslTls,
          username: 'login-name',
        ).toParams(),
      );

  List<EmailMessage> inboxMessages(int count) => [
        for (var uid = 1; uid <= count; uid++)
          EmailMessage(
            id: '$uid',
            from: 'a@b.test',
            subject: 's',
            body: '',
            headers: const {},
            receivedDate: DateTime(2026, 10, 8),
            folderName: 'INBOX',
          ),
      ];

  Future<int> limiterAttempts() async =>
      (await AuthRateLimiter(DatabaseHelper())
              .checkBlock('imap-person@example.test'))
          .attempts;

  group('a sign-in refused at a mid-scan reconnect', () {
    test('during a chunked move: the refusal propagates, no client survives, '
        'and no further LOGIN is sent', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();
      addTearDown(adapter.disconnect);
      await adapter.loadCredentials(creds(server.port));
      expect(server.loginCount, 1);

      // The password changes on the server mid-scan.
      server.rejectLogin = true;
      // 51 UIDs = two chunks of at most 50. Two operations remain before the
      // reconnect: chunk 1's MOVE and its verification SEARCH. So the
      // reconnect runs at the top of chunk 2, INSIDE the per-chunk catch.
      adapter.debugReconnectAfter(2);

      await expectLater(
        adapter.moveToFolderBatch(inboxMessages(51), 'Trash'),
        throwsA(isA<AuthenticationException>()),
      );
      expect(adapter.debugHasClient, isFalse,
          reason: 'a signed-out client must not survive a refused LOGIN');
      expect(server.loginCount, 2);
      expect(await limiterAttempts(), 1,
          reason: 'a refused reconnect counts toward the SEC-22 lockout');

      // A later operation in the same scan must not send LOGIN again.
      final again = await adapter.moveToFolderBatch(inboxMessages(1), 'Trash');
      expect(again.failureCount, 1);
      expect(server.loginCount, 2,
          reason: 'one refused LOGIN per scan, never one per chunk');
    });

    test('during searchByMessageId: the refusal propagates instead of '
        '"no match"', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();
      addTearDown(adapter.disconnect);
      await adapter.loadCredentials(creds(server.port));

      server.rejectLogin = true;
      adapter.debugReconnectAfter(0);

      await expectLater(
        adapter.searchByMessageId('INBOX', '<a@b.test>'),
        throwsA(isA<AuthenticationException>()),
      );
      expect(adapter.debugHasClient, isFalse);
      expect(server.loginCount, 2);
      expect(await limiterAttempts(), 1);
    });
  });

  group('a refused LOGIN at the first connection', () {
    test('busy server ([UNAVAILABLE]) with a correct password: a connection '
        'failure with its own sentence, NOT counted by the limiter', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      server.loginReply = 'NO [UNAVAILABLE] try again later';
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();

      Object? thrown;
      try {
        await adapter.loadCredentials(creds(server.port));
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<UserFacingConnectionException>());
      expect(ErrorMessages.humanize(thrown!),
          GenericIMAPAdapter.loginServerUnavailableMessage);
      expect(await limiterAttempts(), 0);
      expect(adapter.debugHasClient, isFalse);
    });

    test('wrong password on a fixed-host provider: sign-in failure, counted, '
        'and no client survives', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      server.rejectLogin = true;
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter(
        imapHost: 'localhost',
        imapPort: server.port,
        platformId: 'aol',
      );

      await expectLater(
        adapter.loadCredentials(
            Credentials(email: 'person@example.test', password: 'pw')),
        throwsA(isA<AuthenticationException>()),
      );
      expect(adapter.debugHasClient, isFalse);
      expect(
          (await AuthRateLimiter(DatabaseHelper())
                  .checkBlock('aol-person@example.test'))
              .attempts,
          1);
    });
  });
}
