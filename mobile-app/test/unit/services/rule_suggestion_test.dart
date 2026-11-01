/// F306 (Sprint 82): the pure suggestion function.
///
/// What these tests do NOT catch (one line each):
///   - the basis firing on real mail: they use fixed sender strings, not the
///     Task 6 DEV counts (35 of 254);
///   - a safe-sender basis added later that builds its value wrongly: the RED
///     guard test uses an injected always-safe basis, so it proves the guard
///     only, not any real safe basis;
///   - a pattern that is wrong in the builder itself: the expected values call
///     the same builder, so a builder defect is covered by its own tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';

void main() {
  group('yellow authentication suggests a block rule', () {
    test('non-provider sender: Block Entire Domain on the root domain', () {
      final s = RuleSuggestion.suggest(
        fromEmail: 'Deals <offers@mail.shop-example.com>',
        authClassification: 'yellow',
      )!;
      expect(s.kind, 'block');
      expect(s.type, 'entireDomain');
      expect(s.value, 'shop-example.com');
      expect(s.pattern,
          RuleQuickActionService.blockPatternFor('entireDomain', 'shop-example.com'));
      expect(s.reasonCode, 'auth_yellow');
      expect(s.reasonText, contains('authentication'));
    });

    test('shared provider sender (gmail.com): Block Email on the address', () {
      final s = RuleSuggestion.suggest(
        fromEmail: 'Some One <Some.One@gmail.com>',
        authClassification: 'yellow',
      )!;
      expect(s.kind, 'block');
      expect(s.type, 'from');
      expect(s.value, 'some.one@gmail.com');
      expect(s.pattern,
          RuleQuickActionService.blockPatternFor('from', 'some.one@gmail.com'));
    });

    test('a sender with no domain gets no suggestion', () {
      expect(
          RuleSuggestion.suggest(
              fromEmail: 'not-an-address', authClassification: 'yellow'),
          isNull);
    });
  });

  group('every other classification gets none', () {
    for (final name in ['green', 'grey', 'red', null, '', 'bogus']) {
      test('classification "$name"', () {
        expect(
            RuleSuggestion.suggest(
                fromEmail: 'a@spam-example.com', authClassification: name),
            isNull);
      });
    }
  });

  group('AC-3: a RED email is never suggested as a safe sender', () {
    final alwaysSafe = <SuggestionBasis>[
      (from, auth) => (
            kind: 'safe',
            type: 'exact',
            value: 'a@spam-example.com',
            reasonCode: 'test',
          ),
    ];

    test('the guard drops a safe result for RED', () {
      expect(
          RuleSuggestion.suggest(
              fromEmail: 'a@spam-example.com',
              authClassification: 'red',
              basis: alwaysSafe),
          isNull);
    });

    test('the same basis IS used for GREEN (the guard is not blanket)', () {
      final s = RuleSuggestion.suggest(
          fromEmail: 'a@spam-example.com',
          authClassification: 'green',
          basis: alwaysSafe)!;
      expect(s.kind, 'safe');
      expect(s.pattern,
          RuleQuickActionService.safeSenderPatternFor('exact', 'a@spam-example.com'));
    });

    test('a RED block suggestion is not dropped by the safe guard', () {
      final s = RuleSuggestion.suggest(
          fromEmail: 'a@spam-example.com',
          authClassification: 'red',
          basis: [
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
      final s = RuleSuggestion.suggest(
          fromEmail: 'a@spam-example.com',
          authClassification: 'red',
          basis: [
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
        RuleSuggestion.suggest(
            fromEmail: 'a@b.com',
            authClassification: 'yellow',
            basis: [
              (from, auth) => (
                    kind: 'block',
                    type: 'from',
                    value: '@null',
                    reasonCode: 'test',
                  ),
            ]),
        isNull);
  });

  group('columns', () {
    test('round trip, and null writes five nulls', () {
      final s = RuleSuggestion.suggest(
          fromEmail: 'a@spam-example.com', authClassification: 'yellow')!;
      expect(RuleSuggestion.fromColumns(RuleSuggestion.toColumns(s)), s);
      final nulls = RuleSuggestion.toColumns(null);
      expect(nulls.length, 5);
      expect(nulls.values.every((v) => v == null), isTrue);
      expect(RuleSuggestion.fromColumns(nulls), isNull);
    });

    test('a partly filled row reads as no suggestion', () {
      final cols = RuleSuggestion.toColumns(RuleSuggestion.suggest(
          fromEmail: 'a@spam-example.com', authClassification: 'yellow'));
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
