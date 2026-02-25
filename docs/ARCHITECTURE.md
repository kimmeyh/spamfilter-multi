# Application Architecture

**Purpose**: Detailed architectural documentation for the spamfilter-multi Flutter application

**Last Updated**: February 24, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** (this doc) | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Overview

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS). The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, iCloud) with a single codebase, SQLite database for rules and scan history, and portable YAML rule export for version control.

**Current Status**: Sprint 17 complete (Feb 2026) - 977 tests passing, 28 skipped, 0 failures.

---

## Core Design Principles

### 1. Provider-Agnostic Core
All email filtering logic is independent of email provider implementation. The core business logic works with any email provider through the `SpamFilterPlatform` interface.

**Benefits**:
- Easy to add new email providers
- Business logic tested independently
- No vendor lock-in

### 2. Adapter Pattern (ADR-0002)
Email providers implement the `SpamFilterPlatform` abstract class. Each provider adapter translates provider-specific APIs to the common interface. A `PlatformRegistry` factory manages adapter instantiation.

**Key Interfaces**:
- `SpamFilterPlatform`: Primary abstract class for all email providers (replaces legacy `EmailProvider`)
- `EmailMessage`: Normalized email representation
- `EvaluationResult`: Standardized rule evaluation result with pattern type tracking

### 3. Four Scan Modes (ADR-0006)
Progressive scan modes with boolean enforcement flags to prevent accidental data loss:
- `readonly` (default): Scan only, no modifications
- `testLimit`: Modify up to N emails, then stop
- `testAll`: Evaluate safe senders only
- `fullScan`: Production mode - permanent delete/move operations

### 4. State Management (ADR-0009)
Uses Provider pattern (`ChangeNotifier`) for reactive state management with automatic UI updates.

**Key Providers**:
- `RuleSetProvider`: Manages rule sets and safe senders with dual-write persistence (database + YAML)
- `EmailScanProvider`: Tracks real-time scan progress with throttled UI updates and scan history persistence

### 5. Dual-Write Storage (ADR-0004)
SQLite is the authoritative storage for rules and scan data. YAML files are exported as a secondary write for version control and portability. On app start, a one-time YAML-to-database migration runs if the database is empty.

### 6. Platform-Agnostic Storage (ADR-0012)
`AppPaths` provides unified file system access across all 5 platforms (Windows, macOS, Linux, Android, iOS).

**Platform Paths**:
- **Windows**: `C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\`
- **Android**: `/data/user/0/com.example.spam_filter_mobile/files`
- **macOS**: `~/Library/Application Support/spam_filter_mobile`
- **Linux**: `~/.local/share/spam_filter_mobile`
- **iOS**: `/Library/Application Support/spam_filter_mobile`

**Subdirectories**: `rules/`, `credentials/`, `backups/`, `logs/`; SQLite database at root.

---

## Component Architecture

### Core Models (`lib/core/models/`)

Immutable data classes representing domain entities.

| Model | Purpose | Key Fields |
|-------|---------|------------|
| **EmailMessage** | Normalized email representation | id, from, subject, body, headers, receivedDate, folderName |
| **RuleSet** | Collection of spam filtering rules | version, settings, rules |
| **Rule** | Individual spam filtering rule | name, enabled, conditions, actions, exceptions, executionOrder, metadata |
| **RuleConditions** | Rule matching criteria | type (AND/OR), from[], header[], subject[], body[] |
| **RuleActions** | Actions to perform on match | delete, moveToFolder |
| **RuleExceptions** | Exception patterns (skip rule if matched) | Same structure as RuleConditions |
| **SafeSenderList** | Whitelist of trusted senders | safeSenders (regex patterns), findMatch() returns pattern + type |
| **EvaluationResult** | Result of rule evaluation | shouldDelete, shouldMove, targetFolder, matchedRule, matchedPattern, matchedPatternType, isSafeSender |
| **BatchActionResult** | Aggregate result of batch operations | successCount, failureCount, errors[] |
| **ProviderEmailIdentifier** | Unique email ID per provider | Format: `{platformId}-{email}` |

**Safe Sender Pattern Types** (detected automatically from pattern structure):
- `exact_email`: `^user@domain\.com$`
- `exact_domain`: `^[^@\s]+@domain\.com$`
- `entire_domain`: `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$`

**Design Pattern**: Value Objects (immutable, copyWith methods for updates)

---

### Core Services (`lib/core/services/`)

Business logic and domain services.

#### RuleEvaluator

**Purpose**: Evaluates emails against rules to determine actions (ADR-0005)

**Algorithm**:
1. Check safe senders first (whitelist has priority)
2. Evaluate rules in execution order (ascending)
3. Check exceptions before conditions
4. Return first matching rule's action (first match wins, no cascade)
5. Return "no match" if no rules match

**Key Methods**:
- `evaluate(EmailMessage message) -> EvaluationResult`
- `_matchesConditions(EmailMessage, RuleConditions) -> bool`
- `_matchesExceptions(EmailMessage, RuleExceptions) -> bool`

#### PatternCompiler (ADR-0023)

**Purpose**: Compiles and caches regex patterns for efficient matching

**Features**:
- `HashMap<String, RegExp>` cache with ~100x speedup (2.1ms -> 0.18ms)
- Case-insensitive matching
- Python-style inline flag stripping (`(?i)`, `(?m)`, `(?s)`, `(?x)`)
- Error tracking for invalid patterns (graceful fallback to never-matching regex)
- Cache hit/miss statistics

**Key Methods**:
- `compile(String pattern) -> RegExp`
- `getStats() -> Map<String, int>` (cached_patterns, cache_hits, cache_misses, failed_patterns)

**Known Issue**: Cache grows unbounded (Issue #16)

#### EmailScanner

**Purpose**: Orchestrates the full scanning pipeline

**Workflow**:
1. Get platform adapter via `PlatformRegistry.getPlatform(platformId)`
2. Load credentials from `SecureCredentialsStore`
3. Connect to email provider
4. Initialize scan result persistence (database)
5. For each folder: fetch messages, evaluate against rules, take actions (batch operations)
6. Persist individual email actions to database
7. Update UI progress (throttled: every 10 emails OR every 2 seconds)
8. Finalize scan results

#### RuleConflictDetector

**Purpose**: Warns users when existing rules or safe senders would prevent a new rule from being evaluated

#### Background Scanning Services

| Service | Purpose |
|---------|---------|
| **BackgroundModeService** | Detects `--background-scan` CLI flag in main.dart |
| **BackgroundScanWindowsWorker** | Headless worker for Windows Task Scheduler scans |
| **BackgroundScanWorker** | Android WorkManager callback dispatcher |
| **BackgroundScanManager** | Schedule/cancel background scans |
| **WindowsTaskSchedulerService** | Create/manage Windows Task Scheduler tasks (ADR-0014) |
| **WindowsNotificationService** | Windows toast notifications via PowerShell WinRT (ADR-0018) |
| **WindowsSystemTrayService** | System tray icon with context menu (ADR-0019) |
| **PowershellScriptGenerator** | Generates PowerShell scripts for Task Scheduler and notifications |

#### Other Services

| Service | Purpose |
|---------|---------|
| **YamlService** | Load/parse YAML rule files |
| **YamlExportService** | Normalize, sort, deduplicate, export rules to YAML (lowercase, trimmed, single quotes) |
| **SafeSenderEvaluator** | Pattern matching with exception support |
| **EmailBodyParser** | Extract/decode email bodies |
| **EmailAvailabilityChecker** | Check if email provider is reachable |
| **AppLogger** | Keyword-based logging (EMAIL, RULES, EVAL, DB, AUTH, SCAN, ERROR, PERF, UI, DEBUG) |

---

### Adapters (`lib/adapters/`)

Provider-specific implementations following the adapter pattern.

#### Email Provider Interface

**SpamFilterPlatform** (primary interface):
```dart
abstract class SpamFilterPlatform {
  String get platformId;           // 'gmail', 'aol', 'yahoo', 'imap', 'demo'
  String get displayName;          // Human-readable name
  AuthMethod get supportedAuthMethod;

  Future<void> loadCredentials(Credentials credentials);
  Future<List<EmailMessage>> fetchMessages({required int daysBack, required List<String> folderNames});
  Future<void> takeAction({required EmailMessage message, required FilterAction action});
  Future<void> moveToFolder({required EmailMessage message, required String targetFolder});
  void setDeletedRuleFolder(String? folderName);
}
```

Note: The legacy `EmailProvider` abstract class still exists but is only used for the `Credentials` class definition.

#### Platform Implementations

| Adapter | Protocol | Auth | Factory | Key Details |
|---------|----------|------|---------|-------------|
| **GmailApiAdapter** | Gmail REST API | OAuth 2.0 | `PlatformRegistry.getPlatform('gmail')` | Uses `googleapis` package, batch operations via `BatchOperationsMixin`, Gmail labels |
| **GenericIMAPAdapter** | IMAP | Username/password | `.aol()`, `.yahoo()`, `.icloud()`, `.custom()` | Uses `enough_mail` package, UID-based operations (not sequence IDs), reconnects every 50 ops |
| **MockEmailProvider** | None (in-memory) | None | `PlatformRegistry.getPlatform('demo')` | 55 synthetic emails across 5 categories (ADR-0020) |

**PlatformRegistry** (Factory Pattern):
```dart
static final Map<String, SpamFilterPlatform Function()> _factories = {
  'aol': () => GenericIMAPAdapter.aol(),
  'gmail': () => GmailApiAdapter(),
  'yahoo': () => GenericIMAPAdapter.yahoo(),
  'icloud': () => GenericIMAPAdapter.icloud(),
  'imap': () => GenericIMAPAdapter.custom(),
  'demo': () => MockEmailProvider(),
};
```

**Junk Folder Config** (ADR-0024):
- AOL: `['Bulk Mail', 'Spam']`
- Gmail: `['Spam', 'Trash']`
- Outlook: `['Junk Email', 'Spam']`
- Yahoo: `['Bulk', 'Spam']`
- iCloud: `['Junk', 'Trash']`

#### Batch Operations (BatchOperationsMixin)

Both `GmailApiAdapter` and `GenericIMAPAdapter` implement `BatchOperationsMixin` for efficient bulk operations:
- `batchDelete()`: Delete multiple emails in one IMAP/API call
- `batchMove()`: Move multiple emails in one call
- `batchMarkAsRead()`: Mark multiple emails as read

Uses IMAP UID sequence sets to reduce round-trips from 3N to ~3 batch operations.

#### Auth Adapters

**GoogleAuthService** (ADR-0011):
- **Android/iOS**: `google_sign_in` native SDK
- **Windows/macOS/Linux**: Browser-based OAuth with PKCE + loopback redirect (localhost:8080)
- Scopes: `gmail.modify`, `userinfo.email`
- Token refresh with automatic retry via `getValidAccessToken()`

**SecureCredentialsStore** (ADR-0008):
- Platform-native encrypted storage via `flutter_secure_storage`
- Windows: Credential Manager, Android: Keystore, iOS: Keychain, Linux: libsecret
- Methods: `getCredentials()`, `saveCredentials()`, `deleteCredentials()`, `getSavedAccounts()`
- Legacy migration: `migrateFromLegacyTokenStore()`

#### Storage Adapters

**AppPaths** (ADR-0012):
- Lazy initialization with safety guards
- Subdirectories: `rules/`, `credentials/`, `backups/`, `logs/`
- SQLite database at root

**LocalRuleStore**:
- YAML file persistence (secondary write target)
- Timestamped backups before overwrite

---

### Database Layer (`lib/core/storage/`)

#### Schema (ADR-0010)

SQLite database with the following tables:

| Table | Purpose | Key Fields |
|-------|---------|------------|
| **accounts** | Account metadata tracking | account_id (PK), platform_id, email, display_name, date_added, last_scanned |
| **scan_results** | Aggregate scan results per scan | id (PK), account_id (FK), scan_type, scan_mode, started_at, completed_at, total_emails, processed/deleted/moved/safe/no_rule/error counts, status, folders_scanned |
| **email_actions** | Individual email results within a scan | id (PK), scan_result_id (FK), email_id, email_from, email_subject, email_folder, action_type, matched_rule_name, matched_pattern, is_safe_sender, success |
| **rules** | Imported rules (dual-write from YAML) | name (UNIQUE), enabled, execution_order, condition_type, condition_from/header/subject/body, action_delete, action_move_to_folder, exception fields, metadata |
| **safe_senders** | Whitelist patterns (dual-write from YAML) | pattern (UNIQUE), added_date, source, enabled |
| **app_settings** | Global app settings | key-value pairs |
| **account_settings** | Per-account setting overrides (ADR-0013) | account_id, setting key-value pairs |
| **background_scan_log** | Background scan execution logs | timestamp, account_id, status, stats |

**Indexes**: 10+ targeted indexes for fast lookups (by platform, account, completion time, scan ID, folder, no-rule matches).

**Settings Inheritance** (ADR-0013): Three-tier fallback: account_settings -> app_settings -> hardcoded defaults.

#### Store Classes

| Store | Purpose |
|-------|---------|
| **DatabaseHelper** | SQLite singleton, table definitions, migrations |
| **MigrationManager** | Transaction-wrapped schema migrations (ADR-0021) |
| **RuleDatabaseStore** | CRUD for rules table |
| **SafeSenderDatabaseStore** | CRUD for safe_senders table |
| **ScanResultStore** | Persist/query scan results and history |
| **EmailActionStore** | Persist individual email actions per scan |
| **SettingsStore** | App and account settings persistence |
| **AccountStore** | Account metadata |
| **BackgroundScanLogStore** | Background scan execution logs |
| **UnmatchedEmailStore** | Track emails with no rule match |
| **LocalRuleStore** | YAML import/export (file-based, secondary to database) |

#### Dual-Write Pattern (ADR-0004)

```
User adds rule in UI
    |
    v
RuleSetProvider.addRule()
    |
    v
Writes to: RuleDatabaseStore (PRIMARY - used by rule evaluator)
Writes to: LocalRuleStore.exportRules() (SECONDARY - for version control)
    |
    v
Database rules updated immediately
YAML rules exported for git tracking
```

---

### State Management (`lib/core/providers/`)

Reactive state using Provider pattern (ADR-0009).

#### RuleSetProvider

**Purpose**: Manages rules and safe senders with caching and database persistence

**State**:
- `ruleSet`: Current loaded RuleSet
- `safeSenderList`: Current Safe Sender List
- `loadingState`: RuleLoadingState (loading, success, error)
- Stores: `RuleDatabaseStore` (primary), `SafeSenderDatabaseStore`, `LocalRuleStore` (secondary YAML), `PatternCompiler`

**Methods**:
- `initialize()`: Load rules from database + run YAML-to-DB migration if needed
- `addRule(Rule)`, `deleteRule(name)`: CRUD with dual-write
- `addSafeSender(pattern)`, `deleteSafeSender(pattern)`: Whitelist management
- `exportToYaml()`: Export to YAML for version control

**Lifecycle**: Initialized in `main.dart` within MultiProvider

#### EmailScanProvider

**Purpose**: Tracks real-time scan progress with throttled UI updates and scan history persistence

**State**:
- `status`: ScanStatus (idle, scanning, paused, completed, error)
- `totalEmails`, `processedCount`: Progress tracking
- `deletedCount`, `movedCount`, `safeSenderCount`, `noRuleCount`, `errorCount`: Categorized counts
- `currentEmail`, `currentFolder`, `statusMessage`: Current scan context
- `scanResultStore`, `currentScanResultId`: Persistence handles

**Methods**:
- `startScan(totalEmails, scanType, foldersScanned)`: Initialize scan with persistence
- `updateProgress(email, message)`: Report progress (throttled: every 10 emails OR 2 seconds, ADR-0022)
- `completeScan()`: Finalize results and persist
- `setCurrentFolder(folderName)`: Track folder being scanned
- `initializePersistence()`: Setup database stores for scan history

**UI Binding**: UI screens use `context.watch<EmailScanProvider>()` for reactive updates

---

## Data Flow

### Application Initialization (main.dart)

```
main.dart
  1. WidgetsFlutterBinding.ensureInitialized()
  2. sqfliteFfiInit() [desktop platforms only]
  3. BackgroundModeService.initialize(args)
  4. IF --background-scan flag:
       -> BackgroundScanWindowsWorker.executeBackgroundScan()
       -> exit(0)
  5. SecureCredentialsStore.migrateFromLegacyTokenStore()
  6. WindowsSystemTrayService.initialize() [Windows only]
  7. WindowsNotificationService.initialize() [Windows only]
  8. WindowsTaskSchedulerService.verifyAndRepairTaskPath() [Windows release only]
  9. WindowsTaskSchedulerService.ensureTaskExists() [Windows release only]
  10. MultiProvider
        |- RuleSetProvider
        |- EmailScanProvider
  11. runApp(SpamFilterApp)
        -> MainNavigationScreen [Entry point]
```

### Email Scanning Flow

```
User clicks "Start Live Scan"
  |
  v
ScanProgressScreen
  |- EmailScanner.scanInbox(daysBack, folderNames, scanType)
  |    |- PlatformRegistry.getPlatform(platformId)
  |    |- SecureCredentialsStore.getCredentials(accountId)
  |    |- platform.loadCredentials(credentials)
  |    |- EmailScanProvider.initializePersistence()
  |    |- EmailScanProvider.startScan(totalEmails, scanType, folders)
  |    |- FOR EACH folder:
  |    |    |- EmailScanProvider.setCurrentFolder(folderName)
  |    |    |- platform.fetchMessages(daysBack, [folder])
  |    |    |- Increment found count
  |    |- FOR EACH message:
  |    |    |- RuleEvaluator.evaluate(message) -> EvaluationResult
  |    |    |- platform.takeAction(message, action) [if not readonly]
  |    |    |- EmailScanProvider.addEmailAction() [persist to database]
  |    |    |- EmailScanProvider.updateProgress() [throttled UI update]
  |    |- EmailScanProvider.completeScan()
  |
  v
Navigate to ResultsDisplayScreen
```

### Background Scanning Flow (Windows, ADR-0014)

```
Windows Task Scheduler triggers executable with --background-scan flag
  |
  v
main.dart detects BackgroundModeService.isBackgroundMode
  |
  v
BackgroundScanWindowsWorker.executeBackgroundScan()
  |- Initialize AppPaths, DatabaseHelper, RuleSetProvider
  |- Get all saved account IDs from SecureCredentialsStore
  |- FOR EACH account with background scanning enabled:
  |    |- Load per-account settings (folders, scan mode, frequency)
  |    |- Create EmailScanner
  |    |- scanInbox(daysBack, folders, scanType='background')
  |    |- Log results to BackgroundScanLogStore
  |    |- Send Windows toast notification
  |- Exit with code 0 (success) or 1 (failure)
```

### Rule Evaluation Flow (ADR-0005)

```
RuleEvaluator.evaluate(EmailMessage)
  |- Check SafeSenderList.findMatch(email.from)
  |    -> If match: Return EvaluationResult.safeSender(pattern, patternType)
  |- Sort rules by executionOrder
  |- For each enabled rule:
  |    |- Check exceptions first
  |    |    -> If matched: Skip rule
  |    |- Check conditions (AND/OR logic)
  |    |    |- Match from patterns
  |    |    |- Match subject patterns
  |    |    |- Match body patterns
  |    |    |- Match header patterns
  |    -> If matched: Return EvaluationResult(action, matchedRule, matchedPattern)
  -> If no match: Return EvaluationResult.noMatch()
```

---

## UI Layer (`lib/ui/`)

### Screens (19 screens)

| Screen | Purpose |
|--------|---------|
| **main_navigation_screen.dart** | Entry point after auth - bottom nav, tab-based UI |
| **platform_selection_screen.dart** | Select email provider (Gmail, AOL, Yahoo, etc.) |
| **account_setup_screen.dart** | Configure account credentials |
| **account_selection_screen.dart** | Switch between accounts |
| **account_maintenance_screen.dart** | Manage accounts (add/remove/edit) |
| **folder_selection_screen.dart** | Choose which folders to scan (dynamic discovery) |
| **scan_progress_screen.dart** | Real-time scan progress (Manual Scan screen) |
| **results_display_screen.dart** | Scan results summary with filter chips |
| **process_results_screen.dart** | Review results before finalizing |
| **scan_history_screen.dart** | Historical scan results (manual + background) with retention |
| **background_scan_log_screen.dart** | Background scan execution logs |
| **background_scan_progress_screen.dart** | Background scan progress display |
| **rules_management_screen.dart** | View/edit/delete rules |
| **rule_quick_add_screen.dart** | Quick-add rule from email |
| **safe_senders_management_screen.dart** | View/edit/delete whitelist |
| **safe_sender_quick_add_screen.dart** | Quick-add safe sender from email |
| **email_detail_view.dart** | Full email details display |
| **settings_screen.dart** | App configuration (Manual Scan, Background, Account tabs) |
| **gmail_oauth_screen.dart** | Gmail OAuth flow (legacy WebView) |

### Widgets (`lib/ui/widgets/`)

| Widget | Purpose |
|--------|---------|
| **app_bar_with_exit.dart** | AppBar with Exit button and confirmation dialog |
| **empty_state.dart** | Empty state placeholder |
| **error_display.dart** | Error display component |
| **skeleton_loader.dart** | Loading skeleton UI |

---

## Directory Structure

```
mobile-app/
|- lib/
|   |- core/                    # Business logic (provider-agnostic)
|   |   |- models/             # Domain entities (EmailMessage, RuleSet, etc.)
|   |   |- services/           # Business logic (RuleEvaluator, EmailScanner, background services)
|   |   |- providers/          # State management (RuleSetProvider, EmailScanProvider)
|   |   |- storage/            # Persistence (DatabaseHelper, Store classes, MigrationManager)
|   |   |- utils/              # Utilities (AppLogger, PatternNormalization)
|   |- adapters/                # Provider implementations
|   |   |- email_providers/    # Email adapters (Gmail, IMAP, Mock, PlatformRegistry)
|   |   |- storage/            # Storage adapters (AppPaths, LocalRuleStore, SecureCredentialsStore)
|   |   |- auth/               # Auth adapters (GoogleAuthService, SecureTokenStore)
|   |   |- gmail/              # Gmail API client wrapper
|   |- ui/                      # Flutter screens and widgets
|       |- screens/            # 19 full-screen pages
|       |- widgets/            # Reusable components
|       |- theme/              # AppTheme (Material Design)
|       |- utils/              # Accessibility helpers
|- test/                        # Tests (977 passing, 28 skipped)
|   |- unit/                   # Unit tests (models, services)
|   |- integration/            # Integration tests (adapters, workflows)
|   |- adapters/               # Adapter-specific tests
|   |- core/                   # Core logic tests
|   |- ui/                     # UI tests
|   |- fixtures/               # Test data and mocks
|- android/                     # Android-specific configuration
|- scripts/                     # Build automation (PowerShell)
```

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **UI Framework** | Flutter 3.x | Cross-platform UI (5 platforms) |
| **Language** | Dart 3.x | Application logic |
| **State Management** | Provider (v6.1.0) | Reactive state via ChangeNotifier |
| **Local Storage** | SQLite (sqflite/sqflite_ffi) | Persistent data (8 tables, 10+ indexes) |
| **Secure Storage** | flutter_secure_storage | Credentials, tokens (OS-native keystores) |
| **Networking** | http, googleapis | REST APIs (Gmail) |
| **Email** | enough_mail | IMAP protocol (AOL, Yahoo, iCloud) |
| **OAuth** | google_sign_in (mobile), flutter_appauth (desktop) | Gmail authentication |
| **System Tray** | system_tray (v2.0.3), window_manager (v0.3.7) | Windows desktop integration |
| **Logging** | logger (v2.0.0) | Keyword-based logging via AppLogger |

---

## Design Patterns

| Pattern | Where Used | Purpose |
|---------|------------|---------|
| **Adapter** | SpamFilterPlatform implementations | Unify different email provider APIs |
| **Factory** | PlatformRegistry.getPlatform() | Provider instantiation by platform ID |
| **Provider (State)** | RuleSetProvider, EmailScanProvider | Reactive UI updates via ChangeNotifier |
| **Dual-Write** | RuleDatabaseStore + LocalRuleStore | SQLite primary, YAML secondary for version control |
| **Repository** | Store classes (RuleDatabaseStore, etc.) | Abstract storage layer |
| **Strategy** | RuleEvaluator | Pluggable pattern matching (AND/OR conditions) |
| **Observer** | ChangeNotifier listeners | Real-time progress updates |
| **Singleton** | DatabaseHelper, PatternCompiler | Single instance per app lifecycle |
| **Mixin** | BatchOperationsMixin | Batch delete/move/mark-as-read for adapters |

---

## Platform-Specific Considerations

### Android
- Uses native `google_sign_in` SDK for Gmail OAuth
- Requires Firebase configuration (`google-services.json`) for Google Sign-In
- Emulator must use "Google APIs" image (NOT AOSP) for Google Sign-In
- Multi-account support via unique accountId (`{platformId}-{email}`)
- Background scanning via WorkManager (implementation in progress)

### Windows (Primary Development Platform)
- Browser-based OAuth with PKCE + loopback redirect (localhost:8080)
- Requires Desktop OAuth client credentials in `secrets.dev.json`
- Build via `build-windows.ps1` script (injects secrets via `--dart-define-from-file`)
- System tray integration with context menu (ADR-0019)
- Toast notifications via PowerShell WinRT (ADR-0018)
- Background scanning via Windows Task Scheduler (ADR-0014)
- Task Scheduler auto-repair on app startup (executable path fix after rebuild)

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

### Credentials Storage (ADR-0008)
- **Never commit secrets**: secrets.dev.json, google-services.json, client_secret_*.json are gitignored
- **Encrypted storage**: All credentials stored via flutter_secure_storage (OS-native keystores)
- **Platform-native**: Keychain (iOS/macOS), Keystore (Android), Credential Manager (Windows), libsecret (Linux)

### OAuth Tokens (ADR-0011)
- Access tokens cached in-memory only
- Refresh tokens stored encrypted in SecureCredentialsStore
- Automatic token refresh before expiry via `getValidAccessToken()`
- PKCE used for desktop OAuth flows (public client, no client secret)
- No tokens logged (log "token refreshed" not token value)

### Email Safety (ADR-0006, ADR-0007)
- Four progressive scan modes with boolean enforcement flags
- Default mode is `readonly` (no modifications)
- All "delete" actions move to trash (recoverable), not permanent delete
- Gmail: `trash()` API; IMAP: `UID MOVE` to Trash folder
- IMAP uses UIDs (not sequence IDs) to prevent the "100-delete limit" bug

### Rule Patterns (ADR-0003)
- All patterns are regex-only (legacy wildcard mode removed)
- Invalid patterns logged, tracked, and replaced with never-matching fallback
- Python-style inline flags automatically stripped for Dart compatibility
- No user input directly executed as code

---

## Testing Strategy

**Current State**: 977 tests passing, 28 skipped, 0 failures (Sprint 17)

### Unit Tests
- Models: Immutability, copyWith, serialization
- Services: RuleEvaluator, PatternCompiler, RuleConflictDetector, PowershellScriptGenerator
- Providers: State transitions, notifications, persistence

### Integration Tests
- Adapters: Email provider operations, batch operations
- Workflows: End-to-end scanning flow, scan result persistence
- Storage: Database operations, YAML persistence, settings inheritance

### Manual Integration Tests
- Platform-specific OAuth flows
- Email operations on real accounts (AOL, Gmail)
- UI workflows on target devices (Windows desktop, Android emulator)

**Target Coverage**: 95%+ for core business logic

---

## Performance Optimization

### Pattern Caching (ADR-0023)
- `PatternCompiler` uses `HashMap<String, RegExp>` cache
- ~100x speedup (2.1ms -> 0.18ms per pattern)
- Cache hit/miss statistics for monitoring

### Throttled UI Updates (ADR-0022)
- Dual-threshold: notify every 10 emails OR every 2 seconds
- Separate throttle for result recording
- Reset counters on scan start to prevent accumulation

### Batch Operations
- `BatchOperationsMixin` reduces IMAP round-trips from 3N to ~3 batch operations
- Uses IMAP UID sequence sets for bulk delete/move/mark-as-read

### Asynchronous Operations
- All I/O operations are async (file, network, database)
- Folder-by-folder progressive scanning with 2-second UI refresh interval

---

## Future Architecture Enhancements

### Rule Sync (Future)
- Cloud sync for rules across devices
- Conflict resolution for multi-device editing

### Plugin Architecture (Future)
- Extensible rule actions (custom scripts)
- Third-party email provider plugins

### Google Play Store Readiness (ADRs 0026-0034)

Product readiness decisions documented as ADRs. See `docs/adr/` for details.

**Accepted**:
- ADR-0026: Application Identity -- Domain `myemailspamfilter.com`, App ID `com.myemailspamfilter`, App Name `MyEmailSpamFilter`
- ADR-0029: Gmail API Scope Strategy -- Phased approach: unverified OAuth for alpha/beta, app passwords for general users, CASA deferred until 2,500+ users or $5K/yr revenue
- ADR-0030: Privacy and Data Governance -- Zero telemetry, host privacy policy on `myemailspamfilter.com` via GitHub Pages, indefinite local storage, in-app + web account deletion
- ADR-0034: Gmail Access Method -- Dual path: Gmail REST API (OAuth) for alpha/beta, Gmail IMAP (app passwords) for general users

**Proposed** (decisions pending):
- ADR-0027: Android Release Signing Strategy
- ADR-0028: Android Permission Strategy
- ADR-0031: App Icon and Visual Identity
- ADR-0032: User Data Deletion Strategy
- ADR-0033: Analytics and Crash Reporting Strategy

### Gmail Authentication Strategy (ADR-0029, ADR-0034)

The app supports two Gmail access paths, matching investment to viability:

| Phase | Method | Users | Scope | Verification |
|-------|--------|-------|-------|--------------|
| 1 (Alpha/Beta) | Gmail REST API + OAuth | Up to 100 testers | `gmail.modify` | None (Testing mode) |
| 2 (General) | Gmail IMAP + App Passwords | Unlimited | N/A (no OAuth) | None |
| 3 (Future) | Gmail REST API + Verified OAuth | Unlimited | `gmail.modify` | CASA audit required |

**CASA trigger**: Pursue verification when app has 2,500+ active Gmail IMAP users at $3/yr or yearly revenue exceeds $5,000.

---

## Architecture Decision Records

All architectural decisions are documented as ADRs in `docs/adr/`. Currently 29 accepted and 5 proposed.

**Accepted ADRs** (0001-0025):

| ADR | Title | Key Decision |
|-----|-------|--------------|
| 0001 | Flutter/Dart Single Codebase | 100% Flutter for all 5 platforms |
| 0002 | Adapter Pattern for Email Providers | SpamFilterPlatform interface + PlatformRegistry factory |
| 0003 | Regex-Only Pattern Matching | All patterns compiled as Dart RegExp, case-insensitive |
| 0004 | Dual-Write Storage (SQLite + YAML) | SQLite authoritative, YAML exported for version control |
| 0005 | Safe Senders Evaluated Before Rules | Whitelist checked first, then rules in execution order |
| 0006 | Four Progressive Scan Modes | readonly/testLimit/testAll/fullScan with enforcement flags |
| 0007 | Move-to-Trash, Not Permanent Delete | Delete = trash (recoverable) |
| 0008 | Platform-Native Secure Storage | flutter_secure_storage wraps OS keystores |
| 0009 | Provider Pattern for State Management | ChangeNotifier-based providers |
| 0010 | Normalized Database Schema | 8 tables, JSON arrays, text enums, 10+ indexes |
| 0011 | Desktop OAuth via Loopback + PKCE | Desktop: loopback server; Mobile: native SDKs |
| 0012 | AppPaths Platform Storage Abstraction | Platform-agnostic path resolution |
| 0013 | Per-Account Settings with Inheritance | Account -> App -> Hardcoded three-tier fallback |
| 0014 | Windows Background Scanning | Task Scheduler with PowerShell scripts |
| 0015 | GitFlow Branching Strategy | main <- develop <- feature branches |
| 0016 | Sprint-Based Development with Model Tiering | Haiku/Sonnet/Opus complexity scoring |
| 0017 | PowerShell as Primary Build Automation | All build scripts are .ps1 |
| 0018 | Windows Toast Notifications | PowerShell-generated WinRT notifications |
| 0019 | Windows System Tray Integration | system_tray + window_manager |
| 0020 | Demo Mode with Synthetic Emails | MockEmailProvider with 55 test emails |
| 0021 | YAML-to-Database One-Time Migration | Transaction-wrapped idempotent import |
| 0022 | Throttled UI Progress Updates | Every 10 emails OR every 2 seconds |
| 0023 | In-Memory Pattern Caching | HashMap cache, ~100x speedup |
| 0024 | Canonical Folder Mapping | Provider-specific junk folder names |
| 0025 | CHANGELOG Updated Per Commit | Update in same commit as code changes |

---

**Document Version**: 2.0
**Created**: January 30, 2026
**Major Revision**: February 21, 2026 (updated to reflect Sprint 17 completion, all 12 identified gaps resolved)
**Update**: February 24, 2026 (ADR-0026/0029/0030/0034 accepted, Gmail auth strategy documented)
**Related Documents**:
- `docs/RULE_FORMAT.md` - YAML rule specification
- `docs/adr/` - Architecture Decision Records (ADR-0001 through ADR-0034)
- `CLAUDE.md` - Primary development guide
- `docs/SPRINT_PLANNING.md` - Development methodology
- `CHANGELOG.md` - Project change history
