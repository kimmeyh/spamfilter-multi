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
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
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
      await store.setCsvExportDirectory(a);
      expect(await DiagnosticLogger.resolveLogDir(), p.join(a, 'diagnostics'));
      await store.setCsvExportDirectory(b);
      expect(await DiagnosticLogger.resolveLogDir(), p.join(b, 'diagnostics'),
          reason: 'the store setter must invalidate the logger cache');
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
      final deleted = await store.deleteFinishedScanResults(accountId: 'a');
      expect(deleted, 2);
      final left = await remainingIds();
      expect(left, containsAll([aLive, bDone]));
      expect(left, isNot(contains(aDone)));
      expect(left, isNot(contains(aBg)));
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

    test('off by default -- an unredacted export is unchanged', () {
      final csv = providerWith('winner@spammy.com').exportResultsToCSV();
      expect(csv, contains('winner@spammy.com'));
      expect(csv, contains('231203'));
    });
  });
}
