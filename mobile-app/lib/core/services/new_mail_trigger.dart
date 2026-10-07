import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/settings_store.dart';

/// F253 (Sprint 76): "Scan when new mail arrives" -- the Dart side of the
/// Android notification listener (`MailNotificationListener.kt`, ADR-0044).
///
/// **F264 (Sprint 77): the switch is per ACCOUNT.** Each account's switch lives
/// in the app database with its other background settings
/// (`SettingsStore.getAccountNewMailTrigger`). The NATIVE preference this class
/// reads and writes is now only the "any account has it on" flag, kept because
/// the listener runs without a Flutter engine and cannot read the database; it
/// gates the listener cheaply (and enables or disables the component).
/// [syncAnyAccountOn] keeps the two in step and is called whenever a switch
/// changes.
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

  /// F264: set the native "any account on" flag from the per-account
  /// switches: ON when at least one of [accountIds] has its own new-mail
  /// switch ON. Returns true only when the native side confirmed the change.
  ///
  /// [accountIds] are the SAVED accounts, not every row in the settings table,
  /// so a removed account's leftover switch cannot keep the listener bound.
  static Future<bool> syncAnyAccountOn(
    SettingsStore settings,
    Iterable<String> accountIds,
  ) async {
    var anyOn = false;
    for (final id in accountIds) {
      if (await settings.getAccountNewMailTrigger(id) == true) {
        anyOn = true;
        break;
      }
    }
    return setEnabled(anyOn);
  }

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
