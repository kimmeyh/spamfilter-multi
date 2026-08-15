/// Sprint 58 Manual Validation follow-ups MV-1/MV-2/MV-3 (Harold,
/// 2026-08-15): search-box behavior on the Scan Results screen.
///
///   MV-1: tapping the Search ICON must focus the text box immediately so
///         the user can start typing without a second click. (The Ctrl+F
///         path already did this; the icon path was missing the post-frame
///         focus request and the TextField's own autofocus loses the race
///         against the screen's outer Focus(autofocus: true) wrapper.)
///   MV-2: the close-search control is a back-arrow (Material convention
///         for leaving in-AppBar search mode), NOT an X -- the X visually
///         collided with the app-exit X on the opposite end of the AppBar.
///   MV-3: Escape closes the search box while it is open (standard Windows
///         desktop convention), sharing the same _closeSearch() path as the
///         back-arrow so both exits behave identically.
///
/// Harness: same DatabaseTestHelper + mountAndLoadDbWidget pattern as
/// results_display_popup_width_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('ResultsDisplayScreen search behavior -- MV-1/2/3', () {
    late DatabaseTestHelper testHelper;
    const accountId = 'aol-user@aol.com';
    late int scanId;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      await testHelper.createTestAccount(accountId, platformId: 'aol');

      scanId = await testHelper.createTestScanResult(
        accountId,
        scanType: 'manual',
        scanMode: 'readonly',
        totalEmails: 1,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await testHelper.dbHelper.insertEmailActionBatch([
        {
          'scan_result_id': scanId,
          'email_id': '4001',
          'email_from': 'bad@spam.com',
          'email_subject': 'Win a prize',
          'email_received_date': now,
          'email_folder': 'INBOX',
          'action_type': 'none',
          'matched_rule_name': null,
          'matched_pattern': null,
          'is_safe_sender': 0,
          'success': 1,
        },
      ]);
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    Future<RuleSetProvider> buildRuleProvider() async {
      final provider = RuleSetProvider();
      provider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await provider.loadRules();
      await provider.loadSafeSenders();
      return provider;
    }

    Widget wrapScreen(
      RuleSetProvider ruleProvider,
      EmailScanProvider scanProvider,
    ) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: MaterialApp(
          home: ResultsDisplayScreen(
            platformId: 'aol',
            platformDisplayName: 'AOL',
            accountId: accountId,
            accountEmail: accountId,
            historicalScanId: scanId,
          ),
        ),
      );
    }

    Future<void> mountScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late RuleSetProvider ruleProvider;
      await tester.runAsync(() async {
        ruleProvider = await buildRuleProvider();
        final scanProvider = EmailScanProvider();
        await mountAndLoadDbWidget(
            tester, wrapScreen(ruleProvider, scanProvider));
      });
    }

    Future<void> openSearchViaIcon(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Search (Ctrl+F)'));
      await tester.pump(); // build the TextField
      await tester.pump(); // run the post-frame focus request
    }

    testWidgets('MV-1: tapping the search icon focuses the text box',
        (tester) async {
      await mountScreen(tester);
      await openSearchViaIcon(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, isNotNull);
      expect(textField.focusNode!.hasFocus, isTrue,
          reason: 'the user must be able to start typing immediately after '
              'tapping the search icon, without clicking the text box');
    });

    testWidgets(
        'MV-2: close-search control is a leading back-arrow, and tapping it '
        'closes the search box', (tester) async {
      await mountScreen(tester);
      await openSearchViaIcon(tester);
      expect(find.byType(TextField), findsOneWidget);

      // The leading close-search control renders as a back-arrow with the
      // 'Close Search' tooltip (NOT an X, which collided with app-exit).
      final closeSearch = find.byTooltip('Close Search');
      expect(closeSearch, findsOneWidget);
      expect(
        find.descendant(
            of: closeSearch, matching: find.byIcon(Icons.arrow_back)),
        findsOneWidget,
        reason: 'close-search must be a back-arrow, not an X',
      );
      expect(
        find.descendant(of: closeSearch, matching: find.byIcon(Icons.close)),
        findsNothing,
        reason: 'the X icon must no longer be the close-search control',
      );

      await tester.tap(closeSearch);
      await tester.pump();
      expect(find.byType(TextField), findsNothing,
          reason: 'tapping the back-arrow must close the search box');
    });

    testWidgets('MV-3: Escape closes the search box while it is open',
        (tester) async {
      await mountScreen(tester);
      await openSearchViaIcon(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(TextField), findsNothing,
          reason: 'Escape must close the open search box');
    });
  });
}
