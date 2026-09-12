import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F209 (Sprint 69): the Android system-navigation inset must stay wired into
/// `MaterialApp.builder`.
///
/// **Why guard the WIRING rather than each screen.** The defect was that only
/// 2 of 23 screens inset for the navigation bar, and every screen builds its
/// own `Scaffold` -- there is no shared body container to fix. Applying the
/// wrapper at `MaterialApp.builder` covers every route, including screens
/// added after this sprint, which a per-screen audit cannot do.
///
/// That makes the builder line a single point of failure: delete it and all 23
/// screens silently regress at once, with no test failing, because each
/// screen's own tests never render a system inset. This gate is the tripwire
/// for that one line.
///
/// It deliberately asserts STRUCTURE, not behaviour --
/// `f209_system_inset_test.dart` owns the behaviour, on both ADR-0042
/// branches. A source-text gate proves a symbol is present, never that it
/// works, so the two are paired on purpose.
void main() {
  test('MaterialApp still applies SystemInsetWrapper to every route', () {
    final main = File('lib/main.dart');
    expect(main.existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');

    final source = main.readAsStringSync();

    expect(
      source.contains('SystemInsetWrapper'),
      isTrue,
      reason: 'lib/main.dart no longer references SystemInsetWrapper. Without '
          'it, content on every Android screen falls back under the system '
          'navigation buttons -- the F209 defect, which hid an error message '
          'mid-sentence on the Import/Export screen. If the wrapper was '
          'replaced, point this gate at whatever replaced it; do not delete '
          'the gate.',
    );

    expect(
      RegExp(r'builder:\s*\(context,\s*child\)').hasMatch(source),
      isTrue,
      reason: 'the MaterialApp builder hook is gone. SystemInsetWrapper must '
          'be applied there rather than per screen: each of the 23 screens '
          'builds its own Scaffold, and a screen added later would not '
          'inherit the fix any other way.',
    );
  });

  test('the wrapper itself still exists and declares its platform exception',
      () {
    final widget = File('lib/ui/widgets/system_inset_wrapper.dart');
    expect(widget.existsSync(), isTrue,
        reason: 'lib/ui/widgets/system_inset_wrapper.dart is missing');

    final source = widget.readAsStringSync();
    expect(
      source.contains('ADR-0042'),
      isTrue,
      reason: 'the Android-only fork must stay DECLARED in the code, naming '
          'what cannot be shared and why (ADR-0042). An undeclared platform '
          'fork is indistinguishable from an accident to the next reader.',
    );
  });
}
