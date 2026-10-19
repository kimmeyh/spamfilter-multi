# Sprint 80 Plan

**Status**: DRAFT, awaiting Phase 3.7 approval and the decision questions below. Scope selected by Harold at Phase
8.4 pass 2 (2026-10-18).
**Branch**: `feature/20261018_Sprint_80` | **PR**: #490 (draft until the end of 7.7)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads this turn; file:line
evidence is in each card.

## Objective

Finish the phone checks on the 0.20.0 closed-test build (Fold steps, F205 errors, the F277 battery arms, the Fix 2
decision, whether the plugin upgrade ended the scans that die within 30 s); put every platform difference behind one
capability seam with an ADR, and write the iPhone parity ADR from vendor documentation; keep CI on the local Flutter
version; make rule and safe sender edits take effect at once; and build the first rule-learning tools (an evaluation
harness, a PC-side rule miner and a merge import).

**Scope (Harold, 2026-10-18, verbatim list)**: MV76-1, F292, F294, F295, F296, F298, F205, F277, F267, F268, F269, F289,
F299. Annotated separately: F276 *"Hasn't this been resolved?"*, F247 *"Close - will re-open if they re-occur"*, F204
*"Hasn't this been resolved"*, and F299 *"Hasn't this been resolved"*. Each note is read as applying to the item above
it. Answers are in "Harold's four notes" below.

**Parity (Harold, 2026-10-18, verbatim)**: *"everything needs to take into account both the Windows App and the Android
app and ADR stating that everything should be functionally and UI the same unless it cannot be - and where it cannot be
it should be implemented as a platform exception for what is needed -- this applies to all backend code, frontend code,
data, architecture, development, security, testing, deployment."* Every card has a **Parity (ADR-0042)** line naming
the Windows path and the Android path, and either claims parity (naming the OS behavior assumed identical) or declares
the exception and what the other platform does instead.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control before creating a new one, then the instance fix.

## Harold's four notes -- answers (evidence read 2026-10-18)

- **F299 "Hasn't this been resolved"**: partly, and not proven. The card's recorder is not built:
  `getHistoricalProcessExitReasons` / `ApplicationExitInfo` appear nowhere in `mobile-app/android` or `lib/`. What DID
  ship is the Sprint 79 upgrade to workmanager 0.10.10 (`pubspec.lock:1214`, workmanager_android 0.10.9 at `:1222`),
  first released to users in 0.20.0. Its changelog says it fixes *"background tasks no longer fail ~30 seconds after
  start on Android 16 when the Dart isolate boots slowly"* (#738), which matches the 11 class-B scans. The source keeps
  a 30 s watchdog (`BackgroundWorker.kt:47` `DART_INITIALIZATION_TIMEOUT_MILLIS = 30_000L`, armed at `:195-209`) that
  now fails the task only if Dart never signals ready. The class-B rows were all on 0.18.0 and 0.19.0. So the cause may
  be fixed, and the 0.20.0 phone logs decide it. Proposal: Task 12 is verify-first (Q5).
- **F276 "Hasn't this been resolved?"**: no. `UnmatchedEmailStore.updateAvailabilityStatus`
  (`unmatched_email_store.dart:487`) still has no caller in `lib/`, and `EmailAvailabilityChecker` is never constructed,
  so every No Rule row stays `unknown` and mail deleted or moved in the mail app stays listed. What did ship is F245
  (Sprint 77, CHANGELOG line 124): one row per email instead of one per scan. That is probably what you remember.
  Card written below as Task 13, pending Q6.
- **F247 "Close - will re-open if they re-occur"**: done. The master-plan card is marked CLOSED with your words and
  date; the text is kept for a re-open. Not in scope.
- **F204 "Hasn't this been resolved"**: not as a repo gate. Nothing under `mobile-app/test/policy/` or the build
  scripts asserts `targetSdk`, `AD_ID` or 16 KB alignment (grep, 2026-10-18; `build.gradle.kts:45` still reads
  `targetSdk = flutter.targetSdkVersion`). The AD_ID and package checks you saw at each release are a scratchpad script
  I run by hand (`verify_aab.py`), so they depend on me remembering. Gap 3 (16 KB) is not due until 2027-02-01. Card
  written below as Task 14 (gaps 1 and 2 only), pending Q7.

## Carry-ins (from the stub, kept)

- **0.20.0 store updates**: SUBMITTED to both stores, in process (Harold, 2026-10-18 ~11:39pm ET). Not yet observed
  live. Still open: whether 0.19.0.0 went live on the Microsoft Store (Q8).
- **Fix 2 decision** (inside Task 1): on the 0.20.0 Fold build, look for `stopped by WorkManager before it finished:
  reason=... raw=...` in the diagnostic log; Harold then decides whether the native Application-class hook (Fix 2,
  `SPRINT_79_PLAN.md:302-327`) is needed.
- **Sprint 79 retro IMPs live**: IMP-1 (every MV number, interval, path or count read from the live system during the
  5.1.9 rehearsal, source named); IMP-2 (the phone pull collects `_Device care` and `_Settings`); IMP-3 (a package
  claim cites its pub-cache source at the resolved version -- applied to F299 above).
- **Open items**: the emulator dev app still has the 60 s diagnostic hold until the next dev build installs over it;
  the s75 WinWright launch failed once in the Sprint 79 sweep and passed alone (cause unknown; candidate: the
  single-instance mutex) -- watch the first Sprint 80 sweep.

## Tasks, order, models and estimates

Estimates are minutes from the `CODING_VELOCITY.md` Estimate Table, set at the low end of each band: the last trend
row (Sprint 78) is 0.23, so planned cards ran about 4x under. `[no-history]` marks a step-type with no samples.

- **Task 0 -- Version bump 0.21.0+18** (3.7.0b). MINOR: F269 is a user-facing `feat`. Same commit: "Last uploaded to
  Play" -> 0.20.0 (versionCode 17), the CHANGELOG `[Unreleased]` 0.20.0 content under a `## [0.20.0] - 2026-10-18`
  heading, provisional 0.21.0 notes. Haiku. 10-15m.
- **Task 1 -- MV76-1 + F205 + Fix 2 decision** (#471, #433, #428): the Fold remainder on 0.20.0. Session model.
  40-70m + phone time.
- **Task 2 -- F277** (#472): arm A second night, arm C, the decision rule, the 0.3% versus 1.5% spread. Haiku
  analysis. 30-45m + nights.
- **Task 3 -- F292 remainder** (new card): re-scoped by 3.2.2.1 -- see the card and Q4. Sonnet. 10-60m.
- **Task 4 -- F294**: ADR-0049 and one `PlatformCapabilities` seam; 65 checks in 21 files move behind it; a policy
  test refuses new bare checks. Class 1 (Q1). 4a ADR and seam design: Fable/Opus 40-60m; 4b migration: Sonnet
  60-110m; 4c policy test: Haiku 10-20m. Total 110-190m.
- **Task 5 -- F295**: iPhone readiness research, ADR-0050 with each iOS parity exception, the F67/F95 card list.
  Fable/Opus (research spike + ADR, by rule). Time-box 90-120m.
- **Task 6 -- F296**: CI Flutter 3.38.5 -> 3.47.4, one recorded version, a policy test (Q3). Haiku, escalate to
  Sonnet if CI goes red on the new version. 20-45m.
- **Task 7 -- F298**: rule and safe sender edits reload `RuleSetProvider` (9 write sites in 5 screens). Sonnet.
  30-60m.
- **Task 8 -- F267**: rule evaluation harness (Dart CLI). Sonnet. 60-100m.
- **Task 9 -- F268**: PC-side rule miner over the Windows DEV content history. Sonnet. 60-120m. After Task 8.
- **Task 10 -- F269**: YAML import "Merge" beside "Replace". Class 2 (Q2). Sonnet. 45-75m.
- **Task 11 -- F289**: BLOCKED on upstream (WinWright 3.1.0 of 2026-06-10 is the latest release; the trigger has not
  fired). See Q4b. 0-60m.
- **Task 12 -- F299**: verify-first on the 0.20.0 logs; build the exit-reason recorder only if class-B rows recur (Q5).
  10m check; recorder Sonnet 45-75m if needed.
- **Task 13 -- F276** (pending Q6): No Rule rows marked gone when an action fails "not found". Sonnet. 40-60m.
- **Task 14 -- F204 gaps 1 and 2** (pending Q7): assert `targetSdkVersion >= 36` and no `AD_ID` from the built AAB.
  Haiku. 25-40m.
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 150-250m. Sprints 70, 76 and 78 each spent as much or more on this as on planned cards.

**Total**: Tasks 0-12 about 525-1,020 minutes, plus 65-100 if Q6 and Q7 add Tasks 13 and 14, plus the 150-250
unplanned allowance, plus Harold's phone time and nights. This is about double the slate recommended at 8.4; the
number is stated so the size is visible, not to de-scope.

**When can Harold come back (first Manual Validation handoff)**: about 6-9 hours of wall-clock after approval if run
serially; Tasks 4b, 7, 8, 10 and 6 can run as parallel sub-agents (different files), which brings it to about 4-6
hours. Phone work (Task 1, Task 2 nights) runs alongside from the start.

**Order**:
1. Task 0 and the cards (3.7.0, 3.7.0b), then 3.7.1.
2. Phone work starts at once on the Play-installed 0.20.0 (when Play shows it): Task 1 by day, Task 2 by night. The
   two cannot overlap: Task 1 needs AOL, Yahoo and iCloud on; the battery nights need ONE account (AOL) on. Task 12's
   check reads the same pulled logs.
3. Task 4a (ADR-0049) first among code tasks: Task 7, Task 10 and Task 13 touch screens that hold platform checks
   (`settings_screen.dart`, `yaml_import_export_screen.dart`, `rules_management_screen.dart`,
   `safe_senders_management_screen.dart`), so they land after 4b or are written against the seam.
4. Task 5 (research) and Task 6 (CI) fill waits; Task 8, then Task 9.
5. Task 3 and Task 11 per their answers.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b) where possible,
otherwise (a), recorded once): the independent coding tasks (4b, 6, 7, 8, 10, 14) are delegated to sub-agents on their
assigned tier before Manual Validation, with the delegation checklist verbatim. Phone feedback interleaves with the
rest, so anything not delegated runs on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand + pr-review-toolkit code-reviewer and silent-failure-hunter) when
the retrospective improvements are complete. The 7.7.1 size limit applies to review fixes, not to planned work.

**Cards**: created at Phase 3.7.0, the first action after approval, because the questions below change card content.
Reused, not duplicated: #471 (MV76-1), #433 (F205), #428 (MV74-1), #472 (F277). New: F292 remainder (#486 closed on
the Sprint 79 merge), F294, F295, F296, F298, F267, F268, F269, F289, F299, and F276 / F204 if Q6 / Q7 include them.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md:473-484`), so they are not asked
again: (a) Task 6 -- the edit to `.github/workflows/ci.yml` (shared infrastructure) and, if Q3 = 1, the pubspec
`environment: flutter:` pin; (b) Task 0 -- the version bump. No dependency version changes are planned.

## Phase 3.2.2.1 branch-state verification (summary)

Findings that changed scope or estimate:

- **F292: the post-reboot runs already exist, and the page file never grew.** Last boot 2026-10-16 12:02:28
  (`Win32_OperatingSystem.LastBootUpTime`); page file still 30,840 MB (`Win32_PageFileUsage.AllocatedBaseSize`, same
  as the Sprint 79 card). Four `run-full-suite.ps1` runs since that reboot, all green with 0 load failures:
  `79-5.2` (10-17 23:44, 3,061 passed, peak commit 52.16 GB), `79-771` (10-18 08:56, 3,075, 50.22 GB), `79-771b`
  (10-18 11:09, 3,088, 51.58 GB), `79-771c` (10-18 13:34, 3,092, 52.22 GB) (`%TEMP%\full-suite-runs\results.txt` and
  log names). Nine runs in all since the containment, none reproducing. Task 3 re-scoped (Q4).
- **F294: 65 bare checks in 21 files, not 68.** `grep -c "Platform.is(Android|Windows|IOS|MacOS|Linux)"` over
  `lib/`: `main.dart` 11, `app_theme.dart` 10, `settings_screen.dart` 6, `google_auth_service.dart` 5,
  `gmail_oauth_screen.dart` 4, `export_directories.dart` 4, 3 each in `system_inset_wrapper.dart`,
  `yaml_import_export_screen.dart`, `windows_task_scheduler_service.dart`, `gmail_windows_oauth_handler.dart`, 2 each
  in `background_scan_scheduler.dart`, `gmail_api_adapter.dart`, and 1 each in 9 more.
- **F296: confirmed.** `.github/workflows/ci.yml:30,60,98` pin `flutter-version: '3.38.5'`; local `flutter --version`
  is 3.47.4. pubspec has `flutter: ">=3.10.0"` (a range). `subosito/flutter-action@v2` reads a version from a file:
  README, fetched 2026-10-18: *"flutter-version-file: pubspec.yaml # path to pubspec.yaml or .fvmrc or
  .fvm/fvm_config.json"* and *"For `flutter-version-file` to work, you need to have the exact Flutter version defined
  in your pubspec.yaml"*.
- **F298: confirmed, line numbers current.** Writes without a reload: `rules_management_screen.dart:253,315`,
  `rule_edit_screen.dart:509`, `safe_senders_management_screen.dart:255`, `rule_quick_add_screen.dart:149,158,403`,
  `safe_sender_quick_add_screen.dart:198,265`. The master-plan card missed `rule_quick_add_screen.dart:403` (addRule).
  `reloadFromDatabase()` is at `rule_set_provider.dart:230`; existing callers `email_scanner.dart:1174`,
  `rule_quick_action_service.dart:184,392`, `results_display_screen.dart:594`, `yaml_import_export_screen.dart:115,154`.
  `email_detail_view.dart:184` has no caller in `lib/` (F285 HOLD) -- left alone.
- **F267/F268: the data exists.** Windows DEV `content_history.db`: 603 rows; `spam_filter.db`: `email_actions`
  10,832, `unmatched_emails` 637, `rules` 2,202, `safe_senders` 457 (read-only count, 2026-10-18). F266 (the dead-pattern
  validator F268/F269 depend on) shipped in Sprint 77 (CHANGELOG line 112).
- **F289: trigger not fired.** WinWright v3.1.0 (2026-06-10) is the latest release (`gh release list`); it is the
  installed version (`winwright.json` has the 3.1.0 `AllowFileRead` permission). Its notes mention replayed
  assertions, but `winwright_script_strings_test.dart:109-116` records the runner rejecting `ww_assert*` and skipping
  `ww_get_value`, found live 2026-10-10 on this version. Cannot finish as a 30-60m task (Q4b).
- **F299**: see "Harold's four notes".
- **F276, F204**: see "Harold's four notes".
- **MV76-1, F205, F277**: no code state to check; they wait for 0.20.0 on the Fold.

**Phase 3.2.2.2**: fired -- Task 3 re-scoped (post-reboot runs done); Task 12 made verify-first; Task 7 gained one
write site; Task 11 marked blocked; all estimates set at the low end per the Sprint 78 calibration.

## Phase 3.6.1 Architecture Impact Check

- **New ADR-0049 (F294)**: platform capabilities in one seam. Changes how ADR-0042 exceptions are expressed (one table
  instead of scattered checks). Class 1 -- Q1.
- **New ADR-0050 (F295)**: iOS parity exceptions, from vendor documentation. Research only; no code.
- **ADR-0042**: amended by ADR-0049 -- a declared exception lives as a capability entry plus its test.
- **ADR-0047** (content history, dev only): F267 and F268 read it on Harold's PC only; no change to capture. A rule
  mined from Gmail-derived data is never bundled into the shipped seed (R76-3 Section 4.7; bundling would be Class 1,
  not proposed).
- **ARCHITECTURE.md**: a `PlatformCapabilities` row and the startup path in `main.dart` (Task 4); the import dialog
  gains Merge (Task 10); `scripts/` developer tools (Tasks 8, 9).
- **Import semantics** (F269): Replace stays the default; Merge is new. Class 2 -- Q2.
- No other ADR conflicts found.

## Decision questions (answer by number, for example "q1 1 q2 1 ...")

- Q1. F294 (Class 1). This would change a prior architectural decision: 65 `Platform.isX` checks in 21 files, each
  deciding a platform difference where it stands, are replaced by one `PlatformCapabilities` seam (ADR-0049), and a
  policy test refuses any new bare check outside it. Should I proceed?
  1. Yes, all 65 checks move this sprint (recommended).
  2. Yes, but the seam and policy test only, with the 65 existing checks on a shrinking allow-list moved over later.
  3. No, leave F294 in the backlog.
- Q2. F269 (Class 2). Import gains "Merge" beside "Replace"; Replace stays the default; Merge adds only rules and safe
  senders that are new, skips duplicates and dead patterns, and reports the counts.
  1. Approve.
  2. Do not build it this sprint.
- Q3. F296: where the one Flutter version is recorded.
  1. A `.fvmrc` file at the repo root, read by CI (`flutter-version-file`), plus a policy test that the local SDK
     matches it (recommended; `pub get` is not affected).
  2. An exact `flutter: 3.47.4` in `pubspec.yaml`, read by CI; `pub get` then refuses any other Flutter version,
     including in the prod worktree.
- Q4. F292: nine runs since the containment (four after the Oct 16 reboot) are green, and the page file did not grow
  (30,840 MB).
  1. Close the investigation as "cause unknown, not reproduced in nine runs"; keep `run-full-suite.ps1` as the Phase
     5.2 runner, so the next failure records its commit charge (recommended; 10m).
  2. You enlarge the page file and reboot; I run three more labeled runs (about 60m).
- Q4b. F289 (blocked upstream).
  1. Keep it in Sprint 80 as a 15m check: one probe of WinWright 3.1.0 replaying an assertion step, and the upstream
     request filed if it fails (recommended).
  2. Remove it from Sprint 80 until a WinWright release replays a read step.
  3. Replace the six mouse steps with Flutter widget tests of the same labels and tooltips, and drop them from the
     sweep (no upstream wait; WinWright then no longer checks those six on the real app).
- Q5. F299.
  1. Verify first: read every background scan in the 0.20.0 logs for class-B rows (reaped, no heartbeat, no stop
     line); none over the MV76-1 period closes F299 as fixed by workmanager 0.10.10; any builds the recorder
     (recommended).
  2. Build the exit-reason recorder regardless.
- Q6. F276 (not resolved; card below as Task 13).
  1. Include in Sprint 80.
  2. Leave in the backlog.
- Q7. F204 gaps 1 and 2 (not resolved; card below as Task 14).
  1. Include in Sprint 80.
  2. Leave in the backlog.
- Q8. Did 0.19.0 go live on the Microsoft Store? (Submitted 2026-10-13; the Store row still reads 0.18.0.0.)
  1. Yes, the Store-installed app showed Version 0.19.0.
  2. No, or not checked.
- Q-S1. Models as assigned: 1 approve. Q-S2. Version 0.21.0+18: 1 approve.

---

# Cards

## Task 0 -- Version bump 0.21.0+18 (3.7.0b)

**Value**: This lets a tester tell the Sprint 80 dev build from the 0.20.0 store builds.

**Requirements**:
- R-1: `pubspec.yaml` `version: 0.21.0+18` and `msix_config.msix_version: 0.21.0.0`.
- R-2: Same commit: `STORE_VERSION_STATUS.md` "Last uploaded to Play" -> 0.20.0 (versionCode 17) and the Dev row ->
  0.21.0+18; CHANGELOG: the `[Unreleased]` entries dated 2026-10-13 to 2026-10-18 go under `## [0.20.0] - 2026-10-18`;
  provisional `RELEASE_NOTES_0.21.0_windows.md` and `_play.md`.

**Affected components / files**: `mobile-app/pubspec.yaml`, `docs/STORE_VERSION_STATUS.md`, `CHANGELOG.md`,
`docs/store-assets/`.

**Parity (ADR-0042)**: one version on both platforms (ADR-0043).

**Dependencies / blockers**: plan approval.

**Acceptance criteria**: AC-1: `version_consistency_test`, `dev_version_ahead_test` and `release_notes_test` pass.

**Tests to write**: none new; T-1 (AC-1) runs the three existing gates.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: 10-15m.

## Task 1 -- MV76-1: Finish the Fold checks on the 0.20.0 closed-test build (Priority 1; absorbs F205 #433, MV74-1 #428; #471)

**Value**: This closes the last phone checks of Sprints 74-79 on the build customers have.

**Requirements** (the full remainder, re-presented):
- R-1: Step 8: the Background note screenshot (Settings > Background on the Fold).
- R-2: Step 9 / F253 AC-5: a scan started by a mail app's new-mail notification (`trigger=notification` in the
  diagnostic log); Notification access is already allowed, and no such scan has been seen yet.
- R-3: Step 11 reboot half (#428): background scans resume after a phone restart without opening the app; plus the F250
  Google account state screenshot.
- R-4: Boot-time `main()` trace: name what started the engine with no app opened (2026-10-07 09:14:39), and whether
  `app start (foreground)` is the wrong label for that path.
- R-5: One completed iCloud background scan (iCloud background ON for that day).
- R-6: The F283 Android screenshot.
- R-7: F205 / MV74-3 (#433): classify every scan error from one day of normal use per account on 0.20.0, or record
  zero.
- R-8: Fix 2 decision: find `stopped by WorkManager before it finished: reason=... raw=...` in the 0.20.0 log, show it
  to Harold, and record his decision on the native Application-class hook.
- R-9: Every number, interval and count in a step handed to Harold is read from the live system and its source named
  (Sprint 79 IMP-1); the phone pull includes `_Device care` and `_Settings` (IMP-2).

**Affected components / files**: evidence only; logs pulled by `scripts/pull-phone-screenshots.ps1` over MTP;
`scripts/phone-log-health.ps1`.

**Existing behavior relied on**: the worker stop line exists from workmanager 0.10.9 (`BackgroundWorker.kt:260-295`,
verified 2026-10-16, `SPRINT_79_PLAN.md:288-290`).

**Parity (ADR-0042)**: Android-only evidence by nature (WorkManager, Doze, notification listener, reboot receiver).
Windows equivalents already verified: Task Scheduler runs one process per scan and survives a reboot by its own
trigger; Windows has no new-mail listener (declared exception, F253).

**Dependencies / blockers**: 0.20.0 installed from Play on the Fold; Harold's phone time.

**Acceptance criteria**: AC-1: each of R-1 to R-7 has a named log line or screenshot file, or a recorded FAIL with
its card; AC-2: R-8 has Harold's decision recorded verbatim.

**Tests to write**: none (field evidence). A defect found gets its own card and test.

**Definition of Done**: default DoD, minus code items, plus #471, #433 and #428 closed by the sprint PR or carried with
Harold's approval.

**Model**: session model (transcription is Haiku-shaped; see the single-session note). **Step-types**: DOCS.
**Est-Effort**: 40-70m + phone time.

## Task 2 -- F277: Fold energy check, interval 5 against interval 15 (Priority 20; #472)

**Value**: This decides the 5-minute floor (`kMinIntervalMinutes`) from measured battery cost, not a guess.

**Requirements**:
- R-1: Arm A second night: AOL every 15 minutes, ONE account on, about 8 hours on battery.
- R-2: Arm C: new-mail scanning on (Notification access allowed), one account, one night.
- R-3: Explain the 0.3% versus 1.5% spread between the two arm-B nights (screen-on time, other apps, scans completed),
  or record "cause unknown" plus what would settle it.
- R-4: Apply the decision rule: if an interval-5 account costs more than 3x an interval-15 account, propose raising
  `kMinIntervalMinutes` to 10 (a Class-2 change, asked, not made).
- R-5: Before each night, check the last pulled log shows the planned AOL interval and new-mail setting, with
  `phone-log-health.ps1 -Path <log> -Since <start> -IntervalMinutes <n> -SingleAccount`.

**Affected components / files**: `docs/research/R76-1_BATTERY_AB_RESULTS.md` section R77-BAT-1.

**Parity (ADR-0042)**: Android-only (battery attribution per app). Windows: background scans run on mains or laptop
battery through Task Scheduler; no per-app energy figure is used for the floor (the floor is shared Dart and applies to
both).

**Dependencies / blockers**: Harold's nights; cannot overlap Task 1 days that need several accounts on.

**Acceptance criteria**: AC-1: arms A (two nights), B (two nights) and C recorded with app % and scan counts; AC-2: a
decision-rule result stated as a number.

**Tests to write**: none (measurement).

**Definition of Done**: default DoD, minus code items.

**Model**: Haiku (screenshot and log transcription). **Step-types**: DOCS. **Est-Effort**: 30-45m + nights.

## Task 3 -- F292 remainder: full-suite processes die or hang (Priority 5; new card)

**Value**: This prevents a real regression from being dismissed as noise in a red suite.

**Requirements** (per Q4):
- Q4 = 1: R-1 record the nine runs (five pre-reboot, four post-reboot) and the unchanged page file in the master plan;
  R-2 close the investigation as "cause unknown, not reproduced in nine runs; settled by the commit charge of the next
  failing `run-full-suite.ps1` run"; R-3 keep the runner as the Phase 5.2 command.
- Q4 = 2: R-1 Harold enlarges the page file and reboots; R-2 three labeled runs after it; R-3 the mechanism or "cause
  unknown" plus what would settle it.

**Affected components / files**: `docs/ALL_SPRINTS_MASTER_PLAN.md` F292; `scripts/run-full-suite.ps1` unchanged.

**Parity (ADR-0042)**: N/A -- developer test tooling on Harold's Windows PC; the suite itself covers both platforms'
shared code.

**Dependencies / blockers**: Q4.

**Acceptance criteria**: AC-1: each run listed with label, date, result, load failures and peak commit; AC-2: a
mechanism or "cause unknown" with what settles it. Never "flaky".

**Tests to write**: none new (the runner's self-test exists).

**Definition of Done**: None -- default DoD only.

**Model**: Sonnet -- *why not Haiku*: naming a process-memory mechanism from commit-charge data needs judgment.
**Step-types**: DOCS (+ test runs). **Est-Effort**: 10m (Q4 = 1) or 60m (Q4 = 2).

## Task 4 -- F294: One platform-capability seam instead of scattered platform checks (Priority 7; Class 1, Q1)

**Value**: This puts every platform difference in one place, so adding iOS is one table entry and a missed platform
decision fails a test instead of failing silently.

**Requirements**:
- R-1: ADR-0049 first: the seam's shape (one `PlatformCapabilities` with named questions, for example background
  mechanism, new-mail trigger available, export folder, OAuth flow, notification delivery, window chrome, tray), how a
  test overrides it, and how it amends ADR-0042 (a declared exception = a capability entry + its test).
- R-2: Audit first: classify each of the 65 checks as a capability question or a true platform-API guard (for example
  calling a Windows-only plugin); list both in the ADR.
- R-3: Every check moves behind the seam (Q1 = 1) or onto a shrinking allow-list (Q1 = 2). Behavior unchanged on
  Windows and Android.
- R-4: A policy test fails on any bare `Platform.isX` in `lib/` outside the seam file (and the allow-list if Q1 = 2).
- R-5: The test seam replaces existing ad hoc overrides where they exist (for example `debugIsAndroid`); list each
  one replaced.

**Affected components / files**: new `lib/core/platform/platform_capabilities.dart`; the 21 files listed in the
3.2.2.1 summary; new `test/policy/platform_check_seam_test.dart`; `docs/adr/0049-*.md`; `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: grep for existing platform helpers before writing (`app_environment.dart`,
`export_directories.dart`, any `debugIs*` seam); the card records what was found and reused.

**Callers of any guard being changed**: every one of the 65 sites is a guard; the ADR's R-2 table lists each with its
before and after behavior on Windows and Android. Tooling: none launches differently.

**Parity (ADR-0042)**: this task IS the parity mechanism. Each capability entry states Windows, Android and (as
"unknown until ADR-0050") iOS.

**Dependencies / blockers**: Q1. Task 5's findings fill the iOS column later.

**Non-functional requirements**: Platform -- no behavior change on either shipped platform; startup order in
`main.dart` unchanged.

**Acceptance criteria**: AC-1: ADR-0049 Accepted by Harold; AC-2: `grep Platform.is lib/` returns only the seam file
(Q1 = 1) or the seam plus the allow-list (Q1 = 2); AC-3: the policy test fails when a bare check is added (mutation);
AC-4: full suite green and the WinWright sweep passes on Windows; AC-5: the Android dev build starts and runs one
background scan on the emulator.

**Tests to write**: T-1 (AC-3) TEST-UNIT policy test, mutation-checked; T-2 (AC-2) unit tests of each capability's
answer on Windows and Android through the override; T-3 (AC-4/5) existing suite + sweep + emulator run.

**Definition of Done**: default DoD plus the emulator background-scan check.

**Model**: 4a Fable/Opus -- *why not Sonnet*: ADR authoring and a Class-1 seam design (`SPRINT_PLANNING.md:94-110`);
4b Sonnet -- *why not Haiku*: 21 files, each site classified by behavior; 4c Haiku. **Delegation checklist**: yes for
4b and 4c. **Step-types**: DOCS (ADR), SVC-NEW, SVC-EDIT, TEST-UNIT. **Est-Effort**: 110-190m.

_**Risk & rollback**_: a misclassified site changes behavior on one platform; mitigated by the R-2 table, the sweep and
the emulator run; rollback is reverting the migration commit (the seam commit stands alone).

_**Decision-class interrupts**_: Class 1 -- Q1.

## Task 5 -- F295: iPhone readiness research and parity ADR, time-boxed (Priority 8)

**Value**: This settles from Apple's and Google's own documentation what an iPhone version can and cannot match before
any iOS code is written.

**Requirements**:
- R-1: From primary sources, with links and the date read: iOS background scheduling (BGTaskScheduler limits, whether a
  near-15-minute interval is possible); any equivalent of Android's notification listener for "scan when new mail
  arrives"; Gmail OAuth on iOS (client type, redirect); Keychain credential storage; App Store privacy details and
  review rules for a mail-reading app; the Mac, Xcode and Apple Developer account requirements.
- R-2: ADR-0050 lists each iOS parity exception against ADR-0042 and its capability entry from Task 4.
- R-3: The cards F67 and F95 actually need, written into the master plan.
- R-4: Anything not settled is marked UNVERIFIED with what would settle it.

**Affected components / files**: `docs/research/F295_IOS_READINESS.md`, `docs/adr/0050-*.md`,
`docs/ALL_SPRINTS_MASTER_PLAN.md`.

**Parity (ADR-0042)**: the output is the iOS parity table.

**Dependencies / blockers**: none (Task 4's capability names are used if ready).

**Acceptance criteria**: AC-1: every R-1 question answered with a vendor link or marked UNVERIFIED; AC-2: ADR-0050
Proposed for Harold; AC-3: F67/F95 replacement cards written.

**Tests to write**: none (research).

**Definition of Done**: default DoD, minus code items.

**Model**: Fable/Opus -- *why not Sonnet*: research spike and ADR authoring are top-tier by rule.
**Step-types**: DOCS `[no-history]` for research. **Est-Effort**: 90-120m (time-box).

## Task 6 -- F296: CI Flutter version in sync with local (Priority 9)

**Value**: This prevents CI from passing or failing on a Flutter version nobody develops on.

**Requirements**:
- R-1: One recorded Flutter version (Q3), 3.47.4.
- R-2: All three CI jobs read it (`ci.yml:30,60,98`) through `flutter-version-file`.
- R-3: A policy test fails when the local SDK and the recorded version differ (reads the SDK's own version file under
  `FLUTTER_ROOT`).
- R-4: CI green on 3.47.4 (fix any analyzer or test difference the upgrade exposes).
- R-5: Document the rule in `CLAUDE.md` CI section: an SDK upgrade updates the recorded version in the same commit.

**Affected components / files**: `.github/workflows/ci.yml`, `.fvmrc` or `mobile-app/pubspec.yaml` (Q3), new
`test/policy/flutter_version_sync_test.dart`, `CLAUDE.md`.

**Parity (ADR-0042)**: CI builds Windows and runs the shared tests on Linux; Android is not built in CI today
(unchanged).

**Dependencies / blockers**: Q3.

**Acceptance criteria**: AC-1: the three CI jobs install 3.47.4 (job log line); AC-2: the policy test fails when the
recorded version is changed to 3.38.5 (mutation); AC-3: CI green on the sprint PR.

**Tests to write**: T-1 (AC-2) TEST-UNIT policy test.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- escalate to Sonnet if CI goes red on 3.47.4. **Delegation checklist**: yes.
**Step-types**: HOOK, TEST-UNIT. **Est-Effort**: 20-45m.

## Task 7 -- F298: Rule and safe sender edits reload the in-memory rules (Priority 10)

**Value**: This makes an edited, deleted or quick-added rule or safe sender take effect at once in No Rule Review and
the next manual scan, without a restart.

**Requirements**:
- R-1: Prevention first: one shared write-then-reload path (extend the F297 pattern in
  `rule_quick_action_service.dart:184,392`) that every screen uses, rather than nine copies.
- R-2: All nine sites end with `RuleSetProvider.reloadFromDatabase()` through it: `rules_management_screen.dart:253,315`,
  `rule_edit_screen.dart:509`, `safe_senders_management_screen.dart:255`, `rule_quick_add_screen.dart:149,158,403`,
  `safe_sender_quick_add_screen.dart:198,265`.
- R-3: A failed reload says so in the same words F297 uses ("saved, but the rules did not reload ...").

**Affected components / files**: the five screens above; `rule_quick_action_service.dart` or a new shared helper.

**Existing abstraction checked**: `RuleSetProvider.reloadFromDatabase` (`rule_set_provider.dart:230`) and the F297
helper in `rule_quick_action_service.dart`.

**Observable behavior -- before / after**: BEFORE: after editing or deleting a rule, Review No Rule Items still shows
the old matches until a scan completes or the app restarts. AFTER: the change shows at once; if the reload fails, a
message says the rule is saved but not yet in effect.

**Parity (ADR-0042)**: shared Dart, same screens on Windows and Android; no exception.

**Dependencies / blockers**: after Task 4b if it touches the same screens.

**Acceptance criteria**: AC-1: each of the nine sites reaches the reload (behavior test per screen family: rules
management, rule edit, safe senders management, the two quick-add screens); AC-2: a failed reload shows the message.

**Tests to write**: T-1 (AC-1) TEST-WIDGET per screen family proving the provider sees the change; T-2 (AC-2)
TEST-WIDGET failure path. Each with its "what this does NOT catch" line; mutation-checked.

**Definition of Done**: None -- default DoD only.

**Model**: Sonnet -- *why not Haiku*: one shared path across five screens plus a failure message (the Sprint 75 Haiku
batch failed cross-file work). **Delegation checklist**: yes. **Step-types**: SVC-EDIT, TEST-WIDGET.
**Est-Effort**: 30-60m.

## Task 8 -- F267: Rule evaluation harness, read only (Priority 20)

**Value**: This measures any candidate rule against Harold's own history before it can act on mail.

**Requirements**:
- R-1: A Dart CLI in `scripts/` that loads candidate YAML plus a COPY of the Windows DEV `spam_filter.db` and
  `content_history.db` and reports, per candidate: matches, precision on "would delete", safe-sender hits, recall on
  No Rule mail later deleted.
- R-2: Reuses `RuleEvaluator` and `PatternCompiler` unchanged (no second engine).
- R-3: The bar from R76-3 Section 4.8: zero safe-sender hits and precision of at least 0.99 on at least 20 matches;
  the report marks PASS or FAIL per candidate.
- R-4: Never opens the live database (copies only); never writes.

**Affected components / files**: new `scripts/rule-eval/` (Dart), its README.

**Existing abstraction checked**: `RuleEvaluator`, `PatternCompiler`, the F266 dead-pattern validator.

**Parity (ADR-0042)**: developer tool on Harold's PC; the engine it calls is the shared one both apps use. N/A for the
apps.

**Dependencies / blockers**: none.

**Acceptance criteria**: AC-1: on a fixture DB with known labels the report's numbers match hand-computed values;
AC-2: a candidate that matches a safe sender FAILs; AC-3: the live DB path is refused.

**Tests to write**: T-1..T-3 TEST-UNIT against fixtures, mutation-checked.

**Definition of Done**: README with the run command.

**Model**: Sonnet -- *why not Haiku*: new CLI design over two databases with metric definitions. **Delegation
checklist**: yes. **Step-types**: SVC-NEW, TEST-UNIT. **Est-Effort**: 60-100m.

## Task 9 -- F268: PC-side rule miner: deleted-mail history to candidate delete rules (Priority 22)

**Value**: This proposes block rules from mail Harold already deleted, with no new content stored by the app.

**Requirements**:
- R-1: Define the "deleted" label from data on Harold's PC: content-history rows later deleted by the Fold or by
  Harold (`email_actions`, `unmatched_emails.processed`); record the definition in the README.
- R-2: Mine recurring sender domains, subject phrases and body phrases into candidate YAML in `docs/RULE_FORMAT.md`
  shape.
- R-3: Every candidate passes F266 and is scored by Task 8; only PASS candidates are written to the output file.
- R-4: Output stays on Harold's PC; rules derived from Gmail data are never bundled into the shipped seed (Class 1,
  not proposed).

**Affected components / files**: new `scripts/rule-miner/` (Dart), README.

**Parity (ADR-0042)**: developer tool; the output YAML imports on both apps (Settings > Import / Export YAML).

**Dependencies / blockers**: Task 8.

**Acceptance criteria**: AC-1: on a fixture history the miner proposes the planted domain and subject rules; AC-2: a
candidate failing F266 or the Task 8 bar is not written; AC-3: one real run on Harold's DB copy reports the count of
PASS candidates.

**Tests to write**: T-1, T-2 TEST-UNIT on fixtures, mutation-checked.

**Definition of Done**: None -- default DoD only.

**Model**: Sonnet -- *why not Haiku*: phrase mining with precision thresholds. **Delegation checklist**: yes.
**Step-types**: SVC-NEW, TEST-UNIT. **Est-Effort**: 60-120m.

## Task 10 -- F269: YAML import merge mode (Priority 24; Class 2, Q2)

**Value**: This lets mined or shared rule files be added without wiping the user's rules.

**Requirements**:
- R-1: The import confirmation dialog offers "Replace" (default, unchanged) and "Merge".
- R-2: Merge adds only new rules and safe senders; duplicates resolved by `manual_rule_duplicate_checker` /
  `rule_conflict_detector`; patterns failing F266 are skipped and counted.
- R-3: The result message states added, skipped as duplicate, and skipped as invalid; then the provider reloads (F297).

**Affected components / files**: `yaml_import_export_screen.dart`, the import service it calls.

**Existing abstraction checked**: the two duplicate/conflict services and the F266 validator.

**User-reachable control**: Settings > Import / Export YAML > Import > confirmation dialog > "Merge".

**Observable behavior -- before / after**: BEFORE: importing a file replaces all rules and safe senders. AFTER: the
dialog asks Replace or Merge; Merge keeps everything and adds what is new, then says how many were added and skipped.

**Parity (ADR-0042)**: shared Dart and the same dialog on both; the file picker differs by platform already (existing
exception, unchanged).

**Dependencies / blockers**: Q2; after Task 4b (the screen has 3 platform checks).

**Acceptance criteria**: AC-1 (Given a DB with rule A and a file with A and B, When Merge, Then the DB has A once and
B, and the message says 1 added, 1 duplicate); AC-2: Replace behaves exactly as before; AC-3: an invalid pattern is
skipped and counted.

**Tests to write**: T-1..T-3 TEST-WIDGET and TEST-UNIT, mutation-checked.

**Definition of Done**: CHANGELOG `feat` entry; Help content updated if it describes import.

**Model**: Sonnet -- *why not Haiku*: Class-2 semantics plus dialog and service. **Delegation checklist**: yes.
**Step-types**: UI-NEW, SVC-EDIT, TEST-WIDGET. **Est-Effort**: 45-75m.

## Task 11 -- F289: WinWright default sweep with no mouse steps (Priority 25; blocked upstream, Q4b)

**Value**: This lets the WinWright sweep run on a locked PC.

**Requirements** (Q4b = 1): R-1 one probe: a copy of one `test_f124_rule_labels.json` label check rewritten as a
3.1.0 recorded assertion step, replayed with `run` in the scratchpad; R-2 if it replays, convert the six steps and empty
`knownPending`; R-3 if not, file the upstream request and keep the card blocked. (Q4b = 3: replace the six steps with
widget tests and remove them from the sweep.)

**Affected components / files**: `mobile-app/test/winwright/test_f124_rule_labels.json`,
`test_s75_new_controls.json`, `winwright_script_strings_test.dart:103-117`.

**Parity (ADR-0042)**: N/A -- Windows test tooling; Android UI is covered by Flutter widget tests.

**Dependencies / blockers**: an upstream WinWright change (Criterion 2 if the probe fails).

**Acceptance criteria**: AC-1: probe result recorded; AC-2: either `knownPending` empty and the sweep passes on a
locked PC, or the upstream request link recorded.

**Tests to write**: existing `winwright_script_strings_test.dart` gates.

**Model**: Sonnet -- *why not Haiku*: WinWright discovery is time-boxed judgment (`CODING_VELOCITY.md`
WINWRIGHT-DISCOVERY). **Step-types**: WINWRIGHT-SCRIPT. **Est-Effort**: 15m probe; 30-60m if it works.

## Task 12 -- F299: Android scans that die within 30 s: verify, then record the exit reason if needed (Priority 25)

**Value**: This tells whether the plugin upgrade ended the silent mid-scan deaths and, if not, names why the process
died.

**Requirements**:
- R-1 (Q5 = 1): read every background scan in the 0.20.0 logs pulled during Task 1 for class-B rows (reaped, no
  heartbeat, no stop line); record the count and the period covered.
- R-2: zero over the MV76-1 period closes F299 as fixed by workmanager 0.10.10 (cite `BackgroundWorker.kt:195-209`);
  any row starts R-3.
- R-3: at each app and worker start, read `ActivityManager.getHistoricalProcessExitReasons` (API 30+) through a
  platform channel and write each exit since the last read (reason, importance, time) to the diagnostic log.
- R-4: a watchdog failure ("Dart engine did not initialize the background channel within 30000 ms") is recognized in
  the log if Android reports it.

**Affected components / files**: R-1/R-2 evidence only; R-3 `android/app/src/main/kotlin/.../MainActivity.kt` or a
plugin class, `lib/` diagnostic logger call.

**Parity (ADR-0042)**: declared exception -- Android-only. Windows: Task Scheduler runs one process per scan and
records its exit code (Last Run Result), so the same question is already answerable there.

**Dependencies / blockers**: 0.20.0 logs from Task 1.

**Acceptance criteria**: AC-1: class-B count on 0.20.0 recorded with the period; AC-2 (only if R-3 runs): a forced
process kill on the emulator produces a log line with the exit reason.

**Tests to write**: R-3 only: TEST-UNIT of the Dart side parsing the channel result; emulator check for the native
side.

**Model**: R-1/R-2 session model; R-3 Sonnet -- *why not Haiku*: native platform channel. **Step-types**: DOCS;
SVC-NEW + native. **Est-Effort**: 10m; R-3 45-75m.

## Task 13 -- F276: No Rule Review lists mail already deleted or moved (Priority 30; pending Q6)

**Value**: This stops No Rule Review listing mail that is gone, and stops actions on it failing.

**Requirements**:
- R-1: Prevention first: in the one shared action path, an action that fails with "message not found" marks the row
  `deleted` through `updateAvailabilityStatus` (`unmatched_email_store.dart:487`).
- R-2: The Review query filters `deleted` rows (the `availabilityOnly` filter at `:444-459` already exists).
- R-3: A message seen again in another folder (moved) marks the old folder's row `moved`.

**Affected components / files**: the shared action path (`rule_quick_action_service.dart` and the adapters' not-found
classification), `unmatched_email_store.dart`, the Review screen query.

**Existing abstraction checked**: `updateAvailabilityStatus`, `availabilityOnly`, `EmailAvailabilityChecker` (exists,
never constructed -- reuse or delete, recorded in the card).

**Observable behavior -- before / after**: BEFORE: mail deleted in the mail app stays in Review for up to 90 days and
actions on it fail; moved mail shows twice. AFTER: the first failed action removes it from the list with a short
message; moved mail shows once.

**Parity (ADR-0042)**: shared Dart; "not found" is classified per adapter (IMAP and Gmail API), same behavior on both
platforms.

**Acceptance criteria**: AC-1: an action on a not-found message marks the row and it leaves the list; AC-2: a moved
message is listed once.

**Tests to write**: TEST-UNIT and TEST-WIDGET for both, mutation-checked.

**Model**: Sonnet -- *why not Haiku*: error classification across two adapters. **Step-types**: SVC-EDIT, TEST-UNIT.
**Est-Effort**: 40-60m.

## Task 14 -- F204 gaps 1 and 2: assert target SDK and no AD_ID from the built AAB (Priority 24; pending Q7)

**Value**: This makes a Flutter downgrade or a transitive ads dependency fail the build instead of failing at Play or
making the Data safety answer false.

**Requirements**:
- R-1: After `build-with-secrets.ps1 -Output aab`, read the built bundle's manifest and fail if `targetSdkVersion < 36`
  or `com.google.android.gms.permission.AD_ID` is present (promote the hand-run `verify_aab.py` checks into the
  script, generalized).
- R-2: Gap 3 (16 KB alignment, due 2027-02-01) stays in the backlog.

**Affected components / files**: `mobile-app/scripts/build-with-secrets.ps1`, a helper it calls.

**Parity (ADR-0042)**: declared exception -- Play requirements are Android-only. Windows equivalent already gated:
`--release-self-test` and `msix_config_test`.

**Acceptance criteria**: AC-1: a bundle with AD_ID injected fails the check; AC-2: the real 0.20.0 bundle passes.

**Tests to write**: T-1 self-test of the check on a crafted manifest (mutation style).

**Model**: Haiku. **Delegation checklist**: yes. **Step-types**: HOOK. **Est-Effort**: 25-40m.
