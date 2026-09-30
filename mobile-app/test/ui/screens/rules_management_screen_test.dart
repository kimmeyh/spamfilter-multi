import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

/// F124 (Sprint 50, Issue #282): legacy pre-classification rules (NULL
/// patternCategory/patternSubType, e.g. SpamAutoDeleteFrom) must render the
/// "Uncategorized (legacy)" fallback -- consistently in the list tile, the
/// details dialog, and the category filter chip -- instead of the old blank
/// "-" sub-label.
///
/// DB-in-initState hazards handled per db_widget_test_harness.dart (runAsync
/// + mountAndLoadDbWidget; never pumpAndSettle).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> insertLegacyUncategorizedRule() async {
    final db = await testHelper.dbHelper.database;
    await db.insert('rules', {
      'name': 'SpamAutoDeleteFrom',
      'enabled': 1,
      'is_local': 1,
      'execution_order': 30,
      'condition_type': 'OR',
      'condition_from': '["spammer@bad.example"]',
      'action_delete': 1,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'legacy',
      // The F124 shape: NULL pattern_category and pattern_sub_type.
    });
  }

  Widget buildTestWidget() =>
      const MaterialApp(home: RulesManagementScreen());

  testWidgets(
      'legacy uncategorized rule shows the fallback label in tile, filter '
      'chip, and details dialog -- no blank "-" sub-label (F124)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await insertLegacyUncategorizedRule();
      await mountAndLoadDbWidget(tester, buildTestWidget());
    });

    // AC-1: tile shows the fallback, not a bare "-" line.
    expect(find.text('SpamAutoDeleteFrom'), findsOneWidget);
    expect(find.text('Uncategorized (legacy)'), findsOneWidget);
    expect(find.text(' - '), findsNothing);
    expect(find.text('-'), findsNothing);

    // AC-2: the category filter chip uses the same wording and counts it.
    expect(find.text('Uncategorized (legacy) (1)'), findsOneWidget);

    // AC-2: details dialog agrees. The tile's leading icon opens details.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('View rule details'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });
    // Dialog renders Category and Sub-Type sections, both with the fallback
    // wording (tile instance + 2 dialog instances may coexist).
    expect(find.text('Uncategorized (legacy)'), findsNWidgets(3));
  });

  testWidgets(
      'F188: rule with all empty condition lists renders invalid marker; rule '
      'with one empty optional list does not (AC-2)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final db = await testHelper.dbHelper.database;

      // Insert rule with ALL empty condition lists (invalid)
      await db.insert('rules', {
        'name': 'AllEmptyConditionsRule',
        'enabled': 1,
        'is_local': 1,
        'execution_order': 10,
        'condition_type': 'AND',
        'condition_from': null,
        'condition_header': null,
        'condition_subject': null,
        'condition_body': null,
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
        'created_by': 'test',
      });

      // Insert rule with one populated list and some empty (healthy)
      await db.insert('rules', {
        'name': 'HealthyWithEmptyOptional',
        'enabled': 1,
        'is_local': 1,
        'execution_order': 20,
        'condition_type': 'AND',
        'condition_from': '["valid@example.com"]',
        'condition_header': null,
        'condition_subject': null,
        'condition_body': null,
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
        'created_by': 'test',
        'pattern_category': 'header_from',
      });

      await mountAndLoadDbWidget(tester, buildTestWidget());
    });

    // AC-2a: The all-empty rule should show the invalid marker in the subtitle
    expect(find.text('invalid -- matches nothing'), findsOneWidget);

    // AC-2b: The healthy rule should NOT show the invalid marker
    // (it should show its category instead)
    expect(find.text('Header / From'), findsOneWidget); // Category label for healthy rule
  });

  // Sprint 74 MV (Harold, 2026-09-29): subject rules read "Subject - Exact
  // Domain" and inflated the Header / From "Exact Domain" chip (46 shown, 14
  // real). What this does NOT catch: a new sub-type value with no label (it
  // would render raw, as 'keyword' would have).
  testWidgets(
      'a subject rule reads "Subject - Keyword", and the Header / From chips '
      'count header rules only', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final db = await testHelper.dbHelper.database;
      Future<void> add(String name, String cat, String sub, String col) =>
          db.insert('rules', {
            'name': name,
            'enabled': 1,
            'is_local': 1,
            'execution_order': 30,
            'condition_type': 'OR',
            col: '["x"]',
            'action_delete': 1,
            'date_added': DateTime.now().millisecondsSinceEpoch,
            'created_by': 'test',
            'pattern_category': cat,
            'pattern_sub_type': sub,
            'source_domain': name,
          });
      await add('Backup subject', 'subject', 'keyword', 'condition_subject');
      await add('example.com', 'header_from', 'exact_domain',
          'condition_header');
      // A legacy body row still carrying a header sub-type value.
      await add('body legacy', 'body', 'exact_domain', 'condition_body');
      await mountAndLoadDbWidget(
          tester, const MaterialApp(home: RulesManagementScreen()));
    });

    expect(find.text('Subject - Keyword'), findsOneWidget);
    expect(find.text('Subject - Exact Domain'), findsNothing);
    expect(find.text('Exact Domain (1)'), findsOneWidget,
        reason: 'the Header / From chip counts the one header rule, not the '
            'body row sharing the value');
    expect(find.text('Keyword (1)'), findsNothing,
        reason: 'keyword is not a Header / From sub-type chip');

    // PR #440 test review: the FILTER, not just the count. Tapping the chip
    // shows the header rule and hides the body row sharing the sub-type.
    expect(find.text('body legacy'), findsOneWidget);
    await tester.tap(find.text('Exact Domain (1)'));
    await tester.pump();
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('body legacy'), findsNothing,
        reason: 'a body rule must not appear under a Header / From chip');
    expect(find.text('Backup subject'), findsNothing);
  });
}
