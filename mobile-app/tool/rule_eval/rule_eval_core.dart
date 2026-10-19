/// F267 (Sprint 80): read-only rule evaluation harness.
///
/// Scores candidate rules (docs/RULE_FORMAT.md YAML) against the developer's
/// own scan history, using COPIES of the Windows DEV `spam_filter.db` and
/// `content_history.db`. The matching engine is the app's own
/// [RuleEvaluator] and [PatternCompiler], unchanged (R-2). Nothing here writes
/// to a database, and a path under `%APPDATA%\MyEmailSpamFilter` is refused
/// (R-4). Label definitions: see README.md beside this file (R-5).
///
/// This file is a tool, not app code: it may print (the CLI does), and it is
/// not shipped. It lives under tool/, and the app never imports it.
library;

import 'dart:io';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:my_email_spam_filter/core/services/yaml_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The bar (R76-3 Section 4.8, item 3).
const double kMinPrecision = 0.99;
const int kMinLabeledMatches = 20;

/// What the history says happened to an email.
enum HistoryLabel {
  /// Deleted by the user (a "block" decision) or by a rule (a delete outcome
  /// or a successful delete action).
  deleted,

  /// Kept: the user marked the sender safe, or the sender is a safe sender.
  kept,

  /// No evidence either way (for example a No Rule email nobody acted on).
  unlabeled,
}

/// One email from the history, with its label.
class HistorySample {
  HistorySample({
    required this.source,
    required this.accountId,
    required this.from,
    required this.subject,
    required this.body,
    required this.headers,
    required this.label,
    required this.noRuleLaterDeleted,
  });

  /// `content_history` (has a body) or `email_actions` (no body).
  final String source;
  final String accountId;
  final String from;
  final String subject;
  final String body;
  final Map<String, String> headers;
  final HistoryLabel label;

  /// True when the email was No Rule when first seen and was later deleted.
  /// This is the recall denominator.
  final bool noRuleLaterDeleted;

  /// Filled by [loadHistory] from the CURRENT safe_senders table.
  bool fromSafeSender = false;

  EmailMessage toMessage() => EmailMessage(
        id: '$source:$accountId:${from.hashCode}:${subject.hashCode}',
        from: from,
        subject: subject,
        body: body,
        headers: headers,
        receivedDate: DateTime.fromMillisecondsSinceEpoch(0),
        folderName: 'INBOX',
      );
}

/// The loaded history plus the current safe sender list.
class History {
  History({
    required this.samples,
    required this.safeSenders,
    required this.contentHistoryRows,
    required this.actionGroups,
    required this.contentHistoryPresent,
  });

  final List<HistorySample> samples;
  final SafeSenderList safeSenders;
  final int contentHistoryRows;
  final int actionGroups;
  final bool contentHistoryPresent;
}

/// R-4: returns the reason [path] must be refused, or null when it is allowed.
///
/// Refuses anything under `%APPDATA%\MyEmailSpamFilter` (a prefix match, so
/// the `MyEmailSpamFilter_Dev` folder is refused too), including the `-wal`
/// and `-shm` files. [appData] defaults to the APPDATA environment variable;
/// when it is unknown, the path-shape check below still applies.
String? liveDatabaseRefusal(String path, {String? appData}) {
  final normalized = _norm(path);
  final roots = <String>[];
  final base = appData ?? Platform.environment['APPDATA'];
  if (base != null && base.isNotEmpty) {
    roots.add(_norm(p.join(base, 'MyEmailSpamFilter')));
  }
  for (final root in roots) {
    if (normalized.startsWith(root)) {
      return 'REFUSED: "$path" is under the live app data folder '
          '(%APPDATA%\\MyEmailSpamFilter). This tool never opens live '
          'databases: the app may be writing to them, and a read can see a '
          'half-written WAL. Copy spam_filter.db (with its -wal and -shm '
          'files) and content_history.db to another folder and point the '
          'tool at the copy.';
    }
  }
  if (normalized.contains('/appdata/roaming/myemailspamfilter')) {
    return 'REFUSED: "$path" looks like the live app data folder '
        '(AppData\\Roaming\\MyEmailSpamFilter). Use a copy in another folder.';
  }
  return null;
}

String _norm(String path) {
  var full = p.normalize(p.absolute(path));
  try {
    final type = FileSystemEntity.typeSync(full, followLinks: true);
    if (type != FileSystemEntityType.notFound) {
      full = p.normalize(File(full).existsSync()
          ? File(full).resolveSymbolicLinksSync()
          : Directory(full).resolveSymbolicLinksSync());
    }
  } on FileSystemException {
    // Keep the lexical form when links cannot be resolved.
  }
  return full.replaceAll('\\', '/').toLowerCase();
}

/// Opens [path] strictly read-only (public so a test can prove writes fail).
Future<Database> openReadOnly(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
}

class _ActionGroup {
  _ActionGroup(this.accountId, this.from, this.subject, this.msgId, this.emailId,
      this.firstAction);
  final String accountId;
  final String from;
  final String subject;
  final String? msgId;
  final String emailId;
  final String firstAction;
  bool anyDelete = false;
  bool anySafe = false;
  bool consumed = false;
}

/// Loads the labeled history from the two database copies in [dbDir].
///
/// Throws [StateError] with the refusal text when [dbDir] is a live path, and
/// [FileSystemException] when `spam_filter.db` is missing. A missing
/// `content_history.db` is allowed: only the `email_actions` corpus is used.
Future<History> loadHistory(String dbDir, {String? appData}) async {
  final refusal = liveDatabaseRefusal(dbDir, appData: appData);
  if (refusal != null) throw StateError(refusal);

  final mainPath = p.join(dbDir, 'spam_filter.db');
  final historyPath = p.join(dbDir, 'content_history.db');
  for (final f in [mainPath, historyPath]) {
    final r = liveDatabaseRefusal(f, appData: appData);
    if (r != null) throw StateError(r);
  }
  if (!File(mainPath).existsSync()) {
    throw FileSystemException('spam_filter.db not found in the copy folder', mainPath);
  }

  final main = await openReadOnly(mainPath);
  try {
    final safeRows = await main.rawQuery('SELECT pattern FROM safe_senders');
    final safe = SafeSenderList(
        safeSenders:
            safeRows.map((r) => (r['pattern'] as String).toLowerCase().trim()).toList());

    // email_actions: one group per email (account + Message-ID, else provider
    // id), because a read-only scan re-sees the same email every cycle.
    final actionRows = await main.rawQuery(
        'SELECT ea.id AS id, sr.account_id AS account_id, ea.email_id AS email_id, '
        'ea.email_from AS email_from, ea.email_subject AS email_subject, '
        'ea.action_type AS action_type, ea.success AS success, '
        'ea.is_safe_sender AS is_safe_sender, '
        'ea.rfc5322_message_id AS msg_id '
        'FROM email_actions ea JOIN scan_results sr ON sr.id = ea.scan_result_id '
        'ORDER BY ea.id');
    final groups = <String, _ActionGroup>{};
    final byProvider = <String, _ActionGroup>{};
    for (final r in actionRows) {
      final account = r['account_id'] as String;
      final emailId = (r['email_id'] as String?) ?? '';
      final msgId = _blankToNull(r['msg_id'] as String?);
      final key = msgId != null ? 'm|$account|$msgId' : 'p|$account|$emailId';
      final g = groups.putIfAbsent(
          key,
          () => _ActionGroup(account, (r['email_from'] as String?) ?? '',
              (r['email_subject'] as String?) ?? '', msgId, emailId,
              (r['action_type'] as String?) ?? ''));
      byProvider.putIfAbsent('$account|$emailId', () => g);
      final action = r['action_type'] as String?;
      if (action == 'delete' && (r['success'] as int?) == 1) g.anyDelete = true;
      if (action == 'safeSender' || (r['is_safe_sender'] as int?) == 1) {
        g.anySafe = true;
      }
    }

    final samples = <HistorySample>[];
    var historyRows = 0;
    final historyPresent = File(historyPath).existsSync();
    if (historyPresent) {
      final hist = await openReadOnly(historyPath);
      try {
        final rows = await hist.rawQuery(
            'SELECT account_id, message_id, provider_id, from_address, '
            'reply_to, return_path_domain, subject, outcome, user_decision, '
            'list_unsubscribe, body_text FROM content_history');
        historyRows = rows.length;
        for (final r in rows) {
          final account = r['account_id'] as String;
          final msgId = _blankToNull(r['message_id'] as String?);
          final providerId = _blankToNull(r['provider_id'] as String?);
          _ActionGroup? g;
          if (msgId != null) g = groups['m|$account|$msgId'];
          if (g == null && providerId != null) {
            g = byProvider['$account|$providerId'];
          }
          if (g != null) g.consumed = true;

          final decision = (r['user_decision'] as String?) ?? '';
          final outcome = (r['outcome'] as String?) ?? '';
          HistoryLabel label;
          if (decision.startsWith('safe_sender:')) {
            label = HistoryLabel.kept;
          } else if (decision.startsWith('block:')) {
            label = HistoryLabel.deleted;
          } else if (g != null && g.anyDelete) {
            label = HistoryLabel.deleted;
          } else if (outcome == 'delete') {
            label = HistoryLabel.deleted;
          } else if (outcome == 'safe_sender' || (g != null && g.anySafe)) {
            label = HistoryLabel.kept;
          } else {
            label = HistoryLabel.unlabeled;
          }
          final noRuleLater = label == HistoryLabel.deleted &&
              (decision.startsWith('block:') ||
                  (g != null && g.firstAction == 'none' && g.anyDelete));

          final headers = <String, String>{};
          final replyTo = _blankToNull(r['reply_to'] as String?);
          if (replyTo != null) headers['reply-to'] = replyTo;
          final rp = _blankToNull(r['return_path_domain'] as String?);
          if (rp != null) headers['return-path'] = rp;
          if ((r['list_unsubscribe'] as int?) == 1) {
            headers['list-unsubscribe'] = 'present';
          }
          samples.add(HistorySample(
            source: 'content_history',
            accountId: account,
            from: (r['from_address'] as String?) ?? '',
            subject: (r['subject'] as String?) ?? '',
            body: (r['body_text'] as String?) ?? '',
            headers: headers,
            label: label,
            noRuleLaterDeleted: noRuleLater,
          ));
        }
      } finally {
        await hist.close();
      }
    }

    // Emails seen only in email_actions (older, or never captured): subject
    // and sender only, no body.
    for (final g in groups.values) {
      if (g.consumed) continue;
      final label = g.anyDelete
          ? HistoryLabel.deleted
          : (g.anySafe ? HistoryLabel.kept : HistoryLabel.unlabeled);
      samples.add(HistorySample(
        source: 'email_actions',
        accountId: g.accountId,
        from: g.from,
        subject: g.subject,
        body: '',
        headers: const {},
        label: label,
        noRuleLaterDeleted: g.firstAction == 'none' && g.anyDelete,
      ));
    }

    for (final s in samples) {
      s.fromSafeSender = safe.findMatch(s.from) != null;
    }
    return History(
      samples: samples,
      safeSenders: safe,
      contentHistoryRows: historyRows,
      actionGroups: groups.length,
      contentHistoryPresent: historyPresent,
    );
  } finally {
    await main.close();
  }
}

String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v;

/// The report for one candidate rule.
class RuleReport {
  RuleReport({
    required this.name,
    required this.deletes,
    required this.matches,
    required this.deletedMatches,
    required this.keptMatches,
    required this.unlabeledMatches,
    required this.safeSenderHits,
    required this.recallHits,
    required this.recallTotal,
    required this.patternProblems,
  });

  final String name;
  final bool deletes;
  final int matches;
  final int deletedMatches;
  final int keptMatches;
  final int unlabeledMatches;
  final int safeSenderHits;
  final int recallHits;
  final int recallTotal;
  final List<String> patternProblems;

  int get labeledMatches => deletedMatches + keptMatches;

  /// deleted / (deleted + kept) over the matches; null with no labeled match.
  double? get precision =>
      labeledMatches == 0 ? null : deletedMatches / labeledMatches;

  double? get recall => recallTotal == 0 ? null : recallHits / recallTotal;

  /// R-3: empty when the rule PASSES; otherwise one reason per failed check.
  List<String> get failReasons {
    final reasons = <String>[];
    if (!deletes) reasons.add('not a delete rule (actions.delete is not true)');
    for (final problem in patternProblems) {
      reasons.add(problem);
    }
    if (safeSenderHits > 0) {
      reasons.add('$safeSenderHits match(es) on mail from a current safe sender (need 0)');
    }
    if (labeledMatches < kMinLabeledMatches) {
      reasons.add('only $labeledMatches labeled matches (need at least $kMinLabeledMatches)');
    }
    final pr = precision;
    if (pr != null && pr < kMinPrecision) {
      reasons.add('precision ${pr.toStringAsFixed(4)} is below $kMinPrecision');
    }
    return reasons;
  }

  bool get passes => failReasons.isEmpty;
}

/// Scores every rule in [candidates] on its own against [history] (R-1..R-3).
///
/// Each rule is evaluated alone, with an EMPTY safe sender list, so that (a)
/// an earlier rule cannot shadow it and (b) a safe sender cannot hide the
/// match: the engine checks safe senders first, so with the real list a safe
/// sender's mail would never reach the rule and the hit would be invisible.
/// Safe-sender hits are counted separately from the CURRENT safe_senders
/// table. A disabled rule is scored as if enabled.
Future<List<RuleReport>> scoreCandidates(
    RuleSet candidates, History history) async {
  final reports = <RuleReport>[];
  final recallTotal = history.samples.where((s) => s.noRuleLaterDeleted).length;

  for (final rule in candidates.rules) {
    final compiler = PatternCompiler();
    final problems = _patternProblems(rule, compiler);

    final scored = Rule(
      name: rule.name,
      enabled: true,
      isLocal: rule.isLocal,
      executionOrder: 0,
      conditions: rule.conditions,
      actions: rule.actions,
      exceptions: rule.exceptions,
    );
    final evaluator = RuleEvaluator(
      ruleSet: RuleSet(version: '1.0', settings: const {}, rules: [scored]),
      safeSenderList: SafeSenderList(safeSenders: []),
      compiler: compiler,
      silent: true,
    );

    var matches = 0, deleted = 0, kept = 0, unlabeled = 0, safeHits = 0;
    var recallHits = 0;
    for (final s in history.samples) {
      final result = await evaluator.evaluate(s.toMessage());
      if (result.matchedRule != rule.name) continue;
      matches++;
      switch (s.label) {
        case HistoryLabel.deleted:
          deleted++;
        case HistoryLabel.kept:
          kept++;
        case HistoryLabel.unlabeled:
          unlabeled++;
      }
      if (s.fromSafeSender) safeHits++;
      if (s.noRuleLaterDeleted) recallHits++;
    }

    reports.add(RuleReport(
      name: rule.name,
      deletes: rule.actions.delete,
      matches: matches,
      deletedMatches: deleted,
      keptMatches: kept,
      unlabeledMatches: unlabeled,
      safeSenderHits: safeHits,
      recallHits: recallHits,
      recallTotal: recallTotal,
      patternProblems: problems,
    ));
  }
  return reports;
}

/// Pattern problems that make a candidate unsafe to score or ship: the app's
/// own import checks (ReDoS rejection, invalid regex, the F266 dead-pattern
/// check for address fields), reused from [PatternCompiler].
List<String> _patternProblems(Rule rule, PatternCompiler compiler) {
  final problems = <String>[];
  void check(String pattern, {required bool address, required String where}) {
    compiler.compileWithProvenance(pattern, PatternProvenance.user);
    final redos = compiler.rejectedUserPatterns[pattern];
    if (redos != null) problems.add('$where pattern rejected (ReDoS): $redos');
    final bad = compiler.compilationFailures[pattern];
    if (bad != null) problems.add('$where pattern does not compile');
    if (address) {
      final dead = PatternCompiler.detectUnmatchable(pattern);
      if (dead.isNotEmpty) problems.add('$where pattern can never match an address (F266)');
    }
  }

  final c = rule.conditions;
  for (final x in c.from) {
    check(x, address: true, where: 'from');
  }
  for (final x in c.header) {
    check(x, address: false, where: 'header');
  }
  for (final x in c.subject) {
    check(x, address: false, where: 'subject');
  }
  for (final x in c.body) {
    check(x, address: false, where: 'body');
  }
  final e = rule.exceptions;
  if (e != null) {
    for (final x in e.from) {
      check(x, address: true, where: 'exception from');
    }
    for (final x in e.header) {
      check(x, address: false, where: 'exception header');
    }
    for (final x in e.subject) {
      check(x, address: false, where: 'exception subject');
    }
    for (final x in e.body) {
      check(x, address: false, where: 'exception body');
    }
  }
  return problems;
}

/// Reads the candidate YAML file (docs/RULE_FORMAT.md shape).
RuleSet loadCandidates(String yamlPath) {
  final text = File(yamlPath).readAsStringSync();
  return YamlService().parseRulesFromString(text);
}

/// The text report. Counts and rule names only: no email content.
String renderReport(History history, List<RuleReport> reports) {
  final b = StringBuffer();
  final byLabel = <HistoryLabel, int>{};
  for (final s in history.samples) {
    byLabel[s.label] = (byLabel[s.label] ?? 0) + 1;
  }
  b.writeln('Rule evaluation report (F267)');
  b.writeln('History: ${history.samples.length} emails '
      '(${history.contentHistoryRows} from content_history, '
      '${history.samples.length - history.contentHistoryRows} only in email_actions)');
  b.writeln('Labels: deleted=${byLabel[HistoryLabel.deleted] ?? 0} '
      'kept=${byLabel[HistoryLabel.kept] ?? 0} '
      'unlabeled=${byLabel[HistoryLabel.unlabeled] ?? 0}; '
      'No Rule later deleted (recall base)=${history.samples.where((s) => s.noRuleLaterDeleted).length}; '
      'from a current safe sender=${history.samples.where((s) => s.fromSafeSender).length}; '
      'safe sender patterns=${history.safeSenders.safeSenders.length}');
  if (!history.contentHistoryPresent) {
    b.writeln('[WARNING] content_history.db not found: bodies were not available.');
  }
  b.writeln('Bar: zero safe-sender hits AND precision >= $kMinPrecision '
      'on >= $kMinLabeledMatches labeled matches.');
  b.writeln('');
  for (final r in reports) {
    b.writeln('${r.passes ? "PASS" : "FAIL"}  ${r.name}');
    b.writeln('  matches=${r.matches} deleted=${r.deletedMatches} '
        'kept=${r.keptMatches} unlabeled=${r.unlabeledMatches}');
    b.writeln('  precision=${r.precision == null ? "n/a" : r.precision!.toStringAsFixed(4)} '
        '(deleted / (deleted + kept))');
    b.writeln('  safe-sender hits=${r.safeSenderHits}');
    b.writeln('  recall=${r.recall == null ? "n/a" : r.recall!.toStringAsFixed(4)} '
        '(${r.recallHits} of ${r.recallTotal} No Rule emails later deleted)');
    for (final reason in r.failReasons) {
      b.writeln('  reason: $reason');
    }
  }
  final passed = reports.where((r) => r.passes).length;
  b.writeln('');
  b.writeln('Summary: $passed PASS, ${reports.length - passed} FAIL of ${reports.length} candidates.');
  return b.toString();
}
