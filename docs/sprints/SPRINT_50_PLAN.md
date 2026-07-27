# Sprint 50 Plan: Core App Quality polish + F126 prod-data cleanup + F127 rescope close-out

**Sprint**: 50
**Date**: 2026-07-25
**Branch**: `feature/20260723_Sprint_50` (created FROM `feature/20260720_Sprint_49` per the Phase 6.6 carry-forward flow)
**PR**: [#278](https://github.com/kimmeyh/spamfilter-multi/pull/278) (draft -> develop; DRAFT through Phase 7.7)
**Status**: COMPLETE through Phase 6. Tasks 1-5 + MT-1/MT-2/MT-2b/MT-2c/MT-3 done; suite + CI green; Phase 5.3 manual testing PASSED (Harold 2026-07-26: "All working as expected and can be closed"); Phase 7 retrospective next
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

**Executed-by**: Fable 5 (in-session execution; live prod-DB window coordination)

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

**Executed-by**: Fable 5 (in-session; trivial mirror edit not worth a delegation round-trip)

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

**Executed-by**: Fable 5 (in-session; root-cause escalated to a 350-row data repair)

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

**Executed-by**: Fable 5 (in-session; scope grew to include the latent filter-key mismatch)

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

**Executed-by**: Fable 5 (in-session; single gh command)

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

**Outcome (Phase 6.1.1 confirmation)**: no architecture change occurred. F123's Class-2 path did NOT trigger -- the root cause was stored DATA, not the display-precedence decision, so the Sprint 37 "stored patternType is authoritative" rule stands untouched. No ADR/ARCHITECTURE/ARSD edit required.

## Risk Review Gate (Phase 6.1.1)

Risk review complete: 5 planned tasks + 4 manual-testing items reviewed; all mitigations executed and evidenced.

- **F126 (Medium impact -- live prod-DB delete)**: mitigations proven. Dry-run matched exactly 4 rows; abort-if-not-4 gate held; apply verified 5,887 -> 5,883; re-dry-run returned 0 (idempotent); dev-DB parity checked (0 matches). Rollback artifact on disk: `spam_filter.db.backup_pre_f126_prod_2026-07-25T19-41-14-516247` (12.5 MB).
- **F123 (Medium impact -- 350-row live data repair; conditional Class-2)**: mitigations proven. Rehearsed on a scratchpad copy first (350 repairs, 0 remaining), then applied live prod (350) and dev (341), each verifying 0 repairable rows remain. `custom` types never touched; recompute-to-`unknown` never degrades a labeled row. Class-2 did not trigger (data fix, not precedence change). Rollback artifacts: `...backup_pre_f123_prod_2026-07-25T19-55-28-631532` and `...backup_pre_f123_dev_2026-07-25T19-55-43-579748`.
- **F122 / F124 / F127-residual (Low -- maintenance)**: tests added and green; analyzer clean; CI green.
- **MT-1 / MT-2 / MT-2b / MT-2c / MT-3 (Low-Medium -- mid-sprint manual-testing scope)**: each carries a pinning test (grid geometry, idempotency x2, newer-scan race, platform-aware entry point); all Harold-validated on the dev build.
- **CI cross-platform escape (found + fixed at this gate)**: the MT-3 tooltip assertion assumed a Windows host and failed the ubuntu CI job (`3405a40` makes it platform-aware). Windows Build Verification was green throughout. This is a genuine F-PRECHECK class-1 miss (mirror/parallel-site: local Windows vs CI Linux) -- carried to the retrospective.

## Sprint Result (Phase 6)

All 5 planned tasks complete, plus 5 mid-sprint manual-testing items (MT-1, MT-2, MT-2b, MT-2c, MT-3) and one backlog item filed (F128). Harold validated every item: "All working as expected and can be closed."

## Manual Testing (Phase 5.3) -- PASSED

Build + launch the Windows dev app proactively; Harold verifies: (1) Manage Safe Senders shows "Exact Email" for the observed pattern, (2) Manage Rules shows the fallback label on `SpamAutoDeleteFrom`, (3) Review-No-Rule loads normally (error path covered by widget test), (4) rule counts reflect the F126 removal.

**Result (Harold, 2026-07-26): all items "working as expected and can be closed"** -- F123, F124, F126 (Store app), MT-2c, MT-3, plus MT-1 and MT-2 validated earlier in the session.

### Mid-sprint scope from manual testing (Harold-requested, implemented in-sprint)

- **MT-1 -- fixed 3-column quick-action grid** (`b17239c`): the email popup renders Email | Exact Domain | Entire Domain as equal-width cells across a Safe row and a Block row, with disabled placeholders when a domain action does not apply and Block Subject on its own full-width row, so Block Entire Domain always occupies the same position. Harold chose this option over "Entire-Domain first" and "widest-fit width". Pinned by a geometry test asserting column x-alignment.
- **MT-2 -- idempotent quick actions + auto-resolve** (`233ee00`): rule names are deterministic and `rules.name` is UNIQUE, so a second item on an already-blocked domain threw and stuck in the list ("failed to add block rule"). An existing rule/safe sender now reports "already covered" success carrying the existing rule as the F120 delta. Harold chose "idempotent + auto-resolve" over "idempotent only".
- **MT-2b -- sweep after the reload** (`2089c21`): a newer scan completing while the screen is open re-populates the same senders as fresh rows; the sweep now runs on the post-action pool.
- **MT-2c -- sweep on EVERY load** (`246ceb4`): covered rows were still listed on open. `_loadItems` now evaluates all items against the full rule set + safe senders (F120-style yields), marks covered ones processed and drops them pre-display.
- **MT-3 -- Review "No Rule" Items entry point** (`e92c16c`): added to the Manual Scan and Scan Results app bars, mirroring the F112/F39 convention (icon, tooltip, position ahead of History, Windows-scoped).

### Backlog item discovered (filed, not fixed here)

- **F128** (master plan, Priority 18): `RuleSetProvider.addRule`/`addSafeSender` silently no-op when the provider cache is unloaded -- the caller reports success with no row persisted (F-PRECHECK class 6). Latent in production (startup always loads the provider); surfaced by an unloaded test provider. The MT-2c sweep self-loads as a local guard; the provider-level fix and its sibling early-returns are backlog.
