import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// F253 (Sprint 76): "Scan when new mail arrives" -- the Dart side of the
/// Android notification listener (`MailNotificationListener.kt`, ADR-0044).
///
/// The switch's state lives in NATIVE preferences, not the app database,
/// because the listener runs without a Flutter engine and must read it.
///
/// Never throws: a failure reads as null / false so Settings shows the
/// feature as unavailable rather than erroring.
///
/// ADR-0042: Android only (declared exception).
class NewMailTrigger {
  static const MethodChannel _channel =
      MethodChannel('com.myemailspamfilter/new_mail_trigger');

  /// Test seam: tests stub this channel's handler.
  @visibleForTesting
  static MethodChannel get channel => _channel;

  /// Whether the user granted Notification access in Android settings.
  /// null = unknown.
  static Future<bool?> isAccessGranted() => _call<bool>('isAccessGranted');

  /// Opens Android's Notification access screen.
  static Future<bool> openAccessSettings() async =>
      await _call<bool>('openAccessSettings') ?? false;

  /// The app's own switch (off by default).
  static Future<bool> isEnabled() async =>
      await _call<bool>('isEnabled') ?? false;

  static Future<bool> setEnabled(bool enabled) async =>
      await _call<bool>('setEnabled', {'enabled': enabled}) ?? false;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
