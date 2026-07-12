import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sprint 46 retro IMP-2: shared harness for widget tests whose screens do
/// REAL sqflite-FFI database work in initState.
///
/// THE HANG (has cost time in 3+ sprints -- Sprints 40, 46 twice): in the
/// default widget-test zone, sqflite_common_ffi's futures are backed by a
/// background isolate / real timers, which NEVER resolve under fake-async.
/// Two rules make these tests work, and this helper encodes the second:
///
/// 1. ALL database-touching work -- seeding, provider loads, mounting the
///    screen (whose initState kicks off the DB load), and any taps whose
///    handlers hit the DB -- MUST run inside `tester.runAsync(() async {...})`.
/// 2. NEVER use `pumpAndSettle` -- it spins forever on loading indicators /
///    progress animations while the real-event-loop future is still pending.
///    Instead: pump the widget, give the real event loop time to finish the
///    initState load, then pump frames to flush the resulting setState.
///
/// Usage (from inside `tester.runAsync`):
/// ```dart
/// await tester.runAsync(() async {
///   // ...seed DB, build providers...
///   await mountAndLoadDbWidget(tester, buildTestWidget());
///   // ...assertions / further taps...
/// });
/// ```
///
/// See `results_display_no_rule_reload_test.dart` (the original workaround
/// site) and `no_rule_review_screen_test.dart` for full worked examples,
/// including the DatabaseHelper-singleton + TestAppPaths setup from
/// `database_test_helper.dart`.
Future<void> mountAndLoadDbWidget(
  WidgetTester tester,
  Widget widget, {
  Duration settleDelay = const Duration(milliseconds: 800),
}) async {
  await tester.pumpWidget(widget);
  // Real-event-loop time for initState's DB load chain to complete.
  await Future<void>.delayed(settleDelay);
  await tester.pump(); // flush the load's setState
  await tester.pump(const Duration(milliseconds: 50));
}
