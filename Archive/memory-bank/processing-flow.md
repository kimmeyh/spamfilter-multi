# Processing flow (current as of 11/15/2025)

## File Structure (Consolidated Filenames)
- **rules.yaml** - Main spam filtering rules (contains regex patterns)
- **rules_safe_senders.yaml** - Trusted sender whitelist (contains regex patterns)
- Legacy files deprecated:
  - rulesregex.yaml → consolidated to rules.yaml (11/10/2025)
  - rules_safe_sendersregex.yaml → consolidated to rules_safe_senders.yaml (11/10/2025)

## Logging and Output Functions
- **print_to()** - Unified output function (added 11/15/2025)
  - Replaces multiple concurrent calls to log_print(), simple_print(), and print()
  - Parameters: `message, to_log=False, to_simple=False, to_console=False, log_instance=None`
  - Automatically sanitizes messages for ASCII compatibility
  - Examples:
    - `print_to("Summary:", to_log=True, to_simple=True, to_console=True, log_instance=agent)`
    - `print_to("Debug info", to_log=True, log_instance=agent)`
    - `print_to("User prompt", to_console=True)`
- **simple_print()** - Backward compatibility wrapper for print_to()
  - Original function deprecated but maintained for backward compatibility
  - Now calls print_to() internally
- **OutlookSecurityAgent.log_print()** - Instance method for logging
  - Writes to OUTLOOK_SECURITY_LOG via Python logging module
  - Handles message sanitization and encoding errors

## Processing Flow

- Load mode and active files
  - OutlookSecurityAgent.set_active_mode() uses consolidated regex files (rules.yaml, rules_safe_senders.yaml)
  - Legacy mode completely deprecated (10/14/2025)
  - OutlookSecurityAgent.get_rules() returns (rules_json, safe_senders)
- Primary processing
  - OutlookSecurityAgent.process_emails()
    - Safe senders are checked first
    - Rule evaluation honors regex patterns (only supported mode)
    - Two-pass: reprocess after interactive updates
- Interactive updates (optional)
  - Enabled with -u/--update_rules CLI flag
  - OutlookSecurityAgent.prompt_update_rules()
    - Suggests domain-anchored header regex via build_domain_regex_from_address()
    - Can add to SpamAutoDeleteHeader.header or safe_senders
    - Interactive options:
      - **d**: add domain regex to SpamAutoDeleteHeader (block domain and subdomains)
      - **e**: add full email to SpamAutoDeleteHeader (block specific sender)
      - **s**: add literal to safe_senders (allow specific sender)
      - **sd**: add sender-domain regex to safe_senders (allow domain and all subdomains)
      - **?**: show brief help message
      - **Enter**: skip without adding rules
    - Persists immediately via export_rules_to_yaml() and export_safe_senders_to_yaml()
    - Smart filtering during session (10/18/2025):
      - Skips emails that match newly added rules or safe senders
      - Uses regex matching via _compile_pattern_list() and _regex_match_header_any()
      - Prevents duplicate prompts for emails from same domain after user adds rule
- End-of-run persistence
  - Always exports active structures to consolidated filenames:
    - export_rules_to_yaml() → rules.yaml
    - export_safe_senders_to_yaml() → rules_safe_senders.yaml

## Diagnostics and Invariants
- Exporters lower-case, trim, de-dupe, sort all list fields
- YAML files use single quotes for pattern stability
- Timestamped backups saved in archive/ directory before overwrite
- All regex patterns follow conventions documented in regex-conventions.md
