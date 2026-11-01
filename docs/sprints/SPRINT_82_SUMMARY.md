# Sprint 82 Summary

**Dates**: 2026-10-27 to 2026-10-31
**Branch**: `feature/20261027_Sprint_82` | **PR**: #521 -> develop
**Version**: 0.23.0+20 (bumped at plan approval; MINOR, F306 is a user-facing `feat`; 0.22.0 was never uploaded, so
the 0.23.0 store notes cover both)
**Suite**: 3,287 -> 3,360 passed (15 skipped, 0 failed) | Analyzer clean | Hook suite 162/162 | WinWright 3/3
(2026-10-30, with the new F320 script)

## What this sprint was for

Get the iPhone app onto TestFlight (F67a, F304, F67b). Fix the highest-risk open bug: the Gmail history cursor moved
before the mail was evaluated (F314). Count the evidence for two suspected defects before fixing them (F312, F315).
Build the first No Rule suggestion (F306) on counted signals (F305). Make the No Rule list refresh when the user
comes back from a notification (F319). Close three process gaps (F317, F318, F320). Every card named its Windows,
Android and iPhone paths (ADR-0042, ADR-0049, ADR-0050).

## Delivered

- **F306 (#528)** -- the No Rule pop-up marks one rule as "Suggested" (Block Entire Domain, or Block Email for a
  common provider) when sender authentication did not fully pass, with the exact regex and the reason; stored at scan
  time (schema v17); never a safe sender for a failed check. Block Body and the split row moved to F323 (F306 v2).
- **F314 (#525)** -- the Gmail history cursor moves only after the folder's results are stored. 7.7.1 H-1 extended
  it: when the results cannot be stored, the cursor stays and the scan screen says "Scan complete, but its results
  could not be saved. The next scan checks these emails again."
- **F319 (#529)** -- the No Rule list reloads when the app returns to the foreground. Manual Validation found that a
  Windows notification click did nothing (MV-1 FAIL); fixed: a click brings the window forward and opens Review No
  Rule Items, with the app open (MV-1b PASS) and, on the DEV build, closed (MV-1c PASS). A click never closes a dialog
  or a screen whose text field holds text (7.7.1 M-5).
- **Task 6 (#526)** -- the read-only header probe: F305 signals counted; F312 closed with its counts (196 matched,
  0 differing, 1 foreign authserv-id that Harold explained as forwarded mail).
- **F320 (#530)** -- a WinWright script covers Review No Rule Items (13 steps).
- **F318 (#531)** -- the 7.7.1 toolkit prompt lists every changed file; reports state files read.
- **F317 (#532)** -- delegated agent work survives a usage limit and restarts where it stopped.
- **Version (#522)** -- 0.23.0+20.

## Not delivered, and why

- **F67a (#509), F304 (#510), F67b (#523)** -- wait on Apple's approval of enrollment `R6QG2A9SHS` (stopping
  criterion 2, external). The signed `ios-testflight` job is written; its first run needs Harold's Parts B-D.
- **F303 Fold check (#524) and F315 phone count (#527)** -- moved to Sprint 83 Manual Validation MV-4 by Harold
  (*"This can't be done until after this sprint"*): the phones need the 0.23.0 closed-test build. Windows DEV had 0
  no-UID messages in 1,171 `scan/persist` lines.
- **MV-3 (Fold F319 + F306)** -- moved to Sprint 83 for the same reason.

## What went right

- The 7.7.1 reviews ran before the retrospective again, and the retrospective worked from finding classes; six of
  seven improvements were applied the same day, and IMP-3 was replaced by Harold's broader F321.
- Evidence came before fixes: F312 closed on counts instead of a speculative parser change; F315's Windows count is 0.
- Every new test was mutation-verified, including the hooks (VEL-a/b/c, IMP5 a-d, tap M5 a-e and M5b a-d KILLED).
- The new velocity hook found its own false warning on its first live use; fixed with test case allow-8.

## What cost time

- MV-1 handed over a step whose click mechanism was asserted, never checked (`main.cpp` single-instance hand-off);
  the click did nothing. Root cause: the notification plugin registers the activator only in the calling process, and
  only the short-lived worker registered. Class recorded under Sprint 75 IMP-5; IMP-2 now requires rehearsal evidence.
- A build-script swap guard read `.Count` on a single CimInstance (PowerShell 5.1) and skipped the stop; fixed with
  `@(...)` at three sites.
- A re-added iCloud account silently lost its background scanning; the skip reached only the log (F324).
- Inline `python -c` with backslashes ran in both shells; the hook now blocks both (IMP-5).

## Manual Validation

Windows DEV 0.23.0: MV-1 FAIL -> fixed; MV-1b PASS (a real click on a "2 No rule" AOL toast opened an updated Review
No Rule Items); MV-1c PASS (click with the DEV app closed); MV-2 PASS (F306 "Suggested" on Block Entire Domain; Block
Body split -> F323). MV-3 and MV-4 moved to Sprint 83; MV-5 waits on Apple. Complete per Harold.

## Retrospective

Harold: all categories Very Good; none for 13, 14 and questions.
- IMP-1 applied: the 5.1.2 silent-failure walk covers every language in the diff.
- IMP-2 applied: a "does NOT catch" note is checked against the promises; rehearsal lines cite evidence.
- IMP-3 not done: replaced by F321 (Python conversion). Fact recorded: the hooks run Windows PowerShell 5.1.
- IMP-4 applied: "Signal fires on" names the "could not check" inputs.
- IMP-5 applied: the backslash hook blocks `python -c` in Bash and PowerShell.
- IMP-6 applied: clock times come from the clock in the same turn.
- IMP-7 applied: a hook warns when a task-closing commit leaves out its velocity row.
- 7.7.1 final code reviews, improvement review and CI: see `SPRINT_82_PLAN.md` "Phase 5 evidence".

## Carry-forward

- **Sprint 83**: 0.23.0 store release (AAB rebuild; Store toast click owner step); MV-3, MV-4, the M-6 click step;
  F322; iOS Tasks 1-3 when Apple approves.
- **Backlog**: F305 R-2, F307 (Sprint 86), F308-F311, F313, F316, F321, F323 (F306 v2), F324.
