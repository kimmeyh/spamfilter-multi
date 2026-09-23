/// F224 (Sprint 73): user-facing scan cancellation.
///
/// **The design, in one sentence**: cancellation is a FLAG the scan observes
/// and a THROW the scan performs -- never an out-of-band teardown.
///
/// That is not a style choice. `EmailScanner.scanInbox`'s `finally` already
/// releases the coordinator lease AND disconnects the IMAP session on every
/// path, including a thrown exception. Cancelling by throwing reuses the one
/// teardown known to be correct. The alternative -- freeing the lease from
/// outside while the scan's stack still holds a live socket -- lets the next
/// scan acquire immediately and open a SECOND session against a per-account
/// cap, which is the Sprint 61 failure this coordinator was built to prevent.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they prove the flag is
/// set, scoped, cleared and observed, and that the lease changes hands. They
/// CANNOT prove a real IMAP socket was closed on the server -- the coordinator
/// has no socket. The per-account session cap is the real-world symptom, and
/// only Harold cancelling a live scan on the S24+ and immediately starting
/// another shows it. That is why the DoD requires exactly that.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';

void main() {
  setUp(ScanCoordinator.resetForTest);

  group('F224: the cancel signal', () {
    test('THE FEATURE: cancelling the active scan raises its flag', () async {
      final c = ScanCoordinator.instance;
      await c.acquire(scanType: 'manual', accountId: 'a@x.com');

      expect(c.isCancelRequested, isFalse, reason: 'nothing asked for yet');
      expect(c.requestCancel(accountId: 'a@x.com'), isTrue);
      expect(c.isCancelRequested, isTrue);
    });

    test('THE NFR: a cancel is scoped to ONE account', () async {
      // Account-scoping is an explicit requirement: cancelling one account's
      // scan must never stop another's.
      final c = ScanCoordinator.instance;
      await c.acquire(scanType: 'background', accountId: 'a@x.com');

      expect(c.requestCancel(accountId: 'OTHER@x.com'), isFalse);
      expect(c.isCancelRequested, isFalse,
          reason: 'the wrong account must not be able to stop this scan');
    });

    test('cancelling when nothing runs is a no-op, not a crash', () {
      // The unhappy input: the user taps Cancel just as the scan finishes.
      final c = ScanCoordinator.instance;
      expect(c.requestCancel(accountId: 'a@x.com'), isFalse);
      expect(c.isCancelRequested, isFalse);
    });

    test('THE LEAK GUARD: requesting a cancel does NOT release the lease',
        () async {
      // If this ever goes green the wrong way, the bug it describes is a
      // second IMAP session opening while the first is still closing.
      final c = ScanCoordinator.instance;
      await c.acquire(scanType: 'manual', accountId: 'a@x.com');

      c.requestCancel(accountId: 'a@x.com');

      expect(c.active, isNotNull,
          reason: 'the lease is released by the SCAN, in its finally -- never '
              'by the cancel request, which would free it while the socket is '
              'still open');
    });
  });

  group('F224: the lease after a cancel', () {
    test('AC-1: releasing the cancelled lease leaves the coordinator idle',
        () async {
      final c = ScanCoordinator.instance;
      final lease = await c.acquire(scanType: 'manual', accountId: 'a@x.com');
      c.requestCancel(accountId: 'a@x.com');

      // What scanInbox's `finally` does.
      c.release(lease);

      expect(c.active, isNull);
      expect(c.isCancelRequested, isFalse,
          reason: 'no active scan means nothing is under a cancel request');
    });

    test('AC-2: a new scan acquires immediately after a cancelled one',
        () async {
      final c = ScanCoordinator.instance;
      final first = await c.acquire(scanType: 'manual', accountId: 'a@x.com');
      c.requestCancel(accountId: 'a@x.com');
      c.release(first);

      final second = await c.acquire(scanType: 'manual', accountId: 'a@x.com')
          .timeout(const Duration(seconds: 1));

      expect(second, isNotNull);
      expect(c.active, isNotNull);
      expect(c.isCancelRequested, isFalse,
          reason: 'THE INVARIANT: a fresh scan must not inherit the previous '
              "scan's cancel flag, or it would stop at its first batch");
    });

    test('THE HANDOFF: a waiter does not inherit the cancel flag', () async {
      // The case the card singled out -- a scan cancelled while another waits
      // behind it. _handOffOrIdle constructs a FRESH ActiveScanInfo, so the
      // flag cannot cross the handoff. Verified in source, pinned here.
      final c = ScanCoordinator.instance;
      final first = await c.acquire(scanType: 'manual', accountId: 'a@x.com');

      final queued = c.acquire(scanType: 'background', accountId: 'b@x.com');
      await Future<void>.delayed(Duration.zero);

      c.requestCancel(accountId: 'a@x.com');
      expect(c.isCancelRequested, isTrue);

      c.release(first);
      await queued.timeout(const Duration(seconds: 1));

      expect(c.active, isNotNull, reason: 'the waiter got the lease');
      expect(c.active!.accountId, 'b@x.com');
      expect(c.isCancelRequested, isFalse,
          reason: 'the waiter inheriting a cancel would stop a scan the user '
              'never asked to stop');
    });
  });

  group('F224: the exception', () {
    test('it is an Exception and says what happened', () {
      const e = ScanCancelledException();
      expect(e, isA<Exception>());
      expect(e.toString(), contains('cancelled'));
    });
  });
}
