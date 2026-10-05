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

## Device finding on the live 0.17.0 Play build (2026-10-04, Fold, before planning)

**F238 stop did NOT work on the phone.** Screenshots `validation-screenshots/sprint-76/Screenshot_20261004_2320*.png`
to `_2325*.png`: an AOL background scan started 11:20 PM sat "In progress" with Found 0; "Stop the
background scan and start mine" at 11:21 ended at 11:24 with "The background scan did not stop ... your
scan was not started"; at 11:25 the row was still "In progress", Found 0. An earlier AOL background row
(2:52 PM) had been closed as "Scan stopped responding". The app behaved honestly (no second scan).

**Cause NOT established** -- two candidates, which the diagnostic log separates:
1. The worker is blocked BEFORE its first cancel checkpoint (connect/login). The heartbeat finds the
   request and calls `ScanCoordinator.requestCancel`, but `throwIfCancelled` runs only at batch
   boundaries, so a hung connect is never interrupted. Windows validation stopped a scan that was
   already fetching, which is why it passed there.
2. No live worker holds the row (an orphaned `in_progress` row) -- nothing can honor the request, and
   the row is only reaped once its heartbeat is 5 minutes stale.

**Settle it first**: Settings > diagnostic logging ON on the Fold, reproduce (background scan stuck at
Found 0, then the stop), export the log in-app, pull over MTP. Then card the fix (likely a cancel/timeout
around connect, or a stale-heartbeat close in `waitForScanToClose`) as a Sprint 76 item.

**CORRECTION (same night)**: the diagnostic log CANNOT settle this as the app stands. Its only write
sites are rule re-processing (`results_display_screen.dart`) and three IMAP batch problems
(`generic_imap_adapter.dart`) -- no worker start, claim, connect, heartbeat, stop-request or outcome
event is logged. The Fold's logs confirm it: `Documents/diagnostics/` holds only `diag_v0.16.0_*`
files (last 10/02), all re-process lines. **Fix first**: add scan-lifecycle events to the diagnostic
log (both workers and the manual path), THEN reproduce.

## Gmail add flow on the live 0.17.0 Play build (2026-10-04 23:28-23:31, Fold)

`Screenshot_20261004_2328*` to `_2331*`: Gmail Setup dialog (Sprint 75 wording) -> Sign In Method ->
Google Sign-In -> native account picker (Google Play services) -> **Chrome "Sign in with Google"
account chooser** -> "Google hasn't verified this app" (expected: OAuth app in testing; GP-4 HOLD) ->
signing back in -> consent ("already has some access") -> "[OK] Account kimmeyh@gmail.com saved
successfully" on Manual Scan -> read-only live scan complete (4s) -> Back to Accounts -> the account
list now shows the Gmail account. **The Sprint 75 add-flow fix PASSES on the phone.**

**Finding -- the account is chosen TWICE.** In code (`google_auth_service.dart:577-581`) the Chrome
page appears only when `_signInNative` THROWS -- from `authenticate()` or `authorizeScopes()` -- and
falls back to `_signInDesktop`. So native sign-in failed on the Fold and the browser fallback did the
real sign-in (Sprint 75 review SF-12 named this path as unverified). Which call threw is NOT known:
`Redact.logError` goes to logcat, unreachable without adb. Worth knowing for F246: the browser PKCE
path may store a refresh token where the native path does not -- unverified; check what this
account's saved tokens contain.

## Carry-in from the PR #448 reviews

- **F247** -- behavior tests for navigation and platform-gated paths (startRealScan F238 branches, the
  Gmail add-flow route and its fallback screens, Windows token-path tests on CI, the Android
  `initialize` exception path, Sign In Again details, a mutation-test self-test). Full card in
  `ALL_SPRINTS_MASTER_PLAN.md`.

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
