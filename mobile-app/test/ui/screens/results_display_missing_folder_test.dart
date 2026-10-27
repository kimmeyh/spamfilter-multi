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
/// the diagnostic log); a saved scan opened from Scan History, which carries
/// no missing-folder list and deliberately shows nothing; and Results opened
/// for a DIFFERENT account while the provider still holds another account's
/// scan (an existing limit of the live/historical choice, not checked here).
/// The F203 "already filed" chip shares the gate and the same limits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
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

  // 7.7.1 improvement review HIGH-1: the M-2 case itself. A scan of only a
  // missing label COMPLETES with zero messages, so the screen falls back to the
  // account's last saved scan -- and the first cut hid the line there.
  testWidgets('the line shows after a scan COMPLETES with zero messages while '
      'an earlier completed scan is saved', (tester) async {
    final provider = EmailScanProvider();
    await tester.runAsync(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // scan_results has a foreign key to accounts.
      await testHelper.createTestAccount(_account);
      await ScanResultStore(testHelper.dbHelper).addScanResult(ScanResult(
        accountId: _account,
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: now - 60000,
        completedAt: now - 30000,
        totalEmails: 3,
        status: 'completed',
      ));
      provider.startScan(totalEmails: 0, persist: false);
      provider.recordFolderMissing('Recipts');
      await provider.completeScan();
      await mount(tester, provider);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(provider.results, isEmpty);
    expect(provider.status, ScanStatus.completed);
    expect(find.text('Folder not found: Recipts'), findsOneWidget);
  });

  // Same defect for the F203 "already filed" chip: when every message was
  // already filed, the live list is empty and the screen falls back to the
  // last saved scan, which hid the chip.
  testWidgets('the "already filed" chip shows after a scan COMPLETES with '
      'every message already filed while an earlier scan is saved',
      (tester) async {
    final provider = EmailScanProvider();
    await tester.runAsync(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await testHelper.createTestAccount(_account);
      await ScanResultStore(testHelper.dbHelper).addScanResult(ScanResult(
        accountId: _account,
        scanType: 'manual',
        scanMode: 'readonly',
        startedAt: now - 60000,
        completedAt: now - 30000,
        totalEmails: 3,
        status: 'completed',
      ));
      provider.startScan(totalEmails: 2, persist: false);
      provider.recordSkippedAlreadyFiled();
      provider.recordSkippedAlreadyFiled();
      await provider.completeScan();
      await mount(tester, provider);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(provider.results, isEmpty);
    expect(find.text('2 already filed'), findsOneWidget);
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
