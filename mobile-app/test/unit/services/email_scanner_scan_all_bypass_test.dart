// F147 (Sprint 55): "Scan all emails" (daysBack<=0) must bypass the no-rule
// backlog cursor / historyId cursor instead of silently narrowing the fetch
// to the post-cursor subset -- for BOTH the IMAP path (used by Manual and
// Background scan alike, since both funnel through EmailScanner.scanInbox
// with their own resolved daysBack) and the Gmail OAuth historyId path.
//
// Root cause (confirmed 2026-08-10 against a live AOL account): an IMAP
// folder with a stored `oldest_no_rule_uid` cursor and "Scan all emails"
// enabled returned only 8 of 301 actual messages in the folder, because
// `_fetchFolderMessagesImap` unconditionally preferred the cursor whenever
// one existed, with no check for the user's "scan all" setting at all.
//
// These tests exercise the private fetch-path DECISION directly via the
// @visibleForTesting seams (fetchFolderMessagesImapForTesting /
// fetchFolderMessagesGmailForTesting) with fake adapters that record which
// underlying fetch method was actually called -- full `scanInbox()`
// orchestration (rule evaluation, action execution) is out of scope here;
// this is purely "did the fetch-path selection honor daysBack correctly."
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

EmailMessage _fakeMessage(String id, String folder) => EmailMessage(
      id: id,
      from: 'sender@example.com',
      subject: 'test',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 1, 1),
      folderName: folder,
    );

/// Records which IMAP fetch method was actually invoked, returning a fixed
/// message list per method so the caller (EmailScanner) can be asserted
/// against without a real IMAP connection.
class _RecordingImapAdapter extends GenericIMAPAdapter {
  _RecordingImapAdapter()
      : super(imapHost: 'imap.example.com', platformId: 'aol');

  int fullFetchCallCount = 0;
  int incrementalFetchCallCount = 0;
  int? lastIncrementalStartUid;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    fullFetchCallCount++;
    // Simulate the full mailbox: many more messages than the incremental
    // path would return, matching the real AOL Bulk-Mail-301-vs-8 defect
    // shape (full fetch sees everything, incremental sees only the tail).
    return List.generate(
        20, (i) => _fakeMessage('${100 + i}', folderNames.first));
  }

  @override
  Future<ImapIncrementalFetchResult> fetchMessagesIncremental({
    required int startUid,
    required String folderName,
  }) async {
    incrementalFetchCallCount++;
    lastIncrementalStartUid = startUid;
    return ImapIncrementalFetchResult(
      emails: [_fakeMessage('${startUid + 1}', folderName)],
      newCursor: startUid + 1,
    );
  }

  @override
  Future<int?> firstUidSince(String folderName, DateTime since) async => null;
}

/// Gmail-side equivalent of [_RecordingImapAdapter]: records which fetch
/// method was invoked without touching the real Gmail API.
class _RecordingGmailAdapter extends GmailApiAdapter {
  int fullFetchCallCount = 0;
  int incrementalFetchCallCount = 0;
  String? lastIncrementalStartHistoryId;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    fullFetchCallCount++;
    return List.generate(
        20, (i) => _fakeMessage('${100 + i}', folderNames.first));
  }

  @override
  Future<IncrementalFetchResult> fetchMessagesIncremental({
    required String startHistoryId,
    String folderForLabel = 'INBOX',
  }) async {
    incrementalFetchCallCount++;
    lastIncrementalStartHistoryId = startHistoryId;
    return IncrementalFetchResult(
      emails: [_fakeMessage('1', folderForLabel)],
      newHistoryId: '${int.parse(startHistoryId) + 1}',
      isExpired: false,
    );
  }

  @override
  Future<String?> getCurrentHistoryId() async => '999';
}

void main() {
  group('F147 IMAP scan-all bypass (Manual + Background share this path)',
      () {
    late DatabaseHelper db;
    late EmailScanner scanner;
    late Directory tempDir;
    const accountId = 'aol-test@aol.com';
    const folder = 'Bulk Mail';

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f147_imap_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();

      scanner = EmailScanner(
        platformId: 'aol',
        accountId: accountId,
        ruleSetProvider: RuleSetProvider(),
        scanProvider: EmailScanProvider(),
      );
      scanner.resetDaysBackUidFloorCacheForTesting();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
        'AC-1/AC-6: daysBack<=0 ("scan all") bypasses an existing no-rule cursor '
        '-- full fetch is called, not incremental, reproducing the AOL '
        'Bulk-Mail-301-vs-8 defect as an automated regression', () async {
      // Arrange: seed a no-rule cursor for the folder, matching the real
      // AOL account state at the time the bug was found (cursor=148758).
      await db.setFolderCursor(accountId, folder, '148758');
      final imap = _RecordingImapAdapter();

      // Act: daysBack=0 is the app's "Scan all emails" sentinel.
      final result =
          await scanner.fetchFolderMessagesImapForTesting(imap, folder, 0);

      // Assert: full fetch was used, not the incremental cursor path.
      expect(imap.fullFetchCallCount, 1,
          reason: '"Scan all emails" must call the full fetchMessages path, '
              'not fetchMessagesIncremental, regardless of a stored cursor.');
      expect(imap.incrementalFetchCallCount, 0,
          reason: 'The no-rule cursor must be bypassed entirely when "scan '
              'all" is set -- this is the exact AOL Bulk Mail defect (301 '
              'actual messages, only 8 returned because the cursor silently '
              'won over the scan-all setting).');
      expect(result.length, 20,
          reason: 'The full-fetch fake returns 20 messages; a correct bypass '
              'must surface all of them, not the incremental fake\'s 1.');
    });

    test(
        'AC-2: a specific N-day window with an existing cursor still uses the '
        'incremental cursor path (non-regression -- the fix must not break '
        'the legitimate windowed-scan + cursor interaction)', () async {
      await db.setFolderCursor(accountId, folder, '148758');
      final imap = _RecordingImapAdapter();

      final result =
          await scanner.fetchFolderMessagesImapForTesting(imap, folder, 7);

      expect(imap.incrementalFetchCallCount, 1,
          reason: 'A specific daysBack window (not "scan all") must still '
              'prefer the no-rule cursor when one exists -- this is existing, '
              'correct behavior that must not regress.');
      expect(imap.fullFetchCallCount, 0);
      expect(imap.lastIncrementalStartUid, 148757,
          reason: 'startUid = cursor - 1 so the cursor UID itself is '
              'included in the incremental UID SEARCH result.');
      expect(result.length, 1,
          reason: 'The incremental fake returns 1 message; this proves the '
              'incremental (not full) path drove the result.');
    });

    test(
        'AC-3: no cursor at all (first-ever scan) -- unaffected either way, '
        'full fetch either way', () async {
      // No setFolderCursor call: cursor is genuinely absent for this folder.
      final imap = _RecordingImapAdapter();

      final resultScanAll =
          await scanner.fetchFolderMessagesImapForTesting(imap, folder, 0);
      expect(imap.fullFetchCallCount, 1);
      expect(imap.incrementalFetchCallCount, 0);
      expect(resultScanAll.length, 20);

      final imap2 = _RecordingImapAdapter();
      final resultWindowed =
          await scanner.fetchFolderMessagesImapForTesting(imap2, folder, 7);
      expect(imap2.fullFetchCallCount, 1,
          reason: 'With no cursor at all, even a windowed scan must fall '
              'back to a full fetch -- pre-existing behavior, unaffected by '
              'the F147 fix.');
      expect(imap2.incrementalFetchCallCount, 0);
      expect(resultWindowed.length, 20);
    });

    test(
        'AC-4 (Manual vs Background independence): the fix applies uniformly '
        'regardless of which daysBack value the caller resolved -- proven by '
        'calling with Background\'s "scan all" (0) and Manual\'s windowed (7) '
        'values back-to-back against the SAME cursor state, matching how '
        'Manual (isBackground: false) and Background (isBackground: true) '
        'each resolve their OWN independent account_settings via '
        'SettingsStore.getEffectiveDaysBack before calling into this shared '
        'EmailScanner path', () async {
      await db.setFolderCursor(accountId, folder, '148758');

      // Simulates Background scan resolving background_days_back=0 ("scan
      // all" enabled for background) for this account.
      final bgImap = _RecordingImapAdapter();
      await scanner.fetchFolderMessagesImapForTesting(bgImap, folder, 0);
      expect(bgImap.fullFetchCallCount, 1,
          reason: 'Background scan with its own "scan all" setting must '
              'bypass the cursor exactly like Manual scan does -- the fix in '
              '_fetchFolderMessagesImap has no caller-specific branching, so '
              'it must behave identically for both callers given the same '
              'daysBack value.');

      // Simulates Manual scan resolving manual_days_back=7 for the SAME
      // account+folder -- independent of whatever Background's setting was.
      final manualImap = _RecordingImapAdapter();
      await scanner.fetchFolderMessagesImapForTesting(manualImap, folder, 7);
      expect(manualImap.incrementalFetchCallCount, 1,
          reason: 'Manual scan with a windowed setting must still use the '
              'cursor -- proving the two scan types\' independently-resolved '
              'daysBack values each drive this shared path correctly, with '
              'no cross-contamination between Manual\'s and Background\'s '
              'settings.');
    });
  });

  group('F147 Gmail scan-all bypass (R-5 investigation confirmed the same '
      'bug shape exists on the historyId-cursor path)', () {
    late DatabaseHelper db;
    late EmailScanner scanner;
    late Directory tempDir;
    const accountId = 'gmail-test@gmail.com';

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('f147_gmail_');
      db = DatabaseHelper();
      db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
      await db.deleteAllData();

      // Gmail's cursor (lastHistoryId) lives on the accounts row itself
      // (not account_folder_cursors, which is IMAP-only) -- seed a real
      // account row so getLastHistoryId/setLastHistoryId round-trip through
      // an actual DB write, matching the IMAP group's real-cursor approach
      // rather than asserting only the already-correct no-cursor case.
      await db.insertAccount({
        'account_id': accountId,
        'platform_id': 'gmail',
        'email': accountId,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      scanner = EmailScanner(
        platformId: 'gmail',
        accountId: accountId,
        ruleSetProvider: RuleSetProvider(),
        scanProvider: EmailScanProvider(),
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
        'AC-5/AC-6-equivalent: daysBack<=0 ("scan all") bypasses an EXISTING '
        'historyId cursor -- full fetch is called, not the incremental delta',
        () async {
      // Seed a real historyId cursor, simulating an account that has
      // already completed at least one prior scan.
      await db.setLastHistoryId(accountId, '500');
      final gmail = _RecordingGmailAdapter();

      final result = await scanner.fetchFolderMessagesGmailForTesting(
          gmail, 'INBOX', 0);

      expect(gmail.fullFetchCallCount, 1,
          reason: '"Scan all emails" must select the full-fetch branch on '
              'the Gmail path exactly as on the IMAP path, bypassing a '
              'genuinely SET historyId cursor -- not just the trivially-'
              'correct no-cursor case.');
      expect(gmail.incrementalFetchCallCount, 0,
          reason: 'The historyId incremental delta must not be used when '
              '"scan all" is set, mirroring the IMAP-side AC-1 assertion.');
      expect(result.length, 20);
    });

    test(
        'non-regression: a specific N-day window with an existing historyId '
        'cursor still uses the incremental delta path', () async {
      await db.setLastHistoryId(accountId, '500');
      final gmail = _RecordingGmailAdapter();

      final result = await scanner.fetchFolderMessagesGmailForTesting(
          gmail, 'INBOX', 7);

      expect(gmail.incrementalFetchCallCount, 1,
          reason: 'A specific daysBack window (not "scan all") must still '
              'prefer the historyId cursor when one is set -- existing, '
              'correct behavior that must not regress.');
      expect(gmail.fullFetchCallCount, 0);
      expect(gmail.lastIncrementalStartHistoryId, '500');
      expect(result.length, 1);
    });

    test('no cursor at all (first-ever Gmail scan) -- unaffected either way',
        () async {
      // No setLastHistoryId call: lastHistoryId is genuinely null.
      final gmail = _RecordingGmailAdapter();

      final result = await scanner.fetchFolderMessagesGmailForTesting(
          gmail, 'INBOX', 0);

      expect(gmail.fullFetchCallCount, 1,
          reason: 'First-ever scan (no historyId yet) must full-fetch '
              'regardless of daysBack -- pre-existing behavior, unaffected '
              'by the F147 fix.');
      expect(gmail.incrementalFetchCallCount, 0);
      expect(result.length, 20);
    });
  });
}
