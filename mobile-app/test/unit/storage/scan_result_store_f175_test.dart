/// F175 (Sprint 62): the store-side pieces of scan concurrency control --
/// stale in_progress reconciliation (the forever-running rows 44-60 class),
/// active-background-scan detection (cross-process, database-backed), and
/// the rolling average behind the manual-scan wait estimate.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart'
    show formatBackgroundWaitEstimate;

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
    tempDir = await Directory.systemTemp.createTemp('f175_store_');
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
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<int> seedScan({
    required String scanType,
    required String status,
    required DateTime startedAt,
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

  group('reconcileStaleInProgressScans (R-5)', () {
    test('marks OLD in_progress rows interrupted, leaves FRESH ones alone',
        () async {
      final staleId = await seedScan(
        scanType: 'manual',
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final liveId = await seedScan(
        scanType: 'background',
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      final doneId = await seedScan(
        scanType: 'manual',
        status: 'completed',
        startedAt: DateTime.now().subtract(const Duration(hours: 3)),
        completedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

      final count = await store.reconcileStaleInProgressScans(
          staleAfter: const Duration(minutes: 30));

      expect(count, 1);
      expect((await store.getScanResultById(staleId))!.status, 'interrupted',
          reason: 'a 2-hour-old in_progress row is a dead scan -- the '
              'forever-running Sprint 61 rows 44-60 class');
      expect((await store.getScanResultById(liveId))!.status, 'in_progress',
          reason: 'the age guard protects a genuinely LIVE scan -- on '
              'Windows the background worker scans in a separate process');
      expect((await store.getScanResultById(doneId))!.status, 'completed');
    });
  });

  group('getActiveBackgroundScan (R-3 detection)', () {
    test('returns the fresh in_progress BACKGROUND scan and ignores manual, '
        'stale, and completed rows', () async {
      await seedScan(
        scanType: 'manual',
        status: 'in_progress',
        startedAt: DateTime.now(),
      );
      await seedScan(
        scanType: 'background',
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(await store.getActiveBackgroundScan(), isNull,
          reason: 'a manual scan or a stale zombie must not trigger the '
              'background-scan wait notice');

      await seedScan(
        scanType: 'background',
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      final active = await store.getActiveBackgroundScan();
      expect(active, isNotNull);
      expect(active!.scanType, 'background');
      expect(active.status, 'in_progress');
    });
  });

  group('getAverageScanDuration (R-3 estimate)', () {
    test('averages the completed background scans; null with no history',
        () async {
      expect(await store.getAverageScanDuration(accountId), isNull,
          reason: 'no history must yield null, never a fabricated estimate');

      final base = DateTime.now().subtract(const Duration(days: 1));
      await seedScan(
        scanType: 'background',
        status: 'completed',
        startedAt: base,
        completedAt: base.add(const Duration(minutes: 2)),
      );
      await seedScan(
        scanType: 'background',
        status: 'completed',
        startedAt: base.add(const Duration(hours: 1)),
        completedAt: base.add(const Duration(hours: 1, minutes: 4)),
      );
      // A manual completed scan and an errored background scan must not
      // pollute the average.
      await seedScan(
        scanType: 'manual',
        status: 'completed',
        startedAt: base,
        completedAt: base.add(const Duration(minutes: 20)),
      );
      await seedScan(
        scanType: 'background',
        status: 'error',
        startedAt: base,
        completedAt: base.add(const Duration(minutes: 40)),
      );

      final avg = await store.getAverageScanDuration(accountId);
      expect(avg, const Duration(minutes: 3),
          reason: '(2 min + 4 min) / 2 completed background scans');
    });
  });

  group('formatBackgroundWaitEstimate wording', () {
    test('no history says so honestly', () {
      expect(
        formatBackgroundWaitEstimate(
            startedAt: DateTime.now(), average: null),
        contains('no scan history'),
      );
    });

    test('remaining time is average minus elapsed', () {
      final text = formatBackgroundWaitEstimate(
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        average: const Duration(minutes: 10),
      );
      expect(text, contains('about 8 minutes remaining'));
    });

    test('overdue scans read as finishing shortly, never negative', () {
      final text = formatBackgroundWaitEstimate(
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        average: const Duration(minutes: 5),
      );
      expect(text, contains('should finish shortly'));
    });
  });
}
