import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import 'account_selection_screen.dart';
import 'no_rule_review_screen.dart';

/// Main navigation entry point, shared across every platform (F142, Sprint
/// 57).
///
/// Before F142, Android rendered a separate bottom-navigation shell with
/// "Rules" and "Settings" tabs backed by dead-end placeholder screens (they
/// required an `accountId` the shell had no mechanism to supply). That
/// scaffolding predated and diverged from the Sprint 51/52 desktop
/// navigation overhaul (`SelectedAccountProvider` session-scoped account
/// context, `StandardAppBarActions` canonical AppBar-icon order, F135's
/// `NoRuleReviewScreen`-as-default pattern). Per Harold's governing
/// direction (Sprint 54 F141 deep dive, 2026-08-03): Windows' current
/// architecture takes precedence over old Android-first scaffolding, so
/// Android now renders the SAME default-screen decision desktop uses --
/// there is no more platform branch here at all.
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AppDefaultScreen();
}

/// Picks the app's default screen based on whether any account exists
/// (F135, Sprint 52 retro IMP-3; shared with Android since F142, Sprint 57).
///
/// Deliberately a separate widget rather than a `FutureBuilder` inline in
/// [MainNavigationScreen.build]: that build method runs on every rebuild, and
/// re-reading the credential store each time would both cost IO and risk
/// flipping the user off their current screen mid-session.
class _AppDefaultScreen extends StatefulWidget {
  const _AppDefaultScreen();

  @override
  State<_AppDefaultScreen> createState() => _AppDefaultScreenState();
}

class _AppDefaultScreenState extends State<_AppDefaultScreen> {
  /// null = still resolving; true = at least one account exists.
  bool? _hasAccounts;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // No try/catch here deliberately (Copilot review, PR #292):
    // SecureCredentialsStore.getSavedAccounts() already catches, logs, and
    // returns an empty list on failure, so a wrapper here would be unreachable
    // -- and a silent `catch (_)` at this layer would swallow any genuinely
    // unexpected error instead of surfacing it.
    //
    // The fallback behaviour is unchanged and still correct: a credential-store
    // failure yields an empty list, so we land on Account Selection. That screen
    // surfaces the per-account error state and offers delete/re-add, which is
    // what a user with a broken store needs to see. Defaulting to the No-Rule
    // screen would show an empty list with no way to fix it.
    final accounts = await SecureCredentialsStore().getSavedAccounts();
    if (mounted) setState(() => _hasAccounts = accounts.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) =>
      appDefaultScreenFor(hasAccounts: _hasAccounts);
}

/// The app's default-screen DECISION, extracted so it is testable without a
/// credential store (PR #292 review -- this branch decides what the app shows
/// on launch and had zero coverage, and it is the change that caused MV-1).
///
/// [hasAccounts] null means "still resolving".
///   null  -> neutral spinner (never flash Account Selection then replace it)
///   true  -> Review No Rule Items (F135: the app default when accounts exist)
///   false -> Account Selection (nothing to review yet, and it is the screen
///            that can add an account or repair a broken credential store)
@visibleForTesting
Widget appDefaultScreenFor({required bool? hasAccounts}) {
  if (hasAccounts == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
  return hasAccounts
      ? const NoRuleReviewScreen()
      : const AccountSelectionScreen();
}
