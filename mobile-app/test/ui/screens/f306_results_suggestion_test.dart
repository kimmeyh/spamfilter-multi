/// F306 (Sprint 82): the Results screen computes the suggestion for a No Rule
/// result with the same pure function the scan uses, and gives none to a
/// result that a rule matched.
///
/// Harness: the historical-scan pattern of results_display_popup_width_test.dart
/// (rows come from email_actions, whose auth_classification column carries the
/// scan-time class).
///
/// What these tests do NOT catch (one line each):
///   - a LIVE scan result (headers instead of the stored class): the live path
///     reads the same classifier the scan wrote, but no test feeds raw
///     Authentication-Results headers through this screen;
///   - the Review screen call site (f306_review_screen_suggestion_test.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  const accountId = 'aol-user@aol.com';
  late DatabaseTestHelper testHelper;
  late int scanId;

  Map<String, Object?> row(String id, String from,
          {required String auth, String action = 'none', String? rule}) =>
      {
        'scan_result_id': scanId,
        'email_id': id,
        'email_from': from,
        'email_subject': 'Subject $id',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': action,
        'matched_rule_name': rule,
        'matched_pattern': null,
        'is_safe_sender': 0,
        'success': 1,
        'auth_classification': auth,
      };

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(accountId, platformId: 'aol');
    scanId = await testHelper.createTestScanResult(accountId,
        scanType: 'manual', scanMode: 'readonly', totalEmails: 3);
    await testHelper.dbHelper.insertEmailActionBatch([
      row('1', 'yellow@shop-example.com', auth: 'yellow'),
      row('2', 'green@calm-example.com', auth: 'green'),
      row('3', 'ruled@matched-example.com',
          auth: 'yellow', action: 'delete', rule: 'SpamBlock'),
    ]);
  });

  tearDown(() async => testHelper.tearDown());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final ruleProvider = RuleSetProvider();
      ruleProvider.initializeForTesting(
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
          child: MaterialApp(
            home: ResultsDisplayScreen(
              platformId: 'aol',
              platformDisplayName: 'AOL',
              accountId: accountId,
              accountEmail: accountId,
              historicalScanId: scanId,
            ),
          ),
        ),
      );
    });
  }

  testWidgets('a YELLOW No Rule result gets the suggestion', (tester) async {
    await mount(tester);
    await tester.tap(find.text('yellow@shop-example.com'));
    await tester.pumpAndSettle();
    expect(find.text('Create Block Rule'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.byKey(const ValueKey('suggestion-pattern')), findsOneWidget);
  });

  group('suggestionForResult (every branch)', () {
    EmailActionResult res(EmailActionType action,
            {String? auth, Map<String, String> headers = const {}}) =>
        EmailActionResult(
          email: EmailMessage(
            id: '1',
            from: 'a@mail.shop-example.com',
            subject: 's',
            body: '',
            headers: headers,
            receivedDate: DateTime(2026, 10, 30),
            folderName: 'INBOX',
            authClassificationOverride: auth,
          ),
          action: action,
          success: true,
        );

    test('No Rule + stored YELLOW suggests', () {
      expect(
          suggestionForResult(res(EmailActionType.none, auth: 'yellow'),
              EvaluationResult.noMatch()),
          isNotNull);
    });

    test('a result a rule matched gets none, even when YELLOW', () {
      final matched = EvaluationResult(
          shouldDelete: true,
          shouldMove: false,
          matchedRule: 'SpamBlock',
          matchedPattern: 'x');
      expect(
          suggestionForResult(
              res(EmailActionType.none, auth: 'yellow'), matched),
          isNull);
    });

    test('a non-none action gets none', () {
      expect(
          suggestionForResult(res(EmailActionType.delete, auth: 'yellow'),
              EvaluationResult.noMatch()),
          isNull);
    });

    test('live headers (no stored class) are classified: softfail is YELLOW',
        () {
      final r = res(EmailActionType.none, headers: const {
        'authentication-results': 'mx; spf=softfail; dkim=none; dmarc=none',
      });
      expect(suggestionForResult(r, EvaluationResult.noMatch()), isNotNull);
    });
  });

  testWidgets('a GREEN No Rule result gets none', (tester) async {
    await mount(tester);
    await tester.tap(find.text('green@calm-example.com'));
    await tester.pumpAndSettle();
    expect(find.text('Create Block Rule'), findsOneWidget);
    expect(find.text('Suggested'), findsNothing);
  });
}
