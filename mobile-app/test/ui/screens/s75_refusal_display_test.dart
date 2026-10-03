/// Sprint 75 (Harold Q3 at Manual Validation, 2026-10-03): a scan REFUSED
/// because another scan holds the account must say so on both screens.
///
/// Before: (1) the Results screen's "another scan is running" row was built
/// only when `hasLiveResults` -- and a refusal clears the results BEFORE its
/// claim is refused, so the row never appeared on the one path that produces
/// it (found by the Task 7 widget-test agent); (2) the Manual Scan header read
/// "Scan failed" for a refusal, because it checked `wasCancelled` only.
/// After: the row appears for a live refusal; the header reads "Scan not
/// started".
///
/// The provider is put in the REAL refusal state: `startScan` (which clears
/// results), then `markScanRefused` -- the two calls `EmailScanProvider`
/// makes when `claimAccountScan` refuses.
///
/// What these do NOT catch: a refusal reached through a real cross-process
/// claim (covered by mv74_2_scan_heartbeat_test and Manual Validation), and
/// the Results row while VIEWING HISTORY, which deliberately stays hidden.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

import '../../helpers/database_test_helper.dart';

const _account = 'aol-user@aol.com';
const _refusal = 'A background scan of aol-user@aol.com is running.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);
  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async => testHelper.tearDown());

  /// The state a refused claim leaves: results cleared, then refused.
  EmailScanProvider refusedProvider() {
    final p = EmailScanProvider();
    p.startScan(totalEmails: 0, persist: false);
    p.markScanRefused(_refusal);
    return p;
  }

  Future<void> mountWith(WidgetTester tester, EmailScanProvider provider,
      Widget home) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<RuleSetProvider>(create: (_) => RuleSetProvider()),
        ChangeNotifierProvider<EmailScanProvider>.value(value: provider),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Results: a refused scan with NO results shows the refusal row '
      '(info style)', (tester) async {
    final provider = refusedProvider();
    expect(provider.results, isEmpty, reason: 'precondition: the real state');
    await mountWith(
        tester,
        provider,
        const ResultsDisplayScreen(
          platformId: 'aol',
          platformDisplayName: 'AOL',
          accountId: _account,
          accountEmail: _account,
        ));
    expect(find.textContaining(_refusal), findsOneWidget,
        reason: 'the row was unreachable when results were empty');
    expect(find.byIcon(Icons.info_outline), findsWidgets);
  });

  testWidgets('Manual Scan header: refused reads "Scan not started"; a real '
      'failure still reads "Scan failed"', (tester) async {
    // The screen resets the provider after its first frame (a fresh "Ready
    // to Scan"), so refuse AFTER mounting -- which is also when a real
    // refusal happens.
    final provider = EmailScanProvider();
    await mountWith(
        tester,
        provider,
        const ScanProgressScreen(
          platformId: 'aol',
          platformDisplayName: 'AOL',
          accountId: _account,
          accountEmail: _account,
        ));
    provider.startScan(totalEmails: 0, persist: false);
    provider.markScanRefused(_refusal);
    await tester.pump();
    expect(find.text('Scan not started'), findsOneWidget);
    expect(find.text('Scan failed'), findsNothing);

    await tester.runAsync(() => provider.errorScan('the server closed'));
    await tester.pump();
    expect(find.text('Scan failed'), findsOneWidget,
        reason: 'only a refusal changes the header; failures stay failures');
  });
}
