/// F151e (Sprint 58): the email-detail action popup previously stretched to
/// ~(window width - 32px), which on the default 1600px window meant a
/// ~1568px-wide popup -- confirmed via a live walkthrough screenshot as
/// reading oversized even though its Safe-Senders/Block-Rule button grids
/// were already laid out side-by-side (not stacked). Capping the popup's
/// width to a reasonable dialog size fixes this without touching the
/// already-correct button grid.
///
/// Harness: reuses the DatabaseTestHelper + mountAndLoadDbWidget pattern
/// established in results_display_no_rule_reload_test.dart.
library;

import 'package:flutter/material.dart';
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

  group('ResultsDisplayScreen email-detail popup -- F151e width cap', () {
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
          'email_id': '3001',
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

    testWidgets(
        'popup width is capped well below the default 1600px window width',
        (tester) async {
      // Wide surface matching the default app window size confirmed during
      // the live walkthrough (1600x900) -- this is exactly the scenario
      // that showed the oversized popup.
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

      // Open the popup by tapping the seeded result row.
      await tester.tap(find.text('bad@spam.com'));
      await tester.pumpAndSettle();

      // The popup's Material widget carries the elevation:8/borderRadius:12
      // styling unique to this sheet (distinguishes it from the Scaffold's
      // own root Material).
      final popupMaterial = tester.widgetList<Material>(find.byType(Material))
          .where((m) => m.elevation == 8)
          .toList();
      expect(popupMaterial, hasLength(1),
          reason: 'expected exactly one popup Material (elevation: 8)');

      final popupSize = tester.getSize(find
          .byWidgetPredicate((w) => w is Material && w.elevation == 8)
          .first);
      expect(popupSize.width, lessThanOrEqualTo(480),
          reason: 'popup must be capped at maxWidth: 480, not stretch to '
              'the full window width');
      expect(popupSize.width, greaterThan(200),
          reason: 'sanity check -- popup should still be a normal usable '
              'width, not collapsed');
    });
  });
}
