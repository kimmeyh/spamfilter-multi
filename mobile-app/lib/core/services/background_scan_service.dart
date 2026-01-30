import 'package:logger/logger.dart';
import 'background_scan_manager.dart';
import 'background_scan_worker.dart';
import 'background_scan_notification_service.dart';

/// High-level service for managing background scanning with optimization checks
class BackgroundScanService {
  static final Logger _logger = Logger();

  /// Initialize background scanning with user preferences
  /// Includes battery and network optimization checks
  static Future<void> initializeWithPreferences({
    required ScanFrequency frequency,
    int minBatteryPercent = 20,
    bool wifiOnlyMode = false,
  }) async {
    try {
      _logger.i('Initializing background scan service with frequency: ${frequency.label}');

      // Initialize notifications
      await BackgroundScanNotificationService.initialize();

      // Schedule scanning if frequency is not disabled
      if (frequency != ScanFrequency.disabled) {
        await BackgroundScanManager.scheduleBackgroundScans(frequency: frequency);
        _logger.i('Background scanning scheduled: ${frequency.label}');
      } else {
        await BackgroundScanManager.cancelBackgroundScans();
        _logger.i('Background scanning disabled');
      }
    } catch (e) {
      _logger.e('Failed to initialize background scan service', error: e);
      rethrow;
    }
  }

  /// Update scanning frequency with optimization checks
  static Future<void> updateFrequency(
    ScanFrequency newFrequency, {
    int minBatteryPercent = 20,
    bool wifiOnlyMode = false,
  }) async {
    try {
      _logger.i('Updating scan frequency to: ${newFrequency.label}');

      // Check optimization constraints
      final canProceed = await ScanOptimizationChecks.canProceedWithScan(
        minBatteryPercent: minBatteryPercent,
        wifiOnlyMode: wifiOnlyMode,
      );

      if (!canProceed) {
        _logger.w('Cannot proceed with scan due to optimization constraints');
        throw Exception('Battery or network constraints prevent scanning');
      }

      if (newFrequency == ScanFrequency.disabled) {
        await BackgroundScanManager.cancelBackgroundScans();
        _logger.i('Background scanning disabled');
      } else {
        await BackgroundScanManager.scheduleBackgroundScans(frequency: newFrequency);
        _logger.i('Background scanning updated to: ${newFrequency.label}');
      }
    } catch (e) {
      _logger.e('Failed to update scan frequency', error: e);
      rethrow;
    }
  }

  /// Get current scheduling status with optimization info
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final scheduleStatus = await BackgroundScanManager.getScheduleStatus();
      final batteryOk = await ScanOptimizationChecks.isBatteryLevelSufficient();
      final networkOk = await ScanOptimizationChecks.isNetworkConnected();

      return {
        'isScheduled': scheduleStatus.isScheduled,
        'frequency': scheduleStatus.frequency?.label,
        'nextScheduledTime': scheduleStatus.nextScheduledTime,
        'lastRunTime': scheduleStatus.lastRunTime,
        'batteryOk': batteryOk,
        'networkOk': networkOk,
        'canProceed': batteryOk && networkOk,
      };
    } catch (e) {
      _logger.e('Failed to get background scan status', error: e);
      rethrow;
    }
  }

  /// Disable all background scanning and cleanup
  static Future<void> disable() async {
    try {
      _logger.i('Disabling background scanning');
      await BackgroundScanManager.cancelBackgroundScans();
      await BackgroundScanNotificationService.dismissNotification();
      _logger.i('Background scanning disabled and cleaned up');
    } catch (e) {
      _logger.e('Failed to disable background scanning', error: e);
      rethrow;
    }
  }
}
