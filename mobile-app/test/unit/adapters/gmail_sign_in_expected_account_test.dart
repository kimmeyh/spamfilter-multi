/// F239 (Sprint 75): two account-safety rules in GoogleAuthService.
///
/// R-4 -- "Sign In Again" repairs ONE account. If Google returns a different
/// account, nothing may be saved: `saveGmailTokens` also ADDS the account to
/// the saved list, so a wrong-account sign-in used to create a stray second
/// account.
///
/// R-5 -- `getValidAccessToken` serves the token of the account asked for,
/// never `accounts.first`. A fresh service (Folder Selection creates one) with
/// AOL saved first used to look up AOL's Gmail tokens.
///
/// What these do NOT catch: the interactive Google sign-in itself (no seam --
/// the native picker and the desktop browser flow are static/singleton), so
/// the "check before save" order on those two paths is a SOURCE gate.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/auth/google_auth_service.dart';
import 'package:my_email_spam_filter/adapters/auth/token_store.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';

class _FakeCredStore extends SecureCredentialsStore {
  _FakeCredStore(this.accounts, this.tokens);
  final List<String> accounts;
  final Map<String, GmailTokens> tokens;
  final tokenReads = <String>[];

  @override
  Future<List<String>> getSavedAccounts() async => accounts;

  @override
  Future<GmailTokens?> getGmailTokens(String accountId) async {
    tokenReads.add(accountId);
    return tokens[accountId];
  }

  @override
  Future<String?> getPlatformId(String accountId) async =>
      accountId.contains('gmail') ? 'gmail' : 'aol';
}

GmailTokens _fresh(String email, String token) => GmailTokens(
      accessToken: token,
      refreshToken: null,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      grantedScopes: const [],
      email: email,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R-4: the expected-account check', () {
    test('same address (any case) passes; a different address fails', () {
      expect(GoogleAuthService.isExpectedAccount('A@Gmail.com', 'a@gmail.com'),
          isTrue);
      expect(GoogleAuthService.isExpectedAccount('b@gmail.com', 'a@gmail.com'),
          isFalse);
      expect(GoogleAuthService.isExpectedAccount('b@gmail.com', null), isTrue,
          reason: 'a first-time add expects no particular account');
    });

    test('both sign-in paths check BEFORE saving the tokens (source gate)', () {
      final src =
          File('lib/adapters/auth/google_auth_service.dart').readAsStringSync();
      for (final method in [
        'Future<AuthResult> _signInNative(',
        'Future<AuthResult> _signInDesktop(',
      ]) {
        final start = src.indexOf(method);
        expect(start, greaterThan(-1), reason: method);
        final check = src.indexOf('isExpectedAccount(', start);
        final save = src.indexOf('saveGmailTokens(', start);
        expect(check, greaterThan(start), reason: method);
        expect(save, greaterThan(check),
            reason: '$method: saving before the check would add a wrong '
                'account to the saved list');
      }
    });
  });

  group('R-5: getValidAccessToken never falls back to another account', () {
    test('with AOL saved FIRST, asking for the Gmail account returns the Gmail '
        'token', () async {
      final store = _FakeCredStore(
        ['user@aol.com', 'someone@gmail.com'],
        {'someone@gmail.com': _fresh('someone@gmail.com', 'gmail-token')},
      );
      final token = await GoogleAuthService(credentialsStore: store)
          .getValidAccessToken(accountId: 'someone@gmail.com');
      expect(token, 'gmail-token');
      expect(store.tokenReads, isNot(contains('user@aol.com')));
    });

    test('with no account given and none current, it returns null and reads '
        'no tokens', () async {
      final store = _FakeCredStore(
        ['someone@gmail.com'],
        {'someone@gmail.com': _fresh('someone@gmail.com', 'gmail-token')},
      );
      final token =
          await GoogleAuthService(credentialsStore: store).getValidAccessToken();
      expect(token, isNull,
          reason: 'it used to serve accounts.first -- a guess');
      expect(store.tokenReads, isEmpty);
    });

    test('an account that is not saved returns null', () async {
      final store = _FakeCredStore(['user@aol.com'], {});
      final token = await GoogleAuthService(credentialsStore: store)
          .getValidAccessToken(accountId: 'someone@gmail.com');
      expect(token, isNull);
    });
  });
}
