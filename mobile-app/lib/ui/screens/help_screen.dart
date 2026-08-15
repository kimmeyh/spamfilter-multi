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
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/app_environment.dart';
import '../../core/services/content_loader.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/standard_app_bar_actions.dart';

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
  // Sprint 39 F74: frequently-asked-questions section. General concept and
  // privacy questions (TLDs, the IANA list, rule types, safe senders, scan
  // skips, ReDoS, data storage, rule import/export) that are not tied to one
  // screen. Rendered last so screen-anchored sections appear first.
  faq,
  // Sprint 40 F75: first-use walkthrough section. Step-by-step guide covering
  // install and sign-in, demo scan, read-only manual scan, safe senders and
  // rules tuning, daily background scanning, and ongoing no-rule processing.
  // Rendered after FAQ so all general sections appear at the end.
  walkthrough,
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

  /// F145 (Sprint 55): every section's body loads via an async
  /// `FutureBuilder<String>` (`ContentLoader().load`). Even when the
  /// underlying asset read is effectively synchronous, the `Future` still
  /// completes on a LATER frame than the one `initState`'s
  /// `addPostFrameCallback` fires on -- so the FIRST `_scrollTo` call
  /// computes its target offset while every PRECEDING section is still
  /// showing its short loading placeholder (`SizedBox(height: 14)`) instead
  /// of its real (often much taller) rendered content. The computed scroll
  /// distance is then too short by the sum of all not-yet-loaded preceding
  /// sections' height deltas -- worse the further down the page the target
  /// section is (confirmed via `integration_test`: a section 3 places down
  /// landed ~168px short of the viewport top, growing roughly linearly with
  /// position). Retrying once more after content has had a frame to settle
  /// corrects this without changing the FutureBuilder/ContentLoader design.
  int _scrollRetriesRemaining = 2;

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
    // F145: schedule a follow-up scroll for the next frame so a second pass
    // corrects the position once any preceding sections' async content has
    // resolved and the Column has grown to its real height. Bounded to 2
    // retries: the placeholder-to-content transition settles within one or
    // two frames once the (in-memory-cached after first load) ContentLoader
    // future completes; an unbounded retry loop would risk fighting a user
    // who starts manually scrolling immediately after the screen opens.
    if (_scrollRetriesRemaining > 0) {
      _scrollRetriesRemaining--;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollTo(section);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.of(context).size.height;
    final hasAccount = widget.accountId != null;
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Help'),
        // F134 (Sprint 52): canonical order via the ONE shared builder.
        // includeHelp: false -- this IS the Help screen.
        // History and Settings stay account-scoped: passing a null accountId
        // makes the builder omit Settings, and includeScanHistory follows
        // hasAccount, preserving the previous conditional behavior exactly.
        actions: StandardAppBarActions.build(
          context: context,
          helpSection: HelpSection.settings, // unused -- includeHelp is false
          accountId: hasAccount ? widget.accountId : null,
          accountEmail: widget.accountEmail ?? widget.accountId,
          platformId: widget.platformId ?? '',
          platformDisplayName: widget.platformDisplayName ?? '',
          includeNoRuleReview: false,
          includeScanHistory: hasAccount,
          includeHelp: false,
        ),
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
                // F140 (Sprint 54): duplicated near the top so the version is
                // visible without scrolling -- the full footer (with the
                // issue-tracker link) stays at the bottom of this page.
                // Neither a human tester nor WinWright/UIA automation could
                // reach the bottom-of-page footer without scrolling, and no
                // working scroll mechanism was found (see
                // docs/WINWRIGHT_SELECTORS.md).
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? snapshot.data!.version
                        : '...';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Version $version${AppEnvironment.displaySuffix}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    );
                  },
                ),
                // F151b (Sprint 58): "First time? Start here" callout, near
                // the top so it is visible without scrolling -- closes the
                // gap F75 (Sprint 34) explicitly deferred. The walkthrough
                // section itself stays last (line ~259) so screen-anchored
                // reference sections are not pushed down for readers who
                // already know the app; this callout is the discoverable
                // shortcut for first-time users instead.
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.explore_outlined),
                    title: const Text('First time? Start here'),
                    subtitle: const Text(
                        'Jump to the step-by-step walkthrough for getting started.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _scrollTo(HelpSection.walkthrough),
                  ),
                ),
                const SizedBox(height: 16),
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
                _section(HelpSection.faq,
                    title: 'Frequently Asked Questions'),
                _section(HelpSection.walkthrough,
                    title: 'First-Use Walkthrough'),
                const SizedBox(height: 24),
                // F117 (Sprint 47): show the app version from the compiled
                // package (package_info_plus) instead of a hardcoded sprint #,
                // which drifted stale every sprint. Always accurate, zero
                // manual upkeep. Falls back to no version string if the
                // platform channel is unavailable.
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'Version ${snapshot.data!.version}${AppEnvironment.displaySuffix}. '
                        : '';
                    return Text(
                      '${version}Report issues at '
                      'github.com/kimmeyh/spamfilter-multi/issues.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    );
                  },
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
      case HelpSection.faq:
        return 'faq';
      case HelpSection.walkthrough:
        return 'walkthrough';
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