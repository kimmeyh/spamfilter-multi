/// F192 (Sprint 77): the secure store persists Custom IMAP server settings as
/// side keys, returns them in `Credentials.additionalParams`, and deletes them.
///
/// This is what lets every reconnect path (manual scan, both background
/// workers, folder picker, connection test) reach the right server with no
/// call-site edit: they all load credentials from the store.
///
/// The FlutterSecureStorage method channel is replaced with an in-memory map,
/// so the test can also assert on the RAW stored keys.
///
/// What this does NOT catch: the real Android Keystore or Windows credential
/// store (only a device proves those), and the WorkManager isolate's access to
/// them.
library;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};

  setUp(() {
    fake.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return fake[args['key']];
        case 'write':
          fake[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          fake.remove(args['key']);
          return null;
        case 'containsKey':
          return fake.containsKey(args['key']);
        case 'readAll':
          return Map<String, String>.from(fake);
        case 'deleteAll':
          fake.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  SecureCredentialsStore makeStore() =>
      SecureCredentialsStore(storage: const FlutterSecureStorage());

  const account = 'me@example.test';
  const settings = CustomImapSettings(
    host: 'imap.example.test',
    port: 143,
    encryption: ImapEncryption.startTls,
    username: 'me-login',
  );

  Credentials custom() => Credentials(
        email: account,
        password: 'pw',
        additionalParams: settings.toParams(),
      );

  test('save then get returns the four settings in additionalParams', () async {
    final store = makeStore();
    await store.saveCredentials(account, custom(), platformId: 'imap');

    final loaded = (await store.getCredentials(account))!;
    final back = CustomImapSettings.tryFromParams(loaded.additionalParams)!;
    expect(back.host, 'imap.example.test');
    expect(back.port, 143);
    expect(back.encryption, ImapEncryption.startTls);
    expect(back.username, 'me-login');
    // The existing params are still there beside them.
    expect(loaded.additionalParams!['accountId'], account);
    expect(loaded.additionalParams!['platformId'], 'imap');
  });

  test('each setting is its own side key beside the credentials', () async {
    await makeStore().saveCredentials(account, custom(), platformId: 'imap');
    for (final key in CustomImapSettings.paramKeys) {
      expect(fake.containsKey('credentials_${account}_$key'), isTrue,
          reason: key);
    }
  });

  test('delete removes every settings key', () async {
    final store = makeStore();
    await store.saveCredentials(account, custom(), platformId: 'imap');
    await store.deleteCredentials(account);

    for (final key in CustomImapSettings.paramKeys) {
      expect(fake.containsKey('credentials_${account}_$key'), isFalse,
          reason: '$key must not survive account deletion');
    }
    expect(fake.keys.where((k) => k.startsWith('credentials_$account')), isEmpty);
  });

  test('saving the same address WITHOUT settings clears stale ones', () async {
    final store = makeStore();
    await store.saveCredentials(account, custom(), platformId: 'imap');
    await store.saveCredentials(
        account, Credentials(email: account, password: 'pw2'),
        platformId: 'yahoo');

    final loaded = (await store.getCredentials(account))!;
    expect(CustomImapSettings.tryFromParams(loaded.additionalParams), isNull);
    for (final key in CustomImapSettings.paramKeys) {
      expect(loaded.additionalParams!.containsKey(key), isFalse, reason: key);
    }
  });

  test('a non-settings additionalParams entry is not persisted', () async {
    final store = makeStore();
    await store.saveCredentials(
        account,
        Credentials(
            email: account,
            password: 'pw',
            additionalParams: {'somethingElse': 'x', ...settings.toParams()}),
        platformId: 'imap');
    expect(fake.keys.any((k) => k.contains('somethingElse')), isFalse);
  });
}
