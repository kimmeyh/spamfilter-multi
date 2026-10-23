/// F268 (Sprint 80): PC-side rule miner.
///
/// Proposes delete rules (sender domain, subject phrase, body phrase) from mail
/// that the CURRENT rules do not already catch, then scores every proposal with
/// the F267 harness core before anything is written. Reads COPIES of the
/// Windows DEV databases only, never writes to a database, and keeps its output
/// on the PC. It is a developer tool: nothing here is app code, and its output
/// is never bundled into app seed data (README.md beside this file).
library;

import 'dart:convert';
import 'dart:io';

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:path/path.dart' as p;

import '../rule_eval/rule_eval_core.dart';

/// Smallest number of distinct unmatched deleted emails that must share a
/// domain or phrase before it is a candidate.
const int kMinSupport = 3;

/// Cap per candidate kind, ranked by recall-base support then support.
const int kMaxPerKind = 120;

/// Phrase length limits, in words. Subject phrases never go below three words.
const int kSubjectMinWords = 3;
const int kSubjectMaxWords = 5;
const int kBodyMinWords = 4;
const int kBodyMaxWords = 6;

/// Body text beyond this many characters is ignored (bounds the work).
const int kBodyChars = 4000;

enum CandidateKind { domain, subject, body }

/// One proposed rule, before scoring.
class MinedCandidate {
  MinedCandidate({
    required this.id,
    required this.kind,
    required this.key,
    required this.pattern,
    required this.words,
    required this.support,
    required this.recallSupport,
  });

  /// Short id such as D001, S004, B002. Safe to print.
  final String id;
  final CandidateKind kind;

  /// The domain (kind domain) or the space-joined phrase (kind subject/body).
  final String key;

  /// The regex written into the rule.
  final String pattern;

  /// Word count for phrases; label count for domains.
  final int words;

  /// Distinct unmatched deleted emails that carry it.
  final int support;

  /// Of those, emails in the "No Rule later deleted" recall base.
  final int recallSupport;

  String get ruleName {
    switch (kind) {
      case CandidateKind.domain:
        return 'MinedDomain_${key.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
      case CandidateKind.subject:
        return 'MinedSubject_$id';
      case CandidateKind.body:
        return 'MinedBody_$id';
    }
  }

  Rule toRule(int order) {
    return Rule(
      name: ruleName,
      enabled: true,
      isLocal: true,
      executionOrder: order,
      conditions: RuleConditions(
        type: 'OR',
        header: kind == CandidateKind.domain ? [pattern] : const [],
        subject: kind == CandidateKind.subject ? [pattern] : const [],
        body: kind == CandidateKind.body ? [pattern] : const [],
      ),
      actions: RuleActions(delete: true),
    );
  }
}

/// A candidate with its F267 report.
class ScoredCandidate {
  ScoredCandidate(this.candidate, this.report);
  final MinedCandidate candidate;
  final RuleReport report;

  bool get passes => report.passes;

  /// Precision 1.0, no safe-sender hit, no pattern problem, a delete rule, and
  /// the ONLY failed check is the volume floor (fewer than 20 labeled matches).
  bool get nearMiss =>
      !report.passes &&
      report.labeledMatches > 0 &&
      report.precision == 1.0 &&
      report.safeSenderHits == 0 &&
      report.patternProblems.isEmpty &&
      report.deletes &&
      report.labeledMatches < kMinLabeledMatches;
}

/// The result of one mining run.
class MinerResult {
  MinerResult({
    required this.history,
    required this.poolSize,
    required this.poolRecall,
    required this.poolUserOrFold,
    required this.currentRuleCount,
    required this.generated,
    required this.rejectedBeforeScoring,
    required this.scored,
  });

  final History history;

  /// Deleted-labeled, not matched by any current rule, not from a safe sender.
  final int poolSize;

  /// Of the pool, how many are in the recall base.
  final int poolRecall;

  /// Of the pool, how many came from content_history (have a body).
  final int poolUserOrFold;
  final int currentRuleCount;
  final Map<CandidateKind, int> generated;
  final Map<String, int> rejectedBeforeScoring;
  final List<ScoredCandidate> scored;

  List<ScoredCandidate> get passed => scored.where((s) => s.passes).toList();
  List<ScoredCandidate> get nearMisses => scored.where((s) => s.nearMiss).toList();
  List<ScoredCandidate> get failed =>
      scored.where((s) => !s.passes && !s.nearMiss).toList();
}

// ---------------------------------------------------------------------------
// Guards (R-2)
// ---------------------------------------------------------------------------

/// Big shared mailbox providers: a domain wildcard on one of these would hit
/// every ordinary sender, so it is never proposed.
const Set<String> kSharedProviders = {
  'gmail.com', 'googlemail.com', 'yahoo.com', 'aol.com', 'outlook.com',
  'hotmail.com', 'live.com', 'msn.com', 'icloud.com', 'me.com', 'mac.com',
  'comcast.net', 'verizon.net', 'att.net', 'sbcglobal.net', 'protonmail.com',
  'proton.me', 'mail.com', 'gmx.com', 'zoho.com', 'yandex.com',
};

const Set<String> _secondLevel = {
  'co', 'com', 'org', 'net', 'gov', 'edu', 'ac', 'or', 'ne', 'go'
};

/// Words that carry no meaning on their own.
const Set<String> _stop = {
  'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'with', 'at',
  'by', 'from', 'is', 'are', 'be', 'it', 'this', 'that', 'you', 'your', 'we',
  'our', 'as', 'if', 'so', 'do', 'i', 'my', 'me', 're', 'fw', 'fwd', 'not',
  'no', 'has', 'have', 'will', 'can', 'all', 'more', 'new', 'now', 'get',
};

/// Reason the candidate is too broad to propose, or null when it is acceptable.
/// Every candidate goes through this before scoring, and a test feeds it
/// hand-made over-broad candidates directly (T-4).
String? overBroadReason(MinedCandidate c) {
  switch (c.kind) {
    case CandidateKind.domain:
      final labels = c.key.split('.');
      if (labels.length < 2 || labels.any((l) => l.isEmpty)) {
        return 'domain has fewer than two labels (TLD only)';
      }
      if (kSharedProviders.contains(c.key)) {
        return 'shared mailbox provider domain';
      }
      if (labels.length == 2 && _secondLevel.contains(labels.first) &&
          labels.last.length == 2) {
        return 'public suffix, not a registered domain';
      }
      return null;
    case CandidateKind.subject:
      if (c.words < kSubjectMinWords) {
        return 'subject phrase shorter than $kSubjectMinWords words';
      }
      return _phraseWeak(c.key);
    case CandidateKind.body:
      if (c.words < kBodyMinWords) {
        return 'body phrase shorter than $kBodyMinWords words';
      }
      return _phraseWeak(c.key);
  }
}

String? _phraseWeak(String phrase) {
  final words = phrase.split(' ');
  final meaningful =
      words.where((w) => !_stop.contains(w) && !RegExp(r'^[0-9]+$').hasMatch(w));
  if (meaningful.length < 2) return 'phrase has fewer than two meaningful words';
  return null;
}

// ---------------------------------------------------------------------------
// Mining
// ---------------------------------------------------------------------------

/// Base (registered) domain of a From value, or null when none can be read.
String? baseDomainOf(String from) {
  final m = RegExp(r'@([a-z0-9][a-z0-9.-]*)>?\s*$').firstMatch(from.toLowerCase().trim());
  if (m == null) return null;
  final labels = m.group(1)!.split('.').where((l) => l.isNotEmpty).toList();
  if (labels.length < 2) return null;
  if (labels.every((l) => RegExp(r'^[0-9]+$').hasMatch(l))) return null; // IP
  var take = 2;
  if (labels.length >= 3 &&
      labels.last.length == 2 &&
      _secondLevel.contains(labels[labels.length - 2])) {
    take = 3;
  }
  return labels.sublist(labels.length - take).join('.');
}

/// `@(?:[a-z0-9-]+\.)*example\.com$` for [domain].
String domainPattern(String domain) =>
    '@(?:[a-z0-9-]+\\.)*${domain.split('.').map(RegExp.escape).join('\\.')}\$';

/// Lowercase ASCII word tokens; leading reply/forward markers removed.
List<String> tokenize(String text) {
  var t = text.toLowerCase();
  t = t.replaceFirst(RegExp(r'^\s*((re|fw|fwd)\s*:\s*)+'), '');
  return RegExp(r'[a-z0-9]+').allMatches(t).map((m) => m.group(0)!).toList();
}

String phrasePattern(String phrase) =>
    '\\b${phrase.split(' ').map(RegExp.escape).join('[^a-z0-9]+')}\\b';

class _Sample {
  _Sample(this.s, this.tokensSubject, this.tokensBody);
  final HistorySample s;
  final List<String> tokensSubject;
  final List<String> tokensBody;
}

/// Mines one run. [dbDir] is a COPY folder; a live path throws [StateError].
Future<MinerResult> mine(String dbDir, {String? appData}) async {
  final history = await loadHistory(dbDir, appData: appData);
  final current = await loadCurrentRules(dbDir);

  // R-1: which history emails do the current rules already catch?
  final evaluator = RuleEvaluator(
    ruleSet: current,
    safeSenderList: SafeSenderList(safeSenders: []),
    compiler: PatternCompiler(),
    silent: true,
  );
  final pool = <_Sample>[];
  for (final s in history.samples) {
    if (s.label != HistoryLabel.deleted || s.fromSafeSender) continue;
    final result = await evaluator.evaluate(s.toMessage());
    if (result.matchedRule.isNotEmpty) continue; // a current rule catches it
    pool.add(_Sample(s, tokenize(s.subject),
        tokenize(s.body.length > kBodyChars ? s.body.substring(0, kBodyChars) : s.body)));
  }

  final existingPatterns = <String>{};
  for (final r in current.rules) {
    existingPatterns
      ..addAll(r.conditions.from.map((x) => x.toLowerCase()))
      ..addAll(r.conditions.header.map((x) => x.toLowerCase()))
      ..addAll(r.conditions.subject.map((x) => x.toLowerCase()))
      ..addAll(r.conditions.body.map((x) => x.toLowerCase()));
  }

  final rejected = <String, int>{};
  void reject(String reason) => rejected[reason] = (rejected[reason] ?? 0) + 1;

  final keptSubjectTokens = history.samples
      .where((s) => s.label == HistoryLabel.kept)
      .map((s) => ' ${tokenize(s.subject).join(' ')} ')
      .toList();
  final keptBodyTokens = history.samples
      .where((s) => s.label == HistoryLabel.kept && s.body.isNotEmpty)
      .map((s) => ' ${tokenize(s.body.length > kBodyChars ? s.body.substring(0, kBodyChars) : s.body).join(' ')} ')
      .toList();

  final candidates = <MinedCandidate>[];
  final generated = <CandidateKind, int>{};

  // --- domains ---
  final domainEmails = <String, List<_Sample>>{};
  for (final x in pool) {
    final d = baseDomainOf(x.s.from);
    if (d != null) domainEmails.putIfAbsent(d, () => []).add(x);
  }
  var domainCands = <MinedCandidate>[];
  domainEmails.forEach((d, list) {
    if (list.length < kMinSupport) return;
    domainCands.add(MinedCandidate(
      id: '',
      kind: CandidateKind.domain,
      key: d,
      pattern: domainPattern(d),
      words: d.split('.').length,
      support: list.length,
      recallSupport: list.where((e) => e.s.noRuleLaterDeleted).length,
    ));
  });
  generated[CandidateKind.domain] = domainCands.length;
  candidates.addAll(_rankAndId(domainCands, 'D', existingPatterns, reject, null));

  // --- phrases ---
  for (final kind in [CandidateKind.subject, CandidateKind.body]) {
    final isSubject = kind == CandidateKind.subject;
    final minW = isSubject ? kSubjectMinWords : kBodyMinWords;
    final maxW = isSubject ? kSubjectMaxWords : kBodyMaxWords;
    final support = <String, Set<int>>{};
    for (var i = 0; i < pool.length; i++) {
      final toks = isSubject ? pool[i].tokensSubject : pool[i].tokensBody;
      if (toks.isEmpty) continue;
      for (var n = minW; n <= maxW; n++) {
        for (var j = 0; j + n <= toks.length; j++) {
          final g = toks.sublist(j, j + n).join(' ');
          support.putIfAbsent(g, () => <int>{}).add(i);
        }
      }
    }
    support.removeWhere((_, v) => v.length < kMinSupport);
    // Keep the most specific phrase: drop a phrase when a one-word-longer phrase
    // that starts or ends with it has the same support.
    final dropped = <String>{};
    final byFirst = <String, List<String>>{};
    for (final g in support.keys) {
      final w = g.split(' ');
      if (w.length > minW) {
        byFirst.putIfAbsent(w.sublist(0, w.length - 1).join(' '), () => []).add(g);
        byFirst.putIfAbsent(w.sublist(1).join(' '), () => []).add(g);
      }
    }
    for (final entry in byFirst.entries) {
      final shorter = support[entry.key];
      if (shorter == null) continue;
      for (final longer in entry.value) {
        if (support[longer]!.length == shorter.length) {
          dropped.add(entry.key);
          break;
        }
      }
    }
    final cands = <MinedCandidate>[];
    support.forEach((g, set) {
      if (dropped.contains(g)) return;
      cands.add(MinedCandidate(
        id: '',
        kind: kind,
        key: g,
        pattern: phrasePattern(g),
        words: g.split(' ').length,
        support: set.length,
        recallSupport: set.where((i) => pool[i].s.noRuleLaterDeleted).length,
      ));
    });
    generated[kind] = cands.length;
    final kept = isSubject ? keptSubjectTokens : keptBodyTokens;
    candidates.addAll(_rankAndId(cands, isSubject ? 'S' : 'B', existingPatterns,
        reject, (c) => kept.any((t) => t.contains(' ${c.key} '))
            ? 'phrase appears in kept mail' : null));
  }

  // R-3: score with the F267 core. Same bar, nothing relaxed.
  final scored = await scoreMined(candidates, history);

  return MinerResult(
    history: history,
    poolSize: pool.length,
    poolRecall: pool.where((x) => x.s.noRuleLaterDeleted).length,
    poolUserOrFold: pool.where((x) => x.s.source == 'content_history').length,
    currentRuleCount: current.rules.length,
    generated: generated,
    rejectedBeforeScoring: rejected,
    scored: scored,
  );
}

/// Scores [candidates] with the F267 core, plus the F266 check for domain
/// candidates (see [_withF266]).
Future<List<ScoredCandidate>> scoreMined(
    List<MinedCandidate> candidates, History history) async {
  if (candidates.isEmpty) return [];
  final ruleSet = RuleSet(version: '1.0', settings: const {}, rules: [
    for (var i = 0; i < candidates.length; i++) candidates[i].toRule((i + 1) * 10)
  ]);
  final reports = await scoreCandidates(ruleSet, history);
  final byName = {for (final r in reports) r.name: r};
  return [
    for (final c in candidates)
      ScoredCandidate(c, _withF266(c, byName[c.ruleName]!))
  ];
}

/// The F267 core applies the F266 dead-pattern check to `from` patterns only.
/// A domain candidate lives in `header`, so the F266 check is run here too.
RuleReport _withF266(MinedCandidate c, RuleReport r) {
  if (c.kind != CandidateKind.domain) return r;
  final dead = PatternCompiler.detectUnmatchable(c.pattern);
  if (dead.isEmpty) return r;
  return RuleReport(
    name: r.name,
    deletes: r.deletes,
    matches: r.matches,
    deletedMatches: r.deletedMatches,
    keptMatches: r.keptMatches,
    unlabeledMatches: r.unlabeledMatches,
    safeSenderHits: r.safeSenderHits,
    recallHits: r.recallHits,
    recallTotal: r.recallTotal,
    patternProblems: [...r.patternProblems, 'pattern can never match an address (F266)'],
  );
}

/// Applies the guard and the pre-filters, ranks (recall support first, then
/// support, then key), caps at [kMaxPerKind] and assigns ids.
List<MinedCandidate> _rankAndId(
  List<MinedCandidate> raw,
  String prefix,
  Set<String> existingPatterns,
  void Function(String) reject,
  String? Function(MinedCandidate)? extra,
) {
  final ok = <MinedCandidate>[];
  for (final c in raw) {
    final broad = overBroadReason(c);
    if (broad != null) {
      reject(broad);
      continue;
    }
    if (existingPatterns.contains(c.pattern.toLowerCase())) {
      reject('pattern already in a current rule');
      continue;
    }
    final more = extra?.call(c);
    if (more != null) {
      reject(more);
      continue;
    }
    ok.add(c);
  }
  ok.sort((a, b) {
    final r = b.recallSupport.compareTo(a.recallSupport);
    if (r != 0) return r;
    final s = b.support.compareTo(a.support);
    if (s != 0) return s;
    return a.key.compareTo(b.key);
  });
  final capped = ok.take(kMaxPerKind).toList();
  return [
    for (var i = 0; i < capped.length; i++)
      MinedCandidate(
        id: '$prefix${(i + 1).toString().padLeft(3, '0')}',
        kind: capped[i].kind,
        key: capped[i].key,
        pattern: capped[i].pattern,
        words: capped[i].words,
        support: capped[i].support,
        recallSupport: capped[i].recallSupport,
      )
  ];
}

/// Current rules from the copy's `rules` table, every rule treated as enabled
/// (a rule the user disabled still counts as "the current rules know this").
Future<RuleSet> loadCurrentRules(String dbDir) async {
  final db = await openReadOnly(p.join(dbDir, 'spam_filter.db'));
  try {
    final rows = await db.rawQuery(
        'SELECT name, execution_order, condition_type, condition_from, '
        'condition_header, condition_subject, condition_body, action_delete, '
        'exception_from, exception_header, exception_subject, exception_body '
        'FROM rules ORDER BY execution_order, id');
    List<String> list(Object? v) {
      if (v == null) return const [];
      try {
        final d = jsonDecode(v as String);
        if (d is List) return d.whereType<String>().toList();
      } on FormatException {
        // A malformed column counts as no conditions, as in the app.
      }
      return const [];
    }

    final rules = <Rule>[];
    var order = 0;
    for (final r in rows) {
      final hasEx = r['exception_from'] != null ||
          r['exception_header'] != null ||
          r['exception_subject'] != null ||
          r['exception_body'] != null;
      rules.add(Rule(
        name: r['name'] as String,
        enabled: true,
        isLocal: true,
        executionOrder: order++,
        conditions: RuleConditions(
          type: (r['condition_type'] as String?) ?? 'OR',
          from: list(r['condition_from']),
          header: list(r['condition_header']),
          subject: list(r['condition_subject']),
          body: list(r['condition_body']),
        ),
        actions: RuleActions(delete: (r['action_delete'] as int?) == 1),
        exceptions: hasEx
            ? RuleExceptions(
                from: list(r['exception_from']),
                header: list(r['exception_header']),
                subject: list(r['exception_subject']),
                body: list(r['exception_body']),
              )
            : null,
      ));
    }
    return RuleSet(version: '1.0', settings: const {}, rules: rules);
  } finally {
    await db.close();
  }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

String _q(String v) => "'${v.replaceAll("'", "''")}'";

/// The importable YAML (docs/RULE_FORMAT.md shape): PASS candidates only.
String renderYaml(List<ScoredCandidate> passed) {
  final b = StringBuffer()
    ..writeln('# Proposed by tool/rule_miner (F268). Review before import.')
    ..writeln('# PASS candidates only. Generated from private mail history:')
    ..writeln('# keep this file on your PC; do not commit it or bundle it.')
    ..writeln("version: '1.0'")
    ..writeln('settings: {}');
  if (passed.isEmpty) {
    b.writeln('rules: []');
    return b.toString();
  }
  b.writeln('rules:');
  var order = 0;
  for (final s in passed) {
    final c = s.candidate;
    order += 10;
    b
      ..writeln('- name: ${_q(c.ruleName)}')
      ..writeln("  enabled: 'True'")
      ..writeln("  isLocal: 'True'")
      ..writeln('  executionOrder: $order')
      ..writeln('  conditions:')
      ..writeln("    type: 'OR'")
      ..writeln('    from: []')
      ..writeln(c.kind == CandidateKind.domain
          ? '    header:\n    - ${_q(c.pattern)}'
          : '    header: []')
      ..writeln(c.kind == CandidateKind.subject
          ? '    subject:\n    - ${_q(c.pattern)}'
          : '    subject: []')
      ..writeln(c.kind == CandidateKind.body
          ? '    body:\n    - ${_q(c.pattern)}'
          : '    body: []')
      ..writeln('  actions:')
      ..writeln('    delete: true');
  }
  return b.toString();
}

/// The side report. Counts, ids and domains only: never email text. A phrase
/// candidate is listed by id; a PASS phrase is in the YAML, not here.
String renderMinerReport(MinerResult r) {
  final b = StringBuffer();
  String name(ScoredCandidate s) => s.candidate.kind == CandidateKind.domain
      ? '${s.candidate.id} domain ${s.candidate.key}'
      : '${s.candidate.id} ${s.candidate.kind.name} phrase (${s.candidate.words} words)';
  String line(ScoredCandidate s) {
    final rep = s.report;
    return '${name(s)}: support=${s.candidate.support} '
        '(recall base ${s.candidate.recallSupport}) matches=${rep.matches} '
        'deleted=${rep.deletedMatches} kept=${rep.keptMatches} '
        'unlabeled=${rep.unlabeledMatches} safe-sender hits=${rep.safeSenderHits} '
        'precision=${rep.precision == null ? "n/a" : rep.precision!.toStringAsFixed(4)}';
  }

  final h = r.history;
  b.writeln('Rule miner report (F268)');
  b.writeln('History: ${h.samples.length} emails; current rules read: ${r.currentRuleCount}');
  b.writeln('Mining pool (deleted label, no current rule matches, not a current '
      'safe sender): ${r.poolSize} emails, ${r.poolRecall} in the No Rule later '
      'deleted recall base, ${r.poolUserOrFold} with a stored body');
  b.writeln('Generated: domain=${r.generated[CandidateKind.domain] ?? 0} '
      'subject=${r.generated[CandidateKind.subject] ?? 0} '
      'body=${r.generated[CandidateKind.body] ?? 0}; scored=${r.scored.length}');
  if (r.rejectedBeforeScoring.isNotEmpty) {
    b.writeln('Rejected before scoring (counts):');
    final keys = r.rejectedBeforeScoring.keys.toList()..sort();
    for (final k in keys) {
      b.writeln('  ${r.rejectedBeforeScoring[k]}  $k');
    }
  }
  b.writeln('Bar: zero safe-sender hits AND precision >= $kMinPrecision on >= '
      '$kMinLabeledMatches labeled matches (F267).');
  b.writeln('');
  b.writeln('PASS: ${r.passed.length} (written to the YAML)');
  for (final s in r.passed) {
    b.writeln('  ${line(s)}');
  }
  b.writeln('');
  b.writeln('NEAR MISS: ${r.nearMisses.length} (precision 1.0, fewer than '
      '$kMinLabeledMatches labeled matches; NOT written to the YAML)');
  for (final s in r.nearMisses) {
    b.writeln('  ${line(s)}');
  }
  b.writeln('');
  b.writeln('FAIL: ${r.failed.length}');
  for (final s in r.failed) {
    b.writeln('  ${line(s)}');
    for (final reason in s.report.failReasons) {
      b.writeln('    reason: $reason');
    }
  }
  return b.toString();
}

/// Refusal for an OUTPUT path under the live app data folder (R-4).
String? liveOutputRefusal(String path, {String? appData}) =>
    liveDatabaseRefusal(path, appData: appData);

/// Writes [text] to [path] after the live-path refusal. Throws [StateError].
void writeOutput(String path, String text, {String? appData}) {
  final refusal = liveOutputRefusal(path, appData: appData);
  if (refusal != null) throw StateError(refusal);
  File(path).writeAsStringSync(text);
}
