/// F271 (Sprint 81): reason chips and the "Create rule" action on the No Rule
/// Review screen.
///
/// Drives the real screen on the real database (same harness as
/// no_rule_review_screen_test.dart): a stored row with codes shows its chips,
/// a row without codes shows none, and tapping Create rule opens the existing
/// quick-add screen with that sender's domain filled in.
///
/// What these tests do NOT catch (one line each):
///   - chips: how a wrapped second line looks on a real 360 px phone (the
///     narrow-width test only proves no overflow exception, not the visual);
///   - Create rule: saving the rule from the quick-add screen and the row then
///     leaving the list (the save path is the quick-add screen's own, covered
///     by its tests; here the screen is only opened);
///   - semantics: what TalkBack or Narrator actually speaks.
library;

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
import 'package:my_email_spam_filter/ui/screens/rule_quick_add_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = <String, String>{};

  late DatabaseTestHelper testHelper;
  late RuleSetProvider ruleProvider;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() async {
    fakeSecureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return fakeSecureStorage[call.arguments['key'] as String];
        case 'write':
          fakeSecureStorage[call.arguments['key'] as String] =
              call.arguments['value'] as String;
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
    await ruleProvider.loadRules();
    await ruleProvider.loadSafeSenders();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  Future<void> seed(Map<String, String?> sendersToCodes) async {
    const account = 'gmail-a@example.com';
    await testHelper.createTestAccount(account);
    fakeSecureStorage['saved_accounts'] = account;
    final scanId = await testHelper.dbHelper.insertScanResult({
      'account_id': account,
      'scan_type': 'manual',
      'scan_mode': 'readonly',
      'started_at': 1000,
      'completed_at': 2000,
      'total_emails': sendersToCodes.length,
      'processed_count': 0,
      'deleted_count': 0,
      'moved_count': 0,
      'safe_sender_count': 0,
      'no_rule_count': sendersToCodes.length,
      'error_count': 0,
      'status': 'completed',
      'folders_scanned': '["INBOX"]',
    });
    final store = UnmatchedEmailStore(testHelper.dbHelper);
    var i = 0;
    for (final e in sendersToCodes.entries) {
      await store.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: 'uid-${i++}',
        fromEmail: e.key,
        subject: 'Subject ${e.key}',
        folderName: 'INBOX',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        heuristicSignals: e.value,
      ));
    }
  }

  Widget buildTestWidget() => MaterialApp(
        home: ChangeNotifierProvider<RuleSetProvider>.value(
          value: ruleProvider,
          child: const NoRuleReviewScreen(),
        ),
      );

  Future<void> mount(WidgetTester tester) => mountAndLoadDbWidget(
      tester, buildTestWidget(),
      settleDelay: const Duration(milliseconds: 500));

  /// The reason chips only (the screen has other chips: filters, account).
  final reasonChips = find.byWidgetPredicate((w) =>
      w is Chip &&
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('heuristic_chip_'));

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('a row with codes shows one chip per code, a row without shows '
      'none', (tester) async {
    bigScreen(tester);
    final handle = tester.ensureSemantics();
    await tester.runAsync(() async {
      await seed({
        'flagged@spam.example': 'auth_failed,reply_to_differs',
        'plain@quiet.example': null,
      });
      await mount(tester);
    });

    expect(find.text('Sign-in check failed'), findsOneWidget);
    expect(find.text('Reply-To differs'), findsOneWidget);
    // Only the flagged row has chips: two chips for two codes, none else.
    expect(reasonChips, findsNWidgets(2));
    expect(find.text('Lookalike domain'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Reason: Sign-in check failed')),
        findsWidgets);
    handle.dispose();
  });

  testWidgets('chips wrap on a narrow screen without overflowing',
      (tester) async {
    // 400 px: the app bar itself overflows by 24 px at 360 px in the test font
    // (an existing condition, not part of this change), which would mask a
    // real overflow in the row.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await seed({
        'flagged@spam.example': 'auth_failed,reply_to_differs,'
            'lookalike_domain,blocked_tld,bulk_no_unsubscribe',
      });
      await mount(tester);
    });

    expect(reasonChips, findsNWidgets(5));
    expect(tester.takeException(), isNull);
    // Wrapped: the five chips do not all sit on one line.
    final tops = {
      for (final e in reasonChips.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy
    };
    expect(tops.length, greaterThan(1), reason: 'chips flow onto a second line');
  });

  testWidgets('Create rule opens the quick-add screen with the sender domain '
      'filled in', (tester) async {
    bigScreen(tester);
    await tester.runAsync(() async {
      await seed({'flagged@spam.example': 'reply_to_differs'});
      await mount(tester);
    });

    expect(find.byType(RuleQuickAddScreen), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('create_rule_button')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    });

    expect(find.byType(RuleQuickAddScreen), findsOneWidget);
    final fieldTexts = [
      for (final e in find.byType(EditableText).evaluate())
        (e.widget as EditableText).controller.text
    ];
    // The screen builds its fields lazily; the rule-name field is on screen
    // and is derived from the sender domain (the From pattern field below it
    // is derived from the same normalized address).
    expect(fieldTexts, contains('AutoDeleteSpamExample'),
        reason: 'the quick-add form is prefilled from the sender domain');
  });
}
