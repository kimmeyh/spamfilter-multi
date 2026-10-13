# Sprint 79 Plan -- STUB (carry-ins from Sprint 78)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 78 carried in.

## Start of sprint (Harold, 2026-10-13: "push any further testing to next sprint")

- **0.19.0 store updates** -- the Microsoft Store MSIX and the Google Play closed-test AAB for 0.19.0+16
  (Phase 8.3 of the Sprint 78 cycle). The phone items below run on that closed-test build.
- **MV76-1 Fold steps 8-11** (#471, with #433 F205 and #428 MV74-1): Step 9 needs Notification access for AOL
  (the 0.18.0 logs show no `trigger=notification` scan); iCloud background scanning is OFF on the Fold (turn it on
  if iCloud should be covered); the boot-time `main()` trace.
- **F277 Fold energy check** (#472): all three runs on 0.19.0 with ONE account on. Before reading a battery
  screenshot, confirm the run with `scripts/phone-log-health.ps1 -Path <log> -Since <start> -IntervalMinutes <n>
  -SingleAccount` (Sprint 78 IMP-2).
- **MV-7 on the phone** -- the Doze alarm skips an account scanned within two-thirds of its interval;
  `phone-log-health.ps1` should show no double-scheduling FLAG.
- **Gmail `invalid_grant` on the Fold** (2026-10-12 17:27) -- cause unverified (possibly the Google "Testing"
  refresh-token expiry; check the OAuth consent screen publishing status).
- **Android parity of F281, F282, F283** on 0.19.0.
- **10 AOL background scans that died mid-scan** on Oct 10-12 (found by IMP-2; for example row 1900 stopped after
  its rules step and was reaped 576 s later). Cause unknown; one candidate is the WorkManager run limit (F263,
  unverified).

## Carry-ins from the Sprint 78 retrospective and 7.7.1 reviews

- Category 13: none from Harold. Claude: the start items above.
- **IMP-1 gates now live**: the F193 Manual Validation gate requires one CODING_VELOCITY.md task row per task card
  (planning rows do not count) from this sprint; every `Executed-by` line needs minutes.
- **Targeted at Sprint 79 in the backlog**: F291 (WinWright sweep on a locked PC counts as complete), F292
  (intermittent test-process failures in the full suite), F286 (notification text), F288 (git-flow default branch).

## Open items carried

- **0xc0000409 crash** on opening Review No Rule Items (Sprint 77): did not recur in Sprint 78; card only if it
  recurs.
- **Sprint 78 sweep not re-run** after the 7.7.1 fixes (Harold, Q1 = 2); the first Sprint 79 sweep covers them.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (MV76-1, F277, F286, F288, F291, F292 and the backlog).
