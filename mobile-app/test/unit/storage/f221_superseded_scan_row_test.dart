/// F221 (Sprint 70): a superseded live scan stays "in progress" forever.
///
/// **Reported by Sean Jarvis (tester, 2026-09-17)**: starting a second live
/// scan leaves a row that never resolves, so Scan History shows scans that are
/// forever running.
///
/// **What the investigation actually found, and it is NOT what the card
/// assumed.** The card R-2(a) premise was that the SUPERSEDED scan row sticks.
/// It cannot: `email_scanner.dart:212` calls `startScan` (which creates the
/// persisted row) only AFTER `acquire()` at :170 returns. A queued scan
/// therefore holds no row at all while it waits -- it creates one when it
/// finally gets the lease. The screen earlier `startScan` at
/// `scan_progress_screen.dart:786` passes `persist: false` precisely so it
/// does not create one.
///
/// **So the orphan row comes from the scan that WAS running**, not the one
/// that queued behind it. That is the F220 wedge: the active scan is
/// interrupted, never marks its row, and the row sits at `in_progress`.
/// Reconciliation is the backstop, and until Sprint 70 it had exactly one
/// caller (startup), which is why only a restart cleared it.
///
/// These tests pin the backstop two halves: it MUST resolve a dead row, and it
/// MUST NOT touch a live one. T-2 (F175 serialisation invariant) is guarded
/// here and in `scan_coordinator_test.dart` -- the card names that as the
/// regression guard that matters most, because breaking serialisation
/// re-opens the Sprint 61 production failure.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

void main() {
  late DatabaseHelper db;
  late ScanResultStore store;
  late Directory tempDir;
  const accountId = 'aol-user@aol.com';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('f221_');
    db = DatabaseHelper();
    db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
    await db.deleteAllData();
    store = ScanResultStore(db);
    // scan_results has an FK to accounts (the Sprint 60 lesson).
    final database = await db.database;
    await database.insert('accounts', {
      'account_id': accountId,
      'platform_id': 'aol',
      'email': 'user@aol.com',
      'date_added': DateTime.now().millisecondsSinceEpoch,
    });
    ScanCoordinator.resetForTest();
  });

  tearDown(() async {
    ScanCoordinator.resetForTest();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<int> seedScan({
    required String status,
    required DateTime startedAt,
    String scanType = 'manual',
    DateTime? completedAt,
  }) {
    return store.addScanResult(ScanResult(
      accountId: accountId,
      scanType: scanType,
      scanMode: 'readOnly',
      startedAt: startedAt.millisecondsSinceEpoch,
      completedAt: completedAt?.millisecondsSinceEpoch,
      totalEmails: 10,
      processedCount: 10,
      deletedCount: 0,
      movedCount: 0,
      safeSenderCount: 0,
      noRuleCount: 10,
      errorCount: 0,
      status: status,
      foldersScanned: const ['Inbox'],
    ));
  }

  group('F221 T-1: an interrupted scan row resolves', () {
    test('the INTERRUPTED scan row is reconciled, not the queued one',
        () async {
      // This is the real Sean Jarvis shape: scan A was running and died.
      // There is no row for the queued scan B at all -- it never got the
      // lease, so it never called startScan.
      final wedgedId = await seedScan(
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final count = await store.reconcileStaleInProgressScans(
          staleAfter: const Duration(minutes: 30));

      expect(count, 1);
      final row = await store.getScanResultById(wedgedId);
      expect(row!.status, 'interrupted',
          reason: 'AC-1: no row may sit at in_progress permanently');
      expect(row.errorMessage, isNotNull,
          reason: 'a resolved row must say WHY, or Scan History shows a '
              'failure with no explanation');
    });

    test('a row younger than the guard is LEFT ALONE -- the unhappy input',
        () async {
      // The failure path that matters: over-eager reconciliation would mark a
      // genuinely live scan interrupted. On Windows the background worker
      // runs in a SEPARATE process this app cannot observe, so age is the
      // only safe signal.
      final liveId = await seedScan(
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      final count = await store.reconcileStaleInProgressScans(
          staleAfter: const Duration(minutes: 30));

      expect(count, 0);
      expect((await store.getScanResultById(liveId))!.status, 'in_progress',
          reason: 'clobbering a live scan would be a WORSE defect than the '
              'one being fixed -- it would corrupt a running scan history');
    });

    test('already-resolved rows are never rewritten', () async {
      final doneId = await seedScan(
        status: 'completed',
        startedAt: DateTime.now().subtract(const Duration(hours: 5)),
        completedAt: DateTime.now().subtract(const Duration(hours: 5)),
      );
      final erroredId = await seedScan(
        status: 'error',
        startedAt: DateTime.now().subtract(const Duration(hours: 5)),
      );

      await store.reconcileStaleInProgressScans(
          staleAfter: const Duration(minutes: 30));

      expect((await store.getScanResultById(doneId))!.status, 'completed');
      expect((await store.getScanResultById(erroredId))!.status, 'error',
          reason: 'an old FAILED scan keeps its own error -- overwriting it '
              'with "interrupted" would destroy the real diagnosis');
    });
  });

  group('F221 T-3: manual and background share ONE timeout', () {
    test('both paths read ScanCoordinator.scanTimeout, currently 30 minutes',
        () async {
      // Harold, 2026-09-17 (Class-2 reversal): manual scans previously had no
      // timeout, justified as "a user is watching and can cancel". That
      // premise expires when the user navigates away, so manual now takes the
      // same limit as background.
      //
      // Harold also said the shared value is PROVISIONAL: *"The 30 minute
      // timeout now for background jobs is likely too long since no known
      // scans take that long, but lets set both at 30 minutes for now."*
      // This test exists so that lowering it is a ONE-LINE change that cannot
      // silently apply to only one of the two paths -- a source grep below
      // proves neither path hardcodes its own literal.
      expect(ScanCoordinator.scanTimeout, const Duration(minutes: 30));
    });

    test('neither scan path hardcodes its own timeout literal', () {
      // A source gate, deliberately. The risk is not that the constant is
      // wrong today -- it is that a future edit tightens ONE path and leaves
      // the other at 30 minutes, which would be invisible in behaviour tests
      // until a scan hung on the forgotten path.
      for (final path in const [
        'lib/ui/screens/scan_progress_screen.dart',
        'lib/core/services/background_scan_core.dart',
      ]) {
        final src = File(path).readAsStringSync();
        final timeoutCalls = RegExp(r'\.timeout\(([^)]*)\)')
            .allMatches(src)
            .map((m) => m.group(1)!.trim())
            .where((arg) => arg.isNotEmpty)
            .toList();
        expect(timeoutCalls, isNotEmpty,
            reason: '$path should still wrap its scan in a timeout');
        for (final arg in timeoutCalls) {
          expect(arg, contains('scanTimeout'),
              reason: '$path passes "$arg" to .timeout() instead of the '
                  'shared ScanCoordinator.scanTimeout constant. Both scan '
                  'paths must move together.');
        }
      }
    });
  });

  group('F221 T-2: F175 serialisation still holds (the regression guard)', () {
    test('a second scan QUEUES behind the first rather than running with it',
        () async {
      // The card is explicit that breaking this re-opens the Sprint 61
      // production failure: four stacked AOL scans hit the per-account
      // session cap. The FIFO queue is correct and deliberate -- F221 fixes
      // bookkeeping and messaging, never the queue.
      final coordinator = ScanCoordinator.instance;

      final first = await coordinator.acquire(
        scanType: 'manual',
        accountId: accountId,
      );

      // waitLimit is the COORDINATOR own parameter, not an outer
      // Future.timeout -- an outer timeout fires on the test clock and would
      // pass even if serialisation were removed entirely.
      await expectLater(
        coordinator.acquire(
          scanType: 'manual',
          accountId: accountId,
          waitLimit: const Duration(milliseconds: 300),
        ),
        throwsA(isA<Exception>()),
        reason: 'AC-3: the second scan must WAIT. If this ever passes '
            'immediately, serialisation is gone and Sprint 61 is back.',
      );

      coordinator.release(first);
      expect(coordinator.active, isNull);
    });

    test('releasing the first scan hands the lease to the FIFO waiter',
        () async {
      final coordinator = ScanCoordinator.instance;
      final first = await coordinator.acquire(
        scanType: 'manual',
        accountId: accountId,
      );

      final queued = coordinator.acquire(
        scanType: 'background',
        accountId: accountId,
      );

      coordinator.release(first);

      final lease = await queued.timeout(const Duration(seconds: 2));
      expect(coordinator.active, isNotNull,
          reason: 'the queued scan must actually RUN once the lease frees -- '
              'a queue that never drains is the wedge under another name');
      coordinator.release(lease);
    });
  });
}
