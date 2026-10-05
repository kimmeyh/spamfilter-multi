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

## Scope added 2026-10-05 (Harold, after the unattended-scanning analysis)

Harold: *"Generally the app makes no sense if it can't run without the user going to the app"*, then
*"we are ONLY wanting to do the same thing that the email app currently does - periodically wake up, scan
for new emails, update the app and go quit again"*, then *"yes, lets plan option 1 for this sprint (full
card...) q2. 1 q3 1"*. Option 1 = the notification-listener trigger (Task 6); Q2 = 1 = the Option A
measurement steps now, in 0.17.3 (Task 5); Q3 = 1 = a home-screen widget card to the backlog (F254).
Harold's correction to the listener design: a notification only says "mail arrived" -- the scan it
triggers covers ALL mail since the last scan, Bulk folders included, so it also helps users whose mail
app notifies only for the Inbox.

The analysis behind it (sources quoted in the session, 2026-10-05): Doze *"Suspends network access"* and
*"Doesn't let JobScheduler run"*; an app with *"No user interaction for 8 days"* enters the Restricted
bucket (*"Jobs: Once per day"*, *"Alarms: One per day"*); apps on the battery-optimization exemption list
*"bypass bucket-based restrictions entirely"* and *"can use the network and hold partial wake locks during
Doze"*; *"Most apps can invoke"* `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, while Play restricts the
direct `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` request. Thunderbird for Android -- the closest comparable,
a third-party IMAP app on a timer -- has the same 15-minute floor and Doze delays (its spike #11059,
2026-05-27).

---

## Task 5 -- F252: Keep background scans running -- battery setting and wake-to-scan timing (Priority 1, Issue #457)

**Value**: This prevents Android from cutting background scans to once a day (or none) for a user who
does not open the app, and measures whether a Doze alarm actually produces a scan.

**Requirements**:
- R-1 (audit first -- DONE 2026-10-05): nothing in `lib/` or `android/app/src` reads the battery-optimization
  state or opens its settings; `DozeScanTrigger.kt` sends `f235DozeWake` in the worker payload and no Dart
  code reads it, so the log cannot tell an alarm-started worker from a periodic one or show the delay.
- R-2: The alarm records the time it fired in the worker payload; the worker's start line in the diagnostic
  log names its trigger (`doze-alarm`, `periodic`, `notification`, `test`) and, for an alarm or a
  notification, the seconds between the trigger and the worker starting.
- R-3: Settings (Android only) shows a "Keep background scans running" row with the current state read
  from Android (`PowerManager.isIgnoringBatteryOptimizations`): "Unrestricted" or "Optimized -- Android may
  delay or skip background scans".
- R-4: The row's button opens this app's Android settings page (App info), where Battery > Unrestricted
  is set; the row text names the steps, including Samsung's "Never sleeping apps". The state is re-read
  when the user returns to the app.
- R-5: The app does NOT declare `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play policy: direct exemption
  requests are prohibited unless the core function is adversely affected).
- R-6: Measurement (Harold, on the Fold, 0.17.3): one day with the app Unrestricted and the phone idle;
  record alarm-fire vs worker-start times and how many alarms produced a scan. The result decides
  whether the alarm must run the scan itself (see interrupt).

**Affected components / files**:
- `android/app/src/main/kotlin/com/myemailspamfilter/DozeAlarmScheduler.kt`, `DozeScanTrigger.kt` -- fire time in payload.
- New `android/.../BatteryStatusChannel` (or an extra method on the existing `MainActivity` channel) -- state + open settings.
- `lib/core/services/android_background_scan_worker.dart` -- trigger and delay on the start line.
- `lib/ui/screens/settings_screen.dart` -- the row (Background section, Android only), near `_buildAndroidDozeStatusLine`.

**Existing abstraction checked**: `AndroidDozeAlarm` / `com.myemailspamfilter/doze_alarm` channel (MainActivity);
`DiagnosticLogger.appEvent` worker start line (F248); `_buildAndroidDozeStatusLine` (Settings).

**Callers of any guard being changed**: none -- no guard changes; the payload gains a key that only the
worker's log line reads. Tooling: N/A (Android only; WinWright unaffected).

**User-reachable control**: Settings > Background > "Keep background scans running" (status + "Open battery settings").

**Observable behavior -- before / after**: BEFORE: Settings says Android may delay scans; nothing shows
whether this phone does, and nothing helps fix it. AFTER: Settings shows "Unrestricted" or "Optimized",
and one tap opens the page where the user sets Unrestricted.

**Dependencies / blockers**: None to build; R-6 needs the 0.17.3 build on the Fold (Harold).

**Non-functional requirements**:
- Platform: Android only -- a declared ADR-0042 exception (Windows has no Doze or battery optimization;
  the row is not shown there).
- Accessibility: the status is text, not color alone.

**Acceptance criteria**:
- AC-1: A worker started by the alarm writes a start line with `trigger=doze-alarm` and a delay in seconds;
  a periodic one writes `trigger=periodic`.
- AC-2: Given the app is Optimized, When Settings opens, Then the row reads "Optimized ..." and shows the
  button; Given Unrestricted, Then it reads "Unrestricted".
- AC-3: Tapping the button invokes the open-settings channel method.
- AC-4: The merged manifest does not contain `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- AC-5: The R-6 measurement is recorded in this card.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT `test/unit/services/f252_worker_trigger_line_test.dart`: payload with and without the alarm keys -> start line.
- T-2 (AC-2, AC-3) -- TEST-WIDGET `test/ui/screens/f252_battery_row_test.dart`: channel stub returns each state; button calls the open method; row absent off Android.
- T-3 (AC-4) -- TEST-UNIT (policy) on `AndroidManifest.xml`: the permission is not declared.

**Definition of Done**: default DoD PLUS: R-6 measured on the Fold; ADR-0042 exception noted in the code
comment and in ARCHITECTURE.md's background-scan section.

**Model**: Opus 5.5 -- *why not cheaper*: native channel + worker payload across Kotlin and Dart; single interactive session (Sprint 68 IMP-4 (a)).

**Step-types**: NATIVE-ANDROID, SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET | **Est-Effort**: 120-200m

_**Risk & rollback**_: Samsung may re-add the app to sleeping apps after an update -- the status row makes
that visible. Rollback: remove the row; the payload key is inert.

_**Decision-class interrupts**_: Class 1 if R-6 shows alarms do not produce scans -- running the scan from
the alarm in a foreground service (Play declaration + video) reverses F235's handoff design. Surface with
the measurement and wait.

---

## Task 6 -- F253: Scan when a mail app says new mail arrived (Priority 2, Issue #458)

**Value**: This enables a scan within about a minute of new mail -- including while the phone sleeps and
the app is unopened -- for users whose mail app shows new-mail notifications, instead of waiting for
Android to release the next 15-minute slot.

**Requirements**:
- R-1 (audit first -- DONE 2026-10-05): no notification listener exists; the one-off worker path
  (`DozeScanTrigger.enqueue` -> `BackgroundWorker`) exists, and a worker with no `accountId` scans every
  saved account, each gated by its own background setting and the per-account claim.
- R-2: A `NotificationListenerService` (Android) reacts only to notifications posted by mail apps on a
  single allowlist in code (Gmail, AOL Mail, Yahoo Mail, Samsung Email, Outlook; extendable).
- R-3: Privacy: the listener reads ONLY the posting package name and the post time. It never reads the
  notification's title, text or extras, and stores nothing from the notification.
- R-4: On a match it enqueues the existing one-off worker with no account (all accounts), marked
  `trigger=notification`. Each account's scan covers all its selected folders, Bulk included (Harold,
  2026-10-05). **Correction (2026-10-05, from the 0.17.2 Fold log + `email_scanner.dart`)**: the planning
  claim "the existing incremental cursors already do this" is only PARTLY true. A scan fetches only new
  mail when the account's Background Scan Range is a date window (Gmail: historyId delta; IMAP: from the
  oldest unaddressed No Rule UID forward -- the backlog, not "since the last scan"). With "Scan all" both
  paths do a FULL fetch every time by design (F147, Sprint 55): the Fold's AOL background scans read
  ~550 Inbox emails in ~48 s on every run. A trigger per notification on a "Scan all" account therefore
  costs a full scan; the 2-minute collapse (R-5) bounds it. A true "since the last scan" fetch would
  change F147's semantics -- a Class-2 decision, surfaced at Manual Validation, not assumed here.
- R-5: Bursts collapse: one unique work name, so a notification that arrives while a triggered scan is
  queued or running does not start a second one; at most one triggered scan per 2 minutes.
- R-6: Settings (Android only): a "Scan when new mail arrives" switch, OFF by default. Turning it on opens
  Android's Notification access screen; the row shows whether access is granted. With the switch off,
  the listener ignores every notification even if access is still granted.
- R-7: The worker's start line (F252 R-2) shows `trigger=notification`, the mail app's package, and the
  delay from the notification's post time.
- R-8: A new ADR records the listener: why (the 2026-10-05 analysis), the privacy limits in R-3, the
  Android-only ADR-0042 exception, and the Play disclosure work (listing text, Data safety) required before
  a production release. Closed testing may run without it.

**Affected components / files**:
- New `android/.../MailNotificationListener.kt`; `AndroidManifest.xml` (service with
  `BIND_NOTIFICATION_LISTENER_SERVICE`).
- `DozeScanTrigger.kt` -- an all-accounts variant with its own unique name and trigger marker.
- The native channel (state, open Notification access settings, enabled flag in native preferences).
- `lib/ui/screens/settings_screen.dart` -- the switch; `lib/core/services/android_background_scan_worker.dart` -- start line.
- `docs/adr/00NN-notification-triggered-scan.md`, `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: `DozeScanTrigger.enqueue` (reused, not copied); the worker's
all-accounts path; `claimAccountScan` (F236 per-account lock) prevents overlap with the 15-minute scan.

**Callers of any guard being changed**: none changed. The new caller of the worker path is the listener;
the per-account claim already arbitrates between it, the periodic task, the alarm, and a manual scan.
Tooling: N/A (Android only).

**User-reachable control**: Settings > Background > "Scan when new mail arrives" (switch + access status).

**Observable behavior -- before / after**: BEFORE: new mail waits for the next background slot (15
minutes at best, much longer while the phone sleeps). AFTER: with the switch on and access granted, a
scan starts shortly after a mail app shows a new-mail notification, and its results appear in Scan History.

**Dependencies / blockers**: Task 5 R-2 (the shared worker start line). Fold validation needs a mail app
with notifications ON -- Harold's own phone has them off, so he turns them on for one account to test.

**Non-functional requirements**:
- Privacy/security: R-3; access requested only from the switch, never at startup.
- Platform: Android only (declared ADR-0042 exception; Windows has no equivalent and needs none).
- Battery: no work for non-mail notifications beyond a package-name comparison.

**Acceptance criteria**:
- AC-1: A notification from an allowlisted package enqueues exactly one triggered scan; one from any other
  package enqueues none.
- AC-2: Five allowlisted notifications in 10 seconds produce one triggered scan.
- AC-3: With the switch off, an allowlisted notification enqueues nothing.
- AC-4: The listener source never calls the notification's title, text or extras accessors (source gate,
  declared SOURCE-TEXT VERIFIED -- the privacy promise is about what the code reads).
- AC-5 (behavioral): Given the switch on, access granted and the phone idle, When new mail arrives in an
  account whose mail app notifies, Then a scan with `trigger=notification` appears in the log within a
  few minutes and Scan History shows it (Fold, Manual Validation).

**Tests to write**:
- T-1 (AC-1, AC-2, AC-3) -- TEST-UNIT (JVM, `android/app/src/test`) on the listener's decision function
  (package, enabled flag, last-trigger time -> enqueue or not), extracted as a pure function so it runs
  without a device.
- T-2 (AC-4) -- TEST-UNIT (policy) `test/policy/f253_listener_privacy_test.dart`.
- T-3 (R-6) -- TEST-WIDGET `test/ui/screens/f253_new_mail_switch_test.dart`: switch off by default; turning
  on calls the open-access method; status text for granted / not granted; absent off Android.

**Definition of Done**: default DoD PLUS: the ADR; Fold validation (AC-5); the Play disclosure items
listed in the ADR as a production-release precondition in `GOOGLE_PLAY_RELEASE_PROCESS.md`.

**Model**: Opus 5.5 -- *why not cheaper*: new Android service, privacy-bounded, cross-language; single interactive session.

**Step-types**: NATIVE-ANDROID, SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET, DOCS | **Est-Effort**: 180-300m

_**Risk & rollback**_: Play review may question notification access -- mitigated by OFF-by-default, a
package-name-only read and the disclosure; rollback is removing the service from the manifest (the
switch then reports "not available"). A triggered scan in Doze may still lack network without
Unrestricted (Task 5) -- the log's delay line shows it.

_**Decision-class interrupts**_: Class 1 APPROVED by Harold 2026-10-05 (*"yes, lets plan option 1 for this
sprint"*). A foreground service for triggered scans would be a further Class-1 item -- not in this card.

---

## Sprint summary

- Task 0 -- version 0.17.1+9 -- 10-20m
- Task 1 -- F248 diagnostic log events -- 90-150m
- Task 2 -- F249 F238 stop on Android -- 90-180m (after a phone reproduction)
- Task 3 -- F250 Gmail double pick -- 60-180m (after a phone reproduction)
- Task 4 -- phone checklist -- validation time only
- Task 5 -- F252 keep background scans running (battery row + wake-to-scan timing) -- 120-200m (added 2026-10-05)
- Task 6 -- F253 scan when a mail app says new mail arrived -- 180-300m (added 2026-10-05)
- Backlog: F254 home-screen widget (Harold Q3 = 1, 2026-10-05)

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
- **0.17.1 phone log + screenshots (Fold, 2026-10-05 07:06-07:26), analyzed.** Harold: AOL 15-minute
  background scanning was turned OFF on purpose for manual-scan debugging -- so no worker lines is expected,
  and the 07:08 `stopped (cancel) processed=1 revoked=true` was NOT a background stop. `revoked=true` is set
  only by `releaseActiveByOwner` (the F220 backgrounding handler, or a timeout); the line could not say which.
  Found 638 / processed 163 (= deleted 14 + safe 1 + noRule 148); the 475 difference is expected to be F203
  already-filed skips, but the line did not print them.
  - **New defect F251 (#456) -- DONE**: the Results "M of N No Rule addressed" banner read "0 of 1 ... 148
    remaining", then "22 of 1". `_captureInitialNoRuleCount` captured the total on the FIRST render with any
    No Rule email, and Results renders while a live scan streams in. Fix: no capture while a live
    (non-historical) scan is scanning or paused; the banner uses the live count until the scan ends.
    Callers (IMP-1): one, `_buildNoRuleProgressFooter`; saved scans unaffected (Sprint 38 guard kept).
    Test `s76_no_rule_banner_live_scan_test` (red before, green after); M148 KILLED.
  - **Diagnostics added**: `ActiveScanInfo.stopReason` (first writer wins), set by every stop source --
    user Stop on Results / Scan progress, the F238 heartbeat stop request, the F220 backgrounding handler,
    a timeout (default). The `stopped` line prints `reason=`; the `completed` line prints `alreadyFiled=`.
    Callers of `requestCancel` / `releaseActiveByOwner` (IMP-1): six, all listed above; the parameter is
    optional and named, so no caller's behavior changes. Tests extended in `scan_lock_review_test`,
    `f220_lifecycle_handler_test`, `f248_scan_diagnostic_log_test`; M149-M153 KILLED.
  - Suite 2,536 / 15 skipped / 0 failed; analyzer clean; policy gates 130/130.
  - **Version 0.17.3+11** (plan rule: the code above missed the 0.17.2 / versionCode 10 build Harold is
    uploading); provisional 0.17.3 notes. 0.17.2 is still the build to run the phone checklist on; 0.17.3
    adds the banner fix and the stop reason.
- **Task 5 F252 -- CODE DONE (R-1 to R-5); R-6 measurement pending the 0.17.3 Fold build.** The alarm reads
  the clock first and passes `triggerSource` / `triggerAtMs`; `describeBackgroundTrigger` (pure) writes
  `trigger=doze-alarm delay=Ns` / `periodic` / `test` on the worker start line. Settings > Background >
  "Keep background scans running" (`BatteryOptimizationRow`, channel `com.myemailspamfilter/battery`):
  Unrestricted / Optimized / not available, re-read on resume, "Open battery settings" opens App info.
  No `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (gated). Callers (IMP-1): `executeScan` has one caller (the
  dispatcher). Tests: `f252_worker_trigger_line_test` 7, `f252_battery_row_test` 7; M154b-M163 KILLED
  (M154 first written non-compiling = INVALID, rewritten). Android debug build compiles (exit 0). Suite
  2,550 / 15 / 0; analyzer clean. Samsung menu wording in the row is from a secondary source -- check on
  the Fold.
- **Task 6 F253 -- CODE DONE (R-1 to R-8); AC-5 pending the 0.17.3 Fold build.** `MailNotificationListener`
  (reads only `sbn.packageName` / `sbn.postTime`), pure `MailNotificationPolicy` (allowlist, switch, 2-minute
  gap), `DozeScanTrigger.enqueueAllAccounts` (unique work, KEEP, network required), channel
  `com.myemailspamfilter/new_mail_trigger` (flag in native preferences), Settings switch
  `NewMailTriggerRow` (off by default; turning on opens Notification access; status re-read on resume),
  worker line `trigger=notification app=<pkg> delay=Ns`. ADR-0044; Play production precondition in
  `GOOGLE_PLAY_RELEASE_PROCESS.md`. Callers (IMP-1): no guard changed; the worker's all-accounts path
  gates each account on `getEffectiveBackgroundEnabled` (line 149). Tests: the project's first JVM test
  `MailNotificationPolicyTest` (5, run via `gradlew :app:testDevDebugUnitTest` -- CI runs `flutter test`
  only), `f253_new_mail_switch_test` (9); M168-M175 KILLED. Debug APK builds (exit 0; manifest merges).
  Suite 2,564 / 15 / 0; analyzer clean. Unverified until the Fold: the AOL and Yahoo package names, and
  whether a triggered scan reaches the network while idle without Unrestricted.
- **5.1.1 automated code review**: DONE 2026-10-05 -- `pr-review-toolkit:code-reviewer` (with the mandatory
  related-patterns grep) and `pr-review-toolkit:silent-failure-hunter`, both on `origin/develop...HEAD`
  (39 files, +2771/-41). Both independently found the same HIGH. Dispositions:
  - FIXED -- H-1 / HIGH-1: a notification-triggered worker returned `false` on any account failure ->
    plugin `Result.retry()` -> unique work stuck in backoff (up to 5 h) -> KEEP dropped every later trigger
    while the row read "On". Now `retryOnFailureFor(inputData)` / `workerResult(...)`: a notification run
    never retries (the next notification is the retry); turning the switch off cancels a queued scan.
  - FIXED -- HIGH-2: a failed `setEnabled` is reverted and reported; a missing argument is an error, not a
    silent "off"; native catch logs. HIGH-3: the listener records its last outcome in prefs (shown in the
    row; copied to the diagnostic log at each app start) and advances the throttle only after a successful
    enqueue. MEDIUM-1: an unreadable state shows "Status unavailable" and the switch is disabled; an open
    failure gives the manual path. M-1: the app-wide switch is no longer gated on the selected account's
    background switch. M-2: turning it off disables the listener component (Android stops binding it).
    M-3: tests for the F251 guard's paused and error branches. MEDIUM-3: a failing diagnostic write is
    shown in Settings. MEDIUM-4: "refresh token unknown" when the tokens could not be read back.
    MEDIUM-5: the worker's FAILED line is awaited. L-1: privacy gate covers `activeNotifications` and
    friends. L-2: stale refresh cannot overwrite a tap. L-3: `executeScan` doc. L-4: export dialog title.
    L-5: reset writes before rebuilding. L-6: `reason` is REQUIRED on `requestCancel` /
    `releaseActiveByOwner` (both timeout callers now name their timeout). L-7: checklist line for the
    JVM tests. LOWs: reaping query cannot fail the claim; heartbeat failure logged once per run; move-safe
    throw labeled EXCEPTION; "marked needs sign-in" logged after the write; native battery catches log;
    the scanner's markAsRead batch failure is logged.
  - NO CHANGE -- POTENTIAL_MISS scanner batch reasons (`email_scanner.dart` 6b-1/2/3): each failed email
    already reaches the log as a `scan/error` line with its reason via `recordResult(success: false)`.
  - HELD FOR MANUAL VALIDATION (Class 2) -- POTENTIAL_MISS `DozeScanTrigger.enqueue` REPLACE can cancel a
    RUNNING Doze-started scan (the reviewer confirmed the scenario; F249 part 2 candidate).
  - L-8: AOL / Yahoo package names stay unverified until the Fold run (AC-5).
  - Found while fixing (Harold: *"I had to re-authenticate the gamil account at least once today"*):
    on Android a Gmail token RENEWAL always goes through the native SDK (`_refreshViaNativeSignIn`) -- the
    same path that fails with F250's `[16]` -- and the refresh token the browser fallback stored is never
    used (only the desktop HTTP path reads it). Read from code, unverified on the device; new
    `gmail/renewal` log lines name the failing step. Using that refresh token on Android changes the
    sign-in design -- Class 2, held for Manual Validation.
  - Verification: mutations M176-M184 KILLED; Kotlin compiles, JVM tests 5/5; suite 2,575 / 15 / 0;
    analyzer clean.
- **5.1.2 F-PRECHECK** (2026-10-05, against `origin/develop...HEAD` after the 5.1.1 fixes):
  1. Mirror/parallel-site sync: CLEAN -- the worker start/exit lines exist in both workers; the trigger
     fields are Android-only payload (declared ADR-0042 exception); the platform-gated Settings rows are
     tested as widgets directly plus source gates, so no Windows-vs-ubuntu assertion depends on `Platform.is*`.
  2. Helper wired into the PRODUCTION path: CLEAN -- `describeBackgroundTrigger` and `retryOnFailureFor`
     are called by the WorkManager dispatcher; `summarizeBatchFailureReasons` by both re-process batch
     paths; `AndroidBatteryStatus` / `NewMailTrigger` by the Settings rows and `main.dart` (grep: 20 call
     sites in 7 lib files).
  3. Doc-comment-vs-code drift: FIXED in 5.1.1 (L-3 `executeScan` doc; L-6 removed the defaulted reason the
     comments described); ARCHITECTURE F252/F253 sections match the code.
  4. Fragile input parsing: CLEAN -- the one new parser (`NewMailTrigger.parseLastResult`) splits
     "<epoch ms>|<outcome>" at the FIRST `|`; the millisecond field cannot contain one, the outcome may.
  5. API scope matches caller intent: CLEAN -- `enqueueAllAccounts` scans every background-enabled account
     by design (Harold, 2026-10-05); `cancelNewMailScan` cancels only `f253_new_mail_scan`;
     `getEnabledListenerPackages` is checked for this package only.
  6. Silent failure: covered by the 5.1.1 silent-failure hunter; HIGH-2/HIGH-3/MEDIUM-1/3/4/5 fixed.
- **5.1.5 WinWright sweep**: 2026-10-05 -- 3 scripts (`test_f124_rule_labels`, `test_mt2c_no_rule_sweep`,
  `test_s75_new_controls`), 27 steps, 3 PASS / 0 FAIL, DB drift none, on the 0.17.4 dev Windows build.
  sweep-head: 30f44ef. The new Android-only rows (F252, F253) are not reachable on Windows. Sprint 77
  carry-in: add WinWright coverage for the Windows-visible Sprint 76 UI -- Settings "Writing to:" line and
  "Export folder > Reset to default" (F248), and the Results "No rule" banner total after a live scan (F251).
- **5.1.6 runtime launch gate**: 0.17.3 (and 0.17.1/0.17.2) installed from Play launched on the Fold -- the
  diagnostic log's `app start (foreground) -- v0.17.3 env=prod platform=android` line (16:45:13).
- **Task 3 F250 -- R-1 DONE, configuration checked (2026-10-05).** AC-1: the failing call is the native
  `authenticate()` -- `GoogleSignInException(code canceled, [16] Account reauth failed.)` (0.17.2 log 09:43:24
  and 09:43:44); the browser fallback then succeeds. Checked from Harold's screens, not inferred: the Google
  Cloud "Android App OAuth Client" has package `com.myemailspamfilter` and SHA-1
  `3B:C2:42:60:27:14:4F:7F:AD:6E:10:D1:5E:DF:42:8F:E2:01:33:92`, which equals the Play App signing key recorded in
  `docs/OAUTH_SETUP.md:179` (F211). `google-services.json` (client IDs read with Harold's Q1 = 1) names project
  `spamfilter-multi` and web client `...-15np...` ("spamfilter web oauth client", shown "not used"). The
  `authenticate()` request is unchanged since 0.16.0 (`git diff dfa4881 8e4a21b`: Sprint 75 added only a
  post-sign-in account check and a disabled renewal path; `google_sign_in` version unchanged). Conclusion:
  no mismatch found in the app or the OAuth clients; the cause is not in the code path that changed. The
  "Last used Sep 26" on the Android client is NOT evidence of a native success -- the browser fallback uses
  that client too. Cause unknown; candidates to check on the device: the Google account's state on the Fold
  (an account that Android itself wants re-authenticated), and the same add flow on a second device.
- **0.17.3 Fold log (16:45-18:48), 2026-10-05 -- first evidence for F252 R-6 and F253 AC-5.**
  - Unattended AOL background scans ran all evening: 19 worker starts, every one `completed`, 8-12 s each
    after the Background Scan Range changed to 1 day at about 16:55 (was "Scan all", 60 s).
  - Every Doze-alarm worker read `trigger=doze-alarm delay=0s` (6 of 6): the alarm-to-WorkManager handoff
    ran immediately. Whether the phone was idle/locked at those times is not in the log -- R-6 still needs
    the overnight-idle run.
  - The alarm and the periodic task run as two separate ~15-19 minute cycles, so AOL scanned about twice
    per cycle, often 1-2 minutes apart (18:04/18:05, 18:44/18:45); at 17:45 both fired together, one was
    refused, waited 124 s, and ran a second scan straight after the first. Redundant work -- a Class-2 item
    for Manual Validation (e.g. skip a background scan when the account completed one within half the
    interval).
  - F249 part 2: periodic row 354 (16:45:49, full Inbox fetch) died before its first 30 s heartbeat; the
    16:52 manual scan reaped it ("started 410s ago, last heartbeat never") and ran. The reaper worked; the
    cause of the death is unknown. Periodic registration uses `ExistingPeriodicWorkPolicy.update` (not
    REPLACE), which I believe does not interrupt running work (unverified).
  - No `trigger=notification` line: F253 did not fire in this window (switch state not in the log).
  - Gmail: still "needs you to sign in again" on every manual scan (F246/F250).
- **0.17.2 Fold log (08:57-14:22) analysis, 2026-10-05**: Gmail safe-sender move out of Spam fails 400
  "Cannot both add and remove the same label" (`gmail_api_adapter.dart:1343`, `:1650` add AND remove
  INBOX); AOL re-process safe-sender moves fail and are retried on every rule (2 -> 29), cause not in the
  log; scan 291 died mid-fetch at 11:32:40 leaving an orphaned row until the 13:55 app start (F249 part 2
  evidence); F250 R-1 = `GoogleSignInException canceled, [16] Account reauth failed.`; Gmail background
  "needs sign-in" from 11:32 despite "refresh token stored" at 09:44 (F246/F250 R-3); a no-network Gmail
  scan recorded "completed, errors=3" and not retried; 2-4 workers start together; log lines fragment
  when isolates write at once; Gmail "found" counter wrong. New items held for Harold at Manual
  Validation (Class 3).
