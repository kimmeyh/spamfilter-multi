/// Sprint 75 Manual Validation (Harold, 2026-10-03): adding a Gmail account.
///
/// Q2 -- the Gmail Setup box opened with "Before connecting, you'll need to
/// generate an app password", and two lines lower said "No app password
/// needed". One dialog serves every provider; Gmail now gets its own sentence.
///
/// Q3 -- after Google sign-in, Gmail opened a folder screen that saves on
/// every tick (Sprint 19 F27) and is left with the back arrow, which returns
/// no list; the sign-in screen waited for one and stayed on its own page.
/// Harold: finish "the same that is done after adding AOL and Yahoo accounts"
/// -- saved message, then the Manual Scan screen (its back arrow pops to the
/// route below).
///
/// What these do NOT catch: the live Google sign-in and the navigation it
/// drives (there is no seam for a fake Google sign-in; the source gates below
/// pin the wiring, and Manual Validation on the emulator runs the real flow).
/// Only `gmail_oauth_screen.dart` is gated: the WebView and manual-token
/// fallback screens (`gmail_webview_oauth_screen.dart`,
/// `gmail_manual_token_screen.dart`) still go to the folder step and are not
/// covered (PR #448 review; behavior test tracked as F247).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/platform_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSetupFor(WidgetTester tester, String provider) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmailScanProvider()),
        ChangeNotifierProvider(create: (_) => RuleSetProvider()),
      ],
      child: const MaterialApp(home: PlatformSelectionScreen()),
    ));
    await tester.pump();
    await tester.tap(find.text(provider).first);
    await tester.pumpAndSettle();
  }

  group('Q2: the setup box tells the truth per provider', () {
    testWidgets('Gmail: no app-password sentence', (tester) async {
      await openSetupFor(tester, 'Gmail');
      expect(find.text('Gmail Setup'), findsOneWidget);
      expect(find.textContaining('generate an app password'), findsNothing,
          reason: 'Gmail signs in with Google -- no app password');
      expect(find.text('Here is what happens when you connect:'),
          findsOneWidget);
    });

    testWidgets('AOL keeps the app-password sentence', (tester) async {
      await openSetupFor(tester, 'AOL Mail');
      expect(find.textContaining('generate an app password'), findsOneWidget);
    });
  });

  group('Q3: a Gmail account finishes like AOL and Yahoo (source gates)', () {
    final oauth =
        File('lib/ui/screens/gmail_oauth_screen.dart').readAsStringSync();
    final setup =
        File('lib/ui/screens/account_setup_screen.dart').readAsStringSync();

    test('the sign-in screen no longer opens the folder step', () {
      expect(oauth.contains('FolderSelectionScreen('), isFalse);
    });

    test('both sign-in success paths hand the address back', () {
      expect(oauth.contains('Navigator.pop(context, email);'), isTrue,
          reason: 'browser sign-in path');
      expect(oauth.contains('Navigator.pop(context, accountId);'), isTrue,
          reason: 'native sign-in path');
    });

    test('Gmail and the IMAP providers share ONE finish', () {
      expect('_finishAccountAdded('.allMatches(setup).length, 3,
          reason: 'the definition, the IMAP save path, and the Gmail path');
      final gmailStart = setup.indexOf('Future<void> _startGmailOAuth()');
      final gmailBody = setup.substring(gmailStart, gmailStart + 900);
      expect(gmailBody.contains('Navigator.push<String>('), isTrue);
      // The success branch must START with the shared finish -- presence
      // alone let a mutation that pops first and returns survive (M115).
      expect(
          RegExp(r'if \(email != null && mounted\) \{\s*await _finishAccountAdded\(')
              .hasMatch(gmailBody),
          isTrue);
    });
  });
}
