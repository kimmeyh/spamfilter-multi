import 'package:flutter/foundation.dart';

/// Session-scoped "currently selected account" (F135, Sprint 51 retro IMP-3).
///
/// Harold, 2026-07-30: *"If an account is selected while the app is running, the
/// app should keep track of this setting and assume any other needs for the
/// account resolve to this selection unless the user returns to the Account page
/// and selects another. The pop-up should appear only as needed: 1) an account
/// has not been selected AND 2) the user gets to a page that needs it (3
/// account-specific settings pages and the Manual Live Scan page)."*
///
/// Before this, every account-scoped destination re-prompted with the account
/// picker even though the user had already chosen an account moments earlier.
/// The picker is now LAZY: shown only when [hasSelection] is false AND the
/// destination genuinely needs an account.
///
/// **Deliberately NOT persisted** (Harold approved option A, 2026-07-30):
/// "does not need to be persisted between sessions". The selection lives for
/// the life of the process and resets on restart, matching "while the app is
/// running". Persisting it would also change startup semantics -- the app would
/// boot straight into the last account's screen -- which was explicitly not
/// wanted. If that changes, persist via `SettingsStore`; do not add a second
/// source of truth here.
///
/// Which surfaces require an account (and therefore may prompt):
///   - Settings > Account, Manual Scan, Background tabs (account-scoped)
///   - Manual / Live Scan
/// Which do NOT:
///   - Settings > General (cross-account by design -- rules, retention, privacy)
///   - Review "No Rule" Items (aggregates across ALL accounts)
///   - Scan History (shows every account's scans)
class SelectedAccountProvider extends ChangeNotifier {
  String? _accountId;

  /// The accountId chosen this session, or null if the user has not picked one.
  String? get accountId => _accountId;

  /// True when an account has been chosen this session. Callers use this to
  /// decide whether the picker is needed -- never prompt when this is true.
  bool get hasSelection => _accountId != null && _accountId!.isNotEmpty;

  /// Record the user's choice. Called from the Account Selection screen and
  /// from the picker dialog itself, so a picker shown on the way to Settings
  /// also satisfies the next account-scoped destination.
  void select(String accountId) {
    if (accountId.isEmpty || _accountId == accountId) return;
    _accountId = accountId;
    notifyListeners();
  }

  /// Clear the selection. Used when the selected account is deleted, so a
  /// stale id can never be handed to a screen that would then fail to load
  /// credentials for it.
  void clear() {
    if (_accountId == null) return;
    _accountId = null;
    notifyListeners();
  }

  /// Clear only if [accountId] is the one currently selected. Convenience for
  /// account deletion, where clearing unconditionally would discard a valid
  /// selection when a DIFFERENT account was deleted.
  void clearIfSelected(String accountId) {
    if (_accountId == accountId) clear();
  }
}
