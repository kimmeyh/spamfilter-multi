# R76-1 Battery A/B results, first half (Sprint 77, Issue #464)

**Status**: arms 1 and 2 measured on today's code (0.18.0+15 dev debug build, before F264). Arm 7 is BLOCKED
(see below). Arms 3-6 are pending F264 and are described in the last section.
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

## Arms 3-6 (pending F264)

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
