/// F54 (Sprint 33): in-app Help screen.
///
/// One scrollable page, one anchored section per primary screen or settings
/// tab. Tapping the Help icon on any AppBar pushes this screen with
/// [initialSection] set to that screen's anchor; the screen auto-scrolls so
/// the relevant section is already visible on arrival. The back button pops
/// the Help screen and returns the user to wherever they tapped the icon.
///
/// Content depth per section: 1-3 short paragraphs (tooltip-style), not a
/// walkthrough. Intended as "what is this screen for?" + "what are the
/// non-obvious controls?" quick reference.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Anchors for each primary screen / settings-tab section in [HelpScreen].
enum HelpSection {
  selectAccount,
  accountSetup,
  demoScan,
  manualScan,
  resultsDisplay,
  scanHistory,
  settings,
  folderSettings,
  manualScanSettings,
  backgroundScanning,
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
    // Round 2 feedback: ensure the target section lands at the TOP of the
    // viewport rather than just "somewhere visible". Combined with the
    // trailing filler SizedBox below, this lets any section pin to the top.
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 300),
      alignment: 0.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      // Round 2 feedback: wrap in Scrollbar with thumbVisibility: true so
      // the scroll position is always visible, not hover-only.
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SelectionArea(
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
                HelpSection.demoScan,
                title: 'Demo Scan',
                body:
                    'Demo Scan runs the rules engine against a bundled set of '
                    'synthetic emails -- no network, no real inbox, no risk of '
                    'side effects. Use it to see how rules resolve, to '
                    'validate a new rule change, or to demonstrate the app '
                    'without configuring an account.\n\n'
                    'Demo Results look identical to a live-scan Results '
                    'screen, but the "delete" and "move" actions are always '
                    'read-only (they cannot mutate the demo dataset). Tap '
                    'back to return to Manual Scan for the current account.',
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
                    'The back arrow returns to Manual Scan (or Scan History, '
                    'if you opened Results from a historical row). Manual '
                    'Scan is cleared on return so it is ready for the next '
                    'run.',
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
                    'overrides shadow the app-wide defaults when set. The '
                    'Help icon here deep-links to the section matching the '
                    'currently visible tab.',
              ),
              _section(
                HelpSection.folderSettings,
                title: 'Folder Settings (Settings > Account)',
                body:
                    'The Account tab configures two special folders per '
                    'account: the Safe Sender Folder and the Deleted Rule '
                    'Folder. Both are optional -- leaving them blank falls '
                    'back to provider defaults.\n\n'
                    '- Safe Sender Folder: destination for emails matched by '
                    'a safe-sender rule. Typically the same folder where you '
                    'already file "keep these" mail.\n'
                    '- Deleted Rule Folder: destination when a block rule\'s '
                    'action is "move to folder" rather than delete. Useful '
                    'for review-before-purge workflows.\n\n'
                    'Provider suggestions:\n'
                    '- Gmail: Safe -> INBOX (or a custom label like "Safe"); '
                    'Deleted -> "[Gmail]/Trash" (soft delete) or a custom '
                    'label like "Spam Candidates".\n'
                    '- AOL / Yahoo: Safe -> INBOX; Deleted -> "Bulk" or '
                    '"Spam" (both are recognized as junk folders).\n'
                    '- Outlook.com: Safe -> Inbox; Deleted -> "Junk Email" or '
                    '"Deleted Items".\n'
                    '- Generic IMAP: INBOX and Trash are nearly universal. '
                    'Use the Folder Selection screen to see the exact names '
                    'your server exposes.',
              ),
              _section(
                HelpSection.manualScanSettings,
                title: 'Manual Scan Settings (Settings > Manual Scan)',
                body:
                    'This tab sets defaults for manual (on-demand) scans. '
                    'Per-account overrides are applied when present; the app-'
                    'wide values shown here are the fallback.\n\n'
                    '- General: top-of-tab controls including scan-history '
                    'retention days (how long past scan results stay in the '
                    'database). Lower numbers save disk space; higher '
                    'numbers keep more audit trail.\n'
                    '- Scan Mode: read-only (dry run), rules-only, '
                    'safe-senders-only, or test-all. Read-only never modifies '
                    'email; the others mutate mail per matched actions.\n'
                    '- Scan Range: how many days back to read from each '
                    'folder. 1-3 days is typical for daily use; 7-30 days '
                    'for occasional cleanup.\n'
                    '- Default Folders: which folders to scan by default '
                    '(INBOX almost always, spam folders optional). The '
                    'folder picker reads the account\'s IMAP namespace.\n'
                    '- Confirmation: whether to show a "proceed?" dialog '
                    'before destructive scans. Off = faster loop, on = '
                    'safer when testing rules.\n'
                    '- Export Settings: where CSV exports are saved when you '
                    'tap the Download icon on a Results screen. Leaving the '
                    'path blank uses the OS Downloads folder.',
              ),
              _section(
                HelpSection.backgroundScanning,
                title: 'Background Scanning',
                body:
                    'Background Scanning runs the same rules engine as Manual '
                    'Scan, but on a schedule -- the app wakes up the Windows '
                    'Task Scheduler (or Android WorkManager) without an open '
                    'window. Scan mode, scan range, and default folders are '
                    'shared with Manual Scan (see that section).\n\n'
                    '- Enable: master on/off switch. Off removes the '
                    'scheduled task; on registers it with the OS scheduler. '
                    'Disabled by default on fresh installs.\n'
                    '- Test: runs the background pipeline once, immediately, '
                    'so you can verify the scheduler, credentials, and rules '
                    'all line up before trusting the scheduled run. Useful '
                    'after an upgrade or a config change.\n'
                    '- Frequency: how often the scheduled task fires (hourly, '
                    '4-hourly, daily, etc.). Daily with Scan Range = 1 day '
                    'is the most efficient continuous-monitoring setup.\n'
                    '- Debug (Export after each scan): typically off. When '
                    'on, every background run writes a per-run CSV next to '
                    'the scan log. Useful when diagnosing a rule that seems '
                    'to misfire or building an audit trail.',
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
              // Round 2 feedback: trailing filler so the ensureVisible call
              // can pin the LAST section to the top of the viewport. Without
              // this, ListView cannot scroll past its own content height and
              // the final sections end up mid-screen on deep-link.
              SizedBox(height: viewportHeight * 0.8),
            ],
          ),
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
