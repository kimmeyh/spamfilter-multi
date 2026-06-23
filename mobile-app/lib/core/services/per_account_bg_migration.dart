// Sprint 42, F98 (ADR-0039) -- one-time per-account background-scan migration.
//
// Migrates the app-wide global `background_scan_enabled` model to the
// per-account model. Idempotent and guarded by a sentinel so it runs at most
// once. Follows the established one-time-migration pattern in main.dart and does
// NOT require an ALTER TABLE (Option A: account_settings key-value rows).
//
// Behavior (ADR-0039 Locked Decision 1 -- preserve today's behavior):
//   - If the global flag is TRUE: every saved account that has no explicit
//     per-account `background_enabled` override inherits `true`, and the global
//     frequency is copied into each account's `background_frequency` override
//     (unless the account already has one). Accounts with an explicit override
//     are left untouched (the user already expressed intent).
//   - If the global flag is FALSE/unset: do nothing (fresh-install default).
// The global app_settings row is retained as the inheritance fallback.

import 'package:logger/logger.dart';

import '../storage/settings_store.dart';

class PerAccountBgMigration {
  PerAccountBgMigration({
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
  static const String sentinelKey = 'per_account_bg_migration_done';

  /// Runs the migration if it has not run before. Returns true if it performed
  /// the migration this call, false if it was already done or not needed.
  Future<bool> runIfNeeded() async {
    final alreadyDone = await _settings.getRawAppSetting(sentinelKey);
    if (alreadyDone == 'true') {
      return false;
    }

    try {
      final globalEnabled = await _settings.getBackgroundScanEnabled();
      if (globalEnabled) {
        final globalFrequency = await _settings.getBackgroundScanFrequency();
        final accountIds = await _getAccountIds();
        _logger.i('F98 migration: global bg-scan ON -> seeding per-account '
            'overrides for ${accountIds.length} account(s)');

        for (final accountId in accountIds) {
          final existingEnabled =
              await _settings.getAccountBackgroundEnabled(accountId);
          if (existingEnabled == null) {
            await _settings.setAccountBackgroundEnabled(accountId, true);
          }
          final existingFreq =
              await _settings.getAccountBackgroundFrequency(accountId);
          if (existingFreq == null) {
            await _settings.setAccountBackgroundFrequency(
                accountId, globalFrequency);
          }
        }
      } else {
        _logger.i('F98 migration: global bg-scan OFF -> no per-account seeding');
      }

      // Mark complete regardless of branch so it never re-runs.
      await _settings.setRawAppSetting(sentinelKey, 'true', 'bool');
      return true;
    } catch (e) {
      _logger.w('F98 per-account bg migration failed (will retry next launch): $e');
      return false;
    }
  }
}
