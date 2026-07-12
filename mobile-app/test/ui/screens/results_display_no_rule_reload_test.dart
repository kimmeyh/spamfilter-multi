/// Widget test for S38-CI-6: cross-screen no-rule reload on the
/// Scan History > Scan Results screen (ResultsDisplayScreen in historical
/// mode).
///
/// Regression guarded (Sprint 38 Rounds 7/8/9): when a user opens a
/// historical scan, then adds a rule out-of-band (as if via Settings >
/// Manage Rules), then RE-ENTERS the scan, the screen must reflect the new
/// rule ON FIRST PAINT -- the matching row hidden (_hiddenEmailKeys), the
/// F82 footer showing the correct "M of N addressed -- K remaining", and the
/// "No rule" chip count decremented. Before the Round 8/9 fix, the first
/// paint cached the pre-eval state and only a subsequent filter toggle picked
/// up the override.
///
/// Harness notes:
/// - Uses the real sqflite_ffi database (via DatabaseTestHelper), because
///   ResultsDisplayScreen constructs DatabaseHelper()/ScanResultStore directly
///   inside initState's _loadLastCompletedScan (no store injection seam).
///   DatabaseHelper is a singleton; DatabaseTestHelper.setUp() points it at an
///   isolated temp DB via setAppPaths, so the screen reads the seeded data.
/// - Uses testWidgets + pumpAndSettle (NOT fakeAsync). The initState async DB
///   load resolves under pumpAndSettle. The repo's known FakeAsync +
///   sqflite_ffi + initState-DB-load hang is avoided by not using fakeAsync.
/// - EmailScanProvider defaults to ScanMode.readOnly / ScanStatus.idle, which
///   makes _reProcessAffectedEmails return early (no IMAP / no secure-storage
///   access). The Round 9 unconditional hidden-row pass is what hides the
///   matched row on first paint -- exactly the path under test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('ResultsDisplayScreen historical no-rule cross-screen reload', () {
    late DatabaseTestHelper testHelper;
    const accountId = 'aol-user@aol.com';
    late int scanId;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      await testHelper.createTestAccount(accountId, platformId: 'aol');

      // Seed a completed historical scan with TWO "no rule" emails:
      //   - bad@spam.com  -> will be matched by the out-of-band rule
      //   - friend@trusted.com -> will NOT be matched (stays no-rule)
      scanId = await testHelper.createTestScanResult(
        accountId,
        scanType: 'manual',
        scanMode: 'readonly',
        totalEmails: 2,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await testHelper.dbHelper.insertEmailActionBatch([
        {
          'scan_result_id': scanId,
          'email_id': '1001',
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
        {
          'scan_result_id': scanId,
          'email_id': '1002',
          'email_from': 'friend@trusted.com',
          'email_subject': 'Lunch?',
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

    /// Build a RuleSetProvider backed by the test database (no AppPaths /
    /// migration). Starts with zero local rules (default seed is not run, so
    /// neither email matches anything initially).
    ///
    /// NOTE: must be invoked inside tester.runAsync -- loadRules /
    /// loadSafeSenders issue real FFI sqlite calls that only resolve on the
    /// real event loop.
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

    // [instanceKey] forces Flutter to build a FRESH State (and thus re-run
    // initState -> _loadLastCompletedScan) on the second mount. Without a
    // distinct key, Flutter reuses the existing State for a same-type widget
    // and only calls didUpdateWidget, so the cross-screen reload path would
    // never execute -- the whole point of this test.
    Widget wrapScreen(
      RuleSetProvider ruleProvider,
      EmailScanProvider scanProvider, {
      required Key instanceKey,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: MaterialApp(
          home: ResultsDisplayScreen(
            key: instanceKey,
            platformId: 'aol',
            platformDisplayName: 'AOL',
            accountId: accountId,
            accountEmail: accountId,
            historicalScanId: scanId, // the actual seeded scan id
          ),
        ),
      );
    }

    testWidgets(
        'matched row hidden, footer "1 of 2 addressed -- 1 remaining", '
        'and "No rule" chip == 1 on FIRST paint after out-of-band rule add',
        (tester) async {
      // ALL database-touching async work (provider load, rule add, the
      // screen's initState _loadLastCompletedScan) MUST run inside
      // tester.runAsync. Those operations issue real FFI sqlite calls backed
      // by a background isolate / real timers; in the default fake-async test
      // zone the futures never complete and the test hangs (the repo's known
      // sqflite_ffi + initState async-load hang). pumpAndSettle is also
      // avoided -- it would spin on the RefreshIndicator / progress widgets.
      //
      // Strategy: drive the whole scenario inside runAsync, calling pump()
      // (NOT pumpAndSettle) to render frames after each async load. find/expect
      // run on the rendered element tree afterward and are zone-agnostic.

      // Use a tall surface so the whole screen Column (summary card + chip
      // wrap + footer + both ListTiles + bottom buttons) lays out without a
      // RenderFlex overflow and both list rows are actually built (the default
      // 800x600 surface clips the list, hiding rows from find.text).
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late RuleSetProvider ruleProvider;

      await tester.runAsync(() async {
        ruleProvider = await buildRuleProvider();
        final scanProvider = EmailScanProvider(); // readOnly / idle defaults

        /// Render a fresh screen instance and let its async initState DB load
        /// (getScanResultById -> queryEmailActions -> loadRules/loadSafeSenders
        /// -> re-evaluate -> setState) complete. Delegates to the shared
        /// harness (Sprint 46 retro IMP-2).
        Future<void> mountAndLoad(Widget app) =>
            mountAndLoadDbWidget(tester, app);

        // --- First mount: NO matching rule yet -----------------------------
        await mountAndLoad(wrapScreen(ruleProvider, scanProvider,
            instanceKey: const ValueKey('mount1')));

        // Both emails are "No rule" -> footer denominator is 2, none
        // addressed, both rows visible.
        expect(find.text('No rule: 2'), findsOneWidget,
            reason: 'Both seeded emails start as "No rule"');
        expect(find.textContaining('0 of 2 "No rule" emails addressed'),
            findsOneWidget,
            reason: 'Initial footer: nothing addressed yet');
        expect(find.text('bad@spam.com'), findsOneWidget);
        expect(find.text('friend@trusted.com'), findsOneWidget);

        // --- Out-of-band rule add (simulates Settings > Manage Rules) ------
        // Header rule matching the From address bad@spam.com. The historical
        // loader seeds headers {'From': ..., 'Subject': ...}, and the
        // evaluator matches 'header' patterns against message.from
        // (lowercased).
        await ruleProvider.addRule(
          Rule(
            name: 'Block_spam_com',
            enabled: true,
            isLocal: true,
            executionOrder: 20,
            conditions: RuleConditions(type: 'OR', header: [r'@spam\.com$']),
            actions: RuleActions(delete: true),
            patternCategory: 'header_from',
            patternSubType: 'exact_domain',
            sourceDomain: 'spam.com',
          ),
        );

        // --- Re-enter the screen (simulate cross-screen return) ------------
        // A brand-new ResultsDisplayScreen instance + fresh EmailScanProvider,
        // reusing the same (now-updated) RuleSetProvider. This forces
        // initState -> _loadLastCompletedScan to run again against the new
        // rule set, which is precisely the Rounds 7/8/9 reload path.
        final scanProvider2 = EmailScanProvider();
        await mountAndLoad(wrapScreen(ruleProvider, scanProvider2,
            instanceKey: const ValueKey('mount2')));
      });

      // FIRST paint assertions (no filter toggle performed):

      // 1) The matched row is hidden; the unmatched row remains.
      expect(find.text('bad@spam.com'), findsNothing,
          reason: 'bad@spam.com matched the new rule and must be hidden on '
              'first paint (_hiddenEmailKeys)');
      expect(find.text('friend@trusted.com'), findsOneWidget,
          reason: 'friend@trusted.com still has no matching rule');

      // 2) Footer reflects 1 of 2 addressed, 1 remaining.
      expect(
          find.textContaining('1 of 2 "No rule" emails addressed -- 1 remaining'),
          findsOneWidget,
          reason: 'F82 footer must show cumulative progress on first paint');

      // 3) Chip strip: "No rule" count reflects the effective action override
      //    (now 1), and the "Deleted" chip reflects the newly-matched email.
      expect(find.text('No rule: 1'), findsOneWidget,
          reason: 'Effective "No rule" count must drop to 1 on first paint');
      // readOnly mode renders the deleted chip as "Deleted (not processed)".
      expect(find.text('Deleted (not processed): 1'), findsOneWidget,
          reason: 'Newly matched email counts toward the Deleted chip');
    });

    // Sprint 46 manual-testing feedback (Harold 2026-07-11): the "No rule"
    // auto-advance must work on the HISTORICAL path (Scan History > scan
    // results) too, not just live scan results -- both views are the same
    // ResultsDisplayScreen, and this pins the historical mode so it never
    // regresses independently. Also covers the skip-covered-items rule: a
    // Block Exact Domain action on bad@spam.com must advance PAST
    // worse@spam.com (same domain -- the new rule addresses it too)
    // straight to friend@trusted.com.
    testWidgets(
        'historical view: quick action auto-advances popup to next item '
        'not covered by the new rule ("No rule" filter active)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        // Third seeded email, SAME domain as bad@spam.com, sitting between it
        // and friend@trusted.com in the sorted list (folder -> domain ->
        // email: spam.com sorts after trusted.com? No -- 's' > 't' is false:
        // 'spam.com' < 'trusted.com', so both spam.com rows come first).
        await testHelper.dbHelper.insertEmailActionBatch([
          {
            'scan_result_id': scanId,
            'email_id': '1003',
            'email_from': 'worse@spam.com',
            'email_subject': 'Another prize',
            'email_received_date': DateTime.now().millisecondsSinceEpoch,
            'email_folder': 'INBOX',
            'action_type': 'none',
            'matched_rule_name': null,
            'matched_pattern': null,
            'is_safe_sender': 0,
            'success': 1,
          },
        ]);

        final ruleProvider = await buildRuleProvider();
        final scanProvider = EmailScanProvider(); // readOnly / idle

        await mountAndLoadDbWidget(
            tester,
            wrapScreen(ruleProvider, scanProvider,
                instanceKey: const ValueKey('advanceMount')));

        // Activate the "No rule" filter (the advance is scoped to it).
        expect(find.text('No rule: 3'), findsOneWidget);
        await tester.tap(find.text('No rule: 3'));
        await tester.pump();

        // Open the popup on the first spam.com email.
        await tester.tap(find.text('bad@spam.com'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Create Block Rule'), findsOneWidget,
            reason: 'Detail popup must open in historical mode');

        // Act: Block Exact Domain (@spam.com) -- covers worse@spam.com too.
        await tester.tap(find.text('Block Exact Domain'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // The popup must have advanced DIRECTLY to friend@trusted.com,
        // skipping worse@spam.com (covered by the domain rule just created).
        expect(find.text('Create Block Rule'), findsOneWidget,
            reason: 'Next popup must be open immediately after the action');
        expect(find.text('friend@trusted.com'), findsAtLeastNWidgets(2),
            reason: 'friend@trusted.com must appear in the advanced popup '
                '(header + button subtitles) in addition to its list row');
        expect(find.text('worse@spam.com').evaluate().length,
            lessThanOrEqualTo(1),
            reason: 'worse@spam.com must NOT be the advanced popup target '
                '(same domain as the rule just created)');

        // Let the background pipeline (rule persist + re-evaluation) finish
        // before teardown so no timers/futures leak past the test.
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await tester.pump();
      });
    });
  });
}
