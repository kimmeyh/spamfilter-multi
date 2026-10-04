/// Sprint 75 review fixes to the F238 stop-for-manual flow.
///
/// M-1: cancelling a periodic timer does not stop a tick that is already
/// running. A heartbeat tick that was waiting on the database when its scan
/// ended used to go on and call ScanCoordinator.requestCancel(accountId) --
/// which cancels whatever scan holds the account NOW, possibly the user's
/// manual scan that had just started.
///
/// SF-5: the stopped scan's row is closed by markScanCancelled. On Windows the
/// UI process polls that row while waiting, so the write can meet "database
/// is locked"; one failed write left the row in_progress, the manual side
/// timed out saying the scan did not stop, and the account stayed blocked.
///
/// What these do NOT catch: two real processes (one SQLite connection here)
/// and a lock that outlasts the single retry.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

/// Holds every cancel-request read open until [gate] completes.
class _SlowReadStore extends ScanResultStore {
  _SlowReadStore(super.dbHelper);
  Completer<void> gate = Completer<void>();
  int reads = 0;

  @override
  Future<bool> isCancelRequested(int scanResultId) async {
    reads++;
    await gate.future;
    return super.isCancelRequested(scanResultId);
  }
}

/// Fails the first close with a locked database.
class _LockedOnceStore extends ScanResultStore {
  _LockedOnceStore(super.dbHelper);
  int attempts = 0;

  @override
  Future<bool> markScanCancelled(int scanResultId,
      {String reason = ScanResultStore.cancelledByUserReason}) async {
    attempts++;
    if (attempts == 1) throw Exception('DatabaseException(database is locked)');
    return super.markScanCancelled(scanResultId, reason: reason);
  }
}

void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount('acct-a');
    ScanCoordinator.resetForTest();
    EmailScanProvider.markCancelledRetryDelay = Duration.zero;
  });

  tearDown(() async {
    EmailScanProvider.debugHeartbeatIntervalOverride = null;
    EmailScanProvider.markCancelledRetryDelay =
        const Duration(milliseconds: 750);
    ScanCoordinator.resetForTest();
    await testHelper.tearDown();
  });

  Future<(EmailScanProvider, ScanLease, int)> startScan(
      ScanResultStore store) async {
    EmailScanProvider.debugHeartbeatIntervalOverride =
        const Duration(milliseconds: 25);
    final lease = await ScanCoordinator.instance
        .acquire(scanType: 'background', accountId: 'acct-a');
    final provider = EmailScanProvider()
      ..initializePersistence(
        scanResultStore: store,
        unmatchedEmailStore: UnmatchedEmailStore(testHelper.dbHelper),
        databaseHelper: testHelper.dbHelper,
      )
      ..setCurrentAccountId('acct-a');
    await provider.startScan(
        totalEmails: 5, scanType: 'background', platformId: 'test-platform');
    final db = await testHelper.dbHelper.database;
    final id = (await db.query('scan_results',
            where: 'account_id = ? AND status = ?',
            whereArgs: ['acct-a', 'in_progress']))
        .single['id'] as int;
    return (provider, lease, id);
  }

  test('M-1: a tick still reading when its scan ended does NOT cancel the '
      'next scan on the account', () async {
    final store = _SlowReadStore(testHelper.dbHelper);
    final (provider, lease, id) = await startScan(store);
    expect(await store.requestCancel(id), isTrue);

    // Let at least one tick start and block on the read.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(store.reads, greaterThan(0), reason: 'precondition: a tick is '
        'mid-read');

    // The scan ends (its own cancel/finish path) and the user's manual scan
    // takes the account.
    await provider.cancelScan();
    ScanCoordinator.instance.release(lease);
    final manual = await ScanCoordinator.instance
        .acquire(scanType: 'manual', accountId: 'acct-a');

    // Now the stale tick's read completes -- and finds the request.
    store.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(manual.info.cancelRequested, isFalse,
        reason: 'the stale tick must not stop the user\'s manual scan');
    ScanCoordinator.instance.release(manual);
  });

  test('SF-5: the close write retries once on a locked database and the row '
      'ends interrupted with its reason', () async {
    final store = _LockedOnceStore(testHelper.dbHelper);
    final (provider, lease, id) = await startScan(store);
    await provider.cancelScan(reason: ScanResultStore.stoppedForManualScanReason);
    ScanCoordinator.instance.release(lease);

    expect(store.attempts, 2);
    final db = await testHelper.dbHelper.database;
    final row = (await db.query('scan_results',
            where: 'id = ?', whereArgs: [id]))
        .single;
    expect(row['status'], 'interrupted',
        reason: 'left in_progress, the manual side would time out and the '
            'claim would refuse the account for 5 minutes');
    expect(row['error_message'], ScanResultStore.stoppedForManualScanReason);
  });
}
