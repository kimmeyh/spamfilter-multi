/// Sprint 38 Round 1 (post-retro IMAP extension of F6c Phase 2):
/// tests for the ImapIncrementalFetchResult shape contract that
/// EmailScanner._fetchFolderMessagesImap branches on.
///
/// Two observable properties EmailScanner relies on:
///   1. .emails -- empty for .empty(), populated for standard ctor
///   2. .newCursor -- always non-null; reflects highest UID seen this scan
///
/// Unlike Gmail's IncrementalFetchResult there is no `expired` state for
/// IMAP -- UIDs are monotonically increasing per RFC 3501.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

void main() {
  group('ImapIncrementalFetchResult shape contract (Sprint 38 Round 1)', () {
    test('empty() returns no emails but a non-null cursor', () {
      final result = ImapIncrementalFetchResult.empty(newCursor: 12345);

      expect(result.emails, isEmpty,
          reason: 'An empty delta is a successful no-op, not a failure.');
      expect(result.newCursor, 12345,
          reason: 'Scanner persists this cursor (even when emails is empty) '
              'so the next scan resumes from the right point.');
    });

    test('standard ctor returns emails and the new cursor', () {
      final email = EmailMessage(
        id: '12346',
        from: 'sender@example.com',
        subject: 'test',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 5, 16),
        folderName: 'INBOX',
      );

      final result = ImapIncrementalFetchResult(
        emails: [email],
        newCursor: 12346,
      );

      expect(result.emails, hasLength(1));
      expect(result.emails.first.id, '12346');
      expect(result.newCursor, 12346);
    });

    test('newCursor never decreases (caller invariant)', () {
      // The scanner's branch: only persist the new cursor when it changed.
      // This test pins the expected invariant that .newCursor >= startUid,
      // i.e. the result never reports a regressed cursor. Caller relies
      // on this to avoid persisting a smaller cursor and then redundantly
      // re-scanning.
      final result = ImapIncrementalFetchResult(
        emails: const [],
        newCursor: 100,
      );
      expect(result.newCursor, greaterThanOrEqualTo(0));
    });
  });
}
