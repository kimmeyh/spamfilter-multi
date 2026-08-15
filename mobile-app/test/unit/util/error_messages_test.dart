/// F151f (Sprint 58): ErrorMessages.humanize() classifies common exception
/// types and returns a clean, human-readable sentence -- generalizes the
/// AuthRateLimitedException-specific handling that already existed in
/// AccountSetupScreen._testConnection() so all 3 raw-exception call sites
/// (connection test, credential save, scan failure) share one
/// implementation instead of three near-duplicate ad hoc checks.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/security/auth_rate_limiter.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

void main() {
  group('ErrorMessages.humanize', () {
    test('AuthRateLimitedException -> shows the unlock time, not raw toString', () {
      final blockedUntil = DateTime(2026, 8, 15, 14, 30);
      final error = AuthRateLimitedException('test@example.com', blockedUntil);

      final message = ErrorMessages.humanize(error);

      expect(message, contains('Too many failed sign-in attempts'));
      expect(message, contains('14:30'));
      expect(message, isNot(contains('AuthRateLimitedException')));
    });

    test('AuthenticationException -> human sign-in message, not raw toString', () {
      final error = AuthenticationException('bad password', 'raw detail');

      final message = ErrorMessages.humanize(error);

      expect(message, contains('Sign-in failed'));
      expect(message, isNot(contains('AuthenticationException')));
      expect(message, isNot(contains('raw detail')));
    });

    test('ConnectionException -> human connectivity message, not raw toString', () {
      final error = ConnectionException('imap.example.com timed out');

      final message = ErrorMessages.humanize(error);

      expect(message, contains('Unable to connect'));
      expect(message, isNot(contains('ConnectionException')));
      expect(message, isNot(contains('imap.example.com')));
    });

    test('CredentialStorageException -> human save-failure message, not raw toString', () {
      final error = CredentialStorageException('write failed', 'os error 5');

      final message = ErrorMessages.humanize(error);

      expect(message, contains('Unable to save'));
      expect(message, isNot(contains('CredentialStorageException')));
      expect(message, isNot(contains('os error 5')));
    });

    test('SocketException -> human connectivity message, not raw toString', () {
      final error = const SocketException('Connection refused');

      final message = ErrorMessages.humanize(error);

      expect(message, contains('Unable to connect'));
      expect(message, isNot(contains('SocketException')));
    });

    test('TimeoutException -> human timeout message, not raw toString', () {
      final error = TimeoutException('operation timed out');

      final message = ErrorMessages.humanize(error);

      expect(message, contains('took too long'));
      expect(message, isNot(contains('TimeoutException')));
    });

    test('unrecognized exception type -> generic fallback, not raw toString', () {
      final error = Exception('some internal detail nobody should see');

      final message = ErrorMessages.humanize(error);

      expect(message, 'Something went wrong. Please try again.');
      expect(message, isNot(contains('some internal detail')));
    });
  });
}
