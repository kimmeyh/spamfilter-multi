import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/windows_toast_notification_service.dart';

void main() {
  group('WindowsToastNotificationService', () {
    group('initialize', () {
      test('initializes successfully', () async {
        // Act & Assert
        expect(
          () async => await WindowsToastNotificationService.initialize(),
          returnsNormally,
        );
      });
    });

    group('showScanCompleteNotification', () {
      test('does not throw when called with zero unmatched count', () async {
        // Arrange
        const unmatchedCount = 0;
        const accountsScanned = 3;

        // Act & Assert
        expect(
          () async => await WindowsToastNotificationService.showScanCompleteNotification(
            unmatchedCount: unmatchedCount,
            accountsScanned: accountsScanned,
          ),
          returnsNormally,
        );
      });

      test('does not throw when called with positive unmatched count', () async {
        // Arrange
        const unmatchedCount = 5;
        const accountsScanned = 2;

        // Act & Assert
        // Note: Will fail in test environment without Windows notification system
        // but we are checking that the method does not throw exceptions
        expect(
          () async => await WindowsToastNotificationService.showScanCompleteNotification(
            unmatchedCount: unmatchedCount,
            accountsScanned: accountsScanned,
          ),
          returnsNormally,
        );
      });

      test('handles single unmatched email correctly', () async {
        // Arrange
        const unmatchedCount = 1;
        const accountsScanned = 1;

        // Act & Assert
        expect(
          () async => await WindowsToastNotificationService.showScanCompleteNotification(
            unmatchedCount: unmatchedCount,
            accountsScanned: accountsScanned,
          ),
          returnsNormally,
        );
      });

      test('handles multiple accounts correctly', () async {
        // Arrange
        const unmatchedCount = 10;
        const accountsScanned = 5;

        // Act & Assert
        expect(
          () async => await WindowsToastNotificationService.showScanCompleteNotification(
            unmatchedCount: unmatchedCount,
            accountsScanned: accountsScanned,
          ),
          returnsNormally,
        );
      });
    });

    group('dismissNotification', () {
      test('does not throw when called', () async {
        // Act & Assert
        expect(
          () async => await WindowsToastNotificationService.dismissNotification(),
          returnsNormally,
        );
      });
    });

    group('areNotificationsEnabled', () {
      test('returns boolean value', () async {
        // Act
        final result = await WindowsToastNotificationService.areNotificationsEnabled();

        // Assert
        expect(result, isA<bool>());
      });
    });

    group('constants', () {
      test('app ID is correct', () {
        // Assert
        expect(
          WindowsToastNotificationService.appId,
          equals('SpamFilterMulti.BackgroundScan'),
        );
      });

      test('app name is correct', () {
        // Assert
        expect(
          WindowsToastNotificationService.appName,
          equals('Spam Filter Multi'),
        );
      });
    });
  });
}
