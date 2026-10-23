/// F259 (Sprint 81, Harold Q3 = 1): the REAL v13 -> v15 database upgrade copies
/// each account's Gmail history cursor to INBOX in `account_folder_cursors`;
/// every other folder starts with no cursor.
///
/// Opens a database built at schema version 13 (with data) through the real
/// `DatabaseHelper`, so the shipped `_upgradeTables` runs (v14 and v15 both),
/// as it does on a user's phone or PC. The file is a temp copy.
///
/// What these tests do NOT catch (one line each):
///   - a user database whose `accounts.last_history_id` holds a value Gmail no
///     longer honors: the copy is faithful, and the scanner's expiry path
///     (404 -> full fetch) handles a stale one, as it did per account;
///   - the account's Gmail folder being configured under a name other than
///     INBOX: that folder then starts with no cursor (one full fetch), the
///     safe direction;
///   - a copy of the real dev database: the Definition of Done line is a
///     separate manual run recorded in the sprint plan.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  group('DB v15: the REAL upgrade of a v13 database', () {
    late DatabaseTestHelper helper;

    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    Future<void> buildV13Fixture({bool withCursorTable = true}) async {
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
              CREATE TABLE email_actions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_result_id INTEGER NOT NULL,
                email_id TEXT NOT NULL,
                email_from TEXT NOT NULL,
                email_subject TEXT NOT NULL,
                email_received_date INTEGER NOT NULL,
                email_folder TEXT NOT NULL,
                action_type TEXT NOT NULL,
                success INTEGER NOT NULL
              );''');
            if (withCursorTable) {
              await db.execute('''
                CREATE TABLE account_folder_cursors (
                  account_id TEXT NOT NULL,
                  folder_name TEXT NOT NULL,
                  cursor_type TEXT NOT NULL,
                  cursor_value TEXT NOT NULL,
                  updated_at INTEGER NOT NULL,
                  PRIMARY KEY (account_id, folder_name, cursor_type)
                );''');
              await db.insert('account_folder_cursors', {
                'account_id': 'aol-b@aol.com',
                'folder_name': 'INBOX',
                'cursor_type': 'oldest_no_rule_uid',
                'cursor_value': '4242',
                'updated_at': 1,
              });
            }
            Future<void> account(String id, String platform, String? hist) =>
                db.insert('accounts', {
                  'account_id': id,
                  'platform_id': platform,
                  'email': id,
                  'date_added': 1,
                  'last_history_id': hist,
                });
            await account('gmail-a@gmail.com', 'gmail', '777');
            await account('gmail-b@gmail.com', 'gmail', '888');
            await account('gmail-c@gmail.com', 'gmail', null);
            await account('gmail-d@gmail.com', 'gmail', '');
            await account('aol-b@aol.com', 'aol', null);
            await db.insert('email_actions', {
              'scan_result_id': 1,
              'email_id': '101',
              'email_from': 'x@y.z',
              'email_subject': 's',
              'email_received_date': 1,
              'email_folder': 'INBOX',
              'action_type': 'none',
              'success': 1,
            });
          },
        ),
      );
      await v13.close();
    }

    test('each account cursor lands on INBOX only; other folders, null and '
        'empty cursors, and other cursor types are untouched', () async {
      await buildV13Fixture();

      final db = await helper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, greaterThanOrEqualTo(15));

      final copied = await db.query('account_folder_cursors',
          where: 'cursor_type = ?',
          whereArgs: [DatabaseHelper.cursorTypeGmailHistoryId],
          orderBy: 'account_id');
      expect(copied.map((r) => '${r['account_id']}|${r['folder_name']}|'
          '${r['cursor_value']}'), [
        'gmail-a@gmail.com|inbox|777',
        'gmail-b@gmail.com|inbox|888',
      ]);
      expect(copied.every((r) => (r['updated_at'] as int) > 1), isTrue);

      // The scanner's own reader sees the copy, for INBOX in any case, and
      // sees NOTHING for any other folder.
      final h = helper.dbHelper;
      expect(await h.getGmailHistoryCursor('gmail-a@gmail.com', 'INBOX'), '777');
      expect(await h.getGmailHistoryCursor('gmail-a@gmail.com', 'Inbox'), '777');
      expect(await h.getGmailHistoryCursor('gmail-a@gmail.com', 'SPAM'), isNull);
      expect(await h.getGmailHistoryCursor('gmail-a@gmail.com', 'Unwanted'),
          isNull);
      expect(await h.getGmailHistoryCursor('gmail-c@gmail.com', 'INBOX'), isNull);
      expect(await h.getGmailHistoryCursor('gmail-d@gmail.com', 'INBOX'), isNull);

      // The IMAP cursor row is untouched.
      expect(await h.getFolderCursor('aol-b@aol.com', 'INBOX'), '4242');

      // The old column stays, unchanged (rollback = ignore the new rows).
      final acct = await db.query('accounts',
          where: 'account_id = ?', whereArgs: ['gmail-a@gmail.com']);
      expect(acct.single['last_history_id'], '777');
    });

    test('v14 ran in the same upgrade: the new column exists, old rows intact',
        () async {
      await buildV13Fixture();
      final db = await helper.dbHelper.database;
      final cols = (await db.rawQuery('PRAGMA table_info(email_actions)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('imap_sequence_number'));
      expect((await db.query('email_actions')).single['email_id'], '101');
    });

    test('a partial schema without the cursor table upgrades without error',
        () async {
      await buildV13Fixture(withCursorTable: false);
      final db = await helper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(await db.rawQuery('PRAGMA table_info(account_folder_cursors)'),
          isEmpty);
    });
  });
}
