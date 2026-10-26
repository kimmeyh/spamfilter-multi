/// F301 / F244 (Sprint 81): tells the user that a Gmail account is not being
/// scanned because it needs a new sign-in.
///
/// Why this exists: while the Google consent screen is in Testing, Gmail
/// sign-in expires about every seven days (ADR-0029 Phase 1, kept on purpose).
/// Until now the background scan recorded a skip and the user saw nothing
/// until they opened the account list. This makes the expiry visible.
///
/// Rules:
/// - At most ONE notification per account per [minInterval] (24 hours). The
///   time is kept per account in the settings store (`account_settings`, key
///   `gmail_sign_in_notified_at`); no new persistence mechanism.
/// - Independent of the `gmail_sign_in_required` flag. That flag is written
///   best effort by the Gmail adapter and the write can fail (F244); a failed
///   write must not hide the notification. This class never reads that flag.
/// - Best effort: nothing here throws. A failure to read the last time posts
///   anyway (the user is told, at worst more than once a day); a failure to
///   save it is logged.
/// - The attempt time is saved BEFORE posting, so a notification that cannot be
///   shown (the user turned notifications off in the OS) is not attempted on
///   every 15-minute scan.
/// - A post that FAILS is retried after [retryAfterFailedPost] (1 hour), not
///   [minInterval] (7.7.1 silent-failure L-7, Harold Q6 = 3, 2026-10-26): a
///   temporary failure gets a quick retry, and a lasting one (notifications
///   off) costs one attempt an hour. The saved time is moved back so the
///   existing [minInterval] check comes due one hour from now.
///
/// ADR-0042: one code path for Windows, Android and iOS. Delivery goes through
/// [ScanCompleteNotifier.postSignInNeeded] (Windows toast, Android channel);
/// the only platform difference is inside that class and is chosen by
/// `PlatformCapabilities`. iOS: `NotificationDelivery.iosAlert` is declared
/// but NOT wired yet -- `ScanCompleteNotifier` has no Darwin settings, so on
/// iOS `initialize` throws ArgumentError (flutter_local_notifications 22.3.2,
/// `flutter_local_notifications_plugin.dart:143`) and `_deliver` logs it (not
/// silent). Wiring is F67c (Sprint 82).
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

import '../../util/redact.dart';
import '../storage/settings_store.dart';
import 'diagnostic_logger.dart';
import 'scan_complete_notifier.dart';

class GmailSignInNotifier {
  GmailSignInNotifier._();

  static final Logger _logger = Logger();

  /// The shortest time between two notifications for one account.
  static const Duration minInterval = Duration(hours: 24);

  /// The time before a FAILED post is tried again.
  static const Duration retryAfterFailedPost = Duration(hours: 1);

  /// Test seam: the clock.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Posts the "Gmail sign-in needed" notification for [accountId] unless one
  /// was posted for it within [minInterval]. Returns whether one was posted.
  static Future<bool> notifyIfDue({
    required String accountId,
    required SettingsStore settingsStore,
  }) async {
    final label = Redact.accountId(accountId);
    final at = now();
    try {
      DateTime? last;
      try {
        last = await settingsStore.getGmailSignInNotifiedAt(accountId);
      } catch (e) {
        _logger.w('F301: could not read the last sign-in notification time '
            'for $label; notifying anyway: $e');
        // A release build keeps no console log, so the diagnostic log is the
        // only place this failure (which can mean more than one notification
        // a day) is seen (F-PRECHECK, Sprint 81).
        await DiagnosticLogger.log(
          kind: DiagnosticLogger.kindScan,
          context: 'scan/post',
          detail: 'sign-in notification time unreadable; notifying anyway -- '
              '${DiagnosticLogger.describeError(e)}',
        );
      }
      // A last time in the future (clock moved back) counts as due; otherwise
      // the account would stay silent until the clock caught up.
      if (last != null) {
        final elapsed = at.difference(last);
        if (!elapsed.isNegative && elapsed < minInterval) {
          _logger.d('F301: sign-in notification for $label suppressed (sent '
              '${elapsed.inMinutes} minutes ago)');
          return false;
        }
      }
      try {
        await settingsStore.setGmailSignInNotifiedAt(accountId, at);
      } catch (e) {
        _logger.w('F301: could not save the sign-in notification time for '
            '$label: $e');
        await DiagnosticLogger.log(
          kind: DiagnosticLogger.kindScan,
          context: 'scan/post',
          detail: 'sign-in notification time not saved -- '
              '${DiagnosticLogger.describeError(e)}',
        );
      }
      final posted =
          await ScanCompleteNotifier.postSignInNeeded(accountId: accountId);
      if (!posted) {
        try {
          await settingsStore.setGmailSignInNotifiedAt(
              accountId, at.subtract(minInterval - retryAfterFailedPost));
        } catch (e) {
          _logger.w('F301: could not schedule the sign-in notification '
              'retry for $label: $e');
        }
      }
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: posted
            ? 'sign-in-needed notification posted'
            : 'sign-in-needed notification NOT posted (reason on the line '
                'above); retry in ${retryAfterFailedPost.inMinutes} minutes',
      );
      return posted;
    } catch (e) {
      // Nothing above should throw; this keeps a notification problem from
      // ever turning a skipped scan into a failed one.
      _logger.w('F301: sign-in notification failed for $label: $e');
      await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindScan,
        context: 'scan/post',
        detail: 'sign-in notification failed -- '
            '${DiagnosticLogger.describeError(e)}',
      );
      return false;
    }
  }
}
