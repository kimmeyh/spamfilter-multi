/// Sprint 77 MV-Q4 = 1 (Harold): adding an email address that is already
/// saved asks "Replace?" instead of silently overwriting that account.
///
/// What this does NOT catch: the dialog's buttons (no widget harness exists
/// for AccountSetupScreen; its credential store is created inside the State),
/// and `credentialsExist` returning false on a storage READ error, which
/// skips the question (the save that follows would hit the same storage).
/// Manual Validation step: add an existing address and see the question.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';

void main() {
  test('the question names the saved provider and what is kept', () {
    expect(
        replaceAccountMessage('AOL'),
        'This email address is already added (AOL). Replace its saved '
        'sign-in details with the ones you entered? Its scan history, rules '
        'and settings are kept.');
    expect(replaceAccountMessage(null), startsWith('This email address is already added. '));
  });

  test('provider names come from the provider list', () {
    for (final info in PlatformRegistry.getSupportedPlatforms()) {
      expect(providerNameFor(info.id), info.displayName);
    }
    expect(providerNameFor('gmail-imap'), 'Gmail, App Password');
    expect(providerNameFor(null), isNull);
    expect(providerNameFor('no-such'), isNull);
  });

  test('source gate: the save path asks BEFORE it saves credentials', () {
    final src = File('lib/ui/screens/account_setup_screen.dart').readAsStringSync();
    final connect = src.indexOf('Future<void> _handleConnect()');
    expect(connect, greaterThan(0));
    final ask = src.indexOf('await _confirmReplaceExisting(email)', connect);
    final save = src.indexOf('_credStore.saveCredentials(', connect);
    expect(ask, greaterThan(connect), reason: 'the question is on the save path');
    expect(save, greaterThan(ask), reason: 'asked before anything is saved');
    // And a "no" stops the save.
    final guard = src.substring(ask - 10, ask + 120);
    expect(guard, contains('if (!await _confirmReplaceExisting(email))'));
    expect(src.substring(ask, save), contains('return;'));
  });
}
