# Sprint 78 Plan

**Status**: DRAFT -- awaiting Phase 3.7 approval (Harold). Scope selected by Harold at Phase 8.4 pass 2 (2026-10-09).
Harold's decision answers recorded 2026-10-10 (R76-4 reshaped to dev-only; F199-b to HOLD; Task 9 notifications added).
**Branch**: `feature/20261009_Sprint_78` | **PR**: draft, created at Phase 3.3.1
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 branch-state audits by four read-only
agents (2026-10-09); the file:line evidence in each card comes from them and from spot reads this turn.

## Objective

Finish the phone checks on the 0.18.0 closed-test build (with the battery measurement that settles the 5-minute
floor), put every file the app writes for the user in one `MyEmailSpamFilter` folder, make Review No Rule Items work
like the Results screen, take the WinWright sweep off the mouse, redesign the "Scan every" control from researched
practice, and start a content history of Harold's own four mailboxes for future heuristics, ML and GenAI work.

**Parity (Harold, 2026-10-09, verbatim)**: *"everything needs to take into account both the Windows App and the Android
app and ADR stating that everything should be functionally and UI the same unless it cannot be - and where it cannot be
it should be implemented as a platform exception for what is needed -- this applies to all backend code, frontend code,
data, architecture, development, security, testing, deployment."* Every card names the Windows path and the Android
path and either claims parity (naming the OS behavior assumed identical) or declares an ADR-0042 exception.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control before creating a new one, then the instance fix.

**R76-4 Class-1 approval (Harold, 2026-10-09, verbatim)**: *"Noting this is for storing, from me and only for me, my 4
personal email accounts: kimmeyharold@aol.com, kimmeyh@gmail.com, kimmeyh@yahoo.com and kimmeyharold@icloud.com and
this is my Class 1 approval of an exception for this purpose (and F273) - settle this before plan is approved."* The
shape of the exception is settled by decision questions R1-R8 below.

**R76-4 reshaped (Harold, 2026-10-10, verbatim)**: *"Can we limit to only running in Windows dev or only dev - no need
at this time to run anywhere else as Windows dev can capture the entire list. on/off button on the Settings> General tab
only for dev."* This replaces R1 and R2 (no secrets key, no hash list): the feature exists only in dev builds
(`AppEnvironment.isDev`, `app_environment.dart:29`), so no Store or Play build can ever capture. In practice it runs on
Harold's Windows DEV install, which holds his four accounts.

## Carry-ins from the Sprint 78 stub (kept)

- 0.18.0 store updates: MSIX and AAB BUILT + VERIFIED 2026-10-09 (Phase 8.3). Harold 2026-10-10: both updated. Fold
  diagnostic log: `app start (foreground) -- v0.18.0 env=prod platform=android` at 2026-10-09 13:33. Windows: Harold's
  screenshot shows a prod (no `[DEV]`) window at Version 0.18.0; Partner Center submission status not observed.
- MV76-1 Fold steps 7-11 on 0.18.0, and the boot-time `main()` trace (`app start (foreground)` at 09:14:39 on
  2026-10-07 with no app opened) -- Task 1.
- First sprint under Sprint 77 IMP-1: every MV step is rehearsed before handover; the F193 gate requires
  `- **5.1.9 MV rehearsal**: <evidence>`.
- 0xc0000409 crash on opening Review No Rule Items (Sprint 77, cause unknown): card only if it recurs. F283 rewrites
  that screen, so Manual Validation opens it on both platforms and records whether it recurs.

## Tasks, order, models and estimates

- **Task 0 -- Version bump 0.19.0+16** (Phase 3.7.0b; MINOR because F282, F283 and R76-4 are `feat`). Haiku. 10-20m.
  "Last uploaded to Play" moves to 0.18.0 (versionCode 15) in this bump (Harold confirmed the update 2026-10-10).
- **Task 1 -- MV76-1 + F205 + boot trace**: Fold steps 7-11 on 0.18.0. Haiku transcription / session model. 40-70m +
  Harold's phone time.
- **Task 2 -- F277**: Fold energy check, interval 5 against 15 (three 8-hour arms). Haiku analysis. 45-60m + three
  overnight windows of phone time.
- **Task 3 -- F282**: one `MyEmailSpamFilter` folder. Haiku (with the delegation checklist). 50-80m (re-estimated from
  60-90m, see the card).
- **Task 4 -- F281**: "Scan every" research (Fable/Opus, mandatory for best-practices research), then the implementation
  card Harold picks (Sonnet). 150-270m.
- **Task 5 -- F284**: mouse-free WinWright sweep, retire mt2c, fixed window size. Sonnet. 90-140m including a 45-minute
  WINWRIGHT-DISCOVERY time-box.
- **Task 6 -- F283**: Review No Rule Items rebuilt on shared Results widgets. Sonnet (extraction), Haiku (test rewrites).
  300-420m (re-estimated from 150-210m, see the card).
- **Task 7 -- R76-4**: content history, dev builds only (Harold's Windows DEV install). ADR-0047 on Fable/Opus
  (mandatory for ADR authoring), implementation Sonnet, tests Haiku. 315-470m including R7 (was 330-505m +30m: the
  secrets gate, the export and the per-account controls are gone).
- **Task 8 -- F199-b**: repo records synced to Partner Center (`Kimmey Consulting - Ohio`), card moved to HOLD. Haiku.
  10-15m.
- **Task 9 -- N78-1**: MOVED to the backlog as F286, target Sprint 79 (Harold 2026-10-10, N1 = 2).

**Total**: about 1,010-1,545 minutes plus Harold's phone time. Calibration: Sprint 77 planned items ran under estimate,
but each recent sprint added 40-55% unplanned work (MV fixes, review fixes). F283 and R76-4 carry most of the risk.

**Order**: Task 0; Task 1 and Task 2 start at once on the phone once 0.18.0 is installed from Play (their waits are
filled by the rest); Task 7 ADR-0047 first (it fixes the
design before code); Task 3; Task 4 research, then Harold's pick -- asked as a numbered question while work continues on Tasks 5-7, the one
planned mid-sprint decision (approve it in Q-S2); Tasks 5 and 6 together (F284 b retires mt2c as F283 removes
multi-select); Task 7 implementation; Task 8 any time.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (a), recorded once):
Harold's phone feedback interleaves with implementation, so execution is the session model unless a task is delegated.
`Executed-by` per task cites this line. Delegated coding sub-agents get the delegation checklist verbatim.

**Code reviews**: no 5.1.1. The 7.7.1 pair (Copilot by hand + pr-review-toolkit code-reviewer and silent-failure-hunter)
runs when the retrospective improvements are complete. The 7.7.1 size limit (4+ code files or 600+ lines asks first)
applies to review fixes, not to the planned work below.

**Cards**: GitHub issue cards are created at Phase 3.7.0, the first action after approval (the Sprint 77 precedent: draft
PR at 3.3.1, cards after approval), because the decisions below change card content.

## Phase 3.2.2.1 branch-state verification (summary)

Each card carries its audit. Findings that changed scope or estimate:

- F282: Android already defaults to Documents; every writer except YAML export already goes through
  `ExportDirectories.resolve`; the dev/prod split exists only for the diagnostics folder. Re-estimated down.
- F283: every Results piece (chip row, filter bar, rows, search, the ~770-line detail popup at
  `results_display_screen.dart:2099-2870`) is a private method on the screen state; Review has NO detail popup; row
  types differ (`_NoRuleItem`/`UnmatchedEmail` against `EmailActionResult`). Re-estimated up.
- F284: only the Review screen has an account drop-down face (`no_rule_review_screen.dart:851`); the runner refuses a
  locked PC unconditionally (`run-winwright-tests.ps1:231-263`); no window-size step exists (scripts maximize).
- F281: no clamp below 99 hours anywhere; `nearestValid` runs at every startup and settings load.
- R76-4: one shared choke point (`EmailScanner` `evaluateBatch`, `email_scanner.dart:384-470`); no account gate exists;
  every Android build reads `secrets.dev.json` (`build-with-secrets.ps1:511`), the Store MSIX reads `secrets.prod.json`;
  iCloud and Yahoo are supported providers (`platform_registry.dart:130-168`); `allowBackup="false"`
  (`AndroidManifest.xml:37`), so nothing reaches Google Drive backup.
- F199-b: `pubspec.yaml:140` holds `Kimmey Consulting - Ohio` (Partner Center rejects a mismatch -- Submission 26);
  `docs/LEGAL_ENTITY.md:43` wrongly says the repo holds `Kimmey Consulting LLC`.

**Phase 3.2.2.2**: fired -- F282 and F283 re-estimated in their cards; R76-4 estimated for the first time (was
`[no-history]`, 90m design time-box).

## Phase 3.6.1 Architecture Impact Check

- **NEW ADR-0047** (R76-4): content history as DEV-ONLY tooling -- the Class-1 exception (dev builds only, so only the
  developer's own accounts), fields, identity hash, storage file, retention, deletion, and what must happen before it
  could ever ship in a customer build (F273 first).
- **ADR-0042 amendment** (F282): the "Default export folder (F206)" deliberate non-parity bullet (`:99`) is RETIRED --
  both platforms default to Documents.
- **ADR-0039 amendment** (F281): interval range 5 minutes to 24 hours; the control shown only when a background mode is
  on. ADR-0044 note if the new-mail switch changes visibility.
- **ARCHITECTURE.md**: `:235-237` (LiveScanLogger, ExportDirectories, DiagnosticLogger folder rows) for F282; a new
  content-history component row and its storage for R76-4; the Review No Rule Items screen description for F283.
- No other ADR conflicts found.

## Decision questions -- answers (Harold, 2026-10-10)

The original options are kept in git history (commit 9acbb01). Answers as given, with what each means for the cards.

**R76-4 content history**

- R1 / R2 (gate and builds): REPLACED by Harold's reshape -- *"limit to only running in Windows dev or only dev ... on/off
  button on the Settings> General tab only for dev."* Gate = dev build (`AppEnvironment.isDev`) AND the Settings >
  General switch, off by default. No secrets key, no hash list. Prod builds (Store MSIX, Play AAB) contain the code but
  can never turn it on: the switch is not shown and capture checks the environment first.
- R3 = 1: header fields, outcome label and the plain-text body (HTML converted), capped at 64 KB, no attachments.
- R4 = 1: separate `content_history.db` beside `spam_filter.db` in the dev data folder
  (`%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`).
- R5 = 1: kept until deleted; a "Delete content history" control.
- R6: Harold asked *"if only in Windows Dev can it write to the DB directly?"* -- Yes. Capture writes straight into
  `content_history.db` on the PC, so no export or merge is needed. The export (R-8) is dropped from this sprint; a later
  F267/F268 item adds one if a tool needs it.
- R7 = 1: the pre-existing deletion gaps are fixed inside R76-4 with a policy test that every table holding account data
  is in both deletion paths (+30m, now inside the estimate).
- R8 (not answered; follows from dev-only): option 1. No customer build can capture, so the privacy policy and Data
  safety stay true with no text change; ADR-0047 records that F273 must ship before this could ever reach a customer
  build; a policy test asserts capture is impossible when `APP_ENV` is not `dev`.

**F281 "Scan every"**

- F1 (not answered): taking option 1 -- a saved interval above 24 hours becomes 24 hours through the existing
  `nearestValid`, unless Harold says otherwise.
- F2 = 1: a saved interval is kept while the control is hidden and shown again when a background mode is turned on.

**F282 one folder**

- F3 = 1: `scan_exports` and `diagnostics` inside `MyEmailSpamFilter` / `MyEmailSpamFilter_Dev`; a folder the user chose
  keeps today's `diagnostics_Dev` naming.

**F283 Review No Rule Items**

- F4 = 1 (Harold: "pretty sure"): the first screenshot of the new Review chip row goes to Harold before the rest of the
  screen is built (Task 6 R-8).
- F5: KEEP `email_detail_view.dart` -- *"keep it for 5 sprints then ask again"*; re-ask at Sprint 83 planning (F285,
  HOLD, in the master plan).
- F6 = 1: the same popup actions as Results, through Review's single-row action path, then advance to the next row.

**F199-b** (Harold, 2026-10-10, verbatim): *"update the repo Windows store section to match what the Microsoft Partner
Center says for now. Then close and state that no real business is being done by either entity and will resolve later.
Can you push F199-b to HOLD and update it's backlog."* Task 8 does exactly that: repo records synced to
`Kimmey Consulting - Ohio`, the sprint task closed, the backlog card moved to HOLD with that reason.

**Sprint**

- Q-S1 = 1 (models approved), Q-S2 = 1 (F281's pick asked mid-sprint while work continues), Q-S3 = 1 (0.19.0+16).

**Notifications (Harold, 2026-10-10)**: two fixes from the 0.18.0 phone, first planned as Task 9. N1 = 2 (backlog,
target Sprint 79: F286), N2 = 2 (the notifications did not say which account they were for), N3 = 1 (Windows toast
as backlog card F287). Text set by Harold: body `No rule 9 Deleted 1 Safe 0` (` Errors N` only when N > 0), title
`Back. scan k*@aol completed`. Not in Sprint 78.

---

# Cards

## Task 1 -- MV76-1: Finish the Sprint 76 Fold checks on the 0.18.0 closed-test build (Priority 1; absorbs F205 #433, MV74-1 #428)

**Value**: This closes the last phone checks of Sprints 74-77 on the build customers will get.

**Requirements**:
- R-1: Fold steps 7-11 from `SPRINT_77_PLAN.md:419-431`, run on 0.18.0 installed from Play closed testing (re-presented
  in full at Manual Validation, never by reference).
- R-2: F205 / MV74-3 (#433): classify every scan error from a day of normal use per account, or record zero. The S24+
  history (53 errors) was Gmail-only and pre-0.15.0 (master plan F205 card); new errors on 0.18.0 are what matter.
- R-3: MV74-1 reboot half (#428): worker lines appear before the app-start line after a restart with the app unopened.
- R-4: Boot-time `main()` trace: find what started the Flutter engine at 09:14:39 on 2026-10-07 with no app opened
  (boot receiver or Doze alarm receiver), from the 0.18.0 diagnostic log; name the receiver and whether the
  `app start (foreground)` label is wrong for that path.
- R-5: F250: record the Google account state screenshot; decision already taken (F265 HOLD).
- R-6: iCloud on the Fold: the 0.18.0 logs pulled 2026-10-10 (through 09:56) name only `k***@aol.com` (1,121 lines),
  `k***@gmail.com` (153) and `k***@yahoo.com` (84); the iCloud account has a 2026-10-09 manual-scan CSV but no
  background scan line. Cause unknown: either its per-account background setting is off, or the worker skips it. Settle
  from the account's Settings screen first, then the worker's account selection.

**Affected components / files**: evidence only; a code change only if R-4 finds a mislabeled start (then a one-line
label fix in the start path, both platforms checked).

**Existing behavior relied on**: evidence pull `scripts/pull-phone-screenshots.ps1 -Sprint 78` (adb is unavailable).

**Dependencies / blockers**: Harold's 0.18.0 Play upload and Google's review; Harold's phone time.

**Acceptance criteria**:
- AC-1: Steps 7-11 each recorded PASS / FAIL with the log line or screenshot that proves it.
- AC-2: Errors per account for one day recorded with a class each, or zero; #433 closed or re-scoped.
- AC-3: #428 closed with the reboot evidence, or a failure card filed.
- AC-4: The boot-start receiver named with its log line.

**Tests to write**: T-1 (AC-4, only if a label fix is made) -- TEST-UNIT on the start-reason label.

**Definition of Done**: default DoD; evidence lines in this plan's Phase 5 evidence section.

**Model**: Haiku -- transcription and log reading; session model per the deviation note.
**Step-types**: DOCS (evidence). **Est-Effort**: 40-70m + phone time.

## Task 2 -- F277: Fold energy check, interval 5 against interval 15 (Priority 20)

**Value**: This settles the 5-minute floor with measured energy instead of emulator counts.

**Requirements**:
- R-1: Protocol `docs/research/R76-1_BATTERY_AB_RESULTS.md:216-231` (R77-BAT-1): arms (A) one real account interval
  15, new mail off; (B) interval 5, new mail off; (C) interval 5, new mail on. Screen off, unplugged, 8 hours each,
  same standby bucket and network.
- R-2: Metric: Settings > Battery percent for the app (screenshots over MTP), plus the diagnostic-log scan count.
- R-3: Decision rule: B at most 3x A keeps the floor at 5; above 3x raises `kMinIntervalMinutes`
  (`scan_interval.dart:31`) to 10 and re-runs B; C more than 50% above B raises the new-mail minimum spacing.
- R-4: Android only -- ADR-0042: Windows has no battery cost model for this (plugged-in desktop; Task Scheduler), so no
  Windows arm; any constant change is shared Dart and applies to both platforms.

**Dependencies / blockers**: Task 1 install; three overnight windows (Harold).

**Acceptance criteria**: AC-1: three arms recorded with battery percent and scan counts; AC-2: the decision rule applied
and recorded in the results doc; AC-3: if the floor changes, `scan_interval_test.dart` and the help text change with it.

**Tests to write**: T-1 (AC-3, conditional) -- TEST-UNIT updates in `scan_interval_test.dart`.

**Definition of Done**: default DoD. **Model**: Haiku -- protocol already written; reading screenshots.
**Step-types**: DOCS, SVC-EDIT (conditional). **Est-Effort**: 45-60m + three nights.

## Task 3 -- F282: One "MyEmailSpamFilter" folder for every file the app writes for the user (Priority 7)

**Value**: A user finds every exported file in one named folder in Documents, on both platforms.

**Requirements**:
- R-1 (audit first): already true -- Android defaults to Documents (`export_directories.dart:79-81`); every writer
  except YAML export goes through `ExportDirectories.resolve` (`:143-181`); a chosen folder already wins unchanged
  (`:157`). Not yet true: no `MyEmailSpamFilter` folder; Windows defaults to Downloads (`:67-76`); root CSVs land
  directly in the base; `scan_exports` is not split by environment.
- R-2: The DEFAULT base becomes `<Documents>\MyEmailSpamFilter` (prod) / `<Documents>\MyEmailSpamFilter_Dev` (dev) on
  both platforms, applied inside `platformDefault()` only, so a user-chosen folder is never wrapped (MV-Q13).
- R-3: Windows Documents from the Documents known folder (`path_provider` `getApplicationDocumentsDirectory()`, verified
  against the Microsoft known-folder docs at implementation), `%USERPROFILE%\Documents` only as fallback (MV-Q11).
- R-4: Subfolders per F3; diagnostics resolution (`diagnostic_logger.dart:169-183`) and its F248 "already the
  diagnostics folder" check keep working; `androidDocumentUri` (`:127-136`) maps the new path.
- R-5: `defaultLabel` (`:43-47`) names the folder on both platforms, e.g. "Documents\MyEmailSpamFilter (default)".
- R-6: Help text fixed: `manual_scan_settings.md:8` (says Downloads), `background_scanning.md:12` (says next to the scan
  log), `yaml_import_export.md:1` (says timestamped directory).
- R-7: ADR-0042 `:99` bullet retired; ARCHITECTURE.md `:235-237` updated.

**Affected components / files**: `lib/core/services/export_directories.dart`, `lib/core/services/diagnostic_logger.dart`
(only if F3 changes the subfolder name), three help files, ADR-0042, ARCHITECTURE.md.

**Existing abstraction checked**: `ExportDirectories` (the one resolver; no second copy of the path is added).

**Callers of any guard being changed**: `platformDefault()` is reached only through `resolve` when no folder is chosen
(`:157`) -- callers `results_display_screen.dart:723`, `rules_management_screen.dart:1119`,
`safe_senders_management_screen.dart:777`, `scan_sheet_export.dart:168`, `live_scan_logger.dart:100`,
`diagnostic_logger.dart:169`, and `saveDialogStart` (YAML dialog start, `:110-119`). All get the new default; none gets
it when a folder is chosen.

**User-reachable control**: Settings > General > "Export folder" (`settings_screen.dart:1393-1441`) shows the new
default label and "Reset to default".

**Observable behavior -- before / after**: BEFORE: Windows exports land in Downloads, Android in Documents, loose and
mixed. AFTER: a user who never chose a folder finds every app file under Documents\MyEmailSpamFilter (dev:
MyEmailSpamFilter_Dev) on both platforms; a user who chose a folder sees no change; existing files are not moved.

**Non-functional requirements**: Platform: one shared default (the ADR-0042 exception is removed); the write probe and
app-folder fallback (`:165-176`) stay.

**Acceptance criteria**:
- AC-1: With no folder chosen, `resolve()` returns `<Documents>/MyEmailSpamFilter[_Dev]` on Windows and Android.
- AC-2: With a folder chosen, `resolve()` returns that folder unchanged (no `MyEmailSpamFilter` added).
- AC-3: `scan_exports` and diagnostics resolve inside the new folder per F3.
- AC-4: `defaultLabel` names the folder on both platforms; help text matches.

**Tests to write**: T-1..T-3 (AC-1..AC-3) -- TEST-UNIT updates in `test/unit/services/f206_export_test.dart` (`:69-131`),
`live_scan_logger_test.dart:212-239`, `f245_export_dedup_test.dart`, `f248_*`; T-4 (AC-4) -- TEST-WIDGET
`f248_settings_log_location_test.dart:84-89`. Mutation-check AC-2 (a wrap of the chosen folder must fail a test).

**Definition of Done**: default DoD plus ADR-0042 and ARCHITECTURE.md updated in the same commit.

**Model**: Haiku -- one resolver change with named tests; delegation checklist included.
**Step-types**: SVC-EDIT, TEST-UNIT, CONTENT, DOCS. **Est-Effort**: 50-80m (Phase 3.2.2.2: 60-90m -> 50-80m; Android
default and single resolver already exist).

**Status (2026-10-10)**: code, tests, help, ADR-0042, ARCHITECTURE.md and CHANGELOG DONE; Manual Validation on both
platforms pending. Evidence: 100/100 in the seven export and log test files; mutations F282-M1..M4 all KILLED (chosen
folder wrapped, default without the app folder, default diagnostics suffixed, fallback without the app folder);
policy 146/146; analyzer clean. Windows Documents source verified: `path_provider_windows` 2.3.0
`path_provider_windows_real.dart:123-124` (`WindowsKnownFolder.Documents`). Found on the way: the unwritable-default
fallback on Windows is Documents itself, shared by DEV and PROD, so it now also gets the app folder (M4).
**Executed-by**: Opus 5.5 (session model) -- single interactive session, deviation note (a).
**What the tests do NOT catch**: that the real Documents folder is writable on a device (scoped storage on Android, a
OneDrive-redirected Documents on Windows); the resolver runs on a test override. Manual Validation checks both.

## Task 4 -- F281: Best-practice UI for "run every <interval>", then the chosen implementation (Priority 6)

**Value**: The interval control reads naturally and offers only intervals that make sense.

**Requirements**:
- R-1 (research, Fable/Opus): at least 3 alternatives, each with a mockup, pros, cons, Windows + Android fit (one
  shared control) and cited sources; a recommendation. Harold picks one (Q-S2).
- R-2: Every alternative: minimum 5 minutes (`kMinIntervalMinutes`, `scan_interval.dart:31`), maximum 24 hours (change
  from `kMaxIntervalMinutes = 99 * 60`, `:34`, and `kMaxIntervalNumber`, `:37`, message `:79`), default 15 the first
  time shown (`settings_store.dart:79`), more than a short preset list, save-on-change (MV-Q3; no Save button).
- R-3: Shown ONLY when a background mode is on: Windows `background_enabled`; Android `background_enabled` or
  `new_mail_trigger` (`settings_store.dart:592-617`). This reverses the F264 R-11 choice
  (`settings_screen.dart:1643-1647`) at Harold's request. Saved value per F2.
- R-4: Stored values above 24 hours per F1, through `reconcileAccountInterval` (`f264_upgrade_migration.dart:28-45`),
  called at settings load (`settings_screen.dart:519`) and Windows startup (`main.dart:392-404`); the migration sentinel
  (`:80`) does not re-run, and does not need to.
- R-5: Help `background_scanning.md:8` ("longest is 99 hours") and `help_platform_claims_test.dart:98-99` updated.

**Affected components / files**: `lib/ui/widgets/scan_interval_control.dart`, `lib/core/services/scan_interval.dart`,
`lib/ui/screens/settings_screen.dart:1643-1672`, help, ADR-0039.

**Callers of any guard being changed**: `ScanInterval.validate` / `nearestValid` callers -- the control
(`scan_interval_control.dart:100-116`), `_updateScheduledScan` (`settings_screen.dart:1503-1509`),
`reconcileAccountInterval` (three call sites above). A lower maximum makes each clamp to 24 hours; schedulers receive
at most 1,440 minutes (Windows repetition trigger and Android alarm both accept it).

**User-reachable control**: Settings > Account tab > Background > "Scan every".

**Observable behavior -- before / after**: BEFORE: a unit drop-down and a 2-digit box, shown even when background
scanning is off, up to 99 hours. AFTER: the chosen control, shown only when a background mode is on, 5 minutes to 24
hours, 15 minutes suggested first.

**Acceptance criteria**: AC-1: research document committed with 3+ alternatives and sources; AC-2: entries below 5
minutes and above 24 hours cannot be saved; AC-3: hidden with every background mode off, shown when one is on, on both
platforms; AC-4: a stored 99-hour value reads as F1 decides; AC-5: help matches.

**Tests to write**: T-1 (AC-2) -- TEST-UNIT `scan_interval_test.dart` (replace the 99-hour literals at :26-87); T-2
(AC-3) -- TEST-WIDGET `f264_interval_control_test.dart` (rewrite :196 "background OFF" and :244-252 both platforms);
T-3 (AC-4) -- TEST-UNIT `f264_upgrade_migration_test.dart`; T-4 (AC-5) -- policy test update.

**Definition of Done**: default DoD plus ADR-0039 amendment. **Decision (Q-S2, Harold 2026-10-10)**: Alternative D -- preset drop-down (5, 10, 15, 30 minutes; 1, 2, 4, 12, 24
hours) plus "Custom..." (number + unit dialog, Save disabled until 5 minutes to 24 hours). Harold: *"Adopt any other
sprint Tasks around this decision"* -- checked: F277 arms (5 and 15 minutes) and the R76-4 Windows DEV background
interval (15 or 5 minutes) are both presets, so neither task changes; no WinWright script touches the interval control
(grep of `test/winwright/` for "interval" and "Scan every": none), so F284 does not change; help text and ADR-0039
amendment item 3 updated.

**Status (2026-10-10)**: DONE except Manual Validation. Research b6b2a55; part 1 (24-hour maximum, shown only with
background on) e5495c5; part 2 (control D). Evidence: interval widget tests 13/13, interval unit tests pass;
mutations F281-M1..M3 and F281D-M1..M4 all KILLED. Visibility rule: "this account's background scanning is on" is the
complete rule on Android too -- the worker skips an account whose background is off, notification runs included
(`android_background_scan_worker.dart:205-216`), so the new-mail switch needs no rule of its own (R-3 simplified;
same user-visible behavior). **Executed-by**: Opus 5.5 (session model) for research and implementation --
single-session deviation note (a).

**Model**: research Fable/Opus (mandatory,
`SPRINT_PLANNING.md:94-110`); implementation Sonnet -- why not Haiku: control design depends on the pick and touches
visibility logic on two platforms.
**Step-types**: DOCS (research), UI-NEW, TEST-WIDGET, TEST-UNIT. **Est-Effort**: 150-270m (research 90-120, implementation
60-150 depending on the pick).

## Task 5 -- F284: WinWright without taking over the laptop (Priority 20)

**Value**: The sweep runs while Harold uses the PC, or with it locked, and passes the same way on any monitor.

**Requirements**:
- R-1 (a): `Semantics(button: true, ...)` on the Review account drop-down face (`no_rule_review_screen.dart:851,880`;
  the Results screen has none) and on the Settings tab labels the scripts click (`settings_screen.dart:636-639`),
  following the Sort chip pattern (`results_display_screen.dart:1897`); no visual change. This is shared UI code, so it
  also gives Android TalkBack a button (parity benefit).
- R-2 (a): CheckBox steps -> `ww_set_checked` (s75 `:64,66`); hover steps (s75 `:69-70`) -> tooltip reads if UIA exposes
  them (probe first, 45-minute WINWRIGHT-DISCOVERY time-box); f124/f37/f56 `ww_click` steps -> pattern steps.
- R-3 (a): the runner's unconditional locked-PC refusal (`run-winwright-tests.ps1:231-263`) allows a run when every
  selected script is pattern-only; a script with any `ww_click` still refuses.
- R-4 (b): retire `test_mt2c_no_rule_sweep.json` and `scripts/winwright-seed-no-rule.ps1` and the runner's seed/unseed
  hooks (`:423-435`, `:518-521`); its contract stays covered by `no_rule_review_screen_test.dart:693-754`; README
  (`:99-106,134,228`) updated.
- R-5 (c): the runner sets a fixed window size after launch (replacing per-script maximize) and records display size
  and window size in the summary (`:555-573`).
- R-6: ADR-0042: WinWright is Windows-only tooling (no Android equivalent); Android UI coverage stays widget tests plus
  Fold Manual Validation -- declared exception, testing layer.

**Callers / tooling that launches or kills the executable**: the runner's `Ensure-FreshAppAtHome` (`:167,447`) --
unchanged except the window-size step after launch.

**Acceptance criteria**: AC-1: zero `ww_click` steps in the default sweep; AC-2: the sweep passes with the PC locked;
AC-3: the summary records display and window size; AC-4: mt2c and its seed script are gone and the README says why.

**Tests to write**: T-1 (AC-1) -- extend `test/policy/winwright_script_strings_test.dart` to fail on any `ww_click` in a
default-sweep script; T-2 (R-1) -- TEST-WIDGET asserting the account face exposes a button semantics node; T-3
(AC-2) -- the locked-PC run itself, recorded.

**Definition of Done**: default DoD. **Model**: Sonnet -- why not Haiku: harness constraints are found only by failing
runs (CODING_VELOCITY WINWRIGHT-DISCOVERY).
**Step-types**: WINWRIGHT-SCRIPT, WINWRIGHT-DISCOVERY (time-box), HOOK (runner), UI-MOVE. **Est-Effort**: 90-140m.

## Task 6 -- F283: Review No Rule Items looks and works like the Results screen, across all accounts (Priority 8)

**Value**: A user finds one email among hundreds by typing part of it, and the screen behaves like the Results screen
they already know.

**Requirements**:
- R-1 (audit first): already true -- the account drop-down defaults to All (`no_rule_review_screen.dart:67`) and lists
  every saved account including zero counts (`:837`); rows come from every saved account
  (`unmatched_email_store.dart:398-411`). Not yet true: summary, chip row, filter bar, folder/date row format, search,
  detail popup (Review has none; tapping selects, `:1054`).
- R-2: Extract the Results pieces into shared widgets on one shared row model (an adapter from `UnmatchedEmail` and
  from `EmailActionResult`): summary header (`_buildSummary :1388`), chip row (`:1545-1617`: Folders `:1941`, Sort
  `:1894`), "Showing X of Y" bar (`:1331`), row tile (`:2042-2071`), search (`:847-861`, `:950-997`, `:1067-1085`), and
  the detail popup (`:2099-2870`). Results keeps identical behavior (Sprint 52 IMP-5: one copy).
- R-3: Review: account drop-down styled like "Folders", ALWAYS shown (MV-Q14; today hidden with one account, `:798`),
  then Folders, then Sort; the "No rule" chip per F4.
- R-4: Search over sender, subject and folder (the shared search also matches rule name, which is empty on Review).
- R-5: Multi-select and bulk actions removed (MV-Q16): `_selectedIds` (`:73-74`), `:325-412`, `_runBulkAction` and the
  three bulk handlers (`:422-701`), selection bar and bulk menu (`:908-1003`), row checkbox, right-click menu
  (`:1060`, `:1133-1182`).
- R-6: Detail popup on BOTH screens shows the account email in place of the domain next to the date/time (MV-Q17;
  today `:2440-2466`); actions per F6.
- R-7: `email_detail_view.dart` is KEPT (F5, Harold 2026-10-10: "keep it for 5 sprints then ask again"; re-ask at
  Sprint 83 planning, F285 HOLD in the master plan); help `review_no_rule_items.md:5-11` rewritten (it describes
  multi-select).
- R-8: F4 = 1 with Harold "pretty sure": the first screenshot of the new Review chip row ("No rule (N)" fixed, then
  account, Folders, Sort) goes to Harold before the rest of the screen is built; work continues while he looks.

**Affected components / files**: `results_display_screen.dart` (4,632 lines), `no_rule_review_screen.dart` (1,183
lines), new shared widgets under `lib/ui/widgets/`, help, tests.

**Existing abstraction checked**: `ProviderGroupHeader`/`ProviderGroupEnd`, `formatReceivedDayForRow`,
`AccountEmailLabel` (`account_email_label.dart:17`) -- reused; no shared row widget exists today.

**Callers of any guard being changed**: the popup's action handlers (`_quickActionThenAdvance`,
`_getEffectiveEvaluation`, `_buildSkipButton`) become callbacks; Results passes its existing ones (no behavior change,
pinned by the existing Results tests), Review passes its single-row action path.

**User-reachable control**: Scan History / Settings > "Review No Rule Items" (existing entry points), search icon and
Ctrl+F on that screen.

**Observable behavior -- before / after**: BEFORE: a plain list with checkboxes, bulk menu, account chip only with 2+
accounts, no search, no detail popup. AFTER: the Results layout -- summary, account / Folders / Sort chips, "Showing X of
Y emails", folder-date-subject rows, search, a tap opens the Results-style popup naming the account email; no
checkboxes.

**Non-functional requirements**: Account-scoping: the account filter reads saved accounts, per row account id;
Accessibility: chip faces keep button semantics (F284 R-1); Platform: one shared screen, touch long-press paths removed
with multi-select on both platforms.

**Acceptance criteria**:
- AC-1: Given 3 accounts and 398 rows, When the user types part of a subject, Then only matching rows show and the bar
  reads "Showing X of 398 emails".
- AC-2: The account drop-down shows with one saved account and lists every saved account with its count.
- AC-3: No checkbox, selection bar or bulk menu on either platform.
- AC-4: Tapping a row opens the popup with the account email next to the date/time; same on Results.
- AC-5: Every existing Results test passes unchanged (behavior preserved by the extraction).
- AC-6: The MT-2c contract (sweep never drops uncovered rows) holds, counted from "Showing X of Y" instead of the
  removed "2 items" (`no_rule_review_screen_test.dart:747`).

**Tests to write**: T-1 (AC-1) TEST-WIDGET search on Review; T-2 (AC-2) rewrite `no_rule_review_account_dropdown_test.dart`
(drop `:158` selection clearing); T-3 (AC-3) delete `no_rule_review_touch_selection_test.dart` and the bulk tests in
`no_rule_review_screen_test.dart` (`:292,320,385,510,761`), add an absence test; T-4 (AC-4) TEST-WIDGET popup account
email on both screens; T-5 (AC-6) rewrite `:693-754`. Each states what it does NOT catch.

**Definition of Done**: default DoD; Windows and Android screenshots of the new screen at Manual Validation; the
0xc0000409 crash recurrence recorded.

**Model**: Sonnet for the extraction -- why not Haiku: a behavior-preserving extraction out of a 4,632-line screen with
state-bound callbacks; Haiku for the test rewrites once the widgets exist.
**Step-types**: UI-NEW (x5 extracted widgets), UI-MOVE, TEST-WIDGET (x5), CONTENT. **Est-Effort**: 300-420m (Phase
3.2.2.2: 150-210m -> 300-420m; the popup and every Results piece are private and state-bound, Review has no popup, and
the row types differ).

**Status (2026-10-10)**: code, tests, help, ARCHITECTURE.md and CHANGELOG DONE; Windows/Android screenshots, the F4
chip-row check with Harold and Manual Validation pending. Commits: step 1 21de960 (list pieces shared), step 2 35f9ecd
(pop-up shared, R-6), step 3 (Review rebuilt). Evidence: Results/Review test files 389/389 after the rebuild plus the
new search/advance tests (Review file 16/16 + 2); policy 147/147; mutations F283-M1..M3 and F283-RM1..RM4 all KILLED
(RM4 first SURVIVED: the rewritten stale-summary test matched a list row instead of the SnackBar; fixed to read the
SnackBar). AC-5 note: `f230_f231_action_sheet_test.dart` (source-text) was retargeted at the shared pop-up file -- its
guarantees are unchanged; every other Results test passes unchanged. `no_rule_review_touch_selection_test.dart` deleted
(multi-select removed); `NoRuleMarkReason.popupAction` added. Decision recorded: the Review default sort is the Results
default (Folder), not the old newest-first. **Executed-by**: Opus 5.5 (session model), deviation note (a).

_**Risk & rollback**_: regression on the Results screen; mitigated by AC-5 (existing Results suite unchanged) and the
5.1.5 WinWright sweep; rollback is one revert of the extraction commit, kept separate from the Review rewrite commit.

## Task 7 -- R76-4: Content history in dev builds only (Priority 5; Class-1 exception approved 2026-10-09, reshaped 2026-10-10)

**Value**: This builds the labeled history that later heuristic, rule-mining and ML items need (F267-F272). It uses
Harold's own mail only, on his Windows DEV install, and no customer build can ever capture.

**Requirements** (shape per Harold's 2026-10-10 answers):
- R-1: ADR-0047 is written FIRST, as dev-only tooling. It covers the exception and its limit (dev builds only), the
  fields, identity, storage, retention and deletion, and the F273 precondition for any customer build.
- R-2: Gate: capture runs only when `AppEnvironment.isDev` (`app_environment.dart:29`) is true AND the Settings > General
  "Content history" switch is on. The switch defaults to off. It is a dev-environment check in shared code, not a
  platform branch, so a dev Android build behaves the same way (ADR-0042 parity). Today it runs on Harold's Windows DEV
  install only.
- R-3: Capture at the one shared choke point (`email_scanner.dart` `evaluateBatch`, `:384-470`), placed BEFORE the
  safe-sender `continue` at `:438`, so no outcome is missed.
- R-4: Unique emails only, decided from headers (Harold, 2026-10-10: *"ensuring it only writes unique emails as it will
  see many, many duplicates ... if it can see duplicates without pulling the full email then that is preferrable - only
  pull full email if not in DB"*).
  - Identity: SHA-256 of the RFC 5322 Message-ID plus the account. The Message-ID already arrives with the headers the
    scan fetches today (IMAP `generic_imap_adapter.dart:2107-2114`, Gmail `gmail_api_adapter.dart:1217-1221`), so the
    duplicate check costs no extra fetch. The fallback when a message has no Message-ID is the provider id plus folder.
  - Order per email: compute the identity from headers, look it up in `content_history.db` (one indexed lookup per
    batch), and fetch the body ONLY when the identity is absent.
  - A repeat sighting writes no new row and fetches nothing. It only updates "last seen" (date and folder) and the
    outcome when that changed, for example the same email seen in Inbox and later in Trash after the Fold deleted it.
- R-5: Fields per R3 = 1: header fields, outcome label, and plain-text body (HTML converted), capped at 64 KB. One body
  fetch per new message, through a new content method on the provider interface (`spam_filter_platform.dart:57`).
  - IMAP (`generic_imap_adapter.dart:2043-2123`) and Gmail (`gmail_api_adapter.dart:1155-1207`) both implement it.
  - When there is no text part, HTML is converted to text. Nested multipart is walked.
  - The existing `fetchFullBody` used by body rules does NOT change.
  - Demo and mock adapters get a named no-op.
- R-6: Outcome label: the scan outcome at capture, then the user's final decision from the existing Results and Review
  action paths, with its date.
- R-7: Storage per R4 = 1: `content_history.db` beside `spam_filter.db` in the dev data folder, so capture writes
  straight to the PC (R6 answer; no export this sprint). Retention per R5 = 1: kept until deleted.
- R-8: Deletion:
  - "Remove an account" deletes that account's rows; "delete all data" deletes the file (`data_deletion_service.dart:57-140`,
    `database_helper.dart:1527-1538`).
  - R7 = 1: also fix the pre-existing gaps. "Remove an account" misses `account_folder_cursors` and
    `background_scan_log`. "Delete all data" misses `unmatched_emails`, `background_scan_log`,
    `account_folder_cursors` and `auth_rate_limit`.
  - Prevention: a policy test asserts that every table holding account data is in both paths.
- R-9: Control (dev builds only): Settings > General > "Content history" switch, with the stored count and a "Delete
  content history" button beside it.
- R-10: Policy per R8 = 1: no customer-facing text changes. `data_safety_declarations_test.dart` stays green. A new
  policy test asserts that capture cannot run and the switch is not shown when `APP_ENV` is not `dev`.

**Affected components / files**: `email_scanner.dart`, `spam_filter_platform.dart`, `generic_imap_adapter.dart`,
`gmail_api_adapter.dart`, new `content_history_store.dart` (+ gate), `data_deletion_service.dart`, `database_helper.dart`
(deletion gaps only), `settings_screen.dart` (General tab, one row), ADR-0047, ARCHITECTURE.md, CHANGELOG.

**Existing abstraction checked**:
- `AppEnvironment.isDev` is reused as the gate. It already gates the dev seeder (`dev_environment_seeder.dart:30`) and the
  `_dev` export suffix (`scan_sheet_export.dart:81`).
- `EmailScanner` choke point.
- The `ScanSheetExport` SHA-256 helper (`scan_sheet_export.dart:68-69`) is reused for hashing.
- `DataDeletionService` is extended, not copied.

**Existing behavior relied on**:
- Both providers fetch headers without bodies (`generic_imap_adapter.dart:2003-2006`, `gmail_api_adapter.dart:581,688`).
- The Store MSIX and the Play AAB are built with `APP_ENV=prod`; the Fold log reads `env=prod platform=android`
  (2026-10-09 13:33).
- Windows DEV stays read-only. Harold will turn its background scans ON, read-only, every 15 or 5 minutes for all four
  accounts (2026-10-10), so capture runs on those background scans as well as manual ones. Both pass through
  `evaluateBatch`.

**Callers of any guard being changed**: the new gate is consulted only by the capture call and the Settings row. With
the gate off, `evaluateBatch` behavior is byte-for-byte today's (pinned by a test).

**User-reachable control**: Settings > General > "Content history" (dev builds only).

**Observable behavior -- before / after**:
- BEFORE: nothing beyond a 100-character preview is kept.
- AFTER, in a dev build with the switch on: each scanned email is kept once, with its fields, body text and outcome.
  Settings > General shows the count and a Delete button.
- Prod builds and every customer see no change.

**Dependencies / blockers**: none from Harold (no secrets key needed). Coverage: the Fold acts on mail every 15 minutes.
Harold closes that gap by running Windows DEV background scans read-only at 15 or 5 minutes for each of the four
accounts (2026-10-10). Expect many repeat sightings; R-4 makes them header-only.

**Non-functional requirements**:
- Security: the history file is plaintext SQLite like the main DB (SEC-11b on HOLD); ADR-0047 records this.
- Platform: shared Dart, gated by environment, not platform; no ADR-0042 exception.
- Performance: one extra body fetch per NEW email while the switch is on. The F177/F180 memory limits are respected (one
  message at a time).

**Acceptance criteria**:
- AC-1: In a prod build, the switch is absent, no file is created, and no extra fetch happens (test).
- AC-2: In a dev build with the switch on, a scan of N new emails stores N rows and fetches N bodies. A second scan of
  the same emails stores 0 rows and fetches 0 bodies. The same email seen in another folder (Inbox, then Trash) stores
  0 rows, fetches 0 bodies, and updates its last-seen folder.
- AC-3: An HTML-only message stores readable text; a nested multipart Gmail message stores its text part.
- AC-4: A user action on a stored email updates its outcome label.
- AC-5: "Remove an account" deletes that account's rows and the R7 tables. "Delete content history" empties the history.
- AC-6: `data_safety_declarations_test`, the prod-inert policy test and the deletion-coverage policy test pass.

**Tests to write**:
- T-1 (AC-1): TEST-UNIT, prod-inert gate.
- T-2 (AC-2): TEST-UNIT, capture and dedup, with a mock adapter that counts fetches.
- T-3 (AC-3): TEST-UNIT, content extraction for both adapters on fixture MIME and Gmail payloads.
- T-4 (AC-4): TEST-UNIT, outcome update.
- T-5 (AC-5): TEST-UNIT, deletion paths plus the table-coverage policy test.
- T-6 (AC-6): policy tests.
- T-1 and T-2 are mutation-checked.

**Definition of Done**: the default DoD, plus:
- Harold accepts ADR-0047 before the capture code merges.
- A manual scan on Windows DEV with the switch on shows a non-zero count.

**Model**: ADR-0047 Fable/Opus (mandatory). Implementation Sonnet; why not Haiku: a new store, a provider-interface
member on two adapters, and deletion paths across 6+ files. Tests Haiku.
**Step-types**: DOCS (ADR), SVC-NEW, SVC-EDIT, IMAP, UI-NEW (one row), TEST-UNIT.
**Est-Effort**: 315-470m.
- ADR 45-70; gate and switch 10-15; store 30-45; capture and content fetch 60-100; outcome 30-45.
- Control row 30-45; deletion 15-25 plus R7 gaps 30; tests 50-75; docs 15-20.
- Was 330-505m +30m. The secrets gate, the export and the per-account controls are gone.

_**Risk & rollback**_: the capture path runs inside every scan. Mitigations:
- AC-1: gate off means no change.
- Capture runs in a try/catch that logs and never fails the scan.
- Rollback: turn the switch off, or revert.

_**Decision-class interrupts**_: any change to the stored fields, or to which builds can capture, is a new Class-1
question.

## Task 8 -- F199-b: Partner Center publisher display name -> repo synced, card to HOLD (Priority 12)

**Value**: This makes every repo record say what Partner Center actually holds, and parks a card that has no business
reason to move now.

**Requirements** (Harold, 2026-10-10; verbatim in the decisions section):
- R-1: Every repo record of the Windows Store publisher name matches Partner Center: `Kimmey Consulting - Ohio`.
  - `LEGAL_ENTITY.md:43`, which wrongly says the repo holds `Kimmey Consulting LLC`.
  - Its "ask support" text at `:77-80` and `:155-157`.
  - `STORE_LISTING_ASSETS.md:7`.
  - The `pubspec.yaml:132-139` comment. The value at `:140` is already correct.
- R-2: The sprint task is closed. The master-plan card moves to HOLD with Harold's reason: *"no real business is being
  done by either entity and will resolve later."* Trigger: Harold reopens it (business activity starts, or Microsoft
  raises the name).
- R-3: `msix_config.publisher` and `identity_name` are never touched.

**Affected components / files**: `docs/LEGAL_ENTITY.md`, `docs/STORE_LISTING_ASSETS.md`, `mobile-app/pubspec.yaml`
(comment only), `docs/ALL_SPRINTS_MASTER_PLAN.md`.

**Acceptance criteria**:
- AC-1: A grep of `docs/` and `pubspec.yaml` finds no record saying the Windows Store publisher name is `Kimmey Consulting
  LLC`.
- AC-2: F199-b sits in the master plan HOLD section with the reason and the trigger.

**Tests to write**: none (docs); `msix_config_test.dart` stays green.
**Definition of Done**: None -- default DoD only. **Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: 10-15m.

**Status**: R-1 and R-2 DONE 2026-10-10, before approval, at Harold's direct instruction (docs only; `pubspec.yaml`
change is a comment). **Executed-by**: Opus 5.5 (session model) -- done in the planning turn because Harold asked for it
directly.

