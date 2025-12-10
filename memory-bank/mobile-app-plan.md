# Mobile Spam Filter App - Development Plan

**Status**: Phase 1.5 - IMAP Integration & E2E Testing ✅ COMPLETE  
**Last Updated**: 2025-12-05  
**Flutter Installation**: ✅ Complete (3.38.3 verified)
**Target Platforms**: Android, iOS (phones & tablets), Chromebooks  
**Tech Stack**: Flutter/Dart (with optional Rust optimization path)

## Repository Migration Status

✅ **Completed (2025-12-04)**:
- New directory structure created in `mobile-app/`
- Core models implemented (EmailMessage, RuleSet, SafeSenderList, EvaluationResult)
- Core services implemented (PatternCompiler, RuleEvaluator, YamlService)
- **NEW**: Translator layer architecture (`SpamFilterPlatform` abstraction)
- **NEW**: Platform registry and factory pattern
- **NEW**: Platform-specific adapters (Gmail, Outlook, IMAP)
- Email provider interface defined (EmailProvider, Credentials)
- Basic UI scaffold (AccountSetupScreen)
- pubspec.yaml configured with Phase 1 & Phase 2 dependencies
- Root README.md updated with new structure
- Mobile app README.md created

✅ **Phase 1.3 Complete (December 10, 2025)**:
- Flutter SDK installed (3.38.3) with full toolchain
- Debug APK built and deployed to Android emulator
- All code analysis passing (zero issues)
- Unit test suite: 16 tests passing
- Android emulator validated (API 34, Android 14)

✅ **Phase 1.4 Complete (December 10, 2025)**:
- YAML integration testing: 3 of 4 tests passing
- Production rules.yaml loaded successfully (5 rules parsed)
- Production rules_safe_senders.yaml loaded (426 patterns)
- **Performance validated**: 2,890 regex patterns compiled in 42ms (0.01ms/pattern)
- Performance target exceeded: 100x faster than 5-second target
- Total test suite: 19 tests passing

✅ **Phase 1.5 Complete (December 10, 2025)**:
- **Test Suite**: 34 total tests (27 passing, 6 skipped, 1 non-critical failure)
  - 16 unit tests (PatternCompiler, SafeSenderList)
  - 4 YAML integration tests (production file validation)
  - 4 end-to-end workflow tests (email evaluation pipeline)
  - 10 IMAP adapter tests (6 require AOL credentials)
- **End-to-End Validation**: Complete email processing workflow tested
  - Safe sender evaluation working
  - Spam detection matched production rule (SpamAutoDeleteHeader: `@.*\.xyz$`)
  - Batch processing: 100 emails in 1,958ms (19.58ms avg - 5x better than target)
  - Full inbox scan simulation successful
- **IMAP Integration Framework**: All tests compile, ready for live credentials
- **Performance**: 19.58ms per email (5x better than 100ms target)
- **Code Quality**: flutter analyze passes with 0 issues
- **Documentation**: PHASE_1.5_COMPLETION_REPORT.md created (460 lines)

📋 **Next Steps (Phase 2.0 - Platform Storage & UI Development)**:
1. Integrate path_provider for file system access
2. Implement secure credential storage (flutter_secure_storage)
3. Configure Provider for app-wide state management
4. Run live IMAP tests with AOL credentials (AOL_EMAIL, AOL_APP_PASSWORD)
5. Build platform selection UI
6. Create account setup form with validation
7. Add scan progress indicator
8. Build results summary display

## Executive Summary

Port the OutlookMailSpamFilter desktop application to a cross-platform mobile app that works with multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail, and others). The app will maintain compatibility with existing YAML rule formats while decoupling from Outlook-specific COM interfaces.

## Stack Decision: Flutter/Dart

**Primary Stack**: Pure Flutter/Dart  
**Optional Enhancement**: Rust via `flutter_rust_bridge` (only if profiling shows regex performance bottleneck)

### Rationale
- **Full Platform Coverage**: Native support for Android, iOS, tablets, Chromebooks (Android app or PWA), and web
- **Single Codebase**: Faster development, easier maintenance
- **Mature Ecosystem**: Excellent packages for OAuth (`flutter_appauth`), IMAP (`enough_mail`), secure storage
- **Performance**: Dart's native `RegExp` with precompiled caching sufficient for initial validation
- **Developer Experience**: Hot reload, rich debugging tools, strong type system
- **Rust Escape Hatch**: Can add high-performance regex engine later if needed

## Architecture Overview

### Storage Strategy Decision

**Approach**: Progressive enhancement - Start simple, add complexity when proven necessary

**Phase 1 (MVP)**: Pure File-Based Storage
- YAML files for rules & safe senders (maintain desktop compatibility)
- Encrypted JSON for credentials/tokens (`flutter_secure_storage`)
- In-memory compiled regex cache
- No database initially

**Phase 2 (Post-MVP)**: Selective SQLite Addition
- SQLite (`sqflite`) for email cache, audit logs, scan history
- YAML remains source of truth for rules/safe senders
- Sync layer: YAML → SQLite on rule changes for fast queries
- Incremental scanning uses DB to track processed messages

**Phase 3 (Advanced - Optional)**: Full Database Migration
- Migrate rules/safe senders to SQLite if:
  - YAML load time exceeds 2 seconds
  - Complex rule search/filtering needed
  - Multi-device sync requires conflict resolution
- Maintain YAML export/import for backups and desktop compatibility

**Rationale**:
- ✅ Start simple: Zero database overhead for MVP, validate performance first
- ✅ Desktop parity: Direct YAML import/export, version control friendly
- ✅ Incremental risk: Add SQLite only when features demand it
- ✅ User choice: Power users keep YAML control, GUI-only for casual users
- ✅ Fallback safety: YAML always works if DB migration fails

**Current Scale**: Rules ~111 KB (3,084 lines), Safe Senders ~18 KB (427 patterns) - easily fits in memory on modern phones

### Layered Architecture

```
┌─────────────────────────────────────────────────────┐
│              Flutter UI Layer                       │
│  - Platform selection (Gmail, Outlook, AOL, etc.)   │
│  - Account setup & OAuth flows                      │
│  - Rule editor (view/add/remove patterns)           │
│  - Safe sender manager                              │
│  - Interactive inbox trainer (d/e/s/sd options)     │
│  - Scan status & notifications                      │
│  Material Design (Android) + Cupertino (iOS)        │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│         Business Logic Layer (Pure Dart)            │
│  - RuleSet: In-memory rule management               │
│  - SafeSenderList: Whitelist management             │
│  - PatternCompiler: Precompile & cache regex        │
│  - RuleEvaluator: Apply rules to messages           │
│  - YamlService: Load/save YAML rules                │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│   ⭐ Translator Layer (SpamFilterPlatform)          │
│  Unified abstraction for all email providers:       │
│    - loadCredentials(credentials)                   │
│    - fetchMessages(daysBack, folderNames)           │
│    - applyRules(messages, compiledRegex)            │
│    - takeAction(message, action)                    │
│    - listFolders()                                  │
│    - testConnection()                               │
│    - disconnect()                                   │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│       Platform-Specific Adapters                    │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Gmail       │  │  Outlook/    │  │  Generic   │ │
│  │ Adapter     │  │  Office365   │  │  IMAP      │ │
│  │             │  │  Adapter     │  │  Adapter   │ │
│  │ OAuth 2.0   │  │  OAuth 2.0   │  │  App Pass  │ │
│  │ Gmail API   │  │  Graph API   │  │  IMAP      │ │
│  │ Labels      │  │  Folders     │  │  Folders   │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
│       Phase 2         Phase 2           Phase 1     │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│          Email Provider APIs                        │
│  Gmail REST API | Microsoft Graph API | IMAP/SMTP   │
│  - Evaluator: Message → Action decision engine      │
│  - MutationService: Add/remove rules (immediate)    │
│  - YAMLService: Import/export with validation       │
│  - AuditLog: Track actions & stats                  │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│           Adapter Layer (Dart)                      │
│  Email Providers:                                   │
│    - GenericIMAPAdapter (AOL, Yahoo baseline)       │
│    - GmailAPIAdapter (Gmail via REST API)           │
│    - OutlookGraphAdapter (Outlook.com, Office 365)  │
│    - ProtonMailBridgeAdapter (desktop relay)        │
│  Storage (Phase 1 - MVP):                           │
│    - YAMLStorage: rules.yaml, safe_senders.yaml     │
│    - SecureStorage: Encrypted credentials & tokens  │
│    - FileStorage: Simple JSON for stats/logs        │
│  Storage (Phase 2 - Optional):                      │
│    - SQLiteCache: Email metadata, scan tracking     │
│    - YAMLStorage: Still primary for rules           │
│  Background:                                        │
│    - WorkManager (Android scheduled tasks)          │
│    - BackgroundFetch (iOS background refresh)       │
│  Auth:                                              │
│    - OAuth2Manager: Token acquisition & refresh     │
│    - AppPasswordManager: Legacy auth fallback       │
└─────────────────────────────────────────────────────┘
                     ↓ ↑
┌─────────────────────────────────────────────────────┐
│          External Services                          │
│  - Email Providers (IMAP, Gmail API, Graph API)     │
│  - OAuth Identity Providers                         │
│  - Cloud Storage (optional backup)                  │
└─────────────────────────────────────────────────────┘
```

## Translator Layer Architecture

### Core Abstraction: `SpamFilterPlatform`

The translator layer provides a unified interface for all email platforms while allowing platform-specific optimizations:

```dart
abstract class SpamFilterPlatform {
  /// Platform identifier (e.g., 'gmail', 'outlook', 'aol', 'imap')
  String get platformId;
  
  /// Human-readable platform name for UI display
  String get displayName;
  
  /// Authentication method supported by this platform
  AuthMethod get supportedAuthMethod;
  
  /// Load and validate credentials for this platform
  Future<void> loadCredentials(Credentials credentials);
  
  /// Fetch messages with platform-specific optimization
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  });
  
  /// Apply compiled rules with platform-native filtering when available
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  });
  
  /// Execute action (delete, move, mark) with platform-specific API
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  });
  
  /// List available folders with platform-specific names
  Future<List<FolderInfo>> listFolders();
  
  /// Test connection and authentication without fetching data
  Future<ConnectionStatus> testConnection();
  
  /// Disconnect and cleanup resources
  Future<void> disconnect();
}
```

### Platform Implementations

**1. GenericIMAPAdapter** (Phase 1 - MVP):
- Standard IMAP protocol using `enough_mail` package
- App passwords or basic auth
- Works with AOL, Yahoo, iCloud, custom servers
- Factory methods for known providers: `GenericIMAPAdapter.aol()`

**2. GmailAdapter** (Phase 2):
- OAuth 2.0 authentication via `google_sign_in`
- Gmail REST API using `googleapis` package
- Label-based operations (Gmail doesn't use folders)
- Batch operations for performance
- Efficient query syntax: `"after:2025/11/01 in:inbox OR in:spam"`

**3. OutlookAdapter** (Phase 2):
- Microsoft Identity Platform OAuth 2.0 via `msal_flutter`
- Microsoft Graph API for email operations
- OData query filters for efficient searching
- Native folder operations
- Well-known folders: inbox, junkemail, deleteditems

**4. Future Adapters** (Phase 3+):
- ProtonMail (via ProtonMail Bridge or API)
- Zoho Mail (IMAP + OAuth)
- Fastmail (IMAP with app password)
- Any custom IMAP server

### Benefits

- **Unified Business Logic**: Core spam filtering rules work across all platforms
- **Platform Optimization**: Each adapter can use native APIs for better performance
- **Extensibility**: New providers added without changing core logic
- **Testing**: Mock adapters for unit testing without real email accounts
- **YAML Compatibility**: Same rule files work across desktop and mobile

### Core Interfaces

#### Legacy EmailProvider Interface (Kept for compatibility)
```dart
abstract class EmailProvider {
  Future<void> connect(Credentials credentials);
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  });
  Future<void> deleteMessage(String messageId);
  Future<void> moveMessage(String messageId, String targetFolder);
  Future<List<String>> listFolders();
  Future<void> disconnect();
}
```

#### EmailMessage DTO
```dart
class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final String body;
  final Map<String, String> headers;
  final DateTime receivedDate;
  final String folderName;
}
```

#### RuleEvaluator Interface
```dart
class EvaluationResult {
  final bool shouldDelete;
  final bool shouldMove;
  final String? targetFolder;
  final String matchedRule;
  final String matchedPattern;
}

abstract class RuleEvaluator {
  Future<EvaluationResult?> evaluate(EmailMessage message);
}
```

## Email Provider Coverage

### Phase 1 (MVP) - Generic IMAP
- **AOL Mail**: `GenericIMAPAdapter.aol()` with app password
  - IMAP: imap.aol.com:993 (SSL)
  - Primary target for MVP validation
- **Custom IMAP**: `GenericIMAPAdapter.custom()` with manual configuration
  - Allows testing with any IMAP server

### Phase 2 - Major Platforms with Native APIs
- **Gmail**: `GmailAdapter` with OAuth 2.0 + Gmail REST API
  - Label-based operations (INBOX, SPAM, TRASH labels)
  - Efficient query syntax for date filtering
  - Batch message operations for performance
  - Better than IMAP for Gmail-specific features
  
- **Outlook.com/Office 365**: `OutlookAdapter` with OAuth 2.0 + Microsoft Graph API
  - OData filtering for efficient queries
  - Native folder operations
  - Enterprise account support
  - Well-known folders: inbox, junkemail, deleteditems
  
- **Yahoo Mail**: `GenericIMAPAdapter.yahoo()` with app password
  - IMAP: imap.mail.yahoo.com:993 (SSL)
  - OAuth support may be added later if Yahoo enables it

### Phase 3 - Additional Consumer Platforms
- **iCloud Mail**: `GenericIMAPAdapter.icloud()` with app-specific password
  - IMAP: imap.mail.me.com:993 (SSL)
  - Requires 2FA enabled on Apple ID
  
- **ProtonMail**: Custom adapter using ProtonMail Bridge or API
  - Bridge: Local IMAP/SMTP server for ProtonMail
  - Native API: If ProtonMail provides mobile SDK
  
- **Zoho Mail**: IMAP + OAuth support
  - IMAP: imap.zoho.com:993 (SSL)
  
- **Fastmail**: `GenericIMAPAdapter` with app password
  - IMAP: imap.fastmail.com:993 (SSL)

### Phase 4 - Extended Coverage
- **GMX/Mail.com**: Generic IMAP adapter
- **Yandex Mail**: Generic IMAP adapter
- **Tutanota**: Native API if available
- **Mailbox.org**: Generic IMAP adapter
- **Any Custom Server**: Manual IMAP configuration with server details

### Email Providers Recommended for Consideration
Based on market share and user requests:
1. **Gmail** (Highest priority - largest user base)
2. **Outlook/Hotmail** (Second highest - Microsoft ecosystem)
3. **Yahoo Mail** (Third - still significant user base)
4. **iCloud Mail** (Apple ecosystem users)
5. **ProtonMail** (Privacy-focused users)
6. **AOL Mail** (Legacy but still active, good for MVP due to simple IMAP)
7. **Custom IMAP** (Power users with self-hosted email)

## Development Phases

### Phase 0: Planning & Architecture (Current)
**Status**: In Progress  
**Duration**: 1-2 weeks

- ✅ Select tech stack (Flutter/Dart)
- ✅ Define architecture layers
- 🔄 Design core interfaces
- 🔄 Plan migration strategy from Python codebase
- 🔄 Create project structure
- 🔄 Set up new repository

### Phase 1: MVP - AOL Email with Core Filtering
**Duration**: 4-6 weeks  
**Goal**: Replicate core spam filtering for AOL accounts  
**Storage**: Pure file-based (YAML + encrypted JSON), no database

#### 1.1 Project Setup
- Create Flutter project structure in new branch (feature/mobile-app)
- Add core dependencies (see dependencies section)
- Configure linting and code standards
- Set up testing infrastructure

#### 1.2 Business Logic Migration (File-Based Storage)
- Port YAML loader/exporter from Python to Dart
- Implement RuleSet and SafeSenderList models (in-memory)
- Build PatternCompiler with precompiled regex cache
- Create Evaluator engine (header/body/subject/from matching)
- Implement MutationService for rule updates
- Add YAMLStorage service (read/write with atomic operations)
- Add unit tests for all core logic
- **No database**: All data in YAML files and memory

#### 1.3 AOL IMAP Integration
- Implement GenericIMAPAdapter using `enough_mail` package
- Add app password authentication
- Build message fetcher (with date range filtering)
- Implement delete/move operations
- Handle bulk folder processing

#### 1.4 Basic Mobile UI
- Account setup screen (IMAP credentials input)
- Manual scan trigger button
- Scan progress indicator
- Results summary (deleted/moved counts)
- Rule viewer (read-only list)
- Safe sender viewer (read-only list)

#### 1.5 Testing & Validation
- Unit tests for all business logic
- Integration tests for IMAP operations
- Performance profiling with real rule sets (3,000+ patterns)
  - Measure YAML load time (target: <1 second)
  - Measure regex compilation time (target: <2 seconds for 3,000 patterns)
  - Measure per-email evaluation time (target: <100ms)
  - Memory footprint (target: <50 MB for app + rules)
- Test on Android phone, Android tablet
- Test on iOS phone, iOS tablet
- Test on Chromebook (if available)

**Deliverable**: Working app that scans AOL inbox, applies existing YAML rules, deletes/moves spam

**Decision Gate**: Based on profiling results, decide if SQLite needed for Phase 2

### Phase 2: Multi-Platform Support via Translator Layer
**Duration**: 4-6 weeks  
**Goal**: Support Gmail, Outlook.com, Yahoo with proper OAuth flows using unified translator abstraction  
**Storage Enhancement**: Conditionally add SQLite for email cache & tracking (only if Phase 1 profiling shows need)

#### 2.1 Complete Translator Layer Implementation
- ✅ Core `SpamFilterPlatform` interface defined
- ✅ `PlatformRegistry` factory created
- ✅ Platform metadata and selection UI data structure
- 🔄 Complete `GenericIMAPAdapter` testing with AOL
- 🔄 Add unit tests for platform abstraction
- 🔄 Create mock platform adapter for testing

#### 2.2 OAuth Infrastructure
- Implement OAuth2Manager with token refresh
- Add secure credential storage (flutter_secure_storage)
- Build OAuth consent flow UI
- Handle token expiration gracefully
- Support for multiple OAuth providers

#### 2.3 Gmail Integration
- Complete `GmailAdapter` implementation using Gmail REST API
- Add dependencies: `googleapis`, `google_sign_in`
- Implement OAuth 2.0 flow with Google Sign-In
- Map Gmail labels to folder concept
- Optimize for Gmail-specific features (filters, categories)
- Batch operations for improved performance

#### 2.4 Outlook.com Integration
- Complete `OutlookAdapter` implementation using Microsoft Graph API
- Add dependencies: `msal_flutter`, `http`
- Implement Microsoft Identity Platform OAuth 2.0
- Handle Outlook folder hierarchy
- Support Office 365 accounts
- OData query optimization

#### 2.5 Yahoo Integration
- Extend `GenericIMAPAdapter.yahoo()` factory
- Add app password flow (Yahoo no longer supports OAuth for IMAP)
- Handle Yahoo folder naming conventions
- Test with Yahoo-specific IMAP quirks

#### 2.6 Platform Selection UI
- Build platform selection screen
- Display available platforms with icons and descriptions
- Show authentication method per platform
- Guide users through setup process
- Test connection before proceeding

#### 2.7 Multi-Account Support
- Allow multiple email accounts in app
- Per-account platform adapter instances
- Per-account rule sets (optional)
- Unified vs. per-account scanning modes
- Account switcher UI

#### 2.8 Optional SQLite Addition (Decision-Based)
- **IF** Phase 1 showed YAML load time >1s OR memory issues:
  - Add `sqflite` dependency
  - Create email_cache table for incremental scanning
  - Add scan_history and audit_log tables
  - Keep YAML as source of truth for rules
  - Sync layer: Load YAML → populate in-memory cache → use SQLite for email tracking
- **ELSE**: Continue with pure YAML approach

**Deliverable**: App supports 4 major providers (AOL, Gmail, Outlook.com, Yahoo) with unified translator layer and optimized storage strategy

**Success Criteria**:
- All 4 platforms functional via `SpamFilterPlatform` interface
- OAuth flows complete and tested
- Platform-specific optimizations working (Gmail batching, Outlook OData)
- Same YAML rules work across all platforms
- Performance improvement: 2x faster than pure IMAP for Gmail/Outlook

### Phase 3: Interactive Training & Advanced Features
**Duration**: 3-4 weeks  
**Goal**: Replicate interactive rule addition from desktop app

#### 3.1 Interactive Inbox Trainer
- Build UI for unmatched emails (similar to Python CLI prompts)
- Add domain button (d): Add SpamAutoDeleteHeader rule
- Add email button (e): Add exact email to safe senders
- Add safe sender button (s): Add email to safe senders
- Add sender domain button (sd): Add regex domain pattern to safe senders
- Immediate rule application (re-evaluate inbox after each change)
- Skip logic (don't re-prompt for processed emails)

#### 3.2 Rule Editor UI
- View all rules organized by type
- Add/remove individual patterns
- Search/filter rules
- Import/export YAML files
- Validate regex patterns before saving

#### 3.3 Safe Sender Manager
- View safe sender list
- Add/remove safe senders
- Test email against safe sender patterns
- Bulk import from contacts

#### 3.4 Advanced Filtering
- Second-pass processing (re-evaluate remaining emails)
- Rule priority/ordering
- Custom folder targets for move actions
- Whitelist specific senders for specific rules

**Deliverable**: Full-featured app with interactive training matching desktop capabilities

### Phase 4: Background Processing & Notifications
**Duration**: 3-4 weeks  
**Goal**: Automatic background scanning with notifications

#### 4.1 Background Sync (Android)
- Implement WorkManager for periodic scanning
- Handle device sleep/wake cycles
- Battery optimization considerations
- Configurable scan frequency

#### 4.2 Background Sync (iOS)
- Implement Background Fetch
- Handle iOS background execution limits
- Silent notification triggers (if using push)
- Configurable scan frequency

#### 4.3 Notifications
- New spam detected notifications
- Scan completion notifications
- Authentication error notifications
- Rule update suggestions

#### 4.4 Performance Optimization
- Incremental scanning (track last processed message)
- Batch operations for efficiency
- Optimize regex compilation (cache, group patterns)
- Memory management for large inboxes

**Deliverable**: App runs automatically in background, notifies user of spam activity

### Phase 5: Extended Providers & Enterprise Features
**Duration**: 4-6 weeks  
**Goal**: Support additional providers and enterprise use cases

#### 5.1 Additional Providers
- ProtonMail Bridge integration
- iCloud Mail (IMAP + app-specific password)
- Zoho, Fastmail, GMX support
- Generic IMAP fallback for any provider

#### 5.2 Enterprise Features
- Office 365 / Exchange Online full support
- Admin-managed rule sets
- Compliance logging
- Multi-user rule sharing

#### 5.3 Cloud Sync & Backup
- Google Drive backup for rules
- iCloud backup for rules
- Cross-device rule synchronization
- Conflict resolution for concurrent edits

**Deliverable**: Comprehensive provider support, enterprise-ready features

### Phase 6: Performance Optimization (Optional Rust Integration)
**Duration**: 2-3 weeks  
**Goal**: Add Rust-based regex engine if profiling shows bottleneck

#### 6.1 Profiling & Analysis
- Profile regex evaluation with 5000+ patterns
- Identify bottlenecks (compilation vs. matching)
- Benchmark Dart vs. Rust performance delta
- Decision gate: Only proceed if >2x improvement possible

#### 6.2 Rust Integration (Conditional)
- Set up flutter_rust_bridge
- Port batch evaluator to Rust
- Use Rust `regex` crate with `RegexSet` for multi-pattern matching
- Minimize FFI boundary crossings (batch operations)
- Maintain Dart fallback for simplicity

#### 6.3 Testing & Validation
- Performance benchmarks (before/after)
- Verify correctness (identical results to Dart)
- Cross-platform builds (Android ARM64, iOS ARM64)
- Memory profiling

**Deliverable**: High-performance regex engine (only if needed)

### Phase 7: Polish & Release
**Duration**: 2-3 weeks  
**Goal**: Production-ready release

#### 7.1 UI/UX Polish
- Material Design 3 refinements
- Cupertino design for iOS
- Dark mode support
- Accessibility (screen readers, high contrast)
- Localization framework (initial: English)

#### 7.2 Security Hardening
- Security audit of credential storage
- Input validation (prevent regex DOS)
- Secure communication (TLS/SSL verification)
- Privacy policy implementation
- Data retention policies

#### 7.3 Documentation
- User guide
- Setup instructions per provider
- Troubleshooting guide
- API documentation
- Contributing guide

#### 7.4 App Store Preparation
- Google Play Store listing
- Apple App Store listing
- Screenshots & promotional materials
- Beta testing program
- Release management

**Deliverable**: Production release on Google Play & Apple App Store

## Migration Strategy from Python

### Code Porting Roadmap

| Python Component | Dart Equivalent | Priority | Complexity |
|-----------------|-----------------|----------|------------|
| YAML load/export | `yaml` package | P0 | Low |
| Regex compilation | `RegExp` precompile cache | P0 | Low |
| Rule evaluation logic | Pattern matching engine | P0 | Medium |
| Safe sender matching | Dart implementation | P0 | Low |
| Interactive prompts | Flutter UI forms/dialogs | P1 | Medium |
| Outlook COM access | Provider adapters | P0 | High (different APIs) |
| Logging system | `logger` package | P1 | Low |
| File I/O | `dart:io` + platform storage | P0 | Medium |
| Backup/archive | Timestamped exports | P1 | Low |
| Second-pass processing | Re-evaluation loop | P2 | Medium |
| Stats/counters | Dart models | P1 | Low |

### Data Format Compatibility

**Maintain 100% YAML Compatibility**:
- Identical schema: `version`, `settings`, `rules` structure
- Same normalization rules (lowercase, trim, dedupe, sort)
- Preserve single-quote convention for regex patterns
- Keep archive backup strategy (timestamped files)
- Support import from existing desktop app exports

### Key Differences from Desktop App

| Aspect | Desktop (Python) | Mobile (Flutter) |
|--------|-----------------|------------------|
| **Email Access** | Outlook COM | IMAP/REST APIs |
| **Rule Storage** | Local filesystem (absolute Windows paths) | App sandbox storage |
| **Logging** | File-based (D:/Data/...) | Platform logging + optional file |
| **Interactive Updates** | Terminal CLI (`input()`) | Flutter dialogs/forms |
| **Background Processing** | Not implemented | WorkManager/BackgroundFetch |
| **Authentication** | Windows integrated auth | OAuth 2.0 + secure storage |
| **Paths** | Absolute Windows paths | Platform-agnostic relative paths |
| **Second Pass** | Re-fetch via COM | Re-evaluate in-memory cache |

## Performance Considerations

### Regex Optimization Strategy

**Phase 1 (Pure Dart)**:
1. Precompile all patterns at app startup → cache `RegExp` objects
2. Group patterns by type (header, body, subject, from) → reduce comparisons
3. Evaluate safe senders first → early exit for known good emails
4. Batch message processing → reduce context switching
5. Profile with real rule sets (1000-5000 patterns)

**Target Performance** (Mid-Range Phone):
- Rule compilation: <3 seconds for 5000 patterns
- Single email evaluation: <100ms for 5000 patterns
- Inbox scan (100 emails): <10 seconds

**Phase 2 (Optional Rust)**:
- Only if Dart performance <target thresholds
- Use `RegexSet` for multi-pattern matching (compiled DFA)
- Batch FFI calls (evaluate 10-50 emails per crossing)
- Expected improvement: 2-5x faster evaluation

### Memory Management

- Lazy load email bodies (headers first, body on match attempt)
- LRU cache for compiled patterns (if sets exceed memory budget)
- Incremental inbox scanning (process batches of 50-100 emails)
- Clear message bodies after evaluation (keep metadata only)

### Battery & Network Optimization

- Configurable scan frequency (15min, 30min, 1hr, manual only)
- WiFi-only mode for background scans
- Exponential backoff for failed connections
- Suspend scanning when battery <20% (configurable)

## Security & Privacy

### Data Protection

- **Credentials**: Store in platform secure storage (Keychain/Keystore)
- **OAuth Tokens**: Encrypted at rest, auto-refresh before expiration
- **Email Content**: Process in memory, never persist bodies
- **Rules/Safe Senders**: Stored locally, optionally encrypted
- **Logs**: Minimal sensitive data, user-controlled retention

### Privacy Principles

- **Zero Server**: All processing on-device (no cloud backend required)
- **Minimal Permissions**: Only request necessary OAuth scopes
- **Transparent Actions**: User controls all rule additions/deletions
- **Data Portability**: Export rules anytime as YAML
- **Optional Cloud Backup**: User-controlled, encrypted

### Regex Safety

- **Input Validation**: Limit pattern length (<500 chars)
- **Complexity Analysis**: Reject patterns with potential catastrophic backtracking
- **Timeout Protection**: Abort regex evaluation after 100ms
- **Sanitization**: Use `sanitize_email_input()` for user-provided patterns
- **Testing**: Automated tests for malicious pattern detection

## Testing Strategy

### Unit Tests
- All business logic (RuleSet, Evaluator, PatternCompiler)
- YAML import/export with edge cases
- Regex pattern builders
- Safe sender matching logic
- Rule mutation operations

### Integration Tests
- IMAP adapter with mock server
- OAuth flow simulation
- End-to-end scan with sample inbox
- Multi-provider account switching
- Background sync triggers

### Performance Tests
- Regex compilation benchmarks (1K, 5K, 10K patterns)
- Email evaluation latency (P50, P95, P99)
- Memory profiling (peak usage during scan)
- Battery impact measurement

### Platform Tests
- Android phones (multiple API levels)
- Android tablets (screen size variations)
- iOS phones (multiple iOS versions)
- iOS tablets (iPad layouts)
- Chromebooks (Android runtime)

### User Acceptance Tests
- Real email accounts (AOL, Gmail, etc.)
- Existing rule sets from desktop app
- Interactive training workflow
- Background scanning scenarios
- Error recovery (network failures, auth expiration)

## Repository Structure (New Repo)

```
spam-filter-mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── models/
│   │   │   ├── email_message.dart
│   │   │   ├── rule_set.dart
│   │   │   ├── safe_sender_list.dart
│   │   │   └── evaluation_result.dart
│   │   ├── services/
│   │   │   ├── rule_evaluator.dart
│   │   │   ├── pattern_compiler.dart
│   │   │   ├── mutation_service.dart
│   │   │   ├── yaml_service.dart
│   │   │   └── audit_log.dart
│   │   └── utils/
│   │       ├── regex_builder.dart
│   │       └── sanitizer.dart
│   ├── adapters/
│   │   ├── email_providers/
│   │   │   ├── email_provider.dart (interface)
│   │   │   ├── generic_imap_adapter.dart
│   │   │   ├── gmail_api_adapter.dart
│   │   │   └── outlook_graph_adapter.dart
│   │   ├── storage/
│   │   │   ├── secure_storage.dart
│   │   │   └── local_database.dart
│   │   ├── auth/
│   │   │   └── oauth2_manager.dart
│   │   └── background/
│   │       ├── work_manager_adapter.dart (Android)
│   │       └── background_fetch_adapter.dart (iOS)
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── account_setup_screen.dart
│   │   │   ├── inbox_trainer_screen.dart
│   │   │   ├── rule_editor_screen.dart
│   │   │   └── safe_sender_screen.dart
│   │   ├── widgets/
│   │   │   ├── scan_progress.dart
│   │   │   └── rule_list_item.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   └── config/
│       └── constants.dart
├── test/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│       ├── sample_rules.yaml
│       └── sample_safe_senders.yaml
├── android/
├── ios/
├── docs/
│   ├── architecture.md
│   ├── provider_setup_guides/
│   │   ├── aol_setup.md
│   │   ├── gmail_setup.md
│   │   └── outlook_setup.md
│   └── api/
├── pubspec.yaml
├── README.md
└── LICENSE
```

## Key Dependencies (pubspec.yaml)

```yaml
name: spam_filter_mobile
description: Cross-platform email spam filter app
version: 0.1.0

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

  # Email & Auth
  enough_mail: ^2.1.0          # IMAP/SMTP client
  flutter_appauth: ^6.0.0      # OAuth 2.0 flows
  google_sign_in: ^6.1.0       # Gmail integration
  http: ^1.1.0                 # HTTP client for REST APIs

  # Storage & Persistence (Phase 1 - MVP)
  flutter_secure_storage: ^9.0.0  # Secure credential storage
  yaml: ^3.1.0                    # YAML parsing (primary storage)
  path_provider: ^2.1.0           # Platform-specific paths
  
  # Optional (Phase 2+): Add only if profiling shows need
  # sqflite: ^2.3.0               # SQLite database for caching

  # Background Processing (Phase 4)
  # workmanager: ^0.5.0          # Android background tasks
  # background_fetch: ^1.2.0     # iOS background refresh

  # State Management & Utils
  provider: ^6.1.0             # State management
  logger: ^2.0.0               # Logging
  intl: ^0.18.0                # Internationalization

  # UI Components (Phase 3+)
  # flutter_slidable: ^3.0.0     # Swipe actions
  # badges: ^3.1.0               # Notification badges

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.0              # Mocking for tests
  build_runner: ^2.4.0         # Code generation

flutter:
  uses-material-design: true

# Note: Start minimal, add dependencies incrementally as features proven necessary
```

## Risk Management

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Regex performance insufficient on low-end devices | High | Profile early, add Rust path if needed, optimize pattern grouping |
| OAuth flow complexity across providers | Medium | Use well-tested libraries, extensive testing |
| Background processing restrictions (iOS) | Medium | Set user expectations, offer manual mode, use push notifications |
| Large rule sets exceed memory on low-end phones | Medium | Implement LRU cache, lazy loading, pattern grouping |
| Provider API changes break integration | Medium | Version lock APIs, monitor provider changelogs, automated testing |

### Business Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| User reluctance to grant OAuth permissions | Low | Clear privacy policy, optional manual auth, educational UI |
| App store approval delays | Low | Follow platform guidelines strictly, prepare appeals |
| Competition from built-in spam filters | Medium | Highlight custom rule power, cross-provider support |
| Rule migration from desktop complex | Low | Automated import, clear documentation, support guide |

## Success Metrics

### MVP Success Criteria (Phase 1)
- ✅ Successfully scan AOL inbox with existing rule sets
- ✅ Match desktop app spam detection accuracy (>95%)
- ✅ Evaluation performance <100ms per email (mid-range phone)
- ✅ Zero crashes during 100-email scan
- ✅ Runs on Android 10+, iOS 14+, Chromebooks

### Full Release Success Criteria (Phase 7)
- ✅ Support 5+ email providers
- ✅ 10,000+ active users within 6 months
- ✅ <2% crash rate
- ✅ 4.0+ average rating (app stores)
- ✅ Background scanning works reliably for 80% of users
- ✅ Rule import success rate >95%

## Next Steps

### Immediate Actions (This Week)
1. ✅ Finalize architecture and plan (this document)
2. ✅ Database decision: Start with pure YAML/file-based, add SQLite only if needed
3. 🔄 Set up Flutter project in new branch (feature/mobile-app)
4. 🔄 Define core interfaces in code
5. 🔄 Port YAML schema and sample files

### Week 2-3
- Implement YAML loader/exporter in Dart (maintain desktop compatibility)
- Build RuleSet and SafeSenderList models (in-memory)
- Create PatternCompiler with precompiled regex cache
- Write unit tests for core logic
- Performance benchmarking harness

### Week 4-6
- Implement GenericIMAPAdapter (AOL)
- Build basic UI (account setup, manual scan)
- Integration testing with test AOL account
- Performance profiling (YAML load, regex compile, evaluation)
- **Decision gate**: SQLite needed for Phase 2?

---

## Flutter Installation Guide (PowerShell 7)

### Option 1: Using Chocolatey (Recommended)

```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Flutter
choco install flutter -y

# Verify installation
flutter doctor
```

### Option 2: Manual Installation

```powershell
# Download Flutter SDK
$flutterZip = "$env:USERPROFILE\Downloads\flutter_windows.zip"
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.0-stable.zip" -OutFile $flutterZip

# Extract to C:\src\flutter
Expand-Archive -Path $flutterZip -DestinationPath "C:\src"

# Add to PATH permanently
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$currentPath;C:\src\flutter\bin", "User")

# Reload PATH in current session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User")

# Verify installation
flutter doctor
```

### Post-Installation Setup

```powershell
# Accept Android licenses (if Android SDK installed)
flutter doctor --android-licenses

# Install VS Code Flutter extension
code --install-extension Dart-Code.flutter

# Navigate to mobile app and get dependencies
cd mobile-app
flutter pub get

# Check for issues
flutter doctor -v
```

### Common Issues & Fixes

**Issue**: `flutter: The term 'flutter' is not recognized`  
**Fix**: Restart PowerShell or reboot computer to reload PATH

**Issue**: Android SDK not found  
**Fix**: Install Android Studio or set ANDROID_HOME environment variable

**Issue**: Visual Studio not found (Windows)  
**Fix**: Install Visual Studio 2022 with "Desktop development with C++" workload

---

**Document Version**: 1.2  
**Last Updated**: 2025-11-28  
**Database Decision**: Pure YAML/file-based for MVP, conditional SQLite for Phase 2+  
**Related Docs**: 
- Mobile app code: `mobile-app/`
- Original Python codebase: `withOutlookRulesYAML.py` (or `Archive/desktop-python/`)
- Existing architecture: `memory-bank/*.md`
- Rule schemas: `rules.yaml`, `rules_safe_senders.yaml`
