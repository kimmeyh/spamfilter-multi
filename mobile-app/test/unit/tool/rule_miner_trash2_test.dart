// F308 (Sprint 83): tests for the rule miner trash2 mode (tool/rule_miner/
// trash_miner_core.dart). Every record is a small in-memory fixture. No real
// mail and no database are read.
//
// ADR-0042: developer tool on Harold's Windows PC only. The matching engine
// (RuleEvaluator, PatternCompiler) is the shared one both apps use, unchanged.
// There is no Android path for the tool; the YAML it writes imports on both
// apps through the existing import (covered by the YAML tests, not here).
//
// What these tests do NOT catch: the real Trash2 folder (10,000 messages of
// mixed encodings, HTML-only bodies and AOL quirks) and the IMAP probe itself.
// The probe is a scratch script; its read-only property is asserted in the
// script (EXAMINE before any fetch) and recorded in docs/research/
// F308_TRASH2_MINING.md, not tested here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:path/path.dart' as p;

import '../../../tool/rule_eval/rule_eval_core.dart';
import '../../../tool/rule_miner/trash_miner_core.dart';

const String kPhrase = 'limited time offer today';

TrashRecord rec(String mid, String from, String subject,
        {String body = 'plain body', int? dateMs, Map<String, String>? headers}) =>
    TrashRecord(
      messageId: normalizeMessageId(mid),
      from: from,
      subject: subject,
      dateMs: dateMs,
      headers: headers ?? const {},
      body: body,
    );

HistorySample hist(String from, String subject,
        {String body = 'ordinary note',
        String outcome = 'no_rule',
        HistoryLabel label = HistoryLabel.unlabeled,
        String? mid,
        String account = 'acct',
        bool safe = false}) =>
    HistorySample(
      source: 'content_history',
      accountId: account,
      from: from,
      subject: subject,
      body: body,
      headers: const {},
      label: label,
      noRuleLaterDeleted: false,
      messageId: mid,
      outcome: outcome,
    )..fromSafeSender = safe;

History historyOf(List<HistorySample> samples, {List<String> safePatterns = const []}) =>
    History(
      samples: samples,
      safeSenders: SafeSenderList(safeSenders: safePatterns),
      contentHistoryRows: samples.length,
      actionGroups: 0,
      contentHistoryPresent: true,
    );

final RuleSet noRules = RuleSet(version: '1.0', settings: const {}, rules: []);

/// Ten rule-deleted Trash2 emails (history outcome delete) that carry [kPhrase]
/// in the subject, each from a different one-off domain.
({List<TrashRecord> records, List<HistorySample> samples}) positives({int n = 10}) {
  final records = <TrashRecord>[];
  final samples = <HistorySample>[];
  for (var i = 0; i < n; i++) {
    final from = 'u@promo$i.example';
    final subject = '$kPhrase ref$i';
    records.add(rec('pos$i@x', from, subject));
    samples.add(hist(from, subject, outcome: 'delete', mid: 'pos$i@x'));
  }
  return (records: records, samples: samples);
}

/// [total] safe-sender emails with a stored body; the first [hits] carry the phrase.
List<HistorySample> safeMail(int total, int hits) => [
      for (var i = 0; i < total; i++)
        hist('friend$i@family$i.example',
            i < hits ? '$kPhrase from a friend $i' : 'dinner plans $i',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true)
    ];

/// No Rule mail that carries the phrase (so a pass adds new coverage).
List<HistorySample> noRuleMail(int n) => [
      for (var i = 0; i < n; i++)
        hist('n$i@shop$i.example', '$kPhrase sale $i')
    ];

Future<TrashMineResult> run(List<TrashRecord> records, List<HistorySample> samples,
        {RuleSet? rules}) =>
    mineTrashWith(records, historyOf(samples), rules ?? noRules);

ScoredTrash? phraseCandidate(TrashMineResult r) {
  final hits = r.singles.where(
      (s) => s.candidate.kind == TrashKind.subjectPhrase && s.candidate.key == kPhrase);
  return hits.isEmpty ? null : hits.first;
}

void main() {
  group('R-5 dedup', () {
    test('same Message-ID collapses; no Message-ID falls back to From+Date+Subject', () {
      final records = [
        rec('<A@x>', 'a@one.example', 's1'),
        rec('a@x', 'other@two.example', 'different text'), // same id, brackets differ
        rec('', 'b@one.example', 'hello', dateMs: 1000),
        rec('', 'B@one.example', 'Hello', dateMs: 1000), // same From+Date+Subject
        rec('', 'b@one.example', 'hello', dateMs: 2000), // different date: kept
        rec('c@x', 'c@one.example', 'hello', dateMs: 1000), // has an id: kept
      ];
      final d = dedupTrash(records);
      expect(d.kept.length, 4);
      expect(d.droppedCount, 2);
      expect(d.kept.first.from, 'a@one.example', reason: 'the first record wins');
    });

    test('a history row for the same email is replaced by the Trash2 record', () async {
      final pos = positives();
      final dup = [...pos.records, pos.records.first]; // one exact duplicate
      final extra = hist('u@promo0.example', '$kPhrase ref0', outcome: 'no_rule', mid: 'pos0@x');
      final r = await run(dup, [...pos.samples, extra, ...safeMail(20, 0)]);
      expect(r.corpus.trashRaw, 11);
      expect(r.corpus.trashDuplicates, 1);
      // pos0 has two history rows (outcome delete + the no_rule copy): one email.
      expect(r.corpus.historyReplaced, 11);
      expect(r.corpus.count(CorpusGroup.ruleDeleted), 10);
      expect(r.corpus.count(CorpusGroup.noRule), 0,
          reason: 'the no_rule copy of a Trash2 email must not count as No Rule mail');
    });
  });

  group('R-6 hand-deleted group', () {
    test('a Trash2 email no delete rule caught is hand-deleted, not a positive', () async {
      final pos = positives();
      final hand = [
        for (var i = 0; i < 12; i++) rec('h$i@x', 'z@hand$i.example', 'wholly different words $i')
      ];
      final r = await run([...pos.records, ...hand], [...pos.samples, ...safeMail(50, 0)]);
      expect(r.corpus.count(CorpusGroup.ruleDeleted), 10);
      expect(r.corpus.count(CorpusGroup.handDeleted), 12);
    });

    test('a phrase carried only by hand-deleted emails is never mined', () async {
      final pos = positives();
      final hand = [
        for (var i = 0; i < 12; i++)
          rec('h$i@x', 'z@hand$i.example', 'unique handmade phrase here $i')
      ];
      final r = await run([...pos.records, ...hand], [...pos.samples, ...safeMail(50, 0)]);
      expect(r.singles.any((s) => s.candidate.key.contains('unique handmade phrase')),
          isFalse);
    });

    test('hand-deleted hits neither help nor hurt: the verdict is unchanged', () async {
      final pos = positives();
      final base = await run(pos.records, [...pos.samples, ...safeMail(100, 0), ...noRuleMail(3)]);
      final hand = [
        for (var i = 0; i < 30; i++) rec('h$i@x', 'z@hand$i.example', '$kPhrase handmade $i')
      ];
      final withHand = await run([...pos.records, ...hand],
          [...pos.samples, ...safeMail(100, 0), ...noRuleMail(3)]);
      final a = phraseCandidate(base)!, b = phraseCandidate(withHand)!;
      expect(a.score.passes, isTrue);
      expect(b.score.passes, a.score.passes);
      expect(b.score.ruleDeleted, a.score.ruleDeleted, reason: 'positives unchanged');
      expect(b.score.safeSender, a.score.safeSender, reason: 'safe-sender hits unchanged');
      expect(b.score.handDeleted, 30, reason: 'counted for information only');
    });
  });

  group('R-2 threshold', () {
    test('zero safe-sender hits: reported, with new coverage', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(200, 0), ...noRuleMail(4)]);
      final c = phraseCandidate(r)!;
      expect(c.score.ruleDeleted, 10);
      expect(c.score.noRule, 4);
      expect(c.score.safeSender, 0);
      expect(r.reported(r.singles), contains(c));
      expect(r.verifyMismatches, 0, reason: 'fast counts equal the real RuleEvaluator');
    });

    test('hits within both limits (1 of 200 = 0.5 percent) still pass', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(200, 1), ...noRuleMail(2)]);
      final c = phraseCandidate(r)!;
      expect(c.score.safeSender, 1);
      expect(c.score.safeRate, closeTo(kSafeHitRateMax, 1e-12));
      expect(c.score.passes, isTrue);
    });

    test('more than $kSafeHitsMax hits fail even when the share is small', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(2000, 3), ...noRuleMail(2)]);
      final c = phraseCandidate(r)!;
      expect(c.score.safeRate!, lessThan(kSafeHitRateMax)); // 0.15 percent
      expect(c.score.passes, isFalse);
      expect(r.reported(r.singles), isNot(contains(c)));
    });

    test('a share above the limit fails even with only 2 hits', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(100, 2), ...noRuleMail(2)]);
      final c = phraseCandidate(r)!;
      expect(c.score.safeSender, 2);
      expect(c.score.passes, isFalse); // 2 percent
    });

    test('a candidate that cannot be checked on any safe-sender mail is not reported', () async {
      // Safe-sender mail exists but has no stored body: a body candidate has no
      // denominator, so it must not pass as "clean".
      final noBodySafe = [
        for (var i = 0; i < 50; i++)
          hist('f$i@fam$i.example', 'dinner $i',
              body: '', label: HistoryLabel.kept, outcome: 'safe_sender', safe: true)
      ];
      final withBody = [
        for (var i = 0; i < 10; i++)
          rec('pb$i@x', 'u@bodyco$i.example', 'subject number $i',
              body: 'please verify your account password immediately xyz$i')
      ];
      final samples = [
        for (var i = 0; i < 10; i++)
          hist('u@bodyco$i.example', 'subject number $i', outcome: 'delete', mid: 'pb$i@x'),
        ...noBodySafe,
        for (var i = 0; i < 3; i++)
          hist('m$i@mk$i.example', 'x $i',
              body: 'please verify your account password immediately q$i'),
      ];
      final r = await run(withBody, samples);
      final b = r.singles.firstWhere((s) =>
          s.candidate.kind == TrashKind.bodyPhrase &&
          s.candidate.key.contains('verify your account password'));
      expect(b.score.safeCheckable, 0);
      expect(b.score.passes, isFalse);
    });

    test('fewer than $kTrashMinSupport rule-deleted matches never pass', () async {
      final pos = positives(n: 4);
      final r = await run(pos.records, [...pos.samples, ...safeMail(100, 0), ...noRuleMail(3)]);
      expect(phraseCandidate(r), isNull, reason: 'support below the floor is not even generated');
    });

    test('a pass that adds no coverage is counted but not reported', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(200, 0)]);
      final c = phraseCandidate(r)!;
      expect(c.score.passes, isTrue);
      expect(c.score.newCoverage, 0);
      expect(r.reported(r.singles), isNot(contains(c)));
    });
  });

  group('classification of the positives', () {
    test('a current delete rule that matches a Trash2 email makes it rule-deleted', () async {
      final records = [
        for (var i = 0; i < 6; i++) rec('r$i@x', 'a$i@caught.example', 'hello $i'),
        rec('s@x', 'someone@other.example', 'hello'),
      ];
      final rules = RuleSet(version: '1.0', settings: const {}, rules: [
        Rule(
            name: 'Caught',
            enabled: true,
            isLocal: true,
            executionOrder: 1,
            conditions: RuleConditions(
                type: 'OR', header: [r'@(?:[a-z0-9-]+\.)*caught\.example$']),
            actions: RuleActions(delete: true)),
        Rule(
            name: 'NotDelete',
            enabled: true,
            isLocal: true,
            executionOrder: 2,
            conditions: RuleConditions(
                type: 'OR', header: [r'@(?:[a-z0-9-]+\.)*other\.example$']),
            actions: RuleActions(delete: false)),
      ]);
      final r = await run(records, [...safeMail(10, 0)], rules: rules);
      expect(r.corpus.count(CorpusGroup.ruleDeleted), 6);
      expect(r.corpus.count(CorpusGroup.handDeleted), 1,
          reason: 'a rule that does not delete does not make a positive');
    });

    test('a Trash2 email from a current safe sender is safe-sender mail', () async {
      final h = historyOf([], safePatterns: [r'^[^@\s]+@family\.example$']);
      final r = await mineTrashWith(
          [rec('f@x', 'mom@family.example', 'hi')], h, noRules);
      expect(r.corpus.count(CorpusGroup.safeSender), 1);
      expect(r.corpus.count(CorpusGroup.ruleDeleted), 0);
    });
  });

  group('R-3 kinds and AND combinations', () {
    test('sender shape keeps a 3-letter prefix and rejects shorter ones', () {
      final s = localPartShape('News_12345@any.example')!;
      expect(s.pattern, r'^news_[0-9]+@');
      expect(RegExp(s.pattern).hasMatch('news_777@other.example'), isTrue);
      expect(localPartShape('ab_12@x.example'), isNull);
      expect(localPartShape('plainname@x.example'), isNull);
    });

    test('an AND pair is reported only when neither part passes alone', () async {
      // Subject phrase P: 10 positives + 5 safe hits (safe set A).
      // Body url U: the same 10 positives + 5 other safe hits (safe set B).
      // Together: 10 positives, 0 safe hits.
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'u@promo$i.example';
        records.add(rec('and$i@x', from, '$kPhrase ref$i',
            body: 'see https://track.adhost.example/c$i for details'));
        samples.add(hist(from, '$kPhrase ref$i', outcome: 'delete', mid: 'and$i@x'));
      }
      for (var i = 0; i < 100; i++) {
        final inA = i < 5, inB = i >= 5 && i < 10;
        samples.add(hist('friend$i@fam$i.example',
            inA ? '$kPhrase from a friend $i' : 'dinner plans $i',
            body: inB ? 'link https://track.adhost.example/f$i here' : 'family news $i',
            label: HistoryLabel.kept,
            outcome: 'safe_sender',
            safe: true));
      }
      for (var i = 0; i < 3; i++) {
        samples.add(hist('n$i@shop$i.example', '$kPhrase sale $i',
            body: 'visit https://track.adhost.example/n$i now'));
      }
      final r = await run(records, samples);
      final p = phraseCandidate(r)!;
      final u = r.singles.firstWhere((s) =>
          s.candidate.kind == TrashKind.bodyUrlDomain &&
          s.candidate.key == 'adhost.example');
      expect(p.score.passes, isFalse);
      expect(u.score.passes, isFalse);
      final pair = r.combos.firstWhere((s) =>
          s.candidate.key == '${p.candidate.id}+${u.candidate.id}' ||
          s.candidate.key == '${u.candidate.id}+${p.candidate.id}');
      expect(pair.score.ruleDeleted, 10);
      expect(pair.score.safeSender, 0);
      expect(pair.score.noRule, 3);
      expect(pair.score.passes, isTrue);
      expect(r.reported(r.combos), contains(pair));
      expect(r.verifyMismatches, 0);
      final yaml = renderTrashYaml(r.reported(r.combos));
      expect(yaml, contains("type: 'AND'"));
      expect(yaml, contains('subject:'));
      expect(yaml, contains('body:'));
    });

    test('a pair matching fewer than the support floor is not built', () async {
      // Phrase on positives 0-6 and URL on positives 3-9: each has 7, both fail
      // alone on 5 safe-sender hits, and together they match only 4 (3-6).
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'u@promo$i.example';
        final subject = i <= 6 ? '$kPhrase ref$i' : 'plain words here $i';
        final body = i >= 3 ? 'see https://track.adhost.example/c$i now' : 'plain body $i';
        records.add(rec('fl$i@x', from, subject, body: body));
        samples.add(hist(from, subject, outcome: 'delete', mid: 'fl$i@x'));
      }
      for (var i = 0; i < 100; i++) {
        samples.add(hist('friend$i@fam$i.example',
            i < 5 ? '$kPhrase from a friend $i' : 'dinner plans $i',
            body: (i >= 5 && i < 10) ? 'link https://track.adhost.example/f$i' : 'family $i',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true));
      }
      final r = await run(records, samples);
      final p = phraseCandidate(r)!;
      final u = r.singles.firstWhere((s) =>
          s.candidate.kind == TrashKind.bodyUrlDomain && s.candidate.key == 'adhost.example');
      expect(p.score.ruleDeleted, 7);
      expect(u.score.ruleDeleted, 7);
      expect(p.score.passes || u.score.passes, isFalse);
      expect(r.combos.every((c) => c.score.ruleDeleted >= kTrashMinSupport), isTrue);
      expect(
          r.combos.any((c) =>
              c.candidate.key == '${p.candidate.id}+${u.candidate.id}' ||
              c.candidate.key == '${u.candidate.id}+${p.candidate.id}'),
          isFalse,
          reason: 'the pair matches 4 positives, below the floor of $kTrashMinSupport');
    });

    test('a part that passes alone is never paired', () async {
      // The sender shape sale# passes alone (no safe-sender hit). The phrase
      // fails alone (5 safe-sender hits). A pair of the two would pass, but
      // the shape is already reportable on its own, so no pair is built.
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'sale$i@shop.example';
        records.add(rec('pp$i@x', from, '$kPhrase ref$i'));
        samples.add(hist(from, '$kPhrase ref$i', outcome: 'delete', mid: 'pp$i@x'));
      }
      for (var i = 0; i < 100; i++) {
        samples.add(hist('friend$i@fam$i.example',
            i < 5 ? '$kPhrase from a friend $i' : 'dinner plans $i',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true));
      }
      for (var i = 0; i < 3; i++) {
        samples.add(hist('sale9$i@other$i.example', '$kPhrase sale $i'));
      }
      final r = await run(records, samples);
      final shape = r.singles.firstWhere((s) => s.candidate.kind == TrashKind.senderShape);
      final phrase = phraseCandidate(r)!;
      expect(shape.score.passes, isTrue);
      expect(phrase.score.passes, isFalse);
      expect(
          r.combos.any((c) => c.candidate.key.split('+').contains(shape.candidate.id)),
          isFalse);
    });

    test('two parts in the same field are never combined', () async {
      // Phrase A is on all 10 positives, phrase B on the first 8 only, so the
      // two have different match sets (no collapse) and both fail on the 10
      // safe-sender emails that carry both. Without the same-field rule an
      // A+B pair of 8 positives would appear.
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'u@promo$i.example';
        final subject = i < 8 ? '$kPhrase ref$i special deal inside' : '$kPhrase ref$i';
        records.add(rec('sf$i@x', from, subject));
        samples.add(hist(from, subject, outcome: 'delete', mid: 'sf$i@x'));
      }
      for (var i = 0; i < 100; i++) {
        samples.add(hist('friend$i@fam$i.example',
            i < 10 ? '$kPhrase special deal inside $i' : 'dinner plans $i',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true));
      }
      samples.addAll(noRuleMail(2));
      final r = await run(records, samples);
      final a = phraseCandidate(r)!;
      final b = r.singles.firstWhere((s) =>
          s.candidate.kind == TrashKind.subjectPhrase &&
          s.candidate.key == 'special deal inside');
      expect(a.score.passes, isFalse);
      expect(b.score.passes, isFalse);
      expect(a.score.ruleDeleted, 10);
      expect(b.score.ruleDeleted, 8);
      for (final c in r.combos) {
        final fields = c.candidate.parts.map((x) => x.field).toList();
        expect(fields.toSet().length, fields.length);
      }
    });

    test('candidates with identical matched emails collapse to the simplest', () async {
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'u@promo$i.example';
        records.add(rec('cl$i@x', from, 'subject number $i',
            body: 'see https://track.adhost.example/c$i for details'));
        samples.add(hist(from, 'subject number $i', outcome: 'delete', mid: 'cl$i@x'));
      }
      samples.addAll(safeMail(100, 0));
      final r = await run(records, samples);
      expect(
          r.singles.any((s) =>
              s.candidate.kind == TrashKind.bodyUrlDomain &&
              s.candidate.key == 'adhost.example'),
          isTrue);
      expect(
          r.singles.any((s) =>
              s.candidate.kind == TrashKind.bodyPhrase &&
              s.candidate.key.contains('adhost example')),
          isFalse,
          reason: 'the body phrase matches exactly the same emails as the URL domain');
      expect(r.rejected['same matched emails as a simpler candidate'], greaterThan(0));
    });

    test('a phrase carrying an account name is never a candidate', () async {
      final records = <TrashRecord>[];
      final samples = <HistorySample>[];
      for (var i = 0; i < 10; i++) {
        final from = 'u@promo$i.example';
        final subject = 'dear zebracorn your account is locked ref$i';
        records.add(rec('ac$i@x', from, subject));
        samples.add(hist(from, subject,
            outcome: 'delete', mid: 'ac$i@x', account: 'zebracorn@aol.example'));
      }
      samples.addAll(safeMail(100, 0));
      final r = await run(records, samples);
      expect(r.singles.any((s) => s.candidate.key.contains('zebracorn')), isFalse);
      expect(r.singles.any((s) => s.candidate.key.contains('your account is locked')),
          isTrue,
          reason: 'the rest of the subject is still mined');
      expect(r.rejected['phrase contains an account name'], greaterThan(0));
    });
  });

  group('input and output', () {
    test('readTrashJsonl round-trips a record and lowercases header names', () {
      final dir = Directory.systemTemp.createTempSync('trash_jsonl_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File(p.join(dir.path, 't.jsonl'));
      f.writeAsStringSync('${jsonEncode({
            'message_id': '<Abc@X>',
            'from': 'a@b.example',
            'subject': 'hi',
            'date_ms': 5,
            'headers': {'Reply-To': 'r@s.example'},
            'body': 'text'
          })}\n\n');
      final out = readTrashJsonl(f.path);
      expect(out.length, 1);
      expect(out.single.messageId, 'abc@x');
      expect(out.single.headers['reply-to'], 'r@s.example');
    });

    test('the report states the threshold and hides phrase text by default', () async {
      final pos = positives();
      final r = await run(pos.records, [...pos.samples, ...safeMail(200, 0), ...noRuleMail(4)]);
      final hidden = renderTrashReport(r);
      expect(hidden, contains('at most $kSafeHitsMax emails'));
      expect(hidden, contains('0.50%'));
      expect(hidden, isNot(contains(kPhrase)));
      expect(renderTrashReport(r, showPhrases: true), contains(kPhrase));
    });

    test('an output path under the live app data folder is refused', () {
      expect(
          () => writeTrashOutput(
              p.join('C:', 'live', 'MyEmailSpamFilter', 'out.yaml'), 'x',
              appData: 'C:\\live'),
          throwsStateError);
    });
  });
}
