/// Sprint 38 F6c Phase 2 (Issue #250): tests for the IncrementalFetchResult
/// shape contract that EmailScanner._fetchFolderMessages branches on.
///
/// Sprint 37 added IncrementalFetchResult; this sprint wires it into the
/// scan path. The branching logic in EmailScanner depends on three
/// observable properties of an IncrementalFetchResult instance:
///
///   1. .isExpired must be true ONLY for the expired() factory
///   2. .newHistoryId must be non-null for empty() and the standard ctor
///   3. .emails must be empty for empty() and expired(), populated for ctor
///
/// If any of these change shape, _fetchFolderMessages will silently break
/// (no compile error, just wrong scan behavior). These tests pin the
/// contract.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

void main() {
  group('IncrementalFetchResult shape contract', () {
    test('expired() returns isExpired=true with no emails and null historyId',
        () {
      final result = IncrementalFetchResult.expired();

      expect(result.isExpired, isTrue,
          reason: 'Scanner branches on isExpired to clear last_history_id '
              'and fall back to a full scan.');
      expect(result.emails, isEmpty,
          reason: 'No emails should be returned when history has expired -- '
              'caller takes the full-fetch path next.');
      expect(result.newHistoryId, isNull,
          reason: 'Caller will re-capture historyId via '
              'getCurrentHistoryId() after the full-fetch fallback.');
    });

    test('empty() returns isExpired=false with no emails but a historyId', () {
      final result = IncrementalFetchResult.empty(newHistoryId: 'cursor-42');

      expect(result.isExpired, isFalse,
          reason: 'An empty delta is a successful no-op, not a failure.');
      expect(result.emails, isEmpty);
      expect(result.newHistoryId, 'cursor-42',
          reason:
              'Scanner persists this cursor so the NEXT scan can pick up from here.');
    });

    test('standard ctor returns isExpired=false with emails and historyId',
        () {
      final email = EmailMessage(
        id: 'msg-1',
        from: 'sender@example.com',
        subject: 'test',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 5, 13),
        folderName: 'INBOX',
      );

      final result = IncrementalFetchResult(
        emails: [email],
        newHistoryId: 'cursor-43',
      );

      expect(result.isExpired, isFalse);
      expect(result.emails, hasLength(1));
      expect(result.emails.first.id, 'msg-1');
      expect(result.newHistoryId, 'cursor-43');
    });

    test('expired and empty are distinguishable (separate scanner branches)',
        () {
      final expired = IncrementalFetchResult.expired();
      final empty = IncrementalFetchResult.empty(newHistoryId: 'cursor-44');

      // Both have empty emails -- isExpired is the discriminator.
      expect(expired.emails, isEmpty);
      expect(empty.emails, isEmpty);
      expect(expired.isExpired, isNot(empty.isExpired),
          reason:
              'EmailScanner._fetchFolderMessages distinguishes "history expired -> '
              'full-scan fallback" from "no changes since last scan -> persist '
              'cursor and continue" via the isExpired flag alone.');
    });
  });
}
