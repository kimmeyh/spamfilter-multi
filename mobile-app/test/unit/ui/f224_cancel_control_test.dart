/// F224 (Sprint 73): the Cancel control, on BOTH screens that can run a scan.
///
/// **Why two surfaces and not one.** The card asked for the control "where the
/// user actually is". That is not only the scan screen: "Scan Again" on the
/// results screen calls `startRealScan(useReplacement: true)`, so the scan runs
/// with the user still on the RESULTS screen and the scan screen's control is
/// never shown. It is also the way testers actually restart scans -- the same
/// navigation quirk F220 (Sprint 70) had to account for. A control on the scan
/// screen alone would miss the commonest route to a long scan.
///
/// **What these do NOT catch** (CLAUDE.md IMP-1): they assert the controls
/// exist, are gated on the scanning state, and call the coordinator rather than
/// tearing anything down themselves. They cannot prove the button is reachable
/// on a real phone screen without scrolling, nor that the wording reads as
/// "stopping" rather than "stopped" to a user mid-scan. Both are Harold's
/// judgement at manual validation.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String scanScreen;
  late String resultsScreen;

  setUpAll(() {
    scanScreen =
        File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync();
    resultsScreen =
        File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
  });

  group('F224: the scan progress screen', () {
    test('THE CONTROL: a Cancel Scan button exists', () {
      expect(scanScreen.contains("label: const Text('Cancel Scan')"), isTrue);
      expect(scanScreen.contains('_cancelScan(context, scanProvider)'), isTrue);
    });

    test('it is shown ONLY while a scan is running', () {
      // A cancel offered when nothing runs invites a tap that does nothing,
      // which teaches the user the button is unreliable.
      final guard =
          scanScreen.indexOf('if (scanProvider.status == ScanStatus.scanning) '
              '...[');
      final button = scanScreen.indexOf("label: const Text('Cancel Scan')");
      expect(guard, greaterThan(-1));
      expect(guard, lessThan(button));
    });
  });

  group('F224: the results screen (the "Scan Again" path)', () {
    test('THE GAP THIS CLOSES: a cancel is reachable while Scan Again runs',
        () {
      expect(resultsScreen.contains("label: const Text('Cancel Scan')"), isTrue,
          reason: 'startRealScan(useReplacement: true) runs the scan with the '
              'user still on THIS screen, so the scan screen control is never '
              'shown on this path');
      expect(resultsScreen.contains('_cancelRunningScan('), isTrue);
    });

    test('the button swaps rather than stacking a dead one', () {
      // While scanning, "Scan Again" is disabled anyway. Two buttons would put
      // a permanently-dead widget in the row.
      final cond =
          resultsScreen.indexOf('scanProvider.status == ScanStatus.scanning\n'
              '                              ? ElevatedButton.icon(');
      expect(cond, greaterThan(-1),
          reason: 'one conditional button, not two side by side');
    });
  });

  group('F224: neither control tears anything down', () {
    test('THE LEAK GUARD: both call requestCancel and nothing else', () {
      // The design rests on the scan releasing its OWN lease in its `finally`.
      // A control that called release/releaseActiveByOwner would free the lease
      // while the scan still held its socket -- the Sprint 61 session leak.
      for (final (name, source) in [
        ('scan screen', scanScreen),
        ('results screen', resultsScreen),
      ]) {
        expect(source.contains('ScanCoordinator.instance.requestCancel('),
            isTrue,
            reason: '$name must ask, not act');
      }

      // The scan screen legitimately force-releases on TIMEOUT (F221), which
      // is a different path; the results screen has no such case, so any
      // force-release there would be the leak.
      expect(resultsScreen.contains('releaseActiveByOwner'), isFalse,
          reason: 'a cancel must never free the lease from outside the scan');
    });

    test('both tell the user the stop is PENDING, not done', () {
      // "Stopped" would be the F228 class of lie -- the scan keeps running
      // until its next batch boundary.
      for (final source in [scanScreen, resultsScreen]) {
        expect(source.contains('Stopping the scan.'), isTrue);
        expect(source.contains('That scan has already finished.'), isTrue,
            reason: 'the race where the scan ends between draw and tap must '
                'not look like an ignored tap');
      }
    });
  });
}
