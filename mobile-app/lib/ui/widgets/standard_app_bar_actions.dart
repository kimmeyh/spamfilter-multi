import 'dart:io';
import 'package:flutter/material.dart';

import '../screens/account_selection_screen.dart';
import '../screens/help_screen.dart';
import '../screens/no_rule_review_screen.dart';
import '../screens/scan_history_screen.dart';
import '../screens/settings_screen.dart';

/// The ONE definition of the standard AppBar action icons and their ORDER
/// (F134, Sprint 51 retro IMP-2).
///
/// Harold, 2026-07-30, specified the canonical order for every screen:
///
///   Review "No Rule" Items, View Scan History, Accounts, Settings, Help
///
/// with screen-specific icons (Download, Find, Refresh) preceding that block,
/// and the Exit button appended automatically by [AppBarWithExit].
///
/// **Why this is shared rather than copied per screen**: before this, five
/// screens each hand-rolled the same five IconButtons in four DIFFERENT orders,
/// and `scan_progress_screen.dart` carried a comment asserting a "standardized
/// icon order -- History, Accounts, Help, Settings" that matched no other
/// screen. That is precisely the duplication-drift defect class the F130
/// process-docs audit keeps finding, reproduced in code. One builder means the
/// order cannot diverge again: change it here, every screen follows.
///
/// Ordering rule, in one place so it is never re-derived from memory:
/// navigation-to-elsewhere icons run left to right in the sequence above, and
/// **Help is always LAST** (Harold confirmed 2026-07-30). Screen-specific
/// actions come FIRST, because they act on the current screen's content.
class StandardAppBarActions {
  StandardAppBarActions._();

  /// Builds the standard trailing action block in the canonical order.
  ///
  /// [accountId] / [accountEmail] / [platformId] / [platformDisplayName] scope
  /// the History, Settings and Help destinations to the current account when
  /// known. When [accountId] is null the Settings icon is omitted rather than
  /// pushed with a bogus id -- callers that have no account context (e.g. the
  /// account-selection screen itself) supply their own Settings handler via
  /// [onSettings].
  ///
  /// [helpSection] deep-links Help to the relevant part of the Help screen.
  ///
  /// [leading] holds screen-specific actions (Download, Find, Refresh) that
  /// must appear BEFORE the standard block.
  ///
  /// [onAccounts] defaults to popping back to the first route (the account
  /// selection screen), which is what every current caller wants.
  static List<Widget> build({
    required BuildContext context,
    required HelpSection helpSection,
    String? accountId,
    String? accountEmail,
    String? platformId,
    String? platformDisplayName,
    List<Widget> leading = const [],
    VoidCallback? onSettings,
    VoidCallback? onAccounts,
    VoidCallback? onScanHistory,
    VoidCallback? onManualScan,
    bool includeNoRuleReview = true,
    bool includeScanHistory = true,
    bool includeAccounts = true,
    bool includeSettings = true,
    bool includeHelp = true,
  }) {
    return [
      // Screen-specific actions first (Download, Find, Refresh, ...).
      ...leading,

      // 0. Manual / Live Scan (Harold 2026-07-31, during MV-1):
      //    "the Account screen is also, currently, the only way to get to the
      //    Live Scan/Manual Scan screen -- but an icon for the Manual Scan
      //    Screen would be advisable."
      //
      //    Opt-IN rather than default-on, unlike the other actions: starting a
      //    scan needs a resolved account AND its platformId (an async
      //    credential-store read), which this builder cannot do inline without
      //    duplicating the F135 resolver. A screen that already has that
      //    context supplies [onManualScan]; screens that do not simply omit it
      //    and keep reaching Manual Scan via the Accounts screen exactly as
      //    before. Nothing regresses for a screen that does not pass it.
      //
      //    Placed FIRST in the standard block because it acts on the selected
      //    account rather than navigating to a management surface, and because
      //    appending it would put it after Help -- Help is always last.
      //    LABEL: the destination screen titles itself "Manual Scan -
      //    <email>", so the tooltip matches the screen you land on. Harold
      //    okayed "Live Scan" if it read better, but the button ON that screen
      //    is already "Start Live Scan" -- naming the icon for the ACTION and
      //    the screen for the DESTINATION would make them look like two
      //    different places. The radar icon carries the "scanning" sense that
      //    a generic play arrow does not.
      if (onManualScan != null)
        IconButton(
          icon: const Icon(Icons.radar),
          tooltip: 'Manual Scan',
          onPressed: onManualScan,
        ),

      // 1. Review "No Rule" Items -- Windows-desktop scoped, matching the
      //    existing F112/F39 entry points.
      if (includeNoRuleReview && Platform.isWindows)
        IconButton(
          icon: const Icon(Icons.rule_folder_outlined),
          tooltip: 'Review "No Rule" Items',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NoRuleReviewScreen()),
          ),
        ),

      // 2. View Scan History -- [onScanHistory] lets a screen supply its own
      //    navigation (e.g. Settings, which routes through a helper that also
      //    carries platform/email context it already resolved).
      if (includeScanHistory)
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'View Scan History',
          onPressed: onScanHistory ??
              () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScanHistoryScreen(
                        platformId: platformId,
                        platformDisplayName: platformDisplayName,
                        accountId: accountId,
                        accountEmail: accountEmail,
                      ),
                    ),
                  ),
        ),

      // 3. Accounts
      //
      // MV-1 FIX (Sprint 52, Harold 2026-07-31): this used to default to
      // `Navigator.popUntil(context, (route) => route.isFirst)`. That was
      // correct BEFORE F135 -- Account Selection was effectively what the first
      // route rendered, so unwinding to it worked. F135 changed the desktop
      // default screen to Review "No Rule" Items, and the first route is
      // MainNavigationScreen, which now renders the No-Rule screen inline
      // whenever at least one account exists. Account Selection is therefore
      // NOT a route on desktop at all, so popUntil could never reach it:
      //   - from the No-Rule screen itself, popUntil found it was already at
      //     the first route and did nothing at all (the reported symptom -- a
      //     completely dead icon);
      //   - from any deeper screen it unwound to the No-Rule screen instead of
      //     to Accounts.
      //
      // Harold: "the account screen is still needed for adding additional
      // accounts ... it is no longer the default screen if you have more than
      // one account setup, but still needs to be available (also for making
      // updates to an email account)."
      //
      // PUSHING is the correct verb now: Account Selection is a destination
      // like any other, not an ancestor to unwind to. Screens that ARE the
      // account selection screen pass includeAccounts: false, so this never
      // pushes a duplicate of itself.
      //
      // The two changes were each correct in isolation and broke only at their
      // intersection -- which is exactly the class of defect a shared builder
      // is supposed to make impossible to hit in only some places. It is
      // fixed once here, so every screen gets it.
      if (includeAccounts)
        IconButton(
          icon: const Icon(Icons.people),
          tooltip: 'Select Account',
          onPressed: onAccounts ??
              () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSelectionScreen(),
                    ),
                  ),
        ),

      // 4. Settings -- omitted when there is no account to scope it to and the
      //    caller supplied no handler, rather than pushing a bogus accountId.
      if (includeSettings && (onSettings != null || accountId != null))
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: onSettings ??
              () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(accountId: accountId!),
                    ),
                  ),
        ),

      // 5. Help -- ALWAYS LAST (Harold, 2026-07-30).
      if (includeHelp)
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Help',
          onPressed: () => openHelp(
            context,
            helpSection,
            accountId: accountId,
            accountEmail: accountEmail,
            platformId: platformId,
            platformDisplayName: platformDisplayName,
          ),
        ),
    ];
  }
}
