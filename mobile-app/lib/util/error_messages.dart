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
import '../core/services/email_scanner.dart' show ScanFetchFailedException;

/// Converts common exception types into a short, human-readable sentence.
class ErrorMessages {
  ErrorMessages._();

  static const _generic = 'Something went wrong. Please try again.';

  /// Returns a user-facing message for [error], safe to display directly
  /// (no raw exception class names, stack traces, or internal detail).
  static String humanize(Object error) {
    if (error is AuthRateLimitedException) {
      final unlock = error.blockedUntil.toLocal();
      final hh = unlock.hour.toString().padLeft(2, '0');
      final mm = unlock.minute.toString().padLeft(2, '0');
      return 'Too many failed sign-in attempts. Try again at $hh:$mm.';
    }
    if (error is GmailSignInRequiredException) {
      // F239: the user can fix this one, and the app says how -- plus what
      // went wrong this time (a wrong account, a cancelled sign-in).
      final detail = error.detail;
      return '${GmailSignInRequiredException.reason}.'
          '${detail == null || detail.isEmpty ? '' : ' $detail'}';
    }
    if (error is AuthenticationException) {
      // Copilot review (PR #317): provider-agnostic wording -- OAuth flows
      // (Gmail Google Sign-In) have no password for the user to check.
      return 'Sign-in failed. Please check your sign-in details and try again.';
    }
    if (error is UserFacingConnectionException) {
      // F192: the adapter already wrote a safe sentence for this failure.
      return error.userMessage;
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
    if (error is ScanFetchFailedException) {
      // Sprint 76 7.7.1 review: every folder failed -- almost always no
      // network. Use the underlying error's message when it is a known one.
      final cause = error.cause;
      if (cause != null && cause is! ScanFetchFailedException) {
        final inner = humanize(cause);
        if (inner != _generic) return inner;
      }
      return 'Could not read any folder from the email server. Please check your internet connection and try again.';
    }
    return _generic;
  }
}
