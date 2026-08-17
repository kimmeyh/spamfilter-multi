/// Sprint 60 Manual Validation (Harold, Android re-validation) -- two
/// Results-screen findings, both pinned here:
///
/// 1. FILTER-BANNER X WAS DEAD with only the DEFAULT filter active: the X
///    called `_toggleFilter(null)`, which clears the ACTION filter -- but at
///    the time the screen's initState default was the Processed SPECIAL
///    filter, so with nothing else active the call was a no-op and the
///    banner could not be dismissed ("couldn't x out of Showing 59 of 59
///    message"). The X now clears every filter dimension
///    (`_clearAllFilters`) -- pinned here across action AND folder filters
///    per the PR #335 cowork review.
///
/// 2. COMPACT LAYOUT: on a phone-width screen the fixed header stack
///    (summary card + banners) consumed nearly the whole height, leaving a
///    ~one-row list viewport. On widths < 600 the header items now scroll
///    WITH the list; desktop widths keep the fixed header.
///
/// Harness mirrors results_display_popup_width_test.dart.
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

  group('ResultsDisplayScreen -- Sprint 60 MV filter-X and compact layout', () {
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
        totalEmails: 20,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await testHelper.dbHelper.insertEmailActionBatch([
        // 20 rows so the folded compact list genuinely scrolls (fewer rows
        // fit the viewport entirely and the scroll assertions would no-op).
        for (final (id, from) in [
          for (var i = 0; i < 20; i++) ('30$i', 'sender$i@spam.com'),
        ])
          {
            'scan_result_id': scanId,
            'email_id': id,
            'email_from': from,
            'email_subject': 'Subject $id',
            'email_received_date': now,
            'email_folder': 'INBOX',
            // 'none' = No-rule rows, so the screen's default filter (F166:
            // No rule) shows them; other action types would leave the
            // filtered list empty.
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

    Future<void> mount(WidgetTester tester) async {
      late RuleSetProvider ruleProvider;
      await tester.runAsync(() async {
        ruleProvider = await buildRuleProvider();
        final scanProvider = EmailScanProvider();
        await mountAndLoadDbWidget(
            tester, wrapScreen(ruleProvider, scanProvider));
      });
    }

    testWidgets(
        'the filter banner X clears EVERY filter dimension (action + folder), '
        'the dead-X bug', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mount(tester);
      await tester.pump();

      // The initState default (F166: the No rule action filter) makes the
      // banner show without ANY user action -- exactly Harold's state.
      final banner = find.textContaining('Tap X to clear filters');
      expect(banner, findsOneWidget,
          reason: 'precondition: the default No-rule filter shows the '
              'banner on load');

      // PR #335 cowork review (mutation gap): tapping X with only the
      // DEFAULT ACTION filter active also passes against the OLD buggy
      // handler and against a narrow fix that clears `_filter` alone. Set
      // the FOLDER dimension too, so this pins the actual claim -- the X
      // clears EVERY filter dimension.
      await tester.tap(find.textContaining('Folders:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INBOX').last);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Folders: 1'), findsOneWidget,
          reason: 'precondition: the folder dimension is now active too');

      await tester.tap(find.byTooltip('Clear filter'));
      await tester.pump();

      expect(banner, findsNothing,
          reason: 'the X must dismiss the banner with only the DEFAULT '
              'filter active -- _toggleFilter(null) was a no-op in that '
              'state and left the X dead');
      expect(find.textContaining('Folders: All'), findsOneWidget,
          reason: 'the X must ALSO clear the folder dimension -- a handler '
              'that clears only the action filter leaves this at '
              '"Folders: 1" and the list still filtered');
    });

    testWidgets(
        'compact width folds the summary header INTO the scrolling list '
        '(just under the 600px threshold), so scrolling moves the summary away', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mount(tester);
      await tester.pump();

      final summaryTitle = find.textContaining('Scan Results');
      expect(summaryTitle, findsOneWidget,
          reason: 'historical view titles the card Scan Results');
      final beforeY = tester.getTopLeft(summaryTitle).dy;

      // Drag the list upward; in the folded (compact) layout the summary is
      // part of the scrollable and must MOVE. In the old fixed layout it
      // stayed put while the one-row list scrolled beneath it.
      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await tester.pump();

      final afterY = tester.getTopLeft(summaryTitle).dy;
      expect(afterY, lessThan(beforeY),
          reason: 'on compact widths the summary must scroll WITH the list '
              '-- a fixed summary leaves a phone with a ~one-row viewport '
              '(Sprint 60 MV finding)');
    });

    testWidgets(
        'desktop width keeps the fixed header (summary does not scroll away)',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mount(tester);
      await tester.pump();

      final summaryTitle = find.textContaining('Scan Results');
      final beforeY = tester.getTopLeft(summaryTitle).dy;

      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await tester.pump();

      final afterY = tester.getTopLeft(summaryTitle).dy;
      expect(afterY, beforeY,
          reason: 'DESKTOP REGRESSION GUARD: the fixed-header layout is '
              'unchanged at desktop widths -- the compact fold must not '
              'leak past its 600px threshold');
    });
  });
}
