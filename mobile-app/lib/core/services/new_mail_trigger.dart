import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// F253 (Sprint 76): "Scan when new mail arrives" -- the Dart side of the
/// Android notification listener (`MailNotificationListener.kt`, ADR-0044).
///
/// The switch's state lives in NATIVE preferences, not the app database,
/// because the listener runs without a Flutter engine and must read it.
///
/// Never throws. Review MEDIUM-1 / HIGH-2 (Sprint 76): a failure is reported
/// as UNKNOWN (null) or as "not done" (false) -- never collapsed into a
/// confident state such as "off".
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

  /// Opens Android's Notification access screen. false = it did not open.
  static Future<bool> openAccessSettings() async =>
      await _call<bool>('openAccessSettings') == true;

  /// The app's own switch. null = could not be read.
  static Future<bool?> isEnabled() => _call<bool>('isEnabled');

  /// true only when the native side confirmed the change.
  static Future<bool> setEnabled(bool enabled) async =>
      await _call<bool>('setEnabled', {'enabled': enabled}) == true;

  /// The most recent trigger attempt, as recorded by the listener:
  /// "<epoch ms>|<outcome>", or null when none / unreadable.
  static Future<String?> lastResult() => _call<String>('lastResult');

  /// Parses [lastResult] into a time and an outcome; null when malformed.
  static ({DateTime at, String outcome})? parseLastResult(String? raw) {
    if (raw == null) return null;
    final bar = raw.indexOf('|');
    if (bar <= 0) return null;
    final ms = int.tryParse(raw.substring(0, bar));
    if (ms == null) return null;
    return (
      at: DateTime.fromMillisecondsSinceEpoch(ms),
      outcome: raw.substring(bar + 1),
    );
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
