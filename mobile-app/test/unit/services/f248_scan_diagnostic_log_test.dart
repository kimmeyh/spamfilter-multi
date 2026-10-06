/// F248 (Sprint 76): the diagnostic log records each scan's stages.
///
/// Before: the log recorded only re-processing and three IMAP batch failures,
/// so the two 0.17.0 phone defects -- a background scan stuck at Found 0 that
/// "Stop the background scan and start mine" could not stop (F249), and a
/// Gmail sign-in that fell back to the browser (F250) -- wrote nothing.
/// After: start, claim, connect (begin / done with elapsed ms), each folder
/// fetch, a stop request found by the heartbeat, and the outcome.
///
/// The REAL BackgroundScanCore and EmailScanner run over a fake platform
/// registered under 'aol' (so the credential connect runs -- a demo scan skips
/// it), fake secure storage, and a real test database.
///
/// What these do NOT catch: a second ISOLATE or PROCESS writing the same file
/// (one isolate here), the file being reachable on a phone over MTP, and the
/// Gmail sign-in lines (`f248_sign_in_diagnostic_log_test.dart`).
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

const _account = 'someone@example.com';

/// Returns the full sample mail for any folder (the account's AOL folder
/// names match none of the mock's own).
class _AllMailPlatform extends MockEmailProvider {
  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) =>
      super.fetchMessages(daysBack: daysBack, folderNames: ['All Folders']);
}

/// Sprint 76 (Harold Q4): no network -- every fetch and the folder listing fail.
class _OfflinePlatform extends MockEmailProvider {
  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async =>
      throw const SocketException("Failed host lookup: 'imap.aol.com'");

  @override
  Future<List<FolderInfo>> listFolders() async =>
      throw const SocketException("Failed host lookup: 'imap.aol.com'");
}

/// Asks for a stop ON THE ROW mid-scan, then gives the heartbeat time to see it.
class _RowStopPlatform extends MockEmailProvider {
  _RowStopPlatform(this.store);
  final ScanResultStore store;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    final row = await store.getActiveScanForAccount(_account);
    if (row?.id != null) await store.requestCancel(row!.id!);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // 'All Folders': the full sample set, so the scan has BATCHES -- the
    // cancel is honored at a batch boundary (see the AC-2 comment).
    return super.fetchMessages(daysBack: daysBack, folderNames: ['All Folders']);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};
  late DatabaseTestHelper testHelper;
  late Directory logDir;
  SpamFilterPlatform Function()? previous;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    store
      ..clear()
      ..['saved_accounts'] = _account
      ..['credentials_${_account}_email'] = _account
      ..['credentials_${_account}_password'] = 'app-password'
      ..['credentials_${_account}_platformId'] = 'aol';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = call.arguments['value'] as String;
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
      }
      return null;
    });
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(_account, platformId: 'aol');
    logDir = await Directory.systemTemp.createTemp('f248_log_');
    DiagnosticLogger.debugSetDir(logDir.path);
    DiagnosticLogger.debugSetEnabled(true);
    BackgroundScanCore.busyWait = (_) async {};
    previous =
        PlatformRegistry.overrideFactoryForTest('aol', MockEmailProvider.new);
  });

  tearDown(() async {
    PlatformRegistry.overrideFactoryForTest('aol', previous);
    BackgroundScanCore.busyWait = (d) => Future<void>.delayed(d);
    EmailScanProvider.debugHeartbeatIntervalOverride = null;
    DiagnosticLogger.debugSetDir(null);
    DiagnosticLogger.debugSetEnabled(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
    await testHelper.tearDown();
    if (await logDir.exists()) await logDir.delete(recursive: true);
  });

  Future<String> readLog() async {
    // Let fire-and-forget writes drain through the logger's chain.
    await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindInfo, context: 'test', detail: 'flush');
    final buffer = StringBuffer();
    if (!await logDir.exists()) return '';
    await for (final e in logDir.list()) {
      if (e is File) buffer.write(await e.readAsString());
    }
    return buffer.toString();
  }

  Future<void> runBackgroundScan() => BackgroundScanCore.scanAccount(
        accountId: _account,
        platformId: 'aol',
        ruleSetProvider: RuleSetProvider(),
        settingsStore: SettingsStore(testHelper.dbHelper),
        scanResultStore: ScanResultStore(testHelper.dbHelper),
      );

  /// Index of [needle] after [from], or -1.
  int at(String text, String needle, [int from = 0]) =>
      text.indexOf(needle, from);

  test('AC-1: a background scan writes start, claim, connect, fetch and '
      'outcome lines, in that order', () async {
    await runBackgroundScan();
    final log = await readLog();

    final start = at(log, 'start -- platform=aol');
    final claim = at(log, 'claim -- granted', start);
    final connectBegin = at(log, 'connect -- begin', claim);
    final connectDone = at(log, 'connect -- done in', connectBegin);
    final fetch = at(log, 'fetch -- folder', connectDone);
    final outcome = at(log, 'outcome -- completed', fetch);
    expect([start, claim, connectBegin, connectDone, fetch, outcome],
        everyElement(greaterThanOrEqualTo(0)),
        reason: 'every stage present and in order; log was:\n$log');
    expect(log, contains('[SCAN] [scan/background]'));
  });

  test('AC-5: no line carries the full account address', () async {
    await runBackgroundScan();
    final log = await readLog();
    expect(log, isNotEmpty);
    expect(log, isNot(contains(_account)),
        reason: 'the log is a file the user shares (F248 R-5)');
  });

  test('AC-3: with logging OFF the same scan writes nothing', () async {
    DiagnosticLogger.debugSetEnabled(false);
    await runBackgroundScan();
    final files = await logDir.list().toList();
    expect(files, isEmpty);
  });

  test('AC-2: a stop request on the row is logged as found by the heartbeat '
      '(ONCE), and the outcome reads stopped', () async {
    // The demo platform, because it supplies emails: the cancel is honored at
    // a BATCH boundary, and a fake that returns none never reaches one (the
    // scan then "completes" with the request ignored -- an F249 finding,
    // recorded in the Sprint 76 plan, not something this test is about).
    final scanStore = ScanResultStore(testHelper.dbHelper);
    final previousDemo = PlatformRegistry.overrideFactoryForTest(
        'demo', () => _RowStopPlatform(scanStore));
    addTearDown(
        () => PlatformRegistry.overrideFactoryForTest('demo', previousDemo));
    EmailScanProvider.debugHeartbeatIntervalOverride =
        const Duration(milliseconds: 20);

    await BackgroundScanCore.scanAccount(
      accountId: _account,
      platformId: 'demo',
      ruleSetProvider: RuleSetProvider(),
      settingsStore: SettingsStore(testHelper.dbHelper),
      scanResultStore: scanStore,
    );
    final log = await readLog();

    expect(log, contains('stop-request found on row'));
    expect(log, contains('coordinator accepted'));
    expect(log, contains('outcome -- stopped (cancel)'));
    // Sprint 76: the line names WHO stopped it (0.17.1 could not tell an F220
    // backgrounding revoke from a timeout).
    expect(log, contains('reason=stop request from another scan (F238)'));
    expect('stop-request found on row'.allMatches(log).length, 1,
        reason: 'logged once per scan, not once per heartbeat tick');
  });

  test('each counted scan error is logged with its cause, without sender or '
      'subject (F205 / MV74-3)', () async {
    final provider = EmailScanProvider()..setCurrentAccountId(_account);
    provider.recordFolderFetchError(
        'Bulk', 'SocketException: reset while fetching for someone@example.com');
    provider.recordResult(EmailActionResult(
      email: EmailMessage(
        id: '42',
        from: 'spammer@bad.example',
        subject: 'SECRET SUBJECT',
        body: 'body',
        headers: const {},
        receivedDate: DateTime(2026, 10, 4),
        folderName: 'INBOX',
      ),
      action: EmailActionType.delete,
      success: false,
      error: 'NO [CANNOT] message is gone',
    ));
    final log = await readLog();

    expect(log, contains('[scan/error]'));
    expect(log, contains('folder "Bulk" fetch failed: SocketException'));
    expect(log, contains('action delete failed in folder "INBOX": NO [CANNOT]'));
    expect(log, isNot(contains('SECRET SUBJECT')));
    expect(log, isNot(contains('spammer@bad.example')));
    expect(log, isNot(contains(_account)));
  });

  test('a scan that finds mail logs rules loaded, each folder\'s count and '
      'time, the action plan, the stored No Rule rows and its duration',
      () async {
    PlatformRegistry.overrideFactoryForTest('aol', _AllMailPlatform.new);
    await runBackgroundScan();
    final log = await readLog();

    expect(log, contains(RegExp(r'rules -- rules=\d+ enabled=\d+ safeSenders=\d+')));
    expect(log, contains(RegExp(r'fetch -- folder "Inbox" done: \d+ emails in \d+ms')));
    expect(log, contains(RegExp(r'actions -- mode=\w+ executeRules=(true|false)')));
    expect(log, contains(RegExp(r'\[scan/persist\] .* stored \d+ action record\(s\), [1-9]\d* No Rule row\(s\)')),
        reason: 'the sample mail matches no rule, so No Rule rows are stored');
    expect(log, contains(RegExp(r'outcome -- completed found=[1-9]\d* .* in \d+\.\ds')));
    // Sprint 76: found minus processed was unexplained on the Fold (638/163).
    expect(log, contains(RegExp(r'outcome -- completed .* alreadyFiled=\d+ in ')));
    expect(log, isNot(contains('@bad.example')),
        reason: 'no sender addresses from the mail itself');
  });

  test('Sprint 76 Q4: a scan where EVERY folder failed (no network) ends as '
      'an error, not "completed"', () async {
    // What this does NOT catch: a partial failure (one folder ok) -- that
    // stays "completed" with errors by design (F174), covered by the pure
    // scanFetchedNothing tests.
    PlatformRegistry.overrideFactoryForTest('aol', _OfflinePlatform.new);
    Object? thrown;
    try {
      await runBackgroundScan();
    } catch (e) {
      thrown = e;
    }
    final log = await readLog();
    expect(log, contains('every folder failed to fetch'));
    expect(log, isNot(contains('outcome -- completed')),
        reason: '0.17.2 Fold: "completed found=0 ... errors=3" and no retry');
    expect(thrown, isNotNull,
        reason: 'the failure reaches the worker, so WorkManager can retry');
  });

  test('Sprint 76 Q3: a background scan right after another waits out the '
      '5-minute spacing, then scans', () async {
    await runBackgroundScan(); // completes now
    final waits = <Duration>[];
    BackgroundScanCore.busyWait = (d) async => waits.add(d);
    await runBackgroundScan();
    final log = await readLog();

    expect(waits, isNotEmpty);
    expect(waits.first, greaterThan(const Duration(minutes: 4, seconds: 50)));
    expect(waits.first, lessThanOrEqualTo(const Duration(minutes: 5)));
    expect(log, contains('spacing -- waiting'));
    expect('outcome -- completed'.allMatches(log).length, 2,
        reason: 'spacing delays the scan; it never skips it');
  });

  test('a dead holder reaped by the claim is named with its heartbeat age',
      () async {
    final scanStore = ScanResultStore(testHelper.dbHelper);
    ScanResult row() => ScanResult(
          accountId: _account,
          scanType: 'background',
          scanMode: 'readOnly',
          startedAt: DateTime.now().millisecondsSinceEpoch,
          totalEmails: 0,
          foldersScanned: const ['INBOX'],
          status: 'in_progress',
        );
    final first = await scanStore.claimAccountScan(row());
    expect(first.granted, isTrue);
    // Age the holder past the heartbeat freshness: it stopped beating.
    final db = await testHelper.dbHelper.database;
    final old = DateTime.now()
        .subtract(const Duration(minutes: 10))
        .millisecondsSinceEpoch;
    await db.update('scan_results',
        {'started_at': old, 'last_heartbeat_at': old},
        where: 'id = ?', whereArgs: [first.id]);

    final second = await scanStore.claimAccountScan(row());
    expect(second.granted, isTrue);
    final log = await readLog();
    expect(log,
        contains(RegExp('reaped dead background row ${first.id}: started '
            r'\d+s ago, last heartbeat \d+s ago')));
  });

  test('error text is scrubbed of addresses (R-5)', () {
    final described = DiagnosticLogger.describeError(
        Exception('No credentials found for account a.person@example.org'));
    expect(described, isNot(contains('a.person@example.org')));
    expect(described, startsWith('_Exception: '));
  });
}
