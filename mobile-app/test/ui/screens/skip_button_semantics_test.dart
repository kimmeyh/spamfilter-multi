import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// F136 (Sprint 52): the popup-header "Skip" control.
///
/// Harold: *"add a 'Skip' button in the header - leaves the current item
/// unaffected and goes to the next unaddressed item in the list - button should
/// be about the same size as the safe sender and rules buttons."*
///
/// Two things must hold, and only one of them is about looks:
///   1. Skip is NAMED and ACTIVATABLE via the accessibility tree.
///   2. Skip changes NOTHING about the current item -- it is navigation, not a
///      state change.
///
/// This pins the SHAPE the production widget uses (`_buildSkipButton`), the
/// same approach `account_selection_semantics_test.dart` takes: the Flutter
/// semantics tree is the authoritative source for whether a label exists and
/// whether a node can be activated, and the Windows UIA projection proved
/// unreliable as a verification instrument during Sprint 51.
void main() {
  /// Mirrors the production Skip button structure:
  /// Semantics -> Tooltip -> InkWell -> Container(Row(Icon, Text)).
  Widget buildSkipButton({required VoidCallback onSkip}) {
    return MaterialApp(
      home: Scaffold(
        body: Semantics(
          container: true,
          button: true,
          excludeSemantics: true,
          label: 'Skip',
          hint: 'Leave this email unchanged and go to the next unaddressed item',
          onTap: onSkip,
          child: Tooltip(
            message: 'Skip -- leave unchanged, go to the next unaddressed item',
            child: InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_next,
                        size: 16, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 6),
                    Text('Skip',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Skip exposes an accessible name and a hint explaining it',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildSkipButton(onSkip: () {}));

    expect(find.bySemanticsLabel('Skip'), findsOneWidget,
        reason: 'the control must announce itself as Skip');

    final node = tester.getSemantics(find.bySemanticsLabel('Skip'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue,
        reason: 'Skip is actionable, so assistive technology must present it '
            'as a button');
    expect(node.hint, contains('next unaddressed'),
        reason: 'the hint must say what Skip DOES -- "Skip" alone does not '
            'convey that the item is left unchanged');

    handle.dispose();
  });

  testWidgets('Skip is ACTIVATABLE through the accessibility tree',
      (tester) async {
    // The Sprint 51 lesson, applied at build time rather than after a defect:
    // `excludeSemantics` drops the child's gesture node, so without `onTap` on
    // the Semantics widget this button would announce correctly and be
    // impossible to activate. Asserting the isButton FLAG is not enough -- the
    // broken shape sets that flag too.
    final handle = tester.ensureSemantics();

    var skipped = 0;
    await tester.pumpWidget(buildSkipButton(onSkip: () => skipped++));

    final node = tester.getSemantics(find.bySemanticsLabel('Skip'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
        reason: 'the merged Skip node must expose a TAP action');

    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump();

    expect(skipped, 1,
        reason: 'activating Skip through the accessibility tree must run the '
            'same handler a mouse tap would');

    handle.dispose();
  });

  testWidgets('a mouse tap runs the same handler', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(buildSkipButton(onSkip: () => skipped++));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(skipped, 1,
        reason: 'ordinary pointer input must be unaffected by the semantics '
            'wrapper');
  });
}
