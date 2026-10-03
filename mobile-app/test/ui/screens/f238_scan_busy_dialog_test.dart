/// F238 (Sprint 75), T-3 (AC-4): the "A scan is already running" dialog
/// offers "Stop the background scan and start mine" ONLY when the holder is a
/// background scan. A manual scan or a rule update (`reprocess`) holding the
/// account keeps the OK-only dialog (R-6). Also the waiting dialog that shows
/// "Stopping the background scan..." and closes itself with the wait's answer.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): that `startRealScan`
/// actually CALLS these two functions in the right order (request, wait, then
/// the normal start) -- that is a database-backed top-level function and is
/// pinned by the source-text checks at the bottom plus Windows Manual
/// Validation with a background scan really running. Nor can they prove the
/// action is reachable without scrolling on a phone-width dialog.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

ScanResult holder(String scanType) => ScanResult(
      id: 7,
      accountId: 'aol-user@example.com',
      scanType: scanType,
      scanMode: 'readOnly',
      startedAt: DateTime.now()
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch,
      totalEmails: 0,
    );

/// Pumps a host whose button opens the dialog and records the choice.
Future<ScanBusyChoice?> openBusyDialog(
    WidgetTester tester, String scanType) async {
  ScanBusyChoice? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showScanAlreadyRunningDialog(
              context: context,
              holder: holder(scanType),
              accountEmail: 'user@example.com',
              estimate: '',
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  final stopAction = find.text(stopBackgroundScanActionLabel);

  group('T-3 -- which actions the busy dialog offers', () {
    testWidgets('a BACKGROUND holder: OK and the stop action', (tester) async {
      await openBusyDialog(tester, 'background');
      expect(find.text('A scan is already running'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(stopAction, findsOneWidget);
      expect(find.textContaining('background scan'), findsWidgets);
    });

    testWidgets('a MANUAL holder: OK only', (tester) async {
      await openBusyDialog(tester, 'manual');
      expect(find.text('OK'), findsOneWidget);
      expect(stopAction, findsNothing,
          reason: "R-6: the user's own manual scan is never stopped from here");
      expect(find.textContaining('manual scan of'), findsOneWidget);
    });

    testWidgets('a REPROCESS (rule update) holder: OK only', (tester) async {
      await openBusyDialog(tester, 'reprocess');
      expect(find.text('OK'), findsOneWidget);
      expect(stopAction, findsNothing,
          reason: 'R-6: a rule update holding the account is not stoppable');
      expect(find.textContaining('rule update of'), findsOneWidget);
    });

    testWidgets('a DEMO holder: OK only', (tester) async {
      await openBusyDialog(tester, 'demo');
      expect(stopAction, findsNothing);
    });

    testWidgets('tapping the stop action returns stopBackgroundAndStart',
        (tester) async {
      ScanBusyChoice? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showScanAlreadyRunningDialog(
                  context: context,
                  holder: holder('background'),
                  accountEmail: 'user@example.com',
                  estimate: 'There is no scan history yet to estimate its '
                      'completion time.',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(stopAction);
      await tester.pumpAndSettle();
      expect(result, ScanBusyChoice.stopBackgroundAndStart);
      expect(find.text('A scan is already running'), findsNothing);
    });

    testWidgets('tapping OK returns ok', (tester) async {
      ScanBusyChoice? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showScanAlreadyRunningDialog(
                  context: context,
                  holder: holder('background'),
                  accountEmail: 'user@example.com',
                  estimate: '',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, ScanBusyChoice.ok);
    });

    testWidgets('the stop action is named in the semantics tree '
        '(WinWright-addressable)', (tester) async {
      final handle = tester.ensureSemantics();
      await openBusyDialog(tester, 'background');
      expect(find.bySemanticsLabel(stopBackgroundScanActionLabel),
          findsOneWidget);
      handle.dispose();
    });
  });

  group('the waiting dialog', () {
    Future<Future<bool>> openWaiting(
        WidgetTester tester, Completer<bool> wait) async {
      final done = Completer<bool>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                done.complete(await showStoppingBackgroundScanDialog(
                  context: context,
                  wait: () => wait.future,
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      return done.future;
    }

    testWidgets('shows "Stopping the background scan..." and returns true '
        'when the holder closes', (tester) async {
      final wait = Completer<bool>();
      final result = await openWaiting(tester, wait);
      expect(find.text('Stopping the background scan...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      wait.complete(true);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text('Stopping the background scan...'), findsNothing);
    });

    testWidgets('returns false when the bound expires', (tester) async {
      final wait = Completer<bool>();
      final result = await openWaiting(tester, wait);
      wait.complete(false);
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('a wait that throws reads as not stopped', (tester) async {
      final wait = Completer<bool>();
      final result = await openWaiting(tester, wait);
      wait.completeError(StateError('database closed'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('the user cannot dismiss it (back does nothing)',
        (tester) async {
      final wait = Completer<bool>();
      final result = await openWaiting(tester, wait);
      await tester.binding.handlePopRoute();
      // Not pumpAndSettle: the spinner animates for as long as the dialog is
      // up, which is exactly the state being asserted.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Stopping the background scan...'), findsOneWidget,
          reason: 'a dismissed wait would start the scan on a guess');
      wait.complete(true);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });
  });

  // Source-text wiring gate: the dialogs above are proven; this pins that
  // startRealScan uses them in the order the card requires -- offer, request
  // on the holder row, wait, then fall into the normal start. (What it does
  // not catch: the ORDER being right while the branch is never taken --
  // Windows Manual Validation with a real background scan.)
  group('wiring in startRealScan', () {
    late String src;
    setUpAll(() {
      src = File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync();
    });

    test('offer -> requestCancel on the holder row -> bounded wait -> start',
        () {
      final start = src.indexOf('Future<void> startRealScan(');
      final offer = src.indexOf('await showScanAlreadyRunningDialog(', start);
      final request =
          src.indexOf('scanResultStore.requestCancel(activeScan.id!)', offer);
      final wait = src.indexOf('await showStoppingBackgroundScanDialog(', request);
      final bounded =
          src.indexOf('waitForScanToClose(activeScan.id!)', wait);
      final normalStart =
          src.indexOf('scanProvider.startScan(totalEmails: 0, persist: false)', bounded);
      expect(start, greaterThan(-1));
      expect(offer, greaterThan(start));
      expect(request, greaterThan(offer));
      expect(wait, greaterThan(request));
      expect(bounded, greaterThan(wait));
      expect(normalStart, greaterThan(bounded),
          reason: 'the manual scan starts through the NORMAL path -- the '
              'claim decides, not the wait');
    });

    test('a timed-out wait starts nothing', () {
      final timedOut = src.indexOf("'The background scan did not stop'");
      expect(timedOut, greaterThan(-1));
      // The `return;` must come BEFORE the next statement of the success
      // branch -- a later, unrelated `return;` further down the function must
      // not satisfy this (mutation M8 survived the looser form).
      final successLog = src.indexOf(
          "logger.i('[SCAN_SCREEN] F238: background scan stopped", timedOut);
      final returnAfter = src.indexOf('return;', timedOut);
      expect(successLog, greaterThan(timedOut));
      expect(returnAfter, greaterThan(timedOut));
      expect(returnAfter, lessThan(successLog),
          reason: 'the timed-out branch must return before the success path');
    });
  });
}
