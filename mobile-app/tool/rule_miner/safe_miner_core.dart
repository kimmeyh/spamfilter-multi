/// F310 (Sprint 83): safe-sender mining mode for the rule miner.
///
/// The mirror of the F308 trash2 mode. It learns what mail from safe senders
/// has in common that delete-rule mail does not (a sender domain with several
/// authenticated emails, reply threads, transactional subjects, few links, no
/// bulk-mail header, a long sender history), then scores each candidate
/// against the delete-rule mail in the same corpus.
///
/// R-3 (AC-2): every safe-sender suggestion REQUIRES the authentication gate
/// ([kGateAuthClass]). A [SafeCandidate] carries `gated`; [SafeMineResult.reported]
/// and [renderSafeYaml] drop every candidate whose `gated` is false, whatever
/// its score. Content alone never suggests a safe sender.
///
/// THE GATE IS A PROXY. Only the stored class (`content_history.auth_class`:
/// green, yellow, red, grey) exists in stored data. `green` means every
/// SPF/DKIM/DMARC method that returned a verdict passed and at least one did
/// (lib/core/services/auth_results_parser.dart `classify`). It does NOT prove
/// DMARC itself passed: a mail with SPF pass and no DMARC record is green. The
/// runtime suggestion (F270) must test DMARC pass from the raw
/// Authentication-Results header.
///
/// UNKNOWN AUTH IS RISK. A delete-rule email whose auth class is unknown (a
/// Trash2 email with no history row) is counted as a spam hit when its content
/// matches, because the gate cannot be shown to stop it (Sprint 82 IMP-4: a
/// check that did not run must not make a candidate look safe).
///
/// R-4: report only. Nothing is imported or applied; nothing here writes to a
/// database or a mailbox.
///
/// ADR-0042: Windows DEV developer tool only. No Android path for the tool; the
/// patterns it suggests are ordinary safe-sender regexes that both apps import
/// through the existing import.
library;

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';

import '../rule_eval/rule_eval_core.dart';
import 'rule_miner_core.dart';
import 'trash_miner_core.dart';

/// The stored auth class a safe-sender suggestion requires (R-3).
const String kGateAuthClass = 'green';

/// Smallest number of gated safe-sender emails a candidate must match.
const int kSafeMinSupport = 5;

/// A candidate is reported only when it hits delete-rule mail on at most this
/// many emails ... (same bound as the F308 safe-side bound, Task 7)
const int kSpamHitsMax = kSafeHitsMax;

/// ... and at most this share of the delete-rule mail it could be checked on.
const double kSpamHitRateMax = kSafeHitRateMax;

/// "Few tracking links": at most this many http(s) links in the body.
const int kFewLinksMax = 2;

/// "Long sender history": a sender domain seen on at least this many emails ...
const int kHistoryMinMails = 5;

/// ... spread over at least this many days.
const int kHistoryMinSpanDays = 90;

/// Transactional subject words (fixed list, so the signal is reproducible).
const String kTransactionalPattern =
    r'\b(?:order|receipt|invoice|statement|confirmation|confirmed|password|'
    r'verification|verify|shipped|shipping|delivery|delivered|appointment|'
    r'reservation|payment|billing|booking|itinerary|ticket)\b';

/// A subject that is a reply or forward in a thread.
const String kReplyPattern = r'^\s*(?:re|aw|sv)\s*:';

enum SafeKind {
  senderDomain,
  replyThread,
  transactionalSubject,
  fewLinks,
  noListUnsubscribe,
  longHistory,
  and,
}

/// True for mail a delete rule caught: the Trash2 positives, plus history mail
/// whose outcome was `delete` (R-2: the spam pool).
bool isSpamEntry(CorpusEntry e) =>
    e.group == CorpusGroup.ruleDeleted ||
    (e.group == CorpusGroup.other && e.outcome == 'delete');

bool isSafeEntry(CorpusEntry e) => e.group == CorpusGroup.safeSender;

/// The bare address of a From value ("Name <a@b.example>" gives "a@b.example").
String addressOf(String from) {
  final m = RegExp(r'<([^<>]+)>\s*$').firstMatch(from.trim());
  return (m != null ? m.group(1)! : from).trim().toLowerCase();
}

/// Per-domain history facts, from every email in the corpus with a date.
class SafeContext {
  SafeContext(this.domainMails, this.domainSpanDays);

  final Map<String, int> domainMails;
  final Map<String, int> domainSpanDays;

  factory SafeContext.of(Corpus corpus) {
    final count = <String, int>{};
    final first = <String, int>{};
    final last = <String, int>{};
    for (final e in corpus.entries) {
      final d = baseDomainOf(addressOf(e.from));
      final t = e.receivedAtMs;
      if (d == null || t == null) continue;
      count[d] = (count[d] ?? 0) + 1;
      if (first[d] == null || t < first[d]!) first[d] = t;
      if (last[d] == null || t > last[d]!) last[d] = t;
    }
    return SafeContext(count, {
      for (final d in count.keys) d: ((last[d]! - first[d]!) ~/ 86400000)
    });
  }
}

/// One condition. Several are ANDed in a [SafeCandidate].
class SafeFeature {
  SafeFeature({
    required this.id,
    required this.kind,
    required this.key,
    required this.test,
    this.needsBody = false,
    this.needsHeaders = false,
    this.pattern,
  });

  final String id;
  final SafeKind kind;
  final String key;
  final bool Function(CorpusEntry, SafeContext) test;
  final bool needsBody;
  final bool needsHeaders;

  /// The safe-sender regex, for a sender-domain feature only.
  final String? pattern;

  bool checkable(CorpusEntry e) =>
      (!needsBody || e.hasBody) && (!needsHeaders || e.hasHeaders);
}

/// A safe-sender candidate: features ANDed, plus the auth gate when [gated].
class SafeCandidate {
  SafeCandidate({
    required this.id,
    required this.kind,
    required this.features,
    required this.gated,
  });

  final String id;
  final SafeKind kind;
  final List<SafeFeature> features;

  /// R-3: true when the candidate requires [kGateAuthClass]. Only a gated
  /// candidate can be a suggestion.
  final bool gated;

  bool get isSuggestion => gated;
  String get key => features.map((f) => f.key).join(' + ');
  String? get safePattern =>
      features.length == 1 ? features.first.pattern : null;

  bool checkable(CorpusEntry e) => features.every((f) => f.checkable(e));

  bool _contentMatches(CorpusEntry e, SafeContext c) =>
      features.every((f) => f.test(e, c));

  /// Safe-sender mail this candidate matches: the gate must be PROVEN.
  bool matchesSafe(CorpusEntry e, SafeContext c) =>
      checkable(e) &&
      (!gated || e.authClass == kGateAuthClass) &&
      _contentMatches(e, c);

  /// Delete-rule mail this candidate could let through: the gate stops mail
  /// whose class is known and not green, never mail whose class is unknown.
  bool matchesSpamRisk(CorpusEntry e, SafeContext c) =>
      checkable(e) &&
      (!gated || e.authClass == kGateAuthClass || e.authClass == null) &&
      _contentMatches(e, c);
}

class SafeScore {
  SafeScore({
    required this.safeHits,
    required this.safeEligible,
    required this.spamHits,
    required this.spamUnknownAuthHits,
    required this.spamCheckable,
    required this.noRuleHits,
    required this.noRuleCheckable,
  });

  /// Safe-sender emails matched (gate proven when gated).
  final int safeHits;

  /// Safe-sender emails the candidate could be checked on.
  final int safeEligible;

  /// Delete-rule emails matched, counting unknown-auth mail as a hit.
  final int spamHits;

  /// Of [spamHits], the emails whose auth class is unknown.
  final int spamUnknownAuthHits;

  /// Delete-rule emails the candidate could be checked on.
  final int spamCheckable;

  final int noRuleHits;
  final int noRuleCheckable;

  double? get spamRate => spamCheckable == 0 ? null : spamHits / spamCheckable;

  /// The threshold alone (the gate is applied by [ScoredSafe.passes]).
  bool get meetsThreshold {
    if (safeHits < kSafeMinSupport) return false;
    final rate = spamRate;
    if (rate == null) return false; // could not be checked is not "clean"
    return spamHits <= kSpamHitsMax && rate <= kSpamHitRateMax;
  }
}

class ScoredSafe {
  ScoredSafe(this.candidate, this.score, {this.alreadyCovered = false});
  final SafeCandidate candidate;
  final SafeScore score;

  /// True when a CURRENT safe-sender pattern already matches the candidate's
  /// sender domain, so a suggestion would add nothing for that domain.
  final bool alreadyCovered;

  /// R-3 / AC-2: a candidate without the gate never passes.
  bool get passes => candidate.isSuggestion && score.meetsThreshold;
}

SafeScore scoreSafe(Corpus corpus, SafeContext ctx, SafeCandidate c) {
  var safe = 0, safeEl = 0, spam = 0, unk = 0, spamCk = 0, nr = 0, nrCk = 0;
  for (final e in corpus.entries) {
    if (!c.checkable(e)) continue;
    if (isSafeEntry(e)) {
      safeEl++;
      if (c.matchesSafe(e, ctx)) safe++;
    } else if (isSpamEntry(e)) {
      spamCk++;
      if (c.matchesSpamRisk(e, ctx)) {
        spam++;
        if (e.authClass == null) unk++;
      }
    } else if (e.group == CorpusGroup.noRule) {
      nrCk++;
      if (c.matchesSpamRisk(e, ctx)) nr++;
    }
  }
  return SafeScore(
      safeHits: safe,
      safeEligible: safeEl,
      spamHits: spam,
      spamUnknownAuthHits: unk,
      spamCheckable: spamCk,
      noRuleHits: nr,
      noRuleCheckable: nrCk);
}

// ---------------------------------------------------------------------------
// Candidates
// ---------------------------------------------------------------------------

/// The fixed signal features (R-1). Regex signals compile through the app's
/// [PatternCompiler] and test the subject, as a rule condition would.
List<SafeFeature> signalFeatures(PatternCompiler compiler) {
  final reply = compiler.compile(kReplyPattern);
  final trans = compiler.compile(kTransactionalPattern);
  final url = RegExp(r'https?://');
  return [
    SafeFeature(
        id: 'S1',
        kind: SafeKind.replyThread,
        key: 'reply thread subject',
        test: (e, c) => reply.hasMatch(e.subject)),
    SafeFeature(
        id: 'S2',
        kind: SafeKind.transactionalSubject,
        key: 'transactional subject word',
        test: (e, c) => trans.hasMatch(e.subject)),
    SafeFeature(
        id: 'S3',
        kind: SafeKind.fewLinks,
        key: 'at most $kFewLinksMax links in the body',
        needsBody: true,
        test: (e, c) => url.allMatches(e.body).length <= kFewLinksMax),
    SafeFeature(
        id: 'S4',
        kind: SafeKind.noListUnsubscribe,
        key: 'no List-Unsubscribe header',
        needsHeaders: true,
        test: (e, c) => !e.headers.containsKey('list-unsubscribe')),
    SafeFeature(
        id: 'S5',
        kind: SafeKind.longHistory,
        key: 'sender domain seen $kHistoryMinMails+ times over $kHistoryMinSpanDays+ days',
        test: (e, c) {
          final d = baseDomainOf(addressOf(e.from));
          if (d == null) return false;
          return (c.domainMails[d] ?? 0) >= kHistoryMinMails &&
              (c.domainSpanDays[d] ?? 0) >= kHistoryMinSpanDays;
        }),
  ];
}

/// Candidates: each signal alone, each pair of signals, and one per sender
/// domain with enough gated safe-sender mail. All are gated (R-3).
List<SafeCandidate> generateSafeCandidates(
    Corpus corpus, PatternCompiler compiler,
    {Map<String, int>? rejected}) {
  void reject(String why) {
    if (rejected != null) rejected[why] = (rejected[why] ?? 0) + 1;
  }

  final signals = signalFeatures(compiler);
  final out = <SafeCandidate>[];
  for (final s in signals) {
    out.add(SafeCandidate(id: s.id, kind: s.kind, features: [s], gated: true));
  }
  var n = 0;
  for (var i = 0; i < signals.length; i++) {
    for (var j = i + 1; j < signals.length; j++) {
      n++;
      out.add(SafeCandidate(
          id: 'P${n.toString().padLeft(2, '0')}',
          kind: SafeKind.and,
          features: [signals[i], signals[j]],
          gated: true));
    }
  }

  // Sender domains: distinct gated safe-sender emails per base domain.
  final perDomain = <String, int>{};
  for (final e in corpus.entries) {
    if (!isSafeEntry(e) || e.authClass != kGateAuthClass) continue;
    final d = baseDomainOf(addressOf(e.from));
    if (d != null) perDomain[d] = (perDomain[d] ?? 0) + 1;
  }
  final domains = perDomain.keys.where((d) => perDomain[d]! >= kSafeMinSupport).toList()
    ..sort();
  var k = 0;
  for (final d in domains) {
    final why = domainGuard(d);
    if (why != null) {
      reject(why);
      continue;
    }
    k++;
    final pattern = domainPattern(d);
    final re = compiler.compile(pattern);
    out.add(SafeCandidate(
        id: 'D${k.toString().padLeft(3, '0')}',
        kind: SafeKind.senderDomain,
        features: [
          SafeFeature(
              id: 'D${k.toString().padLeft(3, '0')}',
              kind: SafeKind.senderDomain,
              key: d,
              pattern: pattern,
              test: (e, c) => re.hasMatch(addressOf(e.from)))
        ],
        gated: true));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Mining run
// ---------------------------------------------------------------------------

class SafeMineResult {
  SafeMineResult({
    required this.corpus,
    required this.scored,
    required this.signalScores,
    required this.rejected,
    required this.contentOnlyPass,
    required this.gateOnlyPass,
    required this.verifyMismatches,
  });

  final Corpus corpus;
  final List<ScoredSafe> scored;

  /// Per-signal rates for the learning table (R-1), keyed by feature key.
  final List<SignalRow> signalScores;
  final Map<String, int> rejected;

  /// Candidates whose CONTENT alone meets the threshold. They are not
  /// suggestions (R-3); the count shows what the gate refuses to pass.
  final int contentOnlyPass;

  /// Candidates that meet the threshold only because of the gate.
  final int gateOnlyPass;
  final int verifyMismatches;

  /// R-3 / AC-2: reported suggestions are gated and meet the threshold.
  List<ScoredSafe> get reported => scored
      .where((s) => s.passes)
      .toList()
    ..sort((a, b) {
      final h = b.score.safeHits.compareTo(a.score.safeHits);
      return h != 0 ? h : a.candidate.id.compareTo(b.candidate.id);
    });
}

class SignalRow {
  SignalRow(this.key, this.safeHits, this.safeEligible, this.noRuleHits,
      this.noRuleCheckable, this.spamHits, this.spamCheckable);
  final String key;
  final int safeHits, safeEligible, noRuleHits, noRuleCheckable, spamHits, spamCheckable;
}

Future<SafeMineResult> mineSafe(List<TrashRecord> records, String dbDir,
    {String? appData}) async {
  final history = await loadHistory(dbDir, appData: appData);
  final current = await loadCurrentRules(dbDir);
  return mineSafeWith(records, history, current);
}

/// The same run with the history and rules already loaded (tests use this).
Future<SafeMineResult> mineSafeWith(
    List<TrashRecord> records, History history, RuleSet current) async {
  final corpus = await buildCorpus(
      records: records, history: history, currentRules: current);
  final compiler = PatternCompiler();
  final ctx = SafeContext.of(corpus);
  final rejected = <String, int>{};
  final candidates = generateSafeCandidates(corpus, compiler, rejected: rejected);

  final scored = [
    for (final c in candidates)
      ScoredSafe(c, scoreSafe(corpus, ctx, c),
          alreadyCovered: c.safePattern != null &&
              history.safeSenders.findMatch('probe@${c.features.first.key}') != null)
  ];

  // What the gate refuses: the same candidates without it.
  var contentOnly = 0, gateOnly = 0;
  for (final s in scored) {
    final ungated = SafeCandidate(
        id: s.candidate.id,
        kind: s.candidate.kind,
        features: s.candidate.features,
        gated: false);
    final u = scoreSafe(corpus, ctx, ungated);
    if (u.meetsThreshold) contentOnly++;
    if (s.passes && !u.meetsThreshold) gateOnly++;
  }

  final rows = <SignalRow>[];
  for (final s in scored.where((s) => s.candidate.kind != SafeKind.senderDomain && s.candidate.features.length == 1)) {
    rows.add(SignalRow(
        s.candidate.key,
        s.score.safeHits,
        s.score.safeEligible,
        s.score.noRuleHits,
        s.score.noRuleCheckable,
        s.score.spamHits,
        s.score.spamCheckable));
  }

  final result = SafeMineResult(
    corpus: corpus,
    scored: scored,
    signalScores: rows,
    rejected: rejected,
    contentOnlyPass: contentOnly,
    gateOnlyPass: gateOnly,
    verifyMismatches: 0,
  );
  final mismatches = _verifyDomains(result.reported, corpus, ctx);
  return SafeMineResult(
    corpus: corpus,
    scored: scored,
    signalScores: rows,
    rejected: rejected,
    contentOnlyPass: contentOnly,
    gateOnlyPass: gateOnly,
    verifyMismatches: mismatches,
  );
}

/// Reported domain candidates are re-checked with the app's own
/// [SafeSenderList]: its match must equal the fast regex match on every email.
int _verifyDomains(List<ScoredSafe> reported, Corpus corpus, SafeContext ctx) {
  var mismatches = 0;
  for (final s in reported) {
    final pattern = s.candidate.safePattern;
    if (pattern == null) continue;
    final list = SafeSenderList(safeSenders: [pattern]);
    for (final e in corpus.entries) {
      final real = list.findMatch(addressOf(e.from)) != null;
      final fast = s.candidate.features.first.test(e, ctx);
      if (real != fast) {
        mismatches++;
        break;
      }
    }
  }
  return mismatches;
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

String _q(String v) => "'${v.replaceAll("'", "''")}'";

/// Candidate YAML (rules_safe_senders.yaml shape): REPORTED sender-domain
/// candidates only (R-3: a gated, passing candidate). Sender domains come from
/// private mail, so the file stays on the developer PC.
String renderSafeYaml(List<ScoredSafe> reported) {
  final b = StringBuffer()
    ..writeln('# Proposed by tool/rule_miner safe mode (F310). Review before import.')
    ..writeln('# Each entry is a suggestion ONLY for mail that also passes DMARC.')
    ..writeln('# The safe_senders list cannot express that condition: do not import')
    ..writeln('# these as plain safe senders without it.')
    ..writeln('# Generated from private mail: keep this file on your PC.');
  final patterns = [
    for (final s in reported)
      if (s.passes && s.candidate.safePattern != null) s.candidate.safePattern!
  ];
  if (patterns.isEmpty) {
    b.writeln('safe_senders: []');
  } else {
    b.writeln('safe_senders:');
    for (final p in patterns) {
      b.writeln('- ${_q(p)}');
    }
  }
  return b.toString();
}

String _pct(num a, num b) =>
    b == 0 ? 'n/a' : '${(a / b * 100).toStringAsFixed(2)}%';

/// The report text. Domain names are hidden unless [showDomains].
String renderSafeReport(SafeMineResult r, {bool showDomains = false}) {
  final c = r.corpus;
  final spam = c.entries.where(isSpamEntry).length;
  final safe = c.entries.where(isSafeEntry).length;
  final gated = c.entries.where((e) => isSafeEntry(e) && e.authClass == kGateAuthClass).length;
  final spamKnownAuth = c.entries.where((e) => isSpamEntry(e) && e.authClass != null).length;
  final b = StringBuffer();
  b.writeln('Safe-sender mining report (F310)');
  b.writeln('Corpus: ${c.entries.length} emails. delete-rule (spam pool) $spam, '
      'of which auth class known $spamKnownAuth; safe-sender $safe, of which '
      'gate-proven ($kGateAuthClass) $gated; No Rule ${c.count(CorpusGroup.noRule)}');
  b.writeln('Gate (R-3): the stored auth class must be "$kGateAuthClass". This is a '
      'PROXY: stored data has the class only, not a DMARC verdict.');
  b.writeln('Threshold (R-2): a candidate is reported when it matches at least '
      '$kSafeMinSupport gate-proven safe-sender emails and hits delete-rule mail '
      'on at most $kSpamHitsMax emails AND at most ${(kSpamHitRateMax * 100).toStringAsFixed(2)}% '
      'of the delete-rule mail it could be checked on. Delete-rule mail with an '
      'unknown auth class counts as a hit when its content matches.');
  b.writeln('Content-only candidates that meet the threshold but are NOT suggestions '
      '(R-3): ${r.contentOnlyPass}. Candidates that meet it only because of the gate: ${r.gateOnlyPass}.');
  if (r.rejected.isNotEmpty) {
    b.writeln('Rejected before scoring (counts):');
    final keys = r.rejected.keys.toList()..sort();
    for (final k in keys) {
      b.writeln('  ${r.rejected[k]}  $k');
    }
  }
  b.writeln('Verification: ${r.verifyMismatches} reported domain candidate(s) differ '
      'between the fast match and the real SafeSenderList (must be 0).');
  b.writeln('');
  b.writeln('Signals (R-1), gate applied to safe-sender mail:');
  for (final s in r.signalScores) {
    b.writeln('  ${s.key}: safe ${s.safeHits}/${s.safeEligible} (${_pct(s.safeHits, s.safeEligible)}); '
        'No Rule ${s.noRuleHits}/${s.noRuleCheckable} (${_pct(s.noRuleHits, s.noRuleCheckable)}); '
        'delete-rule ${s.spamHits}/${s.spamCheckable} (${_pct(s.spamHits, s.spamCheckable)})');
  }
  final rep = r.reported;
  final domains = rep.where((s) => s.candidate.kind == SafeKind.senderDomain).toList();
  final others = rep.where((s) => s.candidate.kind != SafeKind.senderDomain).toList();
  final covered = domains.where((s) => s.alreadyCovered).length;
  final gain = domains.where((s) => !s.alreadyCovered && s.score.noRuleHits > 0).length;
  b.writeln('');
  b.writeln('Scored ${r.scored.length} candidates; ${rep.length} reported '
      '(${domains.length} sender domains, ${others.length} signal conditions).');
  b.writeln('Of the ${domains.length} reported domains: $covered are already matched by '
      'a current safe-sender pattern; $gain are not and would cover No Rule mail.');
  String line(ScoredSafe s) {
    final sc = s.score;
    final what = (s.candidate.kind == SafeKind.senderDomain && !showDomains)
        ? '(domain hidden)'
        : s.candidate.key;
    return '${s.candidate.id} ${s.candidate.kind.name} $what: safe=${sc.safeHits}/${sc.safeEligible} '
        'delete=${sc.spamHits}/${sc.spamCheckable} (unknown-auth ${sc.spamUnknownAuthHits}) '
        'noRule=${sc.noRuleHits}/${sc.noRuleCheckable}'
        '${s.alreadyCovered ? ' [already a safe sender]' : ''}';
  }

  for (final s in others) {
    b.writeln('  ${line(s)}');
  }
  for (final s in domains) {
    b.writeln('  ${line(s)}');
  }
  return b.toString();
}

/// Refusal for an OUTPUT path under the live app data folder (R-4).
void writeSafeOutput(String path, String text, {String? appData}) =>
    writeOutput(path, text, appData: appData);
