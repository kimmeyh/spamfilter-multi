// F268 (Sprint 80): tests for the rule miner in tool/rule_miner. Every database
// is a small fixture the test builds in a temp directory. No real data is read.
//
// ADR-0042: this is a developer tool that runs on Harold's Windows PC only.
// The engine it calls (RuleEvaluator, PatternCompiler) is the shared one both
// apps use, unchanged. There is no Android path for the tool itself; the YAML
// it writes imports on both apps through Settings > Import / Export YAML
// (that import path is covered by the existing YAML tests, not here).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/rule_miner/rule_miner_core.dart';

Future<void> _buildFixture(String dir) async {
  final main = await databaseFactoryFfi.openDatabase(p.join(dir, 'spam_filter.db'));
  await main.execute('CREATE TABLE safe_senders (id INTEGER PRIMARY KEY, pattern TEXT)');
  await main.execute('CREATE TABLE scan_results (id INTEGER PRIMARY KEY, account_id TEXT)');
  await main.execute('''CREATE TABLE email_actions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, scan_result_id INTEGER, email_id TEXT,
      email_from TEXT, email_subject TEXT, action_type TEXT, success INTEGER,
      is_safe_sender INTEGER, rfc5322_message_id TEXT)''');
  await main.execute('''CREATE TABLE rules (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, enabled INTEGER,
      execution_order INTEGER, condition_type TEXT, condition_from TEXT,
      condition_header TEXT, condition_subject TEXT, condition_body TEXT,
      action_delete INTEGER, exception_from TEXT, exception_header TEXT,
      exception_subject TEXT, exception_body TEXT)''');
  await main.insert('scan_results', {'id': 1, 'account_id': 'acct1'});
  await main.insert('safe_senders', {'pattern': r'^vip@trustedco\.example$'});
  await main.insert('rules', {
    'name': 'ExistingCovered',
    'enabled': 1,
    'execution_order': 1,
    'condition_type': 'OR',
    'condition_header': jsonEncode([r'@(?:[a-z0-9-]+\.)*coveredco\.example$']),
    'action_delete': 1,
  });
  await main.close();

  final hist = await databaseFactoryFfi.openDatabase(p.join(dir, 'content_history.db'));
  await hist.execute('''CREATE TABLE content_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL,
      message_id TEXT, provider_id TEXT, from_address TEXT, reply_to TEXT,
      return_path_domain TEXT, subject TEXT, outcome TEXT, user_decision TEXT,
      list_unsubscribe INTEGER DEFAULT 0, body_text TEXT)''');
  Future<void> row(String from, String subject,
      {String outcome = 'no_rule', String? decision, String? body}) async {
    await hist.insert('content_history', {
      'account_id': 'acct1',
      'from_address': from,
      'subject': subject,
      'outcome': outcome,
      'user_decision': decision,
      'body_text': body,
    });
  }

  // Planted spam domain: 25 user-blocked emails, unique one-word subjects.
  for (var i = 0; i < 25; i++) {
    await row('a$i@plantco.example', 'invoice$i', decision: 'block:from');
  }
  // Planted subject phrase from 25 different one-off domains.
  for (var i = 0; i < 25; i++) {
    await row('u@prize$i.example', i.isEven ? 'claim your free - prize ref$i' : 'claim your free prize ref$i', decision: 'block:subject');
  }
  // Planted body phrase from 25 different one-off domains, unique subjects.
  for (var i = 0; i < 25; i++) {
    await row('u@bodyco$i.example', 'bxa$i bxb$i bxc$i',
        decision: 'block:from',
        body: 'please verify your account password immediately zzb$i');
  }
  // T-2: already covered by the current rule (verdicts of an EXISTING rule).
  for (var i = 0; i < 25; i++) {
    await row('c$i@coveredco.example', 'covered phrase here $i', outcome: 'delete');
  }
  // T-3: a wildcard on this domain would hit the safe sender vip@ (deleted
  // label, so safe-sender is the only failed check).
  for (var i = 0; i < 25; i++) {
    await row('a$i@trustedco.example', 'trusted$i', decision: 'block:from');
  }
  await row('vip@trustedco.example', 'vipnote', outcome: 'delete');
  // Near miss: perfect precision, only 5 emails.
  for (var i = 0; i < 5; i++) {
    await row('a$i@smallco.example', 'smallnote$i', decision: 'block:from');
  }
  // T-4: a recurring TWO-word subject (never proposed).
  for (var i = 0; i < 25; i++) {
    await row('u@sale$i.example', 'big sale', decision: 'block:subject');
  }
  // Phrase also seen in KEPT mail (rejected before scoring).
  for (var i = 0; i < 25; i++) {
    await row('u@offer$i.example', 'limited time offer ref$i', decision: 'block:subject');
  }
  await row('friend@kept.example', 'limited time offer ref0 from a friend',
      decision: 'safe_sender:from');
  await hist.close();
}

void main() {
  late Directory tmp;
  late String dbDir;
  late MinerResult result;
  late String yaml;
  late String report;

  Iterable<ScoredCandidate> byKey(String key) =>
      result.scored.where((s) => s.candidate.key == key);

  setUpAll(() async {
    sqfliteFfiInit();
    tmp = await Directory.systemTemp.createTemp('rule_miner_test_');
    dbDir = p.join(tmp.path, 'copy');
    Directory(dbDir).createSync();
    await _buildFixture(dbDir);
    result = await mine(dbDir);
    yaml = renderYaml(result.passed);
    report = renderMinerReport(result);
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // What T-1 does NOT catch: a miner that works on this tidy fixture but
  // mis-ranks or mis-groups real, messy subjects; and base-domain handling of
  // country-code second levels (not in the fixture).
  test('T-1 the planted domain, subject phrase and body phrase are proposed and PASS', () {
    final dom = byKey('plantco.example').single;
    expect(dom.passes, isTrue, reason: dom.report.failReasons.join('; '));
    expect(dom.candidate.pattern, r'@(?:[a-z0-9-]+\.)*plantco\.example$');
    expect(dom.candidate.support, 25);
    expect(dom.candidate.recallSupport, 25);
    expect(dom.report.deletedMatches, 25);

    final subj = byKey('claim your free prize').single;
    expect(subj.passes, isTrue, reason: subj.report.failReasons.join('; '));
    expect(subj.candidate.kind, CandidateKind.subject);
    expect(subj.candidate.pattern, r'\bclaim[^a-z0-9]+your[^a-z0-9]+free[^a-z0-9]+prize\b');

    final body = result.passed.where((s) => s.candidate.kind == CandidateKind.body);
    expect(body, hasLength(1));
    expect(body.single.candidate.key, 'please verify your account password immediately');

    expect(result.passed, hasLength(3));
    // The importable YAML holds exactly the PASS rules and parses back.
    expect(yaml, contains('plantco'));
    expect(yaml, contains(r'claim[^a-z0-9]+your[^a-z0-9]+free[^a-z0-9]+prize'));
    expect(yaml, contains(r'verify[^a-z0-9]+your[^a-z0-9]+account'));
    expect('name:'.allMatches(yaml), hasLength(3));
    expect(yaml, contains('delete: true'));
  });

  // What T-2 does NOT catch: a current rule that covers a domain only through
  // a subject or body condition (the fixture covers it through a header).
  test('T-2 mail a current rule already catches is not mined', () {
    expect(byKey('coveredco.example'), isEmpty);
    expect(result.scored.where((s) => s.candidate.key.contains('covered phrase')), isEmpty);
    expect(yaml, isNot(contains('coveredco')));
    // 25 covered rows are history but not in the pool.
    expect(result.currentRuleCount, 1);
  });

  // What T-3 does NOT catch: a safe sender that matches only through a pattern
  // shape the F267 core mishandles; the core is tested in rule_eval_test.
  test('T-3 a candidate that hits a safe sender is scored FAIL and not written', () {
    final trusted = byKey('trustedco.example').single;
    expect(trusted.passes, isFalse);
    expect(trusted.report.safeSenderHits, 1);
    expect(trusted.candidate.support, 25); // the safe sender vip@ is not mined
    expect(trusted.report.precision, 1.0);
    expect(trusted.report.failReasons, hasLength(1));
    expect(trusted.report.failReasons.single, contains('safe sender'));
    expect(yaml, isNot(contains('trustedco')));
    expect(report, contains('domain trustedco.example'));
  });

  // What this does NOT catch: any other F266 shape; it proves a dead pattern
  // fed through the same scoring path as mined candidates is marked FAIL and
  // is left out of the YAML.
  test('T-3 a candidate failing F266 is scored FAIL and not written', () async {
    final dead = MinedCandidate(
      id: 'D999',
      kind: CandidateKind.domain,
      key: 'deadco.example',
      pattern: r'^[^@\s]+@(?:[a-z0-9-]+\.)*@deadco\.example$',
      words: 2,
      support: 3,
      recallSupport: 0,
    );
    final scored = await scoreMined([dead], result.history);
    expect(scored.single.passes, isFalse);
    expect(scored.single.report.failReasons.join(' | '), contains('F266'));
    expect(renderYaml(scored.where((s) => s.passes).toList()), isNot(contains('deadco')));
  });

  // What this does NOT catch: a different volume floor; near misses are
  // identified by the one failed check being the volume check.
  test('a perfect candidate with too few emails is a near miss, never in the YAML', () {
    final near = byKey('smallco.example').single;
    expect(near.nearMiss, isTrue);
    expect(near.passes, isFalse);
    expect(near.report.precision, 1.0);
    expect(near.report.labeledMatches, 5);
    expect(result.nearMisses.map((s) => s.candidate.key), contains('smallco.example'));
    expect(yaml, isNot(contains('smallco')));
    expect(report, contains('NEAR MISS: 1'));
  });

  // What T-4 does NOT catch: an over-broad shape the guard does not list (for
  // example a 3-word phrase made only of common words is covered by the
  // meaningful-word rule, but a 3-word phrase of rare filler is accepted).
  test('T-4 over-broad candidates are rejected by the guard and never mined', () {
    MinedCandidate c(CandidateKind k, String key, int words) => MinedCandidate(
        id: 'X', kind: k, key: key, pattern: 'x', words: words, support: 9, recallSupport: 0);
    expect(overBroadReason(c(CandidateKind.domain, 'com', 1)), contains('TLD'));
    expect(overBroadReason(c(CandidateKind.domain, 'gmail.com', 2)), contains('provider'));
    expect(overBroadReason(c(CandidateKind.domain, 'co.uk', 2)), contains('public suffix'));
    expect(overBroadReason(c(CandidateKind.subject, 'big sale', 2)), contains('shorter'));
    expect(overBroadReason(c(CandidateKind.subject, 'of the new', 3)), contains('meaningful'));
    expect(overBroadReason(c(CandidateKind.body, 'big sale now', 3)), contains('shorter'));
    expect(overBroadReason(c(CandidateKind.domain, 'plantco.example', 2)), isNull);
    expect(overBroadReason(c(CandidateKind.subject, 'claim your free prize', 4)), isNull);

    // And through the miner: the recurring two-word subject yields nothing.
    expect(result.scored.where((s) => s.candidate.key.contains('big sale')), isEmpty);
    expect(yaml, isNot(contains('big')));
    expect(result.scored.where((s) => s.candidate.words < 2), isEmpty);
  });

  // What this does NOT catch: kept mail whose subject only partly overlaps the
  // phrase; the pre-filter needs the whole phrase as consecutive words.
  test('a phrase that also appears in kept mail is rejected before scoring', () {
    expect(result.scored.where((s) => s.candidate.key == 'limited time offer'), isEmpty);
    expect(result.rejectedBeforeScoring['phrase appears in kept mail'], greaterThan(0));
    expect(yaml, isNot(contains('limited')));
  });

  // What this does NOT catch: a phrase or domain leaking by some other path
  // (a log line). It checks the side report text only.
  test('the report holds counts, ids and domains, never phrase text', () {
    expect(report, isNot(contains('claim your free prize')));
    expect(report, isNot(contains('verify')));
    expect(report, contains('PASS: 3'));
    expect(report, contains('domain plantco.example'));
    expect(result.poolSize, greaterThan(0));
  });

  // What T-5 does NOT catch: a live path reached through a junction this
  // machine resolves differently (the F267 check resolves existing links).
  test('T-5 a live-database path is refused for input and for output', () async {
    final fakeAppData = p.join(tmp.path, 'Roaming');
    final live = p.join(fakeAppData, 'MyEmailSpamFilter', 'MyEmailSpamFilter_Dev');
    Directory(live).createSync(recursive: true);
    File(p.join(live, 'spam_filter.db')).writeAsStringSync('not a database');

    await expectLater(mine(live, appData: fakeAppData),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('REFUSED'))));
    final out = p.join(live, 'proposed.yaml');
    expect(() => writeOutput(out, 'x', appData: fakeAppData), throwsStateError);
    expect(File(out).existsSync(), isFalse);

    final ok = p.join(tmp.path, 'out.yaml');
    writeOutput(ok, 'x', appData: fakeAppData);
    expect(File(ok).existsSync(), isTrue);
  });

  // What this does NOT catch: a write by another tool while this one runs.
  test('mining leaves the database copy byte for byte unchanged', () async {
    String snapshot() {
      final files = Directory(dbDir).listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files
          .map((f) =>
              '${p.basename(f.path)}:${f.lengthSync()}:${f.readAsBytesSync().fold<int>(0, (h, b) => (h * 31 + b) & 0x7fffffff)}')
          .join('|');
    }

    final before = snapshot();
    await mine(dbDir);
    expect(snapshot(), before);
  });
}
