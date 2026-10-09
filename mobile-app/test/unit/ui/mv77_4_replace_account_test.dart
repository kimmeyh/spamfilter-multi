/// Sprint 77 MV-Q4 = 1 (Harold): adding an email address that is already
/// saved asks "Replace?" instead of silently overwriting that account.
///
/// Sprint 77 final review (finding 5) closed two gaps: the Google sign-in add
/// paths never asked, and a storage READ error skipped the question (the
/// existence check failed open). The question now lives in ONE helper
/// (`confirm_replace_account.dart`) that every add flow calls, and an
/// unreadable store asks.
///
/// What this does NOT catch: the dialog's buttons (no widget harness exists
/// for these screens; each builds its credential store inside its State and
/// the Google sign-in calls the network), so the screen wiring is pinned by
/// SOURCE gates on call order, not by driving the screens. Manual Validation
/// step: add a saved address through the password form AND through Google
/// Sign-In and see the question both times.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';
import 'package:my_email_spam_filter/ui/utils/confirm_replace_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the question names the saved provider and what is kept', () {
    expect(
        replaceAccountMessage('AOL'),
        'This email address is already added (AOL). Replace its saved '
        'sign-in details with the ones you entered? Its scan history, rules '
        'and settings are kept.');
    expect(replaceAccountMessage(null), startsWith('This email address is already added. '));
  });

  test('provider names come from the provider list', () {
    for (final info in PlatformRegistry.getSupportedPlatforms()) {
      expect(providerNameFor(info.id), info.displayName);
    }
    expect(providerNameFor('gmail-imap'), 'Gmail, App Password');
    expect(providerNameFor(null), isNull);
    expect(providerNameFor('no-such'), isNull);
  });

  test('source gate: the save path asks BEFORE it saves credentials', () {
    final src = File('lib/ui/screens/account_setup_screen.dart').readAsStringSync();
    final connect = src.indexOf('Future<void> _handleConnect()');
    expect(connect, greaterThan(0));
    final ask = src.indexOf('await _confirmReplaceExisting(email)', connect);
    final save = src.indexOf('_credStore.saveCredentials(', connect);
    expect(ask, greaterThan(connect), reason: 'the question is on the save path');
    expect(save, greaterThan(ask), reason: 'asked before anything is saved');
    // And a "no" stops the save.
    final guard = src.substring(ask - 10, ask + 120);
    expect(guard, contains('if (!await _confirmReplaceExisting(email))'));
    expect(src.substring(ask, save), contains('return;'));
    // The setup screen uses the shared helper, not a private copy.
    expect(src, contains('confirmReplaceExistingAccount(context, _credStore'));
  });

  group('the decision fails closed', () {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final fake = <String, String>{};
    var failReads = false;

    setUp(() {
      fake.clear();
      failReads = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = (call.arguments as Map?) ?? const {};
        switch (call.method) {
          case 'read':
            if (failReads) throw PlatformException(code: 'read-failed');
            return fake[args['key']];
          case 'write':
            fake[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
            fake.remove(args['key']);
            return null;
          case 'readAll':
            return Map<String, String>.from(fake);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<({bool go, List<String> asked})> decide(
        {required bool answer}) async {
      final asked = <String>[];
      final go = await shouldReplaceAccount(
        store: SecureCredentialsStore(storage: const FlutterSecureStorage()),
        accountId: 'a@example.com',
        ask: (m) async {
          asked.add(m);
          return answer;
        },
      );
      return (go: go, asked: asked);
    }

    test('an address that is not saved goes ahead without a question', () async {
      final r = await decide(answer: false);
      expect(r.go, isTrue);
      expect(r.asked, isEmpty);
    });

    test('a saved address asks, and Cancel stops the add', () async {
      fake['credentials_a@example.com_email'] = 'a@example.com';
      fake['credentials_a@example.com_platformId'] = 'aol';
      final r = await decide(answer: false);
      expect(r.asked, hasLength(1));
      expect(r.asked.single, contains('already added'));
      expect(r.go, isFalse);
      expect((await decide(answer: true)).go, isTrue);
    });

    test('an address saved only by Google Sign-In (tokens) asks', () async {
      fake['token_a@example.com_gmail_tokens'] = '{}';
      final r = await decide(answer: false);
      expect(r.asked, hasLength(1));
      expect(r.go, isFalse);
    });

    test('a storage READ error asks instead of silently replacing', () async {
      failReads = true;
      final r = await decide(answer: false);
      expect(r.asked, hasLength(1), reason: 'unknown must ask, not skip');
      expect(r.asked.single, replaceAccountUnknownMessage());
      expect(r.go, isFalse);
      expect(
          await SecureCredentialsStore(storage: const FlutterSecureStorage())
              .accountPresence('a@example.com'),
          AccountPresence.unknown);
    });
  });

  group('every add flow goes through the shared question', () {
    String read(String p) => File(p).readAsStringSync();

    test('Google Sign-In passes the question, asks before tokens are saved',
        () {
      final src = read('lib/adapters/auth/google_auth_service.dart');
      // Both the native and the desktop/browser paths.
      var from = 0;
      var found = 0;
      while (true) {
        final ask = src.indexOf('!await confirmAdd(accountId)', from);
        if (ask < 0) break;
        final save = src.indexOf('saveGmailTokens(accountId, tokens)', ask);
        expect(save, greaterThan(ask), reason: 'asked before tokens are saved');
        // Only an add asks; a renewal (expectedAccountId set) never does.
        expect(src.substring(ask - 80, ask), contains('expectedAccountId == null'));
        found++;
        from = ask + 1;
      }
      expect(found, 2, reason: 'native and desktop sign-in both ask');

      final screen = read('lib/ui/screens/gmail_oauth_screen.dart');
      expect('signIn(confirmAdd: _confirmAdd)'.allMatches(screen).length, 2,
          reason: 'both screen sign-in handlers pass the question');
      expect(screen, contains('confirmReplaceExistingAccount('));
      // The renewal callers do not pass it.
      expect(read('lib/ui/widgets/sign_in_again.dart'),
          isNot(contains('confirmAdd')));
    });

    test('WebView and manual-token screens ask before saving tokens', () {
      for (final p in [
        'lib/ui/screens/gmail_webview_oauth_screen.dart',
        'lib/ui/screens/gmail_manual_token_screen.dart',
      ]) {
        final src = read(p);
        final ask = src.indexOf('confirmReplaceExistingAccount(');
        final save = src.indexOf('_tokenStore.saveTokens(');
        expect(ask, greaterThan(0), reason: '$p asks');
        expect(save, greaterThan(ask), reason: '$p asks before it saves');
        expect(src.substring(ask, save), contains('return;'));
      }
    });

    test('no add-account screen calls saveCredentials without asking', () {
      // Every UI file that saves credentials must also call the shared
      // question; a new add screen that forgets it fails here.
      final offenders = <String>[];
      for (final f in Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        if (src.contains('.saveCredentials(') &&
            !src.contains('confirmReplaceExistingAccount(') &&
            !src.contains('_confirmReplaceExisting(')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
