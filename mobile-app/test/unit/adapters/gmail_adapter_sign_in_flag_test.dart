/// F239 (Sprint 75): when the Gmail adapter decides an account "needs you to
/// sign in again" -- and when it must NOT.
///
/// Before: (1) an OFFLINE background scan on Windows went getProfile ->
/// renewal (which swallows network errors into "Session expired") -> flagged a
/// healthy account and recorded "Gmail needs you to sign in again"; (2) the
/// Windows insufficient-scopes path skipped the flag and, in the foreground,
/// threw a plain AuthenticationException, so neither the account list nor the
/// scan screen offered Sign In Again. After: offline is a ConnectionException
/// with no flag; every needs-the-user path flags the account and throws
/// GmailSignInRequiredException.
///
/// The REAL adapter runs over a fake HTTP client
/// (`GmailApiAdapter.debugHttpClientFactory`), fake secure storage and a real
/// test database. The token path is the Windows one (`Platform.isWindows`),
/// so those cases run on Windows only; CI (ubuntu) runs the classifier.
///
/// What these do NOT catch: the Android path (it renews through the Google
/// sign-in plugin, which has no seam here -- Android offline is a recorded
/// known limit), and a network that drops between getProfile and renewal.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart' show Credentials;
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/services/background_mode_service.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

import '../../helpers/database_test_helper.dart';

const _gmail = 'someone@gmail.com';

Credentials _creds() => Credentials(
      email: _gmail,
      accessToken: 'stored-token',
      additionalParams: {'accountId': _gmail, 'isGmailOAuth': 'true'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late DatabaseTestHelper testHelper;
  // Fake secure storage. Empty by default: renewal finds nothing.
  final store = <String, String>{};

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = call.arguments['value'] as String;
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
      }
      return null;
    });
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
    await testHelper.createTestAccount(_gmail, platformId: 'gmail');
    BackgroundModeService.setModeForTesting(isBackground: true);
  });

  tearDown(() async {
    GmailApiAdapter.debugHttpClientFactory = null;
    BackgroundModeService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
    await testHelper.tearDown();
  });

  Future<bool> flagged() => SettingsStore().getGmailSignInRequired(_gmail);

  http.Response json(int status, String body) => http.Response(body, status,
      headers: {'content-type': 'application/json; charset=utf-8'});

  test('the scan text keeps what went wrong this time (wrong account)', () {
    expect(
        ErrorMessages.humanize(GmailSignInRequiredException(
            detail: 'You signed in as x@gmail.com. To fix $_gmail, sign in '
                'with $_gmail.')),
        'Gmail needs you to sign in again. You signed in as x@gmail.com. '
        'To fix $_gmail, sign in with $_gmail.');
    expect(ErrorMessages.humanize(GmailSignInRequiredException()),
        'Gmail needs you to sign in again.');
  });

  test('Android renewal refuses a different account BEFORE saving (source '
      'gate -- the native SDK has no seam on this host)', () {
    final src =
        File('lib/adapters/auth/google_auth_service.dart').readAsStringSync();
    final start = src.indexOf('Future<AuthResult> _refreshViaNativeSignIn(');
    final lightweight =
        src.indexOf('attemptLightweightAuthentication()', start);
    final check =
        src.indexOf('isExpectedAccount(user.email, tokens.email)', lightweight);
    final save = src.indexOf('saveGmailTokens(accountId, newTokens)', check);
    expect(lightweight, greaterThan(start));
    expect(check, greaterThan(lightweight));
    expect(save, greaterThan(check));
  });

  test('network errors are classified as "not reachable", a refusal is not',
      () {
    expect(GmailApiAdapter.isNetworkError(const SocketException('down')),
        isTrue);
    expect(GmailApiAdapter.isNetworkError(http.ClientException('reset')),
        isTrue);
    expect(GmailApiAdapter.isNetworkError(TimeoutException('slow')), isTrue);
    expect(GmailApiAdapter.isNetworkError(Exception('401 Unauthorized')),
        isFalse);
  });

  group('Windows token path', () {
    test('OFFLINE: a connection error, and the healthy account is NOT '
        'flagged', () async {
      GmailApiAdapter.debugHttpClientFactory = () =>
          MockClient((_) async => throw const SocketException('offline'));
      await expectLater(GmailApiAdapter().loadCredentials(_creds()),
          throwsA(isA<ConnectionException>()));
      expect(await flagged(), isFalse);
    });

    test('Gmail says "try later" (503): a connection error, NOT flagged',
        () async {
      GmailApiAdapter.debugHttpClientFactory = () => MockClient((_) async =>
          json(503, '{"error":{"code":503,"message":"Backend Error"}}'));
      await expectLater(GmailApiAdapter().loadCredentials(_creds()),
          throwsA(isA<ConnectionException>()));
      expect(await flagged(), isFalse);
    });

    test('renewal handing back the SAME refused token is not a renewal: '
        'flagged, never scanned with the dead token', () async {
      // The stored token has NOT reached its local expiry, so
      // getValidAccessToken returns it unchanged -- the token Gmail refused.
      store['saved_accounts'] = _gmail;
      store['credentials_${_gmail}_platformId'] = 'gmail';
      store['token_${_gmail}_gmail_tokens'] = jsonEncode({
        'accessToken': 'stored-token',
        'refreshToken': null,
        'expiresAt':
            DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        'grantedScopes': ['https://www.googleapis.com/auth/gmail.modify'],
        'email': _gmail,
      });
      GmailApiAdapter.debugHttpClientFactory = () => MockClient((_) async =>
          json(401, '{"error":{"code":401,"message":"Invalid Credentials"}}'));
      await expectLater(GmailApiAdapter().loadCredentials(_creds()),
          throwsA(isA<GmailSignInRequiredException>()));
      expect(await flagged(), isTrue);
    });

    test('token refused and renewal impossible in the background: flagged, '
        'and the typed exception', () async {
      GmailApiAdapter.debugHttpClientFactory = () => MockClient((_) async =>
          json(401, '{"error":{"code":401,"message":"Invalid Credentials"}}'));
      await expectLater(GmailApiAdapter().loadCredentials(_creds()),
          throwsA(isA<GmailSignInRequiredException>()));
      expect(await flagged(), isTrue);
    });

    test('insufficient scopes in the background: flagged, and the typed '
        'exception', () async {
      GmailApiAdapter.debugHttpClientFactory = () => MockClient((req) async {
            if (req.url.path.endsWith('/profile')) {
              return json(200, '{"emailAddress":"$_gmail"}');
            }
            return json(403,
                '{"error":{"code":403,"message":"Request had insufficient authentication scopes."}}');
          });
      final adapter = GmailApiAdapter();
      await adapter.loadCredentials(_creds());
      await expectLater(
          adapter.fetchMessages(daysBack: 1, folderNames: ['INBOX']),
          throwsA(isA<GmailSignInRequiredException>()));
      expect(await flagged(), isTrue);
    });
  }, skip: !Platform.isWindows);
}
