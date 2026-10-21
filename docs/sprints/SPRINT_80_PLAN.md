# Sprint 80 Plan

**Status**: APPROVED at Phase 3.7 by Harold, 2026-10-19 (*"q1 a - and do any adr approval at Manual Validation"*, then
*"Sprint plan approved as amended (with any comments I provided), proceed with execution"*). Q1 = 1: all 65 checks
move this sprint; ADR-0049 and ADR-0050 are approved at Manual Validation. Cards: Task 0 #491, Task 1 #471 (with #433,
#428), Task 2 #472, Task 3 #492, Task 4 #493, Task 5 #494, Task 6 #495, Task 7 #496, Task 8 #497, Task 9 #498,
Task 10 #499, Task 12 #500, Task 13 #501, Task 14 #502. Scope selected by Harold at Phase 8.4 pass 2 (2026-10-18).
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

**Total (after Harold's answers, 2026-10-19)**: Tasks 0-10 and 12-14 about 540-990 minutes (Task 3 at 10m, Task 11
removed, Tasks 13 and 14 added), plus the 150-250 unplanned allowance, plus Harold's phone time and nights. This is about double the slate recommended at 8.4; the
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

- Q0. Each of your four notes applies to the item ABOVE it (F299, F276, F247, F204), so F247 is the one marked closed.
  1. Correct.
  2. No -- tell me which item each note belongs to (I then move the closure).

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

**Answers (Harold, 2026-10-19, verbatim)**: *"q0 1 q1 is PlatformCapabilities an architectual best practice for large
code-bases targeting multiple platforms? q2 1 but "merge" gets the default q3 a q4 a q4b b q5 a q6 a q7 a q8 a q-s1 1
q-s2 1"* (letters read as option numbers: a = 1, b = 2).

- Q0 = 1: each note applies to the item above it; F247 stays closed.
- Q1: OPEN -- Harold asked whether the pattern is a best practice. Answer (Flutter's own guidance) and the re-asked
  question below.
- Q2 = 1, with a change: **Merge is the DEFAULT** choice in the import dialog; Replace stays available (Class 2,
  approved by Harold). Task 10 updated.
- Q3 = 1: `.fvmrc` at the repo root, read by CI, plus a policy test that the local SDK matches it.
- Q4 = 1: F292 investigation closed as "cause unknown, not reproduced in nine runs"; `run-full-suite.ps1` stays the
  Phase 5.2 runner. Task 3 is 10m.
- Q4b = 2: F289 REMOVED from Sprint 80 until a WinWright release replays a read step. Task 11 dropped.
- Q5 = 1: F299 verify first (Task 12).
- Q6 = 1: F276 IN scope (Task 13).
- Q7 = 1: F204 gaps 1 and 2 IN scope (Task 14).
- Q8 = 1: 0.19.0 went live on the Microsoft Store (Harold's report; `STORE_VERSION_STATUS.md` Store row updated).
- Q-S1 = 1, Q-S2 = 1: models and version 0.21.0+18 approved.

**Q1 answer -- is a capability seam a best practice?** Yes; it is Flutter's own published guidance.
`docs.flutter.dev/ui/adaptive-responsive/capabilities` (Flutter 3.47 docs, page updated 2026-05-05, read 2026-10-19):
*"Avoid using `Platform.isAndroid` and similar functions to make layout decisions or assumptions about what a device can
do. Instead, describe what you want to branch on in a method."* It splits the branches into two classes: *"A
capability defines what the code can do"* (an API exists, OS-enforced restrictions, hardware) and *"A policy defines
what the code should do"* (app store guidelines, design preferences, copy that refers to the host device). Reason
given: *"The Flutter team has found with productionized apps that making a logical distinction between what apps can
do and what they should do helps larger products respond to changes in what platforms can do or require"*, and *"Test
the branching code by mocking capabilities and policies so the widget tests don't need to change"*. The companion page
`/ui/adaptive-responsive/best-practices` (updated 2026-07-31) points to the same idea for business logic. **Change to
the card from this**: two classes, `PlatformCapabilities` and `PlatformPolicy`, each method named for what it
branches on, not one class. Re-asked as Q1 in the approval message.

---

# Cards

## Task 0 -- Version bump 0.21.0+18 (3.7.0b)

**Value**: This lets a tester tell the Sprint 80 dev build from the 0.20.0 store builds.

**Requirements**:
- R-1: `pubspec.yaml` `version: 0.21.0+18` and `msix_config.msix_version: 0.21.0.0`.
- R-2: Same commit: `STORE_VERSION_STATUS.md` "Last uploaded to Play" -> 0.20.0 (versionCode 17) and the Dev row ->
  0.21.0+18; CHANGELOG: the `[Unreleased]` entries dated 2026-10-13 to 2026-10-18 go under `## [0.20.0] - 2026-10-18`;
  provisional `RELEASE_NOTES_0.21.0_windows.md` and `_play.md`.
- R-3: `[Unreleased]` holds every entry since 0.14.0 (the last release heading, CHANGELOG line 266). Either backfill
  headings for 0.15.0-0.19.0 from the dates in `STORE_VERSION_STATUS.md` and the submission timing table, or note
  under the 0.20.0 heading that it also holds the 0.15.0-0.19.0 entries. Decided and recorded at execution;
  `dev_version_ahead_test` reads only the first heading, so either passes at 0.21.0.

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
- R-1: ADR-0049 first: the seam's shape, following Flutter's published capabilities-and-policies guidance
  (`docs.flutter.dev/ui/adaptive-responsive/capabilities`): `PlatformCapabilities` for what the code CAN do (for
  example background mechanism, new-mail trigger available, OAuth flow, notification delivery, tray) and
  `PlatformPolicy` for what it SHOULD do (store rules, design preferences, copy naming the device); each method named
  for what it branches on, never for the device; how a test overrides both; and how it amends ADR-0042 (a declared
  exception = a capability or policy entry + its test).
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
- R-1: The import confirmation dialog offers "Merge" (the DEFAULT, Harold Q2 2026-10-19) and "Replace" (today's
  behavior, still available).
- R-2: Merge adds only new rules and safe senders; duplicates resolved by `manual_rule_duplicate_checker` /
  `rule_conflict_detector`; patterns failing F266 are skipped and counted.
- R-3: The result message states added, skipped as duplicate, and skipped as invalid; then the provider reloads (F297).

**Affected components / files**: `yaml_import_export_screen.dart`, the import service it calls.

**Existing abstraction checked**: the two duplicate/conflict services and the F266 validator.

**User-reachable control**: Settings > Import / Export YAML > Import > confirmation dialog > "Merge".

**Observable behavior -- before / after**: BEFORE: importing a file replaces all rules and safe senders. AFTER: the
dialog offers Merge (selected by default) or Replace; Merge keeps everything and adds what is new, then says how many
were added and skipped. A user who wants the old behavior picks Replace.

**Parity (ADR-0042)**: shared Dart and the same dialog on both; the file picker differs by platform already (existing
exception, unchanged).

**Dependencies / blockers**: Q2; after Task 4b (the screen has 3 platform checks).

**Acceptance criteria**: AC-1 (Given a DB with rule A and a file with A and B, When Merge, Then the DB has A once and
B, and the message says 1 added, 1 duplicate); AC-2: Replace behaves exactly as before; AC-3: an invalid pattern is
skipped and counted; AC-4: Merge is the pre-selected choice when the dialog opens.

**Tests to write**: T-1..T-3 TEST-WIDGET and TEST-UNIT, mutation-checked.

**Definition of Done**: CHANGELOG `feat` entry; Help content updated if it describes import.

**Model**: Sonnet -- *why not Haiku*: Class-2 semantics plus dialog and service. **Delegation checklist**: yes.
**Step-types**: UI-NEW, SVC-EDIT, TEST-WIDGET. **Est-Effort**: 45-75m.

## Task 11 -- F289: REMOVED from Sprint 80 (Harold Q4b = 2, 2026-10-19); stays in the backlog until a WinWright release replays a read step. Card text kept for that sprint.

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
  heartbeat, no stop line); record the count, the period covered, and the Fold's Android version (from the
  `_Settings` pull). The #738 fix is described as Android 16 specific: if the Fold is not on Android 16, a zero count
  still closes F299 on evidence, but "fixed by the upgrade" is then not supported.
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

## Task 13 -- F276: No Rule Review lists mail already deleted or moved (Priority 30; IN scope, Q6 = 1)

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

## Task 14 -- F204 gaps 1 and 2: assert target SDK and no AD_ID from the built AAB (Priority 24; IN scope, Q7 = 1)

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

## Task 15 -- Windows startup: Task Scheduler reconciliation after the window appears (ADDED at Manual Validation, Harold Q4 = 2, 2026-10-21; #503)

**Value**: This makes the Windows window appear in about 2 seconds instead of 15-30.

**Requirements**:
- R-1: A Windows release build shows its window without waiting for the per-account Task Scheduler reconciliation
  (F98 migration, F264 conversions, verify/repair/ensure per account, orphan cleanup).
- R-2: The reconciliation still runs on every foreground start, in full, after `runApp`.
- R-3: A Settings schedule or cancel made while the reconciliation runs is not undone by it.

**Affected components / files**:
- `mobile-app/lib/main.dart` -- the block moves into `_reconcileWindowsBackgroundTasks()`, started unawaited after
  `runApp`.
- `mobile-app/lib/core/services/windows_task_scheduler_service.dart` -- new `runExclusive` (reentrant, in-process).
- `mobile-app/lib/core/services/background_scan_scheduler.dart` -- `WindowsSchedulerAdapter.schedule` and `cancel`
  run inside `runExclusive`.

**Existing abstraction checked**: no lock or mutex in `lib/core/services` (grep `Mutex|_serial|synchronized|_lock`);
only the single-instance mutex name in `app_environment.dart`, which is cross-process and unrelated.

**Callers of any guard being changed** (the change alters WHEN the reconciliation runs):
- `main()` foreground start -- now after `runApp`, not awaited.
- Background-scan launch (`--background-scan`) -- exits at `main.dart:206`, before the block; unchanged.
- Settings (`settings_screen.dart:1501`, `:1850`) through `BackgroundScanSchedulerFactory.instance` ->
  `WindowsSchedulerAdapter` -- now waits for a running reconciliation (up to about 30 s on the first seconds after
  start); no other `lib/` caller changes tasks directly (grep of `WindowsTaskSchedulerService.`).
- Tooling that launches or kills the exe: the WinWright runner and `build-windows.ps1` may stop the app while the
  reconciliation runs; the PowerShell child finishes or the next start redoes the (idempotent) reconciliation. Their
  60 s launch waits are now larger than needed (not changed here; see F300).

**Observable behavior -- before / after**: BEFORE: after a double-click, nothing is visible for 15-30 s. AFTER: the
window appears in about 2 s; the background tasks are checked during the next half minute with no visible sign. A
background change SAVED in Settings during that half minute waits for the check, so its confirmation can appear up
to about 25 s late (before, the window was not up yet, so no change could be made then). Opening Settings only reads
state and does not wait.

**Parity (ADR-0042)**: Windows-only by mechanism (Task Scheduler). Android's WorkManager registration before
`runApp` is one in-process call and was never slow; unchanged.

**Acceptance criteria**:
- AC-1: on the DEV release build, the window appears in under 5 s (measured with `Start-Process` and the window
  handle).
- AC-2: all 9 scheduled-task calls of the 4-account DEV install still run after the window, and the 4 DEV tasks stay
  `Ready`.
- AC-3: a Settings schedule waits while a reconciliation holds the lock; a nested call does not deadlock; an error
  releases the lock.

**Tests to write**: T-1 (AC-3) TEST-UNIT `test/unit/services/windows_task_scheduler_exclusive_test.dart`: order,
reentrancy, release after an error, adapter takes the lock. What it does NOT catch: whether `main.dart` wraps the
reconciliation in the lock and starts it after `runApp` (AC-1/AC-2 measurement covers that).

**Definition of Done**: default DoD plus the AC-1/AC-2 measurement recorded below.

**Model**: Opus (executed in the main session at Manual Validation) -- *why not the cheaper tier*: ordering change
on the startup path with a concurrency lock; the callers had to be traced first. **Est-Effort**: 45-60m.

**Result (2026-10-21)**: window at **1.8 s** (was 30.9 s); child processes 9 (8 `get_status.ps1` from 2.2 s to 22.1 s,
1 `adhoc_query.ps1` at 25.5 s); 4 DEV tasks `Ready`. T-1 4/4 pass; mutations Q4-M1 (no queue), Q4-M2 (not
reentrant), Q4-M3 (error keeps the lock), Q4-M4 (adapter bypasses the lock) all KILLED. Full suite `80-q4`:
3174 passed, 15 skipped, 0 failed, 0 load failures; `flutter analyze` clean on the changed files.

---

# Phase 5 evidence

- **5.1.2 F-PRECHECK**: 2026-10-19, six classes run against the sprint diff (`lib`, `scripts`, `tool`, `test`), then
  again on the three Phase 5 commits (32e9f78, 82adc6b9, 833f7cee). Clean on all six for Tasks 0-14. Notes: (1)
  mirror sites -- the F276 presence check is in BOTH adapters (IMAP `UID SEARCH`, Gmail `messages.get`) and the
  scanner calls it for any `MessagePresenceChecker`; the F269 merge has a rules and a safe-senders twin, both
  wired; `.fvmrc` is read by all three CI jobs and by `flutter_version_sync_test`. (2) helper wiring -- every new
  helper has a runtime caller (`reconcileNoRulePresence` from `email_scanner.dart`, `reloadRulesAfterWrite` from 5
  screens, `YamlImportMerge` from the import screen, `PlatformCapabilities` at the 62 moved sites). (3) doc drift --
  the 82adc6b9 change updated the reconciler doc comment and the ARCHITECTURE.md unmatched_emails row. (4) parsing
  -- the IMAP check leaves out ids that are not integer UIDs (tested). (5) API scope -- `UID SEARCH` runs on the
  selected folder only; Gmail `messages.get` reads one message with `format: minimal` and `$fields: id,labelIds`.
  (6) silent failure -- the presence check rethrows cancellation and session-fatal errors and logs the rest at
  error level (tests include the session-fatal case); the F267/F268 tools take the app-data path as a parameter.
- **5.1.5 WinWright sweep**: 2026-10-19 09:36-09:53, DEV build started at 833f7cee (lib/ unchanged since 82adc6b9;
  4d42c8dd, docs only, landed during the build), 2 scripts (the default sweep), unlocked PC (mouse steps skipped: 0), DB drift none, DEV tasks
  re-enabled. `test_f124_rule_labels.json` PASS 29/29 (471 s); `test_s75_new_controls.json` PASS 27/27 (463 s; cases
  HIST-1, SORT-1, SET-1). Two earlier runs the same morning failed before any step under test, each fixed at its
  cause: (1) 09:03 -- "Dev app window did not appear within 30s": the release app runs 9 serial PowerShell Task
  Scheduler calls before `runApp` (window at 30.9 s, measured); the runner now waits 60 s and logs PIDs alive at
  launch and the exit code of a launch that exits (82adc6b9; this closes the Sprint 79 "cause unknown" launch
  failure). (2) 09:20 -- step 2 "resolved 0 elements": the accessibility tree appeared 10-41 s after the priming
  query, past the 15 s `stepTimeoutMs`; now 60000 (833f7cee); the cause of that delay is unknown (README entry
  names what would settle it). Duration note: about 16 s per step, as in Sprint 79 (f124 6 m 53 s then). After
  the sweep, 6dc572c5 changed only `lib/core` (`email_scan_provider.dart`, the store and a doc comment); `lib/ui`
  is unchanged since the swept build, so the sweep stands for the 10:07 MV build.
- **5.2 full suite**: 2026-10-19 10:01, `run-full-suite.ps1 -Label 80-5.2c` at 6dc572c5: 3170 passed, 15 skipped,
  0 failed (4 minutes); `flutter analyze` clean. (80-5.2b at 82adc6b9 failed 1 -- see the F276 finding.)
  sweep-head: 4d42c8dd
- **5.1.9 MV rehearsal**: 2026-10-19, every Windows step handed over below was rehearsed on its real path before
  handover; each step carries its own `Rehearsed:` line. F269 by the screen's parse path plus the merge on a test
  database seeded with the same existing rule as the DEV database (`mv80_f269_rehearsal_test.dart`, scratch, PASS:
  "Merged rules: 1 added, 1 skipped as duplicate, 0 skipped as invalid."); F276 against the local GreenMail server
  (UIDs [1,2,3], middle one expunged: present / absent / present) AND on the live DEV database (below); F298 and
  F294 by their tests and a screenshot of the running DEV build. Phone steps are re-presented from the Task 1, 2
  and 12 cards; they run on the installed 0.20.0 and cannot be rehearsed on this PC.
- **5.1.6 Runtime Launch Gate / F294 AC-5 (Android)**: 2026-10-19 08:5x, `build-with-secrets.ps1 -BuildType debug
  -Env dev -InstallToEmulator -SkipUninstall` on emulator-5554: "APK installed", "[OK] App launched successfully";
  app pid 25828 alive afterwards, `logcat -b crash` 0 lines.
- **Phase 5 findings fixed in-sprint**:
  - F276 re-sighting (82adc6b9): a re-sighting wrote `unknown` / never checked, so every scan re-asked the rows it had
    just seen (every 5 minutes on DEV, up to 50 Gmail requests per scan). Found by reading the live DEV database in
    the rehearsal. Now a sighting records `available` with its time. First placed in the store's upsert (82adc6b9);
    the full suite then failed `unmatched_email_store_test.dart:416` because that overwrote a caller's explicit
    status, so the stamp moved to the one production writer, `EmailScanProvider.completeScan`, and the store keeps
    caller values again. The test drives two real scan completions; mutations R1 and R2 KILLED at the new place.
  - `build-windows.ps1` (32e9f78): a background-scan task that started from `dist\dev` during the 2-minute compile
    held the exe and dll files; the variant swap deleted `data\` and then failed, leaving a DEV build that could not
    start. The script now stops processes running from the variant folder right before the swap.
  - WinWright runner and scripts (82adc6b9, 833f7cee): see 5.1.5.
- **F276 live evidence (DEV database, read-only, 2026-10-19)**: the first 0.21.0 AOL background scan,
  09:00:20-09:00:23, marked 10 unprocessed AOL rows `deleted` -- 7 Bulk spam rows from 10-18, 2 Inbox newsletters
  last seen 07:48 and 07:59 (Harold worked the Fold's No Rule list to 0 by 08:38), 1 August row. The one AOL row
  still in the mailbox (Speedpay, re-sighted 09:10:36) stayed listed: DEV Review shows "No rule (1)".
- **Phone evidence so far (pulled 2026-10-19 09:0x, `validation-screenshots/sprint-80/`)**: 0.20.0 installed from
  Play between 05:45:10 (last 0.19.0 line) and 06:00:24 (first 0.20.0 line). Fold: Galaxy Z Fold8 Ultra, **Android
  17**, One UI 9.0 (Settings > About phone > Software information). F299 class-B rows on 0.20.0: **0** over
  06:00-08:57 (`phone-log-health.ps1`: AOL 14 starts, 12 completed, 2 refused, 0 unfinished; Gmail, iCloud, Yahoo 1
  each, completed). R-5 candidate: iCloud background scan 07:54:55 completed (found 0, errors 0).
- **Task 2 R-3 (F277, the 0.3% versus 1.5% spread between the two arm-B nights) -- cause unknown, desk analysis of
  the Sprint 79 night log (`SPRINT_79_PLAN.md` "Night log")**:
  - Night 10-14/15: on battery about 01:00-05:52 (91% to 84%, 7 points), screen on 29 m, **44** completed AOL scans
    (8.06 an hour), app **0.3%** (Telegram 1.8%).
  - Night 10-16/17: on battery about 00:25-06:28 (94% to 86%, 8 points), screen-on time not recorded, **55** AOL
    starts (about 9.1 an hour), app **1.5%** (Telegram 4.2%).
  - Scan count explains at most 1.25x (55 / 44) of the 5x; the phone's total drop barely differs (7 against 8
    points). So the per-scan cost would have to differ about 4x, which nothing in the logs shows (same account, same
    interval, 0 errors both nights).
  - Leading candidate, unverified: the two figures do not cover the same window. The app info screen on 10-18 reads
    "Battery 0% used since last fully charged", and neither night started from a full charge (91% and 94%), so each
    reading may include a different stretch of the day before. Telegram also rose 2.3x between the two readings,
    which fits a longer window on the second night better than a costlier app.
  - What would settle it: charge to 100% immediately before unplugging, screenshot the app's own battery detail at
    unplug and again in the morning, and record screen-on time. Added to the F277 Manual Validation step below, so
    arm A night 2 and arm C are measured on the same window. The 3x decision rule (R-4) waits for those two nights.
- **Windows startup cost (pre-existing, NOT a Sprint 80 change; asked at Manual Validation; Harold Q4 = 2, FIXED by
  Task 15 on 2026-10-21, window 1.8 s)**: a release build runs
  one PowerShell script per Task Scheduler call before `runApp` (`main.dart:360-431`). Measured on DEV with 4
  enabled accounts: 8 `get_status.ps1` plus 1 `adhoc_query.ps1`, about 3.1 s each, window at 30.9 s, app idle in
  between. With background off (Harold's prod), one delete script per account plus the enumerate, about 15 s.
  Unchanged since 80d92c6 except the `Platform.isWindows` to capability swap.

## Manual Validation steps (Sprint 80 -- re-present IN FULL every time Harold is asked to validate)

Build: Windows DEV 0.21.0 with Task 15 (lib/ identical to 0f0148c8; built 2026-10-21 from the working tree before
that commit, docs-only changes after)
(`D:\Data\Harold\github\spamfilter-multi\mobile-app\dist\dev\MyEmailSpamFilter-Dev.exe`, title `MyEmailSpamFilter [DEV]`, the same exe the four DEV background tasks run every 5 minutes). DEV is read-only (scan
mode), so no step changes mail except the one you make yourself in MV-3. Since Task 15 (2026-10-21 build) the
window appears in about 2 seconds.

- **MV-1 (F269, YAML import Merge, the default)**.
  - Preconditions: the DEV app open. The file `C:\Users\kimme\Documents\Sprint80_MV\rules_merge_test.yaml` holds 2
    rules: `Block_EntireDomain_18pluseislandphotos.info` (already in the DEV database, id 6883) and the new
    `MV80_F269_MergeTest` (blocks `@...f269-mv-test.invalid`).
  - Steps: Settings (gear) > General tab > Import / Export YAML > Import Rules > pick the file above. In the dialog,
    leave **Merge** selected (it is pre-selected) and press **Merge 2 rules**.
  - Expected: the dialog text says nothing you have is changed or removed; after the press the status message reads
    `Merged rules: 1 added, 1 skipped as duplicate, 0 skipped as invalid.` Settings > General > Manage Rules: the
    rule count is one higher than before (2202 before, read 2026-10-19) and searching `MV80` finds the new rule.
  - Rehearsed: 2026-10-19, the same file through the screen's parse path and `YamlImportMerge.mergeRules` on a test
    database seeded with the existing rule: exactly that message.
- **MV-2 (F298, a rule delete reloads the rules in use)**.
  - Preconditions: MV-1 done.
  - Steps: Settings > General > Manage Rules > search `MV80` > select the rule > **Delete** > **Delete** in the
    confirmation.
  - Expected: a snackbar `Deleted: <the rule's name or domain>` with NO "-- saved, but the rules in use could not be
    reloaded; restart the app" ending. Searching `MV80` again finds nothing; the count is back to 2202.
  - Rehearsed: `f298_*` tests drive the same delete path with a provider whose reload succeeds and one whose reload
    fails (the second shows the suffix).
- **MV-3 (F276, Review hides mail that is gone)**.
  - Preconditions: the DEV background tasks enabled (Task Scheduler Library, `SpamFilterBackgroundScan_*_Dev`, every
    5 minutes). DEV Review lists at least one row you are willing to move (today: 1 row, `noreply@speedpay.com`,
    AOL Inbox, "AutoPay Payment Processed").
  - Steps: in AOL (web or the mail app), move that email to another folder (or delete it). Wait up to 65 minutes. In
    the DEV app press the Refresh icon (Re-check the last scan) on Review No Rule Items.
  - Expected: the row is gone and "No rule (N)" is 1 lower. Why up to 65 minutes: every scan that still sees a row
    stamps it present, and a row is re-checked at most once an hour after its last sighting; the tasks run every 5
    minutes. Optional: move it back to the Inbox; the next scan lists it again.
  - Rehearsed: 2026-10-19, GreenMail (an expunged UID reads absent, the others present) and the live DEV database
    (the first 0.21.0 AOL scan hid 10 rows whose mail was gone and kept the one still in the Inbox).
- **MV-4 (F294, Windows looks and behaves the same)**.
  - Steps: look at the DEV app.
  - Expected: the Exit (X) button at the right of the toolbar, flat dark surfaces as before, the tray icon present.
  - Rehearsed: screenshot of the running DEV build 2026-10-19 09:2x (Exit button, flat surfaces); the tray icon is
    not visible to a window screenshot -- its code path is covered by `platform_capabilities_test` (`hasSystemTray`
    true on Windows) and the `main.dart` tray block is unchanged apart from the capability check.
- **MV-5 (Task 15, the window appears at once)**.
  - Preconditions: the DEV app built 2026-10-21 or later (Task 15). Close the DEV app first (tray icon > Exit, or the
    Exit button).
  - Steps: start `D:\Data\Harold\github\spamfilter-multi\mobile-app\dist\dev\MyEmailSpamFilter-Dev.exe`. Within the
    first 30 seconds, open Settings > Background and look at an account's background setting (do not change it).
  - Expected: the window appears within about 2 seconds (it took about 30 before). Settings opens normally. After a
    minute, Task Scheduler Library still lists the four `SpamFilterBackgroundScan_*_Dev` tasks as Ready.
  - Rehearsed: 2026-10-21, `Start-Process` plus the window handle: window at 1.8 s; 9 PowerShell task checks seen
    from 2.2 s to 25.5 s; 4 DEV tasks Ready.
- **Phone (Fold, 0.20.0 from Play) -- Task 1 MV76-1, Task 2 F277, Task 12 F299**: the full remainder, re-presented:
  - R-1: Settings > Background screenshot (the Background note).
  - R-2: a scan started by a mail app's new-mail notification (`trigger=notification` in the diagnostic log);
    Notification access is already allowed. None seen yet in today's 0.20.0 log.
  - R-3: restart the phone and do not open the app; background scans must resume (#428). Plus a screenshot of the
    F250 Google account state.
  - R-4: the boot-time trace -- read from the log after R-3.
  - R-5: one completed iCloud background scan (candidate already: 07:54:55 today, found 0, errors 0).
  - R-6: the F283 Android screenshot.
  - R-7: one day of normal use on 0.20.0 for the F205 error classification (or zero).
  - R-8: the `stopped by WorkManager before it finished: reason=... raw=...` line, then your Fix 2 decision.
  - F277: arm A second night (AOL every 15 minutes, ONE account on, about 8 hours on battery) and arm C (new-mail
    scanning on, one account, one night). For each night: charge to 100% and unplug at bedtime; at unplug, take a
    screenshot of the app's battery detail (Settings > Apps > MyEmailSpamFilter > Battery); in the morning, take the
    same screenshot plus Settings > Battery app usage, and note the screen-on time. (Task 2 R-3: the two arm-B
    readings may cover different windows; a full charge at unplug makes both nights start from the same point.)
  - F299: nothing to do beyond R-7's day of use; recorded so far: 0 class-B rows on Android 17.
