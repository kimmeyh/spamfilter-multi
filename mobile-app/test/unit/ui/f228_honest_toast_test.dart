/// F228 (Sprint 72): the per-action toast must not claim success after the
/// mailbox action failed.
///
/// **Reproduced on demand** (Harold, S24+ 0.15.2, airplane mode ON): each item
/// produced a success-coloured toast -- `...rule to block entire domain
/// "*.<domain>" -- 9 "No rule" remaining` -- while the batch summary for the
/// SAME actions was orange: `Re-processed 0 of 6 (6 failed)`. Three surfaces,
/// two verdicts, seconds apart.
///
/// **Mechanism**: the toast hardcoded its colour and fired AFTER
/// `await _reProcessAffectedEmails()`, so the failure had already happened and
/// the count was already known. The code had the information and did not use
/// it.
///
/// **What must NOT be "fixed"**: the rule IS created offline and that is
/// correct -- rules are local state, and recording the user's intent without a
/// connection is right. `stats.remaining` legitimately drops. Only the CLAIM
/// about the mailbox was wrong.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the OUTCOME
/// TYPE's semantics and the source wiring. They do not render a SnackBar and
/// read its colour -- that needs the full screen with a live platform and
/// database. A widget test that mounted the screen would be the stronger guard
/// and is not available at this level.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

void main() {
  group('F228: the outcome type cannot round a failure up to success', () {
    test('THE BUG: a total failure is not success', () {
      const outcome =
          ReProcessOutcome(attempted: 6, succeeded: 0, failed: 6);

      expect(outcome.allSucceeded, isFalse,
          reason: 'THE ASSERTION THAT WAS MISSING. This is Harold airplane-mode '
              'case exactly: 6 attempted, 6 failed, and the toast was green.');
      expect(outcome.anyFailed, isTrue);
    });

    test('a PARTIAL failure is not success either', () {
      const outcome =
          ReProcessOutcome(attempted: 6, succeeded: 4, failed: 2);

      expect(outcome.allSucceeded, isFalse,
          reason: 'partial success is the commonest real case and the one a '
              'green toast hides most convincingly');
      expect(outcome.anyFailed, isTrue);
    });

    test('a clean run IS success', () {
      const outcome =
          ReProcessOutcome(attempted: 6, succeeded: 6, failed: 0);

      expect(outcome.allSucceeded, isTrue);
      expect(outcome.anyFailed, isFalse);
    });

    test('NOTHING TO DO is not success -- the unhappy input', () {
      // The case a naive `failed == 0` check gets wrong: no work ran, so there
      // is nothing to claim. Reporting "your mailbox was updated" here is the
      // same class of lie this card closes.
      const outcome = ReProcessOutcome.nothingToDo();

      expect(outcome.allSucceeded, isFalse,
          reason: 'attempted == 0 must not read as success');
      expect(outcome.anyFailed, isFalse,
          reason: 'and it is not a failure either -- it is neither');
    });

    test('READ-ONLY is its own state, distinct from failure', () {
      const outcome = ReProcessOutcome.readOnly();

      expect(outcome.skippedReadOnly, isTrue);
      expect(outcome.anyFailed, isFalse,
          reason: 'a deliberately read-only account did not FAIL -- telling the '
              'user it failed would be a different lie');
      expect(outcome.allSucceeded, isFalse);
    });
  });

  group('F228: the production toast consults the outcome', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    });

    test('neither action toast hardcodes a success colour any more', () {
      expect(
          source.contains("content: Text('\${result.displayMessage}\$progressSuffix'),\n"
              '          backgroundColor: Colors.green,'),
          isFalse,
          reason: 'the hardcoded green is the defect');
      expect(
          source.contains("content: Text('\${result.displayMessage}\$progressSuffix'),\n"
              '          backgroundColor: Colors.blue,'),
          isFalse,
          reason: 'the block-rule site had the same defect in blue');
    });

    test('both sites route through the honest helper', () {
      expect(source.contains('_showActionOutcome('), isTrue);
      expect(
          RegExp(r'outcome: reProcessOutcome').allMatches(source).length, 2,
          reason: 'both the safe-sender and block-rule paths must consult it');
    });

    test('the re-process method returns its counts', () {
      expect(source.contains('Future<ReProcessOutcome> _reProcessAffectedEmails()'),
          isTrue,
          reason: 'it returned void before, which is why the caller could not '
              'tell the truth');
    });

    test('the correct batch summary is left alone', () {
      expect(source.contains('failCount == 0 ? Colors.green : Colors.orange'),
          isTrue,
          reason: 'this line already did the right thing and is the model the '
              'fix follows -- do not unify it away');
    });

    test('a failure toast stays up longer than a success (F231)', () {
      expect(source.contains('outcome.anyFailed ? 8 : 5'), isTrue,
          reason: 'Harold measured ~1s of readable time on the old 3s value');
    });
  });
}
