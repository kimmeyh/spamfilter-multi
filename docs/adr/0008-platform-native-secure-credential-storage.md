# ADR-0008: Platform-Native Secure Credential Storage

## Status

Accepted

## Date

~2025-10 (project inception, unified store added ~2026-01)

## Context

The spam filter stores sensitive credentials for connecting to email accounts:

- **IMAP accounts (AOL, Yahoo, iCloud)**: Email address and app password
- **Gmail accounts**: OAuth access tokens, refresh tokens, token expiry timestamps, granted scopes
- **Future providers (Outlook)**: OAuth tokens with different scopes

These credentials must be protected from:
- Other applications on the device reading them
- Malware extracting stored passwords
- Credential exposure if the device is lost or stolen
- Credentials appearing in backups, logs, or crash reports

Each platform provides its own secure storage mechanism with hardware-backed encryption:
- **Android**: EncryptedSharedPreferences backed by Android Keystore
- **iOS**: Keychain Services
- **Windows**: Windows Credential Manager
- **macOS**: Keychain Services
- **Linux**: libsecret (GNOME Keyring / KDE Wallet)

## Decision

Use `flutter_secure_storage` (v9.0.0) as a unified wrapper around platform-native secure storage backends. All credentials are stored exclusively through `SecureCredentialsStore`, which provides a consistent API regardless of platform.

**Platform-specific configuration**:
- **Android**: `EncryptedSharedPreferences` enabled (hardware-backed via Android Keystore)
- **iOS**: Keychain accessibility set to `first_unlock_this_device` (credentials available after first device unlock, not synced to other devices)
- **Windows/macOS/Linux**: Default platform backends (Credential Manager, Keychain, libsecret)

**Storage key schema**:
- `credentials_{accountId}_{field}` - Email, password, platformId
- `token_{accountId}_{tokenType}` - OAuth access and refresh tokens
- `token_{accountId}_gmail_tokens` - Complete Gmail token bundle (JSON)
- `saved_accounts` - Comma-separated list of registered account IDs

**Account ID format**: `{platform}-{email}` (e.g., `gmail-user@gmail.com`, `aol-user@aol.com`)

**Migration from legacy storage**: A one-time migration runs at app startup to move tokens from the deprecated `SecureTokenStore` (key format: `gmail_tokens_{accountId}`) to the unified `SecureCredentialsStore` (key format: `token_{accountId}_gmail_tokens`). Migration is non-blocking - failure does not prevent app launch.

**Nothing stored in SQLite or YAML**: Credentials are never written to the SQLite database or YAML files. The database stores rule data and scan results; YAML files store rule definitions. Credentials are exclusively in the secure store.

## Alternatives Considered

### Encrypted SQLite Database
- **Description**: Store credentials in the existing SQLite database with application-level encryption (e.g., SQLCipher)
- **Pros**: Single storage system for all data; familiar SQL queries; built-in backup/restore with database
- **Cons**: Application-level encryption is weaker than OS-level encryption; encryption key must be stored somewhere (circular problem); SQLite database file can be copied off the device; SQLCipher adds a native dependency and build complexity
- **Why Rejected**: Platform-native keystores provide hardware-backed encryption managed by the OS, which is fundamentally more secure than application-level encryption. The OS handles key management, access control, and hardware security module integration

### Encrypted File on Disk
- **Description**: Serialize credentials to JSON, encrypt with AES, and store as a file in the app data directory
- **Pros**: Simple implementation; portable; no dependency on platform keystore availability
- **Cons**: Must manage encryption keys (where to store the key?); file can be copied; no hardware-backed protection; app-level encryption can be reverse-engineered; no OS-level access control
- **Why Rejected**: The fundamental problem of "where do you store the encryption key?" has no good answer at the application level. Platform keystores solve this by delegating key management to the OS and hardware security modules

### Environment Variables or Build-Time Injection Only
- **Description**: Inject credentials at build time via `--dart-define` and never persist them
- **Pros**: Credentials never written to disk; secure as long as build environment is secure
- **Cons**: Users would need to re-authenticate on every app launch; cannot support multiple accounts; does not work for OAuth tokens that are obtained at runtime; build-time injection is for developer credentials (API keys), not user credentials
- **Why Rejected**: User credentials (email passwords, OAuth tokens) are obtained at runtime through sign-in flows and must be persisted for session continuity. Build-time injection is used only for developer secrets (Gmail client ID/secret) that do not change per user

## Consequences

### Positive
- **OS-level security**: Credentials are protected by hardware-backed encryption on Android (Keystore) and iOS (Secure Enclave), providing stronger protection than any application-level scheme
- **No key management burden**: The OS manages encryption keys; the application does not need to store, rotate, or protect encryption keys
- **Platform best practices**: Uses each platform's recommended credential storage mechanism, meeting security audit expectations
- **Separation from data**: Credentials are stored separately from application data (rules, scan results), so database exports/backups never include sensitive credentials
- **Multi-account support**: The key schema (`{platform}-{email}`) naturally supports multiple accounts per provider

### Negative
- **Platform-specific behavior**: Each platform's secure storage has different characteristics (capacity limits, accessibility options, backup behavior), which can cause subtle differences in behavior across platforms
- **No cross-device sync**: Credentials stored in platform-native keystores are device-local. Users must re-authenticate when switching devices (iOS Keychain sync is explicitly disabled via `first_unlock_this_device`)
- **Debugging difficulty**: Secure storage contents cannot be easily inspected during development. Unlike SQLite (which can be opened with a database viewer), secure storage requires platform-specific tooling to inspect
- **Migration complexity**: The legacy `SecureTokenStore` to unified `SecureCredentialsStore` migration adds startup logic and must handle partial migrations gracefully

### Neutral
- **flutter_secure_storage dependency**: The project depends on a third-party package for secure storage abstraction. This package is well-maintained and widely used, but it is an external dependency that must be kept updated for security patches

## References

- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` - Unified credential storage (lines 1-593)
- `mobile-app/lib/adapters/auth/secure_token_store.dart` - Legacy token storage (deprecated, lines 28-131)
- `mobile-app/lib/adapters/auth/token_store.dart` - TokenStore interface and GmailTokens model (lines 25-95)
- `mobile-app/lib/main.dart` - Legacy migration call at startup (lines 53-61)
- `mobile-app/pubspec.yaml` - `flutter_secure_storage: ^9.0.0` dependency
- GitHub Issue #10 - Credential type confusion in SecureCredentialsStore
- GitHub Issue #12 - Missing refresh token storage on Android
