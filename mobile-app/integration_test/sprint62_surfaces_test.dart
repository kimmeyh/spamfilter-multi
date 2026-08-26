// F184 (Sprint 63) -- in-VM E2E coverage for the three Sprint 62 UI surfaces
// that shipped with NO E2E asset (recorded coverage gap, SPRINT_62_PLAN.md
// Phase 5 evidence section):
//
//   1. F175 -- the "Background scan in progress" wait-and-start dialog on
//      Manual Scan entry (DB-backed detection; dialog shown/Cancel/Wait plus
//      the stale-row negative).
//   2. F178 -- the email-detail popup at compact width with a simulated
//      system bottom inset: bottom-anchored inside the safe area, "Block
//      Subject" reachable at full scroll (the exact Sprint 62 defect shape).
//   3. F176 -- the AccountEmailLabel on the results summary.
//
// LANE CHOICE (recorded in the F184 card): WinWright is deliberately NOT
// extended for these -- a replayed script cannot arrange an active background
// scan, and the popup needs compact-width simulation. The shared in-VM lane
// is platform-neutral (ADR-0042: parity of coverage from ONE suite).
//
// Run: flutter test integration_test/sprint62_surfaces_test.dart
//   (or .\scripts\run-integration-tests.ps1 -TestName sprint62)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

import 'helpers/app_harness.dart';

Future<void> _seedAccount(String accountId, String platformId) async {
  final db = await DatabaseHelper().database;
  await db.insert('accounts', {
    'account_id': accountId,
    'platform_id': platformId,
    'email': accountId,
    'date_added': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<int> _seedScan(
  String accountId, {
  required String scanType,
  required String status,
  required DateTime startedAt,
}) async {
  final db = await DatabaseHelper().database;
  return db.insert('scan_results', {
    'account_id': accountId,
    'scan_type': scanType,
    'scan_mode': 'readOnly',
    'started_at': startedAt.millisecondsSinceEpoch,
    'total_emails': 5,
    'processed_count': 5,
    'deleted_count': 0,
    'moved_count': 0,
    'safe_sender_count': 0,
    'no_rule_count': 5,
    'error_count': 0,
    'status': status,
    'folders_scanned': '["INBOX"]',
  });
}

/// Minimal host screen whose button invokes the REAL [startRealScan] --
/// exactly the production entry point the Manual Scan screen uses.
class _ScanLauncher extends StatelessWidget {
  const _ScanLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => startRealScan(
              context: context,
              scanProvider: context.read<EmailScanProvider>(),
              ruleProvider: context.read<RuleSetProvider>(),
              platformId: 'demo',
              platformDisplayName: 'Demo',
              accountId: 'demo-it@example.com',
              accountEmail: 'demo-it@example.com',
            ),
            child: const Text('Start Scan'),
          ),
        ),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 62 surfaces (F184 in-VM E2E)', () {
    HarnessSession? session;

    setUp(ScanCoordinator.resetForTest);

    tearDown(() async {
      await session?.dispose();
    });

    Widget wrapLauncher(
        RuleSetProvider ruleProvider, EmailScanProvider scanProvider) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: const MaterialApp(home: _ScanLauncher()),
      );
    }

    testWidgets(
        'F175: a FRESH in_progress background scan raises the wait dialog; '
        'Cancel starts nothing', (tester) async {
      session = await bootDbOnly(tester);
      await tester.runAsync(() async {
        await _seedAccount('bg-holder@example.com', 'aol');
        await _seedScan('bg-holder@example.com',
            scanType: 'background',
            status: 'in_progress',
            startedAt: DateTime.now().subtract(const Duration(minutes: 2)));
      });

      final ruleProvider = RuleSetProvider();
      final scanProvider = EmailScanProvider();
      await tester.pumpWidget(wrapLauncher(ruleProvider, scanProvider));
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Background scan in progress'), findsOneWidget,
          reason: 'the DB-backed detection must surface the dialog');
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Wait and start'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(scanProvider.processedCount, 0,
          reason: 'Cancel must return without starting any scan');
    });

    testWidgets(
        'F175: Wait-and-start proceeds -- the scan actually runs after the '
        'dialog', (tester) async {
      session = await bootDbOnly(tester);
      await tester.runAsync(() async {
        await _seedAccount('bg-holder@example.com', 'aol');
        await _seedScan('bg-holder@example.com',
            scanType: 'background',
            status: 'in_progress',
            startedAt: DateTime.now().subtract(const Duration(minutes: 2)));
      });

      final ruleProvider = RuleSetProvider();
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      await tester.pumpWidget(wrapLauncher(ruleProvider, scanProvider));

      await tester.runAsync(() async {
        await tester.tap(find.text('Start Scan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Wait and start'));
        // Let the demo scan run to completion inside runAsync.
        for (var i = 0; i < 100 && !scanProvider.isComplete; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });

      expect(scanProvider.processedCount, greaterThan(0),
          reason: 'Wait-and-start must proceed into a real (demo) scan');
    });

    testWidgets(
        'F175 negative: a STALE in_progress row (older than scanTimeout) '
        'must NOT raise the dialog', (tester) async {
      session = await bootDbOnly(tester);
      await tester.runAsync(() async {
        await _seedAccount('bg-holder@example.com', 'aol');
        await _seedScan('bg-holder@example.com',
            scanType: 'background',
            status: 'in_progress',
            startedAt: DateTime.now()
                .subtract(ScanCoordinator.scanTimeout + const Duration(minutes: 5)));
      });

      final ruleProvider = RuleSetProvider();
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      await tester.pumpWidget(wrapLauncher(ruleProvider, scanProvider));

      await tester.runAsync(() async {
        await tester.tap(find.text('Start Scan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Background scan in progress'), findsNothing,
            reason: 'a zombie row past the timeout is not an active scan');
        for (var i = 0; i < 100 && !scanProvider.isComplete; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      expect(scanProvider.processedCount, greaterThan(0),
          reason: 'the scan proceeds directly with no dialog');
    });

    testWidgets(
        'F178 + F176: at compact width with a bottom inset, the popup is '
        'bottom-anchored in the safe area with Block Subject reachable; the '
        'summary carries the account email label', (tester) async {
      session = await bootDbOnly(tester);
      const accountId = 'aol-user@aol.com';
      late int scanId;
      await tester.runAsync(() async {
        await _seedAccount(accountId, 'aol');
        scanId = await _seedScan(accountId,
            scanType: 'manual',
            status: 'completed',
            startedAt: DateTime.now().subtract(const Duration(minutes: 10)));
        final db = await DatabaseHelper().database;
        await db.insert('email_actions', {
          'scan_result_id': scanId,
          'email_id': 'it-3001',
          'email_from': 'bad@spam.example',
          'email_subject': 'Win a prize',
          'email_received_date': DateTime.now().millisecondsSinceEpoch,
          'email_folder': 'INBOX',
          'action_type': 'none',
          'is_safe_sender': 0,
          'success': 1,
        });
      });

      const bottomInset = 48.0;
      tester.view.physicalSize = const Size(500, 731);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = FakeViewPadding(bottom: bottomInset);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      final ruleProvider = RuleSetProvider();
      final scanProvider = EmailScanProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
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
      ));
      // Let the DB-backed history load settle.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();

      // F176: the summary card carries the account email in the body.
      expect(find.text(accountId), findsWidgets,
          reason: 'AccountEmailLabel must render the account email');

      // F178: open the popup from the seeded row.
      await tester.tap(find.text('bad@spam.example'));
      await tester.pumpAndSettle();
      final popupFinder =
          find.byWidgetPredicate((w) => w is Material && w.elevation == 8);
      expect(popupFinder, findsOneWidget);
      final popupRect = tester.getRect(popupFinder);
      const safeBottom = 731.0 - bottomInset;
      expect(popupRect.bottom, lessThanOrEqualTo(safeBottom));
      expect(popupRect.bottom, closeTo(safeBottom, 1.0),
          reason: 'compact widths bottom-anchor the popup to the safe area');

      final scrollable = find.descendant(
          of: popupFinder, matching: find.byType(SingleChildScrollView));
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final blockSubject = find.text('Block Subject');
      expect(blockSubject, findsOneWidget);
      expect(tester.getRect(blockSubject).bottom, lessThanOrEqualTo(safeBottom),
          reason: 'Block Subject must be fully inside the safe area at full '
              'scroll -- the exact Sprint 62 defect');
    });
  });
}
