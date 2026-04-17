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
}
