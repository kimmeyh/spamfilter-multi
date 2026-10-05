/// F252 (Sprint 76): what started an Android background worker, for its
/// diagnostic start line.
///
/// **Why this exists.** The F235 Doze alarm hands every scan to WorkManager,
/// and Android's Doze guidance says JobScheduler -- which WorkManager runs on --
/// does not run while the device is idle. Whether an alarm actually produces a
/// scan while the phone sleeps was therefore unverified, and the log could not
/// settle it: a worker started by the alarm and one started by the periodic
/// schedule wrote the same line. The alarm now records when it fired, and this
/// turns that into `trigger=doze-alarm delay=NNs`.
///
/// Pure (no I/O) so it is unit-testable without a device.
///
/// ADR-0042: Android only by nature -- these payload keys come only from the
/// Android alarm (and, with F253, the new-mail notification listener).
library;

/// Must match `DozeScanTrigger.KEY_TRIGGER_SOURCE` in `DozeScanTrigger.kt`.
const String kTriggerSourceKey = 'triggerSource';

/// Must match `DozeScanTrigger.KEY_TRIGGER_AT_MS` in `DozeScanTrigger.kt`.
const String kTriggerAtMsKey = 'triggerAtMs';

/// Describe what started this worker run, e.g. `trigger=doze-alarm delay=42s`.
///
/// - [isTest]: the Settings "Test Background Scan" one-off.
/// - A [inputData] carrying [kTriggerSourceKey]: the native trigger that
///   enqueued it, with the delay from [kTriggerAtMsKey] to [now] when present.
/// - Anything else: the periodic WorkManager schedule (it carries only the
///   account id).
String describeBackgroundTrigger({
  required bool isTest,
  required Map<String, dynamic>? inputData,
  required DateTime now,
}) {
  if (isTest) return 'trigger=test';
  final source = inputData?[kTriggerSourceKey];
  if (source is! String || source.isEmpty) return 'trigger=periodic';

  final buffer = StringBuffer('trigger=$source');
  final at = inputData?[kTriggerAtMsKey];
  if (at is num) {
    final delayMs = now.millisecondsSinceEpoch - at.toInt();
    // A negative delay means the clock moved (or the value is bad); say so
    // rather than printing a number that reads as a measurement.
    buffer.write(delayMs >= 0
        ? ' delay=${(delayMs / 1000).round()}s'
        : ' delay=unknown (clock changed)');
  }
  return buffer.toString();
}
