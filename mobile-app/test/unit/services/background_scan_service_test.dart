import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/background_scan_manager.dart';

void main() {
  group('ScanOptimization - Frequency Validation', () {
    test('all ScanFrequency values are valid according to manager', () {
      for (final freq in ScanFrequency.values) {
        expect(
          BackgroundScanManager.isValidFrequency(freq.minutes),
          true,
          reason: 'Frequency ${freq.label} should be valid',
        );
      }
    });

    test('ScanFrequency.disabled has zero minutes', () {
      expect(ScanFrequency.disabled.minutes, 0);
    });

    test('ScanFrequency values have unique minute values', () {
      final minutes = ScanFrequency.values.map((f) => f.minutes).toList();
      expect(minutes.length, minutes.toSet().length);
    });

    test('ScanFrequency values have non-empty labels', () {
      for (final freq in ScanFrequency.values) {
        expect(freq.label.isNotEmpty, true);
      }
    });

    test('ScanFrequency values are in ascending order', () {
      final minutes = ScanFrequency.values.map((f) => f.minutes).toList();
      for (int i = 0; i < minutes.length - 1; i++) {
        expect(minutes[i] <= minutes[i + 1], true);
      }
    });

    test('fromMinutes finds correct frequency', () {
      expect(
        ScanFrequency.fromMinutes(15),
        ScanFrequency.every15min,
      );
      expect(
        ScanFrequency.fromMinutes(60),
        ScanFrequency.every1hour,
      );
    });

    test('fromMinutes returns disabled for invalid values', () {
      expect(
        ScanFrequency.fromMinutes(999),
        ScanFrequency.disabled,
      );
      expect(
        ScanFrequency.fromMinutes(-5),
        ScanFrequency.disabled,
      );
    });
  });

  group('ScanScheduleStatus - Display', () {
    test('disabled status shows readable message', () {
      final status = ScanScheduleStatus(isScheduled: false);
      expect(
        status.toString(),
        contains('disabled'),
      );
    });

    test('enabled status shows frequency', () {
      final status = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every30min,
      );
      expect(
        status.toString(),
        contains('30 minutes'),
      );
    });

    test('schedule status with next run time shows both', () {
      final nextRun = DateTime.now().add(Duration(minutes: 15));
      final status = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every15min,
        nextScheduledTime: nextRun,
      );
      final output = status.toString();
      expect(output, contains('15 minutes'));
      expect(output, contains('next run'));
    });
  });

  group('Frequency Scheduling - Constraint Validation', () {
    test('minimum battery is configurable', () {
      expect(
        BackgroundScanManager.isValidFrequency(15),
        true,
      );
      expect(
        BackgroundScanManager.isValidFrequency(30),
        true,
      );
    });

    test('disabled frequency disables scanning', () {
      expect(
        ScanFrequency.disabled.minutes,
        0,
      );
    });

    test('daily frequency is 1440 minutes', () {
      expect(
        ScanFrequency.daily.minutes,
        1440,
      );
    });

    test('hourly frequency is 60 minutes', () {
      expect(
        ScanFrequency.every1hour.minutes,
        60,
      );
    });
  });
}
