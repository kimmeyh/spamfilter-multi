/// F306 (Sprint 82): the five suggestion columns on the No Rule row.
///
/// Covers: the store round trip (write, read, refresh clears), the scan-time
/// WIRING (a real [EmailScanProvider] scan computes and stores the suggestion
/// from the Authentication-Results headers), and the REAL DatabaseHelper
/// upgrade from a v16 database that already holds rows (AC-5).
///
/// What these tests do NOT catch (one line each):
///   - wiring: a real server's header shape (folded or duplicate
///     Authentication-Results lines); the fake headers here are single-line;
///   - migration: a v16 database whose rows carry data the fixture lacks
///     (the fixture has the v16 columns and two rows), and the dev DB copy
///     rehearsal, which is a manual step;
///   - round trip: two isolates writing one row at once (the upsert's
///     transaction owns that, see f245_no_rule_upsert_test.dart).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';
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

  final suggestion = RuleSuggestion.suggest(
      fromEmail: 'a@mail.shop-example.com',
      authClassification: 'yellow',
      authResult:
          AuthResultsParser.syntheticResultFor(AuthClassification.yellow))!;

  group('store round trip', () {
    late int scan;
    UnmatchedEmail make(RuleSuggestion? s) => UnmatchedEmail(
          scanResultId: scan,
          providerIdentifierType: 'email_id',
          providerIdentifierValue: '9',
          fromEmail: 'a@mail.shop-example.com',
          folderName: 'INBOX',
          createdAt: DateTime.now(),
          suggestion: s,
        );

    setUp(() async => scan = await testHelper.createTestScanResult('acct-a'));

    test('all five columns persist through upsert and read', () async {
      final id = (await store.upsertUnmatchedEmails([make(suggestion)]))
          .single
          .id;
      final db = await testHelper.dbHelper.database;
      final raw = (await db.query('unmatched_emails',
              where: 'id = ?', whereArgs: [id]))
          .single;
      expect(raw['suggestion_kind'], 'block');
      expect(raw['suggestion_type'], 'entireDomain');
      expect(raw['suggestion_value'], 'shop-example.com');
      expect(raw['suggestion_pattern'],
          RuleQuickActionService.blockPatternFor(
              'entireDomain', 'shop-example.com'));
      expect(raw['suggestion_reason'], 'auth_yellow');
      expect((await store.getUnmatchedEmailById(id))!.suggestion, suggestion);
    });

    test('a re-seen row refreshes the suggestion, and null clears it',
        () async {
      final id = (await store.upsertUnmatchedEmails([make(null)])).single.id;
      expect((await store.getUnmatchedEmailById(id))!.suggestion, isNull);
      await store.upsertUnmatchedEmails([make(suggestion)]);
      expect((await store.getUnmatchedEmailById(id))!.suggestion, suggestion);
      await store.upsertUnmatchedEmails([make(null)]);
      expect((await store.getUnmatchedEmailById(id))!.suggestion, isNull);
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
            receivedDate: DateTime(2026, 10, 30),
            folderName: 'INBOX',
          ),
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.none,
          success: true,
        );

    Future<EmailScanProvider> runScan(List<EmailActionResult> results,
        {String scanType = 'background',
        UnmatchedEmailStore? unmatchedStore,
        void Function(bool stored)? onCompleted}) async {
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      provider.initializePersistence(
        scanResultStore: ScanResultStore(testHelper.dbHelper),
        unmatchedEmailStore: unmatchedStore ?? store,
        databaseHelper: testHelper.dbHelper,
      );
      provider.setCurrentAccountId('acct-a');
      await provider.startScan(
          totalEmails: results.length,
          scanType: scanType,
          foldersScanned: ['INBOX'],
          platformId: 'test-platform');
      results.forEach(provider.recordResult);
      final stored = await provider.completeScan();
      onCompleted?.call(stored);
      return provider;
    }

    // 7.7.1 H-1 (F314): a failed store is REPORTED, so the scanner keeps the
    // Gmail cursors, and the user sees it on the scan screen.
    // What this does NOT catch: a failure inside markScanCompleted alone (same
    // catch, not exercised separately) and the background worker's notice,
    // which reads only the diagnostic log line.
    test('7.7.1 H-1: completeScan returns false and says so when the No Rule '
        'rows cannot be stored; true when they are', () async {
      bool? ok;
      await runScan([result('1', 'a@calm-example.com', const {})],
          onCompleted: (s) => ok = s);
      expect(ok, isTrue);

      final failing = await runScan(
          [result('2', 'b@calm-example.com', const {})],
          unmatchedStore: _ThrowingUnmatchedStore(testHelper.dbHelper),
          onCompleted: (s) => ok = s);
      expect(ok, isFalse,
          reason: 'the upsert threw, so the results are not stored');
      expect(failing.statusMessage, contains('could not be saved'));
    });

    // A mixed result: SPF pass, DKIM none. Classified YELLOW by
    // AuthResultsParser (same rule f96 tests rely on); asserted below so a
    // classifier change fails here with a clear message.
    const yellowHeaders = {
      'authentication-results':
          'mx.example; spf=softfail smtp.mailfrom=shop-example.com; '
              'dkim=none; dmarc=none',
    };
    const greenHeaders = {
      'authentication-results':
          'mx.example; spf=pass smtp.mailfrom=calm-example.com; '
              'dkim=pass header.d=calm-example.com; dmarc=pass '
              'header.from=calm-example.com',
    };

    for (final scanType in ['background', 'manual']) {
      test('$scanType scan: YELLOW row stores the suggestion, GREEN none',
          () async {
        await runScan([
          result('1', 'a@mail.shop-example.com', yellowHeaders),
          result('2', 'a@calm-example.com', greenHeaders),
        ], scanType: scanType);
        final db = await testHelper.dbHelper.database;
        final rows = {
          for (final r in await db.query('unmatched_emails'))
            r['provider_identifier_value'] as String: r
        };
        expect(rows['1']!['auth_classification'], 'yellow',
            reason: 'fixture must classify YELLOW');
        expect(rows['2']!['auth_classification'], 'green');
        expect(rows['1']!['suggestion_kind'], 'block');
        expect(rows['1']!['suggestion_type'], 'entireDomain');
        expect(rows['1']!['suggestion_value'], 'shop-example.com');
        expect(rows['1']!['suggestion_pattern'],
            RuleQuickActionService.blockPatternFor(
                'entireDomain', 'shop-example.com'));
        expect(rows['2']!['suggestion_kind'], isNull);
        expect(rows['2']!['suggestion_pattern'], isNull);
      });
    }

    // Sprint 83 MV Q6 = 2 (scan caller): a GREEN row whose Reply-To is at
    // another domain stores the Block suggestion with its own reason.
    test('a GREEN row with a mismatched Reply-To stores the Block suggestion',
        () async {
      await runScan([
        result('1', 'a@calm-example.com',
            {...greenHeaders, 'reply-to': 'claims@elsewhere-example.net'}),
      ]);
      final db = await testHelper.dbHelper.database;
      final row = (await db.query('unmatched_emails')).single;
      expect(row['auth_classification'], 'green');
      expect(row['suggestion_kind'], 'block');
      expect(row['suggestion_value'], 'calm-example.com');
      expect(row['suggestion_reason'], 'reply_to_mismatch');
    });

    // F323 R-2 / AC-1 (scan caller): a temperror stores the "could not check"
    // note in the SAME five columns, not a block rule. What this does NOT
    // catch: the Results-screen caller (f306_results_suggestion_test.dart).
    test('F323: a temperror row stores the could-not-check note, no rule',
        () async {
      await runScan([
        result('1', 'a@mail.shop-example.com', const {
          'authentication-results':
              'mx.example; spf=temperror smtp.mailfrom=shop-example.com; '
                  'dkim=none; dmarc=none',
        }),
      ]);
      final db = await testHelper.dbHelper.database;
      final row = (await db.query('unmatched_emails')).single;
      expect(row['suggestion_kind'], 'none');
      expect(row['suggestion_reason'], 'auth_could_not_check');
      final back = (await store.getUnmatchedEmailById(row['id'] as int))!;
      expect(back.suggestion!.isCouldNotCheck, isTrue);
      expect(back.suggestion!.isBlock, isFalse);
    });
  });

  group('DB v17: the REAL upgrade of a v16 database', () {
    Future<void> buildV16Fixture() async {
      await testHelper.dbHelper.close();
      final dbFile = File(testHelper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v16 = await databaseFactoryFfi.openDatabase(
        testHelper.testDbPath,
        options: OpenDatabaseOptions(
          version: 16,
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
                last_seen_at INTEGER, heuristic_signals TEXT,
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
                'last_seen_at': 100, 'auth_classification': 'yellow',
                'heuristic_signals': 'auth_failed',
              });
            }
          },
        ),
      );
      await v16.close();
    }

    test('adds the five columns, keeps every row and neighbor column, and a '
        'write after the upgrade stores a suggestion', () async {
      await buildV16Fixture();

      final db = await testHelper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, greaterThanOrEqualTo(17));

      final info = await db.rawQuery('PRAGMA table_info(unmatched_emails)');
      final names = info.map((r) => r['name']).toSet();
      expect(
          names,
          containsAll([
            'suggestion_kind',
            'suggestion_type',
            'suggestion_value',
            'suggestion_pattern',
            'suggestion_reason',
          ]));

      final rows = await db.query('unmatched_emails', orderBy: 'id');
      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r['suggestion_kind'], isNull);
        final model = UnmatchedEmail.fromMap(r);
        expect(model.suggestion, isNull);
        expect(model.authClassification, 'yellow');
        expect(model.heuristicSignals, 'auth_failed');
      }

      final results = await store.upsertUnmatchedEmails([
        UnmatchedEmail(
          scanResultId: 1,
          providerIdentifierType: 'email_id',
          providerIdentifierValue: '7',
          fromEmail: 'x@spam.example',
          subject: 's7',
          folderName: 'INBOX',
          createdAt: DateTime.now(),
          suggestion: suggestion,
        ),
      ]);
      expect(results.single.id, rows.first['id']);
      expect(
          (await store.getUnmatchedEmailById(results.single.id))!.suggestion,
          suggestion);
      expect(await db.query('unmatched_emails'), hasLength(2));
    });
  });
}

/// 7.7.1 H-1: a No Rule store whose write fails (a locked or full database).
class _ThrowingUnmatchedStore extends UnmatchedEmailStore {
  _ThrowingUnmatchedStore(super.db);

  @override
  Future<List<UnmatchedUpsertResult>> upsertUnmatchedEmails(
      List<UnmatchedEmail> emails,
      {bool keepStoredHeuristicSignals = false}) async {
    throw StateError('database is locked');
  }
}
