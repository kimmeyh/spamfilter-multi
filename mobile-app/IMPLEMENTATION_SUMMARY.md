# Mobile App Implementation Summary

**Status**: Documentation Created - Implementation Pending  
**Last Updated**: 2025-12-29  
**Issue**: Gmail scan removing stored accounts and tokens

## Current Status

### Mobile App Implementation: NOT YET STARTED

This document serves as a specification and guide for the future Flutter-based mobile spam filter app. The mobile app code **does not exist yet** but is planned according to `memory-bank/mobile-app-plan.md`.

## Issue Resolution: Token and Account Persistence

### Problem Statement (from Issue)
After Gmail account has been setup and a scan is conducted, the Android app was removing all Android saved email accounts and tokens.

### Solution Specification

**CRITICAL REQUIREMENT**: When the mobile app is implemented, it **MUST NOT** remove stored accounts and tokens after scanning.

#### Token Management Implementation Requirements

1. **Secure Storage - Persistent Across Scans**
   - Use `flutter_secure_storage` for OAuth tokens and credentials
   - Tokens must persist in Android Keystore / iOS Keychain
   - Storage must survive:
     - Email scanning operations
     - App restarts
     - Background sync tasks
     - Token refresh operations

2. **Account Management - Never Delete**
   - Stored accounts are user-controlled only
   - Scanning operations must NEVER modify account storage
   - Only explicit user actions should add/remove accounts:
     - User clicks "Add Account" → Store account
     - User clicks "Remove Account" → Delete account
     - Automatic scanning → NO CHANGES to storage

3. **Token Lifecycle - Proper Refresh, No Deletion**
   ```dart
   // CORRECT: Refresh token without deletion
   Future<void> refreshToken(String accountId) async {
     final currentToken = await secureStorage.read(key: 'token_$accountId');
     final newToken = await oauth2Manager.refreshAccessToken(currentToken);
     await secureStorage.write(key: 'token_$accountId', value: newToken);
     // Old token replaced, account persists
   }
   
   // INCORRECT: Never do this during scan
   Future<void> scanEmails() async {
     // ❌ NEVER clear storage during scan
     // await secureStorage.deleteAll(); // WRONG!
     
     // ✅ CORRECT: Read tokens, use them, keep them stored
     final token = await secureStorage.read(key: 'token_$accountId');
     await gmailAPI.scanWithToken(token);
     // Token remains in storage after scan
   }
   ```

4. **Encryption at Rest**
   - All tokens/credentials encrypted using platform secure storage
   - Never store tokens in:
     - Plain text files
     - Shared preferences (unencrypted)
     - SQLite database (unless encrypted)
     - Application logs
     - Analytics events

5. **Session Management**
   - Maintain in-memory session state during app lifecycle
   - Load tokens from secure storage on app start
   - Don't reload/clear tokens unnecessarily
   - Preserve authentication state across navigation

### Architecture for Token Persistence

When implementing the mobile app (Phase 1-2 from mobile-app-plan.md):

#### Storage Layer Design

```dart
/// Secure credential storage - accounts persist across scans
class CredentialStorage {
  final FlutterSecureStorage _secureStorage;
  
  /// Save account credentials - called ONLY on user "Add Account"
  Future<void> saveAccountCredentials({
    required String accountId,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _secureStorage.write(
      key: 'account_${accountId}_access',
      value: accessToken,
    );
    await _secureStorage.write(
      key: 'account_${accountId}_refresh',
      value: refreshToken,
    );
    await _secureStorage.write(
      key: 'account_${accountId}_expires',
      value: expiresAt.toIso8601String(),
    );
  }
  
  /// Load credentials for scanning - NEVER deletes anything
  Future<AccountCredentials?> loadAccountCredentials(String accountId) async {
    final accessToken = await _secureStorage.read(
      key: 'account_${accountId}_access',
    );
    if (accessToken == null) return null;
    
    final refreshToken = await _secureStorage.read(
      key: 'account_${accountId}_refresh',
    );
    final expiresStr = await _secureStorage.read(
      key: 'account_${accountId}_expires',
    );
    
    return AccountCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.parse(expiresStr ?? ''),
    );
  }
  
  /// Delete account - called ONLY on user "Remove Account"
  Future<void> deleteAccountCredentials(String accountId) async {
    // Only called when user explicitly removes account
    await _secureStorage.delete(key: 'account_${accountId}_access');
    await _secureStorage.delete(key: 'account_${accountId}_refresh');
    await _secureStorage.delete(key: 'account_${accountId}_expires');
  }
}
```

#### Gmail Scan Service - Token Preservation

```dart
/// Gmail scanning service that preserves tokens
class GmailScanService {
  final CredentialStorage _credentialStorage;
  final OAuth2Manager _oauth2Manager;
  final GmailAPIAdapter _gmailAPI;
  
  /// Scan emails WITHOUT modifying stored credentials
  Future<ScanResult> scanAccount(String accountId) async {
    // 1. Load existing credentials (read-only)
    final credentials = await _credentialStorage.loadAccountCredentials(accountId);
    if (credentials == null) {
      throw Exception('Account not found - user must add account first');
    }
    
    // 2. Check if token needs refresh
    if (credentials.isExpired()) {
      // Refresh token and update storage (replace, not delete)
      final newToken = await _oauth2Manager.refreshAccessToken(
        credentials.refreshToken,
      );
      await _credentialStorage.saveAccountCredentials(
        accountId: accountId,
        accessToken: newToken.accessToken,
        refreshToken: newToken.refreshToken,
        expiresAt: newToken.expiresAt,
      );
    }
    
    // 3. Perform scan using credentials
    final messages = await _gmailAPI.fetchMessages(
      credentials: credentials,
      daysBack: 30,
      folderNames: ['SPAM', 'INBOX'],
    );
    
    // 4. Process messages (delete spam, etc.)
    final result = await _processMessages(messages);
    
    // 5. Return results - credentials remain in storage
    return result;
    // ✅ Tokens and account info still stored after scan
  }
}
```

### Anti-Patterns to Avoid

**DO NOT implement any of these patterns:**

```dart
// ❌ WRONG: Clearing storage after scan
Future<void> scanEmails() async {
  await performScan();
  await secureStorage.deleteAll(); // NEVER DO THIS
}

// ❌ WRONG: Temporary credentials that expire after scan
class TempCredentials {
  // Don't create temp storage that gets cleared
}

// ❌ WRONG: Clearing tokens on error
try {
  await scanEmails();
} catch (e) {
  await secureStorage.deleteAll(); // NEVER DO THIS
}

// ❌ WRONG: Storing tokens in memory only
Map<String, String> _tokens = {}; // Lost on app restart

// ❌ WRONG: Recreating OAuth flow on every scan
Future<void> scanEmails() async {
  final token = await oauth2Manager.authenticate(); // Too frequent
  // Should reuse stored token instead
}
```

### Testing Requirements

When mobile app is implemented, create tests to verify:

1. **Token Persistence Test**
   ```dart
   test('tokens persist after email scan', () async {
     // Setup: Add account with token
     await credentialStorage.saveAccountCredentials(...);
     
     // Action: Perform email scan
     await gmailScanService.scanAccount(accountId);
     
     // Verify: Token still exists in storage
     final credentials = await credentialStorage.loadAccountCredentials(accountId);
     expect(credentials, isNotNull);
     expect(credentials.accessToken, isNotEmpty);
   });
   ```

2. **Account Persistence Test**
   ```dart
   test('account list unchanged after scan', () async {
     // Setup: Add 2 accounts
     await addAccount('account1');
     await addAccount('account2');
     final initialAccounts = await accountManager.listAccounts();
     
     // Action: Scan first account
     await gmailScanService.scanAccount('account1');
     
     // Verify: Both accounts still exist
     final finalAccounts = await accountManager.listAccounts();
     expect(finalAccounts.length, equals(initialAccounts.length));
     expect(finalAccounts, containsAll(initialAccounts));
   });
   ```

3. **Token Refresh Test**
   ```dart
   test('expired token refreshed not deleted', () async {
     // Setup: Store expired token
     await credentialStorage.saveAccountCredentials(
       accountId: 'test',
       accessToken: 'expired_token',
       refreshToken: 'refresh_token',
       expiresAt: DateTime.now().subtract(Duration(hours: 1)),
     );
     
     // Action: Scan (should trigger refresh)
     await gmailScanService.scanAccount('test');
     
     // Verify: Token updated (not deleted)
     final credentials = await credentialStorage.loadAccountCredentials('test');
     expect(credentials, isNotNull);
     expect(credentials.accessToken, isNot('expired_token')); // Refreshed
   });
   ```

## Security Requirements

From issue: "Tokens/credentials must be stored securely and encrypted at rest."

### Encryption Implementation

1. **Platform-Native Encryption**
   - **Android**: Use Android Keystore via `flutter_secure_storage`
   - **iOS**: Use iOS Keychain via `flutter_secure_storage`
   - Both provide hardware-backed encryption on supported devices

2. **No Clear Text Storage**
   - ✅ Allowed: `flutter_secure_storage`
   - ✅ Allowed: Platform keychain/keystore
   - ❌ Forbidden: Plain text files
   - ❌ Forbidden: `shared_preferences` (unencrypted)
   - ❌ Forbidden: SQLite without encryption
   - ❌ Forbidden: Source code
   - ❌ Forbidden: Git repository
   - ❌ Forbidden: Logs
   - ❌ Forbidden: Analytics events

3. **Access Control**
   - Tokens accessible only to the app (sandboxed)
   - Require device authentication for sensitive operations (optional)
   - Clear tokens only on explicit user logout

### Security Testing

```dart
test('tokens never appear in logs', () async {
  final logSpy = LogSpy();
  
  await credentialStorage.saveAccountCredentials(
    accountId: 'test',
    accessToken: 'secret_token_12345',
    ...
  );
  
  await gmailScanService.scanAccount('test');
  
  // Verify token not in any log message
  expect(
    logSpy.messages.any((msg) => msg.contains('secret_token_12345')),
    isFalse,
  );
});
```

## Implementation Timeline

Based on `memory-bank/mobile-app-plan.md`:

### Phase 1 (Weeks 1-6): MVP with Proper Token Management
- ✅ Design: Token persistence architecture (this document)
- [ ] Implement: `CredentialStorage` with `flutter_secure_storage`
- [ ] Implement: OAuth2 flow with token refresh
- [ ] Implement: Account management (add/remove only by user)
- [ ] Implement: Gmail IMAP adapter with persistent credentials
- [ ] Test: Token persistence across scans
- [ ] Test: Account list unchanged after scan
- [ ] Test: Security (no tokens in logs/analytics)

### Phase 2 (Weeks 7-12): Multi-Provider Support
- [ ] Extend token storage for multiple providers
- [ ] Implement per-account token management
- [ ] Support AOL, Yahoo, Outlook.com with same persistence model

### Phase 3 (Weeks 13-16): Background Scanning
- [ ] Ensure background tasks preserve tokens
- [ ] Test token persistence during background sync
- [ ] Handle token refresh in background

## Dependencies

```yaml
# pubspec.yaml additions for token management
dependencies:
  flutter_secure_storage: ^9.0.0  # Encrypted credential storage
  flutter_appauth: ^6.0.0          # OAuth 2.0 flows
  google_sign_in: ^6.1.0           # Gmail OAuth
  http: ^1.1.0                     # API calls with Bearer tokens
```

## Documentation Updates Needed

When mobile app is implemented, update:
1. ✅ This file (IMPLEMENTATION_SUMMARY.md) - Created with specification
2. [ ] `mobile-app/README.md` - Add setup guide for OAuth credentials
3. [ ] `memory-bank/memory-bank.json` - Add mobile app architecture section
4. [ ] `memory-bank/mobile-app-plan.md` - Mark Phase 1 token management as complete

## Related Issues

- Original Issue: "Update to Gmail scan to not remove stored accounts and tokens"
- Root Cause: Mobile app not implemented yet
- Resolution: Document proper token persistence requirements for future implementation
- Status: ✅ Specification complete, awaiting Phase 1 implementation

## Summary

**The mobile app does not exist yet.** This document establishes the architectural requirements to ensure that when the app IS built (per `mobile-app-plan.md`), it will:

1. ✅ Store tokens securely using `flutter_secure_storage`
2. ✅ Never delete accounts/tokens during email scanning
3. ✅ Encrypt all credentials at rest
4. ✅ Only modify account storage on explicit user actions
5. ✅ Refresh expired tokens without deletion
6. ✅ Maintain persistent authentication across app lifecycle

**Next Steps**: Begin Phase 1 implementation of mobile app following this specification.
