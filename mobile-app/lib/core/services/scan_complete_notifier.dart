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

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../providers/email_scan_provider.dart' show ScanMode;
import '../platform/platform_capabilities.dart';
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

  /// Android channel and HTML body, or Windows toast and plain body. The test
  /// seam is `PlatformCapabilities.debugOverride` (ADR-0049).
  static bool get _isAndroid =>
      PlatformCapabilities.current.notificationDelivery ==
      NotificationDelivery.androidChannel;

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
    return _deliver(
        id: id, title: text.title, body: body, details: details, what: 'scan');
  }

  /// F301 (Sprint 81): tells the user a Gmail background scan was skipped
  /// because the account needs a new sign-in. Same plugin, same delivery and
  /// same best-effort rule as [post]; plain text on both platforms (the body
  /// has no markup). Its ID differs from the completion ID, so it never
  /// replaces or is replaced by a completion notification.
  ///
  /// Returns whether it was posted. A failure (including notifications turned
  /// off in the OS) never escapes and is written to the diagnostic log.
  static Future<bool> postSignInNeeded({required String accountId}) {
    final details = _isAndroid
        ? const NotificationDetails(android: _signInAndroidDetails)
        : const NotificationDetails(windows: WindowsNotificationDetails());
    return _deliver(
      id: ScanNotificationText.signInNeededId(accountId),
      title: ScanNotificationText.signInNeededTitle(accountId),
      body: ScanNotificationText.signInNeededBody,
      details: details,
      what: 'sign-in-needed',
    );
  }

  static const AndroidNotificationDetails _signInAndroidDetails =
      AndroidNotificationDetails(
    'sign_in_needed_channel',
    'Sign-in needed',
    channelDescription:
        'Tells you when an account must be signed in again to be scanned',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    showWhen: true,
  );

  static Future<bool> _deliver({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    required String what,
  }) async {
    try {
      final show = showOverride ?? _pluginShow;
      await show(id: id, title: title, body: body, details: details);
      return true;
    } catch (e) {
      _logger.w('Notification ($what) failed (scan itself unaffected): $e');
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: 'notification ($what) FAILED (scan unaffected): '
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
