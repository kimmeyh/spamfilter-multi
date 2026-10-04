# Sprint 75 Summary

**Dates**: 2026-10-02 to 2026-10-04
**Branch**: `feature/20261002_Sprint_75` | **PR**: #448 -> develop
**Version**: 0.17.0+8, no bump (exception: no store release after Sprint 74, Harold 2026-10-02). The
0.17.0 RELEASE HOLD is satisfied: F238 shipped.
**Suite**: 2,417 -> 2,508 (15 skipped) | Analyzer clean | WinWright 3/3 (at `7e807d5`) | Hook suite 83 -> 91

## What this sprint was for

Ship F238, the 0.17.0 release blocker: a way to stop a running background scan in favor of a manual
one. Alongside it: F239 (Gmail renewal on Android plus "Sign In Again"), four small cards (F216, F214,
F236, F215) and the Sprint 74 test carry-ins (Task 7). Every task carried ADR-0042.

## Delivered

- **F238 (#441)** -- the "A scan is already running" dialog offers "Stop the background scan and
  start mine". The request is written to the scan row (`cancel_requested_at`, DB v11, Class-1
  approved); the background scan sees it on its heartbeat, stops, and records a stopped skip -- no
  export, no "scan complete" notification, no busy retry. Scan History shows the reason.
- **F239 (#442)** -- "Sign In Again" on the account list and the scan screen; it signs in the same
  account and refuses a different one. A background scan that needs sign-in is skipped with that
  reason; on Windows it no longer opens a browser unattended (development-decision change, approved).
  Token lookups always use the scanned account (a real cross-account bug fixed).
- **F243 (#450, added at Manual Validation)** -- Windows background scans run while the app is open;
  the per-account claim decides, as on Android.
- **F216** supporting text sizes; **F214** slider alignment; **F236** app version in YAML exports (both
  write paths); **F215** validation-screenshot folder wired into the process docs and
  `scripts/pull-phone-screenshots.ps1`; **Task 7** WinWright script and widget tests for the Sprint
  74-75 controls.
- **Manual Validation fixes**: "Scan not started" header and a reachable refusal row; the YAML save
  dialog starts in the export folder; adding a Gmail account finishes like AOL/Yahoo; the Gmail Setup
  sentence.

## Not delivered, and why

- **Android Gmail renewal without the app open (F239 R-1/R-2)** -- the emulator spike FAILED:
  `clientAuthorizationTokensForScopes` returned NULL from the WorkManager isolate for a granted account.
  Per R-6, R-2 was not built. Harold chose the server-side route as backlog (F246, "1.3").
- **Phone checks** (MV74-1, F205, live deletion from a saved scan, Doze lock, Android YAML export,
  F238/F239 on the phone) -- they need the live 0.17.0 build; moved to Sprint 76 (Q3 at approval).
- **Cause of the red "Failed to queue the test scan" message** -- not established; no log line was
  written.

## What went right

- The release blocker passed Manual Validation on its first round (manual scan started 22 s after
  the stop request).
- The spike gate worked: R-6 stopped the build at a measured FAIL instead of shipping an unproven
  renewal path.
- New tests caught a half-wired fix (the refusal row was gated, its parent block was not).

## What cost time

- The 5.1.1 review found a HIGH: the per-folder catch swallowed the new sign-in exception (retro IMP-3).
- Two mutants that did not compile were counted KILLED (retro IMP-1).
- Shell mechanics: a bare `cat >` hung twice; a heredoc ate the backslashes in a JSON spec (IMP-2).
- F243 let background scans run during the WinWright sweep; found at the fourth sweep (IMP-4).
- The Haiku batch's output needed about 35 minutes of rework (IMP-6).

## Manual Validation

Windows: all steps PASS across four rounds (F214, F216, F236, F238, F243, the four MV fixes).
Emulator: Gmail add flow and Sign In Again PASS; the F239 R-1 spike FAIL recorded.

## Retrospective

Harold: all 14 categories Very Good; no carry-ins, no backlog items, no questions. Improvements
IMP-1 to IMP-6 approved ("do now") and applied: mutation-test baseline and INVALID verdict; the
heredoc guard extended to double backslashes and a bare `cat >`; the swallow-class walk when ADDING
an exception; tooling counted as a caller; Manual Validation steps traced to the code; one delegation
checklist for every coding sub-agent.

## Carry-forward

- **Sprint 76**: the phone validation checklist (stub: `SPRINT_76_PLAN.md`).
- **Backlog**: F244 (notify on a needs-sign-in skip), F245 (no duplicate No Rule rows), F246
  (server-side Gmail token exchange), plus F240, F241, F242.
