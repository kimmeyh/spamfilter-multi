/// MV74-2 (Sprint 74): cross-isolate scan liveness.
///
/// The UI's ScanCoordinator cannot see a background scan on EITHER platform:
/// Android runs it in a separate isolate (workmanager_android creates a new
/// FlutterEngine per worker), Windows in a separate process. So liveness and
/// exclusion go through the shared `scan_results` row:
///   - the scanning isolate refreshes `last_heartbeat_at` (DB v9);
///   - the manual-scan notice counts a background row only if its heartbeat is
///     fresh;
///   - a background scan SKIPS an account with a live interactive scan
///     (ADR-0039 amendment, Harold Q3).
///
/// **What these tests do NOT catch**: that a heartbeat actually fires on a
/// real device across an isolate boundary under Doze -- the timer is proven to
/// START and STOP with the scan, and the queries are proven against rows, but
/// the two-isolate interleaving is Manual Validation on the S24+.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late ScanResultStore store;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = ScanResultStore(testHelper.dbHelper);
    await testHelper.createTestAccount('acct-a');
    await testHelper.createTestAccount('acct-b');
  });

  tearDown(() async {
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

  group('T-2 -- DB v9 schema', () {
    test('a fresh database has scan_results.last_heartbeat_at', () async {
      final db = await testHelper.dbHelper.database;
      final cols = (await db.rawQuery('PRAGMA table_info(scan_results)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('last_heartbeat_at'));
    });

    test('the REAL DatabaseHelper upgrade adds the column to a v8 database '
        'and keeps existing rows', () async {
      // Build a v8-shaped file at the helper's own path, then let the real
      // DatabaseHelper reopen it -- its _upgradeTables must do the work. (A
      // test that re-implements the ALTER itself would pass with the real
      // migration deleted.)
      await testHelper.dbHelper.close();
      final dbFile = File(testHelper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v8 = await databaseFactoryFfi.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(
          version: 8,
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
                folders_scanned TEXT NOT NULL
              );''');
            await db.insert('scan_results', {
              'account_id': 'legacy', 'scan_type': 'manual', 'scan_mode': 'readOnly',
              'started_at': 1, 'total_emails': 1, 'processed_count': 1,
              'deleted_count': 0, 'moved_count': 0, 'safe_sender_count': 0,
              'no_rule_count': 0, 'error_count': 0, 'status': 'completed',
              'folders_scanned': '[]',
            });
          },
        ),
      );
      await v8.close();

      final upgraded = await testHelper.dbHelper.database;
      final cols = (await upgraded.rawQuery('PRAGMA table_info(scan_results)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('last_heartbeat_at'));
      final rows = await upgraded.query('scan_results',
          where: 'account_id = ?', whereArgs: ['legacy']);
      expect(rows, hasLength(1), reason: 'existing rows must survive v9');
      expect(rows.single['last_heartbeat_at'], isNull);
      expect(await upgraded.getVersion(), 9);
    });
  });

  group('T-1 -- the manual-scan notice needs a FRESH heartbeat', () {
    test('a background row with a fresh heartbeat is active', () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(minutes: 20)),
          heartbeatAt: ago(const Duration(seconds: 30)));
      expect(await store.getActiveBackgroundScan(), isNotNull);
    });

    test('a background row whose heartbeat went stale is NOT active, well '
        'inside the 30-minute timeout (the F207 complaint)', () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(minutes: 10)),
          heartbeatAt: ago(ScanCoordinator.heartbeatFreshness +
              const Duration(minutes: 1)));
      expect(await store.getActiveBackgroundScan(), isNull);
    });

    test('a brand-new row with no heartbeat yet is active via started_at',
        () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(seconds: 5)));
      expect(await store.getActiveBackgroundScan(), isNotNull);
    });

    test('a pre-v9 row older than the freshness window is NOT active',
        () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(minutes: 8)));
      expect(await store.getActiveBackgroundScan(), isNull);
    });
  });

  group('recordHeartbeat', () {
    test('refreshes an in_progress row and never touches a finished one',
        () async {
      final live = await insertRow(
          accountId: 'acct-a', scanType: 'manual',
          startedAt: ago(const Duration(minutes: 1)));
      final done = await insertRow(
          accountId: 'acct-a', scanType: 'manual', status: 'completed',
          startedAt: ago(const Duration(minutes: 1)));
      await store.recordHeartbeat(live);
      await store.recordHeartbeat(done);
      final db = await testHelper.dbHelper.database;
      final liveRow = (await db.query('scan_results',
              where: 'id = ?', whereArgs: [live]))
          .single;
      final doneRow = (await db.query('scan_results',
              where: 'id = ?', whereArgs: [done]))
          .single;
      expect(liveRow['last_heartbeat_at'], isNotNull);
      expect(doneRow['last_heartbeat_at'], isNull);
    });
  });

  group('T-3 -- the scanning provider runs the heartbeat for its scan only',
      () {
    Future<EmailScanProvider> startPersisted() async {
      final provider = EmailScanProvider();
      provider.initializePersistence(
        scanResultStore: store,
        unmatchedEmailStore: UnmatchedEmailStore(testHelper.dbHelper),
        databaseHelper: testHelper.dbHelper,
      );
      provider.setCurrentAccountId('acct-a');
      await provider.startScan(totalEmails: 5, platformId: 'test-platform');
      return provider;
    }

    test('starts with a persisted scan and stops on completeScan', () async {
      final p = await startPersisted();
      expect(p.debugHeartbeatActive, isTrue);
      await p.completeScan();
      expect(p.debugHeartbeatActive, isFalse);
    });

    test('stops on errorScan', () async {
      final p = await startPersisted();
      await p.errorScan('boom');
      expect(p.debugHeartbeatActive, isFalse);
    });

    test('stops on cancelScan', () async {
      final p = await startPersisted();
      await p.cancelScan();
      expect(p.debugHeartbeatActive, isFalse);
    });

    test('stops on reset and on dispose', () async {
      final p = await startPersisted();
      p.reset();
      expect(p.debugHeartbeatActive, isFalse);
      final q = await startPersisted();
      q.dispose();
      expect(q.debugHeartbeatActive, isFalse);
    });

    test('review C-2: the timer really WRITES -- the row\'s heartbeat is set '
        'and moves forward', () async {
      EmailScanProvider.debugHeartbeatIntervalOverride =
          const Duration(milliseconds: 40);
      addTearDown(() => EmailScanProvider.debugHeartbeatIntervalOverride = null);
      final p = await startPersisted();
      final db = await testHelper.dbHelper.database;
      Future<int?> beat() async => (await db.query('scan_results',
              where: 'account_id = ? AND status = ?',
              whereArgs: ['acct-a', 'in_progress']))
          .single['last_heartbeat_at'] as int?;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final first = await beat();
      expect(first, isNotNull, reason: 'no write reached the row');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(await beat(), greaterThanOrEqualTo(first!));
      await p.completeScan();
    });

    test('the heartbeat interval stays well inside the freshness window', () {
      expect(ScanCoordinator.heartbeatInterval * 3,
          lessThan(ScanCoordinator.heartbeatFreshness),
          reason: 'a live scan must beat several times per freshness window, '
              'or it reads as dead and loses both the notice and the '
              'exclusion');
    });

    test('a UI-only scan (persist: false) runs no heartbeat', () async {
      final provider = EmailScanProvider();
      provider.initializePersistence(
        scanResultStore: store,
        unmatchedEmailStore: UnmatchedEmailStore(testHelper.dbHelper),
      );
      provider.setCurrentAccountId('acct-a');
      await provider.startScan(totalEmails: 5, persist: false);
      expect(provider.debugHeartbeatActive, isFalse);
    });
  });

  group('Harold Q1 -- re-processing holds a live claim', () {
    test('the claim is seen by the background exclusion, and gone when it '
        'ends', () async {
      final claim = await store.claimInteractive('acct-a',
          heartbeatInterval: const Duration(milliseconds: 30));
      expect(claim, isNotNull);
      final live = await store.getActiveInteractiveScanForAccount('acct-a');
      expect(live?.scanType, 'reprocess');
      await claim!.end();
      expect(await store.getActiveInteractiveScanForAccount('acct-a'), isNull);
    });

    test('a claim row never appears in Scan History, even one left behind',
        () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'reprocess', status: 'interrupted',
          startedAt: ago(const Duration(hours: 2)));
      await insertRow(
          accountId: 'acct-a', scanType: 'manual', status: 'completed',
          startedAt: ago(const Duration(hours: 1)));
      final history = await store.getAllScanHistory();
      expect(history.map((s) => s.scanType), ['manual']);
    });

    // SOURCE-TEXT wiring gate: the store behavior is proven above; this pins
    // that the Scan Results re-process path actually TAKES the claim and
    // ENDS it in its finally. (What it does not catch: the claim being taken
    // AFTER the connect -- the order is asserted by position below.)
    test('the re-process path takes the claim before connecting and ends it',
        () {
      final src = File('lib/ui/screens/results_display_screen.dart')
          .readAsStringSync();
      final claimAt = src.indexOf('.claimInteractive(widget.accountId)');
      final connectAt = src.indexOf(
          'await platform.loadCredentials(credentials);', claimAt);
      expect(claimAt, greaterThan(0));
      expect(connectAt, greaterThan(claimAt),
          reason: 'the claim must exist before the session opens');
      expect(src.contains('await claim?.end();'), isTrue);
    });

    test('a claim that cannot be written returns null instead of blocking the '
        're-process (no account row -> FK failure)', () async {
      expect(await store.claimInteractive('no-such-account'), isNull);
    });
  });

  group('review I-1 -- what a worker does after an account scan', () {
    test('a SKIP exports nothing and notifies nothing', () async {
      final calls = <String>[];
      await BackgroundScanCore.completeAccount(
        AccountScanOutcome.skipped('a manual scan is in progress',
            EmailScanProvider()),
        export: () async => calls.add('export'),
        notify: () async => calls.add('notify'),
      );
      expect(calls, isEmpty);
    });

    test('a real scan EXPORTS (the F206 Android fix) and then notifies',
        () async {
      final calls = <String>[];
      await BackgroundScanCore.completeAccount(
        AccountScanOutcome(
          emailsProcessed: 3, deletedCount: 0, movedCount: 0, safeCount: 0,
          unmatchedCount: 3, errorCount: 0, scanProvider: EmailScanProvider()),
        export: () async => calls.add('export'),
        notify: () async => calls.add('notify'),
      );
      expect(calls, ['export', 'notify']);
    });
  });

  group('T-4 -- background scans yield to a live interactive scan '
      '(ADR-0039 amendment)', () {
    test('finds a live manual or reprocess scan on the same account only',
        () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'reprocess',
          startedAt: ago(const Duration(seconds: 20)));
      expect(await store.getActiveInteractiveScanForAccount('acct-a'),
          isNotNull);
      expect(await store.getActiveInteractiveScanForAccount('acct-b'), isNull,
          reason: 'another account must not block this one');
    });

    test('ignores background rows, finished rows and stale heartbeats',
        () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'background',
          startedAt: ago(const Duration(seconds: 20)));
      await insertRow(
          accountId: 'acct-a', scanType: 'manual', status: 'completed',
          startedAt: ago(const Duration(seconds: 20)));
      await insertRow(
          accountId: 'acct-a', scanType: 'manual',
          startedAt: ago(const Duration(minutes: 12)),
          heartbeatAt: ago(const Duration(minutes: 9)));
      expect(await store.getActiveInteractiveScanForAccount('acct-a'), isNull);
    });

    test('BackgroundScanCore.scanAccount SKIPS the account -- before any '
        'connection -- while a manual scan is live on it', () async {
      await insertRow(
          accountId: 'acct-a', scanType: 'manual',
          startedAt: ago(const Duration(seconds: 10)));
      final outcome = await BackgroundScanCore.scanAccount(
        accountId: 'acct-a',
        platformId: 'test-platform',
        ruleSetProvider: RuleSetProvider(),
        settingsStore: SettingsStore(testHelper.dbHelper),
        scanResultStore: store,
      );
      expect(outcome.skipped, isTrue);
      expect(outcome.skippedReason, contains('manual'));
      expect(outcome.emailsProcessed, 0);
    });
  });
}
