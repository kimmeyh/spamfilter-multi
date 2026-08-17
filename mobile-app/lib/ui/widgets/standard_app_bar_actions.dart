import 'package:flutter/material.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/utils/platform_inference.dart';
import '../screens/account_selection_screen.dart';
import '../screens/help_screen.dart';
import '../screens/no_rule_review_screen.dart';
import '../screens/scan_history_screen.dart';
import '../screens/scan_progress_screen.dart';
import '../screens/settings_screen.dart';

/// The ONE definition of the standard AppBar action icons and their ORDER
/// (F134, Sprint 51 retro IMP-2).
///
/// Harold specified the canonical order for every screen (2026-07-30; Manual
/// Scan position updated per the Sprint 58 MV-4 audit, 2026-08-15):
///
///   Review No Rule Items, View Scan History, Manual Scan, Select Account,
///   Settings, Help
///
/// with screen-specific icons preceding that block in the order Reload,
/// Export Results, Search (each only where the screen has it), and the Exit
/// button appended automatically by [AppBarWithExit].
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
    bool includeManualScan = true,
    bool includeNoRuleReview = true,
    bool includeScanHistory = true,
    bool includeAccounts = true,
    bool includeSettings = true,
    bool includeHelp = true,
  }) {
    return [
      // Screen-specific actions first (Download/Export, Find/Search,
      // Refresh/Reload, ...). Their own relative order is Harold's MV-4 spec
      // (2026-08-15): Reload, Export Results, Search -- callers pass them in
      // that order.
      ...leading,

      // 1. Review No Rule Items -- ALL platforms since F143 (Sprint 60).
      //
      //    History: F142 (Sprint 57) deliberately Windows-gated this icon
      //    because NoRuleReviewScreen's multi-select was Ctrl/Shift/right-click
      //    only -- surfacing the screen's deep-link on Android would have led
      //    to a bulk-action interaction that does not work by touch. F143
      //    landed the touch selection model (long-press to select, tap to
      //    toggle while a selection is active), so the gate's reason is gone
      //    and it is removed per F142's own revisit note.
      if (includeNoRuleReview)
        IconButton(
          icon: const Icon(Icons.rule_folder_outlined),
          tooltip: 'Review No Rule Items',
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

      // 3. Manual / Live Scan (Harold 2026-07-31, during MV-1):
      //    "the Account screen is also, currently, the only way to get to the
      //    Live Scan/Manual Scan screen -- but an icon for the Manual Scan
      //    Screen would be advisable."
      //
      //    POSITION (Sprint 58 MV-4, Harold 2026-08-15): moved from first in
      //    the standard block to AFTER View Scan History, per the audited
      //    canonical order: No-Rule Review, Scan History, Manual Scan,
      //    Accounts, Settings, Help. (The original first-position rationale --
      //    "acts on the selected account rather than a management surface" --
      //    is superseded by Harold's explicit full ordering.)
      //    LABEL: the destination screen titles itself "Manual Scan -
      //    <email>", so the tooltip matches the screen you land on. Harold
      //    okayed "Live Scan" if it read better, but the button ON that screen
      //    is already "Start Live Scan" -- naming the icon for the ACTION and
      //    the screen for the DESTINATION would make them look like two
      //    different places. The radar icon carries the "scanning" sense that
      //    a generic play arrow does not.
      //
      //    DEFAULT-ON, suppressed only by the Manual Scan screen itself
      //    (Harold 2026-07-31: "The radar icon belongs on either: all screens
      //    OR all screens except the Manual Scan screen (follow the same
      //    pattern as for icon tool bar currently)"). This mirrors every other
      //    action here: on everywhere, with `include*: false` used ONLY for the
      //    self-referential case -- No-Rule hides No-Rule, Settings hides
      //    Settings, Scan History hides Scan History.
      //
      //    Like Settings, it is omitted when there is no account to scope it to
      //    and the caller supplied no handler, rather than opening a scan
      //    screen with nothing to scan.
      //
      //    NET EFFECT (re-audited 2026-08-02 against this guard, PR #292
      //    re-review -- the previous "9 of 15" figure here was WRONG and
      //    survived two fix rounds; it omitted three screens and its arithmetic
      //    never matched the guard). Across the 15 screens (16 call sites)
      //    using this builder, the icon can appear on at most SIX:
      //      - always (3): folder_selection, results_display (non-nullable
      //        accountId) and no_rule_review (always passes onManualScan);
      //      - only when an account is resolvable (3): help_screen,
      //        scan_history and settings (nullable accountId).
      //    Never on the other nine: scan_progress (includeManualScan: false --
      //    it IS Manual Scan); the five Help-only editors (rules_management,
      //    safe_senders_management, rule_test, rule_quick_add,
      //    yaml_import_export); and account_selection, account_setup (both call
      //    sites) and platform_selection, which pass no accountId and no
      //    handler. The editor and account-flow screens are deliberate: showing
      //    an icon that cannot resolve an account would be the MV-1 dead-icon
      //    class again. If Manual Scan is ever wanted there, give them an
      //    accountId first.
      if (includeManualScan && (onManualScan != null || accountId != null))
        IconButton(
          icon: const Icon(Icons.radar),
          tooltip: 'Manual Scan',
          onPressed: onManualScan ??
              () => openManualScan(
                    context,
                    accountId: accountId!,
                    accountEmail: accountEmail,
                    platformId: platformId,
                    platformDisplayName: platformDisplayName,
                  ),
        ),

      // 4. Accounts
      //
      // MV-1 FIX (Sprint 52, Harold 2026-07-31): this used to default to
      // `Navigator.popUntil(context, (route) => route.isFirst)`. That was
      // correct BEFORE F135 -- Account Selection was effectively what the first
      // route rendered, so unwinding to it worked. F135 changed the desktop
      // default screen to Review No Rule Items, and the first route is
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

      // 5. Settings -- omitted when there is no account to scope it to and the
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

      // 6. Help -- ALWAYS LAST (Harold, 2026-07-30).
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

  /// Opens the Manual Scan screen for [accountId], resolving the pieces
  /// `ScanProgressScreen` requires but that most callers do not carry.
  ///
  /// Lives here rather than on each screen so the resolution exists ONCE.
  /// `account_selection_screen._selectAccount` had this logic inline, and the
  /// first cut of the No-Rule icon copied it -- two copies of a platform
  /// lookup is exactly the duplication-drift this class exists to prevent.
  ///
  /// [platformId] is looked up in the credential store when the caller does not
  /// already know it, with a domain-based fallback for accounts saved before
  /// the platformId was recorded.
  ///
  /// PUBLIC so a screen that needs to do something on RETURN can await it --
  /// the No-Rule screen reloads, because a scan can resolve items it is
  /// currently displaying. Such a screen passes its own [onManualScan] that
  /// calls this, rather than reimplementing the resolution.
  static Future<void> openManualScan(
    BuildContext context, {
    required String accountId,
    String? accountEmail,
    String? platformId,
    String? platformDisplayName,
  }) async {
    var resolvedPlatformId = platformId ?? '';
    if (resolvedPlatformId.isEmpty) {
      resolvedPlatformId =
          await SecureCredentialsStore().getPlatformId(accountId) ?? '';
    }
    if (resolvedPlatformId.isEmpty) {
      resolvedPlatformId = inferPlatformFromEmail(accountEmail ?? accountId);
    }

    // The await above crosses an async gap; the screen may have been popped.
    if (!context.mounted) return;

    // DO NOT navigate with an unresolved platform (PR #292 review).
    // `inferPlatformFromEmail` (core/utils/platform_inference.dart -- the ONE
    // implementation; this widget's private copy diverged from its two
    // account_selection_screen siblings and was removed) returns
    // `unknownPlatformId` for any address outside its six known domains --
    // which includes every custom or corporate IMAP host the generic adapter
    // otherwise supports fine. Pushing anyway put "unknown" into the scan
    // pipeline: the real failure (`EmailScanner`: 'Platform unknown not
    // supported') only surfaced two screens later, in a Results screen titled
    // with a provider the user never chose, after they tapped Start Live Scan.
    //
    // The sentinel is also ambiguous at this boundary: it is indistinguishable
    // between a genuinely unsupported provider, a keystore read failure inside
    // getPlatformId (which swallows its own errors and returns null), and a
    // missing _platformId key. Reporting here keeps the message honest about
    // what we actually know.
    //
    // This mirrors what settings_screen.dart already does correctly in three
    // places: resolve, and on failure show a message and return WITHOUT
    // navigating. The shared helper was the outlier.
    if (resolvedPlatformId.isEmpty ||
        resolvedPlatformId == unknownPlatformId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not determine the email provider for this account. Open '
              'Accounts and re-add it to restore its provider setting.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanProgressScreen(
          platformId: resolvedPlatformId,
          platformDisplayName:
              platformDisplayName ?? _platformDisplayName(resolvedPlatformId),
          accountId: accountId,
          accountEmail: accountEmail ?? accountId,
        ),
      ),
    );
  }

  // Platform inference and its `unknownPlatformId` sentinel moved to
  // `core/utils/platform_inference.dart` (PR #292 re-review): this widget's
  // private copy had diverged from the two copies in
  // `account_selection_screen.dart` when the endsWith security fix was applied
  // here only -- the spoof address the AppBar path blocked still resolved as
  // Gmail on the account-selection path. One core function, three call sites.

  static String _platformDisplayName(String platformId) {
    switch (platformId) {
      case 'gmail':
        return 'Gmail';
      case 'aol':
        return 'AOL';
      case 'yahoo':
        return 'Yahoo';
      case 'outlook':
        return 'Outlook';
      case 'icloud':
        return 'iCloud';
      default:
        return platformId;
    }
  }
}
