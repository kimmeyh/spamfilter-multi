# Sprint 50 Plan: Core App Quality polish + F126 prod-data cleanup + F127 rescope close-out

**Sprint**: 50
**Date**: 2026-07-25
**Branch**: `feature/20260723_Sprint_50` (created FROM `feature/20260720_Sprint_49` per the Phase 6.6 carry-forward flow)
**PR**: [#278](https://github.com/kimmeyh/spamfilter-multi/pull/278) (draft -> develop; DRAFT through Phase 7.7)
**Status**: DRAFT -- awaiting Phase 3.7 approval
**Scope source**: 2026-07-25 backlog refinement (v1.3 format); Harold's selection 2026-07-25: F126 + F122 + F123 + F124 + F127 (rescoped)

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md` (Sprint 49 recompute note: prefer the LOW end of band for S-size SVC-EDIT/DOCS items).

---

## Sprint Objective

Close out the small, well-scoped quality items surfaced by Harold's 0.5.6/0.5.7 validation passes and the Copilot round-6 carry-in: remove the last 4 ambiguous legacy rules from the prod DB, polish the Review-No-Rule load-error path, fix two Manage-screens display defects, and verify the F127 rescope leaves CI green.

---

## Pre-approval work already on the branch (Phase 3.2.2.1 verification)

The sprint branch already carries completed work from the refinement window -- listed here for the record, NOT active scope:

- Backlog-refinement deterministic-process hardening: format gate + spec v1.2/v1.3 (Summary Index) + `backlog-refinement` skill (`80d3a95`, `864ef39`).
- **F127 fix portion already shipped**: ci.yml `secrets.ci.json` key correction to `WINDOWS_GMAIL_*` (`5c4e0ce`) -- Task 5 below is the residual verification only.
- **F-WINSTORE-ASSETS DONE**: 7 screenshot masters committed (`3c357a6`, `b40c089`); Harold completed the Partner Center listing update 2026-07-25.
- 0.5.7 release close-out docs (`741d0ba`, `ca4a7a3`); refinement Step 6 registration (`45d2453`).

Phase 3.2.2.2 re-estimate: F127 reduced from ~30m to 5-10m residual (fix already shipped in `5c4e0ce`). No other 3.2.2.1 findings -- all F122/F123/F124 code anchors verified present and unfixed on the branch (`no_rule_review_screen.dart:129`, `safe_senders_management_screen.dart:51-73`, `rules_management_screen.dart:829-830`).

---

## Sprint Scope

### Task 1 -- F126: Remove the 4 ambiguous legacy TLD-block body rules (Priority 10, Issue #279)

**Value**: This removes the last known-dead legacy rows from the restored prod rules DB, completing the F121/F33-PROD data-restoration arc.

**Requirements**:
- R-1: Delete exactly the 4 legacy `%`-wildcard body rows left report-only by F33-PROD: `/%.nl/`, `/%.ru/`, `/%.store/`, `/.*.xyz` (PO delete decision made by scope selection, 2026-07-25).
- R-2: Dry-run-first discipline: the run must list the matched rows and their count BEFORE any mutation; the apply must ABORT if the match count differs from 4.
- R-3: Timestamped prod-DB backup created immediately before apply (same convention as the F121/F33-PROD backups at the DB path).
- R-4: Check the dev DB for the same 4 rows; if present, apply the same removal there for parity (same dry-run/backup discipline).

**Affected components / files**:
- `mobile-app/scripts/remove_ambiguous_tld_rules.dart` -- NEW small script mirroring the `cleanup_body_rules.dart` seams (`--db` override, dry-run default, `--apply` + backup).
- Prod DB: `C:\Users\kimme\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\spam_filter.db` (app must be closed for the apply window).

**Dependencies / blockers**: None (BUG-DECODE/F33-PROD shipped Sprint 49; PO decision made).

**Non-functional requirements**:
- Persistence: destructive one-time data change on the LIVE prod DB -- backup + dry-run gate mandatory; script matches rows by exact pattern content, never by rowid guess.

**Acceptance criteria**:
- AC-1: Dry-run output lists exactly 4 rows, each matching one of the 4 patterns in R-1; any other count aborts with no mutation.
- AC-2: After apply, prod-DB rule count = pre-apply count minus 4, and a `spam_filter.db.backup_pre_f126_prod_<timestamp>` file exists at the DB path.
- AC-3: A re-run of the dry-run after apply reports 0 matches (idempotent; nothing else was touched).
- AC-4: Script unit test (fixture DB via `--db` seam) proves: match-4 -> delete-4, match-not-4 -> abort untouched.

**Tests to write**:
- T-1 (AC-1, AC-4) -- TEST-UNIT in `mobile-app/test/scripts/remove_ambiguous_tld_rules_test.dart`: fixture DB with the 4 rows + decoys proves exact-match selection and the abort gate.
- T-2 (AC-2, AC-3) -- release-style check (not a unit test): the live dry-run/apply/re-dry-run sequence, reported to Harold.

**Definition of Done**: default task-level DoD PLUS: live apply results (counts + backup filename) reported to Harold in-chat.

**Model**: Sonnet -- *why not Haiku*: destructive apply against the LIVE prod DB; needs the dry-run/abort/backup verification discipline and environment judgment (prod vs dev DB paths), beyond mechanical scripting.

**Executed-by** (filled at completion):

**Step-types**: DATA + SVC-NEW (small script) + TEST-UNIT

**Est-Effort**: 15-25m

**Risk & rollback**: Risk -- deleting a live rule Harold still wants. Mitigation -- exact-pattern match + abort-if-not-4 + PO decision on record. Rollback -- restore the timestamped backup file.

---

### Task 2 -- F122: Review-No-Rule screen load-error polish (Priority 12, Issue #280)

**Value**: This prevents a raw exception string reaching the user and gives support-grade stack traces on load failures (Copilot round-6 carry-in).

**Requirements**:
- R-1: `_loadItems` catch at `no_rule_review_screen.dart:129` captures the stack trace and logs it (`catch (e, s)` + `stackTrace: s`), mirroring the correct sibling at line 255.
- R-2: The SnackBar shows a friendly message (no raw `$e`), e.g. "Could not load review items. Please try again." -- exact wording at implementer's discretion, no exception text.

**Affected components / files**:
- `mobile-app/lib/ui/screens/no_rule_review_screen.dart:129-135` -- catch block + SnackBar.

**Dependencies / blockers**: None

**Acceptance criteria**:
- AC-1: The load-error log call passes a non-null `stackTrace`.
- AC-2: No raw exception object is interpolated into any user-facing string on the load-error path.
- AC-3: Full suite green; analyze clean.

**Tests to write**:
- T-1 (AC-1/AC-2) -- TEST-WIDGET in the existing `no_rule_review_screen` test file: force the load to throw; assert the friendly SnackBar text appears and contains no exception `toString()`.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- single-file mirror of an in-file sibling pattern.

**Executed-by** (filled at completion):

**Step-types**: SVC-EDIT + TEST-WIDGET

**Est-Effort**: 10-20m

---

### Task 3 -- F123: Safe-sender classification display fix (Priority 14, Issue #281)

**Value**: This prevents Manage Safe Senders from mislabeling patterns (an exact-email pattern shown as "Entire Domain"), which misleads rule-audit decisions.

**Requirements**:
- R-1: Root-cause WITH EVIDENCE why the exact-email-shaped pattern (`^...@live\.com$`, observed in Harold's 0.5.6 validation) is categorized `entireDomain`: inspect the actual stored row (`patternType` value) vs `SafeSenderCategory.categorize()` (`safe_senders_management_screen.dart:51-73`) -- is the stored `patternType` wrong (data), or does the classification logic mis-rank it (code)?
- R-2: Fix so an exact-email-shaped pattern displays "Exact Email" -- in the list tile, the category filter chips/counts, and the CSV export sub-type.
- R-3: If the fix changes the precedence of stored `patternType` over pattern-shape analysis (a prior Sprint 37 development decision), STOP and surface Class-2 to Harold before implementing.

**Affected components / files**:
- `mobile-app/lib/ui/screens/safe_senders_management_screen.dart:51-73` (`categorize()`) -- and/or the stored `patternType` data path, per R-1 findings.

**Dependencies / blockers**: None

**Non-functional requirements**:
- Persistence: if the root cause is stored data, any data correction follows the Task 1 discipline (dry-run, backup, report).

**Acceptance criteria**:
- AC-1: Root cause stated with the actual stored row values as evidence.
- AC-2 (behavioral): Given the observed safe-sender row, When Manage Safe Senders renders, Then its category label reads "Exact Email" (tile, filter count, CSV sub-type all agree).
- AC-3: Existing category tests still pass; no other pattern's category changes unless proven equally wrong (list any that do).

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT in `test/unit/` (safe-sender categorization): pins `categorize()` for the observed pattern shape (and the stored-type combination found in R-1) to `exactEmail`.

**Definition of Done**: default task-level DoD PLUS: R-1 evidence included in the commit message or PR notes.

**Model**: Sonnet -- *why not Haiku*: root cause spans stored DB data vs display-logic precedence and carries a conditional Class-2 decision (R-3); requires investigation judgment, not pattern-following.

**Executed-by** (filled at completion):

**Step-types**: SVC-EDIT + TEST-UNIT (+ DATA if R-1 finds bad stored data)

**Est-Effort**: 25-40m

**Decision-class interrupts**: Conditional Class-2 per R-3 (stored-`patternType`-precedence change) -- surface and WAIT if triggered.

---

### Task 4 -- F124: Legacy uncategorized-rule label fix (Priority 16, Issue #282)

**Value**: This prevents legacy pre-classification rules (e.g. `SpamAutoDeleteFrom`) from rendering a blank "-" sub-label in Manage Rules.

**Requirements**:
- R-1: A rule with null `patternCategory`/`patternSubType` displays a sensible fallback label (e.g. "Uncategorized (legacy)") in the list tile (`rules_management_screen.dart:829-830` currently falls through to `''`).
- R-2: The details dialog (lines 258-259, currently "Unknown") and the tile use consistent fallback wording.
- R-3: Category filter counts continue to bucket null categories under one label (the existing `'uncategorized'` bucket at line 147) consistent with R-1's wording.

**Affected components / files**:
- `mobile-app/lib/ui/screens/rules_management_screen.dart:258-259, 829-830` (+ filter-chip labels if they render the bucket).

**Dependencies / blockers**: None

**Acceptance criteria**:
- AC-1 (behavioral): Given a rule with null `patternCategory` and null `patternSubType`, When Manage Rules renders, Then the tile shows the fallback label and no bare "-"/blank sub-label.
- AC-2: Tile, details dialog, and filter bucket use one consistent fallback wording.
- AC-3: Full suite green; analyze clean.

**Tests to write**:
- T-1 (AC-1/AC-2) -- TEST-WIDGET in the existing rules-management test file: renders a null-category rule; asserts the fallback label appears in the tile and the details dialog.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- well-defined single-file display fallback with named line anchors.

**Executed-by** (filled at completion):

**Step-types**: UI-MOVE (label logic) + TEST-WIDGET

**Est-Effort**: 15-25m

---

### Task 5 -- F127 (rescoped): CI green-run verification (Priority 22, Issue #283)

**Value**: This proves the F127 rescope (corrected `secrets.ci.json` key names, CI_* secrets deliberately unset) leaves the CI pipeline fully green.

**Requirements**:
- R-1: The Sprint 50 PR's CI run (analyze + test + Windows build-verification) completes green with the corrected key generation from `5c4e0ce`.
- R-2: If CI fails for a reason traceable to the key correction, fix it in-sprint; unrelated failures are triaged per the fix-failures-as-found rule.

**Affected components / files**: None expected (verification only; `.github/workflows/ci.yml` already corrected).

**Dependencies / blockers**: CI runs on the draft PR after push (Task order: verify after the first code push of Tasks 1-4).

**Acceptance criteria**:
- AC-1: All CI jobs green on the Sprint 50 PR head commit; run link recorded in the PR.

**Tests to write**: None (CI itself is the test).

**Definition of Done**: None -- default DoD only (velocity row still recorded).

**Model**: Haiku -- status verification.

**Executed-by** (filled at completion):

**Step-types**: DOCS (verification note)

**Est-Effort**: 5-10m

---

## Sprint Totals

- **Est-Effort**: 70-120m across 5 tasks (+20% buffer on the two manual-verification touchpoints -> ~85-140m).
- **Model mix**: Haiku x3 (F122, F124, F127-residual), Sonnet x2 (F126, F123) -- cheapest-first per SPRINT_PLANNING.md; "why not cheaper" recorded per task.

## Risk Assessment (sprint level)

- F126 live prod-DB delete (Low likelihood / Medium impact): exact-match + abort-if-not-4 + timestamped backup + PO decision on record; rollback = restore backup.
- F123 conditional Class-2 (Medium/Low): surfaced and waited on if triggered -- explicitly planned, so no unsurfaced decision risk.
- Remaining tasks are UI-polish maintenance: Low -- maintenance work.

## Architecture Impact Check (Phase 3.6.1)

No architecture impact: no ADR, ARCHITECTURE.md, or ARSD change anticipated. F123's conditional Class-2 (R-3) is the only path that could touch a prior design decision, and it is gated on Harold's sign-off. No new dependencies, no schema changes (F126 deletes rows, no DDL).

## Manual Testing (Phase 5.3)

Build + launch the Windows dev app proactively; Harold verifies: (1) Manage Safe Senders shows "Exact Email" for the observed pattern, (2) Manage Rules shows the fallback label on `SpamAutoDeleteFrom`, (3) Review-No-Rule loads normally (error path covered by widget test), (4) rule counts reflect the F126 removal.
