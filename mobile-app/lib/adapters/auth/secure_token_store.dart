/// Secure token storage implementation using flutter_secure_storage.
///
/// ## Storage Backend
/// - **iOS**: Keychain Services (hardware-backed encryption)
/// - **Android**: EncryptedSharedPreferences + Android Keystore
/// - **Windows**: Windows Credential Manager
/// - **macOS**: Keychain Services
/// - **Linux**: libsecret
///
/// ## Token Refresh Flow
/// 1. Load stored [GmailTokens] on app startup
/// 2. If [GmailTokens.isExpired], use refresh token to get new access token
/// 3. Save updated tokens via [saveTokens]
/// 4. If refresh fails (invalid_grant), delete tokens and prompt re-auth
///
/// ## Revocation
/// Call [deleteTokens] to remove stored credentials.
/// Also call Google's revoke endpoint to invalidate server-side tokens.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spam_filter_mobile/adapters/auth/token_store.dart';
import 'package:spam_filter_mobile/util/redact.dart';

/// Secure implementation of [TokenStore] using flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  static const String _keyPrefix = 'gmail_tokens_';
  static const String _accountsListKey = 'gmail_accounts_list';

  final FlutterSecureStorage _storage;

  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  String _tokenKey(String accountId) => '$_keyPrefix$accountId';

  @override
  Future<void> saveTokens(String accountId, GmailTokens tokens) async {
    try {
      final json = jsonEncode(tokens.toJson());
      await _storage.write(key: _tokenKey(accountId), value: json);

      // Update accounts list
      final accounts = await listAccounts();
      if (!accounts.contains(accountId)) {
        accounts.add(accountId);
        await _storage.write(key: _accountsListKey, value: jsonEncode(accounts));
      }

      // Safe logging (never log actual tokens)
      Redact.logSafe('Saved tokens for account: ${Redact.email(tokens.email)}');
    } catch (e) {
      Redact.logSafe('Failed to save tokens: ${e.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<GmailTokens?> getTokens(String accountId) async {
    try {
      final json = await _storage.read(key: _tokenKey(accountId));
      if (json == null) return null;

      final tokens = GmailTokens.fromJson(jsonDecode(json));
      Redact.logSafe('Loaded tokens for: ${Redact.email(tokens.email)}, expired: ${tokens.isExpired}');
      return tokens;
    } catch (e) {
      Redact.logSafe('Failed to read tokens: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> deleteTokens(String accountId) async {
    try {
      await _storage.delete(key: _tokenKey(accountId));

      // Update accounts list
      final accounts = await listAccounts();
      accounts.remove(accountId);
      await _storage.write(key: _accountsListKey, value: jsonEncode(accounts));

      Redact.logSafe('Deleted tokens for account: ${Redact.accountId(accountId)}');
    } catch (e) {
      Redact.logSafe('Failed to delete tokens: ${e.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<List<String>> listAccounts() async {
    try {
      final json = await _storage.read(key: _accountsListKey);
      if (json == null) return [];
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> hasTokens(String accountId) async {
    final json = await _storage.read(key: _tokenKey(accountId));
    return json != null;
  }

  @override
  Future<void> clearAll() async {
    try {
      final accounts = await listAccounts();
      for (final account in accounts) {
        await _storage.delete(key: _tokenKey(account));
      }
      await _storage.delete(key: _accountsListKey);
      Redact.logSafe('Cleared all Gmail tokens');
    } catch (e) {
      Redact.logSafe('Failed to clear all tokens: ${e.runtimeType}');
      rethrow;
    }
  }
}
