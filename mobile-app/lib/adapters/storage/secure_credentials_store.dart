/// Secure credential storage using platform encryption
/// 
/// Stores email credentials, OAuth tokens, and sensitive data
/// using platform-specific secure storage:
/// - Android: EncryptedSharedPreferences
/// - iOS: Keychain
/// - Web: In-memory (no persistence in browsers)
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../adapters/email_providers/email_provider.dart';
import '../auth/token_store.dart';

/// Exception thrown when credential operations fail
class CredentialStorageException implements Exception {
  final String message;
  final dynamic originalError;

  CredentialStorageException(this.message, [this.originalError]);

  @override
  String toString() => 'CredentialStorageException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Secure storage for email credentials and authentication tokens
/// 
/// This storage implementation:
/// - Uses flutter_secure_storage for encrypted persistence
/// - Stores credentials by account identifier (email address)
/// - Supports multiple email accounts
/// - Handles OAuth tokens, app passwords, and basic auth
/// 
/// Example:
/// ```dart
/// final credStore = SecureCredentialsStore();
/// 
/// // Save AOL credentials
/// await credStore.saveCredentials('aol', Credentials(
///   email: 'user@aol.com',
///   password: 'app-password',
/// ));
/// 
/// // Load AOL credentials
/// final creds = await credStore.getCredentials('aol');
/// 
/// // Delete credentials (logout)
/// await credStore.deleteCredentials('aol');
/// ```
class SecureCredentialsStore {
  static const String _credentialsPrefix = 'credentials_';
  static const String _tokenPrefix = 'token_';
  static const String _accountsKey = 'saved_accounts';

  final FlutterSecureStorage _storage;
  final Logger _logger = Logger();

  SecureCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Save credentials for an account
  /// 
  /// Securely stores email, password, and platformId as separate fields
  /// accountId should be the email address (primary key)
  /// platformId is stored separately to avoid concatenation
  /// Returns true if successful
  Future<bool> saveCredentials(
    String accountId,
    Credentials credentials, {
    String? platformId,
  }) async {
    try {
      _logger.i('Saving credentials for accountId: $accountId, platformId: $platformId');
      
      // Store email
      await _storage.write(
        key: '${_credentialsPrefix}${accountId}_email',
        value: credentials.email,
      );

      // Store platformId separately if provided
      if (platformId != null && platformId.isNotEmpty) {
        await _storage.write(
          key: '${_credentialsPrefix}${accountId}_platformId',
          value: platformId,
        );
        _logger.i('[OK] Stored platformId: $platformId for account: $accountId');
      } else {
        _logger.w('[WARNING] No platformId provided for account: $accountId');
      }

      // Store password
      await _storage.write(
        key: '${_credentialsPrefix}${accountId}_password',
        value: credentials.password,
      );

      // Store access token if provided (for OAuth desktop flows)
      if (credentials.accessToken != null && credentials.accessToken!.isNotEmpty) {
        await _storage.write(
          key: '${_credentialsPrefix}${accountId}_accessToken',
          value: credentials.accessToken,
        );
      }

      // Update accounts list
      await _addAccountToList(accountId);

      final savedAccounts = await getSavedAccounts();
      _logger.i('[OK] Saved credentials for account: $accountId. Total accounts now: ${savedAccounts.length}. All accounts: $savedAccounts');
      return true;
    } catch (e) {
      throw CredentialStorageException('Failed to save credentials', e);
    }
  }

  /// Load credentials for an account
  /// 
  /// Returns null if credentials don't exist
  Future<Credentials?> getCredentials(String accountId) async {
    try {
      final email = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_email',
      );

      // If no standard credentials found, check Gmail tokens as fallback
      if (email == null) {
        final gmailTokens = await getGmailTokens(accountId);
        if (gmailTokens != null) {
          _logger.d('Using Gmail tokens for credentials: $accountId');

          // Get platformId if stored
          final platformId = await _storage.read(
            key: '$_credentialsPrefix${accountId}_platformId',
          );

          return Credentials(
            email: gmailTokens.email,
            password: null, // OAuth doesn't use passwords
            accessToken: gmailTokens.accessToken,
            additionalParams: {
              'accountId': accountId,
              if (platformId != null) 'platformId': platformId,
              'isGmailOAuth': 'true', // Flag for adapters
            },
          );
        }

        // No credentials found at all
        return null;
      }

      final password = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_password',
      );

      // Access token (optional)
      String? accessToken = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_accessToken',
      );

      // Fallback to OAuth token store if credentials blob does not include an access token
      if (accessToken == null || accessToken.isEmpty) {
        try {
          final oauthToken = await getOAuthToken(accountId, 'access');
          if (oauthToken != null && oauthToken.isNotEmpty) {
            accessToken = oauthToken;
            _logger.i('Using stored OAuth access token for account: $accountId');
          }
        } catch (e) {
          _logger.w('Failed to load OAuth access token for account: $accountId', error: e);
        }
      }

      // Retrieve platformId if stored
      final platformId = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_platformId',
      );

      _logger.d('Retrieved credentials for account: $accountId');
      return Credentials(
        email: email,
        password: password,
        accessToken: accessToken,
        additionalParams: {
          // Provide accountId so adapters can look up refresh tokens when needed
          'accountId': accountId,
          if (platformId != null) 'platformId': platformId,
        },
      );
    } catch (e) {
      throw CredentialStorageException('Failed to retrieve credentials', e);
    }
  }

  /// Save OAuth token for an account
  /// 
  /// Useful for storing access/refresh tokens for Gmail, Outlook, etc.
  Future<void> saveOAuthToken(
    String accountId,
    String tokenType,
    String token,
  ) async {
    try {
      await _storage.write(
        key: '${_tokenPrefix}${accountId}_${tokenType}',
        value: token,
      );

      // Update accounts list
      await _addAccountToList(accountId);

      _logger.i('Saved $tokenType token for account: $accountId');
    } catch (e) {
      throw CredentialStorageException('Failed to save OAuth token', e);
    }
  }

  /// Load OAuth token for an account
  ///
  /// Returns null if token doesn't exist
  Future<String?> getOAuthToken(String accountId, String tokenType) async {
    try {
      final token = await _storage.read(
        key: '${_tokenPrefix}${accountId}_${tokenType}',
      );

      if (token != null) {
        _logger.d('Retrieved $tokenType token for account: $accountId');
      }

      return token;
    } catch (e) {
      throw CredentialStorageException('Failed to retrieve OAuth token', e);
    }
  }

  /// Save Gmail OAuth tokens (complete token bundle)
  ///
  /// Stores all Gmail OAuth 2.0 tokens including access token, refresh token,
  /// expiry time, granted scopes, and email address.
  /// This replaces the need for SecureTokenStore for Gmail accounts.
  /// UNIFIED STORAGE FIX: Consolidates token storage to prevent race conditions
  Future<void> saveGmailTokens(String accountId, GmailTokens tokens) async {
    try {
      final json = jsonEncode(tokens.toJson());
      await _storage.write(
        key: '${_tokenPrefix}${accountId}_gmail_tokens',
        value: json,
      );

      // Update accounts list
      await _addAccountToList(accountId);

      _logger.i('[OK] Saved Gmail tokens for account: $accountId');
    } catch (e) {
      throw CredentialStorageException('Failed to save Gmail tokens', e);
    }
  }

  /// Load Gmail OAuth tokens for an account
  ///
  /// Returns null if no tokens exist for this account
  Future<GmailTokens?> getGmailTokens(String accountId) async {
    try {
      final json = await _storage.read(
        key: '${_tokenPrefix}${accountId}_gmail_tokens',
      );

      if (json == null) {
        _logger.d('No Gmail tokens found for account: $accountId');
        return null;
      }

      final tokens = GmailTokens.fromJson(jsonDecode(json));
      _logger.d('[OK] Retrieved Gmail tokens for account: $accountId, expired: ${tokens.isExpired}');
      return tokens;
    } catch (e) {
      _logger.e('[FAIL] Failed to retrieve Gmail tokens for $accountId', error: e);
      return null;
    }
  }

  /// Delete Gmail OAuth tokens for an account
  ///
  /// Note: This only deletes the Gmail token bundle, not the account credentials.
  /// Use deleteCredentials() to remove the account entirely.
  Future<void> deleteGmailTokens(String accountId) async {
    try {
      await _storage.delete(key: '${_tokenPrefix}${accountId}_gmail_tokens');
      _logger.i('[OK] Deleted Gmail tokens for account: $accountId');
    } catch (e) {
      throw CredentialStorageException('Failed to delete Gmail tokens', e);
    }
  }

  /// Check if Gmail tokens exist for an account
  Future<bool> hasGmailTokens(String accountId) async {
    try {
      final json = await _storage.read(
        key: '${_tokenPrefix}${accountId}_gmail_tokens',
      );
      return json != null;
    } catch (e) {
      return false;
    }
  }

  /// Save platformId for an account
  ///
  /// Useful when GoogleAuthService saves tokens but we need to associate platformId
  Future<void> savePlatformId(String accountId, String platformId) async {
    try {
      await _storage.write(
        key: '${_credentialsPrefix}${accountId}_platformId',
        value: platformId,
      );

      // Ensure account is in the list (idempotent)
      await _addAccountToList(accountId);

      _logger.i('[OK] Saved platformId: $platformId for account: $accountId');
    } catch (e) {
      throw CredentialStorageException('Failed to save platformId', e);
    }
  }

  /// Get the platformId for an account
  /// Returns null if not found
  Future<String?> getPlatformId(String accountId) async {
    try {
      final platformId = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_platformId',
      );

      if (platformId != null && platformId.isNotEmpty) {
        _logger.d('[OK] Retrieved platformId: $platformId for account: $accountId');
      } else {
        _logger.w('[WARNING] No platformId found for account: $accountId (will need to infer)');
      }

      return platformId;
    } catch (e) {
      _logger.e('Failed to get platformId for $accountId: $e');
      return null;
    }
  }

  /// Check if credentials exist for an account
  Future<bool> credentialsExist(String accountId) async {
    try {
      final email = await _storage.read(
        key: '${_credentialsPrefix}${accountId}_email',
      );
      return email != null;
    } catch (e) {
      _logger.w('Failed to check if credentials exist', error: e);
      return false;
    }
  }

  /// Delete credentials for an account (logout)
  Future<void> deleteCredentials(String accountId) async {
    try {
      _logger.w('🔴 DELETING credentials for account: $accountId');
      
      // Delete email
      await _storage.delete(
        key: '${_credentialsPrefix}${accountId}_email',
      );

      // Delete password
      await _storage.delete(
        key: '${_credentialsPrefix}${accountId}_password',
      );

      // Delete tokens (support both historical and current key formats)
      // Historical format
      await _storage.delete(key: '${_tokenPrefix}${accountId}_access_token');
      await _storage.delete(key: '${_tokenPrefix}${accountId}_refresh_token');
      // Current format used by saveOAuthToken(accountId, 'access'|'refresh', ...)
      await _storage.delete(key: '${_tokenPrefix}${accountId}_access');
      await _storage.delete(key: '${_tokenPrefix}${accountId}_refresh');

      // Delete access token stored within credentials
      await _storage.delete(
        key: '${_credentialsPrefix}${accountId}_accessToken',
      );

      // Delete Gmail OAuth token bundle
      await _storage.delete(key: '${_tokenPrefix}${accountId}_gmail_tokens');

      // Delete platformId
      await _storage.delete(
        key: '${_credentialsPrefix}${accountId}_platformId',
      );

      // Update accounts list
      await _removeAccountFromList(accountId);

      _logger.i('[OK] Successfully deleted credentials for account: $accountId');
    } catch (e) {
      throw CredentialStorageException('Failed to delete credentials', e);
    }
  }

  /// Get list of all saved account IDs
  Future<List<String>> getSavedAccounts() async {
    try {
      final accountsJson = await _storage.read(key: _accountsKey);
      _logger.d('[CHECKLIST] Raw accounts JSON from storage: "$accountsJson" (length: ${accountsJson?.length}, isNull: ${accountsJson == null}, isEmpty: ${accountsJson?.isEmpty})');
      
      if (accountsJson == null) {
        _logger.w('[WARNING]  accounts JSON is NULL - no accounts saved yet');
        return [];
      }
      
      if (accountsJson.isEmpty) {
        _logger.w('[WARNING]  accounts JSON is EMPTY string - something cleared the list!');
        return [];
      }

      // Parse comma-separated list (simple format)
      final split = accountsJson.split(',');
      _logger.d('[CHECKLIST] After split: ${split.length} items: $split');
      
      final parsed = split.where((a) => a.isNotEmpty).toList();
      _logger.i('[OK] Loaded ${parsed.length} saved accounts: $parsed');
      return parsed;
    } catch (e) {
      _logger.e('[FAIL] Failed to get saved accounts', error: e);
      return [];
    }
  }

  /// Clear all stored credentials (dangerous!)
  Future<void> deleteAllCredentials() async {
    try {
      final accounts = await getSavedAccounts();
      for (final accountId in accounts) {
        await deleteCredentials(accountId);
      }
      _logger.w('Cleared all stored credentials');
    } catch (e) {
      throw CredentialStorageException('Failed to clear all credentials', e);
    }
  }

  /// Add account to saved accounts list
  Future<void> _addAccountToList(String accountId) async {
    try {
      final accounts = await getSavedAccounts();
      _logger.i('➕ Adding account $accountId to list. Current accounts before: $accounts (${accounts.length} items)');
      
      if (!accounts.contains(accountId)) {
        accounts.add(accountId);
        final joinedValue = accounts.join(',');
        _logger.i('➕ Account $accountId not in list, adding it. New list: $accounts');
        _logger.i('➕ Joined value to write: "$joinedValue" (length: ${joinedValue.length})');
        
        await _storage.write(
          key: _accountsKey,
          value: joinedValue,
        );
        
        // Verify it was written correctly
        final verify = await _storage.read(key: _accountsKey);
        _logger.i('[OK] Written to storage. Verified read back: "$verify"');
        _logger.i('[OK] Successfully added $accountId. All accounts now: $accounts');
      } else {
        _logger.d('ℹ️  Account $accountId already in list, skipping');
      }
    } catch (e) {
      _logger.e('[FAIL] Failed to add account to list', error: e);
    }
  }

  /// Remove account from saved accounts list
  Future<void> _removeAccountFromList(String accountId) async {
    try {
      final accountsBefore = await getSavedAccounts();
      _logger.i('🗑️  Removing account $accountId. Accounts BEFORE: $accountsBefore');
      
      accountsBefore.remove(accountId);
      final accountsAfter = accountsBefore;
      _logger.i('🗑️  Accounts AFTER removal: $accountsAfter');
      
      final joinedValue = accountsAfter.join(',');
      _logger.i('🗑️  Writing to storage: "$joinedValue"');
      
      await _storage.write(
        key: _accountsKey,
        value: joinedValue,
      );
      
      _logger.i('[OK] Successfully removed account $accountId from list. Remaining: $accountsAfter');
    } catch (e) {
      _logger.e('[FAIL] Failed to remove account from list', error: e);
    }
  }

  /// Migrate Gmail tokens from old SecureTokenStore to unified storage
  ///
  /// This is a one-time migration for existing users who have tokens stored
  /// in the old `gmail_accounts_list` format from SecureTokenStore.
  /// Should be called on app startup to ensure seamless transition.
  Future<void> migrateFromLegacyTokenStore() async {
    try {
      // Check if old token store has any accounts
      final oldAccountsJson = await _storage.read(key: 'gmail_accounts_list');
      if (oldAccountsJson == null || oldAccountsJson.isEmpty) {
        _logger.d('No legacy token store data to migrate');
        return;
      }

      final oldAccounts = List<String>.from(jsonDecode(oldAccountsJson));
      if (oldAccounts.isEmpty) {
        _logger.d('Legacy token store exists but is empty');
        return;
      }

      _logger.i('📦 Migrating ${oldAccounts.length} accounts from legacy token store...');

      int migratedCount = 0;
      for (final accountId in oldAccounts) {
        try {
          // Read old token format
          final oldTokenJson = await _storage.read(key: 'gmail_tokens_$accountId');
          if (oldTokenJson == null) {
            _logger.w('No tokens found for legacy account: $accountId');
            continue;
          }

          // Parse and save to new format
          final tokens = GmailTokens.fromJson(jsonDecode(oldTokenJson));
          await saveGmailTokens(accountId, tokens);

          // Set platformId to 'gmail' for migrated accounts
          await savePlatformId(accountId, 'gmail');

          migratedCount++;
          _logger.i('[OK] Migrated account: $accountId');
        } catch (e) {
          _logger.e('[FAIL] Failed to migrate account $accountId', error: e);
        }
      }

      // Clean up old storage keys after successful migration
      if (migratedCount == oldAccounts.length) {
        await _storage.delete(key: 'gmail_accounts_list');
        for (final accountId in oldAccounts) {
          await _storage.delete(key: 'gmail_tokens_$accountId');
        }
        _logger.i('[OK] Migration complete! Migrated $migratedCount accounts and cleaned up legacy storage');
      } else {
        _logger.w('[WARNING]  Partial migration: $migratedCount/${oldAccounts.length} accounts migrated. Keeping legacy storage for safety.');
      }
    } catch (e) {
      _logger.e('[FAIL] Migration failed', error: e);
      // Don't throw - migration failure shouldn't block app startup
    }
  }

  /// Test secure storage availability
  ///
  /// Useful for verifying platform support
  Future<bool> testAvailable() async {
    try {
      const testKey = '_test_secure_storage_availability';
      const testValue = '_test_value_123';

      await _storage.write(key: testKey, value: testValue);
      final read = await _storage.read(key: testKey);
      await _storage.delete(key: testKey);

      return read == testValue;
    } catch (e) {
      _logger.w('Secure storage not available', error: e);
      return false;
    }
  }
}
