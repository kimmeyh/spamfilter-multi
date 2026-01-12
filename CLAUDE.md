# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Philosophy: Co-Lead Developer Collaboration

**CRITICAL**: Treat the user as a co-lead developer, not a client. This means:

1. **Think Out Loud**: Share your investigation process, reasoning, and hypotheses before taking action
   - Explain what you're checking and why before running commands
   - Narrate your detective work when debugging ("I'm checking X because Y might be causing Z")
   - Share findings immediately rather than silently making fixes

2. **Collaborative Problem-Solving**: Debugging is a team effort
   - When you have multiple approaches, present options and discuss trade-offs
   - Ask for input when facing architectural decisions
   - Acknowledge when the user's insight completes your investigation (e.g., suspecting .gitignore issues)

3. **Full Transparency**: Provide complete information about what you're doing
   - Don't shortcut analysis - show the full picture
   - Explain both what you found AND what you did not find
   - Share context about why something matters

4. **Mutual Respect**: Together you are better than either individually
   - The user brings domain knowledge, project history, and strategic vision
   - You bring pattern recognition, systematic analysis, and code generation
   - Best results come from combining both perspectives

5. **Communication Style**:
   - Explain your thought process before and during actions
   - Use "Let me check..." or "I'm investigating..." instead of silent tool usage
   - Share intermediate findings, not just final conclusions

**Example of Good Co-Lead Collaboration**:
```
❌ BAD: [Silently runs git status, finds files missing, edits .gitignore, reports "Fixed!"]

✅ GOOD: "I'm checking git status to see which files are tracked... Interesting - the
mobile-app/lib/ files are not showing up. You opened .gitignore - good thinking! Let me
search for 'lib/' in there... Found it! Line 81 has a broad 'lib/' exclusion that's
catching both Python lib directories AND our Flutter source code. This is a mixed-repo
issue. Should I make it more specific to only exclude 'Archive/desktop-python/lib/'?"
```

## Coding Style Guidelines

### Documentation and Comments
- **No contractions**: Use "do not" instead of "don't", "does not" instead of "doesn't", "cannot" instead of "can't", etc.
- **Clarity over brevity**: Write clear, complete sentences in documentation
- **Use Logger, not print()**: Production code (`lib/`) must use `Logger` for all logging. Test files (`test/`) may use `print()`.  Exception: unit and integration tests (ex. *_test.dart files)

### Example
```dart
// ❌ BAD: Don't use this pattern, it won't work correctly
// ✅ GOOD: Do not use this pattern, it will not work correctly

// ❌ BAD: Can't be null here
// ✅ GOOD: Cannot be null here
```

## Project Overview

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS). The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail) with a single codebase and portable YAML rule sets.

**Current Status**: Phase 3.3 Complete - All automated tests passing (122/122), folder selection fixed, dynamic folder discovery implemented, progressive UI updates with throttling, Gmail header parsing fixed, Claude Code MCP tools added.

**Latest Updates**: January 6, 2026 - Phase 3.2 & 3.3 Complete:

**Phase 3.3 - Enhancement Features (Jan 5-6, 2026)**:
- ✅ **Issue #36**: Progressive UI updates with throttling (every 10 emails OR 3 seconds)
- ✅ **Issue #37**: Dynamic folder discovery - fetches real folders from email providers
- ✅ **Gmail Token Refresh**: Folder discovery now uses `getValidAccessToken()` for automatic token refresh
- ✅ **Gmail Header Fix**: Extract email from "Name <email>" format for rule matching
- ✅ **Counter Bug Fix**: Reset `_noRuleCount` in `startScan()` to prevent accumulation across scans
- ✅ **Claude Code MCP Tools**: Custom MCP server for YAML validation, regex testing, rule simulation
- ✅ **Build Script Enhancements**: `-StartEmulator`, `-EmulatorName`, `-SkipUninstall` flags

**Phase 3.2 - Bug Fixes (Jan 4-5, 2026)**:
- ✅ **Issue #35**: Folder selection now correctly scans selected folders (not just INBOX)
- ✅ **Navigation Fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress

**Phase 3.1 - UI/UX Enhancements (Jan 4, 2026)**:
- ✅ **Issue #32**: Full Scan mode added (4th scan mode) with persistent mode selector and warning dialogs
- ✅ **Issue #33**: Scan Progress UI redesigned - removed redundant elements, added Found/Processed bubbles, auto-navigation to Results
- ✅ **Issue #34**: Results Screen UI redesigned - shows email address in title, mode in summary, matching bubble design
- ✅ **Bubble Counts Fix**: All scan modes now show proposed actions (what WOULD happen)
- ✅ **No Rule Tracking**: Added "No rule" bubble (grey) to track emails with no rule match

## Repository Structure

```
spamfilter-multi/
├── mobile-app/           # Flutter application (all 5 platforms)
│   ├── lib/
│   │   ├── core/        # Business logic (provider-agnostic)
│   │   ├── adapters/    # Provider implementations (email, storage, auth)
│   │   └── ui/          # Flutter screens and widgets
│   ├── test/            # Unit, integration, and smoke tests
│   ├── scripts/         # Build automation scripts
│   └── android/         # Android-specific configuration
├── archive/
│   └── desktop-python/  # Original Outlook desktop app (reference only)
├── memory-bank/         # Development planning and documentation
├── rules.yaml           # Active spam filtering rules (regex, shared)
└── rules_safe_senders.yaml  # Active safe sender whitelist (regex, shared)
```

## Common Commands

**IMPORTANT - Development Environment**: This project uses **PowerShell** as the primary shell environment on Windows. All commands, scripts, and automation should use PowerShell syntax and cmdlets. Bash/sh commands should be avoided unless absolutely necessary.

**CRITICAL - Execution Context**: When running PowerShell commands programmatically (e.g., via automation tools), execute them directly in PowerShell context, NOT wrapped in Bash. Wrapping PowerShell in Bash (`bash -c "powershell ..."`) loses VSCode terminal environment variables and Flutter toolchain context, causing failures. Always use native PowerShell execution.

### Development

```powershell
# Navigate to Flutter app
cd mobile-app

# Install dependencies
flutter pub get

# Run app on connected device/emulator
flutter run

# Run all tests
flutter test

# Analyze code quality
flutter analyze
```

### Windows Development

**CRITICAL**: Always use `build-windows.ps1` for Windows builds and tests (not `flutter build windows` directly):

```powershell
cd mobile-app/scripts
.\build-windows.ps1               # Clean build, inject secrets, run app
.\build-windows.ps1 -RunAfterBuild:$false  # Build without running
```

### Android Development

```powershell
cd mobile-app/scripts

# Build release APK
.\build-apk.ps1

# Build with secrets and install to emulator
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator"

# Launch emulator and run
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -Run"
```

### Testing

```powershell
cd mobile-app

# Run all tests (81 tests)
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator"

# Run specific test file
flutter test test/unit/rule_evaluator_test.dart

# Run with coverage
flutter test --coverage
```

## Architecture

### Core Design Principles

1. **Provider-Agnostic Core**: All email filtering logic is independent of email provider implementation
2. **Adapter Pattern**: Email providers (Gmail, AOL, Outlook) implement a common `EmailProvider` interface
3. **State Management**: Uses Provider pattern for rule sets (`RuleSetProvider`) and scan progress (`EmailScanProvider`)
4. **Platform-Agnostic Storage**: `AppPaths` provides unified file system access across all 5 platforms

### Key Components

#### Core Models (`lib/core/models/`)
- **EmailMessage**: Normalized email representation (id, from, subject, body, headers)
- **RuleSet**: Collection of spam filtering rules with conditions and actions
- **SafeSenderList**: Whitelist of trusted senders (regex patterns)
- **EvaluationResult**: Result of rule evaluation (delete/move/safe sender)

#### Core Services (`lib/core/services/`)
- **RuleEvaluator**: Evaluates emails against rules; checks safe senders first, then rules in execution order
- **PatternCompiler**: Compiles regex patterns for matching
- **YamlService**: Loads/parses YAML rule files
- **EmailScanner**: Orchestrates email fetching and filtering

#### Adapters (`lib/adapters/`)
- **EmailProvider**: Abstract interface for email providers
  - `GenericImapAdapter`: IMAP implementation for AOL, Yahoo, ProtonMail
  - `GmailApiAdapter`: Gmail REST API with OAuth
  - `OutlookAdapter`: Outlook.com REST API with MSAL (deferred)
- **Storage**:
  - `AppPaths`: Platform-agnostic file system helper (rules, credentials, backups, logs)
  - `LocalRuleStore`: YAML file persistence with auto-defaults and timestamped backups
  - `SecureCredentialsStore`: Encrypted credential storage (Keychain iOS, Keystore Android, Credential Manager Windows)
- **Auth**:
  - `GoogleAuthService`: Gmail OAuth flow (native Android SDK, WebView/browser for Windows)
  - `SecureTokenStore`: OAuth token persistence

#### State Management (`lib/core/providers/`)
- **RuleSetProvider**: Manages rule sets with async initialization and automatic persistence
- **EmailScanProvider**: Tracks real-time scan progress (idle, scanning, paused, completed, error)

### Data Flow

1. **Initialization**: `main.dart` initializes `MultiProvider` with `RuleSetProvider` and `EmailScanProvider`
2. **Rule Loading**: `RuleSetProvider` loads rules from YAML files via `LocalRuleStore` and `YamlService`
3. **Account Selection**: `AccountSelectionScreen` lists saved accounts or navigates to platform selection
4. **Scanning**: `EmailScanner` fetches emails via `EmailProvider`, evaluates with `RuleEvaluator`, tracks progress in `EmailScanProvider`
5. **Results**: `ResultsDisplayScreen` shows categorized results (deleted, moved, safe senders, errors)

## YAML Rule Format

All rules use **regex patterns only** (legacy wildcard mode removed 11/10/2025):

### rules.yaml Structure
```yaml
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "SpamAutoDeleteHeader"
    enabled: "True"
    conditions:
      type: "OR"
      header: ["^from:.*@(?:[a-z0-9-]+\\.)*example\\.com$"]
      subject: ["^urgent.*"]
    actions:
      delete: true
    exceptions:
      from: ["^trusted@example\\.com$"]
```

### rules_safe_senders.yaml Structure
```yaml
safe_senders:
  - "^user@example\\.com$"                          # Exact email match
  - "^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com$"   # Domain + all subdomains
```

### YAML Export Invariants
All YAML exports enforce:
1. Lowercase conversion
2. Trimmed whitespace
3. De-duplication
4. Alphabetical sorting
5. Single quotes (avoid backslash escaping)
6. Timestamped backups to `Archive/` before overwrite

### Regex Pattern Conventions

**Pattern Formatting**:
- All patterns are **lowercase** (case-insensitive matching via `caseSensitive: false`)
- All patterns are **trimmed** (no leading/trailing whitespace)
- Dart RegExp does not support Python-style inline flags (`(?i)`, `(?m)`, `(?s)`, `(?x)`) - these are automatically stripped by PatternCompiler
- YAML uses **single quotes** to avoid backslash escaping issues

**Domain Blocking Patterns** (for SpamAutoDeleteHeader.header):
```regex
@(?:[a-z0-9-]+\.)*example\.com$           # Block domain and all subdomains
@(?:[a-z0-9-]+\.)*example\.[a-z0-9.-]+$   # Block domain with generic TLD match
mailer-daemon@aol\.com                     # Block specific email address
```

**Safe Sender Patterns** (for rules_safe_senders.yaml):
```regex
^john\.doe@company\.com$                           # Exact email match (anchored)
^[^@\s]+@(?:[a-z0-9-]+\.)*lifeway\.com$           # Allow domain and all subdomains
```

**Pattern Building Reference**:
| Purpose | Pattern Format | Example |
|---------|---------------|---------|
| Block domain | `@(?:[a-z0-9-]+\.)*domain\.com$` | `@(?:[a-z0-9-]+\.)*spam\.com$` |
| Block email | Literal email address | `spammer@example\.com` |
| Allow exact email | `^email@domain\.com$` | `^trusted@company\.com$` |
| Allow domain | `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$` | `^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$` |

**Regex Compilation**:
- Patterns compiled with `caseSensitive: false` (equivalent to Python `re.IGNORECASE`)
- Invalid patterns are logged and tracked (not silently ignored)
- Compiled patterns are cached for performance

## OAuth and Secrets Management

### CRITICAL: Never Commit Secrets

**Files excluded by .gitignore** (NEVER commit):
- `mobile-app/secrets.dev.json` - Build-time secrets (Gmail client ID/secret, AOL credentials)
- `mobile-app/android/app/google-services.json` - Firebase configuration for Android
- `client_secret_*.json` - OAuth client secret files from Google Cloud Console

### Secrets Configuration

1. **Copy template**: `cp mobile-app/secrets.dev.json.template mobile-app/secrets.dev.json`
2. **Fill credentials**:
   - **Gmail**: OAuth credentials from Google Cloud Console
   - **AOL**: Email and app password from AOL account settings
3. **Build with secrets**: Use `scripts/build-with-secrets.ps1` (auto-injects `--dart-define-from-file`)

### Gmail OAuth Setup

#### Android
- Requires Firebase project with Android app registered
- Must add SHA-1 fingerprint to Firebase Console
- Run `mobile-app/android/get_sha1.bat` to extract fingerprint
- Download `google-services.json` from Firebase Console → `mobile-app/android/app/google-services.json`
- See `ANDROID_GMAIL_SIGNIN_QUICK_START.md` for complete setup

#### Windows Desktop
- Uses Desktop OAuth client ID from Google Cloud Console
- Requires client secret (must be in `secrets.dev.json`)
- Loopback redirect URI: `http://localhost:8080/oauth/callback`
- See `WINDOWS_GMAIL_OAUTH_SETUP.md` for complete setup

## Platform-Specific Considerations

### Android
- Emulator must use "Google APIs" image (NOT AOSP) for Google Sign-In
- Norton Antivirus "Email Protection" may intercept IMAP TLS connections (disable if needed)
- Multi-account support via unique accountId: `{platform}-{email}`

### Windows
- Always use `build-windows.ps1` script (not `flutter build windows` directly)
- Desktop OAuth requires browser-based flow with loopback redirect
- Secrets injected at build time via `--dart-define-from-file=secrets.dev.json`

### iOS/macOS/Linux
- Not yet validated but architecture supports all platforms
- Storage uses `AppPaths` for platform-specific directories

## Testing Strategy

**Total Tests**: 122 passing (as of Jan 2026)
- **Phase 1 Regression**: 27 tests (core models, services)
- **Phase 2.0 Tests**: 23 tests (AppPaths, SecureCredentialsStore, EmailScanProvider)
- **Phase 2.1 Tests**: 31 tests (adapters, providers, integration)
- **Phase 2.2 Tests**: 41 tests (RuleEvaluator, PatternCompiler with error tracking)

### Test Organization
```
mobile-app/test/
├── unit/          # Unit tests for models and services
├── integration/   # Integration tests for adapters and workflows
├── adapters/      # Adapter-specific tests
├── core/          # Core logic tests
├── fixtures/      # Test data and mock responses
└── smoke_test.dart  # Smoke test for app initialization
```

### Running Tests
```powershell
flutter test                                    # All tests
flutter test test/unit/rule_evaluator_test.dart # Specific file
flutter test --coverage                         # With coverage
```

## Common Issues and Fixes

### Android Gmail Sign-In: "Sign in was cancelled"
**Root Cause**: SHA-1 fingerprint not registered in Firebase Console
**Fix**: Extract SHA-1 (`mobile-app/android/get_sha1.bat`), add to Firebase Console, download fresh `google-services.json`, rebuild
**Guide**: `ANDROID_GMAIL_SIGNIN_QUICK_START.md`

### Norton Antivirus Blocks IMAP
**Symptom**: "TLS certificate validation failed" when adding AOL/Yahoo accounts
**Root Cause**: Norton's "Email Protection" intercepts TLS connections
**Fix**: Disable Norton Email Protection in Settings → Security → Advanced → Intrusion Prevention
**Verify**: Run `python -c "import socket, ssl; ..."` (see README.md § Troubleshooting)

### Windows Gmail OAuth: "client_secret is missing"
**Root Cause**: `secrets.dev.json` missing or incomplete
**Fix**: Ensure `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` is in `secrets.dev.json`, rebuild with `build-windows.ps1`
**Guide**: `WINDOWS_GMAIL_OAUTH_SETUP.md`

### Flutter Source Files Not Tracked by Git
**Symptom**: Dart files in `mobile-app/lib/` don't show as modified in git status or VSCode Source Control
**Root Cause**: Root `.gitignore` had overly broad `lib/` exclusion (intended for Python lib directories) that also excluded Flutter's `mobile-app/lib/` source code directory
**Fix Applied (Dec 30, 2025)**: Changed line 81-82 in root `.gitignore` from `lib/` to `Archive/desktop-python/lib/` to only exclude Python package directories
**Impact**: All Flutter/Dart source code in `mobile-app/lib/` is now properly tracked by git
**Note**: This was a mixed-repository issue where Python gitignore rules conflicted with Flutter project structure

### Results Screen Navigation Not Returning to Account Selection
**Symptom**: "Back to Accounts" button on Results Display screen returned to Scan Progress screen instead of Account Selection screen
**Root Cause**: Navigation stack was Account Selection → Scan Progress → Results Display. Using `Navigator.pop()` only popped one level back to Scan Progress
**Fix Applied (Jan 1, 2026)**: Changed navigation to use `Navigator.popUntil(context, (route) => route.isFirst)` to pop all screens until reaching Account Selection screen
**Files Modified**: `mobile-app/lib/ui/screens/results_display_screen.dart`
**Impact**: "Back to Accounts" button now correctly navigates directly to Account Selection screen

### Scan Progress Status Updates Delayed
**Symptom**: After clicking "Start Live Scan" and confirming scan options, screen continued to show "Ready to scan" and "No results yet" until results actually started appearing
**Root Cause**: Status only changed when `EmailScanner.scanInbox()` called `scanProvider.startScan()`, which happened after fetching emails from server
**Fix Applied (Jan 1, 2026)**: Added immediate call to `scanProvider.startScan(totalEmails: 0)` right after dialog closes, before scanner runs
**Files Modified**: `mobile-app/lib/ui/screens/scan_progress_screen.dart`
**Impact**: UI immediately updates to show "Scanning in progress" and replaces "No results yet" with progress indicator

### Account Loading Flicker on Account Selection Screen
**Symptom**: When returning to Account Selection screen, account cards briefly flicker showing loading state (spinner) before displaying full account details
**Root Cause**: FutureBuilder creates a new Future on every widget rebuild, causing it to show `ConnectionState.waiting` state even for already-loaded accounts
**Fix Applied (Jan 1, 2026)**: Implemented caching system in `AccountSelectionScreen`:
  - Added `Map<String, AccountDisplayData?> _accountDataCache` to store loaded account data
  - Modified `_loadAccountDisplayData()` to return cached data immediately if available
  - Background refresh via `_refreshAccountDataInBackground()` updates cache only when data changes
  - Removed loading spinner state from FutureBuilder (always shows data immediately)
  - Cache cleared when accounts are deleted
**Files Modified**: `mobile-app/lib/ui/screens/account_selection_screen.dart`
**Impact**: Accounts appear instantly when returning to screen, no visual flicker, still refreshes data in background to catch credential changes
**Applies to**: All account types (Gmail OAuth, AOL IMAP, Yahoo IMAP)

### Account Selection Navigation and Refresh Issues
**Symptom**: After completing a scan and clicking "Back to Accounts" from Results Display screen, navigation went to Platform Selection instead of Account Selection, and account list did not refresh to show newly added accounts
**Root Cause**: Delete handler used `Navigator.pushReplacement` to replace Account Selection with Platform Selection when last account was deleted (breaking navigation stack), and Account Selection screen only refreshed accounts on 2-second timer (not on navigation events)
**Fix Applied (Jan 2, 2026)**:
  - Removed pushReplacement navigation from delete handler - Account Selection now stays in navigation stack and shows built-in "Add Account" UI when empty
  - Added RouteObserver and RouteAware mixin to detect navigation events and refresh account list immediately when screen becomes visible
  - Added global RouteObserver in main.dart
  - Account Selection implements RouteAware mixin with didPopNext() callback
**Files Modified**: `mobile-app/lib/main.dart`, `mobile-app/lib/ui/screens/account_selection_screen.dart`
**Impact**: "Back to Accounts" correctly navigates to Account Selection (not Platform Selection), account list refreshes immediately when navigating back (no delay or empty state), navigation stack preserved correctly for all account deletion scenarios
**Applies to**: All account types (Gmail OAuth, AOL IMAP, Yahoo IMAP)

### Phase 3.2 Folder Selection Fixes (Issue #35)
**Status**: ✅ COMPLETE (Jan 5, 2026)
**Focus**: Fix folder selection to actually scan selected folders

**Issue #35 - Folder Selection Not Scanning Selected Folders**:
- **Problem**: Selecting non-Inbox folders (e.g., "Bulk Mail") still only scanned Inbox
- **Root Cause**: Missing state management - `scanProvider.selectedFolders` was not being set
- **Solution**: Added `_selectedFolders` field to EmailScanProvider, connected UI callback to `setSelectedFolders()`, pass to scanner
- **Files Modified**: `email_scan_provider.dart`, `scan_progress_screen.dart`

**Navigation Fix - Auto-Navigation Race Condition**:
- **Problem**: Returning to Scan Progress from Account Selection caused unwanted auto-navigation to Results
- **Root Cause**: `_previousStatus` was null on first build but scan status was completed
- **Solution**: Initialize `_previousStatus` in `initState()` before first build
- **Files Modified**: `scan_progress_screen.dart`

### Phase 3.3 Enhancement Features (Issues #36, #37)
**Status**: ✅ COMPLETE (Jan 5-6, 2026)
**Focus**: Progressive updates, dynamic folder discovery, Gmail fixes, Claude Code tools

**Issue #36 - Progressive UI Updates**:
- **Problem**: UI updated for every email, causing performance issues with large scans
- **Solution**: Throttle updates to every 10 emails OR 3 seconds (whichever comes first)
- **Implementation**: Added `_lastProgressNotification`, `_emailsSinceLastNotification` fields
- **Files Modified**: `email_scan_provider.dart`

**Issue #37 - Dynamic Folder Discovery**:
- **Problem**: Folder selection limited to hardcoded lists
- **Solution**: Call `provider.listFolders()` dynamically, added search/filter UI, loading states
- **Features**: Gmail label discovery via API, IMAP folder listing, "Recommended" badges
- **Files Modified**: `folder_selection_screen.dart`

**Gmail Token Refresh Fix**:
- **Problem**: 401 errors when selecting folders with expired OAuth tokens
- **Solution**: Use `GoogleAuthService.getValidAccessToken()` instead of stored tokens directly
- **Impact**: Seamless token refresh, no manual re-authentication needed

**Gmail Header Format Fix**:
- **Problem**: Gmail emails not matching rules due to "Name <email>" format vs just "email"
- **Solution**: Added `_extractEmail()` helper to parse email from header format
- **Files Modified**: `gmail_api_adapter.dart`

**Counter Accumulation Bug Fix**:
- **Problem**: "No Rules" count accumulated across scans (showed impossible values)
- **Solution**: Reset `_noRuleCount = 0` in `startScan()` method
- **Files Modified**: `email_scan_provider.dart`

**Claude Code MCP Tools**:
- Custom MCP server for email rule testing (`scripts/email-rule-tester-mcp/`)
- YAML validation script (`scripts/validate-yaml-rules.ps1`)
- Regex pattern tester (`scripts/test-regex-patterns.ps1`)
- 10 custom skills in `.claude/skills.json`
- 4 automated hooks in `.claude/hooks.json`

**Build Script Enhancements**:
- `-StartEmulator`: Auto-start Android emulator if none running
- `-EmulatorName`: Specify which AVD to launch
- `-SkipUninstall`: Preserve saved accounts during debug builds

### Phase 3.1 UI/UX Enhancements (Issues #32-#34)
**Status**: ✅ COMPLETE (Jan 4, 2026)
**Focus**: Full Scan mode, UI redesign, consistent bubble displays, improved navigation

**Issue #32 - Full Scan Mode and Persistent Selection**:
- Added `ScanMode.fullScan` (4th mode) - permanent delete/move operations
- Added persistent "Scan Mode" button on Scan Progress screen
- Removed scan mode pop-up from account setup flow (default to readonly)
- Added warning dialog for Full Scan mode (requires user confirmation)
- Updated `recordResult()` to distinguish revertible vs permanent actions
- Files Modified: `email_scan_provider.dart`, `account_setup_screen.dart`, `scan_progress_screen.dart`

**Issue #33 - Scan Progress Screen UI Redesign**:
- Removed redundant progress bar and processed count text
- Updated to 7-bubble row: Found (Blue), Processed (Purple), Deleted (Red), Moved (Orange), Safe (Green), No rule (Grey), Errors (Dark Red)
- Added auto-navigation to Results screen when scan completes
- Re-enabled buttons after scan completes (idle or completed status)
- Added scan mode to header: "Ready to scan - <mode>" / "Scan complete - <mode>"
- Files Modified: `scan_progress_screen.dart`

**Issue #34 - Results Screen UI Redesign**:
- Added `accountEmail` parameter (required) to show email in title
- Updated title format: "Results - <email> - <provider>"
- Updated summary format: "Summary - <mode>"
- Updated bubble row to match Scan Progress (7 bubbles with exact same colors)
- Made accountEmail required in ScanProgressScreen
- Files Modified: `results_display_screen.dart`, `scan_progress_screen.dart`

**Bubble Counts Fix**:
- **Problem**: In Read-Only mode, bubbles showed "Deleted: 0" even when rules evaluated emails for deletion
- **Solution**: Changed `recordResult()` to always increment counts based on rule evaluation (proposed actions), not just executed actions
- **Impact**: All scan modes now show what WOULD happen, making Read-Only mode useful for previewing results
- Files Modified: `email_scan_provider.dart`, `email_scan_provider_test.dart` (5 tests updated)

**No Rule Tracking**:
- Added `_noRuleCount` field and getter to EmailScanProvider
- Added "No rule" bubble (grey #757575) between "Safe" and "Errors"
- Tracks emails that did not match any rules (for future rule creation)
- Increments when `action == EmailActionType.none`
- Files Modified: `email_scan_provider.dart`, `scan_progress_screen.dart`, `results_display_screen.dart`

**Test Results**: 122/122 tests passing (13 skipped integration tests requiring credentials)

**Commits**:
- `af6a36d` - feat: Add 'No rule' bubble to track emails with no rule match
- `2f4f1ce` - fix: Bubble counts now show proposed actions in all scan modes
- `964ef9d` - fix: Redesign Results Screen UI (Issue #34)
- `e542823` - feat: Redesign Scan Progress UI (Issue #33)
- `72d876b`, `7816546`, `bf2ab3c`, `2d15ebf` - feat: Full Scan mode (Issue #32)

## Development Workflow

1. **Setup**: Follow `mobile-app/NEW_DEVELOPER_SETUP.md` for validated Windows 11 setup
2. **Secrets**: Configure `secrets.dev.json` with Gmail and/or AOL credentials
3. **Build**:
   - Windows: `.\scripts\build-windows.ps1`
   - Android: `.\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
4. **Test**: `flutter test` (verify all 185 tests passing)
5. **Analyze**: `flutter analyze` (ensure 0 issues)

## Changelog Policy

**CHANGELOG.md** should be updated with each commit that introduces user-facing changes:

1. **When to Update**: Update CHANGELOG.md in the same commit as the code changes (not after PR merge)
2. **Format**: `- **type**: Description (Issue #N)` where type is:
   - `feat`: New feature or enhancement
   - `fix`: Bug fix
   - `chore`: Maintenance, refactoring, dependencies
   - `docs`: Documentation only changes
   - `test`: Adding or updating tests
3. **Location**: Add entries under `## [Unreleased]` section, grouped by date (newest first)
4. **Issue References**: Always include GitHub issue number when applicable
5. **Commit Together**: Stage CHANGELOG.md with the related code changes in a single commit

**Example Entry**:
```markdown
### 2026-01-12
- **feat**: Update Results screen to show folder • subject • rule format (Issue #47)
- **feat**: Add AOL Bulk/Bulk Email folder recognition as junk folders (Issue #48)
```

## Known Limitations

- **Outlook.com OAuth**: Deferred (MSAL integration incomplete)
- **Production Delete Mode**: Not yet validated with spam-heavy inbox (read-only mode tested)
- **iOS/macOS/Linux**: Not yet validated (architecture supports, testing pending)

## Code Review Findings & Issue Backlog (January 2026)

A comprehensive code review of the Flutter spam filter codebase identified **11 high-confidence issues** with specific file:line references. All issues have been documented in the GitHub repository.

### Completed Issues (3)
- **Issue #18 ✅ COMPLETE (Jan 3, 2026)**: Created comprehensive RuleEvaluator test suite - 32 tests with 97.96% coverage, includes anti-spoofing verification (`rule_evaluator_test.dart`)
- **Issue #8 ✅ FIXED (Jan 3, 2026)**: Header matching bug in RuleEvaluator - Rules now properly check email headers instead of From field (`rule_evaluator.dart:53-141`)
- **Issue #4 ✅ FIXED (Jan 3, 2026)**: Silent regex compilation failures - Invalid patterns now logged and tracked for UI visibility (`pattern_compiler.dart:1-66`)

### Critical Issues Remaining (2)
- **Issue #9**: Scan mode bypass in EmailScanner - readonly mode still deletes emails (`email_scanner.dart:66-125`)
- **Issue #10**: Credential type confusion in SecureCredentialsStore (`secure_credentials_store.dart:137-161`)

### High Priority Issues (4)
- **Issue #11**: Silent regex compilation failures in PatternCompiler (DUPLICATE - see Issue #4 ✅ FIXED)
- **Issue #12**: Missing refresh token storage on Android (`google_auth_service.dart:422-428`)
- **Issue #13**: Overly broad exception mapping in GenericIMAPAdapter (`generic_imap_adapter.dart:146-165`)
- **Issue #14**: Duplicate scan mode enforcement logic (`email_scan_provider.dart:315-358`)
- **Issue #15**: Inconsistent logging - mix of print() and Logger (9 occurrences in main.dart, adapters)

### Medium/Low Priority Issues (2)
- **Issue #16**: PatternCompiler cache grows unbounded (medium priority)
- **Issue #17**: EmailMessage.getHeader() returns empty string instead of null (low priority)

**Complete Details**: See `GITHUB_ISSUES_BACKLOG.md` for full problem descriptions, root causes, proposed solutions, and acceptance criteria for all 11 issues.

**Progress Summary**: 3 of 11 issues fixed (27% complete). Test suite expanded from 81 to 122 tests (+50% growth).

## Additional Resources

### Documentation Structure
```
spamfilter-multi/
├── 0*.md                     # Developer workflow files (DO NOT read or modify)
├── CHANGELOG.md              # Feature/bug updates (newest first)
├── CLAUDE.md                 # Primary documentation (this file)
├── README.md                 # Project overview
├── docs/                     # Consolidated documentation
│   ├── OAUTH_SETUP.md        # Gmail OAuth for Android + Windows
│   ├── TROUBLESHOOTING.md    # Common issues and fixes
│   └── ISSUE_BACKLOG.md      # Open issues and status
├── mobile-app/
│   ├── README.md             # App-specific quick start
│   └── docs/
│       └── DEVELOPER_SETUP.md  # New developer onboarding (Windows 11)
└── scripts/
    └── email-rule-tester-mcp/  # Custom MCP server
```

### Quick Reference
- **QUICK_REFERENCE.md**: Command cheat sheet
- **CLAUDE_CODE_SETUP_GUIDE.md**: MCP server, skills, hooks setup

### Claude Code Tooling
- **Custom MCP Server**: `scripts/email-rule-tester-mcp/`
- **Validation Scripts**: `scripts/validate-yaml-rules.ps1`, `scripts/test-regex-patterns.ps1`
- **Skills Config**: `.claude/skills.json` (10 custom skills)
- **Hooks Config**: `.claude/hooks.json` (pre-commit validation, post-checkout pub get)

### Archives (gitignored)
- **Archive/**: Historical docs, legacy Python desktop app, completed phase reports
