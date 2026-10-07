/// SEC-8b (Sprint 77, ADR-0046): Custom IMAP certificate trust against REAL
/// sockets and REAL TLS handshakes (loopback fake server, fixture certs).
///
/// Device trust in THIS test process: `cert.pem` is added to dart:io's default
/// SecurityContext (it stands in for a CA-issued certificate the device
/// trusts). `cert2.pem` and `cert3.pem` are NOT trusted (they stand in for a
/// self-signed / private-CA server certificate).
///
/// Claims proven, for SSL/TLS and STARTTLS:
/// - an untrusted certificate with no stored fingerprint stops BEFORE any IMAP
///   command: no LOGIN, no password, and a named "not trusted" error that
///   carries the certificate the dialog shows;
/// - the stored fingerprint of exactly that certificate lets it connect;
/// - a DIFFERENT untrusted certificate is "changed", never accepted;
/// - a device-trusted certificate connects and its fingerprint is recorded;
/// - a reconnect that meets a changed certificate keeps the named reason;
/// - the text a failed scan records (`ErrorMessages.humanize`, which the
///   `email_scanner.dart` failure path uses for manual AND background scans)
///   is the named reason;
/// - the Save probe reads the certificate without sending LOGIN.
///
/// Platforms (ADR-0042): runs on the Windows host; Android runs the same Dart
/// over the same dart:io `SecureSocket` (BoringSSL in the Dart runtime).
///
/// What these tests do NOT catch: a real OS trust store's decisions (the
/// fixture trust is set in-process), a server that changes certificate in the
/// middle of a TLS session, and the WorkManager isolate's secure-storage write
/// of a refreshed fingerprint (device only).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

import '../helpers/database_test_helper.dart';
import '../helpers/fake_imap_server.dart';

String _fingerprintOf(String pemPath) {
  // The DER bytes between the PEM armor lines.
  final pem = File(pemPath).readAsStringSync();
  final body = pem
      .split('\n')
      .map((l) => l.trim())
      .where((l) => !l.startsWith('-----') && l.isNotEmpty)
      .join();
  return certificateSha256(base64Decode(body));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseTestHelper db;
  late String fp1; // device-trusted
  late String fp2; // untrusted
  late String fp3; // untrusted
  final recorded = <String, String>{};
  late Future<void> Function(String, String) originalRecorder;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
    SecurityContext.defaultContext
        .setTrustedCertificates('$tlsFixtureDir/cert.pem');
    fp1 = _fingerprintOf('$tlsFixtureDir/cert.pem');
    fp2 = _fingerprintOf('$tlsFixtureDir/cert2.pem');
    fp3 = _fingerprintOf('$tlsFixtureDir/cert3.pem');
    originalRecorder = GenericIMAPAdapter.recordTrustedCertificate;
  });

  setUp(() async {
    db = DatabaseTestHelper();
    await db.setUp();
    recorded.clear();
    GenericIMAPAdapter.recordTrustedCertificate =
        (accountId, sha) async => recorded[accountId] = sha;
  });

  tearDown(() async {
    GenericIMAPAdapter.recordTrustedCertificate = originalRecorder;
    await db.tearDown();
  });

  const password = 'tofu-secret-pw-42';

  Credentials creds(int port, ImapEncryption encryption,
          {String? trusted, String? accountId, String host = 'localhost'}) =>
      Credentials(
        email: 'me@example.test',
        password: password,
        additionalParams: {
          ...CustomImapSettings(
            host: host,
            port: port,
            encryption: encryption,
            username: 'me',
            trustedCertificateSha256: trusted,
          ).toParams(),
          if (accountId != null) 'accountId': accountId,
        },
      );

  Future<FakeImapServer> serverFor(ImapEncryption mode, int certNumber,
      {StartTlsBehavior behavior = StartTlsBehavior.accept}) async {
    final server = mode == ImapEncryption.sslTls
        ? await FakeImapServer.implicitTls(fixtureServerContext(certNumber))
        : await FakeImapServer.startTls(
            behavior, fixtureServerContext(certNumber));
    addTearDown(server.close);
    return server;
  }

  void expectNoCredentialSent(FakeImapServer server) {
    expect(server.everything, isNot(contains(password)));
    expect(server.everything, isNot(contains('LOGIN')));
    expect(server.tlsCommands, isEmpty,
        reason: 'no IMAP command may follow a rejected certificate');
  }

  for (final mode in ImapEncryption.values) {
    group('${mode.label}: ', () {
      test('untrusted certificate, nothing stored: blocked before any command, '
          'named "not trusted", certificate details for the dialog', () async {
        final server = await serverFor(mode, 2);
        final adapter = GenericIMAPAdapter.custom();

        Object? error;
        try {
          await adapter.loadCredentials(creds(server.port, mode));
        } catch (e) {
          error = e;
        }

        expect(error, isA<ServerCertificateNotTrustedException>());
        final e = error! as ServerCertificateNotTrustedException;
        expect(e.problem, CertificateTrustProblem.notTrusted);
        expect(e.certificate.sha256Hex, fp2);
        expect(e.certificate.subject, contains('Second Test Certificate'));
        expect(e.certificate.isSelfSigned, isTrue);
        expect(e.certificate.validTo.isAfter(DateTime.now()), isTrue);
        expect(ErrorMessages.humanize(e),
            ServerCertificateNotTrustedException.notTrustedMessage);
        expectNoCredentialSent(server);
      });

      test('the stored fingerprint of exactly that certificate connects and '
          'logs in over TLS', () async {
        final server = await serverFor(mode, 2);
        final adapter = GenericIMAPAdapter.custom();
        addTearDown(adapter.disconnect);

        await adapter.loadCredentials(
            creds(server.port, mode, trusted: fp2, accountId: 'me@example.test'));

        expect(server.tlsCommands.any((c) => c.contains('LOGIN "me"')), isTrue);
        expect(server.plaintextCommands.any((c) => c.contains('LOGIN')), isFalse);
        expect(recorded, isEmpty,
            reason: 'a user-accepted certificate is already the stored one');
      });

      test('a DIFFERENT untrusted certificate is "changed" and never accepted',
          () async {
        final server = await serverFor(mode, 3);
        final adapter = GenericIMAPAdapter.custom();

        Object? error;
        try {
          await adapter.loadCredentials(creds(server.port, mode, trusted: fp2));
        } catch (e) {
          error = e;
        }

        expect(error, isA<ServerCertificateNotTrustedException>());
        final e = error! as ServerCertificateNotTrustedException;
        expect(e.problem, CertificateTrustProblem.changed);
        expect(e.certificate.sha256Hex, fp3);
        expect(e.userMessage,
            startsWith('Server certificate changed -- open the app and '
                'confirm the server.'));
        expectNoCredentialSent(server);
      });

      test('a device-trusted certificate connects even with an old stored '
          'fingerprint, and the new fingerprint is recorded', () async {
        final server = await serverFor(mode, 1);
        final adapter = GenericIMAPAdapter.custom();
        addTearDown(adapter.disconnect);

        await adapter.loadCredentials(
            creds(server.port, mode, trusted: fp2, accountId: 'me@example.test'));

        expect(server.tlsCommands.any((c) => c.contains('LOGIN')), isTrue);
        expect(recorded, {'me@example.test': fp1});
      });
    });
  }

  test('STARTTLS: capabilities are fetched again over TLS, before LOGIN',
      () async {
    final server = await serverFor(ImapEncryption.startTls, 2);
    final adapter = GenericIMAPAdapter.custom();
    addTearDown(adapter.disconnect);

    await adapter.loadCredentials(
        creds(server.port, ImapEncryption.startTls, trusted: fp2));

    final capability =
        server.tlsCommands.indexWhere((c) => c.contains('CAPABILITY'));
    final login = server.tlsCommands.indexWhere((c) => c.contains('LOGIN'));
    expect(capability, greaterThanOrEqualTo(0));
    expect(login, greaterThan(capability));
  });

  test('STARTTLS: plaintext injected after the OK is refused, password never '
      'sent', () async {
    final server = await serverFor(ImapEncryption.startTls, 2,
        behavior: StartTlsBehavior.okWithInjection);
    final adapter = GenericIMAPAdapter.custom();

    Object? error;
    try {
      await adapter.loadCredentials(
          creds(server.port, ImapEncryption.startTls, trusted: fp2));
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
    expect(ErrorMessages.humanize(error!), contains('did not send your password'));
    expectNoCredentialSent(server);
  });

  test('a host name not on the certificate is a certificate the user must '
      'confirm, never a silent accept', () async {
    // cert.pem is device-trusted for "localhost"; reached as 127.0.0.1 the
    // name does not match, so the device rejects it and the trust rule runs.
    final server = await serverFor(ImapEncryption.sslTls, 1);
    final adapter = GenericIMAPAdapter.custom();

    await expectLater(
      adapter.loadCredentials(
          creds(server.port, ImapEncryption.sslTls, host: '127.0.0.1')),
      throwsA(isA<ServerCertificateNotTrustedException>()),
    );
    expectNoCredentialSent(server);
  });

  test('a reconnect that meets a changed certificate keeps the named reason',
      () async {
    final server = await serverFor(ImapEncryption.startTls, 2);
    final adapter = GenericIMAPAdapter.custom();
    addTearDown(adapter.disconnect);
    await adapter.loadCredentials(
        creds(server.port, ImapEncryption.startTls, trusted: fp2));

    server.context = fixtureServerContext(3); // the server's cert changes
    Object? error;
    try {
      await adapter.debugReconnectNow();
    } catch (e) {
      error = e;
    }

    expect(error, isA<ServerCertificateNotTrustedException>());
    expect(ErrorMessages.humanize(error!),
        ServerCertificateNotTrustedException.changedMessage);
    expect(server.tlsCommands.where((c) => c.contains('LOGIN')).length, 1,
        reason: 'the password went only to the trusted certificate');
  });

  test('probeServerCertificate (Save) reads the certificate and sends no LOGIN',
      () async {
    final trustedServer = await serverFor(ImapEncryption.sslTls, 1);
    final info = await GenericIMAPAdapter.custom()
        .probeServerCertificate(creds(trustedServer.port, ImapEncryption.sslTls));
    expect(info.sha256Hex, fp1);
    expect(trustedServer.everything, isNot(contains('LOGIN')));

    final untrustedServer = await serverFor(ImapEncryption.startTls, 2);
    await expectLater(
      GenericIMAPAdapter.custom().probeServerCertificate(
          creds(untrustedServer.port, ImapEncryption.startTls)),
      throwsA(isA<ServerCertificateNotTrustedException>()),
    );
    expectNoCredentialSent(untrustedServer);
  });

  test('a malformed stored fingerprint is NO trust, not a skipped check',
      () async {
    final server = await serverFor(ImapEncryption.sslTls, 2);
    final params = {
      ...creds(server.port, ImapEncryption.sslTls).additionalParams!,
      CustomImapSettings.keyTrustedCertSha256: fp2.toUpperCase(),
    };
    await expectLater(
      GenericIMAPAdapter.custom().loadCredentials(Credentials(
          email: 'me@example.test', password: password, additionalParams: params)),
      throwsA(isA<ServerCertificateNotTrustedException>().having(
          (e) => e.problem, 'problem', CertificateTrustProblem.notTrusted)),
    );
    expectNoCredentialSent(server);
  });

  test('ServerCertificateInfo.displayFingerprint is 32 colon pairs', () {
    final info = ServerCertificateInfo(
      sha256Hex: fp2,
      subject: '/CN=x',
      issuer: '/CN=x',
      validFrom: DateTime(2026),
      validTo: DateTime(2126),
    );
    expect(info.displayFingerprint.split(':'), hasLength(32));
    expect(info.displayFingerprint.replaceAll(':', '').toLowerCase(), fp2);
  });
}
