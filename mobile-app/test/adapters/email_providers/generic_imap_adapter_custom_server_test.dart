/// F192 (Sprint 77): the Custom IMAP adapter against REAL sockets.
///
/// A fake IMAP server runs inside the test process (loopback only) and records
/// every byte the adapter sends. That makes the security claims checkable at
/// the level they are made:
///
/// - STARTTLS never sends the password unless the TLS upgrade succeeded
///   (server refuses, server breaks the handshake, wrong host name).
/// - STARTTLS verifies the certificate against the host name the user typed.
/// - A missing, blank or unrecognized setting opens NO socket and never
///   becomes a plaintext login.
/// - A reconnect uses the same server, encryption and username.
/// - Only the Custom IMAP platform reads the server settings.
///
/// OS behavior assumed identical on Windows and Android (ADR-0042): dart:io
/// `Socket` and `SecureSocket` with the OS trust store. This test runs on the
/// Windows host; the Android path is the same Dart code over the same dart:io
/// API. The certificate is trusted here through dart:io's default
/// SecurityContext, which is what both platforms consult.
///
/// What these tests do NOT catch: a real provider's certificate chain, a
/// server that advertises STARTTLS but behaves unusually after it, and the
/// WorkManager isolate's secure-storage access (only a device proves that).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/fake_imap_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fixtureDir = 'test/fixtures/tls';
  late SecurityContext serverContext;
  late DatabaseTestHelper db;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
    serverContext = SecurityContext()
      ..useCertificateChain('$fixtureDir/cert.pem')
      ..usePrivateKey('$fixtureDir/key.pem');
    // The fixture certificate is self-signed. Trust it for THIS test process
    // only, so the handshake is a real, validating one (hostname included).
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

  const password = 's3cr3t-pw-xyz';

  Credentials credsFor(
    String host,
    int port,
    ImapEncryption encryption, {
    String username = 'login-name',
    String email = 'person@example.test',
  }) =>
      Credentials(
        email: email,
        password: password,
        additionalParams: CustomImapSettings(
          host: host,
          port: port,
          encryption: encryption,
          username: username,
        ).toParams(),
      );

  group('SSL/TLS (implicit)', () {
    test('connects, verifies the certificate against the typed host name, and '
        'logs in with the username', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();
      addTearDown(adapter.disconnect);

      await adapter.loadCredentials(
          credsFor('localhost', server.port, ImapEncryption.sslTls));

      expect(server.tlsCommands.any((c) => c.contains('LOGIN "login-name"')),
          isTrue,
          reason: 'login name must be the Username field, not the email');
      expect(server.plaintextCommands, isEmpty);
    });

    test('a host name that is not on the certificate is refused and the '
        'password is never sent', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();

      await expectLater(
        adapter.loadCredentials(
            credsFor('127.0.0.1', server.port, ImapEncryption.sslTls)),
        throwsA(isA<UserFacingConnectionException>()),
      );
      expect(server.everything, isNot(contains(password)));
      expect(server.everything, isNot(contains('LOGIN')));
    });
  });

  group('STARTTLS downgrade protection (Sprint 77 Q3)', () {
    test('server refuses STARTTLS: password never sent, clear message',
        () async {
      final server = await FakeImapServer.startTls(
          StartTlsBehavior.refuse, serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();

      Object? error;
      try {
        await adapter.loadCredentials(
            credsFor('localhost', server.port, ImapEncryption.startTls));
      } catch (e) {
        error = e;
      }

      expect(error, isA<UserFacingConnectionException>());
      expect(ErrorMessages.humanize(error!), contains('STARTTLS'));
      expect(ErrorMessages.humanize(error), contains('did not send your password'));
      expect(server.plaintextCommands.any((c) => c.contains('STARTTLS')),
          isTrue,
          reason: 'the adapter must actually ASK for the upgrade');
      expect(server.everything, isNot(contains('LOGIN')),
          reason: 'a cleartext LOGIN after a refused upgrade is the downgrade');
      expect(server.everything, isNot(contains(password)));
    });

    test('server says OK but the TLS handshake cannot complete: password '
        'never sent', () async {
      final server = await FakeImapServer.startTls(
          StartTlsBehavior.okThenClose, serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();

      await expectLater(
        adapter.loadCredentials(
            credsFor('localhost', server.port, ImapEncryption.startTls)),
        throwsA(isA<ConnectionException>()),
      );
      expect(server.everything, isNot(contains('LOGIN')));
      expect(server.everything, isNot(contains(password)));
    });

    test('STARTTLS verifies the certificate against the typed host name: '
        '127.0.0.1 is refused, localhost is accepted', () async {
      final server = await FakeImapServer.startTls(
          StartTlsBehavior.accept, serverContext);
      addTearDown(server.close);

      final wrongName = GenericIMAPAdapter.custom();
      await expectLater(
        wrongName.loadCredentials(
            credsFor('127.0.0.1', server.port, ImapEncryption.startTls)),
        throwsA(isA<ConnectionException>()),
      );
      expect(server.everything, isNot(contains('LOGIN')),
          reason: 'name mismatch must stop before the password');
      expect(server.tlsCommands, isEmpty);

      final rightName = GenericIMAPAdapter.custom();
      addTearDown(rightName.disconnect);
      await rightName.loadCredentials(
          credsFor('localhost', server.port, ImapEncryption.startTls));
      expect(server.tlsCommands.any((c) => c.contains('LOGIN "login-name"')),
          isTrue);
      expect(server.plaintextCommands.any((c) => c.contains('LOGIN')), isFalse,
          reason: 'the password travels only inside the TLS session');
    });
  });

  group('settings that are missing or invalid open no socket', () {
    Future<void> expectNoSocket(
        FakeImapServer server, Credentials credentials) async {
      final adapter = GenericIMAPAdapter.custom();
      Object? error;
      try {
        await adapter.loadCredentials(credentials);
      } catch (e) {
        error = e;
      }
      expect(error, isA<UserFacingConnectionException>());
      expect(ErrorMessages.humanize(error!), contains('no valid server settings'));
      expect(server.connections, 0);
      expect(server.everything, isEmpty);
    }

    test('no additionalParams at all', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      await expectNoSocket(
          server, Credentials(email: 'a@b.test', password: password));
    });

    test('blank host', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      await expectNoSocket(server, credsFor('  ', server.port, ImapEncryption.sslTls));
    });

    test('an encryption value that is not a known mode (never plaintext)',
        () async {
      final server = await FakeImapServer.startTls(
          StartTlsBehavior.accept, serverContext);
      addTearDown(server.close);
      for (final bad in ['none', 'plaintext', 'false', '', 'SSLTLS']) {
        final params = <String, String>{
          ...credsFor('localhost', server.port, ImapEncryption.sslTls)
              .additionalParams!,
          CustomImapSettings.keyEncryption: bad,
        };
        await expectNoSocket(
            server,
            Credentials(
                email: 'a@b.test', password: password, additionalParams: params));
      }
    });

    test('an out-of-range or non-numeric port', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      for (final bad in ['0', '70000', 'abc', '']) {
        final params = <String, String>{
          ...credsFor('localhost', server.port, ImapEncryption.sslTls)
              .additionalParams!,
          CustomImapSettings.keyPort: bad,
        };
        await expectNoSocket(
            server,
            Credentials(
                email: 'a@b.test', password: password, additionalParams: params));
      }
    });
  });

  group('one connect path', () {
    test('a reconnect uses the same server, STARTTLS and username', () async {
      final server = await FakeImapServer.startTls(
          StartTlsBehavior.accept, serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();
      addTearDown(adapter.disconnect);

      await adapter.loadCredentials(
          credsFor('localhost', server.port, ImapEncryption.startTls));
      await adapter.debugReconnectNow();

      expect(server.connections, 2);
      expect(server.plaintextCommands.where((c) => c.contains('STARTTLS')).length,
          2,
          reason: 'the reconnect must upgrade too, not log in in cleartext');
      expect(server.tlsCommands.where((c) => c.contains('LOGIN "login-name"')).length,
          2);
      expect(server.plaintextCommands.any((c) => c.contains('LOGIN')), isFalse);
    });

    test('only the Custom IMAP platform reads the server settings', () async {
      final real = await FakeImapServer.implicitTls(serverContext);
      final decoy = await FakeImapServer.implicitTls(serverContext);
      addTearDown(real.close);
      addTearDown(decoy.close);
      // A provider with a FIXED host (AOL, Yahoo, ...) must ignore stray
      // custom keys, so a stored value can never redirect it.
      final adapter = GenericIMAPAdapter(
        imapHost: 'localhost',
        imapPort: real.port,
        platformId: 'aol',
      );
      addTearDown(adapter.disconnect);

      await adapter.loadCredentials(
          credsFor('localhost', decoy.port, ImapEncryption.sslTls));

      expect(decoy.connections, 0);
      expect(real.connections, 1);
      expect(real.tlsCommands.any((c) => c.contains('LOGIN "person@example.test"')),
          isTrue,
          reason: 'fixed-host providers log in with the email address');
    });

    // F-PRECHECK (Sprint 77 Phase 5.1.2): the enough_mail STARTTLS branch for
    // fixed-host providers was unreachable and was removed; that path now
    // always connects with TLS. This guard is what keeps it unreachable: a
    // fixed-host provider can never be built with STARTTLS (which on that
    // path would now mean a cleartext LOGIN).
    // What this does NOT catch: a new code path that changes `_encryption`
    // after construction for a non-imap platform (today only
    // _resolveCustomServer writes it, for 'imap' only).
    test('a fixed-host provider cannot be built with STARTTLS', () {
      expect(
          () => GenericIMAPAdapter(
              imapHost: 'imap.example.com',
              platformId: 'aol',
              encryption: ImapEncryption.startTls),
          throwsArgumentError);
      expect(
          GenericIMAPAdapter(
                  imapHost: 'x', encryption: ImapEncryption.startTls)
              .platformId,
          'imap',
          reason: 'Custom IMAP keeps STARTTLS (through ImapTlsConnector)');
    });

    test('a blank username falls back to the email address', () async {
      final server = await FakeImapServer.implicitTls(serverContext);
      addTearDown(server.close);
      final adapter = GenericIMAPAdapter.custom();
      addTearDown(adapter.disconnect);

      await adapter.loadCredentials(credsFor(
          'localhost', server.port, ImapEncryption.sslTls,
          username: ''));

      expect(server.tlsCommands.any((c) => c.contains('LOGIN "person@example.test"')),
          isTrue);
    });
  });
}
