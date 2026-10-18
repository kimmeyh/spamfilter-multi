# Sprint 80 Plan -- STUB (carry-ins from Sprint 79)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 79 carried in.

## Start of sprint (Harold, 2026-10-16: "move any other tasks for execution to the backlog for next sprint")

- **0.20.0 store updates** -- the Microsoft Store MSIX and the Google Play closed-test AAB for 0.20.0+17 (Phase
  8.3 of the Sprint 79 cycle). Release notes were re-derived at Sprint 79 Phase 7.7. The phone items below run on
  that closed-test build. Also confirm 0.19.0 went live on both stores (submitted 2026-10-13, not yet observed).
- **Fix 2 decision** -- after the 0.20.0 build is on the Fold, look for `stopped by WorkManager before it finished:
  reason=... raw=...` in the diagnostic log; Harold then decides whether the native debug hook (Fix 2) is needed.
- **MV76-1 phone remainder** (#471, with #433 F205 and #428 MV74-1): the step 8 Background note screenshot; step 9 /
  F253 AC-5 new-mail trigger (no `trigger=notification` scan yet although Notification access is allowed); step 11
  reboot half (#428) and the F250 Google account screenshot; R-3 boot-time `main()` trace; R-4 one completed iCloud
  background scan; the F283 Android screenshot; the class-B cause (F299).
- **F277 Fold energy check** (#472): arm A has one night (10-17/18, 4.2 h, app 0%; `SPRINT_79_PLAN.md` Task 2
  night log); a second, 8-hour arm A night, then arm C (new mail on), then the decision rule. Explain the 0.3% versus
  1.5% spread between the two arm-B nights. Before each night, check the last pulled log shows the planned AOL
  interval and new-mail setting.
- **F292 post-reboot runs** (#486): three or more `run-full-suite.ps1` runs after a reboot; the page file did not
  grow.

## Carry-ins from the Sprint 79 retrospective

- Category 13: none from Harold or Claude.
- **IMP-1 (live)**: every number, interval, path or count in an MV step is read from the live system during the
  5.1.9 rehearsal, and its source named.
- **IMP-2 (live)**: the default phone pull collects `_Device care` and `_Settings` screenshots.
- **IMP-3 (live)**: a claim about a package's behavior cites its pub-cache source at the resolved version.
- **Targeted at Sprint 80 in the backlog**: F294 (one platform-capability seam), F295 (iPhone readiness research),
  F296 (CI Flutter version), F298 (rule edits reload the in-memory rules). F299 (record the Android process exit
  reason) is in the backlog.

## Open items carried

- The dev app on the emulator still has the 60 s diagnostic hold until the next dev build installs over it.
- The s75 WinWright launch failed once in the Sprint 79 full sweep and passed alone; cause unknown (candidate: the
  single-instance mutex). Watch the next sweep.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (MV76-1, F277, F292, F294-F299 and the backlog).
