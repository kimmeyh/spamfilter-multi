/// F249 (Sprint 76): an ACCEPTED stop is honored before the first batch.
///
/// Before: the only cancel checkpoint was at a batch boundary. A scan that had
/// fetched nothing yet -- Found 0, like the Fold's stuck 11:20 PM row --
/// never reached one, so "Stop the background scan and start mine" was
/// accepted by the coordinator and then ignored; the scan went on to
/// "completed" (seen first in the F248 tests, 2026-10-05). After: the scan
/// also checks right after the connect, at each folder start and after the
/// last folder.
///
/// The REAL BackgroundScanCore, EmailScanner, heartbeat and row request run
/// over a fake platform registered under 'aol', fake secure storage and a
/// real test database.
///
/// What these do NOT catch: a stop while the CONNECT ITSELF is blocked (a
/// hung login never returns to a checkpoint -- that needs a cancel race,
/// pending the phone log), a stop while one folder's search is blocked, and a
/// row with no live worker behind it (Task 2 candidate 2).
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart'
    show Credentials;
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

/// Requests the stop on the row at a chosen moment, waits for the heartbeat
/// to see it, and returns NO emails (so no batch checkpoint can fire).
class _StopPlatform extends MockEmailProvider {
  _StopPlatform(this.store, {required this.duringConnect, this.onFolder});
  final ScanResultStore store;
  final bool duringConnect;

  /// Request the stop while fetching this folder (null = never).
  final String? onFolder;

  Future<void> _requestAndWait() async {
    final row = await store.getActiveScanForAccount(_account);
    if (row?.id != null) await store.requestCancel(row!.id!);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    await super.loadCredentials(credentials);
    if (duringConnect) await _requestAndWait();
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    if (onFolder != null && folderNames.contains(onFolder)) {
      await _requestAndWait();
    }
    return const [];
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
    logDir = await Directory.systemTemp.createTemp('f249_log_');
    DiagnosticLogger.debugSetDir(logDir.path);
    DiagnosticLogger.debugSetEnabled(true);
    BackgroundScanCore.busyWait = (_) async {};
    EmailScanProvider.debugHeartbeatIntervalOverride =
        const Duration(milliseconds: 20);
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
    await DiagnosticLogger.log(
        kind: DiagnosticLogger.kindInfo, context: 'test', detail: 'flush');
    final buffer = StringBuffer();
    await for (final e in logDir.list()) {
      if (e is File) buffer.write(await e.readAsString());
    }
    return buffer.toString();
  }

  /// Runs the background scan on [platform]; returns (outcome, row, log).
  Future<(AccountScanOutcome, ScanResult, String)> run(
      _StopPlatform Function(ScanResultStore) platform) async {
    final scanStore = ScanResultStore(testHelper.dbHelper);
    previous =
        PlatformRegistry.overrideFactoryForTest('aol', () => platform(scanStore));
    final outcome = await BackgroundScanCore.scanAccount(
      accountId: _account,
      platformId: 'aol',
      ruleSetProvider: RuleSetProvider(),
      settingsStore: SettingsStore(testHelper.dbHelper),
      scanResultStore: scanStore,
    );
    final rows = await scanStore.getScanResultsByAccount(_account);
    return (outcome, rows.single, await readLog());
  }

  void expectStopped(AccountScanOutcome outcome, ScanResult row, String log) {
    expect(outcome.stopped, isTrue,
        reason: 'an accepted stop must stop the scan; log:\n$log');
    expect(row.status, 'interrupted');
    expect(row.errorMessage, ScanResultStore.stoppedForManualScanReason);
    expect(log, isNot(contains('outcome -- completed')));
  }

  test('a stop requested while CONNECTING is honored right after the connect, '
      'before any folder is searched', () async {
    final (outcome, row, log) =
        await run((s) => _StopPlatform(s, duringConnect: true));
    expectStopped(outcome, row, log);
    expect(log, contains('cancel -- observed after connect'));
    expect(log, isNot(contains('fetch -- folder')),
        reason: 'no folder may be searched after the stop');
  });

  test('a stop requested during an EMPTY folder is honored at the next folder '
      'start (Found 0 -- the Fold case)', () async {
    final (outcome, row, log) = await run(
        (s) => _StopPlatform(s, duringConnect: false, onFolder: 'Inbox'));
    expectStopped(outcome, row, log);
    expect(log, contains('cancel -- observed folder "Bulk" start'));
    expect(log, isNot(contains('fetch -- folder "Bulk" begin')));
  });

  test('a stop requested during the LAST folder is honored before results are '
      'acted on', () async {
    final (outcome, row, log) = await run(
        (s) => _StopPlatform(s, duringConnect: false, onFolder: 'Bulk Mail'));
    expectStopped(outcome, row, log);
    expect(log, contains('cancel -- observed after the last folder'));
  });
}
