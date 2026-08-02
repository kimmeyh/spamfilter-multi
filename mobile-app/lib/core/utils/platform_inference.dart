/// Platform inference from an email address (Sprint 52, PR #292 review).
///
/// THE ONE implementation. There were three copies of this logic -- two in
/// `account_selection_screen.dart` and one in `standard_app_bar_actions.dart`
/// -- and they DIVERGED when a security fix (match on the address ENDING, not
/// `contains`) was applied to only one of them: `evil@gmail.com.attacker.net`
/// was blocked on the AppBar path while still resolving as Gmail on the
/// account-selection path, and `User@GMAIL.COM` resolved on one path and not
/// the other. A semantics fix must sweep every code path that parses the value;
/// one shared function is how that stays true.
///
/// This is domain logic, not UI -- it lives in core so no widget owns it.
library;

/// Sentinel returned by [inferPlatformFromEmail] when the address matches no
/// known provider. Named rather than inlined so guards cannot drift from the
/// value they check.
const String unknownPlatformId = 'unknown';

/// Infers a platformId from an email address, for accounts saved before the
/// platformId was recorded.
///
/// Matches on the address ENDING, case-normalized: a `contains('@gmail.com')`
/// test also matches `user@gmail.com.attacker.example`, which is a different
/// host entirely. Six domains map to five providers.
///
/// Returns [unknownPlatformId] when nothing matches -- callers must treat that
/// as a resolution FAILURE (report, do not navigate/scan with it), because the
/// generic IMAP adapter supports hosts this function cannot guess.
String inferPlatformFromEmail(String email) {
  final address = email.trim().toLowerCase();
  if (address.endsWith('@gmail.com')) return 'gmail';
  if (address.endsWith('@aol.com')) return 'aol';
  if (address.endsWith('@yahoo.com')) return 'yahoo';
  if (address.endsWith('@outlook.com') || address.endsWith('@hotmail.com')) {
    return 'outlook';
  }
  if (address.endsWith('@icloud.com')) return 'icloud';
  return unknownPlatformId;
}
