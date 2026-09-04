/// F186 (Sprint 64) -- T-3: an authored-shape body-phrase rule (the exact
/// pattern shape ManualRulePatternGenerator.generateBodyPhrase produces,
/// RegExp.escape of a lowercased phrase) matches through the F180 deferral
/// staging: RuleEvaluator.evaluateWithoutBody defers (returns null) because
/// the rule has an undecidable body condition, then the caller re-runs the
/// full evaluate() with the real body and gets a match.
///
/// ISOLATED-BRANCH GUARD FIXTURE (TESTING_STRATEGY.md "Isolated-Branch Guard
/// Tests", Sprint 63 retro IMP-1): the rule set below contains exactly ONE
/// rule -- the authored body-phrase rule -- so the body condition is the
/// ONLY possible deciding factor. There is no other rule, and no other
/// condition on this rule, that could produce the expected outcome if the
/// body-matching clause were deleted. This proves AC-3 end-to-end with an
/// authored rule, not a hand-written regex literal.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:my_email_spam_filter/core/utils/manual_rule_pattern_generator.dart';

/// Build the SAME rule shape ManualRuleCreateScreen._saveBlockRule writes
/// for a Body Phrase selection: pattern_category 'body', pattern_sub_type
/// 'keyword', execution_order 50, single-element OR body condition list
/// holding the ManualRulePatternGenerator.generateBodyPhrase output.
Rule _authoredBodyPhraseRule(String phrase) {
  final result = ManualRulePatternGenerator.generateBodyPhrase(phrase);
  // Plain assertion, not `expect()` -- this fixture builder runs at group
  // body evaluation time (outside any individual `test()` callback), and
  // flutter_test's `expect()` requires an active test zone.
  if (!result.isSuccess) {
    throw StateError(
        'fixture phrase must generate successfully: ${result.error}');
  }
  return Rule(
    name: 'manual_${phrase.replaceAll(' ', '_')}_test',
    enabled: true,
    isLocal: true,
    executionOrder: 50,
    conditions: RuleConditions(type: 'OR', body: [result.pattern]),
    actions: RuleActions(delete: true),
    patternCategory: 'body',
    patternSubType: 'keyword',
  );
}

EmailMessage _headerOnlyMsg({
  required String id,
  String from = 'sender@ok.example',
  String subject = 'a subject',
}) {
  return EmailMessage(
    id: id,
    from: from,
    subject: subject,
    body: '', // F180 adapter contract: header-first fetch serves empty body.
    headers: {'From': from, 'Subject': subject},
    receivedDate: DateTime(2026, 1, 1),
    folderName: 'INBOX',
  );
}

EmailMessage _withBody(EmailMessage headerOnly, String body) => EmailMessage(
      id: headerOnly.id,
      from: headerOnly.from,
      subject: headerOnly.subject,
      body: body,
      headers: headerOnly.headers,
      receivedDate: headerOnly.receivedDate,
      folderName: headerOnly.folderName,
    );

void main() {
  group('F186 T-3: authored body-phrase rule -- deferral then full evaluate',
      () {
    final rule = _authoredBodyPhraseRule('click here to claim');
    final evaluator = RuleEvaluator(
      ruleSet: RuleSet(version: '1.0', settings: const {}, rules: [rule]),
      safeSenderList: SafeSenderList(safeSenders: []),
      compiler: PatternCompiler(),
      silent: true,
    );

    test('oracle defers (returns null) -- the only rule is body-only, so '
        'headers alone cannot decide', () async {
      final oracle = await evaluator.evaluateWithoutBody(_headerOnlyMsg(id: '1'));
      expect(oracle, isNull,
          reason: 'a body-only rule set must always defer to the full body');
    });

    test('full evaluate on a MATCHING body deletes via the authored rule',
        () async {
      final headerOnly = _headerOnlyMsg(id: '2');
      final oracle = await evaluator.evaluateWithoutBody(headerOnly);
      expect(oracle, isNull);

      final full = await evaluator.evaluate(
          _withBody(headerOnly, 'Please Click Here To Claim your prize now'));
      expect(full.shouldDelete, isTrue);
      expect(full.matchedRule, rule.name);
    });

    test('full evaluate on a NON-matching body does not match', () async {
      final headerOnly = _headerOnlyMsg(id: '3');
      final oracle = await evaluator.evaluateWithoutBody(headerOnly);
      expect(oracle, isNull);

      final full =
          await evaluator.evaluate(_withBody(headerOnly, 'nothing relevant in this body'));
      expect(full.shouldDelete, isFalse);
    });

    test('staged evaluation (oracle-then-full) is equivalent to a direct '
        'full evaluate for both matching and non-matching bodies', () async {
      Future<void> expectStagedEquivalent(String id, String body) async {
        final headerOnly = _headerOnlyMsg(id: id);
        final oracle = await evaluator.evaluateWithoutBody(headerOnly);
        final staged = oracle ?? await evaluator.evaluate(_withBody(headerOnly, body));
        final direct = await evaluator.evaluate(_withBody(headerOnly, body));
        expect(staged.matchedRule, direct.matchedRule);
        expect(staged.shouldDelete, direct.shouldDelete);
      }

      await expectStagedEquivalent('4', 'act now and click here to claim');
      await expectStagedEquivalent('5', 'a perfectly ordinary email');
    });
  });
}
