import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/settings_store.dart';
import 'diagnostic_logger.dart';

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

  /// Sprint 80 Task 17 (#505): the native start-up snapshot (Notification
  /// access, flag, listener component and bind times, the last ignored
  /// mail-app notification, installed mail apps, how the screen was started);
  /// null when unreadable.
  ///
  /// PR #490 7.7.1 (silent-failure review finding 9): when the call fails,
  /// [lastDiagnosticsError] keeps why (the native exception's type and
  /// message), so the log line names a cause instead of only "unavailable".
  static Future<Map<Object?, Object?>?> diagnostics() async {
    lastDiagnosticsError = null;
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('diagnostics');
    } catch (e) {
      lastDiagnosticsError = DiagnosticLogger.describeError(e);
      return null;
    }
  }

  /// Why the last [diagnostics] call returned null; null after a success.
  static String? lastDiagnosticsError;

  /// One diagnostic-log line from [diagnostics]. Pure, so the wording is
  /// tested without a device. [error] is [lastDiagnosticsError].
  static String formatDiagnostics(Map<Object?, Object?>? d, {String? error}) {
    if (d == null) {
      return error == null
          ? 'diagnostics unavailable'
          : 'diagnostics unavailable -- $error';
    }
    String onOff(Object? v) => v == true ? 'on' : (v == false ? 'off' : 'unknown');
    String at(Object? ms) => ms is int && ms > 0
        ? DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String()
        : 'never';
    // PackageManager.COMPONENT_ENABLED_STATE_DEFAULT / _ENABLED / _DISABLED.
    const states = {0: 'default', 1: 'enabled', 2: 'disabled'};
    final state = d['componentState'];
    final ignored = parseLastIgnored(d['lastIgnored'] as String?);
    final apps = (d['installedMailApps'] as List?)?.join(',') ?? 'unknown';
    return 'access=${onOff(d['accessGranted'])} flag=${onOff(d['enabled'])} '
        'component=${states[state] ?? state} '
        'listenerConnected=${at(d['connectedMs'])} '
        'listenerDisconnected=${at(d['disconnectedMs'])} '
        'lastIgnored=${ignored == null ? 'none' : '${ignored.at.toIso8601String()} ${ignored.app} (${ignored.reason})'} '
        'mailApps=${apps.isEmpty ? 'none' : apps} '
        'launch: ${d['launch'] ?? 'unknown'}';
  }

  /// Parses the listener's "<epoch ms>|<package>|<reason>"; null when malformed.
  static ({DateTime at, String app, String reason})? parseLastIgnored(
      String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final ms = int.tryParse(parts[0]);
    if (ms == null) return null;
    return (
      at: DateTime.fromMillisecondsSinceEpoch(ms),
      app: parts[1],
      reason: parts[2],
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
