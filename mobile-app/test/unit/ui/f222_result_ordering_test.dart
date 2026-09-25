/// F222 (Sprint 74): scan results read like an inbox -- newest first,
/// clustered by BASE domain -- and Gmail messages carry their REAL received
/// date (they carried the scan time before, which made any date ordering
/// meaningless for Gmail).
///
/// **What these tests do NOT catch**: an IMAP received-date defect -- IMAP
/// dates come from enough_mail's `decodeDate()` on a different path, which
/// these tests do not exercise. And the on-screen order of a LIVE scan is
/// Manual Validation; the widget-level wiring is covered by the existing
/// no-rule reload test, which walks the rendered order.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/utils/result_ordering.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

EmailActionResult _r(String from, DateTime at, {String subject = 's'}) =>
    EmailActionResult(
      email: EmailMessage(
        id: '$from-${at.millisecondsSinceEpoch}',
        from: from,
        subject: subject,
        body: '',
        headers: const {},
        receivedDate: at,
        folderName: 'INBOX',
      ),
      action: EmailActionType.none,
      success: true,
    );

void main() {
  final t0 = DateTime(2026, 9, 25, 12);
  DateTime at(int minutesAgo) => t0.subtract(Duration(minutes: minutesAgo));

  group('T-1 -- Gmail received date', () {
    test('resolveGmailReceivedDate prefers internalDate', () {
      final ms = DateTime.utc(2026, 9, 23, 18, 5, 11).millisecondsSinceEpoch;
      final d = GmailApiAdapter.resolveGmailReceivedDate(
        internalDate: '$ms',
        dateHeader: 'Tue, 01 Jan 2019 00:00:00 +0000',
      );
      expect(d.millisecondsSinceEpoch, ms);
    });

    test('falls back to an RFC 2822 Date header -- the form DateTime.tryParse '
        'rejected', () {
      final d = GmailApiAdapter.resolveGmailReceivedDate(
        internalDate: null,
        dateHeader: 'Tue, 23 Sep 2026 14:05:11 -0400',
      );
      expect(d.toUtc(), DateTime.utc(2026, 9, 23, 18, 5, 11));
    });

    test('uses the scan time only when both are unusable', () {
      final fixed = DateTime(2000);
      final d = GmailApiAdapter.resolveGmailReceivedDate(
        internalDate: 'garbage',
        dateHeader: 'not a date',
        now: () => fixed,
      );
      expect(d, fixed);
    });

    test('the REAL conversion path uses it (wiring, not just the helper)', () {
      final ms = DateTime.utc(2026, 9, 23, 18, 5, 11).millisecondsSinceEpoch;
      final msg = gmail.Message(
        id: 'm1',
        internalDate: '$ms',
        payload: gmail.MessagePart(headers: [
          gmail.MessagePartHeader(name: 'From', value: 'a@b.com'),
          gmail.MessagePartHeader(name: 'Subject', value: 's'),
          gmail.MessagePartHeader(
              name: 'Date', value: 'Tue, 23 Sep 2026 14:05:11 -0400'),
        ]),
      );
      final converted = GmailApiAdapter().debugConvertGmailMessage(msg, 'INBOX');
      expect(converted, isNotNull);
      expect(converted!.receivedDate.millisecondsSinceEpoch, ms);
    });
  });

  group('T-2 -- orderNewestFirstClusteredByDomain (Harold\'s specification)',
      () {
    List<String> order(List<(String, DateTime)> items) =>
        orderNewestFirstClusteredByDomain<(String, DateTime)>(
          items,
          receivedAt: (i) => i.$2,
          baseDomainOf: (i) => i.$1.split('@').last.split('.').reversed
              .take(2)
              .toList()
              .reversed
              .join('.'),
        ).map((i) => i.$1).toList();

    test('newest email, then its whole domain newest-first, then the next '
        'newest remaining', () {
      final result = order([
        ('a1@alpha.com', at(50)),
        ('b1@beta.com', at(5)), // newest overall -> beta cluster first
        ('a2@alpha.com', at(10)), // newest remaining after beta -> alpha
        ('b2@beta.com', at(40)),
        ('c1@gamma.com', at(20)),
      ]);
      expect(result, [
        'b1@beta.com', 'b2@beta.com', // beta: newest first
        'a2@alpha.com', 'a1@alpha.com', // alpha (newest remaining = a2 @10)
        'c1@gamma.com', // gamma (@20) comes after alpha's newest (@10)
      ]);
    });

    test('returns a NEW list and never reorders the input', () {
      final input = [('x@old.com', at(30)), ('y@new.com', at(1))];
      final copy = List.of(input);
      orderNewestFirstClusteredByDomain<(String, DateTime)>(input,
          receivedAt: (i) => i.$2, baseDomainOf: (i) => i.$1);
      expect(input, copy);
    });
  });

  group('T-3 -- orderResultsForDisplay: the call site\'s real inputs', () {
    test('subdomains cluster with their base domain; co.uk domains do not '
        'merge', () {
      final result = orderResultsForDisplay([
        _r('promo@example.co.uk', at(1)),
        _r('deal@news.example.com', at(3)),
        _r('other@other.co.uk', at(4)),
        _r('info@example.com', at(9)),
      ]).map((r) => r.email.from).toList();
      expect(result, [
        'promo@example.co.uk',
        'deal@news.example.com', 'info@example.com', // one base domain
        'other@other.co.uk',
      ]);
    });

    test('equal dates order deterministically', () {
      final a = orderResultsForDisplay(
              [_r('b@x.com', at(1)), _r('a@x.com', at(1))])
          .map((r) => r.email.from)
          .toList();
      expect(a, ['a@x.com', 'b@x.com']);
    });
  });
}
