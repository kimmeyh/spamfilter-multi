/// F239 (Sprint 75): "Sign In Again" for a Gmail account whose sign-in could
/// not be renewed without the user.
///
/// Before: a Gmail account whose renewal failed showed nothing (or, with its
/// tokens gone, "Error: Missing credentials -- Tap delete to remove"), and the
/// only repair was to delete the account and add it again. After: the row
/// says "Gmail needs you to sign in again" and offers "Sign In Again", which
/// re-runs sign-in for THAT account and keeps it.
///
/// These tests mount the REAL AccountSelectionScreen over fake secure storage
/// and a real test database, and replace only the interactive Google sign-in
/// (`AccountSelectionScreen.debugSignInAgain`).
///
/// What these do NOT catch: the real Google sign-in (browser on Windows,
/// account picker on Android) and the wrong-account refusal inside
/// GoogleAuthService -- that is covered by gmail_sign_in_expected_account_test.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/auth/google_auth_service.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';

import '../../helpers/database_test_helper.dart';

const _gmail = 'someone@gmail.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};
  late DatabaseTestHelper testHelper;
  final signInCalls = <String>[];

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    fake.clear();
    signInCalls.clear();
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
    // account_settings has a foreign key to accounts; in the app the row
    // exists before the flag is ever written (a scan creates it first).
    await testHelper.createTestAccount(_gmail, platformId: 'gmail');
  });

  tearDown(() async {
    AccountSelectionScreen.debugSignInAgain = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  void seedGmail({required bool withTokens}) {
    fake['saved_accounts'] = _gmail;
    fake['credentials_${_gmail}_platformId'] = 'gmail';
    if (withTokens) {
      fake['token_${_gmail}_gmail_tokens'] = jsonEncode({
        'accessToken': 'expired-token',
        'refreshToken': null,
        'expiresAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'grantedScopes': ['https://www.googleapis.com/auth/gmail.modify'],
        'email': _gmail,
      });
    }
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
    // The row's FutureBuilder reads the database (the F239 flag) after the
    // screen's 500ms load delay; let it finish on the REAL event loop and
    // rebuild there -- under the fake clock a pending sqflite read never
    // completes (database_test_helper / db_widget_test_harness notes).
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

  /// Let the snackbar's own timers finish so no timer outlives the test.
  Future<void> drain(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 6));

  final signInButton = find.byKey(const Key('sign_in_again_$_gmail'));

  testWidgets('a flagged Gmail account offers Sign In Again, and a successful '
      'sign-in clears the flag and keeps the account', (tester) async {
    seedGmail(withTokens: true);
    await tester.runAsync(
        () => SettingsStore().setGmailSignInRequired(_gmail, true));
    AccountSelectionScreen.debugSignInAgain = (id) async {
      signInCalls.add(id);
      return AuthResult.success(id, 'new-token');
    };
    await mount(tester);

    expect(find.textContaining('Gmail needs you to sign in again'),
        findsOneWidget);
    expect(signInButton, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(signInButton);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(signInCalls, [_gmail], reason: 'sign in for THIS account');
    final stillFlagged = await tester
        .runAsync(() => SettingsStore().getGmailSignInRequired(_gmail));
    expect(stillFlagged, isFalse);
    expect(fake['saved_accounts'], _gmail,
        reason: 'the account is repaired, never deleted');
    expect(find.textContaining('Signed in again as $_gmail'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a Gmail account with NO tokens left offers Sign In Again '
      'instead of the "Missing credentials" dead end', (tester) async {
    seedGmail(withTokens: false);
    await mount(tester);
    expect(signInButton, findsOneWidget);
    expect(find.textContaining('Missing credentials'), findsNothing);
    await drain(tester);
  });

  testWidgets('a healthy Gmail account shows no Sign In Again', (tester) async {
    seedGmail(withTokens: true);
    await mount(tester);
    expect(signInButton, findsNothing);
    await drain(tester);
  });

  testWidgets('a failed sign-in says why and keeps the flag', (tester) async {
    seedGmail(withTokens: true);
    await tester.runAsync(
        () => SettingsStore().setGmailSignInRequired(_gmail, true));
    AccountSelectionScreen.debugSignInAgain = (id) async =>
        AuthResult.failure('You signed in as other@gmail.com. To fix $id, '
            'sign in with $id.');
    await mount(tester);
    await tester.runAsync(() async {
      await tester.tap(signInButton);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('You signed in as other@gmail.com'),
        findsOneWidget);
    final stillFlagged = await tester
        .runAsync(() => SettingsStore().getGmailSignInRequired(_gmail));
    expect(stillFlagged, isTrue);
    await drain(tester);
  });
}
