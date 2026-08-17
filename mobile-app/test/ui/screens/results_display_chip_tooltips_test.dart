/// F151c (Sprint 58): Scan Results summary chips gain a plain-language
/// tooltip each, and the "Moved" chip is removed entirely (move-on-match is
/// not yet implemented, so it always read 0 alongside real, populated
/// chips -- confirmed reading like a bug rather than an intentional zero
/// during a live user-centric walkthrough, Harold 2026-08-15).
///
/// Harness: reuses the DatabaseTestHelper + mountAndLoadDbWidget pattern
/// established in results_display_no_rule_reload_test.dart -- the only
/// existing way to reach ResultsDisplayScreen's real rendered chip row
/// (it constructs DatabaseHelper()/ScanResultStore directly in initState,
/// no injection seam).
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

  group('ResultsDisplayScreen summary chips -- F151c tooltips + Moved removal', () {
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
          'email_id': '2001',
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

    testWidgets('the "Moved" chip does not appear in the summary row',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
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

      expect(find.textContaining('Moved'), findsNothing,
          reason: 'move-on-match is not implemented; the chip must not '
              'appear at all, not even reading "Moved: 0"');
    });

    testWidgets('each remaining summary chip has a non-empty Tooltip',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
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

      // PR #335 cowork review: this assertion used to count Tooltips
      // anywhere in the tree and passed vacuously off the AppBar icons
      // alone once F166 replaced the chips with a dropdown. It now asserts
      // the F151c explanations THEMSELVES, wherever they live -- the
      // dropdown entries (opened below) plus the chip-face tooltip.
      final faceMessage = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((w) => w.message ?? '')
          .firstWhere((m) => m.startsWith('Filter the email list'),
              orElse: () => '');
      expect(faceMessage, contains('Total emails found'),
          reason: 'the removed Found chip F151c explanation must survive '
              'on the dropdown face');

      await tester.tap(find.byTooltip(faceMessage));
      await tester.pumpAndSettle();

      // Each F151c explanation, verbatim from Sprint 58.
      for (final explanation in [
        'No existing rule or safe sender matched these emails.',
        'These emails matched a safe sender.',
        'These emails matched a delete rule.',
        'Emails that could not be processed due to an error.',
        'Emails evaluated against your rules so far.',
      ]) {
        expect(find.textContaining(explanation), findsOneWidget,
            reason: 'F151c plain-language explanation "$explanation" must '
                'still reach the user after the F166 redesign');
      }
    });
  });
}
