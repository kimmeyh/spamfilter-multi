/// F245 (Sprint 77, Harold Q19, Q23): the BACKGROUND-scan export lists an
/// unaddressed No Rule email once; the manual-scan export and every count stay
/// complete.
///
/// Drives the REAL path: a provider with persistence completes two scans, then
/// `BackgroundScanExport.exportIfEnabled` (the call both platform workers use)
/// writes the file, and the test reads the file.
///
/// What these tests do NOT catch: the two platform workers actually calling
/// `exportIfEnabled` after `scanInbox` on a device (their wiring is covered by
/// the existing f206 tests and Manual Validation), and the xlsx workbook
/// content (only the tab-separated `.data.csv` is read).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/export_directories.dart';
import 'package:my_email_spam_filter/core/services/scan_sheet_export.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late Directory tmp;
  late SettingsStore settings;
  late UnmatchedEmailStore unmatchedStore;
  final logs = <String>[];

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    tmp = await Directory.systemTemp.createTemp('f245_');
    ExportDirectories.overrideDefaultForTest(p.join(tmp.path, 'default'));
    settings = SettingsStore(testHelper.dbHelper);
    await settings.setBackgroundScanDebugCsv(true);
    unmatchedStore = UnmatchedEmailStore(testHelper.dbHelper);
    await testHelper.createTestAccount('acct-a');
    logs.clear();
  });

  tearDown(() async {
    ExportDirectories.overrideDefaultForTest(null);
    await testHelper.tearDown();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  EmailActionResult result(String id,
          {String subject = 'subj',
          EmailActionType action = EmailActionType.none}) =>
      EmailActionResult(
        email: EmailMessage(
          id: id,
          from: 'sender@spam.example',
          subject: subject,
          body: '',
          headers: const {},
          receivedDate: DateTime(2026, 10, 6),
          folderName: 'INBOX',
        ),
        evaluationResult: action == EmailActionType.none
            ? EvaluationResult.noMatch()
            : EvaluationResult(
                shouldDelete: false,
                shouldMove: false,
                matchedRule: 'Safe: sender',
                matchedPattern: 'x'),
        action: action,
        success: true,
      );

  /// Runs one background scan that evaluates [results] and completes it.
  Future<EmailScanProvider> runScan(List<EmailActionResult> results) async {
    final provider = EmailScanProvider()
      ..initializeScanMode(mode: ScanMode.readOnly);
    provider.initializePersistence(
      scanResultStore: ScanResultStore(testHelper.dbHelper),
      unmatchedEmailStore: unmatchedStore,
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
    return provider;
  }

  Future<void> export(EmailScanProvider provider) =>
      BackgroundScanExport.exportIfEnabled(
        scanProvider: provider,
        accountId: 'acct-a',
        settingsStore: settings,
        log: (m) async => logs.add(m),
      );

  /// Data lines (header and blanks removed) of the single daily file.
  List<String> exportedLines() {
    final dir = Directory(p.join(tmp.path, 'default', 'scan_exports'));
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.data.csv'))
        .toList();
    expect(files, hasLength(1));
    return files.single
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && l != scanSheetHeaderLine)
        .toList();
  }

  int listings(String id) =>
      exportedLines().where((l) => l.split('\t').contains(id)).length;

  group('T-4 -- the background export lists an unaddressed No Rule email once',
      () {
    test('a second scan that re-finds the same email does not list it again',
        () async {
      await export(await runScan([result('uid-1'), result('uid-2')]));
      expect(listings('uid-1'), 1);
      expect(listings('uid-2'), 1);

      await export(await runScan([result('uid-1'), result('uid-2')]));
      expect(listings('uid-1'), 1, reason: 'listed once, not once per scan');
      expect(listings('uid-2'), 1);
    });

    test('a scan whose rows are all omitted still writes the "<no records to '
        'process>" row', () async {
      await export(await runScan([result('uid-1')]));
      await export(await runScan([result('uid-1')]));
      final lines = exportedLines();
      expect(lines.where((l) => l.contains('<no records to process>')),
          hasLength(1));
      expect(lines, hasLength(2));
    });

    test('actions taken are always exported, even when a No Rule email beside '
        'them is omitted', () async {
      await export(await runScan([result('uid-1')]));
      await export(await runScan([
        result('uid-1'),
        result('uid-9', action: EmailActionType.safeSender),
      ]));
      expect(listings('uid-1'), 1);
      expect(listings('uid-9'), 1);
      await export(await runScan([
        result('uid-9', action: EmailActionType.safeSender),
      ]));
      expect(listings('uid-9'), 2, reason: 'an action row is never omitted');
    });

    test('a changed subject is listed again', () async {
      await export(await runScan([result('uid-1', subject: 'first')]));
      await export(await runScan([result('uid-1', subject: 'second')]));
      expect(listings('uid-1'), 2);
    });

    test('an email dismissed in Review and re-found is listed again (Q20)',
        () async {
      await export(await runScan([result('uid-1')]));
      final row = (await (await testHelper.dbHelper.database)
              .query('unmatched_emails'))
          .single;
      await unmatchedStore.markAsProcessed(row['id'] as int, true, reason: NoRuleMarkReason.dismissed);

      await export(await runScan([result('uid-1')]));
      expect(listings('uid-1'), 2);
      expect((await (await testHelper.dbHelper.database)
              .query('unmatched_emails'))
          .single['processed'], 0);
    });
  });

  group('T-5 -- everything else stays complete (Q19, Q23)', () {
    test('the manual-scan rows (default getExcelRows) still include an '
        'already-listed email', () async {
      await runScan([result('uid-1')]);
      final second = await runScan([result('uid-1')]);
      expect(second.getExcelRows(), hasLength(1),
          reason: 'the manual-scan export calls getExcelRows() with no flag');
      expect(second.getExcelRows(omitAlreadyListedNoRule: true), isEmpty);
    });

    test('the second scan still COUNTS the email as No Rule', () async {
      await runScan([result('uid-1'), result('uid-2')]);
      final second = await runScan([result('uid-1'), result('uid-2')]);
      expect(second.noRuleCount, 2);
      final rows = await (await testHelper.dbHelper.database)
          .query('scan_results', orderBy: 'id');
      expect(rows.last['no_rule_count'], 2,
          reason: 'Scan History "No Rule" is the per-scan evaluated count');
      expect(await (await testHelper.dbHelper.database)
              .query('unmatched_emails'),
          hasLength(2),
          reason: 'but the table holds one row per email');
    });
  });
}
