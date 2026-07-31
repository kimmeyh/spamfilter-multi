import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F134 (Sprint 52): build-failing gate on the canonical AppBar action order.
///
/// Harold specified ONE order for every screen: screen-specific actions first,
/// then `Review "No Rule" Items, View Scan History, Accounts, Settings, Help`,
/// with **Help always last** and the Exit button auto-appended by
/// `AppBarWithExit`.
///
/// **Why a gate rather than a one-time cleanup**: the Sprint 52 audit found the
/// same five IconButtons hand-rolled across 12 screens in at least FOUR
/// different orders -- and `scan_progress_screen.dart` carried a comment
/// asserting a "standardized icon order" that matched no other screen. Help
/// alone appeared hand-rolled 11 times. That is the duplication-drift defect
/// class the F130 process-docs audit keeps finding, reproduced in code. A
/// cleanup fixes today; a gate keeps it fixed.
///
/// The rule this enforces: a screen must not declare a standard AppBar action
/// itself. It calls `StandardAppBarActions.build()`, which is the single
/// definition of both the set and the order.
void main() {
  group('AppBar action-order invariant (F134, Sprint 52)', () {
    /// Tooltips owned exclusively by the shared builder.
    ///
    /// 'Manual Scan' joined the set on 2026-07-31 (Harold, during MV-1): the
    /// account screen was the ONLY route to Manual Scan, which became a dead
    /// end once F135 made Review "No Rule" Items the desktop default. It
    /// follows the same rule as every other action -- default-ON, with
    /// `includeManualScan: false` used ONLY by the Manual Scan screen itself.
    const standardActionTooltips = <String>[
      'Manual Scan',
      'Review "No Rule" Items',
      'View Scan History',
      'Select Account',
      'Settings',
      'Help',
    ];

    /// Declarations that are legitimately NOT AppBar actions and must not be
    /// flagged. Each entry needs a reason -- an unexplained exemption is how a
    /// gate quietly stops gating.
    const allowedExemptions = <String, String>{
      'scan_history_screen.dart':
          'In-BODY filter chip: a compact Review-No-Rule icon rendered directly '
          'above the "No Rule" total chip (_buildNoRuleChipWithReviewIcon). It '
          'is page content, not an AppBar action, so the canonical order does '
          'not apply to it.',
    };

    late Directory screensDir;

    setUpAll(() {
      screensDir = Directory('lib/ui/screens');
      expect(screensDir.existsSync(), isTrue,
          reason: 'run this test from the mobile-app/ directory');
    });

    test('the matcher self-checks: it detects a hand-rolled standard action',
        () {
      // Guards against the gate silently passing because the pattern stopped
      // matching anything at all.
      const sample = "IconButton(\n  tooltip: 'Help',\n  icon: Icon(x),\n)";
      expect(sample.contains("tooltip: 'Help'"), isTrue);
    });

    test('no screen declares a standard AppBar action outside the shared builder',
        () {
      final violations = <String>[];

      for (final entity in screensDir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final fileName = entity.uri.pathSegments.last;
        final source = entity.readAsStringSync();

        for (final tooltip in standardActionTooltips) {
          if (!source.contains("tooltip: '$tooltip'")) continue;
          if (allowedExemptions.containsKey(fileName)) continue;

          violations.add(
            '$fileName declares `tooltip: \'$tooltip\'` directly. '
            'Standard AppBar actions belong to StandardAppBarActions.build() -- '
            'pass screen-specific actions via `leading:` and suppress a '
            "screen's own entry with the include* flags.",
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'AppBar action order must have exactly ONE definition '
            '(lib/ui/widgets/standard_app_bar_actions.dart). Hand-rolling it '
            'per screen is what produced four different orders across 12 '
            'screens before Sprint 52.\n\n${violations.join('\n\n')}',
      );
    });

    test('the shared builder still defines every standard action', () {
      // If someone deletes an action from the builder, the test above would
      // pass vacuously (no screen declares it, because it no longer exists).
      final builder =
          File('lib/ui/widgets/standard_app_bar_actions.dart').readAsStringSync();

      for (final tooltip in standardActionTooltips) {
        expect(builder.contains("tooltip: '$tooltip'"), isTrue,
            reason: 'StandardAppBarActions must still define the `$tooltip` '
                'action -- if it was intentionally removed, update this test '
                'and the canonical order in the class doc together.');
      }
    });

    test('only the Manual Scan screen suppresses the Manual Scan icon', () {
      // Harold, 2026-07-31: "The radar icon belongs on either: all screens OR
      // all screens except the Manual Scan screen (follow the same pattern as
      // for icon tool bar currently)."
      //
      // The chosen variant is the second, so exactly ONE screen may pass
      // includeManualScan: false. This is the self-referential-suppression rule
      // every other action follows; a second screen opting out would be the
      // icon quietly going missing rather than a deliberate design choice.
      final offenders = <String>[];
      for (final file in screensDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (!source.contains('includeManualScan: false')) continue;
        final name = file.uri.pathSegments.last;
        if (name != 'scan_progress_screen.dart') offenders.add(name);
      }

      expect(offenders, isEmpty,
          reason: 'Only scan_progress_screen.dart (which IS the Manual Scan '
              'screen) may set includeManualScan: false. These screens also '
              'opt out, so the icon is missing there: ${offenders.join(', ')}');

      // And the Manual Scan screen MUST suppress it -- otherwise the icon
      // re-pushes the screen you are already on, stacking a second scan screen
      // on top of a running scan.
      final scanScreen =
          File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync();
      expect(scanScreen.contains('includeManualScan: false'), isTrue,
          reason: 'scan_progress_screen.dart must suppress its own Manual Scan '
              'icon, the same way Settings/Scan History/No-Rule each suppress '
              'theirs.');
    });

    test('Help is declared LAST in the shared builder', () {
      // The order inside build() IS the canonical order, so its source order
      // is the contract. Help last is Harold's explicit rule (2026-07-30).
      final builder =
          File('lib/ui/widgets/standard_app_bar_actions.dart').readAsStringSync();

      final positions = <String, int>{
        for (final t in standardActionTooltips)
          t: builder.indexOf("tooltip: '$t'"),
      };

      final helpPosition = positions['Help']!;
      for (final entry in positions.entries) {
        if (entry.key == 'Help') continue;
        expect(helpPosition, greaterThan(entry.value),
            reason: 'Help must be declared after ${entry.key} in the builder -- '
                'Help is always the LAST standard action.');
      }
    });
  });
}
