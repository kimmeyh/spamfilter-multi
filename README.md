# Spam Filter Multi-Platform

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS).

## Overview

This repository contains a unified cross-platform spam filter application built entirely with Flutter. The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail, etc.) across all platforms with a single codebase. Complete YAML rule format compatibility enables portable rule sets between any platform.
[Flutter Docs](https://docs.flutter.dev/get-started/quick)

## Repository Structure

```
spamfilter-multi/
├── mobile-app/           # Flutter application (all 5 platforms: Windows, macOS, Linux, Android, iOS)
├── Archive/
│   ├── desktop-python/   # Original Outlook desktop application (reference only)
│   └── ...               # Historical files and backups
├── memory-bank/          # MCP server configuration (development planning docs)
├── rules.yaml            # Active spam filtering rules (shared across all platforms)
├── rules_safe_senders.yaml   # Active safe sender whitelist (shared across all platforms)
├── README.md             # This file
└── DOCUMENTATION_INDEX.md    # Complete documentation reference
```

## Projects

### Flutter App (Active Development - All Platforms)

**Location**: [`mobile-app/`](mobile-app/)  
**Status**: Phase 2.0 Complete - Storage & State Management ✅ | Phase 2 Ready - UI Development 🔄  
**Platforms**: Flutter (Windows, macOS, Linux, Android, iOS)  
**Email Access**: IMAP/OAuth for universal provider support  
**First Target**: AOL (IMAP), then Gmail (OAuth), then Outlook.com (OAuth)

#### Quick Start

```powershell
# Install Flutter (if not already installed)
# Download from https://flutter.dev/docs/get-started/install/windows
# Or use chocolatey: choco install flutter

# Navigate to mobile app
cd mobile-app

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run tests
flutter test

# Build release APK (Android)
flutter build apk --release

# Build Windows installer (MSIX)
flutter build windows
```

See [`mobile-app/README.md`](mobile-app/README.md) for project details and
[`mobile-app/NEW_DEVELOPER_SETUP.md`](mobile-app/NEW_DEVELOPER_SETUP.md) for the validated Windows 11 setup.

### Desktop Python Application (Reference/Archive)

**Location**: [`Archive/desktop-python/`](Archive/desktop-python/)  
**Status**: Archived reference implementation  
**Platform**: Windows with Microsoft Outlook COM

The original Python application using Outlook COM is archived for reference only. New development uses the unified Flutter approach.

## Current Status (December 11, 2025)

### ✅ Architecture: 100% Flutter/Dart for All Platforms (NEW - Pivot Complete)
- **Decision Made** (December 11, 2025): Unified Flutter approach for all 5 platforms
- **Rationale**: Outlook desktop client no longer needed (web client used); AOL IMAP connection complete; single codebase simplifies development and maintenance
- **Old Approach**: Python desktop (Outlook COM) + Flutter mobile (IMAP)
- **New Approach**: 100% Flutter/Dart for Windows, macOS, Linux, Android, iOS with IMAP/OAuth

### ✅ Phase 2.0 Complete - Platform Storage & State Management (December 11, 2025)
- **AppPaths**: Platform-agnostic file system helper (190 lines) ✅
  - Auto-creates app support directory structure (rules, credentials, backups, logs)
  - Single API for all 5 platforms (iOS, Android, Windows, macOS, Linux)
  - 7 unit tests passing ✅
- **LocalRuleStore**: YAML file persistence with auto-defaults (200 lines) ✅
  - Load/save rules and safe senders with automatic timestamped backups
  - Default file creation on first run
  - Backup listing and pruning
- **SecureCredentialsStore**: Encrypted credential storage (310 lines) ✅
  - Uses flutter_secure_storage (Keychain iOS, Keystore Android, Credential Manager Windows)
  - Multi-account support with account tracking
  - OAuth token storage (access, refresh)
  - 4 unit tests passing ✅
- **RuleSetProvider**: Rule state management via Provider (210 lines) ✅
  - Async initialization with loading states (idle, loading, success, error)
  - Load/save/add/remove/update operations with automatic persistence
  - UI-ready via Provider.of<>() pattern
- **EmailScanProvider**: Real-time scan progress tracking (260 lines) ✅
  - Track scan status (idle, scanning, paused, completed, error)
  - Result categorization (deleted, moved, safe senders, errors)
  - Progress calculation (0.0-1.0) and summary generation
  - 12 unit tests passing ✅
- **MultiProvider Integration**: Updated main.dart with async initialization ✅
  - RuleSetProvider and EmailScanProvider initialized on app startup
  - Loading UI while rules initialize
  - Error UI if initialization fails

### ✅ Phase 2.0 Test Results (December 11, 2025)
- **Total Tests**: 50+ passing, 0 failing ✅
- **Phase 1 Regression**: 27 tests passing ✅
- **Phase 2.0 New Tests**: 23 tests passing ✅
  - AppPaths: 7/7 passing (fixed platform channel mocking)
  - SecureCredentialsStore: 4/4 passing
  - EmailScanProvider: 12/12 passing
- **Code Quality**: flutter analyze - 0 issues ✅

### 📋 Phase 2 Ready - UI Development & Live Testing (Next Phase)
1. Platform Selection Screen (AOL, Gmail, Outlook, Yahoo)
2. Account Setup Forms with SecureCredentialsStore integration
3. Scan Progress Screen bound to EmailScanProvider
4. Results Display Screen with summary metrics
5. Live IMAP/OAuth testing with real credentials

## Rule Format Compatibility

Both desktop and mobile applications use the same YAML rule format:
- **rules.yaml** - Spam filtering rules with regex patterns
- **rules_safe_senders.yaml** - Whitelisted senders with regex patterns

Rules are fully portable between platforms. The mobile app supports importing existing desktop rule sets.

## Key Features (Desktop Python App)

- **Multi-Folder Processing**: Process emails from configurable list of folders
- **YAML-Based Configuration**: Easy-to-maintain rule files (`rules.yaml`, `rules_safe_senders.yaml` - both use regex patterns)
- **Regex-Only Mode**: YAML files contain regex patterns (legacy wildcard mode deprecated 10/14/2025)
- **Multi-Criteria Filtering**: Header, body, subject, and sender-based filtering
- **Phishing Detection**: Suspicious URL and domain analysis
- **Safe Sender Management**: Whitelist trusted senders and domains
- **Comprehensive Logging**: Detailed audit trails of all processing activities
- **Interactive Rule Updates**: Prompts for adding rules based on unmatched emails
	- Options during -u prompts: d/e/s/sd/?
		- d: add domain regex to SpamAutoDeleteHeader (block)
		- e: add full sender email to SpamAutoDeleteHeader (block)
		- s: add literal to safe_senders (allow)
		- sd: add sender-domain regex to safe_senders (allow any subdomain)
		- ?: show brief help
	- **Smart filtering**: Emails matching newly added rules are automatically skipped during the interactive session (10/18/2025)
- **Backup System**: Automatic timestamped backups of rule changes
- **Second Pass Reprocessing**: Re-checks remaining emails after interactive updates for additional cleanup

## How to Run

### Flutter App (All Platforms)

```powershell
# Activate Python virtual environment (optional, for desktop app only)
./.venv/Scripts/Activate.ps1
```

```bash
# Activate Python virtual environment (optional, for desktop app only)
source .venv/bin/activate
```

```powershell
# Standard Flutter app run (debug)
cd mobile-app && flutter run

# Build release APK (Android)
cd mobile-app && flutter build apk --release

# Build Windows app (desktop)
cd mobile-app && flutter build windows
```

### Desktop Python Application (Reference Only)

```powershell
# Activate Python virtual environment
./.venv/Scripts/Activate.ps1

# Standard processing (no interactive updates)
python withOutlookRulesYAML.py

# Interactive mode (prompts to add rules)
python withOutlookRulesYAML.py -u
```

## Configuration

The application targets the **kimmeyharold@aol.com** account and processes emails from the following folders:
- "Bulk Mail"
- "bulk"

Configuration can be modified in the script constants:
- `EMAIL_BULK_FOLDER_NAMES = ["Bulk Mail", "bulk"]`
- `EMAIL_ADDRESS = "kimmeyharold@aol.com"`

## File Structure

- **withOutlookRulesYAML.py** - Main application script
- **rules.yaml** - Spam filtering rules (regex patterns)
- **rules_safe_senders.yaml** - Trusted sender whitelist (regex patterns)
- **requirements.txt** - Python dependencies
- **pytest/** - All test files and test configuration
- **Archive/** - Historical backups and development files
- **memory-bank/** - Configuration for GitHub Copilot memory enhancement

Historical files (deprecated):
- **rulesregex.yaml** - DEPRECATED 10/18/2025: Consolidated to rules.yaml
- **rules_safe_sendersregex.yaml** - DEPRECATED 10/18/2025: Consolidated to rules_safe_senders.yaml

## CLI Flags

- `-u`, `--update_rules`: enable interactive prompts to add header regexes or safe senders during processing
- ~~`--use-regex-files`~~: **DEPRECATED and removed from CLI (11/10/2025)** - Regex mode is always on. If provided, it is ignored with a warning.
- ~~`--convert-rules-to-regex`~~: **DEPRECATED and removed from CLI (11/10/2025)** - Conversion utilities were retired. If provided, it is ignored with a warning.
- ~~`--convert-safe-senders-to-regex`~~: **DEPRECATED and removed from CLI (11/10/2025)** - Conversion utilities were retired. If provided, it is ignored with a warning.
- ~~`--use-legacy-files`~~: **DEPRECATED 10/14/2025** - legacy YAML files are no longer supported

## Testing

All tests are located in the `pytest/` directory. Run tests using:

```bash
# Run all tests
python -m pytest pytest/ -v

# Run specific test file
python -m pytest pytest/test_file_content.py -v
```

Test files include:
- `test_withOutlook_rulesYAML_compare_inport_to_export.py` - YAML import/export validation
- `test_withOutlook_rulesYAML_compare_safe_senders_mport_to_export.py` - Safe senders validation
- `test_file_content.py` - File content validation
- `test_folder_list_changes.py` - Multi-folder configuration tests
- `test_import_compatibility.py` - Import compatibility validation
- `test_second_pass_implementation.py` - Second-pass processing tests

## Logging and Output Functions

The application provides flexible output functions for different logging needs:

### print_to()
Unified output function that can write to multiple destinations simultaneously:
```python
print_to(message, to_log=False, to_simple=False, to_console=False, log_instance=None)
```

**Parameters:**
- `message` (str): Message to output
- `to_log` (bool): Write to debug/info log via OutlookSecurityAgent.log_print()
- `to_simple` (bool): Write to simple log file (OUTLOOK_SIMPLE_LOG)
- `to_console` (bool): Write to console (stdout)
- `log_instance`: Instance of OutlookSecurityAgent (required if to_log=True)

**Usage Examples:**
```python
# Write to all three destinations (common for important summaries)
print_to("Processing complete", to_log=True, to_simple=True, to_console=True, log_instance=agent)

# Console only (for user prompts)
print_to("Enter choice: ", to_console=True)

# Detailed logging only
print_to("Debug info", to_log=True, log_instance=agent)
```

### simple_print()
Backward compatibility wrapper maintained for existing code:
```python
simple_print(message)  # Writes to simple log or console based on OUTLOOK_SIMPLE_LOG
```

### OutlookSecurityAgent.log_print()
Instance method for detailed logging with automatic sanitization:
```python
agent.log_print(message, level="INFO")  # Writes to OUTLOOK_SECURITY_LOG
```

## Dependencies

- win32com.client (Outlook COM interface)
- yaml (YAML file processing)
- logging (Application logging)
- Standard Python libraries (re, datetime, os, etc.)

## Backups and Exporter Invariants

- All list fields (rules conditions/exceptions and safe_senders) are normalized on export:
	- lowercased, trimmed, de-duplicated, and sorted
	- All YAML files written with single quotes to reduce escape noise
- Before overwriting active YAML files, a timestamped backup is created in `archive/`

## Schemas and Conventions

For details, see memory-bank docs:
- `memory-bank/processing-flow.md` — high-level processing, interactive updates, second pass
- `memory-bank/yaml-schemas.md` — effective YAML schemas for rules and safe senders
- `memory-bank/regex-conventions.md` — quoting, glob-to-regex, and domain anchor patterns
	- Includes sender-domain safe-senders regex: `^[^@\s]+@(?:[a-z0-9-]+\.)*<domain>$`
- `memory-bank/quality-invariants.md` — exporter and processing invariants
- `memory-bank/cli-usage.md` — CLI usage reference

## Future Enhancements

- Reprocess emails in multiple folders for additional cleanup passes
- Move backup files to dedicated backup directory
- Regex pattern support for all rule types
- Cross-platform email client support
- Machine learning-based spam detection
