/// F271 (Sprint 81): the heuristic reason codes are stored on the No Rule row.
///
/// Covers the scan-time WIRING (a real [EmailScanProvider] scan writes the
/// codes through the store), the model round trip, and the REAL DatabaseHelper
/// upgrade from a v13 database that already holds rows (AC-3: old rows have no
/// codes and nothing throws).
///
/// What these tests do NOT catch (one line each):
///   - wiring: a header block a real server returns in a shape the fake
///     headers do not have (folded lines, duplicate headers);
///   - migration: a v14 or v15 database (those versions are built by another
///     task; this fixture starts at v13 and the block only checks the column);
///   - round trip: two isolates writing the same row at once (the upsert's
///     transaction owns that, see f245_no_rule_upsert_test.dart).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  late DatabaseTestHelper testHelper;
  late UnmatchedEmailStore store;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = UnmatchedEmailStore(testHelper.dbHelper);
    await testHelper.createTestAccount('acct-a');
  });

  tearDown(() async => testHelper.tearDown());

  group('model', () {
    test('heuristicSignals round-trips through the store, null stays null',
        () async {
      final scan = await testHelper.createTestScanResult('acct-a');
      UnmatchedEmail make(String id, String? codes) => UnmatchedEmail(
            scanResultId: scan,
            providerIdentifierType: 'email_id',
            providerIdentifierValue: id,
            fromEmail: 'x@spam.example',
            folderName: 'INBOX',
            createdAt: DateTime.now(),
            heuristicSignals: codes,
          );
      final withCodes =
          await store.addUnmatchedEmail(make('1', 'reply_to_differs,auth_failed'));
      final without = await store.addUnmatchedEmail(make('2', null));
      expect((await store.getUnmatchedEmailById(withCodes))!.heuristicSignals,
          'reply_to_differs,auth_failed');
      expect((await store.getUnmatchedEmailById(without))!.heuristicSignals,
          isNull);
    });
  });

  group('7.7.1 M-3: a scan that could not read the rules keeps stored codes',
      () {
    // What this does NOT catch: the provider deciding the context read
    // failed (its catch sets the flag); that path needs a failing database.
    late int scan;
    UnmatchedEmail make(String? codes) => UnmatchedEmail(
          scanResultId: scan,
          providerIdentifierType: 'email_id',
          providerIdentifierValue: '7',
          fromEmail: 'x@paypa1.com',
          folderName: 'INBOX',
          createdAt: DateTime.now(),
          heuristicSignals: codes,
        );

    late int rowId;

    setUp(() async {
      scan = await testHelper.createTestScanResult('acct-a');
      rowId = (await store.upsertUnmatchedEmails([make('lookalike_domain')]))
          .single
          .id;
    });

    Future<String?> stored() async =>
        (await store.getUnmatchedEmailById(rowId))!.heuristicSignals;

    test('refresh with keepStoredHeuristicSignals keeps the codes', () async {
      await store.upsertUnmatchedEmails([make(null)],
          keepStoredHeuristicSignals: true);
      expect(await stored(), 'lookalike_domain');
    });

    test('a normal refresh writes what this scan computed', () async {
      await store.upsertUnmatchedEmails([make(null)]);
      expect(await stored(), isNull);
    });
  });

  group('scan wiring', () {
    EmailActionResult result(String id, String from, Map<String, String> h) =>
        EmailActionResult(
          email: EmailMessage(
            id: id,
            from: from,
            subject: 'Subject $id',
            body: '',
            headers: h,
            receivedDate: DateTime(2026, 10, 23),
            folderName: 'INBOX',
          ),
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.none,
          success: true,
        );

    Future<void> runScan(List<EmailActionResult> results) async {
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      provider.initializePersistence(
        scanResultStore: ScanResultStore(testHelper.dbHelper),
        unmatchedEmailStore: store,
        databaseHelper: testHelper.dbHelper,
      );
      provider.setCurrentAccountId('acct-a');
      await provider.startScan(
          totalEmails: results.length,
          scanType: 'background',
          foldersScanned: ['INBOX'],
          platformId: 'test-platform');
      results.forEach(provider.recordResult);
      await provider.completeScan();
    }

    test('codes are computed from the headers and the user\'s own safe '
        'senders and TLD rules, and stored on the row', () async {
      final db = await testHelper.dbHelper.database;
      await db.insert('safe_senders', {
        'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*paypal\.com$',
        'pattern_type': 'subdomain',
        'date_added': 1,
      });
      await db.insert('rules', {
        'name': '.*.xyz',
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_header': r'["@.*\\.xyz$"]',
        'date_added': 1,
        'pattern_sub_type': 'top_level_domain',
        'source_domain': '.*.xyz',
      });

      await runScan([
        result('lookalike', 'a@paypa1.com', {'Reply-To': 'z@evil.test'}),
        result('tld', 'a@deals.xyz', const {}),
        result('clean', 'a@plain.example.org', const {}),
      ]);

      final rows = {
        for (final r in await db.query('unmatched_emails'))
          r['provider_identifier_value'] as String:
              r['heuristic_signals'] as String?
      };
      expect(rows['lookalike'], contains('lookalike_domain'));
      expect(rows['lookalike'], contains('reply_to_differs'));
      // 7.7.1 CR M-1 / SF M-4, Harold Q1 = 1: the blocked_tld chip was
      // removed, so a sender under a TLD rule gets no chip.
      expect(rows['tld'], isNull);
      expect(rows['clean'], isNull);
    });
  });

  group('DB v16: the REAL upgrade of a v13 database', () {
    Future<void> buildV13Fixture() async {
      await testHelper.dbHelper.close();
      final dbFile = File(testHelper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v13 = await databaseFactoryFfi.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(
          version: 13,
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
                last_seen_at INTEGER,
                FOREIGN KEY (scan_result_id) REFERENCES scan_results(id)
                  ON DELETE CASCADE
              );''');
            await db.insert('scan_results', {
              'id': 1, 'account_id': 'acct-a', 'scan_type': 'background',
              'scan_mode': 'readOnly', 'started_at': 1, 'total_emails': 2,
              'processed_count': 2, 'deleted_count': 0, 'moved_count': 0,
              'safe_sender_count': 0, 'no_rule_count': 2, 'error_count': 0,
              'status': 'completed', 'folders_scanned': '["INBOX"]',
            });
            for (final uid in ['7', '8']) {
              await db.insert('unmatched_emails', {
                'scan_result_id': 1,
                'provider_identifier_type': 'email_id',
                'provider_identifier_value': uid,
                'from_email': 'x@spam.example', 'subject': 's$uid',
                'folder_name': 'INBOX', 'created_at': 100,
                'last_seen_at': 100, 'auth_classification': 'red',
              });
            }
          },
        ),
      );
      await v13.close();
    }

    test('adds the column, keeps every row, old rows read as no codes, and a '
        'new write after the upgrade stores codes', () async {
      await buildV13Fixture();

      final db = await testHelper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, greaterThanOrEqualTo(16));

      final info = await db.rawQuery('PRAGMA table_info(unmatched_emails)');
      expect(info.map((r) => r['name']), contains('heuristic_signals'));

      final rows = await db.query('unmatched_emails', orderBy: 'id');
      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r['heuristic_signals'], isNull);
        final model = UnmatchedEmail.fromMap(r);
        expect(model.heuristicSignals, isNull);
        expect(model.authClassification, 'red', reason: 'neighbour column kept');
      }

      // A re-sighting after the upgrade fills the codes into the SAME row.
      final results = await store.upsertUnmatchedEmails([
        UnmatchedEmail(
          scanResultId: 1,
          providerIdentifierType: 'email_id',
          providerIdentifierValue: '7',
          fromEmail: 'x@spam.example',
          subject: 's7',
          folderName: 'INBOX',
          createdAt: DateTime.now(),
          heuristicSignals: 'auth_failed',
        ),
      ]);
      expect(results.single.id, rows.first['id']);
      expect(
          (await store.getUnmatchedEmailById(results.single.id))!
              .heuristicSignals,
          'auth_failed');
      expect(await db.query('unmatched_emails'), hasLength(2));
    });
  });
}
