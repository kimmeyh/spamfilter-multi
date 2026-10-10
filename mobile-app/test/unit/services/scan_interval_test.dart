/// F264 (Sprint 77) T-1: the interval model -- conversion, validation, label,
/// the upgrade conversion ([ScanInterval.nearestValid]) and the floor's tie to
/// the scan spacing. F281 (Sprint 78): the maximum is 24 hours (was 99).
///
/// What these do NOT catch: a scheduler (Task Scheduler, WorkManager, the Doze
/// alarm) accepting the value, or a UI that fails to call these helpers -- the
/// widget test `f264_interval_control_test.dart` and phone validation cover
/// those.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/scan_interval.dart';

void main() {
  group('validate (AC-1)', () {
    test('4 minutes fails with the exact message', () {
      expect(ScanInterval.validate(4), 'Minimum is 5 minutes, to limit battery use');
      expect(ScanInterval.validate(0), kIntervalTooShortMessage);
      expect(ScanInterval.validate(-3), kIntervalTooShortMessage);
    });

    test('the limits themselves pass', () {
      expect(ScanInterval.validate(5), isNull);
      expect(ScanInterval.validate(99), isNull);
      expect(ScanInterval.validate(24 * 60), isNull);
    });

    test('F281 AC-2: 24 hours plus one minute fails with the exact message', () {
      expect(ScanInterval.validate(24 * 60 + 1), 'Maximum is 24 hours');
      expect(ScanInterval.validate(25 * 60), kIntervalTooLongMessage);
      expect(ScanInterval.validate(99 * 60), kIntervalTooLongMessage,
          reason: 'the F264 maximum is no longer allowed');
    });
  });

  group('conversion and label (AC-1)', () {
    test('toMinutes is number x unit', () {
      expect(ScanInterval.toMinutes(ScanIntervalUnit.hours, 2), 120);
      expect(ScanInterval.toMinutes(ScanIntervalUnit.minutes, 45), 45);
      expect(ScanInterval.toMinutes(ScanIntervalUnit.hours, 24), 1440);
    });

    test('label', () {
      expect(ScanInterval.label(120), '2 hours');
      expect(ScanInterval.label(5), '5 minutes');
      expect(ScanInterval.label(60), '1 hour');
      expect(ScanInterval.label(90), '90 minutes');
      expect(ScanInterval.label(1440), '24 hours');
    });

    test('split shows whole hours as hours and everything else as minutes', () {
      expect(ScanInterval.split(60), (unit: ScanIntervalUnit.hours, number: 1));
      expect(ScanInterval.split(240), (unit: ScanIntervalUnit.hours, number: 4));
      expect(ScanInterval.split(90), (unit: ScanIntervalUnit.minutes, number: 90));
      expect(ScanInterval.split(15), (unit: ScanIntervalUnit.minutes, number: 15));
    });

    test('split then toMinutes round-trips every representable value', () {
      for (var m = kMinIntervalMinutes; m <= kMaxIntervalMinutes; m++) {
        if (!ScanInterval.isRepresentable(m)) continue;
        final s = ScanInterval.split(m);
        expect(ScanInterval.toMinutes(s.unit, s.number), m, reason: '$m');
        expect(s.number, inInclusiveRange(1, kMaxIntervalNumber), reason: '$m');
      }
    });
  });

  group('the upgrade conversion (nearestValid), Q11', () {
    test('every value the OLD Settings list offered is kept as is', () {
      // 15/30/60/120/240 (and the old enum's daily, 1440) are all typable.
      for (final m in [15, 30, 60, 120, 240, 1440]) {
        expect(ScanInterval.nearestValid(m), m);
        expect(ScanInterval.isRepresentable(m), isTrue);
      }
    });

    test('out of range clamps to the nearest limit', () {
      expect(ScanInterval.nearestValid(0), 5);
      expect(ScanInterval.nearestValid(-10), 5);
      expect(ScanInterval.nearestValid(3), 5);
      expect(ScanInterval.nearestValid(1441), 1440);
    });

    test('F281 AC-4 (F1 = 1): a stored F264 value above 24 hours becomes 24 hours',
        () {
      expect(ScanInterval.nearestValid(5940), 1440, reason: '99 hours');
      expect(ScanInterval.nearestValid(25 * 60), 1440);
      expect(ScanInterval.reconcileStored(5940),
          (minutes: 1440, converted: true));
    });

    test('a value the control cannot type maps to the nearest one it can', () {
      expect(ScanInterval.nearestValid(100), 99, reason: '99 minutes is closer than 2 hours');
      expect(ScanInterval.nearestValid(125), 120);
      expect(ScanInterval.nearestValid(119), 120);
      expect(ScanInterval.nearestValid(179), 180);
      expect(ScanInterval.nearestValid(1439), 1440);
    });

    test('a tie goes to the LONGER interval (less battery)', () {
      expect(ScanInterval.nearestValid(150), 180); // 120 and 180 are equally near
    });

    test('the result is always representable and never moves a typable value',
        () {
      for (var m = -5; m <= kMaxIntervalMinutes + 50; m++) {
        final n = ScanInterval.nearestValid(m);
        expect(ScanInterval.isRepresentable(n), isTrue, reason: '$m -> $n');
        if (ScanInterval.isRepresentable(m)) expect(n, m, reason: '$m');
      }
    });

    test('reconcileStored reports whether it converted', () {
      expect(ScanInterval.reconcileStored(240), (minutes: 240, converted: false));
      expect(ScanInterval.reconcileStored(3), (minutes: 5, converted: true));
    });
  });

  group('the floor and the jitter rule', () {
    test('AC-13: the floor is not below the scan spacing', () {
      expect(kMinIntervalMinutes * 60,
          greaterThanOrEqualTo(BackgroundScanCore.kMinScanSpacing.inSeconds),
          reason: 'a background scan waits until kMinScanSpacing after the '
              'last one; an interval below it would make every scan wait');
    });

    test('Q13: jitter only above 15 minutes', () {
      expect(ScanInterval.hasJitter(5), isFalse);
      expect(ScanInterval.hasJitter(15), isFalse);
      expect(ScanInterval.hasJitter(16), isTrue);
      expect(ScanInterval.hasJitter(1440), isTrue);
    });

    test('the jitter cannot pull a firing inside the scan spacing', () {
      // The shortest jittered interval (16) minus the largest advance.
      expect(kJitterThresholdMinutes + 1 - 2 * kJitterMinutes,
          greaterThanOrEqualTo(kMinIntervalMinutes),
          reason: 'a Windows trigger with a 10 minute RandomDelay can fire up '
              'to 10 minutes after the nominal time, so consecutive firings '
              'can be as close as interval - 10 minutes');
    });

    test('WorkManager keeps its documented 15 minute minimum, alone', () {
      expect(ScanInterval.workManagerMinutes(5), 15);
      expect(ScanInterval.workManagerMinutes(14), 15);
      expect(ScanInterval.workManagerMinutes(15), 15);
      expect(ScanInterval.workManagerMinutes(120), 120);
    });
  });
}
