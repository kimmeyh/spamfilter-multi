/// Sprint 77 Manual Validation step 2 (Harold, 2026-10-08): after the FIRST
/// scan of a new account, started from the account list, the Results screen
/// read "No Results Yet. Run a scan." although the scan had completed.
///
/// Cause: `_hasEverScanned` is read once, when the screen loads, from the
/// saved scans. A first-ever scan that completes after that read left it
/// false, and with no results to list the screen chose the never-scanned
/// state. Fix: a live scan of THIS account that has completed also counts.
///
/// What these do NOT catch: a completed scan whose results are later cleared
/// by a provider reset (status returns to idle, so the never-scanned state
/// would show again until the screen reloads), and the Scan History path,
/// which reads a saved scan and is unaffected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';

const _account = 'new-user@yahoo.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);
  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async => testHelper.tearDown());

  Future<void> mount(WidgetTester tester, EmailScanProvider provider) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<RuleSetProvider>(create: (_) => RuleSetProvider()),
        ChangeNotifierProvider<EmailScanProvider>.value(value: provider),
      ],
      child: const MaterialApp(
        home: ResultsDisplayScreen(
          platformId: 'imap',
          platformDisplayName: 'Custom IMAP',
          accountId: _account,
          accountEmail: _account,
        ),
      ),
    ));
    await tester.pump();
    // The screen's saved-scan lookup is real database I/O; let it finish so
    // _historicalLoaded is true before anything is asserted.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> completeScanOf(
      WidgetTester tester, EmailScanProvider provider, String account) async {
    provider.setCurrentAccountId(account);
    provider.startScan(totalEmails: 0, persist: false);
    await tester.runAsync(() async {
      await provider.completeScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a never-scanned account shows "No Results Yet" (baseline)',
      (tester) async {
    await mount(tester, EmailScanProvider());
    expect(find.text('No Results Yet'), findsOneWidget);
  });

  testWidgets('a first scan that completes after the screen loaded shows '
      '"Scan Complete", not "No Results Yet"', (tester) async {
    final provider = EmailScanProvider();
    await mount(tester, provider);
    await completeScanOf(tester, provider, _account);
    expect(find.text('No Results Yet'), findsNothing,
        reason: 'the scan completed; the never-scanned state is wrong');
    expect(find.text('Scan Complete'), findsOneWidget);
  });

  testWidgets('a completed scan of ANOTHER account does not count',
      (tester) async {
    final provider = EmailScanProvider();
    await mount(tester, provider);
    await completeScanOf(tester, provider, 'someone-else@aol.com');
    expect(find.text('No Results Yet'), findsOneWidget);
  });
}
