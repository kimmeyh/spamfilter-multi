import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// F235 (Sprint 73): schedule an Android alarm that fires while the device is
/// in Doze.
///
/// **Why this exists.** Harold, 2026-09-22: *"from experience, it is very
/// frustrating to a user that Android background jobs only run when the app is
/// open and in view. This completely renders 'background' jobs as useless."*
///
/// Android's own guidance confirms the mechanism: Doze *"doesn't let
/// JobScheduler run"*, and WorkManager uses JobScheduler internally, so
/// periodic work is deferred to maintenance windows. Nothing in this app's own
/// configuration causes it -- the periodic task constrains only
/// `networkType: connected`.
///
/// **Why `setAndAllowWhileIdle` and not the exact variant** (F235 R-1,
/// determined 2026-09-23 from developer.android.com):
///
/// | Method | Permission | Fires in Doze | Timing |
/// |---|---|---|---|
/// | `setExactAndAllowWhileIdle` | SCHEDULE_EXACT_ALARM or USE_EXACT_ALARM | yes | precise |
/// | `setAndAllowWhileIdle` | **none** | **yes** | within ~1 hour |
/// | `set` / `setInexactRepeating` | none | **no** | ~1 hour |
///
/// The inexact variant escapes Doze with NO permission and NO Play policy
/// exposure. Both exact variants carry a policy burden, and Android's own
/// recommendation is to use the inexact one *"unless your app's core
/// functionality requires precise timing"*. A spam filter does not -- which is
/// the same argument that would have made an exact-alarm justification hard to
/// defend at review.
///
/// **The cost, stated rather than buried**: a ~1 hour delivery window. At the
/// app's 15-minute setting that is four times the interval. It is still
/// strictly better than today, where those scans frequently do not fire at all
/// while the phone is idle.
///
/// **Alarms do not repeat and do not survive reboot.** Both are handled: the
/// native side re-arms after each firing, and a `BOOT_COMPLETED` receiver
/// restores the schedule. Without those this would be a REGRESSION against
/// WorkManager, whose work is persisted.
class AndroidDozeAlarm {
  static const MethodChannel _channel =
      MethodChannel('com.myemailspamfilter/doze_alarm');

  /// Test seam: swap the channel handler without a device.
  @visibleForTesting
  static MethodChannel get channel => _channel;

  /// Arm (or re-arm) the repeating Doze-tolerant alarm for [accountId].
  ///
  /// Idempotent by the same contract as the scheduler interface: arming an
  /// already-armed account UPDATES it, because the native side uses a stable
  /// PendingIntent request code derived from the account.
  ///
  /// Returns false on any failure rather than throwing, so the caller can fall
  /// back to WorkManager. **That fallback is the point** -- losing Doze
  /// tolerance is a degradation, losing scheduling entirely is a regression.
  static Future<bool> schedule({
    required String accountId,
    required int intervalMinutes,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('schedule', {
        'accountId': accountId,
        'intervalMinutes': intervalMinutes,
      });
      return ok ?? false;
    } catch (_) {
      // DELIBERATELY BROAD, and this is load-bearing.
      //
      // The narrow version caught only MissingPluginException and
      // PlatformException, and it BROKE FOUR EXISTING SCHEDULER TESTS with
      // "Binding has not yet been initialized" -- those tests drive the real
      // adapter against a fake platform and never call
      // TestWidgetsFlutterBinding.ensureInitialized(), so touching a
      // MethodChannel throws a FlutterError before any platform code runs.
      //
      // Widening the catch is the correct fix rather than changing those
      // tests: arming the alarm is an ENHANCEMENT to scheduling, and no
      // failure of it may stop WorkManager being registered. A Doze-tolerant
      // alarm that cannot be armed is a degradation; scheduling nothing at all
      // is the regression this card exists to prevent.
      return false;
    }
  }

  /// Cancel the alarm for [accountId]. Cancelling nothing is a no-op, per the
  /// scheduler interface's idempotent-cancel rule.
  static Future<bool> cancel(String accountId) async {
    try {
      final ok = await _channel.invokeMethod<bool>('cancel', {
        'accountId': accountId,
      });
      return ok ?? false;
    } catch (_) {
      // Broad by design -- see the note in [schedule].
      return false;
    }
  }

  /// Whether an alarm is currently armed for [accountId].
  static Future<bool> isScheduled(String accountId) async {
    try {
      final ok = await _channel.invokeMethod<bool>('isScheduled', {
        'accountId': accountId,
      });
      return ok ?? false;
    } catch (_) {
      // Broad by design -- see the note in [schedule].
      return false;
    }
  }
}
