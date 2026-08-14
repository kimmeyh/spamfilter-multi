# Sprint 1: Database Foundation - Phase 3.5

> **NOTE (Sprint 57 doc-audit, 2026-08-14)**: This plan document was not found in the repository during a repo-wide sprint-documentation audit. It has been reconstructed retroactively from PR #56 (title, body, and commit history), GitHub Issues #51-#55, and the existing `SPRINT_1_COMPLETE.md` / `SPRINT_1_RETROSPECTIVE.md` files, which were already present. Where the original plan's specific estimates could be recovered from these sources they are shown; anything not recoverable is marked "not recorded" rather than invented.

**Branch**: `feature/20260124_Sprint_1`
**Dates**: January 24, 2026 (single-day sprint; branch created and merged same day)
**Status**: Complete (merged via PR #56)
**Goal**: Establish the SQLite database foundation for Phase 3.5, migrating rule and safe-sender storage from YAML-only to a database-backed model, and fix a results-display bug discovered during review.

---

## Context

Phase 3.5 of the project (pre-dating the numbered-sprint model formalized later) called for moving the app's persistence layer from YAML files to a SQLite database, to support scan-result history, richer settings, and background-scan scheduling that YAML could not represent well. Sprint 1 is the first sprint executed under the sprint-based development model and establishes the database schema, a one-time YAML-to-database migration path, and the test coverage for both.

A pre-existing bug (Issue #51 - Results screen not displaying matched rule names) was also folded into this sprint as Task D after being discovered during review.

---

## Scope

### Task A: Create SQLite Database Schema and DatabaseHelper (Issue #53)
**Assigned Model**: Haiku
**Description**: Create a `DatabaseHelper` singleton defining the SQLite schema (8 tables: `scan_results`, `email_actions`, `rules`, `safe_senders`, `app_settings`, `account_settings`, `background_scan_schedule`, `accounts`) with 10 supporting indexes, plus CRUD helper methods for all tables.

**Acceptance Criteria**:
- [ ] All 8 tables created with correct schema
- [ ] All indexes created for performance
- [ ] Foreign keys configured with ON DELETE CASCADE
- [ ] CRUD helper methods for all tables
- [ ] Thread-safe singleton pattern
- [ ] Database initialization creates tables on first launch
- [ ] `flutter analyze` reports zero issues

**Files**: `lib/core/storage/database_helper.dart` (new), `pubspec.yaml` (add `sqflite: ^2.3.0`), `lib/adapters/storage/app_paths.dart` (add `databaseFilePath` getter)

---

### Task B: Implement YAML to Database Migration Manager (Issue #54)
**Assigned Model**: Sonnet
**Description**: Create a `MigrationManager` to perform a one-time migration from the existing `rules.yaml` / `rules_safe_senders.yaml` files into the new database, with timestamped backups and idempotent re-run safety.

**Acceptance Criteria**:
- [ ] YAML to database migration working
- [ ] All rules imported with migration date
- [ ] YAML files backed up to `Archive/` before migration
- [ ] Malformed YAML handled gracefully (skip and log, do not abort)
- [ ] Import completeness verified via statistics
- [ ] Idempotent: safe to run multiple times without duplicating rows
- [ ] Unit tests for each scenario

**Files**: `lib/core/storage/migration_manager.dart` (new)

**Dependencies**: Task A (DatabaseHelper)

---

### Task C: Test Database Migration with Real YAML Files (Issue #55)
**Assigned Model**: Haiku
**Description**: Build comprehensive unit and integration test coverage for both the database schema/CRUD layer and the migration manager.

**Acceptance Criteria**:
- [ ] 30+ unit tests for database operations (schema, CRUD, indexes, cascade delete, complex queries)
- [ ] Performance tests (bulk insert, indexed query timing)
- [ ] Integration test structure for migration scenarios (missing YAML, malformed YAML, idempotency, pattern-type detection)
- [ ] All new and existing tests passing

**Files**: `test/unit/storage/database_helper_test.dart` (new), `test/integration/migration_test.dart` (new)

**Dependencies**: Task A, Task B

---

### Task D: Fix Results Screen Rule Display (Issue #52 / Issue #51)
**Assigned Model**: Haiku
**Description**: Fix a bug where the Results screen displayed an empty string instead of the matched rule name (or "No rule" when unmatched). Root cause: Dart's `??` null-coalescing operator only guards against `null`, not empty strings, so an empty `matchedRule` string bypassed the fallback text.

**Acceptance Criteria**:
- [ ] Results screen displays the actual matched rule name when a rule matched
- [ ] Results screen displays "No rule" when no rule matched (not a blank string)
- [ ] Fix verified on both Android and Windows Desktop
- [ ] Regression test added (`results_display_test.dart`)

**Files**: results display screen (`_buildResultTile()`), demo-scan result generation (`scan_progress_screen.dart`)

**Note**: This task's originating issue (#52) had been closed before implementation was complete, which was flagged in the Sprint 1 retrospective as a process gap; it led directly to the "verify all sprint cards are OPEN before execution" step added to `SPRINT_EXECUTION_WORKFLOW.md`.

---

## Estimated Effort

Per PR #56 and `SPRINT_1_COMPLETE.md`: 9-13 hours combined (Task A: 3-4 hrs, Task B: 4-6 hrs, Task C: 2-3 hrs). Task D was discovered and added mid-sprint and is not reflected in the original estimate. Actual effort figures differ between sources (`SPRINT_1_COMPLETE.md` records "~11-13 hours"; `SPRINT_1_RETROSPECTIVE.md` records user-reported actual effort of "~4 hours") -- see `SPRINT_1_RETROSPECTIVE.md` for the discrepancy and its analysis.

---

## Out of Scope (deferred to Sprint 2+)

- Migrating `RuleSetProvider` to read/write the database (Sprint 2)
- YAML auto-export / dual-write pattern (Sprint 2)
- Safe-sender exception patterns (Sprint 3)
- Scan-result persistence via `EmailScanner` (Sprint 4)

---

## Related Documents

- PR #56: `Sprint 1: Database Foundation - Phase 3.5` (merged 2026-01-24, commit `ffd0726`)
- `docs/sprints/SPRINT_1_COMPLETE.md` - detailed completion report
- `docs/sprints/SPRINT_1_RETROSPECTIVE.md` - retrospective and lessons learned
- Issues #51, #52, #53, #54, #55 (all closed)
