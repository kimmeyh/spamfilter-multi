# Sprint 75 Plan -- STUB (scope not yet selected)

**Status**: **STUB -- NOT PLANNED, NOT APPROVED.** Created at Sprint 74 Phase 7.7 to hold the
carry-ins. Planning (Phase 3) replaces this file.

## Committed by Harold at Sprint 74 Manual Validation

- **F238 (Issue #441) -- "Stop the background scan and start mine"**. RELEASE BLOCKER for 0.17.0.
  Model: **Fable 5.1** (Harold). Full card on the issue (R-1..R-6, AC-1..AC-4, T-1..T-4, DB v11,
  Class-1 interrupt to confirm at approval).

## Carry-ins from the Sprint 74 retrospective (Category 13)

- **Manual Validation device checklist** (0.17.0-or-later phone build, Fold8), moved from Sprint 74
  because no AAB is built until both PRs merge:
  1. MV74-1 -- background scans fire in Doze; the schedule survives a reboot (over hours).
  2. Task 7 AC-2 -- a block rule added from a saved scan moves the mail; the toast reports N of N.
  3. F205 -- classify every scan error on the current build (or record zero).
  4. The per-account lock under a real Doze batch -- never two `in_progress` rows for one account.
  5. The 2-6 minute busy wait against Android's ~10-minute worker limit.
  6. Android YAML export saves through the system dialog.
- **WinWright scripts for new UI with none yet**: Sort chip, "A scan is already running" dialog,
  Scan History Clear history, "Hide sender details in exports", resolved-default folder rows.
- **Widget tests for the same controls** (PR #440 test review, MINOR 5/7/8/9 -- grouped here with
  the WinWright scripts because they cover the same UI): (5) the Results "another scan is running"
  row uses the info style, never the error style (`wasRefused` branch before `hasError`); (7) the
  Manual Scan OK-only dialog and the refusal snackbar; (8) tapping "Hide sender details in exports"
  persists `getExportRedacted()`; (9) Clear history's zero-finished snackbar and scope text.

## Backlog candidates (for scope selection)

- F239 (#442) Gmail headless renewal + "Sign In Again"; F240 body-rule sub-types; F241 unused query.

## Process notes

- New card template line (Sprint 74 retro IMP-1): "Observable behavior -- before / after" is
  mandatory for any card that changes what a user sees.
- No AAB until the Sprint 74 and Sprint 75 PRs are both merged (Harold, 2026-09-27).
