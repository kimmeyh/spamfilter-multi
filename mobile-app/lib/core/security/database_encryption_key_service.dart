/// SEC-11 (Sprint 33): encryption key management for SQLite at rest.
///
/// ## Design summary
///
/// [DatabaseEncryptionKeyService] owns the per-device encryption key used
/// by SQLCipher when the `encrypt_database` feature flag is on. The key:
/// - Is generated on first launch (256 bits from [Random.secure]).
/// - Is stored in `flutter_secure_storage` (Windows Credential Manager on
///   Windows, EncryptedSharedPreferences on Android, Keychain on iOS/macOS).
/// - Is base64-encoded so SQLCipher's `PRAGMA key` accepts it as a string.
/// - Is never logged, never written to disk outside `flutter_secure_storage`.
///
/// ## Why not derive from a password?
///
/// This app does not require a user-supplied passphrase. The threat model
/// is "someone with file-system access to the app data directory reads the
/// DB" -- binding the key to the OS secure storage protects against that
/// without forcing a passphrase on every launch.
///
/// ## Feature flag
///
/// Encryption is opt-in via the `encrypt_database` app setting, which
/// defaults to `false` for this release. The infrastructure (key service +
/// migration) is shipped so it can be enabled after dedicated QA on real
/// installs without a code change. See [DatabaseEncryptionKeyService.isEnabled].
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Manages the per-device SQLCipher key.
class DatabaseEncryptionKeyService {
  static const String _secureStorageKey = 'db_encryption_key_v1';

  /// Number of bytes in the key (256 bits).
  static const int keyLengthBytes = 32;

  final FlutterSecureStorage _storage;
  final Logger _logger = Logger();

  DatabaseEncryptionKeyService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Fetch the existing key, or generate-and-store a new one if this is
  /// the first launch. Returned string is base64 and ready to hand to
  /// SQLCipher's `PRAGMA key = '...'`.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _secureStorageKey);
    if (existing != null && existing.isNotEmpty) {
      _logger.d('Loaded existing database encryption key');
      return existing;
    }

    final key = _generateKey();
    await _storage.write(key: _secureStorageKey, value: key);
    _logger.i('Generated and stored new database encryption key');
    return key;
  }

  /// Return true if a key already exists (the DB has been encrypted at
  /// least once on this device).
  Future<bool> hasKey() async {
    final existing = await _storage.read(key: _secureStorageKey);
    return existing != null && existing.isNotEmpty;
  }

  /// Delete the stored key. Only call during full-reset flows (F66) or
  /// recovery paths where the encrypted DB is also being removed.
  ///
  /// WARNING: destroying the key without also destroying the encrypted
  /// DB renders the DB permanently unreadable.
  Future<void> deleteKey() async {
    await _storage.delete(key: _secureStorageKey);
    _logger.w('Deleted database encryption key (DB is now unreadable)');
  }

  String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(keyLengthBytes, (_) => rng.nextInt(256));
    return base64.encode(bytes);
  }
}
