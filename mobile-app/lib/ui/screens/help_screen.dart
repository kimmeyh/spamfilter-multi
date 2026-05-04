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

import '../widgets/app_bar_with_exit.dart';
import 'scan_history_screen.dart';
import 'settings_screen.dart';

/// Anchors for each primary screen / settings-tab section in [HelpScreen].
enum HelpSection {
  selectAccount,
  accountSetup,
  demoScan,
  manualScan,
  resultsDisplay,
  scanHistory,
  settings,
  // Settings > General sub-sections (appear in tab-order below settings)
  generalRulesManagement,
  generalScanHistoryRetention,
  generalPrivacyLogging,
  // Settings > Account, Manual Scan, Background tab sections
  folderSettings,
  manualScanSettings,
  backgroundScanning,
  // Rule / safe-sender screens
  manageRules,
  ruleQuickAdd,
  ruleTest,
  safeSenders,
  folderSelection,
  yamlImportExport,
  // Sprint 37 Phase 7 Imp-2: terminal "see also" section pointing users to
  // outside-the-app channels for unwanted email/text/mail/calls.
  otherWaysToReduceJunk,
}

class HelpScreen extends StatefulWidget {
  /// Which section to scroll to on open. Null means "start from the top".
  final HelpSection? initialSection;

  /// Optional account context. When provided, the Help AppBar exposes the
  /// Scan History and Settings shortcuts (both require an accountId). When
  /// null (e.g. Help opened from the pre-account Select Email Provider
  /// screen), those shortcuts are omitted.
  final String? accountId;
  final String? accountEmail;
  final String? platformId;
  final String? platformDisplayName;

  const HelpScreen({
    super.key,
    this.initialSection,
    this.accountId,
    this.accountEmail,
    this.platformId,
    this.platformDisplayName,
  });

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
    final hasAccount = widget.accountId != null;
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Help'),
        // F55 (Sprint 33, round 3): Help screen gets the same icon row as
        // every other screen. Order: History, Accounts, Settings, [X auto].
        // History and Settings are account-scoped, so they only appear when
        // an accountId was threaded through openHelp().
        actions: [
          if (hasAccount)
            IconButton(
              tooltip: 'View Scan History',
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScanHistoryScreen(
                      accountId: widget.accountId!,
                      accountEmail: widget.accountEmail ?? widget.accountId!,
                      platformId: widget.platformId ?? '',
                      platformDisplayName:
                          widget.platformDisplayName ?? '',
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Select Account',
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          if (hasAccount)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(accountId: widget.accountId!),
                  ),
                );
              },
            ),
        ],
      ),
      // Round 2 feedback: wrap in Scrollbar with thumbVisibility: true so
      // the scroll position is always visible, not hover-only.
      //
      // Round 3 fix: switched from ListView (lazy-built) to
      // SingleChildScrollView + Column. ListView defers building offscreen
      // children until the scroll position reaches them, so GlobalKey
      // contexts for far-away sections return null during the post-frame
      // ensureVisible call and the scroll is a no-op. Column builds every
      // section up front, so every key is live and deep-links always work.
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'Four tabs, ordered: General, Account, Manual Scan, '
                      'Background. General holds app-wide options; Account '
                      'holds per-account overrides; Manual Scan and '
                      'Background set defaults for the two scan modes.\n\n'
                      'The Help icon on the Settings AppBar deep-links to '
                      'the section matching the currently visible tab, so '
                      'you always land on the relevant subsection below.',
                ),
                // --- Settings > General sub-sections (in on-screen order) ---
                _section(
                  HelpSection.generalRulesManagement,
                  title: 'General > Rules Management',
                  body:
                      'Top of the General tab. Shortcut buttons open the '
                      'screens for editing the active rule set:\n'
                      '- Manage Rules: browse / enable / disable / delete '
                      'every block rule.\n'
                      '- Manage Safe Senders: browse the safe-sender '
                      'whitelist (bypasses all block rules).\n'
                      '- YAML Import / Export: back up or replace the entire '
                      'rule set from a YAML file. Useful for sharing rules '
                      'across devices or restoring after a reset.\n'
                      '- Reset to Defaults: re-seeds the bundled rules.yaml '
                      'and rules_safe_senders.yaml, overwriting any edits. '
                      'Irreversible unless you export first.',
                ),
                _section(
                  HelpSection.generalScanHistoryRetention,
                  title: 'General > Scan History',
                  body:
                      '"Keep Scan History for" controls how many days of '
                      'past scan results are kept in the local database. '
                      'Older entries are pruned automatically at the end of '
                      'every scan. Lower numbers save disk space; higher '
                      'numbers preserve more audit history for later review '
                      'on the Scan History screen.\n\n'
                      'The "Go to View Scan History" button is a shortcut '
                      'to the Scan History screen from this tab.',
                ),
                _section(
                  HelpSection.generalPrivacyLogging,
                  title: 'General > Privacy & Logging',
                  body:
                      'Three switches plus a retention picker that control '
                      'what the app logs and stores on disk:\n'
                      '- Disable detailed auth logging: when on, debug-only '
                      'authentication log lines (redacted tokens, account '
                      'IDs) are suppressed. Errors and warnings still log. '
                      'Turn off only to diagnose sign-in issues.\n'
                      '- Unmatched Emails Retention: how many days to keep '
                      'the pool of "emails that matched no rule" used by '
                      'Rule Test / Rule Quick Add. 0 disables retention; '
                      '30-90 days is a typical sweet spot.\n'
                      '- Pin Google OAuth certificates: rejects TLS '
                      'connections to Google sign-in endpoints that do not '
                      'match the pinned SPKI hashes. Turn off only after a '
                      'Google CA rotation causes sign-in failures.\n'
                      '- Encrypt database (experimental): provisions a '
                      '256-bit key in the system keychain for future '
                      'SQLCipher-backed encryption. The database itself is '
                      'not yet encrypted -- the key is stored early so the '
                      'later driver-swap release can migrate in place.\n\n'
                      'The red "Delete All App Data" button wipes every '
                      'account, credential, rule, scan result, and setting. '
                      'Two-step confirmation required; no undo.',
                ),
                // --- Settings > Account, Manual Scan, Background tabs ---
                _section(
                  HelpSection.folderSettings,
                  title: 'Account > Folder Settings',
                  body:
                      'The Account tab configures two special folders per '
                      'account: the Safe Sender Folder and the Deleted Rule '
                      'Folder. Both are optional -- leaving them blank falls '
                      'back to provider defaults.\n\n'
                      '- Safe Sender Folder: destination for emails matched '
                      'by a safe-sender rule. Typically the same folder '
                      'where you already file "keep these" mail.\n'
                      '- Deleted Rule Folder: destination when a block '
                      'rule\'s action is "move to folder" rather than '
                      'delete. Useful for review-before-purge workflows.\n\n'
                      'Provider suggestions:\n'
                      '- Gmail: Safe -> INBOX (or a custom label like '
                      '"Safe"); Deleted -> "[Gmail]/Trash" (soft delete) or '
                      'a custom label like "Spam Candidates".\n'
                      '- AOL / Yahoo: Safe -> INBOX; Deleted -> "Bulk" or '
                      '"Spam" (both are recognized as junk folders).\n'
                      '- Outlook.com: Safe -> Inbox; Deleted -> "Junk Email" '
                      'or "Deleted Items".\n'
                      '- Generic IMAP: INBOX and Trash are nearly universal. '
                      'Use the Folder Selection screen to see the exact '
                      'names your server exposes.',
                ),
                _section(
                  HelpSection.manualScanSettings,
                  title: 'Manual Scan Settings',
                  body:
                      'The Manual Scan tab sets defaults for manual '
                      '(on-demand) scans. Per-account overrides apply when '
                      'present; the app-wide values shown here are the '
                      'fallback. Background scans use the same inputs '
                      '(see Background Scanning).\n\n'
                      '- General: top-of-tab controls including '
                      'scan-history retention days (duplicated here and on '
                      'General for convenience).\n'
                      '- Scan Mode: read-only (dry run), rules-only, '
                      'safe-senders-only, or test-all. Read-only never '
                      'modifies email; the others mutate mail per matched '
                      'actions.\n'
                      '- Scan Range: how many days back to read from each '
                      'folder. 1-3 days is typical for daily use; 7-30 days '
                      'for occasional cleanup.\n'
                      '- Default Folders: which folders to scan by default '
                      '(INBOX almost always, spam folders optional). The '
                      'folder picker reads the account\'s IMAP namespace.\n'
                      '- Confirmation: whether to show a "proceed?" dialog '
                      'before destructive scans. Off = faster loop, on = '
                      'safer when testing rules.\n'
                      '- Export Settings: where CSV exports are saved when '
                      'you tap the Download icon on a Results screen. '
                      'Leaving the path blank uses the OS Downloads folder.',
                ),
                _section(
                  HelpSection.backgroundScanning,
                  title: 'Background Scanning',
                  body:
                      'Background Scanning runs the same rules engine as '
                      'Manual Scan, but on a schedule -- the app wakes up '
                      'the Windows Task Scheduler (or Android WorkManager) '
                      'without an open window. Scan Mode, Scan Range, and '
                      'Default Folders are shared with Manual Scan (see '
                      'that section above).\n\n'
                      '- Enable: master on/off switch. Off removes the '
                      'scheduled task; on registers it with the OS '
                      'scheduler. Disabled by default on fresh installs.\n'
                      '- Test: runs the background pipeline once, '
                      'immediately, so you can verify the scheduler, '
                      'credentials, and rules all line up before trusting '
                      'the scheduled run. Useful after an upgrade or a '
                      'config change.\n'
                      '- Frequency: how often the scheduled task fires '
                      '(hourly, 4-hourly, daily, etc.). Daily with Scan '
                      'Range = 1 day is the most efficient continuous-'
                      'monitoring setup.\n'
                      '- Debug (Export after each scan): typically off. '
                      'When on, every background run writes a per-run CSV '
                      'next to the scan log. Useful when diagnosing a rule '
                      'that seems to misfire or building an audit trail.',
                ),
                _section(
                  HelpSection.manageRules,
                  title: 'Manage Rules',
                  body:
                      'Browse and edit every spam rule the scanner will '
                      'apply. Each rule has an execution order, one or more '
                      'condition buckets (from / header / subject / body), '
                      'and an action (delete / move / categorize). Use the '
                      'filter bar to narrow by pattern category or '
                      'subtype.\n\n'
                      'Patterns that match ReDoS heuristics '
                      '(catastrophic-backtracking regex) are rejected when '
                      'you save; this prevents scanner hangs. Rewrite the '
                      'pattern or simplify its quantifiers to save.',
                ),
                _section(
                  HelpSection.ruleQuickAdd,
                  title: 'Rule Quick Add',
                  body:
                      'Streamlined flow for creating a block rule from a '
                      'sample email. Pick the condition bucket(s) that '
                      'should match, the action to take, and the execution '
                      'order. Conflict detection warns if a new rule '
                      'overlaps or contradicts existing ones; use "Test '
                      'pattern" (flask icon) to preview matches against '
                      'your recent unmatched emails.',
                ),
                _section(
                  HelpSection.ruleTest,
                  title: 'Rule Test',
                  body:
                      'Previews how a pattern would match against the '
                      'current unmatched-email pool. Useful when drafting a '
                      'new rule before committing. Matches highlight the '
                      'portion of the email (from / header / subject / '
                      'body) the regex hit.',
                ),
                _section(
                  HelpSection.safeSenders,
                  title: 'Manage Safe Senders',
                  body:
                      'Safe senders bypass all rules. Entries are regex '
                      'patterns matched against the full sender string. '
                      'Common shapes:\n'
                      '- Exact email: ^user@example\\.com\$\n'
                      '- Domain + subdomains: ^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com\$\n\n'
                      'Ordering does not matter; safe senders are checked '
                      'before any block rule. ReDoS-vulnerable patterns are '
                      'rejected on save.',
                ),
                _section(
                  HelpSection.folderSelection,
                  title: 'Folder Selection',
                  body:
                      'Pick which folders the scanner reads. Most providers '
                      'list INBOX plus a spam folder (Bulk, Junk, Spam, '
                      'etc.); select only the folders you want acted on. '
                      'The move-to folder for block rules is configured in '
                      'Settings > Account.',
                ),
                _section(
                  HelpSection.yamlImportExport,
                  title: 'YAML Import / Export',
                  body:
                      'Back up or share rule sets via YAML files. Export '
                      'writes rules.yaml and rules_safe_senders.yaml to a '
                      'timestamped directory. Import merges entries from a '
                      'YAML file into the current database; existing '
                      'patterns are skipped (idempotent). Import files are '
                      'capped at 10 MB and parsed with ReDoS detection -- '
                      'dangerous patterns are rejected at parse time.',
                ),
                _section(
                  HelpSection.otherWaysToReduceJunk,
                  title:
                      'Other ways to reduce junk email, mail, texts, and phone calls',
                  body:
                      'This app filters mail in your inbox. The unwanted '
                      'messages you receive at all also have official '
                      'reporting and opt-out channels run by the FTC, FCC, '
                      'major carriers, and direct-mail trade groups. Using '
                      'them in addition to (not instead of) this app reduces '
                      'the volume that ever reaches your inbox in the first '
                      'place.\n\n'
                      'Unwanted emails:\n'
                      '- Mark obvious spam as "Junk" or "Spam" in your '
                      'provider (Gmail, Outlook.com, AOL, Yahoo). This '
                      'trains your provider\'s filter and demotes the '
                      'sender for everyone.\n'
                      '- Do not click links or open attachments in spam; '
                      'doing so confirms the address is live and increases '
                      'volume.\n'
                      '- Forward phishing email to '
                      'reportphishing@apwg.org (Anti-Phishing Working '
                      'Group) and to the impersonated brand\'s abuse '
                      'address.\n'
                      '- Report scams (not just spam) to the FTC at '
                      'ReportFraud.ftc.gov.\n'
                      '- See: '
                      'consumer.ftc.gov/unwanted-calls-emails-and-texts/'
                      'unwanted-emails-texts-and-mail\n'
                      '- Use the "Unsubscribe" link ONLY for senders you '
                      'recognize as well-known, reputable companies '
                      '(roughly Fortune 1000 / household-name brands). '
                      'Although CAN-SPAM technically requires legitimate '
                      'U.S. senders to honor unsubscribe requests within '
                      '10 business days, less-reputable list operators '
                      'often turn an unsubscribe click into proof that '
                      'your address is monitored and respond, then sell '
                      'it to other lists at a premium. For unknown or '
                      'shady senders, mark as Junk/Spam (above) instead '
                      'of unsubscribing.\n\n'
                      'Unwanted texts:\n'
                      '- Forward the spam text to 7726 (which spells '
                      '"SPAM"). All major U.S. carriers accept reports at '
                      'this short code free of charge; they use the '
                      'reports to identify and block sending numbers.\n'
                      '- Use your phone\'s built-in "Block this number" / '
                      '"Report Junk" option (iOS Messages and Google '
                      'Messages both have one-tap reporting).\n'
                      '- Report scam texts to the FTC at '
                      'ReportFraud.ftc.gov.\n'
                      '- Do not reply -- not even with "STOP" -- to texts '
                      'from unknown senders. Replying confirms a live '
                      'number to spammers. Use carrier or device blocking '
                      'instead.\n'
                      '- See: '
                      'consumer.ftc.gov/unwanted-calls-emails-and-texts/'
                      'unwanted-emails-texts-and-mail\n\n'
                      'Unwanted postal mail:\n'
                      '- Opt out of pre-screened credit and insurance '
                      'offers at OptOutPrescreen.com (the official site '
                      'authorized by the major credit bureaus). You can '
                      'opt out for 5 years online or for life by mailing '
                      'a signed form. Phone: 1-888-5-OPTOUT '
                      '(1-888-567-8688).\n'
                      '- Opt out of marketing mail from the Direct '
                      'Marketing Association at DMAchoice.org. Small '
                      'one-time fee; reduces national-list mailings for '
                      '10 years.\n'
                      '- For mail addressed to a previous resident, write '
                      '"Not at this address" on the unopened envelope and '
                      'put it back in the mailbox.\n'
                      '- AVOID contacting individual mail-order catalogs '
                      'directly to be removed -- the act of contacting '
                      'them is often interpreted as confirmation that '
                      'your address is actively monitored, after which '
                      'your details get sold to other catalog list '
                      'brokers. Use the DMAchoice.org bulk opt-out above '
                      'instead, which removes you from the upstream '
                      'list-rental marketplace that most catalogs draw '
                      'from.\n'
                      '- See: '
                      'consumer.ftc.gov/unwanted-calls-emails-and-texts/'
                      'unwanted-emails-texts-and-mail\n\n'
                      'Unwanted phone calls:\n'
                      '- Register your phone number on the National Do '
                      'Not Call Registry at DoNotCall.gov, or by calling '
                      '1-888-382-1222 from the phone you want to '
                      'register. Free; registration is permanent until '
                      'you remove the number.\n'
                      '- Note what the registry does NOT cover: political '
                      'calls, charities, debt collectors, surveys, and '
                      'companies you have a recent business relationship '
                      'with are all exempt.\n'
                      '- After 31 days on the registry, report unwanted '
                      'sales calls and most robocalls at DoNotCall.gov '
                      '(or 1-888-382-1222).\n'
                      '- Use your phone\'s "Silence Unknown Callers" '
                      'feature (iOS) or "Filter spam calls" (Google '
                      'Phone) to send unrecognized callers straight to '
                      'voicemail.\n'
                      '- Most U.S. carriers offer a free spam-call '
                      'blocking service: Verizon Call Filter, AT&T '
                      'ActiveArmor, T-Mobile Scam Shield. Enable it from '
                      'your carrier account or app.\n'
                      '- Report scam and robocall violations to the FTC '
                      'at ReportFraud.ftc.gov and to the FCC at '
                      'fcc.gov/consumers/guides/stop-unwanted-robocalls-'
                      'and-texts.\n'
                      '- See: DoNotCall.gov',
                ),
                const SizedBox(height: 24),
                Text(
                  'Last updated: Sprint 37 (May 2026). Report issues at '
                  'github.com/kimmeyh/spamfilter-multi/issues.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                // Trailing filler so Scrollable.ensureVisible can always
                // pin the target section to the TOP of the viewport, even
                // when the target is the last real section. Without this,
                // the scroll view cannot offset past its own content height
                // and late sections end up mid-screen.
                SizedBox(height: viewportHeight * 0.8),
              ],
            ),
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
/// without duplicating the MaterialPageRoute boilerplate. When [accountId]
/// is provided, the Help screen's AppBar also renders the Scan History and
/// Settings shortcuts (both require an account context).
void openHelp(
  BuildContext context,
  HelpSection section, {
  String? accountId,
  String? accountEmail,
  String? platformId,
  String? platformDisplayName,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HelpScreen(
        initialSection: section,
        accountId: accountId,
        accountEmail: accountEmail,
        platformId: platformId,
        platformDisplayName: platformDisplayName,
      ),
    ),
  );
}
