/// F222 (Sprint 74, reworked at Manual Validation 2026-09-27): the Scan
/// Results list has TWO orders -- the default folder -> domain -> address
/// (the pre-Sprint-74 order Harold asked to keep) and newest first, switched
/// by a chip -- and Gmail messages carry their REAL received date (they
/// carried the scan time before, which made any date ordering meaningless for
/// Gmail). The first version, newest first clustered by base domain, was not
/// what Harold asked for and is gone.
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

EmailActionResult _r(String from, DateTime at,
        {String subject = 's', String folder = 'INBOX'}) =>
    EmailActionResult(
      email: EmailMessage(
        id: '$from-${at.millisecondsSinceEpoch}',
        from: from,
        subject: subject,
        body: '',
        headers: const {},
        receivedDate: at,
        folderName: folder,
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

  group('T-2 -- the two orders (pure functions)', () {
    test('orderByFolderDomainAddress: folder, then domain, then address, all '
        'A to Z -- dates play no part', () {
      final result = orderByFolderDomainAddress<(String, String)>(
        [
          ('INBOX', 'b@beta.com'),
          ('INBOX', 'a@beta.com'),
          ('Bulk', 'z@zeta.com'),
          ('INBOX', 'x@alpha.com'),
        ],
        folderOf: (i) => i.$1,
        domainOf: (i) => i.$2.split('@').last,
        addressOf: (i) => i.$2,
      ).map((i) => i.$2).toList();
      expect(result,
          ['z@zeta.com', 'x@alpha.com', 'a@beta.com', 'b@beta.com']);
    });

    test('orderNewestFirst: received date, newest first', () {
      final result = orderNewestFirst<(String, DateTime)>(
        [('old', at(30)), ('newest', at(1)), ('mid', at(10))],
        receivedAt: (i) => i.$2,
      ).map((i) => i.$1).toList();
      expect(result, ['newest', 'mid', 'old']);
    });

    test('both return a NEW list and never reorder the input', () {
      final input = [('INBOX', 'y@b.com'), ('Bulk', 'x@a.com')];
      final copy = List.of(input);
      orderByFolderDomainAddress<(String, String)>(input,
          folderOf: (i) => i.$1, domainOf: (i) => i.$2, addressOf: (i) => i.$2);
      orderNewestFirst<(String, String)>(input,
          receivedAt: (i) => DateTime(2026));
      expect(input, copy);
    });
  });

  group('T-3 -- orderResultsForDisplay: the call site\'s real inputs', () {
    final mixed = [
      _r('b@beta.com', at(1)),
      _r('z@zeta.com', at(20), folder: 'Bulk'),
      _r('a@alpha.com', at(5)),
      _r('a@beta.com', at(40)),
    ];

    test('DEFAULT is folder -> domain -> address (the pre-Sprint-74 order '
        'Harold asked to keep)', () {
      expect(orderResultsForDisplay(mixed).map((r) => r.email.from).toList(),
          ['z@zeta.com', 'a@alpha.com', 'a@beta.com', 'b@beta.com']);
    });

    test('newestFirst is purely by date', () {
      expect(
          orderResultsForDisplay(mixed, order: ResultSortOrder.newestFirst)
              .map((r) => r.email.from)
              .toList(),
          ['b@beta.com', 'a@alpha.com', 'z@zeta.com', 'a@beta.com']);
    });

    test('the domain key is the FULL sender domain, as before the sprint '
        '(news.example.com is not merged into example.com)', () {
      final result = orderResultsForDisplay([
        _r('info@news.example.com', at(1)),
        _r('deal@example.com', at(2)),
        _r('x@middle.com', at(3)),
      ]).map((r) => r.email.from).toList();
      expect(result,
          ['deal@example.com', 'x@middle.com', 'info@news.example.com']);
    });

    test('equal keys order deterministically in both orders', () {
      for (final order in ResultSortOrder.values) {
        final a = orderResultsForDisplay([
          _r('same@x.com', at(1), subject: 'b'),
          _r('same@x.com', at(1), subject: 'a'),
        ], order: order)
            .map((r) => r.email.subject)
            .toList();
        expect(a, ['a', 'b'], reason: '$order');
      }
    });
  });

  group('T-4 -- the received date on each row', () {
    test('local time, to the minute -- the pop-up and the row share this', () {
      expect(formatReceivedDateForDisplay(DateTime(2026, 9, 26, 22, 5, 31)),
          '2026-09-26 22:05');
    });

    test('a UTC date is shown in LOCAL time', () {
      final utc = DateTime.utc(2026, 9, 26, 12, 0);
      expect(formatReceivedDateForDisplay(utc),
          utc.toLocal().toString().substring(0, 16));
    });
  });
}
