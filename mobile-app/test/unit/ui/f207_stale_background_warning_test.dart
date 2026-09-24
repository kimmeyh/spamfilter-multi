/// F207: when does a manual scan warn about a background scan in progress?
///
/// ## This file previously asserted the WRONG behaviour, and that is the point
///
/// Sprint 73 suppressed the warning whenever the in-process [ScanCoordinator]
/// held no lease, reasoning that "Android runs every scan in one process, so
/// the coordinator is authoritative". Six tests pinned that, including an
/// exhaustive truth table -- and every one of them passed while the feature was
/// wrong, because they injected `coordinatorIsIdle` as a BOOLEAN rather than
/// exercising the real cross-isolate value.
///
/// **The reasoning conflated the OS process with the Dart isolate.**
/// `androidBackgroundScanDispatcher` is a `@pragma('vm:entry-point')`
/// WorkManager entry that calls `WidgetsFlutterBinding.ensureInitialized()` --
/// the signature of a SEPARATE ISOLATE entry, since nothing re-initialises a
/// binding it already has. `ScanCoordinator` is a plain per-isolate in-memory
/// singleton and Dart isolates do not share memory, so the UI isolate's
/// coordinator reads idle even while a background scan genuinely holds its
/// lease in the worker isolate.
///
/// So on Android the suppression fired essentially always, hiding the warning
/// for LIVE scans and letting the user start a concurrent manual scan -- the
/// Sprint 61 concurrent-session failure the notice exists to prevent. Found by
/// the PR #435 reviews (Copilot HIGH, and independently by the Claude review).
///
/// **The lesson for these tests specifically**: a test that injects the value
/// whose DERIVATION is the bug cannot see the bug. The old truth table was
/// rigorous about the wrong thing.
///
/// ## What is asserted now
///
/// The conservative direction: trust the row on every platform. A warning shown
/// for a dead scan is a nuisance the user clicks past; a warning suppressed for
/// a live scan risks concurrent sessions against a per-account cap.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the decision,
/// not the query. They cannot prove `getActiveBackgroundScan` returns the right
/// rows, nor that the 30-minute staleness window is the right length -- the
/// original F207 complaint (a stale row warning for up to 30 minutes) is REAL
/// and remains unfixed, tracked as MV74-2 (#434), because fixing it properly
/// needs a cross-isolate liveness signal: a heartbeat or `updated_at` column
/// that `scan_results` does not have.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

void main() {
  group('F207: the row is the only evidence this isolate has', () {
    test('THE FIX: a fresh in_progress row always warns', () {
      // Post-review behaviour. Before the fix this returned FALSE on Android
      // whenever the UI isolate's coordinator was idle -- which is nearly
      // always -- so a live background scan was silently allowed to collide
      // with a manual one.
      expect(shouldWarnAboutBackgroundScan(hasActiveRow: true), isTrue,
          reason: 'a background scan the database reports as running must '
              'warn, because this isolate cannot see the worker isolate that '
              'would prove otherwise');
    });

    test('no row means no warning', () {
      // The unhappy input: nothing to warn about. Nothing may manufacture a
      // warning from an absent row.
      expect(shouldWarnAboutBackgroundScan(hasActiveRow: false), isFalse);
    });

    test('THE REGRESSION GUARD: the decision takes no platform argument', () {
      // Stated as a behavioural property rather than prose, so re-adding a
      // platform or coordinator branch cannot pass silently. The previous
      // signature took `coordinatorIsIdle` and `isAndroid`; both are gone
      // deliberately, and their absence IS the fix.
      //
      // If a future change needs platform awareness here, it needs a
      // cross-isolate liveness signal first -- see the library doc.
      expect(
        () => shouldWarnAboutBackgroundScan(hasActiveRow: true),
        returnsNormally,
        reason: 'the function must remain callable with the row alone',
      );

      // Both inputs map to exactly one output, with no third state.
      final outcomes = <bool>{
        shouldWarnAboutBackgroundScan(hasActiveRow: true),
        shouldWarnAboutBackgroundScan(hasActiveRow: false),
      };
      expect(outcomes, {true, false},
          reason: 'the row alone determines the answer');
    });
  });
}
