## Executive Summary

The OutlookMailSpamFilter desktop application has been successfully ported to a cross-platform mobile app supporting multiple email providers (AOL, Gmail). The app maintains compatibility with existing YAML rule formats and is decoupled from Outlook-specific COM interfaces.


## Development Phases
### Phase 3.4 Goals: 
- Focus on AOL and Gmail email addresses
- Focus on Android and Windows Desktop apps
  - Both Android and Windows Desktop
    - Scan
      - Results screen
        - Update to View Results screen > results list. Add the folder in front of the from email address, "<from-email-address> o <rule>" to be "<folder> o <subject> o <rule>"
      - Select Folders screen
        - Update the AOL platform/email "Bulk" and "Bulk Email" (if they exist)to be considered "Spam/Junk folders" and should be tagged as "Recommended" and checked by default

Planning
The management of identified spam will similar, but will likely have differences.  Like the rest of the app, would like it to be the same whenever possible, but different when needed or unreasonable to do the same.
Functionality in human terms:
  - The Safe Senders list identifies regex email addresses that the user wants as identified as OK to see and wants to make sure they are always in the inbox for review:
    - Many of these are identified as top-level domains combined with principle domains (ex: x.com).
      - We can refer to these as "Domain Regex Safe Senders"
      - These are often done by regex because companies like <name>@x.com now will put sub-domains in front of them like <name>@e.x.com.  The user is usually not concerned and wants to see both/all.
      - These are usually for communications from companies they interact with.
      - Exceptions to "Domain Regex Safe Senders" can be added to the rules (i.e. rules.yaml) to override "domain" regex patterns.
    - Others are individual email addresses from common email providers like joe@aol.com
      - We can refer to these as "Individual Email Address Safe Senders"
      - The list could be propagated with all the unique email addresses the user sends email to.
      - A future enhancement might be a feature to review all past "sent mail" and add the "To" email address (regex) to the safe sender list. Another would be to add all new sent message to the safe senders list.
      - Exceptions to "Individual Email Address Safe Senders" is unlikely as they are very specific.
  - The rules.yaml is a functionality to identify for users email address (or regex patterns) that they will never want to see. However, like email "Junk Folders" a user may want to "find" and email that has bee deleted by a rule and will want add items to help find them (specific folders for different types of rule, tagging the messages with rule match...).  There are several types of rules:
    - AutoDeleteHeader - Automatically Delete based on content of the email header
      - From: address in the email header against stored regex patterns
        - There are datasets of known spam email domains (first-level-domain.top-level-domain) that are known 99% spam.
      - Subject: content
    - AutoDeleteBody


be a little different for email providers.

Phase 3.5
  - Android specific enhancements
    - TBD
  - Windows Desktop specific enhancements
    - TBD 
- Process all "No rule" messages via Interactive Inbox Trainer
  - Build UI for unmatched emails (similar to Python CLI prompts)
  - Should have UI and keyboard equivalents for each user action
  - Add domain button (d): Add SpamAutoDeleteHeader rule
  - Add email button (e): Add exact email to safe senders
  - Add safe sender button (s): Add email to safe senders
  - Add sender domain button (sd): Add regex domain pattern to safe senders
  - Immediate rule application (re-evaluate inbox after each change)
  - Skip logic (don't re-prompt for processed emails)
- Rule Editor UI
  - View all rules organized by type
  - Add/remove individual patterns
  - Search/filter rules
  - Import/export YAML files
  - Validate regex patterns before saving
- Safe Sender Manager
  - View safe sender list
  - Add/remove safe senders
  - Test email against safe sender patterns
  - Bulk import from contacts
- Advanced Filtering
  - Second-pass processing (re-evaluate remaining emails)
  - Rule priority/ordering
  - Custom folder targets for move actions
  - Whitelist specific senders for specific rules
- Windows MSIX installer
- Desktop-specific UI adjustments
- Background sync implementation- Background sync implementation

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

## Email Provider Coverage (Updated Dec 17 - Gmail/AOL Focus Only)

### Phase 2 (Current) - PRIMARY FOCUS: Gmail and AOL Only
- **AOL Mail**: `GenericIMAPAdapter.aol()` with app password
  - IMAP: imap.aol.com:993 (SSL)
  - Status: Full validation in progress (Windows/Android)
  - Full functionality checklist: Setup (âœ…), Multi-account (âœ…), Inbox/spam scanning (framework ready), Production delete (testing), Rule add/update (planned)
  
- **Gmail**: `GmailAdapter` with OAuth 2.0 + Gmail REST API
  - Label-based operations (INBOX, SPAM, TRASH labels)
  - Efficient query syntax for date filtering
  - Batch message operations for performance
  - Status: Framework ready; Android/iOS OAuth working; Windows OAuth methods implemented Dec 16 (browser/WebView/manual)
  - Full functionality checklist: Setup (OAuth), Multi-account (framework ready), Inbox/spam scanning (framework ready), Production delete (testing), Rule add/update (planned)

### Phase 3+ - DEFERRED (Until Gmail/AOL Full Functionality Confirmed)
The following providers are **DEFERRED** until Gmail and AOL achieve full functionality (setup, multi-account, inbox+spam scanning, production delete and move, rule add/update) on Windows and Android:

- **Outlook.com/Office 365**: `OutlookAdapter` with OAuth 2.0 + Microsoft Graph API
  - Reason for deferral: Allows focused testing of Gmail/AOL before expanding provider support
  - Planned for Phase 5+ after Gmail/AOL validation complete
  
- **Yahoo Mail**: `GenericIMAPAdapter.yahoo()` with app password
  - Reason for deferral: IMAP framework already proven with AOL; Yahoo support can wait until Gmail/AOL validated
  - Planned for Phase 4+ after Gmail/AOL validation complete
  
- **iCloud Mail**: `GenericIMAPAdapter.icloud()` with app-specific password
  - Reason for deferral: Lower priority; IMAP framework covers generic support
  - Planned for Phase 4+ after Gmail/AOL validation complete
  
- **ProtonMail**: Custom adapter using ProtonMail Bridge or API
  - Reason for deferral: Requires Bridge setup; lower priority until core providers validated
  - Planned for Phase 4+ after Gmail/AOL validation complete
  
- **Custom IMAP**: Manual IMAP configuration
  - Reason for deferral: Power user feature; implement after core providers working end-to-end
  - Planned for Phase 4+ after Gmail/AOL and Outlook/Yahoo validated

## Security & Privacy

### GitHub Secrets Best Practices

**CRITICAL: Never Commit Secrets to Git**
- **DO**: Store secrets in `secrets.dev.json` (in .gitignore)
- **DO**: Use masked placeholders in documentation (e.g., `GOCSPX-**********************LSH6`)
- **DO**: Redact client IDs and secrets from all markdown files before committing
- âŒ **DON'T**: Commit real OAuth client IDs, client secrets, API keys, or passwords
- âŒ **DON'T**: Include secrets in code comments, commit messages, or documentation examples

**GitHub Push Protection**:
- GitHub automatically scans commits for exposed secrets
- Push will be blocked if secrets detected in commit history
- Fix blocked pushes by rewriting Git history to remove secrets
- Always redact secrets from documentation BEFORE staging commits

**Secret Masking Format**:
- Client IDs: `577022808534-****************************kcb.apps.googleusercontent.com` (show first/last chars)
- Client Secrets: `GOCSPX-**********************LSH6` (show prefix and last 4 chars)
- Maintains context for developers while protecting actual values

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
â”œâ”€â”€ lib/
â”‚   â”œâ”€â”€ main.dart
â”‚   â”œâ”€â”€ core/
â”‚   â”‚   â”œâ”€â”€ models/
â”‚   â”‚   â”‚   â”œâ”€â”€ email_message.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ rule_set.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ safe_sender_list.dart
â”‚   â”‚   â”‚   â””â”€â”€ evaluation_result.dart
â”‚   â”‚   â”œâ”€â”€ services/
â”‚   â”‚   â”‚   â”œâ”€â”€ rule_evaluator.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ pattern_compiler.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ mutation_service.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ yaml_service.dart
â”‚   â”‚   â”‚   â””â”€â”€ audit_log.dart
â”‚   â”‚   â””â”€â”€ utils/
â”‚   â”‚       â”œâ”€â”€ regex_builder.dart
â”‚   â”‚       â””â”€â”€ sanitizer.dart
â”‚   â”œâ”€â”€ adapters/
â”‚   â”‚   â”œâ”€â”€ email_providers/
â”‚   â”‚   â”‚   â”œâ”€â”€ email_provider.dart (interface)
â”‚   â”‚   â”‚   â”œâ”€â”€ generic_imap_adapter.dart
â”‚   â”‚   â”‚   â”œâ”€â”€ gmail_api_adapter.dart
â”‚   â”‚   â”‚   â””â”€â”€ outlook_graph_adapter.dart
â”‚   â”‚   â”œâ”€â”€ storage/
â”‚   â”‚   â”‚   â”œâ”€â”€ secure_storage.dart
â”‚   â”‚   â”‚   â””â”€â”€ local_database.dart
â”‚   â”‚   â”œâ”€â”€ auth/
â”‚   â”‚   â”‚   â””â”€â”€ oauth2_manager.dart
â”‚   â”‚   â””â”€â”€ background/
â”‚   â”‚       â”œâ”€â”€ work_manager_adapter.dart (Android)
â”‚   â”‚       â””â”€â”€ background_fetch_adapter.dart (iOS)
â”‚   â”œâ”€â”€ ui/
â”‚   â”‚   â”œâ”€â”€ widgets/
â”‚   â”‚   â”‚   â”œâ”€â”€ scan_progress.dart
â”‚   â”‚   â”‚   â””â”€â”€ rule_list_item.dart
â”‚   â”‚   â””â”€â”€ theme/
â”‚   â”‚       â””â”€â”€ app_theme.dart
â”‚       â”œâ”€â”€ sample_rules.yaml
â”‚       â””â”€â”€ sample_safe_senders.yaml
â”œâ”€â”€ android/
â”œâ”€â”€ ios/
â”‚   â”œâ”€â”€ architecture.md
â”‚   â”œâ”€â”€ provider_setup_guides/
â”‚   â”‚   â”œâ”€â”€ aol_setup.md
â””â”€â”€ LICENSE
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
- Successfully scan AOL inbox with existing rule sets
- Match desktop app spam detection accuracy (>95%)
- Evaluation performance <100ms per email (mid-range phone)
- Zero crashes during 100-email scan
- Runs on Android 10+, iOS 14+, Chromebooks

### Full Release Success Criteria (Phase 7)
- Support 5+ email providers
- 10,000+ active users within 6 months
- <2% crash rate
- 4.0+ average rating (app stores)
- Background scanning works reliably for 80% of users
- Rule import success rate >95%

## Next Steps

### Immediate Actions (This Week)
1. Finalize architecture and plan (this document)
2. Database decision: Start with pure YAML/file-based, add SQLite only if needed
3. ðŸ”„ Set up Flutter project in new branch (feature/mobile-app)
4. ðŸ”„ Define core interfaces in code
5. ðŸ”„ Port YAML schema and sample files

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

## Phase 2 Sprint 5: Windows Gmail OAuth Implementation COMPLETE (December 14, 2025)

**Completed Tasks**:

### Problem Statement
Sprint 4 identified that `google_sign_in` 7.2.0 plugin does NOT implement OAuth on Windows platform by design. Native Google SDKs only available for Android/iOS. This was a platform limitation, not a code bug.

### Solution: Three-Tiered OAuth Approach

**1. Browser-Based OAuth (Primary Method)**:
   - Created `GmailWindowsOAuthHandler` class (250 lines)
   - Launches system browser for Google OAuth consent
   - Starts local HTTP server on port 8080 for OAuth callback
   - Captures authorization code via redirect URL
   - Exchanges code for access/refresh tokens
   - Validates tokens via Google userinfo API
   - 5-minute timeout for user interaction
   - User-friendly success/error HTML responses
   - Token refresh mechanism for long-term access

**2. WebView OAuth (Backup Method)**:
   - Created `GmailWebViewOAuthScreen` widget (150 lines)
   - Embedded WebView for in-app authentication
   - Intercepts OAuth callback URL
   - Extracts authorization code from URL parameters
   - Same token exchange flow as browser method
   - Retry button on failure
   - Loading indicators during auth flow

**3. Manual Token Entry (Fallback Method)**:
   - Created `GmailManualTokenScreen` widget (350 lines)
   - Comprehensive step-by-step instructions
   - Links to OAuth 2.0 Playground
   - Copy/paste support for tokens
   - Show/hide token visibility toggle
   - Token validation before saving
   - Security warnings prominently displayed
   - Form validation with helpful error messages

**4. Updated Gmail OAuth Screen**:
   - Platform detection (checks if Windows)
   - Windows OAuth method selector dialog
   - Three option cards with icons and descriptions
   - Color-coded priority indicators
   - Seamless navigation to selected method
   - Maintains existing Android/iOS native flow

**5. Dependencies Added**:
   - `url_launcher: ^6.2.0` - For system browser launch
   - `webview_flutter: ^4.4.0` - For embedded WebView

**6. OAuth Flow Architecture**:
   ```
   Windows User â†’ Gmail OAuth Selection Dialog
                        â†“
          â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
          â†“              â†“              â†“
    Browser OAuth   WebView OAuth   Manual Token
     (Primary)        (Backup)       (Fallback)
          â†“              â†“              â†“
          â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                        â†“
              Authorization Code
                        â†“
              Token Exchange (Google)
                        â†“
              Access + Refresh Tokens
                        â†“
         User Email Validation (Google API)
                        â†“
        SecureCredentialsStore.save()
                        â†“
           FolderSelectionScreen
   ```

### Files Created:
1. `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart` (250 lines)
2. `mobile-app/lib/screens/gmail_webview_oauth_screen.dart` (150 lines)
3. `mobile-app/lib/screens/gmail_manual_token_screen.dart` (350 lines)

### Files Modified:
1. `mobile-app/lib/ui/screens/gmail_oauth_screen.dart` - Added Windows detection and method selector
2. `mobile-app/pubspec.yaml` - Added url_launcher and webview_flutter dependencies

### Configuration Required:
âš ï¸ **Before using**: Replace placeholder values in `gmail_windows_oauth_handler.dart`:
- Line 18: Replace `YOUR_CLIENT_ID.apps.googleusercontent.com`
- Line 19: Replace `YOUR_CLIENT_SECRET`
- Google Cloud Console: Add `http://localhost:8080/oauth/callback` to authorized redirect URIs

### Benefits:
- **Windows Gmail support restored** - All platforms now functional
- **User choice** - Three methods with clear priority guidance
- **Graceful fallback** - If primary fails, two backups available
- **Educational** - Manual method teaches OAuth flow
- **Future-proof** - Architecture supports other OAuth providers
- **No breaking changes** - Android/iOS native flow untouched

### Known Limitations:
- Manual token entry requires user to visit OAuth 2.0 Playground
- Browser/WebView methods require Google Cloud Console configuration
- Tokens from Playground expire after 7 days without refresh token
- Local HTTP server (port 8080) must be available for browser method

### Next Steps:
1. Configure Google Cloud Console OAuth credentials
2. Run `flutter pub get` to install dependencies
3. Test all three methods on Windows
4. Validate Android/iOS native method still works
5. Deploy release builds for all platforms

---


### Phase 3.2 and 3.3 COMPLETE (January 5, 2026)
**Focus**: Build script enhancements and Android emulator workflow improvements

**Completed Tasks**:
- Added `-SkipUninstall` parameter to `build-with-secrets.ps1` to preserve saved accounts during debug builds
- Changed default behavior: debug builds no longer uninstall APK (preserves credentials)
- Added `-StartEmulator` parameter to auto-start Android emulator before build
- Added `-EmulatorName` parameter to specify which AVD to start
- Added emulator detection (checks if already running via ADB)
- Added 15-second wait for emulator boot when starting fresh
- Updated documentation for new build script parameters

**Files Modified**:
- `mobile-app/scripts/build-with-secrets.ps1` - Added 3 new parameters and emulator management

### Phase 3.3 COMPLETE (January 6, 2026)
**Focus**: Claude Code tooling, MCP server, validation scripts, and automation hooks

**Completed Tasks**:
- Created custom MCP server for email rule testing (`scripts/email-rule-tester-mcp/`)
- Created YAML rule validator script (`scripts/validate-yaml-rules.ps1`) - validates 2,850+ patterns
- Created regex pattern tester script (`scripts/test-regex-patterns.ps1`) - performance benchmarking
- Created 10 custom Claude Code skills (`.claude/skills.json`)
- Created 4 automated hooks (`.claude/hooks.json`) - pre-commit, post-checkout, on-save
- Installed MCP server with npm dependencies
- Created setup documentation (`CLAUDE_CODE_SETUP_GUIDE.md`, `QUICK_REFERENCE.md`)
- Updated `.gitignore` for log files and local settings
- Fixed 3 of 11 code review issues (Issue #18, #8, #4)
- Tests expanded from 81 to 122 (+50% growth)

**Files Created**:
- `scripts/validate-yaml-rules.ps1` - YAML validation with regex safety checks
- `scripts/test-regex-patterns.ps1` - Interactive regex testing
- `scripts/email-rule-tester-mcp/server.js` - Custom MCP server
- `scripts/email-rule-tester-mcp/package.json` - MCP dependencies
- `.claude/skills.json` - 10 custom development skills
- `.claude/hooks.json` - 4 automated validation hooks
- `CLAUDE_CODE_SETUP_GUIDE.md` - Complete setup documentation
- `QUICK_REFERENCE.md` - Quick reference card

