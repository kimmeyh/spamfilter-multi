import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../adapters/auth/google_auth_service.dart';
import '../../adapters/email_providers/spam_filter_platform.dart'
    show GmailSignInRequiredException;
import '../../core/storage/settings_store.dart';

/// F239 (Sprint 75): "Sign In Again" for a Gmail account whose sign-in could
/// not be renewed without the user.
///
/// ONE implementation for both places the problem is reported -- the account
/// list row and a failed scan -- so they cannot drift. It re-runs the
/// interactive Google sign-in for THAT account only
/// ([GoogleAuthService.signIn] refuses a different account before saving
/// anything), clears the account's "needs sign-in" flag on success, and tells
/// the user the result. The account keeps its id, settings and history.
class SignInAgain {
  SignInAgain._();

  static final Logger _logger = Logger();

  /// The button label, shared by every surface.
  static const String label = 'Sign In Again';

  /// Test seam: replaces the interactive Google sign-in.
  @visibleForTesting
  static Future<AuthResult> Function(String accountId)? debugSignIn;

  /// True if [message] is the "Gmail needs you to sign in again" failure, as
  /// [ErrorMessages.humanize] words it for a scan error.
  static bool isSignInRequiredMessage(String? message) =>
      message != null && message.contains(GmailSignInRequiredException.reason);

  /// Run sign-in for [accountId] and report the result in a snackbar.
  /// Returns true when the account is signed in again.
  static Future<bool> run(BuildContext context, String accountId) async {
    final messenger = ScaffoldMessenger.of(context);
    final signIn = debugSignIn ??
        (String id) => GoogleAuthService().signIn(expectedAccountId: id);
    final result = await signIn(accountId);
    if (result.success) {
      try {
        await SettingsStore().setGmailSignInRequired(accountId, false);
      } catch (e) {
        _logger.w('F239: could not clear the Gmail sign-in state: $e');
      }
      messenger.showSnackBar(SnackBar(
        content: Text('Signed in again as $accountId.'),
      ));
      return true;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(result.errorMessage ?? 'Sign-in did not complete.'),
    ));
    return false;
  }
}
