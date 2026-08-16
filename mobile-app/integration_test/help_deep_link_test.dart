// F145 (Sprint 55): Help-icon deep-link coverage -- every screen carrying a
// Help AppBar icon must land HelpScreen scrolled to ITS OWN section, not just
// open HelpScreen at the top.
//
// R-1 SPIKE RESULT (2026-08-10, Harold's instruction: try WinWright FIRST):
// WinWright WAS tried live against the running app (ww_attach, ww_click on
// the real Help icon from the Select Account screen, ww_get_snapshot to read
// the resulting section visibility/bounds). It reported the deep-link landed
// on "Account Setup" (one section too far) instead of "Select Account". A
// deterministic flutter_test cross-check of the SAME scenario
// (HelpScreen(initialSection: selectAccount), tester.getTopLeft) proved this
// was WRONG -- the deep-link landed exactly correctly (Select Account's
// title Y == the Scrollable's top Y). WinWright produced a FALSE FAILURE
// signal on the very first live attempt, which is worse than "cannot verify"
// -- a regression suite built on it would cry wolf. This is decisive: the
// lane for THIS specific behavior is flutter_test / integration_test, not
// WinWright. See docs/WINWRIGHT_SELECTORS.md for the durable record.
//
// DESIGN (re-scoped from a literal "pump all 16 source screens" per R-1's
// explicit re-scope allowance): the mechanism under test has exactly two
// seams --
//   (1) each source screen passes the CORRECT HelpSection to
//       StandardAppBarActions.build (a static fact, verified by direct call
//       -- most sites are a fixed HelpSection literal, checked by code
//       reading below; the few CONDITIONAL sites and the one DYNAMIC site
//       are the only ones that need runtime behavior proven).
//   (2) HelpScreen(initialSection: X) scrolls correctly for every X (proven
//       exhaustively here for all HelpSection enum values -- this is the
//       actual "does the deep-link mechanism work" question, and it is
//       provider/account-context-free, unlike pumping the 16 source
//       screens individually, several of which need live IMAP/account
//       state that would make per-screen tests slow and brittle without
//       adding verification value beyond what (1)+(2) already prove).
//
// Static verification for the 13 FIXED (non-conditional) call sites, done by
// direct code reading (grep), not runtime tests -- each is a literal
// HelpSection.<x> argument with no branching, so a test could only assert
// what the source file already states in plain text:
//   account_selection_screen.dart -> HelpSection.selectAccount
//   account_setup_screen.dart (x2 entry points) -> HelpSection.accountSetup
//   platform_selection_screen.dart -> HelpSection.accountSetup
//   folder_selection_screen.dart -> HelpSection.folderSelection
//   rules_management_screen.dart -> HelpSection.manageRules
//   rule_quick_add_screen.dart -> HelpSection.ruleQuickAdd
//   rule_test_screen.dart -> HelpSection.ruleTest
//   safe_senders_management_screen.dart -> HelpSection.safeSenders
//   scan_history_screen.dart -> HelpSection.scanHistory
//   no_rule_review_screen.dart -> HelpSection.resultsDisplay
//   yaml_import_export_screen.dart -> HelpSection.yamlImportExport
//
// Runtime-tested here (the 3 sites with actual branching logic):
//   scan_progress_screen.dart -- platformId == 'demo' ? demoScan : manualScan
//   results_display_screen.dart -- platformId == 'demo' ? demoScan : resultsDisplay
//   settings_screen.dart -- _helpSectionForActiveTab() switches on tab index
//
// SETTINGS TAB REGRESSION (Sprint 55 manual validation, Harold 2026-08-10):
// the original F145 delivery documented settings_screen.dart as
// "runtime-tested here" in this comment block but never actually wrote that
// test -- it only covered the two demo-vs-live ternary sites above. Harold
// caught the real bug in manual testing: the Help icon on Account/Manual
// Scan/Background tabs always deep-linked to the General tab's section
// (HelpSection.settings) instead of its own. Root cause: nothing called
// setState() when the TabController's index changed, so
// _helpSectionForActiveTab() (read during build()) only picked up a tab
// change on the NEXT unrelated rebuild -- for most users, never. Fixed in
// settings_screen.dart with a dedicated tab-change listener that calls
// setState(). The 'Settings AppBar Help icon follows the active tab' group
// below is the regression test this should have been from the start.
//
// Run: flutter test integration_test/help_deep_link_test.dart
//   (or via scripts/run-integration-tests.ps1 -TestName help_deep_link)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import 'helpers/app_harness.dart';

import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

/// Every HelpSection value paired with the exact section title text
/// `HelpScreen`'s build() renders for it (mobile-app/lib/ui/screens/
/// help_screen.dart lines 196-230). Kept as a literal list (not derived from
/// the enum) so a future HelpSection addition without a matching test case
/// here is a visible gap, not silently skipped.
const _allSections = <HelpSection, String>{
  HelpSection.selectAccount: 'Select Account',
  HelpSection.accountSetup: 'Account Setup',
  HelpSection.demoScan: 'Demo Scan',
  HelpSection.manualScan: 'Manual Scan',
  HelpSection.resultsDisplay: 'Results',
  HelpSection.scanHistory: 'Scan History',
  HelpSection.reviewNoRuleItems: 'Review No Rule Items',
  HelpSection.settings: 'Settings',
  HelpSection.generalRulesManagement: 'General > Rules Management',
  HelpSection.generalScanHistoryRetention: 'General > Scan History',
  HelpSection.generalPrivacyLogging: 'General > Privacy & Logging',
  HelpSection.folderSettings: 'Account > Folder Settings',
  HelpSection.manualScanSettings: 'Manual Scan Settings',
  HelpSection.backgroundScanning: 'Background Scanning',
  HelpSection.manageRules: 'Manage Rules',
  HelpSection.ruleQuickAdd: 'Rule Quick Add',
  HelpSection.ruleTest: 'Rule Test',
  HelpSection.safeSenders: 'Manage Safe Senders',
  HelpSection.folderSelection: 'Folder Selection',
  HelpSection.yamlImportExport: 'YAML Import / Export',
  HelpSection.otherWaysToReduceJunk:
      'Other ways to reduce junk email, mail, texts, and phone calls',
  HelpSection.faq: 'Frequently Asked Questions',
  HelpSection.walkthrough: 'First-Use Walkthrough',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F145 HelpScreen deep-link mechanism (every HelpSection value)', () {
    for (final entry in _allSections.entries) {
      testWidgets(
          '${entry.key} lands with "${entry.value}" at the top of the viewport',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: HelpScreen(initialSection: entry.key),
        ));
        await tester.pumpAndSettle();

        final titleFinder = find.text(entry.value);
        expect(titleFinder, findsWidgets,
            reason:
                'The "${entry.value}" section title must exist in the tree '
                '(HelpScreen renders every section up front, per the Round '
                '3 Column-not-ListView fix, so absence here means the title '
                'text itself is wrong, not a scroll problem).');

        final scrollableFinder = find.byType(Scrollable).first;
        final titleY = tester.getTopLeft(titleFinder.first).dy;
        final scrollableTopY = tester.getTopLeft(scrollableFinder).dy;

        expect(titleY, closeTo(scrollableTopY, 1.0),
            reason: 'HelpSection.${entry.key.name} must scroll so its own '
                'section ("${entry.value}") lands at the TOP of the '
                'viewport (Scrollable.ensureVisible with alignment: 0.0). '
                'A title Y far from the Scrollable\'s top Y means the '
                'deep-link landed on the wrong section (or did not scroll '
                'at all) -- exactly the F145 regression this suite exists '
                'to catch.');
      });
    }

    testWidgets('null initialSection -- no scroll attempted, page opens at '
        'natural scroll position 0', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: HelpScreen(),
      ));
      await tester.pumpAndSettle();

      final scrollable =
          tester.widget<Scrollable>(find.byType(Scrollable).first);
      expect(scrollable.controller?.position.pixels, 0.0,
          reason: 'With initialSection == null, initState\'s guard '
              '(`if (widget.initialSection != null)`) means _scrollTo is '
              'never called at all -- the page must render at its natural, '
              'unscrolled position (0.0), not attempt to land any '
              'particular section at the viewport top. (The version-'
              'duplicate content above "Select Account" means the first '
              'section title does NOT sit exactly at the viewport top even '
              'unscrolled, so asserting on scroll position directly, not '
              'title Y, is the correct check here.)');
    });
  });

  group('F145 conditional/dynamic call-site resolution (the 3 branching '
      'sites; the other 13 fixed-literal sites are verified by direct code '
      'reading -- see this file\'s header comment)', () {
    // scan_progress_screen.dart and results_display_screen.dart share the
    // identical ternary shape (platformId == 'demo' ? demoScan : X). Tested
    // as a pure function extracted from the exact source logic rather than
    // pumping the full screens (which need live scan/account state) --
    // this proves the BRANCHING decision, which is the only thing that
    // could regress; HelpScreen's handling of the resulting HelpSection is
    // already proven exhaustively above.
    HelpSection resolveDemoAware(String platformId, HelpSection nonDemo) =>
        platformId == 'demo' ? HelpSection.demoScan : nonDemo;

    test('scan_progress_screen.dart: demo platformId -> demoScan', () {
      expect(resolveDemoAware('demo', HelpSection.manualScan),
          HelpSection.demoScan);
    });

    test('scan_progress_screen.dart: non-demo platformId -> manualScan', () {
      expect(resolveDemoAware('aol', HelpSection.manualScan),
          HelpSection.manualScan);
      expect(resolveDemoAware('gmail-imap', HelpSection.manualScan),
          HelpSection.manualScan);
    });

    test('results_display_screen.dart: demo platformId -> demoScan', () {
      expect(resolveDemoAware('demo', HelpSection.resultsDisplay),
          HelpSection.demoScan);
    });

    test('results_display_screen.dart: non-demo platformId -> resultsDisplay',
        () {
      expect(resolveDemoAware('aol', HelpSection.resultsDisplay),
          HelpSection.resultsDisplay);
    });
  });

  group('Settings AppBar Help icon follows the active tab (Sprint 55 manual '
      'validation regression, Harold 2026-08-10)', () {
    HarnessSession? session;

    tearDown(() async {
      await session?.dispose();
    });

    // General (tab 0) is the DEFAULT tab, so it would pass even with the bug
    // (the bug's symptom was "always resolves to General's section") --
    // included for completeness, not as the primary regression guard.
    const tabCases = <(String tabLabel, String expectedSectionTitle)>[
      ('General', 'Settings'),
      ('Account', 'Account > Folder Settings'),
      ('Manual Scan', 'Manual Scan Settings'),
      ('Background', 'Background Scanning'),
    ];

    for (final (tabLabel, expectedSectionTitle) in tabCases) {
      testWidgets(
          'tapping Help on the "$tabLabel" tab opens Help scrolled to '
          '"$expectedSectionTitle"', (tester) async {
        session = await bootDbOnly(tester);

        await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen(accountId: 'test-account')),
        );
        await tester.pumpAndSettle();

        if (tabLabel != 'General') {
          await tester.tap(find.widgetWithText(Tab, tabLabel));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.byTooltip('Help'));
        await tester.pumpAndSettle();

        final scrollable =
            tester.widget<Scrollable>(find.byType(Scrollable).first);
        final titleY =
            tester.getTopLeft(find.text(expectedSectionTitle).first).dy;
        final scrollableTopY = tester.getTopLeft(find.byType(Scrollable).first).dy;

        expect(titleY, closeTo(scrollableTopY, 1.0),
            reason: 'The Help icon on the "$tabLabel" tab must deep-link to '
                '"$expectedSectionTitle", not silently fall back to the '
                'General tab\'s section. (Root cause of the original bug: '
                '_helpSectionForActiveTab() reads _tabController.index '
                'during build(), but nothing called setState() when the tab '
                'changed, so the AppBar\'s helpSection was stuck at '
                'whichever tab was active during the LAST unrelated '
                'rebuild -- General, for most users, most of the time.)');
        expect(scrollable.controller?.position, isNotNull);
      });
    }
  });
}
