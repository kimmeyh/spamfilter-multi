/// F177 (Sprint 62): the memory-bounded, chunked IMAP fetch -- the fix for
/// the Sprint 61 LOW_MEMORY kill cascade (an unbounded 137-message
/// `BODY.PEEK[]` fetch retained ~7-10MB per message, ballooning the Android
/// app to 817MB-1.4GB PSS).
///
/// These tests run the REAL `GenericIMAPAdapter` fetch path against a fake
/// `ImapClient` (injected via the F177 `debugSetImapClient` seam) that
/// scripts SEARCH/FETCH responses and RECORDS every FETCH request size --
/// pinning the core invariant: no single UID FETCH ever requests more than
/// `GenericIMAPAdapter.fetchBatchSize` (= 20, universal, no folder-size
/// threshold) messages.
///
/// Mutation-verified at authoring: raising the batch bound to 10_000 turns
/// the request-size assertions red; dropping the onBatch handoff turns the
/// streaming-contract assertions red.
library;

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

/// Fake ImapClient scripting a mailbox of [totalUids] messages (UIDs 1..N).
/// Records the size of every UID FETCH request the adapter issues.
class _FakeImapClient extends ImapClient {
  _FakeImapClient(this.totalUids) : super(isLogEnabled: false);

  final int totalUids;
  final List<int> fetchRequestSizes = [];
  final List<List<int>> fetchRequestUids = [];

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async =>
      Mailbox(
        encodedName: path,
        encodedPath: path,
        pathSeparator: '/',
        flags: [],
      );

  @override
  Future<SearchImapResult> uidSearchMessages({
    String searchCriteria = 'UNSEEN',
    List<ReturnOption>? returnOptions,
    Duration? responseTimeout,
  }) async {
    final result = SearchImapResult();
    if (totalUids > 0) {
      result.matchingSequence = MessageSequence.fromIds(
        List<int>.generate(totalUids, (i) => i + 1),
        isUid: true,
      );
    } else {
      result.matchingSequence = MessageSequence(isUidSequence: true);
    }
    return result;
  }

  @override
  Future<FetchImapResult> uidFetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    final uids = sequence.toList();
    fetchRequestSizes.add(uids.length);
    fetchRequestUids.add(uids);
    final messages = [
      for (final uid in uids)
        MimeMessage()
          ..uid = uid
          ..addHeader('From', 'sender$uid@example.com')
          ..addHeader('Subject', 'Message $uid'),
    ];
    return FetchImapResult(messages, null);
  }
}

GenericIMAPAdapter _adapterWith(_FakeImapClient client) {
  final adapter =
      GenericIMAPAdapter(imapHost: 'imap.example.com', platformId: 'aol');
  adapter.debugSetImapClient(client);
  return adapter;
}

void main() {
  group('F177: chunked UID FETCH (m=20 universal)', () {
    test(
        '47-UID folder is fetched as 20/20/7 in order -- no FETCH request '
        'exceeds fetchBatchSize', () async {
      final client = _FakeImapClient(47);
      final adapter = _adapterWith(client);

      final messages = await adapter.fetchMessages(
        daysBack: 0,
        folderNames: ['Inbox'],
      );

      expect(client.fetchRequestSizes, [20, 20, 7],
          reason: 'ceil(47/20) batches, each bounded to m=20 -- the '
              'invariant that prevents whole-mailbox MIME content from '
              'being held in memory at once');
      expect(messages, hasLength(47),
          reason: 'the list-returning contract is unchanged: all messages '
              'still come back when no onBatch is provided');
      expect(client.fetchRequestUids.first.first, 1);
      expect(client.fetchRequestUids.last.last, 47,
          reason: 'batches cover the full UID list in order');
    });

    test('a 3-message folder is one batch of 3 (no threshold, m applies '
        'universally)', () async {
      final client = _FakeImapClient(3);
      final adapter = _adapterWith(client);

      final messages =
          await adapter.fetchMessages(daysBack: 0, folderNames: ['Inbox']);

      expect(client.fetchRequestSizes, [3]);
      expect(messages, hasLength(3));
    });

    test(
        'onBatch streams each batch with monotonic fetched-so-far progress '
        'and the returned list is empty', () async {
      final client = _FakeImapClient(47);
      final adapter = _adapterWith(client);

      final batchSizes = <int>[];
      final progress = <(int, int)>[];
      final returned = await adapter.fetchMessages(
        daysBack: 0,
        folderNames: ['Inbox'],
        onBatch: (batch, fetchedSoFar, totalUids) async {
          batchSizes.add(batch.length);
          progress.add((fetchedSoFar, totalUids));
        },
      );

      expect(batchSizes, [20, 20, 7]);
      expect(progress, [(20, 47), (40, 47), (47, 47)],
          reason: 'AC-2: per-batch progress, monotonically increasing -- '
              'the fix for the "0 emails for 20+ minutes" blindness');
      expect(returned, isEmpty,
          reason: 'streamed batches must NOT also be accumulated, or the '
              'memory bound is fiction');
    });

    test('fetchMessagesIncremental batches identically and still returns '
        'the correct cursor when streaming', () async {
      final client = _FakeImapClient(25);
      final adapter = _adapterWith(client);

      final batchSizes = <int>[];
      final result = await adapter.fetchMessagesIncremental(
        startUid: 0,
        folderName: 'Inbox',
        onBatch: (batch, fetchedSoFar, totalUids) async {
          batchSizes.add(batch.length);
        },
      );

      expect(client.fetchRequestSizes, [20, 5],
          reason: 'the backlog re-scan path batches too (AC-4) -- it is '
              'the path the Sprint 61 manual scan actually took');
      expect(batchSizes, [20, 5]);
      expect(result.emails, isEmpty);
      expect(result.newCursor, 25,
          reason: 'the cursor is computed from the SEARCH result before '
              'fetching, so streaming must not lose it');
    });

    test('batches hand back converted EmailMessage objects with their UIDs',
        () async {
      final client = _FakeImapClient(21);
      final adapter = _adapterWith(client);

      final ids = <String>[];
      await adapter.fetchMessages(
        daysBack: 0,
        folderNames: ['Inbox'],
        onBatch: (List<EmailMessage> batch, _, __) async {
          ids.addAll(batch.map((m) => m.id));
        },
      );

      expect(ids, List<String>.generate(21, (i) => '${i + 1}'),
          reason: 'batching changes HOW messages are fetched, never WHICH '
              '(AC-3 at the adapter level)');
    });
  });
}
