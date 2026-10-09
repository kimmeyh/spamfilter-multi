# Sprint 78 Plan -- STUB (carry-ins from Sprint 77)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 77 carried in.

## Start of sprint (Scrum Master decision MV-Q7 = 2, Sprint 77)

- **0.18.0 store updates** -- build and submit 0.18.0+15 to the Microsoft Store and Google Play closed
  testing, so every Sprint 77 change ships in one update (release notes already re-derived:
  `docs/store-assets/RELEASE_NOTES_0.18.0_windows.md`, `_play.md`).
- **MV76-1 Fold steps 7-11** on the 0.18.0 closed-test build (the steps are in `SPRINT_77_PLAN.md`,
  "Manual Validation steps"), including the per-account "Scan when new mail arrives" trigger on the phone.
- **Boot-time `main()` trace** -- an `app start (foreground)` line was logged at 09:14:39 on 2026-10-07
  with no app opened; trace the boot receiver and the Doze alarm receiver's engine start (MV76-1 step 11).

## Carry-ins from the Sprint 77 retrospective

- Category 13: none from Harold. Claude: only the start items above.
- **First sprint under IMP-1 (5.1.9 MV rehearsal)**: every MV step is rehearsed before handover --
  Flutter tests for UI steps, WinWright only when needed and batched with the 5.1.5 sweep. The F193
  gate requires `- **5.1.9 MV rehearsal**: <evidence>` from this sprint.

## Open items carried

- **0xc0000409 crash** on opening Review No Rule Items (Sprint 77, 2026-10-08 08:59; cause unknown).
  Card only if it recurs (IMP-4); full local dumps go to `%LOCALAPPDATA%\CrashDumps`.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (MV76-1, F282, F283 and the backlog).
