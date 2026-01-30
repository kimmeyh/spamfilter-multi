import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/background_scan_manager.dart';

void main() {
  group('ScanFrequency', () {
    test('ScanFrequency.disabled has correct values', () {
      expect(ScanFrequency.disabled.minutes, 0);
      expect(ScanFrequency.disabled.label, 'Disabled');
    });

    test('ScanFrequency.every15min has correct values', () {
      expect(ScanFrequency.every15min.minutes, 15);
      expect(ScanFrequency.every15min.label, '15 minutes');
    });

    test('ScanFrequency.every30min has correct values', () {
      expect(ScanFrequency.every30min.minutes, 30);
      expect(ScanFrequency.every30min.label, '30 minutes');
    });

    test('ScanFrequency.every1hour has correct values', () {
      expect(ScanFrequency.every1hour.minutes, 60);
      expect(ScanFrequency.every1hour.label, '1 hour');
    });

    test('ScanFrequency.daily has correct values', () {
      expect(ScanFrequency.daily.minutes, 1440);
      expect(ScanFrequency.daily.label, 'Daily');
    });

    test('ScanFrequency.fromMinutes returns correct enum for valid minutes', () {
      expect(ScanFrequency.fromMinutes(0), ScanFrequency.disabled);
      expect(ScanFrequency.fromMinutes(15), ScanFrequency.every15min);
      expect(ScanFrequency.fromMinutes(30), ScanFrequency.every30min);
      expect(ScanFrequency.fromMinutes(60), ScanFrequency.every1hour);
      expect(ScanFrequency.fromMinutes(1440), ScanFrequency.daily);
    });

    test('ScanFrequency.fromMinutes returns disabled for unknown minutes', () {
      expect(ScanFrequency.fromMinutes(99), ScanFrequency.disabled);
      expect(ScanFrequency.fromMinutes(-1), ScanFrequency.disabled);
      expect(ScanFrequency.fromMinutes(1000), ScanFrequency.disabled);
    });
  });

  group('ScanScheduleStatus', () {
    test('ScanScheduleStatus toString shows disabled message when not scheduled', () {
      final status = ScanScheduleStatus(isScheduled: false);
      expect(status.toString(), 'Background scanning is disabled');
    });

    test('ScanScheduleStatus toString shows frequency when scheduled', () {
      final status = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every15min,
      );
      expect(status.toString(), contains('Scheduled every 15 minutes'));
    });

    test('ScanScheduleStatus toString includes next run time when available', () {
      final nextRun = DateTime.now().add(Duration(minutes: 15));
      final status = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every15min,
        nextScheduledTime: nextRun,
      );
      final output = status.toString();
      expect(output, contains('Scheduled every 15 minutes'));
      expect(output, contains('next run'));
    });

    test('ScanScheduleStatus stores all fields correctly', () {
      final now = DateTime.now();
      final nextRun = now.add(Duration(hours: 1));
      final lastRun = now.subtract(Duration(hours: 1));

      final status = ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every1hour,
        nextScheduledTime: nextRun,
        lastRunTime: lastRun,
      );

      expect(status.isScheduled, true);
      expect(status.frequency, ScanFrequency.every1hour);
      expect(status.nextScheduledTime, nextRun);
      expect(status.lastRunTime, lastRun);
    });
  });

  group('BackgroundScanManager', () {
    test('isValidFrequency returns true for valid frequencies', () {
      expect(BackgroundScanManager.isValidFrequency(0), true);
      expect(BackgroundScanManager.isValidFrequency(15), true);
      expect(BackgroundScanManager.isValidFrequency(30), true);
      expect(BackgroundScanManager.isValidFrequency(60), true);
      expect(BackgroundScanManager.isValidFrequency(1440), true);
    });

    test('isValidFrequency returns false for invalid frequencies', () {
      expect(BackgroundScanManager.isValidFrequency(-1), false);
      expect(BackgroundScanManager.isValidFrequency(5), false);
      expect(BackgroundScanManager.isValidFrequency(45), false);
      expect(BackgroundScanManager.isValidFrequency(99), false);
      expect(BackgroundScanManager.isValidFrequency(2000), false);
    });

    test('all ScanFrequency values are valid', () {
      for (final freq in ScanFrequency.values) {
        expect(
          BackgroundScanManager.isValidFrequency(freq.minutes),
          true,
          reason: 'Frequency ${freq.label} with ${freq.minutes} minutes should be valid',
        );
      }
    });

    // Note: scheduleBackgroundScans and cancelBackgroundScans cannot be easily tested
    // without mocking WorkManager, which requires platform-specific setup.
    // These are tested in integration tests instead.

    test('getScheduleStatus does not throw', () async {
      expect(
        () async => await BackgroundScanManager.getScheduleStatus(),
        returnsNormally,
      );
    });

    test('getNextScheduledTime returns a DateTime or null', () async {
      final time = await BackgroundScanManager.getNextScheduledTime();
      expect(time, anyOf(isA<DateTime>(), isNull));
    });
  });
}
