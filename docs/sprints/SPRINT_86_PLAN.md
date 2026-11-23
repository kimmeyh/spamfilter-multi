# Sprint 86 Plan -- STUB (carry-ins from Sprint 85)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 85 carried in.

## Start of sprint

- **0.25.0 store updates** (Phase 8.3 of the Sprint 85 cycle) -- the Microsoft Store MSIX and the Google Play
  closed-test AAB for 0.25.0+23 (`docs/store-assets/RELEASE_NOTES_0.25.0_*.md`, re-derived 2026-11-21 at 7.7). The
  AAB in `mobile-app\dist\android-0.25.0+23\` was built from 42b56afc, before the 7.7.1 fixes; rebuild both from
  HEAD of `main` after the merge. Serialize the Windows and Android builds.
- **F307 removal (Harold, Sprint 85 q1)** -- remove the "Create rule" page (RuleQuickAddScreen). Sprint 85 Task 8
  (#568) did the R-1 coverage audit only; #568 stays open for this sprint. Master plan Priority 36.
- **F363 task clock (Harold, 2026-11-23, register d2)** -- every task's start and finish recorded by a script and
  enforced by gates, so no task closes with no minutes. Build it first, so the other Sprint 86 tasks use it. Master
  plan Priority 32. Needs register q2 (new hook matchers) answered before planning.
- **F362 question register (Harold, 2026-11-22: "Add to backlog for next sprint")** -- the register file
  `docs/DECISION_REGISTER.md` was started 2026-11-23 (register d1); the card finishes the process changes. Master
  plan Priority 34.

## Manual Validation carried from Sprint 85

- **iPhone (F67a #509, F304 #510, F67b #523)**: waits on Apple's approval of enrollment `R6QG2A9SHS` (stopping
  criterion 2).
- None else: every Sprint 85 MV step passed or was closed by Harold (2026-11-18).

## Carry-ins from the Sprint 85 retrospective (Harold, 2026-11-21)

- Category 13: none (Harold); Claude: the F307 removal above.
- **i1 (live)**: 5.1.2 findings are fixed at 5.1.2 under the 7.7.1 rule; a finding left open is a numbered question
  at the MV handover and is recorded as `5.1.2 open findings: <list> / none` in the plan's MV section.
- **i2 (live)**: 5.1.2 class 3 traces every CHANGELOG line added and the Help page of every changed screen to code,
  as `<claim>: <file:line>` in the F-PRECHECK record.
- **i3 (live)**: a failure that changes what the user sees shows its reason on that screen.
- **i4 (live)**: port cards fill "Error paths" (with a test that runs a real failing command) and "Gates by file
  type".
- **i5 (live, gated)**: "Port of existing code" and "Old name search" lines hold their RESULTS on the line itself;
  close-out check 3d-4 blocks this sprint's close-out otherwise.
- **i6 (live)**: 5.1.9 steps Claude cannot rehearse record `Precondition: <what>: <how checked>`.
- **i7 (live)**: each task's CODING_VELOCITY row gets `Started <date HH:MM>` when the task starts.
- **i8 (tracked)**: a Windows SDK check before a Windows build; propose again if a toolchain update breaks the build.

## Backlog created in Sprint 85 (for Phase 8.4 scope selection)

F358 "All reviewed" shows before any scan has run (from F341 R-6); F359 Android emulator integration test (Priority
40); F360 WinWright runner screen-reader flag restore and the F124 runner-only failure (Priority 42); F361
improvement Effort states its full-suite and CI test time (Priority 38, Harold: top 10 for this sprint); F362
store every question, decision and improvement in full and re-ask an open one in full (Priority 34, Harold
2026-11-22: "Add to backlog for next sprint").

## Open questions

Moved 2026-11-23 to `docs/DECISION_REGISTER.md` (Harold, register d1): questions, decisions and improvements live
there in full, not in a sprint plan. The former q-S85-min is register q1. Open: q1, q2.
