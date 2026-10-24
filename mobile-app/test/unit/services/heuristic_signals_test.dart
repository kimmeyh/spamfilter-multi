/// F271 (Sprint 81): header-only heuristic reason codes for No Rule rows.
///
/// Each signal has a header set that triggers it and one that does not.
///
/// What these tests do NOT catch (one line each):
///   - compute: whether an IMAP server or Gmail actually RETURNS Reply-To,
///     List-Id, Precedence and List-Unsubscribe (they are fed in by hand; the
///     adapters fetch the full header block, which this test cannot prove);
///   - lookalike: a real-world false positive between two unrelated domains
///     that happen to be one edit apart (the rule is narrow, not proven
///     empty of them);
///   - context rows: a safe sender pattern shape the app does not write today.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/heuristic_signals.dart';

void main() {
  List<String> run(
    Map<String, String> headers, {
    String from = 'Shop <news@shop.example.com>',
    String? auth,
    HeuristicContext context = HeuristicContext.empty,
  }) =>
      HeuristicSignals.compute(
        headers: headers,
        from: from,
        authClassificationName: auth,
        context: context,
      );

  group('reply_to_differs', () {
    test('fires when Reply-To is on another registrable domain', () {
      expect(run({'Reply-To': 'Help <help@evil.test>'}),
          [HeuristicSignal.replyToDiffers]);
    });

    test('header name case does not matter', () {
      expect(run({'reply-to': 'help@evil.test'}),
          [HeuristicSignal.replyToDiffers]);
    });

    test('does not fire for the same domain or only a subdomain', () {
      expect(run({'Reply-To': 'support@shop.example.com'}), isEmpty);
      expect(run({'Reply-To': 'support@mail.example.com'}), isEmpty);
    });

    test('does not fire without a Reply-To header', () {
      expect(run({}), isEmpty);
    });

    // F-PRECHECK (Sprint 81): bare addresses used to be joined into one
    // ("a@shop.example.comb@evil.test") and judged by the LAST domain.
    test('judges only the first of several bare Reply-To addresses', () {
      expect(run({'Reply-To': 'support@shop.example.com, b@evil.test'}),
          isEmpty);
      expect(run({'Reply-To': 'a@evil.test, support@shop.example.com'}),
          [HeuristicSignal.replyToDiffers]);
    });

    test('a quoted display name with a comma is not cut', () {
      expect(run({'Reply-To': '"Shop, Support" <support@shop.example.com>'}),
          isEmpty);
    });
  });

  group('auth_failed', () {
    test('fires for the red class only', () {
      expect(run({}, auth: 'red'), [HeuristicSignal.authFailed]);
      for (final n in ['green', 'yellow', 'grey', null]) {
        expect(run({}, auth: n), isEmpty, reason: 'class $n');
      }
    });
  });

  group('lookalike_domain', () {
    const ctx = HeuristicContext(safeSenderRootDomains: {'paypal.com'});

    test('fires for one substituted letter, a digit swap and a swap of two',
        () {
      expect(run({}, from: 'a@paypa1.com', context: ctx),
          [HeuristicSignal.lookalikeDomain]);
      expect(run({}, from: 'a@paypall.com', context: ctx),
          [HeuristicSignal.lookalikeDomain]);
      expect(run({}, from: 'a@paypla.com', context: ctx),
          [HeuristicSignal.lookalikeDomain]);
      expect(run({}, from: 'a@mail.paypa1.com', context: ctx),
          [HeuristicSignal.lookalikeDomain],
          reason: 'a subdomain of the lookalike root is still a lookalike');
    });

    test('folds rn to m', () {
      const bank = HeuristicContext(safeSenderRootDomains: {'chasemail.com'});
      expect(run({}, from: 'a@chasernail.com', context: bank),
          [HeuristicSignal.lookalikeDomain]);
    });

    test('does not fire for the safe domain itself or its subdomains', () {
      expect(run({}, from: 'a@paypal.com', context: ctx), isEmpty);
      expect(run({}, from: 'a@mail.paypal.com', context: ctx), isEmpty);
    });

    test('does not fire for an unrelated domain, another TLD or two edits',
        () {
      expect(run({}, from: 'a@example.com', context: ctx), isEmpty);
      expect(run({}, from: 'a@paypal.de', context: ctx), isEmpty);
      expect(run({}, from: 'a@paypxx.com', context: ctx), isEmpty);
    });

    test('does not fire for short labels or with no safe senders', () {
      const short = HeuristicContext(safeSenderRootDomains: {'ibm.com'});
      expect(run({}, from: 'a@ibn.com', context: short), isEmpty);
      // A short SENDER label against a long safe one: 'abcd' is one deletion
      // from 'abcde'.
      const longSafe = HeuristicContext(safeSenderRootDomains: {'abcde.com'});
      expect(run({}, from: 'a@abcd.com', context: longSafe), isEmpty);
      // A short SAFE label too: 'maily' is one insertion from 'mail'.
      const shortSafe = HeuristicContext(safeSenderRootDomains: {'mail.com'});
      expect(run({}, from: 'a@maily.com', context: shortSafe), isEmpty);
      expect(run({}, from: 'a@paypa1.com'), isEmpty);
    });
  });

  group('blocked_tld', () {
    const ctx = HeuristicContext(blockedTlds: {'xyz'});

    test('fires when the sender TLD has a TLD block rule', () {
      expect(run({}, from: 'a@deals.xyz', context: ctx),
          [HeuristicSignal.blockedTld]);
    });

    test('does not fire for another TLD or an empty context', () {
      expect(run({}, from: 'a@deals.com', context: ctx), isEmpty);
      expect(run({}, from: 'a@deals.xyz'), isEmpty);
    });
  });

  group('bulk_no_unsubscribe', () {
    test('fires for Precedence bulk or list, or a List-Id, without '
        'List-Unsubscribe', () {
      expect(run({'Precedence': 'bulk'}), [HeuristicSignal.bulkNoUnsubscribe]);
      expect(run({'Precedence': 'List'}), [HeuristicSignal.bulkNoUnsubscribe]);
      expect(run({'List-Id': '<news.example.com>'}),
          [HeuristicSignal.bulkNoUnsubscribe]);
    });

    test('does not fire with List-Unsubscribe, or for non-bulk mail', () {
      expect(
          run({
            'Precedence': 'bulk',
            'List-Unsubscribe': '<mailto:u@example.com>',
          }),
          isEmpty);
      expect(run({'Precedence': 'first-class'}), isEmpty);
      expect(run({}), isEmpty);
    });
  });

  test('several signals come back in display order', () {
    final codes = run(
      {'Reply-To': 'x@evil.test', 'Precedence': 'bulk'},
      auth: 'red',
    );
    expect(codes, [
      HeuristicSignal.authFailed,
      HeuristicSignal.replyToDiffers,
      HeuristicSignal.bulkNoUnsubscribe,
    ]);
  });

  group('encode and decode', () {
    test('round-trips, drops unknown codes, tolerates null and empty', () {
      final stored = HeuristicSignal.encode(
          [HeuristicSignal.replyToDiffers, HeuristicSignal.authFailed]);
      expect(stored, 'reply_to_differs,auth_failed');
      expect(HeuristicSignal.decode(stored),
          [HeuristicSignal.authFailed, HeuristicSignal.replyToDiffers]);
      expect(HeuristicSignal.decode('made_up_code,auth_failed'),
          [HeuristicSignal.authFailed]);
      expect(HeuristicSignal.decode(null), isEmpty);
      expect(HeuristicSignal.decode(''), isEmpty);
      expect(HeuristicSignal.encode([]), isNull);
    });

    test('every code has a plain-English label and an explanation', () {
      for (final c in HeuristicSignal.all) {
        expect(HeuristicSignal.labels[c], isNotEmpty);
        expect(HeuristicSignal.explanations[c], isNotEmpty);
      }
    });
  });

  group('HeuristicContext.fromRows', () {
    test('reads domains from the safe sender shapes the app writes and TLDs '
        'from TLD rules only', () {
      final ctx = HeuristicContext.fromRows(
        safeSenderRows: [
          {'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*paypal\.com$'},
          {'pattern': r'@chase\.com$'},
          {'pattern': r'^someone@bank\.example\.org$'},
          {'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*shop\.co\.uk$'},
          {'pattern': 'not a pattern'},
        ],
        ruleRows: [
          {'pattern_sub_type': 'top_level_domain', 'source_domain': '.*.xyz'},
          {'pattern_sub_type': 'entire_domain', 'source_domain': 'spam.com'},
        ],
      );
      expect(ctx.safeSenderRootDomains,
          {'paypal.com', 'chase.com', 'example.org', 'shop.co.uk'});
      expect(ctx.blockedTlds, {'xyz'});
    });
  });
}
