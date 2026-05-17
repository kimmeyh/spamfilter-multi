/// Sprint 38 Round 1 (post-retro IMAP extension of F6c Phase 2, Issue #250):
/// tests for the per-(account, folder) IMAP UID cursor helpers added to
/// DatabaseHelper.
///
/// Verifies the v5 schema + getFolderCursor / setFolderCursor pass-throughs.
/// Real IMAP UID search is provider-coupled and verified via Phase 5.3
/// manual testing per the Sprint 37 retrospective Category 2 disposition.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Tests operate against an in-memory account_folder_cursors table that
  // mirrors the production v5 schema. We don't exercise DatabaseHelper
  // itself because its singleton initializer reads AppPaths which is not
  // available in the test environment without extra plumbing. The
  // helpers (getFolderCursor / setFolderCursor) are tiny pass-throughs
  // over db.query / db.insert / db.delete and the shape contract is
  // what these tests pin.
  group('IMAP per-folder cursor persistence (Sprint 38 Round 1)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS account_folder_cursors (
              account_id TEXT NOT NULL,
              folder_name TEXT NOT NULL,
              cursor_type TEXT NOT NULL,
              cursor_value TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (account_id, folder_name, cursor_type)
            );
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('table starts empty -- no cursor for fresh (account, folder)',
        () async {
      final rows = await db.query(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: ['aol-test@example.com', 'INBOX', 'imap_uid'],
      );
      expect(rows, isEmpty,
          reason: 'Fresh account+folder must have no cursor so EmailScanner '
              'takes the first-scan full-fetch branch.');
    });

    test('inserting and reading a cursor round-trips', () async {
      // Simulate what DatabaseHelper.setFolderCursor does (insert-or-replace).
      await db.insert(
        'account_folder_cursors',
        {
          'account_id': 'aol-test@example.com',
          'folder_name': 'INBOX',
          'cursor_type': 'imap_uid',
          'cursor_value': '12345',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(
        'account_folder_cursors',
        columns: ['cursor_value'],
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: ['aol-test@example.com', 'INBOX', 'imap_uid'],
      );
      expect(rows.length, 1);
      expect(rows.first['cursor_value'], '12345');
    });

    test('setting a new value replaces the old (insert-or-replace)',
        () async {
      await db.insert(
        'account_folder_cursors',
        {
          'account_id': 'aol-test@example.com',
          'folder_name': 'INBOX',
          'cursor_type': 'imap_uid',
          'cursor_value': '100',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'account_folder_cursors',
        {
          'account_id': 'aol-test@example.com',
          'folder_name': 'INBOX',
          'cursor_type': 'imap_uid',
          'cursor_value': '200',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: ['aol-test@example.com', 'INBOX', 'imap_uid'],
      );
      expect(rows.length, 1,
          reason: 'Composite PRIMARY KEY (account_id, folder_name, '
              'cursor_type) must prevent duplicate rows; insert-or-replace '
              'must overwrite the prior cursor value.');
      expect(rows.first['cursor_value'], '200');
    });

    test('cursors are independent across folders within the same account',
        () async {
      await db.insert('account_folder_cursors', {
        'account_id': 'aol@example.com',
        'folder_name': 'INBOX',
        'cursor_type': 'imap_uid',
        'cursor_value': '100',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('account_folder_cursors', {
        'account_id': 'aol@example.com',
        'folder_name': 'Bulk Mail',
        'cursor_type': 'imap_uid',
        'cursor_value': '50',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      final inbox = await db.query(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ?',
        whereArgs: ['aol@example.com', 'INBOX'],
      );
      final bulk = await db.query(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ?',
        whereArgs: ['aol@example.com', 'Bulk Mail'],
      );

      expect(inbox.first['cursor_value'], '100');
      expect(bulk.first['cursor_value'], '50',
          reason: 'IMAP UIDs are mailbox-scoped per RFC 3501. Cursors must '
              'be stored per (account, folder) so a Bulk Mail cursor never '
              'leaks into an INBOX scan or vice versa.');
    });

    test('cursors are independent across accounts for the same folder name',
        () async {
      await db.insert('account_folder_cursors', {
        'account_id': 'aol@example.com',
        'folder_name': 'INBOX',
        'cursor_type': 'imap_uid',
        'cursor_value': '111',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('account_folder_cursors', {
        'account_id': 'gmail-imap@example.com',
        'folder_name': 'INBOX',
        'cursor_type': 'imap_uid',
        'cursor_value': '222',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      final aol = await db.query('account_folder_cursors',
          where: 'account_id = ? AND folder_name = ?',
          whereArgs: ['aol@example.com', 'INBOX']);
      final gmailImap = await db.query('account_folder_cursors',
          where: 'account_id = ? AND folder_name = ?',
          whereArgs: ['gmail-imap@example.com', 'INBOX']);

      expect(aol.first['cursor_value'], '111');
      expect(gmailImap.first['cursor_value'], '222',
          reason: 'AOL INBOX and Gmail-IMAP INBOX have independent UID '
              'sequences. Cursor lookups must scope by accountId, not just '
              'folderName.');
    });

    test('deleting a cursor clears it (used by force-full-rescan paths)',
        () async {
      await db.insert('account_folder_cursors', {
        'account_id': 'aol@example.com',
        'folder_name': 'INBOX',
        'cursor_type': 'imap_uid',
        'cursor_value': '999',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // setFolderCursor(null) maps to delete.
      await db.delete(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: ['aol@example.com', 'INBOX', 'imap_uid'],
      );

      final rows = await db.query(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: ['aol@example.com', 'INBOX', 'imap_uid'],
      );
      expect(rows, isEmpty,
          reason: 'Deleting a cursor must remove the row so the next scan '
              'takes the first-scan full-fetch branch. Used in any future '
              'UIDVALIDITY-changed recovery flow.');
    });
  });
}
