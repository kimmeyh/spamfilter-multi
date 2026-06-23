# Sprint 42 Plan: F99 integration_test harness -> F98 per-account bg-scan -> BUG-S37-2 TLD data

**Sprint**: 42
**Date**: 2026-06-20 (Planning / Phase 1-3)
**Branch**: `feature/20260620_Sprint_42` (created off merged `develop`)
**Status**: APPROVED 2026-06-20 (Harold, Phase 3.7). Execution started -- F99 first.

**Harold decisions at approval (2026-06-20)**:
- **F98 scheduling (Class-1) -- RESOLVED**: **one scheduled task per enabled account** (true per-account isolation). No mid-sprint Class-1 stop needed for this; F98-design now only confirms the task-naming string.
- **BUG-S37-2 ccTLD strategy -- DIRECTION GIVEN, exact list TBC**: the bundled block/allow list is only an INITIAL LOAD, user-overridable anytime (remove a TLD, or add safe-sender rules). Leaning **US/UK allowed + high-spam TLDs blocked + the user's existing account-configured set**. Harold said "OK to ask about TLD" -> surface the exact ccTLD list for confirmation when BUG-S37-2 starts (third item).
**Type**: Mixed -- Testing infrastructure (F99, pre-MVP), Architecture implementation (F98), Data quality (BUG-S37-2)
**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md` (effort = sum of sub-agents; wall-clock = parallel critical path).

> **Scope confirmed by Harold (2026-06-20)**: F99 -> F98 -> BUG-S37-2, **in that order**. F99 first because it is pre-MVP AND lands regression coverage before the F98 multi-surface refactor (de-risks F98). F96 / SEC-11b held for a later sprint.

---

## Sprint Objective

Stand up the Flutter `integration_test` E2E harness (F99) as the robust in-VM second lane -- delivering the create/delete lifecycle, folder-picker, and visual/layout-regression coverage that Sprint 41 deferred into it -- THEN implement per-account background scanning (F98) per the approved ADR-0039 with that new coverage in place, and finish with the bundled-rule TLD data-quality cleanup + ccTLD expansion (BUG-S37-2).

---

## Sprint Scope (3 items, ordered)

### 1. F99 -- Parallel `integration_test` E2E harness (Priority 76, PRE-MVP) -- FIRST

Per the IMP-1 refinement starting point baked into the F99 backlog entry:

- **Task F99-a (HARNESS SETUP)**: add `integration_test` dev-dependency + `integration_test/` dir; create a runner script (`run-integration-tests.ps1`) paralleling `run-winwright-tests.ps1`, reusing the same DB-snapshot drift guard (`winwright-db-snapshot.ps1`). Decide: two harnesses, one combined sweep entry point vs two separate -- **recommend two separate runners** (WinWright = read-only accessibility lane; integration_test = write/lifecycle + visual lane), documented in TESTING_STRATEGY.md.
- **Task F99-b (WIDGET KEYS)**: add stable `Key`s to the targeted widgets (Settings/Help/nav buttons, Add-Block-Rule radios + TLD/domain input + Save confirm dialog, folder pickers + search field, Manage Rules / Safe Senders search). Prerequisite for stable `find.byKey`.
- **Task F99-c (LIFECYCLE FLOWS -- absorbs F56)**: port the rule-create-block + safe-sender-create + delete-teardown lifecycle to `integration_test` with `pumpAndSettle()` (no settle race) and zero-DB-drift teardown. The `test_f56_*.json` files are the reference flow.
- **Task F99-d (FOLDER PICKER -- absorbs F37)**: port the folder-picker open/search/back flow.
- **Task F99-e (VISUAL/LAYOUT -- absorbs F76)**: golden-image and/or `RenderBox` layout-bounds assertions for the primary screens; capture baselines; prove a deliberate layout change fails the check (the acceptance criterion F76 never met on WinWright).
- **Task F99-f (DOCS)**: TESTING_STRATEGY.md two-harness strategy; note CI implications (integration_test on Windows desktop needs a display/session -> local cadence for now; ties to F64 HOLD).

**Acceptance**: `flutter test integration_test/` runs the create/delete + folder-picker + visual flows green with zero net DB drift; a deliberate layout change is shown to fail the visual check; two-harness strategy documented.

**Step-types**: HARNESS/HOOK + TEST-WIDGET + UI-MOVE (keys) + DOCS.
**Est-Effort: 80-120m | Est-Wall: 60-90m** (F99-c/d/e parallelize after F99-a/b land).

### 2. F98 -- Per-account background scanning IMPLEMENTATION (Priority 78) -- SECOND

Implements approved **ADR-0039**. UNBLOCKED (ADR Accepted 2026-06-15).

- **Task F98-design (CLASS-1 SURFACE FIRST)**: before coding, surface the F98 design decisions the ADR enumerated change-sites but did not fully lock -- per-account **scheduling semantics** (one Task Scheduler entry / WorkManager task per enabled account vs one shared task that iterates only enabled accounts) and **task-naming convention** (`SpamFilterBackgroundScan_<env>_<accountId>` proposed). Present to Harold for Class-1 sign-off, THEN execute. (~10m, no code.)
- **Task F98-db (DB-MIGRATE)**: per-account `background_scan_enabled` schema -- migrate the single global `app_settings.background_scan_enabled` to per-account (`account_settings` table per ADR change-site #N); DB v7 migration + back-fill. Also clean up the orphaned `background_scan_schedule` table the ADR flagged.
- **Task F98-ui (UI-NEW)**: per-account toggle in Settings > Background (replaces the single global toggle); relocate the "account-specific" info card per the existing pattern.
- **Task F98-win (NATIVE-WIN)**: Windows Task Scheduler per-account entries (`windows_task_scheduler_service.dart` + `powershell_script_generator.dart` -- add `accountId` param + enumerate-all + orphan cleanup per ADR sites #15/#18).
- **Task F98-android (SVC-EDIT)**: Android WorkManager per-account equivalent (`background_scan_manager.dart`); fix the latent Android key-mismatch bug the F83 research surfaced.
- **Task F98-cli (SVC-EDIT)**: `--background-scan --account-id=<id>` CLI arg + dispatcher; per-account log/CSV path separation.
- **Task F98-content (CONTENT)**: Help text update (`assets/content/help/background_scanning.md`) per ADR-0038.
- **Task F98-test**: unit + widget + (new) integration_test coverage for the per-account toggle + migration.

**Acceptance**: enabling background scan on one account schedules only that account; per-account schema migrates clean (v7); Windows per-account task entries created/removed correctly; CLI targets a single account; Help text updated; tests green (incl. F99 integration_test coverage).

**Step-types**: DB-MIGRATE + UI-NEW + NATIVE-WIN + SVC-EDIT + CONTENT + tests.
**Est-Effort: 100-160m | Est-Wall: 70-110m** (DB -> UI/native/android parallelize; CLI + content serial-ish).

### 3. BUG-S37-2 -- Bundled-rule TLD data quality + ccTLD expansion (Priority 50) -- THIRD

- **Task BUG-S37-2-design (CLASS-1/PO SURFACE)**: the ccTLD scoping strategy is a Product-Owner decision (false-positive risk vs coverage). Surface the four options from the backlog (strict-except-US/UK; English-allies allowlist; high-spam-only; user-allowlist) for Harold's choice before producing the data patch. (~part of Phase 3.)
- **Task BUG-S37-2-a (DATA, audit)**: script-driven sweep of existing bundled TLD rules outputting typo/miscategorization candidates (`*.c`, `*.giw`, `*.de.com`, etc.) for Harold review -- do NOT auto-apply.
- **Task BUG-S37-2-b (DATA, expansion + cleanup)**: YAML patch / DB migration adding the chosen ccTLDs as `top_level_domain` block rules + a one-time migration removing the confirmed typos.

**Acceptance**: typo candidates surfaced for review; chosen ccTLD set added as block rules; cleanup migration ships with the expansion; rule-count delta documented.

**Step-types**: DATA + a Phase-3 design choice.
**Est-Effort: 30-45m | Est-Wall: 25-35m.**

---

## Sprint total

**Est-Effort ~210-325m | Est-Wall ~155-235m** (3 items run serially per Harold's ordering; within-item tasks parallelize). Larger than Sprint 41's planned scope -- expected, since F98 is the multi-surface implementation half and F99 is full harness setup. Wall-clock is well under the 400-hour stopping threshold; no time-based stop applies.

---

## Model assignments

- **F99-a/b (harness, keys), F98-db/ui/win/android/cli, BUG-S37-2-a/b**: **Sonnet** -- mechanical infra/impl with a clear spec.
- **F99 visual/golden design (F99-e), F98-design (Class-1), BUG-S37-2 ccTLD strategy**: **Opus** -- judgment/architecture.
- **F98 NATIVE-WIN (F98-win)**: **Opus** -- high-variance C++/Task-Scheduler surface (NATIVE-WIN history shows retries).

---

## Decision-Class interrupts (NOT pre-authorized -- surface + wait per CLAUDE.md taxonomy)

- **F98-design** (Class-1): per-account scheduling semantics + task-naming -- surface at Phase 3, sign-off before F98 coding.
- **BUG-S37-2 ccTLD strategy** (PO decision): surface the four options, get Harold's pick before the data patch.
- Any change to a prior ADR-0039 decision discovered mid-implementation.

Everything else (all task execution as scoped, branch commits/pushes, CHANGELOG/plan/velocity updates, opening/updating the Sprint 42 PR to `develop`) is pre-authorized on Phase 3.7 approval.

---

## Coverage / velocity tracking

- Each Item gets a PLANNED Coverage Ledger row in `docs/CODING_VELOCITY.md` at approval; both actuals filled at completion; Accuracy Trend row at retro.
- **Phase 7 EXIT GATE**: every touched Item (incl. mid-sprint scope) has a ledger row with both estimates + both actuals, or the retro is INCOMPLETE.

---

## Phase 3.7 Standing Approval Inventory (pre-authorized through Phase 7 on approval)

All three Items' task execution as scoped; committing/pushing Phase 4/5 work to the sprint branch; updating CHANGELOG.md + this plan + CODING_VELOCITY.md; opening/updating the sprint PR to `develop`. NOT pre-authorized: the two decision-class interrupts above.

---

**Status**: PLANNING. Next action: Harold reviews this plan + answers the two early decision-class items (F98 scheduling/naming; ccTLD strategy), then gives Phase 3.7 approval to begin F99.
