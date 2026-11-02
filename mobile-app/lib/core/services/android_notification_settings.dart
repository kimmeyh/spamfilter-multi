import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// F322 (Sprint 83): opens Android's notification settings page for this app,
/// where the scan notification channels ("Scans with No Rule items", "Scans
/// with nothing to review") are listed and the user can silence one.
///
/// ADR-0042 / ADR-0049: Android only (declared exception, `ScanCompleteNotifier`
/// "choice"). The native side is `MainActivity` (`ACTION_APP_NOTIFICATION_SETTINGS`,
/// API 26+; older Android falls back to the app's App info page).
///
/// Never throws: a failure returns false and is logged, and the Settings row
/// tells the user the page could not be opened.
class AndroidNotificationSettings {
  static const MethodChannel _channel =
      MethodChannel('com.myemailspamfilter/notification_settings');

  static final Logger _logger = Logger();

  /// Test seam: tests stub this channel's handler.
  @visibleForTesting
  static MethodChannel get channel => _channel;

  /// Opens the page. Returns false when it could not be opened.
  static Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('openAppNotificationSettings') ??
          false;
    } catch (e) {
      _logger.w('Could not open the Android notification settings: $e');
      return false;
    }
  }
}
