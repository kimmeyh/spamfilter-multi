import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F229 (Sprint 73): every screen must render [ScreenVersionLine], or its
/// version is invisible at phone width and its screenshots stop identifying
/// the build they came from.
///
/// **Why a gate at all.** This is a fix applied 22 times, which is a fix that
/// decays: the next screen someone adds will not have it, and no screen's own
/// tests assert a version line. Exactly the F209 situation, so this mirrors
/// `system_inset_wiring_test.dart` rather than inventing a second shape.
///
/// **Why per screen rather than one wiring line.** Applying this once at
/// `MaterialApp.builder` would sit above the `Navigator` and therefore also
/// paint over dialog routes, modal sheets and the `ScaffoldMessenger` overlay
/// -- which are not screens and must not carry a version. F209's first
/// implementation did exactly that and broke three things, including
/// re-breaking the F178 action popup. The cost of doing it right is this gate.
///
/// Asserts STRUCTURE only. `f229_screen_version_line_test.dart` owns the
/// behaviour, on both sides of the 600px threshold -- a source-text gate
/// proves a symbol is present, never that it works, so the two are paired
/// deliberately. That pairing is not optional here: Sprint 73's own F234 and
/// F224 both shipped inert with green source-text suites.
void main() {
  final screensDir = Directory('lib/ui/screens');

  /// Screens that legitimately do not render the line.
  ///
  /// Every entry needs a reason. An unexplained exemption is how a gate stops
  /// gating.
  const exempt = <String, String>{
    'main_navigation_screen.dart':
        'Hosts the other screens inside its own body, each of which renders '
        'its own line. Rendering one here as well would show the version '
        'twice on every hosted screen.',
  };

  /// Comment CONTENT blanked to spaces.
  ///
  /// Must read CODE, not prose: a comment naming the widget is not a use of
  /// it, and a comment containing `Scaffold(` is not a Scaffold. This is the
  /// blind spot the F209 gate shipped with for one round.
  String blankComments(String source) => source
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  test('every screen with a Scaffold body renders ScreenVersionLine', () {
    expect(screensDir.existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');

    final missing = <String>[];

    for (final entity in screensDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      final code = blankComments(entity.readAsStringSync());

      // Matches the widget, not the `return` keyword, and excludes
      // `ScaffoldMessenger` / `Scaffold.of`, which use an ambient Scaffold
      // rather than constructing one.
      if (!RegExp(r'(?<![A-Za-z])Scaffold\(').hasMatch(code)) continue;
      if (!RegExp(r'(?<![A-Za-z])body\s*:').hasMatch(code)) continue;
      if (exempt.containsKey(name)) continue;

      // COUNT, do not test presence -- PR #435 review C-2.
      //
      // **This gate shipped testing presence and it hid a real defect.** The
      // check was `hasMatch(code)`: one wired branch satisfied the whole file.
      // `account_selection_screen.dart` has FOUR Scaffolds -- loading, error,
      // empty, and the steady state shown on nearly every launch -- and only
      // the loading SKELETON was wired. The gate was green while three
      // reachable branches, including the app's primary landing screen,
      // shipped with no version line at all. That is F229 failing on its
      // most-screenshotted screen, with its own gate reporting success.
      //
      // The structural lesson, which applies to every gate of this shape in
      // the repo: **these gates count FILES while the bug lives in BRANCHES.**
      // A boolean per file is permanently satisfiable by wiring any one
      // branch, including a dead one.
      //
      // Counting is not a perfect proof of placement -- a file could wire the
      // same branch twice -- but it converts "at least one" into "at least as
      // many as there are Scaffolds", which is what actually failed here.
      final scaffolds =
          RegExp(r'(?<![A-Za-z])Scaffold\(').allMatches(code).length;
      final lines = RegExp(r'ScreenVersionLine\(').allMatches(code).length;
      if (lines < scaffolds) {
        missing.add('$name ($lines line(s) for $scaffolds Scaffold(s))');
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'These screens have MORE Scaffold branches than version '
          'lines, so at least one reachable branch shows no version at phone '
          'width and a screenshot of it cannot identify its build.\n\n'
          'A build() with several early returns needs the line in EVERY '
          'branch -- account_selection_screen had four and wired only the '
          'loading skeleton, which shows for a fraction of a second.\n\n'
          'Fix: make the body a Column whose first child is '
          '`const ScreenVersionLine()`.\n'
          'If a screen genuinely should not show it, add it to `exempt` WITH '
          'a reason.\n\nMissing: ${missing.join(', ')}',
    );
  });

  test('the two version surfaces are COMPLEMENTARY, never both or neither',
      () {
    // The AppBar label hides below 600px; this line shows below 600px. If
    // those thresholds ever drift apart, some width shows the version twice
    // and some shows it nowhere -- and nothing else in the suite would catch
    // it, because each widget's own tests pass in isolation.
    final line = File('lib/ui/widgets/screen_version_line.dart')
        .readAsStringSync();
    final appBar = File('lib/ui/widgets/standard_app_bar_actions.dart')
        .readAsStringSync();

    expect(line.contains('width < 600'), isTrue,
        reason: 'the body line is the NARROW branch');
    expect(appBar.contains('MediaQuery.of(context).size.width < 600'), isTrue,
        reason: 'the AppBar label is the WIDE branch; if this threshold moves '
            'without the other, the version doubles or disappears');
  });
}
