# ADR-0004: Dual-Write Storage (SQLite + YAML Export)

## Status

Accepted

## Date

~2026-01 (Sprint 7-8, database architecture implementation)

## Context

The spam filter manages two primary data sets:

1. **Spam filtering rules**: Conditions, actions, exceptions, execution order
2. **Safe sender whitelist**: Trusted sender patterns that bypass all rules

These data sets must satisfy competing requirements:

- **Runtime performance**: Rules must be loaded and queried efficiently during email scans (potentially thousands of evaluations per scan)
- **Human readability**: Users and developers need to inspect, edit, and review rules in a human-readable format
- **Version control**: Rule changes should be trackable in git for audit trails and rollback capability
- **Portability**: Rules must be shareable across devices and platforms without database compatibility concerns
- **Backup safety**: Rule data must survive database corruption or application failures
- **Migration path**: The project originally stored rules exclusively in YAML files; the transition to database storage needed to preserve existing rules

No single storage format satisfies all of these requirements. SQLite excels at runtime queries but is binary and not human-readable. YAML excels at human readability and version control but is slow for large-scale pattern matching.

## Decision

Implement a dual-write pattern where:

1. **SQLite database is the primary (authoritative) storage** for all rule data at runtime
2. **YAML files are exported after every database write** for version control, portability, and backup
3. **One-time migration**: On first launch, existing YAML rules are imported into the database. All subsequent reads use the database only
4. **YAML export is non-blocking**: Export failures are logged but do not propagate to the caller or block the user operation

**Write flow** (in `RuleSetProvider`):
```
User action (add/update/delete rule)
  -> Write to SQLite database
  -> Update in-memory cache
  -> Export to YAML file (non-blocking)
  -> Notify UI subscribers
```

**Read flow**:
```
App startup
  -> Check if migration needed (first run)
  -> If first run: Import YAML -> Database (one-time)
  -> All reads: Load from SQLite database
```

**YAML export invariants** (enforced on every export):
- Lowercase conversion for all patterns
- Whitespace trimming
- De-duplication of identical patterns
- Alphabetical sorting
- Single-quote formatting
- Timestamped backup of previous YAML before overwrite

## Alternatives Considered

### Database-Only Storage
- **Description**: Store all rule data exclusively in SQLite; no YAML files
- **Pros**: Single source of truth; no synchronization concerns; simpler write path; faster writes (no export step)
- **Cons**: Binary database file cannot be version-controlled meaningfully in git; cannot be inspected or edited by humans without tooling; no portable format for sharing rules across devices; if database corrupts, all rules are lost
- **Why Rejected**: Version control and human readability are essential for a rule-based system where users need to understand, share, and audit their filtering rules. Losing these capabilities would significantly reduce the system's transparency

### YAML-Only Storage
- **Description**: Continue using YAML files as the sole storage mechanism (original approach)
- **Pros**: Human-readable; version-controllable; portable; simple to implement
- **Cons**: File I/O for every rule lookup during scanning is slow; no efficient query capabilities; concurrent access is problematic; large rule sets degrade performance; no relational integrity constraints
- **Why Rejected**: As the rule set grew and scan performance became important, YAML file I/O became a bottleneck. SQLite provides indexed queries, ACID transactions, and efficient concurrent access that YAML file operations cannot match

### Continuous Bidirectional Sync (Database <-> YAML)
- **Description**: Keep database and YAML in sync bidirectionally - changes to either source propagate to the other
- **Pros**: Users can edit YAML directly and have changes reflected in the database; maximum flexibility
- **Cons**: Conflict resolution is complex (what happens when both database and YAML are modified?); file watching adds complexity and potential race conditions; harder to reason about which source is authoritative; changes from YAML edits bypass validation logic
- **Why Rejected**: Bidirectional sync introduces complexity and ambiguity about the source of truth. The unidirectional approach (database -> YAML) is simpler and avoids conflict resolution entirely. Users who want to edit rules directly use the UI, which writes to the database

### Cloud Sync Service
- **Description**: Use a cloud service (Firebase, Supabase, etc.) for rule storage and cross-device synchronization
- **Pros**: Rules available on all devices automatically; real-time sync; backup to cloud
- **Cons**: Requires internet connectivity; adds external service dependency; privacy concerns (rules may contain sensitive patterns); cost; additional infrastructure to maintain; offline-first requirement conflicts with cloud-first approach
- **Why Rejected**: The application must work fully offline. Adding a cloud dependency contradicts the self-contained design philosophy. Cloud sync is a potential future enhancement (noted in architecture roadmap) but should not be the primary storage mechanism

## Consequences

### Positive
- **Version-controllable rules**: YAML files can be committed to git, providing a full history of rule changes with diffs, blame, and rollback capability
- **Human-readable backup**: If the database becomes corrupted, the most recent YAML export preserves the rule state in a format that can be manually inspected and re-imported
- **Portability**: YAML files can be copied between machines, shared with other users, or used across different platforms without database compatibility concerns
- **Runtime performance**: SQLite provides indexed queries and efficient concurrent access during email scans, avoiding the I/O overhead of repeatedly parsing YAML files
- **Timestamped backups**: Every YAML export creates a timestamped backup of the previous version, providing an additional safety net
- **Non-blocking exports**: YAML export failures do not impact the user experience or block rule modifications

### Negative
- **Dual writes**: Every rule change writes to two locations (database + YAML file), adding a small performance cost and a second failure point
- **Potential YAML staleness**: If a YAML export fails silently, the YAML file may not reflect the current database state. This is mitigated by logging failures, but the YAML file is not guaranteed to be perfectly in sync
- **Storage duplication**: Rules are stored in two formats (SQLite + YAML), using more disk space. In practice this is negligible (rule sets are small)
- **Migration complexity**: The one-time YAML-to-database migration adds startup logic and must handle edge cases (malformed YAML, duplicate rules, missing files)

### Neutral
- **YAML is write-only after migration**: After the initial import, YAML files are only written to (exported), never read from. The database is the sole read source. This means direct edits to YAML files have no effect on the running application
- **Export invariants normalize data**: The YAML export process normalizes patterns (lowercase, trim, deduplicate, sort). This means the exported YAML may differ from the original input YAML, which is intentional but can surprise users comparing files

## References

- `mobile-app/lib/core/storage/database_helper.dart` - SQLite database schema and operations (lines 1-726)
- `mobile-app/lib/core/storage/rule_database_store.dart` - Database CRUD for rules
- `mobile-app/lib/core/services/yaml_export_service.dart` - YAML export pipeline (lines 1-89)
- `mobile-app/lib/core/services/yaml_service.dart` - YAML parsing and normalization (lines 128-135: invariants)
- `mobile-app/lib/core/providers/rule_set_provider.dart` - Dual-write orchestration (line 67: "Keep for YAML export (dual-write pattern)", lines 188-213: write sequence)
- `rules.yaml` - Exported spam filtering rules
- `rules_safe_senders.yaml` - Exported safe sender whitelist
- `docs/ARCHITECTURE.md` - Architecture overview
- `docs/RULE_FORMAT.md` - YAML rule format specification
