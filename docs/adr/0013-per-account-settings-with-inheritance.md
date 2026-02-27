# ADR-0013: Per-Account Settings with Inheritance

## Status

Accepted

## Date

~2026-01-24 (Sprint 1, formalized in Sprint 8-13)

## Context

The spam filter supports multiple email accounts (Gmail, AOL, Yahoo, iCloud, custom IMAP) on the same device. Each account may need different configuration:

- **Scan mode**: One account might use readonly while another uses fullScan
- **Folder selection**: Gmail accounts scan "INBOX" and "[Gmail]/Spam"; AOL accounts scan "INBOX" and "Bulk Mail"
- **Deleted email destination**: One account moves filtered emails to "Trash", another to a custom "SpamFilter/Deleted" folder
- **Background scan frequency**: Work email scans every 15 minutes; personal email scans daily
- **Safe sender folder**: Where to move safe sender emails (if configured)

However, most users want a single default configuration that applies to all accounts, with the ability to override specific settings for individual accounts. Requiring full configuration per account would create unnecessary friction.

The account identifier must be globally unique across all email providers, since a user could have the same email address on different platforms (unlikely but architecturally possible).

## Decision

Implement a two-table settings architecture with inheritance resolution:

### Account Identification

Each account has a unique `accountId` in the format `{platform}-{email}`:
- `gmail-user@gmail.com`
- `aol-user@aol.com`
- `imap-user@outlook.com`

This format guarantees uniqueness across providers and enables platform-specific lookups.

### Settings Tables

**`app_settings`** (global defaults):
```
| key (PK)                    | value          | value_type | date_modified |
|-----------------------------|----------------|------------|---------------|
| manual_scan_mode            | readonly       | string     | 1706140800000 |
| manual_scan_folders         | ["INBOX"]      | json       | 1706140800000 |
| background_scan_enabled     | false          | boolean    | 1706140800000 |
| confirm_dialogs_enabled     | true           | boolean    | 1706140800000 |
```

**`account_settings`** (per-account overrides):
```
| account_id (PK)         | setting_key (PK)     | setting_value | value_type | date_modified |
|--------------------------|----------------------|---------------|------------|---------------|
| gmail-user@gmail.com    | manual_scan_mode     | fullScan      | string     | 1706140800000 |
| gmail-user@gmail.com    | manual_scan_folders  | ["INBOX","[Gmail]/Spam"] | json | 1706140800000 |
```

Composite primary key `(account_id, setting_key)` ensures one value per setting per account.

### Inheritance Resolution

`SettingsStore` provides `getEffective*()` methods that resolve the final value:

```
getEffectiveScanMode(accountId):
  1. Check account_settings for accountId + 'manual_scan_mode'
  2. If found: return account value
  3. If not found: return app_settings['manual_scan_mode']
  4. If neither: return hardcoded default (ScanMode.readonly)
```

This three-tier fallback (account -> app -> hardcoded) ensures every setting always has a value.

### Hardcoded Defaults

```
manual_scan_mode: ScanMode.readonly
manual_scan_folders: ['INBOX']
background_scan_enabled: false
background_scan_frequency: 15 minutes
confirm_dialogs_enabled: true
```

## Alternatives Considered

### Single Settings Table with Nullable account_id
- **Description**: One `settings` table with columns `(account_id NULLABLE, key, value)`. Rows with `account_id = NULL` are global defaults; rows with a specific `account_id` are overrides
- **Pros**: Single table; simpler schema; fewer queries for settings that apply to all accounts
- **Cons**: Nullable foreign keys complicate constraints and indexing; "global" vs. "per-account" is implicit (depends on NULL check); composite unique constraint `(account_id, key)` does not work cleanly with NULLs in SQLite (NULL != NULL); queries must handle NULL specially
- **Why Rejected**: SQLite's handling of NULL in unique constraints is non-intuitive (multiple rows with NULL account_id and the same key are allowed). Separate tables make the scope explicit and avoid NULL-related edge cases

### Per-Account Database Files
- **Description**: Create a separate SQLite database file for each account, containing that account's settings, scan results, and email actions
- **Pros**: Complete isolation between accounts; no foreign key complexity; can back up/restore individual accounts; no composite keys needed
- **Cons**: Shared data (rules, safe senders) must be duplicated or stored in a separate "global" database; multiple database connections to manage; cross-account queries (e.g., "total emails scanned across all accounts") require querying multiple databases; database connection pooling complexity
- **Why Rejected**: Rules and safe senders are shared across all accounts (one rule set applies to all email). Splitting databases would require either duplicating shared data or managing cross-database queries, adding significant complexity for limited benefit

### Settings Embedded in Account Record
- **Description**: Add settings columns directly to the `accounts` table (e.g., `scan_mode`, `scan_folders`, `background_enabled` as columns)
- **Pros**: Single query to load account with all settings; no JOIN or separate lookup; simple schema
- **Cons**: Adding a new setting requires an ALTER TABLE migration; columns for settings not overridden are NULL (wastes space conceptually); no clear separation between account identity and account configuration; table becomes very wide as settings grow
- **Why Rejected**: The settings catalog grows over time (Sprint 8 added background settings, Sprint 13 added deleted rule folder). A key-value design accommodates new settings without schema migrations. Embedding settings in the account table would require an ALTER TABLE for each new setting

### Shared Preferences (Platform-Native)
- **Description**: Use Flutter's `shared_preferences` package for settings storage instead of SQLite
- **Pros**: Simple key-value API; platform-native storage (SharedPreferences on Android, NSUserDefaults on iOS, Registry on Windows); well-suited for small configuration data
- **Cons**: No relational queries; no foreign key relationships to accounts; platform-specific storage locations make debugging inconsistent; no transaction support; cannot easily migrate or export settings; separate from the main database
- **Why Rejected**: Settings are relationally tied to accounts (via account_id foreign key). Storing them in a separate system outside the main database would split the data model and prevent CASCADE deletes when an account is removed

## Consequences

### Positive
- **Zero-configuration default**: New accounts automatically inherit all app-level defaults. Users only configure per-account settings when they need different behavior
- **Clean inheritance**: The three-tier fallback (account -> app -> hardcoded) guarantees every setting always resolves to a value, eliminating null-handling throughout the codebase
- **Extensible**: New settings are added by defining a new key constant and hardcoded default. No schema migration required (the key-value design accommodates new settings without ALTER TABLE)
- **Account deletion cleanup**: CASCADE delete on the `account_settings` foreign key automatically removes all per-account settings when an account is deleted

### Negative
- **No type safety**: Settings are stored as text values with a `value_type` hint. The application must parse and validate values at read time (e.g., converting `"true"` to `bool`, parsing JSON arrays)
- **Query overhead for effective values**: Resolving the effective value requires checking two tables (account_settings first, then app_settings). For frequently accessed settings, this adds a small overhead compared to a single-table lookup
- **Setting key consistency**: Setting keys are string constants defined in `SettingsStore`. Typos in key names produce silent misses (setting not found, falls back to default). There is no compile-time verification that a key exists

### Neutral
- **JSON for complex values**: List-type settings (folder selections, scan folders) are stored as JSON strings. This is consistent with the JSON array approach used in the rules table (ADR-0010) but means complex values require JSON parsing on every read

## References

- `mobile-app/lib/core/storage/settings_store.dart` - Settings CRUD with inheritance resolution (lines 1-523): app settings (lines 41-60), per-account overrides (lines 174-345), effective resolution (lines 391-416)
- `mobile-app/lib/core/storage/account_store.dart` - Account registry (lines 1-87)
- `mobile-app/lib/core/storage/database_helper.dart` - app_settings and account_settings table schemas
- ADR-0010 (Normalized Database Schema) - Table design and composite primary key
- ADR-0006 (Four Progressive Scan Modes) - ScanMode enum stored as per-account setting
