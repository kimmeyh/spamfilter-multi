# ADR-0010: Normalized Database Schema (9 Tables)

## Status

Accepted

## Date

~2026-01-24 (Sprint 1, Phase 3.5 database architecture)

## Context

The spam filter application needs persistent storage for rules, safe senders, scan results, email action history, account information, settings, and background scan schedules. The database must support:

- **Multi-account management**: Multiple email accounts with independent settings
- **Scan audit trail**: Complete history of every scan and every email action taken
- **Rule storage**: Migrated from YAML with full condition/action/exception support
- **Settings hierarchy**: Global app settings and per-account overrides
- **Background scheduling**: Per-account scan schedules with execution logs

The schema design required several sub-decisions about data representation: how to store rule conditions (multiple patterns per field), how to represent enums, how to handle timestamps across platforms, and how to structure settings for inheritance.

These decisions were documented in detail in `DATABASE_ARCHITECTURE_DECISIONS.md` during the Phase 3.5 Sprint 1 planning.

## Decision

Implement a normalized schema with 9 separate tables, each serving a single purpose, connected by foreign keys with CASCADE delete rules. Key sub-decisions:

### Table Structure

| Table | Purpose | Primary Key |
|-------|---------|-------------|
| `accounts` | Account registry | `account_id` TEXT |
| `scan_results` | Scan execution metadata | `id` INTEGER AUTOINCREMENT |
| `email_actions` | Per-email evaluation results | `id` INTEGER AUTOINCREMENT |
| `rules` | Spam filtering rules | `id` INTEGER AUTOINCREMENT |
| `safe_senders` | Trusted sender patterns | `id` INTEGER AUTOINCREMENT |
| `app_settings` | Global configuration | `key` TEXT |
| `account_settings` | Per-account overrides | (`account_id`, `setting_key`) composite |
| `background_scan_schedule` | Per-account schedules | `account_id` TEXT |
| `background_scan_log` | Schedule execution history | `id` INTEGER AUTOINCREMENT |

### Sub-Decision 1: JSON Arrays for Rule Conditions

Rule conditions (from, header, subject, body) each contain multiple regex patterns. These are stored as JSON arrays within TEXT columns:

```
condition_from: '["@spam\\.com$", "@phishing\\.net$"]'
condition_header: '["x-mailer:.*bulk"]'
```

This preserves the semantic grouping (all "from" patterns belong together) and maps directly to/from the YAML rule format.

### Sub-Decision 2: Text-Based Enums

Enum values are stored as human-readable text, not integer codes:

```
scan_type: 'manual' | 'background'
scan_mode: 'readonly' | 'testLimit' | 'testAll' | 'fullScan'
action_type: 'delete' | 'moveToJunk' | 'safeSender' | 'none'
status: 'running' | 'completed' | 'error'
```

### Sub-Decision 3: Milliseconds Since Epoch for Timestamps

All timestamp columns use INTEGER storing Dart's `DateTime.now().millisecondsSinceEpoch`:

```
date_added: 1706140800000  (not '2026-01-25T00:00:00Z')
```

### Sub-Decision 4: 10 Targeted Indexes

Indexes are created for specific query patterns rather than blanket indexing:

- `idx_rules_enabled`: Composite `(enabled, execution_order)` for rule evaluation queries
- `idx_email_actions_no_rule`: Partial index for unmatched emails (`matched_rule_name IS NULL`)
- `idx_scan_results_completed`: For date-range scan history queries
- 7 additional indexes for account lookups, folder filtering, and settings access

## Alternatives Considered

### Single Table with JSON Blobs
- **Description**: Store all data in one or two tables with JSON columns for complex data (rules as complete JSON objects, scan results as JSON arrays)
- **Pros**: Simple schema; flexible; no migrations needed for new fields; document-store-like simplicity
- **Cons**: No query filtering on individual fields (cannot "SELECT rules WHERE enabled=1"); no referential integrity; no type constraints; JSON parsing overhead on every read; entire dataset loaded even when only one field needed
- **Why Rejected**: The application needs to query specific fields frequently (enabled rules in execution order, unmatched emails, scans by date range). JSON blobs would force loading and parsing entire documents for every query

### Separate Pattern Table with JOINs
- **Description**: Instead of JSON arrays in the rules table, create a separate `rule_patterns` table with foreign key to rules and columns for pattern_type (from/header/subject/body) and pattern_value
- **Pros**: Fully normalized; can query individual patterns; standard relational design; can add metadata per pattern (date added, match count)
- **Cons**: Requires JOINs for every rule load (rules + N patterns); more complex insert/update logic (must manage child records); breaks atomicity of rule definition (partial updates possible); lossy transformation from YAML format
- **Why Rejected**: Rule conditions are always loaded as a complete unit for evaluation. Splitting them across tables adds JOIN overhead and complexity without enabling useful per-pattern queries. The JSON array approach preserves the atomic "load all conditions at once" pattern and maps cleanly to/from YAML

### Integer Enum Codes
- **Description**: Store enum values as integers (e.g., `scan_mode: 0` for readonly, `1` for testLimit) with a lookup table or application-level mapping
- **Pros**: Smaller storage; faster comparison; standard database practice; enforces valid values via CHECK constraints
- **Cons**: Requires lookup to understand raw database content; application must maintain bidirectional mapping; adding new enum values requires careful coordination; database dumps are not human-readable
- **Why Rejected**: Debuggability was prioritized over micro-optimization. Text enums allow developers to read raw database content without a lookup table. The storage overhead is negligible for the data volumes in this application (hundreds of rules, not millions of rows)

### ISO 8601 Text Timestamps
- **Description**: Store timestamps as TEXT in ISO 8601 format (e.g., `'2026-01-25T12:00:00Z'`)
- **Pros**: Human-readable in raw database; timezone-explicit; standard format; sortable as text
- **Cons**: String comparison slower than integer comparison; parsing overhead on every read; timezone handling complexity (UTC vs. local); larger storage per row; SQLite string sorting may differ from chronological sorting in edge cases
- **Why Rejected**: Dart's DateTime natively serializes to/from millisecondsSinceEpoch, making it the natural format. Integer timestamps sort correctly, compare efficiently, and avoid timezone ambiguity across the 5 supported platforms

## Consequences

### Positive
- **Query efficiency**: Each query touches only the relevant table(s) with appropriate indexes; no unnecessary data loading
- **Referential integrity**: Foreign keys with CASCADE delete ensure that deleting an account removes all associated scan results, email actions, settings, and schedules automatically
- **Debuggability**: Text-based enums and descriptive column names make raw database inspection straightforward with any SQLite viewer
- **Extensibility**: New tables can be added without affecting existing ones; new columns can be added with DEFAULT values for backward compatibility
- **Multi-account isolation**: Account-scoped foreign keys naturally partition data by account

### Negative
- **Migration complexity**: Schema changes require migration logic in `onUpgrade` with version tracking; each new column or table needs careful migration code
- **JSON array limitations**: Cannot perform SQL-level filtering on individual patterns within JSON arrays (e.g., "find all rules that contain a specific pattern"); all pattern matching must happen in application code
- **Schema breadth**: 9 tables with 10 indexes add complexity to the DatabaseHelper class; developers must understand the full schema to work effectively

### Neutral
- **SQLite as database engine**: SQLite is embedded (no server), cross-platform, and well-supported by Flutter via `sqflite`. It is sufficient for this application's data volumes but would not scale to millions of rules or concurrent multi-device access without a server-based database
- **Version-tracked migrations**: The database uses `onUpgrade` with a version integer, providing a clear upgrade path but requiring developers to write migration logic for each schema change

## References

- `mobile-app/lib/core/storage/database_helper.dart` - Schema definitions (lines 76-264), migration logic, PRAGMA settings
- `docs/DATABASE_ARCHITECTURE_DECISIONS.md` - Detailed design rationale for all 11 sub-decisions (473 lines)
- ADR-0004 (Dual-Write Storage) - YAML export as secondary persistence after database writes
- ADR-0013 (Per-Account Settings) - app_settings and account_settings table design
