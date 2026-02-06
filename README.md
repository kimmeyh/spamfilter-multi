# Spam Filter Multi-Platform

Cross-platform email spam filtering application built with 100% Flutter/Dart.

## Overview

Unified spam filter supporting multiple email providers across all platforms with a single codebase and portable YAML rule sets.

**Supported Platforms**: Windows, Android, macOS, Linux, iOS

**Supported Email Providers**: Gmail (OAuth), AOL (IMAP), Yahoo (IMAP), Outlook.com (planned)

## Quick Start

```powershell
# Navigate to app
cd mobile-app

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run
```

### Platform-Specific Builds

**Windows Desktop**:
```powershell
cd mobile-app/scripts
.\build-windows.ps1
```

**Android**:
```powershell
cd mobile-app/scripts
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator
```

## Documentation

| Document | Description |
|----------|-------------|
| [CLAUDE.md](CLAUDE.md) | Complete project documentation |
| [CHANGELOG.md](CHANGELOG.md) | Feature and bug updates |
| [docs/OAUTH_SETUP.md](docs/OAUTH_SETUP.md) | Gmail OAuth configuration |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and fixes |
| [docs/ISSUE_BACKLOG.md](docs/ISSUE_BACKLOG.md) | Open issues and status |

## Project Structure

```
spamfilter-multi/
├── mobile-app/           # Flutter application
├── docs/                 # Documentation
├── scripts/              # Build and validation scripts
├── rules.yaml            # Spam filtering rules
├── rules_safe_senders.yaml   # Safe sender whitelist
└── Archive/              # Legacy Python desktop app
```

## Current Status

**Phase 3.3 Complete** (January 2026)
- 138 tests passing
- Gmail and AOL fully functional
- Windows Desktop and Android validated

See [CHANGELOG.md](CHANGELOG.md) for recent updates.

## License

MIT License
