/// PR #448 test review (Sprint 75): the Gmail adapter's `initialize` path --
/// the one Android Gmail always takes, and Windows takes when no access token
/// is stored -- decides three things F239 depends on:
///
///   1. renewal impossible (`!result.success`) -> the account is FLAGGED and
///      `GmailSignInRequiredException` is thrown (a background skip with
///      "Sign In Again" in the account list);
///   2. Google's session is a DIFFERENT account -> flagged and thrown. This is
///      the ONLY guard: `GoogleAuthService.initialize` returns the stored
///      tokens' email without comparing it to the requested account, so a
///      revert to log-and-continue would run this account's rules -- possibly
///      in a deleting mode -- against another person's mailbox;
///   3. success -> a stale flag is CLEARED, so "Sign In Again" disappears.
///
/// The REAL adapter and auth service run over fake secure storage and a real
/// test database. No access token is passed in, so the Windows stored-token
/// branch is skipped and these run on every host, including CI (ubuntu).
///
/// What these do NOT catch: an EXCEPTION thrown out of `initialize` (review
/// M-2: network -> ConnectionException, anything else -> plain
/// AuthenticationException, neither flagged). On this host `initialize`
/// cannot throw -- storage errors are swallowed into "no tokens", and the
/// rethrowing path is Android's native refresh, which has no seam here.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart' show Credentials;
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/services/background_mode_service.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

const _gmail = 'someone@gmail.com';
const _other = 'somebody.else@gmail.com';

/// No access token: the adapter goes through `GoogleAuthService.initialize`.
Credentials _creds() => Credentials(
      email: _gmail,
      additionalParams: {'accountId': _gmail, 'isGmailOAuth': 'true'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late DatabaseTestHelper testHelper;
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
        case 'delete':
          store.remove(key);
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
    BackgroundModeService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
    await testHelper.tearDown();
  });

  Future<bool> flagged() => SettingsStore().getGmailSignInRequired(_gmail);

  /// Saved, unexpired tokens for [_gmail] whose session email is [email].
  void saveTokens({required String email}) {
    store['saved_accounts'] = _gmail;
    store['credentials_${_gmail}_platformId'] = 'gmail';
    store['token_${_gmail}_gmail_tokens'] = jsonEncode({
      'accessToken': 'valid-token',
      'refreshToken': null,
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
      'grantedScopes': ['https://www.googleapis.com/auth/gmail.modify'],
      'email': email,
    });
  }

  test('renewal impossible (nothing stored): flagged, and the typed '
      'exception', () async {
    await expectLater(GmailApiAdapter().loadCredentials(_creds()),
        throwsA(isA<GmailSignInRequiredException>()));
    expect(await flagged(), isTrue);
  });

  test('Google returns a DIFFERENT account: flagged, typed exception, and '
      'the adapter is not left connected', () async {
    saveTokens(email: _other);
    final adapter = GmailApiAdapter();
    await expectLater(adapter.loadCredentials(_creds()),
        throwsA(isA<GmailSignInRequiredException>()));
    expect(await flagged(), isTrue);
    // A second load must not slip through on a cached "connected" session.
    await expectLater(adapter.loadCredentials(_creds()),
        throwsA(isA<GmailSignInRequiredException>()));
  });

  test('success clears a stale "Sign In Again" flag', () async {
    await SettingsStore().setGmailSignInRequired(_gmail, true);
    expect(await flagged(), isTrue);
    saveTokens(email: _gmail);
    await GmailApiAdapter().loadCredentials(_creds());
    expect(await flagged(), isFalse);
  });
}
