/// F54 (Sprint 33): in-app Help screen.
///
/// One scrollable page, one anchored section per primary screen. Tapping the
/// Help icon on any AppBar pushes this screen with [initialSection] set to
/// that screen's anchor; the screen auto-scrolls so the relevant section is
/// already visible on arrival. The back button pops the Help screen and
/// returns the user to wherever they tapped the icon.
///
/// Content depth per section: 1-3 short paragraphs (tooltip-style), not a
/// walkthrough. Intended as "what is this screen for?" + "what are the
/// non-obvious controls?" quick reference.
library;

import 'package:flutter/material.dart';

/// Anchors for each primary screen section in [HelpScreen].
enum HelpSection {
  selectAccount,
  accountSetup,
  manualScan,
  resultsDisplay,
  scanHistory,
  settings,
  manageRules,
  ruleQuickAdd,
  ruleTest,
  safeSenders,
  folderSelection,
  yamlImportExport,
}

class HelpScreen extends StatefulWidget {
  /// Which section to scroll to on open. Null means "start from the top".
  final HelpSection? initialSection;

  const HelpScreen({super.key, this.initialSection});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<HelpSection, GlobalKey> _keys = {
    for (final s in HelpSection.values) s: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(
            widget.initialSection!,
          ));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(HelpSection section) {
    final keyContext = _keys[section]?.currentContext;
    if (keyContext == null) return;
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 300),
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: SelectionArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              HelpSection.selectAccount,
              title: 'Select Account',
              body:
                  'Start here. This screen lists every email account you have '
                  'added, along with the last-scan status. Tap an account to '
                  'open Manual Scan for that inbox. Use the "+" button to add '
                  'a new account, or swipe an account to delete all of its '
                  'data.',
            ),
            _section(
              HelpSection.accountSetup,
              title: 'Account Setup',
              body:
                  'Add a new email account. For Gmail, the recommended method '
                  'is an App Password (IMAP) with 2-Step Verification enabled; '
                  'Google Sign-In (OAuth) is available as an alternative but '
                  'may require more frequent re-authentication. For AOL, '
                  'Yahoo, and other IMAP providers, enter your email and an '
                  'app password from the provider\'s security settings.\n\n'
                  'The "Test Connection" button verifies credentials without '
                  'saving. If you see "Too many failed sign-in attempts", '
                  'wait for the displayed unlock time before retrying '
                  '(sign-in is rate-limited per account to resist brute force).',
            ),
            _section(
              HelpSection.manualScan,
              title: 'Manual Scan',
              body:
                  'Runs the rules engine against the current inbox. The '
                  'status banner shows total emails, deletions, moves, safe '
                  'senders, and errors. Progress updates are throttled for '
                  'performance -- final counts always appear when the scan '
                  'completes.\n\n'
                  'Scan mode is chosen in Settings; the default is '
                  'read-only (dry run). Switch to an action mode to actually '
                  'delete or move matched emails. The Select Account icon '
                  'returns to the account list; View Scan History shows past '
                  'scans for this account.',
            ),
            _section(
              HelpSection.resultsDisplay,
              title: 'Results',
              body:
                  'Shows every email the scanner processed, grouped by '
                  'action. Tap an email for its full subject, sender, folder, '
                  'and matched rule/pattern (if any). Use the search bar to '
                  'filter by any visible field, and the CSV icon to export.\n\n'
                  '"Back to Accounts" is a shortcut that returns to Select '
                  'Account in one hop (past the Scan Progress screen). The '
                  'regular back arrow returns to whichever screen you came '
                  'from (Scan Progress or Scan History).',
            ),
            _section(
              HelpSection.scanHistory,
              title: 'Scan History',
              body:
                  'Past scans for the current account. Tap a row to re-open '
                  'its Results view. Entries older than the retention window '
                  '(default 7 days, configurable in Settings > General) are '
                  'pruned automatically.',
            ),
            _section(
              HelpSection.settings,
              title: 'Settings',
              body:
                  'Four tabs. General covers rule management, scan-history '
                  'retention, privacy controls (auth log suppression, '
                  'unmatched-email retention, certificate pinning), and the '
                  '"Delete All App Data" reset. Account is per-account '
                  'overrides (safe-sender / deleted-rule folders). Manual '
                  'Scan and Background cover scan-mode defaults and schedule '
                  'options.\n\n'
                  'Most app-wide options live on General; per-account '
                  'overrides shadow the app-wide defaults when set.',
            ),
            _section(
              HelpSection.manageRules,
              title: 'Manage Rules',
              body:
                  'Browse and edit every spam rule the scanner will apply. '
                  'Each rule has an execution order, one or more condition '
                  'buckets (from / header / subject / body), and an action '
                  '(delete / move / categorize). Use the filter bar to '
                  'narrow by pattern category or subtype.\n\n'
                  'Patterns that match ReDoS heuristics '
                  '(catastrophic-backtracking regex) are rejected when you '
                  'save; this prevents scanner hangs. Rewrite the pattern '
                  'or simplify its quantifiers to save.',
            ),
            _section(
              HelpSection.ruleQuickAdd,
              title: 'Rule Quick Add',
              body:
                  'Streamlined flow for creating a block rule from a sample '
                  'email. Pick the condition bucket(s) that should match, '
                  'the action to take, and the execution order. Conflict '
                  'detection warns if a new rule overlaps or contradicts '
                  'existing ones; use "Test pattern" (flask icon) to '
                  'preview matches against your recent unmatched emails.',
            ),
            _section(
              HelpSection.ruleTest,
              title: 'Rule Test',
              body:
                  'Previews how a pattern would match against the current '
                  'unmatched-email pool. Useful when drafting a new rule '
                  'before committing. Matches highlight the portion of the '
                  'email (from / header / subject / body) the regex hit.',
            ),
            _section(
              HelpSection.safeSenders,
              title: 'Manage Safe Senders',
              body:
                  'Safe senders bypass all rules. Entries are regex patterns '
                  'matched against the full sender string. Common shapes:\n'
                  '- Exact email: ^user@example\\.com\$\n'
                  '- Domain + subdomains: ^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com\$\n\n'
                  'Ordering does not matter; safe senders are checked before '
                  'any block rule. ReDoS-vulnerable patterns are rejected '
                  'on save.',
            ),
            _section(
              HelpSection.folderSelection,
              title: 'Folder Selection',
              body:
                  'Pick which folders the scanner reads. Most providers list '
                  'INBOX plus a spam folder (Bulk, Junk, Spam, etc.); '
                  'select only the folders you want acted on. The move-to '
                  'folder for block rules is configured in Settings > '
                  'Account.',
            ),
            _section(
              HelpSection.yamlImportExport,
              title: 'YAML Import / Export',
              body:
                  'Back up or share rule sets via YAML files. Export writes '
                  'rules.yaml and rules_safe_senders.yaml to a timestamped '
                  'directory. Import merges entries from a YAML file into '
                  'the current database; existing patterns are skipped '
                  '(idempotent). Import files are capped at 10 MB and '
                  'parsed with ReDoS detection -- dangerous patterns are '
                  'rejected at parse time.',
            ),
            const SizedBox(height: 24),
            Text(
              'Last updated: Sprint 33 (April 2026). Report issues at '
              'github.com/kimmeyh/spamfilter-multi/issues.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(HelpSection section,
      {required String title, required String body}) {
    return Padding(
      key: _keys[section],
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Convenience helper: push a [HelpScreen] focused on [section].
///
/// Extracted so every screen's Help icon button can use the same call
/// without duplicating the MaterialPageRoute boilerplate.
void openHelp(BuildContext context, HelpSection section) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HelpScreen(initialSection: section),
    ),
  );
}
