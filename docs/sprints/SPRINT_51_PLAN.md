# Sprint 51 Plan (STUB -- pre-kickoff)

**Sprint**: 51
**Date**: 2026-07-27 (stub created at Sprint 50 close-out, Phase 7.7)
**Branch**: `feature/20260727_Sprint_51` (created FROM `feature/20260723_Sprint_50` per the Phase 6.6 carry-forward flow)
**PR**: not yet created (Phase 3.3.1 creates it as a DRAFT once the plan is drafted)
**Status**: **STUB -- NOT APPROVED.** Awaiting Phase 1 backlog refinement and Harold's scope selection. No Phase 4 work may begin until Phase 3.7 approval is explicit in-conversation.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Purpose of this stub

`SPRINT_CHECKLIST.md` Phase 7.7 requires the next sprint's plan stub to exist carrying the previous retrospective's **Category 13** items (carry-ins destined for the next sprint plan) so they cannot be lost between sprints. This file holds them until Phase 1 refinement and Phase 3 planning turn them into approved scope.

---

## Carry-ins from Sprint 50 (candidates, NOT approved scope)

Harold recorded "none" for retrospective Categories 13 and 14. The items below therefore come from work that surfaced during Sprint 50 execution and Copilot review, and each still needs Product Owner selection:

### From the F128 fix (Copilot round 4, escalated and fixed in Sprint 50)

- **F128-residual** (~15m): the sibling early-returns in `RuleSetProvider` share the silent-no-op shape that F128 fixed in `addRule`/`addSafeSender` -- `removeRule`, `updateRule`, `removeSafeSender`, and any other `if (_x == null) return;`. They were explicitly NOT audited during the Sprint 50 fix. Registered in the master plan under the F128 entry.

### From the Phase 5.1.5 WinWright sweep (exit criteria)

- **F129** (~1-2h, Priority 19): no WinWright script exercises the three surfaces Sprint 50 changed -- the quick-action grid in the email popup (MT-1), Manage Rules category/sub-type display (F124), and the Review "No Rule" screen including its covered-item sweep (MT-2c). Each script must restore all state it modifies (Sprint 37 policy).

### Store release close-out (blocked on certification, not sprint scope)

- `0.5.8` was submitted to Partner Center 2026-07-27 and is in certification. On PASS, run the close-out recorded in `.claude/sprint_status.json` -> `store_release.post_cert_closeout_pending`: CHANGELOG `[0.5.8]` heading + links, dev bump 0.5.8 -> 0.5.9 (one file), master-plan Store status, and Harold's verification of the Store-installed build.

### Standing backlog (see ALL_SPRINTS_MASTER_PLAN.md "Next Sprint Candidates")

- F-COPILOT-INSTR, F125, F94 / Android flavors, F108-RETEST, and the **Android / Google Play track**, which remains the next major track per the promotion trigger that fired 2026-07-24.

---

## Next steps

1. **Phase 1 -- Backlog Refinement** (`docs/BACKLOG_REFINEMENT.md`): read the "Backlog Presentation Format" section FIRST, then present candidates in the v1.3 format (Summary Index at top, `**<ID>. <Title> (~<effort>) Priority <N>**` with Phase/Platform bullets).
2. **Phase 3 -- Planning**: Harold selects scope; expand the selected items into augmented task cards per `SPRINT_PLANNING.md`; run the 3.2.2.1 plan-to-branch-state verification gate; create the draft PR (3.3.1) and GitHub issues (3.4).
3. **Phase 3.7**: explicit approval before any implementation work.
