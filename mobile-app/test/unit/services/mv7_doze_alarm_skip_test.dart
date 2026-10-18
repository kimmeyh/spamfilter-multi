/// Sprint 78 MV-7 (Harold, Fold logs 2026-10-09..13): the Doze alarm scanned
/// on its own schedule beside the periodic job -- AOL about twice per
/// interval. A Doze-alarm run now skips an account whose last scan started
/// within two-thirds of its interval.
///
/// Sprint 79 (Task 1 R-5, Harold Q1 = 1): the PERIODIC run applies the same
/// rule, counting only completed scans -- the overnight 2026-10-14 log still
/// showed Yahoo (15 minutes) at 6.25 scans/hour because only the alarm side
/// checked. Also R-8: the line written when WorkManager stops a worker.
///
/// SOURCE-TEXT VERIFIED: the wiring test reads the worker source, because
/// `executeScan` needs a real Android environment (paths, secure storage);
/// the decision and the query are proven by behavior tests.
///
/// What these tests do NOT catch: how often Android actually delivers the
/// alarm or the periodic job (that is the F277 Fold measurement), a scan
/// row written under a different account id than the saved account's, or
/// whether the plugin really calls onTaskStopped on the phone (proven only
/// by a `stopped by WorkManager` line in a Fold log).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart' show StopReason;

import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  group('recentScanShouldSkip', () {
    final now = DateTime(2026, 10, 13, 12, 0);
    const interval = Duration(minutes: 15);
    bool skip(Duration? age) => recentScanShouldSkip(
        now: now,
        lastScanStart: age == null ? null : now.subtract(age),
        interval: interval);

    test('no scan yet: run', () => expect(skip(null), isFalse));
    test('periodic ran 5 minutes ago: skip',
        () => expect(skip(const Duration(minutes: 5)), isTrue));
    test('just inside two-thirds (9m59s): skip',
        () => expect(skip(const Duration(minutes: 9, seconds: 59)), isTrue));
    test('at two-thirds (10m): run',
        () => expect(skip(const Duration(minutes: 10)), isFalse));
    test('Doze: the previous ALARM scan, just under one interval old: run',
        () => expect(skip(const Duration(minutes: 14, seconds: 59)), isFalse));
    test('a start time in the future (clock change): run',
        () => expect(skip(const Duration(minutes: -3)), isFalse));
    // The 2026-10-14 Yahoo pair: alarm scan at 00:16:21, periodic at 00:21:25.
    test('periodic 5 minutes after an alarm scan (Yahoo 00:21): skip',
        () => expect(skip(const Duration(minutes: 5, seconds: 4)), isTrue));
  });

  group('checksRecentScan', () {
    test('periodic and Doze-alarm runs check', () {
      expect(checksRecentScan(isTest: false, notificationProviders: null),
          isTrue);
    });
    test('a Test run never checks', () {
      expect(checksRecentScan(isTest: true, notificationProviders: null),
          isFalse);
    });
    test('a new-mail notification run never checks', () {
      expect(checksRecentScan(isTest: false, notificationProviders: 'aol'),
          isFalse);
    });
  });

  group('ScanResultStore.getLatestScanStart', () {
    late DatabaseTestHelper helper;
    setUpAll(DatabaseTestHelper.initializeFfi);
    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    Future<void> row(String account, String type, int startedAt,
        {String status = 'completed'}) async {
      final db = await helper.dbHelper.database;
      await db.insert('scan_results', {
        'account_id': account,
        'scan_type': type,
        'scan_mode': 'readonly',
        'started_at': startedAt,
        'total_emails': 0,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': status,
        'folders_scanned': '[]',
      });
    }

    test('latest start across manual and background, this account only',
        () async {
      await helper.createTestAccount('a@aol.com', platformId: 'aol');
      await helper.createTestAccount('b@aol.com', platformId: 'aol');
      await row('a@aol.com', 'background', 1000);
      await row('a@aol.com', 'manual', 3000);
      await row('b@aol.com', 'background', 9000);

      final store = ScanResultStore(helper.dbHelper);
      expect((await store.getLatestScanStart('a@aol.com'))!
          .millisecondsSinceEpoch, 3000);
      expect(await store.getLatestScanStart('none@aol.com'), isNull);
    });

    test('completedOnly ignores a newer failed, dead or running scan',
        () async {
      await helper.createTestAccount('a@aol.com', platformId: 'aol');
      await row('a@aol.com', 'background', 1000);
      await row('a@aol.com', 'background', 2000, status: 'error');
      await row('a@aol.com', 'background', 3000, status: 'interrupted');
      await row('a@aol.com', 'background', 4000, status: 'in_progress');

      final store = ScanResultStore(helper.dbHelper);
      expect((await store.getLatestScanStart('a@aol.com'))!
          .millisecondsSinceEpoch, 4000);
      expect((await store.getLatestScanStart('a@aol.com',
              completedOnly: true))!
          .millisecondsSinceEpoch, 1000);
    });
  });

  group('describeWorkerStop', () {
    test('names the reason and the run', () {
      expect(
          describeWorkerStop(
              running: 'k***@aol.com trigger=doze-alarm delay=0s',
              reason: StopReason.cancelledByApp),
          'stopped by WorkManager before it finished: reason=timeout raw=3 '
          '(k***@aol.com trigger=doze-alarm delay=0s)');
    });
    test('no run recorded yet: reason only', () {
      expect(describeWorkerStop(running: null, reason: StopReason.unknown),
          'stopped by WorkManager before it finished: reason=unknown raw=0');
    });
  });

  // The plugin's enum numbers reasons differently from AndroidX, so the name
  // must come from the raw value. What this does NOT catch: a future plugin
  // that stops forwarding the raw AndroidX value unchanged.
  group('androidStopReasonName (AndroidX WorkInfo.STOP_REASON_*)', () {
    test('every value 1-9 the plugin can pass maps to its AndroidX name', () {
      final names = {
        1: 'cancelledByApp', 2: 'preempt', 3: 'timeout', 4: 'deviceState',
        5: 'constraintBatteryNotLow', 6: 'constraintCharging',
        7: 'constraintConnectivity', 8: 'constraintDeviceIdle',
        9: 'constraintStorageNotLow',
      };
      for (final e in names.entries) {
        expect(androidStopReasonName(e.key), e.value, reason: 'raw ${e.key}');
      }
    });
    test('the plugin enum name is never used', () {
      // Plugin 3 is cancelledByApp, plugin 9 is deviceIdle; AndroidX differs.
      expect(describeWorkerStop(running: null, reason: StopReason.deviceIdle),
          contains('reason=constraintStorageNotLow raw=9'));
    });
    test('0 is unknown; anything else is unlisted', () {
      expect(androidStopReasonName(0), 'unknown');
      expect(androidStopReasonName(42), 'unlisted');
    });
  });

  group('onWorkerStopped', () {
    test('writes one stop line with the reason', () async {
      final lines = <String>[];
      await onWorkerStopped('spamfilter_background_scan', StopReason.timeout,
          write: (d) async => lines.add(d));
      expect(lines, hasLength(1));
      expect(lines.single,
          startsWith('stopped by WorkManager before it finished: '
              'reason=cancelledByApp raw=1'));
    });
    test('a write that hangs or throws does not hold the teardown', () async {
      final sw = Stopwatch()..start();
      await onWorkerStopped('t', StopReason.preempt,
          write: (_) => Future<void>.delayed(const Duration(seconds: 30)));
      await onWorkerStopped('t', StopReason.preempt,
          write: (_) async => throw StateError('disk'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  test('wiring: periodic and alarm runs check; stops are logged', () {
    final src =
        File('lib/core/services/android_background_scan_worker.dart')
            .readAsStringSync();
    expect(src, contains("dozeAlarm: inputData?[kTriggerSourceKey] == 'doze-alarm'"));
    expect(src, contains('final checkRecent = checksRecentScan('));
    expect(src, contains('isTest: isTest, notificationProviders: notificationProviders);'));
    expect(src, contains('if (checkRecent) {'));
    expect(src, contains('getLatestScanStart(id, completedOnly: !dozeAlarm)'));
    expect(src, contains('if (!recentScanShouldSkip('));
    // Sprint 79 (Harold A = 1): the SAME check runs again after a busy wait.
    expect(src, contains('skipAfterWait: checkRecent ? recentScanReason : null'));
    expect(src, contains('}, onTaskStopped: onWorkerStopped);'));
  });
}
