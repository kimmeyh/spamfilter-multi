/// Sprint 77 MV-Q5 (Harold): every prompt "should state what it actually is
/// - an 'App Password' or a regular non-app 'Password'". The ONE place the
/// word is chosen, from the provider's sign-in method, so the setup form, its
/// messages and the account list cannot disagree again (before this, the
/// form said "Password" for a Custom IMAP account while the list said
/// "App Password").
library;

import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';

/// "App Password" for a provider that takes an app password, otherwise
/// "Password" (a Custom IMAP server takes the mailbox's normal password).
String credentialLabel(AuthMethod method) =>
    method == AuthMethod.appPassword ? 'App Password' : 'Password';

/// [credentialLabel] for [platformId], from its adapter. An unknown platform
/// reads as "Password", the plainer word, rather than claiming an app
/// password.
String credentialLabelFor(String platformId) {
  final method = PlatformRegistry.getPlatform(platformId)?.supportedAuthMethod;
  return method == null ? 'Password' : credentialLabel(method);
}
