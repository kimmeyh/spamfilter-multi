import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

/// Service for background scan notifications
class BackgroundScanNotificationService {
  static final Logger _logger = Logger();
  static const int _notificationId = 1;
  static const String _channelId = 'background_scan_channel';
  static const String _channelName = 'Background Scan Notifications';

  static late FlutterLocalNotificationsPlugin _plugin;

  /// Initialize notification service
  static Future<void> initialize() async {
    try {
      _plugin = FlutterLocalNotificationsPlugin();

      // Android initialization
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosInitSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      await _plugin.initialize(initSettings);

      // Create notification channel for Android
      await _createNotificationChannel();

      _logger.i('Notification service initialized');
    } catch (e) {
      _logger.e('Failed to initialize notification service', error: e);
    }
  }

  /// Create Android notification channel
  static Future<void> _createNotificationChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notifications for background email scans',
        importance: Importance.defaultImportance,
        showBadge: true,
        enableVibration: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _logger.d('Notification channel created');
    } catch (e) {
      _logger.e('Failed to create notification channel', error: e);
    }
  }

  /// Show notification for background scan completion
  /// Only shows if unmatched_count > 0
  static Future<void> showScanCompletionNotification({
    required String accountEmail,
    required int unmatchedCount,
    void Function()? onTap,
  }) async {
    if (unmatchedCount == 0) {
      _logger.d('No unmatched emails found, skipping notification');
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Background scan notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        enableVibration: true,
        showProgress: false,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = 'Background Scan Complete';
      final body = '$accountEmail: $unmatchedCount unmatched email'
          '${unmatchedCount > 1 ? 's' : ''}';

      await _plugin.show(
        _notificationId,
        title,
        body,
        notificationDetails,
        payload: 'background_scan_result',
      );

      _logger.i('Scan completion notification shown: $body');
    } catch (e) {
      _logger.e('Failed to show scan completion notification', error: e);
    }
  }

  /// Show notification for scan in progress
  static Future<void> showScanInProgressNotification({
    required String accountEmail,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Background scan notifications',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        autoCancel: false,
        enableVibration: false,
        showProgress: true,
        maxProgress: 100,
        progress: 0,
        indeterminate: true,
        silent: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        _notificationId,
        'Background Scan In Progress',
        'Scanning $accountEmail...',
        notificationDetails,
      );

      _logger.d('Scan in progress notification shown');
    } catch (e) {
      _logger.e('Failed to show scan in progress notification', error: e);
    }
  }

  /// Show notification for scan error
  static Future<void> showScanErrorNotification({
    required String accountEmail,
    required String errorMessage,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Background scan notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        _notificationId,
        'Background Scan Error',
        'Failed to scan $accountEmail: $errorMessage',
        notificationDetails,
        payload: 'background_scan_error',
      );

      _logger.w('Scan error notification shown: $errorMessage');
    } catch (e) {
      _logger.e('Failed to show scan error notification', error: e);
    }
  }

  /// Dismiss any active notifications
  static Future<void> dismissNotification() async {
    try {
      await _plugin.cancel(_notificationId);
      _logger.d('Notification dismissed');
    } catch (e) {
      _logger.e('Failed to dismiss notification', error: e);
    }
  }
}

/// Battery and network optimization checks
class ScanOptimizationChecks {
  static final Logger _logger = Logger();

  /// Check if device battery level is sufficient for scanning
  /// Returns true if battery >= threshold (default 20%)
  static Future<bool> isBatteryLevelSufficient({int minBatteryPercent = 20}) async {
    try {
      // Note: In a real implementation, you would use the battery_plus package
      // For now, return true (optimization not implemented in MVP)
      _logger.d('Battery check: Assuming sufficient battery level');
      return true;
    } catch (e) {
      _logger.e('Failed to check battery level', error: e);
      return false;
    }
  }

  /// Check if network connectivity is sufficient for scanning
  /// Returns true if WiFi connected or mobile data available
  static Future<bool> isNetworkConnected() async {
    try {
      // Note: In a real implementation, you would use the connectivity_plus package
      // For now, return true (assuming network available)
      _logger.d('Network check: Assuming network connectivity');
      return true;
    } catch (e) {
      _logger.e('Failed to check network connectivity', error: e);
      return false;
    }
  }

  /// Check if WiFi-only mode would prevent scanning on cellular
  static Future<bool> shouldSkipOnCellular({bool wifiOnlyMode = false}) async {
    if (!wifiOnlyMode) {
      return false;
    }

    try {
      // Note: Use connectivity_plus to check if on cellular
      // For now, return false (allow scanning)
      _logger.d('WiFi-only check: Allowing scan (assuming WiFi)');
      return false;
    } catch (e) {
      _logger.e('Failed to check connectivity type', error: e);
      return false;
    }
  }

  /// Comprehensive check for whether scan should proceed
  static Future<bool> canProceedWithScan({
    int minBatteryPercent = 20,
    bool wifiOnlyMode = false,
  }) async {
    final batteryOk = await isBatteryLevelSufficient(
      minBatteryPercent: minBatteryPercent,
    );
    final networkOk = await isNetworkConnected();
    final noWifiOnlyRestriction = !await shouldSkipOnCellular(
      wifiOnlyMode: wifiOnlyMode,
    );

    final canProceed = batteryOk && networkOk && noWifiOnlyRestriction;
    _logger.d(
      'Scan optimization check: '
      'battery=$batteryOk, network=$networkOk, wifiOk=$noWifiOnlyRestriction '
      '→ proceed=$canProceed',
    );

    return canProceed;
  }
}
