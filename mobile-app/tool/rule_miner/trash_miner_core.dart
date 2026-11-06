/// F308 (Sprint 83): Trash2 mining mode for the rule miner.
///
/// Learns what the mail in the DEV AOL "Trash2" folder that a delete rule
/// caught has in common, then scores each candidate (single part and AND
/// combination) against No Rule mail and safe-sender mail from the DEV history.
/// A candidate is reported only when it almost never hits a safe sender
/// ([kSafeHitRateMax] and [kSafeHitsMax]).
///
/// Input is a JSONL file written by the read-only probe (IMAP EXAMINE plus
/// BODY.PEEK, see docs/research/F308_TRASH2_MINING.md) and COPIES of the DEV
/// databases. Output is a report and candidate YAML for the developer. Nothing
/// is imported or applied (R-4), and nothing here writes to a database or to
/// the mailbox. Developer tool, not app code: it is never bundled.
///
/// ADR-0042: Windows DEV developer tool only. There is no Android path for the
/// tool; the YAML it writes imports on both apps through the existing import.
library;

import 'dart:convert';
import 'dart:io';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';

import '../rule_eval/rule_eval_core.dart';
import 'rule_miner_core.dart';

/// A candidate is reported only when its hits on safe-sender mail are at most
/// this share of the safe-sender mail it could be checked on (0.5 percent) ...
const double kSafeHitRateMax = 0.005;

/// ... and at most this many emails, whatever the share.
const int kSafeHitsMax = 2;

/// Smallest number of rule-deleted Trash2 emails a candidate must match.
const int kTrashMinSupport = 5;

/// AND combinations are built from this many of the strongest failing singles.
const int kComboPool = 80;

/// Cap per single-part kind before scoring.
const int kMaxSinglesPerKind = 120;

/// Where a mail record belongs after dedup and classification.
enum CorpusGroup {
  /// In Trash2 and a delete rule matched it (R-2: the positives).
  ruleDeleted,

  /// In Trash2 and no delete rule matched it: deleted by hand (R-6: counted
  /// for information, never for or against a candidate).
  handDeleted,

  /// History mail no rule matched.
  noRule,

  /// Mail from a current safe sender.
  safeSender,

  /// History mail that is none of the above (for example rule-deleted in the
  /// inbox). Not counted either way.
  other,
}

enum TrashField { from, header, subject, body }

enum TrashKind {
  subjectPhrase,
  bodyPhrase,
  bodyUrlDomain,
  senderDomain,
  senderShape,
  headerValue,
  and,
}

/// One email read from Trash2 by the probe.
class TrashRecord {
  TrashRecord({
    required this.messageId,
    required this.from,
    required this.subject,
    required this.dateMs,
    required this.headers,
    required this.body,
  });

  /// Normalized Message-ID (no brackets, lowercase), or null when none.
  final String? messageId;
  final String from;
  final String subject;
  final int? dateMs;
  final Map<String, String> headers;
  final String body;

  factory TrashRecord.fromJson(Map<String, dynamic> j) => TrashRecord(
        messageId: normalizeMessageId(j['message_id'] as String?),
        from: ((j['from'] as String?) ?? '').trim(),
        subject: (j['subject'] as String?) ?? '',
        dateMs: j['date_ms'] as int?,
        headers: {
          for (final e in ((j['headers'] as Map?) ?? const {}).entries)
            (e.key as String).toLowerCase(): e.value as String
        },
        body: (j['body'] as String?) ?? '',
      );
}

/// Reads the probe's JSONL file. A line that is not valid JSON throws.
List<TrashRecord> readTrashJsonl(String path) {
  final out = <TrashRecord>[];
  for (final line in File(path).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    out.add(TrashRecord.fromJson(jsonDecode(line) as Map<String, dynamic>));
  }
  return out;
}

/// R-5: the key that makes two records "the same email": the Message-ID, else
/// From + Date + Subject.
String dedupKey(TrashRecord r) {
  if (r.messageId != null) return 'm|${r.messageId}';
  return 'f|${r.from.toLowerCase().trim()}|${r.dateMs ?? ''}|'
      '${r.subject.toLowerCase().trim()}';
}

class DedupResult {
  DedupResult(this.kept, this.droppedCount);
  final List<TrashRecord> kept;
  final int droppedCount;
}

/// R-5: one record per email. The first record of a key wins.
DedupResult dedupTrash(List<TrashRecord> records) {
  final seen = <String>{};
  final kept = <TrashRecord>[];
  for (final r in records) {
    if (seen.add(dedupKey(r))) kept.add(r);
  }
  return DedupResult(kept, records.length - kept.length);
}

/// One email in the scoring corpus.
class CorpusEntry {
  CorpusEntry({
    required this.group,
    required this.fromTrash,
    required String from,
    required String subject,
    required String body,
    required Map<String, String> headers,
    required this.hasHeaders,
    this.authClass,
    this.receivedAtMs,
    this.outcome = '',
  })  : from = from.toLowerCase().trim(),
        subject = subject.toLowerCase().trim(),
        body = body.toLowerCase().trim(),
        headers = Map.unmodifiable(headers),
        headerTests = [
          from.toLowerCase().trim(),
          for (final e in headers.entries)
            if (e.key.toLowerCase() != 'from')
              '${e.key}:${e.value}'.toLowerCase().trim()
        ];

  final CorpusGroup group;
  final bool fromTrash;
  final String from;
  final String subject;
  final String body;
  final Map<String, String> headers;

  /// True when the header values are real (content history or Trash2). False
  /// for an email_actions-only row, which carries no headers at all.
  final bool hasHeaders;

  /// F310: stored authentication class (`green`, `yellow`, `red`, `grey`), or
  /// null when it is not known (a Trash2 email with no history row).
  final String? authClass;

  /// F310: received time in epoch milliseconds, when known.
  final int? receivedAtMs;

  /// F310: content_history outcome (`delete`, `safe_sender`, `no_rule`), or
  /// empty when unknown.
  final String outcome;

  /// The strings a header pattern is tested against, as the evaluator does.
  final List<String> headerTests;

  bool get hasBody => body.isNotEmpty;

  bool checkable(Set<TrashField> fields) {
    if (fields.contains(TrashField.body) && !hasBody) return false;
    if (fields.contains(TrashField.header) && !hasHeaders) return false;
    return true;
  }

  EmailMessage toMessage() => EmailMessage(
        id: 'corpus:${from.hashCode}:${subject.hashCode}',
        from: from,
        subject: subject,
        body: body,
        headers: {...headers, 'from': from},
        receivedDate: DateTime.fromMillisecondsSinceEpoch(0),
        folderName: 'INBOX',
      );
}

/// The corpus plus the counts the report states.
class Corpus {
  Corpus({
    required this.entries,
    required this.trashRaw,
    required this.trashDuplicates,
    required this.historyReplaced,
    this.accountTokens = const {},
  });

  /// Local parts of the history account ids. A phrase carrying one is a
  /// personal phrase (a greeting or an address), never a rule candidate.
  final Set<String> accountTokens;

  final List<CorpusEntry> entries;
  final int trashRaw;
  final int trashDuplicates;

  /// History rows dropped because the same email is in Trash2 (R-5).
  final int historyReplaced;

  int count(CorpusGroup g) => entries.where((e) => e.group == g).length;
}

String? _fallbackKey(String from, String subject, int? ms) =>
    'f|${from.toLowerCase().trim()}|${subject.toLowerCase().trim()}|'
    '${ms == null ? '' : ms ~/ 86400000}';

/// Builds the corpus (R-5, R-6). [currentRules] decides which Trash2 emails a
/// delete rule caught: those are the positives. Everything else in Trash2 is
/// hand-deleted. A Trash2 email from a current safe sender is safe-sender mail.
Future<Corpus> buildCorpus({
  required List<TrashRecord> records,
  required History history,
  required RuleSet currentRules,
}) async {
  final dedup = dedupTrash(records);

  // Every history row of the same email (an account re-sees it each scan).
  final byMid = <String, List<HistorySample>>{};
  final byFallback = <String, List<HistorySample>>{};
  for (final s in history.samples) {
    if (s.messageId != null) byMid.putIfAbsent(s.messageId!, () => []).add(s);
    byFallback
        .putIfAbsent(_fallbackKey(s.from, s.subject, s.receivedAtMs)!, () => [])
        .add(s);
  }

  final deleteOnly = RuleSet(
      version: '1.0',
      settings: const {},
      rules: currentRules.rules.where((r) => r.actions.delete).toList());
  final evaluator = RuleEvaluator(
    ruleSet: deleteOnly,
    safeSenderList: SafeSenderList(safeSenders: []),
    compiler: PatternCompiler(),
    silent: true,
  );

  final entries = <CorpusEntry>[];
  final replaced = <HistorySample>{};
  for (final r in dedup.kept) {
    final matched = (r.messageId != null ? byMid[r.messageId!] : null) ??
        byFallback[_fallbackKey(r.from, r.subject, r.dateMs)!] ??
        const <HistorySample>[];
    replaced.addAll(matched);
    final historyDeleted = matched.any((s) => s.outcome == 'delete');
    final safe = history.safeSenders.findMatch(r.from) != null;
    final entry = CorpusEntry(
      group: CorpusGroup.handDeleted, // placeholder, set below
      fromTrash: true,
      from: r.from,
      subject: r.subject,
      body: r.body,
      headers: r.headers,
      hasHeaders: true,
    );
    CorpusGroup group;
    if (safe) {
      group = CorpusGroup.safeSender;
    } else if (historyDeleted) {
      group = CorpusGroup.ruleDeleted;
    } else {
      final res = await evaluator.evaluate(entry.toMessage());
      group = res.matchedRule.isNotEmpty
          ? CorpusGroup.ruleDeleted
          : CorpusGroup.handDeleted;
    }
    entries.add(CorpusEntry(
      group: group,
      fromTrash: true,
      from: r.from,
      subject: r.subject,
      body: r.body,
      headers: r.headers,
      hasHeaders: true,
      // F310: the Trash2 read has no auth header; the matching history row
      // (when there is one) carries the stored class.
      authClass: matched.map((s) => s.authClass).whereType<String>().firstOrNull,
      receivedAtMs: r.dateMs,
      outcome: matched.map((s) => s.outcome).where((o) => o.isNotEmpty).firstOrNull ?? '',
    ));
  }

  for (final s in history.samples) {
    if (replaced.contains(s)) continue;
    CorpusGroup group;
    if (s.fromSafeSender || s.label == HistoryLabel.kept) {
      group = CorpusGroup.safeSender;
    } else if (s.outcome == 'no_rule' ||
        (s.outcome.isEmpty &&
            (s.label == HistoryLabel.unlabeled || s.noRuleLaterDeleted))) {
      group = CorpusGroup.noRule;
    } else {
      group = CorpusGroup.other;
    }
    entries.add(CorpusEntry(
      group: group,
      fromTrash: false,
      from: s.from,
      subject: s.subject,
      body: s.body,
      headers: s.headers,
      hasHeaders: s.source == 'content_history',
      authClass: s.authClass,
      receivedAtMs: s.receivedAtMs,
      outcome: s.outcome,
    ));
  }

  return Corpus(
    entries: entries,
    trashRaw: records.length,
    trashDuplicates: dedup.droppedCount,
    historyReplaced: replaced.length,
    accountTokens: {
      for (final s in history.samples)
        for (final t in RegExp(r'[a-z0-9]+')
            .allMatches(s.accountId.toLowerCase().split('@').first)
            .map((m) => m.group(0)!))
          if (t.length >= 4) t
    },
  );
}

// ---------------------------------------------------------------------------
// Candidates
// ---------------------------------------------------------------------------

class TrashPart {
  const TrashPart(this.field, this.pattern);
  final TrashField field;
  final String pattern;
}

/// One candidate: a single part, or an AND of two parts in different fields.
class TrashCandidate {
  TrashCandidate({
    required this.id,
    required this.kind,
    required this.key,
    required this.parts,
  });

  final String id;
  final TrashKind kind;

  /// Domain, shape or phrase. For an AND, the two part ids.
  final String key;
  final List<TrashPart> parts;

  bool get isAnd => parts.length > 1;
  Set<TrashField> get fields => parts.map((p) => p.field).toSet();
  String get ruleName => 'Trash2Mined_$id';

  Rule toRule(int order) {
    List<String> of(TrashField f) =>
        [for (final p in parts) if (p.field == f) p.pattern];
    return Rule(
      name: ruleName,
      enabled: true,
      isLocal: true,
      executionOrder: order,
      conditions: RuleConditions(
        type: isAnd ? 'AND' : 'OR',
        from: of(TrashField.from),
        header: of(TrashField.header),
        subject: of(TrashField.subject),
        body: of(TrashField.body),
      ),
      actions: RuleActions(delete: true),
    );
  }
}

/// Counts of one candidate over the corpus.
class TrashScore {
  TrashScore({
    required this.ruleDeleted,
    required this.handDeleted,
    required this.noRule,
    required this.safeSender,
    required this.safeCheckable,
  });

  final int ruleDeleted;
  final int handDeleted;
  final int noRule;
  final int safeSender;

  /// Safe-sender emails the candidate could be tested on (a body candidate
  /// needs a stored body, a header candidate needs stored headers).
  final int safeCheckable;

  double? get safeRate => safeCheckable == 0 ? null : safeSender / safeCheckable;

  /// New coverage: mail no current rule catches that the candidate would.
  int get newCoverage => noRule + handDeleted;

  /// The R-2 threshold. Needs a checkable safe-sender denominator: a candidate
  /// that could not be checked is not reported (it is not "clean").
  bool get passes {
    if (ruleDeleted < kTrashMinSupport) return false;
    final rate = safeRate;
    if (rate == null) return false;
    return safeSender <= kSafeHitsMax && rate <= kSafeHitRateMax;
  }
}

class ScoredTrash {
  ScoredTrash(this.candidate, this.score, this.matches);
  final TrashCandidate candidate;
  final TrashScore score;

  /// Indexes into [Corpus.entries] that the candidate matches.
  final List<int> matches;
}

TrashScore scoreMatches(Corpus corpus, Set<TrashField> fields, List<int> matches) {
  var del = 0, hand = 0, nr = 0, safe = 0;
  for (final i in matches) {
    switch (corpus.entries[i].group) {
      case CorpusGroup.ruleDeleted:
        del++;
      case CorpusGroup.handDeleted:
        hand++;
      case CorpusGroup.noRule:
        nr++;
      case CorpusGroup.safeSender:
        safe++;
      case CorpusGroup.other:
        break;
    }
  }
  final checkable = corpus.entries
      .where((e) => e.group == CorpusGroup.safeSender && e.checkable(fields))
      .length;
  return TrashScore(
      ruleDeleted: del,
      handDeleted: hand,
      noRule: nr,
      safeSender: safe,
      safeCheckable: checkable);
}

bool _partMatches(RegExp re, TrashField field, CorpusEntry e) {
  switch (field) {
    case TrashField.from:
      return re.hasMatch(e.from);
    case TrashField.subject:
      return re.hasMatch(e.subject);
    case TrashField.body:
      return e.hasBody && re.hasMatch(e.body);
    case TrashField.header:
      return e.hasHeaders && e.headerTests.any(re.hasMatch);
  }
}

/// Entries matching one part, as sorted indexes.
List<int> matchPart(PatternCompiler compiler, Corpus corpus, TrashPart part) {
  final re = compiler.compile(part.pattern);
  final out = <int>[];
  for (var i = 0; i < corpus.entries.length; i++) {
    if (_partMatches(re, part.field, corpus.entries[i])) out.add(i);
  }
  return out;
}

List<int> intersectSorted(List<int> a, List<int> b) {
  final out = <int>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      out.add(a[i]);
      i++;
      j++;
    } else if (a[i] < b[j]) {
      i++;
    } else {
      j++;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Generation (single parts)
// ---------------------------------------------------------------------------

class _Raw {
  _Raw(this.kind, this.key, this.field, this.pattern, this.words);
  final TrashKind kind;
  final String key;
  final TrashField field;
  final String pattern;
  final int words;
}

/// `^prefix[sep]digits@` for a local part such as `news_12345`, else null.
/// The literal prefix must be at least three letters: a shape with a shorter
/// prefix would match far too much.
({String key, String pattern})? localPartShape(String from) {
  final m = RegExp(r'^([a-z0-9._+-]+)@').firstMatch(from.toLowerCase().trim());
  if (m == null) return null;
  final shape = RegExp(r'^([a-z]{3,})([._-]?)([0-9]+)$').firstMatch(m.group(1)!);
  if (shape == null) return null;
  final prefix = shape.group(1)!, sep = shape.group(2)!;
  return (
    key: '$prefix$sep#',
    pattern: '^${RegExp.escape(prefix)}${sep.isEmpty ? '' : RegExp.escape(sep)}[0-9]+@',
  );
}

String _hostPattern(String domain) =>
    'https?://(?:[a-z0-9-]+\\.)*${domain.split('.').map(RegExp.escape).join('\\.')}\\b';

String? domainGuard(String domain) => overBroadReason(MinedCandidate(
    id: '',
    kind: CandidateKind.domain,
    key: domain,
    pattern: '',
    words: domain.split('.').length,
    support: 0,
    recallSupport: 0));

/// All distinct (kind, key) parts carried by [e], each with its pattern.
Iterable<_Raw> _partsOf(CorpusEntry e) sync* {
  final d = baseDomainOf(e.from);
  if (d != null) {
    yield _Raw(TrashKind.senderDomain, d, TrashField.header, domainPattern(d), d.split('.').length);
  }
  final shape = localPartShape(e.from);
  if (shape != null) {
    yield _Raw(TrashKind.senderShape, shape.key, TrashField.from, shape.pattern, 1);
  }
  final hosts = <String>{};
  for (final m in RegExp(r'https?://([a-z0-9][a-z0-9.-]*)').allMatches(e.body)) {
    final base = baseDomainOf('@${m.group(1)}');
    if (base != null) hosts.add(base);
  }
  for (final h in hosts) {
    yield _Raw(TrashKind.bodyUrlDomain, h, TrashField.body, _hostPattern(h), h.split('.').length);
  }
  final reply = e.headers['reply-to'];
  if (reply != null) {
    final rd = baseDomainOf(reply);
    if (rd != null) {
      yield _Raw(TrashKind.headerValue, 'reply-to $rd', TrashField.header,
          '^reply-to:.*@(?:[a-z0-9-]+\\.)*${rd.split('.').map(RegExp.escape).join('\\.')}>?\$', 2);
    }
  }
  final rp = e.headers['return-path'];
  if (rp != null) {
    final rd = baseDomainOf('@$rp');
    if (rd != null) {
      yield _Raw(TrashKind.headerValue, 'return-path $rd', TrashField.header,
          '^return-path:(?:[a-z0-9-]+\\.)*${rd.split('.').map(RegExp.escape).join('\\.')}\$', 2);
    }
  }
  if (e.headers['list-unsubscribe'] == 'present') {
    yield _Raw(TrashKind.headerValue, 'list-unsubscribe present', TrashField.header,
        '^list-unsubscribe:present\$', 1);
  }
}

/// Phrase support over [pool]: phrase -> pool indexes, with a shorter phrase
/// dropped when a one-word-longer phrase has the same support.
Map<String, List<int>> _phraseSupport(
    List<List<String>> tokenLists, int minW, int maxW,
    {Set<String> blocked = const {}, Set<String>? blockedGrams}) {
  final support = <String, List<int>>{};
  for (var i = 0; i < tokenLists.length; i++) {
    final toks = tokenLists[i];
    for (var n = minW; n <= maxW; n++) {
      for (var j = 0; j + n <= toks.length; j++) {
        final window = toks.sublist(j, j + n);
        // An account name inside a phrase makes it personal. It is dropped
        // BEFORE the shorter-phrase pass, so the rest of the subject survives.
        if (window.any(blocked.contains)) {
          blockedGrams?.add(window.join(' '));
          continue;
        }
        final list = support.putIfAbsent(window.join(' '), () => <int>[]);
        if (list.isEmpty || list.last != i) list.add(i);
      }
    }
  }
  support.removeWhere((_, v) => v.length < kTrashMinSupport);
  final dropped = <String>{};
  final shorterOf = <String, List<String>>{};
  for (final g in support.keys) {
    final w = g.split(' ');
    if (w.length > minW) {
      shorterOf.putIfAbsent(w.sublist(0, w.length - 1).join(' '), () => []).add(g);
      shorterOf.putIfAbsent(w.sublist(1).join(' '), () => []).add(g);
    }
  }
  for (final entry in shorterOf.entries) {
    final shorter = support[entry.key];
    if (shorter == null) continue;
    if (entry.value.any((l) => support[l]!.length == shorter.length)) {
      dropped.add(entry.key);
    }
  }
  support.removeWhere((k, _) => dropped.contains(k));
  return support;
}

/// Single-part candidates mined from the rule-deleted Trash2 emails only
/// (R-6: hand-deleted emails are never in the mining pool).
List<TrashCandidate> generateSingles(Corpus corpus,
    {Map<String, int>? rejected}) {
  void reject(String why) {
    if (rejected != null) rejected[why] = (rejected[why] ?? 0) + 1;
  }

  final pool = corpus.entries.where((e) => e.group == CorpusGroup.ruleDeleted).toList();
  final byKey = <String, ({_Raw raw, Set<int> idx})>{};
  for (var i = 0; i < pool.length; i++) {
    for (final raw in _partsOf(pool[i])) {
      final k = '${raw.kind.index}|${raw.key}';
      final cur = byKey.putIfAbsent(k, () => (raw: raw, idx: <int>{}));
      cur.idx.add(i);
    }
  }
  final raws = <_Raw, int>{};
  byKey.forEach((_, v) {
    if (v.idx.length >= kTrashMinSupport) raws[v.raw] = v.idx.length;
  });

  // Phrases.
  for (final isSubject in [true, false]) {
    final tokens = [
      for (final e in pool)
        isSubject
            ? tokenize(e.subject)
            : tokenize(e.body.length > kBodyChars ? e.body.substring(0, kBodyChars) : e.body)
    ];
    final minW = isSubject ? kSubjectMinWords : kBodyMinWords;
    final maxW = isSubject ? kSubjectMaxWords : kBodyMaxWords;
    final blockedGrams = <String>{};
    final support = _phraseSupport(tokens, minW, maxW,
        blocked: corpus.accountTokens, blockedGrams: blockedGrams);
    for (var k = 0; k < blockedGrams.length; k++) {
      reject('phrase contains an account name');
    }
    support.forEach((g, idx) {
      final words = g.split(' ').length;
      raws[_Raw(isSubject ? TrashKind.subjectPhrase : TrashKind.bodyPhrase, g,
          isSubject ? TrashField.subject : TrashField.body, phrasePattern(g), words)] =
          idx.length;
    });
  }

  // Guards, then rank and cap per kind.
  final perKind = <TrashKind, List<MapEntry<_Raw, int>>>{};
  for (final e in raws.entries) {
    final r = e.key;
    String? broad;
    switch (r.kind) {
      case TrashKind.senderDomain || TrashKind.bodyUrlDomain:
        broad = domainGuard(r.key);
      case TrashKind.headerValue:
        final parts = r.key.split(' ');
        if (parts.length == 2 && parts[1].contains('.')) broad = domainGuard(parts[1]);
      case TrashKind.subjectPhrase || TrashKind.bodyPhrase:
        broad = overBroadReason(MinedCandidate(
            id: '',
            kind: r.kind == TrashKind.subjectPhrase
                ? CandidateKind.subject
                : CandidateKind.body,
            key: r.key,
            pattern: '',
            words: r.words,
            support: 0,
            recallSupport: 0));
      default:
        break;
    }
    if (broad != null) {
      reject(broad);
      continue;
    }
    perKind.putIfAbsent(r.kind, () => []).add(e);
  }
  final out = <TrashCandidate>[];
  const prefix = {
    TrashKind.subjectPhrase: 'S',
    TrashKind.bodyPhrase: 'B',
    TrashKind.bodyUrlDomain: 'U',
    TrashKind.senderDomain: 'D',
    TrashKind.senderShape: 'L',
    TrashKind.headerValue: 'H',
  };
  for (final kind in prefix.keys) {
    final list = perKind[kind] ?? [];
    list.sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.key.compareTo(b.key.key);
    });
    final capped = list.take(kMaxSinglesPerKind).toList();
    for (var i = 0; i < capped.length; i++) {
      final r = capped[i].key;
      out.add(TrashCandidate(
        id: '${prefix[kind]}${(i + 1).toString().padLeft(3, '0')}',
        kind: kind,
        key: r.key,
        parts: [TrashPart(r.field, r.pattern)],
      ));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Mining run
// ---------------------------------------------------------------------------

class TrashMineResult {
  TrashMineResult({
    required this.corpus,
    required this.singles,
    required this.combos,
    required this.rejected,
    required this.currentRuleCount,
    required this.f267,
    required this.verifyMismatches,
  });

  final Corpus corpus;
  final List<ScoredTrash> singles;
  final List<ScoredTrash> combos;
  final Map<String, int> rejected;
  final int currentRuleCount;

  /// F267 verdict per listed candidate rule name (the history-only bar).
  final Map<String, RuleReport> f267;

  /// Listed candidates whose fast counts differ from the real RuleEvaluator.
  final int verifyMismatches;

  List<ScoredTrash> get passedSingles => singles.where((s) => s.score.passes).toList();
  List<ScoredTrash> get passedCombos => combos.where((s) => s.score.passes).toList();

  /// Reported: passes the threshold and adds coverage beyond current rules.
  /// Candidates that hit No Rule mail come first; those that only hit
  /// hand-deleted mail follow (information, R-6: they neither help nor hurt).
  List<ScoredTrash> reported(List<ScoredTrash> list) =>
      list.where((s) => s.score.passes && s.score.newCoverage > 0).toList()
        ..sort((a, b) {
          final n = b.score.noRule.compareTo(a.score.noRule);
          if (n != 0) return n;
          final d = b.score.ruleDeleted.compareTo(a.score.ruleDeleted);
          return d != 0 ? d : a.candidate.id.compareTo(b.candidate.id);
        });
}

/// Keeps one candidate per identical set of matched emails: the simplest kind
/// (sender, header, URL, subject, body) and then the shortest key. Sliding
/// windows of one long phrase otherwise fill the report with copies.
List<ScoredTrash> collapseEquivalent(
    List<ScoredTrash> all, Map<String, int> rejected) {
  const priority = {
    TrashKind.senderDomain: 0,
    TrashKind.senderShape: 1,
    TrashKind.headerValue: 2,
    TrashKind.bodyUrlDomain: 3,
    TrashKind.subjectPhrase: 4,
    TrashKind.bodyPhrase: 5,
    TrashKind.and: 6,
  };
  final order = [...all]..sort((a, b) {
      final k = priority[a.candidate.kind]!.compareTo(priority[b.candidate.kind]!);
      if (k != 0) return k;
      final l = a.candidate.key.length.compareTo(b.candidate.key.length);
      return l != 0 ? l : a.candidate.id.compareTo(b.candidate.id);
    });
  final keep = <ScoredTrash>{};
  final seen = <String>{};
  for (final s in order) {
    if (seen.add(s.matches.join(','))) {
      keep.add(s);
    } else {
      const why = 'same matched emails as a simpler candidate';
      rejected[why] = (rejected[why] ?? 0) + 1;
    }
  }
  return [for (final s in all) if (keep.contains(s)) s];
}

/// Mines one run from the dedup-ready [records] and the DB copy in [dbDir].
Future<TrashMineResult> mineTrash(List<TrashRecord> records, String dbDir,
    {String? appData}) async {
  final history = await loadHistory(dbDir, appData: appData);
  final current = await loadCurrentRules(dbDir);
  return mineTrashWith(records, history, current);
}

/// The same run with the history and rules already loaded (tests use this).
Future<TrashMineResult> mineTrashWith(
    List<TrashRecord> records, History history, RuleSet current) async {
  final corpus = await buildCorpus(
      records: records, history: history, currentRules: current);
  final compiler = PatternCompiler();
  final rejected = <String, int>{};
  final candidates = generateSingles(corpus, rejected: rejected);

  final scoredAll = <ScoredTrash>[];
  for (final c in candidates) {
    final m = matchPart(compiler, corpus, c.parts.first);
    scoredAll.add(ScoredTrash(c, scoreMatches(corpus, c.fields, m), m));
  }
  final singles = collapseEquivalent(scoredAll, rejected);

  // AND pairs of different fields, from the strongest singles that fail the
  // threshold alone. A pair is reported only when neither part passes alone.
  final failing = singles
      .where((s) => !s.score.passes && s.score.ruleDeleted >= kTrashMinSupport)
      .toList()
    ..sort((a, b) => b.score.ruleDeleted.compareTo(a.score.ruleDeleted));
  final pool = failing.take(kComboPool).toList();
  final combos = <ScoredTrash>[];
  var n = 0;
  for (var i = 0; i < pool.length; i++) {
    for (var j = i + 1; j < pool.length; j++) {
      final a = pool[i], b = pool[j];
      if (a.candidate.parts.first.field == b.candidate.parts.first.field) continue;
      final m = intersectSorted(a.matches, b.matches);
      final fields = {...a.candidate.fields, ...b.candidate.fields};
      final score = scoreMatches(corpus, fields, m);
      if (score.ruleDeleted < kTrashMinSupport) continue;
      n++;
      combos.add(ScoredTrash(
          TrashCandidate(
            id: 'A${n.toString().padLeft(3, '0')}',
            kind: TrashKind.and,
            key: '${a.candidate.id}+${b.candidate.id}',
            parts: [...a.candidate.parts, ...b.candidate.parts],
          ),
          score,
          m));
    }
  }

  final result = TrashMineResult(
    corpus: corpus,
    singles: singles,
    combos: combos,
    rejected: rejected,
    currentRuleCount: current.rules.length,
    f267: const {},
    verifyMismatches: 0,
  );

  // Verify the listed candidates with the app's own evaluator and the F267 core.
  final listed = [...result.reported(singles), ...result.reported(combos)];
  final verified = await _verify(listed, corpus, history);
  return TrashMineResult(
    corpus: corpus,
    singles: singles,
    combos: combos,
    rejected: rejected,
    currentRuleCount: current.rules.length,
    f267: verified.f267,
    verifyMismatches: verified.mismatches,
  );
}

Future<({Map<String, RuleReport> f267, int mismatches})> _verify(
    List<ScoredTrash> listed, Corpus corpus, History history) async {
  if (listed.isEmpty) return (f267: const <String, RuleReport>{}, mismatches: 0);
  final rules = [for (var i = 0; i < listed.length; i++) listed[i].candidate.toRule((i + 1) * 10)];
  final reports = await scoreCandidates(
      RuleSet(version: '1.0', settings: const {}, rules: rules), history);
  final f267 = {for (final r in reports) r.name: r};

  var mismatches = 0;
  final messages = [for (final e in corpus.entries) e.toMessage()];
  for (var i = 0; i < listed.length; i++) {
    final evaluator = RuleEvaluator(
      ruleSet: RuleSet(version: '1.0', settings: const {}, rules: [rules[i]]),
      safeSenderList: SafeSenderList(safeSenders: []),
      compiler: PatternCompiler(),
      silent: true,
    );
    final real = <int>[];
    for (var k = 0; k < messages.length; k++) {
      final entry = corpus.entries[k];
      if (!entry.checkable(listed[i].candidate.fields)) continue;
      final res = await evaluator.evaluate(messages[k]);
      if (res.matchedRule == rules[i].name) real.add(k);
    }
    final fast = listed[i].matches.where((k) => corpus.entries[k].checkable(listed[i].candidate.fields)).toList();
    if (real.length != fast.length || !_sameList(real, fast)) mismatches++;
  }
  return (f267: f267, mismatches: mismatches);
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

String _q(String v) => "'${v.replaceAll("'", "''")}'";

/// Candidate YAML (docs/RULE_FORMAT.md shape): reported candidates only. It
/// carries phrases from private mail, so it stays on the developer PC.
String renderTrashYaml(List<ScoredTrash> reported) {
  final b = StringBuffer()
    ..writeln('# Proposed by tool/rule_miner trash2 mode (F308). Review before import.')
    ..writeln('# Reported candidates only. Generated from private mail:')
    ..writeln('# keep this file on your PC; do not commit it or bundle it.')
    ..writeln("version: '1.0'")
    ..writeln('settings: {}');
  if (reported.isEmpty) {
    b.writeln('rules: []');
    return b.toString();
  }
  b.writeln('rules:');
  var order = 0;
  for (final s in reported) {
    order += 10;
    final rule = s.candidate.toRule(order);
    void list(String name, List<String> v) {
      if (v.isEmpty) {
        b.writeln('    $name: []');
      } else {
        b.writeln('    $name:');
        for (final x in v) {
          b.writeln('    - ${_q(x)}');
        }
      }
    }

    b
      ..writeln('- name: ${_q(rule.name)}')
      ..writeln("  enabled: 'True'")
      ..writeln("  isLocal: 'True'")
      ..writeln('  executionOrder: $order')
      ..writeln('  conditions:')
      ..writeln('    type: ${_q(rule.conditions.type)}');
    list('from', rule.conditions.from);
    list('header', rule.conditions.header);
    list('subject', rule.conditions.subject);
    list('body', rule.conditions.body);
    b
      ..writeln('  actions:')
      ..writeln('    delete: true');
  }
  return b.toString();
}

String _pct(double? v) => v == null ? 'n/a' : '${(v * 100).toStringAsFixed(2)}%';

/// The report text. [showPhrases] false hides phrase text (ids and counts only);
/// domains, shapes and header values are always shown (they are not mail text).
String renderTrashReport(TrashMineResult r, {bool showPhrases = false}) {
  final c = r.corpus;
  final b = StringBuffer();
  b.writeln('Trash2 mining report (F308)');
  b.writeln('Trash2 emails read: ${c.trashRaw}; duplicates dropped (R-5): '
      '${c.trashDuplicates}; history rows replaced by the same email in Trash2: '
      '${c.historyReplaced}');
  b.writeln('Corpus: ${c.entries.length} emails. rule-deleted (positives) '
      '${c.count(CorpusGroup.ruleDeleted)}; hand-deleted (neutral, R-6) '
      '${c.count(CorpusGroup.handDeleted)}; No Rule ${c.count(CorpusGroup.noRule)}; '
      'safe-sender ${c.count(CorpusGroup.safeSender)}; other '
      '${c.count(CorpusGroup.other)}');
  b.writeln('Current rules read: ${r.currentRuleCount}');
  b.writeln('Threshold (R-2): a candidate is reported when it matches at least '
      '$kTrashMinSupport rule-deleted emails, hits safe-sender mail on at most '
      '$kSafeHitsMax emails AND at most ${_pct(kSafeHitRateMax)} of the '
      'safe-sender mail it could be checked on, and adds coverage (hits No Rule or '
      'hand-deleted mail).');
  if (r.rejected.isNotEmpty) {
    b.writeln('Rejected before scoring (counts):');
    final keys = r.rejected.keys.toList()..sort();
    for (final k in keys) {
      b.writeln('  ${r.rejected[k]}  $k');
    }
  }
  b.writeln('Verification: ${r.verifyMismatches} listed candidate(s) differ '
      'between the fast counts and the real RuleEvaluator (must be 0).');

  String line(ScoredTrash s) {
    final cand = s.candidate;
    final sc = s.score;
    final isPhrase = cand.kind == TrashKind.subjectPhrase || cand.kind == TrashKind.bodyPhrase;
    final what = (isPhrase && !showPhrases) ? '(phrase hidden)' : cand.key;
    final f = r.f267[cand.ruleName];
    return '${cand.id} ${cand.kind.name} $what: delete=${sc.ruleDeleted} '
        'noRule=${sc.noRule} hand=${sc.handDeleted} safe=${sc.safeSender}/'
        '${sc.safeCheckable} (${_pct(sc.safeRate)}) '
        '${sc.noRule > 0 ? 'covers-No-Rule' : 'hand-deleted-only'}'
        '${f == null ? '' : ' F267=${f.passes ? 'PASS' : 'below bar'}'}';
  }

  for (final entry in {'Single-part candidates': r.singles, 'AND combinations': r.combos}.entries) {
    final rep = r.reported(entry.value);
    final passedNoGain = entry.value.where((s) => s.score.passes).length - rep.length;
    b.writeln('');
    b.writeln('${entry.key}: ${entry.value.length} scored, '
        '${entry.value.where((s) => s.score.passes).length} pass the threshold, '
        '${rep.length} reported ($passedNoGain pass but add no coverage).');
    for (final kind in TrashKind.values) {
      final ofKind = rep.where((s) => s.candidate.kind == kind).toList();
      if (ofKind.isEmpty) continue;
      b.writeln('  ${kind.name} (${ofKind.length}):');
      for (final s in ofKind) {
        b.writeln('    ${line(s)}');
      }
    }
  }
  return b.toString();
}

/// Refusal for an OUTPUT path under the live app data folder (R-4).
void writeTrashOutput(String path, String text, {String? appData}) =>
    writeOutput(path, text, appData: appData);
