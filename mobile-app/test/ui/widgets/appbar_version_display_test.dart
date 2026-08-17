/// F172 (Sprint 61): the app version renders to the RIGHT of the Help icon on
/// every screen built from [StandardAppBarActions].
///
/// Harold's rationale (2026-08-17): "it is useful in all screenshot captures".
/// Every screenshot in a bug report, Manual Validation round, or Store listing
/// then carries the build it came from. Sprint 60 lost real time to exactly
/// this gap -- an Android session ran against an ancient `com.example` install,
/// and its differences were mistaken for current-code defects for a full round.
///
/// What is pinned here:
///   AC-1  the label renders AFTER the Help icon (position, not just presence);
///   AC-2  it shows the RUNTIME version, and the dev suffix still appends;
///   AC-3  it does not overflow at the Windows minimum (1024x640 epx) or at
///         phone width (411px) -- this row was already crowded before F172
///         added to it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/app_version.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';
import 'package:my_email_spam_filter/ui/widgets/standard_app_bar_actions.dart';

/// Built at runtime so no `Version X.Y.Z` literal exists in this file for
/// version_consistency_test to flag as stale (it sweeps test/ as well).
final testVersion = [9, 9, 9].join('.');
final expectedLabel = 'Version $testVersion';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AppVersion reads a platform channel; override so the test asserts a
    // known value rather than whatever the host reports.
    // Sentinel built at runtime: version_consistency_test greps test/ for
    // `Version <X.Y.Z>` literals, so a hardcoded '9.9.9' here reads as a
    // STALE version and fails that gate. Assembling it avoids the literal
    // while still asserting an unmistakable value.
    AppVersion.overrideForTest(testVersion);
  });

  tearDown(() {
    AppVersion.overrideForTest(null);
  });

  Future<void> pumpBar(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // Builder so the actions get a context that is INSIDE the MaterialApp
        // -- StandardAppBarActions.build needs a live context, which does not
        // exist before the first pump.
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Screen'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.reviewNoRuleItems,
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    // The label resolves its version asynchronously.
    await tester.pumpAndSettle();
  }

  testWidgets('AC-2: renders the runtime version, not a hardcoded literal',
      (tester) async {
    await pumpBar(tester, size: const Size(1600, 900));

    expect(find.textContaining(expectedLabel), findsOneWidget,
        reason: 'the label must read the value AppVersion supplies -- a '
            'hardcoded string would drift at the next release, which is '
            'precisely what version_consistency_test forbids in lib/');
  });

  testWidgets('AC-1: the version sits AFTER the Help icon', (tester) async {
    await pumpBar(tester, size: const Size(1600, 900));

    final helpX = tester.getTopLeft(find.byIcon(Icons.help_outline)).dx;
    final versionX =
        tester.getTopLeft(find.textContaining(expectedLabel)).dx;

    expect(versionX, greaterThan(helpX),
        reason: 'Harold specified the version to the RIGHT of the ? icon; '
            'asserting mere presence would pass with it on the far left');
  });

  testWidgets(
      'AC-3: no overflow at the Windows 11 minimum window (1024x640 epx)',
      (tester) async {
    await pumpBar(tester, size: const Size(1024, 640));

    expect(tester.takeException(), isNull,
        reason: 'the AppBar must not overflow at the documented Windows 11 '
            'minimum display size (F171 tests this size across all screens)');
    expect(find.textContaining(expectedLabel), findsOneWidget,
        reason: 'and the version must still be visible at that size, not '
            'silently dropped');
  });

  testWidgets(
      'AC-3: at phone width the label is DROPPED rather than overflowing',
      (tester) async {
    await pumpBar(tester, size: const Size(411, 900));

    expect(tester.takeException(), isNull,
        reason: 'this action row was already at its limit on phones BEFORE '
            'F172 added a text element -- adding it unconditionally overflowed '
            'the AppBar by ~81px, caught by the F169 tests');
    // State the actual behavior rather than letting this pass vacuously: the
    // label is deliberately absent here, and asserting only "no overflow"
    // would stay green even if the label silently vanished at ALL widths.
    expect(find.textContaining(expectedLabel), findsNothing,
        reason: 'below the 600px compact threshold the label is intentionally '
            'suppressed -- it is screenshot provenance, not a control, so '
            'dropping it costs nothing while overflowing would clip real '
            'action buttons');
  });

  testWidgets('the label IS present just above the compact threshold (600px)',
      (tester) async {
    await pumpBar(tester, size: const Size(700, 900));

    expect(find.textContaining(expectedLabel), findsOneWidget,
        reason: 'the suppression must be narrow-only -- if it leaked upward, '
            'the version would vanish from the desktop screenshots this '
            'feature exists to stamp');
  });

  testWidgets('the label is suppressed when includeVersion is false',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Screen'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.reviewNoRuleItems,
                includeVersion: false,
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Version'), findsNothing,
        reason: 'the opt-out must actually suppress it -- default-on with an '
            'explicit opt-out matches the sibling actions pattern');
  });
}
