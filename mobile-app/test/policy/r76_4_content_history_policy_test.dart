/// R76-4 (Sprint 78, ADR-0047) policy gates.
///
/// T-6 (AC-6): no customer build can capture -- the release paths pass
/// APP_ENV=prod (the default environment is dev), the scanner's capture is
/// behind the gate and BEFORE the safe-sender skip, and the Settings row
/// builds nothing in a prod build.
///
/// R7 (prevention first): every table holding account data is covered by
/// BOTH deletion paths. The audit found "Remove an account" missing
/// `account_folder_cursors` and `background_scan_log`, and "delete all data"
/// missing four tables; this fails the next time a table is added and not
/// listed.
///
/// What these do NOT catch: a release build made by hand with
/// `flutter build ... --dart-define=APP_ENV=dev` outside the scripts (the
/// release self-test's [DEV] title check is the backstop), or a table that
/// holds account data WITHOUT an `account_id` column (email_actions and
/// unmatched_emails are reached through scan_results; they are listed
/// explicitly below).
///
/// SOURCE-TEXT VERIFIED: the release-path, scanner-placement and table-list
/// checks read source and config text; they prove the settings and calls
/// EXIST, not that a build behaves. What settles it: a manual scan on Windows
/// DEV with the switch on stores rows (Task 7 DoD), and the installed Store
/// build shows no "Content history" row on Settings > General (Manual
/// Validation). The deletion behavior and the prod-build widget check above
/// are real behavior tests.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/content_history.dart';
import 'package:my_email_spam_filter/core/services/data_deletion_service.dart';
import 'package:my_email_spam_filter/ui/widgets/content_history_row.dart';

import '../helpers/database_test_helper.dart';

void main() {
  setUpAll(DatabaseTestHelper.initializeFfi);

  group('T-6: no customer build can capture', () {
    test('the Store MSIX build passes APP_ENV=prod', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final line = pubspec
          .split('\n')
          .firstWhere((l) => l.trim().startsWith('windows_build_args:'));
      expect(line.contains('--dart-define=APP_ENV=prod'), isTrue,
          reason: 'APP_ENV defaults to dev; a Store build without it would '
              'be a dev build that can capture');
    });

    test('the Android build script defaults to prod and passes APP_ENV with '
        'the flavor', () {
      final script = File('scripts/build-with-secrets.ps1').readAsStringSync();
      expect(script.contains(r"[string]$Env = 'prod'"), isTrue);
      expect(
          script.contains(r"""@('--flavor', $Env, "--dart-define=APP_ENV=$Env")"""),
          isTrue);
    });

    test('the scanner captures behind the gate, before the safe-sender skip',
        () {
      final src =
          File('lib/core/services/email_scanner.dart').readAsStringSync();
      expect(src.contains('await ContentHistory.isActive(_settingsStore)'),
          isTrue);
      final record = src.indexOf('await contentCapture?.record(message, result);');
      final skip = src.indexOf('shouldSkipSafeSenderAlreadyInTarget(\n');
      expect(record, greaterThan(0));
      expect(skip, greaterThan(record),
          reason: 'ADR-0047 item 3: capture BEFORE the skip, so no outcome is '
              'missed');
    });

    testWidgets('the Settings row builds nothing in a prod build',
        (tester) async {
      ContentHistory.debugIsDevOverride = false;
      addTearDown(() => ContentHistory.debugIsDevOverride = null);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ContentHistoryRow())));
      expect(find.byKey(const Key('content_history_row')), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });
  });

  group('R7: both deletion paths cover every table holding account data', () {
    late DatabaseTestHelper testHelper;
    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
    });
    tearDown(() => testHelper.tearDown());

    Future<List<String>> tables() async {
      final db = await testHelper.dbHelper.database;
      final rows = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'");
      return rows.map((r) => r['name'] as String).toList();
    }

    Future<bool> hasAccountId(String table) async {
      final db = await testHelper.dbHelper.database;
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      return cols.any((c) => c['name'] == 'account_id');
    }

    test('"Remove an account" names every table with an account_id', () async {
      final src = File('lib/core/services/data_deletion_service.dart')
          .readAsStringSync();
      final missing = <String>[];
      for (final t in await tables()) {
        if (await hasAccountId(t) && !src.contains("'$t'")) missing.add(t);
      }
      expect(missing, isEmpty,
          reason: 'add the table to DataDeletionService.deleteAccountData');
      // Reached through scan_results, so named explicitly:
      expect(src.contains("'email_actions'"), isTrue);
      expect(src.contains("'unmatched_emails'"), isTrue);
    });

    test('"delete all data" names every table', () async {
      final src =
          File('lib/core/storage/database_helper.dart').readAsStringSync();
      final start = src.indexOf('Future<void> deleteAllData() async {');
      final body = src.substring(start, src.indexOf('\n  }\n', start));
      final missing = <String>[];
      for (final t in await tables()) {
        if (!body.contains("'$t'")) missing.add(t);
      }
      expect(missing, isEmpty,
          reason: 'add the table to DatabaseHelper.deleteAllData');
    });

    test('behavior: removing an account deletes its folder cursors and its '
        'background scan log', () async {
      const acct = 'aol-r7@aol.com';
      await testHelper.createTestAccount(acct);
      final db = await testHelper.dbHelper.database;
      await db.insert('account_folder_cursors', {
        'account_id': acct,
        'folder_name': 'INBOX',
        'cursor_type': 'uid',
        'cursor_value': '5',
        'updated_at': 1,
      });
      await db.insert('background_scan_log', {
        'account_id': acct,
        'scheduled_time': 1,
        'status': 'completed',
      });
      await DataDeletionService(dbHelper: testHelper.dbHelper)
          .deleteAccountData(acct);
      for (final t in ['account_folder_cursors', 'background_scan_log']) {
        expect(
            await db.query(t, where: 'account_id = ?', whereArgs: [acct]),
            isEmpty,
            reason: '$t must not keep a removed account\'s rows');
      }
    });
  });
}
