import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';

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
/// Rules Management stands in for all four screens; the handlers are the same
/// shape and the fix is identical in each.
void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
  });

  tearDown(() async {
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
}
