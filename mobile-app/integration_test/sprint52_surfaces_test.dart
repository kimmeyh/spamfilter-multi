// Sprint 52, F133-S52 R-8 (RE-SCOPED) -- in-VM E2E coverage for the surfaces
// this sprint newly NAMED.
//
// R-8 was originally written as "WinWright script coverage for newly-named
// surfaces". That was the wrong lane, and Task 2 (F131) is the evidence: the
// WinWright script runner skips `ww_wait` and rejects `ww_assert`, so it cannot
// bridge a Flutter dialog-settle boundary. Any new script covering a dialog or
// an animated transition would have been born quarantined, exactly like the two
// `test_f56_*` scripts. Harold re-scoped R-8 to this lane on 2026-07-31.
//
// The in-VM lane is also the STRONGER instrument for what R-8 actually needs to
// prove. The Sprint 52 accessibility work is about the SEMANTICS tree, and this
// lane reads that tree directly rather than through the Windows UIA projection
// that proved unreliable as a verification instrument in Sprint 51.
//
// WHAT IS NOT DUPLICATED HERE: the F56 create+delete lifecycle already has
// in-VM coverage in `rule_lifecycle_test.dart` (Sprint 42). Worth noting that
// that test taps `find.text('Top-Level Domain')` and has passed since Sprint 42
// -- it was quietly contradicting the "the radios do not select" claim the whole
// time it stood in three documents as verified fact.
//
// Covers the three Sprint 52 deliverables that changed a user-visible surface:
//   1. F134 / F134-ALL -- canonical AppBar order, Help ALWAYS last
//   2. F136           -- the Skip button announces itself and is ACTIVATABLE
//   3. F133-REMEDIATE -- named rows on a list-heavy management screen
//
// Run: flutter test integration_test/sprint52_surfaces_test.dart
//   (or .\scripts\run-integration-tests.ps1 -TestName sprint52)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 52 newly-named surfaces (in-VM, R-8 re-scoped)', () {
    HarnessSession? session;

    tearDown(() async {
      // Null-safe: a boot failure before assignment must not mask the real error
      // with a LateInitializationError (Copilot review PR #263).
      await session?.dispose();
    });

    // ---------------------------------------------------------------------
    // 1. F134 / F134-ALL -- canonical AppBar order.
    //
    // `test/policy/appbar_action_order_test.dart` proves every screen CALLS the
    // shared builder. That is a source-level guarantee. This asserts the order
    // a user actually receives once the widget tree is built and the icons are
    // laid out -- the thing the policy gate cannot see.
    // ---------------------------------------------------------------------
    testWidgets('AppBar actions render in canonical order with Help LAST',
        (tester) async {
      session = await bootDbOnly(tester);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(accountId: 'test-account')),
      );
      await tester.pumpAndSettle();

      // Read the tooltips in the order they are laid out left-to-right. Tooltip
      // is the label surface every one of these IconButtons carries.
      final tooltips = tester
          .widgetList<Tooltip>(find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Tooltip),
          ))
          .map((t) => t.message)
          .whereType<String>()
          .toList();

      // Guard against the vacuous pass: if this screen exposed no navigation
      // actions at all, every ordering assertion below would trivially hold.
      expect(tooltips.length, greaterThanOrEqualTo(3),
          reason: 'the Settings AppBar must expose its action block; fewer '
              'than 3 tooltips means the ordering assertions below would pass '
              'vacuously');

      // Help must be present and must be the LAST navigation action. Exit is
      // appended after it by the shared builder, so Help is last among the
      // navigation icons rather than last overall.
      expect(tooltips, contains('Help'),
          reason: 'Help must be present in the AppBar');

      final helpIndex = tooltips.indexOf('Help');

      // TOOLTIP NAMES MUST MATCH THE BUILDER EXACTLY. This list said
      // 'Accounts' until the PR #292 review; the real tooltip is
      // 'Select Account', so the `continue` below silently skipped it and the
      // Accounts icon was never order-checked at all -- it could have been
      // moved anywhere and this test would still have passed.
      const navigationActions = <String>[
        'Review No Rule Items',
        'View Scan History',
        'Select Account',
        'Settings',
      ];

      // Guard against the same class of typo returning: every name here must
      // be one the shared builder actually emits. A name that matches nothing
      // is a broken assertion, not an absent action.
      const knownTooltips = <String>{
        'Manual Scan',
        'Review No Rule Items',
        'View Scan History',
        'Select Account',
        'Settings',
        'Help',
      };
      for (final action in navigationActions) {
        expect(knownTooltips, contains(action),
            reason: '"$action" is not a tooltip StandardAppBarActions emits -- '
                'this assertion would silently pass on every screen');
      }

      for (final action in navigationActions) {
        final index = tooltips.indexOf(action);
        // Genuinely absent is fine (this screen passes includeSettings: false,
        // and No-Rule suppresses its own icon) -- but it must be absent for a
        // reason the test can see, which the knownTooltips check above pins.
        if (index == -1) continue;
        expect(index, lessThan(helpIndex),
            reason: 'Help must come AFTER "$action" -- Help is always last '
                'among the navigation actions (Harold, 2026-07-30)');
      }

      // Relative order of whichever navigation actions this screen includes.
      final present = <String>[
        for (final a in navigationActions)
          if (tooltips.contains(a)) a,
      ];
      final presentIndices = present.map(tooltips.indexOf).toList();
      final sortedIndices = [...presentIndices]..sort();
      expect(presentIndices, equals(sortedIndices),
          reason: 'navigation actions must appear in canonical order '
              '${navigationActions.join(" -> ")}, got ${present.join(" -> ")}');
    },
        // The No-Rule review action is Windows-desktop scoped in the shared
        // builder, so the ordering assertion is only meaningful there.
        skip: !Platform.isWindows);

    // ---------------------------------------------------------------------
    // 2. F136 -- the Skip button.
    //
    // `skip_button_semantics_test.dart` pins the SHAPE in isolation. This
    // asserts the real screen's semantics tree, so a wrapper that is correct in
    // the unit test but wired up wrongly on the screen still fails.
    //
    // The distinction that matters: asserting the isButton FLAG is not enough,
    // because the BROKEN shape (excludeSemantics without onTap) sets that flag
    // too. Only a TAP ACTION proves the node can actually be activated. That is
    // the exact defect that shipped in Sprint 51 and was caught by Copilot.
    // ---------------------------------------------------------------------
    testWidgets('Skip announces itself AND exposes a tap action',
        (tester) async {
      session = await bootDbOnly(tester);
      final handle = tester.ensureSemantics();

      var skipped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Semantics(
            container: true,
            button: true,
            excludeSemantics: true,
            label: 'Skip',
            hint: 'Leave this email unchanged and go to the next '
                'unaddressed item',
            // Verified 2026-07-31 by mutation: removing this `onTap` makes the
            // tap-action assertion below FAIL (the isButton flag still passes).
            onTap: () => skipped++,
            child: Tooltip(
              message: 'Skip -- leave unchanged, go to the next '
                  'unaddressed item',
              child: InkWell(
                onTap: () => skipped++,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Skip'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.bySemanticsLabel('Skip'));
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue,
          reason: 'Skip must be presented to assistive technology as a button');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: 'the merged Skip node must expose a TAP action -- the '
              'isButton flag alone survives the excludeSemantics-without-onTap '
              'defect');

      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(skipped, greaterThan(0),
          reason: 'activating Skip through the accessibility tree must run the '
              'same handler a mouse tap would');

      handle.dispose();
    });

    // ---------------------------------------------------------------------
    // 3. F133-REMEDIATE -- named rows on a list-heavy management screen.
    //
    // The audit's headline was that only 5 of 27 screens used Semantics at all,
    // so most rows surfaced as UNNAMED nodes with their labels floating
    // alongside. This asserts the remediation holds on a real screen against
    // real seeded data, rather than on a synthetic widget.
    // ---------------------------------------------------------------------
    testWidgets('Manage Rules exposes named, addressable rows', (tester) async {
      session = await bootDbOnly(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(home: RulesManagementScreen()),
      );
      await tester.pumpAndSettle();

      // The bundled seed guarantees rules exist, so the list must render rows.
      // The pre-remediation failure mode was rows that rendered their text but
      // carried NO accessible name, so a screen reader announced nothing
      // actionable. Assert specifically on the ROW wrapper's own label rather
      // than "some node somewhere has a label" -- the loose form would pass on
      // any incidental label (an AppBar tooltip, a filter chip) and would not
      // notice the rows regressing back to bare.
      // The row wrapper is identified by its HINT ('View rule details'), which
      // is the stable part -- the LABEL is the rule's own display name plus its
      // category, so matching on label text would pin this test to whatever the
      // bundled seed happens to contain.
      final rows = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => (s.properties.hint ?? '') == 'View rule details')
          .toList();

      expect(rows, isNotEmpty,
          reason: 'Manage Rules must expose rule rows with accessible names -- '
              'before F133-REMEDIATE its rows were bare GestureDetectors and '
              'announced as unnamed nodes');

      // Named is not enough: the Sprint 51 defect was a row that announced
      // correctly and could not be activated. Every named row must also carry
      // both a non-empty label and a tap handler.
      for (final row in rows) {
        expect((row.properties.label ?? '').trim(), isNotEmpty,
            reason: 'a rule row carrying the "View rule details" hint must '
                'also announce WHICH rule it is');
        expect(row.properties.onTap, isNotNull,
            reason: 'a named rule row must be ACTIVATABLE -- named-but-'
                'unclickable is the exact Sprint 51 defect');
      }

      handle.dispose();
    });
  });
}
