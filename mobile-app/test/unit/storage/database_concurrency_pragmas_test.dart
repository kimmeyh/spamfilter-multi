/// PR #448 test review (Sprint 75): pin the two PRAGMAs F243 now depends on.
///
/// Before F243, a Windows `--background-scan` process exited while the app was
/// open (BUG-S37-1 / F98 "database is locked" protection). F243 removed that
/// deferral, so the app and a background process now write the same database
/// at the same time, and the ONLY protection left is `journal_mode = WAL`
/// plus `busy_timeout = 30000` in `DatabaseHelper`'s `onConfigure`. Before
/// this file nothing asserted either one: dropping or reordering that line
/// would bring back the Sprint 37 lock failure with CI green.
///
/// Test 2 proves the behavior, not only the setting: a second connection holds
/// the write lock, and a write through `DatabaseHelper` WAITS for it instead of
/// failing with "database is locked".
///
/// What these do NOT catch: two separate OS processes (the test uses two
/// connections in one process, which SQLite locks the same way through the
/// file), and a lock held longer than 30 s, which still fails -- by design.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() => testHelper.tearDown());

  test('DatabaseHelper opens with WAL journaling and a 30 s busy timeout',
      () async {
    final db = await DatabaseHelper().database;
    final timeout = (await db.rawQuery('PRAGMA busy_timeout')).first.values;
    expect(timeout.first, 30000);
    final mode = (await db.rawQuery('PRAGMA journal_mode')).first.values;
    expect(mode.first.toString().toLowerCase(), 'wal');
  });

  test('a write WAITS for another connection\'s write lock instead of '
      'failing "database is locked"', () async {
    final db = await DatabaseHelper().database;
    await db.execute(
        'CREATE TABLE IF NOT EXISTS lock_probe (id INTEGER PRIMARY KEY)');

    // A second connection to the same file takes the write lock. It must NOT
    // share the FFI worker isolate: that isolate runs one statement at a time,
    // so the COMMIT below would queue behind the blocked insert and the test
    // would deadlock until the timeout. The no-isolate factory runs here.
    // singleInstance: false -- otherwise sqflite returns the SAME connection.
    final other = await databaseFactoryFfiNoIsolate.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(singleInstance: false));
    await other.execute('BEGIN IMMEDIATE');
    await other.execute('INSERT INTO lock_probe (id) VALUES (1)');

    final started = DateTime.now();
    final write = db.insert('lock_probe', {'id': 2});
    // Release the lock after a delay the write must wait through.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await other.execute('COMMIT');
    await write; // throws DatabaseException (database is locked) without
    //              busy_timeout
    final waited = DateTime.now().difference(started);
    await other.close();

    expect(waited, greaterThanOrEqualTo(const Duration(milliseconds: 1400)));
    final rows = await db.query('lock_probe', orderBy: 'id');
    expect(rows.map((r) => r['id']), [1, 2]);
  },
      // Windows only. F243's concurrent writers (the app and a
      // `--background-scan` process) exist only on Windows, which is where
      // this passes. On the ubuntu CI runner (PR #448, 2026-10-04) the insert
      // waited the full ~1.5 s hold and then failed "database is locked"
      // (code 5) the moment the other connection committed. CAUSE NOT
      // ESTABLISHED -- what would settle it: the extended result code
      // (SQLITE_BUSY_SNAPSHOT vs plain SQLITE_BUSY) and the runner's SQLite
      // version. Test 1 (the PRAGMA values) runs on every host.
      skip: !Platform.isWindows);
}
