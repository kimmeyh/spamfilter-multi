/// F306 (Sprint 82): Review No Rule Items passes the STORED suggestion into the
/// shared pop-up (the call-site wiring: correct abstraction, wrong wiring is a
/// known defect class here).
///
/// Harness copied from no_rule_review_screen_test.dart (secure-storage channel
/// stub, runAsync for every FFI call). That file is not edited.
///
/// What these tests do NOT catch (one line each):
///   - the Results screen call site (it computes the suggestion itself; covered
///     by f306_results_suggestion_test.dart);
///   - a scan writing the columns (covered by f306_suggestion_storage_test.dart
///     through a real EmailScanProvider scan).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';
import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

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

  const account = 'gmail-a@example.com';

  Future<void> seed({required bool withSuggestion}) async {
    await testHelper.createTestAccount(account);
    fakeSecureStorage['saved_accounts'] = account;
    final scanId = await testHelper.dbHelper.insertScanResult({
      'account_id': account,
      'scan_type': 'manual',
      'scan_mode': 'readonly',
      'started_at': 1,
      'completed_at': 1000,
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
    const from = 'offers@mail.shop-example.com';
    await UnmatchedEmailStore(testHelper.dbHelper)
        .addUnmatchedEmail(UnmatchedEmail(
      scanResultId: scanId,
      providerIdentifierType: 'imap_uid',
      providerIdentifierValue: 'uid-1',
      fromEmail: from,
      subject: 'Big sale today',
      folderName: 'INBOX',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      authClassification: 'yellow',
      suggestion: withSuggestion
          ? RuleSuggestion.suggest(
              fromEmail: from, authClassification: 'yellow')
          : null,
    ));
  }

  Future<void> mount(WidgetTester tester) => mountAndLoadDbWidget(
      tester,
      MaterialApp(
        home: ChangeNotifierProvider<RuleSetProvider>.value(
          value: ruleProvider,
          child: const NoRuleReviewScreen(),
        ),
      ),
      settleDelay: const Duration(milliseconds: 500));

  Future<void> openPopup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.text('offers@mail.shop-example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create Block Rule'), findsOneWidget);
  }

  testWidgets('a stored suggestion reaches the pop-up (AC-1)', (tester) async {
    await tester.runAsync(() async {
      await seed(withSuggestion: true);
      await mount(tester);
    });
    await openPopup(tester);
    final s = RuleSuggestion.suggest(
        fromEmail: 'offers@mail.shop-example.com',
        authClassification: 'yellow')!;
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text(s.pattern), findsOneWidget);
    expect(find.text(s.reasonText), findsOneWidget);
  });

  testWidgets('a row with no stored suggestion shows none', (tester) async {
    await tester.runAsync(() async {
      await seed(withSuggestion: false);
      await mount(tester);
    });
    await openPopup(tester);
    expect(find.text('Suggested'), findsNothing);
  });
}
