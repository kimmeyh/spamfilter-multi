# YAML Schemas (Effective as of 11/10/2025)

## Consolidated Filename Structure
As of 11/10/2025, YAML files use consolidated filenames without mode suffixes:
- **rules.yaml** - Contains regex patterns (only supported format)
- **rules_safe_senders.yaml** - Contains regex patterns (only supported format)

## rules.yaml Schema
```yaml
version: string
settings:
  default_execution_order_increment: int
rules: list[Rule]
```

### Rule Object
```yaml
name: string
enabled: 'True'|'False' (string literal)
isLocal: 'True'|'False' (string literal)
executionOrder: string|int
conditions:
  type: 'OR'|'AND'
  from: list[string] (regex patterns)
  header: list[string] (regex patterns)
  subject: list[string] (regex patterns)
  body: list[string] (regex patterns)
actions: object
  assign_to_category: string
  delete: boolean
  move_to_folder: string
  # ... other action properties
exceptions:
  from: list[string] (regex patterns)
  header: list[string] (regex patterns)
  subject: list[string] (regex patterns)
  body: list[string] (regex patterns)
metadata: optional object
```

## rules_safe_senders.yaml Schema
```yaml
safe_senders: list[string]
```
- Each entry is a regex pattern
- Commonly anchored with `^...$` for full address matching
- Can use domain-anchor patterns like `@(?:[a-z0-9-]+\.)*example\.com$`

## YAML Export Conventions
All YAML exports enforce these invariants:
1. **Lowercase** - All patterns converted to lowercase
2. **Trimmed** - Leading/trailing whitespace removed
3. **De-duplicated** - Duplicate entries removed
4. **Sorted** - Alphabetically sorted for consistency
5. **Single quotes** - YAML uses single quotes to avoid backslash escaping issues

## Pattern Format
- All patterns are **regex** (no legacy wildcard-only mode)
- Domain patterns typically use anchored format: `@(?:[a-z0-9-]+\.)*domain\.com$`
- See `regex-conventions.md` for detailed pattern formatting guidelines

## Historical Notes
- **11/10/2025**: Consolidated filenames - removed `regex` suffix from YAML files
  - `rulesregex.yaml` → `rules.yaml`
  - `rules_safe_sendersregex.yaml` → `rules_safe_senders.yaml`
- **10/14/2025**: Legacy wildcard mode deprecated - regex is the only supported mode
- **Pre-10/2025**: Conversion utilities available for migrating wildcard patterns to regex
