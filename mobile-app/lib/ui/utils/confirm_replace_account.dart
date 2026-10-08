import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';

import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/storage/secure_credentials_store.dart';

/// Sprint 77 MV-Q4 and final review: the ONE place every add-account flow
/// asks "Replace its saved sign-in details?".
///
/// Accounts are keyed by email address alone, so adding an address that is
/// already saved replaces that account's sign-in. Every add path calls
/// [confirmReplaceExistingAccount] (or, below the UI, passes it to
/// `GoogleAuthService.signIn(confirmAdd: ...)`) before it saves anything:
/// the password form, Google Sign-In (native and browser), the WebView
/// sign-in and the manual token screen. A normal token renewal for an
/// existing account does NOT call it.

/// The text of the "Account already added" question.
///
/// [providerName] null = the saved account's provider is unknown.
@visibleForTesting
String replaceAccountMessage(String? providerName) {
  final which = providerName == null ? '' : ' ($providerName)';
  return 'This email address is already added$which. Replace its saved '
      'sign-in details with the ones you entered? Its scan history, rules '
      'and settings are kept.';
}

/// The text of the question when saved accounts could not be read.
@visibleForTesting
String replaceAccountUnknownMessage() =>
    'The app could not check whether this email address is already added. '
    'If it is, continuing replaces its saved sign-in details with the ones '
    'you entered. Its scan history, rules and settings are kept. Continue?';

/// The provider's display name for a stored platform id, or null.
@visibleForTesting
String? providerNameFor(String? platformId) {
  if (platformId == null) return null;
  if (platformId == 'gmail-imap') return 'Gmail, App Password';
  for (final info in PlatformRegistry.getSupportedPlatforms()) {
    if (info.id == platformId) return info.displayName;
  }
  return null;
}

/// The decision, with the question injected so it is testable without a
/// widget. True = go ahead and save.
///
/// Fails CLOSED: an unreadable store ([AccountPresence.unknown]) asks the
/// question, exactly as a saved address does.
Future<bool> shouldReplaceAccount({
  required SecureCredentialsStore store,
  required String accountId,
  required Future<bool> Function(String message) ask,
}) async {
  final presence = await store.accountPresence(accountId);
  switch (presence) {
    case AccountPresence.absent:
      return true;
    case AccountPresence.unknown:
      return ask(replaceAccountUnknownMessage());
    case AccountPresence.present:
      final existing = await store.getPlatformId(accountId);
      return ask(replaceAccountMessage(providerNameFor(existing)));
  }
}

/// Ask with the standard dialog. False also when the screen is gone.
Future<bool> confirmReplaceExistingAccount(
  BuildContext context,
  SecureCredentialsStore store,
  String accountId,
) {
  return shouldReplaceAccount(
    store: store,
    accountId: accountId,
    ask: (message) async {
      if (!context.mounted) return false;
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Account already added'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      return replace == true;
    },
  );
}
