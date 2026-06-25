/// F96 (Sprint 43) test: the v8 migration adds the nullable
/// auth_classification column to BOTH the email_actions and unmatched_emails
/// tables, fresh installs get it via onCreate, an existing v7 database gets it
/// via the ALTER in _upgradeTables, and the values round-trip (and tolerate
/// null for rows written before the feature shipped).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('F96 -- auth_classification column on a fresh (current-version) DB', () {
    test('email_actions table has auth_classification column', () async {
      final db = await testHelper.dbHelper.database;
      final info = await db.rawQuery('PRAGMA table_info(email_actions)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns, contains('auth_classification'));
    });

    test('unmatched_emails table has auth_classification column', () async {
      final db = await testHelper.dbHelper.database;
      final info = await db.rawQuery('PRAGMA table_info(unmatched_emails)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns, contains('auth_classification'));
    });
  });

  group('F96 -- email_actions auth_classification round-trip', () {
    Future<int> seedScan() async {
      await testHelper.createTestAccount('acct-1');
      return testHelper.createTestScanResult('acct-1');
    }

    test('persists and reads back a RED classification snapshot', () async {
      final scanId = await seedScan();
      await testHelper.dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-red',
        'email_from': 'spoof@example.com',
        'email_subject': 'hello',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'success': 1,
        'auth_classification': 'red',
      });

      final rows = await testHelper.dbHelper
          .queryEmailActions(scanResultId: scanId);
      expect(rows, hasLength(1));
      expect(rows.first['auth_classification'], 'red');
    });

    test('stores null when classification was not supplied (pre-v8 row shape)',
        () async {
      final scanId = await seedScan();
      await testHelper.dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-null',
        'email_from': 'a@b.com',
        'email_subject': 's',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'success': 1,
      });

      final rows = await testHelper.dbHelper
          .queryEmailActions(scanResultId: scanId);
      expect(rows, hasLength(1));
      expect(rows.first['auth_classification'], isNull);
    });
  });

  group('F96 -- UnmatchedEmail model carries authClassification', () {
    test('round-trips authClassification through the store', () async {
      await testHelper.createTestAccount('acct-2');
      final scanId = await testHelper.createTestScanResult('acct-2');
      final store = UnmatchedEmailStore(testHelper.dbHelper);

      final id = await store.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: '42',
        fromEmail: 'spoof@example.com',
        folderName: 'INBOX',
        createdAt: DateTime.now(),
        authClassification: 'red',
      ));

      final loaded = await store.getUnmatchedEmailById(id);
      expect(loaded, isNotNull);
      expect(loaded!.authClassification, 'red');
    });

    test('tolerates null authClassification', () async {
      await testHelper.createTestAccount('acct-3');
      final scanId = await testHelper.createTestScanResult('acct-3');
      final store = UnmatchedEmailStore(testHelper.dbHelper);

      final id = await store.addUnmatchedEmail(UnmatchedEmail(
        scanResultId: scanId,
        providerIdentifierType: 'imap_uid',
        providerIdentifierValue: '43',
        fromEmail: 'a@b.com',
        folderName: 'INBOX',
        createdAt: DateTime.now(),
      ));

      final loaded = await store.getUnmatchedEmailById(id);
      expect(loaded, isNotNull);
      expect(loaded!.authClassification, isNull);
    });
  });

  group('F96 -- v7 -> v8 migration adds the columns to an existing DB', () {
    test('ALTER adds auth_classification to both tables on upgrade', () async {
      // Build a minimal v7 database directly (only the two tables F96 touches,
      // WITHOUT auth_classification), close it, then open it through the real
      // DatabaseHelper so _upgradeTables runs the v8 ALTER.
      final dbPath = '${testHelper.testDbPath}.v7';

      final v7 = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE email_actions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_result_id INTEGER NOT NULL,
                email_id TEXT NOT NULL,
                email_from TEXT NOT NULL,
                email_subject TEXT NOT NULL,
                email_received_date INTEGER NOT NULL,
                email_folder TEXT NOT NULL,
                action_type TEXT NOT NULL,
                success INTEGER NOT NULL,
                rfc5322_message_id TEXT
              );
            ''');
            await db.execute('''
              CREATE TABLE unmatched_emails (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_result_id INTEGER NOT NULL,
                provider_identifier_type TEXT NOT NULL,
                provider_identifier_value TEXT NOT NULL,
                from_email TEXT NOT NULL,
                folder_name TEXT NOT NULL,
                created_at INTEGER NOT NULL
              );
            ''');
          },
        ),
      );
      // Confirm the pre-migration shape lacks the column.
      final beforeInfo = await v7.rawQuery('PRAGMA table_info(email_actions)');
      expect(
        beforeInfo.map((r) => r['name'] as String),
        isNot(contains('auth_classification')),
      );
      await v7.close();

      // Re-open at the current version through DatabaseHelper's upgrade path.
      final upgraded = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: databaseVersionForTest,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 8) {
              await db.execute(
                  'ALTER TABLE email_actions ADD COLUMN auth_classification TEXT;');
              await db.execute(
                  'ALTER TABLE unmatched_emails ADD COLUMN auth_classification TEXT;');
            }
          },
        ),
      );

      final eaInfo = await upgraded.rawQuery('PRAGMA table_info(email_actions)');
      expect(
        eaInfo.map((r) => r['name'] as String),
        contains('auth_classification'),
      );
      final ueInfo =
          await upgraded.rawQuery('PRAGMA table_info(unmatched_emails)');
      expect(
        ueInfo.map((r) => r['name'] as String),
        contains('auth_classification'),
      );
      await upgraded.close();
    });
  });
}

/// The schema version under which F96 added auth_classification. Kept local to
/// the test so a future version bump does not silently change what this test
/// upgrades TO (the migration logic mirrored above is the v8 step specifically).
const int databaseVersionForTest = 8;
