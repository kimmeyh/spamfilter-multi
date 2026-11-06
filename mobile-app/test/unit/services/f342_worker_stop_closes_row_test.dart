/// F342 (Sprint 84, Issue #551): when WorkManager stops the Android background
/// worker mid-scan (Fold logs: `reason=deviceState raw=4`, 3 scans), the
/// scan's `scan_results` row must be closed as `interrupted` at once, not
/// left `in_progress` for the 5-minute heartbeat window.
///
/// Platform paths (ADR-0042): the stop handler is Android only (WorkManager).
/// The registry and the store method are shared Dart and are also exercised
/// on the Windows path of the scanner, which never reads them. iOS has no
/// background run yet (F67c).
///
/// What these tests do NOT catch: whether the row write finishes before the
/// plugin tears the engine down on a real phone (a host test cannot prove a
/// platform timing guarantee; a `closed N in-progress scan row(s)` line in a
/// Fold log would), and whether `_scanAccountOnce` registers the provider
/// (guarded by the source-text wiring test, which proves the text exists, not
/// that it runs on a phone).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart' show StopReason;

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('F342 stop closes the in-flight scan row', () {
    late DatabaseTestHelper helper;
    late ScanResultStore store;
    late EmailScanProvider provider;
    const accountId = 'aol-f342@aol.com';

    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
      await helper.createTestAccount(accountId, platformId: 'aol');
      store = ScanResultStore(helper.dbHelper);
      provider = EmailScanProvider()
        ..initializePersistence(
          scanResultStore: store,
          unmatchedEmailStore: UnmatchedEmailStore(helper.dbHelper),
          databaseHelper: helper.dbHelper,
        )
        ..setCurrentAccountId(accountId);
      await provider.startScan(
          totalEmails: 1,
          scanType: 'background',
          foldersScanned: ['INBOX'],
          platformId: 'aol');
      BackgroundScanCore.debugRegisterInFlight(accountId, provider);
    });

    tearDown(() async {
      BackgroundScanCore.debugClearInFlight();
      await provider.errorScan('test cleanup'); // ends the heartbeat timer
      await helper.tearDown();
    });

    test('the handler marks the running row interrupted with the reason',
        () async {
      final id = provider.currentScanResultId!;
      await onWorkerStopped('t', StopReason.timeout,
          write: (_) async {},
          closeScans: () =>
              BackgroundScanCore.closeInFlightScansAsInterrupted(helper.dbHelper));
      final row = (await store.getScanResultById(id))!;
      expect(row.status, 'interrupted');
      expect(row.errorMessage, BackgroundScanCore.stoppedByPhoneReason);
    });

    test('the default closer (no seam) reaches the registry', () async {
      // Proves onWorkerStopped's own default wiring, not only the helper.
      // The default calls BackgroundScanCore.closeInFlightScansAsInterrupted
      // (DatabaseHelper()). DatabaseHelper() is a singleton and the test
      // helper's dbHelper is that same instance, so the default closer writes
      // to the test database and the row can be read back.
      // Does NOT catch: a default closer that targets a different database
      // file on a phone (the singleton is shared here by construction).
      final id = provider.currentScanResultId!;
      expect(identical(helper.dbHelper, DatabaseHelper()), isTrue);
      final sw = Stopwatch()..start();
      await onWorkerStopped('t', StopReason.timeout, write: (_) async {});
      expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
      final row = (await store.getScanResultById(id))!;
      expect(row.status, 'interrupted');
      expect(row.errorMessage, BackgroundScanCore.stoppedByPhoneReason);
    });

    test('a scan that finished before the stop keeps its status', () async {
      final id = provider.currentScanResultId!;
      await provider.completeScan();
      final closed =
          await BackgroundScanCore.closeInFlightScansAsInterrupted(helper.dbHelper);
      expect(closed, 0);
      expect((await store.getScanResultById(id))!.status, 'completed');
    });

    test('a provider with no claimed row is skipped, not an error', () async {
      BackgroundScanCore.debugClearInFlight();
      BackgroundScanCore.debugRegisterInFlight(
          'aol-none@aol.com', EmailScanProvider());
      expect(
          await BackgroundScanCore.closeInFlightScansAsInterrupted(helper.dbHelper), 0);
    });

    test('a failing or hanging closer does not hold the teardown', () async {
      final sw = Stopwatch()..start();
      await onWorkerStopped('t', StopReason.timeout,
          write: (_) async {},
          closeScans: () async => throw StateError('db'));
      await onWorkerStopped('t', StopReason.timeout,
          write: (_) async {},
          closeScans: () =>
              Future<int>.delayed(const Duration(seconds: 30), () => 1));
      expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('the closed-rows line is written when a row was closed', () async {
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.timeout,
          write: (d) async => lines.add(d), closeScans: () async => 1);
      expect(lines, hasLength(2));
      expect(lines.last, contains('closed 1 in-progress scan row(s)'));
    });

    test('a failed close writes a diagnostic line, not only logcat', () async {
      // Does NOT catch: a failing log write; that path swallows by design.
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.timeout,
          write: (d) async => lines.add(d),
          closeScans: () async => throw StateError('db locked'));
      expect(lines, hasLength(2));
      expect(lines.last, contains('could not close the stopped scan row'));
      expect(lines.last, contains('db locked'));
    });

    test('wiring: _scanAccountOnce registers and unregisters the provider',
        () {
      final src = File('lib/core/services/background_scan_core.dart')
          .readAsStringSync();
      expect(src, contains('_inFlightScans[accountId] = scanProvider;'));
      expect(src, contains('_inFlightScans.remove(accountId);'));
      expect(src, contains('if (identical(_inFlightScans[accountId], scanProvider))'));
    });
  });
}
