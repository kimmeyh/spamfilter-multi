/// F301 / F244 (Sprint 81): a Gmail background scan that skips because the
/// account needs a new sign-in tells the user, at most once per account per day.
///
/// The REAL BackgroundScanCore.scanAccount and EmailScanner run here (same
/// harness as f239_background_sign_in_skip_test.dart); only the platform is
/// replaced by one that throws GmailSignInRequiredException, the plugin call is
/// replaced by [ScanCompleteNotifier.showOverride], and the clock by
/// [GmailSignInNotifier.now]. The last-notified time lives in the real
/// account_settings table of a test database.
///
/// What these do NOT catch: whether Windows shows the toast or Android renders
/// the notification (settled by Manual Validation on the real builds); the
/// Gmail adapter's own decision to throw (f239 tests and the emulator spike);
/// and a worker that never reaches BackgroundScanCore (the workers call it for
/// every account, which the f239 tests cover). The flag-failure test proves the
/// notifier does not depend on the flag's store methods; it does not prove the
/// real adapter's write-failure handling, which gmail_adapter_sign_in_flag_test
/// covers.
library;

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/gmail_sign_in_notifier.dart';
import 'package:my_email_spam_filter/core/services/scan_complete_notifier.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

class _NeedsSignInPlatform extends MockEmailProvider {
  @override
  void setDeletedRuleFolder(String? folderName) =>
      throw GmailSignInRequiredException();
}

/// A settings store whose sign-in FLAG methods fail, like a failed best-effort
/// write (F244). Everything else is the real store.
class _FlagBrokenStore extends SettingsStore {
  _FlagBrokenStore(DatabaseHelper db) : super(db);

  @override
  Future<void> setGmailSignInRequired(String accountId, bool required) =>
      throw StateError('flag write failed');

  @override
  Future<bool> getGmailSignInRequired(String accountId) =>
      throw StateError('flag read failed');
}

/// The first save (the attempt time) works; the retry save after a failed post
/// throws (7.7.1 improvement review M-1).
class _RetryWriteBrokenStore extends SettingsStore {
  _RetryWriteBrokenStore(DatabaseHelper db, this.attemptAt) : super(db);
  final DateTime attemptAt;

  @override
  Future<void> setGmailSignInNotifiedAt(String accountId, DateTime at) {
    if (at != attemptAt) throw StateError('retry write failed');
    return super.setGmailSignInNotifiedAt(accountId, at);
  }
}

class _Shown {
  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  _Shown(this.id, this.title, this.body, this.details);
}

void main() {
  late DatabaseTestHelper testHelper;
  late List<_Shown> shown;
  late DateTime clock;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount('acct-a@gmail.com');
    await testHelper.createTestAccount('acct-b@gmail.com');
    BackgroundScanCore.busyWait = (d) async {};
    shown = [];
    clock = DateTime(2026, 10, 24, 9, 0);
    GmailSignInNotifier.now = () => clock;
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        shown.add(_Shown(id, title, body, details));
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.android);
  });

  tearDown(() async {
    BackgroundScanCore.busyWait = (d) => Future<void>.delayed(d);
    GmailSignInNotifier.now = DateTime.now;
    ScanCompleteNotifier.showOverride = null;
    PlatformCapabilities.debugOverride = null;
    await testHelper.tearDown();
  });

  void usePlatform(MockEmailProvider Function() factory) {
    final previous = PlatformRegistry.overrideFactoryForTest('demo', factory);
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('demo', previous));
  }

  Future<AccountScanOutcome> scan(String accountId, {SettingsStore? store}) =>
      BackgroundScanCore.scanAccount(
        accountId: accountId,
        platformId: 'demo',
        ruleSetProvider: RuleSetProvider(),
        settingsStore: store ?? SettingsStore(testHelper.dbHelper),
        scanResultStore: ScanResultStore(testHelper.dbHelper),
      );

  test('a sign-in skip produces one notification that names the account and '
      'says it will not be scanned', () async {
    usePlatform(_NeedsSignInPlatform.new);
    final outcome = await scan('acct-a@gmail.com');
    expect(outcome.needsSignIn, isTrue);
    expect(shown, hasLength(1));
    expect(shown.single.title, 'Gmail sign-in needed for a*@gmail');
    expect(shown.single.body,
        'This account will not be scanned until you sign in again in the app.');
    expect(shown.single.details.android!.channelId, 'sign_in_needed_channel');
  });

  test('Windows: the same notification goes out as a toast', () async {
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.windows);
    usePlatform(_NeedsSignInPlatform.new);
    await scan('acct-a@gmail.com');
    expect(shown, hasLength(1));
    expect(shown.single.details.windows, isNotNull);
    expect(shown.single.details.android, isNull);
    expect(shown.single.title, 'Gmail sign-in needed for a*@gmail');
  });

  test('a second skip the same day for the same account produces none, and '
      'one a day later produces another', () async {
    usePlatform(_NeedsSignInPlatform.new);
    await scan('acct-a@gmail.com');
    clock = clock.add(const Duration(minutes: 15));
    await scan('acct-a@gmail.com');
    clock = clock.add(const Duration(hours: 23));
    await scan('acct-a@gmail.com');
    expect(shown, hasLength(1), reason: 'within 24 hours of the first');

    clock = DateTime(2026, 10, 25, 9, 1);
    await scan('acct-a@gmail.com');
    expect(shown, hasLength(2), reason: 'more than 24 hours later');
  });

  test('another account still gets its own notification', () async {
    usePlatform(_NeedsSignInPlatform.new);
    await scan('acct-a@gmail.com');
    await scan('acct-b@gmail.com');
    expect(shown, hasLength(2));
    expect(shown[0].id, isNot(shown[1].id));
  });

  test('a notification is produced when the sign-in flag write throws',
      () async {
    usePlatform(_NeedsSignInPlatform.new);
    final store = _FlagBrokenStore(testHelper.dbHelper);
    final outcome = await scan('acct-a@gmail.com', store: store);
    expect(outcome.needsSignIn, isTrue);
    expect(shown, hasLength(1));
  });

  // 7.7.1 silent-failure L-7, Harold Q6 = 3: a failed post is retried after
  // 1 hour, not 24. What this does NOT catch: whether the OS reports a post
  // as failed when the user turned notifications off (plugin behavior).
  test('a notification that cannot be shown does not fail the skip, and is '
      'retried after 1 hour, not on the next scan', () async {
    usePlatform(_NeedsSignInPlatform.new);
    var attempts = 0;
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async {
      attempts++;
      throw StateError('notifications are turned off for this app');
    };
    final outcome = await scan('acct-a@gmail.com');
    expect(outcome.needsSignIn, isTrue);
    await scan('acct-a@gmail.com');
    clock = clock.add(const Duration(minutes: 59));
    await scan('acct-a@gmail.com');
    expect(attempts, 1, reason: 'within 1 hour of the failed post');

    clock = clock.add(const Duration(minutes: 2));
    await scan('acct-a@gmail.com');
    expect(attempts, 2, reason: 'more than 1 hour after the failed post');
  });

  // 7.7.1 improvement review M-1. What this does NOT catch: a diagnostic log
  // that is itself unwritable (the logger's own failure path).
  test('a failed retry write is recorded in the diagnostic log, and the line '
      'does not claim a 1-hour retry', () async {
    final logDir = Directory.systemTemp.createTempSync('f301_diag_');
    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(logDir.path);
    addTearDown(() {
      DiagnosticLogger.debugSetEnabled(null);
      DiagnosticLogger.debugSetDir(null);
      logDir.deleteSync(recursive: true);
    });
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        throw StateError('notifications are turned off for this app');
    final store = _RetryWriteBrokenStore(testHelper.dbHelper, clock);
    final posted = await GmailSignInNotifier.notifyIfDue(
        accountId: 'acct-a@gmail.com', settingsStore: store);
    expect(posted, isFalse);
    final log = logDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.readAsStringSync())
        .join('\n');
    expect(log, contains('retry time NOT saved'));
    expect(log, isNot(contains('retry in 60 minutes')));
  });

  test('the notifier on its own: a clock that moved back counts as due',
      () async {
    final store = SettingsStore(testHelper.dbHelper);
    await store.setGmailSignInNotifiedAt(
        'acct-a@gmail.com', clock.add(const Duration(days: 3)));
    final posted = await GmailSignInNotifier.notifyIfDue(
        accountId: 'acct-a@gmail.com', settingsStore: store);
    expect(posted, isTrue);
  });
}
