# Credential Verification Test Guide

## Overview

The **Credential Verification Test** (`test/integration/credential_verification_test.dart`) provides comprehensive automated testing of all stored email credentials across all platforms and authentication methods.

**Key Features**:
- ✅ Tests all saved accounts (AOL, Gmail, Yahoo, iCloud, custom IMAP)
- ✅ Supports multiple authentication methods (IMAP App Password, OAuth 2.0)
- ✅ Cross-platform compatibility (Windows Desktop, Android, iOS)
- ✅ Headless execution (no app UI required)
- ✅ Detailed logging and reporting
- ✅ CI/CD pipeline ready

## Running the Test

### Option 1: Unit Test Environment (Mocked)
```bash
# Run with skipped platform-dependent tests
flutter test test/integration/credential_verification_test.dart
```

**Output**: Shows which tests are skipped due to missing platform plugins
```
✓ Credential Verification - All Platforms
  ✓ verify secure storage is available on this platform (skipped)
  ✓ test all saved accounts credentials with appropriate adapters (skipped)
  ✓ verify AOL IMAP credentials specifically (skipped)
  ✓ verify Gmail OAuth credentials specifically (skipped)
  ✓ verify all credential types are properly encrypted (passed)
  ✓ verify platform IDs are correctly stored and retrieved (passed)
```

### Option 2: Integration Test on Device/Emulator
```bash
# Run as integration test (requires device or emulator running)
flutter test integration_test/credential_verification_test.dart
# OR
flutter drive --target=integration_test/credential_verification_test.dart
```

**Requirements**:
- Device or Android emulator running with app installed
- App already launched at least once (to initialize platform channels)
- At least one credential saved via app's login screen

### Option 3: Full Test Suite
```bash
# Run all tests including credential verification
flutter test

# Run with coverage
flutter test --coverage
```

## Test Cases

### 1. **Secure Storage Availability** (Skipped in unit tests)
- Verifies platform-native secure storage is accessible
- Tests read/write/delete operations
- Ensures encryption is functioning

### 2. **All Saved Accounts Verification** (Main test)
- Reads all saved account IDs from `SecureCredentialsStore`
- For each account:
  - Loads credentials from secure storage
  - Determines platform (AOL, Gmail, Yahoo, iCloud, IMAP)
  - Selects appropriate adapter (GenericIMAPAdapter, GmailApiAdapter)
  - Tests connection with actual credentials
  - Reports detailed results
- Generates summary with pass/fail statistics

**Expected Output** (with saved credentials):
```
📋 Found 2 saved account(s)

🔍 Testing account: user@aol.com
   📧 Email: user@aol.com
   🏢 Platform: aol
   🔐 Auth Method: IMAP (App Password)
   🔌 Adapter: AOL Mail
   ✅ Connection successful

🔍 Testing account: user@gmail.com
   📧 Email: user@gmail.com
   🏢 Platform: gmail
   🔐 Auth Method: OAuth 2.0
   🔌 Adapter: Gmail
   ✅ Connection successful

============================================================
📊 CREDENTIAL VERIFICATION SUMMARY
============================================================
Total accounts tested: 2
✅ Valid credentials: 2
❌ Invalid/Failed: 0
```

### 3. **AOL IMAP Credentials** (Platform-specific)
- Specifically tests accounts identified as AOL
- Verifies IMAP app password authentication
- Confirms connection to AOL IMAP server (imap.aol.com:993)

### 4. **Gmail OAuth Credentials** (Platform-specific)
- Tests accounts identified as Gmail
- Verifies OAuth 2.0 access token validity
- Attempts Gmail API connection
- Handles platform-specific OAuth limitations (e.g., Android emulator)

### 5. **Credential Type Verification**
- Validates email addresses exist and are non-empty
- Confirms either password or OAuth token is stored
- Verifies secure encryption of all stored data
- Checks `additionalParams` structure (accountId, platformId)

### 6. **Platform ID Verification**
- Retrieves and validates platform identifiers
- Confirms platform is in known list: `aol`, `yahoo`, `icloud`, `imap`, `gmail`
- Handles missing platform IDs gracefully

## Saved Credential Structure

The test reads credentials stored by the app in this structure:

```
SecureCredentialsStore Keys:
├── saved_accounts                              (comma-separated account IDs)
├── credentials_{accountId}_email               (user@example.com)
├── credentials_{accountId}_password            (app password or empty)
├── credentials_{accountId}_accessToken         (OAuth token or empty)
└── credentials_{accountId}_platformId          (aol, gmail, yahoo, icloud, or imap)
```

**Example** for `user@aol.com`:
```
saved_accounts=user@aol.com,user@gmail.com
credentials_user@aol.com_email=user@aol.com
credentials_user@aol.com_password=abcd1234efgh5678
credentials_user@aol.com_platformId=aol
```

## Supported Platforms & Auth Methods

| Platform  | Display Name  | Auth Method        | Server                 | Port |
|-----------|---------------|--------------------|------------------------|------|
| AOL       | AOL Mail      | IMAP App Password  | imap.aol.com          | 993  |
| Gmail     | Gmail         | OAuth 2.0          | Gmail REST API         | -    |
| Yahoo     | Yahoo Mail    | IMAP App Password  | imap.mail.yahoo.com    | 993  |
| iCloud    | iCloud Mail   | IMAP App Password  | imap.mail.me.com       | 993  |
| imap      | Custom IMAP   | IMAP App Password  | Configurable           | 993  |

## Adapter Selection Logic

```
if (platformId == 'gmail' OR hasAccessToken) {
  ├─> Use GmailApiAdapter (OAuth 2.0)
  └─> testConnection() validates access token
  
else if (platformId == 'aol' OR email.endswith('@aol.com')) {
  ├─> Use GenericIMAPAdapter.aol()
  └─> testConnection() validates IMAP credentials
  
else if (platformId == 'yahoo' OR email.endswith('@yahoo.com')) {
  ├─> Use GenericIMAPAdapter.yahoo()
  └─> testConnection() validates IMAP credentials
  
else if (platformId == 'icloud' OR email.endswith('@icloud.com')) {
  ├─> Use GenericIMAPAdapter.icloud()
  └─> testConnection() validates IMAP credentials
  
else {
  ├─> Use GenericIMAPAdapter.custom()
  └─> testConnection() validates IMAP credentials
}
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Run Credential Verification Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.3'
      
      - name: Install dependencies
        run: cd mobile-app && flutter pub get
      
      - name: Run credential verification tests
        run: cd mobile-app && flutter test test/integration/credential_verification_test.dart
```

### Local Pre-Commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
cd mobile-app
flutter test test/integration/credential_verification_test.dart || exit 1
```

## Troubleshooting

### Issue: "MissingPluginException" or "Secure storage not available"

**Cause**: Tests are running in unit test environment without platform implementation

**Solution**: 
- Run on actual device/emulator for full platform plugin support
- Unit tests will skip these cases - this is expected behavior

### Issue: Tests show "No saved credentials found"

**Cause**: No accounts have been added via the app yet

**Solution**:
1. Launch the app (`flutter run`)
2. Navigate to Settings/Accounts
3. Add at least one email account (AOL or Gmail)
4. Run the test again

### Issue: "OAuth not available on this platform"

**Cause**: Gmail OAuth requires platform-specific browser/webview

**Solution**:
- This is expected on Android emulator without proper Google Play setup
- AOL credentials will still be verified
- Gmail verification will gracefully skip with informative message

### Issue: IMAP connection timeout

**Cause**: Server connection problems or invalid credentials

**Solution**:
1. Verify credentials in app settings
2. Check internet connectivity
3. Ensure app password (not account password) is used for AOL
4. Check that email account is properly configured in the app

## Understanding Test Output

```
🔐 Verifying credential encryption...

✅ user@aol.com credentials properly encrypted and loaded
✅ user@gmail.com credentials properly encrypted and loaded

🏢 Verifying platform IDs...

Account: user@aol.com
  Stored platformId: aol
  In credentials.additionalParams: aol
  ✅ Valid platform: aol

Account: user@gmail.com
  Stored platformId: gmail
  In credentials.additionalParams: gmail
  ✅ Valid platform: gmail
```

## Implementation Details

### File Location
```
mobile-app/test/integration/credential_verification_test.dart
```

### Key Classes
- `CredentialTestResult` - Data class tracking test results
- `SecureCredentialsStore` - Encrypted credential storage
- `GenericIMAPAdapter` - IMAP protocol support (AOL, Yahoo, iCloud)
- `GmailApiAdapter` - Gmail OAuth 2.0 support

### Helper Functions
- `_testIMAPCredentials()` - Tests IMAP-based accounts
- `_testGmailCredentials()` - Tests Gmail OAuth accounts

### Dependencies
```yaml
flutter_test:
  sdk: flutter
spam_filter_mobile:
  path: .
```

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Load credentials from storage | <100ms | Per account |
| IMAP connection test | 2-10s | Depends on server response |
| Gmail OAuth validation | 1-5s | API call overhead |
| Full test suite (3 tests, 2 accounts) | 15-30s | Sequential execution |

## Security Considerations

⚠️ **Important**:
- This test reads actual stored credentials from secure storage
- Credentials are passed to real servers for validation
- **Never commit saved credentials to version control**
- **Always use app passwords (not account passwords) for IMAP**
- Secure storage uses platform-native encryption:
  - Windows: Credential Manager (DPAPI)
  - Android: EncryptedSharedPreferences
  - iOS: Keychain

## Future Enhancements

- [ ] Parallel credential testing (currently sequential)
- [ ] Detailed server response analysis
- [ ] Certificate validation testing
- [ ] Rate-limit and quota checking
- [ ] Automated retry logic for transient failures
- [ ] Webhook/email notification of test results
- [ ] Historical result tracking and trending
- [ ] Performance benchmarking per provider

## Related Documentation

- [Phase 2 Sprint 5 Completion Report](../PHASE_2_SPRINT_5_COMPLETION.md)
- [Integration Test Guide](../mobile-app/IMPLEMENTATION_SUMMARY.md)
- [Memory Bank - Processing Flow](../memory-bank/processing-flow.md)
- [Windows Testing Setup](../WINDOWS_TESTING_SETUP_COMPLETE.md)
