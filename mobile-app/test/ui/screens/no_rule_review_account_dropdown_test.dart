/// F169 (Sprint 61): the Review No Rule Items account filter is a single-select
/// DROPDOWN, replacing the horizontally scrolling chip Row.
///
/// The defect (Harold, 2026-08-16, Android emulator, two accounts configured):
/// the chips sat in a `SingleChildScrollView(Axis.horizontal)` with NO scroll
/// affordance, so at phone width the second chip clipped at the window edge and
/// a third account was off-screen entirely -- unreachable, with nothing on
/// screen suggesting it existed. "All account must be viewable."
///
/// What these tests pin, in the order that matters:
///   AC-1  every configured account is REACHABLE at phone width (the failure);
///   AC-2  switching accounts CLEARS the selection (the behavior the old chip
///         handler had, which a rewrite could silently drop);
///   AC-3  the default face reads All Accounts with the total count.
///
/// Harness mirrors no_rule_review_touch_selection_test.dart: real sqflite_ffi
/// DB, the secure-storage channel stub (the screen enumerates accounts from
/// `saved_accounts`, NOT from the DB), and mounting inside `tester.runAsync`
/// because FFI calls never resolve in the fake-async widget-test zone.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';
import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;
  late RuleSetProvider ruleProvider;

  // THREE accounts: the reported failure needed only two to clip, but three
  // makes "the last one is off-screen" unambiguous at phone width.
  const accounts = ['aol-first@aol.com', 'gmail-second@gmail.com', 'aol-third@aol.com'];

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();

    ruleProvider = RuleSetProvider();
    ruleProvider.initializeForTesting(
      databaseStore: RuleDatabaseStore(testHelper.dbHelper),
      safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
    );
    await ruleProvider.loadRules();
    await ruleProvider.loadSafeSenders();

    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final joined = accounts.join(',');
      if (call.method == 'read') {
        final key = (call.arguments as Map)['key'];
        return key == 'saved_accounts' ? joined : null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': joined};
      }
      return null;
    });

    // One unaddressed row per account, so each account's count is 1 and the
    // All Accounts total is 3 -- distinguishable in the assertions.
    final store = UnmatchedEmailStore(testHelper.dbHelper);
    for (final (i, accountId) in accounts.indexed) {
      await testHelper.createTestAccount(accountId);
      final scanId = await testHelper.dbHelper.insertScanResult({
        'account_id': accountId,
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': 1000,
        'completed_at': 2000,
        'total_emails': 1,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 1,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });
      await store.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-$i',
        fromEmail: 'sender-$i@example.com',
        subject: 'Subject $i',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ));
    }
  });

  tearDown(() async {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await testHelper.tearDown();
  });

  /// Mounts at PHONE width -- the size at which the old chip row failed.
  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(411, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
        tester,
        MaterialApp(
          home: ChangeNotifierProvider<RuleSetProvider>.value(
            value: ruleProvider,
            child: const NoRuleReviewScreen(),
          ),
        ),
        settleDelay: const Duration(milliseconds: 500),
      );
    });
    await tester.pump();
  }

  testWidgets(
      'AC-1: every configured account is reachable from the dropdown at phone '
      'width (the chip row put the third account off-screen)', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Filter by account'));
    await tester.pumpAndSettle();

    // Each account's menu entry must EXIST and be hit-testable -- the precise
    // property the clipped chip row lacked.
    for (final accountId in accounts) {
      final email = accountId.substring(accountId.indexOf('-') + 1);
      final entry = find.textContaining(email);
      expect(entry, findsWidgets,
          reason: 'account $email must appear in the dropdown at phone width; '
              'the old scrolling chip row rendered it off-screen with no '
              'affordance that it existed');
    }
  });

  testWidgets(
      'AC-2: switching accounts CLEARS the active selection', (tester) async {
    await pumpScreen(tester);

    // Select a row (plain tap selects on this triage-only screen).
    await tester.tap(find.textContaining('sender-0@example.com').first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget,
        reason: 'precondition: a selection is active');

    // Switch to a specific account.
    await tester.tap(find.byTooltip('Filter by account'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('second@gmail.com').last);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing,
        reason: 'the selection must be cleared on account change -- carrying a '
            'hidden selection across accounts is exactly what _clearSelection() '
            'in the old chip handler prevented, and a rewrite could silently '
            'drop it');
  });

  testWidgets('AC-3: the default face reads All Accounts with the total count',
      (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('All Accounts (3)'), findsOneWidget,
        reason: 'default selection is All Accounts, showing the total across '
            'all three seeded accounts');
  });
}
