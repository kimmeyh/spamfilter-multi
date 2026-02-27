# Regex Conventions (Updated 11/10/2025)

## Pattern Formatting
- **Lowercase**: All patterns lowercased on export for case-insensitive matching
- **Trimmed**: Leading/trailing whitespace removed
- **YAML Quoting**: Single quotes used to avoid backslash escape issues
- **Regex-only**: All patterns are regex (legacy wildcard mode deprecated 10/14/2025)

## Legacy Conversion (Historical)
Conversion utilities were used to migrate from wildcard to regex patterns:
- `convert_rules_yaml_to_regex()` - Converted rules.yaml wildcards to regex (deprecated 11/10/2025)
- `convert_safe_senders_yaml_to_regex()` - Converted safe senders wildcards to regex (deprecated 11/10/2025)
- Glob semantics: `*` in legacy became `.*` in regex converters
- **Note**: All files now contain regex patterns; conversion utilities no longer needed

## Domain Header Patterns (Blocking)

### build_domain_regex_from_address(addr_or_domain)
Produces anchored regex for blocking emails from a domain and all its subdomains:
- **Pattern**: `@(?:[a-z0-9-]+\.)*<anchor>\.[a-z0-9.-]+$`
- **Logic**: Anchor chosen from first meaningful subdomain left of TLD
- **Fallback**: `@(?:[a-z0-9-]+\.)*[a-z0-9-]+\.[a-z0-9.-]+$` (generic)
- **Usage**: Interactive option 'd' (add to SpamAutoDeleteHeader)

## Sender Domain Safe-Senders Patterns (Allowing)

### build_sender_domain_safe_regex(addr_or_domain)
Produces full-address regex for allowing emails from a domain and all its subdomains:
- **Pattern**: `^[^@\s]+@(?:[a-z0-9-]+\.)*<domain>$`
- **Logic**: Matches any local part at the exact domain and any subdomains
- **Usage**: Interactive option 'sd' (add to safe_senders)

## Pattern Examples

### Blocking Patterns (SpamAutoDeleteHeader.header)
```regex
mailer\-daemon@aol\.com                              # Specific email address
@(?:[a-z0-9-]+\.)*example\.com$                     # Domain and all subdomains
@(?:[a-z0-9-]+\.)*example\.[a-z0-9.-]+$             # Domain with generic TLD
```

### Allowing Patterns (safe_senders)
```regex
john\.doe@company\.com                               # Specific email address (literal)
^[^@\s]+@(?:[a-z0-9-]+\.)*lifeway\.com$             # Domain and all subdomains (sender-domain)
```

## Interactive Options Pattern Usage

| Option | Function | Pattern Type | Target List |
|--------|----------|-------------|-------------|
| **d** | Block domain | `@(?:[a-z0-9-]+\.)*domain\.com$` | SpamAutoDeleteHeader.header |
| **e** | Block email | Literal email address | SpamAutoDeleteHeader.header |
| **s** | Allow literal | Literal email address | safe_senders |
| **sd** | Allow domain | `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$` | safe_senders |

## Regex Compilation
- Patterns compiled with `re.IGNORECASE` flag
- Invalid patterns logged and skipped during processing
- Compilation cached for performance

## File Structure (as of 11/10/2025)
- **rules.yaml** - Contains all regex patterns for blocking
- **rules_safe_senders.yaml** - Contains all regex patterns for allowing
