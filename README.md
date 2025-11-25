# OutlookMailSpamFilter

Automated Python-based email spam and phishing filter for Microsoft Outlook that processes multiple bulk mail folders using configurable YAML rules

## Overview

This tool provides intelligent filtering and removal of SPAM and phishing emails from Outlook accounts using pattern-based rules and safe sender management. The system processes emails from configurable folder lists and applies comprehensive filtering criteria including header analysis, body content scanning, subject pattern matching, and sender verification.

## Recent Updates (November 2025)

- ✅ **Unified print_to() function (11/15/2025)**: Consolidated output functionality
  - New `print_to()` function replaces multiple concurrent calls to log_print(), simple_print(), and print()
  - Supports flexible output to any combination of: debug log, simple log, and console
  - Automatically handles message sanitization for ASCII compatibility
  - Backward-compatible: old simple_print() calls still work via wrapper function
  - Reduces code duplication in summary reporting sections

## Recent Updates (October 2025)

- ✅ **Consolidated YAML filenames (10/18/2025)**: Simplified to single filenames now that regex is the only mode
  - Rules: `rules.yaml` (contains regex patterns)
  - Safe senders: `rules_safe_senders.yaml` (contains regex patterns)
  - Removed `_regex` suffix variants (rulesregex.yaml, rules_safe_sendersregex.yaml)
- ✅ **Interactive rule filtering enhanced (10/18/2025)**: During user input, emails matching newly added rules or safe senders are now properly skipped using regex matching
- ✅ **Legacy mode deprecated (10/14/2025)**: Regex mode is now the only supported mode
- ✅ CLI flags simplified for consolidated filenames
- ✅ Exporters enforce consistency (lowercase, trimmed, de-duped, sorted) and create timestamped backups in `archive/`
- ✅ Memory bank updated with processing flow, schemas, and regex conventions
- ✅ Interactive prompt gains new options: 'sd' (add sender-domain regex to safe_senders) and '?' (help)

## Recent Updates (July 2025)

- ✅ **Multi-Folder Processing**: Updated to process multiple folders instead of single folder
- ✅ **Configurable Folder List**: EMAIL_BULK_FOLDER_NAMES now supports ["Bulk Mail", "bulk"]
- ✅ **Recursive Folder Search**: Added capability to find folders at any nesting level
- ✅ **Enhanced Logging**: Folder-specific logging and processing information

## Key Features

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
