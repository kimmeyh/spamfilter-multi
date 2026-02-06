# Database Architecture Decisions - Sprint 1

This document explains the architectural decisions made for the Phase 3.5 SQLite database implementation, providing rationale for future maintainers and developers.

---

## Overview

Phase 3.5 migrates spamfilter-multi from YAML-based storage to SQLite database while maintaining dual-write compatibility. This document explains the "why" behind the schema design and data structure choices.

---

## Table Design Decisions

### **1. Eight Tables Instead of Fewer**

**Decision**: Create 8 separate tables (scan_results, email_actions, rules, safe_senders, app_settings, account_settings, background_scan_schedule, accounts) instead of consolidating into fewer tables.

**Rationale**:
- **Separation of Concerns**: Each table has a single, clear purpose
  - `scan_results`: Historical scan metadata (when, how many emails, what happened)
  - `email_actions`: Individual email-level details (for review, unmatched tracking)
  - `rules`: Spam filtering rules (from YAML migration)
  - `safe_senders`: Trusted sender patterns
  - `app_settings` & `account_settings`: Configuration (separate from operational data)
  - `background_scan_schedule`: Scheduling (separate from settings)
  - `accounts`: Account registry (foundation for multi-account support)

- **Query Efficiency**: Each query fetches only needed columns
  - Querying "all rules" doesn't load scan history
  - Querying "scan results for last 30 days" doesn't load rule details
  - Prevents N+1 query problems

- **Future Extensibility**: Adding new entities doesn't affect existing queries
  - If we add "rule groups" later, no existing queries break
  - New settings can be added to app_settings without schema changes

- **Data Integrity**: Foreign keys prevent orphaned records
  - Deleting a scan automatically deletes its email_actions (CASCADE)
  - Prevents accidental data inconsistencies

**Alternative Considered**: Single "data" table with JSON blobs
- **Rejected**: Would eliminate query filtering (must load all data to filter), no referential integrity, slower for large datasets

**Alternative Considered**: Star schema with single fact table
- **Rejected**: Unnecessary complexity for current use case; simple normalized schema is more maintainable

---

### **2. JSON Arrays for Rule Conditions Instead of Separate Tables**

**Decision**: Store rule conditions as JSON arrays in single columns:
```
condition_from: '["pattern1", "pattern2", "pattern3"]'
condition_header: '["pattern4", "pattern5"]'
```

Instead of:
```
CREATE TABLE rule_patterns (
  rule_id INTEGER,
  condition_type TEXT,
  pattern TEXT,
  FOREIGN KEY (rule_id) REFERENCES rules(id)
)
```

**Rationale**:
- **Atomicity**: Rule conditions load/save as complete unit
  - When creating rule, all conditions atomic (success or fail together)
  - No partial rule states possible
  - One database write per rule mutation instead of 5+ writes

- **Relationship Preservation**: Conditions always tied to specific rule field
  - "from" patterns logically different from "header" patterns
  - JSON preserves this semantic relationship
  - SQL join would require additional metadata to track which column

- **Query Pattern**: Rules fetched completely, conditions never queried independently
  - Applications never ask: "Show me all rules with this specific pattern"
  - Applications always ask: "Load rule X, get all its conditions"
  - JSON is better match for this access pattern

- **YAML Compatibility**: Original YAML format already uses arrays
  - Migration code simply JSON-encodes existing arrays
  - Round-trip YAML → JSON → YAML preserves structure perfectly
  - No lossy transformation needed

- **Schema Evolution**: Adding new condition type doesn't require migration
  - New column `condition_body` or `condition_custom` added (no existing data moved)
  - vs. separate table would need JOIN updates across app code

**Trade-off**: Cannot filter "SELECT * FROM rules WHERE conditions contain pattern X"
- **Acceptable**: This query never needed (pattern matching is in-application logic via PatternCompiler)

**Performance**: JSON arrays up to ~10KB per rule are very fast
- Current rules: ~10-50 patterns per rule = ~500 bytes to 2KB
- SQLite optimizes this internally
- Not a bottleneck for 500 rules (largest ruleset in testing)

---

### **3. Separate app_settings and account_settings Tables**

**Decision**: Two settings tables instead of single unified settings table with account_id nullable

**Why separate**?
- **Inheritance Pattern**: Account settings fall back to app_settings
  - If account has no setting, use app default
  - Easy to implement: check account first, then app table
  - Clean separation of concerns

- **Data Integrity**: Prevents confusion of app vs account scope
  - Schema enforces: app_settings can never have account_id
  - account_settings always has account_id
  - No ambiguous "is this global or per-account?"

- **Future: Multi-tenant Support**: If needed, could add "team_settings"
  - Would follow same pattern
  - Wouldn't affect app_settings or account_settings schema
  - Easy to extend without breaking existing code

**Alternative Considered**: Single table with nullable account_id
- **Rejected**: Harder to enforce "if account_id IS NULL, must be app-wide setting"
- **Rejected**: Inheritance logic more error-prone in application code

---

### **4. Separate background_scan_schedule Table**

**Decision**: Dedicated table for background scan scheduling instead of columns in account_settings

**Rationale**:
- **Conceptual Clarity**: Scheduling is complex data structure (frequency, next_run, enabled, folders)
  - Cramming into key-value store would require JSON in app_settings value
  - Separate table is clearer intent

- **Query Efficiency**: Getting "which accounts have background scans enabled?"
  - Simple: `SELECT account_id FROM background_scan_schedule WHERE enabled = 1`
  - vs. parsing JSON from settings table for each account

- **Index Optimization**: Can index `(enabled, next_scheduled)` for efficient scheduler
  - Scheduler queries: "Get all enabled schedules where next_scheduled <= now()"
  - Simple B-tree index efficient
  - JSON would require full table scan with string parsing

- **Atomicity**: Schedule updates atomic
  - Update enabled, frequency, next_run together in one transaction
  - JSON approach would require update-parse-modify-re-encode cycle

**Note**: Could be argued as "premature normalization", but background scheduling is complex enough to warrant its own table.

---

### **5. email_actions Table Includes Unmatched Emails**

**Decision**: Store ALL email evaluations in email_actions, including those where matched_rule_name IS NULL

**Why include unmatched?**
- **Unmatched Email Processing**: Users need to review emails that didn't match any rule
  - Original requirement: "keep list of unmatched items from last scan"
  - Separate table would duplicate this data
  - Single table with NULL matched_rule_name is simpler

- **Index Efficiency**: Single index on matched_rule_name supports both queries
  - Query 1: `SELECT * FROM email_actions WHERE scan_result_id = X AND matched_rule_name IS NOT NULL`
    - Gets all matched emails (for results summary)
  - Query 2: `SELECT * FROM email_actions WHERE scan_result_id = X AND matched_rule_name IS NULL`
    - Gets all unmatched emails (for unmatched email review)
  - Index: `idx_email_actions_no_rule ON email_actions(matched_rule_name) WHERE matched_rule_name IS NULL`
    - Optimizes the NULL query specifically (only includes NULL rows)

- **Consistency**: Single source of truth for email processing
  - Don't maintain separate "matched" and "unmatched" lists
  - All emails in one table, filtered by rule match

**Alternative Considered**: Separate unmatched_emails table
- **Rejected**: Duplicate data structure, harder to keep in sync

---

## Field Design Decisions

### **6. millisecondsSinceEpoch for Timestamps**

**Decision**: Store all timestamps as `INTEGER` using Dart's `DateTime.now().millisecondsSinceEpoch`

**Rationale**:
- **Consistency**: Dart ecosystem standard for cross-platform time handling
  - Single format across Android, Windows, iOS, macOS, Linux
  - No timezone conversion issues
  - Automatic DST handling

- **SQLite Efficiency**: INTEGER queries faster than TEXT date parsing
  - No string parsing overhead for comparisons
  - Index queries (e.g., "since last week") are pure integer math
  - TEXT date fields would require string parsing in WHERE clause

- **Sorting**: Natural ascending order = chronological order
  - TEXT dates would require parsing for correct sort
  - INTEGER dates sort correctly without conversion

- **Query Examples**:
  ```sql
  -- Get scans in last 7 days (pure math, no parsing)
  SELECT * FROM scan_results
  WHERE completed_at > ?
  ```
  vs.
  ```sql
  -- Would require string parsing and conversion
  SELECT * FROM scan_results
  WHERE datetime(completed_at) > datetime('now', '-7 days')
  ```

**Conversion**: At UI layer, convert to DateTime for display
  - `DateTime.fromMillisecondsSinceEpoch(dbValue).toString()`
  - Keeps database clean, presentation layer handles formatting

---

### **7. Text-Based Enums (scan_type, action_type, pattern_type)**

**Decision**: Store enum values as TEXT ('manual', 'background') instead of INTEGER codes

**Rationale**:
- **Debuggability**: Looking at raw database, values are human-readable
  - `scan_type = 'manual'` immediately clear
  - vs. `scan_type = 1` requires looking up enum mapping

- **Flexibility**: Can query/filter without knowing integer codes
  - `SELECT * FROM scan_results WHERE scan_type = 'background'` (obvious intent)
  - vs. `SELECT * FROM scan_results WHERE scan_type = 2` (requires documentation)

- **Migration-Friendly**: If enum values change, easier to update
  - `UPDATE scan_results SET scan_type = 'new_name' WHERE scan_type = 'old_name'`
  - INTEGER approach would require mapping table

- **SQLite Efficiency**: String comparison in WHERE clause is still very fast
  - Modern databases optimize TEXT fields
  - Storage difference negligible (2-3 bytes per row)
  - Not a performance bottleneck

**Predefined Values** (enforced at app layer):
- scan_type: 'manual', 'background'
- action_type: 'delete', 'moveToJunk', 'safeSender', 'none'
- pattern_type: 'email', 'domain', 'subdomain'

**Note**: These could be CHECK constraints, but we prefer app-level validation for better error messages

---

### **8. JSON for metadata Field**

**Decision**: Single `metadata` TEXT column containing JSON, instead of separate columns for each metadata item

**Rationale**:
- **Extensibility**: New metadata types don't require schema changes
  - Can add `"source": "manual", "created_by": "user"` without altering table
  - Future: `"ai_suggested": true` doesn't break schema

- **Query Access**: Metadata rarely queried
  - Applications ask: "Get rule X and all its metadata"
  - Never ask: "Show me all rules where created_by = 'user'"
  - JSON preserves relationship as single unit

- **Document Structure**: Mirrors original YAML metadata format
  - Rules in YAML had embedded metadata
  - JSON preserves this structure directly
  - Round-trip YAML → JSON → YAML is lossless

**Alternative Considered**: Multiple columns (created_by, source, etc.)
- **Rejected**: Would require schema changes for each new metadata type
- **Rejected**: Metadata is optional and rule-specific

---

## Index Design Decisions

### **9. Ten Targeted Indexes for Common Queries**

**Decision**: Create specific indexes for identified query patterns, not generic indexes

**Indexes**:
1. `idx_accounts_platform` - Support: "Get account by platform_id"
2. `idx_scan_results_account` - Support: "Get all scans for account"
3. `idx_scan_results_completed` - Support: "Get scans in date range"
4. `idx_email_actions_scan` - Support: "Get emails from specific scan"
5. `idx_email_actions_no_rule` - Support: "Get unmatched emails"
6. `idx_email_actions_folder` - Support: "Get emails from specific folder"
7. `idx_rules_enabled` - Support: "Get active rules"
8. `idx_rules_name` - Support: "Get rule by name"
9. `idx_safe_senders_pattern` - Support: "Verify pattern uniqueness"
10. `idx_account_settings_account` - Support: "Get settings for account"

**Rationale**:
- **Query Analysis**: Identified actual query patterns from application code
  - Not creating indexes for hypothetical "nice to have" queries
  - Only indexes that improve real application performance

- **Index Selectivity**: Each index solves specific problem
  - Composite indexes where queries filter on multiple columns
  - Single-column indexes where WHERE clause uses one column

- **Partial Indexes**: Used where applicable
  - `idx_email_actions_no_rule WHERE matched_rule_name IS NULL`
  - Smaller index (NULL rows only), faster scans

**Performance Impact**: Minimal storage overhead, significant query speedup
- 10 indexes add ~5-10% to database file size
- Query performance: 10-100x faster for filtered searches
- Write performance: Negligible impact (SQLite optimizes)

---

## Migration Design Decisions

### **10. One-Time YAML → Database Migration**

**Decision**: Migrate existing YAML rules once on first app launch, then read/write database

**Why One-Time?**
- **Atomicity**: Either migration completes or starts fresh (no partial state)
  - Simpler than ongoing sync
  - Easier to reason about (data in one place)

- **User Experience**: Happens automatically, transparently
  - User doesn't need to do anything
  - YAML files backed up in Archive/ directory for safety

- **Reliability**: If migration fails, user has original YAML files
  - Can restore from backup
  - Can try migration again on next app start

**Backup Strategy**:
- Before importing: Copy YAML files to timestamped directory
  - Format: `Archive/yaml_pre_migration_YYYYMMDDTHHMMSS/`
  - Preserves original state exactly
  - User can manually restore if needed

**Idempotency**: Safe to run migration multiple times
- Uses UNIQUE constraints on rules.name and safe_senders.pattern
- Duplicate imports rejected at database level (not application level)
- Prevents accidental duplicate rules if migration re-triggered

**Detection**: Check if database has rules
  - If rules exist → migration already done
  - If rules empty → run migration
  - Simple state machine: `isMigrationComplete()` method

---

### **11. Dual-Write Pattern (Database + YAML Export)**

**Decision**: After rule mutations, automatically export database back to YAML

**Why Dual-Write?**
- **Version Control**: YAML files can be committed to git
  - Rules are version-controllable
  - Can see history of rule changes
  - Can roll back changes if needed

- **Backup**: YAML serves as secondary backup
  - If database corrupts, YAML has latest state
  - Users can manually import from YAML if needed

- **Developer Transparency**: Developers can read/edit YAML directly
  - Easier debugging (grep for rule names in YAML)
  - Can manually test rules by editing YAML
  - Lower barrier to contribution

- **Future Multi-Device Sync**: If implemented, YAML is sync mechanism
  - Device 1 exports rules to YAML
  - Device 2 imports from YAML
  - Avoids proprietary sync protocol

**Export Format**: Identical to input YAML
- Lowercase conversion
- Trimmed whitespace
- De-duplication
- Alphabetical sorting
- Single quotes (escape consistency)

**Timing**: Export triggered after every rule mutation
- User adds rule → database write + YAML export
- Slightly slower, but atomic from user perspective
- Could be optimized later (batch exports) if needed

---

## Design Trade-Offs Summary

| Decision | Chosen | Alternative | Trade-Off |
|----------|--------|-------------|-----------|
| Number of tables | 8 separate | Fewer consolidated | Storage vs. Query efficiency |
| Condition storage | JSON arrays | Separate table | Query flexibility vs. Atomicity |
| Settings tables | Separate tables | Single table | Complexity vs. Clarity |
| Timestamps | Milliseconds INTEGER | TEXT dates | Sorting performance |
| Enums | TEXT strings | INTEGER codes | Storage size vs. Debuggability |
| Metadata | JSON | Multiple columns | Flexibility vs. Schema stability |
| Indexes | 10 targeted | No indexes or all columns | Query speed vs. Write speed |
| Migration | One-time → database | Ongoing sync | Simplicity vs. Flexibility |

---

## Future Enhancement Opportunities

### **Potential Changes (Not Implemented in Sprint 1)**

1. **Partial Unique Index**: Rules with soft-delete flag
   - Could support rule versions/history
   - Would require `enabled` column in index
   - Current: UNIQUE(name) prevents any duplicates

2. **Audit Log Table**: Track rule changes over time
   - Separate audit_log table with timestamped mutations
   - Could support "show changes since date"
   - Not needed yet, but schema supports addition

3. **Rule Groups**: Organize rules into categories
   - New table: rule_groups with parent_id
   - Would add rule_group_id to rules table
   - Current schema supports this addition without breaking changes

4. **Pattern Validation Cache**: Pre-compile regex patterns
   - New table: pattern_cache with compiled regex
   - Would optimize repeated pattern matching
   - Could be added transparently to existing schema

5. **Statistics Snapshot**: Pre-calculate stats for reporting
   - New table: scan_statistics with daily summaries
   - Would speed up "spam trends" reports
   - Current queries still work with manual aggregation

---

## Maintenance Notes for Developers

### **When Adding New Features**

1. **New Settings**: Add to app_settings or account_settings (don't create new settings table)
2. **New Metadata**: Add to existing metadata JSON field (don't add columns)
3. **New Queries**: Consider if index needed; add targeted index if filtering large datasets
4. **New Entity Types**: Follow same pattern (separate table + optional indexes)
5. **Timestamps**: Always use millisecondsSinceEpoch INTEGER, never TEXT dates

### **Code Review Checklist**

- [ ] New tables have UNIQUE constraints where needed
- [ ] Foreign keys use CASCADE DELETE for integrity
- [ ] All queries have supporting indexes (no full table scans on large tables)
- [ ] Timestamps stored as millisecondsSinceEpoch INTEGER
- [ ] Enums use TEXT values (not INTEGER codes)
- [ ] Metadata stored in JSON, not spread across columns
- [ ] Migration code handles partial failures gracefully
- [ ] YAML export happens after all mutations

---

## References

- **Sprint 1 Implementation**: `lib/core/storage/database_helper.dart`
- **Migration System**: `lib/core/storage/migration_manager.dart`
- **Testing**: `test/unit/storage/database_helper_test.dart`
- **Related Plan**: `SPRINT_2_PLAN.md` (Rule management migration)

---

**Document Version**: 1.0
**Last Updated**: January 24, 2026
**Applies To**: Phase 3.5 SQLite Database (Sprint 1 and beyond)
**Audience**: Developers maintaining or extending database features
