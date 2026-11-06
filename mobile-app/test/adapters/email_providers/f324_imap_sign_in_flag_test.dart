/// F324 R-4 (Sprint 83): an IMAP login the provider REFUSES flags the account
/// "needs sign-in" -- the same flag the Gmail adapter sets, which the account
/// list reads to offer "Sign In Again". A network error or a busy server does
/// not; a later successful sign-in clears it.
///
/// Real sockets: the in-process [FakeImapServer] answers LOGIN as configured
/// (the same harness as generic_imap_adapter_login_refusal_test).
///
/// What these do NOT catch: a real provider's wording (the classification table
/// is in generic_imap_adapter_login_refusal_test), the account-list row (see
/// test/ui/screens/f324_background_off_test), and an unsaved account (the setup
/// form's Test Connection carries no `accountId`, so nothing is flagged; that
/// branch is asserted below only by "no throw").
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/fake_imap_server.dart';

const _acct = 'person@example.test';

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
    SecurityContext.defaultContext
        .setTrustedCertificates('$fixtureDir/cert.pem');
  });

  setUp(() async {
    db = DatabaseTestHelper();
    await db.setUp();
    DatabaseHelper().setAppPaths(db.appPaths);
    await db.createTestAccount(_acct, platformId: 'imap');
  });

  tearDown(() async {
    await db.tearDown();
  });

  Credentials creds(int port, {bool saved = true}) => Credentials(
        email: _acct,
        password: 'pw',
        additionalParams: {
          ...CustomImapSettings(
            host: 'localhost',
            port: port,
            encryption: ImapEncryption.sslTls,
            username: 'login-name',
          ).toParams(),
          if (saved) 'accountId': _acct,
        },
      );

  Future<bool> flagged() => SettingsStore().getGmailSignInRequired(_acct);

  test('a refused password flags the account', () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    server.rejectLogin = true;
    addTearDown(server.close);
    final adapter = GenericIMAPAdapter.custom();

    await expectLater(adapter.loadCredentials(creds(server.port)),
        throwsA(isA<AuthenticationException>()));
    expect(await flagged(), isTrue);
  });

  test('a busy server with a correct password does NOT flag the account',
      () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    server.loginReply = 'NO [UNAVAILABLE] try again later';
    addTearDown(server.close);
    final adapter = GenericIMAPAdapter.custom();

    await expectLater(adapter.loadCredentials(creds(server.port)),
        throwsA(isA<UserFacingConnectionException>()));
    expect(await flagged(), isFalse);
  });

  test('a network error (nothing listening) does NOT flag the account',
      () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    final port = server.port;
    await server.close();
    final adapter = GenericIMAPAdapter.custom();

    await expectLater(adapter.loadCredentials(creds(port)),
        throwsA(isA<ConnectionException>()));
    expect(await flagged(), isFalse);
  });

  test('a successful sign-in clears the flag', () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    addTearDown(server.close);
    await SettingsStore().setGmailSignInRequired(_acct, true);
    final adapter = GenericIMAPAdapter.custom();
    addTearDown(adapter.disconnect);

    await adapter.loadCredentials(creds(server.port));
    expect(await flagged(), isFalse);
  });

  test('a password refused at a mid-scan RECONNECT flags the account too',
      () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    addTearDown(server.close);
    final adapter = GenericIMAPAdapter.custom();
    addTearDown(adapter.disconnect);
    await adapter.loadCredentials(creds(server.port));
    expect(await flagged(), isFalse);

    server.rejectLogin = true;
    adapter.debugReconnectAfter(0);
    await expectLater(adapter.searchByMessageId('INBOX', '<a@b.test>'),
        throwsA(isA<AuthenticationException>()));
    expect(await flagged(), isTrue);
  });

  test('an unsaved account (setup form) is refused without writing a flag',
      () async {
    final server = await FakeImapServer.implicitTls(serverContext);
    server.rejectLogin = true;
    addTearDown(server.close);
    final adapter = GenericIMAPAdapter.custom();

    await expectLater(
        adapter.loadCredentials(creds(server.port, saved: false)),
        throwsA(isA<AuthenticationException>()));
    expect(await flagged(), isFalse);
  });
}
