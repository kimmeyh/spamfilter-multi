import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/gmail_oauth_screen.dart';

/// F211 (Sprint 69): the project's first external tester could not add a Gmail
/// account. Google returned "Access blocked ... Error 400: invalid_request",
/// with the real cause -- "Custom URI scheme is not enabled for your Android
/// client" -- hidden behind an "error details" link. The app displayed that
/// raw message and offered nothing further, so the tester stopped.
///
/// The console fix is the real repair (docs/OAUTH_SETUP.md, Android Step 5).
/// This pins the SECOND half: when Google Sign-In is unusable, the user must be
/// pointed at App Password, which connects the same mailbox and does not depend
/// on the OAuth client's settings at all.
///
/// Scoped deliberately. This asserts WHICH messages earn a hint, not the
/// prose -- wording is free to improve without breaking the suite.
void main() {
  group('F211 actionable sign-in hint', () {
    String? hint(String? message) => GmailOAuthScreen.actionableHint(message);

    test('the exact tester-facing Google text earns a hint', () {
      // Verbatim from the tester's screenshot, 2026-09-10.
      expect(
        hint("Access blocked: spamfilter-multi's request is invalid"),
        isNotNull,
      );
      expect(hint('Error 400: invalid_request'), isNotNull);
      expect(
        hint('Custom URI scheme is not enabled for your Android client.'),
        isNotNull,
      );
    });

    test('the hint names App Password, the route that still works', () {
      final text = hint('Error 400: invalid_request')!;
      expect(text, contains('App Password'));
    });

    test('matching is case-insensitive -- providers vary their casing', () {
      expect(hint('CUSTOM URI SCHEME IS NOT ENABLED'), isNotNull);
      expect(hint('custom uri scheme is not enabled'), isNotNull);
      expect(hint('Invalid_Request'), isNotNull);
    });

    test('an unrelated failure gets NO hint -- it would be wrong advice', () {
      // These are not routed around by an App Password, so promising one
      // would send the user down a second dead end.
      expect(hint('Network unreachable'), isNull);
      expect(hint('Authentication cancelled'), isNull);
      expect(hint('Failed to save credentials: disk full'), isNull);
      expect(hint(''), isNull);
    });

    test('a null message is safe -- the panel renders only on an error', () {
      expect(hint(null), isNull);
    });
  });
}
