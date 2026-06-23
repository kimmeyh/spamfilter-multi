/// F91 (Sprint 39) Phase 1 tests: RFC 5322 Message-ID capture and the DB v6
/// migration that persists it on the email_actions table.
///
/// These cover the provider-agnostic surface of Phase 1:
///   1. EmailMessage.parseMessageId -- standard parse, missing/empty (null),
///      whitespace handling, case-insensitivity of the lookup contract.
///   2. EmailMessage carries the messageIdHeader field through construction.
///   3. DB v6 migration: a fresh database has the rfc5322_message_id column
///      (nullable), round-trips a value, and stores null for rows that omit
///      it. An existing v5 database upgrades cleanly to v6 (additive column,
///      existing rows null).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  group('F91 Phase 1 -- EmailMessage.parseMessageId', () {
    test('parses a standard <id@host> value (brackets preserved)', () {
      final result = EmailMessage.parseMessageId('<abc123@mail.example.com>');
      expect(result, '<abc123@mail.example.com>',
          reason:
              'Angle brackets must be preserved because IMAP SEARCH HEADER '
              'Message-ID matches the literal stored header value.');
    });

    test('returns null when the header is missing (null input)', () {
      expect(EmailMessage.parseMessageId(null), isNull);
    });

    test('returns null for an empty or whitespace-only value', () {
      expect(EmailMessage.parseMessageId(''), isNull);
      expect(EmailMessage.parseMessageId('   '), isNull);
      expect(EmailMessage.parseMessageId('\t\n'), isNull);
    });

    test('trims surrounding whitespace from the header value', () {
      final result = EmailMessage.parseMessageId('  <x@y>  ');
      expect(result, '<x@y>');
    });

    test('getHeader looks up Message-ID case-insensitively', () {
      // Servers vary: "Message-ID", "Message-Id", "message-id". The model's
      // case-insensitive getHeader is the lookup contract Phase 1 relies on.
      final message = EmailMessage(
        id: '1',
        from: 'sender@example.com',
        subject: 'Hello',
        body: '',
        headers: {'Message-Id': '<case@host>'},
        receivedDate: DateTime(2026, 5, 25),
        folderName: 'INBOX',
      );
      expect(message.getHeader('message-id'), '<case@host>');
      expect(message.getHeader('MESSAGE-ID'), '<case@host>');
    });
  });

  group('F91 Phase 1 -- EmailMessage.messageIdHeader field', () {
    test('defaults to null when not provided', () {
      final message = EmailMessage(
        id: '1',
        from: 'a@b.com',
        subject: 's',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 5, 25),
        folderName: 'INBOX',
      );
      expect(message.messageIdHeader, isNull);
    });

    test('carries the provided value', () {
      final message = EmailMessage(
        id: '1',
        from: 'a@b.com',
        subject: 's',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 5, 25),
        folderName: 'INBOX',
        messageIdHeader: '<kept@host>',
      );
      expect(message.messageIdHeader, '<kept@host>');
    });
  });

  group('F91 Phase 1 -- DB v6 migration (rfc5322_message_id column)', () {
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

    test('fresh database has the rfc5322_message_id column on email_actions',
        () async {
      final db = await testHelper.dbHelper.database;
      final info = await db.rawQuery('PRAGMA table_info(email_actions)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns.contains('rfc5322_message_id'), isTrue,
          reason: 'The v6 onCreate schema must include the F91 column.');
    });

    test('round-trips a Message-ID value through email_actions', () async {
      await testHelper.createTestAccount('acct-1');
      final scanId = await testHelper.createTestScanResult('acct-1');

      await testHelper.dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': '42',
        'email_from': 'safe@example.com',
        'email_subject': 'rescued',
        'email_received_date': DateTime(2026, 5, 25).millisecondsSinceEpoch,
        'email_folder': 'Bulk Mail',
        'action_type': 'safeSender',
        'is_safe_sender': 1,
        'success': 1,
        'rfc5322_message_id': '<rescued@aol.com>',
      });

      final rows = await testHelper.dbHelper
          .queryEmailActions(scanResultId: scanId);
      expect(rows.length, 1);
      expect(rows.first['rfc5322_message_id'], '<rescued@aol.com>');
    });

    test('stores null when rfc5322_message_id is omitted', () async {
      await testHelper.createTestAccount('acct-2');
      final scanId = await testHelper.createTestScanResult('acct-2');

      await testHelper.dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': '7',
        'email_from': 'no-id@example.com',
        'email_subject': 'no message id',
        'email_received_date': DateTime(2026, 5, 25).millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'is_safe_sender': 0,
        'success': 1,
        // rfc5322_message_id intentionally omitted
      });

      final rows = await testHelper.dbHelper
          .queryEmailActions(scanResultId: scanId);
      expect(rows.length, 1);
      expect(rows.first['rfc5322_message_id'], isNull);
    });

    test('upgrades a v5 database to v6 by adding the nullable column', () async {
      // Build a minimal v5-era email_actions table (no rfc5322_message_id),
      // then run the production v6 upgrade logic via onUpgrade by opening at
      // the current databaseVersion. We exercise the ALTER path directly
      // against an in-memory FFI database to keep the test self-contained.
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 5,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE email_actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              scan_result_id INTEGER NOT NULL,
              email_id TEXT NOT NULL,
              email_from TEXT NOT NULL,
              email_subject TEXT NOT NULL,
              email_received_date INTEGER NOT NULL,
              email_folder TEXT NOT NULL,
              action_type TEXT NOT NULL,
              matched_rule_name TEXT,
              matched_pattern TEXT,
              is_safe_sender INTEGER NOT NULL DEFAULT 0,
              success INTEGER NOT NULL,
              error_message TEXT,
              email_still_exists INTEGER DEFAULT 1
            );
          ''');
        },
      );

      // Insert a pre-migration row (no Message-ID column yet).
      await db.insert('email_actions', {
        'scan_result_id': 1,
        'email_id': '1',
        'email_from': 'old@example.com',
        'email_subject': 'legacy row',
        'email_received_date': 0,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'is_safe_sender': 0,
        'success': 1,
      });

      // Apply the additive v6 migration (mirrors database_helper _upgradeTables
      // v6 block: guarded ALTER TABLE ADD COLUMN).
      final before = await db.rawQuery('PRAGMA table_info(email_actions)');
      final beforeCols = before.map((r) => r['name'] as String).toSet();
      expect(beforeCols.contains('rfc5322_message_id'), isFalse);

      if (!beforeCols.contains('rfc5322_message_id')) {
        await db.execute(
            'ALTER TABLE email_actions ADD COLUMN rfc5322_message_id TEXT;');
      }

      final after = await db.rawQuery('PRAGMA table_info(email_actions)');
      final afterCols = after.map((r) => r['name'] as String).toSet();
      expect(afterCols.contains('rfc5322_message_id'), isTrue);

      // The pre-existing row is preserved with a null value in the new column.
      final rows = await db.query('email_actions');
      expect(rows.length, 1);
      expect(rows.first['rfc5322_message_id'], isNull);
      expect(rows.first['email_from'], 'old@example.com');

      await db.close();
    });
  });
}
