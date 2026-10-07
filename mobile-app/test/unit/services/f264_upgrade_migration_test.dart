/// F264 (Sprint 77): the upgrade conversions and the startup reconcile.
///
/// Covers AC-3 (an account stored at 240 is ensured at 240, not 15; a stored 3
/// becomes 5 with a log line), the Q11 conversion of existing users, and the Q9
/// carry-over of the old app-wide new-mail switch.
///
/// What these do NOT catch: `main.dart` handing the reconciled minutes to the
/// Windows scheduler (a source gate below pins the call text), or either OS
/// actually registering the schedule (phone and Task Scheduler validation).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/f264_upgrade_migration.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

void main() {
  late DatabaseHelper db;
  late SettingsStore store;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('f264_migrate_');
    db = DatabaseHelper();
    db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
    await db.deleteAllData();
    store = SettingsStore(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('reconcileAccountInterval (startup, AC-3)', () {
    test('an account stored at 240 stays 240, not 15', () async {
      await store.setAccountBackgroundFrequency('a', 240);
      final logs = <String>[];
      expect(await reconcileAccountInterval(store, 'a', log: logs.add), 240);
      expect(logs, isEmpty);
      expect(await store.getAccountBackgroundFrequency('a'), 240);
    });

    test('a stored 3 becomes 5, is written back and is logged', () async {
      await store.setAccountBackgroundFrequency('a', 3);
      final logs = <String>[];
      expect(await reconcileAccountInterval(store, 'a', log: logs.add), 5);
      expect(logs, hasLength(1));
      expect(logs.single, contains('3'));
      expect(await store.getAccountBackgroundFrequency('a'), 5);
    });

    test('an untypable 125 becomes 120', () async {
      await store.setAccountBackgroundFrequency('a', 125);
      expect(await reconcileAccountInterval(store, 'a'), 120);
      expect(await store.getAccountBackgroundFrequency('a'), 120);
    });

    test('an account with no override reads the app-wide default and does not '
        'gain an override', () async {
      expect(await reconcileAccountInterval(store, 'a'), 15);
      expect(await store.getAccountBackgroundFrequency('a'), isNull);
    });

    test('main.dart passes the reconciled minutes to BOTH Windows calls and no '
        'enum lookup remains', () {
      // SOURCE-TEXT VERIFIED: the startup block runs only in a release
      // Windows process. What this does NOT catch: the minutes being right --
      // the tests above do.
      final src = File('lib/main.dart').readAsStringSync();
      expect(src.contains('await reconcileAccountInterval('), isTrue);
      expect(
          src.contains('verifyAndRepairTaskPath(\n'
              '            accountId: accountId,\n'
              '            intervalMinutes: intervalMinutes,'),
          isTrue);
      expect(
          src.contains('ensureTaskExists(\n'
              '            intervalMinutes: intervalMinutes,'),
          isTrue);
      expect(src.contains('ScanFrequency'), isFalse);
      expect(src.contains('every15min'), isFalse,
          reason: 'the hard-coded 15 fallback was latent bug 2');
    });
  });

  group('BackgroundIntervalMigration (Q11, both platforms)', () {
    BackgroundIntervalMigration migration(
      List<String> ids,
      List<(String, int)> calls,
    ) =>
        BackgroundIntervalMigration(
          settingsStore: store,
          getAccountIds: () async => ids,
          reschedule: (id, minutes) async => calls.add((id, minutes)),
        );

    test('converts stored values and re-registers enabled accounts only',
        () async {
      await store.setAccountBackgroundEnabled('on', true);
      await store.setAccountBackgroundFrequency('on', 120);
      await store.setAccountBackgroundEnabled('odd', true);
      await store.setAccountBackgroundFrequency('odd', 125);
      await store.setAccountBackgroundEnabled('off', false);
      await store.setAccountBackgroundFrequency('off', 240);
      final calls = <(String, int)>[];

      expect(await migration(['on', 'odd', 'off'], calls).runIfNeeded(), isTrue);

      expect(await store.getAccountBackgroundFrequency('odd'), 120);
      expect(calls, [('on', 120), ('odd', 120)],
          reason: 'accounts saved at 120/240 had NOTHING scheduled before '
              'F264 (the settings gate returned early) -- the migration gives '
              'them the schedule; a switched-off account gets none');
    });

    test('is idempotent: the sentinel stops a second run', () async {
      final calls = <(String, int)>[];
      await store.setAccountBackgroundEnabled('a', true);
      expect(await migration(['a'], calls).runIfNeeded(), isTrue);
      calls.clear();
      expect(await migration(['a'], calls).runIfNeeded(), isFalse);
      expect(calls, isEmpty);
    });

    test('with no scheduler (a Windows debug run) it converts but schedules '
        'nothing', () async {
      await store.setAccountBackgroundEnabled('a', true);
      await store.setAccountBackgroundFrequency('a', 3);
      final m = BackgroundIntervalMigration(
        settingsStore: store,
        getAccountIds: () async => ['a'],
        reschedule: null,
      );
      expect(await m.runIfNeeded(), isTrue);
      expect(await store.getAccountBackgroundFrequency('a'), 5);
    });

    test('a failing scheduler leaves the sentinel unset so the next launch '
        'retries', () async {
      await store.setAccountBackgroundEnabled('a', true);
      final m = BackgroundIntervalMigration(
        settingsStore: store,
        getAccountIds: () async => ['a'],
        reschedule: (id, minutes) async => throw StateError('boom'),
      );
      expect(await m.runIfNeeded(), isFalse);
      expect(await store.getRawAppSetting(BackgroundIntervalMigration.sentinelKey),
          isNull);
    });
  });

  group('NewMailSwitchMigration (Q9 = 1)', () {
    NewMailSwitchMigration migration(List<String> ids) => NewMailSwitchMigration(
          settingsStore: store,
          getAccountIds: () async => ids,
        );

    test('app-wide switch ON -> ON for every account with background scanning '
        'on, and only those', () async {
      await store.setAccountBackgroundEnabled('a', true);
      await store.setAccountBackgroundEnabled('b', true);
      await store.setAccountBackgroundEnabled('c', false);
      expect(await migration(['a', 'b', 'c']).runIfNeeded(nativeFlagWasOn: true),
          isTrue);
      expect(await store.getAccountNewMailTrigger('a'), isTrue);
      expect(await store.getAccountNewMailTrigger('b'), isTrue);
      expect(await store.getAccountNewMailTrigger('c'), isNull);
    });

    test('app-wide switch OFF -> nothing is turned on', () async {
      await store.setAccountBackgroundEnabled('a', true);
      expect(await migration(['a']).runIfNeeded(nativeFlagWasOn: false), isTrue);
      expect(await store.getAccountNewMailTrigger('a'), isNull);
    });

    test('an unreadable native flag waits for the next launch instead of '
        'guessing OFF', () async {
      await store.setAccountBackgroundEnabled('a', true);
      expect(await migration(['a']).runIfNeeded(nativeFlagWasOn: null), isFalse);
      expect(await store.getRawAppSetting(NewMailSwitchMigration.sentinelKey),
          isNull);
      // ...and the later successful run still carries the switch over.
      expect(await migration(['a']).runIfNeeded(nativeFlagWasOn: true), isTrue);
      expect(await store.getAccountNewMailTrigger('a'), isTrue);
    });

    test('an account the user already set is not overwritten', () async {
      await store.setAccountBackgroundEnabled('a', true);
      await store.setAccountNewMailTrigger('a', false);
      await migration(['a']).runIfNeeded(nativeFlagWasOn: true);
      expect(await store.getAccountNewMailTrigger('a'), isFalse);
    });

    test('runs once', () async {
      await store.setAccountBackgroundEnabled('a', true);
      expect(await migration(['a']).runIfNeeded(nativeFlagWasOn: true), isTrue);
      expect(await migration(['a']).runIfNeeded(nativeFlagWasOn: true), isFalse);
    });
  });

  group('per-account new-mail storage', () {
    test('round-trips per account and clears with null', () async {
      expect(await store.getAccountNewMailTrigger('a'), isNull);
      await store.setAccountNewMailTrigger('a', true);
      await store.setAccountNewMailTrigger('b', false);
      expect(await store.getAccountNewMailTrigger('a'), isTrue);
      expect(await store.getAccountNewMailTrigger('b'), isFalse);
      await store.setAccountNewMailTrigger('a', null);
      expect(await store.getAccountNewMailTrigger('a'), isNull);
    });
  });
}
