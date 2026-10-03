/// F232 (Sprint 74, Manual Validation on the Fold8): every block rule and
/// safe sender added from a SAVED scan failed with "N of N could not be
/// applied". The diagnostic log named the cause: `Exception: Platform  not
/// supported` -- an EMPTY platform. Scan History derived the platform by
/// splitting the accountId on its first dash, so an account whose id is a
/// bare email (the current form) opened Scan Results with platformId ''.
///
/// These tests drive the REAL path a user has: tap a scan card in Scan
/// History, then read the platform the opened Results screen was given.
///
/// What these tests do NOT catch: a Results screen that is handed the right
/// platform but then loses it before re-processing. They also do not cover
/// the four display-only dash splits (email labels in Scan History, No Rule
/// Review and the Settings account picker), which never feed a platform.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

const _accountId = 'user@aol.com'; // bare email: the form that broke
const _secureChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;

  /// [storedPlatform] is what the credential store holds for the account
  /// (null = nothing stored, so resolution must fall back to the accounts
  /// table).
  void mockSecureStorage(String? storedPlatform) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
      final key = (call.arguments as Map?)?['key'];
      if (call.method == 'read') {
        if (key == 'saved_accounts') return _accountId;
        if (key == 'credentials_${_accountId}_platformId') {
          return storedPlatform;
        }
        return null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': _accountId};
      }
      return null;
    });
  }

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
    await testHelper.tearDown();
  });

  /// Seed, mount Scan History, tap the one scan card. Returns nothing; the
  /// caller inspects the widget tree.
  Future<void> openSavedScan(
    WidgetTester tester, {
    required String accountsTablePlatform,
    required String? credentialPlatform,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockSecureStorage(credentialPlatform);

    await tester.runAsync(() async {
      await testHelper.createTestAccount(_accountId,
          platformId: accountsTablePlatform);
      await testHelper.createTestScanResult(_accountId, totalEmails: 3);

      final ruleProvider = RuleSetProvider()
        ..initializeForTesting(
          databaseStore: RuleDatabaseStore(testHelper.dbHelper),
          safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
        );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();

      await mountAndLoadDbWidget(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
            ChangeNotifierProvider<EmailScanProvider>.value(
                value: EmailScanProvider()),
          ],
          child: const MaterialApp(home: ScanHistoryScreen()),
        ),
      );

      final card = find.descendant(
          of: find.byType(Card), matching: find.byType(InkWell));
      expect(card, findsOneWidget, reason: 'one saved scan was seeded');
      await tester.tap(card);
      // The tap handler reads secure storage and the DB on the real loop.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  testWidgets(
      'a bare-email account opens Scan Results with the platform stored in '
      'the credential store', (tester) async {
    await openSavedScan(tester,
        accountsTablePlatform: 'aol', credentialPlatform: 'aol');

    final results = find.byType(ResultsDisplayScreen);
    expect(results, findsOneWidget);
    expect(tester.widget<ResultsDisplayScreen>(results).platformId, 'aol',
        reason: 'the dash split gave "" here, and every rule add then '
            'failed with "Platform  not supported"');
    // Sprint 74 MV (Harold): the address appears ONCE -- in the
    // "Results - <email>" title, not again above "Summary".
    expect(find.textContaining(_accountId), findsOneWidget);
  });

  testWidgets(
      'with nothing in the credential store, the accounts table supplies '
      'the platform', (tester) async {
    await openSavedScan(tester,
        accountsTablePlatform: 'gmail', credentialPlatform: null);

    final results = find.byType(ResultsDisplayScreen);
    expect(results, findsOneWidget);
    expect(tester.widget<ResultsDisplayScreen>(results).platformId, 'gmail');
  });

  testWidgets(
      'when no platform can be found, the screen does NOT open and the user '
      'is told which account', (tester) async {
    await openSavedScan(tester,
        accountsTablePlatform: '', credentialPlatform: null);

    expect(find.byType(ResultsDisplayScreen), findsNothing,
        reason: 'opening it would make every action fail with an empty '
            'platform, which is the defect');
    expect(
        find.textContaining(
            'Could not determine the email provider for $_accountId'),
        findsOneWidget);
  });
}
