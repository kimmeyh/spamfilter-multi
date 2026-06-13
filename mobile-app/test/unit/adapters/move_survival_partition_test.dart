// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

/// BUG-S40-1 regression: a UID MOVE that the server acknowledges but does not
/// perform (AOL "copy-not-move" on the delete path) must be reported as a
/// FAILURE, not a false success. Before the fix, every message in a batch was
/// marked succeeded merely because uidMove() did not throw, so spam that
/// remained in Bulk Mail was reported deleted and reappeared on every scan
/// (a delete-loop). These tests lock the partition logic that decides
/// succeeded vs failed from the post-move survivor set.
void main() {
  EmailMessage msg(String id) => EmailMessage(
        id: id,
        from: 'spam$id@example.com',
        subject: 'subject $id',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 6, 3),
        folderName: 'Bulk Mail',
      );

  /// Runs the partition and returns (succeeded ids, failed id->reason).
  (List<String>, Map<String, String>) partition(
    List<EmailMessage> messages,
    List<int> survivors,
  ) {
    final succeeded = <String>[];
    final failed = <String, String>{};
    GenericIMAPAdapter.partitionByMoveSurvival(
      messages: messages,
      survivingUids: survivors,
      sourceFolder: 'Bulk Mail',
      targetFolder: 'Trash',
      onSucceeded: succeeded.add,
      onFailed: (id, reason) => failed[id] = reason,
    );
    return (succeeded, failed);
  }

  group('BUG-S40-1 partitionByMoveSurvival', () {
    test('no survivors -> all messages succeed', () {
      final (succeeded, failed) = partition(
        [msg('100'), msg('101'), msg('102')],
        const [],
      );
      expect(succeeded, ['100', '101', '102']);
      expect(failed, isEmpty);
    });

    test('all survived (silent total failure) -> all messages fail', () {
      final (succeeded, failed) = partition(
        [msg('100'), msg('101')],
        [100, 101],
      );
      expect(succeeded, isEmpty);
      expect(failed.keys, containsAll(['100', '101']));
      expect(failed['100'], contains('AOL copy-not-move'));
      expect(failed['100'], contains('Trash'));
      expect(failed['100'], contains('Bulk Mail'));
    });

    test('partial survival -> only survivors fail (the real-world case)', () {
      // Mirrors the 2026-06-03 incident: 271 of a batch stayed behind.
      final (succeeded, failed) = partition(
        [msg('100'), msg('101'), msg('102'), msg('103')],
        [101, 103],
      );
      expect(succeeded, ['100', '102']);
      expect(failed.keys, containsAll(['101', '103']));
      expect(succeeded, isNot(contains('101')));
    });

    test('unparseable UID is treated as success (legacy compatibility)', () {
      final (succeeded, failed) = partition(
        [msg('not-a-uid'), msg('200')],
        [200],
      );
      expect(succeeded, contains('not-a-uid'));
      expect(failed.keys, ['200']);
    });

    test('empty batch -> no callbacks', () {
      final (succeeded, failed) = partition(const [], const []);
      expect(succeeded, isEmpty);
      expect(failed, isEmpty);
    });
  });

  group('BUG-S40-1 chunkUids (bulk UID MOVE chunking)', () {
    test('splits into chunks of at most chunkSize, order preserved', () {
      final chunks = GenericIMAPAdapter.chunkUids([1, 2, 3, 4, 5], 2);
      expect(chunks, [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('exact multiple -> no trailing empty chunk', () {
      final chunks = GenericIMAPAdapter.chunkUids([1, 2, 3, 4], 2);
      expect(chunks, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('chunkSize larger than list -> single chunk', () {
      final chunks = GenericIMAPAdapter.chunkUids([1, 2, 3], 50);
      expect(chunks, [
        [1, 2, 3],
      ]);
    });

    test('empty input -> no chunks', () {
      expect(GenericIMAPAdapter.chunkUids(const [], 50), isEmpty);
    });

    test('no UID dropped or duplicated across chunks (482-message case)', () {
      final uids = List<int>.generate(482, (i) => 143312 + i);
      final chunks = GenericIMAPAdapter.chunkUids(uids, 50);
      expect(chunks.length, 10); // 9 x 50 + 1 x 32
      expect(chunks.last.length, 32);
      final flattened = chunks.expand((c) => c).toList();
      expect(flattened, uids); // order + completeness
      expect(flattened.toSet().length, 482); // no duplicates
    });

    test('non-positive chunkSize -> single chunk (defensive)', () {
      expect(GenericIMAPAdapter.chunkUids([1, 2, 3], 0), [
        [1, 2, 3],
      ]);
    });
  });
}
