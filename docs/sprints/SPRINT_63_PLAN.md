# Sprint 63 Plan -- STUB (created at Sprint 62 close-out, 2026-08-23)

**Status**: NOT PLANNED YET. Scope selection happens at Phase 8.4 (Backlog Refinement pass 2)
after PR #355 merges and the Store release cycle runs. This stub exists per the Phase 7.7
checklist ("Next Sprint Plan stub created/updated with Category 13 carry-ins") so the
carry-ins cannot be lost between sprints.

## Category 13 carry-ins from the Sprint 62 retrospective

Harold's Cat 13: none. Claude Code Development Team items (Harold saw them in the combined
retrospective; fold into Phase 3 planning):

1. **E2E coverage for Sprint 62's new UI surfaces**: F178 bottom-anchored popup, F175
   wait-and-start dialog, F176 AccountEmailLabel. None of the active WinWright scripts
   exercise them (recorded coverage gap, SPRINT_62_PLAN.md Phase 5 evidence section). The
   F175 dialog needs an active background scan, so F99 `integration_test` is the right home
   for it; the popup and label may be WinWright-scriptable.
2. **Watch CI's first live run on PR #355** when it flips Ready-for-Review: first proof of
   the Workmanager Linux-fake fix and the draft-gating change. If it fails, that is a
   Sprint 63 day-one item.
3. ~~Merge f129 into mt2c~~ -- already executed during the Sprint 62 retrospective (IMP-5);
   no longer a carry-in.

## New process rules taking effect THIS sprint (Sprint 63)

- **Phase 5 evidence gate** (`verify-closeout-complete` check 3d, Sprint 62 IMP-1): the
  sprint plan must carry 5.1.1 (code review) + 5.1.2 (F-PRECHECK) + 5.1.5 (sweep) evidence
  before any close-out claim -- and per SPRINT_CHECKLIST.md, BEFORE Phase 5.3 Manual
  Validation starts.
- **Sweep-at-HEAD** (check 3e, Sprint 62 IMP-2): the sweep artifact must include
  `sweep-head: <hash>`; no `mobile-app/lib/ui` commit may be newer at close-out.
- **Never build Windows and Android concurrently** (Sprint 62 IMP-3, CLAUDE.md).
- **Inset-sensitive widget tests** need FakeViewPadding + the real Scaffold structure
  (Sprint 62 IMP-4, TESTING_STRATEGY.md).

## Prime scope candidates flagged at Sprint 62 close (selection is Harold's, at 8.4)

- F180 (fetch/eval body caps -- F177 phase 2, Priority 10, fresh evidence)
- F181 (remove testLimit option, Priority 18, precision-planned)
- F182 (mt2c seeding preamble, Priority 30)
- Plus whatever Backlog Refinement pass 2 surfaces.
