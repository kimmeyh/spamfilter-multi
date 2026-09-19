/// F212 / Copilot review of PR #418 (HIGH): a failed email that LATER SUCCEEDS
/// must stop being counted as failed.
///
/// **The bug this pins, and it was mine.** Fixing H-2 (the earlier review's
/// finding that failed keys were re-added to `_reProcessedEmailKeys`) I added a
/// skip guard reading `_reProcessFailedKeys` -- but nothing ever REMOVED a key
/// from that set. `_recordBatchFailures` returned early when nothing failed, so
/// a successful retry cleared nothing. Consequences, both user-visible:
///
///   - the progress footer reported "N could not be applied" forever, and
///     `isComplete` could never become true, even after every action succeeded;
///   - the email was never added to `_reProcessedEmailKeys`, so
///     `_reProcessAffectedEmails` re-attempted the same IMAP action on every
///     future rule or safe-sender add.
///
/// One fix created the next defect, which is worth recording: H-2 was about a
/// set being written too eagerly, and the correction made it written too
/// permanently. Neither the earlier automated review nor my own mutation
/// testing caught it -- Copilot did, on the PR.
///
/// These tests model the failed/succeeded bookkeeping directly. The production
/// logic lives inside a long private method on a StatefulWidget that needs a
/// live IMAP platform to drive, so the SET SEMANTICS are pinned here and the
/// wiring is verified by the source assertions at the bottom.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_recordBatchFailures` after the Copilot fix: keys that failed are
/// added, and keys that succeeded THIS TIME are cleared.
void recordBatch({
  required Set<String> failedKeys,
  required Set<String> processedKeys,
  required List<String> attempted,
  required Set<String> failedThisBatch,
}) {
  final succeeded =
      attempted.where((k) => !failedThisBatch.contains(k)).toSet();
  failedKeys.removeAll(succeeded);
  for (final key in attempted) {
    if (!failedThisBatch.contains(key)) continue;
    failedKeys.add(key);
    processedKeys.remove(key);
  }
  // The marking loop, scoped to THIS batch rather than the cumulative set.
  for (final key in attempted) {
    if (failedThisBatch.contains(key)) continue;
    processedKeys.add(key);
  }
}

void main() {
  group('F212: a retry that succeeds clears the earlier failure', () {
    test('THE BUG: fail then succeed leaves nothing marked failed', () {
      final failed = <String>{};
      final processed = <String>{};

      // Attempt 1 -- the mail server is unreachable, everything fails.
      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a', 'b'],
        failedThisBatch: {'a', 'b'},
      );
      expect(failed, {'a', 'b'});
      expect(processed, isEmpty);

      // Attempt 2 -- connection restored, both succeed.
      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a', 'b'],
        failedThisBatch: <String>{},
      );

      expect(failed, isEmpty,
          reason: 'THE ASSERTION THAT WAS MISSING. Before the fix nothing ever '
              'removed a key, so the footer reported "could not be applied" '
              'permanently and isComplete could never become true.');
      expect(processed, {'a', 'b'},
          reason: 'a succeeded email must be marked processed, or it is '
              're-attempted on every future rule add');
    });

    test('a PARTIAL recovery clears only what actually succeeded', () {
      final failed = <String>{};
      final processed = <String>{};

      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a', 'b', 'c'],
        failedThisBatch: {'a', 'b', 'c'},
      );
      expect(failed, {'a', 'b', 'c'});

      // Only 'b' succeeds on retry.
      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a', 'b', 'c'],
        failedThisBatch: {'a', 'c'},
      );

      expect(failed, {'a', 'c'},
          reason: 'still-failing emails keep their failed state');
      expect(processed, {'b'},
          reason: 'only the recovered email is marked processed');
    });

    test('the guard uses THIS batch, not the cumulative set', () {
      // The second half of the Copilot finding. If the marking loop tested the
      // cumulative set, 'a' would be skipped forever on the strength of an old
      // failure even when the current batch succeeded.
      final failed = <String>{'a'};
      final processed = <String>{};

      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a'],
        failedThisBatch: <String>{},
      );

      expect(processed, contains('a'),
          reason: 'a cumulative-set guard would skip this key permanently');
      expect(failed, isEmpty);
    });

    test('an all-success first attempt marks everything processed', () {
      // The unhappy input for the early-return that caused the bug: the old
      // code returned before doing anything when failedIds was empty.
      final failed = <String>{};
      final processed = <String>{};

      recordBatch(
        failedKeys: failed,
        processedKeys: processed,
        attempted: ['a', 'b'],
        failedThisBatch: <String>{},
      );

      expect(failed, isEmpty);
      expect(processed, {'a', 'b'});
    });
  });

  group('F212: the production code is wired the same way', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    });

    test('_recordBatchFailures clears keys that succeeded', () {
      expect(source.contains('_reProcessFailedKeys.removeAll('), isTrue,
          reason: 'without a removeAll a failed key is permanent -- this is '
              'the exact line whose absence Copilot found');
    });

    test('the marking loops test the per-batch set, not the cumulative one',
        () {
      expect(source.contains('deleteFailedIds.contains('), isTrue);
      expect(source.contains('moveFailedIds.contains('), isTrue);
      expect(source.contains('if (_reProcessFailedKeys.contains(key)) continue;'),
          isFalse,
          reason: 'the cumulative-set guard is what made an old failure '
              'suppress a later success');
    });
  });
}
