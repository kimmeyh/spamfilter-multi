# ADR-0021: YAML-to-Database One-Time Migration

## Status

Accepted

## Date

~2026-01-24 (Sprint 1, Phase 3.5)

## Context

The spam filter originally stored all rules and safe senders exclusively in YAML files (`rules.yaml` and `rules_safe_senders.yaml`). The migration to SQLite database storage (ADR-0004, ADR-0010) required importing existing YAML data into the database on first launch.

This migration must satisfy several constraints:

- **Atomic**: Either all rules and safe senders are imported, or none are (no partial state)
- **Idempotent**: Running the migration multiple times produces the same result (no duplicate rules)
- **Non-destructive**: Original YAML files are preserved as backups before import
- **Non-blocking**: Migration failure should not prevent the app from launching (start with empty database)
- **One-time**: After successful migration, all subsequent reads use the database; YAML files become write-only exports (ADR-0004)

## Decision

Implement a `MigrationManager` that performs a transaction-wrapped, idempotent, one-time import of YAML data into SQLite.

### Migration Detection

`isMigrationComplete()` determines whether migration is needed:
1. Check if the database contains rules
2. If rules exist, migration is complete
3. If rules do not exist AND `rules.yaml` exists, migration is needed
4. If rules do not exist AND `rules.yaml` does not exist, migration is not needed (fresh install)
5. Special case: if `rules_safe_senders.yaml` exists but safe senders table is empty, migration is incomplete

### Migration Flow

```
App Startup (RuleSetProvider.initialize())
  |
  +--> isMigrationComplete()?
  |     |
  |     +--> Yes: Skip migration, load from database
  |     |
  |     +--> No: Run migration
  |           |
  |           +--> Create timestamped YAML backups
  |           |     Archive/yaml_pre_migration_YYYYMMDDHHMMSS/
  |           |
  |           +--> BEGIN TRANSACTION
  |           |     |
  |           |     +--> Import rules from rules.yaml
  |           |     |     (skip duplicates by name)
  |           |     |
  |           |     +--> Import safe senders from rules_safe_senders.yaml
  |           |     |     (skip duplicates by pattern)
  |           |     |
  |           |     +--> COMMIT (or ROLLBACK on any error)
  |           |
  |           +--> Load from database
```

### Idempotency

Before inserting each rule, the migration checks if a rule with the same name already exists in the database. Duplicate rules are tracked in the migration results but skipped without error. The same approach applies to safe senders (checked by pattern value).

### Backup Strategy

Before import, the original YAML files are copied to a timestamped directory:
```
Archive/yaml_pre_migration_20260124T120000/
  rules.yaml
  rules_safe_senders.yaml
```

This ensures the original data is recoverable even if the migration produces unexpected results.

### Migration Results

`MigrationManager` returns a detailed results object:
- Rules imported count
- Rules skipped (duplicates) count
- Safe senders imported count
- Safe senders skipped count
- Whether the transaction was rolled back
- Error messages (if any)

## Alternatives Considered

### Continuous Bidirectional Sync
- **Description**: Keep YAML and database in continuous sync - changes to either propagate to the other automatically
- **Pros**: Users can edit YAML directly and see changes in the app; maximum flexibility; no migration step needed
- **Cons**: Conflict resolution is complex (what if both are modified?); file watching adds race condition risks; harder to determine source of truth; changes from YAML bypass validation; significant engineering effort
- **Why Rejected**: Bidirectional sync introduces ambiguity about the source of truth and complex conflict resolution. The unidirectional approach (database is primary, YAML is exported) is simpler and avoids these problems entirely. See ADR-0004

### Checkpoint-Based Migration with State Machine
- **Description**: Implement a full state machine (IDLE -> PENDING -> IN_PROGRESS -> COMPLETE) with checkpoint logging, allowing migration to resume from the last successful checkpoint after failure
- **Pros**: Handles large rule sets gracefully; can resume after crash; provides progress tracking
- **Cons**: Significantly more complex; checkpoint storage adds database overhead; most rule sets are small enough to import in a single transaction; recovery scenarios are rare
- **Why Rejected**: The current rule sets are small (tens to hundreds of rules). A single-transaction approach is sufficient and much simpler. The `MIGRATION_STATE_MACHINE.md` document preserves the checkpoint design for future implementation if production data reveals the need

### Manual Import via UI
- **Description**: Provide a UI screen where users explicitly import YAML files into the database, rather than automatic migration on first launch
- **Pros**: User has full control; can select which files to import; can preview before committing
- **Cons**: Adds friction to first launch; users may not understand the need for import; delays the migration decision; app is non-functional until import is completed
- **Why Rejected**: Automatic migration provides the best first-run experience. Users upgrading from YAML-only to database storage should not need to take manual action. The migration is transparent and preserves all existing rules

## Consequences

### Positive
- **Transparent upgrade**: Users upgrading from YAML-only storage to database storage experience no disruption; their rules appear automatically
- **Atomic safety**: The transaction wrapper ensures the database is never left in a partial migration state
- **Idempotent resilience**: Accidental re-runs (e.g., if migration detection has a bug) do not create duplicate rules
- **Backup preservation**: Original YAML files are backed up with timestamps, providing a recovery path

### Negative
- **Simple detection logic**: Migration detection relies on "does the database have rules?" which could produce false positives (empty database after a deliberate rule deletion) or false negatives (database has rules from a different source)
- **No progress reporting**: The migration runs inside a single transaction with no progress updates. For very large rule sets, this could appear to hang (not currently a problem with actual data sizes)
- **One-way only**: There is no reverse migration (database to YAML import). If the database is corrupted, users must rely on YAML backups or the ongoing YAML exports (ADR-0004)

### Neutral
- **State machine documentation preserved**: The `MIGRATION_STATE_MACHINE.md` document describes a more sophisticated checkpoint-based migration that could be implemented if production data reveals the need. The current simple approach is adequate for known data sizes

## References

- `mobile-app/lib/core/storage/migration_manager.dart` - Migration implementation (lines 51-428): detection (384-416), transaction execution (115-145), idempotency checks (185-205, 265-276), YAML backup (147-177)
- `mobile-app/lib/core/providers/rule_set_provider.dart` - Migration trigger during initialization
- `docs/MIGRATION_STATE_MACHINE.md` - Design document for current and future migration approaches (lines 1-356)
- ADR-0004 (Dual-Write Storage) - YAML becomes write-only after migration
- ADR-0010 (Database Schema) - Target schema for migrated data
