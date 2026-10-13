/// Sprint 78 MV-7 (Harold, Fold logs 2026-10-09..13): the Doze alarm scanned
/// on its own schedule beside the periodic job -- AOL about twice per
/// interval. A Doze-alarm run now skips an account whose last scan started
/// within two-thirds of its interval.
///
/// SOURCE-TEXT VERIFIED: the wiring test reads the worker source, because
/// `executeScan` needs a real Android environment (paths, secure storage);
/// the decision and the query are proven by behavior tests.
///
/// What these tests do NOT catch: how often Android actually delivers the
/// alarm or the periodic job (that is the F277 Fold measurement), or a scan
/// row written under a different account id than the saved account's.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  group('dozeAlarmShouldSkip', () {
    final now = DateTime(2026, 10, 13, 12, 0);
    const interval = Duration(minutes: 15);
    bool skip(Duration? age) => dozeAlarmShouldSkip(
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
  });

  group('ScanResultStore.getLatestScanStart', () {
    late DatabaseTestHelper helper;
    setUpAll(DatabaseTestHelper.initializeFfi);
    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    test('latest start across manual and background, this account only',
        () async {
      final db = await helper.dbHelper.database;
      Future<void> row(String account, String type, int startedAt) =>
          db.insert('scan_results', {
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
            'status': 'completed',
            'folders_scanned': '[]',
          });
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
  });

  test('wiring: the dispatcher flags Doze-alarm runs and the loop skips', () {
    final src =
        File('lib/core/services/android_background_scan_worker.dart')
            .readAsStringSync();
    expect(src, contains("dozeAlarm: inputData?[kTriggerSourceKey] == 'doze-alarm'"));
    expect(src, contains('if (dozeAlarm && !isTest) {'));
    expect(src, contains('getLatestScanStart(id)'));
    expect(src, contains('if (dozeAlarmShouldSkip('));
  });
}
