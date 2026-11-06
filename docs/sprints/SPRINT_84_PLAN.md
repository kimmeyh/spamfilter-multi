# Sprint 84 Plan -- STUB (carry-ins from Sprint 83)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 83 carried in.

## Start of sprint

- **0.24.0 store updates** (Phase 8.3 of the Sprint 83 cycle) -- the Microsoft Store MSIX and the Google Play
  closed-test AAB for 0.24.0+21 (`docs/store-assets/RELEASE_NOTES_0.24.0_*.md`, updated 2026-11-05 for the 7.7.1
  decisions; the Play block is exactly 500 characters). Build from HEAD of `main` after the merge, so the AAB carries
  the 7.7.1 fixes. Serialize the Windows and Android builds.
- **Android notification channels**: 0.24.0 creates "Every Completed Scan" and "One or more No Rule Items" and deletes
  `background_scan_channel`. After the Play update, check on the Fold that Settings > Apps > the app > Notifications
  shows the two channels.

## Manual Validation carried from Sprint 83 (Harold, 2026-11-04, Q3 = 1)

- **MV-3c (Fold, YELLOW item)**: when a YELLOW No Rule item appears on the Fold, open its pop-up. Expected: one rule
  is marked "Suggested", and Block Subject, the regex note and the Skip row fit the cover screen with no clipping.
  Until then it is not testable: the only No Rule item seen was RED ("Sign-in check failed").
- **MV-5 (iPhone, Tasks 1-3)**: waits on Apple's approval of enrollment `R6QG2A9SHS` (stopping criterion 2). Then
  `docs/IOS_SETUP.md` Parts B-D one at a time, the first TestFlight run, and the F67b device check.

## Carry-ins from the Sprint 83 retrospective

- Category 13: none (Harold and Claude).
- **IMP-1 (live)**: every card that adds a new caller of a user action, a new list or a new pattern carries
  "Existing code reused: `<function or constant>`"; 5.1.2 class 1 checks the code calls it, class 7 checks each test's
  name against its checks.
- **IMP-2 (b) (live)**: an MV answer that renames or changes a behavior records `Swept: grep '<old text>' -> N hits
  fixed`.
- **IMP-3 (live)**: a script, hook or tool never reports success when it did nothing or what it ran crashed
  (`scripts/test-hook.ps1` is the model; 5.1.2 question 6).
- **IMP-4 (live)**: every delegated agent's progress file records `RUN STARTED` / `RUN STOPPED <yyyy-mm-dd HH:MM>`
  from the clock; `agent-work-status` adds them up.

## Backlog created in Sprint 83 (for Phase 8.4 scope selection)

F341 F325 part B live first-run run; F342 Fold background log errors; F343 F309 trusted-sender hint decision; F344
prompts as Python tools; F326-F340 Python conversion batches and audits.
