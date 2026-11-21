/// Select Account rows at PHONE width (Sprint 85 MV rehearsal finding).
///
/// Before: on the pixel34 emulator (412 dp wide) a Gmail row that needed sign-in
/// put "Sign In Again" in the row's `trailing` Row next to the F352 star, play
/// and delete icons. The trailing area took nearly the whole width, the title
/// got about 0 dp, and the address wrapped one letter per line down the whole
/// screen. Every earlier test of this row mounted it 1400 dp wide
/// (f239_sign_in_again_test.dart), so none could see it.
///
/// After: the trailing area holds icons only; "Sign In Again" sits under its
/// reason in the subtitle. These tests mount the REAL AccountSelectionScreen
/// at 360 and 412 dp, in each row state that adds a control, with the default
/// star set, and assert the title keeps a usable width and the card stays
/// compact.
///
/// What these do NOT catch: a large system font scale (the tests use 1.0), the
/// "Missing credentials" error row (a separate ListTile with one icon), and
/// Windows, where the window is wide.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';

import '../../helpers/database_test_helper.dart';

const _gmail = 'someone.example@gmail.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};
  late DatabaseTestHelper testHelper;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    fake.clear();
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
    await testHelper.createTestAccount(_gmail, platformId: 'gmail');
    fake['saved_accounts'] = _gmail;
    fake['credentials_${_gmail}_platformId'] = 'gmail';
    fake['token_${_gmail}_gmail_tokens'] = jsonEncode({
      'accessToken': 'expired-token',
      'refreshToken': null,
      'expiresAt':
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'grantedScopes': ['https://www.googleapis.com/auth/gmail.modify'],
      'email': _gmail,
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

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

  Future<void> mount(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  for (final width in [360.0, 412.0]) {
    for (final needsSignIn in [true, false]) {
      final state = needsSignIn ? 'Sign In Again' : 'healthy';
      testWidgets('$state row with the default star at ${width.toInt()} dp '
          'keeps the title readable', (tester) async {
        await tester.runAsync(() async {
          await SettingsStore().setDefaultAccountId(_gmail);
          if (needsSignIn) {
            await SettingsStore().setGmailSignInRequired(_gmail, true);
          }
        });
        await mount(tester, width);

        expect(find.byKey(const Key('default_toggle_$_gmail')), findsOneWidget);
        expect(find.byKey(const Key('sign_in_again_$_gmail')),
            needsSignIn ? findsOneWidget : findsNothing);

        final title = find.textContaining('$_gmail - Gmail');
        expect(title, findsOneWidget);
        expect(tester.getSize(title).width, greaterThanOrEqualTo(100),
            reason: 'the title had about 0 dp when a text button shared the '
                'trailing area with the three icons');

        final card = find
            .ancestor(of: title, matching: find.byType(Card))
            .first;
        // The subtitle's first Text starts with the account id.
        final subtitle = find.descendant(
            of: card,
            matching: find.byWidgetPredicate((w) =>
                w is Text && (w.data ?? '').startsWith(_gmail) &&
                !(w.data ?? '').contains(' - Gmail')));
        expect(subtitle, findsOneWidget);
        expect(tester.getSize(subtitle).width, greaterThanOrEqualTo(200),
            reason: 'a squeezed subtitle wraps the address one letter per '
                'line');
        // Measured after the fix: 348-365 dp with every line present (address,
        // reason, Sign In Again, background off, icons); before it, over the
        // screen height.
        expect(tester.getSize(card).height, lessThan(480));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }
}
