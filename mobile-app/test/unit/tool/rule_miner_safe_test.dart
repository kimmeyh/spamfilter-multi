// F310 (Sprint 83): tests for the rule miner safe mode (tool/rule_miner/
// safe_miner_core.dart). Every record is a small in-memory fixture or a temp
// database the test builds. No real mail is read.
//
// ADR-0042: developer tool on Harold's Windows PC only. The matching engine
// (PatternCompiler, SafeSenderList, RuleEvaluator) is the shared one both apps
// use, unchanged. There is no Android path for the tool; the safe-sender
// patterns it suggests import on both apps through the existing import.
//
// What these tests do NOT catch: the stored auth class is a proxy for DMARC
// pass (green = every present SPF/DKIM/DMARC verdict passed). A fixture cannot
// show that real mail with a green class has a DMARC record; only the runtime
// suggestion (F270) reads the raw header. They also do not read the real DEV
// history (the report documents that run).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/rule_eval/rule_eval_core.dart';
import '../../../tool/rule_miner/safe_miner_core.dart';
import '../../../tool/rule_miner/trash_miner_core.dart';

const int day = 86400000;

HistorySample h(String from, String subject,
        {String? auth = 'green',
        String outcome = 'no_rule',
        HistoryLabel label = HistoryLabel.unlabeled,
        String? mid,
        bool safe = false,
        int? at,
        String body = 'ordinary note',
        Map<String, String> headers = const {}}) =>
    HistorySample(
      source: 'content_history',
      accountId: 'acct',
      from: from,
      subject: subject,
      body: body,
      headers: headers,
      label: label,
      noRuleLaterDeleted: false,
      messageId: mid,
      outcome: outcome,
      receivedAtMs: at,
      authClass: auth,
    )..fromSafeSender = safe;

/// [n] safe-sender emails from [domain], each from a different address.
List<HistorySample> safeFrom(String domain, int n,
        {String? auth = 'green', String subject = 'plain note', int? at}) =>
    [
      for (var i = 0; i < n; i++)
        h('u$i@$domain', '$subject $i',
            auth: auth,
            label: HistoryLabel.kept,
            outcome: 'safe_sender',
            safe: true,
            at: at)
    ];

/// [n] delete-rule emails (history outcome delete) from [domain].
List<HistorySample> spamFrom(String domain, int n,
        {String? auth = 'green', String subject = 'cheap pills'}) =>
    [
      for (var i = 0; i < n; i++)
        h('s$i@$domain', '$subject $i',
            auth: auth, label: HistoryLabel.deleted, outcome: 'delete')
    ];

History historyOf(List<HistorySample> samples, {List<String> safePatterns = const []}) =>
    History(
      samples: samples,
      safeSenders: SafeSenderList(safeSenders: safePatterns),
      contentHistoryRows: samples.length,
      actionGroups: 0,
      contentHistoryPresent: true,
    );

final RuleSet noRules = RuleSet(version: '1.0', settings: const {}, rules: []);

Future<SafeMineResult> run(List<HistorySample> samples,
        {List<TrashRecord> records = const [], RuleSet? rules, List<String> safePatterns = const []}) =>
    mineSafeWith(records, historyOf(samples, safePatterns: safePatterns), rules ?? noRules);

ScoredSafe? domainOf(SafeMineResult r, String domain) {
  final hits = r.scored.where((s) =>
      s.candidate.kind == SafeKind.senderDomain && s.candidate.key == domain);
  return hits.isEmpty ? null : hits.first;
}

bool reportedDomain(SafeMineResult r, String domain) => r.reported
    .any((s) => s.candidate.kind == SafeKind.senderDomain && s.candidate.key == domain);

void main() {
  group('AC-2 / R-3: the auth gate', () {
    test('a domain with enough green safe-sender mail and no spam is reported', () async {
      final r = await run([...safeFrom('goodco.example', 6), ...spamFrom('junk.example', 30)]);
      expect(reportedDomain(r, 'goodco.example'), isTrue);
      // Sprint 83 7.7.1 pass-2 F8: the suggested pattern is the one the app
      // saves for a safe sender (Add Safe Sender > entire domain), not the
      // block-rule shape. Would NOT catch: a wrong builder in the app itself.
      expect(domainOf(r, 'goodco.example')!.candidate.safePattern,
          RuleQuickActionService.safeSenderPatternFor('entireDomain', 'goodco.example'));
      expect(r.reported.every((s) => s.candidate.gated), isTrue);
    });

    test('the same mail with a yellow class gives no candidate and no suggestion', () async {
      final r = await run([...safeFrom('goodco.example', 6, auth: 'yellow'), ...spamFrom('junk.example', 30)]);
      expect(domainOf(r, 'goodco.example'), isNull);
      expect(r.reported, isEmpty);
    });

    test('an unknown auth class does not prove the gate (no suggestion)', () async {
      final r = await run([...safeFrom('goodco.example', 6, auth: null), ...spamFrom('junk.example', 30)]);
      expect(r.reported, isEmpty);
    });

    test('red and grey classes do not pass the gate either', () async {
      final r = await run([
        ...safeFrom('redco.example', 6, auth: 'red'),
        ...safeFrom('greyco.example', 6, auth: 'grey'),
        ...spamFrom('junk.example', 30),
      ]);
      expect(r.reported, isEmpty);
    });

    test('a From with a display name is read by its address', () async {
      final samples = [
        for (var i = 0; i < 6; i++)
          h('Some Person <u$i@namedco.example>', 'note $i',
              label: HistoryLabel.kept, outcome: 'safe_sender', safe: true),
        ...spamFrom('junk.example', 30),
      ];
      final r = await run(samples);
      expect(domainOf(r, 'namedco.example')!.score.safeHits, 6);
      expect(addressOf('Some Person <U@Named.Example>'), 'u@named.example');
    });

    test('4 green emails are below the support bar; 5 reach it', () async {
      final four = await run([...safeFrom('fourco.example', 4), ...spamFrom('junk.example', 30)]);
      expect(domainOf(four, 'fourco.example'), isNull);
      final five = await run([...safeFrom('fiveco.example', 5), ...spamFrom('junk.example', 30)]);
      expect(reportedDomain(five, 'fiveco.example'), isTrue);
    });

    test('a candidate built without the gate never passes, whatever its score', () async {
      final r = await run([...safeFrom('goodco.example', 6), ...spamFrom('junk.example', 30)]);
      final gated = domainOf(r, 'goodco.example')!;
      expect(gated.score.meetsThreshold, isTrue);
      final bare = SafeCandidate(
          id: 'X',
          kind: SafeKind.senderDomain,
          features: gated.candidate.features,
          gated: false);
      final scored = ScoredSafe(bare, gated.score);
      expect(scored.score.meetsThreshold, isTrue, reason: 'its numbers are perfect');
      expect(scored.passes, isFalse, reason: 'content alone is not a suggestion');
      expect(bare.isSuggestion, isFalse);
    });

    test('content-only candidates that would pass are counted but never reported', () async {
      // 12 yellow reply-thread emails from many senders: the content is clean
      // (no spam), but none is gate-proven.
      final samples = [
        for (var i = 0; i < 12; i++)
          h('p$i@peer$i.example', 're: lunch $i',
              auth: 'yellow', label: HistoryLabel.kept, outcome: 'safe_sender', safe: true),
        ...spamFrom('junk.example', 30),
      ];
      final r = await run(samples);
      expect(r.contentOnlyPass, greaterThan(0));
      expect(r.reported, isEmpty);
    });

    test('the YAML lists only reported domains and says the DMARC condition is not expressible', () async {
      final r = await run([
        ...safeFrom('goodco.example', 6),
        ...safeFrom('yellowco.example', 6, auth: 'yellow'),
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 5),
        ...spamFrom('junk.example', 30),
      ]);
      expect(domainOf(r, 'mixco.example')!.passes, isFalse);
      // The whole scored list goes in: the YAML must still drop what fails.
      final yaml = renderSafeYaml(r.scored);
      expect(yaml, contains('goodco'));
      expect(yaml, isNot(contains('yellowco')));
      expect(yaml, isNot(contains('mixco')));
      expect(yaml, contains('DMARC'));
      expect(renderSafeYaml(const []), contains('safe_senders: []'));
    });
  });

  group('R-2: delete-rule mail', () {
    test('green delete-rule mail from the domain blocks it above 2 hits, not at 2', () async {
      final two = await run([
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 2),
        ...spamFrom('junk.example', 500),
      ]);
      expect(reportedDomain(two, 'mixco.example'), isTrue);
      // 2 hits is within the count bound here, but 2 of 100 is 2 percent: the
      // share bound (0.5 percent) refuses it.
      final share = await run([
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 2),
        ...spamFrom('junk.example', 98),
      ]);
      expect(domainOf(share, 'mixco.example')!.score.spamHits, 2);
      expect(reportedDomain(share, 'mixco.example'), isFalse);
      final three = await run([
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 3),
        ...spamFrom('junk.example', 2000),
      ]);
      expect(domainOf(three, 'mixco.example')!.score.spamHits, 3);
      expect(reportedDomain(three, 'mixco.example'), isFalse);
    });

    test('delete-rule mail that fails the gate (yellow) is stopped by the gate, not counted', () async {
      final r = await run([
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 10, auth: 'yellow'),
        ...spamFrom('junk.example', 30),
      ]);
      expect(domainOf(r, 'mixco.example')!.score.spamHits, 0);
      expect(reportedDomain(r, 'mixco.example'), isTrue);
    });

    test('delete-rule mail with an UNKNOWN class counts as a hit (could not check is risk)', () async {
      final r = await run([
        ...safeFrom('mixco.example', 6),
        ...spamFrom('mixco.example', 3, auth: null),
        ...spamFrom('junk.example', 30),
      ]);
      final s = domainOf(r, 'mixco.example')!;
      expect(s.score.spamHits, 3);
      expect(s.score.spamUnknownAuthHits, 3);
      expect(reportedDomain(r, 'mixco.example'), isFalse);
    });

    test('a Trash2 email caught by a delete rule is spam with unknown auth', () async {
      final rule = Rule(
        name: 'junkrule',
        enabled: true,
        isLocal: true,
        executionOrder: 1,
        conditions: RuleConditions(
            type: 'OR', from: const [], header: const [], subject: [r'\bpillsale\b'], body: const []),
        actions: RuleActions(delete: true),
      );
      final records = [
        for (var i = 0; i < 3; i++)
          TrashRecord(
              messageId: normalizeMessageId('t$i@x'),
              from: 'x$i@mixco.example',
              subject: 'pillsale $i',
              dateMs: null,
              headers: const {},
              body: 'buy'),
      ];
      final r = await run([...safeFrom('mixco.example', 6), ...spamFrom('junk.example', 30)],
          records: records,
          rules: RuleSet(version: '1.0', settings: const {}, rules: [rule]));
      final s = domainOf(r, 'mixco.example')!;
      expect(s.score.spamUnknownAuthHits, 3);
      expect(reportedDomain(r, 'mixco.example'), isFalse);
    });

    test('a shared mailbox provider domain is never proposed', () async {
      final r = await run([...safeFrom('gmail.com', 8), ...spamFrom('junk.example', 30)]);
      expect(domainOf(r, 'gmail.com'), isNull);
      expect(r.rejected['shared mailbox provider domain'], 1);
    });

    test('a candidate that cannot be checked on any delete-rule mail is not reported', () async {
      final r = await run(safeFrom('goodco.example', 6)); // no spam pool at all
      expect(domainOf(r, 'goodco.example')!.score.spamCheckable, 0);
      expect(r.reported, isEmpty);
    });

    test('the report marks a domain a current safe-sender pattern already matches', () async {
      final r = await run([...safeFrom('goodco.example', 6), ...spamFrom('junk.example', 30)],
          safePatterns: [r'@(?:[a-z0-9-]+\.)*goodco\.example$']);
      expect(domainOf(r, 'goodco.example')!.alreadyCovered, isTrue);
      expect(renderSafeReport(r, showDomains: true), contains('[already a safe sender]'));
    });
  });

  group('R-1: signals', () {
    test('the reply-thread signal matches re: and not words that start with re', () async {
      final samples = [
        h('a@a.example', 're: dinner', label: HistoryLabel.kept, outcome: 'safe_sender', safe: true),
        h('b@b.example', 'receipt for you', label: HistoryLabel.kept, outcome: 'safe_sender', safe: true),
        ...spamFrom('junk.example', 3),
      ];
      final r = await run(samples);
      final row = r.signalScores.firstWhere((s) => s.key == 'reply thread subject');
      expect(row.safeHits, 1);
      final trans = r.signalScores.firstWhere((s) => s.key == 'transactional subject word');
      expect(trans.safeHits, 1, reason: '"receipt" is transactional, "re: dinner" is not');
    });

    test('long history needs both enough mails and enough days', () async {
      final many = [
        for (var i = 0; i < 6; i++)
          h('u$i@oldco.example', 'note $i',
              label: HistoryLabel.kept, outcome: 'safe_sender', safe: true, at: i * 30 * day),
        for (var i = 0; i < 6; i++)
          h('u$i@newco.example', 'note $i',
              label: HistoryLabel.kept, outcome: 'safe_sender', safe: true, at: i * day),
        ...spamFrom('junk.example', 3),
      ];
      final r = await run(many);
      final row = r.signalScores.firstWhere((s) => s.key.startsWith('sender domain seen'));
      expect(row.safeHits, 6, reason: 'only the 150-day domain qualifies');
    });

    test('the few-links signal is not checked on mail with no stored body', () async {
      final samples = [
        h('a@a.example', 'x', label: HistoryLabel.kept, outcome: 'safe_sender', safe: true, body: ''),
        h('b@b.example', 'y',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true, body: 'see https://one.example'),
        ...spamFrom('junk.example', 3),
      ];
      final r = await run(samples);
      final row = r.signalScores.firstWhere((s) => s.key.startsWith('at most'));
      expect(row.safeEligible, 1);
      expect(row.safeHits, 1);
    });

    test('a signal that spam also has is not reported alone', () async {
      final samples = [
        for (var i = 0; i < 20; i++)
          h('p$i@peer$i.example', 're: hello $i',
              label: HistoryLabel.kept, outcome: 'safe_sender', safe: true),
        for (var i = 0; i < 20; i++)
          h('s$i@junk$i.example', 're: your offer $i', label: HistoryLabel.deleted, outcome: 'delete'),
      ];
      final r = await run(samples);
      expect(r.reported.any((s) => s.candidate.id == 'S1'), isFalse);
    });
  });

  group('verification, corpus and I/O', () {
    test('a reported domain agrees with the real SafeSenderList on every email', () async {
      final r = await run([...safeFrom('goodco.example', 6), ...spamFrom('junk.example', 30)]);
      expect(reportedDomain(r, 'goodco.example'), isTrue);
      expect(r.verifyMismatches, 0);
    });

    test('a Trash2 duplicate keeps the auth class of its history row', () async {
      final samples = [
        h('u@shopco.example', 'your order', mid: 'm1@x', auth: 'green',
            label: HistoryLabel.kept, outcome: 'safe_sender', safe: true, at: 5 * day),
      ];
      final records = [
        TrashRecord(
            messageId: normalizeMessageId('m1@x'),
            from: 'u@shopco.example',
            subject: 'your order',
            dateMs: 5 * day,
            headers: const {},
            body: 'thanks'),
      ];
      final c = await buildCorpus(
          records: records, history: historyOf(samples), currentRules: noRules);
      final e = c.entries.single;
      expect(e.fromTrash, isTrue);
      expect(e.authClass, 'green');
      expect(e.receivedAtMs, 5 * day);
    });

    test('loadHistory reads auth_class from content_history', () async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('safe_hist_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final main = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'spam_filter.db'));
      await main.execute('CREATE TABLE safe_senders (id INTEGER PRIMARY KEY, pattern TEXT)');
      await main.execute('CREATE TABLE scan_results (id INTEGER PRIMARY KEY, account_id TEXT)');
      await main.execute('''CREATE TABLE email_actions (
          id INTEGER PRIMARY KEY AUTOINCREMENT, scan_result_id INTEGER, email_id TEXT,
          email_from TEXT, email_subject TEXT, action_type TEXT, success INTEGER,
          is_safe_sender INTEGER, rfc5322_message_id TEXT)''');
      await main.close();
      final hist = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'content_history.db'));
      await hist.execute('''CREATE TABLE content_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL,
          message_id TEXT, provider_id TEXT, from_address TEXT, reply_to TEXT,
          return_path_domain TEXT, subject TEXT, outcome TEXT, user_decision TEXT,
          list_unsubscribe INTEGER DEFAULT 0, body_text TEXT, auth_class TEXT,
          received_at INTEGER)''');
      await hist.insert('content_history', {
        'account_id': 'a', 'from_address': 'u@x.example', 'subject': 's',
        'outcome': 'safe_sender', 'auth_class': 'green', 'received_at': 7,
      });
      await hist.insert('content_history', {
        'account_id': 'a', 'from_address': 'v@x.example', 'subject': 't',
        'outcome': 'no_rule', 'auth_class': '',
      });
      await hist.close();
      final h0 = await loadHistory(dir.path, appData: 'Z:\\none');
      final classes = h0.samples.map((s) => s.authClass).toList();
      expect(classes, containsAll(['green', null]), reason: 'blank stored class reads as unknown');
    });

    test('the report states the threshold, the proxy gate, and hides domains by default', () async {
      final r = await run([...safeFrom('goodco.example', 6), ...spamFrom('junk.example', 30)]);
      final hidden = renderSafeReport(r);
      expect(hidden, contains('at most $kSpamHitsMax emails'));
      expect(hidden, contains('0.50%'));
      expect(hidden, contains('PROXY'));
      expect(hidden, isNot(contains('goodco.example')));
      expect(renderSafeReport(r, showDomains: true), contains('goodco.example'));
    });

    test('an output path under the live app data folder is refused', () {
      expect(
          () => writeSafeOutput(
              p.join('C:', 'live', 'MyEmailSpamFilter', 'out.yaml'), 'x',
              appData: 'C:\\live'),
          throwsStateError);
    });
  });
}
