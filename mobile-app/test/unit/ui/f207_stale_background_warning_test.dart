/// F207 (Sprint 73): a stale `in_progress` row must not warn about a scan that
/// is already dead.
///
/// **The defect.** The manual-scan notice is driven by a DATABASE row, not by
/// the in-process lease. `getActiveBackgroundScan()` matches
/// `status = 'in_progress'` within a 30-minute freshness window, so a
/// background scan killed without writing a terminal status keeps warning the
/// user -- with a wait estimate for a corpse -- for the full 30 minutes.
///
/// **Why the existing cleanup could not help**, and the reason this is a fix
/// rather than a tuning exercise: `reconcileStaleInProgressScans` uses the SAME
/// `ScanCoordinator.scanTimeout` constant as the blocker, so it can only clear
/// a row once that row has already stopped matching. One constant, both sides.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the DECISION,
/// not the query. A test here cannot prove `getActiveBackgroundScan` returned
/// the stale row in the first place, and it cannot prove a real Windows
/// background worker was running in its separate process -- the case where
/// suppressing the warning would be actively harmful. Only a device run with a
/// genuinely killed background scan settles the first; the second is protected
/// by construction (Windows never suppresses) rather than by evidence.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

void main() {
  group('F207: a row is not a running scan', () {
    test('THE FIX: Android + idle coordinator means the row is stale', () {
      expect(
        shouldWarnAboutBackgroundScan(
          hasActiveRow: true,
          coordinatorIsIdle: true,
          isAndroid: true,
        ),
        isFalse,
        reason: 'on Android every scan shares one process, so an idle '
            'coordinator PROVES nothing is running and the row is a corpse',
      );
    });

    test('a genuinely live Android scan still warns', () {
      // The regression guard on the fix: this notice exists to prevent the
      // Sprint 61 concurrent-session failure, and it must keep doing that.
      expect(
        shouldWarnAboutBackgroundScan(
          hasActiveRow: true,
          coordinatorIsIdle: false,
          isAndroid: true,
        ),
        isTrue,
      );
    });

    test('THE PLATFORM EXCEPTION: Windows trusts the row even when idle', () {
      // ADR-0042 declared exception. On Windows the background worker is a
      // SEPARATE process (ADR-0039) that this coordinator cannot observe, so
      // an idle coordinator proves nothing. Suppressing here would re-open the
      // exact failure the notice prevents.
      expect(
        shouldWarnAboutBackgroundScan(
          hasActiveRow: true,
          coordinatorIsIdle: true,
          isAndroid: false,
        ),
        isTrue,
        reason: 'an idle in-process coordinator is not evidence on Windows -- '
            'the scan runs in another process entirely',
      );
    });

    test('Windows with a busy coordinator warns too', () {
      expect(
        shouldWarnAboutBackgroundScan(
          hasActiveRow: true,
          coordinatorIsIdle: false,
          isAndroid: false,
        ),
        isTrue,
      );
    });

    test('no row means no warning, on either platform', () {
      // The unhappy input: nothing to warn about. Neither the coordinator nor
      // the platform may manufacture a warning from an absent row.
      for (final android in [true, false]) {
        for (final idle in [true, false]) {
          expect(
            shouldWarnAboutBackgroundScan(
              hasActiveRow: false,
              coordinatorIsIdle: idle,
              isAndroid: android,
            ),
            isFalse,
            reason: 'isAndroid=$android, coordinatorIsIdle=$idle',
          );
        }
      }
    });

    test('ONLY the Android+idle combination is suppressed', () {
      // Stated as a truth table so a future edit that widens the suppression
      // -- for example dropping the isAndroid guard -- turns this red rather
      // than silently disabling the Windows notice.
      final suppressed = <String>[];
      for (final android in [true, false]) {
        for (final idle in [true, false]) {
          final warn = shouldWarnAboutBackgroundScan(
            hasActiveRow: true,
            coordinatorIsIdle: idle,
            isAndroid: android,
          );
          if (!warn) suppressed.add('android=$android,idle=$idle');
        }
      }
      expect(suppressed, ['android=true,idle=true'],
          reason: 'exactly one cell of the table may suppress the warning');
    });
  });
}
