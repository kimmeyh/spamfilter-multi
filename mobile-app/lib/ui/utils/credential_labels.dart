/// Sprint 77 MV-Q5 (Harold): every prompt "should state what it actually is
/// - an 'App Password' or a regular non-app 'Password'". The ONE place the
/// word is chosen, from the provider's sign-in method, so the setup form, its
/// messages and the account list cannot disagree again (before this, the
/// form said "Password" for a Custom IMAP account while the list said
/// "App Password").
///
/// MV-Q8 (Harold, 2026-10-07, option 1): a Custom IMAP account pointed at a
/// server KNOWN to take only an app password (Yahoo, AOL, Gmail, iCloud) says
/// "App Password" too; any other server says "Password" with
/// [kCustomImapPasswordHint] under the field, because the app cannot know
/// what an unknown server takes.
library;

import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';

/// Shown under the Custom IMAP password field when the server is not one of
/// [_appPasswordDomains].
const String kCustomImapPasswordHint =
    'If your provider requires an app password, enter it here.';

/// Mail domains whose IMAP servers accept only an app password for a
/// third-party app. Matched on a whole-label suffix of the server name, so
/// `imap.mail.yahoo.com` matches `yahoo.com` and `notyahoo.com` does not.
const Map<String, String> _appPasswordDomains = <String, String>{
  'yahoo.com': 'Yahoo',
  'aol.com': 'AOL',
  'gmail.com': 'Gmail',
  'googlemail.com': 'Gmail',
  'me.com': 'iCloud',
  'icloud.com': 'iCloud',
};

/// The provider name when [host] is a server known to take only an app
/// password, otherwise null.
String? appPasswordProviderForHost(String? host) {
  final h = (host ?? '').trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
  if (h.isEmpty) return null;
  for (final entry in _appPasswordDomains.entries) {
    if (h == entry.key || h.endsWith('.${entry.key}')) return entry.value;
  }
  return null;
}

/// "App Password" for a provider that takes an app password, otherwise
/// "Password" (a Custom IMAP server takes the mailbox's normal password).
String credentialLabel(AuthMethod method) =>
    method == AuthMethod.appPassword ? 'App Password' : 'Password';

/// [credentialLabel] for [platformId], from its adapter. An unknown platform
/// reads as "Password", the plainer word, rather than claiming an app
/// password. For Custom IMAP ('imap'), [imapHost] decides: a known
/// app-password server reads "App Password".
String credentialLabelFor(String platformId, {String? imapHost}) {
  if (platformId == 'imap' && appPasswordProviderForHost(imapHost) != null) {
    return 'App Password';
  }
  final method = PlatformRegistry.getPlatform(platformId)?.supportedAuthMethod;
  return method == null ? 'Password' : credentialLabel(method);
}
