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
/// that it runs on a phone). The registry is also driven through the real
/// `scanAccount` with a probe platform (register during the scan, unregister
/// after, including a throwing scan); that cannot show a throwing
/// EmailScanner constructor.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Database;
import 'package:workmanager/workmanager.dart' show StopReason;

import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

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
      await onWorkerStopped('t', StopReason.preempt,
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
      await onWorkerStopped('t', StopReason.preempt, write: (_) async {});
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
      await onWorkerStopped('t', StopReason.preempt,
          write: (_) async {},
          closeScans: () async => throw StateError('db'));
      await onWorkerStopped('t', StopReason.preempt,
          write: (_) async {},
          closeScans: () =>
              Future<int>.delayed(const Duration(seconds: 30), () => 1));
      expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('the closed-rows line is written when a row was closed', () async {
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.preempt,
          write: (d) async => lines.add(d), closeScans: () async => 1);
      expect(lines, hasLength(2));
      expect(lines.last, contains('closed 1 in-progress scan row(s)'));
    });

    test('a failed close writes a diagnostic line, not only logcat', () async {
      // Does NOT catch: a failing log write; that path swallows by design.
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.preempt,
          write: (d) async => lines.add(d),
          closeScans: () async => throw StateError('db locked'));
      expect(lines, hasLength(2));
      expect(lines.last, contains('could not close the stopped scan row'));
      expect(lines.last, contains('db locked'));
    });

    test('the row is closed BEFORE the diagnostic-log write runs (7.7.1 M1)',
        () async {
      // The write seam records what the row looked like when the FIRST log
      // line (the stop line) was written. Order swapped back, it reads
      // in_progress. Does NOT catch: a log write that is slow on a phone (the
      // seam is instant here); only the order is proven.
      final id = provider.currentScanResultId!;
      final statusAtFirstWrite = <String>[];
      await onWorkerStopped('t', StopReason.preempt, write: (d) async {
        if (statusAtFirstWrite.isEmpty) {
          statusAtFirstWrite
              .add((await store.getScanResultById(id))!.status);
        }
      },
          closeScans: () => BackgroundScanCore.closeInFlightScansAsInterrupted(
              helper.dbHelper));
      expect(statusAtFirstWrite, ['interrupted']);
    });

    test('the row is closed even when the log write never finishes (M1)',
        () async {
      // Does NOT catch: a process killed before the close starts.
      final id = provider.currentScanResultId!;
      await onWorkerStopped('t', StopReason.preempt,
          write: (_) => Completer<void>().future,
          closeScans: () => BackgroundScanCore.closeInFlightScansAsInterrupted(
              helper.dbHelper));
      expect((await store.getScanResultById(id))!.status, 'interrupted');
    });

    test('an app cancellation (AndroidX raw 1) stores the turned-off reason',
        () async {
      // AndroidX CANCELLED_BY_APP is 1; the plugin's Dart enum names raw 1
      // `timeout`. Does NOT catch: the plugin delivering a different raw value
      // for a cancel on some Android version (verified from the plugin source
      // and the AndroidX table, not on a device).
      final id = provider.currentScanResultId!;
      expect(StopReason.fromRawValue(kAndroidxStopCancelledByApp),
          StopReason.timeout);
      await onWorkerStopped('t', StopReason.fromRawValue(1), write: (_) async {});
      final row = (await store.getScanResultById(id))!;
      expect(row.status, 'interrupted');
      expect(row.errorMessage, BackgroundScanCore.stoppedByAppReason);
      expect(row.errorMessage, isNot(contains('next scan')));
    });

    test('the reason text follows the raw value, not the plugin enum name', () {
      // The plugin's cancelledByApp (raw 3) is AndroidX TIMEOUT: a phone stop.
      // Does NOT catch: the text shown in Scan History (covered by
      // scan_history_narrow_test for the phone text).
      expect(scanRowReasonFor(StopReason.cancelledByApp),
          BackgroundScanCore.stoppedByPhoneReason);
      expect(scanRowReasonFor(StopReason.fromRawValue(1)),
          BackgroundScanCore.stoppedByAppReason);
      expect(scanRowReasonFor(StopReason.deviceState),
          BackgroundScanCore.stoppedByPhoneReason);
    });

    test('a partial close failure still rethrows the first error', () async {
      // Does NOT catch: the count log line itself (logcat only, no seam).
      BackgroundScanCore.debugClearInFlight();
      BackgroundScanCore.debugRegisterInFlight(accountId, provider);
      await expectLater(
          BackgroundScanCore.closeInFlightScansAsInterrupted(
              _FailingDatabaseHelper()),
          throwsA(isA<StateError>()));
    });

    group('_scanAccountOnce registry (behavior)', () {
      const scanAccount = 'acct-reg';
      late _ProbePlatform probe;

      setUp(() async {
        // The outer setUp registered a provider; start from an empty registry.
        BackgroundScanCore.debugClearInFlight();
        await helper.createTestAccount(scanAccount);
        probe = _ProbePlatform();
        final previous =
            PlatformRegistry.overrideFactoryForTest('demo', () => probe);
        addTearDown(
            () => PlatformRegistry.overrideFactoryForTest('demo', previous));
      });

      Future<AccountScanOutcome> scan() => BackgroundScanCore.scanAccount(
            accountId: scanAccount,
            platformId: 'demo',
            ruleSetProvider: RuleSetProvider(),
            settingsStore: SettingsStore(helper.dbHelper),
            scanResultStore: ScanResultStore(helper.dbHelper),
          );

      test('registered during the scan, unregistered after it', () async {
        // Does NOT catch: registration order relative to the EmailScanner
        // constructor (it cannot be made to throw here).
        await scan();
        expect(probe.countDuringFetch, 1);
        expect(BackgroundScanCore.debugInFlightCount, 0);
      });

      test('unregistered when the scan throws', () async {
        probe.throwOnFetch = true;
        try {
          await scan();
        } catch (_) {
          // Whether the scanner absorbs or rethrows the error, the registry
          // must be empty afterwards.
        }
        expect(probe.countDuringFetch, 1);
        expect(BackgroundScanCore.debugInFlightCount, 0);
      });
    });
  });
}

class _ProbePlatform extends MockEmailProvider {
  int? countDuringFetch;
  bool throwOnFetch = false;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) {
    countDuringFetch = BackgroundScanCore.debugInFlightCount;
    if (throwOnFetch) throw StateError('boom');
    return super.fetchMessages(daysBack: daysBack, folderNames: folderNames);
  }
}

class _FailingDatabaseHelper implements DatabaseHelper {
  @override
  Future<Database> get database async => throw StateError('db gone');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
