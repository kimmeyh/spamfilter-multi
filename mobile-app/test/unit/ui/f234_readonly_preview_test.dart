/// F234 (Sprint 73): read-only as a PREVIEW mode.
///
/// **Harold's idea**, during Sprint 72 manual validation: *"if Manual > Scan
/// mode is readonly then add the rule, but don't delete the email, but add it
/// to 'would have been deleted'."*
///
/// It turns read-only from a refusal into a rehearsal: a broad rule's blast
/// radius can be seen before anything is removed. Most valuable on Windows,
/// which is configured read-only, so it is the platform where a rule's effect
/// was previously invisible.
///
/// **The whole risk of this card is the WORDING.** A preview misread as a
/// completed action is Sprint 72's F228 defect in a new costume -- a message
/// implying a mailbox change that did not happen. So the message says "would
/// have" and states the mailbox was NOT changed, and the rows are deliberately
/// NOT hidden, because hiding them would imply the mail had been dealt with.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the counts,
/// the message content and the structure. They cannot prove a user READS the
/// message as a preview rather than a completed action -- that is Harold's
/// judgement at manual validation, and it is the only thing that settles it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';

void main() {
  group('F234: the outcome carries a preview', () {
    test('THE FEATURE: a read-only run reports what it would have done', () {
      const outcome = ReProcessOutcome.readOnly(
        wouldHaveDeleted: 340,
        wouldHaveMoved: 12,
      );

      expect(outcome.wouldHaveDeleted, 340);
      expect(outcome.wouldHaveMoved, 12);
      expect(outcome.hasPreview, isTrue,
          reason: 'THE ASSERTION THAT WAS MISSING -- before this card the '
              'read-only path discarded these lists entirely');
    });

    test('a preview is NOT a success and NOT a failure', () {
      const outcome = ReProcessOutcome.readOnly(wouldHaveDeleted: 5);

      expect(outcome.allSucceeded, isFalse,
          reason: 'nothing was actioned, so claiming success would be the '
              'F228 lie');
      expect(outcome.anyFailed, isFalse,
          reason: 'a deliberately read-only account did not FAIL either');
      expect(outcome.skippedReadOnly, isTrue);
    });

    test('a read-only run with NOTHING to preview has no preview', () {
      // The unhappy input: read-only, but no rule matched. Showing "0 would
      // have been filed" is noise, so hasPreview must be false.
      const outcome = ReProcessOutcome.readOnly();

      expect(outcome.hasPreview, isFalse);
      expect(outcome.wouldHaveDeleted, 0);
      expect(outcome.wouldHaveMoved, 0);
    });

    test('every other outcome reports a zero preview', () {
      // These describe actions that DID happen. A non-zero preview on them
      // would be describing an action that did not.
      const done = ReProcessOutcome(attempted: 6, succeeded: 6, failed: 0);
      const nothing = ReProcessOutcome.nothingToDo();

      for (final o in [done, nothing]) {
        expect(o.wouldHaveDeleted, 0);
        expect(o.wouldHaveMoved, 0);
        expect(o.hasPreview, isFalse);
      }
    });

    test('BOTH rule kinds are covered -- Harold chose both at approval', () {
      const outcome =
          ReProcessOutcome.readOnly(wouldHaveDeleted: 3, wouldHaveMoved: 4);

      expect(outcome.wouldHaveDeleted, 3);
      expect(outcome.wouldHaveMoved, 4,
          reason: 'safe-sender moves are previewed too; the value of a preview '
              'is seeing the FULL effect');
    });
  });

  group('F234: THE BEHAVIORAL TEST -- the one that was missing', () {
    // Both Phase 5.1 reviews independently proved the shipped feature was
    // INERT while all nine tests below passed: the preview forced
    // `ScanMode.readOnly` into gates that test for rulesOnly / safeSendersOnly
    // / safeSendersAndRules, so both lists stayed empty, the isEmpty guard
    // returned nothingToDo() first, and the preview block was unreachable.
    //
    // Every test in this file was a source-text or value-object assertion, so
    // none could see it. This group drives the real decision instead.

    test('THE DEFECT: a delete under the preview mode IS collected', () {
      expect(
        classifyForReProcess(
          newAction: EmailActionType.delete,
          scanMode: ScanMode.safeSendersAndRules,
        ),
        ReProcessBucket.delete,
        reason: 'THE ASSERTION THAT WAS MISSING -- with ScanMode.readOnly here '
            'this returned none, both lists stayed empty, and the preview '
            'could never report anything but zero',
      );
    });

    test('a safe-sender move under the preview mode IS collected', () {
      expect(
        classifyForReProcess(
          newAction: EmailActionType.safeSender,
          scanMode: ScanMode.safeSendersAndRules,
        ),
        ReProcessBucket.moveSafe,
      );
    });

    test('PROOF OF THE BUG: ScanMode.readOnly collects NOTHING', () {
      // Pins the exact mechanism, so passing readOnly into the collection
      // path again is red immediately rather than silently inert.
      for (final action in [
        EmailActionType.delete,
        EmailActionType.safeSender,
      ]) {
        expect(
          classifyForReProcess(
              newAction: action, scanMode: ScanMode.readOnly),
          ReProcessBucket.none,
          reason: 'readOnly matches none of the execute gates -- this is why '
              'the first version of F234 did nothing at all',
        );
      }
    });

    test('the narrower modes still gate correctly', () {
      // The fix must not turn the gates into a rubber stamp.
      expect(
        classifyForReProcess(
            newAction: EmailActionType.safeSender,
            scanMode: ScanMode.rulesOnly),
        ReProcessBucket.none,
        reason: 'rulesOnly must not move safe senders',
      );
      expect(
        classifyForReProcess(
            newAction: EmailActionType.delete,
            scanMode: ScanMode.safeSendersOnly),
        ReProcessBucket.none,
        reason: 'safeSendersOnly must not delete',
      );
    });

    test('THE WIRING: the preview path passes an ACTING mode, not readOnly',
        () {
      // The abstraction above is correct and was still not enough. Restoring
      // the original defect -- `isReadOnly ? ScanMode.readOnly : effectiveMode`
      // -- left every test in this group GREEN, because they assert the pure
      // function while the bug lives at its CALL SITE. That is the
      // "correct abstraction, wrong wiring" gap, and it is the same shape as
      // the source-text gap it replaced.
      //
      // So this asserts the wiring itself, and it is deliberately the ONE
      // source assertion in this group: the call site is a single expression
      // with no seam to inject, and adding one would be more machinery than
      // the fact is worth.
      final source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
      expect(
        source.contains(
            'isReadOnly ? ScanMode.safeSendersAndRules : effectiveMode'),
        isTrue,
        reason: 'passing ScanMode.readOnly here makes classifyForReProcess '
            'return none for every email, so both lists stay empty and the '
            'preview reports zero forever -- the exact defect two reviews '
            'found in the shipped code',
      );
      expect(
        source.contains('isReadOnly ? ScanMode.readOnly'),
        isFalse,
        reason: 'the defect, stated so its return is red rather than silent',
      );
    });

    test('an action with no bucket is never collected', () {
      // The unhappy input: an evaluation that resolved to no action at all.
      expect(
        classifyForReProcess(
            newAction: EmailActionType.none,
            scanMode: ScanMode.safeSendersAndRules),
        ReProcessBucket.none,
      );
    });
  });

  group('F234: the production wiring', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    });

    test('the read-only check no longer returns before the lists are built',
        () {
      // The card's audit said the data "already exists". Half right: the lists
      // are built LATER IN THE METHOD, and the old early return fired BEFORE
      // the collection loop, so on the read-only path they were never
      // populated. The fix is to let collection run and return after it.
      final flagIdx = source.indexOf('isReadOnly = true;');
      final collectIdx = source.indexOf('final toDelete = <EmailMessage>[];');
      final previewIdx = source.indexOf('if (isReadOnly) {');

      expect(flagIdx, greaterThan(-1));
      expect(flagIdx, lessThan(collectIdx),
          reason: 'the flag is set before collection');
      expect(collectIdx, lessThan(previewIdx),
          reason: 'the preview must be returned AFTER the lists are built, or '
              'it reports zero every time');
    });

    test('THE MUTATION GAP: the return passes the ACTUAL list lengths', () {
      // A first version of this file asserted the outcome TYPE and the source
      // ORDERING, and a mutation that replaced the populated return with
      // `const ReProcessOutcome.readOnly()` -- dropping both counts -- passed
      // every one of them. The tests were describing the shape of the fix
      // rather than its effect, which is the Sprint 70 F220 shape and the
      // reason IMP-1 exists.
      //
      // Driving the real method needs a live platform and database, so this
      // pins the wiring instead: the return must carry the list lengths, not
      // constants.
      expect(source.contains('wouldHaveDeleted: toDelete.length'), isTrue,
          reason: 'a const readOnly() here reports zero forever and the '
              'preview silently does nothing');
      expect(source.contains('wouldHaveMoved: toMoveSafe.length'), isTrue);

      // And the preview return must NOT be const -- a const cannot carry
      // runtime counts, so its presence would prove the counts were dropped.
      final previewIdx = source.indexOf('if (isReadOnly) {');
      final window = source.substring(previewIdx, previewIdx + 500);
      expect(window.contains('const ReProcessOutcome.readOnly()'), isFalse,
          reason: 'this is the exact mutation that slipped through');
    });

    test('the message says "would have" and names the mailbox as unchanged',
        () {
      expect(source.contains('Preview only:'), isTrue);
      expect(source.contains('would have been filed'), isTrue);
      expect(source.contains('would have been moved'), isTrue);
      expect(source.contains('mailbox was NOT changed'), isTrue,
          reason: 'the whole risk of this card is a preview being read as a '
              'completed action');
    });

    test('rows are NOT hidden on the preview path', () {
      // Hiding rows would imply the mail had been dealt with -- the F228
      // defect in a different costume. The preview must leave the screen
      // looking untouched.
      final previewIdx = source.indexOf('if (isReadOnly) {');
      final hideIdx = source.indexOf('_hiddenEmailKeys.add(_getEmailKey(email))');
      expect(previewIdx, lessThan(hideIdx),
          reason: 'the preview returns before any row hiding');
    });

    test('the screen-load path cannot surface a preview', () {
      // AC-4. It passes userInitiated: false, discards the outcome, and never
      // calls _showActionOutcome -- so no preview message can reach the user
      // from a path the user did not trigger.
      expect(source.contains('await _reProcessAffectedEmails(userInitiated: false);'),
          isTrue);
      final loadIdx =
          source.indexOf('await _reProcessAffectedEmails(userInitiated: false);');
      final window = source.substring(loadIdx, loadIdx + 400);
      expect(window.contains('_showActionOutcome'), isFalse,
          reason: 'a preview from screen load would be reporting on something '
              'the user never asked for');
    });
  });
}
