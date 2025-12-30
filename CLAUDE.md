# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS). The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail) with a single codebase and portable YAML rule sets.

**Current Status**: Phase 2.1 Complete - All automated tests passing (81/81), manual Windows and Android testing successful, ready for production validation.

**Latest Test Run**: December 30, 2025 - App successfully launched on Android emulator (emulator-5554) with Gmail OAuth configuration validated. Email input fields, Firebase integration, and UI navigation confirmed operational via logcat analysis.

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
├── Archive/
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

See `memory-bank/yaml-schemas.md` and `memory-bank/regex-conventions.md` for complete specifications.

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

**Total Tests**: 81 passing (as of Dec 2025)
- **Phase 1 Regression**: 27 tests (core models, services)
- **Phase 2.0 Tests**: 23 tests (AppPaths, SecureCredentialsStore, EmailScanProvider)
- **Phase 2.1 Tests**: 31 tests (adapters, providers, integration)

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

## Development Workflow

1. **Setup**: Follow `mobile-app/NEW_DEVELOPER_SETUP.md` for validated Windows 11 setup
2. **Secrets**: Configure `secrets.dev.json` with Gmail and/or AOL credentials
3. **Build**:
   - Windows: `.\scripts\build-windows.ps1`
   - Android: `.\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
4. **Test**: `flutter test` (verify all 81 tests passing)
5. **Analyze**: `flutter analyze` (ensure 0 issues)

## Known Limitations

- **Outlook.com OAuth**: Deferred (MSAL integration incomplete)
- **Production Delete Mode**: Not yet validated with spam-heavy inbox (read-only mode tested)
- **iOS/macOS/Linux**: Not yet validated (architecture supports, testing pending)

## Additional Resources

- **Development Standards**: `memory-bank/development-standards.md`
- **Processing Flow**: `memory-bank/processing-flow.md`
- **YAML Schemas**: `memory-bank/yaml-schemas.md`
- **Regex Conventions**: `memory-bank/regex-conventions.md`
- **Desktop Archive**: `Archive/desktop-python/` (reference only)
