/// Sprint 76 (Fold, 0.17.1, 2026-10-05 7:19-7:26 AM): the Results banner read
/// "0 of 1 'No rule' emails addressed -- 148 remaining" and, after adding
/// rules, "22 of 1". The total (`_initialNoRuleCount`) is captured ONCE, on the
/// first render that has any No Rule email -- and the Results screen renders
/// WHILE a live scan is still streaming results in, so the capture took the
/// count at that moment (1) and kept it. Sprint 38 guarded the saved-scan path
/// (wait for the async load) but not a live scan still running.
///
/// After: no capture while the live scan is still scanning; the banner uses
/// the live count until the scan completes, then captures the full total.
///
/// What this does NOT catch: a saved scan opened from Scan History (covered by
/// `results_display_no_rule_reload_test`), and a live scan the user leaves
/// and re-enters mid-scan (re-entry re-captures by design, Sprint 38 Round 8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;
  const accountId = 'aol-user@aol.com';

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(accountId, platformId: 'aol');
  });

  tearDown(() => testHelper.tearDown());

  EmailActionResult noRule(int i) => EmailActionResult(
        email: EmailMessage(
          id: '$i',
          from: 'sender$i@spam$i.example',
          subject: 'Offer $i',
          body: '',
          headers: const {},
          receivedDate: DateTime(2026, 10, 5),
          folderName: 'Bulk',
        ),
        action: EmailActionType.none,
        success: true,
      );

  testWidgets('a Results screen opened DURING a live scan shows the full No '
      'Rule total once the scan completes -- not the count at first render',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late EmailScanProvider scanProvider;
    await tester.runAsync(() async {
      final ruleProvider = RuleSetProvider()
        ..initializeForTesting(
          databaseStore: RuleDatabaseStore(testHelper.dbHelper),
          safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
        );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();
      scanProvider = EmailScanProvider();
      await scanProvider.startScan(totalEmails: 0, persist: false);
      scanProvider.recordResult(noRule(1)); // the first No Rule email arrives

      await mountAndLoadDbWidget(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
            ChangeNotifierProvider<EmailScanProvider>.value(
                value: scanProvider),
          ],
          child: const MaterialApp(
            home: ResultsDisplayScreen(
              platformId: 'aol',
              platformDisplayName: 'AOL',
              accountId: accountId,
              accountEmail: accountId,
            ),
          ),
        ),
      );

      // The scan goes on: two more No Rule emails, then it completes.
      scanProvider.recordResult(noRule(2));
      scanProvider.recordResult(noRule(3));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await scanProvider.completeScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.textContaining('0 of 3 "No rule" emails addressed -- 3 remaining'),
        findsOneWidget,
        reason: 'the total must be the scan\'s full No Rule count');
    expect(find.textContaining('0 of 1 "No rule"'), findsNothing,
        reason: 'the Fold showed "0 of 1 ... 148 remaining"');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
