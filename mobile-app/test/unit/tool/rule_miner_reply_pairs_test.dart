// F270 R-4 (Sprint 83): tests for the rule miner reply-pair mode (tool/
// rule_miner/reply_pair_core.dart). The database is a small temp file with only
// the four tables the tool reads. All addresses use .example domains.
//
// ADR-0042: developer tool on Harold's Windows PC only; no Android path.
//
// What these tests do NOT catch: the real Sent folder (encodings, Cc and Bcc
// handling, mailing-list recipients) and the IMAP probe itself, a scratch
// script whose read-only property is asserted in the script (EXAMINE before
// any fetch, headers only through BODY.PEEK).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../tool/rule_miner/reply_pair_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('reply_pairs_');
    final db = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'spam_filter.db'));
    await db.execute('CREATE TABLE accounts (email TEXT)');
    await db.execute('CREATE TABLE safe_senders (pattern TEXT)');
    await db.execute('CREATE TABLE unmatched_emails '
        '(from_email TEXT, auth_classification TEXT)');
    await db.execute('CREATE TABLE email_actions '
        '(email_from TEXT, auth_classification TEXT, action_type TEXT)');
    await db.insert('accounts', {'email': 'me@mine.example'});
    await db.close();
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> seed(Future<void> Function(Database db) f) async {
    final db = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'spam_filter.db'));
    await f(db);
    await db.close();
  }

  SentRecord sent(List<String> to) => SentRecord(to, 1);

  test('a recipient who also sent mail, all green, is a candidate', () async {
    await seed((db) async {
      await db.insert('unmatched_emails',
          {'from_email': 'Pal <pal@club.example>', 'auth_classification': 'green'});
      await db.insert('email_actions', {
        'email_from': 'pal@club.example',
        'auth_classification': 'green',
        'action_type': 'none'
      });
    });
    final r = await mineReplyPairs(
        [sent(['pal@club.example', 'nobody@never.example']), sent(['pal@club.example'])],
        dir.path);
    expect(r.sentEmails, 2);
    expect(r.recipients, 2);
    expect(r.pairs.map((x) => x.address), ['pal@club.example']);
    final pair = r.find('pal@club.example')!;
    expect(pair.status, PairStatus.candidate);
    expect(pair.sentCount, 2);
    expect(pair.inboundCount, 2);
    expect(pair.recommendedType, 'entireDomain');
    expect(renderReplyPairYaml(r), contains('club'));
  });

  test('the gate: any non-green class, a rule delete or a safe sender blocks',
      () async {
    await seed((db) async {
      await db.insert('unmatched_emails',
          {'from_email': 'grey@g.example', 'auth_classification': 'grey'});
      await db.insert('unmatched_emails',
          {'from_email': 'mixed@m.example', 'auth_classification': 'green'});
      await db.insert('unmatched_emails',
          {'from_email': 'mixed@m.example', 'auth_classification': null});
      await db.insert('email_actions', {
        'email_from': 'del@d.example',
        'auth_classification': 'green',
        'action_type': 'delete'
      });
      await db.insert('unmatched_emails',
          {'from_email': 'known@k.example', 'auth_classification': 'green'});
      await db.insert('safe_senders', {'pattern': r'^known@k\.example$'});
    });
    final r = await mineReplyPairs(
        [sent(['grey@g.example', 'mixed@m.example', 'del@d.example', 'known@k.example'])],
        dir.path);
    expect(r.find('grey@g.example')!.status, PairStatus.notGreen);
    expect(r.find('mixed@m.example')!.status, PairStatus.notGreen);
    expect(r.find('del@d.example')!.status, PairStatus.ruleDeleted);
    expect(r.find('known@k.example')!.status, PairStatus.alreadySafe);
    expect(r.candidates, isEmpty);
    expect(renderReplyPairYaml(r), contains('safe_senders: []'));
  });

  test('your own address is not a pair; a provider sender gets Exact Email',
      () async {
    await seed((db) async {
      await db.insert('unmatched_emails',
          {'from_email': 'me@mine.example', 'auth_classification': 'green'});
      await db.insert('unmatched_emails',
          {'from_email': 'bob@gmail.com', 'auth_classification': 'green'});
    });
    final r = await mineReplyPairs([sent(['me@mine.example', 'bob@gmail.com'])], dir.path);
    expect(r.pairs.map((x) => x.address), ['bob@gmail.com']);
    expect(r.find('bob@gmail.com')!.recommendedType, 'exact');
  });

  test('the report hides addresses unless asked', () async {
    await seed((db) async {
      await db.insert('unmatched_emails',
          {'from_email': 'pal@club.example', 'auth_classification': 'green'});
    });
    final r = await mineReplyPairs([sent(['pal@club.example'])], dir.path);
    expect(renderReplyPairReport(r), isNot(contains('pal@club.example')));
    expect(renderReplyPairReport(r, showAddresses: true), contains('pal@club.example'));
    expect(renderReplyPairReport(r), contains('Candidates (all stored mail green'));
  });

  test('readSentJsonl keeps recipient addresses only', () {
    final f = File(p.join(dir.path, 'sent.jsonl'));
    f.writeAsStringSync('${jsonEncode({'to': ['A@B.example', 'junk'], 'date_ms': 5})}\n\n'
        '${jsonEncode({'to': <String>[]})}\n');
    final recs = readSentJsonl(f.path);
    expect(recs.length, 2);
    expect(recs.first.to, ['a@b.example']);
    expect(recs.first.dateMs, 5);
  });
}
