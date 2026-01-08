# Spam Filter Mobile App

Flutter application for cross-platform email spam filtering.

## Quick Start

```powershell
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run tests
flutter test
```

## Build Commands

### Windows Desktop
```powershell
cd scripts
.\build-windows.ps1
```

### Android
```powershell
cd scripts
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator -SkipUninstall
```

**Flags**:
- `-StartEmulator`: Auto-start emulator if not running
- `-SkipUninstall`: Preserve saved accounts during debug builds
- `-EmulatorName <name>`: Specify AVD name

## Project Structure

```
mobile-app/
├── lib/
│   ├── core/           # Business logic (provider-agnostic)
│   │   ├── models/     # EmailMessage, RuleSet, SafeSenderList
│   │   ├── services/   # RuleEvaluator, PatternCompiler, EmailScanner
│   │   └── providers/  # RuleSetProvider, EmailScanProvider
│   ├── adapters/       # Platform implementations
│   │   ├── email_providers/  # Gmail, AOL, Outlook adapters
│   │   ├── storage/    # AppPaths, LocalRuleStore, SecureCredentialsStore
│   │   └── auth/       # GoogleAuthService
│   └── ui/             # Flutter screens and widgets
├── test/               # Unit and integration tests
├── scripts/            # Build automation
└── android/            # Android-specific configuration
```

## Configuration

### Secrets (Required for OAuth)

1. Copy template: `cp secrets.dev.json.template secrets.dev.json`
2. Add credentials from Google Cloud Console
3. Build scripts auto-inject secrets via `--dart-define-from-file`

See [docs/OAUTH_SETUP.md](../docs/OAUTH_SETUP.md) for detailed setup.

### Android Emulator

Must use Google APIs image (not AOSP) for Google Sign-In:
- ✅ `Google APIs ARM64 v8a`
- ❌ `Android Open Source Project ARM64 v8a`

## Testing

```powershell
# All tests (138 passing)
flutter test

# Specific test file
flutter test test/unit/rule_evaluator_test.dart

# With coverage
flutter test --coverage
```

## New Developer Setup

See [docs/DEVELOPER_SETUP.md](docs/DEVELOPER_SETUP.md) for complete Windows 11 setup guide.

## Documentation

- [../CLAUDE.md](../CLAUDE.md) - Complete project documentation
- [../docs/OAUTH_SETUP.md](../docs/OAUTH_SETUP.md) - OAuth configuration
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Common issues
