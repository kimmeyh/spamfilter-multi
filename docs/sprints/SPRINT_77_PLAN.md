# Sprint 77 Plan

**Status**: DRAFT -- awaiting Phase 3.7 approval (Harold). Scope selected by Harold at Phase 8.4 pass 2 (2026-10-06).
**Branch**: `feature/20261006_Sprint_77` | **PR**: draft, created at Phase 3.3.1
**Planner**: card audits and drafts by three Fable agents (top tier, `SPRINT_PLANNING.md:94-110`); assembly,
spot-verification and this header on Opus 5.5. Spot-verified against code this turn: `background_scan_scheduler.dart:257`
clamps every interval to 15 before the Doze alarm (`:274`); `main.dart:382-385` falls back to 15 minutes for 120/240;
`unmatched_email_store.dart:178,201` bare inserts with no unique index (`database_helper.dart:336-338`);
`no_rule_review_screen.dart:246-252` reads only the latest completed scan; `certificate_pinner.dart:176-215` checks a pin
only when the platform already distrusts the certificate, and `matches()` has no production caller; enough_mail 2.1.7
`ImapClient.connectToServer` takes `onBadCertificate` (`imap_client.dart:234-250`).

## Objective

Close the phone checks on the shipped 0.17.6 build, make background scanning configurable per account (interval and
new-mail trigger) with its battery cost measured, fix the two largest data defects (Gmail custom-label moves, duplicate
No Rule rows), open the app to any IMAP server with a defined security posture, and research content-based spam
identification.

**Parity (Harold, 2026-10-06, verbatim)**: *"everything needs to take into account both the Windows App and the Android
app and ADR stating that everything should be functionally and UI the same unless it cannot be - and where it cannot be
it should be implemented as a platform exception for what is needed -- this applies to all backend code, frontend code,
data, architecture, development, security, testing, deployment."* Every card below names the Windows path and the
Android path and either claims parity (naming the OS behavior assumed identical) or declares an ADR-0042 exception.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control before creating a new one, then the instance fix.

## Tasks, order, models and estimates

| # | Task | Card | Model (why not cheaper in the card) | Est-Effort (min) |
|---|------|------|-------------------------------------|------------------|
| 0 | Version bump 0.18.0+15 (MINOR: F264/F192 are `feat`) + `STORE_VERSION_STATUS` "Last uploaded to Play" -> 0.17.6 (versionCode 14) in the SAME commit (Sprint 76 IMP-2) + provisional 0.18.0 notes | Phase 3.7.0b | Haiku | 15-25 |
| 1 | **MV76-1** Fold checks on 0.17.6 (absorbs F205 #433, MV74-1 #428) | Block C, Task 1 | Haiku transcription / session model | 40-70 (+ Harold's phone time) |
| 2 | **F258** Gmail custom-label writes use the label ID | Block B, Task B3 | Haiku | 42-130 |
| 3 | **F245** No Rule rows: one row per email (upsert, unique identity, DB v12) + export lists once | Block C, Task 2 | Sonnet | 90-150 |
| 4 | **R76-1** Battery A/B tests on the emulator (arms 1-3 before F264, arms 4-6 after) | Block B, Task B2 | Sonnet | 55-100 + 120 time-boxed emulator |
| 5 | **F264 + R76-2** Per-account interval (unit + number), per-account new-mail switch, Background section rework | Block B, Task B1 | Sonnet (Haiku batch for tests) | 220-425 |
| 6 | **F192 (+ SEC-15 if Q1 = 1)** Custom IMAP server form, validation, persistence | Block A, Tasks A (+ B) | Sonnet (+ Haiku validator) | 155-250 |
| 7 | **SEC-8b** IMAP certificate trust (spike-gated) + OAuth pinner fix (if Q5 = 1) | Block A, Task C | Fable/Opus for the trust design; Haiku for docs | 150-230 |
| 8 | **R76-3** Research: heuristics, ML and GenAI spam identification (research only) | Block C, Task 3 | Fable/Opus (mandatory) | 150-240 (time-box) |

**Total**: about 917-1,615 minutes plus a 120-minute emulator time-box. Calibration: Sprint 76's planned items ran about
0.4x of estimate, but about 55% of its effort was unplanned (field fixes, review fixes); this sprint carries a DB
migration, scheduler changes on both platforms and a new trust model, so the upper half of the range is the prudent read.

**Order**: Task 0, then Task 1 (Harold's phone checks start at once; their waits -- reboot window, a day of use -- are
filled by Tasks 2, 3 and 8), then Task 4 arms 1-3, Task 5, Task 4 arms 4-6, Task 6, Task 7 (its 15-minute spike runs
first and can re-scope it). Manual Validation covers both platforms.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (a), recorded once): this
sprint is expected to run as one continuous session with Harold's phone feedback interleaved. Assignments reflect task
shape; execution is the session model unless a task is delegated. `Executed-by` per task cites this line.

**Code reviews** (Sprint 76 process change): no 5.1.1. The 7.7.1 pair -- Copilot requested by hand plus pr-review-toolkit
code-reviewer and silent-failure-hunter -- runs as soon as the retrospective improvements are complete.

## Phase 3.6.1 Architecture Impact Check

- **ADR-0039** amendment (F264): interval model 5..5940 minutes; Windows one repetition trigger (Microsoft limit 1 minute
  to 31 days); Android alarm at the user's interval, WorkManager safety net at its 15-minute minimum; 5-minute floor
  tied to `kMinScanSpacing` by a test.
- **ADR-0044** amendment (F264): the new-mail switch is per account; package-to-provider mapping; Windows presentation
  (Q10); privacy contract unchanged (package name and post time only).
- **NEW ADR-0045** (F245): identity and refresh semantics of a No Rule entry (Class-1, Q18).
- **NEW ADR-0046** (SEC-8b, only if Q4 is not "keep on HOLD"): IMAP certificate trust -- pinning scope and
  trust-on-first-use for custom servers.
- **ARCHITECTURE.md**: `:286` GenericIMAPAdapter custom settings; `:366`/`:377` unmatched_emails identity and v12 (and the
  stale "30d" retention corrected to 90d); `:555-601` Android background interval model and per-account mapping; a
  security-components row for host validation.
- **Doc defects found at audit** (fixed by whichever card touches them): the IMAP adapter comment
  (`generic_imap_adapter.dart:178-193`) and the pinner dartdoc (`certificate_pinner.dart:19-24`) say IMAP pinning is
  impossible -- enough_mail 2.1.7 accepts `onBadCertificate` and a pre-built socket.

## Security finding surfaced at planning (Class-1 for Q5)

The OAuth certificate pinning shipped in Sprint 33 (SEC-8) has never enforced a pin on a normal connection:
`PinnedHttpClient`'s `badCertificateCallback` runs only when the platform already DISTRUSTS the certificate
(`certificate_pinner.dart:176-191`), `send()` checks only that the URL scheme is https (`:205-214`, its own comment says
so), `matches()` has no production caller, and `fingerprint()` hashes the full certificate while the pin table is
documented as SPKI values. Today the effective control is the platform's normal certificate validation plus the scheme
check. Nothing is weaker than before Sprint 33; the pin layer is simply inert.

## Phase 3.7.0b version bump -- MUST include (recorded 2026-10-06, Phase 8.3)

- 0.17.6 (versionCode 14) was UPLOADED to Play closed testing (Alpha) on 2026-10-06. In the SAME commit as the Sprint 77
  `pubspec.yaml` bump, update `docs/STORE_VERSION_STATUS.md` "Last uploaded to Play (any track)" to 0.17.6
  (versionCode 14) -- not before (Sprint 76 IMP-2). The next build uses versionCode 15 or higher.
- Microsoft Store: Submission 31 (0.17.6.0) in certification since 2026-10-06; update the Live row only from a direct
  Partner Center observation.

## Decision questions -- answer before approval (reply by number, e.g. "all recommended" or "3.2, 18.3")

The cards below carry the detail and evidence for each. This consolidated list is the one to answer.

**Custom IMAP (Tasks 6-7)**
1. Merge SEC-15 into the F192 card? 1. Yes, as part of the same form (recommended). 2. No, separate card.
2. SEC-15 policy for private and loopback hosts (it conflicts with Proton Bridge, DavMail, email-oauth2-proxy and every LAN mail server; SSRF is a server-side threat): 1. Warn once and allow (recommended). 2. Reject, as the Sprint 31 audit wrote it. 3. Allow silently and close SEC-15 as not applicable to a client app. 4. Reject literal private IPs, allow hostnames.
3. Encryption modes on the Custom IMAP form (today "TLS off" means a cleartext password): 1. SSL/TLS and STARTTLS, never plaintext (recommended). 2. SSL/TLS only. 3. Also "None", restricted to loopback with a warning.
4. SEC-8b trust model (new ADR-0046): 1. Trust-on-first-use plus user-accepted self-signed/private-CA certificates (recommended if Q2 = 1 or 3). 2. Trust-on-first-use, platform validation still required. 3. Keep SEC-8b on HOLD; fix the stale comments only. 4. Also pin the known providers' IMAP leaf certificates (not recommended: leaf rotation).
5. The inert OAuth pinner (finding above): 1. Fix it inside SEC-8b (recommended). 2. File it as SEC-8c for later. 3. Accept platform validation as the control and correct the dartdoc.
6. Where custom-server settings are stored: 1. `SecureCredentialsStore` side keys read by the adapter -- no call-site edits (recommended). 2. Account-aware platform registry (7 call sites change). 3. New `accounts` table columns (DB migration).
7. Real custom server for Manual Validation (needs an account you can sign in to): 1. Fastmail (recommended). 2. Yandex. 3. Another (name it).

**Background scanning (Tasks 4-5)**
8. Per-account new-mail flag storage (Class-1): 1. Per-account setting in the app database; the Android listener keeps one "any account on" flag (recommended). 2. Per-account flags in Android native preferences.
9. Upgrade when the app-wide new-mail switch is ON: 1. Turn it on for every account (recommended; ADR-0039 precedent). 2. Start every account off.
10. Windows presentation of the per-account new-mail switch (Windows has no notification listener): 1. Hidden on Windows, extending the ADR-0044 declared exception (recommended). 2. Shown disabled with a one-line note.
11. Schedulers take a number of minutes instead of the fixed `ScanFrequency` list: 1. Approve (recommended; 5-5,940 minutes is not an enum). 2. Keep the enum and add values.
12. The current help sentence "up to about an hour": 1. Replace with "expect up to about 45 minutes" (recommended). 2. Keep both.
13. Windows random start delay for long intervals: 1. Cap at the smaller of interval minus 1 and 59 minutes (recommended). 2. Interval minus 1 always (up to about 4 days of delay at 99 hours).
14. R76-1 sequencing: 1. Interleaved -- arms 1-3 before F264, arms 4-6 after (recommended). 2. All before F264. 3. All after.
15. R76-1 emulator notification source: 1. A debug-build-only extra package in the allowlist, never in release (recommended). 2. A real mail app on the emulator only.

**Gmail labels (Task 2)**
16. A custom label that does not exist at write time: 1. Fail that action with a named error (recommended). 2. Create the label.
17. A move out of a custom label: 1. Also remove the source label once it resolves (recommended). 2. Keep the Sprint 76 behavior (custom source label never removed).

**No Rule rows (Task 3)**
18. Identity of a No Rule entry (Class-1, ADR-0045): 1. Account + message identifier + folder, adding an `account_id` column filled in by the migration (recommended). 2. Message identifier + folder, no new column (merges two IMAP accounts' equal UIDs). 3. Option 1 without folder (a moved email keeps its row).
19. The "listed once" rule for scan export files applies to: 1. Background scan exports only (recommended; the backlog text). 2. Background and manual-scan exports.
20. An email dismissed with "Remove Current Rule" that a later scan still finds with no rule: 1. Stays dismissed (recommended). 2. Comes back.
21. No Rule Review keeps reading only the latest completed scan per account: 1. Yes (recommended; the upsert moves rows to it). 2. No, list every unprocessed row across scans.
22. The 90-day retention for No Rule rows counts from: 1. The last time a scan saw the email (recommended). 2. The first time (as today).
23. Scan History "No Rule" count: 1. Unchanged (recommended). 2. Add a "new No Rule this scan" number (separate card).

**Phone checks (Task 1)**
24. F250 native Gmail sign-in, now that browser sign-in plus refresh-token renewal works: 1. Record the account state and close it out (recommended). 2. Backlog until a second device reproduces it. 3. Work it this sprint.
25. Getting the diagnostic log and `.data.csv` off the Fold: 1. Generalize `scripts/pull-phone-screenshots.ps1` with `-Folder` and `-Pattern` (recommended; 10-20 min, prevents hand copying). 2. You copy them by hand, as in Sprint 76.

**Research and sprint**
26. R76-3 time-box: 1. 240 minutes (recommended). 2. 120 minutes.
27. Model assignments in the table above: 1. Approve (recommended). 2. Change (name which).
28. Version for this sprint: 1. 0.18.0+15 -- MINOR, because F264 and F192 are features (recommended). 2. 0.17.7+15.

## Phase 3.7 approval

**APPROVED 2026-10-06 (Harold, verbatim)**: *"Sprint plan approved as amended (with any comments I provided), proceed
with execution. All Sprint tasks and sub-tasks are approved. Do not stop between tasks as they are all approved, please
continue to complete all tasks and without addition approvals until Manual Validation, providing your recommendation for
Manual Validation steps. Do not stop to ask questions unless meeting the criteria in \docs\SPRINT_STOPPING_CRITERIA.md.
If questions must be asked, ask as late as possible - do everything that can be done (all tasks and parts of takss,
without the answer to the question(s), then ask the question(s)"*

**Answers given at approval (Harold, 2026-10-06)**:
- Q11: *"Windows scheduler takes the same minute/hour drop down and 2 digit entry. Existing user take a conversion from
  current (windows and android)"* -- one interval control on both platforms; schedulers take minutes; existing per-account
  frequencies are converted on upgrade.
- Q13: *"if > 15 min then randome +/- 5 minutes"* -- start-time jitter of up to 5 minutes either way, only for intervals
  over 15 minutes; none at 15 or below.
- Q18 = 2: No Rule identity = message identifier + folder, no new column. (Execution note: two IMAP accounts can share a
  UID in the same folder name, so the single upsert helper matches within the row's own account through its scan --
  `unmatched_emails.scan_result_id -> scan_results.account_id` -- which honors "no new column" without merging two
  accounts' rows.)
- Q21 = 2: No Rule Review lists every unprocessed row across scans, not only the latest scan.
- Q24 = 2: F250 native sign-in to the backlog until a second device reproduces it.
- Q25 = 1: generalize `scripts/pull-phone-screenshots.ps1` (`-Folder`, `-Pattern`).
- Q26 = 1: R76-3 time-box 240 minutes.
- Q27: *"Opus 5.5 instead of Fable unless you are positive it is needed"* -- every Fable/Opus assignment executes on
  Opus 5.5.
- Q28 (not answered; settled by `CHANGELOG_POLICY.md`: a `feat` in the release means MINOR): 0.18.0+15.

**Answered one at a time after approval** (Harold: *"only one question at a time ... After I answer, then the next
question"*; each asked with what / options / pros / cons / recommendation / why, 2026-10-06):
- Q1 = 1: SEC-15 merged into the F192 card.
- Q2 = 1: private/loopback server addresses -- warn once and allow. Harold: *"This is a personal email only app - no
  business usage should be encouraged or used (at this time)"* -- warning text must not mention or suggest business
  setups ("Continue only if you run this mail server yourself.").
- Q3 = 1: encryption modes SSL/TLS and STARTTLS, never plaintext; STARTTLS must refuse to send the password unless the
  upgrade succeeds (downgrade test).
- Q4 = 1: trust-on-first-use plus a one-time user acceptance of a self-signed / private-CA certificate (fingerprint
  shown); change detection afterward. NEW ADR-0046.
- Q5 = 1: fix the inert OAuth pinner inside SEC-8b (check every connection, correct fingerprint kind, pin the issuing
  authority, keep the kill switch).
- Q6 = 1: custom-server settings stored as `SecureCredentialsStore` side keys, read by the adapter (no call-site edits).
- Q7 = 1: Manual Validation uses Harold's Yahoo account entered through the Custom IMAP form, plus a local test IMAP
  server Claude sets up on the PC (STARTTLS, self-signed prompt, change alert, local-address warning; Fold over Wi-Fi).
- Q8 = 1: per-account new-mail switch in the app database (with the other per-account background settings); the Android
  listener keeps one native "any account on" flag; account selection in the shared worker.
- Q9 = 1: upgrade with the app-wide switch ON turns it on for every account that has background scanning on.
- Q10 = 1: the per-account new-mail switch is hidden on Windows (ADR-0044 declared exception extended).
- Q12 = 1: one combined Android note -- "Android runs background scans when the phone allows. While the phone is idle,
  expect up to about 45 minutes between scans, even with a shorter interval. Opening the app runs any work that was
  waiting." (replaces the F217 "about an hour" note, `settings_screen.dart:1530`).
- Q14 = 1: R76-1 interleaved -- arms on today's code first (baseline, all-accounts new-mail, scan range), F264 built
  with the 5-minute floor as one constant, then the F264-dependent arms; the final floor set from the results.
- Q15 = 1: emulator notifications from a debug-build-only allowlist entry, with a gate proving release builds never
  contain it.
- Q16 = 1: a missing custom Gmail label fails the move with a named error ("Gmail label '<name>' was not found --
  choose the folder again in Settings"); never auto-create.
- Q17 = 1 (Harold first answered 2, then *"sorry change q17 to 1"*): a move out of a custom label also removes that
  label once its ID resolves; if the lookup fails the label stays (never a failed move).
- Q19 = 1: "listed once" applies to background-scan export files only; manual-scan exports stay complete.
- Q20 = 2: a dismissed No Rule email comes back when a later scan still finds it with no rule. Harold's reason:
  *"dismissed is often, 'I don't know. I'll have to check.' this give the user to find and look at the full email and
  then decide. When they run the next scan they are likely ready to decide."* -- build it as "deferred until the next
  scan" (the upsert resets `processed` when a scan re-finds the email).
- Q22 = 1: the 90-day No Rule cleanup counts from the last time a scan saw the email.
- Q23 = 1: Scan History "No Rule" count unchanged. Harold: *"the user can often see (and can filter by email) to see
  multiple scan results on the same page and easily see how the no rule numbers are changing."*

All decision questions are answered; execution proceeds without further approval until Manual Validation.

---

# Cards

Task numbers above map to the block cards below; each block keeps its drafting labels so its internal references
(R-N, AC-N, T-N, Q-N) stay intact. Where a block's own question list differs from the consolidated list above, the
consolidated list governs.

| Plan task | Block card |
|-----------|-----------|
| 1 MV76-1 | Block C, Task 1 |
| 2 F258 | Block B, Task B3 |
| 3 F245 | Block C, Task 2 |
| 4 R76-1 | Block B, Task B2 |
| 5 F264 + R76-2 | Block B, Task B1 |
| 6 F192 (+ SEC-15) | Block A, Tasks A and B |
| 7 SEC-8b | Block A, Task C |
| 8 R76-3 | Block C, Task 3 |


# Block C -- MV76-1, F245, R76-3


# Sprint 77 plan draft -- group C: MV76-1 (incl. F205), F245, R76-3

Drafted 2026-10-06 from the backlog text in `docs/ALL_SPRINTS_MASTER_PLAN.md` (lines 179-185, 193-197,
248-250, 315-372), `docs/sprints/SPRINT_76_PLAN.md`, `SPRINT_76_SUMMARY.md`, the Sprint 77 stub, ADR-0042,
ADR-0044 and the code cited per line below. Template: `docs/SPRINT_PLANNING.md` lines 385-461 (augmented
per-task template), read in the same turn. Planning only: no repo file was edited.

Conventions used in this file: file:line references are to `mobile-app/` unless the path starts with
`docs/`, `scripts/` or `android/`. "Fold" = Harold's Galaxy Z Fold (Play closed test, 0.17.6 / versionCode
14). "Windows dev" = the 0.17.6 dev build in `spamfilter-multi-builds\windows-0.17.6-dev`.

---

## Task 1 -- MV76-1: Finish the Sprint 76 Fold checks on 0.17.6 (Priority 1, carry-in; absorbs F205 / MV74-3 #433 and MV74-1 #428)

**Value**: This closes the six open phone checks on the exact build now in Play closed testing and Microsoft
Store certification, so the first unattended-scanning release ships with its two key claims (new-mail trigger,
survives reboot) proven on a device, and the error rate on the build that acts on real mail is known rather than
assumed. It also covers F205, so F205 needs no slot of its own (Product Owner).

**Requirements** (numbered, detailed):
- R-1 (audit first): no code is written for this card. Each check below is a MANUAL VALIDATION STEP whose
  preconditions are stated in the step and whose path to the code under test is traced here (CLAUDE.md Sprint
  75 retro IMP-5). The one allowed code change is the tooling item in R-9, and only if Harold picks it.
- R-2 (check a, F253 AC-5, #458 closed): a scan started by a mail app's new-mail notification is proven by
  BOTH (i) a worker start line `trigger=notification app=<package> delay=Ns` in the diagnostic log AND (ii) a
  completed background scan outcome for at least one account that follows it. (i) alone is not proof: the
  trigger string is computed at worker ENTRY, before any per-account claim or skip
  (`lib/core/services/android_background_scan_worker.dart:66-79`, `describeBackgroundTrigger` at
  `lib/core/services/background_scan_trigger.dart:35-57`), so the line appears even when every account is
  then refused or skipped.
- R-3 (check a, package names): the AOL and Yahoo package names in the allowlist
  (`android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationPolicy.kt:19-25`:
  `com.aol.mobile.aolapp`, `com.yahoo.mobile.client.android.mail`) are confirmed on the device by a method that
  does not depend on the trigger firing, because a non-match leaves NO record: `MailNotificationListener.kt:52`
  returns before any preference write, and the "last result" row in Settings is written only after a match
  (`:62-65`). A silent night therefore cannot distinguish "no notification was posted" from "the package name
  is wrong". The device-side method: open each mail app's Google Play listing on the phone, tap Share, and read
  the `id=` value in the shared URL (or paste it into the chat). If a name differs, the fix is one line in the
  allowlist plus the JVM test (`android/app/src/test/.../MailNotificationPolicyTest.kt`); that is a code change
  and goes to a follow-up card, not this one.
- R-4 (check b, MV74-1 reboot half, #428 open): background scans resume after a phone restart WITHOUT the app
  being opened. Mechanism under test: `BootReceiver` (`DozeAlarmScheduler.kt:223-232`) re-arms every account
  remembered in the `f235_doze_alarms` preferences (`rescheduleAll`, `:145-172`; accounts are remembered at
  `schedule()`, `:102-108`), and WorkManager persists its periodic work across restarts by itself
  (`:32-34`). The inexact alarm has a delivery window of about an hour (`:21-26`), so the observation window
  must exceed the account interval plus one hour. Evidence: diagnostic-log worker start lines (any `trigger=`)
  and Scan History rows timestamped AFTER the reboot and BEFORE the first `app start (foreground)` line
  (SPRINT_76_PLAN.md:781-782 shows that line's shape).
  - TWO preconditions to settle from developer.android.com before the step is handed over (planning fetched
    the Direct Boot guide and the Intent reference; the first gave partial text, the second returned navigation
    only, so neither is quoted here):
    (1) Force stop: from memory a force-stopped app is in the stopped state and receives no broadcasts,
    `BOOT_COMPLETED` included. Until quoted, the step says "do not Force stop the app before the reboot; close
    it with Back or the recents swipe".
    (2) Direct Boot: the Direct Boot guide (read 2026-10-06) places `ACTION_BOOT_COMPLETED` under notification
    of USER UNLOCK ("If your app only uses background processes that can act on a delayed notification, listen
    for the ACTION_BOOT_COMPLETED message"), while `ACTION_LOCKED_BOOT_COMPLETED` is what fires before unlock.
    `BootReceiver` listens only for `BOOT_COMPLETED` (`DozeAlarmScheduler.kt:225-226`; the manifest at
    `AndroidManifest.xml:159`), so on a file-based-encryption phone the alarms are restored only after the
    FIRST unlock. The step therefore reads "unlock the phone ONCE after the restart, then lock it and leave it";
    "never unlock" would make the reboot check fail for a reason that is not a defect. Settle the exact
    wording by quoting the Intent reference for `ACTION_BOOT_COMPLETED` at execution.
- R-5 (check c, export header): a NEW daily `scan_exports/*.data.csv` starts with the 11 column names
  (`lib/core/services/scan_sheet_export.dart:29-47`, written at `:95-100` only when the file is absent or
  empty). The file name carries the date (`:80-92`), and a file already started without a header is left as
  is (`:97`). Today's (2026-10-06) Fold files may have been started by 0.17.5, so the check is valid only on a
  calendar day whose FIRST export write came from 0.17.6: from 2026-10-07 on, or after deleting today's file.
  Both the background export (`BackgroundScanExport.exportIfEnabled`, `:160-185`, called by both platform
  workers per ADR-0042) and the live-scan export (`lib/core/services/live_scan_logger.dart:106`) go through the
  same `appendAndWrite`, so either kind of scan can produce the evidence.
- R-6 (check d, rule-update fix): on the Results screen, adding a safe sender for an email that is ALREADY in
  the Inbox reports no failure. Code: `lib/ui/screens/results_display_screen.dart:4227-4248` counts an
  "already in target" email as applied with no mailbox call (`safeSenderAlreadyInTarget`, shared with the
  scanner at `lib/core/services/email_scanner.dart:41`). Evidence: the update's toast (N of N applied, no
  "could not be applied") and the F248 rule-update line in the diagnostic log (CHANGELOG 2026-10-05: "the
  result of every rule you add from Scan Results").
- R-7 (check e, F250, #454 CLOSED): a screenshot of the Google account's state on the Fold (Android Settings >
  Accounts > the Google account; and the app's account list row for `kimmeyh@gmail.com`), then a numbered
  decision (below) on whether the native sign-in still matters now that refresh-token renewal works on the
  browser path (SPRINT_76_SUMMARY.md:26-28, 41-42; F250 R-1 result at SPRINT_76_PLAN.md:783-795: cause not in
  the app or the OAuth clients).
- R-8 (check f, MV74-3 / F205, #433 open): on 0.17.6, Scan History filtered per account (AOL, Yahoo, Gmail;
  background and manual) is read for rows with Errors > 0. Every such row is mapped to its diagnostic-log
  error line with its cause (F248 records each scan error with its cause: CHANGELOG 2026-10-05, `scanEvent`
  at `lib/core/services/diagnostic_logger.dart:448-460`), and the causes are classified; or "zero errors
  across N scans on 0.17.6, per account" is recorded. The prior finding stands as the baseline: errors were
  Gmail-only and pre-0.15.0 (master plan lines 318-325). Take the baseline count BEFORE attributing any number
  to this build (CLAUDE.md Sprint 73 IMP-5).
- R-9 (tooling gap, Harold's choice): `scripts/pull-phone-screenshots.ps1` reads ONLY the phone's `DCIM` folder
  (`:99-105`), so it cannot pull the diagnostic log, which lives in the export folder (`resolveLogDir` prefers
  the user-chosen export directory, `diagnostic_logger.dart:117`; Android default Documents). Sprint 76 got the
  Fold logs by Harold copying the file. Options are in the decision list below; the default is "Harold copies
  the log as in Sprint 76".
- R-10 (Windows half, ADR-0042): the checks that run on shared code are repeated on Windows dev as a parity
  smoke: (c) the export header (same `appendAndWrite`), (d) the rule-update counting branch (same
  `results_display_screen.dart` path; the "already in target" branch never calls the mailbox on either
  platform, so in the Windows read-only mode this proves the COUNTING only -- the Android step is the real
  evidence), (f) Scan History errors on the Windows dev build classified or recorded zero, and the 0.17.6
  offline message: a manual scan that cannot reach any folder says "Could not read any folder from the email
  server. Please check your internet connection and try again." (`lib/util/error_messages.dart:80`; CHANGELOG
  2026-10-06). Declared Android-only exceptions, NOT repeated on Windows: (a) the notification listener
  (ADR-0044 "Platform scope"); (b) the Doze alarm and BootReceiver (Windows uses per-account Task Scheduler
  tasks, ADR-0039, which the OS persists across reboots -- an optional Windows reboot check is listed in the
  steps as parity evidence, not a requirement); (e) the native Google sign-in (ADR-0011 exception, Windows uses
  the browser flow by design).

**Affected components / files**: none changed. Read for tracing:
- `android/.../MailNotificationListener.kt:39-75`, `MailNotificationPolicy.kt:19-41`, `DozeScanTrigger.kt`
- `android/.../DozeAlarmScheduler.kt:89-118, 145-172, 223-232`; `AndroidManifest.xml:18, 159`
- `lib/core/services/android_background_scan_worker.dart:57-107`; `background_scan_trigger.dart:35-57`
- `lib/core/services/scan_sheet_export.dart:29-47, 71-111, 160-185`; `live_scan_logger.dart:106`
- `lib/ui/screens/results_display_screen.dart:4221-4259`; `lib/core/services/email_scanner.dart:41`
- `lib/core/services/diagnostic_logger.dart:117, 448-483`; `lib/util/error_messages.dart:80`
- `lib/ui/screens/settings_screen.dart:1586` (the switch row, Android only); `lib/core/storage/settings_store.dart:64, 593`
- `scripts/pull-phone-screenshots.ps1:55-62, 99-110`

**Existing abstraction checked**: N/A (no member added).

**Existing behavior relied on**:
- "The trigger line is written at worker entry regardless of the per-account outcome" -- verified at
  `android_background_scan_worker.dart:66-79` (computed before `executeScan` runs any claim).
- "A non-matching notification leaves no record" -- verified at `MailNotificationListener.kt:52` (early return
  before the prefs write at `:62-65`).
- "BootReceiver restores only accounts armed before the reboot" -- verified at `DozeAlarmScheduler.kt:102-108,
  147-165`.
- "A new daily file gets the header; an existing headerless file does not" -- verified at
  `scan_sheet_export.dart:95-100`.
- "Already-in-target safe senders count as applied with no mailbox call" -- verified at
  `results_display_screen.dart:4231-4248`.
- "The diagnostic log directory is the export folder" -- verified at `diagnostic_logger.dart:117` (doc
  comment on `resolveLogDir`); the exact Android path is read from Settings on the device ("Settings shows the
  folder the diagnostic log is written to", CHANGELOG 2026-10-05).

**Callers of any guard being changed**: N/A (no guard changed).
- Tooling that launches or kills the same executable: N/A for the phone. On Windows, do not run the WinWright
  sweep while a Windows background scan is expected for check (f) (Sprint 75 retro IMP-4: the runner stops
  every process of the exe).

**User-reachable control**: N/A (validation only). The controls exercised: Settings > account > Background >
"Scan when new mail arrives" (Android), the per-account Background switch, Settings > General > diagnostic
logging, Settings > Background > export CSV, Results > add safe sender.

**Observable behavior -- before / after**: N/A (no behavior changes). The outcome is evidence: six PASS /
FAIL / N-A lines in `SPRINT_77_PLAN.md` with screenshot and log references, and the F250 decision recorded on
#454.

**Dependencies / blockers**:
- 0.17.6 installed from Play on the Fold (versionCode 14, submitted 2026-10-06; install once Play's quick checks
  finish). The Windows dev 0.17.6 build already exists.
- (a) needs a mail app with new-mail notifications ON for at least one account (Harold's are off,
  SPRINT_76_PLAN.md:443-444).
- (b) needs an uninterrupted window of interval + about 60 minutes after the restart with the app unopened.
- (f) needs a day of normal use on 0.17.6 before the count is read.
- R-4 UNVERIFIED Android fact fetched and quoted before the (b) step is handed over.

**Non-functional requirements**:
- Account-scoping: each check names the account it ran on; (f) is read per account (the prior finding was
  account-specific).
- Platform: Android steps (a), (b), (e) are declared exceptions (ADR-0044, ADR-0039, ADR-0011); (c), (d), (f),
  offline message run on shared code and are repeated on Windows (R-10).
- Privacy: evidence pulled from the phone contains redacted account ids (diagnostic log) but the export
  `.data.csv` carries addresses unless Export redacted is on; evidence files stay in
  `validation-screenshots/sprint-77/`, which is the existing convention.

**Acceptance criteria** (measurable, traceable):
- AC-1 (R-2): the plan records one `trigger=notification app=<package> delay=Ns` line AND one following
  `completed` outcome for an account, with timestamps, from the 0.17.6 Fold log; or records that no mail-app
  notification was posted in the window (with the mail app's notification setting shown in a screenshot).
- AC-2 (R-3): the plan records the device-confirmed package names for AOL and Yahoo next to the allowlist
  values, each marked MATCH or DIFFERS (DIFFERS spawns a follow-up card).
- AC-3 (R-4): the plan records the reboot time, the first worker start line after it, and the first
  `app start (foreground)` line after it, with the worker line earlier than the app-start line; or FAIL with
  the log excerpt.
- AC-4 (R-5): the first line of a `.data.csv` first written on a 0.17.6 day equals the 11 column names
  (`scanSheetHeaderLine`), on the Fold and on Windows dev.
- AC-5 (R-6): a safe-sender add for an Inbox email on the Fold shows N of N applied and the log's rule-update
  line shows 0 failed; the Windows dev repeat shows the same counting.
- AC-6 (R-7): the Google account state screenshot is filed and Harold's numbered answer to decision Q-1 is
  recorded on #454 (reopened only if he picks an option that needs work).
- AC-7 (R-8): for each account on 0.17.6, either every Errors > 0 row is mapped to a classified cause, or
  "zero errors across N scans" is recorded with the N; the same on Windows dev. #433 is closed or re-scoped
  from that record.
- AC-8 (R-10): the Windows dev offline message matches `error_messages.dart:80` word for word (screenshot).

**Tests to write** (one intent per AC; validation card, so these are evidence steps, not automated tests):
- T-1 (AC-1, AC-2) -- MANUAL on the Fold, evidence in `validation-screenshots/sprint-77/` + log excerpt.
- T-2 (AC-3) -- MANUAL on the Fold; log excerpt with the three timestamps.
- T-3 (AC-4) -- MANUAL: the `.data.csv` first line, Fold (MTP copy) and Windows (`%USERPROFILE%\Downloads\scan_exports` or the configured folder).
- T-4 (AC-5) -- MANUAL on the Fold; Windows dev repeat.
- T-5 (AC-6) -- MANUAL screenshot + decision record.
- T-6 (AC-7, AC-8) -- MANUAL: Scan History screenshots per account; the offline-message screenshot on Windows.
- No automated test is added. If R-3 finds a DIFFERS, the follow-up card carries the JVM test change.

**Definition of Done**: default task-level DoD PLUS:
- The six results are written into `SPRINT_77_PLAN.md` in the same shape Sprint 76 used (date, build, finding,
  evidence path), and #428 and #433 are closed or re-scoped with a comment that cites the evidence.
- The R-4 Android fact is fetched from developer.android.com and quoted in the step before the step is given to
  Harold (CLAUDE.md external-policy rule).
- Re-present the FULL step list in every message that asks Harold to validate (memory
  feedback_represent_dont_reference); the list is below under "Manual validation steps".
- DoD items that do not apply: no tests, no CHANGELOG entry (no user-facing change), no velocity row unless R-9
  option 2 is chosen (then a HOOK/DOCS row).

**Model**: Haiku for the evidence transcription (reading screenshots and log excerpts into the plan) -- *why not
cheaper*: none cheaper. Analysis of the (f) error causes and the (e) decision framing: the session model
(Fable/Opus), because cause classification from a log is diagnosis, not transcription. Expected to run as a
single interactive session (see the sprint-level note), so the whole card executes on the session model.
**Delegation checklist included in the sub-agent prompt**: N/A (no coding sub-agent).

**Executed-by**: (filled at completion)

**Step-types**: MANUAL (validation), DOCS (recording). R-9 option 2 only: HOOK/tooling (PowerShell script).

**Est-Effort**: Claude-side 40-70m (DOCS 15-20 for the record, per CODING_VELOCITY.md DOCS band; plus reading
and classifying the log for (f), 20-40m, which is the F205 "~30-60m" estimate with the diagnosis half already
removed by F248). Harold-side wall-clock is dominated by waits: (b) interval + 60 minutes; (f) one day of use.
Do not estimate the waits as effort.

_**Risk & rollback**_: no code change, so no rollback. Risks: (a) may produce a silent night that proves
nothing -- mitigated by R-3's device-side package check and by asking Harold to send himself one email while
the phone is idle; (b) a Doze window of up to an hour may be read as a failure -- mitigated by the window
rule in R-4; (f) a count without a baseline misattributes old errors -- mitigated by reading the per-account
filter and the build column on each row.

_**Decision-class interrupts**_: none inside the steps. Decision Q-1 (F250) and Q-2 (R-9 tooling) are asked
at Phase 3.7 approval, below.

### Manual validation steps (hand these to Harold in full, every time)

Preconditions common to every Fold step: 0.17.6 installed from Play (Settings > About shows 0.17.6);
Settings > General > diagnostic logging ON (persisted; `settings_store.dart:64`), and the log folder shown in
Settings noted; each account's Background switch ON (`settings_store.dart:593`; a worker skips an account whose
switch is off); Battery for the app "Unrestricted" (the F252 row in Settings > Background).

1. (a) New-mail trigger. Preconditions: Settings > any account > Background > "Scan when new mail arrives" ON
   and the row says access is granted; the Gmail, AOL or Yahoo mail app on the phone has new-mail
   notifications ON for one account; phone idle with the screen off. Action: send one email to that account
   from another device; wait 10 minutes. Evidence: the diagnostic log line `trigger=notification app=<package>
   delay=Ns`, then a `completed` outcome for an account; Scan History shows the scan. Also: the Settings row's
   "last result" text (`new_mail_trigger_last`).
2. (a) Package names. Action: on the phone, open Google Play > the AOL app's listing > Share; read the `id=` in
   the shared link; repeat for Yahoo Mail. Record both next to `com.aol.mobile.aolapp` and
   `com.yahoo.mobile.client.android.mail`.
3. (b) Reboot. Preconditions: at least one account with Background ON and a scan interval known (default 15
   minutes); do NOT Force stop the app (close it with Back or the recents swipe); note the time. Action:
   restart the phone; unlock it ONCE after the restart (the boot broadcast the app listens for is delivered
   after the first unlock), then lock it and leave it; do NOT open the app for interval + 60 minutes. Then open
   the app. Evidence: in the diagnostic log, worker start lines after the restart time and
   before the `app start (foreground)` line; Scan History rows in that window.
4. (c) Export header. Preconditions: Settings > Background > export CSV ON; a day whose first scan ran on
   0.17.6 (from 2026-10-07), or delete today's `scan_exports/*.data.csv` first. Action: let one background scan
   run (or run a manual scan). Evidence: copy the day's `.data.csv` from the phone's export folder and read
   line 1 (11 column names).
5. (d) Rule update. Preconditions: a manual or saved scan whose Results list an Inbox email with no rule;
   Settings > the account's safe-sender folder is Inbox (the default). Action: from that email's popup, add the
   sender as a safe sender. Evidence: the toast (N of N applied, no "could not be applied") and the log's
   rule-update line.
6. (e) Google account state. Action: screenshot Android Settings > Accounts (the Google account row, and its
   detail page if it shows a sign-in warning) and the app's account list. Then answer Q-1 below.
7. (f) Errors. Preconditions: one day of normal use on 0.17.6. Action: Scan History, filter by each account
   (AOL, Yahoo, Gmail), both scan types; screenshot the list. For any row with Errors > 0, note its time; the
   log line for that scan with the cause is what gets classified. Record zero if none.
8. Windows dev: (c) delete today's `scan_exports\*.data.csv`, let a background scan run or run a manual scan,
   read line 1; (d) repeat step 5 on Windows dev; (f) Scan History on Windows dev; offline message: disconnect
   Wi-Fi, start a manual scan, screenshot the message. Optional parity evidence for (b): restart the PC and
   check Scan History for a background row before the app was opened.

Evidence pull: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\pull-phone-screenshots.ps1 -Sprint 77`
(screenshots from the phone's DCIM over MTP). The diagnostic log and the `.data.csv` are NOT pulled by that
script; Harold copies them (or see Q-2).

---

## Task 2 -- F245: Background scans must not re-add No Rule rows for emails already listed, and the export lists an unaddressed No Rule email once (Priority 35 -> sprint)

**Audit first (Product Owner: "unless F245 has already been completed or no longer makes sense to complete")
-- RESULT: F245 is STILL NEEDED; nothing dedups today.**
- The only production writer of `unmatched_emails` is `lib/core/providers/email_scan_provider.dart:710-732`
  (`addUnmatchedEmailBatch`), which builds one row per "No rule" result of the CURRENT scan with
  `scanResultId = _currentScanResultId`, `providerIdentifierType = 'email_id'`, `providerIdentifierValue =
  r.email.id`.
- Both inserts are plain inserts: `lib/core/storage/unmatched_email_store.dart:178` (`db.insert`) and `:201`
  (batch, inside a transaction). No upsert, no conflict clause.
- The schema has NO uniqueness: `lib/core/storage/database_helper.dart:317-338` defines three plain indexes
  (`idx_unmatched_scan`, `idx_unmatched_processed`, `idx_unmatched_availability`) and a FK with ON DELETE
  CASCADE to `scan_results`. There is no `account_id` column; account scoping exists only through
  `scan_result_id -> scan_results.account_id`.
- The 90-day retention cuts on `created_at` only (`unmatched_email_store.dart:414-446`), called at startup
  (`lib/main.dart:261-272`) and after every scan (`email_scan_provider.dart:644-659`); default 90 days
  (`settings_store.dart:230`). It bounds the growth; it does not dedup.
- The duplication is a DESIGN CONSEQUENCE of the IMAP backlog cursor, not a scanner bug: a windowed IMAP scan
  re-fetches from the oldest unaddressed No Rule UID forward on purpose so new rules get a chance to match the
  backlog (`lib/core/services/email_scanner.dart:1826-1830, 1872-1885`, Sprint 38 Round 4). Every re-fetched
  No Rule email is evaluated again, gets `action == none` again, and is inserted again. Gmail's windowed path is
  a historyId delta (`:1773-1786`) and does NOT re-fetch, so Gmail only duplicates on "Scan all" or historyId
  expiry. "Scan all" full-fetches on both (`:1858-1870`, F147). This is why the Fold evidence is AOL-shaped
  (about 115 rows per AOL run, the same UID 232848 listed 10 times).
- What reads the table, and what each shows today:
  - No Rule Review screen: reads unprocessed rows of the LATEST completed scan per account ONLY
    (`lib/ui/screens/no_rule_review_screen.dart:246-252`, `getLatestCompletedScan` at
    `scan_result_store.dart:304-313`). So the screen does not show duplicates today; each scan's rows are a
    fresh snapshot, and the older copies are dead weight until retention removes them. This is the constraint
    that decides the fix shape (see R-3).
  - Scan History "No Rule" totals: summed from `scan_results.no_rule_count`
    (`lib/ui/screens/scan_history_screen.dart:459-461`), which is the per-scan count of evaluated no-rule emails
    (`email_scan_provider.dart:629, 1084`). Not read from `unmatched_emails`; unaffected by any dedup.
  - F251 Results banner "M of N No rule addressed": from the provider's counts, not the table.
  - `data_deletion_service.dart:86` deletes the table wholesale (unaffected).
- Export side: `getExcelRows` emits one row per evaluated result (`email_scan_provider.dart:1358-1398`), so a
  re-fetched No Rule email is exported on every scan. Both the background export
  (`scan_sheet_export.dart:160-185`, both platform workers) and the manual-scan export
  (`live_scan_logger.dart:106`) use the same `appendAndWrite`.
- A GitHub issue for F245 does not exist yet (`gh issue list --search F245` returned nothing). Create it at
  Phase 3.3.1.

**Value**: This prevents the No Rule table growing by about 11,000 rows a day on a Windows machine with
background scans every 15 minutes (F243) and by thousands a night on the Fold, and prevents the per-account
export listing the same unaddressed email on every scan; the user sees each unaddressed email once until it is
addressed or changes.

**Requirements** (numbered, detailed):
- R-1 (audit, DONE above): no dedup, upsert or unique index exists; the single writer and both inserts are
  named with file:line.
- R-2 (prevention first -- the control that makes the duplicate impossible, not a cleanup that removes it
  later): ONE identity for a No Rule entry, enforced by a UNIQUE index in the schema, and ONE upsert helper in
  `UnmatchedEmailStore` that every writer uses. The existing bare inserts (`:175-186`, `:192-212`) are retired
  or routed through it, so no future caller can re-create the duplicate. Extends the existing store (the shared
  abstraction) rather than adding a filter in the provider.
- R-3 (shape of the fix, forced by the Review screen): the upsert REFRESHES the existing row, moving its
  `scan_result_id` to the current scan (and refreshing `subject`, `email_date`, `availability_status`,
  `auth_classification`; `folder_name` is refreshed only under identity option 3, where it is not part of the
  key -- under options 1 and 2 a moved email is a new entry), rather than skipping it. A skip-if-exists design would make
  every still-unaddressed email vanish from No Rule Review after the next scan, because the screen reads only
  the latest completed scan per account (`no_rule_review_screen.dart:246-252`). The alternative, changing the
  Review screen's query to "all unprocessed rows across scans", is a Class-2 change to that screen's meaning
  and is NOT assumed here (surfaced as Q-5).
- R-4 (identity -- Class-1, to be DECIDED by Harold, not here): the unique key is one of
  - (i) `(account_id, provider_identifier_type, provider_identifier_value, folder_name)` with a NEW
    `account_id` column on `unmatched_emails`, back-filled from `scan_results` in the migration; or
  - (ii) `(provider_identifier_type, provider_identifier_value, folder_name)` with no new column, relying on
    provider ids being globally unique (Gmail message ids are; IMAP UIDs are unique only per mailbox folder,
    so two accounts can share UID 232848 in "Inbox" -- (ii) would merge them).
  The backlog text says "account + message id / folder + uid"; (i) is the only option that honors "account".
  Whether `folder_name` belongs in the key (a moved email would otherwise be a new entry) is part of the
  same decision.
- R-5 (what "already listed" means for `processed`): the upsert keeps `processed` as it is. Today a row marked
  processed by "Remove Current Rule" (dismiss without a rule, `no_rule_review_screen.dart:695-707`) comes back
  as a NEW unprocessed row on the next scan that re-fetches it; after R-5 the dismissal is durable until the
  email changes. That is a user-visible change and is surfaced as Q-4 (Class-2). Rows marked processed because
  a rule now covers them are swept on every Review load anyway (MT-2b, `:263-270`).
- R-6 (retention): `created_at` keeps the FIRST-seen time; a new `last_seen_at` column is refreshed by the
  upsert. Which column retention cuts on is Q-6 (Class-2): first-seen means an email still unaddressed at 90
  days drops out of Review while it is still being re-listed; last-seen means it stays as long as scans see it.
  Default proposal: cut on `last_seen_at` (nothing a scan still sees should vanish silently).
- R-7 (export side, folded in by Harold 2026-10-06): the upsert returns whether the row EXISTED AND IS
  UNCHANGED (same folder, same subject, still unprocessed); the background export omits such rows. A No Rule
  email is exported again only when first seen, when it changes, or after it was addressed and reappears. The
  "<no records to process>" row stays for an empty scan (Harold: keep it; `scan_sheet_export.dart:101-105`),
  including a scan whose every row was omitted by this rule. Whether the MANUAL-scan export
  (`live_scan_logger.dart`) applies the same rule is Q-3; the backlog text names the per-account background
  export.
- R-8 (counts unchanged): `scan_results.no_rule_count`, Scan History totals and the F251 banner keep meaning
  "No Rule emails evaluated in this scan". Offering "new No Rule this scan" as a second number is Q-7, not
  assumed.
- R-9 (migration): `databaseVersion` 11 -> 12 (`database_helper.dart:66`). The migration (a) adds the columns
  the R-4 decision needs (`account_id` if (i); `last_seen_at`), (b) back-fills `account_id` from `scan_results`,
  (c) DEDUPS existing rows keeping the NEWEST row per identity (so the latest-scan Review query still finds the
  current rows), carrying `processed = 1` if ANY duplicate was processed and the oldest `created_at` as
  first-seen, then (d) creates the UNIQUE index. Order matters: the index cannot be created while duplicates
  exist. Same-sprint siblings share the one version (`:454-467`).
- R-10 (parity, ADR-0042): the writer runs inside the shared scanner on both platforms
  (`background_scan_core.dart:169-172`: persistence happens inside the shared `EmailScanner` /
  `EmailScanProvider`), and the export helper is shared. No platform fork; parity by construction. The
  OS-level assumption that must NOT be made (Sprint 76 retro IMP-3, name the primitive per platform): SQLite
  `INSERT ... ON CONFLICT DO UPDATE` needs SQLite 3.24+. Windows runs `sqflite_common_ffi` (`pubspec.yaml:49`,
  a bundled recent sqlite3); Android runs `sqflite` (`pubspec.yaml:48`) on the DEVICE's platform SQLite, and
  `minSdk = 24` (`android/app/build.gradle.kts:35-37`). From memory (UNVERIFIED -- the two developer.android.com
  fetches in planning returned navigation only), API 24 ships SQLite 3.9 and 3.24+ arrives only around API 30,
  so the upsert SQL is NOT guaranteed on every supported Android device. Therefore the helper uses the portable
  form -- SELECT by identity, then UPDATE or INSERT, inside one transaction -- on both platforms, and the UNIQUE
  index stays as the backstop (a race that slips past the SELECT fails loudly instead of duplicating).
  `INSERT OR REPLACE` is NOT a substitute: it deletes and re-inserts, changing the row id that the Review
  screen's multi-select is keyed on (`no_rule_review_screen.dart:73`). Execution step: log
  `SELECT sqlite_version()` once at startup on the Fold and Windows and record both in the card.

**Affected components / files**:
- `lib/core/storage/database_helper.dart:66` (version 12), `:317-338` (schema: new columns + UNIQUE index for a
  fresh install), `:651+` (new `oldVersion < 12` block: columns, back-fill, dedup, index).
- `lib/core/storage/unmatched_email_store.dart:175-212` -- replace the two bare inserts with one upsert helper
  (returns per-row existed/changed), `:414-446` retention column per Q-6, `UnmatchedEmail` model `:34-163`
  (new fields).
- `lib/core/providers/email_scan_provider.dart:710-732` -- call the upsert; keep the F248 "rows added" log line
  truthful (added vs refreshed counts); `:1358-1398` -- `getExcelRows` gains a way to omit unchanged No Rule
  rows (or the export filters by the upsert result).
- `lib/core/services/scan_sheet_export.dart:160-185` -- background export passes the filtered rows; `:101-105`
  placeholder row unchanged.
- `docs/ARCHITECTURE.md:366` (table row: identity, new columns, and the stale "default 30d" -> 90d per
  `settings_store.dart:230`), `:377` (schema version list), CHANGELOG.
- Candidate ADR: "No Rule entry identity and refresh semantics" (Class-1 record of the R-4 decision).

**Existing abstraction checked**: `UnmatchedEmailStore.addUnmatchedEmail` / `addUnmatchedEmailBatch`
(`unmatched_email_store.dart:175, 192`) -- the new member is an upsert in the SAME store; no other
upsert/dedup helper exists for this table (grep `unmatched_emails` in `lib/`: writer at
`email_scan_provider.dart:732` only; readers in `no_rule_review_screen.dart`, `scan_result_store.dart:924,
952, 1074` (cascades), `data_deletion_service.dart:86`). The IMAP cursor helpers
(`database_helper.dart:1107-1140`) are a separate per-(account, folder) cursor and stay as they are.

**Existing behavior relied on**:
- "The Review screen shows only the latest completed scan's unprocessed rows" -- verified at
  `no_rule_review_screen.dart:246-252`.
- "IMAP windowed scans re-fetch the unaddressed backlog on purpose" -- verified at `email_scanner.dart:1872-1885`.
- "Gmail windowed scans fetch a historyId delta" -- verified at `email_scanner.dart:1773-1786`.
- "Retention cuts on `created_at`" -- verified at `unmatched_email_store.dart:422-431`.
- "Export rows come from `_results`, one per evaluated email" -- verified at `email_scan_provider.dart:1367`.
- "`Remove Current Rule` marks processed without a rule" -- verified at `no_rule_review_screen.dart:695-707`.

**Callers of any guard being changed**: the insert path has one caller (`email_scan_provider.dart:732`); the
retention cut (`deleteOlderThan`) has two callers (`main.dart:265`, `email_scan_provider.dart:652`) and its
column change affects both identically. Readers keyed by scan id (grep of the three store methods, IMP-1 --
R-3 MOVES a row to the newest scan, so an older scan id finds fewer rows than it did):
- `no_rule_review_screen.dart:249` (`getUnmatchedEmailsByScanFiltered`, latest completed scan per account):
  the row is on the latest scan after the upsert, so unchanged -- this is the caller R-3 is shaped for.
- `rule_test_screen.dart:84` (`getUnmatchedEmailsByScan` over the last 3 scans, as sample emails for the Rule
  Test screen; it dedups by from+subject at `:98-99` and caps at 50): after the upsert the two older scans hold
  only rows not re-listed by the newest, so the sample pool shrinks to roughly "the current unaddressed set
  plus what fell out"; still a valid sample. Record as accepted; add AC-9 so it is not silent.
- `getUnmatchedEmailCountByScan` (`unmatched_email_store.dart:449`): no caller in `lib/` (test-only).
- No Scan History detail or saved-scan view reads this table by scan id (the Results screen re-opens a saved
  scan from `email_actions`, not from `unmatched_emails`) -- verified by the grep above returning only the two
  UI callers.
The cascade deletes (`scan_result_store.dart:924, 952, 1074`) are unchanged: today each scan owns its own
copies, so purging an old scan removes only that scan's copies and the latest scan's copy stays; after R-3 the
same holds, with the current row always on the latest scan. The export has two callers
(`scan_sheet_export.dart:177` background; `live_scan_logger.dart:106` manual) -- Q-3 decides the second.
- Tooling that launches or kills the same executable: N/A (no process behavior change).

**User-reachable control**: N/A (no new control). The user sees the effect on the No Rule Review screen, Scan
History and the export file.

**Observable behavior -- before / after**: BEFORE: on an AOL account with background scans, No Rule Review
keeps showing the same emails (correct), but the database grows by about 115 rows per scan and the export file
lists the same unaddressed email on every scan (UID 232848 ten times in one morning). AFTER: the database holds
one row per unaddressed email per account (refreshed in place), No Rule Review shows the same list as today
(plus Q-4: a dismissed email stays dismissed), Scan History numbers are unchanged, and the export lists an
unaddressed No Rule email once -- again only when it changes or after it was addressed -- with the
"<no records to process>" row kept for an empty scan.

**Dependencies / blockers**: Harold's answers to Q-3 to Q-7 and the Class-1 identity decision (R-4) BEFORE
coding (Definition of Ready). Back up the dev database before the first run of the migration (memory
feedback_no_sqlite_downgrade). MV76-1 first in task order (Product Owner).

**Non-functional requirements**:
- Account-scoping: identity option (i) scopes by account explicitly; option (ii) must be shown safe for two
  accounts sharing an IMAP UID (it is not, see R-4).
- Platform: shared code, no fork (R-10).
- Persistence: migration v12 with dedup; idempotent (`CREATE UNIQUE INDEX IF NOT EXISTS`, column-exists
  checks as `:604-609` do), runs inside the existing upgrade transaction.
- Security: no new content stored; `body_preview` cap (SEC-14) unchanged.

**Acceptance criteria** (measurable, traceable):
- AC-1 (R-2, R-3): two consecutive scans of the same account that both evaluate the same No Rule email leave
  exactly ONE `unmatched_emails` row for it, attached to the SECOND scan's id, with `processed` unchanged.
- AC-2 (R-4): two accounts whose emails share the same provider id and folder produce two rows (option (i)) --
  or, if Harold picks (ii), the card records that limit and this AC is replaced by a single-account AC.
- AC-3 (R-5): a row marked processed by "Remove Current Rule" stays processed after a scan re-lists the email.
- AC-4 (R-6): the retention cut uses the column Harold picks in Q-6; a row seen within the window is kept
  even when first seen before it (if `last_seen_at`).
- AC-5 (R-7): the background export of a second scan omits an unchanged, still-unprocessed No Rule email
  listed by the first; a scan with nothing else to list writes the "<no records to process>" row; a changed
  (new folder or subject) or re-appearing (addressed then No Rule again) email is listed again.
- AC-6 (R-8): `scan_results.no_rule_count` for the second scan still counts every No Rule email evaluated.
- AC-7 (R-9): upgrading a v11 database holding duplicates (3 rows for one identity, one of them processed)
  yields one row, processed, oldest `created_at`, newest `scan_result_id`; the UNIQUE index exists; a fresh v12
  install has the same schema; No Rule Review after the upgrade lists the same unprocessed emails it listed
  before.
- AC-8 (R-10): the same test suite exercises the writer through `BackgroundScanCore` (both workers call it)
  and through the live-scan provider; no `Platform.is*` appears in the change.
- AC-9 (Callers): the Rule Test screen (`rule_test_screen.dart:72-99`) still lists sample emails after two
  scans that re-list the same No Rule set (the pool shrinks, it does not empty).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (AC-1, AC-3) -- TEST-UNIT in `test/unit/storage/unmatched_email_store_test.dart` (extend): upsert refreshes
  in place and keeps `processed`. What this does NOT catch: a caller that still uses a bare insert (covered by
  T-7).
- T-2 (AC-2) -- TEST-UNIT same file: identity across two accounts.
- T-3 (AC-4) -- TEST-UNIT same file: retention on the chosen column.
- T-4 (AC-5) -- TEST-UNIT in `test/unit/services/f245_export_dedup_test.dart` (new; sibling of
  `s76_export_header_test.dart` and `f206_export_test.dart`): omitted / placeholder / re-listed cases.
- T-5 (AC-6) -- TEST-UNIT in a provider test (`test/unit/providers/`): `no_rule_count` unchanged by the upsert.
- T-6 (AC-7) -- TEST-UNIT migration test (open a v11 fixture with duplicates, upgrade, assert). What this does
  NOT catch: a production database whose duplicates differ in `folder_name` under option (ii).
- T-7 (AC-8, R-2) -- TEST-UNIT policy gate in `test/policy/`: no `insert('unmatched_emails'` outside the upsert
  helper (source-text gate, paired with T-1 for behavior per memory feedback_source_gates_verify_shape).
- Mutation checks with `scripts/mutation-test.ps1` on T-1, T-4, T-6 (the upsert conflict clause removed; the
  export filter removed; the dedup step removed); each mutant must COMPILE and be KILLED; re-run after the fix
  lands at the call site (Sprint 73 IMP-3).

**Definition of Done**: default task-level DoD PLUS:
- Back up `MyEmailSpamFilter_Dev\spam_filter.db` before the first dev launch on v12; record the row count before
  and after the migration in the plan.
- ARCHITECTURE.md table row and schema-version list updated in the same commit (no-defer rule), including the
  30d -> 90d correction.
- ADR for the identity decision if Harold picks (i) or any `folder_name` semantics (Class-1 record).
- Manual validation on BOTH platforms: Windows dev two background scans 15 minutes apart, row count delta ~0 for
  the unaddressed set; Fold on the next Play build (not 0.17.6) the same, plus the export file.

**Model**: Sonnet -- *why not cheaper*: a schema migration with a dedup step and a Class-1 identity, touching
storage, provider and export together (multi-file, data-loss risk); Haiku's limitation list names
"architectural decisions" and "cross-cutting concerns". *Why not Fable/Opus*: the design is fixed by the
answers to Q-3..Q-7 before coding; what remains is implementation against explicit ACs.
**Delegation checklist included in the sub-agent prompt**: yes (verbatim, SPRINT_PLANNING.md:433-449).

**Executed-by**: (filled at completion)

**Step-types**: DB-MIGRATE, SVC-EDIT, TEST-UNIT (x7), DOCS (ADR + ARCHITECTURE + CHANGELOG).

**Est-Effort**: 90-150m. DB-MIGRATE 13-20 + SVC-EDIT x3 (store upsert, provider call, export filter) 15-54 +
TEST-UNIT x7 28-70 (migration fixture at the high end) + DOCS 15-20, from the CODING_VELOCITY.md Estimate Table;
the dedup migration and its fixture are the uncertain part.

_**Risk & rollback**_: Risk: the dedup step deletes rows; a wrong identity merges distinct emails (option (ii)
across accounts) or a wrong "keep newest" rule drops the processed flag. Mitigation: T-6 on a fixture that has
both cases; dev DB backup; the migration runs in `onUpgrade` (`database_helper.dart:103-105, 373`) -- whether
sqflite wraps `onUpgrade` in a transaction so a failure leaves v11 intact is NOT verified here (read the sqflite
source at execution; if it does not, open an explicit transaction around the v12 block). Rollback:
dropping the UNIQUE index and ignoring the new columns is safe (the old insert path works against v12); the
deleted duplicates are not restorable, which is acceptable because retention would have deleted them within 90
days and the Review screen never showed them. Do NOT downgrade the sqlite packages to roll back (memory).

_**Decision-class interrupts**_ (surface at Phase 3.7, wait before coding):
- Class-1 (data model): R-4 identity (i) vs (ii), and whether `folder_name` is part of the key.
- Class-2: Q-3 manual export, Q-4 durable dismissal, Q-5 Review-screen query, Q-6 retention column, Q-7 a
  "new this scan" count.

---

## Task 3 -- R76-3: Deep dive -- Heuristics, ML and GenAI spam identification from stored email content (Priority 4, carry-in; RESEARCH ONLY this sprint, Product Owner)

**Value**: This enables Harold to choose, from evidence, which identification pipelines (heuristic, ML, GenAI)
are worth building and in what order, with their privacy, store-policy and platform costs known BEFORE any
content is stored (R76-4) or any code is written; the output is prioritized backlog items, not code.

**Requirements** (numbered, detailed):
- R-1 (audit first): no research document on this topic exists (`docs/research/` holds one file,
  `BUG-S40-1-aol-uid-move.md`, which sets the deliverable precedent). What the app ALREADY holds that any
  pipeline could use without R76-4: `from_email`, `subject`, a 100-character `body_preview` (SEC-14,
  `unmatched_email_store.dart:15-31`), `auth_classification` (SPF/DKIM/DMARC, F96), `email_actions` rows with
  the matched rule and pattern, `scan_results` per scan, and the rules / safe-sender YAML as a labeled corpus
  (`rules.yaml`, `rules_safe_senders.yaml`; format in `docs/RULE_FORMAT.md`). Harold's partial history of
  deleted emails is an external corpus (R76-4 text).
- R-2 (deliverable): ONE document, `docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md`, plus the
  backlog items it produces written into `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" in
  priority order, each as a card stub (Value, scope, dependencies, platform parity claim, privacy precondition,
  rough band). The document is the evidence; the backlog items are the product.
- R-3 (questions the document MUST answer, each with sources and a date):
  1. Heuristic pipeline: which signals from the data in R-1 (sender domain age/TLD, display-name vs address
     mismatch, subject patterns, auth failures, reply-to mismatch, list-unsubscribe presence, body preview
     tokens) predict Harold's existing delete rules, and how a heuristic score would feed NEW YAML delete
     rules (known bad domains, subject regex, body regex) through the existing import path.
  2. Safe-sender discovery: how to find and propose safe senders from history (reply pairs, contact lists,
     repeated non-spam senders), as a tool that writes candidates for review, never silently.
  3. ML on device: which runtimes run on BOTH shipped platforms from one Flutter codebase (candidates to
     evaluate, not assume: TensorFlow Lite via a Flutter plugin, ONNX Runtime, a pure-Dart classifier such as
     naive Bayes / logistic regression over hashed tokens), model size, inference time on the Fold and a Windows
     laptop, training location (on device vs on Harold's PC with the model shipped as an asset), and update
     mechanics.
  4. GenAI: on-device options (Android AICore / Gemini Nano availability by device; Windows ML / local models)
     versus a cloud API; for each, what leaves the device, cost per email, latency, and whether it can be
     justified under the privacy posture in R-5. Any cloud route is a Class-1 architecture decision and the
     document must say so.
  5. How each pipeline consumes the R76-4 content history (deferred): the minimum field set R76-4 must store
     for each pipeline to work (headers only? subject + preview? full body?), with retention, so R76-4's design
     is driven by this document rather than guessed.
  6. ADR-0042 parity: for each candidate, "shared on both platforms" or a declared exception naming what the
     other platform cannot do (for example an on-device model API that exists only on Android).
  7. Store policy: fetch and quote (a) Google's API Services User Data Policy "Limited Use" requirements as they
     apply to Gmail scopes and to using Gmail data for ML/AI model development, and (b) Play's Data safety
     requirements for content that is stored or sent off device. Do NOT state from memory what either says; the
     research quotes the pages with their dates (CLAUDE.md external-policy rule, Sprint 66 IMP-2). The card
     records only that these two sources must be quoted.
  8. Evaluation design: how a candidate is measured against Harold's corpus (precision on "would delete",
     false-positive rate on safe senders) before anything acts on mail, and the read-only dry-run path that
     exists today (scan mode by environment, `GOOGLE_PLAY_ACCOUNT_SETUP.md:524-541`).
- R-4 (scope boundaries): no code, no prototype in the repo, no model file, no new dependency in
  `pubspec.yaml`, no data collected from Harold's mailboxes beyond what the app already stores. A throwaway
  measurement (for example timing a pure-Dart tokenizer) is allowed in the scratchpad only, deleted the same
  session (memory feedback_scratch_probes_outside_repo).
- R-5 (privacy constraints the document works under): `docs/legal/PRIVACY_POLICY.md:33-44` states everything is
  stored only on the device and "Full message bodies are never stored"; `:25-30` states a body is retrieved only
  when a body rule requires it. ADR-0044's privacy contract (read only the posting package and time) is the
  house style for a minimal data footprint. Therefore: any pipeline that stores more content (R76-4) or sends
  content off device contradicts the PUBLISHED policy and needs, before any shipped build carries it: a
  privacy-policy revision, a Play Data safety revision (`GOOGLE_PLAY_RELEASE_PROCESS.md:30-33` shows the
  shape), and an ADR. The document sizes that work per candidate; it does not decide it.
- R-6 (time-box): 240 minutes of research time, hard stop; what is unanswered at the stop is listed as open
  questions with the source that would settle each.
- R-7 (model): the top available tier (Fable 5, else Opus) -- `SPRINT_PLANNING.md:94-110` lists "Research
  Spikes" and "Best Practices Research" as MANDATORY top-tier activities. Verify the active model before
  starting; escalate if lower.

**Affected components / files**: new `docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md`;
`docs/ALL_SPRINTS_MASTER_PLAN.md` (new candidates; R76-4 updated with the minimum field set from R-3.5);
no `lib/` change. Read-only inputs: `docs/RULE_FORMAT.md`, `docs/legal/PRIVACY_POLICY.md`, ADR-0044,
`docs/ARCHITECTURE.md:360-380` (tables), `lib/core/services/rule_evaluator.dart` (how rules apply today).

**Existing abstraction checked**: N/A (no member added). The document names the existing extension points it
would reuse: the YAML import path (`YamlService`), `RuleEvaluator`, the No Rule Review bulk actions, the
`scan_exports` CSV as a labeled export.

**Existing behavior relied on**: "The app stores no body beyond a 100-character preview" -- verified at
`unmatched_email_store.dart:15-31` and `email_scan_provider.dart:719-720` (preview deliberately not persisted
on that path). "Scan mode by environment makes a dry run possible" -- `GOOGLE_PLAY_ACCOUNT_SETUP.md:524`.

**Callers of any guard being changed**: N/A.
- Tooling: N/A.

**User-reachable control**: N/A (research). Each resulting backlog item MUST name its control and screen when
it is later carded (Sprint 72 IMP-2).

**Observable behavior -- before / after**: N/A (no behavior change this sprint).

**Dependencies / blockers**: none for the research. The backlog items it produces depend on R76-4 (content
history) and on the privacy / store revisions in R-5. R76-4 is explicitly deferred (Product Owner) and is
fed by R-3.5.

**Non-functional requirements**:
- Privacy/security: R-5; the document contains no email content, no addresses (use the test corpus style of
  the repo's fixtures).
- Platform: R-3.6 parity statement per candidate.

**Acceptance criteria** (measurable, traceable):
- AC-1: the document answers all eight R-3 questions, each with at least one primary source (vendor docs,
  papers, standards) and the date read; unanswered parts are listed as open questions with a settling source.
- AC-2: at least three backlog items are written into the master plan (one per pipeline class: heuristic, ML,
  GenAI; plus the safe-sender tool if it stands alone), each with Value, scope, dependencies, parity claim,
  privacy precondition and a rough band, in priority order with the reason for the order.
- AC-3: R76-4's master-plan entry is updated with the minimum field set and retention each pipeline needs.
- AC-4: the two policy sources in R-3.7 are quoted verbatim with URLs and dates; no policy claim in the document
  is unsourced.
- AC-5: no file under `mobile-app/` changes (git diff shows docs only); the time-box is recorded as actual
  minutes in `CODING_VELOCITY.md`.

**Tests to write**: none (research). The only automated check that applies is the existing docs hygiene:
no contractions, US English, no emojis in the new document (DoD item 4). A spelling pass before commit.

**Definition of Done**: default task-level DoD PLUS: AC-5's docs-only diff; Harold reads the document and
selects or declines each backlog item at the next Backlog Refinement (the research is not "done" until the
items exist in the master plan, but their SELECTION is Harold's and happens at Phase 8.2/8.4, not in this
sprint). DoD items 2 and 3 (tests, analyzer) are N/A; item 7 (ADR) is N/A this sprint -- the document lists ADR
candidates for later.

**Model**: Fable/Opus (mandatory, R-7) -- *why not cheaper*: `SPRINT_PLANNING.md:94-110` requires the top tier
for research spikes and best-practices research; this one also carries privacy and store-policy judgment.
**Delegation checklist included in the sub-agent prompt**: N/A unless sub-agents are used for source gathering;
if they are, they gather and quote, and the synthesis stays on the top tier.

**Executed-by**: (filled at completion)

**Step-types**: DOCS (research document), DOCS (backlog items). There is no RESEARCH step-type in
`CODING_VELOCITY.md`; record it as DOCS with a "research spike" note so the next recompute can add a type.

**Est-Effort**: 150-240m, time-boxed at 240m. Precedent: F83 Phase 1 research + ADR ~22m (narrow, one
mechanism); S47-IMP-1 sprint-card best-practices spike ~110m; the F239 R-1 spike was scoped at 30m. This spike
has eight questions across three disciplines and two policy fetches, so it sits above both precedents; the
time-box is the estimate's ceiling by construction.

_**Risk & rollback**_: no code, so no rollback. Risk: the document drifts into design (writing R76-4's schema)
or into advocacy for a cloud GenAI route without the privacy sizing -- mitigated by R-4, R-5 and AC-4. Risk:
a policy claim stated from memory -- mitigated by AC-4 (quote or mark unverified).

_**Decision-class interrupts**_: none this sprint (research produces candidates). The document MUST flag, for
later: Class-1 for any content store beyond the 100-character preview (R76-4), for any off-device processing,
and for any new OAuth scope; Class-2 for changes to how rules are generated or imported.

---

## Sprint-level summary skeleton (for the plan's header sections)

**Proposed task order**: Task 1 MV76-1 first (Product Owner: "MV76-1 first. It closes the open phone checks on
the build you are about to ship. It also covers F205"). Its Fold steps have long waits (reboot window, a day of
use for the error count), so Task 2 F245 coding and Task 3 R76-3 research run DURING those waits, in that
order: F245 needs Harold's Q-3..Q-7 answers and the Class-1 identity decision at approval, then codes
independently; R76-3 is top-tier work that can also run while Harold validates. Hand-over points: the MV76-1
step list is re-presented in full every time Harold is asked to validate, including after the F245 build.

**Single interactive session -- model deviation note** (SPRINT_PLANNING.md:358-379, option (a), recorded ONCE
here): this sprint is expected to run as one continuous interactive session, because the Fold validation
feedback (Task 1) interleaves with the F245 implementation and the research. Assignments reflect task shape
(Task 1 Haiku transcription / session-model analysis; Task 2 Sonnet; Task 3 Fable/Opus mandatory); execution
will be on the session model. `Executed-by` per task cites this line rather than repeating the reason. Option
(b) (batch cheaper-tier tasks before validation) does not fit: the only Sonnet-shaped task (F245) cannot start
until the approval-time decisions are answered, and validation starts at approval.

**Phase 3.6.1 Architecture Impact Check** (SPRINT_EXECUTION_WORKFLOW.md:405-418):
- Task 1 MV76-1: no architecture impact. The F250 decision (Q-1) may add a one-line note to ADR-0011 / the
  OAuth docs if Harold closes the native path for good; #454 comment either way.
- Task 2 F245: `docs/ARCHITECTURE.md:366` (unmatched_emails row: identity, `last_seen_at`, possibly
  `account_id`; and the stale "default 30d" corrected to 90d) and `:377` (schema version list: v12); a NEW ADR
  for the No Rule entry identity and refresh semantics (Class-1 data-model decision); no ARSD change expected
  (verify the unmatched-email requirement wording in `docs/ARSD.md` when the card is executed).
- Task 3 R76-3: no architecture change this sprint; the document lists ADR candidates (content history,
  off-device processing, on-device model runtime as a platform exception) for the sprints that pick the items.
- Carried from the stub (Phase 3.7.0b): the version bump commit must also update `docs/STORE_VERSION_STATUS.md`
  "Last uploaded to Play" to 0.17.6 (versionCode 14) in the SAME commit, and the next Android build uses
  versionCode 15 or higher; Microsoft Store Submission 31 stays "in certification" until observed in Partner
  Center. The code-review order is the Sprint 76 change: no 5.1.1; the 7.7.1 pair (Copilot by hand +
  pr-review-toolkit) runs after the retrospective improvements (CHANGELOG 2026-10-06).

**Issues to create at Phase 3.3.1**: F245 (none exists); MV76-1 can reuse #428 and #433 (both open) plus a
sprint card; R76-3 a research card. Draft PR from `feature/20261006_Sprint_77` to `develop` at the same step
(require-sprint-cards hook).

---

## Decision questions for Harold (answer by typing the digit)

Q-1 (MV76-1 check e, F250, #454 is CLOSED): now that the browser sign-in plus refresh-token renewal works on
Android, does the native one-pick sign-in still matter?
1. No -- record the account-state screenshot, leave #454 closed, note in ADR-0011/OAuth docs that Android uses
   the browser flow with native attempted first (current code), no further work.
2. Yes, later -- reopen as a backlog item that waits for a second-device reproduction (no sprint slot).
3. Yes, now -- add it to Sprint 77 (not recommended: cause is outside the app per SPRINT_76_PLAN.md:783-795).

Q-2 (MV76-1 R-9, getting the diagnostic log and the `.data.csv` off the Fold):
1. Harold copies the files by hand, as in Sprint 76 (default).
2. Generalize `scripts/pull-phone-screenshots.ps1` with a `-Folder` parameter (DCIM today; Documents or the
   export folder on request) and a `-Pattern` for `*diag_*.log` / `*.data.csv` -- a small HOOK/tooling task
   (10-20m) inside MV76-1, promoted per the "named for the job" rule.

Q-3 (F245 R-7): the "listed once" rule applies to:
1. The background scan export only (the backlog text).
2. Both the background and the manual-scan export files.

Q-4 (F245 R-5): an email dismissed with "Remove Current Rule" (processed, no rule) that a later scan still finds
with no rule:
1. Stays dismissed (the upsert keeps `processed`); it comes back only if it changes or after it was addressed.
2. Comes back as today (the upsert resets `processed` to 0 on refresh).

Q-5 (F245 R-3): the No Rule Review screen keeps reading only the latest completed scan per account (the upsert
moves rows to it) --
1. Yes, keep the screen as it is (recommended; smallest change).
2. No, change the screen to list every unprocessed row across scans (Class-2; larger change; also changes
   what "latest scan" means on that screen).

Q-6 (F245 R-6): the 90-day retention for No Rule rows cuts on:
1. `last_seen_at` -- an email a scan still sees is never dropped (recommended).
2. `created_at` (first seen) -- as today; a still-listed email vanishes 90 days after first sight.

Q-7 (F245 R-8): Scan History and the F251 banner:
1. Keep "No Rule" = No Rule emails evaluated in this scan (no change).
2. Add a second number, "new No Rule this scan" (extra column and UI; a separate small card).

Class-1 (F245 R-4, Chief Architect): the identity of a No Rule entry --
1. (account_id, provider_identifier_type, provider_identifier_value, folder_name) with a new `account_id`
   column back-filled in the migration (recommended: honors "account" in the backlog text and keeps two
   accounts' equal IMAP UIDs apart).
2. (provider_identifier_type, provider_identifier_value, folder_name), no new column (merges equal IMAP UIDs
   across accounts; not safe for two IMAP accounts).
3. Option 1 without `folder_name` (a moved email keeps its row; the row's folder is refreshed).

Q-8 (R76-3 R-6): time-box for the research:
1. 240 minutes (proposed).
2. 120 minutes (answers fewer of the eight questions; the rest become open questions).
3. Another number.



# Block B -- F264 + R76-2, R76-1, F258


# Sprint 77 plan cards -- block B (Background scanning)

Drafted 2026-10-06. Planning only; no repo file edited. Cards follow the "Augmented per-task template"
in `docs/SPRINT_PLANNING.md` lines 385-461 (read this turn). Est-Effort uses the Estimate Table in
`docs/CODING_VELOCITY.md` lines 56-73 (read this turn). All paths are under
`D:\Data\Harold\github\spamfilter-multi\` unless absolute.

Every card below carries the ADR-0042 parity statement (Windows path AND Android path named; parity
claimed with the OS behavior assumed identical, or an exception declared), per the Product Owner's
verbatim rule and `docs/adr/0042-cross-platform-parity-and-platform-exceptions.md` (read this turn).

---

## AUDIT FIRST -- what is already true (file:line)

### Interval control (F264)

- **Vocabulary is a 5-value enum, not minutes.** `mobile-app/lib/core/services/scan_frequency.dart:13-31`:
  `disabled(0)`, `every15min(15)`, `every30min(30)`, `every1hour(60)`, `daily(1440)`; `fromMinutes`
  returns `disabled` for anything else (line 25-30).
- **The UI offers values the enum cannot represent.** `settings_screen.dart:2457` offers `[15, 30, 60, 120, 240]`.
  Nothing in the enum is 120 or 240, and the enum's `daily` (1440) is NOT offered.
- **Latent bug 1 CONFIRMED (backlog claim).** `settings_screen.dart:1443-1444`:
  `ScanFrequency.fromMinutes(_backgroundScanFrequency)` then `if (frequency == ScanFrequency.disabled) return;`.
  Saving 120 or 240 persists the per-account override (`:1599-1600`) and returns without scheduling. The
  snackbar at `:1459-1463` never shows, so the user sees nothing. Read from code; not observed on a device.
- **Latent bug 2 -- SIBLING, not in the backlog.** `main.dart:382-385`: at every release startup the per-account
  frequency is mapped with `firstWhere(..., orElse: () => ScanFrequency.every15min)`. An account saved at 120 or
  240 is silently ensured at **15 minutes** on Windows (`ensureTaskExists` at `:388`). So the two latent bugs
  disagree with each other: the Settings path schedules nothing, the startup path schedules every 15 minutes.
- **Latent bug 3 -- frequency recovery by substring.** `windows_task_scheduler_service.dart:336-347` recovers the
  existing task's frequency from the trigger string with `contains('15')`, `contains('30')`, `'PT1H'`, `'Once'`.
  With arbitrary minutes this is wrong (115 contains '15'; 90 matches nothing and falls to the 1-hour default at
  `:337`). `verifyAndRepairTaskPath` is called from `main.dart:386` which already holds the effective frequency
  at `:381`.
- **Android clamps BEFORE the alarm.** `background_scan_scheduler.dart:257` `final minutes = frequency.minutes < 15 ? 15 : frequency.minutes;`
  and THAT clamped value is passed to `AndroidDozeAlarm.schedule(intervalMinutes: minutes)` at `:274-277` AND to
  `registerPeriodicTask` at `:283-286`. So a 5-14 minute interval does not reach the F235 alarm chain today; the
  alarm would be armed at 15. The backlog's "5-14 minutes run through the existing F235 Doze alarm chain at the
  chosen interval" is NOT already true.
- **The Doze alarm chain re-arms from its own stored interval.** `DozeAlarmScheduler.kt:89-118` stores
  `interval_<accountId>` in prefs `f235_doze_alarms`; `DozeAlarmReceiver.onReceive` (`:183-212`) re-reads it and
  re-arms, then `DozeScanTrigger.enqueue` (`DozeScanTrigger.kt:85-133`) hands off to WorkManager with KEEP.
  `MainActivity.kt:50-63` rejects `minutes <= 0` only; it accepts any positive integer. **No Kotlin change is
  needed for the interval itself** once Dart stops clamping before the alarm.
- **Windows trigger is a 5-way switch.** `powershell_script_generator.dart:216-241` emits one hard-coded
  `New-ScheduledTaskTrigger` line per enum value; `every15min/30min/1hour` use `-Once -At 12:00AM
  -RepetitionInterval ... -RepetitionDuration 365 days -RandomDelay (interval-1 min)`; `daily` uses `-Daily -At 09:00AM`.
- **`ScanFrequency` consumers (grep `ScanFrequency` in `lib/`, this turn, complete list):**
  `scan_frequency.dart` (definition); `settings_screen.dart:1443-1444` (schedule gate), `:1456,1462` (labels);
  `main.dart:382-384` (startup ensure); `background_scan_scheduler.dart:63,101,160-162,249-251,257` (interface +
  3 implementations); `windows_task_scheduler_service.dart:53,56,105,108,259,264,337-346`;
  `powershell_script_generator.dart:27,94,216-240`. **Not** consumed by `background_scan_core.dart`,
  `android_background_scan_worker.dart`, `background_scan_windows_worker.dart`, or any Kotlin file (the native
  side receives an `int intervalMinutes`).
- **Per-account storage already exists.** `settings_store.dart:629-651`: `getAccountBackgroundFrequency`,
  `setAccountBackgroundFrequency(accountId, int? minutes)` (key `background_frequency`, type int),
  `getEffectiveBackgroundFrequency` (account override, then global default 15 at `:79`). No schema change for
  the interval.
- **The 5-minute floor coincides with the spacing constant.** `background_scan_core.dart:253`
  `kMinScanSpacing = Duration(minutes: 5)`: a background scan waits until 5 minutes after the account's last
  completed scan. A floor BELOW 5 would make every scan wait; a floor of exactly 5 is the smallest value that
  does not.
- **Two helper texts already exist and will conflict with the new one.** `settings_screen.dart:1519-1540`
  (`_buildAndroidDozeStatusLine`, key `android_doze_status_line`): "Android may delay background scans by up to
  about an hour while the phone is idle ...". Pinned by `test/unit/ui/f217_doze_honesty_test.dart` (exists).
  `assets/content/help/background_scanning.md:7`: "Frequency: ... (hourly, 4-hourly, daily, etc.)" -- "4-hourly"
  is latent bug 1 in prose. Gated by `test/policy/help_platform_claims_test.dart` (no mechanism names).

### "Scan when new mail arrives" (F264 per-account part)

- **Today it is ONE app-wide flag in native prefs.** `MailNotificationListener.kt:79-80` prefs `f253_new_mail_trigger`,
  key `enabled`; read at `:48`; written by `applyEnabled` at `:91-107`, which also enables/disables the component.
  The Dart side (`new_mail_trigger.dart:15-62`) is a MethodChannel wrapper; `settings_screen.dart:1586` shows
  `NewMailTriggerRow` on every account's Background tab when `Platform.isAndroid`, deliberately NOT gated on
  the account's background switch (comment `:1582-1585`, review M-1).
- **Package -> provider mapping does not exist.** `MailNotificationPolicy.kt:19-25` is a flat allowlist of 5
  package names; `shouldTrigger` (`:30-41`) decides on package + enabled + 2-minute gap. JVM test exists
  (`android/app/src/test/.../MailNotificationPolicyTest.kt`, 5 tests).
- **The posting app's package ALREADY reaches the Dart worker.** `MailNotificationListener.kt:54-59` passes
  `sourceApp = pkg`; `DozeScanTrigger.enqueueAllAccounts` (`:149-180`) puts it in the payload under
  `KEY_TRIGGER_APP`; `background_scan_trigger.dart:26` `kTriggerAppKey = 'triggerApp'` reads it, but today ONLY
  for the diagnostic start line (`:45-46`). The worker's all-accounts loop
  (`android_background_scan_worker.dart:162-181`) filters by `getEffectiveBackgroundEnabled(id)` only.
- **The row's labels say "all accounts".** `new_mail_trigger_row.dart:138` title "Scan when new mail arrives
  (all accounts)"; status `:107-110` "On, for all accounts with background scanning on ...". Widget test
  `test/ui/widgets/f253_new_mail_switch_test.dart` reads these keys.
- **Windows has no listener and the row is hidden.** `settings_screen.dart:1586` `if (Platform.isAndroid)`. ADR-0044
  "Platform scope": "Android only, declared exception. Windows has neither Doze nor a mail-app notification to
  listen to".

### F258 Gmail label writes (gmail_api_adapter.dart)

- **Resolver exists and is used on the READ path only.** `_labelIdFor(String folder)` at `:1329-1338`: system
  labels are their own IDs; otherwise `users.labels.list` once per connection, cached in `_labelIds`; returns null
  for an unknown name. Its one caller is the incremental fetch at `:855`. `_getOrCreateLabel` (`:1503-1533`) is
  the separate name->ID-or-create precedent used by the flag path (`:1476`, `:1656`).
- **Five write sites send a NAME where Gmail wants an ID (all CONFIRMED):**
  1. `deleteMessage` `:925-941`: `targetLabel = _deletedRuleFolder ?? 'TRASH'`; non-TRASH goes to `modify(addLabelIds: [targetLabel], ...)` at `:933-940`.
  2. `moveMessage` `:957-967`: `labelId = _folderToLabelId(targetFolder)` (`:1354-1370` returns the input unchanged for a custom name) -> `addLabelIds: [labelId]` at `:963`.
  3. `moveToFolder` `:1421-1430`: `moveLabels(...)` (`:1300-1313`, static, pure) returns `add: [target]` where `target = _systemLabelOrSelf(targetFolder)` -> `addLabelIds: labels.add` at `:1425`.
  4. `moveToFolderBatch` `:1730-1760`: same `moveLabels` -> `addLabelIds: labels.add` at `:1742` and the per-message fallback at `:1755`.
  5. `takeActionBatch` delete `:1794-1806`: non-TRASH `_deletedRuleFolder` -> `moveToFolderBatch(messages, targetLabel)` (site 4).
  `_batchModifyLabels` (`:1828-1875`) is reached only with the literals `'TRASH'` / `'SPAM'` (`:1799,1812`) -- not a defect site.
- **Who supplies a custom name:** the Deleted Rule folder (`email_scanner.dart:307-309`, `results_display_screen.dart:4161-4164`,
  both via `getEffectiveDeletedRuleFolder`) and the safe-sender target (`email_scanner.dart:830-833`,
  `results_display_screen.dart:4254`). The picker stores `displayName` (`folder_selection_screen.dart:345`,
  `settings_screen.dart:2505-2511`).
- **Blast radius is bounded by the provider default.** `settings_store.dart:135-139`: the `gmail` API provider
  leaves `deletedRuleFolder` unset (class comment `:118-123` says exactly why: the adapter "treats a Deleted
  Rule folder other than null/`TRASH` as a label ID"). So a Gmail account with DEFAULT settings deletes through
  `trash()` (`:929`) and is unaffected; only a user-chosen custom folder (for example "Unwanted") hits 400
  "Invalid label". `'[Gmail]/Trash'` at `:133` belongs to `gmail-imap`, a different adapter.
- **Platform forks in the adapter:** `Platform.isWindows` at `:189` (token reuse) and `:400` (scopes) -- both on the
  sign-in path, none on the label-write path. The five sites are shared code on both platforms.
- **No source gate exists** for `addLabelIds:` / `removeLabelIds:` (grep of `test/` for those tokens this turn: no
  gate; the four files found are sign-in/scope tests). Precedent for a call-site gate:
  `test/policy/factory_call_site_test.dart` (ADR-0042 IMP-2).

### R76-1 tooling pre-flight (run this turn, 2026-10-06)

- `ANDROID_HOME = C:\Android\android-sdk`; `emulator.exe` present, **version 36.2.12.0** (build 14214601).
  (Not the stale `%LOCALAPPDATA%` SDK -- resolved through the environment variable per CLAUDE.md Sprint 67 IMP-3.)
- `emulator -list-avds`: **`pixel34_updated`** (target android-34-ext12, image `google_apis_playstore/x86_64`,
  device pixel_5, PlayStore.enabled = no in config) and **`Nexus_5X_API_29_x86`** (android-29, google_apis, x86).
- `adb` present, **version 1.0.41 / 36.0.0-13206524**; daemon started; `adb devices` lists nothing (no emulator
  booted -- a boot was deliberately not attempted, per the task instruction). adb against the EMULATOR is the
  intended path; adb to the physical phones remains blocked by company policy (memory
  `feedback_phone_screenshots_mtp`).
- An actual emulator BOOT was not attempted this turn; "boots on this machine" is therefore **unverified** and is
  R76-1's first step (T-0 below). The Sprint 67 record says the 36.x emulator launched android-34 images once
  the correct SDK was used.

---

## Primary sources consulted this turn (quotes)

- **WorkManager periodic minimum** -- developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work:
  "The minimum repeat interval that can be defined is 15 minutes (same as the JobScheduler API)."
- **Doze alarm limit** -- developer.android.com/training/monitoring-device-state/doze-standby:
  "Neither `setAndAllowWhileIdle()` nor `setExactAndAllowWhileIdle()` can fire alarms more than once per nine
  minutes, per app." Doze "Suspends network access" and "Doesn't let JobScheduler run". Testing: "Configure a
  hardware device or virtual device with an Android 6.0 (API level 23) or higher system image";
  `adb shell dumpsys deviceidle force-idle` / `unforce`; `adb shell dumpsys battery unplug` / `reset`;
  `adb shell am set-inactive <pkg> true|false`.
- **Standby bucket limits** -- developer.android.com/topic/performance/power/power-details: alarms "Active: No
  execution limits; Working set: Limited to 10 per hour; Frequent: Limited to 2 per hour; Rare: Limited to 1
  per hour; Restricted: One alarm per day"; in Doze "While-idle alarms: Limited to 7 per hour"; "WorkManager
  uses JobScheduler to schedule tasks when the app is not visible and workers are thus impacted by job resource
  limits." (Note: the 9-minute figure comes from the doze-standby page; power-details states 7 per hour for
  while-idle alarms. Both are Android's own pages and are consistent: 60/9 = 6.7.)
- **Windows Task Scheduler repetition interval** -- learn.microsoft.com/en-us/windows/win32/taskschd/repetitionpattern-interval:
  "The format for this string is `P<days>DT<hours>H<minutes>M<seconds>S` ... The maximum time allowed is 31
  days, and the minimum time allowed is 1 minute." So 5 minutes to 99 hours (4 days 3 hours) is inside the
  documented range. **The backlog's "unverified" note on Windows is now verified.**
- **PowerShell cmdlet** -- learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger:
  `-RepetitionInterval <TimeSpan>` and `-RepetitionDuration <TimeSpan>` exist only in the `Once` parameter set;
  `-RandomDelay <TimeSpan>` in all sets. No cmdlet-level min/max is stated beyond the COM limit above.
- **Battery measurement on an emulator** --
  developer.android.com/topic/performance/power/setup-battery-historian: "To use Batterystats and Battery
  Historian, you need a mobile device with USB debugging enabled"; `adb shell dumpsys batterystats --reset`,
  `adb shell dumpsys batterystats > batterystats.txt`, `adb bugreport bugreport.zip`; Battery Historian "is no
  longer actively maintained" (Docker image `gcr.io/android-battery-historian/stable:3.1`).
  developer.android.com/studio/profile/power-profiler: "Power Profiler reads power consumption data from the
  ODPM, which is only available on Pixel 6 and subsequent Pixel devices running Android 10 (API level 29) and
  higher." No emulator support stated.
  **Conclusion for R76-1:** an emulator cannot give energy (mAh/mW) -- it has no battery hardware and no ODPM.
  It CAN give the COUNTS that drive energy: wakeups, alarms fired, jobs run, network bytes and CPU time
  (`dumpsys batterystats` sections for the app's UID after `dumpsys battery unplug`, plus `dumpsys alarm` and
  `dumpsys jobscheduler`), under forced Doze/standby. Absolute energy is measured only on the Fold
  (Settings > Battery > app usage screenshot, pulled over MTP).

---

## Task B1 -- F264 + R76-2: Per-account interval (unit + number), per-account "Scan when new mail arrives", and the Background section rework (Priority 10 / 3)

**Value**: This enables a user to set each account's background interval from 5 minutes to 99 hours on both
platforms, to turn new-mail-triggered scans on per account, and this prevents the silent no-schedule (120/240)
and silent 15-minute (startup) defects that the fixed dropdown created.

**Requirements** (numbered, detailed):
- R-1 (audit first, build second): confirm the three latent bugs above with a failing test BEFORE the fix
  (`fromMinutes(120)` -> disabled at `settings_screen:1443`; `main.dart:382` orElse -> 15;
  `verifyAndRepairTaskPath` substring recovery). Record which were reproduced.
- R-2 (one shared interval model): replace the `ScanFrequency` enum vocabulary with an integer number of minutes
  carried end to end. ONE shared parser/validator (new, `lib/core/services/scan_interval.dart`, name
  indicative): `(unit, number) -> minutes`, `minutes -> (unit, number)` for display, `validate(minutes)` with
  `kMinIntervalMinutes = 5`, `kMaxIntervalMinutes = 99 * 60`, and a `label(minutes)` ("5 minutes", "2 hours",
  "99 hours"). Both platforms' UI and both schedulers use it. `ScanFrequency` is deleted, or reduced to a
  thin deprecated alias for one sprint if any test fixture still names it (decide at implementation; the grep
  above lists every consumer).
- R-3 (floor and ceiling, with the reason in the UI): an entry under 5 minutes shows the inline message
  "Minimum is 5 minutes, to limit battery use" and is NOT saved (the stored value stays what it was); an entry
  over 99 hours is not enterable (2-digit box, unit dropdown). The floor is >= `BackgroundScanCore.kMinScanSpacing`
  (5 min) and a test pins that relation, so a 5-minute interval never becomes a permanent spacing wait.
- R-4 (control shape, Harold-confirmed "1. a 2. a"): unit dropdown FIRST (Minutes | Hours), then a 2-digit
  number field (1-99). Interval = number x unit. Replaces `_buildFrequencySelector` (`settings_screen.dart:2453-2471`)
  and the `[15, 30, 60, 120, 240]` list. Saves through the EXISTING `setAccountBackgroundFrequency` (minutes)
  and reschedules through the EXISTING `_updateScheduledScan` (`:1430`), whose `fromMinutes`/`disabled` gate
  (`:1443-1444`) becomes `validate(minutes)`.
- R-5 (Windows path): `powershell_script_generator.dart:216-241` emits ONE trigger shape for every interval:
  `-Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes <n>) -RepetitionDuration (New-TimeSpan -Days 365)
  -RandomDelay (New-TimeSpan -Minutes <n-1>)`. The `-Daily` special case is removed (1440 minutes is just another
  interval; the 09:00AM daily anchor was never user-selectable from the Settings list -- see audit). Verified
  against Microsoft's documented 1 minute .. 31 days range (quote above). `-RandomDelay` keeps the F98
  anti-collision jitter but is CAPPED: `min(interval - 1, 59)` minutes. Task Scheduler draws a fresh random
  delay on EVERY firing (F98 comment at `powershell_script_generator.dart:219-222`), so the old "interval minus
  one" rule, written for intervals of at most an hour, would put up to four days of jitter on a 99-hour task.
  For 5 minutes the delay is 4; for 90 minutes and above it is 59 (today's 1-hour value). This cap is the card's
  choice (de-synchronizing accounts needs minutes, not days); listed under Decision-class interrupts for the record.
- R-6 (Windows repair path): `verifyAndRepairTaskPath` (`windows_task_scheduler_service.dart:307-360`) stops
  recovering the frequency from the trigger string; it takes the effective minutes from its caller (`main.dart:381`
  already has them). The `triggerFrequency` status field stays for diagnostics only.
- R-7 (Android path, 15 and above): `AndroidSchedulerAdapter.schedule` registers `registerPeriodicTask` with
  `max(minutes, 15)` (WorkManager minimum, quote above) and arms `AndroidDozeAlarm.schedule` with the UNCLAMPED
  minutes. The clamp moves from before line 274 to the `registerPeriodicTask` argument only. The class comment
  block "Android-specific constraints, DECLARED per ADR-0042" (`:184-214`) is rewritten: the 15-minute floor is
  now REACHABLE and applies to the WorkManager safety net only; the alarm carries the user's interval.
- R-8 (Android path, 5-14 minutes): runs on the F235 alarm chain only. Android's own limit applies and is stated
  to the user (R-11): no more than once per 9 minutes per app in Doze, 10 per hour in the Working set bucket,
  fewer in lower buckets. No Kotlin change: `DozeAlarmScheduler.schedule` already stores and re-arms any
  positive interval (`:89-118`, `:183-212`); `MainActivity.kt:52` rejects only `<= 0`. The Dart test for this
  path asserts the two different numbers reach the two different channels.
- R-9 (startup reconciliation): `main.dart:380-391` passes the stored minutes straight through (no enum lookup);
  an out-of-range stored value (from an older build, or hand-edited) is clamped into [5, 5940] with a log line, not
  silently replaced by 15.
- R-10 (per-account "Scan when new mail arrives" -- Android): the switch moves from app-wide to per account in
  each account's Background section, beside the interval. Mapping of posting app -> accounts, exactly as Harold
  specified: Gmail app -> Gmail accounts with the switch on; AOL app -> AOL accounts; Yahoo Mail -> Yahoo
  accounts; Samsung Email and Outlook -> every account with the switch on. The mapping lives in the EXISTING
  `MailNotificationPolicy` (extend it with a pure `providersFor(packageName): Set<String>?`; null = any
  provider), JVM-tested. The 2-minute listener gap and the 5-minute `BackgroundScanCore` spacing are unchanged.
  WHERE the per-account flag is stored is a Class-1/2 interrupt (below) -- the card does not decide it; it lists
  the two shapes.
- R-11 (R76-2 section rework): the Background tab's top block becomes, in order: account header; "Enable
  Background Scanning" switch; "Scan every" (unit dropdown, number box, inline validation line); "Scan when new
  mail arrives" switch (Android; Windows per the Class-1 interrupt below) with its status line; the Android
  battery row (F252); ONE helper line replacing `_buildAndroidDozeStatusLine` text (`settings_screen.dart:1530-1533`):
  "Android runs background scans when the phone allows; while it is idle, expect up to about 45 minutes between
  scans." This line keeps the existing `Platform.isAndroid && _backgroundScanEnabled` gate at
  `settings_screen.dart:1576` (the F217 declared ADR-0042 exception); it is never shown on Windows. Then Divider,
  Test, Scan Mode, Scan Range, Default Folders, Debug as today. The F217 honesty test
  (`test/unit/ui/f217_doze_honesty_test.dart`) is updated to the new sentence, not deleted.
- R-12 (help content, ADR-0038): `assets/content/help/background_scanning.md` line 5-7 rewritten: Frequency becomes
  "Scan every: a number and a unit (minutes or hours), from 5 minutes to 99 hours, per account"; a new bullet for
  "Scan when new mail arrives" that describes the capability per account and names which mail apps map to which
  accounts, without naming WorkManager/Task Scheduler (gate `help_platform_claims_test.dart`); the "4-hourly" text
  goes. The helper sentence in R-11 appears here too.
- R-13 (migration of existing values): existing per-account `background_frequency` values 15/30/60/120/240 are all
  valid minutes and need no migration. The app-wide default (`settings_store.dart:79`, 15) is unchanged. The
  app-wide native `f253_new_mail_trigger.enabled` flag: migration rule is part of the Class-1 interrupt.

**Affected components / files**:
- `mobile-app/lib/core/services/scan_frequency.dart:13-31` -- enum retired (R-2).
- NEW `mobile-app/lib/core/services/scan_interval.dart` -- parser/validator/label (R-2, R-3).
- `mobile-app/lib/core/services/background_scan_scheduler.dart:61-64,99-103,158-173,184-214,247-301` -- interface takes `int intervalMinutes`; Android clamp moves to the WorkManager call only (R-2, R-7, R-8).
- `mobile-app/lib/core/services/windows_task_scheduler_service.dart:52-58,104-111,258-264,336-347` -- minutes in; frequency recovery removed (R-5, R-6).
- `mobile-app/lib/core/services/powershell_script_generator.dart:27,94-98,216-241` -- one trigger shape (R-5).
- `mobile-app/lib/main.dart:380-391` -- pass minutes; clamp with log (R-9).
- `mobile-app/lib/ui/screens/settings_screen.dart:1430-1489` (schedule gate), `:1519-1540` (helper text), `:1542-1610` (section order), `:2453-2471` (control) -- R-4, R-11.
- `mobile-app/lib/ui/widgets/new_mail_trigger_row.dart` -- per-account title/status; takes `accountId` (R-10).
- `mobile-app/lib/core/services/new_mail_trigger.dart` -- per-account read/write (shape per interrupt) (R-10).
- `mobile-app/android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationPolicy.kt:19-41` -- package -> provider mapping (R-10).
- `mobile-app/android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationListener.kt:43-59` and `MainActivity.kt:122-178` -- read "any account on" (shape per interrupt) (R-10).
- `mobile-app/lib/core/services/android_background_scan_worker.dart:162-181` -- a notification-started run scans only the accounts the mapping selects (R-10).
- `mobile-app/assets/content/help/background_scanning.md:5-7` -- R-12.
- `docs/adr/0039-per-account-background-scanning.md` -- amendment: interval model and the alarm-only 5-14 band.
- `docs/adr/0044-notification-triggered-scan.md` -- amendment: per-account switch and app -> provider mapping.
- `docs/ARCHITECTURE.md:555-601` -- the three background paragraphs.
- Tests listed under T-N.

**Existing abstraction checked**: `SettingsStore.getEffectiveBackgroundFrequency` / `setAccountBackgroundFrequency`
(`settings_store.dart:629-651`) -- reused as the store, not duplicated. `BackgroundScanScheduler` interface
(`background_scan_scheduler.dart:41-70`) -- the member CHANGES type; no new sibling. `MailNotificationPolicy` --
extended, not forked (backlog instruction). `AndroidDozeAlarm.schedule(intervalMinutes:)` -- already takes an int;
reused. No existing interval parser found (grep `TimeSpan|intervalMinutes|parseInterval` in `lib/core`: only the
alarm's int plumbing).

**Existing behavior relied on**:
- "`DozeAlarmScheduler` re-arms at the stored per-account interval after every firing and after boot" -- verified
  `DozeAlarmScheduler.kt:102-108` (store), `:194-205` (re-arm), `:223-232` (boot).
- "`MainActivity` accepts any positive `intervalMinutes`" -- verified `MainActivity.kt:51-62`.
- "`registerPeriodicTask` with the same unique name UPDATES existing work" -- `background_scan_scheduler.dart:292`
  `ExistingPeriodicWorkPolicy.update` (plugin behavior, relied on since F161).
- "Task Scheduler accepts a repetition interval from 1 minute to 31 days" -- Microsoft quote above.
- "A background scan waits until 5 minutes after the account's last completed scan" -- `background_scan_core.dart:212-221,253`.
- "The posting app's package name is already in the worker payload" -- `DozeScanTrigger.kt:160`, `background_scan_trigger.dart:26,45`.

**Callers of any guard being changed**:
- `settings_screen.dart:1443-1444` (`disabled` early return): callers are the Enable switch (`:1572`) and the
  frequency change (`:1605-1606`). After: `validate(minutes)` failing is impossible from the UI (the control
  refuses to save an invalid value), so the guard becomes a defensive log + return; both callers keep their
  snackbar outcomes.
- `background_scan_scheduler.dart:162,251` (`disabled` -> return false) and `windows_task_scheduler_service.dart:56,108,264`:
  callers are `settings_screen._updateScheduledScan`, `main.dart:388 ensureTaskExists`, and the adapters
  themselves. After: `minutes <= 0` keeps the same false/delete semantics (`updateScheduledTask:108-111` deletes on
  disabled -- that mapping is kept for `<= 0`).
- `background_scan_scheduler.dart:257` (15-minute clamp): the ONLY caller of the clamped value was the two
  lines below it. After: the alarm gets the raw minutes, WorkManager the clamped one. No other reader.
- `main.dart:382-385` (orElse 15): one caller (startup loop). After: clamp-with-log (R-9).
- Tooling that launches or kills the same executable: `scripts/run-winwright-tests.ps1` stops the dev exe per
  script; a 5-minute Windows task fires more often during a WinWright sweep than today's 15 -- the sweep's
  per-script cleanup already handles a background launch (Sprint 75 retro IMP-4), but the DEV machine's own
  per-account tasks should stay at >= 15 during sweeps. Note in the WinWright runner README; no code change.

**User-reachable control**: Settings > Background (per account) > "Scan every" (unit dropdown + 2-digit number
box + inline message) and "Scan when new mail arrives" switch, on both platforms (Windows presentation of the
second per the interrupt).

**Observable behavior -- before / after**:
- BEFORE: a fixed "Scan every" dropdown of 15 min / 30 min / 1 hour / 2 hours / 4 hours; choosing 2 or 4 hours
  saves and shows no confirmation, and nothing is scheduled; on the next app start (release) the account runs
  every 15 minutes instead. One app-wide "Scan when new mail arrives (all accounts)" switch on Android, shown on
  every account's tab; Android helper line says "up to about an hour".
- AFTER: "Scan every" is a unit dropdown (Minutes | Hours) followed by a 2-digit number; 5 minutes to 99 hours;
  below 5 shows "Minimum is 5 minutes, to limit battery use" and keeps the previous value; a valid change shows
  "Background scan scheduled every <n> <unit>" as today. "Scan when new mail arrives" is a per-account switch
  whose status names this account's mail app(s) ("When the Gmail app, Samsung Email or Outlook shows new mail,
  this account is scanned"). The helper line reads "Android runs background scans when the phone allows; while it
  is idle, expect up to about 45 minutes between scans." Section order per R-11. Windows: same interval control;
  the new-mail switch per the interrupt.
- Behavioral (Gherkin) AC-4/AC-5 below.

**Dependencies / blockers**:
- Class-1/2 interrupts below MUST be answered at plan approval (Phase 3.7) before T-10/T-11 start; everything
  interval-related (R-1..R-9, R-11 except the switch, R-12) can start immediately.
- R76-1 (Task B2) informs the floor; the card ships the Product Owner's 5-minute floor as a named constant that
  R76-1 may revise in a one-line follow-up. B2 should run BEFORE or ALONGSIDE B1's T-3, not after Manual Validation.
- MV76-1 (Fold check of `trigger=notification`, AOL/Yahoo package names) is prerequisite evidence for the mapping's
  package names (`MailNotificationPolicy.kt:15-18` says AOL/Yahoo are unverified).

**Non-functional requirements**:
- Account-scoping: every read/write goes through `_requireAccountId` / `getEffectiveBackgroundFrequency(accountId)`;
  the notification-started worker filters on the per-account flag AND `getEffectiveBackgroundEnabled` (Sprint 19 rule).
- Accessibility: the number field has a semantic label "Interval number"; the inline validation line is a `Text`
  with a key and is announced (ADR-0037); contrast from the theme's error color.
- Platform (ADR-0042): interval control + storage + validator are SHARED code on Windows and Android, identical
  UI. Schedulers stay behind the existing factory. **Parity claim**: both OS schedulers accept an arbitrary
  minute interval in [5, 5940] -- Windows per the Microsoft quote; Android per the AlarmManager chain (any positive
  int) plus the WorkManager safety net clamped at 15 (declared, extends the existing adapter declaration).
  **Declared exceptions**: (a) delivery timing differs -- Windows fires on the minute, Android as the OS allows
  (already declared at `background_scan_scheduler.dart:189-212`; the helper text is the user-facing form);
  (b) "Scan when new mail arrives" has no Windows mechanism (ADR-0044) -- its Windows PRESENTATION is the
  interrupt below (ADR-0042 point 5 "degrade, do not disappear" versus ADR-0044's hidden row).
- Persistence: per-account minutes in the existing `background_frequency` key; the new-mail flag per the interrupt.

**Acceptance criteria** (measurable, traceable):
- AC-1: `validate(4)` fails with the exact message "Minimum is 5 minutes, to limit battery use"; `validate(5)`,
  `validate(99)`, `validate(99*60)` pass; `validate(99*60+1)` fails; `toMinutes(Hours, 2) == 120`;
  `label(120) == "2 hours"`, `label(5) == "5 minutes"`.
- AC-2: saving 120 or 240 minutes on an enabled account calls `scheduler.schedule(accountId, 120|240)` exactly once
  and shows the "scheduled every" snackbar (the `:1443` early return is gone).
- AC-3: at startup an account stored at 240 is ensured at 240, not 15; a stored 3 is clamped to 5 with a log line.
- AC-4 (behavioral): Given the Background tab for account A, When the user picks Minutes and types 4, Then the
  inline line reads "Minimum is 5 minutes, to limit battery use", the stored value is unchanged, and no
  schedule call is made.
- AC-5 (behavioral): Given account A at 2 hours, When the user picks Hours and types 99, Then
  `setAccountBackgroundFrequency(A, 5940)` and `schedule(A, 5940)` are called once each.
- AC-6 (Windows): the generated create and update scripts for 5, 90, 1440 and 5940 minutes each contain
  `-RepetitionInterval (New-TimeSpan -Minutes <n>)`; the `-RandomDelay` values are 4, 59, 59 and 59 minutes
  respectively (`min(n-1, 59)`); no script contains `-Daily`.
- AC-7 (Windows repair): `verifyAndRepairTaskPath` recreates with the minutes it is GIVEN; no code path reads the
  interval from the trigger string.
- AC-8 (Android): `schedule(A, 5)` invokes the doze_alarm channel with `intervalMinutes: 5` and WorkManager with
  `Duration(minutes: 15)`; `schedule(A, 30)` passes 30 to both.
- AC-9 (mapping, JVM): `providersFor("com.google.android.gm") == {gmail}`, AOL -> {aol}, Yahoo -> {yahoo},
  Samsung Email and Outlook -> null (any), unknown package -> empty/false; `shouldTrigger` unchanged for the
  gap and enabled rules.
- AC-10 (worker): a notification-started run from the Gmail app scans only accounts whose provider is Gmail AND
  whose per-account new-mail switch is on AND whose background switch is on; from Samsung Email, every account
  with both switches on.
- AC-11 (UI text): the helper line is exactly "Android runs background scans when the phone allows; while it is
  idle, expect up to about 45 minutes between scans." and appears once; the old "up to about an hour" text
  appears nowhere in `lib/ui/`.
- AC-12 (help): `background_scanning.md` contains "5 minutes", "99 hours", a "Scan when new mail arrives" bullet,
  no "4-hourly", and still passes `help_platform_claims_test.dart`.
- AC-13 (floor relation): `kMinIntervalMinutes * 60 >= BackgroundScanCore.kMinScanSpacing.inSeconds`.
- AC-14 (switch reachability): Settings > Background for account A shows the per-account new-mail switch
  (Android), and the Windows presentation per the interrupt decision, with its key present in a widget test.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (AC-1, AC-13) -- TEST-UNIT in `test/unit/services/scan_interval_test.dart`: parse/validate/label at 4, 5, 99 min, 99 h, 99 h + 1; the floor-vs-spacing relation. Replaces `scan_frequency_test.dart`.
- T-2 (AC-2, AC-4, AC-5) -- TEST-WIDGET in `test/ui/screens/f264_interval_control_test.dart`: with `BackgroundScanSchedulerFactory.overrideForTest`, drive the unit+number control; assert the schedule call count and arguments, the inline message, and that an invalid entry does not write. "Does NOT catch": the real Task Scheduler / WorkManager accepting the value -- Manual Validation.
- T-3 (AC-3) -- TEST-UNIT in `test/unit/services/startup_interval_reconcile_test.dart` (extract the loop body of `main.dart:369-395` into a testable function first -- state this in the commit): 240 stays 240; 3 becomes 5 with a log.
- T-4 (AC-6) -- TEST-UNIT extend `test/unit/services/powershell_script_generator_test.dart`: four intervals, no `-Daily`. "Does NOT catch": PowerShell executing it (source-text test, as its header says).
- T-5 (AC-7) -- TEST-UNIT extend `test/unit/services/windows_task_scheduler_service_test.dart`: repair uses the given minutes; the old `contains('15')` branch is gone (source assertion acceptable here because the behavior is "no parse exists").
- T-6 (AC-8) -- TEST-UNIT extend `test/unit/services/f235_doze_alarm_test.dart` / `background_scan_scheduler_test.dart`: the two channels receive 5 and 15 respectively for a 5-minute interval. Mutation: swap the clamp back to before the alarm call -- must go red.
- T-7 (AC-9) -- JVM in `android/app/src/test/kotlin/com/myemailspamfilter/MailNotificationPolicyTest.kt`: the mapping table. Run with `gradlew :app:testDevDebugUnitTest` (CI does not run it -- say so in the card's DoD).
- T-8 (AC-10) -- TEST-UNIT in `test/unit/services/f264_notification_account_filter_test.dart`: the worker's account filter as a pure function (extract it): provider x switch x background-enabled matrix. "Does NOT catch": Android delivering the notification and the real package names (MV76-1 / Fold).
- T-9 (AC-11) -- TEST-UNIT update `test/unit/ui/f217_doze_honesty_test.dart` to the new sentence; add the "appears nowhere" negative.
- T-10 (AC-12) -- TEST-UNIT extend `test/policy/help_platform_claims_test.dart` or `content_loader_test.dart`: the four content assertions.
- T-11 (AC-14) -- TEST-WIDGET extend `test/ui/widgets/f253_new_mail_switch_test.dart`: per-account title and status; the Windows branch per the decision (both branches, ADR-0042 point 4, through the testable platform seam, not `dart:io`).
- T-12 (source parity) -- extend the existing F235 source-parity assertion so `kMinIntervalMinutes` and the Kotlin `MainActivity` acceptance (`minutes <= 0`) cannot drift (the Kotlin side must not grow its own floor).

**Definition of Done**: default task-level DoD PLUS:
- ADR-0039 and ADR-0044 amendments written in the same commit as the code (architecture-docs-no-defer).
- `gradlew :app:testDevDebugUnitTest` run locally and its pass count reported (CI runs `flutter test` only).
- Mutation re-run AFTER the fix at the call sites (Sprint 73 IMP-3): the `:1443` gate, the `main.dart` clamp, the alarm/WorkManager split.
- Manual Validation recipe written with PRECONDITIONS (Sprint 75 IMP-5): Windows -- set 7 minutes on a dev
  account, confirm in Task Scheduler (`Get-ScheduledTask | Get-ScheduledTaskTrigger`) that the repetition interval
  is PT7M, then wait two firings; Android -- set 5 minutes, lock the phone, read `trigger=doze-alarm delay=` lines
  and the gap between them from the diagnostic log; per-account switch -- Gmail notification scans the Gmail
  account only (Fold, MTP log pull).
- CHANGELOG entries: feat (interval), feat (per-account new-mail), fix (120/240 never scheduled; startup reset to 15).

**Model**: Sonnet -- *why not Haiku*: three surfaces (Dart shared, Windows PowerShell generation, Android
Kotlin) plus an interface type change across three implementations and a Class-1-shaped storage decision to
implement exactly as approved; the Sprint 75 Haiku batch returned an Android-only edit on a two-platform task,
and this card is the two-platform case. *Why not Fable/Opus*: the design is fully specified here; nothing is
left to discover. Sub-tasks T-1, T-4, T-9, T-10 are Haiku-shaped and may be batched to Haiku with the
delegation checklist (SPRINT_PLANNING.md option (b)).
**Delegation checklist included in the sub-agent prompt** (when delegated): yes

**Executed-by** (filled at completion):

**Step-types**: SVC-NEW (interval model), SVC-EDIT x6 (scheduler interface + 2 adapters, Windows service,
PS generator, main.dart, settings gate), UI-NEW (unit+number control), UI-MOVE (section order), NATIVE-ANDROID
(Kotlin mapping + prefs shape; estimated at the NATIVE-WIN band), TEST-UNIT x8, TEST-WIDGET x2, CONTENT, DOCS x3 (2 ADR amendments + ARCHITECTURE).

**Est-Effort**: 220-425m effort / 220-425m wall-clock. Build-up: SVC-NEW 5-18; SVC-EDIT 6 x 5-18 = 30-108;
UI-NEW 30-40; UI-MOVE 3-6; NATIVE 3 x 10-15 = 30-45; TEST-UNIT 8 x 4-10 = 32-80; TEST-WIDGET 2 x 20-25 = 40-50;
CONTENT 5-18; DOCS 3 x 15-20 = 45-60 (sums: 220 low, 425 high). Per the Sprint 49 recompute note, S-size
SVC-EDIT items run near the low end, so expect the lower half. Manual Validation wall-clock (two platforms, Fold
log pulls) is NOT in this number.

**Risk & rollback**: Risk 1 -- a 5-minute Windows task on a dev machine during a WinWright sweep (mitigated:
note in runner README; dev accounts stay >= 15 during sweeps). Risk 2 -- dropping `-Daily` changes the 09:00
anchor for any account that somehow holds 1440 (none can, from the UI; startup clamp logs it). Risk 3 -- the
notification worker scanning FEWER accounts than before for users who had the app-wide switch on (migration
rule in the interrupt). Rollback: the interval model is additive over the same storage key; reverting the
commit restores the enum and the old dropdown with no data loss; the new-mail per-account flag's rollback
depends on the storage choice (DB key: rows ignored; native prefs: keys ignored).

**Decision-class interrupts** (STOP, surface, wait -- at Phase 3.7):
1. **Class-1 (data model)** -- WHERE the per-account "Scan when new mail arrives" flag lives. Today: ONE
   app-wide boolean in Android SharedPreferences `f253_new_mail_trigger.enabled`, read by a native service with
   no Flutter engine. Options: (a) per-account key in `account_settings` (ADR-0013 shape, key
   `new_mail_trigger`, with the native flag becoming "any account on" so the listener still gates cheaply; the
   Dart worker filters accounts; keeps the listener's privacy contract untouched); (b) per-account entries in the
   native prefs (`enabled_<accountId>`), with the listener doing the mapping natively and passing the selected
   account ids in the payload (listener grows account knowledge; two stores of truth). Recommendation to present:
   (a). Also: migration rule when the app-wide flag is ON at upgrade -- (i) copy ON to every account (ADR-0039
   Locked Decision 1 precedent) or (ii) start every account OFF.
2. **Class-1 (parity, ADR-0042 point 5 vs ADR-0044)** -- Windows presentation of the per-account switch.
   Options: (a) hidden on Windows (today's shape; ADR-0044 declared exception, extended to the per-account
   switch); (b) shown disabled with one line "Not available on this platform" (conflicts with the
   no-unshipped-platform-caveat rule? No -- Windows IS shipped; but it documents an absence); (c) a Windows
   equivalent (none exists: no mail-app notification to listen to; Windows background scans are already
   schedule-driven). Recommendation to present: (a), recorded in the ADR-0044 amendment.
3. **Class-2 (signature)** -- `BackgroundScanScheduler.schedule({required ScanFrequency frequency})` becomes
   `({required int intervalMinutes})` across the interface and 3 implementations; `WindowsTaskSchedulerService`
   and `PowerShellScriptGenerator` likewise; `verifyAndRepairTaskPath` gains a required minutes parameter. Scoped
   by the F264 backlog text ("replaces ... the ScanFrequency list") but it is a prior development decision (F144,
   F161) -- surfaced for the record.
4. **Class-2 (text)** -- the F217 helper sentence ("up to about an hour") is replaced, not kept beside the new
   one. Harold's F264 text is the honest floor; two sentences with two numbers would contradict each other.
5. **Class-2 (Windows jitter)** -- `-RandomDelay` capped at `min(interval - 1, 59)` minutes (R-5). The F98
   rule "interval minus one" was a development decision sized for intervals up to an hour; at 99 hours it would
   add up to four days of random delay per firing. Surfaced for the record; the card proceeds with the cap
   unless Harold objects.

---

## Task B2 -- R76-1: Battery deep dive for "Scan when new mail arrives" -- A/B tests on the Android emulator (Priority 2)

**Value**: This enables the interval floor and the per-account mapping in F264 to be set from measured
counts rather than from the Product Owner's estimate, and this prevents shipping a trigger design whose battery
cost is unknown.

**Requirements** (numbered, detailed):
- R-1 (tooling pre-flight, FIRST): boot `pixel34_updated` from `$env:ANDROID_HOME\emulator\emulator.exe`
  (`-avd pixel34_updated -no-snapshot-load`), confirm `adb devices` shows it, install the dev debug build with
  `scripts/build-with-secrets.ps1 -BuildType debug -InstallToEmulator` (read its `param()` block first, per
  CLAUDE.md Sprint 66 IMP-1). Record emulator version, AVD, API level, and boot time. If the boot fails, print the
  version of the binary actually invoked before reporting (Sprint 67 IMP-3). Pre-flight so far (this turn):
  emulator 36.2.12.0; AVDs `pixel34_updated` (API 34, google_apis_playstore x86_64) and `Nexus_5X_API_29_x86`;
  adb 36.0.0; no device booted.
- R-2 (what an emulator can and cannot measure, from the vendor pages quoted above): it cannot report energy
  (no battery, no ODPM; Battery Historian wants "a mobile device with USB debugging"; Power Profiler needs Pixel
  6+). It CAN report, per app UID, after `adb shell dumpsys battery unplug` + `dumpsys batterystats --reset`:
  wakeup alarms, jobs started/duration, network bytes, CPU user/system time, wakelock time (`dumpsys batterystats
  <package>`), plus `dumpsys alarm` (alarm counts and wakeups) and `dumpsys jobscheduler` (job history). Doze and
  standby can be FORCED (`dumpsys deviceidle force-idle`, `am set-inactive`, `am set-standby-bucket` -- the last is
  not on the doze-standby page; verify with `adb shell am help` during R-1 and cite or drop it). The deep dive
  states this explicitly so counts are never read as energy.
- R-3 (the A/B protocol, each arm identical except the variable): fixed inputs -- 2 fake accounts (one gmail, one
  aol; mock or test mailboxes), background on, Scan Range 1 day, a 60-minute window, the device forced idle
  after minute 2. Measured per arm: wakeups, scans started (diagnostic log `trigger=` lines, pulled via `adb pull`
  from the emulator -- adb is fine on the emulator), network bytes, CPU seconds, and the longest gap between
  scans. Notification source for arms 2, 3, 5, 6: `adb shell cmd notification post` posts under the SHELL
  package, which is not in `MAIL_APP_PACKAGES`, so it cannot trigger the listener as-is; and adding a test hook
  that bypasses the package check is NOT acceptable (it would weaken the privacy contract). Two acceptable
  sources, in order: (a) the real Gmail app if it is preinstalled on the `google_apis_playstore` image (check in
  R-1 with `adb shell pm list packages | findstr gm`), signed in to a test account; (b) a debug-build-only extra
  package in the allowlist (`BuildConfig.DEBUG` guarded, never in release) with notifications posted from a
  scratch helper app or from `cmd notification post` if that package can be made the poster. Record which was
  used; (b) is interrupt 2 below.
- R-4 (arms, prioritized by likely success -- the deliverable's order):
  1. **Periodic only (control)**: new-mail off; interval 15. Baseline counts.
  2. **New-mail ON, all-accounts (today's F253)** at interval 15.
  3. **New-mail ON, per-account mapping (F264 shape)**: Gmail notification -> gmail account only. Expected:
     fewer scans per notification than arm 2 with the same coverage.
  4. **Interval 5 (alarm-only band) with new-mail off**: measures what Android actually grants at the floor
     (expect ~9-minute spacing in Doze per the quote).
  5. **Interval 5 + new-mail ON per-account**: the worst-case configuration; decides whether the 5-minute floor
     holds or should rise.
  6. **Listener gap 2 min vs 5 min** (align the listener's `MIN_GAP_MS` with `kMinScanSpacing`): does a longer
     gap reduce wakeups with no coverage loss? (The scan waits 5 minutes anyway.)
  7. (Both platforms) **Scan Range all vs 1 day** on triggered scans: ADR-0044 consequence says "Scan all"
     fetches the whole mailbox every time; measures the bytes delta. Windows arm runs the same configuration
     against the dev exe with `--background-scan --account-id=` and reads bytes from the scan log.
- R-5 (outcome): a short report (scratchpad, then `docs/sprints/` as part of the Sprint 77 docs) with one table
  per arm, and backlog items in priority order written as A/B tests (hypothesis, arms, metric, decision rule),
  plus the recommended floor for F264 and whether the mapping measurably reduces scans. Fold confirmation of
  energy (Settings > Battery screenshot over MTP) is a named follow-up, not part of this card.

**Affected components / files**: none in `lib/` (research card). Scratchpad scripts (promote only if written
twice: CLAUDE.md IMP-3 promotion rule): `scratchpad/r76_1_arm.ps1` (boot, install, configure, force-idle,
collect) and `scratchpad/r76_1_collect.ps1` (dumpsys to files). Read before use:
`mobile-app/scripts/build-with-secrets.ps1` param block; `memory/project_workmanager_retry_persistence.md`
(clear `androidx.work.workdb*` between arms while force-stopped).

**Existing abstraction checked**: the diagnostic log's `trigger=` line (`background_scan_trigger.dart:35-57`)
and `DiagnosticLogger` are the measurement hooks; `scripts/pull-phone-screenshots.ps1` is MTP-only and not
needed for the emulator (adb pull works). None found for batterystats collection -- new scratch scripts.

**Existing behavior relied on**: "the worker logs `trigger=doze-alarm|periodic|notification|test` with delay" --
`background_scan_trigger.dart:40-56`; "the Doze alarm fires with `setAndAllowWhileIdle`" -- `DozeAlarmScheduler.kt:94`;
"an emulator is a valid Doze/standby test device" -- Android doze-standby page: "a hardware device or virtual device".

**Callers of any guard being changed**: N/A (no production guard changes). Tooling: the emulator must not run
while a Windows build runs (shared `build/`; memory `feedback_serialize_platform_builds`), so arms run after
B1's Android build, never concurrently with a Windows build.

**User-reachable control**: N/A (research).

**Observable behavior -- before / after**: N/A (no user-facing change).

**Dependencies / blockers**: B1's R-7/R-8 (alarm receives unclamped minutes) must be built for arms 4 and 5 to
mean anything -- so B2 arms 1-3 run against the current code, arms 4-6 against B1's dev build. The floor
recommendation feeds B1's `kMinIntervalMinutes` (one-line change if it moves). External: a mail app on the AVD
(R-3) -- the `google_apis_playstore` image has `PlayStore.enabled = no` in its config; whether Gmail is
preinstalled is unverified until R-1.

**Non-functional requirements**:
- Platform (ADR-0042): primarily Android (the backlog says so); arm 7 runs on both, and the report states for
  each recommendation whether it is shared or an Android exception. Windows has no new-mail trigger (ADR-0044),
  so arms 2, 3, 5, 6 are Android-only by nature.
- Security/privacy: no notification content is read or synthesized with real content; test accounts only.

**Acceptance criteria** (measurable, traceable):
- AC-1: R-1 pre-flight recorded with emulator version, AVD, boot result; or a cause-named failure (not "flaky").
- AC-2: each of arms 1-6 has a table with the five counts over the same 60-minute window and the same inputs;
  arm 7 has a bytes delta on both platforms.
- AC-3: the report names the measurement method per metric and states that energy was NOT measured on the
  emulator, with the two vendor quotes.
- AC-4: the report ends with (a) a recommended floor for F264 with the arm that supports it, (b) whether the
  per-account mapping reduced scans per notification versus all-accounts, (c) backlog items in priority order
  each written as an A/B test with a decision rule.
- AC-5: the `set-standby-bucket` command is either verified from `adb shell am help` output (pasted) or absent
  from the report.

**Tests to write**: none in the Flutter suite (research). The arms ARE the tests; each arm's log and dumpsys files
are kept in the scratchpad and summarized in the report. "What this does NOT catch": absolute energy, OEM
battery managers (Samsung's), and the real mail apps' notification behavior -- Fold follow-up.

**Definition of Done**: default DoD items 1-3 N/A (no code); PLUS: report file committed under
`docs/sprints/SPRINT_77_R76_1_BATTERY.md` (name indicative), backlog items added to
`docs/ALL_SPRINTS_MASTER_PLAN.md` in priority order, CODING_VELOCITY actuals recorded with the time-boxed
discovery separated from authoring (the WINWRIGHT-DISCOVERY precedent).

**Model**: Sonnet -- *why not Haiku*: the card requires weighing vendor documentation against observed counts
and designing a protocol whose arms differ by one variable; a Haiku run would produce the tables but not the
judgment on confounds (Doze maintenance windows versus the 5-minute spacing). *Why not Fable/Opus*: the
protocol is written here; execution is mechanical once the emulator boots.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes

**Executed-by** (filled at completion):

**Step-types**: DOCS x3 (protocol, report, backlog items), HOOK/script x2 (scratch collection scripts),
EMULATOR-DISCOVERY `[no-history]` (time-box, do not estimate -- the WINWRIGHT-DISCOVERY rule applies: the
constraints of posting a mail-app notification on an emulator are found only by trying).

**Est-Effort**: 55-100m effort for the authored parts (DOCS 3 x 15-20 = 45-60; scripts 2 x 5-8 = 10-16) PLUS a
time-boxed 120m for emulator boot/arm execution (7 arms x ~15 min of wall-clock waiting; much of it idle --
run arms in the background and do B1 work meanwhile). Wall-clock 180-240m.

**Risk & rollback**: Risk -- the emulator cannot receive a real mail-app notification (no Gmail on the image),
which blocks arms 2, 3, 5, 6; fallback in R-3 (debug-only allowlist package). Risk -- counts under forced Doze on
an emulator do not match a Samsung OEM battery manager; stated as a limitation, Fold follow-up named. Rollback:
N/A (no production change).

**Decision-class interrupts**:
1. **Class-3 (scope)** -- sequencing: B2 arms 1-3 before B1's floor is final, arms 4-6 after B1's alarm change
   is built. If Harold prefers B2 entirely first, B1's start slips by the B2 time-box; if entirely after, the
   floor may change after B1 ships (one-line follow-up). Recommendation: interleaved as written.
2. **Class-2 (debug allowlist)** -- adding a `BuildConfig.DEBUG`-only package to `MAIL_APP_PACKAGES` for the
   emulator arms touches the privacy-contract class; surfaced so it is approved or replaced by a Play-image
   Gmail install.

---

## Task B3 -- F258: Gmail moves to a custom label send the label NAME, not its ID (Priority 25)

**Value**: This prevents every Gmail move or delete to a user-chosen custom folder (for example "Unwanted")
from failing with 400 "Invalid label", on both platforms, and prevents the class from returning through a source
gate.

**Requirements** (numbered, detailed):
- R-1 (audit first -- done above, restated as the test's first step): write the tests against the UNMODIFIED
  adapter first and watch them fail at the five sites (the F212 precedent, CODING_VELOCITY ledger row).
- R-2 (prevention first -- one resolver for every label write): every `addLabelIds:` and `removeLabelIds:` value
  that can be a user-supplied folder name is resolved through the EXISTING `_labelIdFor` (`:1329-1338`). Concretely:
  `deleteMessage` resolves `targetLabel` before `:933`; `moveMessage` replaces `_folderToLabelId` at `:957` with
  `await _labelIdFor(targetFolder)`; `moveToFolder` and `moveToFolderBatch` resolve `labels.add` AFTER
  `moveLabels` (keep `moveLabels` static and pure -- it is `@visibleForTesting` and unit-tested; add a small async
  instance wrapper `_resolvedMoveLabels(source, target)` that maps each add/remove entry through `_labelIdFor`
  when it is not a system ID). Site 5 (`takeActionBatch` delete) is fixed by site 4.
- R-3 (null handling -- Class-2 interrupt below): when `_labelIdFor` returns null (no such label), EITHER fail the
  action with a named error ("Gmail label '<name>' does not exist") so the result row records it (F259 wants the
  missing-folder classification to see this), OR create it through the existing `_getOrCreateLabel` precedent.
  The card does not decide; both are one line at the wrapper.
- R-4 (remove side too): `moveLabels` already refuses to remove a custom-label SOURCE (`:1295-1298` "its label ID
  is not its name"). With the resolver available, a custom source CAN now be removed (a move out of "Unwanted"
  into INBOX would otherwise leave the message in both). Include the source label in `remove` when it resolves;
  keep today's behavior when it does not. State this in the commit as the Sprint 76 behavior it extends.
- R-5 (source gate): new `test/policy/gmail_label_id_gate_test.dart` -- in `gmail_api_adapter.dart`, every
  `addLabelIds:` / `removeLabelIds:` argument must be one of: a `const` system literal list (`['TRASH']`,
  `['SPAM']`, `['INBOX', 'UNREAD']`, `['UNREAD']`), the variable `labelId` assigned from `_labelIdFor` /
  `_getOrCreateLabel`, or the resolved-labels record's fields. Pattern precedent:
  `test/policy/factory_call_site_test.dart`. The gate is proven by mutation: re-introduce `[targetLabel]` at site
  1 and the gate must go red.
- R-6 (behavior test over the gate -- memory `feedback_source_gates_verify_shape`): a unit test with a fake
  `GmailApi` (or the adapter's existing test seam) proves a move to "Unwanted" sends `Label_123`, not "Unwanted",
  at all four code sites, and that the label list is fetched once per connection (cache).
- R-7 (caching correctness): `_labelIdFor` caches null for an unknown name for the connection (`:1337`). After a
  create (R-3 option b) the cache entry must be updated, or the next write re-fails. Covered by the test if option
  (b) is chosen.

**Affected components / files**:
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart:925-941` (site 1), `:957-963` (site 2),
  `:1300-1313` (moveLabels doc + the new wrapper beside it), `:1421-1426` (site 3), `:1730-1731,1742-1743,1755-1756`
  (site 4), `:1329-1338` (resolver -- unchanged unless option b), `:1794-1806` (site 5, no change needed).
- NEW `mobile-app/test/policy/gmail_label_id_gate_test.dart` (R-5).
- NEW or extended `mobile-app/test/unit/adapters/gmail_label_write_test.dart` (R-6).
- `CHANGELOG.md` fix entry.

**Existing abstraction checked**: `_labelIdFor` (`:1329`) -- reused; `_getOrCreateLabel` (`:1503`) -- the create
precedent for option (b); `_folderToLabelId` (`:1354`) -- kept for the system-name mapping that `_labelIdFor`
itself calls at `:1330`; `_systemLabelOrSelf` (`:1340`) -- kept for `moveLabels`. No new resolver is created.

**Existing behavior relied on**: "`_labelIdFor` returns the ID for a system label without a network call and
caches user labels per connection" -- `:1330-1337`; "the Gmail API provider default leaves Deleted Rule unset so
default deletes use `trash()`" -- `settings_store.dart:135-139` and `gmail_api_adapter.dart:927-929`; "the
picker stores `displayName`" -- `folder_selection_screen.dart:345`.

**Callers of any guard being changed**: `moveLabels` is called at `:1421` and `:1730` only (grep this turn); the
wrapper sits between those callers and the API call, so the pure function's two callers are unchanged. The
`targetLabel == 'TRASH'` branches at `:927` and `:1795` are untouched. Tooling: N/A.

**User-reachable control**: N/A (defect fix; the controls are the existing Deleted Rule folder and safe-sender
folder pickers in Settings > Account).

**Observable behavior -- before / after**: BEFORE: on a Gmail account with Deleted Rule folder or safe-sender
folder set to a custom label, every matching message fails with "Invalid label" in the results and nothing
moves. AFTER: the message is moved to that label; a label that does not exist is reported by name (or created,
per the interrupt).

**Dependencies / blockers**: None for the code. Validation needs a Gmail account with a custom label on Windows
(dev build) and on the Fold (closed-test build); the backlog says "Needs a Fold or Windows Gmail check with a
custom target".

**Non-functional requirements**:
- Account-scoping: adapter instance is per account; the label cache is per connection (`_labelIds`).
- Platform (ADR-0042): the five sites are shared code; the only `Platform.isWindows` forks in the adapter are on
  the sign-in path (`:189`, `:400`). **Parity claim**: the Gmail REST API behaves identically from both platforms
  (same `googleapis` package, same HTTP). No exception.
- Security: no change to scopes; label listing is already used by the read path.

**Acceptance criteria** (measurable, traceable):
- AC-1: with a fake API that lists `{name: "Unwanted", id: "Label_7"}`, `deleteMessage` with Deleted Rule
  "Unwanted" sends `addLabelIds: ['Label_7']`, `removeLabelIds: ['INBOX','UNREAD']`.
- AC-2: `moveMessage(m, "Unwanted")` sends `addLabelIds: ['Label_7']`.
- AC-3: `moveToFolder` and `moveToFolderBatch` to "Unwanted" from INBOX send `add ['Label_7']`; from SPAM also
  remove `SPAM`; from "Unwanted" to INBOX remove `Label_7` (R-4).
- AC-4: the label list is requested once for four writes on one connection.
- AC-5: an unknown target yields the chosen R-3 behavior (named error recorded per message, or a created label
  whose new ID is used and cached).
- AC-6: the gate test fails when any site passes an unresolved name (mutation evidence in the commit).
- AC-7: Manual Validation on Windows and the Fold: a safe-sender rule targeting "Unwanted" moves one message
  and Scan Results shows it succeeded.

**Tests to write**:
- T-1 (AC-1..AC-5) -- TEST-UNIT in `test/unit/adapters/gmail_label_write_test.dart`: the four sites against a
  fake API client capturing `ModifyMessageRequest` / `BatchModifyMessagesRequest`; written FIRST against
  unmodified code. "Does NOT catch": Gmail's real 400 on a bad ID, label visibility settings, and the
  per-chunk fallback path's network errors.
- T-2 (AC-6) -- TEST-UNIT (policy) in `test/policy/gmail_label_id_gate_test.dart`: source gate per R-5, with
  the mutation named in its header. "Does NOT catch": a new write site that builds its list through a variable
  named like the resolved one but assigned from a name (the behavior test T-1 is the pair).
- T-3 (R-4) -- extend the existing `moveLabels` unit test (grep `moveLabels(` in `test/`): custom source stays
  un-removed in the pure function; the wrapper removes it when resolved.

**Definition of Done**: default DoD PLUS: mutation re-run after the fix at each of the four sites (Sprint 73
IMP-3 -- the resolver is correct; the wiring is where this defect lives); the Sprint 73 "grep the whole call
chain for the pattern" record in the commit: `addLabelIds`/`removeLabelIds` occurrences in `lib/` listed, each
marked resolved / system-literal; F259's overlap noted (null from `_labelIdFor` on the READ path is F259's, not
fixed here).

**Model**: Haiku -- cheapest tier; *why it is sufficient*: four mechanical call-site edits through an existing
resolver, one pure wrapper, one gate with a named precedent, and the tests specified by intent. Escalate to
Sonnet only if interrupt 1 chooses "create the label" (cache invalidation plus the `_getOrCreateLabel`
visibility defaults need judgment). The delegation checklist is mandatory (Sprint 75 retro IMP-6).
**Delegation checklist included in the sub-agent prompt** (when delegated): yes

**Executed-by** (filled at completion):

**Step-types**: SVC-EDIT x4 (sites 1-4), SVC-EDIT (wrapper + remove-side), TEST-UNIT x3 (behavior, gate,
moveLabels extension), DOCS (CHANGELOG + commit grep record).

**Est-Effort**: 42-130m effort / 42-130m wall-clock. Build-up: SVC-EDIT 5 x 5-18 = 25-90 (low end expected:
each site is a one-line substitution); TEST-UNIT 3 x 4-10 = 12-30; DOCS inside the commit, 5-10 (not a separate
DOCS item) (sums: 42 low, 130 high). Manual Validation on two platforms not included.

**Risk & rollback**: Risk -- a resolved removal of a custom SOURCE label (R-4) changes a Sprint 76 decision
("a custom-label source is not removed"); it is surfaced below. Risk -- the label list call adds one API round
trip per connection on the write path (already paid on the read path; cache shared). Rollback: revert the
commit; no data change.

**Decision-class interrupts**:
1. **Class-2** -- unknown label on a WRITE: (a) fail the action with a named error per message (the result row
   shows "Gmail label 'X' does not exist"; aligns with F259's missing-folder classification), or (b) create it
   via `_getOrCreateLabel` (the flag path's precedent; a typo in Settings then creates a stray label).
   Recommendation to present: (a).
2. **Class-2** -- R-4 extends the Sprint 76 `moveLabels` decision ("a custom-label source is not removed") now
   that resolution is available. Keep the Sprint 76 behavior or extend it? Recommendation: extend (a move that
   leaves the message in both places is not a move).

---

## ADR / ARCHITECTURE impact (all three cards)

- **ADR-0039** (per-account background scanning): amendment -- "Sprint 77 (F264): interval model". The
  per-account frequency is any number of minutes in [5, 5940]; Windows expresses it as one `-Once`
  repetition trigger (Microsoft limit 1 minute .. 31 days, cited); Android arms the F235 alarm at the user's
  interval and keeps the WorkManager periodic safety net clamped at its documented 15-minute minimum; the
  5-14 minute band is alarm-only and bounded by Android's own 9-minute idle limit. The 5-minute floor is tied to
  `kMinScanSpacing` by a test. Supersedes the "fixed frequencies" wording in the Change-Site Inventory row 4.
- **ADR-0044** (notification-triggered scan): amendment -- the switch is per account; the listener still reads
  only the package name and time (privacy contract unchanged); `MailNotificationPolicy` maps the posting app to
  the provider set; the Dart worker selects accounts by provider + per-account switch + background switch;
  Decision 1's "every account whose background scanning is on" becomes "every SELECTED account ..."; the Windows
  presentation decision (interrupt B1-2) is recorded in "Platform scope". Storage of the per-account flag
  (interrupt B1-1) is recorded as a decision with the migration rule.
- **ADR-0042**: no amendment; the new-mail Windows presentation is recorded in ADR-0044's platform-scope section
  (and in ADR-0042's "Deliberate non-parity, recorded" list if option (a) hidden is chosen).
- **ARCHITECTURE.md:555-601**: the three Android background paragraphs get the interval model, the alarm-only
  band, and the per-account mapping; the F253 paragraph's "ONE all-accounts one-off worker" becomes "one
  one-off worker that scans the mapped accounts".
- **F258**: no ADR; CHANGELOG fix and the F259 cross-reference. `docs/TROUBLESHOOTING.md` gains a line:
  "Invalid label" on Gmail = custom folder name sent as ID (fixed Sprint 77).

---

## Decision questions for Harold (plain numbered list; answer as "<number>. <letter>", for example "1. a")

1. F264 per-account new-mail flag storage (Class-1):
   a. `account_settings` key per account; the native flag becomes "any account on"
   b. per-account native prefs; the listener does the mapping and names the accounts in the payload
   (recommended: a)
2. Migration when the app-wide new-mail switch is ON at upgrade:
   a. copy ON to every account (ADR-0039 Locked Decision 1 precedent)
   b. start every account OFF
   (recommended: a)
3. Windows presentation of the per-account new-mail switch (Class-1, ADR-0042 point 5 vs ADR-0044):
   a. hidden on Windows; extend the ADR-0044 declared exception
   b. shown disabled with a one-line note
   c. something else (name it)
   (recommended: a)
4. `BackgroundScanScheduler.schedule` and the Windows services take `int intervalMinutes` instead of
   `ScanFrequency` (Class-2):
   a. approve
   b. keep the enum and add values
   (recommended: a; 5..5940 minutes is not an enum)
5. The F217 helper sentence "up to about an hour" (Class-2):
   a. replace it with the F264 sentence "expect up to about 45 minutes"
   b. keep both
   (recommended: a)
6. Windows `-RandomDelay` for long intervals (Class-2):
   a. cap at `min(interval - 1, 59)` minutes
   b. keep "interval minus one" at every interval (up to four days of jitter at 99 hours)
   (recommended: a)
7. R76-1 sequencing (Class-3):
   a. interleaved: arms 1-3 now, arms 4-6 after B1's alarm change is built
   b. all of R76-1 before B1
   c. all of R76-1 after B1
   (recommended: a)
8. R76-1 emulator notification source (Class-2, privacy-contract class):
   a. a debug-build-only extra package in the allowlist, never in release
   b. only a real mail app on the AVD (arms 2, 3, 5, 6 blocked if none installs)
   (recommended: a)
9. F258 unknown label on a write (Class-2):
   a. fail the action with a named error per message
   b. create the label through `_getOrCreateLabel`
   (recommended: a)
10. F258 remove a resolved custom SOURCE label on a move (extends the Sprint 76 `moveLabels` decision):
    a. extend: remove the source label when it resolves
    b. keep the Sprint 76 behavior (source custom label never removed)
    (recommended: a)
11. Model assignments: B1 Sonnet (Haiku batch for T-1/T-4/T-9/T-10), B2 Sonnet, B3 Haiku:
    a. approve
    b. change (name which)
    (recommended: a)



# Block A -- F192, SEC-15, SEC-8b


# Sprint 77 draft cards -- Plan A: Custom IMAP (F192 + SEC-15 + SEC-8b)

Drafted 2026-10-06 (planning only; no repo file edited, nothing committed). Every file:line below was read in this
session. Claims about vendors carry a URL and a VERIFIED / UNVERIFIED mark. Nothing here is decided; the numbered
questions at the end are for the Product Owner / Chief Architect.

BLUF:
1. F192 is a real "build" card (audit confirms nothing collects a host), but the BACKLOG PREMISE of SEC-8b is stale:
   enough_mail 2.1.7 DOES expose `onBadCertificate` and accepts a pre-built socket. Pinning is feasible without a
   fork, with three hard constraints (leaf-only certificate, greeting race, existing pinner never enforced on the
   happy path).
2. SEC-15 as written ("reject internal/private IP ranges") contradicts F192's own value statement ("self-hosted and
   workplace mail") and blocks every localhost bridge (Proton, DavMail, email-oauth2-proxy). The threat it was filed
   against (SSRF) is a server-side threat; this is a client app where the user types the host. Decision needed.
3. Recommend merging SEC-15 into the F192 card (one validator in one form) and keeping SEC-8b separate, gated on a
   15-minute live spike that is a hard precondition of its estimate.

---

## 0. Audit-first findings (what already exists, with file:line)

| Claim in the backlog | What the code actually says |
|---|---|
| "`GenericIMAPAdapter.custom()` defaults `imapHost: ''`" | TRUE. `generic_imap_adapter.dart:143-155`; the registry calls it with no args at `platform_registry.dart:30`. `_imapHost/_imapPort/_isSecure` are `final` (`:36-38`), set only by the constructor (`:82-92`). |
| "no `lib/ui` file collects `imapHost`" | TRUE. Grep of `lib/` for `imapHost` hits only the adapter and the registry. `AccountSetupScreen` has exactly two inputs: email (`account_setup_screen.dart:689-697`) and password (`:701-709`). |
| Custom IMAP tile is "Coming Soon" | FALSE -- it is NOT RENDERED AT ALL. `PlatformInfo(id: 'imap', phase: 4, ...)` at `platform_registry.dart:171-179`; `platform_selection_screen.dart:28` keeps `p.phase <= 2 && p.phase != 0`, so phase 4 is dropped before the list is built. The screen has only "Available Now" (phase 1, `:151-156`) and "Coming Soon" (phase 2, `:160-165`). |
| Gate that pins this | `test/unit/platform_registry_phase_test.dart:66-74` asserts `byId('imap').phase > 1` with the reason "must not become selectable until F192 ships a form". F192 must INVERT this test (to `== 1`) in the same commit as the phase flip, with the inverse reason. |
| Test Connection to mirror | `_testConnection()` at `account_setup_screen.dart:180-248`: builds `Credentials(email, password)` (`:204`), `PlatformRegistry.getPlatform(_effectivePlatformId)` (`:198`), `loadCredentials` then `testConnection()` (`:205-208`), humanizes errors through `ErrorMessages.humanize` (`:235`), disconnects (`:227`). Button at `:739-755`. |
| How AOL/Yahoo app-password accounts are stored | `SecureCredentialsStore.saveCredentials(accountId, Credentials, platformId:)` at `secure_credentials_store.dart:80-128`: email, platformId, password, optional accessToken written as SEPARATE keys `credentials_<accountId>_<field>`; `getCredentials` (`:133-207`) rebuilds `Credentials` and puts `accountId` + `platformId` into `additionalParams` (`:198-202`). `deleteCredentials` (`:376-418`) deletes each key by name -- any new key MUST be added there too. `accountId = email` (`account_setup_screen.dart:279`). |
| How a saved account reconnects | Every production path does `PlatformRegistry.getPlatform(platformId)` then `getCredentials(accountId)` then `platform.loadCredentials(creds)`: `email_scanner.dart:271-294` (manual + background, both platforms via `BackgroundScanCore`), `:1620-1631`; `folder_selection_screen.dart:235-246`; `results_display_screen.dart:4139-4152`. Only `account_setup_screen.dart:204` constructs `Credentials` by hand. `background_scan_core.resolvePlatformId` (`background_scan_core.dart:148-161`) resolves platformId from the same store. |
| `Credentials` shape | `email_provider.dart:4-16`: `email`, `password?`, `accessToken?`, `additionalParams: Map<String,String>?`. |
| `accounts` DB table | `database_helper.dart:150-158`: `account_id, platform_id, email, display_name, date_added, last_scanned, last_history_id`. No host column. |
| TLS off path | `GenericIMAPAdapter.loadCredentials` calls `connectToServer(host, port, isSecure: _isSecure)` (`generic_imap_adapter.dart:195-199`); enough_mail does `Socket.connect` (plaintext) when `isSecure == false` (`client_base.dart:110-116`) and the adapter NEVER calls `ImapClient.startTls()` (exists at `imap_client.dart:434`; zero callers in `lib/`). So today "TLS off" would mean a cleartext IMAP LOGIN. |
| Host validation helper | NONE. Grep of `lib/` for `isLoopback`, `isLinkLocal`, `InternetAddress.tryParse`, `192.168`, `127.0.0.1` returns nothing. The only input validation on the screen is SEC-20 email format (`account_setup_screen.dart:109-114`), deliberately generic messages. |
| Pinner | `lib/core/security/certificate_pinner.dart` (SEC-8, Sprint 33). Settings toggle at `settings_screen.dart:931-947` ("Pin Google OAuth certificates"); persisted preference applied at `main.dart:288-295`; three `PinnedHttpClient()` users in `gmail_windows_oauth_handler.dart:313/391/420`. Tests: `test/unit/security/certificate_pinner_test.dart` (registry, kill switch, setPinsForTesting, exception toString -- no test feeds a real certificate through `matches()`). |
| Help copy that will need a line | `assets/content/help/account_setup.md:1` and `walkthrough.md:19` already say "other IMAP providers, enter your email and an app password" -- they describe a capability that cannot be reached today. `help_platform_claims_test.dart` pins only background-scanning text; untouched by F192. |
| GitHub issues | None exist for F192, SEC-15 or SEC-8b (`gh issue list --search` for each returned only Sprint 33 / F68 umbrella issues). Phase 3.3.1 cards must be created. |
| Sprint 77 plan | `docs/sprints/SPRINT_77_PLAN.md` is a STUB (carry-ins MV76-1, R76-1..4 and the 0.17.6 version-bump note). |

Also surfaced during the audit (not asked, but material):

- **The adapter comment at `generic_imap_adapter.dart:178-193` and the pinner dartdoc at `certificate_pinner.dart:19-24` are both STALE**: they say enough_mail exposes no bad-cert callback. `ImapClient({... bool Function(X509Certificate)? onBadCertificate})` is at `imap_client.dart:239-251`, forwarded to `ClientBase.onBadCertificate` (`client_base.dart:35`, `:77`) and used by `SecureSocket.connect` at `client_base.dart:111-115`. Whichever card touches these files should correct the comments (IMP-2 Sprint 70: a confidently wrong comment is worse than none).
- **The existing pinner's pin VALUES and its `fingerprint()` disagree.** `_defaultPins` (`certificate_pinner.dart:75-102`) are documented as SPKI SHA-256 of the GTS intermediates; `fingerprint()` (`:152-156`) hashes the FULL certificate DER, and `matches()` (`:160-165`) compares the two. If the values are what the pinner's own documentation says they are (SPKI of intermediates), a full-DER hash of a leaf can never equal them and `matches()` cannot return true for a pinned host -- the confidence of that conclusion is bounded by the dartdoc, not by a live check. The code-verified point stands on its own: `matches()` has ZERO production callers (grep of `lib/`), and `PinnedHttpClient` re-implements the comparison inline at `:189-190` only inside the distrust callback. This has had no observable effect because (a) `badCertificateCallback` fires only when platform trust already failed (`:176-191`) and (b) `send()` checks only the URL scheme (`:197-215`, admitted in its own comment). Net: OAuth pinning is a kill switch plus a scheme check; no pin has ever been enforced on the happy path. This is a finding for Harold, not a card I am adding on my own (Class-2: it changes the understanding of a prior security decision).

---

## 1. Tooling-capability pre-flight -- SEC-8b (docs/SPRINT_PLANNING.md "Tooling-Capability Pre-Flight")

**Tool**: `enough_mail` **2.1.7** (`mobile-app/pubspec.lock:228-235`), source read at
`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\enough_mail-2.1.7\`.

Question: does `ImapClient.connectToServer` (or any API) accept a `SecurityContext`, `onBadCertificate`, or an
already-connected socket?

| Primitive | Answer | Evidence |
|---|---|---|
| `SecurityContext` | NO. `connectToServer(host, port, {isSecure, timeout})` has no context parameter and calls `SecureSocket.connect(host, port, onBadCertificate: onBadCertificate)` with no `context:`. | `lib/src/private/util/client_base.dart:99-122` |
| `onBadCertificate` | YES. Constructor parameter on `ImapClient`, stored on `ClientBase`, passed to `SecureSocket.connect`. **Backlog text "exposes no SecurityContext/bad-cert callback" is half wrong.** | `lib/src/imap/imap_client.dart:239-251`; `client_base.dart:28-36`, `:77`, `:114` |
| Already-connected socket | YES. `void connect(Socket socket, {ConnectionInfo? connectionInformation})` is PUBLIC on `ClientBase` (inherited by `ImapClient`), documented "mainly useful for testing". The app can open `SecureSocket.connect(host, port, context: ..., onBadCertificate: ...)` itself, inspect `socket.peerCertificate`, then hand the socket over with `ConnectionInfo(host, port, isSecure: true)`. | `client_base.dart:124-155`; dart:io `SecureSocket.connect` signature has `SecurityContext? context` and `onBadCertificate` (https://api.dart.dev/dart-io/SecureSocket/connect.html, VERIFIED); `X509Certificate? get peerCertificate` (https://api.dart.dev/dart-io/SecureSocket/peerCertificate.html, VERIFIED) |

Three constraints that bound any design (all from source, not docs):

1. **`onBadCertificate` fires only when platform trust FAILS.** A CA-valid certificate from the wrong key never reaches
   it, which is exactly the gap the OAuth pinner already admits (`certificate_pinner.dart:197-204`). Happy-path
   pinning therefore needs either (a) the pre-built socket plus `peerCertificate`, or (b) a `SecurityContext` with
   NO trusted roots (`SecurityContext(withTrustedRoots: false)`), which forces EVERY certificate through the callback
   where the app does its own pin match. Option (b) is the simpler mechanism but it also means the app, not the OS,
   is the sole validator for that host.
2. **Greeting race with the pre-built socket.** `connect()` creates a new greeting completer but returns nothing to
   await (`client_base.dart:132-136`). `ImapClient.onConnectionEstablished` (`imap_client.dart:302-328`) completes
   with error `'reconnect'` EVERY task already in `_queue` when the greeting arrives (`:316-327`). So a `login()`
   issued before the greeting is guaranteed to fail. No-fork workaround: `class PinnedImapClient extends ImapClient`
   overriding `onConnectionEstablished` to complete an app-owned `Future` after `super`, and the adapter awaits it
   before `login`. This is the single primitive that MUST be proven live (~15 min spike against imap.aol.com) before
   the SEC-8b estimate is trusted. Option (b) above avoids the race entirely because `connectToServer` is still used.
3. **Leaf only.** `peerCertificate` returns ONE certificate (the server's); dart:io exposes no chain. The GTS
   INTERMEDIATE pins the OAuth pinner carries cannot be checked on an IMAP socket. IMAP pins would be LEAF pins.
   Google/Yahoo/AOL leaf certificates rotate on the order of weeks to months (UNVERIFIED for the exact cadence; it
   is operational knowledge, not a vendor statement), so pinning known providers' IMAP leaves is a recurring-breakage
   commitment with only the kill switch as the release valve.

What the existing pinner offers to extend (prevention-first): `CertificatePinner.pins` / `matches(host, cert)` /
`setEnabled` / `setPinsForTesting` are host-keyed and transport-agnostic (`certificate_pinner.dart:72-166`). An IMAP
path would reuse the registry and the kill switch and add a socket-level connector beside `PinnedHttpClient`. Before
extending, the DER-vs-SPKI defect above must be settled, otherwise the IMAP path inherits a `matches()` that cannot
match.

**Pre-flight verdict**: FEASIBLE without a fork or a library swap. Not estimable until the greeting-race spike runs.

---

## 2. Provider coverage with F192 + SEC-15 together (Product Owner addition)

**How many providers/domains could connect** (IMAP over TLS with a password or app password)?

A number is not derivable and I will not invent one. The honest answer is qualitative: IMAP over implicit TLS on
port 993 with password or app-password login is the default of every mainstream mail server (Dovecot, Courier,
Cyrus, Exchange on-premises with IMAP enabled, cPanel/Plesk/DirectAdmin hosting mail, Zimbra, Kerio, MDaemon,
hMailServer, Mailcow, iRedMail) and of every ISP and university mailbox that still runs IMAP. That is the "any IMAP
provider" claim from the backlog, and it covers the overwhelming majority of custom domains hosted on shared web
hosting. The exceptions are a short list of large consumer services that have moved to OAuth-only, refuse IMAP
by design, or gate IMAP behind a paid plan or a local bridge.

**Verified SUPPORTED examples** (vendor page gives host, 993, SSL, and a password/app password; VERIFIED unless marked):

- AOL Mail: shipping today via `GenericIMAPAdapter.aol()` (`generic_imap_adapter.dart:95-103`, `imap.aol.com:993`); the AOL app-password page body did not load in this session, so the "app password required" wording is UNVERIFIED from the vendor page but is the app's own shipped setup flow.
- Yahoo Mail: `imap.mail.yahoo.com`, 993, SSL, "Generate App Password" -- https://help.yahoo.com/kb/SLN4075.html
- iCloud Mail: `imap.mail.me.com`, 993, SSL required, app-specific password -- https://support.apple.com/en-us/102525
- Gmail with an App Password: "App passwords can only be used with accounts that have 2-Step Verification turned on" -- https://support.google.com/accounts/answer/185833 (already shipping as `gmail-imap`).
- Fastmail: `imap.fastmail.com`, 993, SSL/TLS (not STARTTLS), "You cannot use your regular Fastmail password" -- https://www.fastmail.help/hc/en-us/articles/1500000278342-Server-names-and-ports
- Xfinity/Comcast: `imap.comcast.net`, 993, SSL; "you'll have to allow access to third-party programs in the Xfinity Email website" (a setting, not an app password) -- https://www.xfinity.com/support/articles/email-client-programs-with-xfinity-email
- AT&T Mail (att.net and legacy sbcglobal/bellsouth, which AT&T hosts): "you'll only be able to access AT&T Mail with a 16-character secure mail key" -- https://www.att.com/support/article/email-support/KM1240308 (host/port not on that page; UNVERIFIED host)
- Yandex Mail: `imap.yandex.com`, 993, SSL, app password required -- https://yandex.com/support/mail/mail-clients/others.html
- Zoho Mail (PAID plans): `imap.zoho.com`, 993, SSL; application-specific password with 2FA -- https://www.zoho.com/mail/help/imap-access.html
- Mailfence (PAID plans): `imap.mailfence.com`, 993 (SSL) -- https://imap.mailfence.com/en/faq.jsp
- GMX: "activate POP3/IMAP in your account settings before setting up your application" -- https://support.gmx.com/pop-imap/imap/index.html (server-data page returned 404; host/port UNVERIFIED)
- Mail.ru: `imap.mail.ru`, 993, SSL, "password for external applications" -- secondary sources only (help.mail.ru page returned 404); UNVERIFIED
- Posteo, mailbox.org: vendor pages returned 404 in this session; UNVERIFIED, listed as likely-supported European providers.
- Google Workspace is NOT listed here: the vendor page fetched (https://support.google.com/accounts/answer/185833) names "You're logged into a work, school, or another organization account" as a case where app passwords cannot be created; whether an admin can enable them per tenant was NOT verified in this session. See NOT-supported rows 3-4.

Countable summary for the PO: 10 named providers verified SUPPORTED from vendor pages in this session (Yahoo, iCloud, Gmail-with-app-password, Fastmail, Xfinity, AT&T, Yandex, Zoho paid, Mailfence paid, GMX activation step) plus AOL by the shipping adapter, plus the uncountable hosting/ISP/self-hosted category. The NOT list below has 13 named providers or tools (rows 1-13) and 7 categories (rows 14-20).

**Up to 20 notable providers/domains that would NOT connect, with the reason:**

| # | Provider / domain | Why it fails | Source |
|---|---|---|---|
| 1 | Outlook.com / Hotmail / Live / MSN (personal) | OAuth-only: "September 16th, 2024 - Basic Authentication no longer available to access any Outlook account". No password or app password works for IMAP. | https://support.microsoft.com/en-us/office/modern-authentication-methods-now-needed-to-continue-syncing-outlook-email-in-non-microsoft-email-apps-c5d65390-9676-4763-b41f-d7986499a90d VERIFIED |
| 2 | Microsoft 365 / Exchange Online (work and school, any custom domain on M365) | "Basic authentication is now disabled in all tenants" for IMAP; "The deprecation of basic authentication also prevents the use of app passwords". OAuth-only. | https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/deprecation-of-basic-authentication-exchange-online VERIFIED |
| 3 | Google Workspace accounts after the LSA turndown where the admin has not enabled app passwords | "CalDAV, CardDAV, IMAP, SMTP, and POP will no longer work with legacy passwords (basic authentication)" after March 14, 2025. The fetched page mentions app passwords only for scanners and devices; that app passwords are an admin-enabled exception for IMAP clients is an INFERENCE, UNVERIFIED. | https://knowledge.workspace.google.com/admin/sync/transition-from-less-secure-apps-to-oauth VERIFIED (date only) |
| 4 | Google accounts that cannot create app passwords: security-key-only 2SV, Advanced Protection, "work, school, or another organization account" restricted by admin | Vendor lists these as cases where app passwords are unavailable; OAuth is the only path. | https://support.google.com/accounts/answer/185833 VERIFIED |
| 5 | Google accounts WITHOUT 2-Step Verification | "App passwords can only be used with accounts that have 2-Step Verification turned on" and plain-password IMAP sign-in is gone with Less Secure Apps. | same as 4, VERIFIED |
| 6 | Proton Mail (Free) | No IMAP at all: "Proton Mail Bridge is currently available only with a paid Proton Mail plan." | https://proton.me/support/imap-smtp-and-pop3-setup VERIFIED |
| 7 | Proton Mail (paid, via Bridge) | Needs the desktop Bridge listening on the loopback address (127.0.0.1, port 1143, STARTTLS, Bridge-generated certificate -- secondary sources; the exact values are UNVERIFIED on a Proton page in this session). SEC-15 loopback rejection BLOCKS it; a TLS-only form with no STARTTLS mode blocks it; strict certificate validation blocks its local certificate. Bridge is desktop-only, so on Android it is unreachable regardless. | Proton paid-only VERIFIED (link in 6); port/STARTTLS from https://smtpedia.com/proton-mail-email-settings/ UNVERIFIED |
| 8 | Tuta (Tutanota) | "does not support IMAP and Pop ... due to the built-in end-to-end encryption". | https://tuta.com/blog/offline-support VERIFIED |
| 9 | HEY (hey.com) | "HEY doesn't support IMAP or POP." and "off-the-shelf 3rd party email apps won't work with HEY." | https://www.hey.com/faqs/ VERIFIED |
| 10 | Zoho Mail (Free plan) | "For newly signed-up users (Free plan), the IMAP Access feature will not be available." | https://www.zoho.com/mail/help/imap-access.html VERIFIED |
| 11 | Mailfence (Free plan) | "Paid accounts have POPS, IMAPS and SMTPS access." Free is webmail only. | https://imap.mailfence.com/en/faq.jsp VERIFIED |
| 12 | Any Exchange / Office 365 mailbox reached through DavMail | DavMail is a LOCAL gateway; the client connects to a "Local IMAP port" (sample 143) on the user's own machine. SEC-15 loopback rejection blocks it; default port 143 is plaintext on the loopback, so a TLS-only form blocks it too. | https://davmail.sourceforge.net/gettingstarted.html VERIFIED (local port); exact "localhost" wording is my inference from "Local IMAP server port" |
| 13 | Outlook.com / M365 / Gmail reached through email-oauth2-proxy (the common workaround for #1-#3) | Proxy "sets this parameter to 127.0.0.1 for all servers" and "The local connection in your email client should be configured as unencrypted". SEC-15 blocks the address; a TLS-only form blocks the unencrypted local hop. | https://github.com/simonrob/email-oauth2-proxy VERIFIED |
| 14 | Self-hosted / home-lab / small-office IMAP on a LAN address (Synology MailPlus, Mailcow, iRedMail, Dovecot on 192.168.x / 10.x) | Reachable by IMAP over TLS with a password, BUT SEC-15 as written rejects 10/8, 172.16/12, 192.168/16. This is the "self-hosted mail" audience the F192 value statement names. | Policy conflict, no vendor page needed |
| 15 | Corporate Exchange on-premises | IMAP is frequently disabled by policy, or allowed only on the LAN/VPN (then #14 applies). | Category statement; UNVERIFIED per site |
| 16 | Skiff Mail | Service shut down after acquisition (2024). | UNVERIFIED in this session |
| 17 | Hushmail (Free) / StartMail / other privacy providers that gate IMAP behind paid tiers | Pattern matches Zoho/Mailfence; not individually verified. | UNVERIFIED |
| 18 | Any provider that only offers OAuth2 (XOAUTH2) for IMAP | The app's IMAP adapter does LOGIN with a password only (`generic_imap_adapter.dart:203-206`); XOAUTH2 is used only by the Gmail API path. | Code fact |
| 19 | Any provider that requires STARTTLS on port 143 rather than implicit TLS on 993 | The adapter never calls `startTls()`; `isSecure: false` means plaintext. Fails unless F192 adds a STARTTLS mode. | Code fact (`client_base.dart:110-116`, `imap_client.dart:434` unused) |
| 20 | Any server with a self-signed or private-CA certificate (common for self-hosted #14) | Platform trust fails, `HandshakeException` is mapped to "TLS certificate validation failed" (`generic_imap_adapter.dart:233-235`). Only a trust-on-first-use path (SEC-8b option) would admit it. | Code fact |

**Where SEC-15's private/loopback rejection CONFLICTS with real providers** (rows 7, 12, 13, 14): Proton Bridge,
DavMail, email-oauth2-proxy and every LAN-hosted server. These are not edge cases; rows 12-13 are the standard
way IMAP users reach Outlook.com and Microsoft 365 after 2024, and row 14 is the audience F192 is sold to.
Presented as Decision Q2 below, not decided here.

Threat-model note for the PO (objective, not a recommendation): S19 (`docs/sprints/SPRINT_31_SECURITY_AUDIT.md:256-264`)
names SSRF as the impact. SSRF is a server-side threat (an attacker makes a server reach internal resources). In
this app the host is typed by the device's own user and reaches only that device's own network; there is no
untrusted input path that supplies a host (rules YAML carries no hosts, deep links carry none). A literal-IP check
is also bypassable by any hostname that resolves to a private address, so it is a speed bump, not a control, unless
the app resolves first and then rejects (which also blocks the legitimate cases above).

---

## 3. Cards

Three cards follow. The recommendation (Section 5) is to MERGE SEC-15 into F192 as its R-6/AC-6/T-6 because it is
one validator inside one form; it is drafted separately so the PO can accept or drop it on its own.

Model-assignment summary (SPRINT_PLANNING.md "Single-session sprints"): if Sprint 77 runs as one interactive
session, record deviation (a) ONCE here; the assignments below reflect task shape.

### Task A -- F192: Custom IMAP Server support, host-entry UI (Priority 32)

**Value**: This enables connecting any IMAP server that takes a password or app password (ISP, hosting, workplace,
self-hosted mail), which the listing copy already claims and the help text already describes.

**Requirements** (numbered, detailed):
- R-1 (audit first, build second): the audit in Section 0 is the baseline; the task builds the gap only -- the form,
  the persistence of server settings, the adapter's host injection, and the phase flip. Nothing in the registry
  factory table or the five reconnect call sites changes.
- R-2: When the user selects "Custom IMAP Server", `AccountSetupScreen` shows, above the existing email/password
  fields, a server section with: Server host (text, required), Port (numeric, default 993), Encryption (see Q3:
  default "SSL/TLS"), Username (text, prefilled from the email address once typed; editable, because IMAP logins
  often differ from the address). The existing "App Password" label reads "Password" for this provider.
- R-3: "Test Connection" for this provider builds `Credentials(email, password, additionalParams: {imapHost,
  imapPort, imapSecure, imapUsername})` and otherwise follows `_testConnection()` at
  `account_setup_screen.dart:180-248` unchanged (same humanized errors, same disconnect).
- R-4: Save persists host/port/encryption/username beside the credentials so a saved account reconnects without
  re-entry. The persistence home is Decision Q1 (Class-2); the card is written for Option Q1-a (secure-store side
  keys) because it is the only option that needs NO call-site edits -- see "Callers" below.
- R-5: `GenericIMAPAdapter.loadCredentials` for `platformId == 'imap'` takes host/port/secure/username from
  `credentials.additionalParams` (keys named in R-3) and fails with a `ConnectionException('Server not configured')`
  when the host is absent -- never silently connects to `''`.
- R-6 (SEC-15 if merged): host validation per Task B.
- R-7: `PlatformInfo(id: 'imap')` moves to `phase: 1`; `platform_registry_phase_test.dart:66-74` is inverted in the
  same commit (`== 1`, reason "F192 shipped the form").
- R-8: `SecureCredentialsStore.deleteCredentials` deletes the four new keys (enumerate-all-outputs rule).
- R-9: Both stale comments (`generic_imap_adapter.dart:178-193`, `certificate_pinner.dart:19-24`) are corrected to
  say enough_mail 2.1.7 exposes `onBadCertificate` and accepts a pre-built socket, pinning deferred to SEC-8b.
- R-10: Help content `assets/content/help/account_setup.md` gains one sentence naming the Custom IMAP form fields;
  `docs/APP_PASSWORD_SETUP.md` is checked for a "custom server" section (`provider_setup_steps_test.dart` compares
  URLs and retired labels only, so prose is free).

**Affected components / files**:
- `mobile-app/lib/ui/screens/account_setup_screen.dart:49-56` -- new controllers (host, port, username) and an
  encryption selection; `:180-248` -- `_testConnection` passes `additionalParams` for `imap`; `:257-312` --
  `_handleConnect` saves the server settings; `:688-709` -- server section rendered above email when
  `widget.platformId == 'imap'`; `:704` label switch.
- `mobile-app/lib/adapters/storage/secure_credentials_store.dart:80-128` -- optional `serverSettings` map written
  as `credentials_<accountId>_imapHost|imapPort|imapSecure|imapUsername` (mirrors the `_platformId` key at `:94-103`);
  `:188-202` -- read back into `additionalParams`; `:376-418` -- delete the four keys.
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:36-38` -- `_imapHost/_imapPort/_isSecure`
  become settable once from `loadCredentials` for the custom platform (or a parallel `_effectiveHost` trio; implementer's
  call, documented); `:164-244` -- resolve from `additionalParams`, login with `imapUsername ?? email`; `:1461-1507`
  `_checkAndReconnect` and `:1400-1424` `testConnection` must use the same resolved values.
- `mobile-app/lib/adapters/email_providers/platform_registry.dart:171-179` -- `phase: 4` -> `1`; `setupInstructions`
  text reviewed.
- `mobile-app/test/unit/platform_registry_phase_test.dart:66-74` -- inverted.
- `mobile-app/assets/content/help/account_setup.md:1`, `docs/ARCHITECTURE.md:286` (GenericIMAPAdapter row: say how the
  custom host is supplied), `CHANGELOG.md`.

**Existing abstraction checked**: `SecureCredentialsStore` side-key pattern (`_platformId` at `:94-103`/`:188-202`)
for per-account non-token fields -- REUSED. `SettingsStore` per-account settings (ADR-0013, `getEffectiveScanMode`
at `settings_store.dart:892`) -- CONSIDERED and not used: it would force every reconnect call site to make a second
lookup, and server identity belongs with the credentials it authenticates (deleted together). `PlatformInfo.imapConfig`
(`platform_registry.dart:246-264`) -- it is a static per-PROVIDER struct, not per-account; not suitable.

**Existing behavior relied on**:
- "Every production reconnect path obtains `Credentials` from `SecureCredentialsStore.getCredentials`" -- verified at
  `email_scanner.dart:282-294`, `:1626-1631`, `folder_selection_screen.dart:241-246`, `results_display_screen.dart:4147-4152`.
  Only `account_setup_screen.dart:204` builds `Credentials` directly.
- "`getCredentials` already returns `additionalParams` with `accountId` and `platformId`" -- `secure_credentials_store.dart:198-202`.
- "`PlatformRegistry.getPlatform('imap')` returns a fresh `custom()` with empty host on every call" -- `platform_registry.dart:30`, `:59-62`.
- "`AuthRateLimiter` keys on `'$platformId-${credentials.email}'`" -- `generic_imap_adapter.dart:167-169`; unchanged, so
  two custom accounts with the same email share a rate-limit bucket (acceptable; note it).

**Callers of any guard being changed**: the phase filter `platform_selection_screen.dart:28` is not changed; the
DATA it filters is (phase 4 -> 1). Effect: the tile appears under "Available Now". The adapter guard "host must be
non-empty" is NEW. Callers of `GenericIMAPAdapter.loadCredentials` and the effect of R-5 on each:
- `account_setup_screen.dart:205` (Test Connection) -- supplies the params; gets the new error if host blank (also
  caught earlier by form validation).
- `email_scanner.dart:294` (manual scan, Windows + Android) and `:1631` -- read params from the store; a legacy
  `imap` account with no stored host (none can exist today, the tile was unreachable) would error with "Server not
  configured" instead of a socket error on `''`.
- `email_scanner.dart:294` via `BackgroundScanCore` (Windows Task Scheduler worker, Android WorkManager worker) --
  same as above; the error is counted as a failed account scan, not a skip (`background_scan_core.dart:140-146` semantics
  unchanged).
- `folder_selection_screen.dart:246`, `results_display_screen.dart:4152` -- same.
- Tooling that launches or kills the same executable: N/A (no process behavior changes).

**User-reachable control**: Accounts > Add Account > "Custom IMAP Server" tile (now under "Available Now") >
AccountSetupScreen server section (Host, Port, Encryption, Username) + the existing Email, Password, Test Connection,
Connect. Edit-after-save: the existing per-account Settings screen has no server-settings editor; this card does
NOT add one (re-add the account to change the host). State this limitation in the help line.

**Observable behavior -- before / after**: BEFORE: the Add Account list shows Demo, AOL, Gmail, Yahoo, iCloud;
"Custom IMAP Server" does not appear anywhere. AFTER: a sixth tile "Custom IMAP Server -- Any email server with
IMAP support" appears under Available Now; tapping it opens the setup screen with Server host, Port (993),
Encryption (SSL/TLS), Username, Email Address, Password; Test Connection reports success or a plain-language
failure; Connect saves and goes to the Manual Scan screen exactly as AOL does (`_finishAccountAdded`,
`account_setup_screen.dart:320-355`); after an app restart the account scans without asking for the server again.

**Dependencies / blockers**: Decision Q1 (persistence home) and Q3 (encryption modes) answered at plan approval.
Independent of F191 and of SEC-8b.

**Non-functional requirements**:
- Account-scoping: server settings keyed by `accountId` exactly as credentials are; no cross-account read.
- Accessibility: new fields carry labels and `semanticsLabel` per ADR-0037; the encryption control is a labeled
  segmented control or dropdown, keyboard-reachable on Windows.
- Platform (ADR-0042): shared Flutter UI and shared adapter on BOTH platforms. OS behavior assumed identical and
  named: dart:io `SecureSocket.connect` performs TLS with the OS trust store on Windows and Android alike; secure
  storage is `flutter_secure_storage` on both (ADR-0008). One factual non-parity that is NOT a code exception: a
  loopback host (127.0.0.1) can have a listener on Windows (Proton Bridge, DavMail) and never on Android, so the same
  input fails differently; no platform conditional is added. UNVERIFIED and to be spiked (5 min) if Q3 allows a
  plaintext mode: whether Android's `network_security_config` `cleartextTrafficPermitted="false"` (SEC-4,
  `android/app/src/main/res/xml/network_security_config.xml:14`) governs dart:io sockets at all -- the Android page
  (https://developer.android.com/privacy-and-security/security-config) does not say; if it does not, the SEC-4
  declaration gives no protection against a plaintext IMAP login on Android.
- Security: password field stays obscured; host is logged redacted or not at all in `LiveScanLogger`; SEC-20 generic
  messages are kept for email/password, with a deliberate deviation for host/port validation messages (the user must
  be told WHICH field is wrong -- surfaced in Task B).
- Known limitation (state in card, do not solve): `accountId = email` (`account_setup_screen.dart:279`), so the same
  address on two different custom servers collides; second save overwrites the first.

**Acceptance criteria** (measurable, traceable):
- AC-1: `PlatformRegistry.getPlatformsByPhase(1)` contains `imap`; the Add Account screen renders a "Custom IMAP
  Server" card under "Available Now" on Windows and Android.
- AC-2 (behavioral): Given the Custom IMAP setup screen, When Host is blank and Test Connection is pressed, Then no
  network call is made and the Host field shows a validation message.
- AC-3 (behavioral): Given valid host/port/encryption/username/email/password, When Test Connection is pressed, Then
  `GenericIMAPAdapter.loadCredentials` receives `additionalParams` carrying exactly those values and the status
  line shows "[OK] Connection successful!" on success or the humanized error on failure.
- AC-4: After Connect, `SecureCredentialsStore.getCredentials(accountId).additionalParams` contains
  `imapHost`, `imapPort`, `imapSecure`, `imapUsername`; after `deleteCredentials(accountId)` none of the four keys
  remain in storage.
- AC-5: `GenericIMAPAdapter.custom()` with `additionalParams` lacking `imapHost` throws `ConnectionException` whose
  message names the missing server configuration, before any socket is opened.
- AC-6: A reconnect through `EmailScanner` (manual, and background via `BackgroundScanCore`) for a saved custom
  account connects to the stored host/port (proven with a scripted provider override, not a live server).
- AC-7: `platform_registry_phase_test.dart` asserts `imap.phase == 1`; full suite green; `flutter analyze` clean.
- AC-8: Manual validation on Windows AND Android (Fold8 closed-test build) against one real custom server (Harold to
  name one; first candidate Fastmail (US-based, verified IMAP/993/app-password), Yandex as fallback).

**Tests to write** (intent, not assertions):
- T-1 (AC-1) -- TEST-UNIT in `test/unit/platform_registry_phase_test.dart`: invert the F192 gate; prove `imap` is in
  the phase-1 query the screen uses. What it does NOT catch: a screen filter change that hides phase 1 (covered by T-2).
- T-2 (AC-1) -- TEST-WIDGET in `test/ui/screens/platform_selection_screen_test.dart` (new): the Custom IMAP card
  renders under Available Now. Does NOT catch: the tap route being wrong.
- T-3 (AC-2, AC-3) -- TEST-WIDGET in `test/ui/screens/account_setup_custom_imap_test.dart` (new, using
  `PlatformRegistry.overrideFactoryForTest('imap', ...)` at `platform_registry.dart:42-54`): blank host blocks the
  call; filled form delivers the four params to a scripted adapter. Does NOT catch: a real TLS handshake.
- T-4 (AC-4) -- TEST-UNIT in `test/unit/secure_credentials_store_test.dart` (extend if present; else new, with a fake
  `FlutterSecureStorage`): round-trip and delete of the four keys. Does NOT catch: a key name typo that is consistent
  in save and delete but differs from what the adapter reads (covered by T-5's shared constant).
- T-5 (AC-5, AC-6) -- TEST-UNIT in `test/adapters/email_providers/generic_imap_adapter_custom_host_test.dart` (new):
  missing host throws before connect; present host is what `connectToServer` is called with (seam: a test-visible
  hook on the connect call, as `generic_imap_adapter_chunked_fetch_test.dart` does for fetch). Does NOT catch:
  `_checkAndReconnect` using a stale host (add one case for it).
- T-6 (AC-6, background) -- TEST-UNIT in `test/core/services/background_scan_core_test.dart` (extend): a saved custom
  account resolves platformId `imap` and reaches the scanner with its params. Does NOT catch: the WorkManager
  isolate's secure-storage access, which only the device proves.
- Mutation: every new test mutation-checked with `scripts/mutation-test.ps1` (delegation checklist items 2-3).

**Definition of Done**: default task-level DoD PLUS:
- Manual validation on both platforms (AC-8) with the full step list re-presented in the message that asks for it.
- `docs/ARCHITECTURE.md:286` row updated; `CHANGELOG.md` `feat` entry; `docs/ALL_SPRINTS_MASTER_PLAN.md` F192 marked.
- Both stale comments corrected (R-9).

**Model**: Sonnet -- *why not Haiku*: the adapter change touches `final` fields read by three code paths
(`loadCredentials`, `_checkAndReconnect`, `testConnection`) and the task crosses four files with a persistence
contract; Sprint 75 showed a Haiku batch returning a vacuous widget test on a similar multi-file UI task. The
form widgets and the two policy/unit test inversions are Haiku-shaped and can be split out as a delegable block if
the sprint is not a single session.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes

**Executed-by** (filled at completion): --

**Step-types**: UI-NEW, SVC-EDIT (adapter), SVC-EDIT (store), DATA (registry phase), TEST-UNIT x3, TEST-WIDGET x2, CONTENT, DOCS

**Est-Effort**: 130-200m (UI-NEW 30-40; adapter SVC-EDIT 10-18; store SVC-EDIT 10-18; registry+gate inversion 5-10;
TEST-UNIT 3x 4-10 = 12-30; TEST-WIDGET 2x 20-25 = 40-50; CONTENT 5-10; DOCS 15-20). Est-Wall: equal for a solo
agent; ~90-140m if the widget tests and content run as a parallel Haiku block. Sprint 76 ran ~0.4x on
agent-implemented items, so coding may land ~60-90m; device validation on two platforms plus one real custom server
is NOT in this number and ran over in Sprint 76 -- time-box it separately. Backlog said 120-180m.

_**Risk & rollback**_: Risk: the phase flip exposes the tile before the form is complete (the exact Sprint 68 F191
listing failure in reverse). Mitigation: the phase flip and the gate inversion are the LAST commit of the task, after
T-3/T-5 pass. Rollback: revert that one commit; stored side keys are inert for other providers.

_**Decision-class interrupts**_ (surface at plan approval):
- Class-2 (Q1): where per-account server settings live -- (a) `SecureCredentialsStore` side keys read by the adapter
  from `additionalParams` (changes the adapter's data model: host is no longer constructor-only), or (b) an
  account-aware registry (`getPlatform(platformId, accountId)`), which changes the signature at SEVEN call sites:
  `folder_selection_screen.dart:235`, `account_setup_screen.dart:198`, `account_selection_screen.dart:274`, `:352`,
  `results_display_screen.dart:4139`, `email_scanner.dart:271`, `:1620`. Recommendation: (a). Decision: Harold.
- Class-2 (Q3): which encryption modes the form offers (see Section 4).
- Class-1 (none): no ADR changes; ADR-0002 (adapter pattern) already describes `custom()`.

---

### Task B -- SEC-15: IMAP host validation for custom servers (Priority HOLD -> candidate)

**Value**: This prevents a custom-server form from accepting a host that the product has decided it should not
connect to, and gives the user a plain-language reason instead of a socket error.

**Requirements**:
- R-1 (audit first): no validator exists (Section 0). The threat model is S19's SSRF, which does not apply to a
  client app (Section 2 note); the requirement below is written for whichever policy the PO picks in Q2.
- R-2: A pure function `ImapHostPolicy.check(String host, int port) -> HostCheckResult` in
  `lib/core/security/imap_host_policy.dart` (beside `auth_rate_limiter.dart` and `certificate_pinner.dart`) that
  classifies: empty / malformed, literal loopback (127/8, ::1, `localhost`), literal private (10/8, 172.16/12,
  192.168/16, fc00::/7, fe80::/10, 169.254/16), public. It performs NO DNS resolution (pure, testable, and resolving
  would block legitimate hostnames that resolve privately only on a VPN).
- R-3: The form calls it before Test Connection and before Connect; the outcome per class is the Q2 policy:
  reject / warn-and-allow / allow.
- R-4: Messages are field-specific ("Server host looks like a private network address") -- a deliberate, documented
  deviation from SEC-20's generic-message rule, because the user typed the value and must know which field to fix.
- R-5: Prevention-first: the check is also applied inside `GenericIMAPAdapter.loadCredentials` for the custom
  platform when the policy is "reject", so a stored host cannot bypass the UI (one function, two callers; no second
  implementation).

**Affected components / files**: new `lib/core/security/imap_host_policy.dart`; `account_setup_screen.dart`
(validation step in `_testConnection` and `_handleConnect`); `generic_imap_adapter.dart:164-244` (R-5);
`CHANGELOG.md`; `docs/ARCHITECTURE.md:252` area (security components table).

**Existing abstraction checked**: `AuthRateLimiter` / `CertificatePinner` as the security-helper family -- the new
class follows their static-registry style; no existing host validator found.

**Existing behavior relied on**: "`HandshakeException`/`SocketException` are humanized" -- `generic_imap_adapter.dart:233-238`,
`account_setup_screen.dart:235`; the policy result must NOT be a `SocketException` so it is not mistaken for a network
failure.

**Callers of any guard being changed**: the guard is new; its callers are the two form paths and (R-5) the adapter's
`loadCredentials`, whose callers are listed in Task A. With policy "reject", a stored private host fails every scan;
with "warn-and-allow", R-5 is a no-op.

**User-reachable control**: inline validation on the Custom IMAP setup screen (Task A). N/A as a setting unless Q2
chooses "warn-and-allow with a remembered choice", which would add a per-account flag.

**Observable behavior -- before / after**: BEFORE: n/a (no form). AFTER (policy-dependent): reject -> Test Connection
and Connect are blocked with a field message; warn-and-allow -> a one-time dialog "This address is on a private
network; continue?"; allow -> nothing.

**Dependencies / blockers**: Task A form (R-2 of Task A). Decision Q2.

**Non-functional requirements**: Platform parity: pure Dart, identical on both; the one named OS difference is that
loopback listeners exist only on desktop (Task A NFR). Security: no DNS from the UI thread.

**Acceptance criteria**:
- AC-1: `ImapHostPolicy.check` classifies each listed range and `localhost` correctly, plus IPv6 forms and a
  hostname (treated as public).
- AC-2 (behavioral): Given policy = reject and host `192.168.1.10`, When Test Connection is pressed, Then no adapter
  call occurs and the Host field shows the private-network message.
- AC-3: With policy = reject, `GenericIMAPAdapter.loadCredentials` for a stored private host throws before opening
  a socket.
- AC-4: Public hostnames and public literals pass unchanged (no regression on AOL/Yahoo/iCloud, which never enter
  this path).

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT `test/unit/security/imap_host_policy_test.dart`: classification table. Does NOT catch: a
  hostname that resolves privately (by design).
- T-2 (AC-2) -- TEST-WIDGET extend `account_setup_custom_imap_test.dart`: blocked path makes no adapter call. Does NOT
  catch: the Connect path if only Test is asserted (assert both).
- T-3 (AC-3) -- TEST-UNIT extend `generic_imap_adapter_custom_host_test.dart`. Does NOT catch: policy "allow" being
  silently selected in production config (add a policy-default test).

**Definition of Done**: default PLUS the S19 row in `docs/sprints/SPRINT_31_SECURITY_AUDIT.md` is annotated with the
chosen policy and rationale (do not rewrite the audit).

**Model**: Haiku -- the validator is a pure classification function with a table test; the two wiring points are
one-liners inside Task A's already-open files.
**Delegation checklist included**: yes

**Executed-by** (filled at completion): --

**Step-types**: SVC-NEW, TEST-UNIT, TEST-WIDGET (extend), DOCS

**Est-Effort**: 25-50m (SVC-NEW 5-18; TEST-UNIT 8-15; wiring 5-10; DOCS 5-10). Est-Wall: equal (solo agent).
Backlog said ~1h.

_**Risk & rollback**_: Risk: policy "reject" ships and blocks a Harold-validated workflow (Bridge/DavMail). Rollback:
policy is one constant; flip to "warn" without touching the validator.

_**Decision-class interrupts**_: Class-2 (Q2) policy choice; Class-2 (R-4) SEC-20 deviation. Both at plan approval.

---

### Task C -- SEC-8b: Certificate pinning for IMAP endpoints (Priority HOLD -> candidate, SPIKE-GATED)

**Value**: This prevents a man-in-the-middle holding a CA-issued but wrong certificate from reading an IMAP
password (known providers), and lets a self-hosted server with a private certificate be used safely (custom servers)
if trust-on-first-use is chosen.

**Requirements**:
- R-0 (pre-flight, first sub-task, time-boxed 15m): live spike against `imap.aol.com:993` proving the chosen connect
  path -- EITHER (i) `SecureSocket.connect` + `peerCertificate` + `ImapClient.connect(socket, connectionInformation:)`
  + greeting await via `PinnedImapClient.onConnectionEstablished` override, OR (ii) `connectToServer` on an
  `ImapClient(onBadCertificate: ...)` whose socket is forced through the callback by a
  `SecurityContext(withTrustedRoots: false)` -- BUT (ii) is impossible as-is because `connectToServer` passes no
  `context` (`client_base.dart:111-115`), so (ii) collapses to (i) unless dart:io's default context is replaced
  process-wide (`SecurityContext.defaultContext` is read-only; rejected). Spike therefore tests (i) and specifically
  that `login()` after the awaited greeting succeeds and that a `login()` BEFORE it fails with `'reconnect'`
  (`imap_client.dart:316-327`) -- the failure-path proof.
- R-1 (prevention-first, before any extension): fix `CertificatePinner` so `fingerprint()`, the pin VALUES and
  `matches()` agree -- either compute SPKI (needs an ASN.1 walk; `pointycastle`/`asn1lib` are not in pubspec, so a
  minimal DER parser or a new dependency) or re-capture the four Google pins as LEAF full-DER hashes with a
  documented rotation cadence. Add the missing fixture test: a real certificate DER in `test/fixtures/` run
  through `matches()` with a known-good and a known-bad pin. Without this, the IMAP path extends a function that
  cannot match. (Class-1/2: see interrupts.)
- R-2: `PinnedImapConnector.open(host, port, {policy})` in `lib/core/security/certificate_pinner.dart` (same file,
  beside `PinnedHttpClient`), returning a `SecureSocket` after: platform validation (unless TOFU accepted a
  stored fingerprint via `onBadCertificate`), then `peerCertificate` fingerprint checked against
  `CertificatePinner.pins[host]` when the host is pinned; mismatch closes the socket and throws
  `CertificatePinMismatchException` (existing class, `:54-69`), which `loadCredentials` maps to
  `ConnectionException('TLS certificate validation failed: ...')` (`generic_imap_adapter.dart:233-235`, extend the
  `if`).
- R-3: `GenericIMAPAdapter.loadCredentials` and `_checkAndReconnect` use the connector when
  `CertificatePinner.enabled`; the kill switch (`setEnabled`, Settings toggle `settings_screen.dart:931-947`) covers
  IMAP too; the toggle's title/subtitle are generalized from "Google OAuth" (Sprint 74 IMP-2: user-visible text must
  match behavior).
- R-4 (custom servers, Decision Q4): the policy for a host with no pin: (a) none (platform validation only, today's
  behavior), (b) trust-on-first-use: on first successful connect store the leaf fingerprint per account
  (`SecureCredentialsStore` side key `imapCertFingerprint`), on later connects compare and on change show a
  blocking dialog "The server's certificate changed" with Accept / Cancel, (c) TOFU plus accept-self-signed on first
  use (the only option that admits Proton Bridge / private CAs). Written for (b)+(c) as one implementation with (c)
  behind the first-use dialog.
- R-5: Known-provider IMAP pins (imap.gmail.com, imap.aol.com, imap.mail.yahoo.com, imap.mail.me.com) are NOT added
  in this card unless Q4 says so: they would be leaf pins that rotate (constraint 3), and the only release valve is
  the kill switch.

**Affected components / files**: `lib/core/security/certificate_pinner.dart:137-165` (R-1), new connector class in
the same file (R-2); `generic_imap_adapter.dart:174-199`, `:1483-1488` (R-3); `settings_screen.dart:931-947` (R-3
copy); `secure_credentials_store.dart` side key (R-4); `test/unit/security/certificate_pinner_test.dart` (R-1 fixture);
new `test/unit/security/pinned_imap_connector_test.dart`; `docs/adr/0045-imap-certificate-trust.md` (new, see
Section 6); `docs/ARCHITECTURE.md`; `CHANGELOG.md`.

**Existing abstraction checked**: `CertificatePinner` (registry, kill switch, exception) -- EXTENDED, not duplicated.
`PinnedHttpClient` -- pattern copied for the socket connector. `ImapClient.startTls()` (`imap_client.dart:434`) --
noted; irrelevant to pinning but needed if Q3 adds STARTTLS.

**Existing behavior relied on**: "the Settings toggle and `main.dart:288-295` already persist and apply
`CertificatePinner.enabled`" -- verified; "`HandshakeException` is already humanized as a certificate failure" --
`generic_imap_adapter.dart:233-235`.

**Callers of any guard being changed**: `CertificatePinner.enabled` currently gates only `PinnedHttpClient`
(`gmail_windows_oauth_handler.dart:313/391/420`, Windows OAuth only). After R-3 it ALSO gates every IMAP connect on
both platforms: `email_scanner.dart:294`/`:1631` (manual + background workers), `folder_selection_screen.dart:246`,
`results_display_screen.dart:4152`, `account_setup_screen.dart:205`. A user who turned the toggle OFF for a Google
CA rotation (its documented purpose) now also disables IMAP TOFU -- name this in the toggle copy.
- Tooling: N/A.

**User-reachable control**: Settings > (existing) certificate-pinning switch, retitled; plus the TOFU "certificate
changed" dialog on the connect path (manual scan, Test Connection); background scans never prompt -- they fail the
account with a logged reason and the next manual scan shows the dialog (same shape as F239's "Sign In Again").

**Observable behavior -- before / after**: BEFORE: a wrong-but-CA-valid certificate on an IMAP host is accepted; a
self-signed one fails with "TLS certificate validation failed". AFTER (Q4 = b+c): first connect to a custom server
with an untrusted certificate shows its fingerprint and asks to trust it; later connects are silent unless the
certificate changes, which shows a blocking dialog; known providers unchanged unless pins are added.

**Dependencies / blockers**: R-0 spike result; R-1 before R-2; Decision Q4; Task A for the custom-server case (TOFU
without a custom server has nothing to trust). Can ship for known providers independently of Task A only if Q4
chooses provider pins, which is not recommended.

**Non-functional requirements**: Platform parity: the connector is pure dart:io and identical on both; OS
behavior assumed identical and named: `SecureSocket` performs the TLS handshake in Dart's BoringSSL on both
platforms and `peerCertificate` returns the server leaf on both (api.dart.dev, VERIFIED for the API; identical
platform behavior is an inference from dart:io being the same binary layer -- a two-platform device test is the
proof, per Sprint 76 IMP-3). Background workers (Windows Task Scheduler process, Android WorkManager isolate) must
read the TOFU fingerprint from the same secure store without UI -- test both. Security: fingerprints logged only as
the first 8 characters.

**Acceptance criteria**:
- AC-0: Spike log shows a successful LOGIN after the awaited greeting and a `'reconnect'` failure when LOGIN precedes
  it (both paths observed).
- AC-1: `CertificatePinner.matches()` returns true for a fixture certificate with its correct pin and false with a
  wrong pin (first real-cert test of the pinner).
- AC-2: `PinnedImapConnector.open` closes the socket and throws `CertificatePinMismatchException` when a pinned host
  presents a non-matching leaf (test with a local `SecureServerSocket` and a test certificate).
- AC-3: With `CertificatePinner.enabled == false` the connector performs platform validation only (kill switch
  honored for IMAP).
- AC-4 (TOFU, behavioral): Given a custom account with a stored fingerprint, When the server presents a different
  leaf, Then the connect fails and the manual path shows the "certificate changed" dialog; accepting it updates the
  stored fingerprint.
- AC-5: Background scan for the same account logs the mismatch and marks the account failed without prompting.
- AC-6: `flutter analyze` clean; suite green; manual validation on Windows AND Android against one custom server with
  a self-signed certificate (a local Dovecot or `openssl s_server` on the LAN -- note this REQUIRES Q2 to allow private
  addresses, which is the dependency between the two security cards).

**Tests to write**:
- T-0 (AC-0) -- scratchpad spike script, NOT committed (feedback_scratch_probes_outside_repo).
- T-1 (AC-1) -- TEST-UNIT extend `certificate_pinner_test.dart` with a DER fixture. Does NOT catch: pins that are
  valid today and rotate tomorrow.
- T-2 (AC-2, AC-3) -- TEST-INTEGRATION `test/integration/pinned_imap_connector_test.dart` with `SecureServerSocket`
  and a committed test certificate (`test/fixtures/tls/`). Does NOT catch: behavior behind a real corporate TLS
  intercept.
- T-3 (AC-4, AC-5) -- TEST-UNIT on the adapter with a scripted connector seam; TEST-WIDGET for the dialog. Does NOT
  catch: the WorkManager isolate's secure-storage read (device only).
- T-4 -- POLICY `test/policy/certificate_pinner_wiring_test.dart`: ZERO direct `connectToServer(` calls remain in
  `lib/` (today there are two: `generic_imap_adapter.dart:195`, `:1484`); the connector is the only socket opener
  (grep gate in the style of `factory_call_site_test.dart`). Does NOT catch: a connector that
  is wired but returns early (T-2 covers that).

**Definition of Done**: default PLUS ADR-0045 written and Accepted by Harold; the two stale comments corrected if
Task A did not already; `docs/sprints/SPRINT_31_SECURITY_AUDIT.md` SEC-8b row annotated.

**Model**: Fable/Opus for R-0, R-1, R-2 (TLS trust design, DER handling, a greeting race in third-party code);
Sonnet for R-3/R-4 wiring and dialog; Haiku for T-4 and docs. *Why not cheaper for the core*: the Sprint 33 pinner was
shipped with a comparison that cannot match and nobody noticed for 44 sprints; this is exactly the class of work
where a confident-looking implementation hides a non-enforcing control, and the failure path must be proven, not
assumed.
**Delegation checklist included**: yes

**Executed-by** (filled at completion): --

**Step-types**: SPIKE (time-boxed), SVC-EDIT (pinner fix), SVC-NEW (connector), SVC-EDIT (adapter), UI-NEW (dialog),
TEST-UNIT, TEST-INTEGRATION, TEST-WIDGET, HOOK-style policy test, DOCS (ADR)

**Est-Effort** (Est-Wall equal unless the Haiku docs/policy block is run in parallel): 150-230m if Q4 = TOFU (spike 15 time-boxed; pinner fix + fixture 20-35; connector 15-30; adapter
wiring 10-18; TOFU store + dialog 30-45; tests 40-60; ADR + docs 20-25). ~60-90m if Q4 = "known providers only"
(not recommended). 5m (comment fixes only) if Q4 = keep on HOLD. Backlog said 4-6h; with the no-fork finding the
range above is realistic, but the spike is the gate on all of it.

_**Risk & rollback**_: Risk: leaf-pin rotation or a TOFU false alarm locks users out of mail; mitigation: kill
switch covers IMAP, TOFU dialog offers Accept, background never hard-fails silently (logged + account marked).
Rollback: `CertificatePinner.setEnabled(false)` path already persisted; the connector is behind that flag.

_**Decision-class interrupts**_:
- Class-1 (Q4): the trust model for custom servers (none / TOFU / TOFU + self-signed) is a new architecture decision
  -- ADR-0045 proposed.
- Class-2 (R-1): correcting the pinner's hash mode changes a prior security implementation decision (Sprint 33
  SEC-8); Harold must approve re-capturing pins as leaf-DER or adding an ASN.1 dependency for SPKI.
- Class-2 (R-3): widening the meaning of the existing Settings toggle from "Google OAuth" to "all pinned/TOFU
  connections".

---

## 4. Encryption-mode question (affects Task A directly; Decision Q3)

The backlog says "TLS toggle". The code shows the OFF state is a cleartext IMAP LOGIN (`client_base.dart:116`;
`startTls()` never called). Options for the form's Encryption control:
- Q3-1: "SSL/TLS" only (port 993); no toggle at all. Simplest; blocks Proton Bridge (STARTTLS 1143), DavMail (143),
  email-oauth2-proxy (unencrypted local hop) -- the same three SEC-15 blocks, so Q2 and Q3 are coupled.
- Q3-2: "SSL/TLS" and "STARTTLS" (adds a `startTls()` call after a plaintext connect, `imap_client.dart:434`; +10-18m
  SVC-EDIT, +1 unit test); still no plaintext login. Admits Proton Bridge if Q2 allows loopback and Q4 admits its
  certificate.
- Q3-3: all three including "None". Only sane for a loopback bridge; a plaintext password over a LAN or the
  Internet is a credential leak the app would be enabling, and it contradicts the SEC-4 Play declaration intent
  (`network_security_config.xml:2-3` says "all email provider connections are TLS-only"). If chosen, restrict "None"
  to loopback hosts and warn.

Recommendation: Q3-2. Decision: Harold.

## 5. Should SEC-15 be merged into F192?

Recommend YES, as Task A's R-6/AC-6/T-6 with Task B's text folded in: it is one pure function called from the same
two form methods Task A already edits, the policy choice (Q2) must be made before the form ships anyway, and a
separate card would create a second Haiku task whose only files are Task A's. Keep SEC-8b SEPARATE: different
risk class, spike-gated, needs an ADR, and can ship a sprint later without changing Task A. Decision: Harold.

## 6. ADR / ARCHITECTURE.md impact

- F192: no new ADR; ADR-0002 (adapter pattern) and ADR-0008 (secure credential storage) already cover the shape.
  `docs/ARCHITECTURE.md:286` (GenericIMAPAdapter row) must say the custom host/port/TLS/username are supplied per
  account through `Credentials.additionalParams` from `SecureCredentialsStore` (if Q1-a). ADR-0042 parity: claimed,
  with the OS behaviors named in Task A's NFR; no exception declared.
- SEC-15: no ADR; one row in ARCHITECTURE.md security components (near `:252`).
- SEC-8b: NEW ADR-0045 "IMAP certificate trust: pinning scope and trust-on-first-use for custom servers" if Q4 is
  anything other than "none" -- it introduces a trust model (app-stored fingerprints, user-accepted certificates)
  that outlives any sprint and changes what "TLS certificate validation failed" means. Recommend; do not create
  until Q4 is answered.
- Both stale comments (Section 0) are doc defects regardless of which cards are selected.

## 7. Decision questions for the Product Owner / Chief Architect (answer by digit)

Q1. Persistence home for custom-server settings (Class-2):
  1. `SecureCredentialsStore` side keys, read by the adapter from `additionalParams` (no call-site edits) -- recommended
  2. Account-aware `PlatformRegistry.getPlatform(platformId, accountId)` (7 call sites change)
  3. New columns on the `accounts` table (DB migration; Class-1 data model)

Q2. SEC-15 policy for private/loopback hosts (Class-2; conflicts with Proton Bridge, DavMail, email-oauth2-proxy, LAN servers):
  1. Reject (as the Sprint 31 audit wrote it)
  2. Warn once and allow (validator shipped, policy = warn) -- recommended
  3. Allow silently and close SEC-15 as not applicable to a client app, with the rationale recorded in the audit
  4. Reject literal private IPs but allow hostnames (speed bump only)

Q3. Encryption modes on the Custom IMAP form (Class-2):
  1. SSL/TLS only
  2. SSL/TLS and STARTTLS -- recommended
  3. SSL/TLS, STARTTLS and None (None restricted to loopback with a warning)

Q4. SEC-8b trust model for servers with no pin (Class-1, ADR-0045):
  1. Keep SEC-8b on HOLD; fix the two stale comments only
  2. Trust-on-first-use for custom servers, platform validation still required on first use
  3. Trust-on-first-use plus user-accepted self-signed/private-CA certificates on first use (admits Proton Bridge and self-hosted) -- recommended if Q2 is 2 or 3
  4. Pin the four known providers' IMAP leaf certificates as well (not recommended: leaf rotation)

Q5. Merge SEC-15 into the F192 card?
  1. Yes, as R-6/AC-6/T-6 of Task A -- recommended
  2. No, keep Task B separate

Q6. The existing OAuth pinner finding (hash mode mismatch, Section 0): 
  1. Fold the fix into SEC-8b R-1 (only if SEC-8b is selected)
  2. File it as its own backlog item (SEC-8c) for a later sprint
  3. Accept as-is (kill switch + scheme check is the intended control) and correct the dartdoc to say so

Q7. Which real custom server will Manual Validation use (needed for AC-8)? Name one; Fastmail (US-based) is the
  first candidate and Yandex the fallback; both are verified IMAP/993/app-password and would exercise the "custom"
  path end to end.
