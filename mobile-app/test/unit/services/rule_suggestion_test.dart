/// F306 (Sprint 82) and F323 (Sprint 83): the pure suggestion function.
///
/// What these tests do NOT catch (one line each):
///   - the basis firing on real mail: they use fixed sender strings, not the
///     Task 6 DEV counts (35 of 254);
///   - a safe-sender basis added later that builds its value wrongly: the RED
///     guard test uses an injected always-safe basis, so it proves the guard
///     only, not any real safe basis;
///   - a pattern that is wrong in the builder itself: the expected values call
///     the same builder, so a builder defect is covered by its own tests;
///   - (F323 R-2) a real header that the PARSER reads as pass when the server
///     sent temperror: these tests build the per-method result by hand, so a
///     parser defect is covered by auth_results_parser_test, not here;
///   - (F323 R-3) the shape regex against a real mail server's From strings:
///     the cases are hand-written addresses.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';

/// Per-method results with no error: the "check finished" case.
const _finished = EmailAuthResult(
  spf: AuthMethodResult.softfail,
  dkim: AuthMethodResult.none,
  dmarc: AuthMethodResult.none,
  raw: '',
);

EmailAuthResult _with(AuthMethodResult spf, AuthMethodResult dkim,
        AuthMethodResult dmarc) =>
    EmailAuthResult(spf: spf, dkim: dkim, dmarc: dmarc, raw: '');

RuleSuggestion? _suggest(String from, String? cls,
        {EmailAuthResult authResult = _finished,
        List<SuggestionBasis>? basis}) =>
    RuleSuggestion.suggest(
      fromEmail: from,
      authClassification: cls,
      authResult: authResult,
      basis: basis,
    );

void main() {
  group('yellow authentication suggests a block rule', () {
    test('non-provider sender: Block Entire Domain on the root domain', () {
      final s = _suggest('Deals <offers@mail.shop-example.com>', 'yellow')!;
      expect(s.kind, 'block');
      expect(s.type, 'entireDomain');
      expect(s.value, 'shop-example.com');
      expect(s.pattern,
          RuleQuickActionService.blockPatternFor('entireDomain', 'shop-example.com'));
      expect(s.reasonCode, 'auth_yellow');
      expect(s.reasonText, contains('authentication'));
    });

    test('shared provider sender (gmail.com): Block Email on the address', () {
      final s = _suggest('Some One <Some.One@gmail.com>', 'yellow')!;
      expect(s.kind, 'block');
      expect(s.type, 'from');
      expect(s.value, 'some.one@gmail.com');
      expect(s.pattern,
          RuleQuickActionService.blockPatternFor('from', 'some.one@gmail.com'));
    });

    test('a sender with no domain gets no suggestion', () {
      expect(_suggest('not-an-address', 'yellow'), isNull);
    });
  });

  group('every other classification gets none', () {
    for (final name in ['green', 'grey', 'red', null, '', 'bogus']) {
      test('classification "$name"', () {
        expect(_suggest('a@spam-example.com', name), isNull);
      });
    }
  });

  group('AC-3 / AC-5: a RED email is never suggested as a safe sender', () {
    final alwaysSafe = <SuggestionBasis>[
      (from, auth) => (
            kind: 'safe',
            type: 'exact',
            value: 'a@spam-example.com',
            reasonCode: 'test',
          ),
    ];

    test('the guard drops a safe result for RED', () {
      expect(_suggest('a@spam-example.com', 'red', basis: alwaysSafe), isNull);
    });

    test('the same basis IS used for GREEN (the guard is not blanket)', () {
      final s = _suggest('a@spam-example.com', 'green', basis: alwaysSafe)!;
      expect(s.kind, 'safe');
      expect(s.pattern,
          RuleQuickActionService.safeSenderPatternFor('exact', 'a@spam-example.com'));
    });

    test('a RED block suggestion is not dropped by the safe guard', () {
      final s = _suggest('a@spam-example.com', 'red', basis: [
        (from, auth) => (
              kind: 'block',
              type: 'entireDomain',
              value: 'spam-example.com',
              reasonCode: 'test',
            ),
      ]);
      expect(s, isNotNull);
    });

    test('a later basis still wins when an earlier safe one is dropped', () {
      final s = _suggest('a@spam-example.com', 'red', basis: [
        ...alwaysSafe,
        (from, auth) => (
              kind: 'block',
              type: 'from',
              value: 'a@spam-example.com',
              reasonCode: 'test',
            ),
      ])!;
      expect(s.kind, 'block');
    });
  });

  test('a draft the builder rejects yields no suggestion', () {
    expect(
        _suggest('a@b.com', 'yellow', basis: [
          (from, auth) => (
                kind: 'block',
                type: 'from',
                value: '@null',
                reasonCode: 'test',
              ),
        ]),
        isNull);
  });

  group('F323 R-2 / AC-1: could not check gives a note, never a rule', () {
    for (final bad in [AuthMethodResult.temperror, AuthMethodResult.permerror]) {
      for (final slot in ['spf', 'dkim', 'dmarc']) {
        test('$slot = ${bad.name} on a YELLOW sender', () {
          final r = _with(
            slot == 'spf' ? bad : AuthMethodResult.pass,
            slot == 'dkim' ? bad : AuthMethodResult.pass,
            slot == 'dmarc' ? bad : AuthMethodResult.pass,
          );
          final s = _suggest('Deals <offers@mail.shop-example.com>', 'yellow',
              authResult: r)!;
          expect(s.isCouldNotCheck, isTrue);
          expect(s.isBlock, isFalse);
          expect(s.kind, kSuggestionKindNone);
          expect(s.reasonText, RuleSuggestion.couldNotCheckText);
        });
      }
    }

    test('the sentence is exactly the one the card names', () {
      expect(RuleSuggestion.couldNotCheckText,
          "Could not check this sender (the mail server's check did not finish)");
    });

    test('AC-2: softfail with no error still gets the F306 suggestion', () {
      final s = _suggest('offers@mail.shop-example.com', 'yellow',
          authResult: _with(AuthMethodResult.softfail, AuthMethodResult.none,
              AuthMethodResult.none))!;
      expect(s.isCouldNotCheck, isFalse);
      expect(s.type, 'entireDomain');
    });

    test('the guard runs before every basis, an injected one included', () {
      final s = _suggest('a@spam-example.com', 'green',
          authResult: _with(AuthMethodResult.temperror, AuthMethodResult.pass,
              AuthMethodResult.pass),
          basis: [
            (from, auth) => (
                  kind: 'block',
                  type: 'from',
                  value: 'a@spam-example.com',
                  reasonCode: 'test',
                ),
          ])!;
      expect(s.isCouldNotCheck, isTrue);
    });

    test('a news_123456 sender with an SPF temperror gets the note, no shape',
        () {
      final s = _suggest('news_123456@any-example.com', 'yellow',
          authResult: _with(AuthMethodResult.temperror, AuthMethodResult.none,
              AuthMethodResult.none))!;
      expect(s.isCouldNotCheck, isTrue);
    });

    test('the note survives the stored columns (v17, no new column)', () {
      final cols = RuleSuggestion.toColumns(RuleSuggestion.couldNotCheckNote);
      expect(cols.length, 5);
      final back = RuleSuggestion.fromColumns(cols)!;
      expect(back, RuleSuggestion.couldNotCheckNote);
      expect(back.isCouldNotCheck, isTrue);
    });
  });

  group('F323 R-3 / AC-4: the news_ plus digits sender shape', () {
    test('4, 5 and 6 digits match, at any domain, with any auth class', () {
      for (final digits in ['1234', '12345', '123456']) {
        for (final cls in ['green', 'yellow', 'grey', 'red']) {
          final s = _suggest('News <news_$digits@whatever-${digits}x.example>', cls)!;
          expect(s.kind, 'block', reason: '$digits $cls');
          expect(s.type, 'senderShape');
          expect(s.value, 'news_digits');
          expect(s.reasonCode, 'sender_shape');
          expect(s.pattern, r'^news_[0-9]{4,6}@');
        }
      }
    });

    test('the shape wins over the YELLOW domain basis for the same sender', () {
      final s = _suggest('news_5555@mail.shop-example.com', 'yellow')!;
      expect(s.type, 'senderShape');
    });

    final nonMatching = [
      'news_abc@example.com',
      'news_12ab@example.com',
      'news_123@example.com',
      'news_1234567@example.com',
      'news_@example.com',
      'xnews_1234@example.com',
      'news_1234x@example.com',
      'news1234@example.com',
      'news_1234.x@example.com',
    ];
    for (final addr in nonMatching) {
      test('$addr gets no shape suggestion (green sender)', () {
        expect(_suggest(addr, 'green'), isNull);
      });
    }

    test('the saved regex matches the digits and not the letters', () {
      final re = RegExp(RuleQuickActionService.blockPatternFor(
          'senderShape', 'news_digits')!);
      expect(re.hasMatch('news_1234@a.example'), isTrue);
      expect(re.hasMatch('news_123456@a.b.example'), isTrue);
      expect(re.hasMatch('news_1234567@a.example'), isFalse);
      expect(re.hasMatch('news_123@a.example'), isFalse);
      expect(re.hasMatch('news_abc1234@a.example'), isFalse);
    });

    test('an unknown shape value is not a rule', () {
      expect(RuleQuickActionService.blockPatternFor('senderShape', 'other'),
          isNull);
    });
  });

  group('columns', () {
    test('round trip, and null writes five nulls', () {
      final s = _suggest('a@spam-example.com', 'yellow')!;
      expect(RuleSuggestion.fromColumns(RuleSuggestion.toColumns(s)), s);
      final nulls = RuleSuggestion.toColumns(null);
      expect(nulls.length, 5);
      expect(nulls.values.every((v) => v == null), isTrue);
      expect(RuleSuggestion.fromColumns(nulls), isNull);
    });

    test('a partly filled row reads as no suggestion', () {
      final cols = RuleSuggestion.toColumns(
          _suggest('a@spam-example.com', 'yellow'));
      cols['suggestion_pattern'] = null;
      expect(RuleSuggestion.fromColumns(cols), isNull);
    });

    test('an unknown reason code still reads as a sentence', () {
      const s = RuleSuggestion(
          kind: 'block',
          type: 'from',
          value: 'a@b.com',
          pattern: r'^a@b\.com$',
          reasonCode: 'future_code');
      expect(s.reasonText, isNotEmpty);
    });
  });
}
