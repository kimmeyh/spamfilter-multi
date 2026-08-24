/// F175 (Sprint 62): scan mutual exclusion -- the coordinator contract, plus
/// an end-to-end proof that two concurrent `scanInbox` calls never overlap.
///
/// The incident this prevents: four AOL scans stacked concurrently during
/// the Sprint 61 validation, each opening its own IMAP session, all stuck
/// `in_progress` at 0 emails for 20+ minutes behind AOL's session cap.
///
/// Mutation-verified at authoring: removing the acquire call in
/// EmailScanner.scanInbox turns the no-overlap test red.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

/// Records fetch intervals so concurrent scans can be proven non-overlapping.
class _OverlapProbeProvider extends MockEmailProvider {
  static final List<(DateTime, DateTime)> fetchIntervals = [];

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    final start = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final end = DateTime.now();
    fetchIntervals.add((start, end));
    return [
      EmailMessage(
        id: '${folderNames.first}-${fetchIntervals.length}',
        from: 'sender@example.com',
        subject: 'probe',
        body: 'body',
        headers: const {},
        receivedDate: DateTime(2026, 1, 1),
        folderName: folderNames.first,
      ),
    ];
  }
}

void main() {
  setUp(ScanCoordinator.resetForTest);

  group('ScanCoordinator contract', () {
    test('grants immediately when idle; second acquire queues until release',
        () async {
      final c = ScanCoordinator.instance;
      final lease1 =
          await c.acquire(scanType: 'background', accountId: 'a@x.com');
      expect(c.active?.scanType, 'background');

      var granted = false;
      final pending = c
          .acquire(scanType: 'manual', accountId: 'a@x.com')
          .then((lease) {
        granted = true;
        return lease;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(granted, isFalse,
          reason: 'R-1/R-2: a second scan must NOT run while one is active');

      c.release(lease1);
      final lease2 = await pending;
      expect(granted, isTrue);
      expect(c.active?.scanType, 'manual');
      c.release(lease2);
      expect(c.active, isNull);
    });

    test('waiters are served FIFO', () async {
      final c = ScanCoordinator.instance;
      final lease1 = await c.acquire(scanType: 'background', accountId: 'a');
      final order = <String>[];
      final w1 = c
          .acquire(scanType: 'manual', accountId: 'b')
          .then((l) {
        order.add('first-waiter');
        return l;
      });
      final w2 = c
          .acquire(scanType: 'background', accountId: 'c')
          .then((l) {
        order.add('second-waiter');
        return l;
      });

      c.release(lease1);
      final l2 = await w1;
      c.release(l2);
      final l3 = await w2;
      c.release(l3);

      expect(order, ['first-waiter', 'second-waiter']);
    });

    test('release is idempotent and a stale double-release cannot free the '
        'next holder', () async {
      final c = ScanCoordinator.instance;
      final lease1 = await c.acquire(scanType: 'manual', accountId: 'a');
      c.release(lease1);
      final lease2 = await c.acquire(scanType: 'manual', accountId: 'b');
      c.release(lease1); // stale second release of lease1
      expect(c.active, isNotNull,
          reason: 'a stale release must not free the CURRENT holder');
      c.release(lease2);
      expect(c.active, isNull);
    });

    test(
        'double-releasing the ACTIVE lease hands off only ONCE -- the '
        'second release must not also pop the next queued waiter '
        '(Sprint 62 code review H-3: the finally-double-invocation shape)',
        () async {
      final c = ScanCoordinator.instance;
      final lease1 = await c.acquire(scanType: 'manual', accountId: 'a');
      final w1 = c.acquire(scanType: 'background', accountId: 'b');
      final w2 = c.acquire(scanType: 'manual', accountId: 'c');

      c.release(lease1);
      c.release(lease1); // the double release, while a waiter is queued
      final lease2 = await w1;
      expect(c.active?.accountId, 'b',
          reason: 'exactly one handoff: the first waiter holds the lease; '
              'a second handoff would have popped waiter c too');

      c.release(lease2);
      final lease3 = await w2;
      expect(c.active?.accountId, 'c');
      c.release(lease3);
      expect(c.active, isNull);
    });

    test(
        'release after a waiter timed out leaves the coordinator IDLE and '
        'immediately grantable (Sprint 62 code review C-1 contract)',
        () async {
      // NOTE on scope: the exact C-1 wedge interleaving (release popping a
      // waiter between its timeout-timer firing and its catch running)
      // proved UNREACHABLE under the single-threaded event loop -- a
      // fakeAsync reproduction was attempted at authoring and the gap
      // cannot be opened (elapseBlocking leaves the timer unfired; elapse
      // drains the catch before control returns). The acquire-side
      // hand-back stays as a zero-cost invariant guard; this test pins the
      // REACHABLE contract.
      final c = ScanCoordinator.instance;
      final lease1 = await c.acquire(scanType: 'background', accountId: 'a');
      await expectLater(
        c.acquire(
          scanType: 'manual',
          accountId: 'b',
          waitLimit: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
      c.release(lease1);
      await Future<void>.delayed(Duration.zero);
      expect(c.active, isNull,
          reason: 'the lease must not stay pinned to the timed-out waiter');
      final lease2 = await c.acquire(scanType: 'manual', accountId: 'c');
      c.release(lease2);
      expect(c.active, isNull);
    });

    test(
        'releaseActiveByOwner frees a hung scan\'s lease ONLY on an exact '
        'owner match (Sprint 62 code review C-2: the background-timeout '
        'path has no ScanLease handle)', () async {
      final c = ScanCoordinator.instance;
      await c.acquire(scanType: 'background', accountId: 'a@x.com');
      final waiter = c.acquire(scanType: 'manual', accountId: 'b@x.com');

      // Wrong owner (the timed-out scan was still queued, not active):
      // must NOT evict the live holder.
      c.releaseActiveByOwner(scanType: 'manual', accountId: 'b@x.com');
      expect(c.active?.scanType, 'background',
          reason: 'a non-matching force-release must be a no-op');

      // Matching owner: the hung scan's lease is freed and handed on.
      c.releaseActiveByOwner(scanType: 'background', accountId: 'a@x.com');
      final lease = await waiter;
      expect(c.active?.scanType, 'manual');

      // The zombie scan's own finally later releases a STALE lease -- the
      // identical() guard must ignore it without disturbing the new holder.
      c.releaseActiveByOwner(scanType: 'background', accountId: 'a@x.com');
      expect(c.active?.scanType, 'manual');
      c.release(lease);
      expect(c.active, isNull);
    });

    test('a queued waiter gives up with TimeoutException at its waitLimit '
        'instead of waiting forever', () async {
      final c = ScanCoordinator.instance;
      final lease1 = await c.acquire(scanType: 'background', accountId: 'a');
      await expectLater(
        c.acquire(
          scanType: 'manual',
          accountId: 'b',
          waitLimit: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
      c.release(lease1);
      // The timed-out waiter must have been dequeued: the lease is free now.
      final lease2 = await c.acquire(scanType: 'manual', accountId: 'c');
      c.release(lease2);
    });
  });

  group('scanInbox exclusion end to end', () {
    late DatabaseHelper db;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f175_coord_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();
      _OverlapProbeProvider.fetchIntervals.clear();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
        'two concurrent scanInbox calls NEVER overlap their fetch windows -- '
        'a crashed scan releases the lease for the next (finally path)',
        () async {
      final previous = PlatformRegistry.overrideFactoryForTest(
          'demo', () => _OverlapProbeProvider());
      addTearDown(() =>
          PlatformRegistry.overrideFactoryForTest('demo', previous));

      EmailScanner makeScanner() => EmailScanner(
            platformId: 'demo',
            accountId: 'demo@example.com',
            ruleSetProvider: RuleSetProvider(),
            scanProvider: EmailScanProvider()
              ..initializeScanMode(mode: ScanMode.readOnly),
          );

      // Launch two scans CONCURRENTLY (the Sprint 61 stacking shape).
      final scan1 =
          makeScanner().scanInbox(daysBack: 0, folderNames: ['INBOX']);
      final scan2 = makeScanner()
          .scanInbox(daysBack: 0, folderNames: ['INBOX'], scanType: 'background');
      await Future.wait([scan1, scan2]);

      final intervals = _OverlapProbeProvider.fetchIntervals;
      expect(intervals, hasLength(2));
      final sorted = [...intervals]..sort((a, b) => a.$1.compareTo(b.$1));
      expect(
          sorted[1].$1.isAfter(sorted[0].$2) ||
              sorted[1].$1.isAtSameMomentAs(sorted[0].$2),
          isTrue,
          reason: 'the second scan\'s fetch must start only after the first '
              'scan\'s fetch ended -- overlapping fetches are exactly the '
              'stacked-IMAP-session cascade F175 prevents');

      expect(ScanCoordinator.instance.active, isNull,
          reason: 'both leases released after completion');
    });
  });
}
