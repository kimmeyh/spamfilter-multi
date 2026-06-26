import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/util/redact.dart';

/// Unit tests for [Redact].
///
/// Focused on the SEC-19 (Sprint 33) runtime auth-logging toggle. Full
/// redaction format coverage lives in integration/auth tests.
void main() {
  group('Redact.logSafe runtime toggle (SEC-19)', () {
    setUp(() {
      // Ensure a clean default before each test (other tests may mutate it)
      Redact.setAuthLoggingDisabled(false);
    });

    tearDown(() {
      Redact.setAuthLoggingDisabled(false);
    });

    test('default state is enabled (authLoggingDisabled == false)', () {
      expect(Redact.authLoggingDisabled, isFalse);
    });

    test('setAuthLoggingDisabled(true) updates the cached flag', () {
      Redact.setAuthLoggingDisabled(true);
      expect(Redact.authLoggingDisabled, isTrue);
    });

    test('setAuthLoggingDisabled can be toggled back off', () {
      Redact.setAuthLoggingDisabled(true);
      Redact.setAuthLoggingDisabled(false);
      expect(Redact.authLoggingDisabled, isFalse);
    });

    test('logSafe does not throw when logging disabled', () {
      // We cannot intercept Logger output easily here; the behavioral
      // contract is: the call returns silently without error when the
      // flag is on. A regression (e.g. stray null access) would surface
      // as a thrown exception.
      Redact.setAuthLoggingDisabled(true);
      expect(() => Redact.logSafe('test message'), returnsNormally);
    });

    test('logSafe does not throw when logging enabled', () {
      Redact.setAuthLoggingDisabled(false);
      expect(() => Redact.logSafe('test message'), returnsNormally);
    });
  });

  group('Redact value formatters', () {
    test('email redacts local part but preserves domain', () {
      expect(Redact.email('user@gmail.com'), 'u***@gmail.com');
    });

    test('email handles null and empty', () {
      expect(Redact.email(null), '[empty]');
      expect(Redact.email(''), '[empty]');
    });

    test('accountId redacts plain email form', () {
      expect(Redact.accountId('user@example.com'), 'u***@example.com');
    });

    test('accountId redacts prefixed form', () {
      expect(Redact.accountId('gmail-user@example.com'),
          'gmail-u***@example.com');
    });

    test('token shows first/last 4 chars for long tokens', () {
      expect(Redact.token('abcdefghijklmnop'), 'abcd...mnop');
    });

    test('token returns [redacted] for short tokens', () {
      expect(Redact.token('short'), '[redacted]');
    });
  });

  group('F110 -- senderForLog (narrowed redaction)', () {
    const userEmails = {'kimmeyharold@aol.com', 'kimmeyh@gmail.com'};

    test('logs a third-party sender in the clear', () {
      expect(Redact.senderForLog('spammer@evil.com', userEmails),
          'spammer@evil.com');
    });

    test('masks the user\'s own address (exact match)', () {
      expect(Redact.senderForLog('kimmeyharold@aol.com', userEmails),
          'k***@aol.com');
    });

    test('masks the user\'s own address case-insensitively', () {
      expect(Redact.senderForLog('KimmeyHarold@AOL.com', userEmails),
          'K***@AOL.com');
    });

    test('handles a Name <addr> header form -- third party in clear', () {
      expect(Redact.senderForLog('Evil Co <spammer@evil.com>', userEmails),
          'Evil Co <spammer@evil.com>');
    });

    test('masks a Name <addr> form when the addr is the user\'s own', () {
      expect(Redact.senderForLog('Me <kimmeyh@gmail.com>', userEmails),
          'k***@gmail.com');
    });

    test('empty user-account set logs everything in the clear', () {
      expect(Redact.senderForLog('anyone@x.com', const {}), 'anyone@x.com');
    });

    test('null/empty address', () {
      expect(Redact.senderForLog(null, userEmails), '[empty]');
      expect(Redact.senderForLog('', userEmails), '[empty]');
    });

    // PR #265 Copilot review: account ids of the form {platform}-{email} must
    // match by suffix, even when the platform id itself contains '-'
    // (e.g. "gmail-imap"). A naive first-'-' split mis-parsed these and failed
    // to mask the user's own address.
    test('masks the user own address when accounts are full account ids', () {
      const accounts = {
        'aol-kimmeyharold@aol.com',
        'gmail-imap-kimmeyh@gmail.com', // hyphenated platform id
      };
      expect(Redact.senderForLog('kimmeyharold@aol.com', accounts),
          'k***@aol.com');
      expect(Redact.senderForLog('kimmeyh@gmail.com', accounts),
          'k***@gmail.com');
      // a third-party sender is still logged in the clear
      expect(Redact.senderForLog('spammer@evil.com', accounts),
          'spammer@evil.com');
    });

    test('suffix match does not over-mask a different local-part', () {
      const accounts = {'gmail-imap-kimmeyh@gmail.com'};
      // "h@gmail.com" is a suffix of "...kimmeyh@gmail.com" as a STRING but the
      // bare-address compare requires the '-<bare>' boundary, so a genuinely
      // different address is NOT masked.
      expect(
          Redact.senderForLog('otheruser@gmail.com', accounts),
          'otheruser@gmail.com');
    });
  });
}
