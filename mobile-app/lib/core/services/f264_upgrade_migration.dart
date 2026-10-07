// F264 (Sprint 77) -- one-time upgrade conversions for the per-account
// background interval and the per-account "Scan when new mail arrives" switch.
//
// Same shape as the existing one-time migration `PerAccountBgMigration` (F98):
// idempotent, guarded by a sentinel in app_settings, no schema change.
//
// Harold (Sprint 77 Q11): "Existing users take a conversion from current
// (Windows and Android)". Q9 = 1: "on upgrade, if the app-wide new-mail switch
// was ON, turn it on for every account that has background scanning on".
//
// ADR-0042: the interval conversion runs on BOTH platforms; the new-mail
// conversion is Android only (declared exception, ADR-0044) and is a no-op
// where the caller supplies no native reader.

import 'package:logger/logger.dart';

import '../storage/settings_store.dart';
import 'scan_interval.dart';

/// The effective interval for [accountId], converted if it is out of range or
/// cannot be typed into the control, and WRITTEN BACK when it was converted.
///
/// The ONE place that turns a stored value into the value a scheduler gets.
/// Startup reconciliation (`main.dart`) calls it for every enabled account, and
/// the upgrade migration below calls it for every account, so the rule
/// "nearest valid, never a hard-coded 15" exists once. [log] receives one line
/// when a conversion happens.
Future<int> reconcileAccountInterval(
  SettingsStore settings,
  String accountId, {
  void Function(String message)? log,
}) async {
  final stored = await settings.getEffectiveBackgroundFrequency(accountId);
  final result = ScanInterval.reconcileStored(stored);
  if (result.converted) {
    log?.call('F264: stored interval $stored minutes converted to '
        '${result.minutes} minutes');
    // Only an explicit per-account override is rewritten; a value inherited
    // from the app-wide default stays inherited.
    if (await settings.getAccountBackgroundFrequency(accountId) != null) {
      await settings.setAccountBackgroundFrequency(accountId, result.minutes);
    }
  }
  return result.minutes;
}

/// Converts every account's stored interval and re-registers the schedule of
/// every account whose background scanning is on.
class BackgroundIntervalMigration {
  BackgroundIntervalMigration({
    required SettingsStore settingsStore,
    required Future<List<String>> Function() getAccountIds,
    required Future<void> Function(String accountId, int intervalMinutes)?
        reschedule,
    Logger? logger,
  })  : _settings = settingsStore,
        _getAccountIds = getAccountIds,
        _reschedule = reschedule,
        _logger = logger ?? Logger();

  final SettingsStore _settings;
  final Future<List<String>> Function() _getAccountIds;

  /// Re-registers one account's schedule at its (converted) minutes, or null
  /// when scheduling must not happen in this process (a Windows debug run,
  /// whose executable path is a temporary runner).
  final Future<void> Function(String accountId, int intervalMinutes)?
      _reschedule;
  final Logger _logger;

  /// Sentinel key marking the migration complete so it never re-runs.
  static const String sentinelKey = 'f264_interval_migration_done';

  /// Returns true when it ran this call, false when it was already done.
  ///
  /// Why it also re-registers, not only rewrites: before F264, an account
  /// saved at 120 or 240 minutes had NOTHING scheduled (the settings gate
  /// returned early) -- on Android as well as Windows. Re-registering at the
  /// stored (and now valid) minutes gives those accounts the schedule they
  /// were told they had. `schedule` is idempotent by contract.
  Future<bool> runIfNeeded() async {
    if (await _settings.getRawAppSetting(sentinelKey) == 'true') return false;
    try {
      final globalMinutes = await _settings.getBackgroundScanFrequency();
      final globalFixed = ScanInterval.nearestValid(globalMinutes);
      if (globalFixed != globalMinutes) {
        await _settings.setBackgroundScanFrequency(globalFixed);
      }

      final ids = await _getAccountIds();
      var converted = 0;
      var rescheduled = 0;
      for (final id in ids) {
        final before = await _settings.getEffectiveBackgroundFrequency(id);
        final minutes = await reconcileAccountInterval(
          _settings,
          id,
          log: (m) => _logger.i(m),
        );
        if (minutes != before) converted++;
        final reschedule = _reschedule;
        if (reschedule != null &&
            await _settings.getEffectiveBackgroundEnabled(id)) {
          await reschedule(id, minutes);
          rescheduled++;
        }
      }
      _logger.i('F264 interval migration: ${ids.length} account(s), '
          '$converted converted, $rescheduled re-registered');
      await _settings.setRawAppSetting(sentinelKey, 'true', 'bool');
      return true;
    } catch (e) {
      _logger.w('F264 interval migration failed (will retry next launch): $e');
      return false;
    }
  }
}

/// Q9 = 1: carry the old app-wide "Scan when new mail arrives" switch onto the
/// accounts.
///
/// Before F264 the switch was ONE native flag that scanned every
/// background-enabled account. To keep that behavior for an upgrading user,
/// when the flag was ON every account that has background scanning on gets its
/// own switch ON. Android only (ADR-0044).
class NewMailSwitchMigration {
  NewMailSwitchMigration({
    required SettingsStore settingsStore,
    required Future<List<String>> Function() getAccountIds,
    Logger? logger,
  })  : _settings = settingsStore,
        _getAccountIds = getAccountIds,
        _logger = logger ?? Logger();

  final SettingsStore _settings;
  final Future<List<String>> Function() _getAccountIds;
  final Logger _logger;

  /// Sentinel key marking the migration complete so it never re-runs.
  static const String sentinelKey = 'f264_new_mail_migration_done';

  /// [nativeFlagWasOn]: the native app-wide flag as read before F264 changed
  /// its meaning; null when it could not be read (the migration then waits for
  /// the next launch rather than guessing OFF, which would silently turn a
  /// feature the user had on into one that is off).
  ///
  /// Returns true when it ran this call.
  Future<bool> runIfNeeded({required bool? nativeFlagWasOn}) async {
    if (await _settings.getRawAppSetting(sentinelKey) == 'true') return false;
    if (nativeFlagWasOn == null) {
      _logger.w('F264 new-mail migration: native flag unreadable; will retry');
      return false;
    }
    try {
      if (nativeFlagWasOn) {
        var turnedOn = 0;
        for (final id in await _getAccountIds()) {
          if (!await _settings.getEffectiveBackgroundEnabled(id)) continue;
          if (await _settings.getAccountNewMailTrigger(id) != null) continue;
          await _settings.setAccountNewMailTrigger(id, true);
          turnedOn++;
        }
        _logger.i('F264 new-mail migration: app-wide switch was ON -> '
            'turned on for $turnedOn account(s)');
      } else {
        _logger.i('F264 new-mail migration: app-wide switch was OFF -> '
            'nothing to carry over');
      }
      await _settings.setRawAppSetting(sentinelKey, 'true', 'bool');
      return true;
    } catch (e) {
      _logger.w('F264 new-mail migration failed (will retry next launch): $e');
      return false;
    }
  }
}
