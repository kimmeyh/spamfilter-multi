/// F324 (Sprint 83): the add-account form, opened from "Sign In Again" for an
/// IMAP account (R-4), and the re-add refresh (R-2, Q3 = 3).
///
/// Mounts the REAL AccountSetupScreen over fake secure storage and a real test
/// database. Save runs the real DataDeletionService.refreshForReAdd.
///
/// What these do NOT catch: the Manual Scan screen the form opens after Save
/// (a different feature; the tree is replaced afterwards), the real password
/// check (Save stores credentials; the next scan checks them), and the Gmail
/// OAuth finish, which shares `_finishAccountAdded` but has no test here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';

import '../../helpers/database_test_helper.dart';

const _acct = 'person@aol.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final stored = <String, String>{};
  late DatabaseTestHelper db;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    stored.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return stored[args['key']];
        case 'write':
          stored[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          stored.remove(args['key']);
          return null;
        case 'readAll':
          return Map<String, String>.from(stored);
      }
      return null;
    });
    db = DatabaseTestHelper();
    await db.setUp();
    DatabaseHelper().setAppPaths(db.appPaths);
    await db.createTestAccount(_acct, platformId: 'aol');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.tearDown();
  });

  /// The account exists (saved credentials), is flagged "Sign In Again", and
  /// has a scan position and a user choice.
  Future<void> seedFlaggedAccount(WidgetTester tester) async {
    await tester.runAsync(() async {
      await SecureCredentialsStore().saveCredentials(
        _acct,
        Credentials(email: _acct, password: 'old-password'),
        platformId: 'aol',
      );
      await SettingsStore().setGmailSignInRequired(_acct, true);
      await SettingsStore().setAccountBackgroundFrequency(_acct, 45);
      await DatabaseHelper().setGmailHistoryCursor(_acct, 'INBOX', '77');
    });
  }

  Future<void> open(WidgetTester tester, {String? signInAgainFor}) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmailScanProvider()),
        ChangeNotifierProvider(create: (_) => RuleSetProvider()),
      ],
      child: MaterialApp(
        home: AccountSetupScreen(
          platformId: 'aol',
          platformDisplayName: 'AOL Mail',
          signInAgainFor: signInAgainFor,
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> enterPasswordAndSave(WidgetTester tester) async {
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'a-long-enough-password');
    await tester.pump();
    await tester.tap(find.text('Save Credentials & Continue'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> endTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
  }

  testWidgets('Sign In Again: the address is filled in, no "Account already '
      'added" question, and saving clears the flag but keeps the scan position '
      'and the user\'s choice', (tester) async {
    await seedFlaggedAccount(tester);
    await open(tester, signInAgainFor: _acct);

    expect(find.widgetWithText(TextField, _acct), findsOneWidget);
    await enterPasswordAndSave(tester);

    expect(find.text('Account already added'), findsNothing);
    final flagged = await tester
        .runAsync(() => SettingsStore().getGmailSignInRequired(_acct));
    expect(flagged, isFalse);
    final cursor = await tester.runAsync(
        () => DatabaseHelper().getGmailHistoryCursor(_acct, 'INBOX'));
    expect(cursor, '77', reason: 'a password repair keeps the scan position');
    final freq = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(_acct));
    expect(freq, 45);
    expect(stored.values, contains('a-long-enough-password'));
    await endTest(tester);
  });

  // 7.7.1 code-reviewer L-3. What this does NOT catch: a Gmail account (its
  // Sign In Again runs a different flow, SignInAgain.run).
  testWidgets('Sign In Again for one account, address edited to ANOTHER '
      'existing account: Replace resets that account\'s scan position',
      (tester) async {
    await seedFlaggedAccount(tester);
    await open(tester, signInAgainFor: 'someone-else@aol.com');

    await tester.enterText(
        find.widgetWithText(TextField, 'someone-else@aol.com'), _acct);
    await enterPasswordAndSave(tester);
    expect(find.text('Account already added'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 100));

    final cursor = await tester.runAsync(
        () => DatabaseHelper().getGmailHistoryCursor(_acct, 'INBOX'));
    expect(cursor, isNull,
        reason: 'a different account replaced through Sign In Again starts '
            'clean');
    await endTest(tester);
  });

  testWidgets('adding the same address again (not Sign In Again) asks first, '
      'then clears the old flag AND the scan position, keeping the choice',
      (tester) async {
    await seedFlaggedAccount(tester);
    await open(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'), _acct);
    await enterPasswordAndSave(tester);
    expect(find.text('Account already added'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 100));

    final flagged = await tester
        .runAsync(() => SettingsStore().getGmailSignInRequired(_acct));
    expect(flagged, isFalse);
    final cursor = await tester.runAsync(
        () => DatabaseHelper().getGmailHistoryCursor(_acct, 'INBOX'));
    expect(cursor, isNull, reason: 'a replaced sign-in starts clean');
    final freq = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(_acct));
    expect(freq, 45, reason: 'the user\'s choice is kept');
    await endTest(tester);
  });
}
