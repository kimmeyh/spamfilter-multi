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

import '../../core/services/content_loader.dart';
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
                // Sprint 38 F85 (ADR-0038): all section bodies now load
                // from `assets/content/help/*.md` via the asset manifest.
                // Titles remain inline because they are short labels, not
                // content. Adding a new section: declare the HelpSection
                // enum case, add an entry to assets/content/manifest.yaml,
                // and write the corresponding .md file. The validator at
                // scripts/validate-content-manifest.ps1 enforces drift.
                _section(HelpSection.selectAccount, title: 'Select Account'),
                _section(HelpSection.accountSetup, title: 'Account Setup'),
                _section(HelpSection.demoScan, title: 'Demo Scan'),
                _section(HelpSection.manualScan, title: 'Manual Scan'),
                _section(HelpSection.resultsDisplay, title: 'Results'),
                _section(HelpSection.scanHistory, title: 'Scan History'),
                _section(HelpSection.settings, title: 'Settings'),
                // --- Settings > General sub-sections (in on-screen order) ---
                _section(HelpSection.generalRulesManagement,
                    title: 'General > Rules Management'),
                _section(HelpSection.generalScanHistoryRetention,
                    title: 'General > Scan History'),
                _section(HelpSection.generalPrivacyLogging,
                    title: 'General > Privacy & Logging'),
                // --- Settings > Account, Manual Scan, Background tabs ---
                _section(HelpSection.folderSettings,
                    title: 'Account > Folder Settings'),
                _section(HelpSection.manualScanSettings,
                    title: 'Manual Scan Settings'),
                _section(HelpSection.backgroundScanning,
                    title: 'Background Scanning'),
                _section(HelpSection.manageRules, title: 'Manage Rules'),
                _section(HelpSection.ruleQuickAdd, title: 'Rule Quick Add'),
                _section(HelpSection.ruleTest, title: 'Rule Test'),
                _section(HelpSection.safeSenders, title: 'Manage Safe Senders'),
                _section(HelpSection.folderSelection, title: 'Folder Selection'),
                _section(HelpSection.yamlImportExport,
                    title: 'YAML Import / Export'),
                _section(HelpSection.otherWaysToReduceJunk,
                    title:
                        'Other ways to reduce junk email, mail, texts, and phone calls'),
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

  /// Sprint 38 F85 (ADR-0038): each section's body now loads from
  /// `assets/content/help/*.md` via the asset manifest. The title remains
  /// inline because titles are short labels, not content. The previous
  /// inline-body API (`body: 'long string ...'`) is preserved for sections
  /// the migration intentionally left inline (none, at present).
  Widget _section(HelpSection section,
      {required String title, String? body}) {
    final manifestKey = _manifestKeyFor(section);
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
          if (body != null)
            // Fallback path: caller passed an inline body. Used only by
            // sections that intentionally opt out of asset extraction
            // (none today; left in place so future short-body callers
            // can pass inline strings without forcing an asset file).
            Text(body, style: const TextStyle(fontSize: 14, height: 1.4))
          else
            FutureBuilder<String>(
              future: ContentLoader().load('help', manifestKey),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.data!,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'Content unavailable: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.red.shade700,
                    ),
                  );
                }
                // Brief loading state -- not visible in practice because
                // the asset bundle resolves synchronously on Windows and
                // the FutureBuilder pumps the data frame immediately.
                return const SizedBox(
                  height: 14,
                  child: LinearProgressIndicator(minHeight: 1),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Sprint 38 F85: map HelpSection enum to its manifest key. Kept as an
  /// explicit switch (rather than .name) so a future rename of a HelpSection
  /// case does not silently break the asset lookup -- the compiler will
  /// flag the missing case.
  String _manifestKeyFor(HelpSection section) {
    switch (section) {
      case HelpSection.selectAccount:
        return 'selectAccount';
      case HelpSection.accountSetup:
        return 'accountSetup';
      case HelpSection.demoScan:
        return 'demoScan';
      case HelpSection.manualScan:
        return 'manualScan';
      case HelpSection.resultsDisplay:
        return 'resultsDisplay';
      case HelpSection.scanHistory:
        return 'scanHistory';
      case HelpSection.settings:
        return 'settings';
      case HelpSection.generalRulesManagement:
        return 'generalRulesManagement';
      case HelpSection.generalScanHistoryRetention:
        return 'generalScanHistoryRetention';
      case HelpSection.generalPrivacyLogging:
        return 'generalPrivacyLogging';
      case HelpSection.folderSettings:
        return 'folderSettings';
      case HelpSection.manualScanSettings:
        return 'manualScanSettings';
      case HelpSection.backgroundScanning:
        return 'backgroundScanning';
      case HelpSection.manageRules:
        return 'manageRules';
      case HelpSection.ruleQuickAdd:
        return 'ruleQuickAdd';
      case HelpSection.ruleTest:
        return 'ruleTest';
      case HelpSection.safeSenders:
        return 'safeSenders';
      case HelpSection.folderSelection:
        return 'folderSelection';
      case HelpSection.yamlImportExport:
        return 'yamlImportExport';
      case HelpSection.otherWaysToReduceJunk:
        return 'otherWaysToReduceJunk';
    }
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
