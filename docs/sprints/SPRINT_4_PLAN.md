# Sprint 4 Plan: Processing Scan Results (Backend & UI)

**Sprint**: Sprint 4
**Date**: January 25, 2026
**Focus**: Persistent storage for scan results and unmatched emails, availability checking, and a UI for reviewing/processing unmatched emails
**Duration**: Estimated 14-16 hours
**Status**: [PLANNED] - Ready for kickoff

> **Note (Sprint 57 doc audit, 2026-08-14)**: This plan document was reconstructed
> retroactively from GitHub Issues #73-#76 (the original Sprint 4 task cards) and
> PR #77 (the sprint's merge PR). It was not present in the repository at sprint
> time; SPRINT_4_RETROSPECTIVE.md and SPRINT_4_SUMMARY.md already existed and are
> unchanged. Acceptance criteria, file estimates, hours, and model assignments
> below are copied verbatim from the source issues, not invented.

---

## Executive Summary

Sprint 4 completes the processing workflow for scan results. Users will be able to review emails that did not match any filtering rule, check whether those emails are still available in the provider's folders (they may have been deleted or moved externally), and quickly add safe senders or create auto-delete rules from the review screen. This sprint implements the persistent storage layer for scan metadata and unmatched emails, an availability-checking service for Gmail and IMAP, and the Process Results UI.

This sprint builds on Sprint 3's safe-sender and database-first foundation.

---

## Sprint Objectives

### Primary Goals
1. Implement a database storage layer for scan results and unmatched emails (`ScanResultStore`, `UnmatchedEmailStore`)
2. Implement an `EmailAvailabilityChecker` service to detect deleted/moved emails for Gmail and IMAP
3. Integrate persistence into the existing scan workflow (manual vs. background scans)
4. Build the Process Results UI for reviewing, filtering, and acting on unmatched emails

### Secondary Goals
- Maintain zero regressions in existing tests
- Provider-agnostic identifier abstraction (Gmail message IDs vs. IMAP UIDs)
- Cascade delete relationships between scans and their unmatched emails

---

## Task Breakdown

### **Task A: Scan Result Storage Layer**
**Model Assignment**: Sonnet (primary, architecture decisions); Haiku (support, if escalation needed)
**Complexity**: HIGH - architecture decisions, schema design, database integration
**Estimated Time**: 4-5 hours
**Issue**: #73

**Description**:
Implement the database storage layer for scan results and unmatched emails. This is the foundation for all other Sprint 4 tasks. Creates two new database tables:
1. `scan_results` - scan metadata (manual/background, counts, status)
2. `unmatched_emails` - unmatched emails linked to a scan, with provider identifiers

**Acceptance Criteria**:
- [ ] Can create scan result with metadata
- [ ] Can store unmatched emails linked to scan
- [ ] Batch insert performs well (100+ emails)
- [ ] Cascade delete removes unmatched emails when scan deleted
- [ ] Provider identifier abstraction works for Gmail and IMAP
- [ ] 65+ tests passing (100% coverage)
- [ ] All existing tests still pass (zero regressions)

**Files to Create**:
- `lib/core/storage/scan_result_store.dart` (~400 lines)
- `lib/core/storage/unmatched_email_store.dart` (~350 lines)
- `lib/core/models/provider_email_identifier.dart` (~80 lines)
- `test/unit/storage/scan_result_store_test.dart` (~400 lines, 30 tests)
- `test/unit/storage/unmatched_email_store_test.dart` (~450 lines, 35 tests)

**Files to Modify**:
- `lib/core/storage/database_helper.dart` (+40 lines)

**Blocks**: Tasks B, C, D (foundation for all other tasks)

---

### **Task B: Email Availability Checking**
**Model Assignment**: Haiku
**Complexity**: MEDIUM - provider integration, error handling
**Estimated Time**: 3-4 hours
**Issue**: #74

**Description**:
Implement a service to check whether emails still exist in their original provider folders. Emails may be deleted or moved externally by the user after the scan, so this service verifies current availability status.

**Acceptance Criteria**:
- [ ] Can check if Gmail email still exists
- [ ] Can check if IMAP email still exists
- [ ] Batch checking efficient (100+ emails < 5 seconds)
- [ ] Handles deleted emails gracefully
- [ ] Handles moved emails (updates status)
- [ ] 25+ tests passing

**Files to Create**:
- `lib/core/services/email_availability_checker.dart` (~250 lines)
- `test/unit/services/email_availability_checker_test.dart` (~300 lines, 25 tests)

**Files to Modify**:
- `lib/adapters/email_providers/gmail_api_adapter.dart` (+30 lines - `checkEmailExists`)
- `lib/adapters/email_providers/generic_imap_adapter.dart` (+30 lines - `checkEmailExists`)

**Depends On**: Task A (ScanResultStore, UnmatchedEmailStore)
**Blocks**: Tasks C, D

---

### **Task C: Scan Result Persistence Integration**
**Model Assignment**: Haiku
**Complexity**: MEDIUM - state management, provider integration
**Estimated Time**: 3-4 hours
**Issue**: #75

**Description**:
Integrate database persistence into the existing scanning workflow. When scans complete, save results and unmatched emails to the database. Track manual vs. background scans separately.

**Acceptance Criteria**:
- [ ] Manual scans create `scan_results` with `type='manual'`
- [ ] Background scans create a separate record with `type='background'`
- [ ] Unmatched emails saved to database
- [ ] Counts match actual results
- [ ] Provider identifiers stored correctly
- [ ] 15+ integration tests passing

**Files to Modify**:
- `lib/core/providers/email_scan_provider.dart` (+50 lines)
- `lib/core/services/email_scanner.dart` (+30 lines)

**Files to Create**:
- `test/integration/scan_result_persistence_test.dart` (~200 lines, 15 tests)

**Depends On**: Task A (ScanResultStore, UnmatchedEmailStore)
**Blocks**: Task D (UI needs persisted data)

---

### **Task D: Process Results UI**
**Model Assignment**: Haiku
**Complexity**: MEDIUM - UI design, navigation
**Estimated Time**: 4-5 hours
**Issue**: #76

**Description**:
Build UI screens for reviewing and processing unmatched emails from scan results. Gives the user the ability to view unmatched emails, check availability, mark them processed, and quick-add safe senders or auto-delete rules.

**Acceptance Criteria**:
- [ ] Process Results screen displays unmatched emails
- [ ] Can filter by availability/processed status
- [ ] Can search by from/subject
- [ ] Email Detail View shows full info
- [ ] Quick-add buttons navigate correctly
- [ ] Mark as processed updates database
- [ ] Availability indicator accurate
- [ ] 35+ UI tests passing

**Files to Create**:
- `lib/ui/screens/process_results_screen.dart` (~400 lines)
- `lib/ui/screens/email_detail_view.dart` (~350 lines)
- `lib/ui/widgets/unmatched_email_card.dart` (~200 lines)
- `test/ui/screens/process_results_screen_test.dart` (~250 lines, 20 tests)
- `test/ui/screens/email_detail_view_test.dart` (~200 lines, 15 tests)

**Files to Modify**:
- `lib/ui/screens/results_display_screen.dart` (+20 lines)
- `lib/ui/screens/scan_progress_screen.dart` (+20 lines)

**Depends On**: Tasks A, B, C (database + availability checking + persistence)

**Note**: The "Add Safe Sender" and "Create Auto-Delete Rule" quick-action buttons in `EmailDetailView` are placeholders in Sprint 4, wired to full functionality in Sprint 6.

---

## Database Schema (New Tables)

```sql
CREATE TABLE IF NOT EXISTS scan_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL,
  scan_type TEXT NOT NULL,           -- 'manual' or 'background'
  scan_date INTEGER NOT NULL,
  total_emails INTEGER DEFAULT 0,
  matched_count INTEGER DEFAULT 0,
  no_rule_count INTEGER DEFAULT 0,
  deleted_count INTEGER DEFAULT 0,
  moved_count INTEGER DEFAULT 0,
  safe_sender_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  folder_names TEXT,                 -- JSON array
  scan_mode TEXT,                    -- 'readonly', 'safe_senders', 'full'
  status TEXT DEFAULT 'in_progress', -- 'in_progress', 'completed', 'error'
  created_at INTEGER NOT NULL,
  updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS unmatched_emails (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scan_result_id INTEGER NOT NULL,
  provider_identifier_type TEXT NOT NULL,
  provider_identifier_value TEXT NOT NULL,
  from_email TEXT NOT NULL,
  from_name TEXT,
  subject TEXT,
  body_preview TEXT,
  folder_name TEXT NOT NULL,
  email_date INTEGER,
  availability_status TEXT DEFAULT 'unknown',
  availability_checked_at INTEGER,
  processed BOOLEAN DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (scan_result_id) REFERENCES scan_results(id) ON DELETE CASCADE
);
```

---

## Model Assignment & Complexity

| Task | Model | Complexity | Hours |
|------|-------|-----------|-------|
| A: Storage Layer | Sonnet (primary) / Haiku (support) | High | 4-5 |
| B: Availability Checking | Haiku | Medium | 3-4 |
| C: Persistence Integration | Haiku | Medium | 3-4 |
| D: Process Results UI | Haiku | Medium | 4-5 |

**Total Estimated Effort**: 14-16 hours

---

## Success Criteria for Sprint 4

### Code Quality
- [ ] All new tests passing (140+ tests across Tasks A-D)
- [ ] Zero code analysis errors
- [ ] Zero regressions in existing tests

### Functionality
- [ ] Scan results and unmatched emails persisted to database
- [ ] Availability checking works for Gmail and IMAP
- [ ] Process Results screen allows filter/sort/search of unmatched emails
- [ ] Mark-as-processed workflow updates database

### Process
- [ ] All commits pushed to remote
- [ ] Sprint review conducted (Phase 4.5)
- [ ] GitHub issues closed (#73, #74, #75, #76)

---

## Dependencies & Blockers

### Dependencies
- Sprint 3 complete (SafeSenderDatabaseStore, SafeSenderEvaluator, database-first migration fix)
- Database schema and migration infrastructure in place

### Potential Blockers
- None identified for core functionality; Task D UI depends on Tasks A-C completing first

---

## Next Steps (After Sprint 4 Approval)

Sprint 5 will focus on: Safe Sender Quick-Add Screen integration (Issue #75 successor work), plus resolving pre-existing test failures and process gaps identified in Sprint 4 (see SPRINT_4_RETROSPECTIVE.md).

---

## References

- **Source Issues**: #73 (Task A), #74 (Task B), #75 (Task C), #76 (Task D)
- **Merge PR**: #77 - https://github.com/kimmeyh/spamfilter-multi/pull/77
- **Sprint 3 Plan**: `docs/sprints/SPRINT_3_PLAN.md`
- **Sprint Execution Workflow**: `docs/SPRINT_EXECUTION_WORKFLOW.md`

---

**Version**: 1.0 (retroactive reconstruction, Sprint 57 doc audit)
**Created**: 2026-08-14
**Status**: [RECONSTRUCTED] - Sprint 4 was already complete; this plan was backfilled from issue/PR history
