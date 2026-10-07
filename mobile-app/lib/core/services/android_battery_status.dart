import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// F252 (Sprint 76): read whether Android exempts this app from battery
/// optimization, and open the page where the user changes it.
///
/// **Why it matters.** Android's own guidance: an app on the exemption list
/// "can use the network and hold partial wake locks during Doze", and such apps
/// "bypass bucket-based restrictions entirely" -- the App Standby limits that
/// cut an app the user does not open to one job a day. A spam filter that runs
/// unattended is exactly that app, so this state decides whether background
/// scanning works at all.
///
/// **What it deliberately does NOT do**: request the exemption itself. That
/// needs `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which Google Play restricts.
/// The user sets Battery > Unrestricted on the app's own settings page.
///
/// Never throws: a failure reads as "unknown" (null) or "could not open"
/// (false), so Settings degrades to showing no status rather than an error.
///
/// ADR-0042: Android only (declared exception) -- Windows has no battery
/// optimization or Doze.
class AndroidBatteryStatus {
  static const MethodChannel _channel =
      MethodChannel('com.myemailspamfilter/battery');

  /// Test seam: tests stub this channel's handler.
  @visibleForTesting
  static MethodChannel get channel => _channel;

  /// true = Unrestricted (exempt), false = Optimized, null = unknown.
  static Future<bool?> isUnrestricted() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  /// Opens this app's Android settings page (App info). Returns false when
  /// the page could not be opened.
  static Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
