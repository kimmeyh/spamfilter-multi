/// F144 (Sprint 60): tests for the LIVE `ScanFrequency` enum, consolidated
/// from `background_scan_manager_test.dart` and
/// `background_scan_service_test.dart` when their host classes
/// (`BackgroundScanManager`/`BackgroundScanService`/`ScanScheduleStatus` --
/// the unwired pre-architecture Android scheduler) were removed. The enum
/// itself moved to `scan_frequency.dart`: it is the frequency vocabulary of
/// the CURRENT Windows Task Scheduler path and settings UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/scan_frequency.dart';

void main() {
  group('ScanFrequency', () {
    test('each value carries its minutes and label', () {
      expect(ScanFrequency.disabled.minutes, 0);
      expect(ScanFrequency.disabled.label, 'Disabled');
      expect(ScanFrequency.every15min.minutes, 15);
      expect(ScanFrequency.every15min.label, '15 minutes');
      expect(ScanFrequency.every30min.minutes, 30);
      expect(ScanFrequency.every30min.label, '30 minutes');
      expect(ScanFrequency.every1hour.minutes, 60);
      expect(ScanFrequency.every1hour.label, '1 hour');
      expect(ScanFrequency.daily.minutes, 1440);
      expect(ScanFrequency.daily.label, 'Daily');
    });

    test('minute values are unique and ascending', () {
      final minutes = ScanFrequency.values.map((f) => f.minutes).toList();
      expect(minutes.toSet().length, minutes.length,
          reason: 'duplicate minute values would make fromMinutes ambiguous');
      final sorted = List<int>.from(minutes)..sort();
      expect(minutes, sorted);
    });

    test('labels are non-empty', () {
      for (final f in ScanFrequency.values) {
        expect(f.label, isNotEmpty);
      }
    });

    test('fromMinutes returns the matching enum for every valid value', () {
      for (final f in ScanFrequency.values) {
        expect(ScanFrequency.fromMinutes(f.minutes), f);
      }
    });

    test('fromMinutes returns disabled for unknown minutes', () {
      expect(ScanFrequency.fromMinutes(99), ScanFrequency.disabled);
      expect(ScanFrequency.fromMinutes(-1), ScanFrequency.disabled);
      expect(ScanFrequency.fromMinutes(1000), ScanFrequency.disabled);
    });
  });
}
