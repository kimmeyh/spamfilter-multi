/// F224 / PR #435 Claude review I-3 and I-4: the cancel path must not tell the
/// user something untrue.
///
/// Two defects, both shipped, both user-visible, and both the same shape as
/// Sprint 72's F228 -- a message describing something the code does not do:
///
/// - **I-4**: `cancelScan()` sets `ScanStatus.error`, and the scan screen's
///   header mapped `error` to "Scan failed". So the user tapped **Cancel Scan**
///   and the app told them their own deliberate action had FAILED -- directly
///   contradicting `cancelScan`'s own doc comment, which states that not saying
///   this is the whole point of the method existing separately from
///   `errorScan`. The database row was always correct (`interrupted`); only the
///   live header was wrong.
/// - **I-3**: both cancel controls said *"It will finish the emails it already
///   fetched, then stop."* It does not. `throwIfCancelled()` throws inside
///   `batchSink`, which unwinds past the Step 6a evaluation AND the Step 6b
///   batch execution, so **no fetched email is ever acted on**. The counts
///   already recorded are kept, which is what AC-4 asks for, but the sentence
///   described a drain-and-finish that does not exist.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they assert the flag
/// transitions and the strings. They cannot prove a user READS "Scan cancelled"
/// as distinct from "Scan failed", nor that the new sentence sets the right
/// expectation mid-scan. That is Harold's judgement at manual validation.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';

void main() {
  group('I-4: a deliberate cancel is not a failure', () {
    test('THE DEFECT: cancelScan marks the run as cancelled', () async {
      final p = EmailScanProvider();
      expect(p.wasCancelled, isFalse, reason: 'nothing cancelled yet');

      await p.cancelScan();

      expect(p.wasCancelled, isTrue,
          reason: 'without this the header says "Scan failed" after the user '
              'taps Cancel Scan, which is the F228 class of lie');
      expect(p.status, ScanStatus.error,
          reason: 'the terminal STATUS stays error deliberately -- adding a '
              'cancelled value to a PERSISTED enum would be a Class-1 change');
    });

    test('a real failure does NOT read as cancelled', () async {
      final p = EmailScanProvider();
      await p.errorScan('the mail server stopped responding');

      expect(p.wasCancelled, isFalse);
    });

    test('THE STALE-FLAG GUARD: a failure after a cancel is not cancelled',
        () async {
      // The unhappy sequence, and the reason errorScan clears rather than
      // ignores the flag: cancel one scan, then have the next genuinely fail.
      // A sticky flag would label a real mail-server failure as the user's own
      // doing, which hides a fault worth reporting.
      final p = EmailScanProvider();
      await p.cancelScan();
      expect(p.wasCancelled, isTrue);

      await p.errorScan('connection reset');

      expect(p.wasCancelled, isFalse,
          reason: 'a genuine failure must never inherit a previous cancel');
    });

    test('reset clears it', () async {
      final p = EmailScanProvider();
      await p.cancelScan();
      p.reset();

      expect(p.wasCancelled, isFalse);
      expect(p.status, ScanStatus.idle);
    });

    test('the header reads the flag rather than the status alone', () {
      final source =
          File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync();
      expect(source.contains("wasCancelled ? 'Scan cancelled' : 'Scan failed'"),
          isTrue,
          reason: 'mapping ScanStatus.error straight to "Scan failed" is the '
              'defect -- the flag is what distinguishes the two');
    });
  });

  group('I-3: the stopping message describes what actually happens', () {
    late String scanScreen;
    late String resultsScreen;

    /// Comment content blanked, so the assertions read CODE and not prose.
    ///
    /// Needed here specifically: the fix's own comment QUOTES the old wording
    /// to explain why it was wrong, so a raw substring check finds the phrase
    /// it is asserting the absence of. Same blind spot the F209 wiring gate
    /// shipped with -- a comment naming a thing is not a use of it.
    String blankComments(String source) => source
        .split('\n')
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');

    setUpAll(() {
      scanScreen = blankComments(
          File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync());
      resultsScreen = blankComments(
          File('lib/ui/screens/results_display_screen.dart')
              .readAsStringSync());
    });

    test('THE DEFECT: it no longer promises to finish the fetched emails', () {
      for (final (name, source) in [
        ('scan screen', scanScreen),
        ('results screen', resultsScreen),
      ]) {
        expect(source.contains('finish the emails it already'), isFalse,
            reason: '$name: the scan unwinds past BOTH evaluation and batch '
                'execution, so nothing fetched is ever acted on');
        expect(source.contains('further will be filed or moved'), isTrue,
            reason: '$name: must state what really happens');
      }
    });

    test('BOTH controls say the same thing -- mirror sites stay in sync', () {
      // The two cancel controls are a twin pair. F-PRECHECK class 1: a fix
      // applied to one and not the other is the commonest way this drifts.
      const kept = 'Emails already checked are kept';
      expect(scanScreen.contains(kept), isTrue);
      expect(resultsScreen.contains(kept), isTrue);
    });
  });
}
