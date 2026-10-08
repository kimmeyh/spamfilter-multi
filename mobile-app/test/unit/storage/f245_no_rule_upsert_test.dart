/// F245 (Sprint 77, ADR-0045): one No Rule row per email.
///
/// Covers the single writer ([UnmatchedEmailStore.upsertUnmatchedEmails]), its
/// account-scoped identity, the Q20 "dismissed comes back" reset, retention on
/// last-seen (Q22), the Review query across scans (Q21), and the real
/// `DatabaseHelper` v11 -> v12 upgrade with its dedup step.
///
/// What these tests do NOT catch (one line each):
///   - upsert: two isolates/processes racing the same email on a real device
///     (BEGIN IMMEDIATE serialization is named in the code, proven on neither
///     platform here);
///   - migration: a production database whose duplicates differ in
///     `folder_name` is treated as distinct emails by design, not tested as a
///     merge;
///   - retention: the clock is real, so a row exactly at the cutoff is not
///     exercised.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late UnmatchedEmailStore store;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = UnmatchedEmailStore(testHelper.dbHelper);
    await testHelper.createTestAccount('acct-a');
    await testHelper.createTestAccount('acct-b');
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  UnmatchedEmail email(
    int scanId, {
    String uid = '232848',
    String folder = 'INBOX',
    String? subject = 'Hello',
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) =>
      UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'email_id',
        providerIdentifierValue: uid,
        fromEmail: 'sender@spam.example',
        subject: subject,
        folderName: folder,
        createdAt: createdAt ?? DateTime.now(),
        lastSeenAt: lastSeenAt,
      );

  Future<List<Map<String, Object?>>> allRows() async =>
      (await testHelper.dbHelper.database).query('unmatched_emails');

  group('T-1 -- one row per email, refreshed in place', () {
    test('two scans that both find the same email leave ONE row on the second '
        'scan, keeping the row id and first-seen time', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final scan2 = await testHelper.createTestScanResult('acct-a');
      final first = DateTime.now().subtract(const Duration(days: 3));
      final second = DateTime.now();

      final r1 = await store.upsertUnmatchedEmails(
          [email(scan1, createdAt: first)]);
      final r2 = await store.upsertUnmatchedEmails(
          [email(scan2, createdAt: second)]);

      expect(r1.single.outcome, UnmatchedUpsertOutcome.inserted);
      expect(r2.single.outcome, UnmatchedUpsertOutcome.unchanged);
      expect(r2.single.id, r1.single.id,
          reason: 'the Review multi-select is keyed on the row id');
      final rows = await allRows();
      expect(rows, hasLength(1));
      expect(rows.single['scan_result_id'], scan2);
      expect(rows.single['created_at'], first.millisecondsSinceEpoch,
          reason: 'created_at stays the FIRST-seen time');
      expect(rows.single['last_seen_at'], second.millisecondsSinceEpoch);
    });

    test('a changed subject is reported as changed and refreshed', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final scan2 = await testHelper.createTestScanResult('acct-a');
      await store.upsertUnmatchedEmails([email(scan1, subject: 'old')]);
      final r = await store.upsertUnmatchedEmails([email(scan2, subject: 'new')]);
      expect(r.single.outcome, UnmatchedUpsertOutcome.changed);
      expect((await allRows()).single['subject'], 'new');
    });

    test('the same email twice in ONE batch yields one row (second is '
        'unchanged)', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final r = await store.upsertUnmatchedEmails(
          [email(scan1), email(scan1)]);
      expect(r.map((e) => e.outcome), [
        UnmatchedUpsertOutcome.inserted,
        UnmatchedUpsertOutcome.unchanged,
      ]);
      expect(await allRows(), hasLength(1));
    });

    test('the legacy add methods route through the same upsert', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final id1 = await store.addUnmatchedEmail(email(scan1));
      final ids = await store.addUnmatchedEmailBatch([email(scan1)]);
      expect(ids.single, id1);
      expect(await allRows(), hasLength(1));
    });
  });

  group('T-2 -- identity is scoped to the account and the folder', () {
    test('two accounts holding the same UID in the same folder keep TWO rows, '
        'and a re-find in one account never touches the other', () async {
      final a1 = await testHelper.createTestScanResult('acct-a');
      final b1 = await testHelper.createTestScanResult('acct-b');
      final b2 = await testHelper.createTestScanResult('acct-b');

      await store.upsertUnmatchedEmails([email(a1)]);
      await store.upsertUnmatchedEmails([email(b1)]);
      expect(await allRows(), hasLength(2));

      await store.upsertUnmatchedEmails([email(b2)]);
      final rows = await allRows();
      expect(rows, hasLength(2));
      expect(rows.where((r) => r['scan_result_id'] == a1), hasLength(1),
          reason: 'account A row must not move to account B scan');
      expect(rows.where((r) => r['scan_result_id'] == b2), hasLength(1));
    });

    test('the same UID in a different folder is a different email', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      await store.upsertUnmatchedEmails(
          [email(scan1), email(scan1, folder: 'Junk')]);
      expect(await allRows(), hasLength(2));
    });
  });

  group('T-3 -- Q20: a dismissed email comes back on the next scan', () {
    test('processed is reset to 0 when a later scan re-finds it', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final scan2 = await testHelper.createTestScanResult('acct-a');
      final id = (await store.upsertUnmatchedEmails([email(scan1)])).single.id;
      await store.markAsProcessed(id, true, reason: NoRuleMarkReason.dismissed);

      final r = await store.upsertUnmatchedEmails([email(scan2)]);
      expect(r.single.outcome, UnmatchedUpsertOutcome.reappeared);
      expect(r.single.listInBackgroundExport, isTrue);
      expect((await allRows()).single['processed'], 0,
          reason: 'deferred until the next scan (Harold, Q20)');
    });
  });

  group('T-4 -- Q21: Review reads every unprocessed row across scans', () {
    test('lists older-scan rows, skips processed ones, stays inside the '
        'account', () async {
      final a1 = await testHelper.createTestScanResult('acct-a');
      final a2 = await testHelper.createTestScanResult('acct-a');
      final b1 = await testHelper.createTestScanResult('acct-b');
      await store.upsertUnmatchedEmails([email(a1, uid: '1')]);
      final done = (await store.upsertUnmatchedEmails([email(a1, uid: '2')])).single.id;
      await store.markAsProcessed(done, true, reason: NoRuleMarkReason.dismissed);
      await store.upsertUnmatchedEmails([email(a2, uid: '3')]);
      await store.upsertUnmatchedEmails([email(b1, uid: '4')]);

      final listed = await store.getUnprocessedForAccount('acct-a');
      expect(listed.map((e) => e.providerIdentifierValue).toSet(), {'1', '3'});
    });
  });

  group('T-5 -- Q22: retention cuts on last-seen', () {
    test('a row first seen long ago but seen recently is KEPT; a row last '
        'seen long ago is deleted', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final old = DateTime.now().subtract(const Duration(days: 120));
      final recent = DateTime.now().subtract(const Duration(days: 1));
      await store.upsertUnmatchedEmails([
        email(scan1, uid: 'still-seen', createdAt: old, lastSeenAt: recent),
        email(scan1, uid: 'gone', createdAt: old, lastSeenAt: old),
      ]);

      final deleted = await store.deleteOlderThan(90);
      expect(deleted, 1);
      final rows = await allRows();
      expect(rows.single['provider_identifier_value'], 'still-seen');
    });
  });

  group('T-6 -- DB v12: the REAL upgrade dedups a v11 database', () {
    Future<void> buildV11Fixture() async {
      await testHelper.dbHelper.close();
      final dbFile = File(testHelper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v11 = await databaseFactoryFfi.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE scan_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL, scan_type TEXT NOT NULL,
                scan_mode TEXT NOT NULL, started_at INTEGER NOT NULL,
                completed_at INTEGER, total_emails INTEGER NOT NULL,
                processed_count INTEGER NOT NULL, deleted_count INTEGER NOT NULL,
                moved_count INTEGER NOT NULL, safe_sender_count INTEGER NOT NULL,
                no_rule_count INTEGER NOT NULL, error_count INTEGER NOT NULL,
                status TEXT NOT NULL, error_message TEXT,
                folders_scanned TEXT NOT NULL,
                last_heartbeat_at INTEGER, cancel_requested_at INTEGER
              );''');
            await db.execute('''
              CREATE TABLE unmatched_emails (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_result_id INTEGER NOT NULL,
                provider_identifier_type TEXT NOT NULL,
                provider_identifier_value TEXT NOT NULL,
                from_email TEXT NOT NULL, from_name TEXT, subject TEXT,
                body_preview TEXT, folder_name TEXT NOT NULL,
                email_date INTEGER, availability_status TEXT DEFAULT 'unknown',
                availability_checked_at INTEGER, processed INTEGER DEFAULT 0,
                created_at INTEGER NOT NULL, auth_classification TEXT,
                FOREIGN KEY (scan_result_id) REFERENCES scan_results(id)
                  ON DELETE CASCADE
              );''');
            // Scans 1-3 belong to account A, scan 4 to account B.
            for (final (id, acct) in [
              (1, 'acct-a'), (2, 'acct-a'), (3, 'acct-a'), (4, 'acct-b'),
            ]) {
              await db.insert('scan_results', {
                'id': id, 'account_id': acct, 'scan_type': 'background',
                'scan_mode': 'readOnly', 'started_at': id, 'total_emails': 1,
                'processed_count': 1, 'deleted_count': 0, 'moved_count': 0,
                'safe_sender_count': 0, 'no_rule_count': 1, 'error_count': 0,
                'status': 'completed', 'folders_scanned': '["INBOX"]',
              });
            }
            Future<void> row(int scan, String uid, int created, int processed,
                {String folder = 'INBOX'}) async {
              await db.insert('unmatched_emails', {
                'scan_result_id': scan,
                'provider_identifier_type': 'email_id',
                'provider_identifier_value': uid,
                'from_email': 'x@spam.example', 'subject': 's',
                'folder_name': folder, 'processed': processed,
                'created_at': created,
              });
            }
            // X: account A uid 7, three copies; the OLDEST was dismissed, the
            // newest is unprocessed -> survivor unprocessed.
            await row(1, '7', 100, 1);
            await row(2, '7', 200, 0);
            await row(3, '7', 300, 0);
            // Y: account A uid 8; the NEWEST was dismissed -> survivor
            // processed (the state of the latest sighting is kept).
            await row(1, '8', 110, 0);
            await row(3, '8', 310, 1);
            // Z: account B shares uid 7 and folder with X -> a different email.
            await row(4, '7', 400, 0);
          },
        ),
      );
      await v11.close();
    }

    test('three copies become one (oldest created_at, newest last_seen_at, '
        'newest scan), the newest row keeps its processed state, and another '
        'account sharing the UID is untouched', () async {
      await buildV11Fixture();

      final db = await testHelper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, 13);

      final rows = await db.query('unmatched_emails', orderBy: 'id');
      expect(rows, hasLength(3), reason: '6 fixture rows -> 3 identities');

      Map<String, Object?> pick(int scan, String uid) => rows.singleWhere(
          (r) =>
              r['scan_result_id'] == scan &&
              r['provider_identifier_value'] == uid);
      final x = pick(3, '7');
      expect(x['created_at'], 100, reason: 'first seen = oldest copy');
      expect(x['last_seen_at'], 300);
      expect(x['processed'], 0);
      final y = pick(3, '8');
      expect(y['created_at'], 110);
      expect(y['processed'], 1,
          reason: 'the newest row keeps its own (dismissed) state');
      final z = pick(4, '7');
      expect(z['created_at'], 400, reason: 'account B is a different email');

      final cols = (await db.rawQuery('PRAGMA table_info(unmatched_emails)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, contains('last_seen_at'));
      final idx = (await db.rawQuery('PRAGMA index_list(unmatched_emails)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(idx, contains('idx_unmatched_identity'));
      expect(
          (await db.rawQuery('PRAGMA index_list(unmatched_emails)'))
              .where((r) => r['name'] == 'idx_unmatched_identity')
              .single['unique'],
          0,
          reason: 'no cross-account UNIQUE index (Q18)');
    });

    test('after the upgrade No Rule Review lists exactly the unprocessed '
        'emails per account, and the next scan refreshes instead of adding',
        () async {
      await buildV11Fixture();
      final upgradedStore = UnmatchedEmailStore(testHelper.dbHelper);

      final listA = await upgradedStore.getUnprocessedForAccount('acct-a');
      expect(listA.map((e) => e.providerIdentifierValue), ['7']);
      final listB = await upgradedStore.getUnprocessedForAccount('acct-b');
      expect(listB.map((e) => e.providerIdentifierValue), ['7']);

      // A new scan of account A re-finds uid 7: still one row.
      final scan = await testHelper.createTestScanResult('acct-a');
      final r = await upgradedStore.upsertUnmatchedEmails([
        email(scan, uid: '7'),
      ]);
      expect(r.single.outcome, isNot(UnmatchedUpsertOutcome.inserted),
          reason: 'a migrated row must be matched by the upsert');
      final db = await testHelper.dbHelper.database;
      expect(await db.query('unmatched_emails'), hasLength(3));
    });
  });

  // Sprint 77 MV step 5 (Harold): a row left the No Rule list and nothing
  // recorded why. Every mark now names its reason in the diagnostic log, and
  // a dismissed row that comes back is logged too. What this does NOT catch:
  // a caller passing the WRONG reason (the enum makes it explicit and
  // reviewable, not verified), or the log being off in Settings.
  group('MV step 5 -- the diagnostic log records why a row left the list', () {
    late Directory logDir;

    setUp(() async {
      logDir = await Directory.systemTemp.createTemp('norule_diag');
      DiagnosticLogger.debugSetDir(logDir.path);
      DiagnosticLogger.debugSetEnabled(true);
    });

    tearDown(() async {
      DiagnosticLogger.debugSetDir(null);
      DiagnosticLogger.debugSetEnabled(null);
      await logDir.delete(recursive: true);
    });

    Future<String> logText() async {
      final buffer = StringBuffer();
      await for (final f in logDir.list(recursive: true)) {
        if (f is File) buffer.write(await f.readAsString());
      }
      return buffer.toString();
    }

    test('each reason is logged with its detail', () async {
      final scan = await testHelper.createTestScanResult('acct-a');
      final ids = [
        for (final uid in ['1', '2', '3', '4'])
          (await store.upsertUnmatchedEmails([email(scan, uid: uid)]))
              .single
              .id,
      ];
      await store.markAsProcessed(ids[0], true,
          reason: NoRuleMarkReason.bulkAction, detail: 'Safe Sender');
      await store.markAsProcessed(ids[1], true,
          reason: NoRuleMarkReason.dismissed);
      await store.markAsProcessed(ids[2], true,
          reason: NoRuleMarkReason.coveredByRule, detail: 'rule "SpamX"');
      await store.markAsProcessed(ids[3], false,
          reason: NoRuleMarkReason.detailView);

      final text = await logText();
      expect(text, contains('row ${ids[0]} marked addressed: bulkAction (Safe Sender)'));
      expect(text, contains('row ${ids[1]} marked addressed: dismissed'));
      expect(text, contains('row ${ids[2]} marked addressed: coveredByRule (rule "SpamX")'));
      expect(text, contains('row ${ids[3]} marked unaddressed: detailView'));
    });

    // Sprint 77 final review (finding 4): the log must hold no address and
    // no subject text. What this does NOT catch: a caller that puts SUBJECT
    // text in detail (scrub redacts addresses only) -- the coveredByRule
    // caller is pinned to a rule TYPE below, and a new caller is a review item.
    test('an address in detail never reaches the log file', () async {
      final scan = await testHelper.createTestScanResult('acct-a');
      final id = (await store.upsertUnmatchedEmails([email(scan)])).single.id;
      await store.markAsProcessed(id, true,
          reason: NoRuleMarkReason.bulkAction,
          detail: 'rule "Block_john.doe@example.com" for jane+x@mail.example.org');

      final text = await logText();
      expect(text, contains('row $id marked addressed: bulkAction'));
      expect(text, isNot(contains('john.doe@example.com')));
      expect(text, isNot(contains('jane+x@mail.example.org')));
    });

    test('coveredByRule detail is the rule type, never the rule name', () {
      EvaluationResult eval(String name, String? type, {bool safe = false}) =>
          EvaluationResult(
            shouldDelete: !safe,
            shouldMove: false,
            matchedRule: name,
            matchedPattern: 'x',
            isSafeSender: safe,
            matchedPatternType: type,
          );
      final sender = coveredByRuleDetail(
          eval('Block_john.doe@example.com', 'exact_email'));
      final subject = coveredByRuleDetail(
          eval('Block_Subject_Win a free prize now', 'subject'));
      final safe = coveredByRuleDetail(
          eval('SafeSender', 'exact_email', safe: true));
      expect(sender, 'rule type exact_email');
      expect(subject, 'rule type subject');
      expect(safe, 'safe sender');
      expect(coveredByRuleDetail(eval('Block_x', null)), 'rule type unknown');
      for (final d in [sender, subject, safe]) {
        expect(d, isNot(contains('Block_')));
        expect(d, isNot(contains('john')));
        expect(d, isNot(contains('prize')));
      }
    });

    test('source gate: the sweep logs coveredByRuleDetail, not the rule name',
        () {
      final src =
          File('lib/ui/screens/no_rule_review_screen.dart').readAsStringSync();
      final at = src.indexOf('NoRuleMarkReason.coveredByRule');
      expect(at, greaterThan(0));
      final call = src.substring(at, at + 200);
      expect(call, contains('detail: coveredByRuleDetail(eval)'));
      expect(call, isNot(contains('matchedRule')));
    });

    test('a dismissed row found again is logged as reappeared', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final scan2 = await testHelper.createTestScanResult('acct-a');
      final id = (await store.upsertUnmatchedEmails([email(scan1)])).single.id;
      await store.markAsProcessed(id, true, reason: NoRuleMarkReason.dismissed);
      await store.upsertUnmatchedEmails([email(scan2)]);

      expect(await logText(), contains('row $id reappeared'));
    });

    test('an unchanged re-sighting is not logged as reappeared', () async {
      final scan1 = await testHelper.createTestScanResult('acct-a');
      final scan2 = await testHelper.createTestScanResult('acct-a');
      final id = (await store.upsertUnmatchedEmails([email(scan1)])).single.id;
      await store.upsertUnmatchedEmails([email(scan2)]);

      expect(await logText(), isNot(contains('row $id reappeared')));
    });
  });
}
