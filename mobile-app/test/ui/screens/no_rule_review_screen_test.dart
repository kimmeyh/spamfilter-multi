import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

    expect(find.text('5 items'), findsOneWidget);
    expect(find.text('All Accounts (5)'), findsOneWidget);
  });

  testWidgets('account filter chip narrows the list to one account',
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

    await tester.tap(find.text('a@example.com (2)'));
    await tester.pump();

    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets('checkbox tap selects an item and shows the bulk action menu',
      (tester) async {
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

    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Apply Rule'), findsOneWidget);
  });

  // MT-2 (Sprint 50, Harold manual testing): a bulk block action must
  // (a) treat an already-existing covering rule as success (item resolves,
  // no 'failed to add block rule'), and (b) auto-resolve UNSELECTED items
  // the new rule covers -- Live Scan parity.
  testWidgets(
      'bulk Block Entire Domain resolves selected items AND auto-resolves '
      'unselected items the rule covers (MT-2)', (tester) async {
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

    expect(find.text('3 items'), findsOneWidget);

    // Select ONLY the first dupdomain item.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    // Run the bulk action (menu tap handlers hit the DB -> runAsync).
    await tester.runAsync(() async {
      await tester.tap(find.text('Apply Rule'));
      // Pump the popup-menu open ANIMATION frames before tapping the item --
      // an un-pumped menu is still at its origin and the tap misses.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add Block Rule - Entire Domain'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    // Selected item resolved AND the unselected same-domain item
    // auto-resolved; only the other-domain item remains.
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('other@keepme.example'), findsOneWidget);
    expect(find.text('first@dupdomain.example'), findsNothing);
    expect(find.text('second@dupdomain.example'), findsNothing);
  });

  // MT-2b (Sprint 50, Harold's 6-item repro 2026-07-26): a NEWER scan can
  // complete while the screen is open, re-populating the SAME senders as
  // fresh unprocessed rows. The bulk action then creates the rules and marks
  // the OLD scan's rows -- but the reload shows the newer scan's identical
  // rows, so the list looked completely unchanged. The auto-resolve sweep
  // must therefore run AFTER the reload, over the fresh pool.
  testWidgets(
      'bulk block resolves rows re-populated by a scan that completed while '
      'the screen was open (MT-2b race)', (tester) async {
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

    expect(find.text('1 item'), findsOneWidget);

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

    // Select the (stale, scan-A) victim item and apply Block Entire Domain.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Apply Rule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add Block Rule - Entire Domain'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    // The reload lands on scan B; its covered victim row must have been
    // auto-resolved by the post-reload sweep -- only the uncovered sender
    // remains, and the count chip reflects it.
    expect(find.text('1 item'), findsOneWidget,
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
      'only the latest completed scan per account is included, not an older one',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      const accountId = 'gmail-a@example.com';
      await testHelper.createTestAccount(accountId);
      registerSavedAccount(accountId);

      // Older scan: 5 unprocessed items -- must NOT appear.
      await insertCompletedScan(accountId, completedAtMs: 1000, noRuleCount: 5);
      // Newer scan: 2 unprocessed items -- must be the only ones shown.
      await insertCompletedScan(accountId, completedAtMs: 2000, noRuleCount: 2);

      await mountAndLoad(tester);
    });

    expect(find.text('2 items'), findsOneWidget);
  });
}
