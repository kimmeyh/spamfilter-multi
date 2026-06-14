# Sprint 41 Plan: Per-Account Background-Scan Design (F83 P1) + WinWright Test Tooling (F97, F76)

**Sprint**: 41
**Date**: 2026-06-13 (Backlog Refinement / Phase 1-3)
**Branch**: `feature/20260613_Sprint_41` (to be created at Phase 3.7)
**Status**: APPROVED 2026-06-13 (Harold). Execution pending branch creation + early ADR questions.
**Type**: Mixed -- Architecture research/ADR (F83 Phase 1), Test tooling (F97), Testing infrastructure (F76)
**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md` (effort = sum of sub-agents; wall-clock = T_end - T_start). Estimates recomputed from Sprint 39+40 actuals; a 5x correction applied to the multi-surface draft numbers per Harold (2026-06-13).

> **Carry-in source**: F76 + F97 from the Sprint 40 backlog (F97 is the deferred WinWright F56 create+delete re-port; F76 moved off HOLD at Sprint 39 refinement). F83 split this sprint -- Phase 1 (research + ADR) here, Phase 2 implementation carved out as **F98** (Sprint 42 candidate, gated on ADR approval).

---

## Sprint Objective

Produce the approved-design foundation for per-account background scanning (F83 Phase 1: deep code research + an ADR enumerating every global-background-scan read/write/artifact site and the per-account schema), and complete the WinWright test suite: re-port the 2 deferred F56 create+delete lifecycle scripts (F97) and add visual-regression assertions to the sweep (F76).

---

## Sprint Scope (3 items, confirmed at 2026-06-13 Backlog Refinement)

F83 Phase 1 (research + ADR ONLY -- no implementation), F97, F76.

**Harold decisions (2026-06-13)**:
- **F83 split**: Phase 1 (Task a, research + ADR) is in Sprint 41. Phase 2 (Task b, implementation) is split to **F98** (high priority, Sprint 42 candidate). F98 does NOT begin until the F83 Phase 1 ADR is approved (Class-1 architecture decision -- Chief Architect signoff).
- **Ask all ADR questions as early as reasonably possible** after sprint approval -- batch them up front so the research is not blocked mid-stream waiting on decisions.
- **Auth-token re-login investigation**: deferred to AFTER this plan is finalized (separate non-sprint task).

---

## Estimates (two metrics, minutes -- per CODING_VELOCITY.md)

Estimates carry **Est-Effort** (sum of sub-agents) and **Est-Wall** (parallel critical path). A 5x correction was applied to the initial multi-surface draft (Harold: "390m estimate is likely 5x larger than actual").

- **F97 -- WinWright F56 create+delete scripts re-port**
  - Step-types: HOOK/tooling + DOCS + live-UI input-format confirmation.
  - **Est-Effort: 6-10m | Est-Wall: 6-10m** (solo; needs live UI to confirm the new Add-Block-Rule input format that blocked the Sprint 40 port).

- **F76 -- WinWright visual regression testing**
  - Step-types: HOOK/tooling + TEST infrastructure. Screenshot-diff or layout-bounds assertions onto the F79 sweep harness.
  - **Est-Effort: 8-14m | Est-Wall: 8-14m** `[no-history]` for visual-diff specifically; conservative. Serialized AFTER F97 (shared WinWright harness -- avoid file conflicts).

- **F83 Phase 1 -- Per-account bg-scan research + ADR**
  - Step-types: read-only code research + DOCS/ADR authoring.
  - **Est-Effort: 10-16m | Est-Wall: 10-16m** (one deep research agent; a single coherent design does not parallelize well).

**Sprint total: Est-Effort ~24-40m | Est-Wall ~24-40m.** (Compare: the pre-correction multi-surface draft was ~215-390m because it included F83 Phase 2 implementation, now split to F98.)

---

## Parallelization plan + Harold's "come back" windows

- **F83 Phase 1** and **F97** are independent (different surfaces, no shared files) -> run as **parallel sub-agents**.
- **F76** touches the same WinWright harness as F97 -> **serialize F76 after F97**.
- Critical path (wall-clock): max(F83-P1 10-16, F97 6-10) then F76 8-14 = **~18-30m wall-clock before the Manual Testing handoff**.

**Away-window estimate: come back in ~20-35 minutes after approval.** Refined to a single number when execution starts; slip flagged immediately.

**Important early interrupt**: F83 Phase 1 produces an ADR. Per the Decision-Class Taxonomy (CLAUDE.md), a per-account architecture change is a **Class-1 (Chief Architect) decision**. Harold will be asked to **review/approve the ADR** before it is finalized and before any F98 work is ever scheduled. Harold also asked to receive **ADR questions as early as possible** -- these come right after approval, before deep research, batched.

---

## Model assignments

- **F83 Phase 1** (architecture research + ADR): **Opus** -- deep-research/design item.
- **F97, F76** (tooling/test infra): **Sonnet**.

---

## Acceptance criteria

**F83 Phase 1**
- A written ADR under `docs/adr/` (next number) enumerating EVERY place the global background-scan setting is read, written, or assumed, and every artifact path it influences (Settings UI, settings storage/DB, Windows Task Scheduler, Android WorkManager, log paths, CSV/xlsx export paths, `--background-scan` CLI arg, Help text), plus the proposed per-account schema + scheduling + naming convention.
- ADR explicitly lists the F98 implementation change-sites so F98 can be minute-estimated from it.
- NO implementation, NO schema migration written this sprint. Research + design only.
- ADR presented to Harold for Class-1 approval.

**F97**
- The 2 F56 lifecycle scripts (`test_f56_create_block_rule.json`, `test_f56_create_safe_sender.json`) re-authored to the current `testCases` schema; the accepted Add-Block-Rule input format confirmed against the live Sprint-40 rule-creation UI.
- Both scripts run unattended and green with zero net DB drift (self-cleaning per the Sprint 35 lifecycle design).

**F76**
- Visual-regression assertions (screenshot-diff or layout-bounds) added to the WinWright sweep for at least the primary screens; baseline images captured; a deliberate layout change is shown to fail the check.
- Sweep remains green unattended with the new assertions on the unchanged UI.

---

## Coverage / velocity tracking (this sprint -- per CODING_VELOCITY.md)

- Each Item already has a **Coverage Ledger** row (PLANNED) in `docs/CODING_VELOCITY.md`.
- At T_start (sprint approval), log the start clock reading. On each Item completion, fill **both** actuals (effort + wall-clock). At the last sub-agent's completion, log T_end.
- **Phase 7 EXIT GATE**: every Item touched this sprint (including any mid-sprint scope from manual-testing feedback) has a Coverage Ledger row with both estimates and both actuals, or the retro is INCOMPLETE.
- Add the Sprint 41 row to the **Accuracy Trend** table at retro. Target: error-ratio 0.7-1.3, MAPE < 30% (first sprint estimated entirely from the recomputed table).

---

## Manual Testing handoff (Phase 5.3)

When coding is green (tests pass, analyze clean) and the Windows desktop build is built+launched, Harold gets a **suggested manual-testing bullet list** covering F97 (run the 2 re-ported scripts unattended; confirm zero DB drift) and F76 (run the sweep; confirm visual assertions pass on unchanged UI, fail on a deliberate layout change). F83 Phase 1 has NO runtime manual test -- its review is the ADR approval, which happens earlier.

---

## Phase 3.7 Standing Approval Inventory (pre-authorized through Phase 7)

On this approval, the following are pre-authorized (no per-task re-approval): all three Items' coding as scoped; creating the sprint feature branch; committing + pushing Phase 4/5 work to the sprint branch; updating CHANGELOG.md + this plan + CODING_VELOCITY.md; opening/updating the sprint PR to `develop`.

**NOT pre-authorized (explicit interrupts, per Harold + Decision-Class Taxonomy)**:
- **F83 ADR approval** (Class-1) -- surfaced for Harold signoff before finalizing.
- **Early ADR questions** -- surfaced up front, right after approval.
- **Manual-testing readiness** -- Harold notified with the bullet list when the build is ready.
- Any de-scope / new-scope / architecture or development decision per the taxonomy.

---

**Status**: APPROVED 2026-06-13. Next actions: (1) create branch, (2) surface early ADR questions, (3) begin F83 P1 research || F97 in parallel, F76 after F97.
