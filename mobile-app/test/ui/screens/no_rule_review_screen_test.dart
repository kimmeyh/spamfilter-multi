import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/rule_set.dart'
    show Rule, RuleConditions, RuleActions;
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';
import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

/// F39 (Sprint 46): widget tests for the cross-account "No rule" review
/// screen.
///
/// F283 (Sprint 78): the screen was rebuilt on the Results pieces -- the count
/// is the fixed "No rule (N)" chip, a row tap opens the shared pop-up, and a
/// quick action there replaces the removed multi-select bulk menu (MV-Q16).
/// The bulk-action tests were rewritten to drive the pop-up; their contracts
/// (covered rows swept, stale sweep count never claimed, the MT-2b race) are
/// unchanged.
///
/// Two known hazards from prior sprints' test infrastructure, both
/// documented in results_display_no_rule_reload_test.dart:
/// (1) sqflite_common_ffi issues real FFI calls that never resolve in the
///     default fake-async widget-test zone -- all DB-touching setup AND
///     the widget's own async initState load must run inside
///     tester.runAsync(), driven with tester.pump() (never pumpAndSettle,
///     which spins forever on the loading indicator in that same zone).
/// (2) SecureCredentialsStore.getSavedAccounts() is not injectable from
///     the screen, so we stub its underlying MethodChannel (same pattern
///     as database_encryption_key_service_test.dart) -- it stores a
///     simple comma-separated string under "saved_accounts", not JSON.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = <String, String>{};

  late DatabaseTestHelper testHelper;
  late RuleSetProvider ruleProvider;

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

    ruleProvider = RuleSetProvider();
    ruleProvider.initializeForTesting(
      databaseStore: RuleDatabaseStore(testHelper.dbHelper),
      safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
    );
    // MT-2b: load like the real app does at startup -- an UNLOADED provider
    // makes addRule/addSafeSender silently no-op (_rules == null early
    // return), which masked a real silent-failure class in earlier versions
    // of these tests.
    await ruleProvider.loadRules();
    await ruleProvider.loadSafeSenders();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  /// getSavedAccounts() parses a simple comma-separated string, not JSON.
  void registerSavedAccount(String accountId) {
    final existing = fakeSecureStorage['saved_accounts'];
    fakeSecureStorage['saved_accounts'] =
        existing == null || existing.isEmpty ? accountId : '$existing,$accountId';
  }

  /// Inserts a completed scan_results row with an explicit completed_at,
  /// bypassing DatabaseTestHelper.createTestScanResult (which leaves
  /// completed_at NULL -- fine for a single scan per account, but
  /// getLatestCompletedScan orders by completed_at DESC across scans, so
  /// tests asserting "latest wins" need explicit control).
  Future<int> insertCompletedScan(
    String accountId, {
    required int completedAtMs,
    int noRuleCount = 0,
  }) async {
    final scanId = await testHelper.dbHelper.insertScanResult({
      'account_id': accountId,
      'scan_type': 'manual',
      'scan_mode': 'readonly',
      'started_at': completedAtMs - 1000,
      'completed_at': completedAtMs,
      'total_emails': noRuleCount,
      'processed_count': 0,
      'deleted_count': 0,
      'moved_count': 0,
      'safe_sender_count': 0,
      'no_rule_count': noRuleCount,
      'error_count': 0,
      'status': 'completed',
      'folders_scanned': '["INBOX"]',
    });

    final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
    for (var i = 0; i < noRuleCount; i++) {
      await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-$scanId-$i',
        fromEmail: 'sender$i@spam.example',
        subject: 'Test subject $i',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(completedAtMs),
      ));
    }
    return scanId;
  }

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<RuleSetProvider>.value(
        value: ruleProvider,
        child: const NoRuleReviewScreen(),
      ),
    );
  }

  /// Mounts the screen and lets its async initState load (getSavedAccounts
  /// -> per-account getLatestCompletedScan -> getUnmatchedEmailsByScanFiltered
  /// -> setState) resolve. Must be called from inside tester.runAsync().
  /// Delegates to the shared harness (Sprint 46 retro IMP-2).
  Future<void> mountAndLoad(WidgetTester tester) => mountAndLoadDbWidget(
      tester, buildTestWidget(),
      settleDelay: const Duration(milliseconds: 500));

  Finder noRuleChip(int n) => find.text('No rule ($n)');

  /// Opens [sender]'s pop-up and taps [action] in it, letting the background
  /// rule write, mark and reload finish (all real I/O -> runAsync).
  Future<void> popupAction(
      WidgetTester tester, String sender, String action) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(sender).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(action));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  /// Closes any open pop-up (the auto-advance opens the next one).
  Future<void> closePopups(WidgetTester tester) async {
    for (var i = 0;
        i < 5 && find.text('Create Block Rule').evaluate().isNotEmpty;
        i++) {
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('shows empty state when no accounts have No rule items',
      (tester) async {
    await tester.runAsync(() async {
      await mountAndLoad(tester);
    });

    expect(find.text('No unaddressed items'), findsOneWidget);
  });

  testWidgets(
      'load failure shows a friendly SnackBar with no raw exception text '
      '(F122, Issue #280)', (tester) async {
    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      // Force the load to throw: drop the table getLatestCompletedScan
      // queries during the screen's initState load.
      final db = await testHelper.dbHelper.database;
      await db.execute('DROP TABLE scan_results');

      await mountAndLoad(tester);
    });
    // Let the SnackBar animation start.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
        find.text('Could not load review items. Please try again or check '
            'the log for details.'),
        findsOneWidget);
    // AC-2: no raw exception object reaches the UI.
    expect(find.textContaining('no such table'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('aggregates No rule items across multiple accounts by default',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 2);

      await testHelper.createTestAccount('aol-b@example.com');
      registerSavedAccount('aol-b@example.com');
      await insertCompletedScan('aol-b@example.com',
          completedAtMs: 1000, noRuleCount: 3);

      await mountAndLoad(tester);
    });

    expect(noRuleChip(5), findsOneWidget);
    expect(find.text('All Accounts (5)'), findsOneWidget);
  });

  testWidgets(
      'Refresh CONFIRMS when nothing changed (Harold MV: "appears to do '
      'nothing")', (tester) async {
    // Harold, 2026-07-31 manual validation: "what does the refresh icon do -
    // as it appears to do nothing". It was working -- re-reading the latest
    // scan and re-running the coverage sweep -- but all of that is local-DB
    // work that finishes in milliseconds, so the spinner never paints a
    // perceptible frame and an unchanged list is indistinguishable from a dead
    // button. The fix is FEEDBACK, not different behavior, so this test
    // asserts the confirmation rather than the reload.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 2);

      await mountAndLoad(tester);
    });

    expect(noRuleChip(2), findsOneWidget,
        reason: 'precondition: the list loaded');
    expect(find.byTooltip('Filter by account'), findsOneWidget,
        reason: 'F283 MV-Q14: the account drop-down shows even with ONE saved '
            'account (it used to hide)');

    // No rules were added between load and refresh, so nothing can become
    // covered -- the exact case Harold hit.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip(
          'Re-check the last scan (does not fetch new mail)'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No changes -- list is up to date'), findsOneWidget,
        reason: 'a refresh that changes nothing must SAY so -- silence is what '
            'made this look broken');

    // The list itself must be unchanged: this is feedback, not behavior.
    expect(noRuleChip(2), findsOneWidget);
  });

  testWidgets('account filter dropdown narrows the list to one account',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 2);

      await testHelper.createTestAccount('aol-b@example.com');
      registerSavedAccount('aol-b@example.com');
      await insertCompletedScan('aol-b@example.com',
          completedAtMs: 1000, noRuleCount: 3);

      await mountAndLoad(tester);
    });

    // F169 (Sprint 61): the account filter is a DROPDOWN now, not a chip row --
    // open the menu, then pick the account. Behavior under test (narrowing the
    // list to one account) is unchanged; only the affordance moved.
    await tester.tap(find.byTooltip('Filter by account'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('a@example.com (2)').last);
    await tester.pumpAndSettle();

    expect(noRuleChip(2), findsOneWidget);
  });

  // F283 AC-3 (MV-Q16): multi-select and bulk actions are gone.
  //
  // What this does NOT catch: a selection reached by a gesture this test does
  // not try (only tap and long-press on a row).
  testWidgets('F283 AC-3: no checkbox, selection bar or bulk menu; tap and '
      'long-press select nothing', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 1);
      await mountAndLoad(tester);
    });

    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Apply Rule'), findsNothing);
    expect(find.byTooltip('Bulk Actions'), findsNothing);
    await tester.longPress(find.text('sender0@spam.example'));
    await tester.pump();
    expect(find.textContaining('selected'), findsNothing);
  });

  // F283 AC-4 (MV-Q17): a row tap opens the Results pop-up, and its date row
  // names the ACCOUNT the email belongs to.
  //
  // What this does NOT catch: the pop-up's placement on a phone (the compact
  // width path), which keeps its own Results tests.
  testWidgets('F283 AC-4: tapping a row opens the Results pop-up naming the '
      'account', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 1);
      await mountAndLoad(tester);
    });

    await tester.tap(find.text('sender0@spam.example'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create Block Rule'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget,
        reason: 'every Review row is unaddressed, so Skip always applies');
    expect(find.text('a@example.com'), findsOneWidget,
        reason: 'the pop-up date row names the account email');
  });

  // F284 R-1 / T-2: the account drop-down face is ONE button node whose tap
  // action opens the menu (UI Automation can invoke it without the mouse).
  //
  // What this does NOT catch: how Windows UIA projects it (the WinWright
  // sweep).
  testWidgets('F284 R-1: the account face is a button whose action opens the '
      'account menu', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 2);
      await mountAndLoad(tester);
    });

    SemanticsNode? face;
    void visit(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.label == 'All Accounts (2)' &&
          d.hasFlag(SemanticsFlag.isButton) &&
          d.hasAction(SemanticsAction.tap)) {
        face = n;
      }
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(face, isNotNull);
    expect(find.text('a@example.com (2)'), findsNothing,
        reason: 'precondition: the menu is closed');

    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(face!.id, SemanticsAction.tap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('a@example.com (2)'), findsOneWidget,
        reason: 'the action must open the account menu');
    handle.dispose();
  });

  // F283 AC-1 (T-1): search over sender, subject and folder, with the
  // Results "Showing X of Y" bar; closing search restores the list.
  //
  // What this does NOT catch: Ctrl+F on a real keyboard focus chain (the test
  // opens search with the icon).
  testWidgets('F283 AC-1: typing part of a subject shows only matching rows '
      'and "Showing 1 of 3 emails"', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 3);
      await mountAndLoad(tester);
    });

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('review_search_field')), 'subject 1');
    await tester.pump();

    expect(find.text('sender1@spam.example'), findsOneWidget);
    expect(find.text('sender0@spam.example'), findsNothing);
    expect(find.text('sender2@spam.example'), findsNothing);
    expect(find.textContaining('Showing 1 of 3 emails'), findsOneWidget);

    await tester.tap(find.byTooltip('Close Search'));
    await tester.pump();
    expect(find.text('sender0@spam.example'), findsOneWidget);
    expect(find.textContaining('Showing'), findsNothing);
  });

  // MT-2 (Sprint 50, Harold manual validation): a bulk block action must
  // (a) treat an already-existing covering rule as success (item resolves,
  // no 'failed to add block rule'), and (b) auto-resolve UNSELECTED items
  // the new rule covers -- Live Scan parity.
  testWidgets(
      'pop-up Block Entire Domain resolves the row AND auto-resolves the '
      'other rows the rule covers (MT-2)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanId = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);

      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      // Two senders from the SAME domain (one will be selected, one not)
      // plus one from a different domain that must stay listed.
      for (final (uid, sender) in [
        ('uid-1', 'first@dupdomain.example'),
        ('uid-2', 'second@dupdomain.example'),
        ('uid-3', 'other@keepme.example'),
      ]) {
        await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
          scanResultId: scanId,
          providerIdentifierType: 'imap_uid',
          providerIdentifierValue: uid,
          fromEmail: sender,
          folderName: 'INBOX',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ));
      }

      await mountAndLoad(tester);
    });

    expect(noRuleChip(3), findsOneWidget);

    // F283: the pop-up's Block Entire Domain on the first dupdomain row.
    await popupAction(tester, 'first@dupdomain.example', 'Block Entire Domain');
    // Auto-advance skipped the row the new rule covers (second@dupdomain) and
    // opened the next uncovered one (Results' F136 / Sprint 46 behavior).
    expect(find.text('Create Block Rule'), findsOneWidget,
        reason: 'the next pop-up opens at once');
    expect(find.text('second@dupdomain.example'), findsNothing,
        reason: 'the advance must skip a row the new rule covers');
    expect(find.text('other@keepme.example'), findsAtLeastNWidgets(2),
        reason: 'the advanced pop-up shows the next uncovered sender');
    await closePopups(tester);

    // The acted row resolved AND the other same-domain row was swept; only
    // the other-domain row remains.
    expect(noRuleChip(1), findsOneWidget);
    expect(find.text('other@keepme.example'), findsOneWidget);
    expect(find.text('first@dupdomain.example'), findsNothing);
    expect(find.text('second@dupdomain.example'), findsNothing);
  });

  testWidgets(
      'action summary omits the STALE sweep count when the post-action reload '
      'fails (PR #292 re-review)', (tester) async {
    // _lastSweepCount is only reset inside _sweepCoveredItems, which a FAILED
    // reload never reaches -- so an ungated summary would append the PREVIOUS
    // load's count ("N more auto-resolved") as a false claim, painted over the
    // load-failure SnackBar. Sequence: a first bulk action that genuinely
    // sweeps one item (making the stale count non-zero), then a broken DB,
    // then a second bulk action whose reload fails.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanId = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);

      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      for (final (uid, sender) in [
        ('uid-1', 'first@dupdomain.example'),
        ('uid-2', 'second@dupdomain.example'),
        ('uid-3', 'other@keepme.example'),
      ]) {
        await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
          scanResultId: scanId,
          providerIdentifierType: 'imap_uid',
          providerIdentifierValue: uid,
          fromEmail: sender,
          folderName: 'INBOX',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ));
      }

      await mountAndLoad(tester);
    });

    // FIRST action: blocking dupdomain sweeps the sibling, leaving
    // _lastSweepCount == 1 (the stale value the gate must suppress).
    await popupAction(tester, 'first@dupdomain.example', 'Block Entire Domain');
    await closePopups(tester);
    expect(noRuleChip(1), findsOneWidget,
        reason: 'precondition: the first action resolved the pair, sweeping '
            'the sibling');

    // The FIRST action's summary legitimately says "1 more covered by it" --
    // clear the whole SnackBar queue so the loop below can only be failed by a
    // SECOND-round (stale) claim.
    final messenger =
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger));
    messenger.clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('more covered by it'), findsNothing,
        reason: 'precondition: the first-round summary must have been cleared');

    // Break the reload path only: the second batch itself (rule insert +
    // mark-processed) does not read scan_results, but _loadItems starts with
    // getLatestCompletedScan, which does.
    await tester.runAsync(() async {
      final db = await DatabaseHelper().database;
      await db.execute('DROP TABLE IF EXISTS scan_results');
    });

    // SECOND action: the rule write succeeds, the reload fails.
    await popupAction(tester, 'other@keepme.example', 'Block Entire Domain');
    await closePopups(tester);

    // The load-failure SnackBar shows FIRST, and the batch summary queues
    // behind it. Its auto-dismiss uses a real-time Timer that `pump(duration)`
    // does not advance (shown from inside runAsync), so the queue must be
    // advanced explicitly. A first version of this assertion frame-scanned and
    // never saw the queued summary at all -- it passed against the ungated
    // mutation, which is exactly the worthless-green shape mutation checks
    // exist to catch.
    expect(find.textContaining('Could not load review items'), findsOneWidget,
        reason: 'the reload failure must be the FIRST thing the user sees');

    messenger.hideCurrentSnackBar();
    // Advance the queue until the action's own summary SnackBar is showing
    // (the load-failure one was just dismissed). Read THAT SnackBar's text,
    // never a list row: a first version matched the row and passed against
    // the ungated mutation (RM4).
    Finder summary = find.descendant(
        of: find.byType(SnackBar), matching: find.byType(Text));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      summary = find.descendant(
          of: find.byType(SnackBar), matching: find.byType(Text));
      final texts = tester.widgetList<Text>(summary).map((t) => t.data ?? '');
      if (texts.isNotEmpty && !texts.any((t) => t.contains('Could not load'))) {
        break;
      }
    }
    final summaryText = tester
        .widgetList<Text>(summary)
        .map((t) => t.data ?? '')
        .join(' | ');
    expect(summaryText, isNotEmpty,
        reason: 'the action summary must still appear once the error is '
            'dismissed -- the rule was created; only the sweep claim is gated');
    expect(summaryText.contains('Could not load'), isFalse);
    expect(summaryText.contains('more covered by it'), isFalse,
        reason: 'the reload FAILED, so the sweep never ran this round -- '
            'appending the previous round\'s count ("1 more covered by it") '
            'would be a false claim about state never observed');
  });

  // MT-2b (Sprint 50, Harold's 6-item repro 2026-07-26): a NEWER scan can
  // complete while the screen is open, re-populating the SAME senders as
  // fresh unprocessed rows. The bulk action then creates the rules and marks
  // the OLD scan's rows -- but the reload shows the newer scan's identical
  // rows, so the list looked completely unchanged. The auto-resolve sweep
  // must therefore run AFTER the reload, over the fresh pool.
  testWidgets(
      'a block action resolves rows re-populated by a scan that completed '
      'while the screen was open (MT-2b race)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanA = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);
      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanA,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'a-1',
        fromEmail: 'victim@racedomain.example',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1500),
      ));

      await mountAndLoad(tester);
    });

    expect(noRuleChip(1), findsOneWidget);

    // A NEWER scan completes behind the screen's back, re-writing the same
    // sender (plus one uncovered sender) as fresh unprocessed rows.
    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      final scanB = await insertCompletedScan(accountId,
          completedAtMs: 2000, noRuleCount: 0);
      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      for (final (uid, sender) in [
        ('b-1', 'victim@racedomain.example'),
        ('b-2', 'other@keepme.example'),
      ]) {
        await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
          scanResultId: scanB,
          providerIdentifierType: 'imap_uid',
          providerIdentifierValue: uid,
          fromEmail: sender,
          folderName: 'INBOX',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2500),
        ));
      }
    });

    // Act on the (stale, scan-A) victim row: Block Entire Domain.
    await popupAction(tester, 'victim@racedomain.example', 'Block Entire Domain');
    await closePopups(tester);

    // The reload lands on scan B; its covered victim row must have been
    // auto-resolved by the post-reload sweep -- only the uncovered sender
    // remains, and the count chip reflects it.
    expect(noRuleChip(1), findsOneWidget,
        reason: 'scan B\'s covered row must not re-surface after the bulk '
            'action');
    expect(find.text('other@keepme.example'), findsOneWidget);
    expect(find.text('victim@racedomain.example'), findsNothing);
  });

  // Sprint 46 retro IMP-1 (Harold): provider senders group at the top with a
  // heading and end indicator; lists without provider senders are unchanged.
  testWidgets(
      'provider senders group at top with heading and end indicator',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanId = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);

      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      // One business-domain sender and one PROVIDER sender (gmail.com),
      // inserted business-first so the grouping (not insertion order) is
      // what puts the provider sender on top.
      await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-biz',
        fromEmail: 'seller@bizcorp.example',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ));
      await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-gmail',
        fromEmail: 'scammer@gmail.com',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ));

      await mountAndLoad(tester);
    });

    expect(find.byKey(const Key('provider_group_header')), findsOneWidget);
    expect(find.byKey(const Key('provider_group_end')), findsOneWidget);
    expect(
        find.text('Email provider senders (1) -- process these together first'),
        findsOneWidget);
    // Provider sender renders ABOVE the business sender.
    final gmailY = tester.getTopLeft(find.text('scammer@gmail.com')).dy;
    final bizY = tester.getTopLeft(find.text('seller@bizcorp.example')).dy;
    expect(gmailY, lessThan(bizY),
        reason: 'provider sender must be grouped at the top');
  });

  testWidgets(
      'no provider senders -> no heading and no end indicator',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await testHelper.createTestAccount('gmail-a@example.com');
      registerSavedAccount('gmail-a@example.com');
      await insertCompletedScan('gmail-a@example.com',
          completedAtMs: 1000, noRuleCount: 2); // sender*@spam.example
      await mountAndLoad(tester);
    });

    expect(find.byKey(const Key('provider_group_header')), findsNothing);
    expect(find.byKey(const Key('provider_group_end')), findsNothing);
  });

  testWidgets(
      'F245 Q21: every UNPROCESSED row across scans is listed, an older scan included',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);

      // Older scan: 5 unprocessed items -- still unaddressed, so they ARE listed.
      await insertCompletedScan(accountId, completedAtMs: 1000, noRuleCount: 5);
      // Newer scan: 2 more distinct items. (One row per email, so no duplicates.)
      await insertCompletedScan(accountId, completedAtMs: 2000, noRuleCount: 2);

      await mountAndLoad(tester);
    });

    expect(noRuleChip(7), findsOneWidget);
  });

  // MT-2c (Sprint 51, F129): the sweep runs on EVERY load, so an item whose
  // covering rule already exists must never be DISPLAYED -- not merely
  // removed after the user acts. This is the behavior the WinWright script
  // cannot express (the 18 item rows render as unnamed Groups in the Windows
  // UIA projection, so only the aggregate count chips are addressable), so it
  // is pinned here instead.
  //
  // Modeled on Harold's real 2026-07-28 Live Scan: 18 no-rule items across 16
  // senders, with darngoodyarn@homelivingcares.com appearing THREE times --
  // exactly the multi-item case where a single Entire Domain rule must sweep
  // every one of that sender's rows in one pass.
  testWidgets(
      'MT-2c: a pre-existing covering rule removes ALL of that sender\'s items '
      'on the very first load, leaving uncovered senders untouched',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanId = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);

      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      // THREE items from one sender (the multi-item case) + two uncovered.
      for (final (uid, sender) in [
        ('m-1', 'darngoodyarn@homelivingcares.example'),
        ('m-2', 'darngoodyarn@homelivingcares.example'),
        ('m-3', 'darngoodyarn@homelivingcares.example'),
        ('u-1', 'thegamer@bestbuyingpoint.example'),
        ('u-2', 'sales@falgunarmy.example'),
      ]) {
        await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
          scanResultId: scanId,
          providerIdentifierType: 'imap_uid',
          providerIdentifierValue: uid,
          fromEmail: sender,
          folderName: 'Bulk Mail',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ));
      }

      // The covering rule ALREADY exists before the screen is ever opened --
      // this is the on-load sweep, not the post-action one.
      await ruleProvider.addRule(Rule(
        name: 'Block_EntireDomain_homelivingcares.example',
        enabled: true,
        isLocal: true,
        executionOrder: 20,
        conditions: RuleConditions(
            type: 'OR', header: [r'@(?:[a-z0-9-]+\.)*homelivingcares\.example$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'entire_domain',
        sourceDomain: 'homelivingcares.example',
      ));

      await mountAndLoad(tester);
    });

    // 5 seeded - 3 covered = 2 displayed, on the FIRST load with no user action.
    expect(noRuleChip(2), findsOneWidget,
        reason: 'all three items from the covered sender must be swept before '
            'display; a count of 5 means the on-load sweep did not run');
    expect(find.textContaining('homelivingcares'), findsNothing,
        reason: 'no row from the covered sender may be displayed');
    expect(find.text('thegamer@bestbuyingpoint.example'), findsOneWidget);
    expect(find.text('sales@falgunarmy.example'), findsOneWidget);
  });

  // F129 R-6 (Sprint 51) / F283: each row announces the email it represents
  // and can be activated. The checkbox is gone (MV-Q16); the row is the shared
  // Results ListTile, whose title and subtitle merge into one node.
  //
  // What this does NOT catch: what Windows UIA projects (the WinWright sweep).
  testWidgets(
      'each row exposes an accessible name identifying the email and a tap '
      'action (F129 R-6, F283)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);
      final scanId = await insertCompletedScan(accountId,
          completedAtMs: 1000, noRuleCount: 0);
      final unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
      await unmatchedStore.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'sem-1',
        fromEmail: 'infoinfo@prohomeprotectplus.example',
        subject: 'Reviewing your solar billing?',
        folderName: 'Bulk Mail',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ));
      await mountAndLoad(tester);
    });

    // "A tree dump proves a name exists; only an interaction proves the node
    // still works." -- docs/ACCESSIBILITY_STANDARDS.md §1
    final matches = <SemanticsNode>[];
    void collect(SemanticsNode n) {
      if (n.label.contains('infoinfo@prohomeprotectplus.example') &&
          n.label.contains('Reviewing your solar billing?') &&
          n.getSemanticsData().hasAction(SemanticsAction.tap)) {
        matches.add(n);
      }
      n.visitChildren((c) {
        collect(c);
        return true;
      });
    }

    collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(matches, isNotEmpty,
        reason: 'the row must announce its sender and subject together and '
            'expose a TAP action');

    handle.dispose();
  });

}
