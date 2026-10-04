# Sprint 76 Plan -- STUB (scope not yet selected)

**Status**: **STUB -- NOT PLANNED, NOT APPROVED.** Created at Sprint 75 Phase 7.7 to hold the
carry-ins. Planning (Phase 3) replaces this file.

## Committed by Harold at Sprint 75 approval (Q3)

*"Can't run until 0.17.0 goes live (next sprint)"* -- the phone validation checklist runs in Sprint 76,
on the live 0.17.0 phone build (S24+ / Fold8; no adb -- screenshots over MTP into
`validation-screenshots/sprint-76/`).

- **Phone validation checklist**:
  1. MV74-1 -- background scans fire in Doze; the schedule survives a reboot (over hours) (#428).
  2. A block rule added from a saved scan moves the mail; the toast reports N of N (F232 AC-2).
  3. F205 -- classify every scan error on the current build, or record zero (#433).
  4. The per-account lock under a real Doze batch -- never two `in_progress` rows for one account.
  5. The 2-6 minute busy wait against Android's ~10-minute worker limit.
  6. Android YAML export saves through the system dialog, starting in the export folder.
  7. F238 -- "Stop the background scan and start mine" on the phone (#441).
  8. F239 -- Gmail "Sign In Again" on the phone; a background scan more than about an hour after the
     app was last opened skips with "Gmail needs you to sign in again" (expected: the renewal spike
     failed, see F246) (#442).

## Carry-ins from the Sprint 75 retrospective (Category 13)

- None (Harold and Claude). The checklist above was already planned at Sprint 75 approval.

## Backlog candidates (for scope selection)

- F246 server-side Gmail token exchange (Class-1, needs a backend); F245 no duplicate No Rule rows
  from repeated background scans; F244 notify on a needs-sign-in skip; F240 body-rule sub-types;
  F241 unused query; F242 span-replacing edit scripts.

## Process notes

- Sprint 75 retro IMP-6: every coding sub-agent prompt carries the delegation checklist
  (`docs/SPRINT_PLANNING.md`), and the card records that it was included.
- Sprint 75 retro IMP-4: tooling that launches or kills the exe (WinWright runner, pre-build cleanup)
  is listed under the card's "Callers" field.
- `scripts/mutation-test.ps1` now runs a baseline and reports a compile error as INVALID (IMP-1).
