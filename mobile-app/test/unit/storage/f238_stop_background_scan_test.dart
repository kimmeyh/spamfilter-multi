/// F238 (Sprint 75): stop a running background scan so a manual scan can start.
///
/// The background scan runs in ANOTHER isolate (Android WorkManager) or
/// ANOTHER process (Windows Task Scheduler), so the UI cannot reach its
/// ScanCoordinator. The stop request therefore travels through the one thing
/// both sides read, the scan's own `scan_results` row:
///   - the UI writes `cancel_requested_at` (DB v11) on the holder row;
///   - the scanning isolate reads it on its EXISTING heartbeat tick and
///     requests cancel through ITS ScanCoordinator (the F224 path), so the
///     scan stops at its next batch boundary and its row closes as
///     `interrupted` with "Stopped so your manual scan could start";
///   - the manual side waits, BOUNDED, for the row to close, then takes the
///     normal per-account claim.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1):
///   - Two REAL connections: one sqflite connection stands in for the UI
///     isolate and the worker. Cross-connection visibility of the written
///     timestamp is SQLite's job and is proven only on the device / with a
///     real Windows worker process (Manual Validation).
///   - The scanner's `ScanCancelledException` handler is simulated by calling
///     `cancelScan()` directly, the way `email_scanner.dart:1061` does. That
///     the handler is wired is pinned by `f224_scanner_cancel_wiring_test`.
///   - A single IMAP fetch or connect longer than the 90 s bound has no batch
///     boundary inside it, so the bound can expire although the request was
///     written and will be honored later -- the user is told to retry.
///   - The scanner marks the row (`cancelScan`) BEFORE its `finally`
///     disconnects, so there is a sub-second window where the manual side may
///     claim while the background socket is still closing (pre-existing F224
///     ordering, not changed here).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart' show databaseVersion;
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late ScanResultStore store;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = ScanResultStore(testHelper.dbHelper);
    await testHelper.createTestAccount('acct-a');
    await testHelper.createTestAccount('acct-b');
    ScanCoordinator.resetForTest();
  });

  tearDown(() async {
    EmailScanProvider.debugHeartbeatIntervalOverride = null;
    ScanCoordinator.resetForTest();
    await testHelper.tearDown();
  });

  int ago(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

  Future<int> insertRow({
    required String accountId,
    required String scanType,
    String status = 'in_progress',
    required int startedAt,
    int? heartbeatAt,
  }) async {
    final db = await testHelper.dbHelper.database;
    return db.insert('scan_results', {
      'account_id': accountId,
      'scan_type': scanType,
      'scan_mode': 'readOnly',
      'started_at': startedAt,
      'total_emails': 10,
      'processed_count': 0,
      'deleted_count': 0,
      'moved_count': 0,
      'safe_sender_count': 0,
      'no_rule_count': 0,
      'error_count': 0,
      'status': status,
      'folders_scanned': '[]',
      'last_heartbeat_at': heartbeatAt,
    });
  }

  Future<Map<String, Object?>> rowById(int id) async {
    final db = await testHelper.dbHelper.database;
    return (await db.query('scan_results', where: 'id = ?', whereArgs: [id]))
        .single;
  }

  Future<List<Map<String, Object?>>> liveRows(String accountId) async {
    final db = await testHelper.dbHelper.database;
    return db.query('scan_results',
        where: 'account_id = ? AND status = ?',
        whereArgs: [accountId, 'in_progress']);
  }

  /// A persisted BACKGROUND scan the way the worker runs one: the lease is
  /// taken first (EmailScanner.scanInbox does this before startScan), then
  /// the provider claims its row and starts its heartbeat.
  Future<(EmailScanProvider, ScanLease, int)> startBackgroundScan({
    Duration heartbeat = const Duration(milliseconds: 25),
  }) async {
    EmailScanProvider.debugHeartbeatIntervalOverride = heartbeat;
    final lease = await ScanCoordinator.instance
        .acquire(scanType: 'background', accountId: 'acct-a');
    final provider = EmailScanProvider();
    provider.initializePersistence(
      scanResultStore: store,
      unmatchedEmailStore: UnmatchedEmailStore(testHelper.dbHelper),
      databaseHelper: testHelper.dbHelper,
    );
    provider.setCurrentAccountId('acct-a');
    await provider.startScan(
        totalEmails: 5, scanType: 'background', platformId: 'test-platform');
    final id = (await liveRows('acct-a')).single['id'] as int;
    return (provider, lease, id);
  }

  group('T-1 (AC-1) -- the stop request reaches the scan through its row', () {
    test('request written; the heartbeat tick requests cancel in the '
        'scanning isolate; the row ends interrupted with the stop-for-manual '
        'reason', () async {
      final (provider, lease, id) = await startBackgroundScan();
      expect(lease.info.cancelRequested, isFalse);

      expect(await store.requestCancel(id), isTrue,
          reason: 'a live row must take the request');
      expect((await rowById(id))['cancel_requested_at'], isNotNull);

      // Several ticks.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(lease.info.cancelRequested, isTrue,
          reason: 'the tick must turn the row flag into a coordinator cancel');
      expect(provider.debugPendingCancelReason,
          ScanResultStore.stoppedForManualScanReason);
      // The tick must NOT close the row: that is the scanner's job once its
      // lease and session are actually being torn down.
      expect((await rowById(id))['status'], 'in_progress',
          reason: 'closing the row early would admit the manual scan while '
              'the background IMAP session is still open');

      // What the scanner's ScanCancelledException handler does
      // (email_scanner.dart: `await scanProvider.cancelScan();`).
      await provider.cancelScan();
      ScanCoordinator.instance.release(lease);

      final row = await rowById(id);
      expect(row['status'], 'interrupted');
      expect(row['error_message'], ScanResultStore.stoppedForManualScanReason);
      expect(row['error_message'], isNot(contains('error')),
          reason: 'R-4: never recorded as an error');
      expect(provider.wasCancelled, isTrue);
      expect(provider.debugHeartbeatActive, isFalse);
      expect(await liveRows('acct-a'), isEmpty);
    });

    test('no request: the ticks pass and nothing is cancelled', () async {
      final (provider, lease, id) = await startBackgroundScan();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(lease.info.cancelRequested, isFalse);
      expect(provider.debugPendingCancelReason, isNull);
      expect((await rowById(id))['status'], 'in_progress');
      await provider.completeScan();
      ScanCoordinator.instance.release(lease);
    });

    test("the user's own Cancel keeps its own text when no request was seen",
        () async {
      final (provider, lease, id) = await startBackgroundScan();
      await provider.cancelScan();
      ScanCoordinator.instance.release(lease);
      expect((await rowById(id))['error_message'],
          ScanResultStore.cancelledByUserReason);
    });

    test('a request on a finished row is refused and leaves it alone',
        () async {
      final done = await insertRow(
          accountId: 'acct-a', scanType: 'background', status: 'completed',
          startedAt: ago(const Duration(minutes: 1)));
      expect(await store.requestCancel(done), isFalse);
      expect((await rowById(done))['cancel_requested_at'], isNull);
      expect(await store.isCancelRequested(done), isFalse);
    });

    test("a request targets ONE row: another account's live scan is untouched",
        () async {
      final a = await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(seconds: 10)));
      final b = await insertRow(
          accountId: 'acct-b', scanType: 'background',
          startedAt: ago(const Duration(seconds: 10)));
      expect(await store.requestCancel(a), isTrue);
      expect(await store.isCancelRequested(a), isTrue);
      expect(await store.isCancelRequested(b), isFalse);
    });

    test('a missing row reads as "no request"', () async {
      expect(await store.isCancelRequested(999999), isFalse);
    });
  });

  group('T-2 (AC-2, AC-3) -- the bounded wait', () {
    test('returns true when the holder closes, and the manual claim is then '
        'granted with never two live rows', () async {
      final holder = await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(seconds: 10)));
      final waiting = store.waitForScanToClose(holder,
          bound: const Duration(seconds: 5),
          pollInterval: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await liveRows('acct-a'), hasLength(1),
          reason: 'the wait must write nothing while it waits');
      // The scanner's handler closes the row.
      await store.markScanCancelled(holder,
          reason: ScanResultStore.stoppedForManualScanReason);
      expect(await waiting, isTrue);

      final claim = await store.claimAccountScan(ScanResult(
        accountId: 'acct-a',
        scanType: 'manual',
        scanMode: 'readOnly',
        startedAt: DateTime.now().millisecondsSinceEpoch,
        totalEmails: 0,
        status: 'in_progress',
      ));
      expect(claim.granted, isTrue);
      expect(await liveRows('acct-a'), hasLength(1),
          reason: 'the stopped holder and the new scan never overlap');
      expect((await rowById(holder))['status'], 'interrupted');
    });

    test('returns true when the heartbeat went stale -- the claim will reap '
        'that holder', () async {
      final dead = await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(minutes: 10)),
          heartbeatAt: ago(ScanCoordinator.heartbeatFreshness +
              const Duration(seconds: 30)));
      expect(
          await store.waitForScanToClose(dead,
              bound: const Duration(milliseconds: 200),
              pollInterval: const Duration(milliseconds: 20)),
          isTrue);
    });

    test('returns true at once for a row that does not exist', () async {
      expect(
          await store.waitForScanToClose(999999,
              bound: const Duration(milliseconds: 200),
              pollInterval: const Duration(milliseconds: 20)),
          isTrue);
    });

    test('TIMES OUT when the holder stays live past the bound; nothing was '
        'written and the holder is untouched', () async {
      final holder = await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(seconds: 10)),
          heartbeatAt: ago(const Duration(seconds: 5)));
      final started = DateTime.now();
      final closed = await store.waitForScanToClose(holder,
          bound: const Duration(milliseconds: 150),
          pollInterval: const Duration(milliseconds: 20));
      expect(closed, isFalse);
      expect(DateTime.now().difference(started),
          greaterThanOrEqualTo(const Duration(milliseconds: 150)),
          reason: 'the wait must last the bound before giving up');
      expect(DateTime.now().difference(started),
          lessThan(const Duration(seconds: 3)),
          reason: 'and must not run past it');
      final rows = await liveRows('acct-a');
      expect(rows, hasLength(1));
      expect(rows.single['id'], holder);
      expect(rows.single['status'], 'in_progress');
    });

    test('the production bound and poll are what the card says', () {
      expect(ScanResultStore.stopForManualScanBound,
          const Duration(seconds: 90));
      expect(ScanResultStore.stopForManualScanPollInterval,
          lessThan(ScanResultStore.stopForManualScanBound));
      expect(ScanResultStore.stopForManualScanBound,
          greaterThan(ScanCoordinator.heartbeatInterval),
          reason: 'the request is read on a heartbeat tick; a bound shorter '
              'than the interval could expire before it is ever seen');
    });
  });

  group('T-4 (AC-5) -- DB v11', () {
    test('a fresh database has scan_results.cancel_requested_at', () async {
      final db = await testHelper.dbHelper.database;
      final cols = (await db.rawQuery('PRAGMA table_info(scan_results)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('cancel_requested_at'));
    });

    test('the REAL DatabaseHelper upgrade adds the column to a v10 database '
        'and keeps existing rows', () async {
      // Build a v10-shaped file at the helper's own path, then let the real
      // DatabaseHelper reopen it -- its _upgradeTables must do the work. (A
      // test that re-implements the ALTER itself would pass with the real
      // migration deleted.)
      await testHelper.dbHelper.close();
      final dbFile = File(testHelper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v10 = await databaseFactoryFfi.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE scan_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL, scan_type TEXT NOT NULL,
                scan_mode TEXT NOT NULL, started_at INTEGER NOT NULL,
                completed_at INTEGER, total_emails INTEGER NOT NULL,
                processed_count INTEGER NOT NULL, deleted_count INTEGER NOT NULL,
                moved_count INTEGER NOT NULL, safe_sender_count INTEGER NOT NULL,
                no_rule_count INTEGER NOT NULL, error_count INTEGER NOT NULL,
                status TEXT NOT NULL, error_message TEXT,
                folders_scanned TEXT NOT NULL,
                last_heartbeat_at INTEGER
              );''');
            await db.insert('scan_results', {
              'account_id': 'legacy', 'scan_type': 'background',
              'scan_mode': 'readOnly', 'started_at': 1, 'total_emails': 1,
              'processed_count': 1, 'deleted_count': 0, 'moved_count': 0,
              'safe_sender_count': 0, 'no_rule_count': 0, 'error_count': 0,
              'status': 'completed', 'folders_scanned': '[]',
            });
          },
        ),
      );
      await v10.close();

      final upgraded = await testHelper.dbHelper.database;
      final cols = (await upgraded.rawQuery('PRAGMA table_info(scan_results)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('cancel_requested_at'));
      final rows = await upgraded.query('scan_results',
          where: 'account_id = ?', whereArgs: ['legacy']);
      expect(rows, hasLength(1), reason: 'existing rows must survive v11');
      expect(rows.single['cancel_requested_at'], isNull,
          reason: 'an old row carries no request');
      expect(await upgraded.getVersion(), databaseVersion);
    });
  });
}
