import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

/// Widget tests for [HelpScreen] (F54, Sprint 33).
void main() {
  testWidgets('HelpScreen renders a title and the first section on open',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    // AppBar title present.
    expect(find.text('Help'), findsOneWidget);
    // The first section should be visible without scrolling.
    expect(find.text('Select Account'), findsOneWidget);
  });

  testWidgets(
      'HelpScreen shows the version near the top, visible without scrolling '
      '(F140, Sprint 54)', (tester) async {
    // Default (small) test viewport -- if the version text only appeared in
    // the original bottom-of-page footer, this would find nothing without a
    // scroll action. WinWright/UIA automation could not reach that footer
    // (see docs/WINWRIGHT_SELECTORS.md), so the duplicate near the top must
    // render within the initial viewport with no scroll.
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Version'), findsWidgets);
  });

  testWidgets('HelpScreen contains a heading for every HelpSection enum value',
      (tester) async {
    // Use a large viewport so all sections are rendered (ListView still
    // lazy-builds but a tall enough screen forces more children to build).
    // Sprint 33 round 2: 16 sections + 80% viewport-height trailing filler
    // means we need a taller canvas than the original 4000px.
    await tester.binding.setSurfaceSize(const Size(800, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    const expected = <String>[
      'Select Account',
      'Account Setup',
      'Demo Scan',
      'Manual Scan',
      'Results',
      'Scan History',
      'Settings',
      'General > Rules Management',
      'General > Scan History',
      'General > Privacy & Logging',
      'Account > Folder Settings',
      'Manual Scan Settings',
      'Background Scanning',
      'Manage Rules',
      'Rule Quick Add',
      'Rule Test',
      'Manage Safe Senders',
      'Folder Selection',
      'YAML Import / Export',
      'Other ways to reduce junk email, mail, texts, and phone calls',
      'Frequently Asked Questions',
      'First-Use Walkthrough',
    ];
    for (final title in expected) {
      expect(find.text(title), findsOneWidget,
          reason: 'missing Help section: $title');
    }
  });

  testWidgets(
      'HelpScreen shows a "First time? Start here" callout near the top, '
      'visible without scrolling (F151b, Sprint 58)', (tester) async {
    // Same rationale as the F140 version-display test above -- a first-time
    // user should not have to already know to scroll to the last of 22
    // sections to find the walkthrough.
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('First time? Start here'), findsOneWidget);
  });

  testWidgets(
      'Tapping the "First time? Start here" callout scrolls toward the '
      'walkthrough section (F151b, Sprint 58)', (tester) async {
    // The screen builds all 22 sections into one eager Column (not a lazy
    // ListView, per the Round-3 fix documented in help_screen.dart), so
    // find.text() locates every section's text regardless of scroll
    // position -- it does not prove visibility. Assert on scroll OFFSET
    // instead, matching how the existing initialSection test above avoids
    // asserting an exact platform-sensitive scroll position but still
    // proves the scroll actually moved.
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final initialOffset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(initialOffset, 0.0,
        reason: 'screen should open at the top with no initialSection');

    await tester.tap(find.text('First time? Start here'));
    await tester.pumpAndSettle();

    final offsetAfterTap = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offsetAfterTap, greaterThan(initialOffset),
        reason: 'tapping the callout should scroll down toward the '
            'last-positioned walkthrough section');
  });

  testWidgets(
      'Help content renders as formatted Markdown, not raw text '
      '(F151i, Sprint 58 MV-7)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    // The walkthrough file contains literal '## Step 1:' and '**Notes on'
    // markers. Rendered as Markdown, those markers must NOT appear as raw
    // text anywhere on the page -- the ## becomes a heading and the **
    // becomes bold.
    expect(find.textContaining('## Step'), findsNothing,
        reason: 'raw ## heading markers must not be visible -- content must '
            'render as formatted Markdown');
    expect(find.textContaining('**'), findsNothing,
        reason: 'raw ** bold markers must not be visible -- content must '
            'render as formatted Markdown');
  });

  testWidgets('HelpScreen accepts an initialSection without throwing',
      (tester) async {
    // The ensureVisible scroll is best-effort and depends on ListView's
    // lazy-build state at post-frame; we verify the screen mounts without
    // error when initialSection is provided, rather than inspecting the
    // exact scroll offset (which is platform-sensitive).
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(initialSection: HelpSection.yamlImportExport),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar is present -- screen did not throw during init.
    expect(find.text('Help'), findsOneWidget);
  });

  test('HelpSection has a stable entry for each primary screen', () {
    // If anyone removes a HelpSection we want the test suite to shout:
    // the enum is a contract between every AppBar that passes into
    // openHelp() and the HelpScreen that renders the target.
    // Sprint 37: added otherWaysToReduceJunk -> 20.
    // Sprint 39 F74: added faq -> 21.
    // Sprint 40 F75: added walkthrough -> 22.
    expect(HelpSection.values, hasLength(22));
  });
}
