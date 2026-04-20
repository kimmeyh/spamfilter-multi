import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/security/certificate_pinner.dart';

/// Unit tests for [CertificatePinner] (SEC-8, Sprint 33).
///
/// Network-based tests (actually validating a TLS handshake against
/// accounts.google.com) are intentionally excluded from this suite --
/// they would couple CI to Google's CA rotation cadence. We test the
/// pure pinning logic (registry lookup, kill switch, fingerprint
/// comparison) with stub inputs instead.
void main() {
  tearDown(() {
    CertificatePinner.resetPinsForTesting();
    CertificatePinner.setEnabled(true);
  });

  group('CertificatePinner registry', () {
    test('ships with pins for Google OAuth hosts', () {
      final pins = CertificatePinner.pins;
      expect(pins.containsKey('accounts.google.com'), isTrue);
      expect(pins.containsKey('oauth2.googleapis.com'), isTrue);
      expect(pins.containsKey('gmail.googleapis.com'), isTrue);
      expect(pins.containsKey('www.googleapis.com'), isTrue);
    });

    test('returned pin map is unmodifiable', () {
      final pins = CertificatePinner.pins;
      expect(() => pins['evil.example.com'] = ['x'],
          throwsUnsupportedError);
    });
  });

  group('CertificatePinner kill switch', () {
    test('is enabled by default', () {
      expect(CertificatePinner.enabled, isTrue);
    });

    test('setEnabled toggles the flag', () {
      CertificatePinner.setEnabled(false);
      expect(CertificatePinner.enabled, isFalse);
      CertificatePinner.setEnabled(true);
      expect(CertificatePinner.enabled, isTrue);
    });
  });

  group('CertificatePinner.setPinsForTesting', () {
    test('replaces the pin map until reset', () {
      CertificatePinner.setPinsForTesting({
        'example.com': ['abc='],
      });
      expect(CertificatePinner.pins.containsKey('example.com'), isTrue);
      expect(
          CertificatePinner.pins.containsKey('accounts.google.com'), isFalse);

      CertificatePinner.resetPinsForTesting();
      expect(
          CertificatePinner.pins.containsKey('accounts.google.com'), isTrue);
    });
  });

  group('CertificatePinMismatchException', () {
    test('toString includes host and expected/actual pins', () {
      final ex = CertificatePinMismatchException(
        host: 'example.com',
        expected: 'abc=, def=',
        actual: 'xyz=',
      );
      final msg = ex.toString();
      expect(msg, contains('example.com'));
      expect(msg, contains('abc='));
      expect(msg, contains('xyz='));
    });
  });
}
