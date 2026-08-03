import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

/// PR #292 review: a Refresh that FAILED must not claim "No changes".
///
/// Every `_loadX()` on the four refreshable screens catches its own exception,
/// shows a failure SnackBar, and returns normally. `_refreshFromUserAction`
/// therefore could not tell success from failure: it compared an unchanged
/// count, concluded "No changes", and -- worse -- called
/// `hideCurrentSnackBar()` first, actively erasing the error the user was
/// meant to read. The load methods now return a success flag.
///
/// Two screens are covered directly. Rules Management stands in for
/// Safe Senders (identical handler shape). Scan History gets its OWN case
/// (PR #292 re-review): its loader is multi-step -- settings read, retention
/// PURGE, credentials, history read -- so it can fail after rows were already
/// deleted, its delta is inverted, and its messages are claims about deleted
/// data. That is the most distinct failure surface of the four.
void main() {
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = <String, String>{};

  late DatabaseTestHelper testHelper;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    fakeSecureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return fakeSecureStorage[key];
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          fakeSecureStorage[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
      }
      return null;
    });

    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  testWidgets('a FAILED refresh does not report "No changes"', (tester) async {
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
        tester,
        const MaterialApp(home: RulesManagementScreen()),
        settleDelay: const Duration(milliseconds: 500),
      );
    });

    // Break the load: dropping the table makes the next read throw, which is
    // the same shape as the real-world trigger (a DB lock held by a concurrent
    // background scan -- a documented F98 condition).
    await tester.runAsync(() async {
      final db = await DatabaseHelper().database;
      await db.execute('DROP TABLE IF EXISTS rules');
    });

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Reload rules from the database'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The failure SnackBar must survive, and no success message may appear.
    expect(find.textContaining('No changes'), findsNothing,
        reason: 'a refresh whose load THREW must not claim the list is up to '
            'date -- it never observed the state it would be describing');

    expect(find.textContaining('Failed to load rules'), findsOneWidget,
        reason: 'the real error must remain visible; the success path calls '
            'hideCurrentSnackBar() and would have erased it');
  });

  testWidgets(
      'Scan History: a FAILED refresh does not claim deletions or "No changes"',
      (tester) async {
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
        tester,
        const MaterialApp(home: ScanHistoryScreen()),
        settleDelay: const Duration(milliseconds: 500),
      );
    });

    // Break the load MID-SEQUENCE: _loadHistory reads settings, PURGES by
    // retention, then queries history. Dropping scan_results makes the purge
    // step throw -- the distinct Scan History hazard, because its messages
    // ("N scans older than X days removed" / "no changes") are claims about
    // deleted data.
    await tester.runAsync(() async {
      final db = await DatabaseHelper().database;
      await db.execute('DROP TABLE IF EXISTS scan_results');
    });

    await tester.runAsync(() async {
      await tester
          .tap(find.byTooltip('Reload scan history (does not fetch new mail)'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('No changes'), findsNothing,
        reason: 'a refresh whose load threw must not claim history is up to '
            'date');
    expect(find.textContaining('removed'), findsNothing,
        reason: 'it must not claim scans were purged -- the purge path threw, '
            'so any removal count would describe deletions never observed');
    expect(find.textContaining('Failed to load scan history'), findsOneWidget,
        reason: 'the real error must remain visible instead of being replaced '
            'by a success-style message');
  });
}
