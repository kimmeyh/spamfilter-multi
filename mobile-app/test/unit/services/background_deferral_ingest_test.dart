/// F109c (Sprint 44) test: the deferral ingest reads the native runner's
/// handoff file, inserts one `status='deferred'` background_scan_log row per
/// valid record, clears the file, tolerates malformed/empty lines, and exposes
/// the latest deferral.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:my_email_spam_filter/core/services/background_deferral_ingest.dart';
import 'package:my_email_spam_filter/core/storage/background_scan_log_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late BackgroundScanLogStore logStore;
  late BackgroundDeferralIngest ingest;
  late Directory logDir;
  late String handoffPath;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    logStore = BackgroundScanLogStore(testHelper.dbHelper);
    // Inject a temp logs dir so the ingest runs without the path_provider plugin.
    logDir = await Directory.systemTemp.createTemp('deferral_test_');
    ingest = BackgroundDeferralIngest(logStore, logDirOverride: logDir.path);
    handoffPath = p.join(logDir.path, kDeferralHandoffFilename);
    // FK: background_scan_log.account_id -> accounts.account_id.
    await testHelper.createTestAccount('acct-1');
    await testHelper.createTestAccount('acct-2');
  });

  tearDown(() async {
    await testHelper.tearDown();
    try {
      if (await logDir.exists()) await logDir.delete(recursive: true);
    } catch (_) {}
  });

  test('returns 0 and is a no-op when no handoff file exists', () async {
    expect(await ingest.ingest(), 0);
    expect(await logStore.getLogsByStatus(kDeferredStatus), isEmpty);
  });

  test('inserts one deferred row per record and deletes the file', () async {
    await File(handoffPath).writeAsString(
      '1000\tacct-1\n'
      '2000\tacct-2\n',
    );

    final n = await ingest.ingest();
    expect(n, 2);

    final deferred = await logStore.getLogsByStatus(kDeferredStatus);
    expect(deferred, hasLength(2));
    expect(deferred.every((e) => e.status == kDeferredStatus), isTrue);
    // Newest first by scheduled_time.
    expect(deferred.first.scheduledTime, 2000);
    expect(deferred.first.accountId, 'acct-2');

    // File consumed so the same deferrals are not double-ingested.
    expect(await File(handoffPath).exists(), isFalse);
    expect(await ingest.ingest(), 0);
  });

  test('skips malformed / empty / accountless lines', () async {
    await File(handoffPath).writeAsString(
      '\n' // empty
      'not-a-number\tacct-1\n' // bad timestamp
      '3000\n' // missing account id
      '4000\tacct-1\n', // valid
    );

    final n = await ingest.ingest();
    expect(n, 1);
    final deferred = await logStore.getLogsByStatus(kDeferredStatus);
    expect(deferred, hasLength(1));
    expect(deferred.first.scheduledTime, 4000);
  });

  test('latestDeferral returns the most recent, or null when none', () async {
    expect(await ingest.latestDeferral(), isNull);

    await File(handoffPath).writeAsString('5000\tacct-1\n9000\tacct-2\n');
    await ingest.ingest();

    final latest = await ingest.latestDeferral();
    expect(latest, isNotNull);
    expect(latest!.scheduledTime, 9000);
    expect(latest.accountId, 'acct-2');
  });
}
