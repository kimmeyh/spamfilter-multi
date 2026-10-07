/// Sprint 77 MV-Q2 = 1 (Harold): a fixed, non-random start stagger for
/// Windows background scans at 15 minutes or less, so accounts do not all
/// start at the same moment.
///
/// What these do NOT catch: Task Scheduler honoring the shifted StartBoundary
/// (the Windows-only test in powershell_script_generator_test.dart runs the
/// real cmdlet for slot 0 only; Manual Validation reads the registered
/// trigger), and two processes allocating a slot at the same instant (every
/// caller today is sequential: Settings, the startup loop, the upgrade
/// migration).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/powershell_script_generator.dart';
import 'package:my_email_spam_filter/core/services/scan_interval.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

void main() {
  group('ScanInterval.staggerMinutes', () {
    test('slot N starts N minutes late at 15 minutes or less; none with jitter',
        () {
      expect(ScanInterval.staggerMinutes(15, 0), 0);
      expect(ScanInterval.staggerMinutes(15, 1), 1);
      expect(ScanInterval.staggerMinutes(15, 2), 2);
      expect(ScanInterval.staggerMinutes(5, 3), 3);
      // Wraps at the interval: the 6th account at 5 minutes shares slot 0.
      expect(ScanInterval.staggerMinutes(5, 5), 0);
      // Over 15 minutes the Q13 random delay spreads accounts instead.
      expect(ScanInterval.staggerMinutes(16, 2), 0);
      expect(ScanInterval.staggerMinutes(60, 1), 0);
    });

    test('distinct slots give distinct start minutes up to the interval', () {
      for (final interval in [5, 10, 15]) {
        final starts = {
          for (var s = 0; s < interval; s++)
            ScanInterval.staggerMinutes(interval, s)
        };
        expect(starts.length, interval, reason: '$interval minutes');
      }
    });
  });

  group('startBoundary with a stagger slot', () {
    test('starts slot minutes after midnight and is never in the future', () {
      final days = [DateTime(2026, 10, 7), DateTime(2026, 3, 8), DateTime(2026, 11, 1)];
      for (final day in days) {
        for (final minuteOfDay in [0, 1, 2, 3, 14, 600, 1439]) {
          final now = day.add(Duration(minutes: minuteOfDay, seconds: 30));
          for (final slot in [0, 1, 2, 14]) {
            final start = PowerShellScriptGenerator.startBoundary(now, 15,
                staggerSlot: slot);
            expect(start.isAfter(now), isFalse,
                reason: 'slot $slot at $now starts at $start');
            expect(start.minute, slot, reason: 'slot $slot keeps its minute');
            expect(start.hour, 0);
          }
        }
      }
    });

    test('two accounts on 15 minutes get different trigger starts', () {
      final now = DateTime(2026, 10, 7, 9, 30);
      expect(
          PowerShellScriptGenerator.triggerForInterval(15,
              now: now, staggerSlot: 0),
          contains("-At ([datetime]'2026-10-07T00:00:00')"));
      expect(
          PowerShellScriptGenerator.triggerForInterval(15,
              now: now, staggerSlot: 1),
          contains("-At ([datetime]'2026-10-07T00:01:00')"));
      // Registered at 00:00:30, slot 1 (00:01) is ahead: it moves back a day.
      expect(
          PowerShellScriptGenerator.triggerForInterval(15,
              now: DateTime(2026, 10, 7, 0, 0, 30), staggerSlot: 1),
          contains("-At ([datetime]'2026-10-06T00:01:00')"));
      // Jitter intervals are unchanged by the slot.
      expect(
          PowerShellScriptGenerator.triggerForInterval(30,
              now: now, staggerSlot: 3),
          contains("-At ([datetime]'2026-10-06T23:55:00')"));
    });

    test('create and update scripts carry the slot', () async {
      final create = await PowerShellScriptGenerator.generateCreateTaskScript(
        taskName: 't',
        executablePath: r'C:\x.exe',
        intervalMinutes: 15,
        workingDirectory: r'C:\',
        accountId: 'a',
        staggerSlot: 2,
      );
      expect(await File(create).readAsString(), contains('T00:02:00'));
      final update = await PowerShellScriptGenerator.generateUpdateTaskScript(
        taskName: 't',
        intervalMinutes: 15,
        staggerSlot: 2,
      );
      expect(await File(update).readAsString(), contains('T00:02:00'));
      await PowerShellScriptGenerator.cleanupScripts();
    });
  });

  group('SettingsStore.getOrAllocateScheduleSlot', () {
    late DatabaseHelper db;
    late SettingsStore store;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mv77_2_slot_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();
      store = SettingsStore(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('allocates 0, 1, 2 and keeps each account on its own slot', () async {
      expect(await store.getOrAllocateScheduleSlot('b@x'), 0);
      expect(await store.getOrAllocateScheduleSlot('c@x'), 1);
      expect(await store.getOrAllocateScheduleSlot('a@x'), 2);
      // Stable: asking again (any order) never moves a slot, even though
      // 'a@x' sorts first -- the case an index-based stagger gets wrong.
      expect(await store.getOrAllocateScheduleSlot('a@x'), 2);
      expect(await store.getOrAllocateScheduleSlot('b@x'), 0);
      expect(await store.getOrAllocateScheduleSlot('c@x'), 1);
    });

    test('fills the lowest free slot and never reuses a held one', () async {
      await store.getOrAllocateScheduleSlot('a');
      await store.getOrAllocateScheduleSlot('b');
      await store.getOrAllocateScheduleSlot('c');
      // A hand-cleared slot (no API removes one) leaves a gap that the next
      // new account takes, without disturbing the others.
      final raw = await db.database;
      await raw.delete('account_settings',
          where: 'account_id = ? AND setting_key = ?',
          whereArgs: ['b', 'schedule_slot']);
      expect(await store.getOrAllocateScheduleSlot('d'), 1);
      expect(await store.getOrAllocateScheduleSlot('a'), 0);
      expect(await store.getOrAllocateScheduleSlot('c'), 2);
    });
  });
}
