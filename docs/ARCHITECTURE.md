# Application Architecture

**Purpose**: Detailed architectural documentation for the spamfilter-multi Flutter application

**Last Updated**: June 20, 2026 (Sprint 42: F98 per-account background scanning per ADR-0039; F99 two-harness E2E testing; BUG-S37-2 ccTLD audit)

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

**Current Status**: See [CHANGELOG.md](../CHANGELOG.md) for current version, sprint, and test count.

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
- `RuleSetProvider`: Manages rule sets and safe senders with database persistence (YAML dual-write removed Sprint 20)
- `EmailScanProvider`: Tracks real-time scan progress with throttled UI updates and scan history persistence

### 5. Database Storage (ADR-0004)
SQLite is the sole source of truth for rules and scan data. YAML files are available for import/export via Settings > Data Management.

### 6. Platform-Agnostic Storage (ADR-0012)
`AppPaths` provides unified file system access across all 5 platforms (Windows, macOS, Linux, Android, iOS).

**Platform Paths** (updated Sprint 19 - identity changed from `com.example` to `MyEmailSpamFilter`):
- **Windows**: `C:\Users\{username}\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\` (development builds use `MyEmailSpamFilter_Dev\`, see ADR-0035)
- **Android**: `/data/user/0/com.myemailspamfilter/files`
- **macOS**: `~/Library/Application Support/MyEmailSpamFilter`
- **Linux**: `~/.local/share/MyEmailSpamFilter`
- **iOS**: `/Library/Application Support/MyEmailSpamFilter`

**Subdirectories**: `rules/`, `credentials/`, `backups/`, `logs/`; SQLite database at root.

**Background Scan Log Convention**: Log files are versioned as `background_scan_v{VERSION}.log` (e.g., `background_scan_v0.5.0.log`) to distinguish logs from different app versions or branches running concurrently. When bumping app version, update the log filename in `background_scan_windows_worker.dart` and `main.dart`.

---

## Component Architecture

### Core Models (`lib/core/models/`)

Immutable data classes representing domain entities.

| Model | Purpose | Key Fields |
|-------|---------|------------|
| **EmailMessage** | Normalized email representation | id, from, subject, body, headers, receivedDate, folderName, **messageIdHeader (RFC 5322 Message-ID, F91 Sprint 39)** |
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

#### PatternCompiler (ADR-0023, SEC-1/SEC-1b Sprint 32-33)

**Purpose**: Compiles and caches regex patterns for efficient matching, with ReDoS protection

**Features**:
- `HashMap<String, RegExp>` cache (see [PERFORMANCE_BENCHMARKS.md](PERFORMANCE_BENCHMARKS.md) for speedup metrics)
- Case-insensitive matching
- Python-style inline flag stripping (`(?i)`, `(?m)`, `(?s)`, `(?x)`)
- Error tracking for invalid patterns (graceful fallback to never-matching regex)
- Cache hit/miss statistics
- **ReDoS detection** (`detectReDoS`): heuristics for nested quantifiers, overlapping alternation, bounded-repetition ReDoS shapes (SEC-1, Sprint 32)
- **Pattern provenance tracking** (SEC-1b, Sprint 33): `PatternProvenance { bundled, user }` enum. `compileWithProvenance(pattern, provenance)` rejects user patterns that match the ReDoS heuristics (caches a never-match fallback and records the rejection in `rejectedUserPatterns`). Bundled patterns skip the check -- curated rules stay on the fast `regex.hasMatch()` path with no per-match overhead
- **Isolate-timeout matching** (`safeHasMatch`): optional async defense-in-depth for callers that want a wall-clock bound even after the compile-time guard

**Key Methods**:
- `compile(String pattern) -> RegExp` (defaults to bundled provenance)
- `compileWithProvenance(String pattern, PatternProvenance provenance) -> RegExp`
- `detectReDoS(String pattern) -> List<String>` (static; warnings list)
- `safeHasMatch(RegExp regex, String input, {Duration timeout}) -> Future<bool>` (static; isolate-timeout wrapper)
- `getStats() -> Map<String, int>`
- `provenanceOf(String pattern) -> PatternProvenance?`
- `rejectedUserPatterns -> Map<String, String>` (read-only)

**Enforcement chokepoints** (SEC-1b): `RuleDatabaseStore.addRule`/`updateRule` and `SafeSenderDatabaseStore.addSafeSender`/`updateSafeSender` call `detectReDoS` before persisting and throw on match, blocking dangerous patterns at the persistence boundary so the scanner hot path never sees them.

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
7. Update UI progress (throttled per [ADR-0022](adr/0022-throttled-ui-progress-updates.md))
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
| **WindowsTaskSchedulerService** | Create/manage Windows Task Scheduler tasks; per-account tasks (ADR-0014, ADR-0039 F98) -- `taskNameFor(accountId)`, enumerate/orphan cleanup |
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
| **DataDeletionService** (F66, Sprint 33) | Per-account wipe (`deleteAccountData`) and full-app wipe (`wipeAllData`). Account-level clears credentials + scan results + email actions + unmatched emails + per-account settings + rate-limit state while preserving global rules/safe-senders/other accounts; full wipe calls `DatabaseHelper.deleteAllData` + `SecureCredentialsStore.deleteAllCredentials`. Used by Account Selection "Delete Account" and Settings > General "Delete All App Data" |
| **DefaultRuleSetService** | Seed bundled rules on first launch; reset to defaults; SEC-1b marks seeded patterns as `bundled` provenance so they skip ReDoS checks. Includes F53 `ensureTldBlockRules` post-seed migration for existing installs, plus the BUG-S37-2 ccTLD gap-fill reconciling the bundled `top_level_domain` set against the ISO 3166-1 list. **Current bundled coverage (BUG-S37-2 audit, Sprint 42): 247 of 248 IANA ccTLDs blocked -- only `.us` is unblocked** (`.uk`/`.ca` ARE blocked; the bundled list is an initial load the user overrides per-account via safe-sender rules). DB v6/v7 migrations remove malformed TLD typos (`.c`, `.giw`, `.sweepss`, ... and Sprint-42 `.sho`/`.sweeps`) |
| **LiveScanLogger** (F90, Sprint 39 warmup) | Persists live-scan runtime log + per-account CSV/XLSX to `{appDataDir}/logs/`, env-aware path (dev/prod), append-mode, setting-gated CSV export. Parity with the background-scan log pipeline |
| **AuthResultsParser** (F89, Sprint 39) | Parses `Authentication-Results` / `Received-SPF` / DKIM / ARC headers (RFC 8601, tolerant of AOL/Yahoo/Gmail variants) into an `EmailAuthResult {spf, dkim, dmarc, raw}`, and classifies to GREEN/YELLOW/RED/GREY. Drives the auth badge + warn-then-confirm dialog on rule / safe-sender quick-add prompts so a user does not whitelist a sender whose mail failed authentication |
| **ManualRulePatternGenerator** (F25, Sprint 40) | Public utility (`lib/core/utils/manual_rule_pattern_generator.dart`) with 5 static methods: `generateTopLevelDomain`, `generateEntireDomain`, `generateExactDomain`, `generateExactEmail`, `generateFromPlaintext` (auto-detect). Extracted from `ManualRuleCreateScreen`'s previously-private generators so create-flow, edit-flow (F35 `RuleEditScreen`), and rule-test plaintext->regex conversion (F25) all share the same source of truth |

---

### Security Services (`lib/core/security/`)

New directory introduced in Sprint 33 for security-cross-cutting services.

| Service | Purpose |
|---------|---------|
| **AuthRateLimiter** (SEC-22) | Tracks up to 10 failed IMAP auth attempts in a rolling 1h window per `{platform}-{email}` account ID; blocks further attempts for 1h once the threshold is hit. State persists in the `auth_rate_limit` table (DB schema v3). `GenericIMAPAdapter.loadCredentials` calls `assertNotBlocked` before network I/O and records failures on `AuthenticationException`; success resets the counter |
| **CertificatePinner** / **PinnedHttpClient** (SEC-8) | SPKI pins for Google OAuth endpoints (`accounts.google.com`, `oauth2.googleapis.com`, `gmail.googleapis.com`, `www.googleapis.com`). `PinnedHttpClient` wraps `dart:io HttpClient` with a bad-cert callback; `GmailWindowsOAuthHandler` token-exchange / refresh / userinfo calls route through the pinned client. Runtime kill switch via `setEnabled` (wired to a Settings toggle). IMAP is NOT pinned (enough_mail does not expose a `SecurityContext`; tracked as future work) |
| **DatabaseEncryptionKeyService** (SEC-11) | Per-device 256-bit key in `flutter_secure_storage`, base64-encoded for SQLCipher's `PRAGMA key`. Infrastructure ships opt-in behind `encrypt_database` setting (default `false`) until dedicated platform QA validates the plaintext→encrypted migration |

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
| **MockEmailProvider** | None (in-memory) | None | `PlatformRegistry.getPlatform('demo')` | Synthetic test emails (see [ADR-0020](adr/0020-demo-mode-synthetic-emails.md) for details) |

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

**Sprint 39 IMAP capability additions** (`GenericIMAPAdapter`, default no-op on non-IMAP platforms via `SpamFilterPlatform`):
- `searchByMessageId(folder, messageId)` (F91): `UID SEARCH HEADER Message-ID <id>` in a folder; used by the post-safe-sender-move source-folder dedup to find AOL re-injected copies.
- `firstUidSince(folder, since)` (S38-CI-4): `UID SEARCH SINCE <date>` returning the smallest UID newer than `now - daysBack`; used to cap the `oldest_no_rule_uid` cursor at the retention window (cached once per folder per scan).

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

SQLite database schema. See [ADR-0010](adr/0010-normalized-database-schema.md) for the authoritative table count and schema definition. Key tables:

| Table | Purpose | Key Fields |
|-------|---------|------------|
| **accounts** | Account metadata tracking | account_id (PK), platform_id, email, display_name, date_added, last_scanned |
| **scan_results** | Aggregate scan results per scan | id (PK), account_id (FK), scan_type, scan_mode, started_at, completed_at, total_emails, processed/deleted/moved/safe/no_rule/error counts, status, folders_scanned |
| **email_actions** | Individual email results within a scan | id (PK), scan_result_id (FK), email_id, email_from, email_subject, email_folder, action_type, matched_rule_name, matched_pattern, is_safe_sender, success, **rfc5322_message_id (DB v6, F91)** |
| **rules** | Imported rules (dual-write from YAML) | name (UNIQUE), enabled, execution_order, condition_type, condition_from/header/subject/body, action_delete, action_move_to_folder, exception fields, metadata, **created_with_auth_state (DB v6, F89)** |
| **safe_senders** | Whitelist patterns (dual-write from YAML) | pattern (UNIQUE), added_date, source, enabled, **created_with_auth_state (DB v6, F89)** |
| **account_folder_cursors** (DB v5, Sprint 38) | Per-(account, folder) IMAP incremental-scan cursors, incl. the `oldest_no_rule_uid` cursor capped at the daysBack window (S38-CI-4, Sprint 39) | account_id, folder_name, cursor_type, cursor_value, updated_at (PK: account_id, folder_name, cursor_type) |
| **app_settings** | Global app settings | key-value pairs |
| **account_settings** | Per-account setting overrides (ADR-0013) | account_id, setting key-value pairs |
| **background_scan_log** | Background scan execution logs | timestamp, account_id, status, stats |
| **unmatched_emails** | Emails captured by scans that did not match any rule. Body previews truncated to 100 chars at insert (SEC-14); rows pruned by `UnmatchedEmailStore.deleteOlderThan` on startup + after each scan (default 30d, configurable) | id (PK), scan_result_id (FK), provider_identifier_type/value, from_email, subject, body_preview, folder_name, availability_status, processed, created_at |
| **auth_rate_limit** (DB v3, SEC-22 Sprint 33) | Tracks failed IMAP auth attempts per account for rate limiting | account_id (PK), window_start, attempts, block_until |

**Schema version history**:
- v1: Initial schema (Sprint 12)
- v2: Pattern classification columns on rules (Sprint 20)
- v3: `auth_rate_limit` table for failed-auth throttling (SEC-22, Sprint 33)
- v4: `last_history_id` on accounts for Gmail historyId incremental scans (F6c, Sprint 37)
- v5: `account_folder_cursors` table for IMAP incremental-scan UID cursors (Sprint 38)
- v6: `email_actions.rfc5322_message_id` (F91 AOL copy-not-move dedup); `created_with_auth_state` on `rules` + `safe_senders` (F89 auth-state snapshot); one-time cleanup removing 6 malformed bundled TLD rules (BUG-S37-2) (Sprint 39)

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
- `updateProgress(email, message)`: Report progress (throttled per [ADR-0022](adr/0022-throttled-ui-progress-updates.md))
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

### Background Scanning Flow (Windows, ADR-0014 + ADR-0039 per-account, F98 Sprint 42)

Background scanning is **per account** (ADR-0039): there is one Windows Task
Scheduler task per enabled account, named
`SpamFilterBackgroundScan_<sanitizedAccountId><envSuffix>`, whose action launches
the executable with `--background-scan --account-id=<accountId>`. Each task uses a
`-RandomDelay` (sized to its interval) so multiple accounts' tasks do not fire
simultaneously and contend for the single SQLite DB. A one-time migration
(`PerAccountBgMigration`) seeds per-account `background_enabled` / `background_frequency`
overrides from the legacy global flag on first launch; `main.dart` startup
reconciles per-account tasks and cleans up the legacy global + orphaned tasks.

```
Windows Task Scheduler fires the PER-ACCOUNT task
  --background-scan --account-id=<accountId>
  |
  v
main.dart detects BackgroundModeService.isBackgroundMode +
  reads BackgroundModeService.backgroundAccountId
  |
  v
BackgroundScanWindowsWorker.executeBackgroundScan(accountId: <id>)
  |- Initialize AppPaths, DatabaseHelper (WAL + busy_timeout=30s), RuleSetProvider
  |- Get saved account IDs; narrow to the ONE named account (legacy: all accounts
  |    when accountId is null -- backward compatibility for un-migrated tasks)
  |- For that account (retry-on-DB-lock: 1 min x 20):
  |    |- Load per-account settings (folders, scan mode, frequency)
  |    |- scanInbox(daysBack, folders, scanType='background')
  |    |- Log results to BackgroundScanLogStore + per-account log file
  |       ({prefix}background_scan_<sanitizedAccountId>_v{VERSION}.log)
  |    |- Send Windows toast notification
  |- Exit with code 0 (success) or 1 (failure)
```

**Android** (ADR-0039): one WorkManager unique periodic task per enabled account
(`background_scan_task::<accountId>`) carrying the accountId in `inputData`;
`callbackDispatcher` routes it to a single-account scan. First-run `initialDelay`
is randomized (1..N min) for the same anti-collision reason.

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

### Screens

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
| **settings_screen.dart** | App configuration (General, Account, Manual Scan, Background tabs). General tab hosts Privacy & Logging toggles (auth logging, unmatched retention, cert pinning) and the "Delete All App Data" action (F66) |
| **gmail_oauth_screen.dart** | Gmail OAuth flow (legacy WebView) |
| **help_screen.dart** (F54, Sprint 33) | Scrollable single-page Help screen with one anchored section per primary screen. `HelpSection` enum + `openHelp(context, section)` helper; every primary AppBar has a Help icon that deep-links to that screen's section. F75 (Sprint 40) added the `walkthrough` section: end-to-end first-use guide as Markdown asset per ADR-0038 (6 steps + recommendation hierarchy Entire Domain > Exact Email > TLD) |
| **rule_edit_screen.dart** (F35, Sprint 40) | Full-screen rule editor mirroring `ManualRuleCreateScreen`'s structure but pre-populating from an existing `Rule` and calling `RuleSetProvider.updateRule()` instead of insert. Dual-mode: guided plaintext-to-regex (via `ManualRulePatternGenerator`) OR direct-regex with ReDoS + IANA validation. Reached via the "Edit" button in the Manage Rules `_showRuleDetails` AlertDialog, alongside F25's "Test" button. `updateRule` rethrows on UNIQUE-violation per BUG-S39-2 discipline |
| **folder_selection_screen.dart** (F37, Sprint 40 enhancement) | Two-level folder presentation: in multi-select mode (Default Folders), folders are grouped into depth-2 `ExpansionTile`s by parent path using each folder's `FolderInfo.hierarchyDelimiter` (`groupFoldersForTree` pure fn); parent rows are expand-only (no checkbox -- IMAP `\NoSelect` rationale). In single-select mode (Safe Sender / Deleted Rule target), `reorderForSingleSelect` places `CanonicalFolder.inbox` first, `CanonicalFolder.trash` second, rest alphabetical |

### Widgets (`lib/ui/widgets/`)

| Widget | Purpose |
|--------|---------|
| **app_bar_with_exit.dart** | AppBar with Exit button and confirmation dialog |
| **empty_state.dart** | Empty state placeholder |
| **error_display.dart** | Error display component |
| **skeleton_loader.dart** | Loading skeleton UI |
| **list_selection_controller.dart** (S38-CI-3, Sprint 39) | `ListSelectionController<T>` mixin: multi-row selection model for list screens -- Shift+Click range-extend (anchor preserved), Ctrl/Cmd+Click disjoint toggle, Ctrl-drag swept range. Used by Manage Rules + Manage Safe Senders |
| **email_auth_badge.dart** + **auth_warning_dialog.dart** (F89, Sprint 39) | GREEN/YELLOW/RED/GREY auth badge computed from `EmailAuthResult`; RED-state warn-then-confirm dialog (per-protocol plain-English explanation + alternatives) gating safe-sender quick-add on authentication-failed mail |

### Adapter Model Extensions (Sprint 40)

`FolderInfo.hierarchyDelimiter` (String, default `'/'`) added to `lib/adapters/email_providers/spam_filter_platform.dart` for F37. Populated per adapter:
- **GenericIMAPAdapter**: live from `enough_mail` `Mailbox.pathSeparator` (the IMAP LIST response delimiter; e.g., AOL returns `'/'`, some providers return `'.'`)
- **GmailApiAdapter**: hardcoded `'/'` (Gmail labels use `/` for nesting; no delimiter exposed by the Labels API)
- **MockEmailProvider**: hardcoded `'/'` for test consistency
- **OutlookAdapter**: unset (listFolders is UnimplementedError; default `'/'` will apply when implemented)

Consumed by `folder_selection_screen.dart`'s `groupFoldersForTree(folders)` -- no hardcoded `/` in the tree-grouping logic.

### Test Tooling (Sprint 40)

| Tool | Purpose |
|------|---------|
| **scripts/run-winwright-tests.ps1** (F79, Sprint 40 enhancement) | Unattended WinWright sweep runner. Extends Sprint 34's runner with `-SnapshotDb` / `-DryRun` / `-TestSnapshotOnly` / `-FailOnDrift` params and a pre/post dev-DB snapshot guard. Exits non-zero on either WinWright script failure OR detected DB drift |
| **scripts/winwright-db-snapshot.ps1** (F79, Sprint 40) | DB-snapshot helper (dot-sourced into the runner). Snapshots `rules`, `safe_senders`, `settings` tables via `sqlite3` (uses Android SDK's `sqlite3.exe`; no new dep). `Compare-DbSnapshots` reports any row added/removed/modified as `[LEAK] table '<t>' added/removed row: <row>`. `-SelfTest` mode injects a synthetic bogus row, verifies drift detection, then cleans up -- no running app or WinWright required for self-verification |

### UI Standards (ADR-0037)

| Standard | Requirement |
|----------|-------------|
| **Accessibility target** | WCAG 2.1 AA |
| **Semantics labels** | Required on all interactive elements (buttons, text fields, tappable list items) |
| **Touch target minimum** | 48dp (`AccessibilityHelper.minTouchTargetSize`) |
| **Text selectability** | `SelectionArea` at Scaffold body level for copyable content |
| **Typography** | Material 3 type scale via `Theme.of(context).textTheme` |
| **Colors** | Theme colors only (no hardcoded values) for dark mode support |
| **Responsive breakpoints** | Phone < 600dp, Tablet 600-900dp, Desktop > 900dp |
| **Helper utilities** | `lib/ui/utils/accessibility_helper.dart` |

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
|       |- screens/            # Full-screen pages
|       |- widgets/            # Reusable components
|       |- theme/              # AppTheme (Material Design)
|       |- utils/              # Accessibility helpers
|- test/                        # Tests (run `flutter test` for current count)
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
| **UI Framework** | Flutter / Dart | Cross-platform UI and application logic |
| **State Management** | Provider | Reactive state via ChangeNotifier ([ADR-0009](adr/0009-provider-pattern-state-management.md)) |
| **Local Storage** | SQLite (sqflite/sqflite_ffi) | Persistent data ([ADR-0010](adr/0010-normalized-database-schema.md)) |
| **Secure Storage** | flutter_secure_storage | Credentials, tokens (OS-native keystores) |
| **Networking** | http, googleapis | REST APIs (Gmail) |
| **Email** | enough_mail | IMAP protocol (AOL, Yahoo, iCloud) |
| **OAuth** | google_sign_in (mobile), flutter_appauth (desktop) | Gmail authentication |
| **System Tray** | system_tray, window_manager | Windows desktop integration |
| **Logging** | logger | Keyword-based logging via AppLogger |

**Package versions**: See `mobile-app/pubspec.yaml` for current dependency versions.

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
- Background scanning via WorkManager -- per-account unique tasks (ADR-0039 / F98, Sprint 42)

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

### Sprint 33 Security Layers
- **ReDoS protection** (SEC-1/1b): user-supplied regex patterns pass `PatternCompiler.detectReDoS` before persisting to the `rules` / `safe_senders` tables; dangerous patterns are rejected at the storage boundary so the evaluator hot path stays on the fast direct-`hasMatch` route. Bundled patterns in `assets/rules/*.yaml` are trusted and skip the check.
- **Failed-auth rate limit** (SEC-22): `AuthRateLimiter` blocks an account for 1h after 10 failed IMAP sign-ins in a rolling 1h window; state persists in the `auth_rate_limit` table so blocks survive app restart. UI surfaces a "Try again at HH:MM" message in place of the generic auth error.
- **Certificate pinning** (SEC-8): `PinnedHttpClient` enforces SPKI pins for Google OAuth endpoints. Runtime kill switch in Settings > General > Privacy & Logging. IMAP is not pinned (enough_mail limitation, tracked as future work).
- **Auth logging suppression** (SEC-19): Settings toggle makes `Redact.logSafe` a no-op even in debug builds.
- **Logging & Redaction invariant** (F102, Sprint 43): never log account ids / email / tokens / email content in the clear -- use the `Redact` utility (`Redact.accountId/email/token`). Applies to `Logger`, the headless `_bgLog`, and generated artifacts (PowerShell scripts, Task Scheduler task names). Enforced by `scripts/check-log-redaction.ps1` (build-failing) + a Phase 5 checklist grep. Policy: ADR-0030 "Logging & Redaction".
- **Unmatched email retention** (SEC-14): rows pruned on startup + after each scan; body previews capped at 100 chars at insert.
- **User data deletion** (F66): per-account wipe + full-app reset via `DataDeletionService`.
- **SQLCipher infrastructure** (SEC-11, opt-in): `DatabaseEncryptionKeyService` ships enabled; actual driver swap deferred until dedicated QA pass.

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

**Current State**: Run `flutter test` for current count. See [CHANGELOG.md](../CHANGELOG.md) for test history.

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

### Automated Desktop E2E Tests -- TWO complementary harnesses (Sprint 27+; F99 Sprint 42)

**1. WinWright (out-of-process UIA).**
- **Tool**: civyk-winwright MCP server (v2.0.0) at `C:\Tools\WinWright\`
- **Method**: Windows UI Automation (UIA3/MSAA) — reads the accessibility tree of the running Flutter Desktop app
- **Scope**: Read-only screen navigation, accessibility-tree coverage on the real window (the 6 green scripts)
- **Limitation**: Flutter Windows exposes MSAA (not full UIA); flaky on Flutter dialog/picker-**settle** boundaries (the `run` runner has no wait/assert primitive) -- create/save (F56) and folder-picker (F37) scripts were therefore moved to the integration_test lane
- **Runner**: `scripts/run-winwright-tests.ps1` (6 read-only scripts + pre/post DB-snapshot drift guard)

**2. Flutter `integration_test` (in-VM) -- F99, Sprint 42, pre-MVP.**
- **Method**: drives the real widget tree in the Dart VM by `Key`/`Finder` with `pumpAndSettle()` -- deterministic; immune to UIA-exposure / DPI / cursor / dialog-settle flakiness
- **Scope**: create/delete lifecycle (rules + safe senders), folder picker, layout-bounds regression (the F76 goal WinWright's CLI could not deliver)
- **DB isolation**: isolated temp DB per test via the `AppPaths.testOverrideBaseDir` test seam (null in production); never touches the dev DB. Modes: `bootDbOnly` (seeded temp DB) / `bootAppWithDevDbCopy` (copy dev DB, delete on teardown)
- **Runner**: `scripts/run-integration-tests.ps1` -- **one `flutter test` process per file** (isolates process-wide singletons); within a file, multiple `testWidgets` share one process with no app shutdown between them
- **Reference**: See TESTING_STRATEGY.md "Two E2E Harnesses" for which to use when, the per-file execution model, and the test seams

**Target Coverage**: 95%+ for core business logic

---

## Performance Optimization

### Pattern Caching (ADR-0023)
- `PatternCompiler` uses `HashMap<String, RegExp>` cache
- See [PERFORMANCE_BENCHMARKS.md](PERFORMANCE_BENCHMARKS.md) for detailed speedup metrics
- Cache hit/miss statistics for monitoring

### Throttled UI Updates (ADR-0022)
- Dual-threshold notify (see [ADR-0022](adr/0022-throttled-ui-progress-updates.md) for thresholds)
- Separate throttle for result recording
- Reset counters on scan start to prevent accumulation

### Batch Operations
- `BatchOperationsMixin` reduces IMAP round-trips via batch operations
- Uses IMAP UID sequence sets for bulk delete/move/mark-as-read

### Asynchronous Operations
- All I/O operations are async (file, network, database)
- Folder-by-folder progressive scanning with throttled UI refresh

---

## Future Architecture Enhancements

### Browser / Flutter Web (Excluded)

A browser target has been evaluated and excluded. The app's IMAP-based email providers (AOL, Yahoo, iCloud, custom IMAP) require raw TCP socket connections, which browsers block via the Same-Origin Policy. The only viable workaround -- a server-side IMAP proxy (the approach used by browser-based email clients such as Outlook Web) -- would route user credentials and email content through a backend server, directly contradicting the local-only, zero-telemetry privacy architecture ([ADR-0030](adr/0030-privacy-and-data-governance-strategy.md)). Chromebook users are served by the existing Android (Play Store) and Linux (Crostini) targets. See [ARSD.md](ARSD.md) Section A1 for full rationale.

### Rule Sync (Future)
- Cloud sync for rules across devices
- Conflict resolution for multi-device editing

### Plugin Architecture (Future)
- Extensible rule actions (custom scripts)
- Third-party email provider plugins

### Google Play Store Readiness

Product readiness decisions documented as ADRs (0026-0034). See [ADR Index](adr/README.md) for current status of each.

### Gmail Authentication Strategy

The app supports dual Gmail access paths. See [ADR-0029](adr/0029-gmail-api-scope-and-verification-strategy.md) and [ADR-0034](adr/0034-gmail-access-method-for-production.md) for the phased strategy and CASA trigger thresholds.

---

## Architecture Decision Records

All architectural decisions are documented as ADRs in `docs/adr/`. See [ADR Index](adr/README.md) for the complete list with current status.

---

**Document Version**: 2.0
**Created**: January 30, 2026
**Major Revision**: February 21, 2026 (updated to reflect Sprint 17 completion, all 12 identified gaps resolved)
**Update**: February 24, 2026 (ADR-0026/0029/0030/0034 accepted, Gmail auth strategy documented)
**Related Documents**:
- `docs/RULE_FORMAT.md` - YAML rule specification
- `docs/adr/README.md` - Architecture Decision Records index
- `CLAUDE.md` - Primary development guide
- `docs/SPRINT_PLANNING.md` - Development methodology
- `CHANGELOG.md` - Project change history
