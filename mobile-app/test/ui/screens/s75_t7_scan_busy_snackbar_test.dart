/// Sprint 75 Task 7 (R-2), PR #440 test-review MINOR-7: the refusal SnackBar
/// `startRealScan` shows (`scan_progress_screen.dart` ~line 1234) when the
/// scan lock (`EmailScanProvider.startScan`'s `claimAccountScan`) refuses a
/// manual scan AFTER the "another scan is already running" pre-check dialog
/// already passed -- the narrow race the dialog cannot see (a scan claimed by
/// another process/isolate in the gap between the pre-check query and the
/// real claim). `f238_scan_busy_dialog_test.dart` already covers the dialog
/// itself; this test does NOT duplicate it -- it covers the fallback catch
/// block the dialog cannot reach.
///
/// **How the race is produced deterministically, without a timing guess.**
/// `EmailScanner.scanInbox` serializes every scan attempt through the
/// in-process `ScanCoordinator` lease BEFORE it ever calls the real DB claim
/// (`email_scanner.dart` ~line 149-195). This test's `setUp`/`tearDown` holds
/// that lease itself (acquired for a different "owner" -- a `background`
/// scan on the same account), so `startRealScan`'s pre-check
/// (`getActiveScanForAccount`, DB-only, never touches the coordinator) finds
/// no row and skips the dialog, while the real scan is PARKED waiting on the
/// coordinator. Only then does the test insert the blocking `scan_results`
/// row and release its lease -- so the parked scan is handed the lease and
/// hits the real claim with the row already there. No sleep/race is needed:
/// the ordering is enforced by the coordinator's FIFO queue, not by timing.
///
/// What this does NOT catch: the TRUE cross-process race in production (a
/// background scan's own insert landing in that exact DB-query gap) --
/// Windows Manual Validation with a background scan actually running is the
/// only thing that exercises that. Nor does it cover the dialog path, which
/// is f238's job.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

import '../../helpers/database_test_helper.dart';

const _accountId = 'aol-user@aol.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;

  setUp(() async {
    ScanCoordinator.resetForTest();
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(_accountId, platformId: 'aol');
  });

  tearDown(() async {
    ScanCoordinator.resetForTest();
    await testHelper.tearDown();
  });

  testWidgets(
      'a manual scan refused by the lock AFTER the pre-check dialog passed '
      'shows the refusal SnackBar, not a generic error', (tester) async {
    final scanProvider = EmailScanProvider();
    final ruleProvider = RuleSetProvider();
    late BuildContext ctx;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Everything below runs in ONE real-event-loop window so the sequence is
    // enforced by explicit awaits, not by hoping enough fake pumps happened:
    // hold the lease, FIRE (not await) startRealScan so it parks on the
    // coordinator, THEN insert the blocking row and release the lease, THEN
    // await startRealScan's own completion.
    late Future<void> scanFuture;
    await tester.runAsync(() async {
      // Hold the in-process lease ourselves, as a stand-in for a background
      // scan running in another isolate/process -- invisible to the
      // pre-check the same way a cross-process scan is.
      final heldByTest = await ScanCoordinator.instance
          .acquire(scanType: 'background', accountId: _accountId);

      // The pre-check finds no DB row (nothing inserted yet) so no dialog;
      // startRealScan proceeds through its settings reads and parks inside
      // scanInbox's ScanCoordinator.acquire, queued behind the held lease.
      scanFuture = startRealScan(
        context: ctx,
        scanProvider: scanProvider,
        ruleProvider: ruleProvider,
        platformId: 'aol',
        platformDisplayName: 'AOL',
        accountId: _accountId,
        accountEmail: _accountId,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Now place the blocking row -- what the parked scan's claim will find
      // the instant it is handed the lease -- and hand off the lease.
      await testHelper.createTestScanResult(_accountId,
          scanType: 'background', status: 'in_progress');
      ScanCoordinator.instance.release(heldByTest);

      // Wait for startRealScan itself to finish (claim -> refused -> caught
      // -> SnackBar shown -> function returns).
      await scanFuture;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final message = find.textContaining(
        'A background scan is already running on this account');
    expect(message, findsOneWidget,
        reason: 'the claim-level refusal must reach the user with the same '
            'wording as the pre-check dialog, not "Something went wrong"');

    // ScaffoldMessenger can hold more than one SnackBar widget CONFIG in the
    // tree while one transitions out and another in; identify every one
    // that carries the refusal text rather than assuming there is exactly
    // one SnackBar element at this instant.
    final snackBars = tester.widgetList<SnackBar>(find.byType(SnackBar)).where(
        (s) =>
            s.content is Text &&
            ((s.content as Text).data ?? '').contains(
                'A background scan is already running on this account'));
    expect(snackBars, isNotEmpty,
        reason: 'at least one SnackBar must carry the refusal text');
    expect(snackBars.every((s) => s.backgroundColor == Colors.blueGrey), isTrue,
        reason: 'a refusal is neutral, never the red failure color');

    expect(ScanCoordinator.instance.active, isNull,
        reason: 'the refused scan must release the lease it was handed, not '
            'leave the coordinator wedged for the next scan');

    await tester.pump(const Duration(seconds: 6)); // drain the SnackBar timer
  });
}
