// Sprint 42, F98 (ADR-0039) -- per-account background scanning unit tests.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/core/utils/account_id_sanitizer.dart';
import 'package:my_email_spam_filter/core/services/background_mode_service.dart';
import 'package:my_email_spam_filter/core/services/background_scan_manager.dart';
import 'package:my_email_spam_filter/core/services/per_account_bg_migration.dart';
import 'package:my_email_spam_filter/core/services/windows_task_scheduler_service.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

void main() {
  group('F98 account-id sanitizer', () {
    test('replaces @ and . consistently', () {
      expect(sanitizeAccountId('gmail-user@gmail.com'),
          'gmail-user_at_gmail_com');
      expect(sanitizeAccountId('aol-a.b@aol.com'), 'aol-a_b_at_aol_com');
    });
  });

  group('F98 CLI --account-id parsing', () {
    tearDown(BackgroundModeService.resetForTesting);

    test('parses --account-id into backgroundAccountId', () {
      BackgroundModeService.initialize(
          ['--background-scan', '--account-id=gmail-a@b.com']);
      expect(BackgroundModeService.isBackgroundMode, isTrue);
      expect(BackgroundModeService.backgroundAccountId, 'gmail-a@b.com');
    });

    test('absent --account-id -> null (legacy all-accounts)', () {
      BackgroundModeService.initialize(['--background-scan']);
      expect(BackgroundModeService.isBackgroundMode, isTrue);
      expect(BackgroundModeService.backgroundAccountId, isNull);
    });

    test('empty --account-id= -> null', () {
      BackgroundModeService.initialize(['--background-scan', '--account-id=']);
      expect(BackgroundModeService.backgroundAccountId, isNull);
    });
  });

  group('F98 per-account task names', () {
    test('Windows task name includes sanitized account id', () {
      final name = WindowsTaskSchedulerService.taskNameFor('gmail-a@b.com');
      expect(name, contains('SpamFilterBackgroundScan_gmail-a_at_b_com'));
    });

    test('null account id -> legacy global task name', () {
      expect(WindowsTaskSchedulerService.taskNameFor(null),
          WindowsTaskSchedulerService.taskName);
    });

    test('WorkManager unique name uses :: separator', () {
      expect(BackgroundScanManager.taskNameFor('gmail-a@b.com'),
          'background_scan_task::gmail-a@b.com');
      expect(BackgroundScanManager.taskNameFor(null), 'background_scan_task');
    });
  });

  group('F98 settings store per-account frequency', () {
    late DatabaseHelper db;
    late SettingsStore store;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f98_settings_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();
      store = SettingsStore(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('per-account frequency override resolves before global', () async {
      await store.setBackgroundScanFrequency(60); // global
      expect(await store.getEffectiveBackgroundFrequency('acct'), 60);

      await store.setAccountBackgroundFrequency('acct', 15);
      expect(await store.getEffectiveBackgroundFrequency('acct'), 15);
      // A different account with no override still falls back to global.
      expect(await store.getEffectiveBackgroundFrequency('other'), 60);

      await store.setAccountBackgroundFrequency('acct', null); // clear
      expect(await store.getEffectiveBackgroundFrequency('acct'), 60);
    });
  });

  group('F98 migration (Locked Decision 1: preserve behavior)', () {
    late DatabaseHelper db;
    late SettingsStore store;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f98_migrate_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();
      store = SettingsStore(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    PerAccountBgMigration migrationFor(List<String> accounts) =>
        PerAccountBgMigration(
          settingsStore: store,
          getAccountIds: () async => accounts,
        );

    test('global ON -> every account inherits enabled + frequency', () async {
      await store.setBackgroundScanEnabled(true);
      await store.setBackgroundScanFrequency(30);

      final ran = await migrationFor(['a', 'b']).runIfNeeded();
      expect(ran, isTrue);

      expect(await store.getEffectiveBackgroundEnabled('a'), isTrue);
      expect(await store.getEffectiveBackgroundEnabled('b'), isTrue);
      expect(await store.getAccountBackgroundFrequency('a'), 30);
    });

    test('explicit per-account override is preserved (not overwritten)', () async {
      await store.setBackgroundScanEnabled(true);
      await store.setAccountBackgroundEnabled('a', false); // user said no
      await migrationFor(['a', 'b']).runIfNeeded();
      expect(await store.getAccountBackgroundEnabled('a'), isFalse);
      expect(await store.getAccountBackgroundEnabled('b'), isTrue);
    });

    test('global OFF -> no per-account seeding', () async {
      await store.setBackgroundScanEnabled(false);
      await migrationFor(['a']).runIfNeeded();
      expect(await store.getAccountBackgroundEnabled('a'), isNull);
    });

    test('is idempotent (second run is a no-op)', () async {
      await store.setBackgroundScanEnabled(true);
      expect(await migrationFor(['a']).runIfNeeded(), isTrue);
      // Sentinel set -> second run returns false and does not re-seed.
      expect(await migrationFor(['a', 'newacct']).runIfNeeded(), isFalse);
      expect(await store.getAccountBackgroundEnabled('newacct'), isNull);
    });
  });
}
