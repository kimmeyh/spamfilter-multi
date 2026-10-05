# Sprint 76 Plan -- 0.17.0 field issues first (F248, F249, F250), release 0.17.1

**Branch**: `feature/20261004_Sprint_76` | **Version**: 0.17.0+8 -> **0.17.1+9** (PATCH: fixes and
diagnostics only; Play needs versionCode 9) | **Status**: APPROVED 2026-10-04 (see "Phase 3.7 approval")

**Why this sprint is shaped this way.** 0.17.0 went live on both stores on 2026-10-04. The same night the
Fold showed two field defects that no Windows run could have caught, and a third finding made them
undiagnosable: the diagnostic log records no scan or sign-in event at all. Harold: *"Need to work any
issues before choosing backlog"* (Q1), then Q3 = 1 (these three as Sprint 76's first cards), then
*"continue with i-\*"*. Backlog scope selection (Phase 8.4 pass 2) resumes after these ship.

## ADR-0042 applies to EVERY task

Every change is shared Flutter/Dart code unless the card declares an exception. F249 and F250 were found
on Android; each card states whether the defect and the fix exist on Windows too.

## Evidence gathered before planning (2026-10-04, Fold, live 0.17.0 Play build)

Screenshots: `validation-screenshots/sprint-76/Screenshot_20261004_2320*` to `_2348*`.

1. **F238 stop did not stop a stuck AOL background scan** (11:20-11:25 PM): row "In progress", Found 0;
   "Stop the background scan and start mine" at 11:21; at 11:24 "The background scan did not stop ...
   your scan was not started"; at 11:25 still "In progress", Found 0. An earlier AOL row (2:52 PM) was
   closed as "Scan stopped responding". The app stayed honest (no second scan).
2. **Gmail add flow passes, but the account is picked twice** (11:28-11:31 PM): native picker, then a
   Chrome "Sign in with Google" chooser. Harold (Q2 = 1): he tapped the account in the native picker and
   the Chrome page appeared anyway. In code the Chrome page appears only when `_signInNative` THROWS
   (`google_auth_service.dart:573-582`), so native sign-in failed AFTER the pick.
3. **The diagnostic log works but records nothing about scans or sign-in.** Its write sites are 9 calls in
   two files: three IMAP batch failures (`generic_imap_adapter.dart`) and six Results-screen re-process
   and rule-action events (`results_display_screen.dart`). A guaranteed write (opening a saved scan, the
   C-1 "screen-load re-evaluation" line) produced `diag_v0.17.0_2026-10-04.log` at 23:45:50 -- in
   `Documents/diagnostics/diagnostics/`, because the export folder setting had been
   `Documents/diagnostics` (Harold reset it to `Documents`). Not a regression.
4. **The export folder row**: the reset control is a bare X (tooltip only -- invisible on a phone), and
   the row is titled "CSV Export Directory" although it also decides where the diagnostic log and YAML
   exports go.

---

## Task 0 -- Version 0.17.1+9 and its release notes (Phase 3.7.0b)

**Value**: Prevents a dev build reading as production (F190), and gives Play an unused versionCode (9).

**Requirements**:
- R-1: `pubspec.yaml` `version: 0.17.1+9`, `msix_version: 0.17.1.0`.
- R-2: `docs/store-assets/RELEASE_NOTES_0.17.1_windows.md` and `_play.md` exist (PROVISIONAL until
  Phase 7.7), one line per paragraph, Windows text <= 1,500, Play <= 500.

**Affected components / files**: `mobile-app/pubspec.yaml`; `docs/store-assets/`; `docs/STORE_VERSION_STATUS.md` Dev row.

**Acceptance criteria**:
- AC-1: `version_consistency_test`, `dev_version_ahead_test`, `release_notes_test` pass.

**Tests to write**: none new (existing gates).

**Definition of Done**: None -- default DoD only.

**Model**: Opus 5.5 (main session) -- *why not cheaper*: two-line change bundled with the session; no delegation overhead.

**Step-types**: DATA, DOCS | **Est-Effort**: 10-20m

---

## Task 1 -- F248: Diagnostic log records scan lifecycle and sign-in events (Priority 1, Issue #452)

**Value**: This enables diagnosing F249 and F250 (and any future field defect) from a log the user can
hand over, instead of from screenshots, which show state but never cause.

**Requirements**:
- R-1: Every scan -- manual, background (Android WorkManager, Windows Task Scheduler) and Test Background
  Scan -- writes a line at each stage when diagnostic logging is on: worker start/exit (with the task or
  trigger name), early skip (live scan found), claim granted / refused, credential load / connect start,
  connect done (elapsed ms) or failed (error type), each folder fetch start, stop request found by the
  heartbeat and whether the coordinator accepted it, and the outcome (completed with counts / stopped /
  skipped with reason / timed out / error with type).
- R-2: The manual side of F238 writes: stop requested (row id), wait result (closed after N s / not
  closed after N s).
- R-3: Gmail sign-in writes: native `authenticate()` result or failure, `authorizeScopes()` result or
  failure (exception type and message), and whether the browser fallback was taken and how it ended.
- R-4: A line is written when logging is turned ON and at each app start while it is on (version,
  environment, platform), so the file appears immediately and "is logging working" is observable.
- R-5: Every address and account id in these lines is redacted (`Redact.email` / `Redact.accountId`):
  the log is a file the user shares.
- R-6: Settings shows the folder the log is actually written to, under the diagnostic-logging toggle.
- R-7: The export folder row is titled "Export folder" (it governs CSV, YAML and the diagnostic log), and
  its reset control is labeled "Reset to default" in visible text, not an icon alone.
- R-8: If the chosen export folder is itself named `diagnostics`, the log is not nested in a second one.
- R-9: Logging never fails or slows a scan: every call is fire-and-forget (`unawaited`), and a logging
  error is swallowed (existing `DiagnosticLogger` contract).

**Affected components / files**:
- `lib/core/services/diagnostic_logger.dart` -- a `kindScan` / `kindSignIn` / `kindApp` set; an `event()`
  convenience; R-8 path rule; a getter for the resolved folder (R-6).
- `lib/core/services/background_scan_core.dart` -- R-1 stages around `_scanAccountOnce` (lines 242-405).
- `lib/core/services/email_scanner.dart` -- connect (`loadCredentials`, line 218), folder fetch, cancel.
- `lib/core/providers/email_scan_provider.dart` -- claim result; heartbeat stop request (`_honorCancelRequest`).
- `lib/core/services/android_background_scan_worker.dart`, `background_scan_windows_worker.dart` -- worker start/exit.
- `lib/ui/screens/scan_progress_screen.dart` -- R-2 (stop requested, wait result).
- `lib/adapters/auth/google_auth_service.dart` -- R-3 (`_signInNative` 533-586, `_signInDesktop`).
- `lib/main.dart` -- R-4 app-start line; `lib/ui/screens/settings_screen.dart` -- R-4 toggle line, R-6, R-7.

**Existing abstraction checked**: `DiagnosticLogger.log` / `.failure` and its `kind*` constants (extend,
do not add a second logger); `Redact` (reuse).

**Callers of any guard being changed**: none -- logging only; no guard, early return or mode check changes.
- Tooling that launches or kills the same executable: N/A (no process behavior change).

**User-reachable control**: Settings > General > Privacy & Logging: the existing diagnostic-logging
toggle (unchanged) now shows "Writing to: <folder>"; the export folder row's "Reset to default" button.

**Observable behavior -- before / after**: BEFORE: turning logging on and running a scan creates no file;
the export folder row reads "CSV Export Directory" with a bare X. AFTER: turning logging on writes a line
at once; every scan adds lines for each stage; Settings shows where the file is; the row reads "Export
folder" with a "Reset to default" button.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Privacy: R-5 redaction on every new line (no full address, no token, no subject).
- Platform: shared code; both workers instrumented (ADR-0042 -- no exception).
- Concurrency: two isolates/processes may append to one file; lines are single small appends
  (`FileMode.append`). Interleaving at line granularity is acceptable; record it in the doc comment.

**Acceptance criteria**:
- AC-1: With logging on, a background scan (real `BackgroundScanCore.scanAccount` over the demo platform)
  writes start, claim, connect, fetch and outcome lines, in that order.
- AC-2: A stop request found by the heartbeat writes a "stop request found" line and an outcome "stopped" line.
- AC-3: With logging OFF, the same scan writes nothing (no file).
- AC-4: A native sign-in failure writes the failing step and exception type; the fallback writes its result.
- AC-5: No new line contains a full email address (asserted on the test address).
- AC-6 (behavioral UI): Given logging on, When Settings > General is shown, Then "Writing to:" shows the
  resolved folder; Given a chosen export folder, Then "Reset to default" is visible text and clears it.
- AC-7: An export folder named `diagnostics` yields log path `<folder>/diag_v...log`, not `<folder>/diagnostics/...`.

**Tests to write**:
- T-1 (AC-1, AC-3, AC-5) -- TEST-UNIT `test/unit/services/f248_scan_diagnostic_log_test.dart`: real core over the demo platform, read the log file.
- T-2 (AC-2) -- same file: row stop request + heartbeat override (as in `f238_stopped_background_outcome_test`).
- T-3 (AC-4) -- TEST-UNIT `test/unit/adapters/f248_sign_in_diagnostic_log_test.dart`: seam for the native calls; failure step recorded.
- T-4 (AC-6) -- TEST-WIDGET `test/ui/screens/f248_settings_log_location_test.dart`.
- T-5 (AC-7) -- TEST-UNIT in `test/unit/services/diagnostic_logger_test.dart` (existing file).
- Each test carries its "what this does NOT catch" line; each is mutation-checked.

**Definition of Done**: default DoD PLUS: a phone build of 0.17.1 produces a log with scan lines on the Fold (Manual Validation).

**Model**: Opus 5.5 (main session) -- *why not cheaper*: cross-isolate instrumentation in eight files with redaction rules; this session already holds the call-path knowledge from tonight's diagnosis.

**Delegation checklist included in the sub-agent prompt**: N/A (not delegated)

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET | **Est-Effort**: 90-150m

---

## Task 2 -- F249: The F238 stop does not stop a stuck Android background scan (Priority 2, Issue #453)

**Value**: This prevents a background scan that is stuck (Found 0) from blocking the user's own scan of
the account for up to its 5-minute heartbeat window -- the exact situation F238 was built for.

**Requirements**:
- R-1: Diagnose from a 0.17.1 log on the Fold (F248): stuck before the first cancel checkpoint (connect)
  vs. no live worker behind the row (orphaned `in_progress`). Record the cause with the log lines.
- R-2: If stuck in connect: a stop request found by the heartbeat interrupts a scan that has not reached
  its first checkpoint (the connect is raced against the cancel), and the row closes as stopped.
- R-3: If orphaned: the manual side's wait treats a holder whose heartbeat is silent as dead sooner than
  5 minutes -- only with Harold's approval (see interrupt).
- R-4: Whichever applies, the user's scan starts without a second tap once the holder is gone.

**Affected components / files** (final list depends on R-1):
- `lib/core/services/email_scanner.dart` (connect, line 218) and/or `lib/core/services/scan_coordinator.dart`.
- `lib/core/storage/scan_result_store.dart` (`waitForScanToClose`, `heartbeatFreshness`).
- `lib/ui/screens/scan_progress_screen.dart` (`startRealScan` F238 branch).

**Existing abstraction checked**: `ScanCoordinator.requestCancel` / `throwIfCancelled` (F224);
`ScanResultStore.waitForScanToClose` / `claimAccountScan` reaping (Sprint 74-75).

**Callers of any guard being changed**: to be listed in this card BEFORE the change, once R-1 picks the
branch (IMP-1). Candidates: `claimAccountScan` (manual, background, demo, re-process all take it),
`waitForScanToClose` (F238 dialog only), the scanner's connect (every scan type).
- Tooling that launches or kills the same executable: the WinWright runner (pauses dev background tasks; unaffected unless claim timing changes).

**User-reachable control**: Manual Scan > "A scan is already running" > "Stop the background scan and start mine" (existing).

**Observable behavior -- before / after**: BEFORE: with a stuck background scan, "Stop ... and start mine"
waits 90 s and says "The background scan did not stop". AFTER: the stuck scan stops (or is closed) and
the user's scan starts.

**Dependencies / blockers**: Task 1 shipped in a 0.17.1 phone build and one reproduction on the Fold (Harold).

**Non-functional requirements**: Platform -- the fix is shared code; Windows behavior must stay as
validated in Sprint 75 (row 6841 stopped in 22 s).

**Acceptance criteria**:
- AC-1: The cause is named in this card with the log lines that show it.
- AC-2: Given a background scan blocked before its first checkpoint, When a stop is requested on its row,
  Then it stops within one heartbeat plus the connect race and its row reads the stopped-for-manual reason.
- AC-3 (if R-3): Given an `in_progress` row with a silent heartbeat, When the user chooses stop, Then the
  manual scan starts after the approved threshold, not after 5 minutes.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT: a platform whose `loadCredentials` never completes; stop request on the row; assert stopped.
- T-2 (AC-3) -- TEST-UNIT: a holder row with an old heartbeat; assert the wait returns closed at the threshold.

**Definition of Done**: default DoD PLUS: reproduced and fixed on the Fold (Manual Validation).

**Model**: Opus 5.5 -- *why not cheaper*: cross-isolate cancellation with a field-only failure; diagnosis-led.

**Step-types**: SVC-EDIT, TEST-UNIT | **Est-Effort**: 90-180m (after diagnosis)

_**Risk & rollback**_: A stop that interrupts a connect could leave a half-open IMAP session; the race must
still run the scanner's `finally` (release + disconnect). Rollback: revert the race; F238 Windows behavior is unaffected.

_**Decision-class interrupts**_: Class 1/2 if R-3 applies -- shortening when a silent holder counts as
dead changes the Sprint 74 reaping rule (heartbeat > 5 min) that every scan type relies on. Surface with
the log evidence and wait.

---

## Task 3 -- F250: Gmail native sign-in fails after the account pick (Priority 3, Issue #454)

**Value**: This prevents every Android Gmail user from choosing their account twice (native picker, then
Chrome) and from getting the less-integrated browser sign-in.

**Requirements**:
- R-1: Diagnose from a 0.17.1 log (F248 R-3): which call throws (`authenticate()` or
  `authorizeScopes()`), with the exception type and message.
- R-2: Fix the cause so one pick in the native picker completes sign-in -- or, if the cause is on
  Google's side (OAuth client configuration, unverified-app status), record it and surface the console
  change to Harold instead of patching around it.
- R-3: Check what the browser-fallback sign-in stored for `kimmeyh@gmail.com` (a refresh token or not) and
  record it on F246 -- it decides whether Android background renewal is possible on that path.

**Affected components / files**: `lib/adapters/auth/google_auth_service.dart` (`_signInNative` 533-586);
possibly Google Cloud Console (Harold).

**Existing abstraction checked**: `GoogleAuthService.signIn` / `_signInNative` / `_signInDesktop`.

**Callers of any guard being changed**: to be listed once R-1 names the cause. Callers of `signIn`: the
Gmail OAuth add screen, Sign In Again (account list and scan screen), the adapter's scope re-auth.
- Tooling: N/A.

**User-reachable control**: Add Account > Gmail > Google Sign-In; Sign In Again (existing).

**Observable behavior -- before / after**: BEFORE: pick the account in the native picker, then a Chrome
page asks to pick it again. AFTER: one pick, then Google's consent, then "saved".

**Dependencies / blockers**: Task 1 shipped; one Gmail add on the Fold with logging on (Harold).

**Non-functional requirements**: Platform -- Android only (Windows uses the browser flow by design;
declared ADR-0042 exception already in ADR-0011).

**Acceptance criteria**:
- AC-1: The failing call and exception are named in this card from the log.
- AC-2: On the Fold, adding a Gmail account takes one account pick (Manual Validation), or the
  Google-side cause is documented with Harold's console decision.

**Tests to write**: T-1 -- TEST-UNIT with the native seam: the corrected path signs in without falling back
(shape depends on R-1).

**Definition of Done**: default DoD PLUS: Fold validation.

**Model**: Opus 5.5 -- *why not cheaper*: plugin/native diagnosis (memory: trace through plugin source).

**Step-types**: SVC-EDIT, TEST-UNIT | **Est-Effort**: 60-180m (cause-dependent)

_**Decision-class interrupts**_: Class 1 if the fix changes the sign-in mechanism (for example dropping the
browser fallback); a Google Cloud Console change is Harold's.

---

## Task 4 -- Phone validation checklist (carried; Harold at Sprint 75 approval, Q3)

Runs at Manual Validation on the 0.17.1 Play build (validation only, no code):
1. MV74-1 -- background scans fire in Doze; the schedule survives a reboot (over hours) (#428).
2. A block rule added from a saved scan moves the mail; the toast reports N of N (F232 AC-2).
3. F205 -- classify every scan error on the current build, or record zero (#433).
4. The per-account lock under a real Doze batch -- never two `in_progress` rows for one account.
5. The 2-6 minute busy wait against Android's ~10-minute worker limit.
6. Android YAML export saves through the system dialog, starting in the export folder.
7. F238 on the phone -- now F249 (Task 2).
8. F239 Sign In Again on the phone; a background scan more than about an hour after the app was last
   opened skips with "Gmail needs you to sign in again" (#442 closed; check only).
Already done on 0.17.0 (2026-10-04): the Gmail add flow -- PASS, with the double pick now F250.

---

## Sprint summary

- Task 0 -- version 0.17.1+9 -- 10-20m
- Task 1 -- F248 diagnostic log events -- 90-150m
- Task 2 -- F249 F238 stop on Android -- 90-180m (after a phone reproduction)
- Task 3 -- F250 Gmail double pick -- 60-180m (after a phone reproduction)
- Task 4 -- phone checklist -- validation time only

**Total**: 250-530 minutes, plus phone time. **Order**: 0 -> 1 -> build and ship 0.17.1 to Play closed
testing -> Harold reproduces both on the Fold with logging on -> 2 and 3 from the log -> 0.17.2 if they
change code. Tasks 2 and 3 cannot start until the log exists; that wait is a planned external
dependency (Stopping Criterion 2), not a de-scope.

**Not in this sprint until pass 2**: F247, F245, F204 and the rest of the slate presented 2026-10-04.

## Phase 3.6.1 Architecture Impact Check

- ARCHITECTURE.md: the diagnostic log's scope (scan and sign-in events) -- Task 1.
- ADRs: none expected for Task 1; Task 2 may amend ADR-0039 (stop semantics) if R-2/R-3 change them;
  Task 3 may amend ADR-0011.

## Phase 3.7 approval

**APPROVED 2026-10-04 by Harold.** Sequence: Q1 *"Need to work any issues before choosing backlog"*; Q3 = 1
(*"Start Sprint 76 with I-1, I-2 and I-3 as its first cards (0.17.1)"*); then *"continue with i-\*"*.
I-1 = F248 (#452), I-2 = F249 (#453), I-3 = F250 (#454). Class-1/2 items inside Tasks 2-3 are surfaced
when the log names the cause, not pre-approved here.

## Progress (live)

- **Task 0 -- DONE** (014da46): 0.17.1+9; provisional 0.17.1 release notes; gates 22/22.
- **F249 evidence found while testing F248 (2026-10-05, before any phone log)**: with a 20 ms heartbeat,
  the stop request was found and the coordinator ACCEPTED it ("stop-request found on row 1; coordinator
  accepted"), yet the scan fetched two more folders and ended `outcome -- completed found=0`. Mechanism,
  read from code: the only cancel checkpoint is `ScanCoordinator.throwIfCancelled` at a BATCH boundary
  (`email_scanner.dart` ~line 462); there is none between folders, before or after the connect, or while
  a folder's search runs. A scan that has fetched nothing yet -- Found 0, exactly the Fold's 11:20 row --
  cannot see an accepted stop. This is candidate 1 of Task 2, shown in a test; the phone log will say
  whether the Fold's scan was in connect or in a folder search, which decides where the new checkpoints
  and the cancel race go.
- **Task 1 F248 -- DONE**: logger kinds (`SCAN`, `SIGN_IN`, `APP`), `scrub` / `describeError`, R-8 path
  rule; lines from the scanner (start, claim, connect begin/done, folder fetch, outcome), the core (skip,
  busy-retry, needs-sign-in, timeout), both workers (start/exit, awaited at exit so queued lines flush),
  the heartbeat (stop request found, once per change -- a 20 ms beat had queued 77), the manual stop
  (holder, choice, request, wait result), Gmail sign-in steps + fallback (+ whether a refresh token was
  stored, F246), app start, logging turned on. **Added mid-task at Harold's MV74-3 question**: each
  COUNTED scan error is logged with its cause (`scan/error`: folder fetch failure, failed action) -- the
  F205 classification now comes from the same log. Settings: "Writing to:", "Export folder", visible
  "Reset to default", accurate toggle text. Tests: `f248_scan_diagnostic_log_test` 6,
  `f248_log_folder_and_sign_in_test` 3 (R-3 declared SOURCE-TEXT VERIFIED), `f248_settings_log_location_test`
  1. Mutations M128-M137 all KILLED. Suite 2,528 / 15 skipped / 0 failed; analyzer clean.
  Existing abstraction checked: `DiagnosticLogger` (extended); `LiveScanLogger` (not usable: manual-only,
  app-private storage).
- **Task 2 F249 -- PART 1 DONE** (candidate 1, shown by test, no phone log needed): cancel check points
  after the connect, at each folder start and after the last folder (`EmailScanner._cancelCheckpoint`).
  Callers of the checkpoint (IMP-1): every scan type through `scanInbox` (manual, background, test,
  demo); the three cancel sources -- manual Cancel Scan, the F238 heartbeat stop, a timeout's revoked
  lease -- all now stop at these points; exit unchanged (`ScanCancelledException` handler + `finally`).
  Re-process does not use `scanInbox` (unaffected). Tooling: none. Tests `f249_cancel_checkpoints_test` 3
  (stop during connect / during an empty folder / during the last folder); M138-M140 KILLED; suite 2,531 /
  15 / 0. ADR-0039 amended. **Still open (part 2)**: a stop while the connect or a folder search is itself
  BLOCKED (no check point inside one awaited call) and an orphaned row -- decided from the 0.17.1 phone log.
- **F248 extension -- "diagnostic information about ALL scans" (Harold, 2026-10-05: *"We need diagnostic
  information about all scans - do an analysis of what information would be useful and then add to the
  'Write diagnostic log' file"*; Q4 = 1).** Analysis: the questions a field report has to answer, what the
  log said after the first F248 commit, and what was added.
  - *Did the scan run, and which build ran it?* -- had: start / worker start / outcome. ADDED: an `APP`
    line (version, environment, platform) at each background worker start -- a worker is its own
    isolate/process and never wrote the app-start line.
  - *What was the scan working with?* -- had: platform, folder count, days back, mode. ADDED: rules loaded
    (total / enabled) and safe senders (`rules --`), so "matched nothing" can be told from "had no rules".
  - *Where did the time go, and what did each folder return?* -- had: folder begin. ADDED: per-folder
    `done: N emails in Ms`, and the fetch PATH per folder (`fetch-path`: Gmail incremental / Gmail full and
    why / history cursor EXPIRED fallback / IMAP full / IMAP backlog re-scan from UID), plus total scan
    duration on the outcome line.
  - *What did it do to the mailbox?* -- had: counts. ADDED: the plan (`actions --`: mode, whether rules
    and safe senders may execute, planned delete / move-to-junk / safe-sender move, target folder) and each
    batch's result (`action-result --`: N succeeded, N failed; or the batch failing entirely).
  - *What did it store?* -- ADDED: `scan/persist` -- action records and No Rule rows added per scan (the
    F245 growth, measurable per run).
  - *Why did a scan get closed or skipped?* -- had: skip, busy retry, refusal, timeout, stop. ADDED: the
    claim REAPING a dead holder (`scan/claim -- reaped dead <type> row N: started Ns ago, last heartbeat
    Ns ago` -- F249 candidate 2) and startup reconciliation (`scan/reconcile`).
  - *What happened after the scan?* -- ADDED: `scan/post` -- export and notification ran, or why not.
  - *Gmail token health* -- had: native sign-in steps. ADDED: `gmail/token` -- an account being marked
    "needs you to sign in again", and a refused token renewed without the user.
  - *Rule actions from Results (Q4)* -- had: failures only. ADDED: every run's outcome -- read-only preview
    (would delete / would move), nothing to act on, or `acted on N of M (failed F)` with the mode.
  - *Deliberately NOT added*: network type and battery/Doze state (needs a new plugin call inside the
    WorkManager engine -- a risk on the path being diagnosed); per-email lines (volume, and a sender or
    subject must never be written). Privacy unchanged: addresses redacted, no subject/body/token.
  - Found while testing: `DiagnosticLogger._enabled()` never cached what it read, so every log call was a
    database query. Now cached (the toggle already invalidates it). Tests: +2 behavior tests, +1 source
    gate (Q4); M141-M147 KILLED; suite 2,534 / 15 / 0.
- **Harold, 2026-10-05**: *"can you confirm if we have completed these 2 items (MV74-1, MV74-3) ... if
  not, can we do them next as part of this sprint"*. Not complete (both need a phone build). They move
  UP: they run on the 0.17.1 build together with the F249/F250 reproductions -- MV74-3 now has per-error
  causes in the log, MV74-1 has worker start/exit lines that show each Doze firing.
