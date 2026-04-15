import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/security/database_encryption_key_service.dart';

/// Unit tests for [DatabaseEncryptionKeyService] (SEC-11, Sprint 33).
///
/// We replace the FlutterSecureStorage MethodChannel with an in-memory
/// stub so tests do not touch the real OS credential store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final Map<String, String> fakeStorage = <String, String>{};

  setUp(() {
    fakeStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return fakeStorage[key];
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          fakeStorage[key] = value;
          return null;
        case 'delete':
          final key = call.arguments['key'] as String;
          fakeStorage.remove(key);
          return null;
        case 'containsKey':
          final key = call.arguments['key'] as String;
          return fakeStorage.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(fakeStorage);
        case 'deleteAll':
          fakeStorage.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  DatabaseEncryptionKeyService makeService() =>
      DatabaseEncryptionKeyService(storage: const FlutterSecureStorage());

  group('getOrCreateKey', () {
    test('generates a new 256-bit base64 key on first call', () async {
      final service = makeService();
      final key = await service.getOrCreateKey();
      expect(key, isNotEmpty);
      final bytes = base64.decode(key);
      expect(bytes.length, DatabaseEncryptionKeyService.keyLengthBytes);
    });

    test('returns the same key on subsequent calls', () async {
      final service = makeService();
      final first = await service.getOrCreateKey();
      final second = await service.getOrCreateKey();
      expect(second, first);
    });

    test('persists across service re-instantiation', () async {
      final first = await makeService().getOrCreateKey();
      final second = await makeService().getOrCreateKey();
      expect(second, first);
    });
  });

  group('hasKey', () {
    test('returns false before any key is generated', () async {
      final service = makeService();
      expect(await service.hasKey(), isFalse);
    });

    test('returns true after getOrCreateKey', () async {
      final service = makeService();
      await service.getOrCreateKey();
      expect(await service.hasKey(), isTrue);
    });
  });

  group('deleteKey', () {
    test('removes the stored key', () async {
      final service = makeService();
      await service.getOrCreateKey();
      expect(await service.hasKey(), isTrue);

      await service.deleteKey();
      expect(await service.hasKey(), isFalse);
    });

    test('is a no-op when no key is stored', () async {
      final service = makeService();
      await expectLater(service.deleteKey(), completes);
    });
  });
}
