import 'dart:io';
import 'package:flutter/material.dart';

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
    bool includeNoRuleReview = true,
    bool includeScanHistory = true,
    bool includeAccounts = true,
    bool includeSettings = true,
    bool includeHelp = true,
  }) {
    return [
      // Screen-specific actions first (Download, Find, Refresh, ...).
      ...leading,

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

      // 2. View Scan History
      if (includeScanHistory)
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'View Scan History',
          onPressed: () => Navigator.of(context).push(
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
      if (includeAccounts)
        IconButton(
          icon: const Icon(Icons.people),
          tooltip: 'Select Account',
          onPressed: onAccounts ??
              () => Navigator.popUntil(context, (route) => route.isFirst),
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
