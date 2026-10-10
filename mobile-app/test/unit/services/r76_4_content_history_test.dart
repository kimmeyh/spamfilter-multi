/// R76-4 (Sprint 78, ADR-0047): the dev-only content history.
///
/// T-1 (AC-1) the gate is inert outside a dev build and with the switch off;
/// T-2 (AC-2) unique emails decided from headers -- a new email fetches its
/// text once, a repeat sighting (same or another folder) fetches nothing and
/// writes no row; T-3 (AC-3) HTML-only and nested Gmail bodies give readable
/// text, capped at 64 KB; T-4 (AC-4) a user decision updates the stored row,
/// by identity or by provider id; T-5 (AC-5) account and full deletion.
///
/// What these do NOT catch: a real IMAP/Gmail server's MIME (fixtures stand
/// in), the scanner's call site (pinned by `r76_4_content_history_policy_test`
/// source checks and the Windows DEV manual scan in the DoD), or two writers
/// racing on a real disk (the UNIQUE index is the guarantee; tested here only
/// as INSERT OR IGNORE on one connection).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/services/content_history.dart';
import 'package:my_email_spam_filter/core/services/content_text_extractor.dart';
import 'package:my_email_spam_filter/core/storage/content_history_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

EmailMessage msg(String id,
        {String? mid, String folder = 'INBOX', String from = 'a@spam.example'}) =>
    EmailMessage(
      id: id,
      from: from,
      subject: 'Subject $id',
      body: '',
      headers: {
        'From': '"Spam Team" <$from>',
        'Return-Path': '<bounce@mailer.spam.example>',
        'List-Unsubscribe': '<mailto:u@spam.example>',
      },
      receivedDate: DateTime(2026, 10, 10, 9),
      folderName: folder,
      messageIdHeader: mid,
    );

String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

void main() {
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;
  late Directory tmp;
  late ContentHistoryStore store;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    tmp = await Directory.systemTemp.createTemp('r764_');
    store = ContentHistoryStore(path: p.join(tmp.path, 'content_history.db'));
  });

  tearDown(() async {
    ContentHistory.debugIsDevOverride = null;
    await store.close();
    await testHelper.tearDown();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('T-1 (AC-1): the gate', () {
    test('a prod build is never active, even with the switch on', () async {
      final settings = SettingsStore(testHelper.dbHelper);
      await settings.setContentHistoryEnabled(true);
      ContentHistory.debugIsDevOverride = false;
      expect(ContentHistory.isAvailable, isFalse);
      expect(await ContentHistory.isActive(settings), isFalse);
    });

    test('a dev build is active only with the switch on (off by default)',
        () async {
      final settings = SettingsStore(testHelper.dbHelper);
      ContentHistory.debugIsDevOverride = true;
      expect(await ContentHistory.isActive(settings), isFalse,
          reason: 'the switch defaults to off');
      await settings.setContentHistoryEnabled(true);
      expect(await ContentHistory.isActive(settings), isTrue);
    });

    test('a decision with the history off writes nothing and creates no file',
        () async {
      ContentHistory.debugIsDevOverride = false;
      await ContentHistory.recordDecision(
        settings: SettingsStore(testHelper.dbHelper),
        accountId: 'acct',
        email: msg('1', mid: '<m1@x>'),
        decision: 'block:from',
        store: store,
      );
      expect(store.fileExists(), isFalse);
    });
  });

  group('T-2 (AC-2): unique emails, decided from headers', () {
    ContentHistoryCapture capture(List<String> fetched) => ContentHistoryCapture(
          accountId: 'acct',
          scanType: 'background',
          platform: 'windows',
          store: store,
          fetchText: (m) async {
            fetched.add(m.id);
            return 'Body of ${m.id}';
          },
        );

    test('N new emails store N rows and fetch N bodies; a second scan stores '
        'and fetches nothing; another folder updates last-seen only', () async {
      final batch = [msg('1', mid: '<m1@x>'), msg('2', mid: '<m2@x>'), msg('3')];
      final noMatch = EvaluationResult.noMatch();

      final fetched1 = <String>[];
      final c1 = capture(fetched1);
      await c1.beginBatch(batch);
      for (final m in batch) {
        await c1.record(m, noMatch);
      }
      expect(await store.count(), 3);
      expect(fetched1, ['1', '2', '3']);
      expect(c1.stored, 3);

      final fetched2 = <String>[];
      final c2 = capture(fetched2);
      await c2.beginBatch(batch);
      for (final m in batch) {
        await c2.record(m, noMatch);
      }
      expect(await store.count(), 3, reason: 'a repeat scan writes no row');
      expect(fetched2, isEmpty, reason: 'a known email fetches no body');

      // The Fold deleted message 1; Windows DEV now sees it in Trash.
      final moved = msg('99', mid: '<m1@x>', folder: 'Trash');
      final fetched3 = <String>[];
      final c3 = capture(fetched3);
      await c3.beginBatch([moved]);
      await c3.record(moved, noMatch);
      expect(await store.count(), 3);
      expect(fetched3, isEmpty);
      final db = await store.database;
      final row = (await db.query('content_history',
              where: 'message_id = ?', whereArgs: ['<m1@x>']))
          .single;
      expect(row['first_folder'], 'INBOX');
      expect(row['last_folder'], 'Trash');
    });

    test('the stored row carries the header fields and outcome', () async {
      final fetched = <String>[];
      final c = capture(fetched);
      final m = msg('1', mid: '<m1@x>');
      await c.beginBatch([m]);
      await c.record(
          m,
          EvaluationResult(
              shouldDelete: true,
              shouldMove: false,
              matchedRule: 'Block_spam',
              matchedPattern: r'@spam\.example$'));
      final db = await store.database;
      final row = (await db.query('content_history')).single;
      expect(row['from_name'], 'Spam Team');
      expect(row['return_path_domain'], 'mailer.spam.example');
      expect(row['list_unsubscribe'], 1);
      expect(row['outcome'], 'delete');
      expect(row['matched_rule'], 'Block_spam');
      expect(row['body_text'], 'Body of 1');
      expect(row['scan_type'], 'background');
      expect(row['platform'], 'windows');
    });

    test('a capture failure never throws into the scan', () async {
      final c = ContentHistoryCapture(
        accountId: 'acct',
        scanType: 'manual',
        platform: 'windows',
        store: store,
        fetchText: (m) async => throw StateError('network down'),
      );
      final m = msg('1', mid: '<m1@x>');
      await c.beginBatch([m]);
      await c.record(m, EvaluationResult.noMatch());
    });
  });

  group('T-3 (AC-3): readable text', () {
    test('htmlToText drops script/style and tags, keeps lines and entities',
        () {
      final text = htmlToText('<html><head><style>p{}</style></head><body>'
          '<p>Win a <b>prize</b> &amp; more</p><script>x()</script>'
          '<div>Line&nbsp;two<br>three</div></body></html>');
      expect(text, 'Win a prize & more\nLine two\nthree');
    });

    test('a nested Gmail multipart gives its text/plain part', () {
      final payload = gmail.MessagePart(mimeType: 'multipart/mixed', parts: [
        gmail.MessagePart(mimeType: 'multipart/alternative', parts: [
          gmail.MessagePart(
              mimeType: 'text/plain',
              body: gmail.MessagePartBody(data: b64('Nested plain'))),
          gmail.MessagePart(
              mimeType: 'text/html',
              body: gmail.MessagePartBody(data: b64('<p>Nested html</p>'))),
        ]),
      ]);
      expect(gmailPartText(payload), 'Nested plain');
    });

    test('an HTML-only Gmail message gives converted text; attachments are '
        'skipped', () {
      final payload = gmail.MessagePart(mimeType: 'multipart/mixed', parts: [
        gmail.MessagePart(
            mimeType: 'text/plain',
            filename: 'notes.txt',
            body: gmail.MessagePartBody(data: b64('ATTACHMENT'))),
        gmail.MessagePart(
            mimeType: 'text/html',
            body: gmail.MessagePartBody(data: b64('<p>Only <i>html</i></p>'))),
      ]);
      expect(gmailPartText(payload), 'Only html');
    });

    test('the body is capped at 64 KB on a character boundary', () {
      final big = 'é' * 40000; // 2 bytes each = 80,000 bytes
      final capped = capContentText(big);
      expect(capped.truncated, isTrue);
      expect(utf8.encode(capped.text).length,
          lessThanOrEqualTo(kContentHistoryMaxBodyBytes));
      expect(capped.text.endsWith('é'), isTrue);
      expect(capContentText('short').truncated, isFalse);
    });
  });

  group('T-4 (AC-4): the user decision', () {
    test('found by identity hash, else by provider id', () async {
      final c = ContentHistoryCapture(
        accountId: 'acct',
        scanType: 'manual',
        platform: 'windows',
        store: store,
        fetchText: (m) async => 'x',
      );
      final withMid = msg('1', mid: '<m1@x>');
      final noMid = msg('2');
      await c.beginBatch([withMid, noMid]);
      await c.record(withMid, EvaluationResult.noMatch());
      await c.record(noMid, EvaluationResult.noMatch());

      expect(
          await store.recordDecision(
              accountId: 'acct',
              identityHash: ContentHistory.identityHash('acct', withMid),
              decision: 'safe_sender:exact'),
          1);
      expect(
          await store.recordDecision(
              accountId: 'acct', providerId: '2', decision: 'block:from'),
          1,
          reason: 'Review rows carry no Message-ID; the provider id finds them');
      final db = await store.database;
      final decisions = (await db.query('content_history', orderBy: 'id'))
          .map((r) => r['user_decision'])
          .toList();
      expect(decisions, ['safe_sender:exact', 'block:from']);
    });
  });

  group('T-5 (AC-5): deletion', () {
    test('an account\'s rows go; "Delete content history" removes the file',
        () async {
      for (final acct in ['a', 'b']) {
        final c = ContentHistoryCapture(
          accountId: acct,
          scanType: 'manual',
          platform: 'windows',
          store: store,
          fetchText: (m) async => 'x',
        );
        final m = msg('1', mid: '<m1@x>');
        await c.beginBatch([m]);
        await c.record(m, EvaluationResult.noMatch());
      }
      expect(await store.count(), 2);
      expect(await store.deleteAccount('a'), 1);
      expect(await store.count(), 1);

      await store.deleteAll();
      expect(store.fileExists(), isFalse);
    });
  });
}
