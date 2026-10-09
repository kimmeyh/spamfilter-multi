/// Sprint 77 MV-Q5 (Harold): a prompt states what the user actually types,
/// "App Password" or a regular "Password".
///
/// Before this, two sources disagreed: the provider list (`PlatformRegistry`
/// `PlatformInfo.authMethod`) said Custom IMAP takes a normal password, and
/// the adapter (`supportedAuthMethod`, which the account list reads) said
/// app password for every IMAP provider. The demo adapter said OAuth 2.0.
///
/// What this does NOT catch: a NEW hard-coded "App Password" string typed
/// into a screen instead of using `credentialLabel` (review), or the
/// instruction text for creating an app password (correctly App Password).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/ui/utils/credential_labels.dart';

void main() {
  test('every provider adapter reports the sign-in method the provider list '
      'records', () {
    final infos = PlatformRegistry.getSupportedPlatforms();
    expect(infos, isNotEmpty);
    for (final info in infos) {
      final adapter = PlatformRegistry.getPlatform(info.id);
      if (adapter == null) continue; // listed but not yet implemented
      expect(adapter.supportedAuthMethod, info.authMethod, reason: info.id);
    }
  });

  test('the label names what is typed', () {
    expect(credentialLabelFor('aol'), 'App Password');
    expect(credentialLabelFor('yahoo'), 'App Password');
    expect(credentialLabelFor('icloud'), 'App Password');
    expect(credentialLabelFor('gmail-imap'), 'App Password');
    expect(credentialLabelFor('imap'), 'Password');
    expect(credentialLabelFor('no-such-provider'), 'Password');
    expect(credentialLabel(AuthMethod.appPassword), 'App Password');
    expect(credentialLabel(AuthMethod.basicAuth), 'Password');
  });

  // MV-Q8 (Harold, 2026-10-07, option 1): Custom IMAP on a known
  // app-password server says "App Password"; any other server "Password".
  // What this does NOT catch: a provider that starts requiring app passwords
  // and is not in the list (the hint line covers it for the user).
  group('MV-Q8 Custom IMAP label follows the server', () {
    test('the providers\' own servers are recognized', () {
      expect(appPasswordProviderForHost('imap.mail.yahoo.com'), 'Yahoo');
      expect(appPasswordProviderForHost('imap.aol.com'), 'AOL');
      expect(appPasswordProviderForHost('imap.gmail.com'), 'Gmail');
      expect(appPasswordProviderForHost('imap.mail.me.com'), 'iCloud');
      expect(appPasswordProviderForHost('  IMAP.Mail.Yahoo.COM. '), 'Yahoo');
    });

    test('other servers, look-alikes and blanks are not', () {
      expect(appPasswordProviderForHost('imap.fastmail.com'), isNull);
      expect(appPasswordProviderForHost('localhost'), isNull);
      expect(appPasswordProviderForHost('notyahoo.com'), isNull);
      expect(appPasswordProviderForHost('yahoo.com.evil.example'), isNull);
      expect(appPasswordProviderForHost(''), isNull);
      expect(appPasswordProviderForHost(null), isNull);
    });

    test('label', () {
      expect(credentialLabelFor('imap', imapHost: 'imap.mail.yahoo.com'),
          'App Password');
      expect(credentialLabelFor('imap', imapHost: 'localhost'), 'Password');
      expect(credentialLabelFor('imap'), 'Password');
      // The host never changes a non-custom provider.
      expect(credentialLabelFor('aol', imapHost: 'localhost'), 'App Password');
    });

    test('the setup form and the account list pass the server name '
        '(wiring; source gate)', () {
      final form =
          File('lib/ui/screens/account_setup_screen.dart').readAsStringSync();
      expect(form, contains('imapHost: _isCustomImap ? _hostController.text'));
      expect(form, contains('kCustomImapPasswordHint'));
      final list = File('lib/ui/screens/account_selection_screen.dart')
          .readAsStringSync();
      expect(list, contains('imapHost: displayData.imapHost'));
      expect(list,
          contains('_customImapHost(platformId, creds.additionalParams)'));
      expect(list, contains('params[CustomImapSettings.keyHost]'));
    });
  });
}
