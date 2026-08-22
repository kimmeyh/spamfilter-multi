/// F171 (Sprint 61): every screen must be USABLE at the Windows 11 minimum
/// window size that Microsoft documents -- **1024x640 epx, maximized**.
///
/// Why a sweep rather than spot checks: Sprint 60 and Sprint 61 each found
/// clipping defects at constrained widths BY ACCIDENT -- the AppBar icon row
/// overflowing at ~411px, the account chips clipping off-screen (F169), and a
/// ~105px selection-bar overflow that had been present for months but had
/// never been rendered at a phone width by any test. Accidents are not a
/// coverage strategy. This file makes the minimum size a deliberate, repeatable
/// check.
///
/// "Usable" is defined BEFORE the sweep, per the F171 card:
///   - nothing clipped (no RenderFlex overflow),
///   - no primary action pushed off-window,
///   - no horizontal scrolling required to reach a control,
///   - popups/dialogs fully inside the window.
/// This file automates the first, which is the mechanically detectable one and
/// the one every defect found so far has fallen under. The rest are recorded
/// as Manual Validation steps in SPRINT_61_PLAN.md.
///
/// Screens are covered here where they can be mounted without a full DB +
/// secure-storage harness; the DB-backed screens are already swept at
/// constrained widths by their own suites (no_rule_review_account_dropdown at
/// 411px, results_display_compact_and_filter at 599px), so this file
/// deliberately does NOT duplicate those harnesses -- it records which screen
/// is covered where, so the sweep is auditable rather than assumed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/app_version.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';
import 'package:my_email_spam_filter/ui/widgets/empty_state.dart';
import 'package:my_email_spam_filter/ui/widgets/standard_app_bar_actions.dart';

/// Microsoft's documented Windows 11 minimum display, maximized.
const Size kWindowsMinimum = Size(1024, 640);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppVersion.overrideForTest([0, 10, 0].join('.')));
  tearDown(() => AppVersion.overrideForTest(null));

  Future<void> pumpAt(WidgetTester tester, Widget child,
      {Size size = kWindowsMinimum, bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // ScanStartedEmptyState holds a CircularProgressIndicator, which never
      // stops animating -- pumpAndSettle would time out rather than report a
      // layout problem. A single pump is enough to force layout, which is
      // what this sweep actually measures.
      await tester.pump();
    }
  }

  group('F171: 1024x640 epx (Windows 11 minimum, maximized)', () {
    testWidgets('the full AppBar action row fits with every action present',
        (tester) async {
      // The worst case: all actions enabled AND the F172 version label, which
      // is exactly the combination that overflowed at phone width.
      await pumpAt(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Review No Rule Items'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.reviewNoRuleItems,
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(tester.takeException(), isNull,
          reason: 'the AppBar must not overflow at the Windows minimum -- this '
              'row already overflows at phone widths, so the margin here is '
              'the thing worth pinning');
    });

    testWidgets('a long screen title does not push actions off-window',
        (tester) async {
      // Real titles include an account email, which is user data and can be
      // long -- the realistic worst case for this row.
      await pumpAt(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text(
                  'Results - a.very.long.account.address@somelongdomain.example.com -'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.resultsDisplay,
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(tester.takeException(), isNull,
          reason: 'a long account address in the title must ellipsize rather '
              'than push the action buttons off-window');
    });

    testWidgets('empty states fit without overflowing', (tester) async {
      // EmptyState was made scrollable in Sprint 60 after overflowing a short
      // viewport by 44px; ScanStartedEmptyState got the same treatment during
      // the PR #335 review. Both are re-checked here at the minimum size.
      await pumpAt(
        tester,
        const Scaffold(body: Center(child: NoResultsEmptyState())),
      );
      expect(tester.takeException(), isNull,
          reason: 'NoResultsEmptyState must fit the minimum window');

      await pumpAt(
        tester,
        const Scaffold(body: Center(child: ScanStartedEmptyState())),
        settle: false,
      );
      expect(tester.takeException(), isNull,
          reason: 'ScanStartedEmptyState must fit the minimum window');
    });

    testWidgets('the version label IS shown at the minimum window size',
        (tester) async {
      await pumpAt(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.settings,
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // F172 suppresses the label below 600px. 1024 is far above that, so the
      // version MUST be present -- this is where Windows screenshots are taken,
      // and a suppression threshold that crept upward would silently defeat
      // the whole point of F172.
      expect(find.textContaining('Version'), findsOneWidget,
          reason: 'the F172 version label must survive at the Windows minimum '
              'window size -- if the compact threshold ever crept above 1024, '
              'desktop screenshots would silently lose their build stamp');
    });
  });
}
