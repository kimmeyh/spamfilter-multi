/// F270 R-4 (Sprint 83, Harold Q7): Sent-folder reply-pair mining mode.
///
/// Harold, 2026-11-01: the Sent-folder part "should be based on my email
/// address not the users and can be done similar to F308". So this is a
/// DEVELOPER TOOL, not an in-app read of any user's Sent folder:
///
/// 1. A read-only probe (IMAP EXAMINE, `BODY.PEEK[HEADER.FIELDS (TO CC DATE
///    MESSAGE-ID)]` only; kept in the scratchpad, like the F308 probe because
///    it reads a credential) writes ONE JSONL line per Sent email with the
///    recipient ADDRESSES only: `{"to": ["a@b.example"], "date_ms": 1}`. No
///    subject and no body leave the mailbox.
/// 2. This core finds REPLY PAIRS: an address Harold wrote to that also sent
///    him mail, using the DB copy's stored senders (`unmatched_emails` and
///    `email_actions`).
/// 3. It reports candidate safe-sender patterns for Harold to review. Nothing
///    is imported or applied; nothing here writes to a database or a mailbox.
///
/// THE GATE (Sprint 82 IMP-4, same as the in-app F270 service): a reply pair
/// is a candidate only when EVERY stored email from that sender has the auth
/// class green, none was deleted by a rule, and no saved safe-sender pattern
/// already covers it. A sender with a stored class of grey, yellow, red or
/// unknown is reported as NOT gated with the reason, never as a candidate.
///
/// Harold's own addresses (the `accounts` table of the copy) are excluded, so
/// a self-reply is not a pair.
///
/// ADR-0042: Windows DEV developer tool only. No Android path for the tool;
/// the patterns it proposes are ordinary safe-sender regexes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:my_email_spam_filter/core/services/email_body_parser.dart';
import 'package:my_email_spam_filter/core/services/safe_sender_suggestion_service.dart';
import 'package:path/path.dart' as p;

import '../rule_eval/rule_eval_core.dart';

/// One Sent email, reduced to its recipient addresses.
class SentRecord {
  SentRecord(this.to, this.dateMs);
  final List<String> to;
  final int? dateMs;

  factory SentRecord.fromJson(Map<String, dynamic> j) => SentRecord(
        [
          for (final a in (j['to'] as List? ?? const []))
            if (a is String && a.contains('@')) a.trim().toLowerCase()
        ],
        (j['date_ms'] as num?)?.toInt(),
      );
}

List<SentRecord> readSentJsonl(String path) {
  final out = <SentRecord>[];
  for (final line in File(path).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    out.add(SentRecord.fromJson(jsonDecode(line) as Map<String, dynamic>));
  }
  return out;
}

/// Why a reply pair is not a candidate.
enum PairStatus { candidate, alreadySafe, notGreen, ruleDeleted }

class ReplyPair {
  ReplyPair({
    required this.address,
    required this.sentCount,
    required this.inboundCount,
    required this.status,
    this.recommendedPattern,
    this.recommendedType,
  });
  final String address;
  final int sentCount;
  final int inboundCount;
  final PairStatus status;
  final String? recommendedPattern;
  final String? recommendedType;
}

class ReplyPairResult {
  ReplyPair? find(String address) {
    for (final pair in pairs) {
      if (pair.address == address) return pair;
    }
    return null;
  }

  ReplyPairResult(this.sentEmails, this.recipients, this.pairs);
  final int sentEmails;
  final int recipients;
  final List<ReplyPair> pairs;

  List<ReplyPair> get candidates =>
      pairs.where((x) => x.status == PairStatus.candidate).toList();
  int count(PairStatus s) => pairs.where((x) => x.status == s).length;
}

/// Finds the reply pairs in [sent] against the DB copy in [dbDir].
Future<ReplyPairResult> mineReplyPairs(
    List<SentRecord> sent, String dbDir) async {
  final parser = EmailBodyParser();
  String addr(String from) => parser.extractEmailAddress(from).trim();
  final db = await openReadOnly(p.join(dbDir, 'spam_filter.db'));
  try {
    final own = <String>{
      for (final r in await db.rawQuery('SELECT email FROM accounts'))
        if (r['email'] is String) (r['email'] as String).toLowerCase()
    };
    final safe = <String>[
      for (final r in await db.rawQuery('SELECT pattern FROM safe_senders'))
        r['pattern'] as String
    ];
    final inbound = <String, int>{};
    final nonGreen = <String>{};
    final ruleDeleted = <String>{};
    void note(String from, String? auth) {
      final a = addr(from);
      if (!a.contains('@')) return;
      inbound[a] = (inbound[a] ?? 0) + 1;
      if ((auth ?? '').toLowerCase() != kSuggestionRequiredAuth) {
        nonGreen.add(a);
      }
    }

    for (final r in await db.rawQuery(
        'SELECT from_email, auth_classification FROM unmatched_emails')) {
      note(r['from_email'] as String, r['auth_classification'] as String?);
    }
    for (final r in await db.rawQuery(
        'SELECT email_from, auth_classification, action_type '
        'FROM email_actions')) {
      final from = r['email_from'] as String;
      note(from, r['auth_classification'] as String?);
      if (r['action_type'] == 'delete') ruleDeleted.add(addr(from));
    }

    final sentCounts = <String, int>{};
    for (final rec in sent) {
      for (final a in rec.to.toSet()) {
        if (own.contains(a)) continue;
        sentCounts[a] = (sentCounts[a] ?? 0) + 1;
      }
    }

    final pairs = <ReplyPair>[];
    sentCounts.forEach((a, n) {
      final inCount = inbound[a];
      if (inCount == null) return; // never wrote back: not a pair
      final choices = SafeSenderSuggestionService.choicesFor(a);
      final rec = choices?.where((c) => c.recommended).firstOrNull;
      PairStatus status;
      if (SafeSenderSuggestionService.isCovered(a, safe)) {
        status = PairStatus.alreadySafe;
      } else if (ruleDeleted.contains(a)) {
        status = PairStatus.ruleDeleted;
      } else if (nonGreen.contains(a) || rec == null) {
        status = PairStatus.notGreen;
      } else {
        status = PairStatus.candidate;
      }
      pairs.add(ReplyPair(
        address: a,
        sentCount: n,
        inboundCount: inCount,
        status: status,
        recommendedPattern: rec?.pattern,
        recommendedType: rec?.type,
      ));
    });
    pairs.sort((x, y) => x.address.compareTo(y.address));
    return ReplyPairResult(sent.length, sentCounts.length, pairs);
  } finally {
    await db.close();
  }
}

/// The side report: counts always; addresses only when [showAddresses].
String renderReplyPairReport(ReplyPairResult r, {bool showAddresses = false}) {
  final b = StringBuffer()
    ..writeln('F270 R-4 reply-pair report (Sent folder, recipients only)')
    ..writeln('Sent emails read: ${r.sentEmails}')
    ..writeln('Distinct recipients (not your own addresses): ${r.recipients}')
    ..writeln('Reply pairs (also sent you mail): ${r.pairs.length}')
    ..writeln('  Candidates (all stored mail green, no rule delete, '
        'not safe): ${r.count(PairStatus.candidate)}')
    ..writeln('  Already covered by a safe sender: '
        '${r.count(PairStatus.alreadySafe)}')
    ..writeln('  Not gated (a stored class other than green, or no usable '
        'domain): ${r.count(PairStatus.notGreen)}')
    ..writeln('  Not gated (a rule deleted mail from them): '
        '${r.count(PairStatus.ruleDeleted)}');
  if (showAddresses) {
    b.writeln('Candidates:');
    for (final c in r.candidates) {
      b.writeln('  ${c.address}  sent ${c.sentCount}, received '
          '${c.inboundCount}, suggest ${c.recommendedType}');
    }
  } else {
    b.writeln('(addresses hidden; use -ShowPhrases to print them)');
  }
  return b.toString();
}

/// The candidate patterns, in the safe_senders YAML shape. Private data: keep
/// the file on your PC and out of the repository.
String renderReplyPairYaml(ReplyPairResult r) {
  final b = StringBuffer()
    ..writeln('# Proposed by tool/rule_miner reply-pair mode (F270 R-4). '
        'Review before import.')
    ..writeln('# Generated from private mail: keep this file on your PC.');
  final patterns = [
    for (final c in r.candidates)
      if (c.recommendedPattern != null) c.recommendedPattern!
  ];
  if (patterns.isEmpty) {
    b.writeln('safe_senders: []');
  } else {
    b.writeln('safe_senders:');
    for (final pat in patterns) {
      b.writeln("  - '${pat.replaceAll("'", "''")}'");
    }
  }
  return b.toString();
}
