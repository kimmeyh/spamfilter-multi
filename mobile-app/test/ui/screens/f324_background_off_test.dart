/// F324 (Sprint 83): the account list tells the user when background scanning
/// is off for an account (R-1), and offers "Sign In Again" for an IMAP account
/// whose provider refused the login (R-4).
///
/// These mount the REAL AccountSelectionScreen over fake secure storage and a
/// real test database. Only the platform scheduler is replaced
/// (`BackgroundScanSchedulerFactory.overrideForTest`), so a test never creates
/// a real Windows scheduled task.
///
/// What these do NOT catch: the real Task Scheduler / WorkManager schedule that
/// "Turn on" asks for (covered by the scheduler adapter tests), and the real
/// password check against a mail server (the adapter tests cover the refusal
/// classification and the flag).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart'
    show Credentials;
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';

import '../../helpers/database_test_helper.dart';

const _icloud = 'someone@icloud.com';
const _offText = 'Background scanning is off for this account';
const _checkingText = 'Checking account...';

class _FakeScheduler implements BackgroundScanScheduler {
  final calls = <String>[];

  @override
  bool get isSupported => true;

  @override
  String get mechanismLabel => 'fake';

  @override
  Future<bool> isScheduled(String accountId) async => false;

  @override
  Future<bool> schedule({
    required String accountId,
    required int intervalMinutes,
    required String caller,
  }) async {
    calls.add('$accountId/$intervalMinutes/$caller');
    return true;
  }

  @override
  Future<bool> cancel(String accountId, {required String caller}) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};
  late DatabaseTestHelper testHelper;
  late _FakeScheduler scheduler;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    fake.clear();
    scheduler = _FakeScheduler();
    BackgroundScanSchedulerFactory.overrideForTest(scheduler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
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
    DatabaseHelper().setAppPaths(testHelper.appPaths);
    await testHelper.createTestAccount(_icloud, platformId: 'icloud');
  });

  tearDown(() async {
    BackgroundScanSchedulerFactory.overrideForTest(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  Future<void> seedIcloud(WidgetTester tester) async {
    await tester.runAsync(() => SecureCredentialsStore().saveCredentials(
          _icloud,
          Credentials(email: _icloud, password: 'app-password'),
          platformId: 'icloud',
        ));
  }

  Widget screen() => MaterialApp(
        builder: (context, child) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SelectedAccountProvider()),
            ChangeNotifierProvider(create: (_) => EmailScanProvider()),
            ChangeNotifierProvider(create: (_) => RuleSetProvider()),
          ],
          child: child!,
        ),
        home: const AccountSelectionScreen(),
      );

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Database reads under the fake clock never complete; let them finish on
    // the real event loop (same approach as f239_sign_in_again_test).
    await tester.runAsync(() async {
      await tester.pumpWidget(screen());
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final turnOn = find.byKey(const Key('turn_on_background_$_icloud'));
  final signInAgain = find.byKey(const Key('sign_in_again_$_icloud'));

  group('R-1: background scanning is off', () {
    testWidgets('an account with background off shows the line and Turn on; '
        'Turn on saves the per-account setting, schedules, and hides the line',
        (tester) async {
      await seedIcloud(tester);
      await tester.runAsync(
          () => SettingsStore().setAccountBackgroundEnabled(_icloud, false));
      await mount(tester);

      expect(find.text(_offText), findsOneWidget);
      expect(turnOn, findsOneWidget);
      expect(find.text('Turn on'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(turnOn);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump();
      // The row re-reads its data on real async time; give it two rounds.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 300));
      }

      final saved = await tester
          .runAsync(() => SettingsStore().getAccountBackgroundEnabled(_icloud));
      expect(saved, isTrue, reason: 'the same per-account setting as Settings');
      expect(scheduler.calls, hasLength(1));
      expect(scheduler.calls.single, startsWith('$_icloud/'));
      expect(find.text(_offText), findsNothing);
      expect(turnOn, findsNothing);
    });

    testWidgets('an account with background on shows neither', (tester) async {
      await seedIcloud(tester);
      await tester.runAsync(
          () => SettingsStore().setAccountBackgroundEnabled(_icloud, true));
      await mount(tester);

      expect(find.text(_offText), findsNothing);
      expect(turnOn, findsNothing);
      // Sprint 83 MV: a finished load shows the normal row, no loading line.
      expect(find.text(_checkingText), findsNothing);
      expect(find.textContaining('Missing credentials'), findsNothing);
      expect(find.text(_icloud), findsWidgets);
    });

    testWidgets('an account with no setting of its own follows the app-wide '
        'default, through the shared resolver', (tester) async {
      await seedIcloud(tester);
      // Default is off: the line shows.
      await mount(tester);
      expect(find.text(_offText), findsOneWidget);
    });

    testWidgets('the app-wide setting ON hides the line, and the per-account '
        'OFF still wins over it', (tester) async {
      await seedIcloud(tester);
      await tester.runAsync(() async {
        await SettingsStore().setBackgroundScanEnabled(true);
      });
      await mount(tester);
      expect(find.text(_offText), findsNothing,
          reason: 'no override: the app-wide ON applies');

      await tester.runAsync(
          () => SettingsStore().setAccountBackgroundEnabled(_icloud, false));
      await tester.pumpWidget(const SizedBox());
      await mount(tester);
      expect(find.text(_offText), findsOneWidget,
          reason: 'the per-account OFF wins, as in the worker');
    });
  });

  // Sprint 83 MV (Harold, image 20): every row opened red ("Missing
  // credentials") until its data loaded. What these do NOT catch: how long the
  // real load takes on a device (the neutral row only says it is loading).
  group('loading row', () {
    testWidgets('while an account is still loading, the row is neutral, not '
        'the red "Missing credentials" row', (tester) async {
      await seedIcloud(tester);
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Let the account LIST load (500 ms delay + secure storage), then stop
      // real time: the row's own reads stay pending, as on a slow start.
      await tester.runAsync(() async {
        await tester.pumpWidget(screen());
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump();

      expect(find.byKey(const ValueKey('account_loading_$_icloud')),
          findsOneWidget);
      expect(find.text(_checkingText),
          findsOneWidget);
      expect(find.textContaining('Missing credentials'), findsNothing);

      // The row's reads are still pending by design; unmount and drain them.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await tester.pump(const Duration(seconds: 2));
    });
    // The finished-load half (the loading row goes away) is asserted in
    // 'an account with background on shows neither' above. Not covered: the
    // red row for a finished load with no credentials (the fake store drops
    // the account from the index with its credentials, so it cannot be seeded
    // here); the code path is the unchanged `displayData == null` branch.
  });

  group('R-4: Sign In Again for an IMAP account', () {
    testWidgets('a flagged iCloud account offers Sign In Again and says why',
        (tester) async {
      await seedIcloud(tester);
      await tester.runAsync(
          () => SettingsStore().setGmailSignInRequired(_icloud, true));
      await mount(tester);

      expect(signInAgain, findsOneWidget);
      expect(find.textContaining('rejected the sign-in'), findsOneWidget);
      expect(find.textContaining('Gmail needs you'), findsNothing);
    });

    // Sprint 83 7.7.1 (silent-failure-hunter LOW): an unreadable flag made
    // the row look healthy. Would NOT catch: a flag read that returns a wrong
    // value without throwing.
    testWidgets('a sign-in flag that cannot be read says so and offers Sign '
        'In Again', (tester) async {
      await seedIcloud(tester);
      AccountSelectionScreen.debugReadSignInRequired =
          (_) async => throw StateError('db locked');
      addTearDown(() => AccountSelectionScreen.debugReadSignInRequired = null);
      await mount(tester);
      expect(find.text(AccountSelectionScreen.signInUnknownText),
          findsOneWidget);
      expect(signInAgain, findsOneWidget);
      expect(find.textContaining('rejected the sign-in'), findsNothing);
    });

    testWidgets('an iCloud account that is not flagged (a network error sets '
        'no flag) offers nothing', (tester) async {
      await seedIcloud(tester);
      await mount(tester);
      expect(signInAgain, findsNothing);
      expect(find.textContaining('rejected the sign-in'), findsNothing);
    });

    testWidgets('Sign In Again opens the add-account form for THAT address, '
        'with the address filled in', (tester) async {
      await seedIcloud(tester);
      await tester.runAsync(
          () => SettingsStore().setGmailSignInRequired(_icloud, true));
      await mount(tester);

      await tester.tap(signInAgain);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AccountSetupScreen), findsOneWidget);
      final setup =
          tester.widget<AccountSetupScreen>(find.byType(AccountSetupScreen));
      expect(setup.signInAgainFor, _icloud);
      expect(setup.platformId, 'icloud');
      expect(find.widgetWithText(TextField, _icloud), findsOneWidget);
    });
  });
}
