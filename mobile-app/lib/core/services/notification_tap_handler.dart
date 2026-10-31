/// Sprint 82 MV-1 (F319 follow-up): what a tap or click on one of the app's
/// notifications does in the foreground (UI) process.
///
/// Before this, nothing handled it:
/// - Windows: the plugin delivers a toast click only to a RUNNING process that
///   called `initialize` with the toast's app ID and GUID
///   (`flutter_local_notifications_windows` 3.1.1, `src/plugin.cpp:150-172`:
///   it writes `AppUserModelId\<id>\CustomActivator` and calls
///   `CoRegisterClassObject`; it never writes a `LocalServer32` key). Only the
///   background-scan process registered, and it exits right after posting, so
///   a click reached nothing (Harold, MV-1, 2026-10-31).
/// - Android: a tap started or resumed the app on whatever screen it last
///   showed; Review No Rule Items appeared only on a cold start (F135 default).
///
/// Now the UI process registers too ([initialize]), and a tap ([handleTap]):
/// 1. DECLARED EXCEPTION (ADR-0042, window): on a platform with a desktop
///    window, shows the window and brings it to the front (the tray's
///    sequence). A phone has no window to raise; the OS brings the app forward.
/// 2. PARITY: pops to the first route, which is Review No Rule Items when
///    accounts exist (F135). That screen reloads on the `resumed` event the
///    foreground change produces (F319, `shouldReloadOnLifecycle`).
///
/// A click while the app is CLOSED starts it (`-ToastActivated`): the Store
/// build through its manifest (`msix_config.toast_activator`), the unpackaged
/// DEV build through the `LocalServer32` that `main.cpp`
/// `RegisterDevToastActivator` writes. The started UI registers here and then
/// receives the click. Not covered: iOS (the notifier has no Darwin settings
/// yet).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../platform/platform_capabilities.dart';
import 'diagnostic_logger.dart';
import 'scan_complete_notifier.dart';
import 'windows_system_tray_service.dart';

class NotificationTapHandler {
  NotificationTapHandler._();

  static final Logger _logger = Logger();

  /// Registers the UI process for notification taps. Call once, after
  /// `runApp`, in the foreground process only (never the background worker).
  ///
  /// Returns whether the plugin registered. Best-effort: a failure leaves
  /// taps doing what they did before and is written to the diagnostic log.
  static Future<bool> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    final delivery = PlatformCapabilities.current.notificationDelivery;
    if (delivery != NotificationDelivery.androidChannel &&
        delivery != NotificationDelivery.windowsToast) {
      return false;
    }
    try {
      final ok = await FlutterLocalNotificationsPlugin().initialize(
        settings: ScanCompleteNotifier.initializationSettings,
        onDidReceiveNotificationResponse: (_) => handleTap(
          navigator: navigatorKey.currentState,
          hasDesktopWindow: PlatformCapabilities.current.hasDesktopWindow,
          bringToFront: WindowsSystemTrayService.bringWindowToFront,
        ),
      );
      if (ok != true) {
        _note('did NOT register (plugin returned $ok); a tap will not open '
            'No Rule review');
      }
      return ok == true;
    } catch (e) {
      _note('failed to register: ${DiagnosticLogger.describeError(e)}');
      return false;
    }
  }

  /// 7.7.1 H-2: the console log is not kept in a release build, so every
  /// failure here also goes to the diagnostic log (Settings > General).
  static void _note(String detail) {
    _logger.w('Notification tap: $detail');
    unawaited(DiagnosticLogger.log(
      kind: DiagnosticLogger.kindInfo,
      context: 'notify/tap',
      detail: detail,
    ));
  }

  /// What one tap does. [bringToFront] runs only when [hasDesktopWindow].
  @visibleForTesting
  static Future<void> handleTap({
    required NavigatorState? navigator,
    required bool hasDesktopWindow,
    required Future<void> Function() bringToFront,
  }) async {
    if (hasDesktopWindow) {
      try {
        await bringToFront();
      } catch (e) {
        _note('could not bring the window forward: '
            '${DiagnosticLogger.describeError(e)}');
      }
    }
    if (navigator == null) {
      _note('no navigator yet; the app shows its start screen');
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }
}
