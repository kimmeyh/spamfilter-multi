/// F287 (Sprint 79): posts the background-scan completion notification on
/// BOTH platforms through one plugin and one text builder.
///
/// Until Sprint 79 only Android posted one; Windows never did -- two Windows
/// services existed (`WindowsNotificationService`, a placeholder for plugin
/// 16.x, and `WindowsToastNotificationService`, ADR-0018's PowerShell toast)
/// and neither had a caller. Both are removed; `flutter_local_notifications`
/// 22.x supports Windows (Q2 = 2, ADR-0018 superseded).
///
/// ADR-0042:
/// - PARITY: the title, the counts, the mode word and the one-per-account rule
///   come from [ScanNotificationText] on both platforms. Both post only for a
///   COMPLETED scan: the callers skip a stopped or skipped scan before this
///   runs (`BackgroundScanCore.completeAccount` on Android, the `continue` on
///   a skip in the Windows worker).
/// - DECLARED EXCEPTION (delivery): Android posts on a notification channel
///   with an HTML body, so a count the mode did not act on is struck through;
///   a Windows toast has no strikethrough markup, so Windows shows the plain
///   body and the title word alone carries the mode. Each platform's own OS
///   setting turns notifications off (Android POST_NOTIFICATIONS / app
///   notification settings; Windows Settings > System > Notifications).
///
/// Best-effort by design: a notification failure must never fail the scan --
/// the scan's persistence is the record; the notification is a courtesy. A
/// failure is written to the diagnostic log so it is not silent.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../providers/email_scan_provider.dart' show ScanMode;
import 'app_environment.dart';
import 'diagnostic_logger.dart';
import 'scan_notification_text.dart';

/// What [ScanCompleteNotifier.post] hands to the plugin -- the test seam.
typedef ScanNotificationShow = Future<void> Function({
  required int id,
  required String title,
  required String body,
  required NotificationDetails details,
});

class ScanCompleteNotifier {
  ScanCompleteNotifier._();

  static final Logger _logger = Logger();

  /// Test seam: replaces the plugin's initialize + show.
  @visibleForTesting
  static ScanNotificationShow? showOverride;

  /// Test seam: force the Android (true) or Windows (false) branch.
  @visibleForTesting
  static bool? isAndroidOverride;

  static bool get _isAndroid => isAndroidOverride ?? Platform.isAndroid;

  /// The toast's app name on Windows.
  static const String windowsAppName = 'MyEmailSpamFilter';

  /// The app ID an UNPACKAGED Windows build registers under (the plugin writes
  /// it to HKCU `Software\Classes\AppUserModelId\<id>`); a packaged (MSIX)
  /// build uses its package identity instead. DEV and PROD differ so the two
  /// builds never share a registration (ADR-0035).
  static String get windowsAppUserModelId =>
      AppEnvironment.isDev ? 'MyEmailSpamFilter.Dev' : 'MyEmailSpamFilter.App';

  /// The toast activation callback's COM class id, fixed per environment.
  static String get windowsGuid => AppEnvironment.isDev
      ? '06668ccd-ce68-41ea-9eb4-e1070255a7f3'
      : 'f5b1ae09-8027-4b72-9444-07d620fe3fdc';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'background_scan_channel',
    'Background Scans',
    channelDescription: 'Results of scheduled background email scans',
    importance: Importance.low,
    priority: Priority.low,
    showWhen: true,
    // F286: the body is HTML so `<s>` renders as strikethrough; the plugin
    // passes it to Html.fromHtml when this flag is set.
    styleInformation: DefaultStyleInformation(true, false),
  );

  /// Posts the notification for one account's completed background scan.
  ///
  /// Returns whether it was posted (Sprint 79 7.7.1 M-4): the worker's step
  /// line reports the real outcome instead of an unconditional "done". A
  /// failure never escapes -- the scan itself has already succeeded.
  static Future<bool> post({
    required String accountId,
    required ScanMode mode,
    required int noRule,
    required int deleted,
    required int safe,
    required int errors,
  }) async {
    final android = _isAndroid;
    final text = ScanNotificationText.build(
      accountId: accountId,
      mode: mode,
      noRule: noRule,
      deleted: deleted,
      safe: safe,
      errors: errors,
    );
    final details = android
        ? const NotificationDetails(android: _androidDetails)
        : const NotificationDetails(windows: WindowsNotificationDetails());
    final body = android ? text.htmlBody : text.plainBody;
    final id = ScanNotificationText.notificationId(accountId);
    try {
      final show = showOverride ?? _pluginShow;
      await show(id: id, title: text.title, body: body, details: details);
      return true;
    } catch (e) {
      _logger.w('Completion notification failed (scan itself succeeded): $e');
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: 'notification FAILED (scan unaffected): '
            '${DiagnosticLogger.describeError(e)}',
      );
      return false;
    }
  }

  static Future<void> _pluginShow({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: windowsAppName,
          appUserModelId: windowsAppUserModelId,
          guid: windowsGuid,
        ),
      ),
    );
    // Sprint 79 7.7.1 M-5: on Android `show` returns normally when the user
    // denied POST_NOTIFICATIONS (Android 13+) or turned the app's
    // notifications off, and nothing appears. Ask first, and report it as a
    // failure so the log does not read "posted" (flutter_local_notifications
    // 22.3.2, `platform_flutter_local_notifications.dart:624`). Null on
    // Windows, where `show` itself throws when it cannot post.
    final enabled = await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    if (enabled == false) {
      throw StateError('notifications are turned off for this app '
          '(Android notification permission or app setting)');
    }
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
