/// S38-CI-4 (Sprint 39): tests for capping the IMAP oldest-no-rule cursor at
/// the daysBack retention window so the cursor ages out.
///
/// Two concerns are unit-tested here:
///
///   1. The pure clamp arithmetic (`EmailScanner.clampNoRuleCursor`):
///      computed-oldest is clamped UP to the daysBack UID floor, so a
///      no-rule UID older than the window is not persisted as the cursor.
///
///   2. The per-scan cache (`resolveDaysBackUidFloorForTesting`): the
///      `UID SEARCH SINCE` lookup runs at most ONCE per folder per scan,
///      not once per batch boundary. Asserted via a call-counting fake
///      adapter.
///
/// Real IMAP `SEARCH SINCE` wire behavior is provider-coupled and is
/// verified via Phase 5.3 manual testing (consistent with the Sprint 37
/// retrospective Category 2 disposition for IMAP UID search).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';

/// Fake IMAP adapter that counts `firstUidSince` calls and returns a fixed
/// floor without touching the network. `firstUidSince` is a plain public
/// method on GenericIMAPAdapter, so overriding it here exercises the same
/// code path EmailScanner uses (it accepts a GenericIMAPAdapter).
class _CountingImapAdapter extends GenericIMAPAdapter {
  _CountingImapAdapter({required this.floor})
      : super(imapHost: 'imap.example.com', platformId: 'imap');

  final int? floor;
  int firstUidSinceCallCount = 0;
  final List<String> foldersQueried = [];

  @override
  Future<int?> firstUidSince(String folderName, DateTime since) async {
    firstUidSinceCallCount++;
    foldersQueried.add(folderName);
    return floor;
  }
}

void main() {
  group('S38-CI-4 clampNoRuleCursor (pure arithmetic)', () {
    test('caps the cursor UP to the daysBack floor when computed is older',
        () {
      // Computed oldest no-rule UID (100) is OLDER (smaller) than the
      // daysBack floor (500): it falls outside the retention window and
      // must NOT be persisted. The cursor is clamped up to the floor.
      expect(EmailScanner.clampNoRuleCursor(100, 500), 500,
          reason: 'A no-rule UID older than the daysBack window must age out: '
              'the persisted cursor is capped at the floor, not the stale UID.');
    });

    test('leaves the cursor unchanged when computed >= floor', () {
      // Computed oldest (800) is within the window (floor 500): keep it.
      expect(EmailScanner.clampNoRuleCursor(800, 500), 800,
          reason: 'A no-rule UID inside the daysBack window is preserved so '
              'the backlog re-scan still sees it.');
    });

    test('leaves the cursor unchanged when computed equals the floor', () {
      expect(EmailScanner.clampNoRuleCursor(500, 500), 500);
    });

    test('null floor (daysBack=0 / scan-all / lookup failure) skips the clamp',
        () {
      // A null floor means "no time floor" -- the computed value passes
      // through unchanged, preserving the pre-S38-CI-4 behavior.
      expect(EmailScanner.clampNoRuleCursor(100, null), 100,
          reason: 'daysBack=0 (scan all), an empty window, or a failed '
              'SEARCH SINCE all yield a null floor and must not change the '
              'computed cursor.');
    });
  });

  group('S38-CI-4 daysBack UID-floor per-scan cache', () {
    late EmailScanner scanner;

    setUp(() {
      scanner = EmailScanner(
        platformId: 'aol',
        accountId: 'aol-test@example.com',
        ruleSetProvider: RuleSetProvider(),
        scanProvider: EmailScanProvider(),
      );
      scanner.resetDaysBackUidFloorCacheForTesting();
    });

    test('runs SEARCH SINCE at most once per folder per scan (cached)',
        () async {
      final imap = _CountingImapAdapter(floor: 500);

      // Simulate several batch boundaries within one scan asking for the
      // same folder's floor: the lookup must run exactly once.
      final a = await scanner.resolveDaysBackUidFloorForTesting(
          imap, 'INBOX', 7);
      final b = await scanner.resolveDaysBackUidFloorForTesting(
          imap, 'INBOX', 7);
      final c = await scanner.resolveDaysBackUidFloorForTesting(
          imap, 'INBOX', 7);

      expect(a, 500);
      expect(b, 500);
      expect(c, 500);
      expect(imap.firstUidSinceCallCount, 1,
          reason: 'The daysBack UID floor must be resolved with a single '
              'IMAP SEARCH SINCE per folder per scan, not one round-trip per '
              'batch boundary.');
    });

    test('separate folders each get their own single lookup', () async {
      final imap = _CountingImapAdapter(floor: 42);

      await scanner.resolveDaysBackUidFloorForTesting(imap, 'INBOX', 7);
      await scanner.resolveDaysBackUidFloorForTesting(imap, 'Bulk Mail', 7);
      await scanner.resolveDaysBackUidFloorForTesting(imap, 'INBOX', 7);
      await scanner.resolveDaysBackUidFloorForTesting(imap, 'Bulk Mail', 7);

      expect(imap.firstUidSinceCallCount, 2,
          reason: 'IMAP UIDs are mailbox-scoped, so each folder needs its own '
              'floor lookup -- but only once each per scan.');
      expect(imap.foldersQueried, containsAll(<String>['INBOX', 'Bulk Mail']));
    });

    test('daysBack=0 (scan all) skips the SEARCH entirely and returns null',
        () async {
      final imap = _CountingImapAdapter(floor: 500);

      final floor =
          await scanner.resolveDaysBackUidFloorForTesting(imap, 'INBOX', 0);

      expect(floor, isNull,
          reason: 'daysBack=0 means scan all -- there is no time floor to '
              'clamp against, so no IMAP round-trip is made.');
      expect(imap.firstUidSinceCallCount, 0,
          reason: 'A scan-all window must not issue a SEARCH SINCE.');
    });

    test('cached null (empty window / failed lookup) is not re-queried',
        () async {
      // floor=null simulates an empty daysBack window or a failed SEARCH.
      final imap = _CountingImapAdapter(floor: null);

      final a = await scanner.resolveDaysBackUidFloorForTesting(
          imap, 'INBOX', 7);
      final b = await scanner.resolveDaysBackUidFloorForTesting(
          imap, 'INBOX', 7);

      expect(a, isNull);
      expect(b, isNull);
      expect(imap.firstUidSinceCallCount, 1,
          reason: 'A null floor is still a resolved result and must be cached '
              'so a fruitless SEARCH SINCE is not repeated every batch.');
    });
  });
}
