# Sprint 51 Plan: Process-docs consistency audit + Sprint 50 carry-in closure

**Sprint**: 51
**Date**: 2026-07-27
**Branch**: `feature/20260727_Sprint_51` (created FROM `feature/20260723_Sprint_50` per the Phase 6.6 carry-forward flow)
**PR**: not yet created (Phase 3.3.1 creates it as a DRAFT once this plan is drafted)
**Status**: **APPROVED** (Phase 3.7, Harold 2026-07-27) -- executing. Blanket execution approval through Manual Validation; stop only per SPRINT_STOPPING_CRITERIA.md.
**Scope source**: Harold 2026-07-27: "F130-S51 -- time-boxed to < 400 hour estimate. Do first; F128; F129"

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`. **Two of the three tasks are `[no-history]`** -- see the Estimating Integrity note below; this plan does NOT present invented ranges as calibrated.

---

## Phase 3.2.2.1 Plan-to-Branch-State Verification (gate result)

Each task verified against actual branch state before this plan was committed -- none is already shipped:

- **Task 1 (F130-S51)**: the stash-guard matcher still keys on the `git stash` string (`block-carry-forward-stash.ps1`), so the false positive is live. A hook test harness already exists (`.claude/hooks/test-cases/` + `run-test-cases.ps1`) with an `allow-*`/`block-*` naming convention -- the new cases extend it rather than build new infrastructure, which lowers the R-2 cost.
- **Task 2 (F128-residual)**: exactly **3** silent-return sites remain in `rule_set_provider.dart` (lines 279 `removeRule`, 311 `updateRule`, 396 `removeSafeSender`). Matches the plan; no others found.
- **Task 3 (F129)**: 3 WinWright scripts exist (F37, F56 x2) and **none** covers the Sprint-50 surfaces. Confirms the Phase 5.1.5 gap.

**Phase 3.2.2.2 re-estimate**: no scope-changing findings; the only adjustment is a downward note on Task 1's R-2 cost (existing test harness reused). No task estimates changed.

---

## Sprint Objective

Audit the sprint-execution instruction surface for the contradictions that caused the Sprint 50/51 execution escapes, and close the two remaining Sprint 50 carry-ins: the unaudited silent-no-op siblings in `RuleSetProvider`, and the missing WinWright coverage for the three screens Sprint 50 changed.

---

## Estimating Integrity note (Harold challenge, 2026-07-27)

Harold challenged a "5-9 hours" total I presented during refinement. The arithmetic was correct; the inputs were not -- **F130-S51's "~3-6h" was a figure I invented**, with no `CODING_VELOCITY.md` step-type and no prior sample, and it dominated the total. It has been withdrawn and the item marked `[no-history]` in the master plan.

Accordingly:

- **Task 1 (F130-S51)** is **TIME-BOXED, not estimated** (Harold's instruction). See its Time-box section.
- **Task 3 (F129)** is `[no-history]` -- no WinWright script has been authored since the F79/F99 harness work, so there is no sample to estimate from. A conservative band is offered and explicitly flagged.
- **Task 2 (F128-residual)** is the only calibrated estimate: a bounded change over three verified sites in one file.

Per `CODING_VELOCITY.md` rule 3, every task records its ACTUAL on completion so the SECOND run of an F130-class audit is the first genuinely estimated one.

---

## Sprint Scope

### Task 1 -- F130-S51: Process-Docs Consistency Deep Dive, first run (Priority 12) -- DO FIRST

**Value**: This prevents the instruction surface from teaching contradictory procedures to different model tiers / different sessions -- the root cause of the Sprint 50 close-out escapes and of the Phase 6.6 branch recipe being corrected five times without sticking.

**Requirements**:
- R-1: Execute the F130 template scope (defined in `ALL_SPRINTS_MASTER_PLAN.md` -- do NOT restate it here) across the instruction surface: the 11 SPRINT EXECUTION docs, `CLAUDE.md`, `AGENTS.md`, `.claude/hooks/*`, `.claude/skills/*/SKILL.md`, `.claude/settings.json` hook registrations, `.claude/sprint_status.json`, and the auto-memory (`MEMORY.md` + `feedback_*.md`).
- R-2a: **Second named item, found while drafting this very plan (2026-07-27)**: fix the **sprint-auto-advance Phase 3.7 false positive**. Gate 1b exempts Phase 1 by testing whether `SPRINT_N_PLAN.md` exists -- but the plan file exists from the moment it is DRAFTED, so the hook cannot distinguish **Phase 3.7 (plan drafted, approval request MANDATORY)** from **Phase 4+ (plan approved, asking is a violation)**. It therefore blocked the one approval request the workflow requires. Phase 3.7 approval is what CREATES durable authorization, so it can never be auto-advanced past. Fix: add a Phase-3.7 exemption -- e.g. treat "plan file exists but is not yet marked approved" as pre-approval (the plan's own `**Status**:` line already carries `DRAFT -- awaiting Phase 3.7 approval` vs an approved marker), or check `.claude/sprint_status.json` `current_sprint.plan_approved`, which exists precisely to record this state. Add test cases: draft-plan-awaiting-approval -> ALLOW; approved-plan mid-execution -> BLOCK.
- R-2: **Named item for this run**: fix the **stash-guard hook false positive**. `.claude/hooks/block-carry-forward-stash.ps1` matches the literal string `git stash` anywhere in a Bash/PowerShell command, so on 2026-07-27 it blocked a legitimate command whose text merely *documented* the prohibition. Match only an actual invocation (command position), not an occurrence inside quoted/heredoc/documentation content.
- R-3: Produce a findings table: `Instruction | Sites | Statements found | Authoritative version | Action`. Every contradiction found gets an explicit disposition (corrected now / backlog / accepted-with-rationale).
- R-4: Prefer ONE authoritative statement plus pointers over duplicated prose -- duplication is what drifts. Where a summary row must exist (cheat sheets, TOC), it must be verified against its detailed section in the same pass.
- R-5: Record the contradiction COUNT found, so the trend is visible when the template runs again.
- R-6: Corrections must not silently change process intent. Any finding where the "correct" version is genuinely ambiguous is a **Class-3 decision** -- surface to Harold, do not pick one.

**Affected components / files**:
- `.claude/hooks/block-carry-forward-stash.ps1` -- matcher narrowed (R-2)
- `.claude/hooks/test-cases/` -- new cases for the stash guard (R-2)
- Any of the instruction-surface files above, as findings dictate
- `docs/sprints/SPRINT_51_F130_FINDINGS.md` -- NEW: the findings table (R-3, R-5)

**Dependencies / blockers**: None. Harold's instruction is to do this task FIRST.

**Time-box (replaces an estimate, per Harold)**:
- The `SPRINT_STOPPING_CRITERIA.md` Criterion 9 threshold is **400 wall-clock hours**, and per that document, if the sprint estimate is below 400 hours the criterion does NOT apply. This task is nowhere near it, so **Criterion 9 will not be the reason this task ends** -- it ends when R-1..R-6 are satisfied or when a genuine criterion 1-8 fires.
- **Discovery is unbounded**, so the box is on BREADTH, not on clock: run the audit in **risk order** and complete each tier before starting the next, so the work is releasable at any tier boundary:
  1. **Tier 1 (highest risk -- execution-changing)**: `SPRINT_EXECUTION_WORKFLOW.md`, `SPRINT_CHECKLIST.md`, `CLAUDE.md`, `AGENTS.md`, the hooks, and the auto-memory. These four docs plus memory are what a session actually acts on.
  2. **Tier 2**: the remaining SPRINT EXECUTION docs + skills + settings/`sprint_status.json` schema.
  3. **Tier 3**: cross-references, dead links, anchors.
- If Tier 1 alone exceeds a reasonable session, STOP at the tier boundary, commit the findings table with tiers 2-3 marked NOT STARTED, and carry them to Sprint 52 -- that is scope management, not an unplanned stop.

**Acceptance criteria**:
- AC-1: `docs/sprints/SPRINT_51_F130_FINDINGS.md` exists and contains, for every finding: the instruction, every site it appears at, the differing statements, the authoritative version, and the disposition.
- AC-2: The stash-guard hook blocks a real `git stash` invocation, ALLOWS a command whose text merely mentions the words, and honors the `allow_stash` bypass -- each proven by a test case under `.claude/hooks/test-cases/`.
- AC-2a: The sprint-auto-advance hook ALLOWS a turn that ends by requesting Phase 3.7 plan approval (plan drafted, not yet approved) and still BLOCKS a procedural question after approval -- each proven by a test case.
- AC-3: Every Tier-1 finding is either corrected in this sprint or has an explicit recorded disposition. No finding is left silently unaddressed.
- AC-4: The contradiction count is recorded in the findings doc and in the retrospective.
- AC-5: Tiers not reached are explicitly marked NOT STARTED in the findings doc (never implied complete by omission).

**Tests to write**:
- T-1 (verifies AC-2) -- HOOK test cases in `.claude/hooks/test-cases/`: three cases (real invocation -> BLOCK; documentation text containing the words -> ALLOW; `allow_stash` token -> ALLOW), runnable via the existing `run-test-cases.ps1` harness.
- T-2 (verifies AC-1/AC-3/AC-5) -- not an automated test: the findings doc IS the artifact. Verified by inspection against the tier list.

**Definition of Done**: default task-level DoD PLUS:
- Findings doc committed with the contradiction count and per-tier status.
- Any doc corrections verified by re-grepping the corrected phrase across ALL surfaces (the Phase 6.6 lesson: fixing one site while four others still teach the old recipe is not a fix).
- Auto-memory `description:` fields and `MEMORY.md` index lines checked against their corrected docs -- recall re-teaches whatever memory says.

**Model**: Fable/Opus -- *why not cheaper*: this is cross-cutting synthesis over the entire instruction surface with judgment calls about which of two conflicting statements is authoritative, and it carries a Class-3 surfacing requirement (R-6). It matches "Architecture Deep Dives" and "Best Practices Research" on the `SPRINT_PLANNING.md` MANDATORY-Fable/Opus list.

**Executed-by** (filled at completion):

**Step-types**: DOCS + HOOK

**Est-Effort**: `[no-history]` -- TIME-BOXED by tier (see above). Record ACTUAL in the Coverage Ledger.

**Risk & rollback**: Risk -- a "correction" changes process intent rather than fixing a contradiction. Mitigation -- R-6 makes ambiguous cases a Class-3 surface, and every change lands in a doc-only commit that is trivially revertable. Second risk -- the audit expands without end; mitigated by the tier boxing and the explicit NOT STARTED marking.

**Decision-class interrupts**: **Class-3 (Scrum Master)** whenever two statements conflict and the authoritative one is genuinely ambiguous -- surface with both versions and WAIT. Do not silently pick.

---

### Task 2 -- F128-residual: audit the sibling silent-no-op early-returns (Priority 10)

**Value**: This prevents the remaining `RuleSetProvider` mutators from reporting success while persisting nothing -- the same silent-failure class F128 fixed in `addRule`/`addSafeSender` during Sprint 50.

**Requirements**:
- R-1: The three remaining `if (_x == null) return;` early-returns get the F128 treatment -- load on demand, and throw `StateError` if the cache is still unavailable afterwards -- so no mutator can silently no-op. Verified sites: `removeRule` (`rule_set_provider.dart:279`), `updateRule` (`:311`), `removeSafeSender` (`:396`).
- R-2: Consistency with the F128 fix already in place: same load-then-throw shape, same comment convention citing F128.
- R-3: Confirm no OTHER method in the file carries the shape (the grep is part of the task, not an assumption).

**Affected components / files**:
- `mobile-app/lib/core/providers/rule_set_provider.dart:279, 311, 396` -- three early-returns
- `mobile-app/test/unit/providers/rule_set_provider_test.dart` -- regression tests

**Dependencies / blockers**: None (F128 landed in Sprint 50).

**Acceptance criteria**:
- AC-1: Each of the three methods, called on an UNLOADED provider, either persists the change or throws -- never returns silently. Proven per method.
- AC-2: A grep for `if (_rules == null) return;` / `if (_safeSenders == null) return;` in `rule_set_provider.dart` returns zero silent-return sites.
- AC-3: Full suite green; analyze clean.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-UNIT in `test/unit/providers/rule_set_provider_test.dart`: one test per method proving load-on-demand + persistence against an unloaded provider, mirroring the F128 tests added in Sprint 50. **Watch for existing tests that PIN the old silent behavior** -- Sprint 50 found `addRule does nothing if rules not loaded` asserting the defect as correct; update any equivalent rather than working around it.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- the pattern is already established in the same file by the F128 fix; this is a mechanical mirror over three named sites with named line numbers.

**Executed-by** (filled at completion):

**Step-types**: SVC-EDIT + TEST-UNIT

**Est-Effort**: 15-25m (calibrated: bounded change over 3 verified sites in 1 file; SVC-EDIT band 5-18m per site-cluster, plus tests)

---

### Task 3 -- F129: WinWright coverage for the Sprint-50-touched screens (Priority 19)

**Value**: This enables the Phase 5.1.5 UI sweep to actually exercise the three surfaces Sprint 50 changed, instead of exiting with "no script covers this" as it did at Sprint 50's gate.

**Requirements**:
- R-1: A script exercising the **quick-action grid** in the email popup (MT-1): the fixed 3-column layout is present and Block Entire Domain occupies its expected cell.
- R-2: A script exercising **Manage Rules** category/sub-type display (F124), including the legacy "Uncategorized (legacy)" fallback.
- R-3: A script exercising the **Review "No Rule"** screen (MT-2c), including that the covered-item sweep removes an already-covered row on load.
- R-4: **Every script restores all state it modifies** (Sprint 37 policy) -- follow the teardown convention in `test_f56_create_block_rule.json`, which creates and then deletes its own rule for a net-zero DB change.
- R-5: Scripts run green via `C:\Tools\WinWright\Civyk.WinWright.Mcp.exe run <script.json>` against a dev build.

**Affected components / files**:
- `mobile-app/test/winwright/test_f129_quick_action_grid.json` -- NEW
- `mobile-app/test/winwright/test_f129_manage_rules_labels.json` -- NEW
- `mobile-app/test/winwright/test_f129_no_rule_sweep.json` -- NEW
- `mobile-app/test/winwright/README.md` + `_SELECTOR_MAP_*.md` -- updated with any new selectors discovered

**Dependencies / blockers**: Requires a running dev build; selectors must be verified live (the existing scripts' comments show selector discovery is the real cost, not authoring).

**Non-functional requirements**:
- Platform: Windows Desktop only (WinWright is a Windows-desktop harness).
- Persistence: R-4 state restoration is mandatory -- these scripts run against the dev database.

**Acceptance criteria**:
- AC-1: Three scripts exist and each runs green via the WinWright CLI.
- AC-2 (behavioral, R-3): Given a No-Rule item whose covering rule already exists, When the Review screen loads, Then that row is absent.
- AC-3: After each script completes, the dev DB rule/safe-sender counts match their pre-run values (net-zero).

**Tests to write**:
- T-1 (verifies AC-1/AC-2) -- the three WinWright scripts ARE the tests (E2E level per `TESTING_STRATEGY.md`).
- T-2 (verifies AC-3) -- teardown steps within each script, following the `test_f56_create_block_rule.json` convention.

**Definition of Done**: default task-level DoD PLUS:
- Any selector discovered live is recorded in the selector map, so the next author does not repeat the discovery cost.

**Model**: Sonnet -- *why not Haiku*: selector discovery against a live accessibility tree is empirical and iterative (the existing scripts' comments document three separate rounds of selector failures: radio-vs-group, mode-dependent field names, off-screen buttons). It needs live-tree reasoning, not pattern-following.

**Executed-by** (filled at completion):

**Step-types**: TEST-E2E (WinWright) + DOCS

**Est-Effort**: `[no-history]` -- no WinWright script has been authored since the F79/F99 harness work. Conservative band **60-150m** for three scripts, FLAGGED as uncalibrated; the F97 actuals (Sprint 41) showed selector discovery running 3 rounds and ~46m for a single script, so this could run high. Record ACTUAL.

**Risk & rollback**: Risk -- scripts mutate the dev DB and leave residue if a run fails mid-script. Mitigation -- R-4 teardown plus AC-3 count verification; back up the dev DB before the first live run. Rollback -- restore the dev DB backup; scripts are additive files.

---

## Sprint Totals

- **Est-Effort**: **NOT a single number.** Task 2 is 15-25m (calibrated). Task 1 is time-boxed by tier. Task 3 is `[no-history]` with a flagged 60-150m band. Presenting a sprint total here would repeat the error Harold challenged during refinement.
- **Model mix**: Fable/Opus x1 (F130-S51 -- cross-cutting synthesis + Class-3 surfacing), Sonnet x1 (F129 -- empirical selector discovery), Haiku x1 (F128-residual -- mechanical mirror). Cheapest-first per `SPRINT_PLANNING.md`; "why not cheaper" recorded per task.
- **Order**: Task 1 FIRST (Harold's instruction), then Tasks 2 and 3.

## Risk Assessment (sprint level)

- **F130-S51 unbounded discovery** (High likelihood / Low impact): mitigated by tier boxing, tier-boundary stopping, and explicit NOT STARTED marking.
- **F130-S51 intent drift** (Low / Medium): a "correction" that changes what the process means. Mitigated by the Class-3 surfacing rule (R-6) and doc-only revertable commits.
- **F129 dev-DB residue** (Medium / Low): mitigated by mandatory teardown, count verification, and a pre-run DB backup.
- **F128-residual** (Low -- maintenance): mirrors an established in-file pattern; the risk is an existing test pinning the old behavior, which Sprint 50 already taught us to look for.

## Architecture Impact Check (Phase 3.6.1)

No architecture impact expected: no ADR, `ARCHITECTURE.md`, or ARSD change. F128-residual extends an existing provider contract already set by F128 (load-on-demand rather than silent no-op) rather than establishing a new one. F130-S51 touches process documentation and harness configuration, not application architecture. If the F130 audit surfaces a contradiction that is actually an ARCHITECTURE/ADR inconsistency, that is a Class-1 surface to the Chief Architect, not a silent edit.

## Manual Validation (Phase 5.3)

Build and launch the Windows dev app proactively. Harold verifies: (1) the three WinWright scripts run green and leave the dev DB unchanged; (2) rule add/remove/update and safe-sender remove still behave correctly after the F128-residual change (no regression in the quick-action or Manage Rules paths). The F130-S51 work is doc/harness-only and is verified by the findings table plus the hook test cases rather than by app behavior.
