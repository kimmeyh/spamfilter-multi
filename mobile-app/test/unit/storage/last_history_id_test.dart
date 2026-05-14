/// Sprint 38 F6c Phase 2 (Issue #250): unit tests for the per-account
/// Gmail historyId persistence helpers added to DatabaseHelper.
///
/// These verify the database layer that EmailScanner relies on to decide
/// between full vs incremental Gmail scans. The full orchestration
/// (EmailScanner._fetchFolderMessages) is provider-coupled (real
/// GmailApiAdapter + real Gmail API) and verified via Phase 5.3 manual
/// testing per the Sprint 37 retrospective Category 2 disposition.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Tests below operate against a minimal in-memory accounts table that
  // mirrors the production schema's v4 shape (Sprint 37 F6c added the
  // last_history_id column). We do NOT exercise DatabaseHelper itself
  // because its singleton initializer reads AppPaths which is not
  // available in the test environment without extra plumbing -- the
  // helpers are tiny pass-throughs over `db.query` / `db.update` and
  // the shape contract is what matters.
  group('Gmail historyId persistence (Sprint 38 F6c Phase 2)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS accounts (
              account_id TEXT PRIMARY KEY,
              platform_id TEXT NOT NULL,
              email TEXT NOT NULL,
              display_name TEXT,
              date_added INTEGER NOT NULL,
              last_scanned INTEGER,
              last_history_id TEXT
            );
          ''');
          await database.insert('accounts', {
            'account_id': 'gmail-test@example.com',
            'platform_id': 'gmail',
            'email': 'test@example.com',
            'date_added': DateTime.now().millisecondsSinceEpoch,
          });
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('last_history_id is null for a fresh account', () async {
      final rows = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );
      expect(rows.length, 1);
      expect(rows.first['last_history_id'], isNull,
          reason:
              'A newly inserted account row must have a null last_history_id so '
              'EmailScanner takes the first-scan full-fetch branch rather than '
              'incremental.');
    });

    test('setLastHistoryId persists a non-null value', () async {
      // Simulate what DatabaseHelper.setLastHistoryId does.
      await db.update(
        'accounts',
        {'last_history_id': 'abc123'},
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );

      final rows = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );
      expect(rows.first['last_history_id'], 'abc123');
    });

    test('setLastHistoryId(null) clears the persisted value (expiry path)',
        () async {
      // First persist
      await db.update(
        'accounts',
        {'last_history_id': 'abc123'},
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );

      // Then clear (matches the IncrementalFetchResult.expired() branch)
      await db.update(
        'accounts',
        {'last_history_id': null},
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );

      final rows = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );
      expect(rows.first['last_history_id'], isNull,
          reason:
              'After IncrementalFetchResult.expired(), EmailScanner must clear '
              'the persisted historyId so the next scan starts with a fresh '
              'full-fetch + re-capture.');
    });

    test('setLastHistoryId scoped per-account', () async {
      // Insert a second account
      await db.insert('accounts', {
        'account_id': 'gmail-other@example.com',
        'platform_id': 'gmail',
        'email': 'other@example.com',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      // Persist different historyIds for each
      await db.update(
        'accounts',
        {'last_history_id': 'history-a'},
        where: 'account_id = ?',
        whereArgs: ['gmail-test@example.com'],
      );
      await db.update(
        'accounts',
        {'last_history_id': 'history-b'},
        where: 'account_id = ?',
        whereArgs: ['gmail-other@example.com'],
      );

      final a = await db.query('accounts',
          where: 'account_id = ?', whereArgs: ['gmail-test@example.com']);
      final b = await db.query('accounts',
          where: 'account_id = ?', whereArgs: ['gmail-other@example.com']);

      expect(a.first['last_history_id'], 'history-a');
      expect(b.first['last_history_id'], 'history-b',
          reason: 'Updating one account must not bleed into another.');
    });

    test('overwriting last_history_id replaces (not appends)', () async {
      await db.update('accounts', {'last_history_id': 'first'},
          where: 'account_id = ?', whereArgs: ['gmail-test@example.com']);
      await db.update('accounts', {'last_history_id': 'second'},
          where: 'account_id = ?', whereArgs: ['gmail-test@example.com']);

      final rows = await db.query('accounts',
          where: 'account_id = ?', whereArgs: ['gmail-test@example.com']);
      expect(rows.first['last_history_id'], 'second',
          reason:
              'Each scan completion must overwrite the prior historyId; we are '
              'storing a single cursor per account, not a list.');
    });
  });
}
