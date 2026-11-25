import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// F346 (Sprint 86): the phone's power-save, device-idle and thermal state,
/// for the diagnostic line written when WorkManager stops a background scan
/// (`reason=deviceState raw=4` on the Fold: which device state?).
///
/// The channel is served by the local plugin `spamfilter_device_state`, NOT by
/// MainActivity like [AndroidBatteryStatus]: the stop handler runs in the
/// WorkManager background engine, which MainActivity never configures.
///
/// ADR-0042 declared exception: Android only. Only WorkManager reports a stop
/// (Windows Task Scheduler gives no stop event), and workmanager_apple 0.9.11
/// never calls `onTaskStopped` from its BGTask expiration handlers
/// (`WorkmanagerPlugin.swift:524` only logs), so iPhone has no stop to log.
const MethodChannel kDeviceStateChannel =
    MethodChannel('com.myemailspamfilter/device_state');

/// The most the stop handler waits for the read. The plugin tears the engine
/// down when the handler returns, so this must stay small.
const Duration kDeviceStateReadTimeout = Duration(milliseconds: 500);

/// `powerSave=<true|false|unknown> deviceIdle=<...> thermal=<none|light|
/// moderate|severe|critical|emergency|shutdown|unknown>`.
///
/// Never throws and never takes longer than [kDeviceStateReadTimeout]: a read
/// that fails, times out or returns an unexpected shape reads `unknown` for
/// every value. A single value the phone cannot give reads `unknown` too; it
/// is never left out. A read that FAILED adds `read=<ExceptionType>` (for
/// example `read=MissingPluginException` when the plugin did not register on
/// the background engine), so a field log can tell that apart from a phone
/// that cannot report a value (Sprint 86 7.7.1 L7). [reader] is the test seam.
Future<String> describeDeviceState({
  Future<Object?> Function()? reader,
}) async {
  Object? raw;
  String? readFailure;
  try {
    raw = await (reader ?? _readChannel)().timeout(kDeviceStateReadTimeout);
  } catch (e) {
    raw = null;
    readFailure = e.runtimeType.toString();
  }
  final map = raw is Map ? raw : const <Object?, Object?>{};
  String boolText(Object? v) => v is bool ? '$v' : 'unknown';
  final thermal = map['thermal'];
  return 'powerSave=${boolText(map['powerSave'])} '
      'deviceIdle=${boolText(map['deviceIdle'])} '
      'thermal=${thermal is String && thermal.isNotEmpty ? thermal : 'unknown'}'
      '${readFailure == null ? '' : ' read=$readFailure'}';
}

Future<Object?> _readChannel() => kDeviceStateChannel.invokeMethod<Object?>('read');

/// Test seam: tests stub this channel's handler.
@visibleForTesting
MethodChannel get deviceStateChannel => kDeviceStateChannel;
