# Spam Filter Multi-Platform

Cross-platform email spam filtering application supporting desktop (Outlook) and mobile (Android/iOS).

## Overview

This repository contains both the original Python-based Outlook spam filter and a new cross-platform mobile application built with Flutter. The mobile app maintains full compatibility with the desktop application's YAML rule format while supporting multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail, etc.).
[Flutter Docs](https://docs.flutter.dev/get-started/quick)

## Repository Structure

```
spamfilter-multi/
├── mobile-app/           # Flutter mobile application (Phase 1 MVP - Active Development)
├── Archive/
│   ├── desktop-python/   # Original Outlook desktop application (if moved)
│   └── ...              # Historical files and backups
├── memory-bank/         # MCP server configuration (development planning docs)
├── rules.yaml           # Active spam filtering rules (shared with desktop)
├── rules_safe_senders.yaml  # Active safe sender whitelist (shared with desktop)
├── withOutlookRulesYAML.py  # Python desktop app (or moved to Archive/desktop-python/)
├── pytest/              # Python tests
└── README.md           # This file
```

## Projects

### Mobile App (Active Development)

**Location**: [`mobile-app/`](mobile-app/)  
**Status**: Phase 1 MVP - Foundation setup complete  
**Platform**: Flutter (Android, iOS, Chromebooks)  
**First Target**: AOL IMAP support

#### Quick Start

```powershell
# Install Flutter (if not already installed)
# Download from https://flutter.dev/docs/get-started/install/windows
# Or use chocolatey: choco install flutter

# Navigate to mobile app
cd mobile-app

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run tests
flutter test
```

See [`mobile-app/README.md`](mobile-app/README.md) for project details and
[`mobile-app/NEW_DEVELOPER_SETUP.md`](mobile-app/NEW_DEVELOPER_SETUP.md) for the validated Windows 11 setup.

### Desktop Python Application (Reference)

**Location**: Root directory (or [`Archive/desktop-python/`](Archive/desktop-python/) if moved)  
**Status**: Functional reference implementation  
**Platform**: Windows with Microsoft Outlook

The original Python application uses Outlook COM interfaces and serves as the reference implementation.

## Current Status (November 28, 2025)

### ✅ Mobile App - Completed
- Mobile app directory structure created
- Core models implemented (EmailMessage, RuleSet, SafeSenderList, EvaluationResult)
- Core services implemented (PatternCompiler, RuleEvaluator, YamlService)
- Email provider interface defined
- Basic UI scaffold (AccountSetupScreen)
- pubspec.yaml configured with Phase 1 dependencies

### 🔄 Mobile App - In Progress
- Flutter SDK installation (required for development)
- IMAP adapter implementation (AOL MVP)
- Platform storage integration

### 📋 Mobile App - Next Steps
1. Install Flutter SDK: https://flutter.dev/docs/get-started/install/windows
2. Run `flutter pub get` in mobile-app directory
3. Implement GenericIMAPAdapter using `enough_mail` package
4. Add platform-specific storage for YAML files
5. Build scan progress UI
6. Create unit tests for evaluator logic

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

```powershell
# Activate Python virtual environment (PowerShell)
./.venv/Scripts/Activate.ps1
```
```bash
# Activate Python virtual environment (Bash)
source .venv/bin/activate
```
# Standard processing (no interactive updates)
cd D:\Data\Harold\github\OutlookMailSpamFilter && ./.venv/Scripts/Activate.ps1 && python withOutlookRulesYAML.py

# Interactive mode (prompts to add rules)
cd D:\Data\Harold\github\OutlookMailSpamFilter && ./.venv/Scripts/Activate.ps1 && python withOutlookRulesYAML.py -u
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
