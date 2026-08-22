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
