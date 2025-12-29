# Spam Filter Mobile App

**Status**: Planning / Not Yet Implemented  
**Platform**: Flutter (Android, iOS, Chromebooks)  
**Last Updated**: 2025-12-29

## Overview

This directory will contain the cross-platform mobile spam filter app built with Flutter. The app will provide automated email spam filtering for multiple email providers (Gmail, AOL, Yahoo, Outlook.com, etc.) using the same YAML-based rule system as the desktop application.

## Current Status: NOT YET IMPLEMENTED

The mobile app code **does not exist yet**. This README and the accompanying `IMPLEMENTATION_SUMMARY.md` serve as specifications for the future implementation.

### What Exists Now
- ✅ Desktop Python spam filter (in repository root)
- ✅ YAML rule files (`rules.yaml`, `rules_safe_senders.yaml`)
- ✅ Architecture plan (`../memory-bank/mobile-app-plan.md`)
- ✅ Implementation specifications (`IMPLEMENTATION_SUMMARY.md`)

### What Needs to Be Built
- [ ] Flutter project structure
- [ ] Core business logic (rule evaluation, pattern matching)
- [ ] Email provider adapters (Gmail, IMAP, etc.)
- [ ] OAuth 2.0 authentication flows
- [ ] Secure credential storage
- [ ] User interface (account setup, scanning, rule management)
- [ ] Background sync capabilities
- [ ] Comprehensive test suite

## Issue Resolution: Token Persistence

### Problem Statement
The issue "Update to Gmail scan to not remove stored accounts and tokens" was raised, but the mobile app doesn't exist yet.

### Solution
The `IMPLEMENTATION_SUMMARY.md` document specifies the **correct architecture** for token and account management that must be implemented when building the app:

1. **Persistent Storage**: Use `flutter_secure_storage` for all credentials
2. **No Deletion During Scans**: Scanning operations must never modify stored accounts/tokens
3. **Encryption at Rest**: All credentials encrypted using platform keystore/keychain
4. **User-Controlled Only**: Only explicit user actions (Add/Remove Account) modify storage

See `IMPLEMENTATION_SUMMARY.md` for detailed specifications, code examples, and security requirements.

## Architecture

Based on `../memory-bank/mobile-app-plan.md`, the app will use a layered architecture:

```
┌─────────────────────────────────────────────────────┐
│              Flutter UI Layer                       │
│  - Account setup & OAuth flows                      │
│  - Scan status & results                            │
│  - Rule editor & safe sender manager                │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│         Business Logic Layer (Pure Dart)            │
│  - RuleSet: In-memory rule management               │
│  - Evaluator: Message → Action decision engine      │
│  - PatternCompiler: Precompile & cache regex        │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│           Adapter Layer (Dart)                      │
│  - Email Providers (Gmail API, IMAP, Graph API)     │
│  - Secure Storage (flutter_secure_storage)          │
│  - OAuth 2.0 Manager                                │
│  - Background Sync (WorkManager, BackgroundFetch)   │
└─────────────────────────────────────────────────────┘
```

## Planned Features

### Phase 1: MVP (Weeks 1-6)
- [ ] AOL email support via IMAP
- [ ] YAML rule import from desktop app
- [ ] Manual email scanning
- [ ] Secure OAuth credential storage (**with proper token persistence**)
- [ ] Basic UI (account setup, scan trigger, results)

### Phase 2: Multi-Provider (Weeks 7-12)
- [ ] Gmail support via Gmail API
- [ ] Outlook.com via Microsoft Graph API
- [ ] Yahoo support
- [ ] Multi-account management

### Phase 3: Interactive Training (Weeks 13-16)
- [ ] Interactive rule builder (d/e/s/sd options)
- [ ] Rule editor UI
- [ ] Safe sender manager

### Phase 4: Background Processing (Weeks 17-20)
- [ ] Automatic background scanning (Android WorkManager, iOS BackgroundFetch)
- [ ] Push notifications for new spam detected
- [ ] Configurable scan frequency

## Security & Privacy

### Critical Requirements

From issue and planning documents:

1. **Encrypted Storage**
   - All tokens/credentials encrypted at rest
   - Use platform secure storage (Android Keystore, iOS Keychain)
   - Never store secrets in plain text

2. **No Clear Text Exposure**
   - Tokens must not appear in:
     - Source code
     - Git repository
     - Application logs
     - Analytics events
     - SQLite database (unless encrypted)
     - Shared preferences

3. **Token Persistence**
   - Tokens persist across app restarts
   - Tokens persist during email scanning
   - Tokens only deleted on explicit user logout/remove account

4. **Zero Server Architecture**
   - All processing on-device
   - No cloud backend required (optional backup only)
   - User controls all data

### Planned Security Implementation

```dart
// Example: Secure credential storage
class CredentialStorage {
  final FlutterSecureStorage _secureStorage;
  
  // Save credentials (called only on user "Add Account")
  Future<void> saveAccountCredentials({
    required String accountId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(
      key: 'account_${accountId}_access',
      value: accessToken,
    );
    // Credentials persist until user removes account
  }
  
  // Load for scanning (read-only, no deletion)
  Future<Credentials?> loadAccountCredentials(String accountId) async {
    return await _secureStorage.read(key: 'account_${accountId}_access');
    // ✅ Never deletes anything during scan
  }
}
```

## Technology Stack

### Core Dependencies (Planned)

```yaml
dependencies:
  flutter: ^3.10.0
  
  # Email & Authentication
  enough_mail: ^2.1.0              # IMAP client
  flutter_appauth: ^6.0.0          # OAuth 2.0
  google_sign_in: ^6.1.0           # Gmail integration
  http: ^1.1.0                     # REST API calls
  
  # Storage (CRITICAL for token persistence)
  flutter_secure_storage: ^9.0.0  # Encrypted credential storage
  yaml: ^3.1.0                     # YAML rule import
  path_provider: ^2.1.0            # App directories
  
  # State & Utilities
  provider: ^6.1.0                 # State management
  logger: ^2.0.0                   # Logging (sanitized)
```

## File Structure (Planned)

When implemented, the mobile app will have this structure:

```
mobile-app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── models/
│   │   │   ├── email_message.dart
│   │   │   ├── rule_set.dart
│   │   │   └── credentials.dart
│   │   ├── services/
│   │   │   ├── rule_evaluator.dart
│   │   │   ├── credential_storage.dart  # Token persistence
│   │   │   └── oauth2_manager.dart
│   │   └── utils/
│   ├── adapters/
│   │   ├── email_providers/
│   │   │   ├── gmail_api_adapter.dart
│   │   │   └── generic_imap_adapter.dart
│   │   └── storage/
│   │       └── secure_storage.dart
│   └── ui/
│       ├── screens/
│       │   ├── account_setup_screen.dart
│       │   ├── scan_screen.dart
│       │   └── rule_editor_screen.dart
│       └── widgets/
├── test/
│   ├── unit/
│   │   └── credential_persistence_test.dart  # Token tests
│   ├── integration/
│   └── fixtures/
├── android/
├── ios/
├── pubspec.yaml
├── README.md                    # This file
└── IMPLEMENTATION_SUMMARY.md    # Detailed specifications
```

## Getting Started (When Implemented)

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Android Studio / Xcode for platform-specific builds
- Gmail API credentials (for Gmail support)
- Microsoft App Registration (for Outlook.com support)

### Installation (Future)

```bash
# Clone repository
git clone https://github.com/kimmeyh/spamfilter-multi.git
cd spamfilter-multi/mobile-app

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run tests
flutter test
```

## OAuth Provider Setup (Future)

### Gmail API Setup
1. Create project in Google Cloud Console
2. Enable Gmail API
3. Create OAuth 2.0 credentials (Android/iOS)
4. Configure consent screen
5. Add credentials to app configuration

### Microsoft Graph API Setup
1. Register app in Azure Portal
2. Configure API permissions (Mail.Read, Mail.ReadWrite)
3. Create client ID for Android/iOS
4. Add redirect URIs
5. Add credentials to app configuration

## Testing Strategy

### Unit Tests
- [ ] Rule evaluation logic
- [ ] Pattern matching (regex compilation)
- [ ] **Credential storage persistence** (critical)
- [ ] Token refresh without deletion
- [ ] YAML import/export

### Integration Tests
- [ ] Email provider adapters
- [ ] OAuth flows
- [ ] **Account persistence across scans** (critical)
- [ ] End-to-end scan workflow

### Security Tests
- [ ] Tokens never in logs
- [ ] Credentials encrypted at rest
- [ ] No plain text storage
- [ ] Token persistence verified

## Development Workflow

When implementing:

1. **Start with Token Management**
   - Implement `CredentialStorage` first
   - Write persistence tests before any other features
   - Verify tokens survive app restart and scans

2. **Follow Mobile App Plan**
   - Reference `../memory-bank/mobile-app-plan.md`
   - Implement phases in order (MVP → Multi-Provider → Advanced)

3. **Maintain Desktop Compatibility**
   - Import/export YAML rules from desktop app
   - Same rule evaluation logic
   - Cross-platform rule sharing

4. **Security First**
   - All credentials through secure storage
   - No shortcuts or plain text storage
   - Regular security audits

## Related Documentation

- `IMPLEMENTATION_SUMMARY.md` - Detailed implementation specs and token management
- `../memory-bank/mobile-app-plan.md` - Full architecture and development plan
- `../memory-bank/memory-bank.json` - Desktop app architecture (for reference)
- `../README.md` - Desktop Python app documentation

## Contributing (Future)

Once implemented:
1. Follow Flutter style guide
2. Write tests for all new features
3. Never store credentials in plain text
4. Document all OAuth setup steps
5. Maintain YAML compatibility with desktop app

## License

Same license as parent project (see `../LICENSE`)

## Support

For questions about:
- **Desktop app**: See `../README.md`
- **Mobile app planning**: See `../memory-bank/mobile-app-plan.md`
- **Token management**: See `IMPLEMENTATION_SUMMARY.md`

## Next Steps

**To begin implementation:**

1. Review `IMPLEMENTATION_SUMMARY.md` for detailed specifications
2. Create Flutter project structure in this directory
3. Implement secure credential storage first (critical for token persistence)
4. Follow Phase 1 of `../memory-bank/mobile-app-plan.md`
5. Write tests to verify token persistence before building UI

**The most critical requirement**: Ensure tokens and accounts are never deleted during email scanning operations.
