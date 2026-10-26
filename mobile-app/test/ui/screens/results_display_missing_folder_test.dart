/// 7.7.1 silent-failure M-2 (Sprint 81, Harold Q2 = 1): a folder or Gmail
/// label the scan skipped because it does not exist is SHOWN on the Results
/// screen as "Folder not found: <name>" -- information, not an error.
///
/// Before: the F202 skip reached only the opt-in diagnostic log, so a scan of
/// a mistyped Gmail label completed with 0 messages and nothing on screen said
/// why (the F259 card promised "visible").
///
/// The provider state comes from `recordFolderMissing`, the call the scanner's
/// F202 branch makes (proven end to end by email_scanner_chunked_outcome_test).
///
/// What these do NOT catch: a background scan's skip (no screen; it stays in
/// the diagnostic log), and a saved scan opened from Scan History, which
/// carries no missing-folder list and deliberately shows nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';

const _account = 'gmail-user@gmail.com';

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
          platformId: 'gmail',
          platformDisplayName: 'Gmail',
          accountId: _account,
          accountEmail: _account,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a missing folder shows "Folder not found: <name>" and is not '
      'counted as an error', (tester) async {
    final provider = EmailScanProvider()..startScan(totalEmails: 0, persist: false);
    provider.recordFolderMissing('Archive');
    provider.recordFolderMissing('Archive'); // one line per folder, not per try
    await mount(tester, provider);

    expect(find.text('Folder not found: Archive'), findsOneWidget);
    expect(provider.errorCount, 0,
        reason: 'F202 R-6: a missing folder is not an error');
  });

  testWidgets('a new scan clears the line', (tester) async {
    final provider = EmailScanProvider()..startScan(totalEmails: 0, persist: false);
    provider.recordFolderMissing('Archive');
    await mount(tester, provider);
    expect(find.text('Folder not found: Archive'), findsOneWidget);

    provider.startScan(totalEmails: 0, persist: false);
    await tester.pump();
    expect(find.text('Folder not found: Archive'), findsNothing);
  });
}
