/// Human-readable error message conversion.
///
/// ## Purpose
/// F151f (Sprint 58): several catch-all error paths (account connection
/// test, credential save, scan failure) fell back to raw exception
/// interpolation (`'Connection failed: $e'`), which surfaces internal
/// exception-class names and stack-adjacent detail to a first-time user
/// (e.g. `ConnectionException: <message>` or a raw `SocketException`
/// `toString()`). This mirrors the account-setup screen's own existing
/// pattern for `AuthRateLimitedException` -- classify by exception type,
/// return a clean sentence -- generalized so all 3 sites share one
/// implementation instead of three near-duplicate ad hoc checks.
///
/// ## Usage
/// ```dart
/// try {
///   await platform.testConnection();
/// } catch (e) {
///   final userMessage = ErrorMessages.humanize(e);
///   // userMessage is safe to show directly, e.g. in a SnackBar
/// }
/// ```
library;

import 'dart:async';
import 'dart:io';

import '../adapters/email_providers/spam_filter_platform.dart';
import '../adapters/storage/secure_credentials_store.dart';
import '../core/security/auth_rate_limiter.dart';

/// Converts common exception types into a short, human-readable sentence.
class ErrorMessages {
  ErrorMessages._();

  /// Returns a user-facing message for [error], safe to display directly
  /// (no raw exception class names, stack traces, or internal detail).
  static String humanize(Object error) {
    if (error is AuthRateLimitedException) {
      final unlock = error.blockedUntil.toLocal();
      final hh = unlock.hour.toString().padLeft(2, '0');
      final mm = unlock.minute.toString().padLeft(2, '0');
      return 'Too many failed sign-in attempts. Try again at $hh:$mm.';
    }
    if (error is AuthenticationException) {
      return 'Sign-in failed. Please check your email and password and try again.';
    }
    if (error is ConnectionException) {
      return 'Unable to connect to the email server. Please check your internet connection and try again.';
    }
    if (error is CredentialStorageException) {
      return 'Unable to save your account. Please try again.';
    }
    if (error is SocketException) {
      return 'Unable to connect to the email server. Please check your internet connection and try again.';
    }
    if (error is TimeoutException) {
      return 'The request took too long to respond. Please check your internet connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
