/// F264 (Sprint 77): which accounts a "Scan when new mail arrives" run scans.
///
/// A mail app's notification starts ONE worker run with no account id. Before
/// F264 that run scanned every background-enabled account. Now each account has
/// its own new-mail switch, and the posting app decides which accounts the
/// notification can possibly be about:
///
///  - Gmail app -> Gmail accounts (platform ids `gmail` and `gmail-imap`)
///  - AOL app -> AOL accounts
///  - Yahoo Mail -> Yahoo accounts
///  - Samsung Email and Outlook -> every account with the switch on
///
/// **ONE copy of the package table.** The table lives in Kotlin
/// (`MailNotificationPolicy.providersFor`, JVM-tested) and the listener puts the
/// resolved provider set into the work payload under [kTriggerProvidersKey];
/// this file only reads that set. A second Dart copy of the package names would
/// be able to drift from the Kotlin one, so none exists.
///
/// Pure (no I/O) so the provider x switch x background matrix is unit-testable
/// without a phone. ADR-0042: Android only by nature (the payload comes only
/// from the Android notification listener); the function itself has no
/// platform code.
library;

/// Payload key carrying the providers the posting app maps to. Must match
/// `DozeScanTrigger.KEY_TRIGGER_PROVIDERS` in `DozeScanTrigger.kt` (pinned by a
/// source-parity test, the same way `triggerApp` is).
const String kTriggerProvidersKey = 'triggerProviders';

/// The payload value meaning "every provider" (Samsung Email, Outlook). Must
/// match `MailNotificationPolicy.ANY_PROVIDER` in Kotlin.
const String kAnyProvider = '*';

/// Provider family of a stored platform id: both Gmail paths (`gmail`, the API
/// adapter, and `gmail-imap`) are "gmail"; every other id is its own family
/// (`aol`, `yahoo`, `icloud`, ...).
String providerFamilyOf(String platformId) =>
    platformId == 'gmail' || platformId.startsWith('gmail-')
        ? 'gmail'
        : platformId;

/// Whether [providers] (the payload value) includes [platformId]'s family.
///
/// A null payload value means a build that did not send the set: treated as
/// "every provider", so a mismatch between native and Dart versions degrades to
/// the pre-F264 behavior for accounts whose own switch is on, never to
/// scanning nothing. An EMPTY value means the package maps to no provider.
bool providersInclude(String? providers, String platformId) {
  if (providers == null) return true;
  final parts = providers.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  if (parts.contains(kAnyProvider)) return true;
  return parts.contains(providerFamilyOf(platformId));
}

/// Whether a notification-started run scans this account: the account's
/// background switch is on AND its own new-mail switch is on AND the posting
/// app maps to its provider.
bool accountSelectedByNotification({
  required String? providers,
  required String platformId,
  required bool newMailSwitch,
  required bool backgroundEnabled,
}) =>
    backgroundEnabled &&
    newMailSwitch &&
    providersInclude(providers, platformId);
