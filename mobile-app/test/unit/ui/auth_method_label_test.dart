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
}
