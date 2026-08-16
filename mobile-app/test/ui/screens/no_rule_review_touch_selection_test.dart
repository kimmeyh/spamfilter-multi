/// F143 (Sprint 60): touch-adapted selection for the Review No Rule Items
/// screen -- the app's default screen, previously usable for multi-select only
/// via Ctrl/Shift/right-click (no touch equivalent, the F141 finding).
///
/// Model under test:
///   - long-press a row -> row joins the selection (entering selection mode);
///   - ON TOUCH PLATFORMS, while a selection is active, a plain tap TOGGLES
///     the tapped row (touch's Ctrl+click);
///   - ON DESKTOP, plain-tap semantics are UNCHANGED (replace-single) -- the
///     strict F143 R-2 do-not-regress requirement, asserted here explicitly.
///
/// Platform is driven per-tree via `ThemeData(platform: ...)` -- the screen
/// deliberately reads `Theme.of(context).platform` (not dart:io Platform) to
/// give tests this seam without the global override (which trips the
/// foundation-vars test invariant in this Flutter version).
///
/// Uses the real sqflite_ffi database (DatabaseTestHelper) with seeded
/// unmatched rows, and the sibling tests' secure-storage channel stub.
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

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();

    // The screen's load path runs the covered-item sweep, which needs a
    // LOADED RuleSetProvider (same harness as no_rule_review_screen_test).
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
      // _loadItems enumerates accounts from secure storage's
      // 'saved_accounts' key (comma-separated), NOT from the DB -- without
      // this the screen renders its empty state no matter what is seeded.
      if (call.method == 'read') {
        final key = (call.arguments as Map)['key'];
        return key == 'saved_accounts' ? 'acct-1' : null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': 'acct-1'};
      }
      return null;
    });

    // Two unaddressed rows from one account's latest completed scan (same
    // seeding shape as no_rule_review_screen_test.dart).
    await testHelper.createTestAccount('acct-1');
    final scanId = await testHelper.dbHelper.insertScanResult({
      'account_id': 'acct-1',
      'scan_type': 'manual',
      'scan_mode': 'readonly',
      'started_at': 1000,
      'completed_at': 2000,
      'total_emails': 2,
      'processed_count': 0,
      'deleted_count': 0,
      'moved_count': 0,
      'safe_sender_count': 0,
      'no_rule_count': 2,
      'error_count': 0,
      'status': 'completed',
      'folders_scanned': '["INBOX"]',
    });
    final store = UnmatchedEmailStore(testHelper.dbHelper);
    for (final (i, from) in ['sender-a@example.com', 'sender-b@example.com']
        .indexed) {
      await store.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-$i',
        fromEmail: from,
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

  /// Mounts inside tester.runAsync -- sqflite_ffi's real FFI calls never
  /// resolve in the default fake-async widget-test zone (the documented
  /// hazard in no_rule_review_screen_test.dart's header), so a plain
  /// pumpWidget leaves the screen on its loading spinner forever.
  Future<void> pumpScreen(WidgetTester tester,
      {required TargetPlatform platform}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
        tester,
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: ChangeNotifierProvider<RuleSetProvider>.value(
            value: ruleProvider,
            child: const NoRuleReviewScreen(),
          ),
        ),
        settleDelay: const Duration(milliseconds: 500),
      );
    });
  }

  Finder rowA() => find.text('sender-a@example.com');
  Finder rowB() => find.text('sender-b@example.com');

  testWidgets(
      'AC-1: long-press enters selection mode with that row selected '
      '(Android)', (tester) async {
    await pumpScreen(tester, platform: TargetPlatform.android);

    expect(find.text('Clear'), findsNothing,
        reason: 'no selection bar before any selection');

    await tester.longPress(rowA());
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget,
        reason: 'long-press must select the pressed row');
    expect(find.text('Clear'), findsOneWidget,
        reason: 'the contextual bar (Clear/Apply Rule) appears with the '
            'selection');
  });

  testWidgets(
      'AC-2: in selection mode a plain tap toggles rows, and Clear exits '
      '(Android)', (tester) async {
    await pumpScreen(tester, platform: TargetPlatform.android);

    await tester.longPress(rowA());
    await tester.pump();
    await tester.tap(rowB());
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget,
        reason: 'tap while a selection is active must ADD (toggle on), not '
            'replace -- the touch Ctrl+click');

    await tester.tap(rowB());
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget,
        reason: 'tapping a selected row must toggle it OFF');

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Clear'), findsNothing,
        reason: 'Clear exits selection mode');
  });

  testWidgets(
      'AC-3 (R-2 guard): desktop plain-tap keeps replace-single semantics '
      '(Windows)', (tester) async {
    await pumpScreen(tester, platform: TargetPlatform.windows);

    await tester.tap(rowA());
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(rowB());
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget,
        reason: 'DESKTOP REGRESSION GUARD: a plain click with a selection '
            'active must REPLACE the selection (single), never toggle-add -- '
            'the F143 touch branch must not leak to desktop');
  });
}
