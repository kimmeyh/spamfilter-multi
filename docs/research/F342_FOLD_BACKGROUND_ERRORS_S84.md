# F342 (Issue #551): Fold background-scan errors and unfinished scans

Sprint 84, Task 2. Written 2026-11-06. All account names are masked. No sender addresses or subjects appear here.

## Inputs and method

- Eleven unique Fold diagnostic logs: `validation-screenshots/sprint-83/diag_v0.21.0_2026-10-29..31`, `diag_v0.23.0_2026-10-31..11-03`, and `validation-screenshots/sprint-84/diag_v0.23.0_2026-11-04..06`, `diag_v0.24.0_2026-11-06`.
  The sprint-83 copy of `diag_v0.23.0_2026-11-04.log` (pulled 10:06) is a subset of the sprint-84 copy (pulled 23:51) and was left out.
- Span: 2026-10-29 to 2026-11-06 08:12. Builds: 0.21.0 (10-29..31), 0.23.0 (10-31..11-06 00:45), 0.24.0 (11-06 from 00:54).
- Counts come from `scripts/phone-log-health.ps1` and were cross-checked with a second parser over the same lines (they agree).
- Windows DEV: the per-account `dev_background_scan_*_v0.21.0..v0.24.0.log` files in the DEV logs folder, searched for the exact message strings below.

Health script output over all eleven logs (full span):

- AOL: starts 941, completed 929, error 5, refused 4, unfinished 3. Interval 10 min (from the log).
- Gmail: starts 7, completed 4, error 3.
- iCloud: starts 36, error 36, completed 0.
- Yahoo: starts 7, completed 7.

Windowed numbers the earlier summaries used: the 11-04..11-06 pull window gave AOL starts 260, completed 259, error 1; iCloud starts 10, error 10.
The full span is 36 iCloud errors, not 10 or 11.
The plan's "2 + 2 AOL, 11 iCloud" figures were first reports on a shorter window. The corrected counts are in the table below.

## R-3: what "unfinished scan" means here

A scan row that logs `start` and never logs an `outcome` line in the same worker run. That gives 7 starts in the first parse, which split into two kinds:

- 4 are not unfinished. Periodic and doze-alarm workers started in the same millisecond, both passed the read-only "recent scan" check (no row existed yet), the atomic claim refused the second (`outcome -- refused`, then `busy-retry`). The first one ran to a normal outcome.
  Dates: 10-29 08:11:55, 10-29 16:53:47, 11-02 05:11:42, 11-03 01:54:51. Their counts are in the "refused" row below.
- 3 are unfinished: a worker stop (`stopped by WorkManager before it finished: reason=deviceState raw=4`) 7 to 13 seconds after the scan started, with the row later closed by the claim reaper (`reaped dead background row ...: last heartbeat never`).
  Dates: 10-29 02:18:39 (row 5229, stopped 02:18:47, reaped 02:30:04, 684 s), 11-02 18:42:44 (row 5828, stopped 18:42:54, reaped 18:55:08, 744 s), 11-02 19:59:05 (row 5835, stopped 19:59:13, reaped 20:08:10, 545 s).
  The 10-29 stop printed two stop lines (periodic and doze-alarm workers were both running) but one scan row.

## Group table

Counts are per Fold account per day. "Windows" is whether the Windows DEV background logs (v0.21.0 to v0.24.0, 16 logs) contain the same message.

1. **iCloud: login rejected** (`AuthenticationException: IMAP login rejected: [AUTHENTICATIONFAILED] Authentication Failed`).
   - Count: 36 background errors on the Fold (10-29: 1, 10-30: 8, 10-31: 5, 11-01: 3, 11-02: 4, 11-03: 5, 11-04: 5, 11-05: 5; 35 periodic, 1 doze-alarm) plus 1 manual scan on 11-06 00:55 (build 0.24.0).
   - Raised at: `generic_imap_adapter.dart:511` (`_login`, `LoginRefusal.credentials`), rethrown through `loadCredentials` (`:255-259`).
   - Cause: iCloud's IMAP server refused the stored credential. The code is not parsing anything wrong; it sent the password and the server said no. Why the server said no is **cause unknown**: the app-specific password was revoked or changed, or the Apple ID needed a new sign-in. The check that settles it: Harold creates a new app-specific password at the Apple ID site, enters it in the app, and runs one manual scan.
   - Evidence it is the credential and not the phone: Windows DEV flipped in the same hour. Windows iCloud scans succeeded (286 and 207 per day on 10-26 and 10-27, 286 on 10-28) until 10-28 23:57, then failed on every attempt. The Fold's first logged failure is 10-29. Both machines also had isolated single rejections earlier (Windows 10-26 x2, 10-28 x1) that then recovered. Windows had one 21-scan success window on 10-31 12:00 to 13:50 and failed again after.
   - Windows: **yes**, 643 failures in v0.23.0 and 192 in v0.22.0, plus the SEC-22 lockout (below).
   - Disposition: **fixed in 0.24.0 for the retry storm** (F324 `1a3a7a0a` flags the account "Sign In Again" and Sprint 83 7.7.1 `c9f21abf` stops sending the refused password while flagged: `background_scan_core.dart:490-520`). The Fold ran 0.23.0 for all 36 errors, so it re-sent the refused password every 5 hours. Windows 0.24.0 shows the effect: 40 `scan SKIPPED: The email server rejected the sign-in; enter the password again` lines on 11-04. The Fold has no 0.24.0 background iCloud evidence: Harold turned the account's background scan off at 00:56 on 11-06, and the 00:55 manual scan on 0.24.0 still failed, so the password is still wrong. **Open action for Harold: re-enter the iCloud app-specific password.**
2. **iCloud: lockout** (`AuthRateLimitedException ... blockedUntil`).
   - Windows only. Hundreds of lines, a 25 minute lockout window repeating on every 5 minute run (10-29 to 11-04). Raised at `auth_rate_limiter.dart:120` (`assertNotBlocked`).
   - Cause: SEC-22 counts every refused sign-in. Windows runs every 5 minutes, so it reaches the limit within an hour. The Fold runs every 5 hours and never reached it.
   - Disposition: same fix as group 1 (no login while flagged). Counted as "fixed in 0.24.0" and shown on Windows by the SKIPPED lines. At 11-04 16:32 the Windows 0.24.0 log shows one lockout failure after Harold's re-save, as designed by Sprint 83 Q3 ("lockout kept on re-save").
3. **AOL: refused, scan already running** (`outcome -- refused -- A background scan is already running on this account`).
   - Count: 4 (10-29: 2, 11-02: 1, 11-03: 1; 2 doze-alarm, 2 periodic). Each is a same-millisecond double start.
   - Raised at: `ScanAccountBusyException` from the claim in `email_scan_provider.dart:529-545`, mapped to a skip at `background_scan_core.dart:579-593`.
   - Cause: periodic and doze-alarm workers wake together and both pass `recentScanShouldSkip` (`android_background_scan_worker.dart`), which reads the database before either has written a row. The atomic claim (`scan_result_store.dart:773`) then lets exactly one in. The loser retries (`busy-retry`) and ends as a skip.
   - Windows: **no** (0 matches; the reason is unverified, a likely one is that Windows runs one process per account run).
   - Disposition: **working as designed**. The claim is the control. No change. The 10-29 08:11 case shows the loser's retry log line and the winner's normal completion.
4. **AOL: worker stopped by Android, row left in_progress** (3 unfinished scans, see R-3).
   - Raised at: the stop arrives in `onWorkerStopped` (`android_background_scan_worker.dart:107`), from `workmanager_android` 0.10.9 `BackgroundWorker.kt:260-293` (`onStopped` posts to the main looper, calls the Dart handler, then `stopEngine`).
   - Cause (mechanism): WorkManager stop reason 4 is `STOP_REASON_DEVICE_STATE`: "The device state (eg. Doze, battery saver, memory usage, etc) requires WorkManager to stop this worker" (developer.android.com/reference/androidx/work/WorkInfo, fetched 2026-11-06). Which of those states fired is **cause unknown**: the log does not record battery saver, Doze or memory state at the stop. The check that settles it: log `PowerManager.isPowerSaveMode`, `isDeviceIdleMode` and thermal status in the stop handler (Android only) and see which one is true at the next stop. The stop line also fell 2 s after a second worker started in 2 of 3 cases (11-02 18:42:52 doze-alarm start, stop 18:42:54), which fits system job accounting but is not proven.
   - The defect that IS ours: the stopped scan's row stayed `in_progress` with no heartbeat (the first 30 s beat had not happened yet). WorkManager restarted the periodic worker 48 to 50 ms after each stop, and that run was refused by the dead row (`skip -- a background scan is in progress on this account (scan id 5229)`). Its busy-retry ran 2.5 to 4.5 minutes later, still inside the 5 minute heartbeat window, and gave up. The next scan was the next interval: 11.4, 12.4 and 9.1 minutes after the stopped scan started, on a 10 minute AOL interval. The new mail in that gap waited one interval.
   - Windows: **no** (`stopped by WorkManager` 0 matches; Windows has no WorkManager).
   - Disposition: **fixed in this sprint** (see "Fix"). The OS stop itself is not preventable.
5. **AOL: 20 second connect timeout** (`ConnectionException: Network connection failed: TimeoutException after 0:00:20.000000: Future not completed`).
   - Count: 2 (10-30 07:42:42 and 07:43:59, 0.21.0; one doze-alarm run, one periodic).
   - Raised at: `ImapTlsConnector.connect` default `timeout = Duration(seconds: 20)` (`imap_certificate_trust.dart:371`), wrapped by `generic_imap_adapter.dart:276`.
   - Mechanism: the TCP connect plus TLS handshake to the AOL server did not finish in 20 seconds. Why is **cause unknown**: the log has no DNS, route or radio detail. The check that settles it: record the network type and the phase (DNS, TCP, TLS) that timed out. Two in a row 77 seconds apart, and the next run at 07:52 completed, so the network path was bad for about 2 minutes.
   - Windows: **no** (0 matches for `Future not completed`).
   - Disposition: **OS or network behavior; handled correctly** (scan fails, the next trigger retries; the log says so). No change.
6. **AOL: login timeout** (`IMAP login not completed, server busy or unavailable: timeout`).
   - Count: 1 (11-01, periodic, 0.23.0).
   - Raised at: `generic_imap_adapter.dart:514`, from the 120 s response timeout `kImapResponseTimeout` (`imap_certificate_trust.dart:238`).
   - Mechanism: the server accepted the connection and did not answer LOGIN within 120 s. Cause of the server's silence: **unknown**. Settled only by the server side.
   - Windows: related message only. `SERVERBUG LOGIN Server error - Please try again later` appears 7 times on Windows (AOL x3, Yahoo x4, 10-25 to 10-27); the identical `timeout` string does not.
   - Disposition: **server-side; handled correctly** (classified as a connection failure, not a wrong password, so SEC-22 does not count it). No change.
7. **AOL: connection reset by peer** (`SocketException: Connection reset by peer (OS Error ... errno = 104)`).
   - Count: 1 (11-03, periodic, 0.23.0), raised at `generic_imap_adapter.dart:276`.
   - Mechanism: the server (or a device in the path) sent a TCP reset. Cause of the reset: **unknown**; the same session pattern worked in the runs before and after.
   - Windows: **no**. Disposition: **network behavior; handled correctly**. No change.
8. **AOL: UID SEARCH got no response** (`IMAP UID SEARCH: no response within the time limit; session closed`).
   - Count: 1 (11-04, periodic, 0.23.0).
   - Raised at: `ImapServerNotRespondingException`, `generic_imap_adapter.dart:59`, built after the 120 s response timeout and `_endSessionOnTimeout` (Sprint 79 7.7.1 Q2).
   - Windows: **yes**, the same string 5 times (Gmail 3 on 10-22 and 10-23, AOL 2 on 10-23 and 10-29).
   - Disposition: **server did not answer; handled correctly** (session closed, scan stopped, next scan retries, user sees "The email server stopped responding, so this scan stopped"). No change.
9. **Gmail: needs sign-in** (`GmailSignInRequiredException: Gmail needs you to sign in again`).
   - Count: 3 (10-29, 10-30, 10-31; periodic; 0.21.0). None after 10-31.
   - Raised at: `gmail_api_adapter.dart:234-244`.
   - Cause: the stored refresh token was refused (`invalid_grant ... Token has been expired or revoked`, log 10-30 23:27:20).
   - Windows: **no** (`Gmail needs you` 0 matches in the DEV logs).
   - Disposition: **known limit, documented**: the scan row is written as an error and the worker records a skip (`background_scan_core.dart:594-626`, "no `skipped` row status, Class 1"). The user is told by the F301 notice. No change.
10. **R-5, `Failed host lookup`**: **none in scope.** No `Failed host lookup` line exists in the eleven logs (0 matches), so nothing is handed to Task 3 (F280). The earlier `Failed host lookup` lines belong to Sprint 80 to 82 logs, outside this span. (Windows DEV has one, iCloud, 10-22.)

Yahoo: no errors in the span (7 of 7 completed).

## Reconciliation with the earlier figures (AC-2)

- AOL "2 + 2": the span has 3 unfinished scans (all `deviceState` stops) and 4 refused double starts. The "2" counts in the plan came from a shorter window.
- iCloud "11" / "10": windowed counts. Span total is 36 background errors.
- The pull-window summary "AOL error=1" is the 11-04 UID SEARCH timeout (group 8).

## Fix: close the stopped scan's row in the stop handler (group 4)

Prevention first. The existing control is `onWorkerStopped` (Sprint 79 R-8), which already runs before the plugin tears the engine down (`BackgroundWorker.kt:260-293`; the plugin's own comment says the callback is there "to persist state or release resources before the engine is torn down"). The fix extends that handler instead of adding a new reaper or shortening the heartbeat window.

Instance fix:

- `background_scan_core.dart`: `_scanAccountOnce` registers its `EmailScanProvider` in `_inFlightScans[accountId]` and removes it in a `finally`. `closeInFlightScansAsInterrupted(DatabaseHelper)` sets `status = 'interrupted'`, `error_message = stoppedByPhoneReason` for each registered scan's row, only `WHERE id = ? AND status = 'in_progress'`.
- `android_background_scan_worker.dart`: `onWorkerStopped` calls it after the existing log write, bounded to 2 seconds, and logs `closed N in-progress scan row(s) as interrupted`.
- `email_scan_provider.dart`: read-only getter `currentScanResultId`.
- User-visible text (Scan History row for that scan): "The phone stopped this background scan before it finished. The next scan will try again." This is true: WorkManager reschedules the periodic job, and the registry only holds scans of the stopped isolate.
- Size: 3 code files, about 90 lines of code (Q1 limit: under 4 code files and under 600 lines). A first version that also touched `scan_result_store.dart` (4 files) was reduced to stay under the limit; the conditional update lives in `background_scan_core.dart` instead.
- Existing abstraction checked: `ScanResultStore.markScanCancelled` writes unconditionally (it would overwrite a `completed` row if the scan finished just before the stop), so it was not reused. `claimAccountScan`'s reaper stays as the backstop when the 2 second write does not finish.

Callers of the changed guard/early path (`onWorkerStopped`): only the WorkManager plugin (`onTaskStopped: onWorkerStopped`, `android_background_scan_worker.dart`). Before: log only. After: log, then close the row. No other caller.
Callers of `_scanAccountOnce`: `scanAccount` (Android worker, Windows worker, Settings > Test Background Scan). The new registry write and `finally` are passive for all three; only the Android stop handler reads the registry.

Catch walk for the new write (Sprint 81 retro IMP-3). From the DB update up to the handler:

- `closeInFlightScansAsInterrupted` per-scan `catch (e)`: stores the first error, keeps closing the other scans, rethrows after the loop.
- `_closeStoppedScanRows` `catch (e)`: writes a logcat warning and returns; nothing else is lost (the reaper closes the row later). Covers the 2 s `TimeoutException` too.
- `onWorkerStopped` (existing) has no catch around the new call; none is needed because `_closeStoppedScanRows` never throws.
- Pattern grep, "no others": other swallows between a row write and the plugin teardown: none. The plugin wraps the Dart callback in a try/catch (`BackgroundWorker.kt:276-293`) and tears the engine down in either case.

Platform paths (ADR-0042): the handler is an Android exception (WorkManager has no Windows equivalent; Windows runs a separate process per run). The registry and the SQL are shared Dart. iOS has no background run yet (F67c); the shared code covers it when one exists.

Tests: `mobile-app/test/unit/services/f342_worker_stop_closes_row_test.dart` (7 tests) plus the existing `mv7_doze_alarm_skip_test.dart` (20), 27 pass. Mutation results are in the sprint report.

## Open items

- Harold: re-enter the iCloud app-specific password (group 1).
- Unverified on the phone: that the 2 second row write beats the engine teardown. A `closed N in-progress scan row(s)` line in the next Fold log after a `stopped by WorkManager` line would prove it.

## Backlog cards proposed

- **Log the device state at a WorkManager stop** (Android): add power-save, device-idle and thermal status to the stop line so the next `deviceState` stop names which state fired. Effort: 30 minutes (one function, one test).
- **Log the phase of an IMAP connect timeout** (DNS, TCP or TLS) and the network type, so the 20 second connect timeouts (group 5) can be attributed. Effort: 45 minutes.
