Claude Code Issues to be resolved
  ⎿ PreToolUse:Edit hook error: Failed with non-blocking status code: Python was not found; run without arguments to install from the Microsoft Store, or
    disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.


***BELOW IS NOT FOR CLAUDE CODE USE***
***BELOW IS NOT FOR Github Copilot USE***
Phase 4 Development Goals
- Expand to iOS platform
- Expand to apple email 
- macOS DMG installer

Phase 5 Development Goals
- Expand to Web App that can run from Browser via user login

Phase 6 Development Goals
- Expand to IMAP email providers (Generic, Yahoo, ProtonMail)

Phase 7 Development Goals
- Expand to other OAuth 2.0 email providers (Outlook.com, TBD)
- Consider - Memory Management
  - Lazy load email bodies (headers first, body on match attempt)
  - LRU cache for compiled patterns (if sets exceed memory budget)
  - Incremental inbox scanning (process batches of 50-100 emails)
  - Clear message bodies after evaluation (keep metadata only)

- Consider - Battery & Network Optimization
  - Configurable scan frequency (15min, 30min, 1hr, manual only)
  - WiFi-only mode for background scans
  - Exponential backoff for failed connections
  - Suspend scanning when battery <20% (configurable)

- Interactive Training & Advanced Features



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

**Development Directives**
Provider Focus: Prioritize ONLY Gmail and AOL until full functionality (setup, multi-folder scanning including junk folders, rule add/update, production mode delete and move) is confirmed on Windows and Android. Defer all other email providers (Outlook, Yahoo, iCloud, ProtonMail, Custom IMAP) to post phase 3 (see Phase <n> Development Goals).

**Key Architecture Principles**
All App Platforms should
- Use the same code for as much as possible, but deviate when necessary.
  - Deviations should be via Object Oriented "Factory" or similar tools if possible.
  - Deviate via separate functions when necessary and possible.
- Use the same basic UI for as much as possible.
  - Adapt via CSS or similar UI conventions whenever possible to avoid needing different code
  - Use different code when necessary.
All email platforms and email addresses should
- Use the same code for as much as possible, but deviate when necessary.


## Architecture Decision: 100% Flutter for All Platforms (December 11, 2025)

**Decision Rationale**:
- Outlook desktop client no longer used (web client migration complete)
- AOL IMAP connection fully functional
- Single Flutter codebase reduces development burden by 50%+
- Eliminates Python desktop app maintenance burden
- Enables parallel development across all 5 platforms
- IMAP/OAuth provides universal email provider support

**Platforms Supported** (5 total):
- Windows (desktop build via `flutter build windows`)
- Android (mobile build via `flutter build apk`)
- iOS (mobile build via `flutter build ios`) - Future
- macOS (desktop build via `flutter build macos`) - Future
- Linux (desktop build via `flutter build linux`) - Possible in the future

**Email Providers** (Phase Priority - Updated Dec 17):
- **AOL** - IMAP (Phase 2 - Live testing - PRIMARY FOCUS)
- **Gmail** - OAuth 2.0 (Phase 2 - PRIMARY FOCUS; Android/iOS working, Windows OAuth implemented Dec 16)
- **iCloud** - IMAP (DEFERRED to Phase 4+ until Gmail/AOL full functionality confirmed)
- **Generic IMAP** for custom providers (DEFERRED to Phase 6+ until Gmail/AOL validated)
- **Yahoo** - IMAP (DEFERRED to Phase 6+ until Gmail/AOL full functionality confirmed)
- **ProtonMail** - IMAP (DEFERRED to Phase 3+ until Gmail/AOL full functionality confirmed)
- **Outlook.com** - OAuth 2.0 (DEFERRED to Phase 3+ until Gmail/AOL full functionality confirmed)

- **AppPaths**: Platform-agnostic file system helper
  - Auto-creates app support directory structure (rules, credentials, backups, logs)
  - Single API for all platform paths (iOS, Android, desktop)
  - Backup filename generation and file management utilities
- **LocalRuleStore**: YAML file persistence with defaults
  - Load rules/safe senders with auto-create defaults on first run
  - Save with automatic timestamped backups
  - Integrates with YamlService for compatibility
  - Backup listing and pruning capability
- **SecureCredentialsStore**: Encrypted credential storage
  - Uses flutter_secure_storage (Keychain iOS, Keystore Android)
  - Multi-account support with account tracking
  - OAuth token storage and retrieval
  - Platform availability testing
- **RuleSetProvider**: Rule state management via Provider pattern
  - Async initialization of AppPaths and rule loading
  - Load/save rules with persistence
  - Add/remove/update rule operations with automatic persistence
  - Add/remove safe sender patterns with automatic persistence
  - Loading state management (idle, loading, success, error)
  - Ready for UI consumption via Provider.of<>() pattern
- **EmailScanProvider**: Scan progress and results state
  - Track scan progress (total, processed, current email)
  - Categorize results (deleted, moved, safe senders, errors)
  - Pause/resume/complete/error functionality
  - Summary generation for results display
  - Ready for progress UI bars and results screens
- **Provider Integration**: Multi-provider setup in main.dart
  - RuleSetProvider and EmailScanProvider initialized on app startup
  - Loading UI while initializing rules
  - Error UI if initialization fails
  - Automatic rule loading via initialize() call

#



### Layered Architecture

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚              Flutter UI Layer                       â”‚
â”‚  - Platform selection (Gmail, Outlook, AOL, etc.)   â”‚
â”‚  - Account setup & OAuth flows                      â”‚
â”‚  - Rule editor (view/add/remove patterns)           â”‚
â”‚  - Safe sender manager                              â”‚
â”‚  - Interactive inbox trainer (d/e/s/sd options)     â”‚
â”‚  - Scan status & notifications                      â”‚
â”‚  Material Design (Android) + Cupertino (iOS)        â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚         Business Logic Layer (Pure Dart)            â”‚
â”‚  - RuleSet: In-memory rule management               â”‚
â”‚  - SafeSenderList: Whitelist management             â”‚
â”‚  - PatternCompiler: Precompile & cache regex        â”‚
â”‚  - RuleEvaluator: Apply rules to messages           â”‚
â”‚  - YamlService: Load/save YAML rules                â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚   â­ Translator Layer (SpamFilterPlatform)          â”‚
â”‚  Unified abstraction for all email providers:       â”‚
â”‚    - loadCredentials(credentials)                   â”‚
â”‚    - fetchMessages(daysBack, folderNames)           â”‚
â”‚    - applyRules(messages, compiledRegex)            â”‚
â”‚    - takeAction(message, action)                    â”‚
â”‚    - listFolders()                                  â”‚
â”‚    - testConnection()                               â”‚
â”‚    - disconnect()                                   â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚       Platform-Specific Adapters                    â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚  â”‚ Gmail       â”‚  â”‚  Outlook/    â”‚  â”‚  Generic   â”‚ â”‚
â”‚  â”‚ Adapter     â”‚  â”‚  Office365   â”‚  â”‚  IMAP      â”‚ â”‚
â”‚  â”‚             â”‚  â”‚  Adapter     â”‚  â”‚  Adapter   â”‚ â”‚
â”‚  â”‚ OAuth 2.0   â”‚  â”‚  OAuth 2.0   â”‚  â”‚  App Pass  â”‚ â”‚
â”‚  â”‚ Gmail API   â”‚  â”‚  Graph API   â”‚  â”‚  IMAP      â”‚ â”‚
â”‚  â”‚ Labels      â”‚  â”‚  Folders     â”‚  â”‚  Folders   â”‚ â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚       Phase 2         Phase 5+          Phase 1     â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚          Email Provider APIs                        â”‚
â”‚  Gmail REST API | Microsoft Graph API | IMAP/SMTP   â”‚
â”‚  - Evaluator: Message â†’ Action decision engine      â”‚
â”‚  - MutationService: Add/remove rules (immediate)    â”‚
â”‚  - YAMLService: Import/export with validation       â”‚
â”‚  - AuditLog: Track actions & stats                  â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚           Adapter Layer (Dart)                      â”‚
â”‚  Email Providers:                                   â”‚
â”‚    - GenericIMAPAdapter (AOL, Yahoo baseline)       â”‚
â”‚    - GmailAPIAdapter (Gmail via REST API)           â”‚
â”‚    - OutlookGraphAdapter (Outlook.com, Office 365)  â”‚
â”‚    - ProtonMailBridgeAdapter (desktop relay)        â”‚
â”‚  Storage (Phase 1 - MVP):                           â”‚
â”‚    - YAMLStorage: rules.yaml, safe_senders.yaml     â”‚
â”‚    - SecureStorage: Encrypted credentials & tokens  â”‚
â”‚    - FileStorage: Simple JSON for stats/logs        â”‚
â”‚  Storage (Phase 2 - Optional):                      â”‚
â”‚    - SQLiteCache: Email metadata, scan tracking     â”‚
â”‚    - YAMLStorage: Still primary for rules           â”‚
â”‚  Background:                                        â”‚
â”‚    - WorkManager (Android scheduled tasks)          â”‚
â”‚    - BackgroundFetch (iOS background refresh)       â”‚
â”‚  Auth:                                              â”‚
â”‚    - OAuth2Manager: Token acquisition & refresh     â”‚
â”‚    - AppPasswordManager: Legacy auth fallback       â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                     â†“ â†‘
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚          External Services                          â”‚
â”‚  - Email Providers (IMAP, Gmail API, Graph API)     â”‚
â”‚  - OAuth Identity Providers                         â”‚
â”‚  - Cloud Storage (optional backup)                  â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

- `AppPaths` helper for file system access
  - Auto-creates app support directory structure (rules, credentials, backups, logs)
  - Platform-agnostic paths (iOS, Android, desktop)
  - Single API for all app storage locations
- `LocalRuleStore` for YAML file persistence
  - Load/save rules and safe senders with auto-default creation
  - Automatic timestamped backups before writes
  - Backup listing and pruning capability
  - Leverages existing YamlService for desktop compatibility
- `SecureCredentialsStore` for encrypted credential storage
  - Uses flutter_secure_storage (Keychain iOS, Keystore Android)
  - Multi-account support with account tracking
  - OAuth token storage and retrieval (access, refresh)
  - Platform availability testing
- `RuleSetProvider` for rule state management
  - Async initialization of AppPaths and rule loading
  - Load/save rules with persistence
  - Add/remove/update operations with automatic persistence
  - Add/remove safe senders with automatic persistence
  - Loading state management (idle, loading, success, error)
  - Ready for UI consumption via Provider.of<>() pattern
- `EmailScanProvider` for scan progress and results state
  - Track scan progress (total, processed, current email)
  - Categorize results (deleted, moved, safe senders, errors)
  - Pause/resume/complete/error functionality
  - Summary generation for results display
  - Ready for progress UI bars and results screens
- Provider integration in main.dart
  - Multi-provider setup with RuleSetProvider and EmailScanProvider
  - Automatic rule loading on app startup
  - Loading UI while initializing
  - Error UI if initialization fails


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
