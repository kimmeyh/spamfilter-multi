/// F66 (Sprint 33): user-data deletion service.
///
/// Provides two flows:
/// - [deleteAccountData]: remove one account's credentials, per-account
///   settings, scan results, email actions, and unmatched emails. Leaves
///   global rules, safe senders, app-wide settings, and other accounts
///   untouched.
/// - [wipeAllData]: clear every table in the DB and delete every credential
///   from secure storage. Returns the app to a fresh-install state.
///
/// Designed to be called from the Settings UI behind a two-step confirmation
/// dialog; the service itself does not prompt.
library;

import '../storage/content_history_store.dart';
import '../storage/settings_store.dart' show SettingsStore;
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart' show Transaction;

import '../../adapters/email_providers/platform_registry.dart' show PlatformRegistry;
import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../storage/database_helper.dart';

/// Result of a deletion operation, useful for surfacing counts in the UI.
class DeletionReport {
  final int scanResultsDeleted;
  final int emailActionsDeleted;
  final int unmatchedEmailsDeleted;
  final int accountSettingsDeleted;

  /// F324 (Sprint 83): `account_settings` rows kept (the user's choices).
  final int accountSettingsKept;
  final int backgroundScheduleEntriesDeleted;
  final bool credentialsDeleted;

  const DeletionReport({
    this.scanResultsDeleted = 0,
    this.emailActionsDeleted = 0,
    this.unmatchedEmailsDeleted = 0,
    this.accountSettingsDeleted = 0,
    this.accountSettingsKept = 0,
    this.backgroundScheduleEntriesDeleted = 0,
    this.credentialsDeleted = false,
  });
}

/// F324 (Sprint 83, Q3 = 3, Harold 2026-11-01): the `account_settings` keys
/// that survive removing an account, so adding the same address back finds the
/// choices the user made (folders, scan modes, background on/off and frequency,
/// days back, target folders, new-mail trigger). Every other key is in
/// [accountSettingKeysRefreshed] and is deleted.
///
/// Prevention: the policy test `account_settings_classification_test` fails
/// when a key used by `SettingsStore` is in neither set, so a new key is
/// classified on purpose and is never kept or lost by accident.
const Set<String> accountSettingKeysKept = {
  'folders',
  'scan_mode',
  'manual_scan_mode',
  'manual_scan_folders',
  'background_scan_mode',
  'background_scan_folders',
  'manual_days_back',
  'background_days_back',
  'background_enabled',
  'background_frequency',
  'new_mail_trigger',
  'deleted_rule_folder',
  'safe_sender_folder',
};

/// F324: keys tied to the old sign-in, or an internal allocation. Deleted on
/// removal. The first two are also cleared again on re-add
/// ([DataDeletionService.refreshForReAdd]); `schedule_slot` is not, because a
/// saved slot never moves (`SettingsStore.getOrAllocateScheduleSlot`).
const Set<String> accountSettingKeysRefreshed = {
  'gmail_sign_in_required',
  'gmail_sign_in_notified_at',
  'schedule_slot',
};

/// Service that tears down user data at the account or app level.
class DataDeletionService {
  final DatabaseHelper _dbHelper;
  final SecureCredentialsStore _credStore;
  final Logger _logger = Logger();

  DataDeletionService({
    DatabaseHelper? dbHelper,
    SecureCredentialsStore? credStore,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _credStore = credStore ?? SecureCredentialsStore();

  /// Delete all data attached to [accountId] but preserve app-wide state
  /// (rules, safe senders, app settings, other accounts).
  ///
  /// Safe to call when the account has never been scanned; missing tables
  /// return zero-count instead of throwing.
  Future<DeletionReport> deleteAccountData(String accountId) async {
    _logger.i('Deleting account data for ${Redact.accountId(accountId)}');
    final db = await _dbHelper.database;

    int scans = 0;
    int emails = 0;
    int unmatched = 0;
    int accountSettings = 0;
    int accountSettingsKept = 0;
    int scheduleEntries = 0;
    bool credsDeleted = false;

    await db.transaction((txn) async {
      // scan_results -> email_actions (cascade via FK, but count first)
      final scanIds = await txn.query(
        'scan_results',
        columns: ['id'],
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      final scanIdList = scanIds.map((r) => r['id'] as int).toList();

      if (scanIdList.isNotEmpty) {
        final placeholders = List.filled(scanIdList.length, '?').join(',');
        emails = await txn.delete(
          'email_actions',
          where: 'scan_result_id IN ($placeholders)',
          whereArgs: scanIdList,
        );
        unmatched = await txn.delete(
          'unmatched_emails',
          where: 'scan_result_id IN ($placeholders)',
          whereArgs: scanIdList,
        );
      }

      scans = await txn.delete(
        'scan_results',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );

      // F324 (Q3 = 3): keep the user's choices; delete the rest (the
      // sign-in state and internal allocations). An allowlist, so a new key
      // is deleted unless it is classified as kept.
      final keptPlaceholders =
          List.filled(accountSettingKeysKept.length, '?').join(',');
      accountSettings = await txn.delete(
        'account_settings',
        where: 'account_id = ? AND setting_key NOT IN ($keptPlaceholders)',
        whereArgs: [accountId, ...accountSettingKeysKept],
      );
      accountSettingsKept = (await txn.query(
        'account_settings',
        columns: ['setting_key'],
        where: 'account_id = ?',
        whereArgs: [accountId],
      ))
          .length;

      // Drop any future background-scan schedule rows for this account.
      scheduleEntries = await txn.delete(
        'background_scan_schedule',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );

      // Rate-limit state (SEC-22) keyed by accountId too. No catch here or
      // above (7.7.1 silent-failure M-4, the whole class): every table is
      // created by `_createTables` or its migration, so a failure is real.
      await _deleteRateLimit(txn, accountId);

      // R76-4 R7 (Sprint 78, prevention: `r76_4_content_history_policy_test`,
      // group "R7", fails when a table holding account data is missing from
      // this path):
      // the per-folder scan cursors and the background-scan run log are this
      // account's data too, and were left behind.
      // No catch (7.7.1 silent-failure M-4): both tables are always created
      // (`_createTables` / the v5 migration), so a failure here is real
      // (SQLITE_BUSY, disk I/O) and must abort the deletion, not be hidden.
      for (final table in ['account_folder_cursors', 'background_scan_log']) {
        await txn.delete(table, where: 'account_id = ?', whereArgs: [accountId]);
      }

      // F352 (ADR-0052 item 5): if this account is the default account,
      // clear the default in the SAME transaction, so no stale id remains.
      // Only the matching value is removed; another account's default stays.
      await txn.delete(
        'app_settings',
        where: 'key = ? AND value = ?',
        whereArgs: [SettingsStore.keyDefaultAccountId, accountId],
      );

      await txn.delete(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
    });

    // R76-4 (ADR-0047 item 9): the dev-only content history keeps its own
    // file; drop this account's rows when one exists. Best effort, logged;
    // showing the failure to the user is backlog (7.7.1 silent-failure M-4,
    // UI half -- a 4-file fix, asked first by the size rule).
    try {
      final history = ContentHistoryStore.instance;
      if (history.fileExists()) await history.deleteAccount(accountId);
    } catch (e) {
      _logger.w('Content history delete for ${Redact.accountId(accountId)} '
          'failed: $e');
    }

    // Credentials live outside the DB, in flutter_secure_storage.
    try {
      await _credStore.deleteCredentials(accountId);
      credsDeleted = true;
    } catch (e) {
      // Some accounts (e.g. Gmail OAuth) store credentials under a
      // different id layout. Log and continue; the DB side is done.
      _logger.w('Credential delete for ${Redact.accountId(accountId)} '
          'did not find a matching record: $e');
    }

    final report = DeletionReport(
      scanResultsDeleted: scans,
      emailActionsDeleted: emails,
      unmatchedEmailsDeleted: unmatched,
      accountSettingsDeleted: accountSettings,
      accountSettingsKept: accountSettingsKept,
      backgroundScheduleEntriesDeleted: scheduleEntries,
      credentialsDeleted: credsDeleted,
    );
    _logger.i('Account deletion complete: scans=$scans, emails=$emails, '
        'unmatched=$unmatched, accountSettings=$accountSettings '
        '(kept $accountSettingsKept), '
        'schedule=$scheduleEntries, creds=$credsDeleted');
    return report;
  }

  /// The platform ids the IMAP adapter puts in front of the address to form
  /// its rate-limit key (`'$platformId-${credentials.email}'`,
  /// `generic_imap_adapter.dart` `loadCredentials` and `_recordSignInFailure`).
  /// Sprint 83 7.7.1: the registry owns the list; this is an alias, not a copy.
  static const Set<String> _rateLimitPlatformIds =
      PlatformRegistry.imapPlatformIds;

  /// F324 (Sprint 83): the lockout count is keyed by `platform-address`, so a
  /// delete by the bare address (the old code) never matched it and a removed
  /// account's failed-password count survived. Clears the bare key and every
  /// `platform-address` key for the address.
  Future<void> _deleteRateLimit(Transaction txn,String accountId) async {
    final ids = [
      accountId,
      for (final p in _rateLimitPlatformIds) '$p-$accountId',
    ];
    final placeholders = List.filled(ids.length, '?').join(',');
    await txn.delete(
      'auth_rate_limit',
      where: 'account_id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// F324 (Sprint 83): clear everything tied to the OLD sign-in of [accountId]
  /// when the address is added again, so nothing from the old sign-in or
  /// server follows the new credentials. The user's choices
  /// ([accountSettingKeysKept]) and the scan history are left alone.
  ///
  /// Always cleared: the sign-in-required flag and its notice time. NOT
  /// cleared: the failed-password lockout count, which resets only on a
  /// successful login (7.7.1 Q3 = 2). With [resetServerState] (a new account or a
  /// replaced one, not a plain password repair) also the per-folder cursors,
  /// the legacy history id and the background schedule rows, because a new
  /// server or mailbox can have different UIDs and history ids.
  ///
  /// No catch: every table is created by `_createTables` or its migration, so
  /// a failure is real and the caller reports it.
  Future<void> refreshForReAdd(String accountId,
      {required bool resetServerState}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'account_settings',
        where: 'account_id = ? AND setting_key IN (?, ?)',
        whereArgs: [
          accountId,
          'gmail_sign_in_required',
          'gmail_sign_in_notified_at',
        ],
      );
      // Sprint 83 7.7.1 (Harold Q3 = 2): the failed-password lockout count is
      // NOT cleared here. Saving a password proves nothing; the count resets
      // only when a login succeeds (`AuthRateLimiter.recordSuccess` in
      // `GenericIMAPAdapter.loadCredentials`). Account delete still clears it.
      if (resetServerState) {
        await txn.delete('account_folder_cursors',
            where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('background_scan_schedule',
            where: 'account_id = ?', whereArgs: [accountId]);
        await txn.update('accounts', {'last_history_id': null},
            where: 'account_id = ?', whereArgs: [accountId]);
      }
    });
  }

  /// Wipe every table and every credential. Returns the app to a
  /// fresh-install state.
  ///
  /// Intended to be the action behind Settings > General > Reset App >
  /// Delete All Data. Caller is responsible for showing the confirmation
  /// dialog and (optionally) restarting the app afterwards.
  Future<void> wipeAllData() async {
    _logger.w('Wiping ALL user data (full reset requested)');
    await _dbHelper.deleteAllData();
    try {
      await _credStore.deleteAllCredentials();
    } catch (e) {
      _logger.w('Credential wipe reported a partial failure: $e');
    }
    _logger.w('Full data wipe complete');
  }
}
