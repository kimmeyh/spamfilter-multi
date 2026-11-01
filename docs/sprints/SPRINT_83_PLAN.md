# Sprint 83 Plan -- STUB (carry-ins from Sprint 82)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 82 carried in.

## Start of sprint

- **0.23.0 store updates** (Phase 8.3 of the Sprint 82 cycle) -- the Microsoft Store MSIX and the Google Play
  closed-test AAB for 0.23.0+20. 0.22.0 was never uploaded, so the 0.23.0 notes cover both
  (`docs/store-assets/RELEASE_NOTES_0.23.0_*.md`). **Rebuild the AAB first**: the 0.23.0+20 AAB built 2026-10-30
  predates the notification-click fix; do not upload it. Serialize the Windows and Android builds.
- **Owner step for the Store build (Phase 8.3)**: on the installed 0.23.0 MSIX, click one background-scan toast with
  the app OPEN and one with it CLOSED, and record both results. Only then may the Windows notes claim the click
  (`msix_config.toast_activator`, prod GUID; argument `-ToastActivated`).

## Manual Validation carried from Sprint 82 (Harold, 2026-10-31)

Harold: *"This can't be done until after this sprint. Can you make this a Manual Validation on the next sprint"*.

- **MV-3 (Fold, 0.23.0 closed test, F319 + F306)**: after the Fold updates (Review No Rule Items top bar shows
  "Version 0.23.0"), with background scanning on: open Review No Rule Items, press Home, wait for a scan notification
  with "No rule" above 0, tap it. Expected: the app comes forward and the list already shows the new item(s), no
  Refresh. A new YELLOW item's pop-up shows "Suggested"; Block Subject and the regex note fit the cover screen with
  no clipping (watch the Skip row). A pass lets the Play notes claim the tap.
- **MV-4 (Fold, Task 4 F303 #524 and Task 7 F315 #527)**: connect the Fold over USB (file transfer); run
  `scripts\pull-phone-screenshots.ps1 -Sprint 83`. Read the `[new-mail-diagnostics]` line from the first start after
  the update AND a later start (no `error:` field). Count no-UID lines ("message has no valid IMAP UID", "FETCH answer
  had no UID"); the same for the S24+ if connected. Windows DEV had 0 in 1,171 `scan/persist` lines.
- **M-6 MV step (7.7.1, Harold Q3 = 3)**: click account 1's notification while that account's background worker is
  still scanning (two processes register the same activation class; which one Windows picks is unverified).
- **MV-5 (iPhone, Tasks 1-3)**: waits on Apple's approval of enrollment `R6QG2A9SHS` (stopping criterion 2). Then
  `docs/IOS_SETUP.md` Parts B-D one at a time, the first TestFlight run, and the F67b device check.

## Carry-ins from the Sprint 82 retrospective

- Category 13 (Claude): the MV-3, MV-4 and M-6 steps above; the 8.3 Store toast click check; the 0.23.0 AAB rebuild.
- **IMP-1 (live)**: the 5.1.2 silent-failure walk covers every language in the diff.
- **IMP-2 (live)**: a test's "does NOT catch" note is checked against what the docs promise; every Manual Validation
  rehearsal line cites its evidence (otherwise NOT REHEARSED).
- **IMP-4 (live)**: a card's "Signal fires on" line names the inputs that mean "could not check".
- **IMP-5 (live)**: the backslash hook also blocks `python -c` with a backslash, in both shells.
- **IMP-6 (live)**: every clock time in a reply or record comes from the clock in the same turn.
- **IMP-7 (live)**: `warn-commit-without-velocity.ps1` warns when a task-closing commit leaves out its velocity row.
- **Standing facts (Harold)**: Fold notification access for the app is ON and stays on. The iCloud DEV account's
  per-account background scan is on, every 5 minutes (re-enabled 2026-10-31).

## Targeted at Sprint 83 (backlog cards)

- **F322** notify only when No Rule is greater than 0 (Harold 2026-10-31, "add to backlog for next sprint").
- **F67a (#509), F304 (#510), F67b (#523)** remainders, when Apple approves.

## Open cards carried

- #509, #510, #523 (iOS, Apple), #524 (F303 Fold check), #527 (F315 phone count). The Sprint 82 PR body lists them
  as "Part of", so the merge leaves them open.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (F303, F315, F322, F323, F324, F67a, F304, F67b and the backlog).
