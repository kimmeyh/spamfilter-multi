# Sprint 6 Plan: Interactive Rule & Safe Sender Management from Scan Results

**Created**: January 26, 2026 (reconstructed retroactively -- see note below)
**Sprint**: Sprint 6
**Status**: COMPLETE (Merged via PR #87)
**Feature Branch**: `feature/20260126_Sprint_6` (per commit history; exact branch name not separately recorded)

> **RETROACTIVE RECONSTRUCTION NOTICE**: This plan document was not created
> during Sprint 6 execution and is being backfilled during the Sprint 57
> documentation audit (2026-08-14). It is reconstructed from PR #87 (title,
> body, and 7 commits), GitHub issues #82-86, and the existing
> `docs/sprints/SPRINT_6_RETROSPECTIVE_IMPROVEMENTS.md` file. No original
> Sprint 6 planning conversation or document survives. Where a specific
> figure (hours, dates) is not recoverable from these sources, it is marked
> "not recorded" rather than invented.

---

## Sprint Overview

Sprint 6 implements interactive quick-add functionality for creating spam
filter rules and safe-sender entries directly from unmatched email reviews,
so a user reviewing scan results can immediately protect against a spammer
or whitelist a legitimate sender without leaving the review flow.

---

## Sprint Objectives

### Primary Objective
Let a user reviewing an unmatched email in `ProcessResultsScreen` /
`EmailDetailView` create a safe-sender entry or an auto-delete rule directly
from that email's content, with the pattern pre-generated from the email's
From/Subject/Body/URL fields.

### Business Value
- Closes the loop between "scan finds an unmatched email" and "user acts on
  it" without a separate rule-editing workflow.
- Reduces the friction of manually writing regex patterns by auto-generating
  them from email content.

---

## Scope & Dependencies

### What IS Included in Sprint 6
1. Pattern normalization utilities (email/subject/body/URL)
2. Pattern generation utilities (Types 1-3: exact email, domain, subdomain)
3. YAML export service (dual-write: SQLite primary, YAML secondary)
4. `SafeSenderQuickAddScreen` UI
5. `RuleQuickAddScreen` UI
6. `EmailDetailView` / `ProcessResultsScreen` integration (navigation + store
   wiring)
7. End-to-end integration tests covering the full quick-add workflow

### Dependencies
- Sprint 3: `SafeSenderDatabaseStore`, `RuleDatabaseStore` (reused directly)
- Existing `EmailMessage`, `Rule`, `RuleConditions`, `RuleActions` models

---

## Sprint Tasks

### Task A: Pattern Utilities & YAML Export Service
**GitHub Issue**: #82
**Files**:
- `lib/core/utils/pattern_normalization.dart` (157 lines) -- email/subject/body
  normalization, URL/domain extraction
- `lib/core/utils/pattern_generation.dart` (124 lines) -- Type 1-3 pattern
  generation, pattern-type auto-detection
- `lib/core/services/yaml_export_service.dart` (90 lines) -- dual-write
  database -> YAML export with timestamped backups

**Tests**: 81 unit tests (46 normalization + 35 generation), 100% passing

---

### Task B: SafeSenderQuickAddScreen UI
**GitHub Issue**: #83
**Files**: `lib/ui/screens/safe_sender_quick_add_screen.dart` (~680 lines)

**Key Responsibilities**:
- Read-only email context card (From, Subject, Folder)
- Pattern type selection: Type 1 (exact email), Type 2 (domain), Type 3
  (domain + subdomains), Type 4 (custom regex)
- Expandable pattern preview with regex validation
- Exception denylist toggle (optional)
- Save via `SafeSenderDatabaseStore`, success/error `SnackBar` feedback

**Tests**: 16 widget tests, 100% passing

---

### Task C: RuleQuickAddScreen UI
**GitHub Issue**: #84
**Files**: `lib/ui/screens/rule_quick_add_screen.dart` (~510 lines)

**Key Responsibilities**:
- Email context card (From, Subject, Body preview, Folder)
- Auto-generated rule name from sender domain (e.g.
  `spammer@spam.com` -> `AutoDeleteSpamCom`)
- 4 condition buckets: From Header, Subject, Body, Body URL
- Condition logic selection (OR/AND)
- Action selection (Delete/Move to folder)
- Execution-order auto-assignment from existing rules
- Form validation (rule name, patterns, folder requirement)

**Tests**: 12 widget tests, 100% passing

---

### Task D: EmailDetailView Integration
**GitHub Issue**: #85
**Files**:
- `lib/ui/screens/email_detail_view.dart` (+95 lines)
- `lib/ui/screens/process_results_screen.dart` (+30 lines)

**Key Responsibilities**:
- Optional `SafeSenderDatabaseStore` / `RuleDatabaseStore` parameters
  threaded through the widget tree (nullable, backward compatible)
- "Add Safe Sender" button navigates to `SafeSenderQuickAddScreen`
- "Create Auto-Delete Rule" button navigates to `RuleQuickAddScreen`
- Success/error feedback via `SnackBar` on return

**Tests**: 49/49 UI screen tests passing, 0 regressions

---

### Task E: End-to-End Testing & Documentation
**GitHub Issue**: #86
**Files**: integration test file (~470 lines)

**Test Workflows** (6 total, all passing):
1. Add safe sender (Type 1 -- exact email)
2. Add safe sender (Type 3 -- domain + subdomains, with exceptions)
3. Create auto-delete rule (From Header pattern)
4. Create multi-condition rule (AND logic, Subject + URL)
5. Pattern-type auto-detection (Types 0-3)
6. Database persistence verification across operations

---

## Architecture

**Dual-Write Pattern**: SQLite database is primary (via
`SafeSenderDatabaseStore` / `RuleDatabaseStore`); YAML export
(`rules.yaml`, `rules_safe_senders.yaml`) is secondary, for version control,
with non-blocking export failures and automatic timestamped backups.

**Pattern Types**:
- Type 1: Exact email match -- `^user@domain\.com$`
- Type 2: Domain match -- `@domain\.com$`
- Type 3: Domain + all subdomains -- `@(?:[a-z0-9-]+\.)*domain\.com$`
- Type 4: Custom regex (user-defined)

**User Flow**: Unmatched email in `ProcessResultsScreen` -> tap to open
`EmailDetailView` -> "Add Safe Sender" or "Create Auto-Delete Rule" -> screen
opens pre-filled with a generated pattern from the email -> user
confirms/customizes -> saved to database -> returns to `EmailDetailView`
with success feedback.

---

## Outcome (from PR #87 and its commits)

- 7 commits, merged 2026-01-27 (`e16c17bb5ef2c665c570420d07708c547ff46c1d`)
- All 5 tasks (A-E) completed as scoped; no evidence in the PR body or commit
  history of tasks dropped or deferred
- 6/6 integration tests passing (100%)
- `flutter analyze`: 0 errors, 21 warnings (documented as non-blocking
  deprecation notices)
- A post-Task-E fix commit (`e5b6acda...`) corrected import paths and
  simplified `yaml_export_service.dart`, and removed unused imports from
  `email_availability_checker.dart`
- A final commit (`1eeaecdc...`, co-authored with Claude Haiku 4.5) applied
  process-documentation improvements from the Sprint 6 retrospective -- see
  `docs/sprints/SPRINT_6_RETROSPECTIVE_IMPROVEMENTS.md` and the new
  `SPRINT_6_RETROSPECTIVE.md` for details

**Effort**: Not recorded in any recoverable source (no time-tracking table
in the PR body or commit messages).

---

**Document Version**: 1.0 (retroactive reconstruction)
**Reconstructed**: 2026-08-14 (Sprint 57 documentation audit)
