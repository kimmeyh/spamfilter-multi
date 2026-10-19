// F267 (Sprint 80): tests for the rule evaluation harness in
// tool/rule_eval/rule_eval_core.dart. Every database here is a small fixture
// the test builds in a temp directory. No real data is read.
//
// ADR-0042: this is a developer tool that runs on Harold's Windows PC only.
// The engine it calls (RuleEvaluator, PatternCompiler) is the shared one the
// Windows and Android apps both use, unchanged. There is no Android path for
// the tool itself, and no platform primitive beyond SQLite files read on
// Windows.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/rule_eval/rule_eval_core.dart';

const _candidateYaml = '''
version: "1.0"
settings: {}
rules:
- name: R1Spamco
  enabled: "True"
  isLocal: "True"
  executionOrder: 10
  conditions:
    type: OR
    from:
    - '@spamco\\.example\$'
  actions:
    delete: true
- name: R2Bulk
  enabled: "True"
  isLocal: "True"
  executionOrder: 20
  conditions:
    type: OR
    from:
    - '@bulk\\.example\$'
  actions:
    delete: true
- name: R3Trusted
  enabled: "True"
  isLocal: "True"
  executionOrder: 30
  conditions:
    type: OR
    from:
    - '@trusted\\.com\$'
  actions:
    delete: true
- name: R4Dead
  enabled: "True"
  isLocal: "True"
  executionOrder: 40
  conditions:
    type: OR
    from:
    - '^[^@\\s]+@(?:[a-z0-9-]+\\.)*@bulk\\.example\$'
  actions:
    delete: true
- name: R6Few
  enabled: "True"
  isLocal: "True"
  executionOrder: 60
  conditions:
    type: OR
    from:
    - '^e[1-3]@spamco\\.example\$'
  actions:
    delete: true
- name: R5Move
  enabled: "True"
  isLocal: "True"
  executionOrder: 50
  conditions:
    type: OR
    from:
    - '@bulk\\.example\$'
  actions:
    delete: false
    move_to_folder: Junk
''';

Future<void> _buildFixture(String dir) async {
  final main = await databaseFactoryFfi.openDatabase(p.join(dir, 'spam_filter.db'));
  await main.execute('CREATE TABLE safe_senders (id INTEGER PRIMARY KEY, pattern TEXT)');
  await main.execute('CREATE TABLE scan_results (id INTEGER PRIMARY KEY, account_id TEXT)');
  await main.execute('''CREATE TABLE email_actions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, scan_result_id INTEGER, email_id TEXT,
      email_from TEXT, email_subject TEXT, action_type TEXT, success INTEGER,
      is_safe_sender INTEGER, rfc5322_message_id TEXT)''');
  await main.insert('safe_senders', {'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$'});
  await main.insert('scan_results', {'id': 1, 'account_id': 'acct1'});

  var seq = 0;
  Future<void> action(String from, String type, String msgId, {int success = 1}) async {
    await main.insert('email_actions', {
      'scan_result_id': 1,
      'email_id': 'e-$msgId',
      'email_from': from,
      'email_subject': 'subject ${seq++}',
      'action_type': type,
      'success': success,
      'is_safe_sender': type == 'safeSender' ? 1 : 0,
      'rfc5322_message_id': msgId,
    });
  }

  // e) three spamco emails first seen with no rule, later deleted. The first
  // is seen three times (none, none, delete) and must count ONCE.
  await action('e1@spamco.example', 'none', 'e1');
  await action('e1@spamco.example', 'none', 'e1');
  await action('e1@spamco.example', 'delete', 'e1');
  for (final id in ['e2', 'e3']) {
    await action('$id@spamco.example', 'none', id);
    await action('$id@spamco.example', 'delete', id);
  }
  // f) two spamco emails deleted on first sight (not No Rule first).
  await action('f1@spamco.example', 'delete', 'f1');
  await action('f2@spamco.example', 'delete', 'f2');
  // g) one spamco email the user kept (safe sender action).
  await action('g1@spamco.example', 'safeSender', 'g1');
  // d) the linked email: its content_history row carries Message-ID m-link.
  await action('d1@spamco.example', 'none', 'm-link');
  await action('d1@spamco.example', 'delete', 'm-link');
  await main.close();

  final hist = await databaseFactoryFfi.openDatabase(p.join(dir, 'content_history.db'));
  await hist.execute('''CREATE TABLE content_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL,
      message_id TEXT, provider_id TEXT, from_address TEXT, reply_to TEXT,
      return_path_domain TEXT, subject TEXT, outcome TEXT, user_decision TEXT,
      list_unsubscribe INTEGER DEFAULT 0, body_text TEXT)''');
  Future<void> row(String from, String outcome,
      {String? decision, String? msgId, String subject = 'hello'}) async {
    await hist.insert('content_history', {
      'account_id': 'acct1',
      'message_id': msgId,
      'provider_id': null,
      'from_address': from,
      'subject': subject,
      'outcome': outcome,
      'user_decision': decision,
      'body_text': 'body text',
    });
  }

  for (var i = 0; i < 12; i++) {
    await row('a$i@spamco.example', 'no_rule', decision: 'block:from'); // a
  }
  for (var i = 0; i < 4; i++) {
    await row('b$i@spamco.example', 'delete'); // b
  }
  for (var i = 0; i < 2; i++) {
    await row('c$i@spamco.example', 'no_rule'); // c, unlabeled
  }
  await row('d1@spamco.example', 'no_rule', msgId: 'm-link'); // d, linked
  for (var i = 0; i < 5; i++) {
    await row('o$i@otherco.example', 'no_rule', decision: 'block:from');
  }
  for (var i = 0; i < 20; i++) {
    await row('k$i@bulk.example', 'delete');
  }
  for (var i = 0; i < 20; i++) {
    await row('vip$i@trusted.com', 'delete');
  }
  await hist.close();
}

void main() {
  late Directory tmp;
  late String dbDir;
  late History history;
  late List<RuleReport> reports;

  RuleReport named(String name) => reports.firstWhere((r) => r.name == name);

  setUpAll(() async {
    sqfliteFfiInit();
    tmp = await Directory.systemTemp.createTemp('rule_eval_test_');
    dbDir = p.join(tmp.path, 'copy');
    Directory(dbDir).createSync();
    await _buildFixture(dbDir);
    final yamlPath = p.join(tmp.path, 'cand.yaml');
    File(yamlPath).writeAsStringSync(_candidateYaml);
    history = await loadHistory(dbDir);
    reports = await scoreCandidates(loadCandidates(yamlPath), history);
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // What T-1 does NOT catch: a wrong LABEL RULE that the fixture happens to
  // agree with (for example outcome 'delete' being a poor proxy for "the user
  // wanted it gone"); the fixture encodes the README definitions, so it
  // proves the code follows them, not that they are right. It also does not
  // exercise a real-size database or the WAL files of a live copy.
  test('T-1 report numbers equal hand-computed values on known labels', () {
    // 70 emails: 64 content_history rows (19 spamco + 5 otherco + 20 bulk +
    // 20 trusted) plus 6 email_actions-only groups (e1 e2 e3 f1 f2 g1). The
    // linked group d1 is consumed by its content_history row.
    expect(history.contentHistoryRows, 64);
    expect(history.samples.length, 70);
    expect(history.samples.where((s) => s.label == HistoryLabel.deleted).length, 67);
    expect(history.samples.where((s) => s.label == HistoryLabel.kept).length, 1);
    expect(history.samples.where((s) => s.label == HistoryLabel.unlabeled).length, 2);

    final r1 = named('R1Spamco');
    expect(r1.matches, 25); // 19 content rows + 6 action-only emails
    expect(r1.deletedMatches, 22); // 12 + 4 + 1 linked + 3 e + 2 f
    expect(r1.keptMatches, 1); // g1
    expect(r1.unlabeledMatches, 2); // c rows
    expect(r1.labeledMatches, 23);
    expect(r1.precision, closeTo(22 / 23, 1e-9));
    expect(r1.safeSenderHits, 0);
    // No Rule later deleted: 12 block + 1 linked + 3 e = 16 of 21 (plus 5 other).
    expect(r1.recallTotal, 21);
    expect(r1.recallHits, 16);
    expect(r1.recall, closeTo(16 / 21, 1e-9));
    expect(r1.passes, isFalse);
    expect(r1.failReasons, hasLength(1));
    expect(r1.failReasons.single, contains('precision'));

    final r2 = named('R2Bulk');
    expect(r2.matches, 20);
    expect(r2.deletedMatches, 20);
    expect(r2.precision, 1.0);
    expect(r2.safeSenderHits, 0);
    expect(r2.recallHits, 0);
    expect(r2.passes, isTrue);
    expect(r2.failReasons, isEmpty);
  });

  // What T-2 does NOT catch: a safe sender that is not in the table copy, or
  // a rule that reaches a safe sender only through a header or body pattern
  // (the hit is counted from the matched email's From, which covers those
  // too, but the fixture only uses a From pattern).
  test('T-2 a candidate that matches a safe sender FAILs for that reason alone', () {
    final r3 = named('R3Trusted');
    expect(r3.matches, 20);
    expect(r3.precision, 1.0); // would pass the precision bar
    expect(r3.labeledMatches, 20); // and the volume bar
    expect(r3.safeSenderHits, 20);
    expect(r3.passes, isFalse);
    expect(r3.failReasons, hasLength(1));
    expect(r3.failReasons.single, contains('safe sender'));
  });

  // F268 found that the scored message carried no From header, so every
  // `header` domain rule (the app's own style, all 2,202 current rules) scored
  // 0 matches. What this does NOT catch: other headers the app's rules read
  // that the history does not store (raw headers are not kept).
  test('the scored message carries the From header that header rules read', () {
    final sample = HistorySample(
      source: 'content_history',
      accountId: 'aol-a@b.com',
      from: 'news@spam.example.com',
      subject: 's',
      body: '',
      headers: const {'reply-to': 'x@y.com'},
      label: HistoryLabel.deleted,
      noRuleLaterDeleted: false,
    );
    final headers = sample.toMessage().headers;
    expect(headers['from'], 'news@spam.example.com');
    expect(headers['reply-to'], 'x@y.com');
  });

  // What this does NOT catch: unmatchable shapes the F266 check does not
  // know, and the header-pattern case where F266 is deliberately not applied.
  test('a dead from pattern and a non-delete rule FAIL with a named reason', () {
    final dead = named('R4Dead');
    expect(dead.matches, 0);
    expect(dead.passes, isFalse);
    expect(dead.failReasons.join(' | '), contains('F266'));

    final move = named('R5Move');
    expect(move.matches, 20);
    expect(move.passes, isFalse);
    expect(move.failReasons.join(' | '), contains('not a delete rule'));
  });

  // What this does NOT catch: a different volume floor (it pins "3 labeled
  // matches fail", not the exact value 20, which T-1's R2 and T-2's R3 sit on).
  test('a perfect rule with too few labeled matches FAILs for volume alone', () {
    final few = named('R6Few');
    expect(few.matches, 3);
    expect(few.precision, 1.0);
    expect(few.safeSenderHits, 0);
    expect(few.failReasons, hasLength(1));
    expect(few.failReasons.single, contains('labeled matches'));
  });

  // What this does NOT catch: another way to open a database. It proves the
  // helper every load goes through rejects writes.
  test('the read-only opener rejects a write', () async {
    final db = await openReadOnly(p.join(dbDir, 'spam_filter.db'));
    try {
      await expectLater(
          db.insert('safe_senders', {'pattern': 'x'}), throwsA(isA<DatabaseException>()));
    } finally {
      await db.close();
    }
  });

  // What T-3 does NOT catch: a live path spelled through a junction or a
  // network share this machine resolves differently; the check resolves
  // symlinks but is lexical for paths that do not exist yet.
  test('T-3 a live-database path is refused, a copy elsewhere is not', () async {
    final fakeAppData = p.join(tmp.path, 'Roaming');
    final live = p.join(fakeAppData, 'MyEmailSpamFilter', 'MyEmailSpamFilter_Dev');
    Directory(live).createSync(recursive: true);
    File(p.join(live, 'spam_filter.db')).writeAsStringSync('not a database');

    expect(liveDatabaseRefusal(live, appData: fakeAppData), contains('REFUSED'));
    expect(
        liveDatabaseRefusal(p.join(live, 'spam_filter.db-wal'), appData: fakeAppData),
        contains('REFUSED'));
    // The production folder name is refused as well (prefix match).
    expect(
        liveDatabaseRefusal(p.join(fakeAppData, 'MyEmailSpamFilter', 'MyEmailSpamFilter'),
            appData: fakeAppData),
        contains('REFUSED'));
    expect(liveDatabaseRefusal(dbDir, appData: fakeAppData), isNull);

    // The loader itself refuses, before it opens anything.
    await expectLater(loadHistory(live, appData: fakeAppData),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('REFUSED'))));
  });

  // What this does NOT catch: a write made by some other tool while this one
  // runs; it proves only that loading and scoring leave the copy untouched.
  test('opening a copy is read-only: bytes and folder contents are unchanged', () async {
    String snapshot() {
      final files = Directory(dbDir).listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files
          .map((f) => '${p.basename(f.path)}:${f.lengthSync()}:${f.readAsBytesSync().fold<int>(0, (h, b) => (h * 31 + b) & 0x7fffffff)}')
          .join('|');
    }

    final before = snapshot();
    final again = await loadHistory(dbDir);
    await scoreCandidates(
        loadCandidates(p.join(tmp.path, 'cand.yaml')), again);
    expect(snapshot(), before);
  });
}
