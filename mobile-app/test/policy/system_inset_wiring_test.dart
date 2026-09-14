import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F209 (Sprint 69): every screen must wrap its `Scaffold` in
/// `SystemInsetWrapper`, or its bottom content falls back under the Android
/// system navigation buttons.
///
/// **Why a gate at all.** The defect was that only 2 of 23 screens inset for
/// the navigation bar. A fix applied 25 times is a fix that decays: the next
/// screen someone adds will not have it, and no existing test would notice,
/// because no screen's own tests render a system inset.
///
/// **Why this shape rather than one wiring line.** The first implementation
/// applied the wrapper once, at `MaterialApp.builder`. That is a single point
/// to guard and it was WRONG: sitting above the Navigator, it shrank the Stack
/// that dialog routes are positioned in, which re-broke the F178 action popup
/// (Sprint 62, found from a screenshot of a clipped "Block Subject"). The
/// popup reads the root view precisely because inherited MediaQuery gets
/// consumed, so it could not see the shrink. Wrapping around each `Scaffold`
/// leaves dialog routes above the wrapper and untouched -- at the cost of
/// needing this gate to keep the coverage honest.
///
/// Asserts STRUCTURE only. `f209_system_inset_test.dart` owns the behaviour,
/// on both ADR-0042 branches -- a source-text gate proves a symbol is present,
/// never that it works, so the two are paired deliberately.
void main() {
  final screensDir = Directory('lib/ui/screens');

  /// Screens that legitimately do not wrap.
  ///
  /// Every entry needs a reason. An unexplained exemption is how a gate stops
  /// gating.
  const exempt = <String, String>{
    'main_navigation_screen.dart':
        'Hosts the other screens inside its own body, each of which wraps '
        'itself. Wrapping here as well would be harmless (SafeArea consumes '
        'what it applies) but would make the ownership ambiguous.',
  };

  /// Source with `//` line comments removed.
  ///
  /// Both checks below must read CODE, not prose. A comment naming a widget is
  /// not a use of it, and a comment containing `Scaffold(` is not a Scaffold.
  String stripComments(String source) => source
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  test('every screen with a Scaffold wraps it in SystemInsetWrapper', () {
    expect(screensDir.existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');

    final missing = <String>[];

    for (final entity in screensDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      final source = entity.readAsStringSync();

      // Does this file build a Scaffold AT ALL? Match the widget itself, not
      // the `return` keyword.
      //
      // **This is the fix for the gate's own blind spot** (PR #410 review).
      // The first version asked whether the source contained
      // `return Scaffold(`. Two screens return a WRAPPER around their
      // Scaffold -- `return Focus(...child: Scaffold(` in
      // results_display_screen.dart and `return PopScope(...child: Scaffold(`
      // in scan_progress_screen.dart -- so that string never appears. Worse,
      // the scope filter above ALSO keyed on it, so both files were skipped
      // before the check ran. The gate reported two tests green while the
      // results list and the scan-progress buttons were genuinely sitting
      // under the navigation bar.
      //
      // Excludes `ScaffoldMessenger` and `Scaffold.of`, which are uses of the
      // ambient Scaffold rather than constructions of a new one.
      final code = stripComments(source);
      final buildsScaffold =
          RegExp(r'(?<![A-Za-z])Scaffold\(').hasMatch(code);
      if (!buildsScaffold) continue;
      if (exempt.containsKey(name)) continue;

      // In scope and building a Scaffold: the wrapper must be CONSTRUCTED.
      //
      // `source.contains('SystemInsetWrapper')` is NOT sufficient, and this
      // gate shipped that way for one round. A file whose only mention is a
      // COMMENT -- `// F209: SystemInsetWrapper goes OUTSIDE PopScope ...` --
      // satisfied a substring test while the widget was entirely absent. That
      // is the same failure as the F193 evidence gate accepting prose that
      // merely says "5.1.1": a mention is not a use.
      //
      // Requiring `SystemInsetWrapper(` means the constructor is called. Its
      // POSITION is still not asserted here -- f209_system_inset_test.dart
      // owns behaviour, and a source gate cannot prove placement is correct.
      final constructsWrapper =
          RegExp(r'SystemInsetWrapper\(').hasMatch(code);
      if (!constructsWrapper) {
        missing.add(name);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'These screens build a Scaffold that is NOT wrapped in '
          'SystemInsetWrapper, so their bottom content sits under the Android '
          'system navigation buttons -- the F209 defect, which hid an error '
          'message mid-sentence on the Import/Export screen and, until the '
          'PR #410 review, hid the last row of the results list and the '
          'scan-progress action buttons as well.\n\n'
          'Fix: `return SystemInsetWrapper(child: Scaffold(...));`\n'
          'If a screen genuinely should not wrap, add it to `exempt` WITH a '
          'reason.\n\nUnwrapped: ${missing.join(', ')}',
    );
  });

  test('the wrapper exists and declares its platform exception', () {
    final widget = File('lib/ui/widgets/system_inset_wrapper.dart');
    expect(widget.existsSync(), isTrue,
        reason: 'lib/ui/widgets/system_inset_wrapper.dart is missing');

    final source = widget.readAsStringSync();

    expect(
      source.contains('ADR-0042'),
      isTrue,
      reason: 'the Android-only fork must stay DECLARED in the code, naming '
          'what cannot be shared and why. An undeclared platform fork is '
          'indistinguishable from an accident to the next reader.',
    );

    expect(
      source.contains('SafeArea'),
      isTrue,
      reason: 'the wrapper must apply SafeArea, not raw Padding. SafeArea '
          'reads `padding` (so the keyboard case is correct) and CONSUMES '
          'what it applies (so nested SafeAreas do not inset twice). Raw '
          'Padding did neither, and code review found three regressions '
          'because of it -- see the widget doc.',
    );
  });
}
