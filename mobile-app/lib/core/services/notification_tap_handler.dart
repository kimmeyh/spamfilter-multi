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
///    7.7.1 M-5 (Harold Q4 = 2): it does NOT pop while a dialog, or a screen
///    with an editable text field that holds text, is open above the first
///    route, because popping could discard what the user typed. The app then
///    shows [keptOpenMessage] and writes a diagnostic line. Cautious: the
///    screens do not report unsaved input, so a PREFILLED field (Settings >
///    General retention days, the scan interval) also stops it. Empty and
///    read-only fields (search boxes, SelectableText) do not. Input outside a
///    text field (a checkbox, a folder pick) is not detected.
///
/// A click while the app is CLOSED starts it (`-ToastActivated`): the Store
/// build through its manifest (`msix_config.toast_activator`), the unpackaged
/// DEV build through the `LocalServer32` that `main.cpp`
/// `RegisterDevToastActivator` writes. The started UI registers here and then
/// receives the click. Not covered: iOS (the notifier has no Darwin settings
/// yet).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../platform/platform_capabilities.dart';
import 'diagnostic_logger.dart';
import 'scan_complete_notifier.dart';
import 'windows_system_tray_service.dart';

/// Keeps the navigator's current routes, so a tap can see what is open.
/// `MaterialApp.navigatorObservers` must include [NotificationTapHandler.routeStack].
/// A route of a disposed navigator can stay in [routes]; readers skip any
/// route that is not `isActive`, which is the guard against stale entries.
class RouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (newRoute == null) {
      if (i >= 0) routes.removeAt(i);
    } else if (i >= 0) {
      routes[i] = newRoute;
    } else {
      routes.add(newRoute);
    }
  }
}

class NotificationTapHandler {
  NotificationTapHandler._();

  static final Logger _logger = Logger();

  /// The app's route observer for [handleTap] (7.7.1 M-5).
  static final RouteStackObserver routeStack = RouteStackObserver();

  /// What the user sees when a tap leaves the open screen in place.
  static const String keptOpenMessage =
      'A screen is open, so the notification did not close it. Go back to '
      'Review No Rule Items when you are done.';

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
          openRoutes: routeStack.routes,
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

  /// Why popping [openRoutes] to the first route could lose input, or null
  /// when it cannot: a dialog (any [PopupRoute]) or a screen holding an
  /// editable text field with text in it, above the first route.
  @visibleForTesting
  static String? inputAtRisk(List<Route<dynamic>> openRoutes) {
    for (final route in openRoutes) {
      if (!route.isActive || route.isFirst) continue;
      if (route is PopupRoute) return 'a dialog is open';
      if (route is ModalRoute && _hasTextField(route.subtreeContext)) {
        return 'a screen with a text field is open';
      }
    }
    return null;
  }

  static bool _hasTextField(BuildContext? context) {
    if (context == null) return false;
    var found = false;
    void visit(Element element) {
      if (found) return;
      final widget = element.widget;
      if (widget is EditableText &&
          !widget.readOnly &&
          widget.controller.text.isNotEmpty) {
        found = true;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// What one tap does. [bringToFront] runs only when [hasDesktopWindow].
  /// [openRoutes] is the navigator's route list ([routeStack] in the app).
  @visibleForTesting
  static Future<void> handleTap({
    required NavigatorState? navigator,
    required bool hasDesktopWindow,
    required Future<void> Function() bringToFront,
    List<Route<dynamic>> openRoutes = const <Route<dynamic>>[],
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
    // Nothing awaits this Future (the plugin callback returns void) and the
    // app has no global error handler, so a failure below would reach only
    // the console, which a release build does not keep.
    try {
      final risk = inputAtRisk(openRoutes);
      if (risk != null) {
        _note('open screen kept ($risk)');
        final messenger = ScaffoldMessenger.maybeOf(navigator.context);
        if (messenger == null) {
          _note('no messenger to show the kept-open message');
        } else {
          messenger.showSnackBar(const SnackBar(
            content: Text(keptOpenMessage),
            duration: Duration(seconds: 8),
          ));
        }
        return;
      }
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      _note('tap failed: ${DiagnosticLogger.describeError(e)}');
    }
  }
}
