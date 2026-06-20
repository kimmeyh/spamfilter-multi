import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';
import 'background_scan_worker.dart';

/// Frequency options for background scanning
enum ScanFrequency {
  disabled(0, 'Disabled'),
  every15min(15, '15 minutes'),
  every30min(30, '30 minutes'),
  every1hour(60, '1 hour'),
  daily(1440, 'Daily');

  final int minutes;
  final String label;

  const ScanFrequency(this.minutes, this.label);

  static ScanFrequency fromMinutes(int minutes) {
    return values.firstWhere(
      (f) => f.minutes == minutes,
      orElse: () => ScanFrequency.disabled,
    );
  }
}

/// Status of background scan schedule
class ScanScheduleStatus {
  final bool isScheduled;
  final ScanFrequency? frequency;
  final DateTime? nextScheduledTime;
  final DateTime? lastRunTime;

  ScanScheduleStatus({
    required this.isScheduled,
    this.frequency,
    this.nextScheduledTime,
    this.lastRunTime,
  });

  @override
  String toString() {
    if (!isScheduled) {
      return 'Background scanning is disabled';
    }
    return 'Scheduled every ${frequency?.label ?? "unknown"}'
        '${nextScheduledTime != null ? ', next run: $nextScheduledTime' : ''}';
  }
}

/// Manager for background email scanning
/// Handles scheduling, cancellation, and status queries
class BackgroundScanManager {
  static final Logger _logger = Logger();

  /// Unique WorkManager task name for an account (F98 / ADR-0039):
  /// `background_scan_task::<accountId>`. Null -> the legacy global name.
  static String taskNameFor(String? accountId) =>
      accountId == null ? backgroundScanTaskId : '$backgroundScanTaskId::$accountId';

  /// Schedule background scans at specified frequency.
  /// Call this when user enables background scanning or changes frequency.
  ///
  /// F98: when [accountId] is non-null, registers a UNIQUELY NAMED periodic task
  /// for that account, carrying the accountId in inputData so the dispatcher
  /// scans only that account.
  static Future<void> scheduleBackgroundScans({
    required ScanFrequency frequency,
    String? accountId,
  }) async {
    if (frequency == ScanFrequency.disabled) {
      // Disable scanning
      return cancelBackgroundScans(accountId: accountId);
    }

    try {
      // Initialize WorkManager if needed
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      final taskName = taskNameFor(accountId);
      _logger.i('Scheduling background scans every ${frequency.minutes} minutes'
          '${accountId != null ? ' for account $accountId' : ''}');

      // Register periodic task with WorkManager
      await Workmanager().registerPeriodicTask(
        taskName,
        backgroundScanTaskId,
        frequency: Duration(minutes: frequency.minutes),
        initialDelay: Duration(minutes: 1), // Start after 1 minute
        backoffPolicy: BackoffPolicy.exponential,
        inputData: accountId != null ? {'account_id': accountId} : null,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      _logger.i('Background scans scheduled successfully');
    } catch (e) {
      _logger.e('Failed to schedule background scans', error: e);
      rethrow;
    }
  }

  /// Cancel background scanning.
  /// Call this when user disables background scanning.
  ///
  /// F98: when [accountId] is non-null, cancels only that account's uniquely
  /// named task.
  static Future<void> cancelBackgroundScans({String? accountId}) async {
    try {
      final taskName = taskNameFor(accountId);
      _logger.i('Cancelling background scans'
          '${accountId != null ? ' for account $accountId' : ''}');

      // Initialize WorkManager if needed
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      // Cancel the periodic task by its unique name.
      await Workmanager().cancelByUniqueName(taskName);

      _logger.i('Background scans cancelled successfully');
    } catch (e) {
      _logger.e('Failed to cancel background scans', error: e);
      rethrow;
    }
  }

  /// Get current schedule status
  static Future<ScanScheduleStatus> getScheduleStatus() async {
    try {
      // In a real implementation, we would query the WorkManager or local storage
      // For now, return a default status
      // This should be enhanced to query actual WorkManager state

      // Try to get from WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      // Note: WorkManager doesn't provide direct status query API
      // In production, you would maintain this in shared preferences or database
      // For MVP, we assume if no error, the task is scheduled

      return ScanScheduleStatus(
        isScheduled: true,
        frequency: ScanFrequency.every15min, // Default for demo
        nextScheduledTime: DateTime.now().add(Duration(minutes: 15)),
      );
    } catch (e) {
      _logger.w('Failed to get schedule status', error: e);
      return ScanScheduleStatus(isScheduled: false);
    }
  }

  /// Get the next scheduled execution time
  /// Returns null if scanning is disabled
  static Future<DateTime?> getNextScheduledTime() async {
    try {
      final status = await getScheduleStatus();
      return status.nextScheduledTime;
    } catch (e) {
      _logger.e('Failed to get next scheduled time', error: e);
      return null;
    }
  }

  /// Validate frequency is supported
  static bool isValidFrequency(int minutes) {
    return ScanFrequency.values
        .any((freq) => freq.minutes == minutes);
  }
}
