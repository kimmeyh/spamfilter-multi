/// Sprint 83 7.7.1 (code-reviewer M-1, silent-failure-hunter M-2): the ONE
/// path that turns an account's background scanning on.
///
/// Two controls do this: Settings > Background > Enable Background Scanning,
/// and "Turn on" on the account list (F324 R-1). The second was written as a
/// copy of the first and dropped three of its steps: the Windows
/// [WindowsTaskSchedulerService.runExclusive] lock (PR #490 7.7.1 finding 6),
/// the Android POST_NOTIFICATIONS request (F161 R-2), and any message when the
/// platform cannot schedule or the interval is invalid. Both controls now call
/// [schedule] (and the account list [turnOn]), so a later step is added once.
///
/// ADR-0042: shared. The platform decisions stay in
/// [BackgroundScanSchedulerFactory] (isSupported) and
/// [PlatformCapabilities.requestsNotificationPermissionAtRuntime].
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../../util/redact.dart';
import '../platform/platform_capabilities.dart';
import '../storage/settings_store.dart';
import 'background_scan_scheduler.dart';
import 'scan_interval.dart';
import 'windows_task_scheduler_service.dart';

/// What [BackgroundScanEnabler.schedule] did.
enum BackgroundEnableResult {
  /// Scheduled with the OS.
  scheduled,

  /// This platform has no background scheduler (nothing runs).
  unsupported,

  /// The stored interval is outside the allowed range (nothing scheduled).
  invalidInterval,

  /// The scheduler returned false (nothing scheduled).
  scheduleFailed,
}

class BackgroundScanEnabler {
  BackgroundScanEnabler._();

  static final Logger _logger = Logger();

  /// Test seam: replaces the permission request.
  @visibleForTesting
  static Future<void> Function()? permissionRequestOverride;

  /// F161 R-2: POST_NOTIFICATIONS is requested when the user turns on the
  /// feature whose completion notification needs it. No-op where the platform
  /// does not ask at runtime.
  static Future<void> requestNotificationPermissionIfNeeded() async {
    final override = permissionRequestOverride;
    if (override != null) return override();
    if (!PlatformCapabilities.current.requestsNotificationPermissionAtRuntime) {
      return;
    }
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      _logger.w('Notification permission request failed: $e');
    }
  }

  /// Validates [minutes], requests the notification permission, and
  /// schedules [accountId]. Does NOT write the setting and does NOT take the
  /// lock: the caller does both (Settings already holds the lock around its
  /// write; [turnOn] does it for the account list).
  static Future<BackgroundEnableResult> schedule({
    required String accountId,
    required int minutes,
    required String caller,
    BackgroundScanScheduler? scheduler,
  }) async {
    final s = scheduler ?? BackgroundScanSchedulerFactory.instance;
    if (!s.isSupported) {
      _logger.w('Background scheduling unsupported on this platform '
          '(${s.mechanismLabel})');
      return BackgroundEnableResult.unsupported;
    }
    final invalid = ScanInterval.validate(minutes);
    if (invalid != null) {
      _logger.w('Not scheduling: interval $minutes minutes is invalid '
          '($invalid)');
      return BackgroundEnableResult.invalidInterval;
    }
    await requestNotificationPermissionIfNeeded();
    final ok = await s.schedule(
        accountId: accountId, intervalMinutes: minutes, caller: caller);
    if (!ok) {
      _logger.e('Background scan scheduling returned false for '
          '${Redact.accountId(accountId)} (${s.mechanismLabel})');
      return BackgroundEnableResult.scheduleFailed;
    }
    return BackgroundEnableResult.scheduled;
  }

  /// The account list's "Turn on": writes the per-account setting and
  /// schedules, inside the Windows scheduler lock, with the account's
  /// effective interval.
  static Future<BackgroundEnableResult> turnOn({
    required String accountId,
    required String caller,
    SettingsStore? settingsStore,
    BackgroundScanScheduler? scheduler,
  }) {
    final settings = settingsStore ?? SettingsStore();
    return WindowsTaskSchedulerService.runExclusive(() async {
      await settings.setAccountBackgroundEnabled(accountId, true);
      final minutes = await settings.getEffectiveBackgroundFrequency(accountId);
      return schedule(
          accountId: accountId,
          minutes: minutes,
          caller: caller,
          scheduler: scheduler);
    });
  }

  /// The text the user sees for [result]. Null for [scheduled] when the
  /// caller has its own success message.
  static String? messageFor(BackgroundEnableResult result) {
    switch (result) {
      case BackgroundEnableResult.scheduled:
        return null;
      case BackgroundEnableResult.unsupported:
        return 'Background scanning is on, but this device cannot run '
            'background scans.';
      case BackgroundEnableResult.invalidInterval:
        return 'Background scanning is on, but its "Scan every" value is not '
            'valid, so nothing was scheduled. Open Settings > Background and '
            'choose a value.';
      case BackgroundEnableResult.scheduleFailed:
        return 'Background scanning is on, but it could not be scheduled. '
            'Open Settings > Background to check it.';
    }
  }
}
