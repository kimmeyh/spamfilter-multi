/// F302 (Sprint 81): the REAL v13 -> v14 database upgrade adds
/// `email_actions.imap_sequence_number` and keeps every existing row.
///
/// Opens a database built at schema version 13 (with data) through the real
/// `DatabaseHelper`, so the shipped `_upgradeTables` runs, as it does on a
/// user's phone or PC. The file is a temp copy; no real database is touched.
///
/// What these tests do NOT catch (one line each):
///   - a user database whose `email_actions` carries a column set other than
///     the shipped v13 one (the migration only adds one column and guards on
///     the table existing);
///   - Android's SQLite build (the ALTER is plain SQL, run by sqflite there
///     and by sqflite_common_ffi here);
///   - a copy of the dev database: the Definition of Done line "migrated on a
///     copy of the dev DB" is a manual step recorded in the sprint plan.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  group('DB v14: the REAL upgrade of a v13 database', () {
    late DatabaseTestHelper helper;

    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    Future<void> buildV13Fixture() async {
      await helper.dbHelper.close();
      final dbFile = File(helper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v13 = await databaseFactoryFfi.openDatabase(
        helper.testDbPath,
        options: OpenDatabaseOptions(
          version: 13,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE accounts (
                account_id TEXT PRIMARY KEY,
                platform_id TEXT NOT NULL,
                email TEXT NOT NULL,
                display_name TEXT,
                date_added INTEGER NOT NULL,
                last_scanned INTEGER,
                last_history_id TEXT
              );''');
            await db.execute('''
              CREATE TABLE scan_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL,
                scan_type TEXT NOT NULL,
                scan_mode TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                completed_at INTEGER,
                total_emails INTEGER NOT NULL,
                processed_count INTEGER NOT NULL,
                deleted_count INTEGER NOT NULL,
                moved_count INTEGER NOT NULL,
                safe_sender_count INTEGER NOT NULL,
                no_rule_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                error_message TEXT,
                folders_scanned TEXT NOT NULL,
                last_heartbeat_at INTEGER,
                cancel_requested_at INTEGER
              );''');
            // The v13 shape: no imap_sequence_number.
            await db.execute('''
              CREATE TABLE email_actions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_result_id INTEGER NOT NULL,
                email_id TEXT NOT NULL,
                email_from TEXT NOT NULL,
                email_subject TEXT NOT NULL,
                email_received_date INTEGER NOT NULL,
                email_folder TEXT NOT NULL,
                action_type TEXT NOT NULL,
                matched_rule_name TEXT,
                matched_pattern TEXT,
                is_safe_sender INTEGER NOT NULL DEFAULT 0,
                success INTEGER NOT NULL,
                error_message TEXT,
                email_still_exists INTEGER DEFAULT 1,
                rfc5322_message_id TEXT,
                auth_classification TEXT
              );''');
            await db.insert('accounts', {
              'account_id': 'aol-a@aol.com',
              'platform_id': 'aol',
              'email': 'a@aol.com',
              'date_added': 1,
            });
            await db.insert('scan_results', {
              'account_id': 'aol-a@aol.com',
              'scan_type': 'manual',
              'scan_mode': 'readonly',
              'started_at': 1,
              'total_emails': 2,
              'processed_count': 2,
              'deleted_count': 0,
              'moved_count': 0,
              'safe_sender_count': 0,
              'no_rule_count': 2,
              'error_count': 0,
              'status': 'completed',
              'folders_scanned': '["INBOX"]',
            });
            for (final id in ['101', '102']) {
              await db.insert('email_actions', {
                'scan_result_id': 1,
                'email_id': id,
                'email_from': 'x@y.z',
                'email_subject': 'subject $id',
                'email_received_date': 1,
                'email_folder': 'INBOX',
                'action_type': 'none',
                'success': 1,
              });
            }
          },
        ),
      );
      await v13.close();
    }

    test('adds the nullable column, keeps old rows (NULL), and the new column '
        'is writable', () async {
      await buildV13Fixture();

      final db = await helper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, greaterThanOrEqualTo(14));

      final cols = (await db.rawQuery('PRAGMA table_info(email_actions)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('imap_sequence_number'));

      final old = await db.query('email_actions', orderBy: 'id');
      expect(old.map((r) => r['email_id']), ['101', '102']);
      expect(old.every((r) => r['imap_sequence_number'] == null), isTrue,
          reason: 'existing rows keep NULL; nothing is back-filled');

      await db.insert('email_actions', {
        'scan_result_id': 1,
        'email_id': 'no-valid-uid',
        'imap_sequence_number': 7,
        'email_from': 'x@y.z',
        'email_subject': 's',
        'email_received_date': 1,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'success': 1,
      });
      final fresh =
          await db.query('email_actions', where: 'email_id = ?', whereArgs: ['no-valid-uid']);
      expect(fresh.single['imap_sequence_number'], 7);
    });

    test('a partial schema without email_actions upgrades without error',
        () async {
      await helper.dbHelper.close();
      final dbFile = File(helper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v13 = await databaseFactoryFfi.openDatabase(
        helper.testDbPath,
        options: OpenDatabaseOptions(
          version: 13,
          onCreate: (db, _) async =>
              db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, '
                  'value TEXT NOT NULL, value_type TEXT NOT NULL, '
                  'date_modified INTEGER NOT NULL);'),
        ),
      );
      await v13.close();

      final db = await helper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(
          (await db.rawQuery('PRAGMA table_info(email_actions)')), isEmpty,
          reason: 'the guard skips a missing table, as v9 to v11 do');
    });
  });
}
