import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Windows toast notification service
///
/// Provides Windows 10/11 toast notifications for background scan results.
/// Uses flutter_local_notifications for cross-platform support.
class WindowsNotificationService {
  static final WindowsNotificationService _instance = WindowsNotificationService._internal();
  factory WindowsNotificationService() => _instance;
  WindowsNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize Windows notifications
  ///
  /// Call this during app startup on Windows platform
  Future<void> initialize() async {
    if (!Platform.isWindows) {
      return; // Only initialize on Windows
    }

    if (_isInitialized) {
      return; // Already initialized
    }

    try {
      // Initialize Windows notification settings
      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
        appName: 'Spam Filter',
        appUserModelId: 'com.spamfilter.spamfiltermobile',
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        windows: initializationSettingsWindows,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
    } catch (e) {
      // Initialization failed - log but don't crash
      print('Failed to initialize Windows notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to results screen based on notification payload
    print('Notification tapped: ${response.payload}');
  }

  /// Show background scan completion notification
  ///
  /// [accountEmail] - Email account that was scanned
  /// [totalEmails] - Total emails scanned
  /// [deletedCount] - Number of emails deleted
  /// [movedCount] - Number of emails moved
  /// [errorCount] - Number of errors encountered
  Future<void> showBackgroundScanComplete({
    required String accountEmail,
    required int totalEmails,
    required int deletedCount,
    required int movedCount,
    required int errorCount,
  }) async {
    if (!_isInitialized || !Platform.isWindows) {
      return;
    }

    try {
      // Build notification summary
      final String summary = _buildScanSummary(
        totalEmails: totalEmails,
        deletedCount: deletedCount,
        movedCount: movedCount,
        errorCount: errorCount,
      );

      // Show notification
      await _notifications.show(
        0, // Notification ID
        'Background Scan Complete',
        '$accountEmail: $summary',
        const NotificationDetails(
          windows: WindowsNotificationDetails(
            subtitle: 'Spam Filter',
          ),
        ),
        payload: accountEmail, // Pass account email as payload for tap handling
      );
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  /// Show background scan error notification
  ///
  /// [accountEmail] - Email account that failed
  /// [errorMessage] - Error message
  Future<void> showBackgroundScanError({
    required String accountEmail,
    required String errorMessage,
  }) async {
    if (!_isInitialized || !Platform.isWindows) {
      return;
    }

    try {
      await _notifications.show(
        1, // Notification ID
        'Background Scan Failed',
        '$accountEmail: $errorMessage',
        const NotificationDetails(
          windows: WindowsNotificationDetails(
            subtitle: 'Spam Filter',
          ),
        ),
        payload: accountEmail,
      );
    } catch (e) {
      print('Failed to show error notification: $e');
    }
  }

  /// Build scan summary text
  String _buildScanSummary({
    required int totalEmails,
    required int deletedCount,
    required int movedCount,
    required int errorCount,
  }) {
    final List<String> parts = [];

    parts.add('Scanned $totalEmails emails');

    if (deletedCount > 0) {
      parts.add('$deletedCount deleted');
    }

    if (movedCount > 0) {
      parts.add('$movedCount moved');
    }

    if (errorCount > 0) {
      parts.add('$errorCount errors');
    }

    return parts.join(', ');
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (_isInitialized) {
      await _notifications.cancelAll();
    }
  }
}
