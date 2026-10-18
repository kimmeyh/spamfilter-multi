# Sprint 79 Summary

**Dates**: 2026-10-13 to 2026-10-18
**Branch**: `feature/20261013_Sprint_79` | **PR**: #480 -> develop
**Version**: 0.20.0+17 (bumped at plan approval)
**Suite**: 3,011 -> 3,088 passed (15 skipped, 0 failed, `run-full-suite.ps1`) | Analyzer clean | WinWright 2/2 at
`80d92c6`

## What this sprint was for

Finish the phone checks on the 0.19.0 closed-test build (MV76-1, F277, MV-7, the Gmail `invalid_grant` cause,
Android parity of F281-F283, the AOL scans that died mid-scan). Make the background-scan notification name its
account on Android and add the same notification on Windows. Make `develop` the default branch. Let a locked-PC
WinWright sweep count. Find why full-suite test processes die or hang. Every card stated Windows + Android parity or
declared an ADR-0042 exception.

## Delivered

- **F286 (#482)** -- the Android notification names the account (`Back. scan k*@aol completed`), lists "No rule"
  first, one per account; a read-only or partial scan names its mode and strikes through what it did not do.
- **F287 (#483)** -- Windows shows the same notification through the same notifier (flutter_local_notifications
  22.3.2; ADR-0048 supersedes ADR-0018).
- **F288 (#484)** -- `develop` is the GitHub default branch, so `Closes #N` closes cards on merge; releases are
  tagged on main.
- **F291 (#485)** -- a WinWright sweep on a locked PC runs every non-mouse step and counts as complete.
- **F293 (#487)** -- backlog refinement shows the next 20 in one order, details in the same order.
- **F297 (#488, added 2026-10-14)** -- rules and safe senders reload after a YAML import, through one shared reload.
- **F292 (#486)** -- `scripts/run-full-suite.ps1` (stall watchdog, containment); cause still unknown.
- **Task 1 (#471), in-sprint part** -- MV-7: the periodic Android run skips a recently scanned account, and a run
  that waited for another scan checks again; IMAP commands get a 120 s response limit, and one timeout ends the
  session and the scan (7.7.1 Q2); every schedule change is logged on both platforms with the step that asked for
  it (with a note when the Doze alarm did not arm or cancel); workmanager 0.10.10, so the
  worker stop line fires with AndroidX reason names (`reason=timeout raw=3` on the emulator).

## Not delivered, and why

- **MV76-1 phone remainder, F277 arms A and C and the decision rule, F292 post-reboot runs** -- moved to Sprint 80
  by Harold (2026-10-16: "move any other tasks for execution to the backlog for next sprint").
- **Fix 2 (native debug hook)** -- decided after the 0.20.0 phone test shows the new stop line (Harold, Fix = 1).

## What went right

- Both Manual Validation steps passed on the first round; the rehearsal found the DEV toast setting off and turned
  it into a precondition.
- The stop-handler question was settled with evidence: plugin source, AndroidX numbering, and a forced timeout on
  the emulator.
- The first true F277 arm-A night ran cleanly: 20 AOL scans at 15 minutes, all completed, app at 0% battery.

## What cost time

- Task 1 ran about 310 minutes against 60-110, mostly the stop-handler hunt; one wrong turn came from a plugin
  claim taken from the changelog (retro IMP-3).
- Two planned F277 nights ran in the wrong arm (the AOL interval was not checked before the night).
- Velocity rows were written at Phase 5, so the evidence gate blocked the first Manual Validation handover.
- The MV-1 step stated a 20-minute task interval; the trigger reads 5 minutes (retro IMP-1).

## Manual Validation

Windows DEV 0.20.0 at `80d92c6`: MV-1 PASS (four toasts, one per account, each with its own tag; Gmail's replaced
under the same tag); MV-2 PASS (Review No Rule chip 116, limit 119). Phone items wait for the 0.20.0 release (Q9 =
2). Complete per Harold (2026-10-18).

## Retrospective

Harold: all 12 rated categories Very Good; no carry-ins, no backlog items, no questions.
- IMP-1 applied: 5.1.9 reads every fact in an MV step from the live system and names the source.
- IMP-2 applied: the phone pull collects Samsung Battery and App info screenshots; `-SelfTest` added.
- IMP-3 applied: a claim about a package's behavior cites its source at the resolved version (CLAUDE.md).
- IMP-4 skipped.
- 7.7.1 final code reviews (Copilot, code-reviewer, silent-failure-hunter): see `SPRINT_79_PLAN.md`.

## Carry-forward

- **Sprint 80 start**: 0.20.0 store builds; the MV76-1 phone remainder; F277 arm A (second night) and arm C, the
  decision rule and the 0.3% versus 1.5% B-night spread; F292 post-reboot runs; the Fix 2 decision.
- **Backlog targeted at Sprint 80**: F294, F295, F296, F298; F299 in the backlog.
