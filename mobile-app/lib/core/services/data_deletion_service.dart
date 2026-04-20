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

import 'package:logger/logger.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../util/redact.dart';
import '../storage/database_helper.dart';

/// Result of a deletion operation, useful for surfacing counts in the UI.
class DeletionReport {
  final int scanResultsDeleted;
  final int emailActionsDeleted;
  final int unmatchedEmailsDeleted;
  final int accountSettingsDeleted;
  final int backgroundScheduleEntriesDeleted;
  final bool credentialsDeleted;

  const DeletionReport({
    this.scanResultsDeleted = 0,
    this.emailActionsDeleted = 0,
    this.unmatchedEmailsDeleted = 0,
    this.accountSettingsDeleted = 0,
    this.backgroundScheduleEntriesDeleted = 0,
    this.credentialsDeleted = false,
  });
}

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

      accountSettings = await txn.delete(
        'account_settings',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );

      // Drop any future background-scan schedule rows for this account.
      // Table might not exist on fresh installs; guard against that.
      try {
        scheduleEntries = await txn.delete(
          'background_scan_schedule',
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      } catch (_) {
        scheduleEntries = 0;
      }

      // Rate-limit state (SEC-22) keyed by accountId too.
      try {
        await txn.delete(
          'auth_rate_limit',
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      } catch (_) {
        // Table may not exist pre-v3; ignore.
      }

      await txn.delete(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
    });

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
      backgroundScheduleEntriesDeleted: scheduleEntries,
      credentialsDeleted: credsDeleted,
    );
    _logger.i('Account deletion complete: scans=$scans, emails=$emails, '
        'unmatched=$unmatched, accountSettings=$accountSettings, '
        'schedule=$scheduleEntries, creds=$credsDeleted');
    return report;
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
