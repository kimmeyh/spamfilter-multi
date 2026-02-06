# Migration State Machine - Production Safety

This document describes the migration state tracking system that prevents partial database initialization and provides recovery mechanisms for system crashes.

---

## Overview

The YAML-to-SQLite migration is critical initialization code. A crash mid-migration could leave the database in an inconsistent state (some rules imported, others not). This state machine ensures safe, deterministic migration behavior.

---

## Current Implementation (Sprint 1)

### **Simple State Detection**

The current `MigrationManager.isMigrationComplete()` method uses a simple check:

```dart
Future<bool> isMigrationComplete() async {
  final rules = await databaseHelper.queryRules();
  return rules.isNotEmpty;
}
```

**Logic**: If database has rules, assume migration completed
- **Works for**: Normal execution, fully completed migrations
- **Problem**: If crash occurs mid-migration:
  - Some rules imported successfully
  - App restarts
  - `queryRules()` returns >0 (returns true)
  - Migration marked complete, but state unknown (some rules missing)

### **Current Safety Mechanisms**

1. **Idempotency via UNIQUE Constraints**
   - `UNIQUE(name)` on rules table
   - Duplicate rule imports rejected at database level
   - Running migration twice won't create duplicates (second run skips duplicates)

2. **Backup Before Import**
   - Original YAML files copied to Archive/ before importing
   - If corruption detected, manual recovery possible
   - User can restore from backup

3. **Graceful Error Handling**
   - Malformed rules logged, not thrown
   - Migration continues on errors
   - Final status report includes skipped rules

**Limitation**: Cannot distinguish between:
- Migration never started
- Migration completed successfully
- Migration crashed mid-way and needs recovery

---

## Proposed State Machine (For Future Implementation)

### **Why Add State Machine?**

While current implementation is functional, a state machine provides:

1. **Explicit State Tracking**: Clear visibility into migration status
   - Can log: "Migration at PENDING state for 2 hours (stuck?)"
   - Can implement timeout recovery: "If PENDING > 1 hour, restart migration"

2. **Crash Recovery**: Detect and recover from mid-migration crashes
   - PENDING → IN_PROGRESS: started but not completed
   - IN_PROGRESS for >X seconds: likely crashed, restart
   - Atomicity: either complete or restart (not partial)

3. **Periodic Checkpointing**: Save progress every N rules
   - If crash at rule 1000 of 5000, can resume from rule 1001
   - vs. current: either start over or assume complete

4. **Monitoring**: Track migration health over time
   - "Migration takes longer than expected" alert
   - "Migration succeeded but took 5x longer than usual" warning

### **Proposed State Machine Design**

```
┌─────────────┐
│   IDLE      │ (initial state)
└──────┬──────┘
       │ migration_needed?
       ▼
┌─────────────┐
│  PENDING    │ (about to start)
└──────┬──────┘
       │ start_migration()
       ▼
┌─────────────┐
│IN_PROGRESS  │ (currently running)
└──┬────────┬─┘
   │        │
   │        └─→ [timer: every 10s] log checkpoint
   │
   │ (finish 100% OR crash)
   │
   ├─→ ✅ COMPLETED (success)
   │
   └─→ ❌ FAILED (error during migration)

(On app restart:)
┌─────────────┐
│  Startup    │ Check migration state table
└──────┬──────┘
       │
       ├─→ State: COMPLETED → Skip migration, proceed
       │
       ├─→ State: PENDING → Likely haven't started, start migration
       │
       └─→ State: IN_PROGRESS → Crashed mid-way
           │
           ├─→ If crashed < 10 sec ago: Restart migration
           │   (assume minimal data written)
           │
           └─→ If crashed > 10 sec ago: Clean database, restart
               (assume partial data, need clean slate)
```

### **Implementation Details (Not for Sprint 1, Design Only)**

**New Table: migration_status**
```sql
CREATE TABLE migration_status (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  state TEXT NOT NULL,
  started_at INTEGER,
  updated_at INTEGER,
  rules_imported INTEGER DEFAULT 0,
  safe_senders_imported INTEGER DEFAULT 0,
  error_message TEXT
);
```

**State Values**:
- `PENDING` - About to start (created at startup if needed)
- `IN_PROGRESS` - Currently running (updated every ~10 rules)
- `COMPLETED` - Successfully finished
- `FAILED` - Error occurred during migration

**Checkpoint Strategy**:
```dart
// During migration, every 100 rules:
await updateMigrationStatus(
  state: 'IN_PROGRESS',
  rulesImported: 450,
  safeSendersImported: 75,
  updatedAt: DateTime.now()
);
```

**Crash Recovery**:
```dart
// On app startup:
final status = await getMigrationStatus();

if (status.state == 'IN_PROGRESS') {
  final elapsedTime = DateTime.now().difference(status.updatedAt);

  if (elapsedTime.inSeconds < 60) {
    // Recent activity, likely still processing
    // Wait a bit, check again
    await Future.delayed(Duration(seconds: 5));
    return getMigrationStatus();
  } else {
    // Crashed, nothing running
    // Either resume from checkpoint or restart clean
    if (status.rulesImported > 0) {
      // Had made progress, restart fresh
      // (could be enhanced to resume from checkpoint)
      await resetDatabaseAndRestart();
    } else {
      // Minimal progress, just continue
      await continueMigration();
    }
  }
}
```

---

## Recommended Approach for Production

### **Monitoring Every Hour (As You Suggested)**

Rather than complex state machine, implement **lightweight periodic checks**:

```dart
// During migration, log checkpoint every 100 rules or 10 seconds:
void _logMigrationCheckpoint(int rulesProcessed, int safeSendersProcessed) {
  _logger.i(
    'Migration checkpoint: '
    '$rulesProcessed rules, $safeSendersProcessed safe senders imported'
  );
}

// On app startup, check migration health:
void _checkMigrationHealth() {
  final lastLogTime = _readLastMigrationLogTime();
  final timeSinceLastLog = DateTime.now().difference(lastLogTime);

  // If last log > 1 hour ago and migration incomplete = problem
  if (timeSinceLastLog > Duration(hours: 1) && !_isMigrationComplete()) {
    _logger.w('Migration appears stuck (no progress in 1 hour)');
    // Could trigger alert, restart, or manual intervention
  }
}
```

### **Benefits of Checkpoint Approach**

1. **Minimal Overhead**: Just logging, no database writes for state
2. **Simple**: Easy to understand and debug
3. **Effective**: Hourly checks catch problems
4. **Recoverable**: Log file shows exactly where migration was when it failed

### **Implementation Plan (For Future Sprint if Needed)**

1. **Sprint 2 or 3**: Add checkpoint logging during migration
   - Every 100 rules processed: log checkpoint
   - Every 10 seconds during migration: log progress
   - Format: timestamp + count of processed items

2. **Sprint 4 or Later**: Add startup health checks
   - Read last migration log timestamp
   - Compare to current time
   - Alert if no recent progress

3. **Not Needed Yet**: Full state machine overhead
   - Current UNIQUE constraints + idempotency sufficient
   - Can implement if production issues emerge

---

## Current Sprint 1 Safety Guarantees

### **What We Have**

1. ✅ **Atomicity via UNIQUE Constraints**
   - Rules with same name cannot be duplicated
   - Safe senders with same pattern cannot be duplicated
   - Multiple migrations will not create data corruption

2. ✅ **Backup Before Import**
   - Original YAML files preserved in Archive/ directory
   - Manual recovery always possible

3. ✅ **Graceful Error Handling**
   - Individual rule failures don't stop migration
   - Partial imports don't crash the app
   - Final status report shows what succeeded/failed

4. ✅ **Clear Status Reporting**
   - `MigrationResults` includes counts, errors, skipped items
   - `getMigrationStatus()` provides human-readable summary

### **What We Don't Have (Yet)**

1. ❌ **Explicit State Tracking**
   - Can't distinguish between "not started" and "crashed mid-way"
   - Current approach: assume "if has rules, completed"

2. ❌ **Crash Detection**
   - No timestamp or "last update" tracking
   - Can't detect if migration got stuck

3. ❌ **Checkpoint Recovery**
   - Can't resume from checkpoint if crashed at rule 3000 of 5000
   - Current approach: re-import everything (UNIQUE constraints prevent duplicates)

4. ❌ **Timeout Alert**
   - No monitoring if migration takes longer than expected
   - No alerting mechanism

---

## Recommendation for Sprint 1

**Keep current simple approach** because:

1. **Sufficient for MVP**: UNIQUE constraints guarantee data integrity
2. **Low Risk**: Idempotent design means repeated migrations won't corrupt
3. **Easy to Debug**: Clear error messages, backup files available
4. **Can Add Later**: State machine can be added in Sprint 3-4 if production issues emerge

**Monitor Early**: If in production and migration causes issues, then implement full state machine.

---

## Recommendation for Sprint 2+

**Add Simple Checkpoint Logging**:

```dart
// In MigrationManager._importRules(), around line 148:
for (final rule in ruleSet.rules) {
  try {
    // existing code...
    results.rulesImported++;

    // Every 100 rules, log checkpoint
    if (results.rulesImported % 100 == 0) {
      _logger.i(
        'Migration checkpoint: '
        '${results.rulesImported} rules imported, '
        '${results.safeSendersImported} safe senders imported'
      );
    }
  } catch (e) {
    // existing error handling...
  }
}
```

**Cost**: 5 lines of code
**Benefit**: Can see migration progress in logs if issues reported

---

## When to Implement Full State Machine

**Triggers for implementation**:
1. Production reports: "Migration took 2+ hours"
2. Production reports: "Migration seems stuck"
3. Production reports: "Database corrupted mid-migration"
4. Performance data shows > 5% of users experience migration failure
5. Need checkpoint recovery for datasets > 10,000 rules

**Estimated Effort**: 4-6 hours (Sonnet task)
- Add migration_status table
- Implement checkpoint writes during migration
- Implement startup health check
- Add recovery logic
- Test crash scenarios

---

## References

- **Current Implementation**: `lib/core/storage/migration_manager.dart`
- **Database Schema**: `lib/core/storage/database_helper.dart`
- **Related Architecture**: `DATABASE_ARCHITECTURE_DECISIONS.md`
- **YAML Backup**: `Archive/yaml_pre_migration_YYYYMMDD*/`

---

**Document Version**: 1.0
**Last Updated**: January 24, 2026
**Status**: Design for future implementation
**Applies To**: Phase 3.5 migration system (Sprint 1+)
**Audience**: Developers maintaining migration code, DevOps monitoring production
