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
/// F322 (Sprint 83): WHICH completed scans notify.
/// - Windows, iPhone and Android 7.x (API 24-25, no channels): the in-app
///   choice (`SettingsStore.getScanNotifyChoice`, Settings > Background >
///   "Scan notifications"). Default "Only when there are No Rule items": a scan
///   with No Rule 0 posts nothing ([ScanNotificationOutcome.skippedByChoice]).
/// - DECLARED EXCEPTION (choice), Android 8.0+ (API 26+): the OS owns the
///   choice. EVERY completed scan posts, on one of two channels picked by the
///   No Rule count ([noRuleChannelId] / [nothingToReviewChannelId]); the user
///   silences the second in Android's notification settings, and the in-app
///   choice is NOT read (two controls for one outcome would disagree).
///   Android: developer.android.com/develop/ui/views/notifications/channels
///   ("Users can modify the settings for notification channels"). The
///   sign-in-needed notification is never gated (R-3).
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
import '../storage/settings_store.dart';
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

/// What [ScanCompleteNotifier.post] did, so a worker's log line can tell a
/// deliberate skip from a failure.
enum ScanNotificationOutcome {
  /// Handed to the OS.
  posted,

  /// The user's choice says no notification for this scan (not an error).
  skippedByChoice,

  /// The post failed (reason in the diagnostic log).
  failed,
}

class ScanCompleteNotifier {
  ScanCompleteNotifier._();

  /// Test seam: replaces the read of the saved [ScanNotifyChoice].
  @visibleForTesting
  static Future<ScanNotifyChoice> Function()? choiceOverride;

  /// Test seam: replaces the "does this Android have notification channels"
  /// probe (true = Android 8.0+).
  @visibleForTesting
  static Future<bool> Function()? channelsSupportedOverride;

  /// F322: channel for a scan with at least one No Rule item. Importance LOW
  /// (no sound, same as the retired `background_scan_channel`). An id and its
  /// importance cannot be changed by the app after the channel exists, so
  /// these are chosen once (Sprint 83 Task 2 card).
  static const String noRuleChannelId = 'scan_with_no_rule_channel';
  static const String noRuleChannelName = 'Scans with No Rule items';

  /// F322: channel for a scan with nothing to review (No Rule 0). The user
  /// silences this one in Android's settings.
  static const String nothingToReviewChannelId =
      'scan_nothing_to_review_channel';
  static const String nothingToReviewChannelName =
      'Scans with nothing to review';

  /// The pre-Sprint 83 channel. Never posted to again; deleted when the new
  /// channels are created so Android's list does not show a dead entry.
  static const String retiredChannelId = 'background_scan_channel';

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

  /// The plugin settings BOTH processes register with: the background worker
  /// that posts, and the UI process that receives a click
  /// (`NotificationTapHandler`). On Windows a click is delivered only to a
  /// running process registered under the toast's app ID and GUID, so the two
  /// must never differ -- hence one getter.
  static InitializationSettings get initializationSettings =>
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: windowsAppName,
          appUserModelId: windowsAppUserModelId,
          guid: windowsGuid,
        ),
      );

  // F286: the body is HTML so `<s>` renders as strikethrough; the plugin
  // passes it to Html.fromHtml when this flag is set.
  static const AndroidNotificationDetails _noRuleAndroidDetails =
      AndroidNotificationDetails(
    noRuleChannelId,
    noRuleChannelName,
    channelDescription: 'Background scans that found mail with no rule',
    importance: Importance.low,
    priority: Priority.low,
    showWhen: true,
    styleInformation: DefaultStyleInformation(true, false),
  );

  static const AndroidNotificationDetails _nothingToReviewAndroidDetails =
      AndroidNotificationDetails(
    nothingToReviewChannelId,
    nothingToReviewChannelName,
    channelDescription: 'Background scans that found nothing to review',
    importance: Importance.low,
    priority: Priority.low,
    showWhen: true,
    styleInformation: DefaultStyleInformation(true, false),
  );

  /// The details for a completed scan on Android: the channel follows the
  /// No Rule count (T-3).
  @visibleForTesting
  static AndroidNotificationDetails androidDetailsFor(int noRule) =>
      noRule > 0 ? _noRuleAndroidDetails : _nothingToReviewAndroidDetails;

  /// Creates both channels (so Android's settings list them before the first
  /// post) and deletes the retired one. Returns true when this Android has
  /// channels (8.0+): the plugin lists them only there ("On older versions, it
  /// will return an empty list", flutter_local_notifications 22.3.2,
  /// `platform_flutter_local_notifications.dart:584`). Any failure returns
  /// false, which makes the in-app choice apply (the safe direction: it can
  /// only silence a scan the user asked to silence) and is logged.
  static Future<bool> ensureAndroidChannels() async {
    final override = channelsSupportedOverride;
    if (override != null) return override();
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: initializationSettings);
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      await android.createNotificationChannel(const AndroidNotificationChannel(
        noRuleChannelId,
        noRuleChannelName,
        description: 'Background scans that found mail with no rule',
        importance: Importance.low,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        nothingToReviewChannelId,
        nothingToReviewChannelName,
        description: 'Background scans that found nothing to review',
        importance: Importance.low,
      ));
      await android.deleteNotificationChannel(channelId: retiredChannelId);
      final channels = await android.getNotificationChannels();
      return channels?.any((c) => c.id == noRuleChannelId) ?? false;
    } catch (e) {
      _logger.w('Notification channel setup failed: $e');
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: 'notification channel setup FAILED (the in-app choice '
            'applies): ${DiagnosticLogger.describeError(e)}',
      );
      return false;
    }
  }

  static Future<ScanNotifyChoice> _readChoice() async {
    try {
      return await (choiceOverride ?? SettingsStore().getScanNotifyChoice)();
    } catch (e) {
      // A failed read must not hide a scan with mail to review: notify.
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: 'notification choice unreadable (notifying): '
            '${DiagnosticLogger.describeError(e)}',
      );
      return ScanNotifyChoice.every;
    }
  }

  /// Posts the notification for one account's completed background scan.
  ///
  /// Returns what happened (Sprint 79 7.7.1 M-4, F322): the worker's step line
  /// reports the real outcome instead of an unconditional "done". A failure
  /// never escapes -- the scan itself has already succeeded.
  static Future<ScanNotificationOutcome> post({
    required String accountId,
    required ScanMode mode,
    required int noRule,
    required int deleted,
    required int safe,
    required int errors,
  }) async {
    final android = _isAndroid;
    // F322. Android 8.0+: the channels are the choice (every scan posts, on
    // the channel the No Rule count picks). Everywhere else: the in-app choice.
    final channelsHonored = android && await ensureAndroidChannels();
    if (!channelsHonored && noRule == 0) {
      if (await _readChoice() == ScanNotifyChoice.noRuleOnly) {
        return ScanNotificationOutcome.skippedByChoice;
      }
    }
    final text = ScanNotificationText.build(
      accountId: accountId,
      mode: mode,
      noRule: noRule,
      deleted: deleted,
      safe: safe,
      errors: errors,
    );
    final details = android
        ? NotificationDetails(android: androidDetailsFor(noRule))
        : const NotificationDetails(windows: WindowsNotificationDetails());
    final body = android ? text.htmlBody : text.plainBody;
    final id = ScanNotificationText.notificationId(accountId);
    final posted = await _deliver(
        id: id, title: text.title, body: body, details: details, what: 'scan');
    return posted
        ? ScanNotificationOutcome.posted
        : ScanNotificationOutcome.failed;
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
    await plugin.initialize(settings: initializationSettings);
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
