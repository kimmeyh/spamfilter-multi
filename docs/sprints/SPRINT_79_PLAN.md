# Sprint 79 Plan

**Status**: APPROVED at Phase 3.7 by Harold, 2026-10-13 (answers recorded under "Decision questions"). Scope selected
by Harold at Phase 8.4 pass 2 (2026-10-13).
**Branch**: `feature/20261013_Sprint_79` | **PR**: #480 (draft until the end of 7.7)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads this turn, plus one
read-only research agent for the notification plugin (F287); file:line evidence is in each card.

## Objective

Finish the phone checks on the 0.19.0 closed-test build (the Fold steps, the battery measurement for the 5-minute
floor, Android parity of the Sprint 78 features, the Gmail `invalid_grant` cause, and the AOL scans that stopped
mid-run); make the background-scan notification name its account on Android AND show on Windows; let a WinWright
sweep on a locked PC count; find why full test runs die; switch the repository to git-flow with `develop` as the
default branch; and change the backlog presentation to the next 20 in one priority order.

**Scope (Harold, 2026-10-13, verbatim)**:
> - MV76-1, with F205 inside it as its error-classification step.
> - F286, F288, F291 and F292.
> - F277 on 0.19.0 with one account on.
> - The MV-7 phone check, the Gmail invalid_grant cause, Android parity of F281, F282 and F283, and the 10 AOL scans
>   that died mid-scan.
> - F293 and F287

**Parity (Harold, 2026-10-13, verbatim)**: *"everything needs to take into account both the Windows App and the Android
app and ADR stating that everything should be functionally and UI the same unless it cannot be - and where it cannot be
it should be implemented as a platform exception for what is needed -- this applies to all backend code, frontend code,
data, architecture, development, security, testing, deployment."* Every card names the Windows path and the Android
path and either claims parity (naming the OS behavior assumed identical) or declares an ADR-0042 exception.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control before creating a new one, then the instance fix.

**Backlog decision (Harold, 2026-10-13, Q3)**: *"add to backlog and target for next sprint"* -- F294 (one
platform-capability seam) and F295 (iPhone readiness research and parity ADR) are in the master plan, TARGET SPRINT 80.
Not in Sprint 79 scope.

## Carry-ins from the Sprint 79 stub (kept)

- 0.19.0 store updates: SUBMITTED to both stores 2026-10-13 (Harold). The Fold runs 0.19.0 from Play: the diagnostic
  log `diag_v0.19.0_2026-10-13.log` starts `app start (foreground) -- v0.19.0 env=prod platform=android` at 14:16:49.
- Sprint 78 sweep not re-run after its 7.7.1 fixes (Harold, Q1 = 2): the first Sprint 79 sweep covers them.
- 0xc0000409 crash on opening Review No Rule Items (Sprint 77): did not recur in Sprint 78; card only if it recurs.
- Sprint 78 IMP-1 gates are live: one CODING_VELOCITY.md task row per task card; every `Executed-by` line has minutes.

## Tasks, order, models and estimates

- **Task 0 -- Version bump 0.20.0+17** (Phase 3.7.0b; MINOR because F286 and F287 are `feat`). Haiku. 10-15m.
  "Last uploaded to Play" moves to 0.19.0 (versionCode 16) in this same commit.
- **Task 1 -- MV76-1 + F205 + the phone carry-ins**: Fold steps 8-11, iCloud, boot trace, error classification, MV-7
  (DONE pre-plan, see the card), the Gmail `invalid_grant` cause, Android parity of F281/F282/F283, the AOL scans that
  stopped mid-run. Session model. 60-110m + Harold's phone time (re-estimated, see the card).
- **Task 2 -- F277**: Fold energy check, three overnight arms, ONE account on. Haiku analysis. 30-45m + three nights.
- **Task 3 -- F286**: Android notification names the account, "No rule" first, one per account, mode shown. Haiku
  with the delegation checklist. 30-50m.
- **Task 4 -- F287**: Windows background-scan completion toast, sharing F286's text and ID helper. Sonnet. 60-150m
  depending on the route (Q2).
- **Task 5 -- F288**: git-flow, `develop` the default branch. Phase A inspect (Haiku-shaped), then a PLANNED
  mid-sprint pause for Harold's approval of the Phase B list, then Phase B. 45-90m.
- **Task 6 -- F291**: a WinWright sweep on a locked PC counts as complete. Sonnet. 40-70m.
- **Task 7 -- F292**: full-suite test processes die or hang. Sonnet, escalate to Fable/Opus if the mechanism is not
  named after two reproduction rounds. 60-120m (mostly wall-clock test runs).
- **Task 8 -- F293**: backlog refinement shows the next 20 in one order. Haiku. 15-25m.
- **Task 9 -- F297** (#488, added 2026-10-14 by Harold): reload rules and safe senders after a YAML import, through one
  shared provider reload. Sonnet. 30-45m.
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review fixes,
  150-250m. Sprints 70, 76 and 78 each spent as much or more on this as on planned cards (CODING_VELOCITY.md trend
  rows); it is a predictable line item.

**Total**: about 350-625 minutes planned plus 150-250 unplanned, plus Harold's phone time. Calibration: the Sprint 78
trend row is 0.23 (planned cards ran about 4x under), so the bands above sit at the low end of the velocity table.

**Order**:
1. Task 0 and the cards (3.7.0, 3.7.0b).
2. Daytime phone work (Task 1) starts at once on the installed 0.19.0; nights carry Task 2's three arms with ONE
   account on (Q6). The two cannot overlap: steps 8-11 need AOL, Yahoo and iCloud on, the battery arms need one.
3. Task 5 Phase A (read-only), handed to Harold as a numbered list while work continues (the one planned mid-sprint
   decision, approved in Q-S2), then Phase B after his answer.
4. Task 3, then Task 4 (Task 4 uses Task 3's helper).
5. Tasks 6, 8 and 7 fill the waits. Task 7's reproduction runs AFTER the reboot that applies the larger page file
   (Harold, 2026-10-13), and the run log records which side of the reboot each run was on.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (a), recorded once):
Harold's phone feedback interleaves with implementation, so execution is the session model unless a task is delegated.
`Executed-by` per task cites this line. Delegated coding sub-agents get the delegation checklist verbatim.

**Code reviews**: no 5.1.1. The 7.7.1 pair (Copilot by hand + pr-review-toolkit code-reviewer and silent-failure-hunter)
runs when the retrospective improvements are complete. The 7.7.1 size limit (4+ code files or 600+ lines asks first)
applies to review fixes, not to the planned work below.

**Cards**: GitHub issue cards are created at Phase 3.7.0, the first action after approval (Sprint 77 and 78
precedent), because the decisions below change card content. #471 (MV76-1), #472 (F277), #433 (F205) and #428 (MV74-1)
already exist and are reused, not duplicated.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md:473-484`), so they are not asked
again: (a) F287 route 2 only -- the `flutter_local_notifications` major-version change named in its card; (b) F288 Phase
B -- the default-branch switch and the CI trigger edit, and ONLY the items Harold approves from the Phase A list.

## Phase 3.2.2.1 branch-state verification (summary)

Findings that changed scope or estimate:

- **MV-7 on the phone: DONE before the sprint.** The 0.19.0 log has three skip lines, for example
  `[14:36:31] account k***@aol.com skipped: a scan started 110s ago (interval 5m; doze alarm)`, and
  `phone-log-health.ps1 -Since 14:16 -IntervalMinutes 5` reports "No flags" (AOL 9 starts, 9 completed, median gap
  6.3 min). Kept in Task 1 only as an overnight confirmation line.
- **F283 Android parity: partly evidenced.** The 0.19.0 log has about 40 `[F245/no-rule] row N marked addressed`
  lines from Harold's 14:17-14:18 Review session (popup block and safe-sender actions, plus rows covered by the new
  rules). F281 and F282 still need screenshots.
- **The AOL scans that stopped mid-run: the F263 lead does NOT fit the one case read.** Row 2434 (0.18.0,
  2026-10-13) started 01:14:45, logged `IMAP full fetch daysBack=1` at 01:14:48, and nothing more; the claim path
  reaped it at 01:21:15 ("started 390s ago, last heartbeat never"). It died about 3 seconds in, not at a ~10-minute
  WorkManager limit. A second periodic worker had started 5 seconds earlier (01:14:40) and its AOL and Gmail scans
  logged only `start`. Candidates (both UNVERIFIED): the process was killed, or the periodic re-enqueue
  (`ExistingPeriodicWorkPolicy.update`, `background_scan_scheduler.dart:304`) stopped a running worker.
- **Gmail background stopped after 14:27 on 0.19.0** (no start or skip line from 14:29 to 15:14, while the manual
  scan at 14:29 completed). The log does not record settings changes, so the cause is unknown (Q8).
- **F286**: the notify call moved -- now `android_background_scan_worker.dart:378-382` (`accountId.hashCode`, title
  `Background scan complete`); the master-plan card cites `:300-334`.
- **F287 -- a different shape than the card**: `windows_notification_service.dart:62` still has no caller, and its IDs
  are fixed (0, 1). A SECOND Windows service exists: `windows_toast_notification_service.dart` (ADR-0018, Accepted,
  PowerShell WinRT toast), with no caller in `lib/` ever (`git log -S` finds only its creating commit d47ac7a). So
  Windows notifications have never shown from this app. The plugin resolves to 17.2.4 (`pubspec.lock`). This makes
  F287 a route choice (Q2), and the card estimate depends on it.
- **F291**: the lock gate is in `mobile-app/scripts/run-winwright-tests.ps1` (header `:18-37`, gate near `:276`), not
  `scripts/`; check 3e is `verify-closeout-complete.ps1:256-290`; `knownPending` is
  `winwright_script_strings_test.dart:103`.
- **F293**: the format lives at `BACKLOG_REFINEMENT.md:443-500` and is restated at `SPRINT_EXECUTION_WORKFLOW.md:160-161`
  and `SPRINT_CHECKLIST.md:30,40` -- four places to change, not one.

**Phase 3.2.2.2**: fired -- Task 1 re-estimated (MV-7 done, AOL investigation added with a real lead); Task 4 split by
route; F277 and F286 set at the low end per the Sprint 78 calibration.

## Phase 3.6.1 Architecture Impact Check

- **ADR-0018** (Windows toast via PowerShell): route 1 of F287 implements it for the first time and amends it (Tag and
  Group so one toast per account, the registered app ID); route 2 SUPERSEDES it with the plugin -- a Class-1 change,
  which is why Q2 asks.
- **ADR-0042**: Windows background notifications were an undeclared gap (Android notifies, Windows never did). F287
  closes it; the ADR records notifications as PARITY (same text helper, same one-per-account rule), with the
  delivery mechanism as the declared platform exception.
- **ADR-0040** (two E2E harnesses): F291 adds the locked-PC rule -- a sweep on a locked PC runs every cursor-free step
  and counts, with the mouse steps listed as skipped.
- **ARCHITECTURE.md**: the `WindowsNotificationService` row (`:219`) and the startup step (`:491`) change with F287;
  a shared notification-text helper row is added with F286.
- **CLAUDE.md and SPRINT_EXECUTION_WORKFLOW.md** branch-policy sections change with F288 (process, not app
  architecture).
- No other ADR conflicts found.

## Decision questions (asked with the plan; answers recorded here)

- Q1. F286 read-only / partial modes: 1 strikethrough plus title word (recommended), 2 strikethrough only, 3 title
  word only.
- Q2. F287 route: 1 wire the existing ADR-0018 PowerShell toast, no dependency change; 2 upgrade the plugin to
  22.3.2 (recommended; supersedes ADR-0018).
- Q3. F288 "Do not state test results in commit messages": 1 this card only, 2 all commits from now on.
- Q4. F291 guard, run the six mouse steps unlocked once per Store release: 1 yes, 2 no.
- Q5. F293: 1 the presentation only, the master plan stays grouped by phase; 2 reorder the master plan too.
- Q6. F277 account left on overnight: 1 AOL, 2 Yahoo, 3 Gmail.
- Q7. Gmail on the Fold during Sprint 79: 1 keep Google sign-in, 2 switch to IMAP with an App Password now.
- Q8. Gmail background stopped after 14:27: 1 you turned it off, 2 you did not.
- Q9. F286/F287 phone check: 1 a mid-sprint 0.20.0 closed-test upload, 2 check after the Sprint 79 release.
- Q-S1. Models as assigned: 1 approve. Q-S2. F288 Phase A asked mid-sprint while work continues: 1 approve.
  Q-S3. Version 0.20.0+17: 1 approve.

**Answers (Harold, 2026-10-13, verbatim)**: *"q1. 1 q2 2 q3 1 q4 1 q5 1 q6 1 q7 1 q8 2 q9 2 q-s1 1 q-s2 1 q-s3 1"*

- Q1 = 1: strikethrough for the counts not acted on, plus a title word naming the mode.
- Q2 = 2: route 2 -- `flutter_local_notifications` 22.3.2 plus `desugar_jdk_libs` 2.1.4; ADR-0018 SUPERSEDED (Class 1,
  approved); `WindowsToastNotificationService` deleted.
- Q3 = 1: "Do not state test results in commit messages" applies to the F288 card only.
- Q4 = 1: the six mouse steps run on an unlocked PC once per Store release (F291 guard).
- Q5 = 1: F293 changes the presentation only; the master plan stays grouped by phase.
- Q6 = 1: AOL stays on for the F277 nights; Yahoo, Gmail and iCloud background OFF those nights.
- Q7 = 1: Gmail on the Fold stays on Google sign-in for Sprint 79 (so the `invalid_grant` cause can be found).
- Q8 = 2: Harold did NOT turn Gmail background off. The stop after 14:27 is a defect -- added to Task 1 as R-9.
- Q9 = 2: the F286 phone check (and strikethrough rendering on the Fold) happens after the Sprint 79 release;
  in-sprint evidence is the emulator rehearsal.
- Q-S1, Q-S2, Q-S3 = approved.

---

# Cards

## Task 1 -- MV76-1: Finish the Fold checks on the 0.19.0 closed-test build (Priority 1; absorbs F205 #433, MV74-1 #428)

**Value**: This closes the last phone checks of Sprints 74-78 on the build customers have, and names the cause of the
AOL scans that stop mid-run.

**Requirements**:
- R-1: Fold steps 8-11 (re-presented in full, never by reference). Authoritative source: `SPRINT_77_PLAN.md:421-431`
  (step 8 interval note and Doze lines, step 9 per-account new mail = F253 AC-5 `trigger=notification`, step 10 Gmail
  custom label F258, step 11 reboot half #428 + Google account state F250 + errors per day) PLUS the master-plan
  MV76-1 bullets (export header row on a new daily `.data.csv`; a Results rule update for an Inbox safe sender reports
  no failure). Corrected at approval: the draft listed only part of this union.
  - Export header row: **PASS (2026-10-13)** -- `background_scan_kimmeyharold_at_icloud_com_2026-10-13.data.csv`,
    first written 00:40:07 as a new daily file, line 1 is the column names (`Scan Date and Time ... Phishing
    SPF/DKIM/DMARC`); same for `live_scan_kimmeyharold_at_aol_com_2026-10-13.data.csv` (first row 14:29:40, 0.19.0).
  - Step 8 Doze lines: evidenced on 0.19.0 (`trigger=doze-alarm` and MV-7 skip lines, health check "No flags"); the
    Background note screenshot is still needed.
- R-2: F205 / MV74-3 (#433): classify every scan error from one day of normal use per account, or record zero. 0.19.0
  so far: zero errors in 18 background scans (14:16-15:14).
  - 2026-10-13 14:16 to 2026-10-14 08:11 (0.19.0, all accounts): **zero `error` outcomes**; 3 AOL `refused` (another
    scan held the account: 10-13 15:57:53, 10-14 04:56:08, 07:13:19) -- the claim lock working, not a fault. Gmail
    renewals on Android: 4 of 4 `renewed with the stored refresh token` after `native silent sign-in returned no
    account`, no `invalid_grant`. (The 8 Gmail and 2 AOL errors in the pull summary are all 0.18.0.)
- R-3: Boot-time `main()` trace: name what started the engine at 09:14:39 on 2026-10-07 with no app opened, and whether
  `app start (foreground)` is the wrong label for that path.
- R-4: iCloud background ON on the Fold if iCloud should be covered (0.18.0 logs: 4 iCloud starts at a 240-minute gap,
  so it is on at 4 hours); record one completed iCloud background scan.
- R-5: MV-7: DONE pre-plan (3.2.2.1); confirm once more on an overnight log (no double-scheduling FLAG).
  - **Overnight 2026-10-14 00:00-08:11: FAILS for a 15-minute account.** Yahoo (15m) completed 52 scans, 6.25/hour
    against about 4. AOL (5m, 9.44/hour), Gmail (240m) and iCloud (720m) are within their intervals. **Mechanism
    (verified in source and log)**: the recent-scan skip runs only on a Doze-alarm run (`if (dozeAlarm && !isTest)`,
    `android_background_scan_worker.dart:244`) with a window of two-thirds of the interval (`dozeAlarmShouldSkip`,
    `:142`, 10 minutes at 15). The alarm fires 10-13 minutes after a periodic scan, past the window, so it scans; the
    periodic run about 5 minutes later never checks, so it scans too. Example: periodic 00:05:58, alarm 00:16:21
    (622 s, ran), periodic 00:21:25 (ran); the one alarm at 582 s (01:56:56) skipped. A 5-minute account is not
    affected because WorkManager's periodic minimum is 15 minutes, so the alarm carries its cadence.
  - **Why the health check did not flag it before**: `phone-log-health.ps1` applied ONE interval to every account.
    Fixed (prevention): it now reads each account's interval from its own skip lines (`(interval 15m; doze alarm)`),
    counts N-1 gaps for the rate (two scans 240 minutes apart had read as a double), and accepts `-Path a,b` through
    `-File`; self-test 13 checks, both new behaviors mutation-verified (each mutant fails the self-test).
  - **App fix NOT made**: applying the skip to periodic runs changes the Sprint 78 MV-7 design (periodic always
    scans). Surfaced to Harold as a development decision.
  - **Harold Q1 = 1 (2026-10-14): fixed.** A periodic run now skips an account whose last COMPLETED scan started
    within two-thirds of its interval (`checksRecentScan`, `recentScanShouldSkip`, `getLatestScanStart(completedOnly:)`).
    Callers: periodic -- changes (skips after a recent completed scan; its retry after a failed, killed or running
    scan still scans, because only `completed` rows count); Doze alarm -- unchanged (any status); new-mail
    notification and Test -- never check. Log line `skipped: a completed scan started Ns ago (interval Nm; periodic)`
    keeps the `(interval Nm` shape `phone-log-health.ps1` reads. ADR-0042: Android-only by nature (Windows Task
    Scheduler has one trigger per account, no second schedule to collide with). Tests: `mv7_doze_alarm_skip_test.dart`
    17 pass; mutations M1 (periodic does not check), M2 (status filter dropped), M3 (notification run checks), M5
    (periodic counts any status) KILLED. What the tests do NOT catch: delivery timing on the phone (overnight log).
- R-8 follow-up (2026-10-14): **two more class-B rows on 0.19.0** (2862 at 10-13 16:48:44, 2886 at 18:29:31). In both,
  and in 2270 (0.18.0), the SAME Doze request ran again exactly 30 s later (`trigger=doze-alarm delay=30s`, the alarm
  time unchanged) and skipped on the dead row. A Doze run never asks for a retry (`retryOnFailureFor`), so a 30 s
  re-run of the same request is consistent with WorkManager re-running a STOPPED worker (UNVERIFIED). **Attempted
  prevention -- DOES NOT WORK ON THE DEVICE (see the emulator result below)**: the dispatcher registers the plugin's
  `onTaskStopped` (workmanager 0.10.7), meant to write `stopped by
  WorkManager before it finished: reason=<timeout|preempt|deviceIdle|...> (<account> <trigger>)` (bounded to 2 s).
  Tests: `onWorkerStopped` writes one line; a hanging or throwing write does not hold teardown; wiring. Mutations M4a
  (no write), M4b (no bound), M4c (not registered) KILLED (M4 against the first, source-only test SURVIVED, which
  is why the handler became a testable function). If a dead row appears with no stop line, the process died
  instead -- that also settles it.
  - **Reproduced on the emulator (2026-10-14 09:41, 0.20.0 debug built before the handler)**: a Settings > Test
    Background Scan of AOL (read-only) was stopped 30 s in -- logcat `WM-GreedyScheduler: Constraints not met:
    Cancelling work ID ...`, `WorkerStoppedException`, `rescheduling for later execution` -- while the emulator's
    network callbacks fired (`onCapabilitiesChanged`). The diagnostic log's last line was `fetch-path -- folder
    "Inbox"`: the class-B shape exactly. Named mechanism for THIS case: the Test and periodic requests carry
    `NetworkType.connected` (`background_scan_scheduler.dart:395`, `:477`); a connectivity flap makes WorkManager
    stop the RUNNING worker. The Doze one-off has no constraint (`DozeScanTrigger.kt:107-110`), so the phone's
    Doze-run deaths (2862, 2886) need the stop line to name their reason.
  - **F282 on the emulator: `csv_export_directory = /storage/emulated/0/Documents`** saved (app_settings,
    date_modified 1791073363700, about 2026-10-04), and its log is in `Documents/diagnostics` -- the saved folder
    wins, VERIFIED here; the phone is still inferred until Harold's Settings check.
  - Emulator Gmail: `stored refresh token failed ... invalid_grant` (09:39:19) -- a second device with the R-6
    symptom; the cause stays UNVERIFIED until the OAuth consent publishing status is read (R-6).
  - **Stop handler on the emulator (0.20.0 debug WITH the handler and a logcat-first line, 10:01 and 10:25)**: two
    forced stops (network cut during a Test run and a periodic run; logcat `Constraints not met: Cancelling`,
    `WorkerStoppedException`) produced NO `stopped by WorkManager` line in logcat or the diagnostic log, and the Dart
    scan kept logging for seconds after `WorkerWrapper interrupted`. **The handler does not fire. Cause unknown**;
    unverified candidate: the plugin's `onStopped` makes the Pigeon call off the platform thread and its default
    (no-op) `WorkmanagerDebug` handler swallows the error. Settled by a `Log.w` at the top of `onStopped` and in its
    `catch` (needs a pub-cache edit -- not done). Alternative that does not depend on the plugin: read
    `WorkInfo.getStopReason()` at the next worker start through a platform channel (asked as a question).
    The code stays registered with a [WARNING] comment; it changes nothing when it does not fire.
    **Harold B = 1 (2026-10-15), then re-asked from the primary source**: AndroidX `WorkInfo.kt:100-112` --
    `stopReason` is "the reason why this worker was stopped on the previous run attempt", `@RequiresApi(31)`, and reads
    `STOP_REASON_NOT_STOPPED` (-256) otherwise. But `WorkerWrapper.kt:478-481` sets `state = RUNNING` AND
    `setStopReason(workSpecId, STOP_REASON_NOT_STOPPED)` when the next attempt starts, before any Dart code runs. So
    "read it when the next scan starts" always reads -256: option 1 as worded cannot work. The reason is readable
    only between the stop and the re-run (30 s for the Doze one-off). Sources fetched 2026-10-15 from
    `androidx/androidx` `androidx-main` (`work/work-runtime/src/main/java/androidx/work/WorkInfo.kt`,
    `impl/WorkerWrapper.kt`); the app ships `work-runtime:2.11.2` (`build.gradle.kts:231`).
  - **Q1 gap found on the emulator (10:21)**: a periodic run that arrives WHILE another scan of the account is
    running passes the entry check (the running scan is not `completed`), waits in `BackgroundScanCore`'s busy-retry
    (254 s), then scans anyway -- 10:25:37, 3.5 minutes after the 10:22:01 completion, inside the window. The entry
    check is not repeated after the wait. Not covered by the Q1 fix as built.
    **FIXED (Harold A = 1, 2026-10-15)**: `BackgroundScanCore.scanAccount` takes `skipAfterWait`, asked once after
    the busy wait and before the retry; a reason skips (`stage: skip`, "after the wait: ..."), a throwing check does
    not. The Android worker passes the SAME closure it runs at entry (`recentScanReason`), only for runs that check
    (`checkRecent`). Windows passes null: one Task Scheduler trigger per account and no recent-scan rule, so its
    behavior is unchanged (ADR-0042: declared, follows the existing Android-only entry rule). Tests: 4 new in
    `mv74_2_scan_heartbeat_test.dart` (skips after the wait and is asked only after it; null retries; throw retries;
    a free account never asks); the `mv7_doze_alarm_skip_test.dart` wiring gate pins the worker passing the check.
    Mutations A1-A5 KILLED (never asks, ignores the reason, a throw skips, asked before the wait, worker passes
    null). What the tests do NOT catch: delivery timing on the phone (the device log line "SKIPPED after the wait").
  - **Test Background Scan can do nothing silently**: `runTestScan` uses a unique name with WorkManager's default
    KEEP (`background_scan_scheduler.dart:473`); while an earlier test request is queued or in its 10-minute backoff
    (after a stop), a new tap is dropped with no message. Seen 10:08 (tap, no run until 10:20:58).
  - **R-9 prevention VERIFIED on a device**: `[scheduler/android] schedule k***@aol.com every 15m ok (from
    settings_screen.dart:1539)` at 10:21:04 and `cancel k***@aol.com ok (from settings_screen.dart:1564)` at 10:31:48.
  - **F286 rehearsal (5.1.9) PASS on the emulator**: read-only AOL Test run completed 10:22:01; the shade shows
    title `Back. scan k*@aol read-only com...` and body `No rule 111 ~~Deleted 0 Safe 0~~` (strikethrough renders;
    dumpsys `android.text=SpannableString`); notification id 772562602 = the Windows toast tag for AOL (F287), so
    both platforms key the same account the same way. Screenshot
    `validation-screenshots/sprint-79/emulator_F286_readonly_strikethrough_20261014_1023.png`.
  - Emulator housekeeping: AOL background was turned ON for this test and OFF again (10:31:48); the emulator was
    rebooted once (09:57) after memory compaction starved it (load 13.78, `kcompactd0` 83%); the other app build
    `com.myemailspamfilter.dev` was force-stopped to free memory.
- R-6: Gmail `invalid_grant` (Fold, 2026-10-12 17:27): Harold opens Google Cloud Console > APIs & Services > OAuth
  consent screen and reports the publishing status. Until he does, the cause stays UNVERIFIED; no claim about what
  that status does to refresh tokens is written unless Google's page is fetched and quoted in the same turn.
  **Closed by Harold, 2026-10-15**: *"this is not needed as proven by phone screenshot showing version 0.19.0"* (Gmail
  renewals on the phone's 0.19.0 were 4/4 via the refresh token). The cause of the 10-12 phone and 10-14 emulator
  `invalid_grant` stays UNVERIFIED; no screenshot will be requested.
- R-7: Android parity of F281 (Scan every presets and Custom, hidden when background is off), F282 (files in
  `Documents/MyEmailSpamFilter`) and F283 (Review No Rule Items, partly evidenced in 3.2.2.1): one screenshot each.
  - **Phone steps, Harold 2026-10-14 ("1 done, 2 mark done, 3, 4, 5, 6 done")**: step 1 interval note -- screenshot
    `Screenshot_20261014_091117.png` (AOL, 5 minutes, idle note shown). Step 2 new-mail trigger -- marked done by Harold
    without a run; the 0.19.0 logs (10-13 14:16 to 10-14 09:31) have **zero** `trigger=notification` lines and the AOL
    screen reads "Needs Notification access", so access is not granted (affects Night C). Step 3 Gmail custom label --
    PASS: Gmail background scans fetch `"Unwanted"` beside INBOX and SPAM (16 each). Steps 4 and 5 -- done per Harold;
    no rule-update failure line in the log. Step 6 parity: F281 PASS (`091310`: 5/10/15/30 minutes, 1/2/4/12/24
    hours, Custom); background OFF hides "Scan every" PASS (`091337`, iCloud); F282 see below; F283 partly evidenced
    (F245 `marked addressed` lines 09:08-09:09).
  - **F282 on the phone: files are in `Documents/diagnostics`, `Documents/scan_exports` and the Documents root, no
    `MyEmailSpamFilter` folder** (`091640`-`091703`, `091815` "Writing to: /storage/emulated/0/Documents/diagnostics").
    Code trace (0.19.0 contains F282, a79ea81 is an ancestor of 757d6a0): the `MyEmailSpamFilter` segment is added
    only to the DEFAULT (`export_directories.dart:71-75`); a saved `csv_export_directory` is used exactly as chosen
    (`:164-179`, F282 AC-2), and no migration rewrites it. **Inferred, not verified**: the phone has
    `/storage/emulated/0/Documents` saved from before 0.19.0. Settles it: Settings > General > Export folder shows that
    path and a "Reset to default" button (shown only when a folder is saved, `settings_screen.dart:1443`). Gap noted:
    no F282 test runs the Android default path (the default is overridden in `f206_export_test.dart:44`).
  - **F282 phone check, Harold 2026-10-15: "as expected"** -- the saved `/storage/emulated/0/Documents` was shown with
    Reset to default; after the reset the folder is `Documents/MyEmailSpamFilter`. F282 Android: PASS; the inference
    above is confirmed (the saved folder, not a defect, put the files in Documents).
- R-8: The AOL scans that stopped mid-run: read every unfinished case in the 0.18.0 and 0.19.0 logs (the first
  is 2026-10-12 08:08:09); for each, record the seconds from start to the last line, the last step reached, and
  whether another worker started within 10 seconds. Settle the two candidates (process kill, periodic re-enqueue
  stopping a running worker) from Android's own WorkManager documentation for `ExistingPeriodicWorkPolicy.UPDATE`,
  quoted. A named mechanism gets a prevention-first fix (in `BackgroundScanCore` or the scheduler) and a test; "cause
  unknown" gets what would settle it.
- R-9 (Q8 = 2): Gmail background scans stopped after 14:27 on 0.19.0 with the setting still on (no start or skip line
  14:29-15:14; the 14:29 manual scan completed). Read the worker's per-account eligibility path for what drops an
  account with no log line, name the mechanism or write "cause unknown" plus what would settle it, and add the missing
  skip-reason log line in any case (prevention first: an account that is not scanned must say why).
  - **Status 2026-10-13**: the 14:27 Gmail scan COMPLETED (`exit success` 14:27:51); from 14:29 Gmail has no line of
    any kind on EITHER trigger while AOL and Yahoo continue on both. Read-only trace (Sonnet agent): the only code that
    removes the periodic task, the Doze alarm and its native `interval_` pref together is
    `AndroidSchedulerAdapter.cancel` (`background_scan_scheduler.dart`), reached only from the Settings Background
    switch's off path (`settings_screen.dart:1564`), and it logged to logcat only. Doze-only and periodic-only
    candidates cannot explain both stopping; worker eligibility checks run after the `start` line, so they do not fit.
    **Cause unknown**; settled by Harold reading Settings > Gmail > Background "Enable Background Scanning" (asked).
  - **RESOLVED 2026-10-14 from the overnight log: Gmail did not stop; its interval is 240 minutes.** Periodic Gmail
    scans at 18:17, 22:17, 02:19 and 06:19, each followed by a Doze-alarm skip line `(interval 240m; doze alarm)`
    (first at 18:31). Gmail ran every 5 minutes up to 14:27, so the interval changed between 14:27 and 18:17; the
    14:29-15:14 silence is the first 240-minute wait. Who changed it is not in the log (0.19.0 has no scheduler line;
    the 399fb52 prevention adds one). iCloud is at 720 minutes, which also explains its 0.18.0 gaps (R-4).
  - **Prevention (done)**: both platform adapters now write `[scheduler/<platform>] schedule|cancel <masked account>
    [every Nm] ok|FAILED (from <file:line>)` to the diagnostic log on every call; tests in
    `background_scan_scheduler_test.dart` (format, caller label, source gate), two mutations KILLED. Native-side
    candidates (receiver re-arm with a missing pref, KEEP dropping a Doze one-off) still log to logcat only -- recorded
    as a remaining gap, not fixed here.
  - **R-8 every reaped row (2026-10-13, all pulled logs Oct 7-13, script-derived)**: 17 rows (15 AOL, 2 Yahoo). Each
    row's OWN last line (other workers' skip/busy lines excluded):
    - **Class A, alive and stuck (6)**: 1627 (+7 s `fetch "Bulk Mail" begin`, heartbeat to about +1050 s), 1900 (+28 s
      `IMAP full fetch`, to +30 s), 1968 Yahoo (+0 s `IMAP full fetch`, to +900 s), 2017 (+310 s `IMAP full fetch "Bulk
      Mail"`, to +1170 s), 2078 (+2 s `IMAP full fetch`, to +900 s), 2147 (+11 s `actions`, to +690 s). The heartbeat (every
      30 s, `scan_coordinator.dart:133`) kept running minutes after the last line, so the process was ALIVE and the
      scan was waiting. **Mechanism (named, verified in source)**: every IMAP client was built WITHOUT a response
      timeout (`generic_imap_adapter.dart:405`, `GreetingAwareImapClient`; the adapter's own comment said so), so a
      command whose reply never came waited forever. **Fix (prevention first, at the one shared seam)**:
      `kImapResponseTimeout` 120 s and `kImapWriteTimeout` 60 s on both constructors; enough_mail applies it per
      command and fails it with `ImapException('timeout')`, which the login classifier treats as "server
      unavailable" (`:541-542`). 120 s vs the slowest whole-folder fetch in 6,484 logged (37.9 s); fetches are 20
      messages per command; no IMAP IDLE in `lib/`. Test `imap_response_timeout_test.dart` (a real silent loopback
      server: the command ends with `timeout` in under 5 s instead of hanging; both constructors; no bare client
      in `lib/`); two mutations KILLED; the 14 IMAP test files pass (211).
    - **Class B, no heartbeat ever (11)**: 912, 1455, 1634, 1930, 1953, 1969, 1980, 2031, 2270, 2434, 2499 -- last line at
      +0 to +30 s (three at `connect -- begin`, which already HAS timeouts in `imap_certificate_trust.dart`), and the
      first 30 s heartbeat never ran. The isolate stopped running within 30 s: the process was killed or frozen.
      **Cause unknown**; what would settle it: Android's exit reason for the process
      (`ActivityManager.getHistoricalProcessExitReasons`, API 30+) read at the next start and written to the
      diagnostic log -- filed as a follow-up, not built in this sprint.
    - Another worker started within 10 s of the dead row's start in 13 of 17 rows (often a doze-alarm and a periodic
      run together). The MV-7 fix (0.19.0) removes most of those overlaps; the 0.19.0 log so far has no reaped row.
  - **Row 2434 (R-8)**: WorkManager's `ExistingPeriodicWorkPolicy.UPDATE` KDoc (androidx source,
    `work/work-runtime/.../ExistingPeriodicWorkPolicy.kt`): *"If the work being updated is currently running, the
    current run won't be interrupted"*. The re-enqueue candidate is excluded; process death remains (UNVERIFIED).

**Affected components / files**: evidence only, unless R-3 finds a wrong label (one-line fix in the start path, both
platforms checked) or R-8 names a mechanism (fix in `background_scan_scheduler.dart` or `background_scan_core.dart`).

**Existing behavior relied on**: the claim path reaps a dead row after 390 s -- verified at the 0.18.0 log line
`[01:21:15] reaped dead background row 2434: started 390s ago, last heartbeat never`; evidence pull
`scripts/pull-phone-screenshots.ps1 -Sprint 79` (adb is unavailable).

**Callers of any guard being changed** (R-8, only if a fix changes enqueue or claim): every `registerPeriodicTask`
caller (`background_scan_scheduler.dart:292`), the Doze alarm path, the notification trigger, and Settings > Test
Background Scan; tooling: none launches the Android worker.

**Dependencies / blockers**: Harold's phone time; R-6 needs Harold at the Google console.

**Non-functional requirements**: Platform -- Android evidence; for R-8, check the Windows background scan for the same
class (Task Scheduler launches one process per run, so a re-enqueue cannot stop a running one there -- verify in
`windows_background_scan_*`, not assume).

**Acceptance criteria**:
- AC-1: Steps 8-11 each recorded PASS / FAIL with the log line or screenshot that proves it.
- AC-2: Errors per account for one day recorded with a class each, or zero; #433 closed or re-scoped.
- AC-3: #428 closed with the reboot evidence, or a failure card filed.
- AC-4: The boot-start receiver named with its log line.
- AC-5: R-6 status recorded from Harold's screen, or the line "UNVERIFIED -- console not opened".
- AC-6: F281, F282, F283 on Android each PASS / FAIL with a screenshot.
- AC-7: Every unfinished AOL scan listed with time-to-death and last step; a named mechanism with a fix and a test, or
  "cause unknown" plus what would settle it.
- AC-8: The Gmail 14:27 stop has a named mechanism or "cause unknown" plus what would settle it, and a skipped account
  always writes a reason line (test T-3).

**Tests to write**: T-1 (AC-4, only if a label fix is made) -- TEST-UNIT on the start-reason label. T-2 (AC-7, only if
a mechanism is fixed) -- TEST-UNIT in the scheduler or core test file proving the fixed path, with its "what this
does NOT catch" line. T-3 (AC-8) -- TEST-UNIT: an account the worker does not scan writes a skip-reason log line.

**Definition of Done**: default DoD; evidence lines in this plan's Phase 5 evidence section.

**Model**: Haiku for transcription; R-8 analysis is Sonnet-shaped -- *why not Haiku*: naming a process-lifecycle
mechanism from logs and vendor docs. Session model per the deviation note.
**Step-types**: DOCS (evidence), SVC-EDIT (conditional). **Est-Effort**: 60-110m + phone time (was 40-70m: MV-7 done,
R-8 added with a real lead).

## Task 2 -- F277: Fold energy check, interval 5 against interval 15 (Priority 20)

**Value**: This settles the 5-minute floor with measured energy instead of emulator counts.

**Requirements**:
- R-1: Protocol `docs/research/R76-1_BATTERY_AB_RESULTS.md` section R77-BAT-1: arms (A) one account interval 15, new
  mail off; (B) interval 5, new mail off; (C) interval 5, new mail on. Screen off, unplugged, 8 hours each, same
  network. ONE account on (Q6); the other three have background OFF for the night.
- R-2: Before reading a battery screenshot, confirm the run with
  `scripts/phone-log-health.ps1 -Path <log> -Since <start> -IntervalMinutes <n> -SingleAccount` (Sprint 78 IMP-2).
- R-3: Metric: Settings > Battery percent for the app (screenshots over MTP), plus the log's scan count.
- R-4: Decision rule: B at most 3x A keeps the floor at 5; above 3x raises `kMinIntervalMinutes` (`scan_interval.dart`)
  to 10 and re-runs B; C more than 50% above B raises the new-mail minimum spacing.
- R-5: Android only -- ADR-0042: Windows has no battery cost for this (plugged-in desktop, Task Scheduler), so no
  Windows arm; any constant change is shared Dart and applies to both platforms.

**Dependencies / blockers**: three overnight windows (Harold); not on the same nights as Task 1's multi-account steps.

**Night log**:
- 2026-10-13/14 (00:00-08:11, 0.19.0): **NOT A VALID ARM.** The Battery activity graph shows the phone CHARGING
  from about 01:30 to 08:00 (24% at 01:05, 94% by 08:00) and "Screen off time: 0 m", so no screen-off discharge was
  measured. All four accounts scanned (AOL 5m: 78 completed; Yahoo 15m: 52; Gmail 240m: 2; iCloud 720m: 1). Kept as
  scheduling evidence (Task 1 R-5, R-9). App battery 0.2% (01:06 and 08:09), background time 9 m -> 14 m, Wi-Fi
  4,686 -> 7,048 packets. Screenshots: `validation-screenshots/sprint-79/Screenshot_20261014_0{10542,10601,10610,
  80914,80922,80931}_Device care.png`.

**Acceptance criteria**: AC-1: three arms recorded with battery percent, scan count and a clean health check; AC-2: the
decision rule applied and recorded in the results doc; AC-3: if the floor changes, `scan_interval_test.dart` and the
help text change with it.

**Tests to write**: T-1 (AC-3, conditional) -- TEST-UNIT updates in `scan_interval_test.dart`.

**Definition of Done**: default DoD. **Model**: Haiku -- protocol written; reading screenshots and logs.
**Step-types**: DOCS, SVC-EDIT (conditional). **Est-Effort**: 30-45m + three nights.

## Task 3 -- F286: Background-scan notification names the account, "No rule" first, one per account (Priority 2)

**Value**: This lets the user tell which account each notification is for, and keeps one notification per account.

**Requirements**:
- R-1: One shared, pure Dart helper builds the title, the body and the notification ID; Android uses it now, Windows
  uses it in Task 4.
- R-2: Title `Back. scan k*@aol completed` -- the account masked as first letter, `*`, `@`, and the domain without its
  suffix. Body `No rule 9 Deleted 1 Safe 0`, with ` Errors N` only when N > 0. No colons or commas. (Text set by Harold,
  2026-10-10.)
- R-3: ID = FNV-1a of the account id, 31 bits, pinned by a test; replaces `accountId.hashCode`
  (`android_background_scan_worker.dart:379`). A newer notification for the same account replaces the older one.
- R-4: Modes other than live (`readOnly`, `rulesOnly`, `safeSendersOnly`, `email_scan_provider.dart:32-37`) show what
  was NOT acted on per Q1. Strikethrough rendering on the Fold is unverified; rehearse on the emulator, confirm on the
  phone (Q9).
- R-5: Mask limit recorded in the code comment: two accounts on one domain with the same first letter look alike.

**Affected components / files**:
- NEW `lib/core/services/scan_notification_text.dart` -- the helper.
- `lib/core/services/android_background_scan_worker.dart:378-382` -- use it.

**Existing abstraction checked**: `WindowsNotificationService._buildScanSummary` (`windows_notification_service.dart:125`)
is the only other summary builder; Task 4 removes it in favor of the shared helper. No other text helper found.

**User-reachable control**: N/A (a notification the scan posts; the existing per-account notification setting
controls it).

**Observable behavior -- before / after**: BEFORE: title `Background scan complete`, body `Processed 10: 1 deleted, 0
safe, 9 no rule`, no account. AFTER: title `Back. scan k*@aol completed` (`... read-only completed` per Q1), body
`No rule 9 Deleted 1 Safe 0`; one notification per account, the newest replacing the older one.

**Dependencies / blockers**: Q1.

**Non-functional requirements**: Accessibility -- TalkBack reads text, not strikethrough, so a title word carries the
mode (Q1 option 1). Platform -- shared Dart helper (parity); the Android delivery call is the existing plugin path.

**Acceptance criteria**:
- AC-1: The helper returns the exact title and body strings above for live mode, errors 0 and errors > 0.
- AC-2: The ID for a given account id is the pinned FNV-1a value, stable across runs.
- AC-3: Each non-live mode renders per the Q1 answer.
- AC-4: The Android worker posts through the helper (no `hashCode`, no old text left).

**Tests to write**: T-1 (AC-1, AC-3) -- TEST-UNIT `test/unit/scan_notification_text_test.dart`. T-2 (AC-2) -- same file,
pinned values. T-3 (AC-4) -- TEST-UNIT source gate plus a behavior test of the worker's notify step if a seam exists;
each test has its "what this does NOT catch" line.

**Definition of Done**: default DoD PLUS the emulator rehearsal screenshot of one notification.

**Model**: Haiku -- a pure function plus one call-site swap. **Delegation checklist included**: yes.
**Step-types**: SVC-NEW, TEST-UNIT. **Est-Effort**: 30-50m.
**Executed-by**: Opus 5.5 (session model), deviation note (a) -- ~25 min (42ba161); emulator rehearsal at 5.1.9.

## Task 4 -- F287: Windows background-scan completion toast (Priority 15)

**Value**: This gives Windows the same per-account completion notification Android has (today Windows never shows one).

**Requirements**:
- R-1: Audit first (done in 3.2.2.1): neither Windows service has a caller; Windows has never shown a scan notification.
- R-2: The Windows background scan (Task Scheduler launch, ADR-0014) posts one toast per account after each scan, with
  F286's text and ID helper; a newer toast for the same account replaces the older one.
- R-3: Route per Q2 -- **Q2 = 2, route 2 selected (Harold, 2026-10-13)**. Route 1 (not taken): wire `WindowsToastNotificationService` (ADR-0018), using the toast Tag (from the F286 ID)
  and a Group to replace per account, and the app ID the installed app is registered under (MSIX package app ID for
  the Store build; the DEV build's registration to be found, not assumed). Route 2: upgrade `flutter_local_notifications`
  to the version named after research (see the research note below) and use its Windows support; ADR-0018 superseded.
- R-4: The unused path is deleted (the other service), not left beside the chosen one.
- R-5: The per-account notification setting applies on Windows exactly as on Android. **Corrected at execution
  (2026-10-13)**: no such setting exists on either platform (`settings_store.dart` has none; Android posts for every
  COMPLETED scan and nothing for a stopped or skipped one, `BackgroundScanCore.completeAccount`,
  `background_scan_core.dart:106-128`). The parity rule implemented is that one: Windows posts only after a completed
  scan (the skip path `continue`s first). Turning notifications off is the OS's per-app setting on each platform.
  AC-2 reads accordingly: a skipped account posts nothing.

**Research note (read-only agent, 2026-10-13; sources pub.dev changelog and the plugin's native source, URLs in the
F287 backlog card)**:
- Windows support first in 19.0.0 ("[Windows] Added support for Windows."); latest stable 22.3.2.
- Breaking changes 17 -> 22 against this repo: 20.0.0 turns `initialize()` and `show()` positional parameters into
  named ones (rewrite `android_background_scan_worker.dart:361-386`); 19.0.0 needs `desugar_jdk_libs` 2.1.4 (repo
  2.0.4, `build.gradle.kts:217`). Flutter 3.47.4, compileSdk 36, minSdk 24, Java 17 and AGP 8.11.1 already meet every
  other floor. Changelog read to 100,000 characters only; the rest is UNVERIFIED.
- Windows init registers the app ID itself (HKCU `Software\Classes\AppUserModelId\<aumid>`); a packaged (MSIX) app uses
  its package app ID, an unpackaged DEV build its own. This removes route 1's unregistered-app-ID risk.
- Same ID replaces the toast (the plugin sets the toast Tag to the ID) -- inferred from source, UNVERIFIED on a device.
- Tap-to-open on the MSIX build needs `msix_config` `toast_activator` (inferred, UNVERIFIED). A toast from a Task
  Scheduler run as the logged-on user is expected to show (UNVERIFIED); the rehearsal settles both.
- Route 2 target: **22.3.2**, plus `desugar_jdk_libs` 2.1.4. Recommended: one plugin on both platforms (parity), and
  it handles app-ID registration that the PowerShell route would have to build.

**Affected components / files**: `windows_toast_notification_service.dart` and `windows_notification_service.dart`
(one kept, one deleted), the Windows background scan's post-scan step (`scan/post` "notification step"), `main.dart:339`,
`pubspec.yaml:58` (route 2 only), ADR-0018 / ADR-0042, ARCHITECTURE.md `:219`, `:491`.

**Existing abstraction checked**: `WindowsToastNotificationService` (ADR-0018) and `WindowsNotificationService` (plugin
placeholder) -- both found; one is kept.

**Callers of any guard being changed**: the post-scan notification step is shared by the Android worker and the
Windows background run; the change must not alter the Android branch. Tooling: the WinWright runner stops every
process of the exe between scripts -- a toast posted by a background run is harmless to it, but a PowerShell child
(route 1) must not outlive or block the background process exit; check the run ends.

**User-reachable control**: the existing per-account notification setting (Settings > Account > Background); no new
control.

**Observable behavior -- before / after**: BEFORE: a Windows background scan finishes with no notification. AFTER: a
Windows toast `Back. scan k*@aol completed` / `No rule 9 Deleted 1 Safe 0`, one per account, replaced by the next.

**Dependencies / blockers**: Task 3 (helper); Q2.

**Non-functional requirements**: Platform -- ADR-0042: text and replacement rule are PARITY; the delivery mechanism
(WinRT toast vs Android notification channel) is the declared exception. Security -- route 1 writes a temporary
PowerShell script; the account text in it is escaped (existing escaping at
`windows_toast_notification_service.dart:92`) and the file is deleted after use.

**Acceptance criteria**:
- AC-1: Given a Windows background scan completes for an account with notifications on, Then exactly one toast with the
  F286 title and body appears, and a later scan of the same account replaces it.
- AC-2: With the account's notification setting off, no toast appears.
- AC-3: Android notification behavior unchanged (Task 3 tests still pass; route 2: the Android call sites compile and
  the emulator rehearsal shows the notification).
- AC-4: Only one Windows notification service remains in `lib/`.

**Tests to write**: T-1 (AC-1, AC-2) -- TEST-UNIT on the Windows notify step with a fake notifier (title, body, tag,
enabled/disabled). T-2 (AC-4) -- policy gate that the removed service is gone. Manual: a real toast on the DEV build
(rehearsed by Claude at 5.1.9 on this PC before handover).

**Definition of Done**: default DoD PLUS a toast observed on Harold's PC from a real Task Scheduler run, and ADR-0018
amended (route 1) or superseded (route 2).

**Model**: Sonnet -- *why not Haiku*: OS registration (app ID, MSIX identity) and, in route 2, a major dependency
upgrade across both platforms.
**Step-types**: SVC-EDIT, NATIVE-WIN, TEST-UNIT. **Est-Effort**: route 1 60-90m; route 2 90-150m.
**Executed-by**: Opus 5.5 (session model), deviation note (a) -- ~60 min (b4cbef5), route 2; Task Scheduler toast at
5.1.9.
**Risk & rollback**: an unregistered app ID makes Windows drop the toast with no error (UNVERIFIED this session; the
5.1.9 rehearsal on this PC settles it before Harold sees it); rollback = revert the commit, Windows returns to no toast.
**Decision-class interrupts**: route 2 supersedes ADR-0018 (Class 1) -- asked as Q2.

## Task 5 -- F288: Git-flow branch model, `develop` the GitHub default branch (Priority 3)

**Value**: This makes `Closes #N` close issues when a sprint PR merges into `develop`, and writes the release step down.

**Requirements**: Harold's instructions in the master-plan F288 card, verbatim, in order:
- R-1 PHASE A (change nothing): default branch; `develop` local and remote; commits each way and whether main-only
  commits change files; open PRs and bases; CI triggers; Dependabot, rulesets, CODEOWNERS; every branch-name hit in
  scripts, hooks, docs and tests classified must-change / fine / history. Findings as bullets, then a numbered list of
  proposed changes. STOP for approval (the planned mid-sprint pause, Q-S2).
- R-2 PHASE B (approved items only): default `develop` (`gh repo edit --default-branch develop`, `git remote set-head
  origin -a`); CI on pull_request into develop AND main; Dependabot target `develop` if present; retarget only approved
  PRs; fix must-change hits; write the release step "PR develop -> main, merged by the owner, then tag the merge". Never
  edit history records. On this sprint's branch, PR into develop, suite run before committing.
- R-3 PHASE C: verify and report (default branch, a no-`--base` `gh pr create` targets develop, CI triggers, the
  `Closes #N` note).
- R-4: Commit messages follow Q3.

**Affected components / files**: `.github/workflows/ci.yml`, CLAUDE.md branch policy, `SPRINT_EXECUTION_WORKFLOW.md`,
`.claude/sprint_status.json` `github_issues.note`, and whatever Phase A finds.

**Callers of any guard being changed**: hooks and scripts that read the default branch or `origin/HEAD` -- listed in
Phase A item 5.

**Dependencies / blockers**: Harold's Phase A approval (outward-facing repository setting).

**Acceptance criteria**: AC-1: Phase A report delivered as bullets plus a numbered list; AC-2: `gh repo view --json
defaultBranchRef` reads `develop`; AC-3: CI triggers include develop and main; AC-4: no must-change hit remains; AC-5:
this sprint's PR body uses `Closes #N` and the cards close on merge (observed at 8.1).

**Tests to write**: T-1 (AC-4) -- re-run the Phase A grep and show zero must-change hits; hook suite
(`run-test-cases.ps1`) if any hook changes.

**Definition of Done**: default DoD PLUS no branch deleted, no PR merged.

**Phase A report (2026-10-13, read-only, nothing changed)**:
- Default branch `main`; `origin/HEAD` -> `origin/main`. `develop` exists locally and on origin.
- `origin/main` has 49 commits `develop` lacks, all "Merge pull request #N from kimmeyh/develop"; `git diff --stat
  <merge-base 7d3b71a> origin/main` is EMPTY, so they change no files. `develop` has 0 commits `main` lacks. No merge
  of main into develop is needed.
- Open PRs: only #480 (feature/20261013_Sprint_79 -> develop, draft). Nothing to retarget.
- CI: one workflow, `.github/workflows/ci.yml`, `on.pull_request.branches: [develop]` -- release PRs into `main` run no
  CI today. No `push` trigger, so the default-branch change starts or stops nothing by itself. (Side note: CI pins
  Flutter 3.38.5; local is 3.47.4.)
- Dependabot: none. CODEOWNERS: `* @kimmeyh`, no branch names. Branch protection: none on main or develop (404).
  Ruleset 15061270 "PR Rules (All Branches)": rules deletion, pull_request, code_scanning; `ref_name.include` is EMPTY
  -- which branches GitHub applies it to is UNVERIFIED this session; not changed by this card.
- Tags: one tag (`v0.5.0`); ADR-0015:84 already says "Tag the release", so releases 0.6.0-0.19.0 were never tagged.
- Branch-name grep (scripts, hooks, skills, docs, tests, lib; history files excluded), 111 lines:
  - MUST CHANGE (they state `Closes #N` does not fire): `require-sprint-cards.ps1:163-165`,
    `verify-closeout-complete.ps1:471` (message), `.claude/skills/phase-check/SKILL.md:37`,
    `SPRINT_CHECKLIST.md:166-167`, `.claude/sprint_status.json` `github_issues.note`; plus the release step (tag the
    merge) in CLAUDE.md branch policy, `AGENTS.md` (mirror), `STORE_RELEASE_PROCESS.md` Step 5, and an ADR-0015 note
    that `develop` is the default branch.
  - FINE AS IS: every explicit `--base develop` (still correct), "main is the release branch" statements, the prod
    worktree's `git checkout main` steps, `CHANGELOG_POLICY.md` (already GitFlow).
  - HISTORY (never edited): `docs/sprints/*`, CHANGELOG, master-plan sprint records, `SPRINT_EXECUTION_WORKFLOW.md:83`
    (Sprint 50 failure record), `sprint_status.json` per-sprint "Closed by hand" lines.
  - FALSE MATCHES: "master plan", "maintain", "main rules file", `main.cpp`.

**Phase B (Harold QF1 = 2, QF2 = 1 and 2, QF3 = 1, 2026-10-14)**:
- Default branch: `gh repo edit --default-branch develop`; `git remote set-head origin -a` -> `origin/HEAD` =
  `origin/develop`; `gh repo view --json defaultBranchRef` = `develop` (AC-2).
- CI on PRs into main: NOT done (Harold: "DO NOT"); AC-3 withdrawn by Harold -- CI stays develop-only.
- Must-change texts fixed (no hook logic changed): `require-sprint-cards.ps1:163-166`,
  `verify-closeout-complete.ps1:471`, `phase-check/SKILL.md:37`, `SPRINT_CHECKLIST.md:166-167`,
  `sprint_status.json` `github_issues.note`, plus `SPRINT_EXECUTION_WORKFLOW.md:83` (made past tense) and `:1686`.
  Hook suite 136/136.
- Release step written: CLAUDE.md and AGENTS.md (new "Default branch and the release step" subsection),
  `STORE_RELEASE_PROCESS.md` Step 5 (tag commands), ADR-0015 amendment.
- Tags: 22 annotated tags pushed (list and evidence rule in the ADR-0015 amendment); remote now has 23 with v0.5.0.
  Map built from the prod worktree reflog, STORE_VERSION_STATUS and sprint_status history.
- QF3: F296 added to the master plan (CI Flutter version kept in sync with local; TARGET SPRINT 80).

**Model**: Haiku for Phase A and the doc edits -- the steps are fully specified; session model per the deviation note.
**Step-types**: DOCS, HOOK (conditional). **Est-Effort**: 45-90m.
**Risk & rollback**: the default-branch switch is reversible (`gh repo edit --default-branch main`); CI edit reverted by
commit.

## Task 6 -- F291: A WinWright sweep on a locked PC counts as complete (Priority 4)

**Value**: This stops the sweep gate from blocking close-out when the PC is locked, while keeping the regression check.

**Requirements**:
- R-1: On a locked workstation the runner (`mobile-app/scripts/run-winwright-tests.ps1`) runs every cursor-free step,
  SKIPS the steps that need the input desktop (today the six pinned in `winwright_script_strings_test.dart:103`
  `knownPending`), names them in the summary, and reports the sweep complete.
- R-2: A step skipped for any OTHER reason still fails its script (the F284 rule).
- R-3: The sweep record reads "locked: N mouse steps skipped"; close-out check 3e (`verify-closeout-complete.ps1:256-290`)
  and the F193 gate (`sprint-auto-advance.ps1` 5.1.5 pattern) accept it.
- R-4: Guard per Q4.

**Affected components / files**: `run-winwright-tests.ps1`, `verify-closeout-complete.ps1`, `sprint-auto-advance.ps1`
(only if its pattern rejects the new record), hook test cases, `TESTING_STRATEGY.md`, ADR-0040.

**Existing behavior relied on**: the runner refuses a locked PC today -- header `run-winwright-tests.ps1:18-37`, gate
near `:276`.

**Callers of any guard being changed**: the lock gate's callers are the 5.1.5 sweep (Claude) and any direct run; the
skip list is shared with the policy test. Tooling: none else launches the runner.

**Acceptance criteria**: AC-1: a locked-PC run (simulated by the runner's lock-check seam) skips exactly the
`knownPending` steps and exits 0 with them named; AC-2: a non-listed skipped step still exits non-zero; AC-3: check 3e
and the F193 gate accept a "locked: 6 mouse steps skipped" record and still reject a missing record.

**Tests to write**: T-1 (AC-1, AC-2) -- runner self-test or a hook test case with a fake lock state. T-2 (AC-3) -- new
`.claude/hooks/test-cases/` allow and block cases; failure-path proven by feeding a missing record.

**Definition of Done**: default DoD PLUS `powershell -NoProfile -ExecutionPolicy Bypass -File
.claude\hooks\run-test-cases.ps1` green after the hook edits.

**Model**: Sonnet -- *why not Haiku*: gate edits have regressed their own allow-cases before (Sprint 67 IMP-2).
**Step-types**: HOOK, DOCS. **Est-Effort**: 40-70m.
**Executed-by**: Opus 5.5 (session model), deviation note (a) -- ~35 min (7dbf56c); hook suite 136/136.

## Task 7 -- F292: Full test suite, test processes die or hang (Priority 5)

**Value**: This prevents a real regression from being dismissed as noise in a red suite.

**Requirements**:
- R-1: Reproduce: N full runs (`flutter test --concurrency=4`) on HEAD under the Sprint 78 conditions (DEV app open,
  DEV background scanning at 5 minutes, analysis server), then with DEV background scanning OFF; record commit charge
  (Task Manager's "Committed" or `Get-Counter '\Memory\Committed Bytes'`) every 30 s during each run.
- R-2: Record for each run whether it was before or after the reboot that applies the larger page file.
- R-3: Name the mechanism (flutter_tester crash, timeout, shared temp or DB file, memory), or write "cause unknown"
  plus what would settle it. Never "flaky".
- R-4: Fix or contain it, prevention first (for example a suite runner that records commit charge and the failing file).

**Affected components / files**: test runner scripts (`/full-test` skill or `scripts/`), possibly `dart_test.yaml`; the
failing files named in the master-plan card.

**Dependencies / blockers**: Harold's reboot for the page-file change (runs before it are labeled as such).

**Acceptance criteria**: AC-1: at least 3 runs recorded with conditions, result and peak commit; AC-2: a named
mechanism or "cause unknown" with what would settle it; AC-3: a fix or containment, with its test or self-check.

**Tests to write**: T-1 (AC-3) -- the containment's own self-test (for example the runner flags a failed-to-load file).

**Runs (2026-10-13, all BEFORE the page-file reboot: boot 2026-10-08 16:07, page file 30,840 MB)**:
- Run 1 (`flutter test --concurrency=4`, DEV app state not recorded): 3,028 passed, 15 skipped, 1 failed
  (`release_notes_test`: the Task 0 notes gap, fixed in 15a243a); 0 test-load failures; 2 min 33 s.
- Run 2 (DEV app closed): exit 0, 3,037 passed, 0 test-load failures, peak commit 56.6 of 93.8 GB, 2 min 29 s.
- Run 3 (DEV app OPEN, all four DEV accounts scanning every 5 minutes -- the Sprint 78 conditions; Yahoo and AOL
  scans ran during it): exit 0, 3,037 passed, 0 test-load failures, peak commit 56.2 of 93.8 GB, 2 min 37 s.
- Run 4 (2026-10-14 10:34, `prereboot-4-q1fix`): **no tests ran -- a RUNNER defect.** `run-full-suite.ps1:64` passed
  `[bool]$SelfTestStall` in argument mode, which is the string "[bool]False" (truthy), so the job took the
  self-test hang and the watchdog reported STALLED after 10 minutes. The promoted script's NORMAL path had never been
  run (only `-SelfTestStall` was proven). Fixed: `-ArgumentList @(..., $SelfTestStall.IsPresent)`, plus a guard
  that prints `RUNNER DEFECT` and exits 3 if the self-test line appears in a run that did not ask for it; the guard
  was proven by restoring the exact old line under a mutation lock (`RUNNER DEFECT`, exit 3; file restored).
  `results.txt` keeps the misleading STALLED line for this run.
- Run 5 (2026-10-14 10:46, runner fixed, `guardcheck`): exit 0, **3,046 passed, 15 skipped, 0 failed**, 0
  test-load failures, peak commit 73.5 GB (higher than runs 2-3: two DEV app processes and the Android emulator
  were running), 3 minutes.
- **Mechanism: cause unknown** -- not reproduced in three runs, one under the Sprint 78 conditions. Leading hypothesis
  (UNVERIFIED): commit-charge pressure from other processes; on the Sprint 78 failure day the AAB build died at 86
  of 94 GB committed, while these runs peak at about 56 GB. Nothing recorded commit charge during the Sprint 78
  failing runs, which is why the question cannot be settled from them. What settles it: the next failing run, with
  its commit charge recorded.
- **Containment (prevention first, done)**: `scripts/run-full-suite.ps1` (promoted from the Sprint 79 scratch helper
  used for runs 2-3): records boot time, page file, DEV app state, commit charge every 30 s, test-RUNNER load
  failures only (the first draft counted 63 false hits from the app's own "Failed to load credentials" log lines),
  and STALLED after `-StallMinutes` (default 10) without output, stopping only the testers it started. Failure
  path proven: `-SelfTestStall -StallMinutes 1` reported `STALLED(1m)` and exit 2. Phase 5.2 now runs the suite
  through it (`SPRINT_EXECUTION_WORKFLOW.md` 5.2). Post-reboot runs are labeled when Harold reboots.

**Definition of Done**: default DoD.

**Model**: Sonnet -- *why not Haiku*: diagnosis across process, memory and test-runner layers; escalate to Fable/Opus
after two rounds without a mechanism.
**Step-types**: TEST-INTEGRATION, DOCS. **Est-Effort**: 60-120m (mostly wall-clock runs).

## Task 8 -- F293: Backlog refinement shows the next 20, details in the same order (Priority 6)

**Value**: This makes each candidate easy to find: one list, one order, index and details matching.

**Requirements**:
- R-1: `BACKLOG_REFINEMENT.md:443-500` "Backlog Presentation Format": the Summary Index lists the next 20 active
  candidates by priority; the details follow in the SAME order, with no phase-group headers (each card keeps its
  `Phase:` bullet); HOLD items stay one line each in the index.
- R-2: Update the restatements at `SPRINT_EXECUTION_WORKFLOW.md:160-161` and `SPRINT_CHECKLIST.md:30,40`; replace the
  "Group items under section headers by phase" rule (`BACKLOG_REFINEMENT.md:498`); add a version-history line.
- R-3: The master plan's storage layout per Q5.

**Observable behavior -- before / after**: BEFORE: "Candidates at a glance" lists 10, details grouped under phase
headers. AFTER: it lists 20, and the details follow in the same order with no group headers.

**Acceptance criteria**: AC-1: no remaining text in the four files requires phase grouping or 10 items; AC-2: the
example in `BACKLOG_REFINEMENT.md` shows 20-item order with matching detail order.

**Tests to write**: T-1 (AC-1) -- grep the four files for "Group items under section headers" and "next 10"; zero hits.

**Definition of Done**: None -- default DoD only (CHANGELOG `chore`/`docs` entry).

**Model**: Haiku -- doc edit fully specified. **Step-types**: DOCS. **Est-Effort**: 15-25m.
**Executed-by**: Opus 5.5 (session model), deviation note (a) -- ~15 min (360008e).

## Task 9 -- F297: Reload rules and safe senders after a YAML import (#488) (added mid-sprint, Harold 2026-10-14)

**Value**: This makes an imported rules or safe senders file take effect at once, without restarting the app.

**Origin**: Harold, 2026-10-14, Windows 0.20.0 [DEV]: *"Please add to for this sprint: backlog item to reload/refresh
all rules after rule upload and safe sender rules upload. Sprint Card, testing..."* and *"Wouldn't it seem that the
reload after a manual scan would be the same thing needed here? Could that be re-used"*. Scope addition by the Scrum
Master (stopping criterion 3, approved in the request).

**Finding (evidence)**: Review No Rule Items read 386 before and after importing the Fold's exports. A copy of the DEV
database after the import held 2,074 rules and 405 open No Rule rows, so the import landed. The screen checks rows
against `RuleSetProvider` (`no_rule_review_screen.dart:350-365`), which loads only when it has never loaded; the import
wrote the stores (`yaml_import_export_screen.dart:566,633` before the fix) and never reloaded it. aglimertoe.com and
brarpy.net have imported block rules and were still listed. A manual scan reads the same provider at its start
(`email_scanner.dart:353`), so the first scan after an import also used the old rules. Replaying the imported patterns
over the database copy (Python approximation of the Dart matcher): about 165 of the 405 rows would clear and about 240
would remain, so the count does not drop to 0 after the fix. Why the Fold shows 0 is not established (its pool holds
the Fold's own scans; unverified).

**Requirements**:
- R-1: After a successful rules or safe senders import, the in-memory rules AND safe senders reload from the database.
- R-2: Re-use (Harold): one `RuleSetProvider.reloadFromDatabase()` replaces the identical `loadRules()` +
  `loadSafeSenders()` pair at the four existing sites (post-scan, Scan History load, quick-action safe sender,
  quick-action block rule).
- R-3: `reloadFromDatabase()` returns false when a load failed; the import then says so instead of "successfully".

**Affected components / files**:
- `mobile-app/lib/core/providers/rule_set_provider.dart` -- `reloadFromDatabase()`.
- `mobile-app/lib/ui/screens/yaml_import_export_screen.dart` -- `commitRulesImport` / `commitSafeSendersImport`
  (save, YAML copy, reload); both handlers call them; a failed reload shows an error status.
- `mobile-app/lib/core/services/email_scanner.dart` -- post-scan reload uses it and logs failure from its result (the
  old `catch` could never run: both loads swallow their errors, so "reloaded" was logged even on failure).
- `mobile-app/lib/ui/screens/results_display_screen.dart`, `mobile-app/lib/core/services/rule_quick_action_service.dart`
  -- the pair replaced.

**Existing abstraction checked**: `RuleSetProvider.loadRules` / `loadSafeSenders` (the four call sites above) and the
load-if-missing guards `_ensureRulesLoaded` / `_ensureSafeSendersLoaded` (`rule_quick_action_service.dart`) and
`no_rule_review_screen.dart:356-361`. The guards serve a different purpose and are unchanged.

**Existing behavior relied on**: `loadRules()` clears `_error` when it starts -- verified at
`rule_set_provider.dart` `_setLoadingState` (a non-error state sets `_error = null`).

**Callers of any guard being changed**: none changed. The four replaced sites behave the same except the scanner,
which now logs a failed reload as a warning.

**Observable behavior -- before / after**: BEFORE: after an import, Review No Rule Items and the next manual scan use
the pre-import rules until the app restarts or a scan completes. AFTER: they use the imported rules at once; a failed
reload shows "Imported N rules, but they could not be loaded. Restart the app to use them."

**Platform (ADR-0042)**: shared code, no exception. The import screen, provider and scanner run identically on Windows
and Android; the Android background worker builds its own provider per run and is unaffected.

**Acceptance criteria**:
- AC-1: Given rules and safe senders saved behind the provider, When `reloadFromDatabase()` runs, Then it holds them
  and returns true.
- AC-2: Given a rules or safe senders load that throws, Then it returns false; a later good reload returns true.
- AC-3: An import committed through `commitRulesImport` / `commitSafeSendersImport` is visible in the provider with no
  restart.
- AC-4: No inline `loadRules();` + `loadSafeSenders();` pair remains in `lib/` outside the provider.

**Tests**: T-1..T-3 (AC-1..AC-3) TEST-UNIT `test/unit/providers/rule_set_provider_reload_test.dart`, real ffi
database, 6 tests. T-4 (AC-4) grep, zero hits. What the tests do NOT catch: a screen that writes the stores itself
(see the follow-up below), and the screen's call into the commit functions (no file picker fake; covered by review).

**Evidence**: 6/6 pass; mutations M1-M6 KILLED (reload skips rules, skips safe senders, always true; rules commit and
safe senders commit without reload; rules commit skips the YAML copy); `flutter analyze` clean; full suite 3,052
passed, 15 skipped, 0 failed (run-full-suite.ps1 label f297, 3 minutes).

**Follow-up (not in scope)**: the Rules and Safe Senders management screens (edit, delete, remove) and the quick-add
screens also write the stores directly and do not reload the provider. Harold, 2026-10-15 (C = 2): backlog, F298
(TARGET SPRINT 80). Windows DEV background scans stay ON (D = 2: they collect data on all mail for spam analysis);
the 2026-10-14 DEV build was run with the four `*_Dev` tasks disabled for the build and re-enabled after.

**Definition of Done**: default DoD, plus Harold re-checks Review No Rule Items after an import on the rebuilt DEV app.

**Model**: Sonnet -- 5 files and a shared provider method. **Executed-by**: Opus 5.5 (session model), deviation
note (a). **Step-types**: SVC-EDIT, TEST-UNIT. **Est-Effort**: 30-45m.

---

# Phase 5 evidence

- **5.1.2 F-PRECHECK**: PENDING
- **5.1.5 WinWright sweep**: PENDING
- **5.1.9 MV rehearsal**: PENDING (partial evidence below; Android emulator rehearsal of F286 still to run)
  - F287 Windows toast, REAL Task Scheduler path (2026-10-13, DEV release build at b0e8ca5+, Windows DEV background
    ON at 5 minutes for all four accounts): the Gmail task launched `--background-scan --account-id=...` at 20:21:01;
    its log says "Completion notification step done" at 20:21:20 and 20:26:25. Proof from Windows' own notification
    store (`wpndatabase.db`, read from a copy): handler `MyEmailSpamFilter.Dev` (app:desktop); one toast per
    account, tags = the pinned FNV-1a IDs (AOL 772562602, Yahoo 663563768, Gmail 1988489478, iCloud 2019592444);
    text "Back. scan k*@gmail read-only completed" / "No rule 0 Deleted 0 Safe 0". After the second Gmail run the
    store holds ONE Gmail toast (id 129153 replaced 129149): replacement per account proven. The read-only title
    word shows on Windows (Q1 parity).
  - Side finding: the store also held many "MyEmailSpamFilter Background Scan Complete / Found 10 unmatched emails
    in 5 accounts" toasts under the ADR-0018 app ID `MyEmailSpamFilter.BackgroundScan` -- posted by the deleted
    `windows_toast_notification_service_test.dart` on every full test run. Deleting that test ends it.
- **5.2 full suite**: PENDING

# Phase 7 evidence

- **7.7.1 final code reviews**: PENDING
- **5.2.3 architecture docs**: PENDING

## Manual Validation steps (Sprint 79 -- re-present IN FULL every time Harold is asked to validate)

Written at Phase 5 after the 5.1.9 rehearsal. Fold steps 8-11 (Task 1) and the three F277 nights (Task 2) are handed
over in full right after plan approval, since they run on the installed 0.19.0 and do not wait for sprint code.
