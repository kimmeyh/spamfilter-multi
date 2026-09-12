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
/// **The negative cases matter more than the positive ones.** Code review found
/// the first version matched bare `invalid_request` and `error 400` -- generic
/// OAuth2 codes that a transient token-endpoint failure also produces. Since
/// `_errorMessage` is assigned from sites that interpolate arbitrary exception
/// text, that version would have told a user to abandon Google Sign-In when a
/// retry would have worked. Confident wrong advice is worse than none, so the
/// tests below fix the boundary in both directions.
void main() {
  group('F211 actionable sign-in hint', () {
    String? hint(String? message) => GmailOAuthScreen.actionableHint(message);

    group('fires on what Google actually says', () {
      test('the verbatim cause, from Google error details', () {
        expect(
          hint('Custom URI scheme is not enabled for your Android client.'),
          isNotNull,
        );
      });

      test('the consent-screen refusal the tester saw', () {
        // Verbatim from the tester's screenshot, 2026-09-10.
        expect(
          hint("Access blocked: spamfilter-multi's request is invalid"),
          isNotNull,
        );
      });

      test('invalid_request WITH Google\'s own refusal wording', () {
        expect(
          hint('Error 400: invalid_request -- the request is invalid'),
          isNotNull,
        );
      });

      test('matching is case-insensitive -- providers vary their casing', () {
        expect(hint('CUSTOM URI SCHEME IS NOT ENABLED'), isNotNull);
        expect(hint('ACCESS BLOCKED: request refused'), isNotNull);
      });

      test('the hint names App Password, the route that still works', () {
        final text = hint('Access blocked: request is invalid')!;
        expect(text, contains('App Password'));
      });

      test('the hint hedges rather than asserting -- it is a text match', () {
        final text = hint('Access blocked: request is invalid')!;
        expect(text, contains('may not be available'));
      });
    });

    group('stays silent where an App Password would NOT help', () {
      test('a bare generic OAuth2 code gets NO hint', () {
        // The regression code review caught: a transient token-endpoint 400
        // from clock skew, an expired code, or a code reused on retry. Telling
        // the user to abandon Google Sign-In here is wrong advice.
        expect(hint('invalid_request'), isNull);
        expect(hint('Error 400'), isNull);
        expect(hint('Browser authentication failed: invalid_request'), isNull);
        expect(
          hint('Error: TokenException(error 400, code already redeemed)'),
          isNull,
        );
      });

      test('an unrelated failure gets NO hint', () {
        expect(hint('Network unreachable'), isNull);
        expect(hint('Authentication cancelled'), isNull);
        expect(hint('Sign-in was cancelled or failed'), isNull);
        expect(hint('Failed to save credentials: disk full'), isNull);
        expect(hint(''), isNull);
      });
    });

    test('a null message is safe -- the panel renders only on an error', () {
      expect(hint(null), isNull);
    });
  });
}
