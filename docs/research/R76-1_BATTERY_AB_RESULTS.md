# R76-1 Battery A/B results, first half (Sprint 77, Issue #464)

**Status**: arms 1 and 2 measured on today's code (0.18.0+15 dev debug build, before F264). Arm 7 is BLOCKED
(see below). Arms 3-5 were measured on the F264 build (second half section); arm 6 was not run (backlog item).
**Date**: 2026-10-07. **Author**: Claude Code (Sonnet 5.5), Sprint 77 Task 4 first half.

## What an emulator cannot show (read first)

- **Energy.** An emulator has no battery hardware and no on-device power monitor. Nothing here is mAh or mW.
  Per Google: "To use Batterystats and Battery Historian, you need a mobile device with USB debugging enabled"
  (developer.android.com/topic/performance/power/setup-battery-historian), and Power Profiler "reads power
  consumption data from the ODPM, which is only available on Pixel 6 and subsequent Pixel devices"
  (developer.android.com/studio/profile/power-profiler). Every number below is a COUNT or a duration that
  drives energy. Absolute energy needs the Fold (Settings > Battery screenshot over MTP), a named follow-up.
- **Real mail traffic.** The accounts are fakes (see Setup), so each scan fails at IMAP login. Bytes and CPU
  per scan are the cost of connect plus a failed login, NOT of listing folders and fetching mail.
- **Real radio cost.** Emulated Wi-Fi has no radio tail, so network bytes are comparable between arms but not
  convertible to energy.

## Setup (what was actually run)

- Emulator 36.2.12.0 from `$env:ANDROID_HOME\emulator` (the `emulator` on PATH is `C:\Android\android-sdk\tools\emulator.exe`
  and was NOT used). AVD `pixel34_updated`, API 34 (google_apis_playstore, x86_64). Cold boot to `sys.boot_completed`
  took about 4 minutes. adb 36.0.0.
- Build: `mobile-app/scripts/build-with-secrets.ps1 -BuildType debug -Env dev -InstallToEmulator -SkipUninstall`
  (package `com.myemailspamfilter.dev`).
- **Deviation to disclose**: the first build used the script's default flavor (prod, package
  `com.myemailspamfilter`) with `-SkipUninstall`. That package ALREADY held Harold's real accounts and data on this
  AVD (seen in a screenshot of the Review screen). It was upgraded in place with its data intact, force-stopped, and
  DISABLED (`pm disable-user`) for the whole run, then re-enabled afterward. No scan ran in it. All measurements use
  the isolated DEV flavor, which had no accounts. Recommendation: use `-Env dev` for every emulator test.
- Two FAKE accounts, entered through the app's setup screens (no connection test, no real credentials):
  `r761test1@aol.com` (AOL) and `r761test2@yahoo.com` (Yahoo), password a 16-letter dummy. Gmail was not possible
  (OAuth only), so the "one gmail, one aol" input became "one yahoo, one aol". Both: background ON, every 15
  minutes, Read-Only mode, diagnostic log ON (writes to `/storage/emulated/0/Documents/diagnostics_Dev`).
- Notification source (Harold Q15 = 1): `adb shell cmd notification post` posts as `com.android.shell`. That package
  is in the new `MailNotificationPolicy.DEBUG_ONLY_PACKAGES`, accepted only when `BuildConfig.DEBUG` is true. The
  real Gmail app IS preinstalled (`com.google.android.gm`) but has no signed-in account, so it cannot post. The
  listener was bound with `adb shell cmd notification allow_listener com.myemailspamfilter.dev/com.myemailspamfilter.MailNotificationListener`.
  End to end proof: a probe post produced `trigger=notification app=com.android.shell delay=2s`.
- Script: `mobile-app/scripts/r76_battery_arm.sh <arm> <minutes> <cadence-minutes>`. Summary:
  `mobile-app/scripts/r76_battery_summarize.py <arm dir>`. Raw files for each arm are in `docs/research/R76-1_raw/`.

## Protocol (per arm)

1. `am set-standby-bucket` to `working_set` (the same for every arm; it limits alarms to 10 per hour).
2. `dumpsys battery unplug`, `dumpsys batterystats --reset`, snapshot `dumpsys alarm`, `jobscheduler`,
   `batterystats <pkg>`, `netstats detail` (after `cmd netstats poll`; added after arm 1, see arm 1).
3. Screen off. Wait 2 minutes. `dumpsys deviceidle force-idle` (device reported `IDLE` at the end of both arms).
4. Window, then the same snapshots, `deviceidle unforce`, `battery reset`, pull the diagnostic log.
- **Deviation**: the protocol says 60 minutes. The 120-minute emulator budget for this half allowed 35-minute
  windows (about 2,100 s after force-idle). Counts below are for that window and are NOT scaled to 60 minutes.
- "Scans started" = `[SCAN] [worker/android] start ... trigger=` lines in the diagnostic log. One start line is
  one worker run; a notification or alarm worker covers all accounts, a periodic worker covers one account.

## Arm 1: periodic only, interval 15, new-mail OFF (baseline)

- Window 2,234 s (2,110 s after force-idle). Notifications posted: 0.
- Scans started after force-idle: **5** (periodic 4, doze-alarm 1). Offsets after force-idle: 390 s periodic,
  437 s periodic, 1,348 s doze-alarm, 1,598 s periodic, 1,645 s periodic.
- Longest gap between consecutive scans: **911 s** (15.2 minutes). First scan 390 s after force-idle. Last scan
  465 s before the window end.
- Wakeup alarms for the app UID (`dumpsys alarm` and batterystats agree): **2** (`ACTION_DOZE_SCAN`).
- Jobs (batterystats): 1 job run recorded, 9.4 s, completions `successful_finish(2x)`. `dumpsys jobscheduler` history
  shows app job STARTs at -38m (before the window) and two at -12m42s (the doze-alarm minute).
- CPU time for the UID: user 37.7 s + system 53.0 s (see the CPU caveat below). Partial wakelock: 9.4 s.
- Network bytes: **NOT CAPTURED** for arm 1. The netstats snapshot was added after arm 1 finished, and
  batterystats for the app UID lists no network line on this image.
- Observation, cause unverified: four of the five worker starts have no matching JobScheduler START in the
  history. The log shows a periodic start about 6.5 minutes after force-idle although Doze "doesn't let
  JobScheduler run" (Android doze-standby page). WorkManager's in-process scheduler running while the process is
  alive is a candidate. What would settle it: log `Thread`/scheduler identity in the worker, or run with the
  app process killed (`am kill`) between runs.
- Both fake accounts fail login each run, so WorkManager applies its retry backoff. Some "periodic" starts are
  likely retries of an earlier failure, not new 15-minute ticks. Real working accounts would not do this.

## Arm 2: new-mail ON (all accounts, today's F253 trigger), interval 15, a debug notification every 5 minutes

- Window 2,228 s (2,105 s after force-idle). Notifications posted: **7** (at 0, 5, ... 30 minutes).
- Scans started after force-idle: **12** (notification 7, doze-alarm 3, periodic 2). Offsets: 2 s n, 303 s n, 541 s
  alarm, 603 s n, 903 s n, 1,203 s n, 1,504 s n, 1,623 s p, 1,671 s p, 1,804 s n, 2,042 s alarm, 2,043 s alarm.
- Each notification started its scan **1 to 2 seconds** after it was posted (`delay=1s` or `2s`), even while the
  device was force-idle. Today's code does NOT wait before a triggered scan. Every post 5 minutes apart produced
  its own scan, because the listener gap is 2 minutes. (The R-4 item 6 text "the scan waits 5 minutes anyway"
  describes F264 design, not today's code.)
- Longest gap between consecutive scans: **301 s**. First scan 2 s after force-idle.
- Wakeup alarms for the app UID: **4** (batterystats) = 6 minus 2 present before the window (`dumpsys alarm`).
- Jobs (batterystats): **9** job runs, 1 m 45 s, completions `successful_finish(5x) canceled(6x)`.
- CPU time for the UID: user 14.8 s + system 30.6 s. Partial wakelock: 1 m 23.8 s blamed (1 m 45.3 s actual).
- Network (`dumpsys netstats detail`, uid 10194, FOREGROUND set, 2-hour bucket, after `cmd netstats poll`):
  received 23,396 -> 162,664 B (+139,268 B), sent 4,790 -> 31,770 B (+26,980 B). The "before" value was taken
  at the start of arm 2, so the delta covers arm 2 plus any traffic not yet flushed when it started (a probe scan
  ran about 1 minute earlier). Treat as an upper bound for arm 2. The set label FOREGROUND is Android's, on a
  device with the screen off; why is unverified.

## Comparison (arm 2 against arm 1, same 35-minute shape)

- Scans started: 12 against 5 (2.4 times). Longest gap: 301 s against 911 s.
- Alarm wakeups: 4 against 2. Job runs: 9 against 1. Partial wakelock: about 1 m 45 s against 9 s.
- CPU is NOT a fair comparison: arm 1 ran straight after UI setup with the Flutter process warm, and its
  process-level CPU is dominated by that. Use scan, wakeup, job and wakelock counts.
- This is the cost of "scan on every mail notification" at one notification per 5 minutes on 2 accounts. It does
  not show a coverage benefit, and it does not show energy.
- Conclusion supported by the data: today's all-accounts trigger multiplies work roughly with the notification
  rate, bounded only by the 2-minute listener gap. Whether a 5-minute floor is right needs arms 4-6.

## Arm 7: Scan Range all against 1 day on triggered scans (Android half): BLOCKED

- A fake account has no mailbox, so a scan never lists or fetches mail and the bytes cannot differ by range. No
  test mailbox is available without real credentials, which this task forbids. Nothing was measured.
- To unblock: a local IMAP server over TLS on the host (`10.0.2.2` from the emulator) plus F192 custom server
  support (Sprint 77 Task for Custom IMAP). Then run two arms identical to arm 2 except Scan Range (Background
  tab) 1 day against All, with a mailbox of known size, and compare the netstats delta.
- **Windows half (for the lead, later)**: build the dev exe, set the same account to Scan Range 1 day then All,
  run `--background-scan --account-id=<id>` once per setting against the same mailbox, and read the fetched message
  count and bytes from the scan log. Do not run the Windows build while any Android build or emulator test runs.

## Second half: arms 3-5 on the F264 build (Sprint 77 Task 4 second half)

**Build**: `build-with-secrets.ps1 -BuildType debug -Env dev -InstallToEmulator -SkipUninstall` from HEAD 31e3aeb
(0.18.0+15, dev debug, package `com.myemailspamfilter.dev`; the prod package was not touched and was not disabled).
Same AVD, same two fake accounts, same standby bucket, Read-Only mode, diagnostic log ON. Notification access was
still granted after the reinstall (verified in `enabled_notification_listeners`).
**Deviation**: each arm is a 20-minute window after force-idle at minute 2 (about 1,205 s of idle), not 35 or 60
minutes, to fit the remaining emulator time. Arms 1 and 2 used about 2,110 s. Counts are NOT scaled; where arms are
compared the table below normalizes to 1,205 s of idle and says so. Emulator time for this half: about 95 minutes
including the build and the settings changes made through the app UI.
**Energy is not measured** (see the first section). Network bytes are NOT captured: the per-UID netstats history did
not change between the before and after snapshots of arms 3, 4 and 5 (the uid 10194 bucket stayed at rb=162,664 for
arm 3 and rb=192,856 for arms 4 and 5), so no byte figure is claimed. The scans are failed logins, so their bytes are
small anyway.
**Settings per arm** (set through Settings > Background, per account, then verified by screenshot):
- Arm 3: AOL interval 15 min, new-mail ON. Yahoo interval 15 min, new-mail OFF. Shell notification every 5 min.
- Arm 4: both accounts interval 5 min ("Background scan scheduled every 5 minutes" toast), new-mail OFF for both.
- Arm 5: both accounts interval 5 min. AOL new-mail ON, Yahoo OFF. Shell notification every 5 min.
Note on labels: a notification worker logs `start (all accounts) trigger=notification` even when the per-account filter
then skips accounts. Count scans with the `[scan/background] <account> start --` lines, as the summarizer now does
(it also counts the `account <addr> not selected by this notification` lines).

### Per-arm numbers

- **Arm 3 (new-mail ON per account, interval 15, 4 notifications)**: worker starts 4 (all notification, at +3, +302,
  +603, +903 s). Account scans run: AOL 4, Yahoo 0. Yahoo skipped by the filter: 4. Doze-alarm and periodic starts: 0.
  Longest gap 301 s. App-UID wakeup alarms in the window: 0 (6 before, 6 after). Jobs: 4 runs, 33.7 s, completions
  `successful_finish(3x) canceled(1x)`. Partial wakelock 33.7 s actual (20.7 s blamed). CPU user 12.7 s + system 29.3 s.
- **Arm 4 (interval 5, new-mail OFF, no notifications)**: worker starts 3, all `doze-alarm`, at +365 s (Yahoo only),
  +889 s (Yahoo and AOL). Account scans run: Yahoo 2, AOL 1. Gap between the two alarm firings: **524 s (8.7
  minutes)**. Longest gap 524 s. Wakeup alarms for the app UID: 4 (`dumpsys alarm` 6 to 10; batterystats "ACTION_DOZE_SCAN:
  4 times"), which is 2 firings times 2 per-account alarms. No periodic start in 1,205 s. Jobs and wakelock: batterystats
  recorded no Job or wakelock line for the alarm path. CPU user 8.3 s + system 18.9 s. Two of the three scans failed at
  DNS (`Failed host lookup: imap.mail.yahoo.com`, `imap.aol.com`) rather than at login, unlike every scan in arms 1 to 3
  and 5. Cause unverified (candidate: Doze network restriction while the first alarm ran); what would settle it: log
  `ConnectivityManager` network state in the worker.
- **Arm 5 (interval 5 + new-mail ON per account, 4 notifications)**: worker starts 8: doze-alarm 4 (+9, +10, +528,
  +1,052 s), periodic 2 (+323, +371 s), notification 2 (+603, +903 s). Account scans run: Yahoo 4, AOL 4. Yahoo skipped
  by the filter: 2. Doze-alarm gaps 519 s and 524 s (8.7 minutes). Longest gap between any two starts 313 s. Wakeup
  alarms for the app UID: 6 (10 to 16). Jobs: 5 runs, 6 m 33.7 s, completions `successful_finish(8x) canceled(1x)`.
  Partial wakelock 6 m 33.9 s actual (6 m 21.8 s blamed). CPU user 21.4 s + system 57.9 s.
  **Two of the four posts (at +1 s and +301 s) produced no notification scan and no log line.** Cause unknown. Candidates:
  the Dart-side `kMinScanSpacing` (5 minutes) deferred them because alarm scans had just finished, or the native
  listener did not fire. What would settle it: logcat from `MailNotificationListener` during the window (the buffer had
  rolled over by the time this was checked).

### Comparison, normalized to 1,205 s of force-idle

Account scans run (arm 1 and arm 2 values scaled from 2,110 s and 2,105 s; the scaling assumes a steady rate and is
only indicative):
- Arm 1, interval 15, new-mail off: 5 in 2,110 s, about **2.9**.
- Arm 2, interval 15, new-mail on for all accounts (pre-F264): 19 in 2,105 s (7 notification scans times 2 accounts, plus
  3 alarm and 2 periodic), about **10.9**.
- Arm 3, interval 15, new-mail on for AOL only: **4**.
- Arm 4, interval 5, new-mail off: **3**.
- Arm 5, interval 5, new-mail on for AOL only: **8**, which is **2.8 times arm 1**.

Does the per-account mapping measurably reduce scans? **Yes for account scans, no for process wakeups.** Per
notification, the scans run fell from 2 (every account, arm 2) to 1 (AOL only, arm 3), and Yahoo was skipped on every
notification (4 of 4 in arm 3, 2 of 2 in arm 5). The notification still starts one worker per post, so wakeups and
job starts per notification did not change. The saving is the connect, login and listing work for the skipped account,
which on a real mailbox is the expensive part (not measurable here because the logins fail).

Does the 5-minute floor deliver 5-minute scans? **Not in forced Doze.** Alarm scans came 519 to 524 s apart in arms 4
and 5, which matches Google's "once per nine minutes, per app" limit for `setAndAllowWhileIdle` and
`setExactAndAllowWhileIdle` (cited in the plan, not re-verified in this task). A 5-minute setting therefore costs about
7 alarm scans an hour per account in idle, not 12. Outside Doze (screen on, charging, app open) the 5-minute value is
not capped by this limit; that case was not measured here.

### Recommendation on the interval floor (`kMinIntervalMinutes`, one constant)

**Keep 5.** Evidence:
- The card rule was "keep the 5-minute floor only if arm 5 stays within a small multiple of arm 1 in scans and wakelock
  time." Scans: 2.8 times arm 1, inside a small multiple. Wakelock: arm 5 shows 6 m 22 s blamed partial wakelock against
  9.4 s for arm 1, which would fail the rule, BUT that figure is not trustworthy as a cost of the setting: the logged
  scans last 7 to 12 s each (8 scans is about 1.5 minutes), arm 3 shows 8.4 s of wakelock per scan, and arm 5 shows about
  49 s per scan. The extra wakelock time is unexplained (candidate: WorkManager jobs held open after the scan; cause
  unknown). Treat the wakelock result as an open question, not a pass or a fail.
- Android itself caps the idle alarm band near 8.7 minutes (arms 4 and 5), so lowering the floor below 5 would buy
  nothing in idle and raising it to 10 would change the idle cost by little (about 7 against 6 alarm scans an hour).
- A 5-minute interval is an explicit per-account opt-in; the default stays at 15.
- **Trigger to raise the floor to 10**: the Fold battery check (R77-BAT-1) showing an interval-5 account costing more than
  about 3 times the interval-15 account in Settings > Battery over the same idle period. The emulator cannot show energy,
  so this recommendation is provisional until that check runs.
- Side finding for the lead: the Settings text under Background reads "While the phone is idle, expect up to about 45
  minutes between scans, even with a shorter interval." Arms 4 and 5 measured 8.7 minutes in FORCED Doze, which is not the
  same state as a phone left idle overnight (deeper maintenance windows). The sentence is about the real device; do not
  change it on this evidence.

### Arm 6 (listener gap 2 minutes against 5 minutes): NOT RUN, backlog item

Changing `MailNotificationPolicy.MIN_GAP_MS` (a Kotlin constant at line 94) is a code change, which this task forbids.
Also, the Dart worker already enforces `BackgroundScanCore.kMinScanSpacing` (5 minutes) after every finished scan, so
the observed notification-scan spacing in arms 3 and 5 (301 to 313 s) was set by that, not by the 2-minute listener gap.
A listener gap of 5 minutes is likely redundant with it. Described as R77-BAT-3 below.

### Backlog items (A/B tests; placeholder ids, in `docs/BACKLOG_REFINEMENT.md` item format)

### R77-BAT-1: Fold energy check of interval 5 against interval 15
**Status**: [CHECKLIST] NEW (2026-10-07, Sprint 77 R76-1)
**Priority**: High
**Estimated Effort**: S (~1 hour of hands-on time plus two overnight windows)
**Value Statement**: This prevents shipping a 5-minute floor that drains a real battery, and replaces the emulator's
count-only evidence with a measured one.
**Dependencies**: A debug or closed-test build with F264 on the Fold (adb is unavailable, so use Settings > Battery
screenshots over MTP, `scripts/pull-phone-screenshots.ps1`).
**Hypothesis**: An interval-5 account costs no more than 3 times the battery of an interval-15 account over the same idle night.
**Arms**: (A) one real account, interval 15, new-mail off; (B) same account, interval 5, new-mail off; (C) interval 5,
new-mail on. Same screen-off, unplugged, 8-hour window each, same standby bucket and network.
**Metric**: Settings > Battery percent attributed to the app, plus the diagnostic-log scan count and the background
wakelock line.
**Decision rule**: If B is at most 3 times A, keep the floor at 5. If B exceeds 3 times A, raise `kMinIntervalMinutes`
to 10 and re-run B. If C exceeds B by more than 50 percent, raise the new-mail minimum spacing.
**Notes**: Also explains the unexplained 6 m 22 s wakelock in arm 5 (see above).

### R77-BAT-2: Why two notifications in arm 5 produced no scan, and why alarm and WorkManager scans coexist
**Status**: [CHECKLIST] NEW (2026-10-07, Sprint 77 R76-1)
**Priority**: Medium
**Estimated Effort**: S (~30 minutes)
**Value Statement**: This prevents a silent loss of new-mail triggers, and shows whether alarm plus periodic scans
overlap wastefully.
**Dependencies**: None (emulator and the existing scripts).
**Hypothesis**: Posts that arrive within 5 minutes of a finished scan are deferred or dropped by `kMinScanSpacing`, not by the listener.
**Arms**: (A) arm 5 as run, with `logcat` filtered to `MailNotificationListener` and the `[new-mail-trigger]` log lines
kept; (B) same with the notification cadence at 10 minutes; (C) same with interval 15.
**Metric**: Posts that produced a worker start, posts that were logged as skipped, and posts with no log line.
**Decision rule**: If any post leaves no log line, add a log line at the drop point (a post with no trace is
unobservable to users and to us). If every dropped post is explained by `kMinScanSpacing`, record that and close.
**Notes**: Arm 3 showed 4 of 4 posts producing a scan at a 5-minute cadence; arm 5 only 2 of 4.

### R77-BAT-3: Listener gap 2 minutes against 5 minutes (was arm 6)
**Status**: [CHECKLIST] NEW (2026-10-07, Sprint 77 R76-1)
**Priority**: Low
**Estimated Effort**: XS (~20 minutes plus two 20-minute emulator windows)
**Value Statement**: This enables dropping or keeping the native 2-minute gap with evidence.
**Dependencies**: One-line debug change to `MailNotificationPolicy.MIN_GAP_MS` under a mutation lock, and a decision
on whether it duplicates `kMinScanSpacing` (5 minutes).
**Hypothesis**: At a post cadence of 2 and 3 minutes, a 5-minute listener gap produces the same scans as a 2-minute gap,
because the Dart 5-minute spacing already limits them.
**Arms**: (A) gap 2 minutes, cadence 2; (B) gap 5 minutes, cadence 2; (C) gap 2 minutes, cadence 3; (D) gap 5 minutes,
cadence 3. All on interval 15, new-mail on for AOL only, 20-minute windows after force-idle.
**Metric**: Worker starts, account scans run, wakeup alarms, wakelock, longest gap.
**Decision rule**: If A and B differ by 1 scan or fewer, remove the native gap (one place owns the spacing). If B has at
least 2 fewer scans, keep the native gap and document why both exist.

### R77-BAT-4: Doze network availability for alarm scans
**Status**: [CHECKLIST] NEW (2026-10-07, Sprint 77 R76-1)
**Priority**: Medium
**Estimated Effort**: S (~45 minutes)
**Value Statement**: This prevents interval-5 scans that run at the alarm and fail for lack of a network.
**Dependencies**: None.
**Hypothesis**: An alarm scan that starts in deep Doze can run before the OS grants network, which causes `Failed host
lookup` (seen in 2 of 3 scans in arm 4).
**Arms**: (A) arm 4 as run with the worker logging network state at start; (B) same with a short wait-for-network step
in the worker; (C) same, charger plugged in.
**Metric**: Share of alarm scans that fail at DNS instead of login.
**Decision rule**: If A fails at DNS in at least 25 percent of scans and B fixes it without raising wakelock time by more
than 20 percent, add the wait; otherwise record the cause and close.
**Notes**: A DNS failure on a real account would look like a skipped scan and delay mail handling by one interval.

## Original plan for arms 3-6 (kept for the record; superseded by the section above)

Prerequisites: F264 built into the dev debug APK (per-account new-mail mapping, interval unit plus number, the
5-minute `kMinScanSpacing` constant). Use `-Env dev` and the same two fake accounts, standby bucket, Read-Only mode and
diagnostic log. Re-run arm 2 on the F264 build first as the new reference, because F264 may change the all-accounts
path too.

- Common command: `OUT_ROOT=<dir> bash mobile-app/scripts/r76_battery_arm.sh <arm> 60 <cadence>` then
  `python mobile-app/scripts/r76_battery_summarize.py <dir>/<arm>`. Use 60 minutes if the budget allows, otherwise 35 and
  say so. Clear WorkManager state between arms only while the app is force-stopped.
- **Arm 3 (new-mail ON, per-account mapping)**: cadence 5. The shell package has no account. F264 needs a way to
  tag a debug post with an account, so add a debug-only mapping entry (the post text or the channel is NOT readable
  by the listener, ADR-0044). Decide that with the lead first: it may need a second debug package for "the Gmail
  account" and a third for "the AOL account". Compare scans per notification and coverage against arm 2.
- **Arm 4 (interval 5, new-mail OFF)**: set both accounts to 5 minutes through the new interval control. Measure
  doze-alarm starts and spacing. Expectation from Google ("Neither setAndAllowWhileIdle() nor setExactAndAllowWhileIdle()
  can fire alarms more than once per nine minutes, per app"): about 9 minutes between alarm scans.
- **Arm 5 (interval 5, new-mail ON, per-account mapping)**: arm 4 plus the arm 3 notification stream. The worst case.
- **Arm 6 (listener gap 2 minutes against 5 minutes)**: change `MailNotificationPolicy.MIN_GAP_MS` to
  `5 * 60 * 1000L` for the second run (one-line debug change, mutation-lock rules apply). Use a cadence of 2 and 3
  minutes so the gap matters (a 5-minute cadence cannot show a difference). Compare scans, wakeups, wakelock and the
  longest gap.
- Decision rule per the card: keep the 5-minute floor only if arm 5 stays within a small multiple of arm 1 in scans
  and wakelock time; otherwise raise it. Confirm on the Fold for energy.

## Release gate for the debug package (Issue #464, Q15 = 1)

- `MailNotificationPolicy.DEBUG_ONLY_PACKAGES` = `com.android.shell`. `shouldTrigger(..., debugBuild = false)` is the
  default, and the listener passes `BuildConfig.DEBUG` (`buildFeatures { buildConfig = true }` was added to
  `android/app/build.gradle.kts` because AGP 8 stopped generating it).
- JVM test: `MailNotificationPolicyTest` (7 tests, pass) via `gradlew :app:testDevDebugUnitTest`.
- Source gate: `mobile-app/test/policy/debug_allowlist_gate_test.dart` (4 tests, pass).
- Mutations R761-M1 to M5, all KILLED (see the task report).
- The listener still reads only package name and post time (ADR-0044).
