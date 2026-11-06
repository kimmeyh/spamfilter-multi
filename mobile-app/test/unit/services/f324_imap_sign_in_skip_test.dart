/// F324 R-4 (Sprint 83): a background scan of an IMAP account (iCloud here)
/// whose provider REFUSED the login is a SKIP with the user told once a day,
/// exactly like the Gmail sign-in skip (f239_background_sign_in_skip_test) --
/// and a network error is still a failure, with no notification.
///
/// Before: the refused login surfaced as an `AuthenticationException` the core
/// did not catch, so each run counted a failed scan (17 on the Fold, iCloud,
/// 2026-10-29 to 2026-11-01) and nothing told the user.
///
/// The REAL BackgroundScanCore.scanAccount and EmailScanner run; the platform
/// registered as 'icloud' is replaced by one that fails at `loadCredentials`
/// the way GenericIMAPAdapter does. Secure storage is the fake channel.
///
/// What these do NOT catch: the adapter's own decision to throw (covered by
/// f324_imap_sign_in_flag_test over a real socket), the Windows and Android
/// workers' use of the outcome (shared with the Gmail skip, covered by their
/// own tests), and the scan row the claim creates before the failure (closed as
/// `error`, as for the Gmail skip).
library;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/scan_complete_notifier.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

const _acct = 'someone@icloud.com';

class _RefusedLoginPlatform extends MockEmailProvider {
  @override
  Future<void> loadCredentials(Credentials credentials) =>
      throw AuthenticationException('IMAP login rejected: AUTHENTICATIONFAILED');
}

class _NetworkDownPlatform extends MockEmailProvider {
  @override
  Future<void> loadCredentials(Credentials credentials) =>
      throw ConnectionException('Network connection failed: Failed host lookup');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};
  late DatabaseTestHelper testHelper;
  late List<String> titles;
  final waits = <Duration>[];

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    fake.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return fake[key];
        case 'write':
          fake[key!] = call.arguments['value'] as String;
          return null;
        case 'delete':
          fake.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(fake);
      }
      return null;
    });
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(_acct, platformId: 'icloud');
    await SecureCredentialsStore().saveCredentials(
      _acct,
      Credentials(email: _acct, password: 'pw'),
      platformId: 'icloud',
    );
    waits.clear();
    BackgroundScanCore.busyWait = (d) async => waits.add(d);
    titles = [];
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        titles.add(title);
  });

  tearDown(() async {
    BackgroundScanCore.busyWait = (d) => Future<void>.delayed(d);
    ScanCompleteNotifier.showOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await testHelper.tearDown();
  });

  void usePlatform(MockEmailProvider Function() factory) {
    final previous = PlatformRegistry.overrideFactoryForTest('icloud', factory);
    addTearDown(
        () => PlatformRegistry.overrideFactoryForTest('icloud', previous));
  }

  Future<AccountScanOutcome> scan() => BackgroundScanCore.scanAccount(
        accountId: _acct,
        platformId: 'icloud',
        ruleSetProvider: RuleSetProvider(),
        settingsStore: SettingsStore(testHelper.dbHelper),
        scanResultStore: ScanResultStore(testHelper.dbHelper),
      );

  test('a refused iCloud login: a skip needing sign-in, no busy wait, and the '
      'user is told with the provider named', () async {
    usePlatform(_RefusedLoginPlatform.new);
    final outcome = await scan();

    expect(outcome.skipped, isTrue);
    expect(outcome.needsSignIn, isTrue);
    expect(outcome.skippedReason, BackgroundScanCore.imapSignInRequiredReason);
    expect(waits, isEmpty, reason: 'waiting cannot fix a refused password');
    expect(titles, hasLength(1));
    expect(titles.single, startsWith('iCloud sign-in needed for '));
  });

  test('a second refused run the same day does not notify again', () async {
    usePlatform(_RefusedLoginPlatform.new);
    await scan();
    await scan();
    expect(titles, hasLength(1));
  });

  test('a network error is still a failure, and posts no sign-in notice',
      () async {
    usePlatform(_NetworkDownPlatform.new);
    await expectLater(scan(), throwsA(isA<ConnectionException>()));
    expect(titles, isEmpty);
  });

  // Sprint 83 7.7.1 (Harold Q2 = 1): a flagged IMAP account gets no login.
  // Would NOT catch: a pop-up read of a flagged account (f323_popup_body_
  // fetcher_test covers that), or a flag the adapter never set (covered by
  // f324_imap_sign_in_flag_test).
  test('a flagged account is skipped BEFORE login, and the user is still '
      'told once a day', () async {
    var logins = 0;
    usePlatform(() => _CountingPlatform(() => logins++));
    await SettingsStore(testHelper.dbHelper).setGmailSignInRequired(_acct, true);

    final outcome = await scan();

    expect(logins, 0, reason: 'no refused login sent again to the provider');
    expect(outcome.skipped, isTrue);
    expect(outcome.needsSignIn, isTrue);
    expect(outcome.skippedReason, BackgroundScanCore.imapSignInRequiredReason);
    expect(titles, hasLength(1));
  });

  test('an account that is not flagged still logs in', () async {
    var logins = 0;
    usePlatform(() => _CountingPlatform(() => logins++));
    await scan();
    expect(logins, 1);
  });
}

class _CountingPlatform extends MockEmailProvider {
  _CountingPlatform(this.onLogin);
  final void Function() onLogin;
  @override
  Future<void> loadCredentials(Credentials credentials) async {
    onLogin();
    throw AuthenticationException('IMAP login rejected: AUTHENTICATIONFAILED');
  }
}
