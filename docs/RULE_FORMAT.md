# YAML Rule Format Specification

**Purpose**: Complete specification for rules.yaml and rules_safe_senders.yaml file formats

**Last Updated**: January 30, 2026

---

## Overview

All spam filtering rules are defined in YAML format using **regex patterns only**. Legacy wildcard mode was removed on November 10, 2025.

**Key Files**:
- `rules.yaml` - Spam filtering rules with conditions and actions
- `rules_safe_senders.yaml` - Whitelist of trusted senders (regex patterns)

---

## rules.yaml Structure

### File Format

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
      body: []
    actions:
      delete: true
      moveToFolder: null
    exceptions:
      from: ["^trusted@example\\.com$"]
      header: []
      subject: []
      body: []
    executionOrder: 10
```

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | String | Yes | File format version (currently "1.0") |
| `settings` | Object | Yes | Global configuration |
| `rules` | Array | Yes | List of spam filtering rules |

### Settings Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default_execution_order_increment` | Integer | 10 | Increment for auto-assigning execution order |

### Rule Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Unique rule identifier |
| `enabled` | String | Yes | "True" or "False" (case-sensitive) |
| `conditions` | Object | Yes | Match conditions (see below) |
| `actions` | Object | Yes | Actions to take when matched |
| `exceptions` | Object | No | Exception patterns (skip rule if matched) |
| `executionOrder` | Integer | Yes | Rule evaluation order (ascending) |

### Conditions Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | String | "OR" | Logic operator: "OR" or "AND" |
| `from` | Array of Strings | [] | From address patterns (regex) |
| `subject` | Array of Strings | [] | Subject line patterns (regex) |
| `body` | Array of Strings | [] | Email body patterns (regex) |
| `header` | Array of Strings | [] | Email header patterns (regex) |

**Logic**:
- **OR**: Email matches if ANY pattern list matches
- **AND**: Email matches if ALL non-empty pattern lists match

**Evaluation**:
1. Empty pattern lists are ignored
2. If all pattern lists are empty, rule does not match
3. Patterns within a list are OR-ed together
4. Pattern lists are combined with the specified type (AND/OR)

### Actions Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `delete` | Boolean | false | Delete email permanently |
| `moveToFolder` | String or null | null | Move email to specified folder |

**Note**: Only one action is typically specified per rule.

### Exceptions Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `from` | Array of Strings | [] | Exception patterns for From address |
| `subject` | Array of Strings | [] | Exception patterns for Subject |
| `body` | Array of Strings | [] | Exception patterns for Body |
| `header` | Array of Strings | [] | Exception patterns for Headers |

**Behavior**: If ANY exception pattern matches, the entire rule is skipped (even if conditions match).

---

## rules_safe_senders.yaml Structure

### File Format

```yaml
safe_senders:
  - "^user@example\\.com$"                          # Exact email match
  - "^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com$"   # Domain + all subdomains
```

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `safe_senders` | Array of Strings | Yes | List of regex patterns for trusted senders |

**Behavior**:
- Safe senders bypass ALL spam rules
- Checked BEFORE rule evaluation
- If From address matches ANY safe sender pattern, email is marked as safe (no actions taken)

---

## YAML Export Invariants

All YAML exports enforce these invariants to maintain consistency:

1. **Lowercase Conversion**: All pattern strings converted to lowercase
2. **Trimmed Whitespace**: Leading/trailing whitespace removed
3. **De-duplication**: Duplicate patterns removed
4. **Alphabetical Sorting**: Patterns sorted alphabetically within lists
5. **Single Quotes**: Use single quotes to avoid backslash escaping issues
6. **Timestamped Backups**: Create backup in `Archive/` before overwriting

**Example**:
```yaml
# Before export
safe_senders:
  - "User@Example.com  "  # Has uppercase and trailing space
  - "user@example.com"    # Duplicate (case-insensitive)

# After export
safe_senders:
  - 'user@example.com'    # Lowercase, trimmed, deduplicated, single quotes
```

---

## Regex Pattern Conventions

### Pattern Formatting

- **Lowercase**: All patterns are lowercase (matching is case-insensitive via `caseSensitive: false`)
- **Trimmed**: No leading/trailing whitespace
- **No Inline Flags**: Dart RegExp does not support Python-style flags (`(?i)`, `(?m)`, `(?s)`, `(?x)`)
- **Single Quotes**: YAML uses single quotes to avoid backslash escaping

### Domain Blocking Patterns

**Use Case**: Block emails from specific domains (for `SpamAutoDeleteHeader.header`)

| Pattern Type | Format | Example |
|--------------|--------|---------|
| **Domain + Subdomains** | `@(?:[a-z0-9-]+\.)*domain\.com$` | `@(?:[a-z0-9-]+\.)*spam\.com$` |
| **Domain + Generic TLD** | `@(?:[a-z0-9-]+\.)*domain\.[a-z0-9.-]+$` | `@(?:[a-z0-9-]+\.)*spam\.[a-z0-9.-]+$` |
| **Specific Email** | `email@domain\.com` | `mailer-daemon@aol\.com` |

**Explanation**:
- `@` - Match literal @ symbol
- `(?:[a-z0-9-]+\.)*` - Match zero or more subdomains (non-capturing group)
- `domain\.com` - Match literal domain with escaped dot
- `$` - Anchor to end of string

### Safe Sender Patterns

**Use Case**: Whitelist trusted senders (for `rules_safe_senders.yaml`)

| Pattern Type | Format | Example |
|--------------|--------|---------|
| **Exact Email** | `^email@domain\.com$` | `^john\.doe@company\.com$` |
| **Domain + Subdomains** | `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$` | `^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$` |

**Explanation**:
- `^` - Anchor to start of string
- `[^@\s]+` - Match one or more characters that are not @ or whitespace (email local part)
- `@` - Match literal @ symbol
- `(?:[a-z0-9-]+\.)*` - Match zero or more subdomains
- `domain\.com` - Match literal domain
- `$` - Anchor to end of string

### Subject/Body Patterns

**Use Case**: Match text in subject or body

| Pattern Type | Format | Example |
|--------------|--------|---------|
| **Contains Word** | `word` | `viagra` (matches "Buy Viagra Now") |
| **Starts With** | `^text` | `^urgent` (matches "Urgent: Action Required") |
| **Ends With** | `text$` | `click here$` (matches "... click here") |
| **Exact Match** | `^exact text$` | `^you have won$` |

### Header Patterns

**Use Case**: Match email headers (X-Spam-Status, etc.)

**Format**: `header-name:value`

**Examples**:
```regex
x-spam-status:yes          # Match X-Spam-Status: Yes
x-mailer:.*spambot.*       # Match X-Mailer containing "spambot"
```

**Special Case - From Header**:
- Match against **email address only** (not "Name <email>" format)
- Use `message.from` which has already extracted the email
- Do NOT include "from:" prefix in pattern

---

## Pattern Building Reference

### Quick Reference Table

| Purpose | Pattern Format | Example |
|---------|---------------|---------|
| **Block domain** | `@(?:[a-z0-9-]+\.)*domain\.com$` | `@(?:[a-z0-9-]+\.)*spam\.com$` |
| **Block email** | `email@domain\.com` | `spammer@example\.com` |
| **Allow exact email** | `^email@domain\.com$` | `^trusted@company\.com$` |
| **Allow domain** | `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$` | `^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$` |
| **Subject contains** | `word` | `viagra` |
| **Subject starts** | `^text` | `^urgent` |
| **Header match** | `header:value` | `x-spam-status:yes` |

### Common Regex Patterns

| Pattern | Meaning | Example |
|---------|---------|---------|
| `.` | Any character except newline | `a.c` matches "abc", "a1c" |
| `\.` | Literal dot | `example\.com` matches "example.com" |
| `*` | Zero or more of preceding | `a*` matches "", "a", "aaa" |
| `+` | One or more of preceding | `a+` matches "a", "aaa" (not "") |
| `?` | Zero or one of preceding | `colou?r` matches "color", "colour" |
| `^` | Start of string | `^hello` matches "hello world" (not "say hello") |
| `$` | End of string | `world$` matches "hello world" (not "world hello") |
| `[abc]` | Any character in set | `[aeiou]` matches any vowel |
| `[^abc]` | Any character NOT in set | `[^0-9]` matches non-digits |
| `\s` | Whitespace | `\s+` matches spaces, tabs, newlines |
| `\d` | Digit | `\d+` matches "123" |
| `\w` | Word character | `\w+` matches "hello" |
| `(?:...)` | Non-capturing group | `(?:[a-z]+\.)*` |

---

## Regex Compilation

### Case-Insensitive Matching

All patterns are compiled with `caseSensitive: false`, equivalent to Python's `re.IGNORECASE`.

**Example**:
```dart
final regex = RegExp(pattern, caseSensitive: false);
```

This means:
- Pattern `example.com` matches "Example.COM", "EXAMPLE.com", etc.
- No need for `(?i)` flag in pattern

### Invalid Pattern Handling

- Invalid patterns are logged and tracked (not silently ignored)
- `PatternCompiler.getInvalidPatterns()` returns list of failed patterns
- UI can display warnings for invalid patterns
- Invalid patterns do NOT match any emails (fail-safe behavior)

### Pattern Caching

- Compiled patterns are cached for performance
- Same pattern string reuses cached RegExp object
- Cache is cleared when rules are reloaded

---

## Example Rules

### Block All Emails from Domain

```yaml
- name: "BlockSpamDomain"
  enabled: "True"
  conditions:
    type: "OR"
    from: ["@(?:[a-z0-9-]+\\.)*spam\\.com$"]
    header: []
    subject: []
    body: []
  actions:
    delete: true
  exceptions: {}
  executionOrder: 10
```

### Block Emails with Specific Subject

```yaml
- name: "BlockUrgentSubject"
  enabled: "True"
  conditions:
    type: "OR"
    from: []
    header: []
    subject: ["^urgent.*action required"]
    body: []
  actions:
    delete: true
  exceptions: {}
  executionOrder: 20
```

### Block Spam Headers Except from Trusted Sender

```yaml
- name: "BlockSpamHeaders"
  enabled: "True"
  conditions:
    type: "OR"
    from: []
    header: ["x-spam-status:yes"]
    subject: []
    body: []
  actions:
    delete: true
  exceptions:
    from: ["^trusted@company\\.com$"]
    header: []
    subject: []
    body: []
  executionOrder: 30
```

### Allow Domain (Safe Sender)

```yaml
# In rules_safe_senders.yaml
safe_senders:
  - '^[^@\\s]+@(?:[a-z0-9-]+\\.)*company\\.com$'  # Allow company.com and all subdomains
  - '^john\\.doe@example\\.com$'                   # Allow specific email
```

---

## Validation Rules

### Schema Validation

When loading YAML files, the following validations are performed:

1. **File Structure**:
   - rules.yaml must have `version`, `settings`, `rules` fields
   - rules_safe_senders.yaml must have `safe_senders` field

2. **Rule Validation**:
   - `name` must be non-empty string
   - `enabled` must be "True" or "False" (case-sensitive)
   - `conditions.type` must be "OR" or "AND"
   - `executionOrder` must be integer >= 0

3. **Pattern Validation**:
   - All patterns must be valid regex (compile without error)
   - Patterns should not be empty strings
   - Patterns are trimmed and lowercased on export

### Best Practices

- **Test patterns** before adding to production rules
- **Use exceptions** instead of complex negative lookaheads
- **Keep patterns simple** - complex regex is hard to maintain
- **Document intent** with YAML comments
- **Anchor patterns** when matching full strings (use ^ and $)
- **Escape special chars** (. becomes \., * becomes \*, etc.)

---

## Common Mistakes

### [FAIL] Incorrect Patterns

```yaml
# BAD: Forgot to escape dot
from: ["@spam.com$"]  # Matches "@spamXcom" (dot matches any char)

# BAD: Missing anchors
safe_senders: ["user@example.com"]  # Matches "baduser@example.com"

# BAD: Using wildcards instead of regex
subject: ["*urgent*"]  # Literal asterisks, not wildcard

# BAD: Mixed case (patterns are lowercased on export)
from: ["User@Example.com"]  # Inconsistent with export format
```

### [OK] Correct Patterns

```yaml
# GOOD: Escaped dot
from: ["@spam\\.com$"]

# GOOD: Anchored pattern
safe_senders: ["^user@example\\.com$"]

# GOOD: Regex for "contains"
subject: [".*urgent.*"]  # Or just "urgent" (implicit contains)

# GOOD: Lowercase
from: ["user@example\\.com"]
```

---

**Document Version**: 1.0
**Created**: January 30, 2026
**Related Documents**:
- `docs/ARCHITECTURE.md` - Application architecture
- `CLAUDE.md` - Primary development guide
- `docs/LOGGING_CONVENTIONS.md` - Logging patterns
