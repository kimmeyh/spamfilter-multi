# Application Architecture

**Purpose**: Detailed architectural documentation for the spamfilter-multi Flutter application

**Last Updated**: January 30, 2026

---

## Overview

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS). The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail) with a single codebase and portable YAML rule sets.

---

## Core Design Principles

### 1. Provider-Agnostic Core
All email filtering logic is independent of email provider implementation. The core business logic works with any email provider through a common interface.

**Benefits**:
- Easy to add new email providers
- Business logic tested independently
- No vendor lock-in

### 2. Adapter Pattern
Email providers (Gmail, AOL, Outlook) implement a common `EmailProvider` interface. Each provider adapter translates provider-specific APIs to the common interface.

**Key Interfaces**:
- `EmailProvider`: Abstract base class for all email providers
- `EmailMessage`: Normalized email representation
- `EvaluationResult`: Standardized rule evaluation result

### 3. State Management
Uses Provider pattern for reactive state management with automatic UI updates.

**Key Providers**:
- `RuleSetProvider`: Manages rule sets with async initialization and automatic persistence
- `EmailScanProvider`: Tracks real-time scan progress (idle, scanning, paused, completed, error)

### 4. Platform-Agnostic Storage
`AppPaths` provides unified file system access across all 5 platforms (Windows, macOS, Linux, Android, iOS).

**Abstractions**:
- Rules: YAML files for portability
- Credentials: Platform-specific secure storage (Keychain, Keystore, Credential Manager)
- Database: SQLite for cross-platform persistence

---

## Component Architecture

### Core Models (`lib/core/models/`)

Immutable data classes representing domain entities.

| Model | Purpose | Key Fields |
|-------|---------|------------|
| **EmailMessage** | Normalized email representation | id, from, subject, body, headers, receivedDate, folderName |
| **RuleSet** | Collection of spam filtering rules | version, settings, rules |
| **Rule** | Individual spam filtering rule | name, enabled, conditions, actions, exceptions, executionOrder |
| **SafeSenderList** | Whitelist of trusted senders | safeSenders (regex patterns) |
| **EvaluationResult** | Result of rule evaluation | shouldDelete, shouldMove, targetFolder, matchedRule, matchedPattern |

**Design Pattern**: Value Objects (immutable, copyWith methods for updates)

---

### Core Services (`lib/core/services/`)

Business logic and domain services.

#### RuleEvaluator

**Purpose**: Evaluates emails against rules to determine actions

**Algorithm**:
1. Check safe senders first (whitelist bypass)
2. Evaluate rules in execution order (ascending)
3. Check exceptions before conditions
4. Return first matching rule's action
5. Return "no match" if no rules match

**Key Methods**:
- `evaluate(EmailMessage message) → EvaluationResult`
- `_matchesConditions(EmailMessage, RuleConditions) → bool`
- `_matchesExceptions(EmailMessage, RuleExceptions) → bool`

#### PatternCompiler

**Purpose**: Compiles and caches regex patterns for efficient matching

**Features**:
- Pattern caching (avoid recompilation)
- Case-insensitive matching
- Error tracking for invalid patterns

**Key Methods**:
- `compile(String pattern) → RegExp`
- `getInvalidPatterns() → List<String>`

#### YamlService

**Purpose**: Loads and parses YAML rule files

**Features**:
- Schema validation
- Error handling with detailed messages
- Support for both rules.yaml and rules_safe_senders.yaml

#### EmailScanner

**Purpose**: Orchestrates email fetching and filtering

**Workflow**:
1. Fetch emails from provider (EmailProvider)
2. Evaluate each email (RuleEvaluator)
3. Execute actions (delete, move, mark safe sender)
4. Update progress (EmailScanProvider)
5. Return results

---

### Adapters (`lib/adapters/`)

Provider-specific implementations following the adapter pattern.

#### Email Providers

**EmailProvider Interface**:
```dart
abstract class EmailProvider {
  Future<List<EmailMessage>> fetchEmails(String folder, int limit);
  Future<void> deleteEmail(String emailId);
  Future<void> moveEmail(String emailId, String targetFolder);
  Future<List<String>> listFolders();
}
```

**Implementations**:

| Adapter | Protocol | OAuth | Platform Support |
|---------|----------|-------|------------------|
| **GenericImapAdapter** | IMAP | No (username/password) | AOL, Yahoo, ProtonMail |
| **GmailApiAdapter** | Gmail REST API | Yes (Google OAuth) | Gmail (all platforms) |
| **OutlookAdapter** | Outlook REST API | Yes (MSAL) | Outlook.com (deferred) |

#### Storage Adapters

**AppPaths**:
- Platform-agnostic file system helper
- Provides paths for: rules, credentials, backups, logs, databases
- Uses `path_provider` for platform-specific directories

**LocalRuleStore**:
- YAML file persistence
- Auto-defaults if files missing
- Timestamped backups before overwrite
- Atomic writes (write to temp, then move)

**SecureCredentialsStore**:
- Platform-specific encrypted storage:
  - **iOS/macOS**: Keychain
  - **Android**: Keystore
  - **Windows**: Credential Manager
  - **Linux**: libsecret

#### Auth Adapters

**GoogleAuthService**:
- Gmail OAuth flow
- **Android**: Native Google Sign-In SDK
- **Windows/Desktop**: WebView/browser with loopback redirect
- Token refresh with automatic retry

**SecureTokenStore**:
- OAuth token persistence
- Encrypted storage for refresh tokens
- Access token caching (in-memory)

---

### State Management (`lib/core/providers/`)

Reactive state using Provider pattern.

#### RuleSetProvider

**Purpose**: Manages rule sets with async initialization

**State**:
- `ruleSet`: Current loaded RuleSet
- `safeSenderList`: Current Safe Sender List
- `isLoading`: Load state indicator

**Methods**:
- `initialize()`: Async load from YAML
- `saveRules()`: Persist to YAML
- `addSafeSender(String pattern)`: Add to whitelist

**Lifecycle**: Initialized in `main.dart` before MaterialApp

#### EmailScanProvider

**Purpose**: Tracks real-time scan progress

**State**:
- `status`: ScanStatus (idle, scanning, paused, completed, error)
- `totalEmails`: Total emails to process
- `processedCount`: Emails processed so far
- `deletedCount`, `movedCount`, `safeSendersCount`, `noRuleCount`, `errorCount`: Categorized counts
- `results`: List of EmailActionResult

**Methods**:
- `startScan(int totalEmails)`: Initialize scan
- `recordResult(EmailActionResult)`: Record email action
- `completeScan()`: Mark scan complete
- `getSummary()`: Get scan statistics

**UI Binding**: Results screen uses `context.watch<EmailScanProvider>()` for reactive updates

---

## Data Flow

### Application Initialization

```
main.dart
  ├─→ MultiProvider
  │     ├─→ RuleSetProvider.initialize() [Load YAML rules]
  │     └─→ EmailScanProvider() [Create scan state]
  └─→ MaterialApp
        └─→ AccountSelectionScreen [Entry point]
```

### Email Scanning Flow

```
User clicks "Start Scan"
  ↓
ScanProgressScreen
  ├─→ EmailScanner.scanInbox()
  │     ├─→ EmailProvider.fetchEmails() [Get emails from server]
  │     ├─→ For each email:
  │     │     ├─→ RuleEvaluator.evaluate() [Check rules]
  │     │     ├─→ EmailProvider.deleteEmail() OR moveEmail() [Execute action]
  │     │     └─→ EmailScanProvider.recordResult() [Update UI]
  │     └─→ EmailScanProvider.completeScan()
  └─→ Navigate to ResultsDisplayScreen
```

### Rule Evaluation Flow

```
RuleEvaluator.evaluate(EmailMessage)
  ├─→ Check SafeSenderList.isSafe(email.from)
  │     └─→ If safe: Return EvaluationResult.safeSender()
  ├─→ Sort rules by executionOrder
  ├─→ For each enabled rule:
  │     ├─→ Check exceptions (if any)
  │     │     └─→ If matched: Skip rule
  │     ├─→ Check conditions (AND/OR logic)
  │     │     ├─→ Match from patterns
  │     │     ├─→ Match subject patterns
  │     │     ├─→ Match body patterns
  │     │     └─→ Match header patterns
  │     └─→ If matched: Return EvaluationResult(action)
  └─→ If no match: Return EvaluationResult.noMatch()
```

---

## Directory Structure

```
mobile-app/
├── lib/
│   ├── core/                    # Business logic (provider-agnostic)
│   │   ├── models/             # Domain entities (EmailMessage, RuleSet, etc.)
│   │   ├── services/           # Business logic (RuleEvaluator, EmailScanner)
│   │   ├── providers/          # State management (RuleSetProvider, EmailScanProvider)
│   │   └── storage/            # Persistence (DatabaseHelper, MigrationManager)
│   ├── adapters/                # Provider implementations
│   │   ├── email_providers/    # Email adapters (Gmail, IMAP, Outlook)
│   │   ├── storage/            # Storage adapters (AppPaths, LocalRuleStore)
│   │   └── auth/               # Auth adapters (GoogleAuthService)
│   └── ui/                      # Flutter screens and widgets
│       ├── screens/            # Full-screen pages
│       └── widgets/            # Reusable components
├── test/                        # Tests
│   ├── unit/                   # Unit tests (models, services)
│   ├── integration/            # Integration tests (adapters, workflows)
│   ├── adapters/               # Adapter-specific tests
│   └── fixtures/               # Test data and mocks
└── android/                     # Android-specific configuration
```

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **UI Framework** | Flutter 3.x | Cross-platform UI |
| **Language** | Dart 3.x | Application logic |
| **State Management** | Provider | Reactive state |
| **Local Storage** | SQLite (sqflite) | Persistent data |
| **Secure Storage** | flutter_secure_storage | Credentials, tokens |
| **Networking** | http, googleapis | REST APIs |
| **Email** | enough_mail (IMAP) | AOL, Yahoo, ProtonMail |
| **OAuth** | google_sign_in, flutter_appauth | Gmail, Outlook auth |
| **Logging** | logger | Debug and error logs |

---

## Design Patterns

| Pattern | Where Used | Purpose |
|---------|------------|---------|
| **Adapter** | EmailProvider implementations | Unify different email APIs |
| **Provider (State Management)** | RuleSetProvider, EmailScanProvider | Reactive UI updates |
| **Repository** | LocalRuleStore, SecureCredentialsStore | Abstract storage layer |
| **Strategy** | RuleEvaluator | Pluggable pattern matching |
| **Observer** | EmailScanProvider listeners | Real-time progress updates |
| **Factory** | EmailProvider.create() | Provider instantiation |

---

## Platform-Specific Considerations

### Android
- Uses native Google Sign-In SDK for Gmail OAuth
- Requires Firebase configuration (google-services.json)
- Emulator must use "Google APIs" image for Google Sign-In
- Multi-account support via unique accountId

### Windows
- Uses WebView/browser OAuth flow for Gmail
- Requires Desktop OAuth client credentials
- Loopback redirect URI: `http://localhost:8080/oauth/callback`
- Build via `build-windows.ps1` script (injects secrets)

### iOS/macOS
- Not yet validated but architecture supports
- OAuth flow via native browser
- Keychain for secure storage

### Linux
- Not yet validated but architecture supports
- OAuth flow via native browser
- libsecret for secure storage

---

## Security Considerations

### Credentials Storage
- **Never commit secrets**: secrets.dev.json, google-services.json, client_secret_*.json are gitignored
- **Encrypted storage**: All credentials stored via flutter_secure_storage
- **Platform-native**: Uses OS-provided secure storage (Keychain, Keystore, Credential Manager)

### OAuth Tokens
- Access tokens cached in-memory only
- Refresh tokens stored encrypted
- Automatic token refresh before expiry
- No tokens logged (log "token refreshed" not token value)

### Rule Patterns
- Regex validation to prevent ReDoS attacks
- Invalid patterns logged and tracked
- No user input directly executed as code

---

## Testing Strategy

### Unit Tests
- Models: Immutability, copyWith, serialization
- Services: Business logic, edge cases
- Providers: State transitions, notifications

### Integration Tests
- Adapters: Email provider operations
- Workflows: End-to-end scanning flow
- Storage: YAML persistence, database operations

### Manual Integration Tests
- Platform-specific OAuth flows
- Email operations on real accounts
- UI workflows on target devices

**Target Coverage**: 95%+ for core business logic

---

## Performance Optimization

### Pattern Caching
- `PatternCompiler` caches compiled regex patterns
- Avoid recompilation for frequently-used patterns

### Progressive UI Updates
- Throttle updates to every 10 emails OR 3 seconds
- Prevents UI jank during large scans

### Lazy Loading
- Rules loaded on-demand (not at app startup)
- Email messages fetched in batches

### Asynchronous Operations
- All I/O operations are async (file, network, database)
- Use isolates for CPU-intensive tasks (future enhancement)

---

## Future Architecture Enhancements

### Database Migration (In Progress)
- Move from YAML to SQLite for rules storage
- Enable faster queries and updates
- Support for rule versioning and rollback

### Background Scanning (Planned)
- Platform-specific background tasks (WorkManager, Task Scheduler)
- Periodic email scanning without user interaction

### Rule Sync (Planned)
- Cloud sync for rules across devices
- Conflict resolution for multi-device editing

### Plugin Architecture (Future)
- Extensible rule actions (custom scripts)
- Third-party email provider plugins

---

**Document Version**: 1.0
**Created**: January 30, 2026
**Related Documents**:
- `docs/RULE_FORMAT.md` - YAML rule specification
- `CLAUDE.md` - Primary development guide
- `docs/SPRINT_PLANNING.md` - Development methodology
