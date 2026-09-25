/// F206 (Sprint 74): export as a platform capability.
///
///   - ONE resolver decides where exports go: the user's folder if set, else
///     the platform default (Harold: Android Documents, Windows Downloads).
///   - Clear history deletes FINISHED scans only, scoped to the filters.
///   - Changing the export folder reaches the diagnostic log's cache through
///     the SETTER (it used to keep writing to the old folder all session).
///   - Redacted exports mask sender, subject and message id.
///
/// **What these tests do NOT catch**: that the real Android/Windows default
/// folders are WRITABLE on a device (scoped storage on Android, the MSIX
/// sandbox on Windows) -- the resolver is driven through a test override.
/// That is Manual Validation on both platforms, and it is the riskiest part
/// of this card.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/scan_sheet_export.dart';
import 'package:my_email_spam_filter/core/services/export_directories.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late Directory tmp;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    tmp = await Directory.systemTemp.createTemp('f206_');
    ExportDirectories.overrideDefaultForTest(p.join(tmp.path, 'default'));
    DiagnosticLogger.invalidateCache();
  });

  tearDown(() async {
    ExportDirectories.overrideDefaultForTest(null);
    DiagnosticLogger.invalidateCache();
    await testHelper.tearDown();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('T-1 -- where exports go', () {
    test('Android: public Documents derived from the app external folder, '
        'keeping the user number', () {
      expect(
          ExportDirectories.publicDocumentsFrom(
              '/storage/emulated/0/Android/data/com.myemailspamfilter/files'),
          '/storage/emulated/0/Documents');
      expect(
          ExportDirectories.publicDocumentsFrom(
              '/storage/emulated/10/Android/data/com.myemailspamfilter/files'),
          '/storage/emulated/10/Documents',
          reason: 'a work or secondary profile gets its OWN Documents');
      expect(ExportDirectories.publicDocumentsFrom('/weird/path'), isNull);
    });

    test('the Settings label names THIS platform\'s real default', () {
      // The suite runs on Windows (dev) and Linux (CI); the label must match
      // what platformDefault() actually returns there.
      final label = ExportDirectories.defaultLabel;
      if (Platform.isWindows) {
        expect(label, contains('Downloads'));
      } else if (Platform.isAndroid) {
        expect(label, contains('Documents'));
      } else {
        expect(label, contains('App documents'));
      }
    });

    test('no folder configured -> the platform default, subfolder created',
        () async {
      final dir = await ExportDirectories.resolve(
          subfolder: 'scan_exports',
          settingsStore: SettingsStore(testHelper.dbHelper));
      expect(dir, p.join(tmp.path, 'default', 'scan_exports'));
      expect(await Directory(dir).exists(), isTrue);
    });

    test('review I-4: an UNWRITABLE default falls back to the app\'s own '
        'folder instead of failing every export', () async {
      ExportDirectories.debugWritableOverride = false;
      ExportDirectories.debugAppOwnFolderOverride = p.join(tmp.path, 'own');
      addTearDown(() {
        ExportDirectories.debugWritableOverride = null;
        ExportDirectories.debugAppOwnFolderOverride = null;
      });
      final dir = await ExportDirectories.resolve(
          subfolder: 'scan_exports',
          settingsStore: SettingsStore(testHelper.dbHelper));
      expect(dir, p.join(tmp.path, 'own', 'scan_exports'));
    });

    test('a folder the user chose wins over the default', () async {
      final store = SettingsStore(testHelper.dbHelper);
      final chosen = p.join(tmp.path, 'chosen');
      await store.setCsvExportDirectory(chosen);
      expect(await ExportDirectories.resolve(settingsStore: store), chosen);
    });
  });

  group('T-3 -- the diagnostic log follows a folder change (R-7)', () {
    test('setting a new export folder moves the NEXT log to it, with no '
        'manual invalidate', () async {
      final store = SettingsStore(testHelper.dbHelper);
      final a = p.join(tmp.path, 'a');
      final b = p.join(tmp.path, 'b');
      final sub = 'diagnostics${AppEnvironment.dataDirSuffix}';
      await store.setCsvExportDirectory(a);
      expect(await DiagnosticLogger.resolveLogDir(), p.join(a, sub));
      await store.setCsvExportDirectory(b);
      expect(await DiagnosticLogger.resolveLogDir(), p.join(b, sub),
          reason: 'the store setter must invalidate the logger cache');
    });

    test('review I-1: the diagnostics folder is environment-suffixed, so DEV '
        'and PROD never share (and delete) each other\'s logs', () async {
      final dir = await DiagnosticLogger.resolveLogDir();
      expect(p.basename(dir), 'diagnostics${AppEnvironment.dataDirSuffix}');
    });
  });

  group('T-2 -- Clear history deletes finished scans only', () {
    late ScanResultStore store;

    Future<int> row(String account, String type, String status) async {
      final db = await testHelper.dbHelper.database;
      return db.insert('scan_results', {
        'account_id': account, 'scan_type': type, 'scan_mode': 'readOnly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 1, 'processed_count': 1, 'deleted_count': 0,
        'moved_count': 0, 'safe_sender_count': 0, 'no_rule_count': 0,
        'error_count': 0, 'status': status, 'folders_scanned': '[]',
      });
    }

    Future<List<int>> remainingIds() async {
      final db = await testHelper.dbHelper.database;
      return (await db.query('scan_results', orderBy: 'id'))
          .map((r) => r['id'] as int)
          .toList();
    }

    setUp(() async {
      store = ScanResultStore(testHelper.dbHelper);
      await testHelper.createTestAccount('a');
      await testHelper.createTestAccount('b');
    });

    test('scoped to one account; a running scan is kept', () async {
      final aDone = await row('a', 'manual', 'completed');
      final aBg = await row('a', 'background', 'interrupted');
      final aLive = await row('a', 'manual', 'in_progress');
      final bDone = await row('b', 'manual', 'completed');
      expect(await store.countFinishedScanResults(accountId: 'a'), 2,
          reason: 'review M-3: the dialog count comes from the store');
      final deleted = await store.deleteFinishedScanResults(accountId: 'a');
      expect(deleted, 2);
      final left = await remainingIds();
      expect(left, containsAll([aLive, bDone]));
      expect(left, isNot(contains(aDone)));
      expect(left, isNot(contains(aBg)));
    });

    test('child rows cascade with a cleared scan', () async {
      final scan = await row('a', 'manual', 'completed');
      await testHelper.dbHelper.insertEmailActionBatch([
        {
          'scan_result_id': scan, 'email_id': 'e1', 'email_from': 'x@y.com',
          'email_subject': 's', 'email_received_date': 1,
          'email_folder': 'INBOX', 'action_type': 'none',
          'matched_rule_name': null, 'matched_pattern': null,
          'is_safe_sender': 0, 'success': 1,
        },
      ]);
      await store.deleteFinishedScanResults(accountId: 'a');
      final db = await testHelper.dbHelper.database;
      expect(await db.query('email_actions', where: 'scan_result_id = ?',
          whereArgs: [scan]), isEmpty);
    });

    test('scoped to a scan type', () async {
      final manual = await row('a', 'manual', 'completed');
      final bg = await row('a', 'background', 'completed');
      await store.deleteFinishedScanResults(scanType: 'background');
      expect(await remainingIds(), [manual]);
      expect(await remainingIds(), isNot(contains(bg)));
    });
  });

  group('T-4 -- redacted exports (Part C)', () {
    EmailScanProvider providerWith(String from) {
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '231203',
          from: from,
          subject: 'Your prize is waiting',
          body: '',
          headers: const {},
          receivedDate: DateTime(2026, 9, 25),
          folderName: 'INBOX',
        ),
        evaluationResult: EvaluationResult.noMatch(),
        action: EmailActionType.none,
        success: true,
      ));
      return provider;
    }

    test('CSV: sender domain kept, local part, subject and id hidden', () {
      final csv = providerWith('Prize Team <winner@spammy.com>')
          .exportResultsToCSV(redact: true);
      expect(csv, contains('w***@spammy.com'));
      expect(csv, isNot(contains('winner@')));
      expect(csv, isNot(contains('Your prize')));
      expect(csv, isNot(contains('231203')));
    });

    test('Excel rows: same masking', () {
      final row = providerWith('winner@spammy.com')
          .getExcelRows(redact: true)
          .single;
      expect(row, contains('w***@spammy.com'));
      expect(row.join('|'), isNot(contains('Your prize')));
      expect(row.join('|'), isNot(contains('231203')));
    });

    test('review I-3: an exact-sender RULE PATTERN does not leak the address',
        () {
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      provider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1', from: 'john.smith@example.com', subject: 's', body: '',
          headers: const {}, receivedDate: DateTime(2026, 9, 25),
          folderName: 'INBOX'),
        evaluationResult: EvaluationResult(
          shouldDelete: false, shouldMove: false,
          matchedRule: 'Safe: john.smith@example.com',
          matchedPattern: r'^john\.smith@example\.com$'),
        action: EmailActionType.safeSender,
        success: true,
      ));
      final csv = provider.exportResultsToCSV(redact: true);
      final row = provider.getExcelRows(redact: true).single.join('|');
      for (final out in [csv, row]) {
        expect(out, isNot(contains('john.smith')));
        expect(out, isNot(contains(r'john\.smith')));
        expect(out, contains('example'));
      }
    });

    test('review I-2: the background export FILE is redacted, and redacted '
        'rows never share a daily file with unredacted ones', () async {
      final dir = p.join(tmp.path, 'sheets');
      await Directory(dir).create(recursive: true);
      final provider = providerWith('winner@spammy.com');
      final plain = await ScanSheetExport.appendAndWrite(
          dir: dir, filePrefix: 'background_scan', accountToken: 'acct',
          sheetName: 'S', headerColor: '#FFFFFF',
          newRows: provider.getExcelRows());
      final red = await ScanSheetExport.appendAndWrite(
          dir: dir, filePrefix: 'background_scan', accountToken: 'acct',
          sheetName: 'S', headerColor: '#FFFFFF',
          newRows: provider.getExcelRows(redact: true), redacted: true);
      expect(red.xlsxPath, isNot(plain.xlsxPath));
      final redCsv = File(red.xlsxPath.replaceAll('.xlsx', '.data.csv'))
          .readAsStringSync();
      expect(redCsv, isNot(contains('winner@')));
      expect(redCsv, isNot(contains('Your prize')));
    });

    test('off by default -- an unredacted export is unchanged', () {
      final csv = providerWith('winner@spammy.com').exportResultsToCSV();
      expect(csv, contains('winner@spammy.com'));
      expect(csv, contains('231203'));
    });
  });
}
