import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/background_scan_notification_service.dart';

void main() {
  group('ScanOptimizationChecks', () {
    test('isBatteryLevelSufficient returns true by default', () async {
      final result = await ScanOptimizationChecks.isBatteryLevelSufficient();
      expect(result, true);
    });

    test('isBatteryLevelSufficient accepts custom threshold', () async {
      final result = await ScanOptimizationChecks.isBatteryLevelSufficient(
        minBatteryPercent: 50,
      );
      expect(result, true);
    });

    test('isNetworkConnected returns true by default', () async {
      final result = await ScanOptimizationChecks.isNetworkConnected();
      expect(result, true);
    });

    test('shouldSkipOnCellular returns false when WiFi-only is disabled', () async {
      final result = await ScanOptimizationChecks.shouldSkipOnCellular(
        wifiOnlyMode: false,
      );
      expect(result, false);
    });

    test('shouldSkipOnCellular returns false when WiFi-only is enabled', () async {
      final result = await ScanOptimizationChecks.shouldSkipOnCellular(
        wifiOnlyMode: true,
      );
      expect(result, false);
    });

    test('canProceedWithScan returns true when all checks pass', () async {
      final result = await ScanOptimizationChecks.canProceedWithScan();
      expect(result, true);
    });

    test('canProceedWithScan with custom battery threshold succeeds', () async {
      final result = await ScanOptimizationChecks.canProceedWithScan(
        minBatteryPercent: 25,
      );
      expect(result, true);
    });

    test('canProceedWithScan with WiFi-only mode succeeds', () async {
      final result = await ScanOptimizationChecks.canProceedWithScan(
        wifiOnlyMode: true,
      );
      expect(result, true);
    });

    test('canProceedWithScan with both custom parameters succeeds', () async {
      final result = await ScanOptimizationChecks.canProceedWithScan(
        minBatteryPercent: 15,
        wifiOnlyMode: true,
      );
      expect(result, true);
    });
  });

  group('BackgroundScanNotificationService', () {
    // Note: BackgroundScanNotificationService methods initialize the FlutterLocalNotificationsPlugin
    // which requires platform-specific setup (Android, iOS). Unit tests can only verify that
    // methods do not throw exceptions.

    test('initialize does not throw', () async {
      expect(
        () async => await BackgroundScanNotificationService.initialize(),
        returnsNormally,
      );
    });

    test('dismissNotification does not throw', () async {
      expect(
        () async => await BackgroundScanNotificationService.dismissNotification(),
        returnsNormally,
      );
    });

    test(
      'showScanCompletionNotification with zero unmatched count does not show',
      () async {
        expect(
          () async =>
              await BackgroundScanNotificationService.showScanCompletionNotification(
            accountEmail: 'test@gmail.com',
            unmatchedCount: 0,
          ),
          returnsNormally,
        );
      },
    );

    test(
      'showScanCompletionNotification with unmatched emails does not throw',
      () async {
        expect(
          () async =>
              await BackgroundScanNotificationService.showScanCompletionNotification(
            accountEmail: 'test@gmail.com',
            unmatchedCount: 5,
          ),
          returnsNormally,
        );
      },
    );

    test('showScanInProgressNotification does not throw', () async {
      expect(
        () async =>
            await BackgroundScanNotificationService.showScanInProgressNotification(
          accountEmail: 'test@gmail.com',
        ),
        returnsNormally,
      );
    });

    test('showScanErrorNotification does not throw', () async {
      expect(
        () async =>
            await BackgroundScanNotificationService.showScanErrorNotification(
          accountEmail: 'test@gmail.com',
          errorMessage: 'Connection timeout',
        ),
        returnsNormally,
      );
    });

    test('multiple notification calls do not throw', () async {
      expect(
        () async {
          await BackgroundScanNotificationService.initialize();
          await BackgroundScanNotificationService.showScanInProgressNotification(
            accountEmail: 'test@gmail.com',
          );
          await BackgroundScanNotificationService.showScanCompletionNotification(
            accountEmail: 'test@gmail.com',
            unmatchedCount: 3,
          );
          await BackgroundScanNotificationService.dismissNotification();
        },
        returnsNormally,
      );
    });
  });
}
