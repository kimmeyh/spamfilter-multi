/// Sprint 74 Manual Validation (Harold Q1, 2026-09-27): a FAILED Gmail token
/// renewal must not delete the stored tokens.
///
/// On the Fold8 (0.16.0) a Gmail account added through OAuth scanned once and
/// then showed "Error: Missing credentials" with Delete as the only option.
/// Android's sign-in stores no refresh token, so about an hour later the next
/// use renews through `attemptLightweightAuthentication`, and five renewal
/// failure paths deleted the tokens -- including ones that can be transient.
///
/// SOURCE GATE. `GoogleAuthService` has no seam: renewal goes through the
/// google_sign_in singleton and a static desktop OAuth handler, so no test
/// drives a real renewal. What this does NOT catch: a new deletion added
/// through a different call (for example a direct secure-storage delete), or
/// the renewal failing in a way that still leaves the account unusable -- the
/// Fold8 run in Sprint 75 is the behavioral check.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src =
      File('lib/adapters/auth/google_auth_service.dart').readAsStringSync();

  /// The body of the method whose signature starts with [signature]: from it
  /// to the next method signature at the same indentation.
  String bodyOf(String signature) {
    final start = src.indexOf(signature);
    expect(start, greaterThan(-1), reason: 'method not found: $signature');
    final next = RegExp(r'\n  (Future<|void |static |bool |String )')
        .firstMatch(src.substring(start + signature.length));
    return next == null
        ? src.substring(start)
        : src.substring(start, start + signature.length + next.start);
  }

  for (final method in [
    'Future<AuthResult> _refreshToken(',
    'Future<AuthResult> _refreshViaNativeSignIn(',
    'Future<AuthResult> _refreshViaHttp(',
    'Future<AuthResult> _attemptSilentSignIn(',
    'Future<AuthResult> initialize(',
    'Future<String?> getValidAccessToken(',
  ]) {
    test('$method never deletes the stored Gmail tokens', () {
      expect(bodyOf(method).contains('deleteGmailTokens('), isFalse,
          reason: 'a failed renewal deleted the tokens and left the account '
              'as "Missing credentials" (Fold8, 0.16.0)');
    });
  }

  test('only signOut deletes tokens (the user asked for it)', () {
    final all = RegExp(r'deleteGmailTokens\(').allMatches(src).length;
    final inSignOut = RegExp(r'deleteGmailTokens\(')
        .allMatches(bodyOf('Future<void> signOut('))
        .length;
    expect(inSignOut, greaterThan(0));
    expect(all, inSignOut,
        reason: 'every token deletion must be inside signOut');
  });
}
