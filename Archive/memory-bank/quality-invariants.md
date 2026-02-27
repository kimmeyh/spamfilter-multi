# Quality Checks and Invariants (Updated 11/10/2025)

## Exporter Invariants

### export_rules_to_yaml()
- **Target file**: rules.yaml (consolidated filename as of 11/10/2025)
- **Normalization**: Lowercases, strips, de-duplicates, and sorts all list fields
- **Quote style**: Uses single quotes for regex pattern stability
- **Backup**: Creates timestamped backup in archive/ directory before overwrite
- **Format**: Enforces consistent YAML structure with proper indentation

### export_safe_senders_to_yaml()
- **Target file**: rules_safe_senders.yaml (consolidated filename as of 11/10/2025)
- **Normalization**: Lowercases, strips, de-duplicates, and sorts safe_senders list
- **Quote style**: Uses single quotes for regex pattern stability
- **Backup**: Creates timestamped backup in archive/ directory before overwrite
- **Format**: Enforces consistent YAML structure with proper indentation

## Processing Invariants

### Email Processing Order
1. Safe senders checked first before rule evaluation
2. Rule conditions evaluated using regex matching
3. Actions applied only if no safe sender match
4. Second-pass reprocessing runs after interactive updates
5. All patterns treated as regex (no legacy wildcard mode)

### Pattern Matching
- **Mode**: Regex-only (legacy wildcard mode deprecated 10/14/2025)
- **Case sensitivity**: All patterns converted to lowercase for case-insensitive matching
- **Compilation**: Patterns compiled with re.IGNORECASE flag
- **Validation**: Invalid regex patterns logged and skipped

### Interactive Updates (with -u flag)
- Rules added immediately to in-memory structures
- Exports triggered after each rule addition
- Smart filtering: Emails matching newly added rules skipped during session (10/18/2025)
- Backup created before each export operation

## YAML File Format

### Consolidated Filenames (11/10/2025)
- **rules.yaml** - Contains all spam filtering rules with regex patterns
- **rules_safe_senders.yaml** - Contains all safe sender patterns with regex

### YAML Structure
- Single quotes used consistently for all string patterns
- Lists formatted with proper indentation
- Boolean values preserved as string literals ('True'/'False')
- Consistent field ordering enforced

## Testing Invariants
- All tests must pass without errors or warnings
- Import compatibility verified for all modules
- YAML syntax validated on export
- File content validation on read/write operations
- Second-pass implementation verified
- Multi-folder processing tested

## Historical Notes
- **11/10/2025**: Consolidated filenames - removed `regex` suffix variants
  - `rulesregex.yaml` → `rules.yaml`
  - `rules_safe_sendersregex.yaml` → `rules_safe_senders.yaml`
- **10/18/2025**: Enhanced interactive filtering with smart skip logic
- **10/14/2025**: Legacy wildcard mode deprecated - regex is the only supported mode
- **Pre-10/2025**: Legacy and regex modes ran in parallel with separate YAML files
