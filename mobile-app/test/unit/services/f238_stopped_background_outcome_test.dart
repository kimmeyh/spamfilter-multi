/// F238 (Sprint 75): a background scan STOPPED so a manual scan could start
/// is not reported as a completed scan.
///
/// Before: the scanner swallows a cancel (correct for a manual scan), so
/// BackgroundScanCore built a normal outcome and the worker EXPORTED partial
/// results and NOTIFIED "scan complete" for a scan the user had just stopped;
/// had it been mapped to a plain skip instead, it would also have taken the
/// 2-6 minute busy wait and scanned the account again.
/// After: a stopped outcome (skipped, `stopped`), no export, no notification,
/// no busy wait.
///
/// The REAL BackgroundScanCore.scanAccount and EmailScanner run here. The
/// platform (behind 'demo') requests cancel through ScanCoordinator mid-scan
/// -- exactly what the F238 heartbeat tick does when it finds the request on
/// the row (that tick is tested in f238_stop_background_scan_test).
///
/// What these do NOT catch: the request crossing a real isolate or process
/// boundary (one process here), and the Windows worker's own log line for the
/// skip (it reads `skippedReason`, unchanged since Sprint 74).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

const _account = 'acct-a';

/// PR #448 test review: the WHOLE stop chain, as the manual scan's dialog
/// drives it -- a stop request WRITTEN TO THE ROW (`requestCancel(rowId)`),
/// found by the scanning provider's heartbeat tick, honored through the
/// coordinator, and recorded with the stopped-for-manual reason. The class
/// above bypasses the row and the heartbeat.
class _RowRequestMidScanPlatform extends MockEmailProvider {
  _RowRequestMidScanPlatform(this.store);
  final ScanResultStore store;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    final row = await store.getActiveScanForAccount(_account);
    if (row?.id != null) await store.requestCancel(row!.id!);
    // Several heartbeat ticks (interval overridden to 20 ms below).
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.fetchMessages(daysBack: daysBack, folderNames: folderNames);
  }
}

class _StoppedMidScanPlatform extends MockEmailProvider {
  @override
  void setDeletedRuleFolder(String? folderName) {
    ScanCoordinator.instance.requestCancel(accountId: _account, reason: 'test');
    super.setDeletedRuleFolder(folderName);
  }
}

void main() {
  late DatabaseTestHelper testHelper;
  final waits = <Duration>[];

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(_account);
    waits.clear();
    BackgroundScanCore.busyWait = (d) async => waits.add(d);
    final previous = PlatformRegistry.overrideFactoryForTest(
        'demo', _StoppedMidScanPlatform.new);
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('demo', previous));
  });

  tearDown(() async {
    BackgroundScanCore.busyWait = (d) => Future<void>.delayed(d);
    await testHelper.tearDown();
  });

  test('a stopped background scan: stopped skip, no export, no notification, '
      'no busy wait', () async {
    final store = ScanResultStore(testHelper.dbHelper);
    final outcome = await BackgroundScanCore.scanAccount(
      accountId: _account,
      platformId: 'demo',
      ruleSetProvider: RuleSetProvider(),
      settingsStore: SettingsStore(testHelper.dbHelper),
      scanResultStore: store,
    );

    expect(outcome.scanProvider.wasCancelled, isTrue,
        reason: 'precondition: the scan really was stopped');
    expect(outcome.skipped, isTrue);
    expect(outcome.stopped, isTrue);
    expect(outcome.skippedReason, ScanResultStore.stoppedForManualScanReason);
    expect(waits, isEmpty, reason: 'never scan the account again after the '
        'user stopped it to scan by hand');

    var exported = false;
    var notified = false;
    await BackgroundScanCore.completeAccount(outcome,
        export: () async => exported = true,
        notify: () async => notified = true);
    expect(exported, isFalse);
    expect(notified, isFalse, reason: 'no "scan complete" for a stopped scan');
  });

  test('end to end: a stop request on the ROW, found by the heartbeat, '
      'stops the scan and records the stopped-for-manual reason', () async {
    final store = ScanResultStore(testHelper.dbHelper);
    PlatformRegistry.overrideFactoryForTest(
        'demo', () => _RowRequestMidScanPlatform(store));
    EmailScanProvider.debugHeartbeatIntervalOverride =
        const Duration(milliseconds: 20);
    addTearDown(() => EmailScanProvider.debugHeartbeatIntervalOverride = null);

    final outcome = await BackgroundScanCore.scanAccount(
      accountId: _account,
      platformId: 'demo',
      ruleSetProvider: RuleSetProvider(),
      settingsStore: SettingsStore(testHelper.dbHelper),
      scanResultStore: store,
    );

    expect(outcome.stopped, isTrue,
        reason: 'the row request must reach the scan through the heartbeat');
    expect(waits, isEmpty);
    final rows = await store.getScanResultsByAccount(_account);
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.status, 'interrupted');
    expect(row.errorMessage, ScanResultStore.stoppedForManualScanReason,
        reason: 'Scan History must say it was stopped for a manual scan, not '
            'cancelled by the user (F238 R-4)');
  });
}
