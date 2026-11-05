# Sprint 83 Plan

**Status**: APPROVED by Harold 2026-11-01 10:18pm (Q-A). Scope selected by Harold at Phase 8.4 pass 2 (2026-10-31).
Cards: Task 0 #535, Task 1 #524 + #527 (reused), Tasks 2-12 #536-#546.
**Branch**: `feature/20261031_Sprint_83` (cut from the Sprint 82 branch, Phase 6.6) | **PR**: draft, created at 3.3.1
(stays draft until 7.7.5)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads on 2026-10-31;
file:line evidence is in each card.

## Objective

Finish the 0.23.0 checks on the phones (MV-3, MV-4, M-6). Give the user control over scan notifications (F322). Stop
the destructive F306 suggestion on a check that did not run, and add the next suggestion kinds (F323). Tell the user
when a re-added account has background scanning off (F324). Start the recommendation work on the safe-sender side
(F270, F309, F310) and widen the delete side (F305 R-2, F308). Start the Python conversion of the tooling with a pilot
(F321). Quiet the Android build noise (F237). Run a first-run evaluation (F325, a copy of the F152 template).

**Scope (Harold, 2026-10-31, verbatim)**: *"Sprint 83 Scope should include the below items. Please complete sprint
planning (/docs/sprint_planning.md) for the below items and present for approval."* The items: the Manual Validation
carry-ins (MV-3, MV-4, M-6); F322 (*"For android I know there are Notification sub-settings and this is where the
setting should go for Android - discuss if this was not what you were going to do. For other platforms I am not sure
if this is possible to do the same way or not."*); F323; F324; F303; and *"Also"* F270, F315, F305, F323, F308, F321,
F309, F310, F237, F152 (*"Add a copy of F152 for this sprint"*).

Card id assigned here: the Sprint 83 copy of F152 is **F325**. F303 and F315 are the MV-4 checks (cards #524 and
#527), so they are one task with MV-3 and M-6. F323 appears twice in the scope list; it is one task.

**iOS (Harold, 2026-10-31)**: *"q1 it will be Monday afternoon before I can call about it."* Apple has not approved
enrollment `R6QG2A9SHS`. F67a (#509), F304 (#510) and F67b (#523) are NOT in this scope and stay open. If Apple
approves during the sprint, adding them is a scope change for Harold to approve then.

**Parity (Harold, 2026-10-30 and 2026-10-31, verbatim)**: *"everything needs to take into account the Windows App,
Android app and the iPhone app with the ADR stating that everything should be functionally and UI the same unless it
cannot be - and where it cannot be it should be implemented as a platform exception for what is needed -- this
applies to all backend code, frontend code, data, architecture, development, security, testing, deployment."* Every
card has a **Parity (ADR-0042 / ADR-0049 / ADR-0050)** line naming the Windows, Android and iOS paths. It either
claims parity and names the OS behavior assumed identical, or declares the exception. iOS answers come from
`PlatformCapabilities` (ADR-0049) and ADR-0050. No new bare `Platform.isX` checks (the F294 policy test refuses them).
The iPhone build cannot be run this sprint (Apple), so iOS paths are proven by tests and the unsigned `ios.yml` build.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control, then the instance fix.

## Phase 2 and 3 checks (2026-10-31)

- Top-tier model: Opus 5.5. DONE.
- 2.2 / 3.1 Sprint number: 83 (Sprint 82 merged: PR #521 -> develop `f34be0d7`; develop -> main PR #533 `8f588043`,
  tag `v0.23.0`). DONE.
- 2.3 Sprint 82 cards: #522, #525, #526, #528-#532 closed by the merge; #509, #510, #523, #524, #527 open as intended
  ("Part of"). DONE.
- 2.4 Working tree clean; all work pushed. DONE.
- 2.6 Dependency check (`dart pub outdated`, 2026-10-31): 107 packages; discontinued: `js` (transitive); direct
  packages a major version behind: app_links, battery_plus, connectivity_plus, enough_mail, file_picker,
  flutter_appauth, flutter_secure_storage, googleapis, package_info_plus, syncfusion_flutter_xlsio. No security
  advisory found by this check. No action this sprint (a dependency change needs Harold's approval); recorded.
- Phase 8 cycle: 8.1 main merge done; 8.2 pass 1 done (f70e44bd); 8.3 0.23.0 MSIX and AAB built and verified
  (e996f784), uploads are Harold's; 8.4 pass 2 scope selected (above). DONE.
- 3.2.1 `docs/sprints/SPRINT_82_SUMMARY.md` exists; the Past Sprint Summary row for 82 exists. DONE.
- 3.2.2 this file. DONE (draft).
- 3.3 Branch `feature/20261031_Sprint_83` exists and is pushed. DONE.
- 3.3.1 Draft PR: created with this plan (number recorded in `.claude/sprint_status.json`).
- 3.4 / 3.5 Cards: created at 3.7.0, the first action after approval (one per task). #524 and #527 are reused for
  Task 1 (no duplicates).
- 3.6.1 Architecture Impact Check: below.

## Tasks, order, models and estimates

Estimates are minutes. Cards keep the backlog estimates Harold selected; re-estimates cite their reason.
`[no-history]` marks a step-type with no samples in `CODING_VELOCITY.md`.

- **Task 0 -- Version bump 0.24.0+21** (3.7.0b). MINOR: F322 and F270 are user-facing `feat`s. Haiku. 10-15m.
- **Task 1 -- Manual Validation carry-ins** (MV-3, MV-4 = F303 #524 + F315 #527, M-6). Main session. 30-45m plus
  Harold's phone time; waits on the 0.23.0 Play rollout reaching the Fold.
- **Task 2 -- F322**: notification choice "only when there are No Rule items". Sonnet. 60-120m -> 90-150m (3.2.2.2:
  Android channel split and the Android 7.x fallback, see the card).
- **Task 3 -- F323**: F306 v2 (Block Body, "could not check", `news_` sender shape). Sonnet. 120-240m.
- **Task 4 -- F324**: keep an account's settings across removal (Q3 = 3, deep dive) and tell the user when an added
  account has background scanning off; plus "Sign In Again" for iCloud (R-4, added 2026-11-01). Sonnet. 45-90m ->
  90-150m (Q3 deep dive) -> 120-195m (R-4).
- **Task 5 -- F270**: suggested safe senders from stored history, plus Sent-folder reply-pair mining of Harold's own
  mail (Q7). Sonnet. 150m -> 150-240m -> 165-270m (Q7-echo: Accept offers the three choices).
- **Task 6 -- F305 R-2**: widen the No Rule signals, proposed from the DEV content history. Sonnet. 60-90m.
- **Task 7 -- F308**: mine AOL Trash2 for delete-rule patterns (developer tool). Sonnet. 180-300m.
- **Task 8 -- F309**: research a trusted-sender source. Sonnet. 60-90m (research).
- **Task 9 -- F310**: mine safe-sender mail for safe-sender patterns (developer tool). Sonnet. 120-240m.
- **Task 10 -- F321 pilot**: Python common layer, the hook library and a small pilot set, plus backlog cards for the
  rest (Q9). Sonnet. 120-240m -> 135-255m.
- **Task 11 -- F237**: quiet the Kotlin daemon traces in the Android build. Haiku. 20-40m.
- **Task 12 -- F325 (copy of F152)**: first-run evaluation on Windows and Android. Main session, interactive with
  Harold. 120-180m plus Harold's time.
- **Conditional (asked first, not in the total)**: F315 Step 2 date-cursor design, only if the MV-4 count is above
  zero (Class 1); F305 R-2 signal changes, asked as one numbered question with the counts.
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 150-250m.

**Total**: Tasks 0-12 about 1,260-2,155 minutes (after the Phase 3.7 answers, Q7-echo and Task 4 R-4), plus the
150-250 allowance, plus Harold's phone and first-run time.

**When can Harold come back (first Manual Validation handoff)**: Task 1 runs as soon as the Fold has 0.23.0 from Play
(Harold's upload). For the code tasks, about 12-18 hours of wall-clock serially; with the parallel blocks below,
about 7-10 hours.

**Order**:
1. 3.7.0 cards (#524, #527 reused), 3.7.0b version bump, 3.7.1 PR body.
2. Parallel block A (sub-agents, different files): Task 2 F322, Task 4 F324, Task 11 F237 (no build may run while
   another build runs; F237's timing builds are serialized with any other build), Task 8 F309 research.
3. Parallel block B: Task 3 F323, Task 6 F305 R-2 (both read the content history; Task 6 only reads), Task 10 F321.
4. Task 7 F308 (needs Q5's answer for the Trash2 read), then Task 9 F310 (same tool mode), then Task 5 F270 (uses
   Task 9's findings where they apply; v1 does not depend on them).
5. Task 1 whenever the Fold has 0.23.0; Task 12 F325 with Harold at a time he chooses (needs an empty first-run
   state, see the card).

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b)): Tasks 2, 3, 4, 6,
8, 10 and 11 are delegated to sub-agents on their assigned tier before Manual Validation, with the delegation
checklist and the "Progress and restart" block verbatim. Tasks 1 and 12 are interactive and run in the main session.
Anything run in the main session executes on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand on the draft + pr-review-toolkit code-reviewer and
silent-failure-hunter, with the changed-file list), started with the retrospective prompt at Manual Validation
complete.

**Cards**: created at Phase 3.7.0. One "Closes #N" per card in the PR body.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md` Standing Approval Inventory), so
they are not asked again: (a) Task 0 the version bump; (b) Task 2 a new Android notification channel (created once,
cannot be changed later by the app) and any database setting key it needs; (c) Task 10 changes under `.claude/` and
`.claude/settings.json` hook registrations for the pilot hooks only, with `.claude\hooks\run-test-cases.ps1` green
after each change; (d) Task 11 one line in `mobile-app/android/gradle.properties` if Q8 selects it; (e) Task 7 and
Task 9 read-only use of the DEV content history and the DEV database. Not covered, still asked: Q5 (reading the DEV
AOL credential), any dependency version change, any edit to `secrets.*.json`.

## Phase 3.2.2.1 branch-state verification (summary)

- **MV-3 / MV-4 / M-6**: need 0.23.0 on the Fold. The 0.23.0 AAB (versionCode 20) is built and verified
  (`mobile-app\dist\android-0.23.0+20\app-prod-release.aab`); the upload is Harold's. F303 code shipped Sprint 81
  (5b87e362); F315's marker and per-scan count line exist (`imap_uid.dart:18`, `generic_imap_adapter.dart:1745-1750`).
- **F322: confirmed open.** One Android channel today, `background_scan_channel`
  (`scan_complete_notifier.dart:91-95`), and a separate `sign_in_needed_channel` (`:156-160`). `post` takes
  `noRule` (`:112`) but posts for every completed scan. No setting exists. Android `minSdk` resolves to 24
  (`android/app/build.gradle.kts`); channels exist only from API 26.
- **F323: confirmed open, and R-2 needs more input than the code passes today.** `RuleSuggestion.suggest`
  (`rule_suggestion.dart:150-176`) receives only the class NAME (`green`/`yellow`/`red`/`grey`). `classify`
  (`auth_results_parser.dart:153-180`) maps temperror and permerror to YELLOW, so the YELLOW basis
  (`:183-204`) suggests Block Entire Domain on a check that did not run. The two callers are
  `email_scan_provider.dart:870` (scan time) and `results_display_screen.dart:74` (pop-up time).
- **F324: confirmed, cause found.** `DataDeletionService.deleteAccountData` deletes every `account_settings` row for
  the account (`data_deletion_service.dart:99-103`), including `background_enabled`. A re-added account then
  resolves through `getEffectiveBackgroundEnabled` (`settings_store.dart:1071-1077`) to the app-wide default, which
  is off on DEV. The worker skips it (`android_background_scan_worker.dart:339-343`; the Windows worker reads the same
  setting) and only the log says so.
- **F270: confirmed open.** No "Suggested safe senders" text in `lib/`. The screen is
  `safe_senders_management_screen.dart`.
- **F305 R-2: open.** R-1 not needed (Sprint 82 Task 6 counted the signals on the content history).
- **F308 / F310: open.** The tools to extend exist: `mobile-app/tool/rule_eval/` (F267) and
  `mobile-app/tool/rule_miner/` (F268). The content history is `content_history_store.dart`.
- **F309: open** (research; nothing in `docs/research/`).
- **F321: open.** No Python hook exists in `.claude/hooks/`.
- **F237: open.** `mobile-app/android/gradle.properties` has no Kotlin setting.
- **F325 (F152 copy): new.** The template is `ALL_SPRINTS_MASTER_PLAN.md` F152 (method and the 7-section checklist).

**Phase 3.2.2.2 (re-estimates)**: F322 60-120m -> 90-150m (the Android channel split and the Android 7.x fallback
add work). F270 150m -> 120-180m (v1 only, Q4). No other card changed.

## Phase 3.6.1 Architecture Impact Check

- **ADR-0048 (notifications, one plugin)** and **ADR-0049 (PlatformCapabilities)**: F322 adds a notification
  choice. If Q1 = 1 or 2, Android's OS channel settings are a declared platform exception, recorded in ADR-0049's
  table and ARCHITECTURE.md (the ScanCompleteNotifier row) in the same commit.
- **Data model**: F322 adds one app setting (no schema change; `app_settings` key). F323 may add a suggestion type
  and reason codes (stored in the existing v17 columns; no schema change expected; the card checks first). F324 none
  (Q3 decides whether removal keeps the setting).
- **ADR-0047 (content history, DEV only)**: Tasks 6, 7 and 9 read it; F308 may add rows from the AOL Trash2 read
  (DEV only).
- **F321**: a new tooling language for hooks and scripts. A short ADR (ADR-0051, "Python for deterministic
  tooling") is written in Task 10, because it changes how every hook is registered.
- **F270**: a new list on the Safe Senders screen (ARCHITECTURE.md screen list).
- No ADR conflicts found.

## Carried from the Sprint 82 close-out (stub content, kept)

- **0.23.0 store release (Phase 8.3, Sprint 82 cycle)**: the MSIX and AAB are built and verified
  (`STORE_VERSION_STATUS.md`). Owner step on the installed 0.23.0 MSIX: click one background-scan toast with the app
  OPEN and one with it CLOSED, and record both; only then may the Windows notes claim the click. Also open: the Step
  4.2 Gmail sign-in URL check on the installed Store build.
- **Retro carry-ins (live rules)**: IMP-1 the 5.1.2 silent-failure walk covers every language in the diff; IMP-2 a
  test's "does NOT catch" note is checked against what the docs promise, and every Manual Validation rehearsal line
  cites its evidence (otherwise NOT REHEARSED); IMP-4 a card's "Signal fires on" line names the "could not check"
  inputs; IMP-5 the backslash hook blocks `python -c` with a backslash in both shells; IMP-6 every clock time in a
  reply or record comes from the clock in the same turn; IMP-7 `warn-commit-without-velocity.ps1` warns when a
  task-closing commit leaves out its velocity row. IMP-3 was replaced by F321 (Task 10).
- **Standing facts (Harold)**: Fold notification access for the app is ON and stays on. The iCloud DEV account's
  per-account background scan is on, every 5 minutes (re-enabled 2026-10-31).

---

# Cards

## Task 0 -- Version bump 0.24.0+21 (3.7.0b)

**Value**: This lets a tester tell the Sprint 83 build from the 0.23.0 store builds.

**Requirements**:
- R-1: `version: 0.24.0+21` and `msix_version: 0.24.0.0`; every version literal follows (`version_consistency_test`).
- R-2: PROVISIONAL `docs/store-assets/RELEASE_NOTES_0.24.0_windows.md` and `_play.md` (range: after 0.23.0).
- R-3: if Harold has reported the 0.23.0 Play upload by then, move "Last uploaded to Play" to 0.23.0 (versionCode 20)
  in `STORE_VERSION_STATUS.md` in the same commit; otherwise leave it.

**Affected components / files**: `mobile-app/pubspec.yaml`; version literals found by the gate; the two notes files;
`docs/STORE_VERSION_STATUS.md` (Dev row).

**Acceptance criteria**:
- AC-1: `version_consistency_test`, `dev_version_ahead_test` and `release_notes_test` pass.

**Tests to write**: none new (the three gates are the tests).

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- mechanical edits guarded by three gates.

**Step-types**: DOCS, SVC-EDIT. **Est-Effort**: 10-15m.

## Task 1 -- Manual Validation carry-ins: MV-3, MV-4 (F303 #524, F315 #527), M-6

**Value**: This proves the 0.23.0 notification tap and the F306 pop-up on a phone, and closes two evidence cards.

**Requirements**:
- R-1 (MV-3, Fold, 0.23.0 closed test): after the Fold updates (Settings top bar shows "Version 0.23.0"), with
  background scanning on: open Review No Rule Items, press Home, wait for a scan notification with "No rule" above 0,
  tap it. Expected: the app comes forward and the list already shows the new items, with no Refresh. A new YELLOW
  item's pop-up shows "Suggested"; Block Subject and the regex note fit the cover screen with no clipping (watch the
  Skip row). A pass lets the next Play notes mention the tap.
- R-2 (MV-4): Harold connects the Fold over USB (file transfer); Claude runs `scripts\pull-phone-screenshots.ps1
  -Sprint 83` and reads the `[new-mail-diagnostics]` line from the first start after the update AND a later start
  (every field present, no `error:` field: closes F303 #524). Count no-UID lines ("message has no valid IMAP UID",
  "FETCH answer had no UID") per account and folder, the same for the S24+ if connected; record with the Windows DEV
  count (0 in 1,171 `scan/persist` lines). Zero closes F315 #527 with the counts; above zero raises the F315 Step 2
  Class 1 question.
- R-3 (M-6, Windows DEV): click account 1's notification while that account's background worker is still scanning
  (two processes register the same activation class). Record which process handles the click and whether Review No
  Rule Items opens.

**Affected components / files**: none (validation); `docs/sprints/SPRINT_83_PLAN.md` results; the Play notes if MV-3
passes.

**Existing behavior relied on**: the F319 resume reload and click routing -- verified at MV-1b/MV-1c on Windows DEV
(`SPRINT_82_PLAN.md` Manual Validation); Android path from the same shared code, not yet run on a phone.

**Dependencies / blockers**: Harold uploads the 0.23.0 AAB to closed testing; the Fold receives the update.

**Acceptance criteria**:
- AC-1: MV-3, MV-4 and M-6 each recorded PASS or FAIL with evidence (screenshot name or log line).
- AC-2: #524 and #527 closed with their counts, or kept open with the reason.

**Tests to write**: none (manual validation; failures become fixes under the allowance).

**Definition of Done**: rehearsal note per Sprint 77 IMP-1: each step's preconditions are checked on DEV first where
possible (the Windows M-6 step), and each rehearsal line cites its evidence.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: MV-3 is the Android run of shared code already passed on Windows; iOS
waits on TestFlight (Apple). MV-4 F303 is Android only (declared, ADR-0049). F315 is the shared IMAP adapter on all
three platforms. M-6 is Windows only (the toast activator is Windows's activation model).

**Model**: main session -- interactive with Harold's phone.

**Results so far (phone pull 2026-11-01, `validation-screenshots/sprint-83/`, Fold on 0.23.0)**:
- MV-3a (warm tap): PASS (Harold 2026-11-01). Notification "Back. scan ... completed, No rule 1" posted 8:13am; at
  8:22am the cover screen showed Review No Rule Items with the new item; no app-start log line at 8:22.
- MV-3b (cold tap): PASS. Two cold starts 14:44:01 and 14:44:28 with `action=SELECT_NOTIFICATION`; at 2:44pm the inner
  screen showed Review No Rule Items with the item.
- MV-3c ("Suggested" on a YELLOW item): NOT TESTABLE yet. The only No Rule item is RED ("Sign-in check failed"), so
  no mark is correct. The 2:45pm cover-screen pop-up showed no clipping. Harold's choice is open.
- MV-4 F303 (#524): PASS. Three `[new-mail-diagnostics]` lines, every field present, no `error:` field.
- MV-4 F315 (#527): PASS. 0 no-UID lines in 86 completed scans (2026-10-31 11:55pm to 2026-11-01 2:50pm); Windows DEV
  0 in 1,171. The F315 Step 2 conditional is not needed.
- M-6 (Windows DEV): open.

**Step-types**: MANUAL-VALIDATION, LOG-READ. **Est-Effort**: 30-45m plus Harold's time.

## Task 2 -- F322: notification choice "only when there are No Rule items" (Priority 30)

**Value**: This lets the user be told only when there is mail to review, instead of after every scan.

**Requirements**:
- R-0 (audit first, platform facts): confirm from each vendor's own documentation, cited in the card at execution:
  Android lets the user change or silence each notification channel in system settings and the app can open one
  channel's settings with `ACTION_CHANNEL_NOTIFICATION_SETTINGS` (VERIFIED 2026-10-31,
  developer.android.com/develop/ui/views/notifications/channels: "Users can modify the settings for notification
  channels"; channels exist from Android 8.0, API 26); Windows has no app-defined sub-settings for a desktop app's
  toasts (UNVERIFIED); iOS has no user-visible per-category notification switches (UNVERIFIED). If either unverified
  fact is false, the card follows the vendor page and records it.
- R-1: the choice has two values, "Every completed scan" and "Only when there are No Rule items". It is decided in
  shared code (`ScanCompleteNotifier.post` or `BackgroundScanCore`), so the Windows worker, the Android worker and the
  future iPhone worker all obey it. Default: Q2.
- R-2 (by Q1): where the user sets it, per platform (see Q1 for the options). The text is the same on every
  platform.
- R-3: the sign-in-needed notification (`sign_in_needed_channel`) is not affected.
- R-4: research other notification choices worth offering (a daily summary, quiet hours, per-account choice) and list
  them for Harold with what each needs per platform; build only what he selects (a later card).

**Affected components / files**:
- `mobile-app/lib/core/services/scan_complete_notifier.dart:91-128` -- the choice; Android channel(s).
- `mobile-app/lib/core/storage/settings_store.dart` -- one app setting.
- `mobile-app/lib/ui/screens/settings_screen.dart` -- the control (Settings > Background, next to the scan
  frequency; the exact place named at execution).
- `mobile-app/android/app/src/main/kotlin/.../MainActivity.kt` -- only if Q1 = 1 or 2 (open the channel settings).

**Existing abstraction checked**: `ScanCompleteNotifier` (one post path for both workers, ADR-0048);
`PlatformCapabilities` for the Android-only branch (ADR-0049).

**Existing behavior relied on**: every completed background scan posts one notification per account through
`ScanCompleteNotifier.post` (`scan_complete_notifier.dart:109`), called from the Windows worker
(`background_scan_windows_worker.dart:286`) and the Android worker (`android_background_scan_worker.dart:486`) -- read
2026-10-31.

**User-reachable control**: Settings > Background, "Scan notifications": "Every completed scan" / "Only when there
are No Rule items" (Windows, iPhone, and Android by Q1). On Android with Q1 = 1, the row reads "Scan notifications"
and opens Android's notification settings for this app, where the two channels are listed.

**Observable behavior -- before / after**: BEFORE: a notification after every completed background scan, even "No
rule 0". AFTER: with "Only when there are No Rule items", a scan with No Rule 0 posts nothing; a scan with No Rule 1
or more posts the usual notification.

**Dependencies / blockers**: Q1, Q2.

**Non-functional requirements**: Platform: no bare `Platform.isX`; the Android branch through `PlatformCapabilities`.
An Android channel's behavior cannot be changed by the app after it is created (Android docs), so channel ids and
importance are chosen once and recorded in the card.

**Acceptance criteria**:
- AC-1: with "Only when there are No Rule items", a completed scan with No Rule 0 posts nothing, and one with No Rule
  1 posts one notification; with "Every completed scan", both post (shared-code test, both workers' call paths).
- AC-2: the sign-in-needed notification posts in both settings.
- AC-3: the control is on the named screen with the same text on Windows and Android (widget test per platform
  answer from `PlatformCapabilities`).
- AC-4 (Q1 = 1 or 2): on Android 8.0+, the two channels exist with the names shown in the card; on Android 7.x
  (API 24-25, no channels) the in-app choice applies.

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-UNIT `test/unit/services/scan_complete_notifier_test.dart`: the choice gates the post;
  sign-in unaffected.
- T-2 (AC-3) -- TEST-WIDGET `test/ui/screens/settings_screen_test.dart`: the control, its text and the saved value.
- T-3 (AC-4) -- TEST-UNIT: the channel picked for a No Rule 0 scan versus a No Rule 1 scan.

**Definition of Done**: default DoD PLUS ADR-0049's exception table and ARCHITECTURE.md updated if Q1 = 1 or 2.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the decision (post or not) is shared Dart on all three. Where the user
sets it is Q1; options 1 and 2 declare an Android exception (OS channel settings). iOS uses the in-app choice and is
proven by T-1 and T-2 (no device this sprint).

**Result (Phase 4)**: built 2026-11-02 (Sonnet 5.5 sub-agent).
- **What**: `ScanCompleteNotifier.post` now decides WHETHER to notify (shared Dart, so the Windows worker, the Android worker and the future iPhone worker all obey it) and returns `ScanNotificationOutcome` (`posted` / `skippedByChoice` / `failed`) instead of a bool, so both workers' log lines tell a deliberate skip from a failure. Setting: one `app_settings` key `scan_notify_choice` (`every` / `noRuleOnly`), no schema change, default `noRuleOnly` (Q2 = 1).
- **User-visible control**: Settings > Background tab, directly under the "Scan every" control, a row titled "Scan notifications". Windows, iPhone and Android 7.x: a dropdown with "Every completed scan" and "Only when there are No Rule items" (default). Android 8.0+: help text "Android decides which scans notify you. Open Android notification settings and turn off "Scans with nothing to review" to be told only when there are No Rule items." and a button "Open notification settings" (native `ACTION_APP_NOTIFICATION_SETTINGS`, falls back to App info below API 26). If the page cannot be opened the row says so.
- **Android channels (chosen once, cannot change later)**: `scan_with_no_rule_channel` "Scans with No Rule items", Importance.low; `scan_nothing_to_review_channel` "Scans with nothing to review", Importance.low (low = no sound, the same as the old channel, so current testers see no change in loudness). The channel is picked by the No Rule count (above 0 = first).
- **Interaction of the in-app choice and the channels (judgment call, Q1 = 1)**: on Android 8.0+ EVERY completed scan posts and the in-app choice is NOT read and NOT shown (two controls for one outcome would disagree; the user silences channel 2 in Android). Android 8.0+ is detected without an API level: `ensureAndroidChannels()` creates both channels and asks the plugin for its channel list, which is empty below 8.0 (flutter_local_notifications 22.3.2, `platform_flutter_local_notifications.dart:584`). A failure of that probe falls back to the in-app choice (it can only silence what the user asked to silence) and is written to the diagnostic log. A choice that cannot be read notifies.
- **Old `background_scan_channel`**: never posted to again and DELETED (`deleteNotificationChannel`) when the new channels are created, so Android's list shows no dead entry. Side effect: a tester who had silenced the old channel gets notifications on the new ones until they silence a new one (they were all Importance.low, so this is quiet).
- **R-3**: `postSignInNeeded` and `sign_in_needed_channel` untouched; tested under both choices.
- **ADR-0042 paths**: Windows (toast, in-app choice) and Android (8.0+ channel exception, 7.x in-app) run the same `post`; iOS runs the in-app branch through the same shared code (T-1 covers `HostPlatform.ios`); no device this sprint. Declared in ADR-0049 (new bullet after `notificationDelivery`) and docs/ARCHITECTURE.md (ScanCompleteNotifier row). No new `PlatformCapabilities` getter (the existing `notificationDelivery == androidChannel` is read), so no bare `Platform.isX`.
- **Catch walk (Sprint 81 IMP-3)**: new early exits are the `skippedByChoice` return in `post` (no throw). `_readChoice` catches its own read failure and returns `every`; `ensureAndroidChannels` catches everything and returns false; the Android row catches in `AndroidNotificationSettings.open` (returns false) and the row shows a message. No exception crosses into the scanner, so no catch between a throw and a handler exists (`grep` for `ScanCompleteNotifier.post` shows only the two workers and `BackgroundScanCore.completeAccount`; the worker `try` at `background_scan_windows_worker.dart` around the post would log a failure, and the Android worker passes the call into `completeAccount`).
- **Files**: `lib/core/services/scan_complete_notifier.dart`, `lib/core/services/android_notification_settings.dart` (new), `lib/core/services/background_scan_core.dart`, `lib/core/services/android_background_scan_worker.dart`, `lib/core/services/background_scan_windows_worker.dart`, `lib/core/storage/settings_store.dart`, `lib/ui/widgets/scan_notifications_row.dart` (new), `lib/ui/screens/settings_screen.dart`, `android/app/src/main/kotlin/com/myemailspamfilter/MainActivity.kt`; tests `test/unit/services/scan_complete_notifier_test.dart` (new, T-1/T-3), `test/ui/screens/settings_scan_notifications_test.dart` (new, T-2), and three updated for the enum (`test/unit/scan_complete_notifier_test.dart`, `f238_stopped_background_outcome_test.dart`, `mv74_2_scan_heartbeat_test.dart`); docs ADR-0049, ARCHITECTURE.md, CHANGELOG.md.
- **Tests / mutation**: the five affected test files pass (86 tests). Mutation (`scripts/mutation-test.ps1`, 10 mutants, every one compiled): 10 of 10 KILLED (gate never skips, channel pick inverted, Android 8+ ignored, default flipped, unreadable choice hides the scan, sign-in gated, skip reported as posted, row wrong branch, choice not saved, row missing from the Background tab). `flutter analyze`: No issues found.
- **What the tests do NOT catch**: that Android lists and honors the two channels, that `getNotificationChannels` is empty on a real Android 7.x device (read from plugin source only), that the native settings page opens (emulator / phone check), and the on-screen position of the row (a source gate checks it is built in the Background tab, not where).
- **R-0 (vendor facts, read 2026-11-02)**: (1) Android: confirmed, developer.android.com/develop/ui/views/notifications/channels ("Users can modify the settings for notification channels"; channels from Android 8.0). (2) Windows: VERIFIED as far as Microsoft documents it. learn.microsoft.com/windows/apps/develop/notifications/app-notifications (updated 2026-10-14) lists the app notification features and has no app-defined channel or category setting; the "headers" page (updated 2026-04-21) says headers "visually group" notifications in Notification Center and change nothing else. Absence in docs is evidence, not proof. (3) iOS: UNVERIFIED. developer.apple.com pages return no body text to the fetch tool (JavaScript-rendered), so no sentence could be quoted. From memory only: iOS shows no switch per app-defined category, and `providesAppNotificationSettings` lets the app add a button in iOS Settings that opens the app's own notification screen, which fits the in-app choice. Settle by reading the Apple pages in a browser before F67c.
- **R-4 research (no code; for Harold to select)**: (a) Daily summary: one notification per day listing counts per account. Needs a scheduler per platform (WorkManager periodic or alarm on Android; Task Scheduler on Windows; BGAppRefresh on iOS, best effort, no exact time) plus storing the day's counts; the completion notifications would be suppressed or merged. Medium. (b) Quiet hours: no notifications between two times. Shared Dart check in `post` against two stored times; trivial on every platform; on Android 8+ Android's own Do Not Disturb already covers it, so the in-app setting would be Windows, iPhone and Android 7.x only (Windows has Focus Assist for the same purpose). Small. (c) Per-account choice: the choice per account instead of app-wide. The store already has per-account settings (`account_settings`), so the check moves from app-wide to `(accountId)`; the Settings row would live on the account's Background tab. On Android 8+ channels are app-wide, so a per-account choice cannot be an OS channel setting (it would need per-account channels created at account add and deleted at remove) - so it is shared Dart with an in-app control on all platforms. Small to medium. (d) Also worth listing: notify on errors only (errors above 0 with No Rule 0), a choice F322 does not offer (a scan with errors and No Rule 0 now posts nothing under the default).
- **Judgment calls**: (1) a scan with Errors above 0 but No Rule 0 is skipped under the default, as the card says "No Rule"; flagged in (d). (2) `post` returns an enum, which changed `BackgroundScanCore.completeAccount`'s `notify` callback type (three test call sites updated). (3) Importance.low for both channels (matches the old one). (4) The row is app-wide, shown whether or not this account's background switch is on.
- **Not done**: no Windows or Android build (told not to); no commit or push; full-suite result recorded in the report to the coordinator.

**Model**: Sonnet -- a shared decision plus one declared platform exception across 3-4 files; beyond Haiku's
heuristics.

**Step-types**: SVC-EDIT, UI-ADD, NATIVE-ANDROID, TEST-UNIT, TEST-WIDGET. **Est-Effort**: 90-150m.

_**Decision-class interrupts**_: Q1 (Class 2, where the setting lives), Q2 (default).

## Task 3 -- F323: F306 v2 -- Block Body, "could not check", and the `news_` sender shape (Priority 34)

**Value**: This prevents a destructive suggestion built on a check that did not run, and adds the next two
suggestion kinds.

**Requirements**:
- R-2 FIRST (prevention, 7.7.1 M-4): `suggest` receives the per-method results (SPF, DKIM, DMARC), not only the class
  name. When any method is temperror or permerror, there is no suggestion, and the pop-up shows "Could not check
  this sender (the mail server's check did not finish)" in place of the "Suggested" mark. Both callers
  (`email_scan_provider.dart:870`, `results_display_screen.dart:74`) pass the results.
- R-1 (MV Q2 = 3): a Block Body button sharing the row Block Subject uses today, as two half-width cells. Its value
  (Q4, Harold 2026-11-01): the domain of the FIRST body link whose domain does not exactly match the sender's email
  domain, skipping any link domain that is a safe sender (exact domain or entire domain); if no link qualifies, no
  Block Body suggestion is shown. The body is fetched when the pop-up opens.
- R-3 (retro Q5 = 2): a sender-shape suggestion for `news_` plus 4-6 digits at any domain, as a From-header regex
  block rule, by Q6.
- R-4: no new stored column unless a check shows the v17 columns cannot hold the new kinds (the card states which).

**Affected components / files**:
- `mobile-app/lib/core/services/rule_suggestion.dart:150-204` -- input, the "could not check" result, new bases.
- `mobile-app/lib/core/services/auth_results_parser.dart` -- read only (method results are already parsed).
- `mobile-app/lib/core/providers/email_scan_provider.dart:870` and `ui/screens/results_display_screen.dart:74` --
  callers.
- `mobile-app/lib/ui/widgets/email_detail_popup.dart` -- the Block Body cell and the "could not check" note.
- `mobile-app/lib/core/services/rule_quick_action_service.dart` -- the body and sender-shape patterns.

**Existing abstraction checked**: `RuleSuggestion` basis list (`rule_suggestion.dart:178`) and its RED guard;
`RuleQuickActionService.blockPatternFor`.

**Callers of any guard being changed**: `RuleSuggestion.suggest` has two callers (scan time and pop-up time); both
gain the method results; the change makes both return null on temperror or permerror.

**Signal fires on**: R-2 fires when any of SPF, DKIM, DMARC is temperror or permerror; the DEV count is taken at card
time from the content history (it stores `auth_class` only, so the count needs the headers: the card names the
method, for example the Sprint 82 probe's counts or a DEV scan-time tally). R-3 fires on `news_<4-6 digits>@`: on DEV
2,225 emails from 102 domains, all in AOL Bulk, none a safe sender; 100 current No Rule senders from 76 domains
(2026-10-31). Inputs that mean "could not check": temperror, permerror, no auth headers (GREY); for these the pop-up
shows the "could not check" note (temperror/permerror) or nothing (GREY, unchanged).

**Observable behavior -- before / after**: BEFORE: a YELLOW sender with a temperror can show "Suggested" on Block
Entire Domain; Block Subject has its own row; no sender-shape suggestion. AFTER: that sender shows "Could not check
this sender"; Block Subject and Block Body share one row; a `news_123456@...` sender shows "Suggested" on the shape
rule (by Q6).

**Dependencies / blockers**: Q4, Q6.

**Acceptance criteria**:
- AC-1: temperror or permerror on any method returns no suggestion and the pop-up shows the note (both callers).
- AC-2: a YELLOW sender with softfail and no error still gets the F306 suggestion (no regression).
- AC-3: the Block Body cell shares the row with Block Subject and saves the Q4 value as a body rule.
- AC-4: a `news_<digits>` sender gets the shape suggestion; a `news_` sender with letters after it does not.
- AC-5: a RED sender is never suggested as a safe sender (the existing guard still holds).

**Tests to write**:
- T-1 (AC-1, AC-2, AC-5) -- TEST-UNIT `test/unit/services/rule_suggestion_test.dart`.
- T-2 (AC-1, AC-3) -- TEST-WIDGET `test/ui/widgets/email_detail_popup_test.dart`, including a narrow width (the Fold
  cover screen).
- T-3 (AC-4) -- TEST-UNIT: the shape regex against matching and non-matching senders.

**Definition of Done**: default DoD PLUS each test's "what this does NOT catch" line; mutation-verified.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart and one shared widget on all three; the narrow-width test
covers the Fold cover screen and small iPhones. No platform branch.

**Model**: Sonnet -- three related changes across the builder, two callers and the pop-up.

**Step-types**: SVC-EDIT, UI-ADD, TEST-UNIT, TEST-WIDGET. **Est-Effort**: 120-240m.

**Result (Phase 4)** (2026-11-04, Sonnet; not committed)
- **R-2 (done first)**: `RuleSuggestion.suggest` takes a REQUIRED `authResult`; any temperror or permerror returns a NOTE before any basis runs. Caller walk (CLAUDE.md IMP-1): (1) `email_scan_provider.dart` (manual and background scans): passes `AuthResultsParser.parse(headers)`; a temperror row now stores the note instead of a block rule. (2) `suggestionForResult` in `results_display_screen.dart` (pop-up time): passes the parsed live headers; a saved scan from history has only the stored class and no headers, so it gets a synthetic no-error result and CANNOT show the note (boundary, stated). No third caller exists (grep of `lib/` and `test/`); four test files that called `suggest` were updated.
- **Judgment call 1 (deviation from the card text "return null")**: `suggest` returns the note (kind `none`), not null, because the Review screen reads stored rows and has no headers; only a stored value can carry "could not check" there. "No suggestion" holds: the note has no button, no regex and `isBlock` is false. The null alternative cannot satisfy AC-1 on the Review screen.
- **R-4**: no new column. The five v17 columns hold: the note (`none` / `note` / `auth_check` / pattern sentinel `-` / `auth_could_not_check`), the shape (`block` / `senderShape` / `news_digits` / `^news_[0-9]{4,6}@` / `sender_shape`) and the existing kinds. Block Body is NOT stored (the body is never persisted, SEC-14); the pop-up computes it on open. An older build reads a note row as a suggestion no button matches, so it shows nothing. `fromColumns` is unchanged.
- **Signal fires on (R-2)**: NOT DERIVABLE from stored data. DEV `email_actions`, `unmatched_emails` and `content_history` store the auth CLASS only (checked in a read-only COPY of the DEV database made in the scratchpad), so a temperror cannot be told from a softfail after the fact. Upper bound only: 150 of 814 `unmatched_emails` rows are YELLOW (the only class that can hold a temperror). Real count: the first live scan after this build stores the note; count `suggestion_kind = 'none'` then. R-3: 123 of 814 `unmatched_emails` rows match `news_` plus 4-6 digits, from 94 domains (SQL glob on the stored From; approximate).
- **R-3**: new basis, checked BEFORE the YELLOW basis (narrower statement; judgment call 2: a YELLOW `news_123456` sender now gets the shape, not Block Entire Domain). The R-2 guard also suppresses it on a temperror. Rule: From-header, stored as `header_from` / `exact_email` (closest known sub-type; Manage Rules lists it as "Exact Email"; judgment call 3).
- **R-1**: Block Body shares the row with Block Subject (two Expanded cells). `PopupBodyFetcher` (new, `popup_body_fetcher.dart`) reads the body when the pop-up opens: scan lease (15 s wait) then per-account claim (the F212 rules), `fetchFullBody`, disconnect, claim end, lease release, all in `finally`. Value: `firstOutsideLinkDomain` over the text/plain body the evaluator will match (HTML-only mail with no text part gives no suggestion: stated boundary). The saved rule is a `body` / `keyword` rule whose regex has look-arounds (`(?<![a-z0-9-])domain(?![a-z0-9-])`) so `evil.com` does not match `notevil.com` (judgment call 4; a plain escaped domain would, and a block rule deletes mail). Callers of the new types: both quick-action callers pass `null` for the safe-sender conflict check for `body` as for `subject`.
- **Catches between the fetch and the pop-up (delegation item 7)**: `gmail_api_adapter.dart` `fetchFullBody` and `generic_imap_adapter.dart` `_fetchMimeMessage` each CATCH a failed fetch and return the message unchanged (empty body); `PopupBodyFetcher.fetch` turns an empty body into `PopupBodyUnavailable`; `_resolveBodyLink` in the pop-up catches everything and shows "Could not read message". A failed fetch and a message with no text part look the same, so both say "Could not read message". `ScanAccountBusyException` and the lease `TimeoutException` take the same path (cell text, no dialog).
- **Judgment call 5**: Results screen reads a body only for No Rule results (a matched email has its answer; a body read opens a mail session); other results show Block Body "Not available". **Judgment call 6**: when an email has no subject the Subject cell is a disabled "Not available" placeholder (it used to be absent) so Body keeps its half-width place.
- **User-visible text (screen: No Rule Item pop-up, from Review No Rule Items and from Results)**: (1) "Block Body" cell, subtitles "Loading...", the domain, "No outside link", "Could not read message", "Not available"; tapping the domain saves a body rule and the snackbar says `Created rule to block mail whose body links to "<domain>"`. (2) "Block sender pattern", subtitle "news_ plus 4-6 digits, any domain", mark "Suggested", under the Block row, only for a matching sender; snackbar `Created rule to block senders named news_ plus 4 to 6 digits`. (3) The note "Could not check this sender (the mail server's check did not finish)" in place of "Suggested". Each label traced: the loading, found, none and failed subtitles map to `BodyLinkOutcome`; only `found` has a tap handler (test).
- **ADR-0042**: shared Dart and one shared widget; Windows and Android both reach the body through `SpamFilterPlatform.fetchFullBody` (Gmail API, IMAP); no platform branch. Narrow width: the 344 px test checks both cells share a row, stay inside the window and have no overflow in any button row. The 93 px overflow at that width comes from the existing date/account row (`email_detail_popup.dart` "Date/time" Row), not F323; recorded, not fixed here.
- **Test infrastructure**: a pop-up opened in an existing screen test now starts the fetcher, whose claim is a real database transaction that never completes under FakeAsync (10-minute hangs seen). Prevention: `PopupBodyFetcher.debugDisabled`, set for every test file by the new `test/flutter_test_config.dart`; the fetcher test turns it back on.
- **Tests / mutation**: 11 test files, 129 tests, all pass (5 new files: `f323_body_link_domain_test`, `f323_popup_body_fetcher_test`, `f323_wiring_test`, `f323_block_rules_test`, `f323_email_detail_popup_test`; the R-2 cases also in `rule_suggestion_test`, `f306_suggestion_storage_test` (scan caller) and `f306_results_suggestion_test` (Results caller)). Mutation (`scripts/mutation-test.ps1`, 13 mutants, every one compiled): 13 of 13 KILLED (guard never fires, permerror not an error, shape accepts 3 digits, YELLOW before shape, body regex without look-arounds, shape regex without `@`, sender domain not skipped, safe domain not skipped, Body cell tappable with no link, claim never ended, scan caller ignores real results, Results caller ignores live headers, body rule removes sender safe senders). Two guards rest on weaker checks: the `request.type == 'body'` null in the two screens' conflict argument is a source gate only (`f323_wiring_test`), and the service-level guard is behavior-tested (M13).
- **What the tests do NOT catch**: a real IMAP or Gmail body (fakes only); a real background scan holding the account in another process (the busy claim is simulated); how the cells look on the real Fold cover screen; the two screens' closures beyond a source gate; a saved scan from history showing the note.
- **Not done**: no build or on-device run; no commit or push.

## Task 4 -- F324: tell the user when an added account has background scanning off (Priority 36)

**Value**: This prevents an account from silently stopping background scans after it is re-added.

**Requirements**:
- R-1 (prevention first): when an account is added or re-added and `getEffectiveBackgroundEnabled` is false, the
  Account Selection screen shows, under that account, "Background scanning is off for this account" with a "Turn on"
  button that sets the per-account setting (the same setting as Settings > Background).
- R-2 (Q3 = 3, Harold 2026-11-01: keep the account's settings across removal for the same address, *"do a deep dive
  to ensure only what is needed on a re-add is kept, everything that needs to be refreshed with a re-add is
  refreshed"*): first list EVERY per-account store (each `account_settings` key, scan results and No Rule rows, the
  Gmail history cursor and the oldest-No-Rule cursor per folder, the background schedule rows, the sign-in-required
  flag, credentials and tokens, the DEV content history) and classify each as KEEP (user choices: folders, scan modes,
  background on/off and frequency, days back, target folders, new-mail trigger), REFRESH (anything tied to the old
  sign-in or server state: credentials, tokens, sign-in-required flag, cursors, schedule rows) or DELETE (scan data
  the user chose to remove). Record the table in this card with file:line for each, then implement it.
  `DataDeletionService.deleteAccountData` keeps the KEEP set; the add flow refreshes the REFRESH set.
- R-3: the worker's skip line stays in the diagnostic log (evidence for Claude); R-1 is the user's view.
- R-4 (added by Harold 2026-11-01, iCloud answer = 1): when an iCloud account's sign-in fails
  (`AUTHENTICATIONFAILED`; 17 background errors on the Fold 2026-10-29 to 2026-11-01), the Select Account screen shows
  "Sign In Again" for it, the same control Gmail shows today. The card first finds why Gmail gets the control and
  iCloud does not (which flag sets it, and which error paths set that flag), then extends the connected existing
  mechanism to IMAP authentication failures (prevention first), for every IMAP provider, not iCloud only.

**Affected components / files**:
- `mobile-app/lib/ui/screens/account_selection_screen.dart` -- the line and the button.
- `mobile-app/lib/core/storage/settings_store.dart:1071-1077` -- read only (the resolver).
- `mobile-app/lib/core/services/data_deletion_service.dart:99-103` -- only if Q3 = 2 or 3.

**Existing abstraction checked**: `SettingsStore.getEffectiveBackgroundEnabled` (the three-tier resolver; Sprint 72
IMP-5: use it, do not re-implement it).

**Existing behavior relied on**: account removal deletes every `account_settings` row
(`data_deletion_service.dart:99-103`); the resolver then returns the app-wide default (`settings_store.dart:1076`) --
read 2026-10-31.

**User-reachable control**: Account Selection screen, under the account: "Background scanning is off for this
account" and a "Turn on" button.

**Observable behavior -- before / after**: BEFORE: a re-added account shows nothing; background scans for it stop and
only the log says why. AFTER: the account's row says background scanning is off, with "Turn on".

**Dependencies / blockers**: Q3.

**Acceptance criteria**:
- AC-1: Given an account whose effective background setting is off, When the Account Selection screen shows, Then
  the line and the button show under it; for an account with it on, nothing shows.
- AC-2: "Turn on" sets the per-account setting to true and the line goes away.
- AC-3 (Q3 = 2 or 3): removing and re-adding an account keeps its background setting.

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-WIDGET `test/ui/screens/account_selection_screen_test.dart`.
- T-2 (AC-3) -- TEST-UNIT `test/unit/services/data_deletion_service_test.dart` (if Q3 = 2 or 3).

**Definition of Done**: None -- default DoD only.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart screen and resolver on all three; the Windows and Android
workers read the same setting. iOS background (F67c) is not built yet; the line uses the same resolver.

**Model**: Sonnet -- touches the account screen and possibly the deletion service; a resolver must be reused, not
copied.

**Step-types**: UI-ADD, SVC-EDIT, TEST-WIDGET. **Est-Effort**: 120-195m (45-90m backlog; Q3 deep dive; R-4).

_**Decision-class interrupts**_: Q3 (Class 2 if removal stops deleting a setting).

**R-2 deep dive: every per-account store (Phase 4, read 2026-11-02; Q3 = 3 approves the Class 2 change)**

KEEP (user choices; `account_settings` rows, kept on removal and on re-add; key -> getter in `settings_store.dart`):
- `folders` (574), `scan_mode` (592), `manual_scan_mode` (839), `manual_scan_folders` (857),
  `background_scan_mode` (879), `background_scan_folders` (897), `manual_days_back` (919), `background_days_back`
  (937): the folders, scan modes and days back the user chose.
- `background_enabled` (610), `background_frequency` (684), `new_mail_trigger` (621): background on/off, frequency, the
  new-mail trigger.
- `deleted_rule_folder` (778), `safe_sender_folder` (795): the target folders the user chose.

REFRESH (tied to the old sign-in or server state; cleared on removal, and cleared again on re-add):
- `account_settings` key `gmail_sign_in_required` (641) and `gmail_sign_in_notified_at` (661): the sign-in-required flag
  and the once-a-day notice time.
- Credentials and tokens in secure storage (`SecureCredentialsStore.deleteCredentials`, `data_deletion_service.dart` credential
  block): removed on removal; replaced by the add flow.
- `account_folder_cursors` (`database_helper.dart:212`): the Gmail history cursor and the oldest-No-Rule cursor per
  folder. A new sign-in or server can have different UIDs and history ids.
- `background_scan_schedule` (`database_helper.dart:350`): next-run rows.
- `auth_rate_limit` (`database_helper.dart:416`): a failed-password lockout count must not follow a new password.
- `accounts` row (`database_helper.dart:196`, `last_history_id`).
- `account_settings` key `schedule_slot` (`settings_store.dart:744`): an internal start-stagger allocation, not a user
  choice. Deleted on removal (as today), so the slot is freed; the next schedule allocates again.

DELETE (scan data; the user chose to remove it, as today): `scan_results` (`database_helper.dart:224`), `email_actions`,
`unmatched_emails` (both reached through `scan_result_id`), `background_scan_log` (`database_helper.dart:397`), and the DEV
content history rows (`ContentHistoryStore.deleteAccount`).

Callers of `deleteAccountData` (Sprint 72 IMP-1; grep over `lib/` and `test/`):
- `account_selection_screen.dart` `_deleteAccount` (the only code caller): the user-visible delete button. After Q3 = 3 it keeps the KEEP set, so the
  confirmation text no longer says "Per-account settings and overrides" are removed; it says the folder, scan and
  background choices are kept for the same address.
- `Settings > General > Reset App > Delete All Data` does NOT call it: it calls `wipeAllData` (`DatabaseHelper.deleteAllData`),
  which still deletes every row, including the KEEP set. "Delete all my data" therefore still deletes everything.
- Tests: `test/unit/services/data_deletion_service_test.dart` and `test/policy/r76_4_content_history_policy_test.dart`
  (group R7: asserts every account table is cleared; the KEEP rows are `account_settings` only, which that test treats
  through the existing path).

**R-4 cause: why Gmail gets "Sign In Again" and IMAP does not (read 2026-11-02)**
- The control shows when `AccountDisplayData.signInRequired` is true (`account_selection_screen.dart:1043`). That value was
  read ONLY for `platformId == 'gmail'` (`account_selection_screen.dart:261-268`) from the `account_settings` flag
  `gmail_sign_in_required` (`settings_store.dart:641`).
- The flag is set ONLY by `GmailApiAdapter._setSignInRequired` (`gmail_api_adapter.dart:330-337`) on the paths that throw
  `GmailSignInRequiredException` (`gmail_api_adapter.dart:233-244, 300, 319`), and cleared at `gmail_api_adapter.dart:254, 271, 308`
  and `sign_in_again.dart:59`.
- The IMAP adapter turns a refused login (`AUTHENTICATIONFAILED`, `AUTHORIZATIONFAILED`, `EXPIRED`, or a plain `NO`) into a
  plain `AuthenticationException` (`generic_imap_adapter.dart:505-508`, classified at 564-579). It only counts the failure for the
  lockout (`_recordSignInFailure`, `generic_imap_adapter.dart:1999-2006`, called at 255 and at the reconnect, 2047). No flag, no
  skip, no notification. The worker has a catch for `GmailSignInRequiredException` only
  (`background_scan_core.dart:471`), so the IMAP failure was counted as a failed scan on every run (the 17 phone errors).
- A network error is a `ConnectionException` (`generic_imap_adapter.dart:272-278`) and a busy server is a
  `UserFacingConnectionException` (`generic_imap_adapter.dart:509-514`, classification 534-539); neither is an
  `AuthenticationException`, so neither sets the flag.

**Result (Phase 4)** (2026-11-02, Sonnet; not committed)
- KEEP / REFRESH / DELETE: as listed above. `DataDeletionService.deleteAccountData` now deletes `account_settings` rows
  with an allowlist (`accountSettingKeysKept`, 13 keys), so a key added later is deleted unless classified; the policy
  test `account_settings_classification_test` fails until a new key is classified. New `refreshForReAdd` clears the old
  sign-in state on re-add. The failed-password count was keyed `platform-address` and removal deleted by the bare
  address, so it survived removal; fixed (`_deleteRateLimit`).
- Callers of `deleteAccountData`: only `_deleteAccount` on the Account Selection screen (dialog text changed to say the
  choices are kept). `wipeAllData` (Reset App > Delete All Data) is unchanged and still deletes everything.
- R-4 cause: see above. Fix extends the same flag: `_recordSignInFailure` in `generic_imap_adapter.dart` (the one place a
  refused login is recorded, first sign-in and mid-scan reconnect) sets `gmail_sign_in_required`; a successful
  `loadCredentials` clears it. The worker (`background_scan_core.dart`) skips an IMAP refusal (platform ids aol,
  gmail-imap, yahoo, icloud, imap) and posts the once-a-day notice with the provider named (`providerName` through
  `GmailSignInNotifier`, `ScanCompleteNotifier.postSignInNeeded`, `ScanNotificationText.signInNeededTitle`). Gmail's plain
  `AuthenticationException` and the demo platform still fail. Catches between the throw (`generic_imap_adapter.dart:~508`)
  and the handler: `loadCredentials` catch (flag, rethrow), `email_scanner` per-folder catch (`isSessionFatal` rethrows),
  `email_scanner` outer catch (`errorScan`, rethrow), `finally` disconnect, then the new worker catch (skip).
- Files: `data_deletion_service.dart`, `generic_imap_adapter.dart`, `background_scan_core.dart`,
  `account_selection_screen.dart`, `account_setup_screen.dart`, `gmail_sign_in_notifier.dart`,
  `scan_complete_notifier.dart` (only `postSignInNeeded` gained `providerName`), `scan_notification_text.dart`
  (`signInNeededTitle` gained `providerName`), `CHANGELOG.md`; tests below.
- Tests: 31 new or updated tests pass (data deletion + classification gate 13, IMAP flag 6, worker skip 3, background-off
  and Sign In Again screen 7, repair flow 2). Existing tests adjusted for the screen's extra database reads:
  `account_selection_legacy_platform_test.dart` (mount and end windows). Mutation: 16 mutants, all KILLED
  (`scripts/mutation-test.ps1`, command form with `flutter test --timeout 4x`; M14 to M16 re-run after the last edit to
  `account_setup_screen.dart`). `flutter analyze`: no issues. Full suite (`--timeout 4x -j 2`): 3383 passed, 15 skipped,
  2 failed in `f302_no_valid_imap_uid_test.dart` (timing under machine load; the file passes alone, 16 of 16).
- User-visible controls: Account Selection list, under the account: "Background scanning is off for this account" and
  "Turn on"; for an IMAP account whose provider rejected the password: "<Provider> rejected the sign-in. Enter your
  password again." and "Sign In Again" (opens the add-account form with the address filled in). Notification title for
  that skip: "<Provider> sign-in needed for <masked address>".
- Judgment calls: reused the Gmail-named flag getters instead of renaming; "Turn on" does not request the Android
  notification permission; 'gmail-imap' repair opens the 'gmail' form (pick app password), custom 'imap' needs the server
  fields retyped; kept folder keys could mismatch if the address returns under a different provider (the F202 missing-folder
  skip covers it); the removed account's `schedule_slot` is still freed. ADR-0042: shared Dart on Windows and Android;
  scheduling goes through `BackgroundScanSchedulerFactory` (Task Scheduler / WorkManager), faked in tests.

## Task 5 -- F270 v1: suggested safe senders from stored history (Priority 30)

**Value**: This protects senders the user trusts before a broad block rule catches them (fewer false positives).

**Requirements**:
- R-1 (v1, stored data only): candidates are senders seen in No Rule mail at least N times (N set by the DEV count,
  stated in the card), whose stored authentication is GREEN (DMARC pass), never deleted by a rule or by the user, not
  already a safe sender.
- R-2: the Safe Senders screen shows "Suggested safe senders" above the list; each row has Accept and Reject (hides
  it; the reject is stored so it does not come back). Accept offers the three safe-sender choices the add-rule pop-up
  already has (Exact Email, Exact Domain, Entire Domain) with the app's recommended one highlighted, and adds the one
  the user taps through the existing quick action (Harold, Q7-echo = 2, 2026-11-01: *"When adding a rule it highlights
  Exact email, Exact domain or Entire domain - based on the app recommendation"*). The card states the rule that picks
  the recommendation and its DEV count per choice.
- R-3: nothing is added without a tap. Device contacts are not used (new permission, out of scope).
- R-4 (Q7, Harold 2026-11-01: *"should be based on my email address not the users and can be done similar to
  F308"*): the Sent-folder part is NOT an in-app read of users' mail. A developer tool reads Harold's own DEV account
  Sent folder read-only (the Task 7 probe method) and finds reply pairs: recipients Harold wrote to who also send him
  mail. The result is a report and candidate safe-sender patterns for Harold to review, like F308; nothing reads a
  user's Sent folder, so no privacy-policy change is needed.

**Affected components / files**:
- `mobile-app/lib/ui/screens/safe_senders_management_screen.dart` -- the section.
- a new shared service in `lib/core/services/` that reads the No Rule rows (scan results, not the DEV-only content
  history, so it works in prod builds).
- `settings_store.dart` or a small table for rejected candidates (the card checks which existing store fits first).

**Existing abstraction checked**: the safe-sender quick action (`RuleQuickActionService.safeSenderPatternFor`); the
No Rule row store used by Review No Rule Items.

**Signal fires on**: Fires when a sender has N or more No Rule emails, all GREEN, never deleted, not a safe sender; on
DEV data (read-only copy, 814 No Rule rows from 559 senders) it fires on 6 senders at N = 3 (14 at N = 2, 2 at N = 5); N = 3 is the shipped value. Recommended choice at N = 3: Entire Domain 6, Exact Email 0, Exact Domain 0. Inputs that mean "could not check": GREY (no auth headers),
temperror, permerror; for these the sender is not a candidate.

**User-reachable control**: Safe Senders screen, "Suggested safe senders", Accept / Reject per row.

**Observable behavior -- before / after**: BEFORE: the Safe Senders screen lists only saved safe senders. AFTER: it
also lists suggested senders at the top, each with Accept and Reject.

**Dependencies / blockers**: Q7 (v1 only). F266, F267 done.

**Acceptance criteria**:
- AC-1: a sender meeting R-1 is listed; a sender with any non-GREEN email, any delete, or already safe is not.
- AC-2: Accept shows Exact Email, Exact Domain and Entire Domain with the recommended one highlighted; the tapped one
  is added and the row is removed; Reject hides the row across a restart.
- AC-3: the DEV count of candidates is recorded in the card before release.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT for the candidate service.
- T-2 (AC-2) -- TEST-WIDGET `test/ui/screens/safe_senders_management_screen_test.dart`.

**Definition of Done**: default DoD PLUS mutation-verified T-1.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart service and screen on all three; data from the shared scan
store. No platform branch.

**Model**: Sonnet -- a new service plus UI plus a stored reject list.

**Step-types**: SVC-ADD, UI-ADD, DATA, TEST-UNIT, TEST-WIDGET. **Est-Effort**: 165-270m (Q7 and Q7-echo).

**Result (Phase 4)**: built 2026-11-04 (Sonnet 5.5 sub-agent; not committed).
- User-visible change: Settings > Manage Safe Senders (all three platforms) shows a card titled "Suggested safe senders (N)" above the list,
  with the line "Seen at least 3 times in No Rule mail, every email passed authentication, none deleted. Nothing is added until you tap."
  Each row shows the address, "<n> No Rule emails", and the buttons "Accept" and "Reject". Accept opens "Add as safe sender" with three
  buttons: "Exact Email: <address>", "Exact Domain: @<domain>", "Entire Domain: @*.<root>"; the recommended one is filled and ends with
  "(recommended)". The tap runs the existing `RuleQuickActionService.addSafeSender` (snackbar text is that service's, for example
  "Added entire domain "*.<root>" to Safe Senders"). Reject shows "Suggestion hidden for <address>" and the address is stored. A failed
  check shows "Suggested safe senders could not be checked: <error>" in red in the same place; with nothing to suggest, the card is absent.
- Candidate rule (R-1): at least 3 stored No Rule emails from the sender, EVERY one with stored auth class green (grey, yellow, red, null
  all remove the sender: "could not check" is not a pass), no `email_actions` delete from it, no `availability_status = 'deleted'` row, no
  saved safe sender covers it, not rejected. Green is the stored class, a proxy for DMARC pass (the F310 caveat).
- Recommendation rule (Q7-echo): the F306 pop-up rule. A shared email provider gets Exact Email; any other sender gets Entire Domain on the
  root domain; Exact Domain is offered, never recommended. Same builders as the tap saves (`safeSenderPatternFor`).
- DEV count (AC-3), read-only copy, Python mirror of the Dart rules (provider list approximated): 6 candidates at N = 3 (49 senders with 3+
  emails, 43 all green, 20 with no delete, 6 not already safe); 14 at N = 2; 2 at N = 5. Entire Domain 6, Exact Email 0, Exact Domain 0.
- Store (no schema change, no decision-class item): rejects are a JSON list in `app_settings` key `rejected_safe_sender_suggestions`
  (`SettingsStore.rejectSafeSenderSuggestion`; not written to the debug log, it holds addresses). A new table was not needed.
- Existing abstraction checked: `RuleQuickActionService.safeSenderPatternFor` (reused for every pattern); `SettingsStore` app_settings (reused,
  its private setter bypassed on purpose so addresses stay out of the debug log); `UnmatchedEmailStore` (no cross-account read of
  from/auth/availability exists, so one direct read-only query); `RuleSuggestion` (F306, block-only, scan-time: its recommendation rule is
  mirrored, the file is untouched because Task 3 owns it).
- R-4 done: `tool/rule_miner` reply-pair mode (`reply_pair_core.dart`, `rule_miner.ps1 -SentJsonl`), probe read the DEV Sent folder read-only
  (170 messages, recipients only). Result: 35 recipients, 5 reply pairs, all 5 already safe senders, 0 new candidates. Report (counts only):
  `docs/research/F270_REPLY_PAIRS.md`.
- Tests: T-1 7 pass, T-2 5 pass (includes a 344 px wide view), reply-pair 5 pass; 24 mutants KILLED (16 + 8).
- ADR-0042/0049/0050: service and section are shared Dart, identical on Windows, Android and iPhone; the reply-pair tool is a Windows DEV
  developer tool with no Android path (same as F308/F310).

## Task 6 -- F305 R-2: widen the No Rule signals (Priority 33)

**Value**: This finds which extra signals would mark No Rule spam, by count, before any change.

**Requirements**:
- R-1: on the DEV content history (read only), count candidate signals on No Rule rows and on Harold's 69+ decisions:
  bulk mail without `List-Id` where stored, Reply-To domain differing from From domain, missing List-Unsubscribe,
  and the Sprint 82 Task 6 header counts.
- R-2: present the result as ONE numbered decision for Harold (which signals to add, with counts), asked as late as
  possible; no signal is changed before his answer.
- R-3: if approved, the change is a basis or chip in shared Dart, with the "Signal fires on" line.

**Affected components / files**: read-only query scripts (scratchpad); results in this plan; code only after the
decision.

**Signal fires on**: each candidate is counted on DEV (N of M No Rule rows and agreement with the decisions).
"Could not check": a row without the stored field is counted apart and never as a hit.

**Dependencies / blockers**: none to count; Harold's decision to change.

**Acceptance criteria**:
- AC-1: a count table (as a bullet list) per candidate signal is recorded in this plan.
- AC-2: the decision question is asked with the counts.

**Tests to write**: none for the count; any approved change carries its own tests.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: analysis only (DEV, Windows); any approved signal is shared Dart.

**Model**: Sonnet -- query design and interpretation on real data.

**Step-types**: DATA-ANALYSIS. **Est-Effort**: 60-90m.

**Result (Phase 4)** (2026-11-02):

**Method**: a COPY of the DEV `content_history.db` (copied 2026-11-02 01:18:38) and of `spam_filter.db` with its `-wal`
and `-shm` (copied 01:19:41) was queried read-only (`mode=ro`) by `s83_task6/f305_r2.py` in the session scratchpad,
run with `python -I`. The real files were not written. Counts only: no address, subject or header text. The Q4 rule
from Sprint 82 is the pass test: fires on at least 10 percent of No Rule rows AND agrees with at least 80 percent of
the decisions it fires on (at least 5 decisions). A row without the stored field is "could not check": counted apart
and never a hit. Population now: 1,827 rows; **302 No Rule** (Sprint 82 counted 254 of 1,551); **86 decisions** by
Harold (safe 56: exact 48, exact domain 8; block 30: entire domain 27, email 3). Sprint 82 had 69 (42 safe, 27 block).
Decision rows come from all outcomes, because a decided row's outcome changes once its rule exists (39 of the 86 still
read No Rule). "Agrees" means a block signal on a block decision, or a safe signal on a safe decision.

**Fields stored per email** (`content_history`): `from_address`, `reply_to`, `return_path_domain`, `auth_class`,
`list_unsubscribe` (0 or 1), `user_decision`. **Not stored**: `List-Id`, `Precedence`, the Authentication-Results
header count and authserv-id. The main database holds one proxy: `unmatched_emails.heuristic_signals` carries the
`bulk_no_unsubscribe` chip result for rows written since v16 (first one 2026-10-23).

- **Bulk mail without List-Id**: CANNOT be counted. `List-Id` and `Precedence` are not stored (Sprint 82 planned to
  read them in the header probe; its recorded results hold only the F312 Authentication-Results counts, so no
  List-Id or Precedence count exists). What would settle it: either store two columns (`list_id_present`,
  `precedence_bulk`) in the content history and rescan, or rerun a Sprint 82 style read-only header probe that counts
  them. The closest stored proxy is the existing `bulk_no_unsubscribe` chip (S1 below).
- **S1 bulk mail with no List-Unsubscribe (existing chip proxy)**: fires on 28 of 302 No Rule rows (9%); could not
  check 147 (no stored row, or only a pre-v16 row). Decisions: block 3 of 30 (23 could not check), safe 0 of 56 (46
  could not check). Agreement 3 of 3 (100%), too few decisions. Fails (rate 9%, 3 decisions).
- **S2 Reply-To domain differs from From domain (existing chip)**: 27 of 302 (9%); could not check 3. Decisions:
  block 7 of 30, safe 2 of 56. Agreement 7 of 9 (78%). Fails by a near miss on both tests (Sprint 82: 26, 7 of 9).
- **S3 missing List-Unsubscribe**: 131 of 302 (43%); could not check 0. Decisions: block 17 of 30, safe 44 of 56.
  Agreement 17 of 61 (28%). Fails. It fires mostly on mail Harold marked safe, so it is a weak spam signal here.
  (Its opposite, List-Unsubscribe present, is 171 of 302 (57%); block 13, safe 12; 13 of 25 (52%); fails.)
- **S4 Return-Path domain differs from From domain**: 19 of 302 (6%); could not check 13 (no stored Return-Path).
  Decisions: block 0 of 30, safe 3 of 56. Agreement 0 of 3. Fails; it points to legitimate mail (sending services).
- **S5 Reply-To header present at all**: 162 of 302 (54%). Decisions: block 20, safe 22. Agreement 20 of 42 (48%). Fails.
- **S6 auth yellow (the Sprint 82 basis)**: 53 of 302 (18%); could not check 0. Decisions: block 6, safe 1. Agreement
  6 of 7 (86%). **PASSES**. Sprint 82: 35 of 254 (14%), 5 of 6.
- **S7 auth red**: 3 of 302 (1%); 0 decisions. Fails (rate). **S8 auth green** (suggests safe): 246 (81%); block 24,
  safe 55; 55 of 79 (70%); fails. **S9 free-mail sender** (suggests safe): 7 (2%); 10 of 12 (83%); fails (rate).
- **Combinations**: S3 and S2 together: 26 (9%), 7 of 8 (88%), fails (rate). S3 and S4: 5 (2%), 0 of 1, fails. S4 and
  S2: 0 hits. S3 and S6 (missing unsubscribe AND auth yellow): 39 (13%), 5 of 6 (83%), PASSES, but it is a subset of
  S6 (39 of S6's 53), so it adds no new rows; it only narrows S6.
- **History signals (DEV only, ADR-0047, time split as in Sprint 82)**: domain deleted before: 20 (7%), 2 of 8 (25%),
  fails. Domain made safe before: 27 (9%), 22 of 22 (100%), fails by rate only. Sender deleted before: 10 (3%), 2 of 3.
  Sender made safe before: 18 (6%), 15 of 15 (100%), fails by rate only. A shipped build has no content history, so
  none of these could ship.
- **Header counts from Sprint 82 (not recountable; the header count is not stored)**: Authentication-Results headers
  per email: 1 on 190, 0 on 6, 2 or more on 0; a lower header differs: 0; foreign authserv-id on the top header: 1.
  Matched 196 of 1,560. No new count was possible without an IMAP probe, which this task does not run.
- **Added coverage over S6 alone** (No Rule rows that S6 does not already reach): S2 adds 23 (union 76 of 302, 25%;
  on decisions, 12 block and 3 safe, so 12 of 15 (80%), which meets the Q4 rule); S1 adds 11 (union 64, 21%). S6 alone
  gives 53 (18%).

**Reading**: only auth yellow passes alone. Reply-To differs is the one near miss, and it passes the Q4 rule when it is
added to yellow (union 76 of 302; 12 of 15 decisions), but on 15 decisions one more wrong decision drops it below 80
percent. Missing List-Unsubscribe and Return-Path differs do not predict a delete in Harold's decisions. Bulk without
List-Id cannot be judged from stored data.

**Decision for Harold (R-2 / AC-2)**: which signals should F306 suggestions use for Block, beyond the current auth
yellow? Nothing changes before your answer.
1. Add none. Keep auth yellow only (53 of 302 No Rule rows, 18%; 6 of 7 decisions agree).
2. Add Reply-To differs (S2) as a second Block basis. The suggestion then reaches 76 of 302 rows (25%) instead of 53
   (18%); 12 of the 15 decisions it touches are blocks (80%). S2 alone is 7 of 9 (78%), a near miss, and 23 more rows
   are reached. Small sample: one wrong decision moves it below 80 percent.
3. Add the existing bulk chip (S1) as a Block basis. It adds 11 rows (union 64, 21%) but has only 3 decisions behind it
   (all blocks) and 147 rows could not be checked, so the evidence is thin.
4. Add the safe-direction history signals (domain or sender made safe before): 22 of 22 and 15 of 15 decisions agree,
   but they reach only 27 (9%) and 18 (6%) rows and exist only in DEV builds, so a shipped app could not use them. Not
   recommended for shipping.
5. Backlog: store `List-Id` and `Precedence` in the content history (two columns, schema change, then rescan) or run
   a read-only header probe, then count bulk-without-List-Id before choosing. No signal added this sprint.

## Task 7 -- F308: mine the AOL Trash2 history for delete-rule patterns (Priority 35)

**Value**: This finds subject, body and sender patterns that predict a delete rule, as candidates for suggestions.

**Requirements** (from the backlog card, Harold 2026-10-25):
- R-1: a read-only read of the DEV AOL Trash2 folder into the content history (ADR-0047), method by Q5. Yahoo is not
  read.
- R-2: extend `tool/rule_miner` (F268) with a mode that learns what delete-rule matches have in common (subject
  regex, body regex, body-URL domains, sender local-part shapes, header values, and AND-combinations), then scores
  each candidate with `tool/rule_eval` (F267) against No Rule and safe-sender mail. A candidate is reported only when
  it almost never hits a safe sender (the threshold stated in the report).
- R-3: report by kind: single-part and combinations (`type: "AND"` rules need no grammar change,
  `docs/RULE_FORMAT.md` lines 75-89).
- R-4: output is a report and candidate YAML for Harold; nothing is imported or applied.
- R-5: one record per email (dedup across accounts by Message-ID; by From + Date + Subject when there is none).
- R-6: hand-deleted items are their own group and weigh neither for nor against a candidate.

**Affected components / files**: `mobile-app/tool/rule_miner/`, `mobile-app/tool/rule_eval/` (developer tools);
`docs/research/F308_TRASH2_MINING.md` (report).

**Existing abstraction checked**: `rule_miner_core.dart`, `rule_eval_core.dart`; `ContentHistoryStore` keys
(SHA-256 of account + Message-ID).

**Dependencies / blockers**: Q5.

**Acceptance criteria**:
- AC-1: the report lists candidates by kind with hit counts on delete, No Rule and safe-sender mail.
- AC-2: no candidate in the report matches more than the stated threshold of safe-sender mail.
- AC-3: dedup and hand-delete rules are covered by tool tests.

**Tests to write**:
- T-1 (AC-2, AC-3) -- TEST-UNIT `test/tool/rule_miner_test.dart`: the new mode on fixture rows (dedup, hand-delete
  group, threshold).

**Definition of Done**: default DoD PLUS the report committed; no change to the app's rules.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: developer tool on Windows DEV; its output feeds shared Dart suggestions
on all three. Declared: tooling, not app code.

**Model**: Sonnet -- pattern mining design with a self-grading risk (F313 R-2 time split noted for later).

**Step-types**: TOOL-ADD, DATA-ANALYSIS, TEST-UNIT. **Est-Effort**: 180-300m.

_**Risk & rollback**_: the Trash2 read must not change the mailbox; EXAMINE and BODY.PEEK (or the app's read-only
scan mode, verified before the run) prevent it.

**Result (Phase 4)**: Q5 = 1 run. A scratch probe read the DEV AOL `Trash2` folder with IMAP EXAMINE (read-only asserted
before the first fetch) and `BODY.PEEK` only; the credential came from the DEV secure store in memory and was never
written, printed or put on a command line. 10,000 messages read (905 duplicates dropped by Message-ID or From + Date +
Subject). New `tool/rule_miner` trash2 mode (`trash_miner_core.dart`, `rule_miner.ps1 -Trash2Jsonl`): 3,809 rule-deleted
(the only pool), 4,593 hand-deleted (neutral), 350 No Rule, 1,459 safe-sender. Threshold: at least 5 rule-deleted
matches, at most 2 safe-sender hits AND at most 0.5 percent of checkable safe-sender mail. Reported: **178 single-part
candidates and 3 AND pairs**, 29 of them hit No Rule mail; strongest are the sender shapes `news_` plus digits (262
rule-deleted, 69 No Rule, 0 safe-sender) and `otp-` plus digits (1,453, 3, 0), both F267 PASS. Report:
`docs/research/F308_TRASH2_MINING.md`; candidate YAML stays in the scratchpad (private phrases), nothing imported. AC-1 and
AC-2 met; AC-3 by 24 new tests in `test/unit/tool/rule_miner_trash2_test.dart` (a new file: the existing
`rule_miner_test.dart` is untouched), 19 mutants KILLED (two first survived and got tests). Caveat for Harold: the safe
list measures only senders already marked safe, so newsletter boilerplate and shared image hosts pass with zero hits
and remain risky.

## Task 8 -- F309: research a global "trusted sender" source (Priority 37)

**Value**: This answers whether a trusted-sender source can support safe-sender suggestions, and at what cost.

**Requirements**:
- R-1: from primary sources only, assess `.gov` (CISA eligibility), Tranco, BIMI with a Verified Mark Certificate,
  and any other source found: what it proves, size, update cadence, license for a shipped app, and whether the app
  can read it from received headers.
- R-2: state, for each, how it combines with `dmarc=pass` from the receiving provider; it is only ever a suggestion.
- R-3: name the decision class (bundled list: new data source; network fetch: Class 1 and a privacy-policy change).

**Affected components / files**: `docs/research/F309_TRUSTED_SENDER_SOURCES.md`.

**Acceptance criteria**:
- AC-1: every claim cites a primary source with its date; unverified claims are marked.
- AC-2: a recommendation and its decision class are stated for Harold.

**Tests to write**: none (research).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: research only; any result would be shared Dart.

**Model**: Sonnet -- primary-source research with license reading.

**Step-types**: RESEARCH. **Est-Effort**: 60-90m.

**Result (Phase 4)**: Report at `docs/research/F309_TRUSTED_SENDER_SOURCES.md`. No source proves a sender is safe; each is
a hint on top of `dmarc=pass`. Recommendation: bundle a CC0 `.gov` snapshot as a hint chip in Task 5 (Tranco has no
stated license; BIMI headers are unproven until a DEV probe). Decision class: new data source (a run-time fetch would be
Class 1 plus a privacy-policy change). Harold answers the numbered question in the report.

## Task 9 -- F310: mine safe-sender mail for safe-sender patterns (Priority 38)

**Value**: This finds what safe-sender mail has in common, as candidates for safe-sender suggestions.

**Requirements** (from the backlog card):
- R-1: learn what safe-sender mail has in common that No Rule spam does not (DMARC pass, aligned DKIM, long sender
  history, reply threads, transactional subjects, few tracking links).
- R-2: score each candidate with `tool/rule_eval` against delete-rule mail; report only those that almost never match
  spam.
- R-3: a safe-sender suggestion always requires DMARC pass; content alone never suggests a safe sender.
- R-4: output is a report only.

**Affected components / files**: `mobile-app/tool/rule_miner/` (the Task 7 mode, safe side);
`docs/research/F310_SAFE_SENDER_MINING.md`.

**Dependencies / blockers**: Task 7 (shares the mode).

**Acceptance criteria**:
- AC-1: the report lists candidates with hit counts on safe-sender and delete mail.
- AC-2: no candidate without a DMARC-pass condition is reported as a safe-sender suggestion.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT `test/tool/rule_miner_test.dart`: the DMARC requirement in the safe mode.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: developer tool (Windows DEV); output feeds shared Dart (F270).

**Model**: Sonnet -- the mirror of Task 7.

**Step-types**: TOOL-ADD, DATA-ANALYSIS, TEST-UNIT. **Est-Effort**: 120-240m.

**Result (Phase 4)**: built 2026-11-04 (Sonnet 5.5 sub-agent; not committed). New safe mode in `tool/rule_miner`
(`safe_miner_core.dart`, `rule_miner.ps1 -Safe`) reusing the Task 7 corpus builder, dedup, thresholds and domain guard.
Every candidate carries the auth gate; a candidate without it never passes (AC-2). **The stored data has only the auth
class (green, yellow, red, grey), not a DMARC verdict**, so the gate is `green` (a proxy); delete-rule mail with an
unknown class (Trash2 only) counts as a hit. Threshold: at least 5 gate-proven safe-sender emails, at most 2 delete-rule
hits AND at most 0.5 percent of 4,127 delete-rule emails (987 with a known class). Result: 46 candidates scored, 31
reported (30 sender domains, 22 already matched by a current safe-sender pattern, 1 new domain that covers 5 No Rule
emails; plus 1 signal pair). No signal passes alone. Report: `docs/research/F310_SAFE_SENDER_MINING.md`. Tests: new
`test/unit/tool/rule_miner_safe_test.dart` (the card's `test/tool/rule_miner_test.dart` path does not exist), 25 pass; 24
mutants all KILLED; Task 7's 24 and F268's 10 tests still pass. Shared edits: `HistorySample.authClass` and
`CorpusEntry` auth/time/outcome fields, `domainGuard` made public.

## Task 10 -- F321 pilot: Python for deterministic tooling (Priority 35)

**Value**: This starts moving the tooling to one language that runs on Windows, Linux, Unix, WSL and macOS.

**Requirements**:
- R-1: a small shared Python layer under `.claude/hooks/lib/` (or `scripts/pylib/`, named in the ADR): payload
  reading, repo root, path normalizing, git calls, allow/block exit codes, UTF-8 stdin/stdout. Every hook fails open
  on a malformed payload. Prior art read first: `hsbc-qfraud-phase2/.claude/hooks/hooklib.py`,
  `EvidenceBasedDB/.claude/hooks/*.py` (read only).
- R-2: pilot set (Q9): convert it, keep each hook's interface (exit codes, the message a gate matches on), register
  it in `.claude/settings.json`, and keep the PowerShell test cases running against it.
- R-3: run the pilot on Windows and on the CI Linux runner; record the defects found.
- R-4: classify every hook, script and skill as deterministic (convert later) or GenAI (stays `.md`); record the list
  in the ADR.
- R-5: ADR-0051 "Python for deterministic tooling" records the layer, the registration form and the conversion
  order.
- R-6 (Q9, Harold 2026-11-01: *"ensure there are backlog items for everything not included in F321"*): backlog cards
  in the master plan for every hook, `scripts/` script, `mobile-app/scripts/` script and deterministic skill the pilot
  does not convert, grouped in batches a sprint can take, each with its effort in minutes.

**Affected components / files**: `.claude/hooks/` (pilot hooks), `.claude/settings.json` (pilot registrations),
`.claude/hooks/test-cases/` (unchanged cases, new runner support if needed), `docs/adr/0051-*.md`.

**Callers of any guard being changed**: each pilot hook is a gate; its callers are the Claude Code tool events it is
registered on; the card lists each with its matcher.

**Acceptance criteria**:
- AC-1: `.claude\hooks\run-test-cases.ps1` passes with the pilot hooks in Python (the same case count as before).
- AC-2: each pilot hook BLOCKs on its block cases and ALLOWs on its allow cases (`scripts/test-hook.ps1`).
- AC-3: the pilot's Python tests pass on the CI Linux runner.

**Tests to write**:
- T-1 (AC-1, AC-2) -- the existing hook test cases, run against the Python hooks; mutation-verified per hook.
- T-2 (AC-3) -- a pytest file for the shared layer, run in CI.

**Definition of Done**: default DoD PLUS ADR-0051 accepted by Harold (asked as late as possible) and the hook suite
green.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development process, not the app. The goal is OS independence of the
tooling; Windows-only build steps (MSIX, Task Scheduler, WinWright) keep a Windows path (out of scope).

**Model**: Sonnet -- a cross-cutting tooling change with a test harness; not Haiku-shaped.

**Step-types**: HOOK, TOOL-ADD, TEST-UNIT, DOCS. **Est-Effort**: 120-240m.

_**Risk & rollback**_: a broken hook can block every tool call. Each pilot hook is registered only after its cases
pass; rollback is the previous `settings.json` registration (one commit).

**Result (Phase 4)**: Done 2026-11-02. ADR-0051 (Proposed): `docs/adr/0051-python-for-deterministic-tooling.md`.
- Files: layer `.claude/hooks/lib/{common,hooklib,mutation_lock}.py`; hooks `.claude/hooks/block-blind-staging.py`,
  `block-heredoc-python-backslash.py`, `block-commit-during-mutation.py` (the three `.ps1` originals are deleted);
  `.claude/hooks/mutation-lock.ps1` is now a thin shim (same four functions, same lock files);
  `scripts/agent-work-status.py` with `scripts/agent-work-status.ps1` kept as the entry point (output diffed against
  the old script on a fixture with every task state and one lock: 0 differing lines); tests
  `.claude/hooks/tests/test_pylib.py` (stdlib `unittest`, 33 tests) and `test-mutation-lock-shim.ps1`; 14 new cases in
  `.claude/hooks/test-cases/commit-lock/` (that hook had none); `run-test-cases.ps1` runs `.py` routes, builds the lock
  fixtures per case and takes `-OnlyRoute`; `scripts/test-hook.ps1` runs `.py` hooks; CI step "Python hook layer
  tests" in the `analyze-and-test` job (`python3`, `working-directory: .`); CLAUDE.md and TESTING_STRATEGY.md hook file
  names updated.
- Case counts (`run-test-cases.ps1`): before 162 passed, 0 failed; after 176 passed, 0 failed (162 unchanged cases, now
  against the Python hooks for staging-guard 24 and heredoc-guard 30, plus 14 new commit-lock cases). The final run
  was one `run-test-cases.ps1 -OnlyRoute` process per route, all at once (55 top level, 25 closeout, 8 sprint-cards,
  8 stash-guard, 12 velocity-warn, 14 commit-lock, 24 staging-guard, 30 heredoc-guard), because one serial run takes
  over an hour on this loaded machine. `test-hook.ps1` ALLOW and BLOCK spot checks on the Python hooks: PASS.
- Mutation (`scripts/mutation-test.ps1`, command checks, specs written with the Write tool): 29 mutants, all KILLED
  (staging 7, heredoc 6, commit gate 6, library 5, agent-work-status 3, PowerShell shim 2). First run: C2 (override token read from the quoted message) and P2 (shim ignores `-File`) SURVIVED
  and L5 (BOM) had a bad anchor. Fixes: a new case `violation-7-override-token-inside-quoted-message` and a bystander
  lock in the shim check; second run killed all three. No INVALID mutant.
- Registration form: `python "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.py"` (forward slashes, one command). The exact
  string was run through PowerShell with `CLAUDE_PROJECT_DIR` set: exit 2 and the message for `git add -A`. The live
  harness reads the main checkout's `settings.json`, so the first live run happens after merge.
- Defects found (Windows unless noted): (1) Windows PowerShell 5.1 `ConvertFrom-Json` returns a JSON array as ONE
  object, so `Get-MutationLockInfo` reported one lock for two (found by the shim check; fixed by piping through
  `ForEach-Object`); (2) the old commit gate wrote its BLOCK message with `Write-Host` (stdout) while Claude Code
  feeds Claude the stderr of an exit-2 hook, so the reason may never have reached Claude (now stderr; unverified how
  the harness displayed it before); (3) text-mode stdin and stdout on Windows use cp1252: a non-ASCII command would
  fail to decode (fail open on a real violation) or fail to encode (exit 1, block lost); the layer reads bytes and
  uses `errors=replace`, test `..._under_cp1252`; (4) Python 3.11 rejects an inline `(?i)` that is not at pattern
  start, and PowerShell `-match` is case-insensitive while `-cmatch` is not (flags carried per call); (5) the first
  runner fixtures for commit-lock were built once at start, and the 30-minute suite made the lock stale before its
  case ran (now built per case); (6) a bare `python` start costs ~2.9 s on this heavily loaded machine (hook 3.2 s,
  `powershell.exe -Command exit 0` 3.6 s), so lazy imports keep a hook near interpreter start; the numbers are under
  load, not a benchmark. Linux: the CI step is in place but has not run (no push, no PR run in this task).
- Backlog: F326 to F340 in `docs/ALL_SPRINTS_MASTER_PLAN.md` (H1 to H4 hooks and test tooling, S1 to S7 scripts, Windows
  bound decisions, one-off audit, skills, memory scripts audit), sizes in minutes. F321 now carries a pilot note.
- Judgment calls: layer under `.claude/hooks/lib/` (named in the ADR); `.py` file names keep hyphens; the commit gate
  block text moved to stderr and gained `timeout: 15` and honors the payload `cwd` when `CLAUDE_PROJECT_DIR` is unset;
  `agent-work-status` resolves the lock folder from the repo root first (environment still wins); old `.ps1` hooks
  deleted rather than kept beside the Python ones; no `python3 || python` fallback (stdin is consumed by the first
  run); ADR acceptance left to Harold.

## Task 11 -- F237: quiet the Kotlin daemon traces in the Android build (Priority 38)

**Value**: This prevents the non-fatal traces from being read as a build failure again.

**Requirements**:
- R-1: measure two release AAB builds (current settings, then the Q8 option), serialized with any other build, and
  record the wall-clock of each.
- R-2: apply the Q8 option if its cost is acceptable to Harold (asked with the numbers, as late as possible);
  otherwise record the numbers and close with a note in TROUBLESHOOTING.md.

**Affected components / files**: `mobile-app/android/gradle.properties` (one line) or the `PUB_CACHE` location;
`docs/TROUBLESHOOTING.md`.

**Acceptance criteria**:
- AC-1: the second build's log has no "Daemon compilation failed" trace, or the reason it still does is recorded.
- AC-2: both build times are recorded.

**Tests to write**: none (build configuration; the build is the test).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Android build only (declared: Kotlin compilation exists only in the
Android build).

**Model**: Haiku -- one property and two timed builds.

**Step-types**: BUILD-CONFIG. **Est-Effort**: 20-40m (plus two build runs).

_**Risk & rollback**_: a slower build; rollback is removing the line.

**Result (Phase 4)**: two release AAB builds, run alone one after the other (2026-11-04). Build 1, current settings:
570 s, exit 0, 30 "Daemon compilation failed" / "Could not close incremental caches" lines. Build 2 with
`kotlin.incremental=false`: 405 s, exit 0, 0 such lines (AC-1, AC-2). The line is committed in
`mobile-app/android/gradle.properties` with a comment; `docs/TROUBLESHOOTING.md` records the numbers. Build 2 was not
slower, so there is no cost to weigh; R-2 still asks Harold at Manual Validation whether to keep it. Executed by the
main session (Opus), not Haiku: the two builds must be serialized with the merges in this session, so a delegated
agent would wait on the same queue.

## Task 12 -- F325 (copy of F152): first-run evaluation, Sprint 83 run

**Value**: This finds what a new user stumbles on in the first minutes, as backlog items.

**Requirements** (method from the F152 template):
- R-1: static pass first (an Explore agent reads the first-run path) to form a baseline.
- R-2: live pass on Windows with a release-equivalent build and a genuinely empty data folder (the DEV data folder is
  backed up first and restored byte for byte after; verified). Harold drives; Claude records against the 7 sections
  (Installation and Launch, First-Run Orientation, Completing the Primary Task, Feedback and Confirmation, Emotional
  Experience, Environment Compatibility, Quick User Feedback Capture).
- R-3: live pass on Android on a clean install (an emulator, so the Fold's closed-test data is not touched), by Q10.
- R-4: iPhone: not possible this sprint (no TestFlight build); recorded as a gap, run when F67b's device check runs.
- R-5: findings become backlog cards sized like F151; nothing is fixed in this task.

**Affected components / files**: `docs/research/F325_FIRST_RUN_EVALUATION_S83.md`; new backlog cards in the master
plan.

**Dependencies / blockers**: Harold's time; Q10.

**Acceptance criteria**:
- AC-1: each of the 7 sections has findings or "no issues" per platform run.
- AC-2: the data folder backup and restore are verified (hash before and after).
- AC-3: every finding is a backlog card with effort in minutes.

**Tests to write**: none (evaluation).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Windows and Android runs; iOS declared as not runnable this sprint
(Apple), not a design exception.

**Model**: main session -- interactive with Harold.

**Step-types**: UX-EVAL. **Est-Effort**: 120-180m plus Harold's time.

---

# Phase 3.7 answers (Harold, 2026-11-01)

Verbatim: *"Q1. 1 q2. 1 q3. 3 (this is common practice for phone and windows apps, so would seem reasonable for adding
and removing email addresses from our app) do a deep dive to ensure only what is needed on a re-add is kept,
everything that needs to be refreshed with a re-add is refreshed... q4. the first link that doesn't exactly match the
email address domain (unless that is in the safe sender exact/entire domains, then skip the first and pick another.
If there are none, then don't provide a recommended body rule) q5. 1 q7 should be based on my email address not the
users and can be done similar to F308 q6. 1 q8 1 q9. 1 (ensure there are backlog items for everything not included in
F321) q10. 1"*

- **Q1 = 1**: Android two channels with the app's Settings row opening Android's settings; Windows and iPhone the
  in-app choice; a declared Android exception (ADR-0049). Android 7.x (no channels) uses the in-app choice.
- **Q2 = 1**: default "Only when there are No Rule items".
- **Q3 = 3** with a deep dive: Task 4 R-2 (below).
- **Q4**: Task 3 R-1 value rule (below).
- **Q5 = 1**: read-only probe with the DEV AOL credential read in memory (Task 7).
- **Q6 = 1**: "Block sender pattern" From-header regex for `news_` plus 4-6 digits.
- **Q7**: Task 5 (below): the Sent-folder part is mined from Harold's own mail by a developer tool, like F308.
- **Q8 = 1**: `kotlin.incremental=false`, measured first.
- **Q9 = 1**: the pilot set as listed, plus backlog cards for everything F321 does not convert (Task 10 R-6).
- **Q10 = 1**: Android first-run run on the emulator.

**Re-estimates from the answers (3.2.2.2)**: Task 4 F324 45-90m -> 90-150m (the deep dive across every per-account
store). Task 5 F270 120-180m -> 150-240m (adds the Sent-folder mining on Harold's mail). Task 10 F321 120-240m ->
135-255m (the remaining-conversion backlog cards). **Total** about 1,215-2,080 minutes plus the 150-250 allowance.

# Decision questions (for Phase 3.7, answered above)

**Q1. F322 (Class 2): where the user sets "notify only when there are No Rule items".** You asked whether Android's
notification sub-settings should hold it. My plan was an in-app setting on all three platforms. Facts: Android lets
the user change or silence each notification CHANNEL in system settings, and the app can open that screen directly
(Google's page, read 2026-10-31); channels exist from Android 8.0, and this app supports Android 7.0+ (minSdk 24), so
7.x needs the in-app setting anyway. Windows and iPhone: I found no OS place for an app's own sub-settings (not yet
verified from Microsoft's and Apple's pages; the card verifies first).
1. Android: two channels, "Scans with No Rule items" and "Scans with nothing to review"; the user turns the second
   off in Android's settings; the app's Settings row opens that screen. Windows and iPhone: the in-app choice. A
   declared Android exception. Matches your direction (recommended).
2. Option 1, and ALSO the in-app choice on Android (two controls on Android for one outcome; more to explain).
3. The in-app choice on all three, same UI; Android keeps one channel (full parity, ignores Android's sub-settings).

**Q2. F322 default.** What a user gets before changing anything.
1. "Only when there are No Rule items" (quieter; what you said most users want) (recommended).
2. "Every completed scan" (today's behavior; no change for current testers).

**Q3. F324 (Class 2 for options 2 and 3): what removing an account does to its background setting.** Today removal
deletes all of the account's settings (`data_deletion_service.dart:99-103`), so a re-added account falls back to the
app-wide default (off on DEV), which is what happened to iCloud.
1. Keep the deletion (removal means "forget this account"); the Account Selection screen shows "Background scanning
   is off for this account" with "Turn on" (recommended).
2. Keep the background setting across removal (removal stops deleting `background_enabled`), plus the screen line.
3. Keep ALL account settings across removal for the same address, plus the screen line.

**Q4. F323 R-1: the Block Body button's value.**
1. The first link domain in the body, fetched when the pop-up opens (one tap) (recommended).
2. A pick list of the body's link domains (more control, one more step).

**Q5. F308 R-1: how to read the AOL Trash2 folder (DEV, read only).** The AOL app password is only in the DEV app's
Windows secure store.
1. A read-only probe like Sprint 82 Task 6 (IMAP EXAMINE, BODY.PEEK), with the DEV AOL credential read in memory from
   the secure store, never written or printed (recommended).
2. You run a DEV manual scan of the AOL account with only Trash2 selected; AOL's DEV manual mode is read-only
   (checked again before you run it).
3. Claude drives that DEV manual scan through WinWright (I notify you before and after).

**Q6. F323 R-3: what the `news_` suggestion is.**
1. A From-header regex rule matching `news_` plus 4-6 digits at any domain, offered as "Suggested" on a new "Block
   sender pattern" action in the pop-up (recommended).
2. Keep Block Entire Domain for these senders and only add the reason text "news_ sender pattern" (no new rule
   type; 76 domains would still need 76 rules).

**Q7. F270 scope.**
1. v1 only: stored No Rule history; v2 (Sent folder) waits for the privacy policy change (recommended).
2. v1 and v2 this sprint (adds the privacy policy and Data safety review).

**Q8. F237 option.**
1. `kotlin.incremental=false` in `gradle.properties`, measured first (recommended).
2. Move the pub cache to `D:` with `PUB_CACHE` (a machine change, every project).
3. Record the measurements only; change nothing.

**Q9. F321 pilot set.**
1. The shared layer plus three hooks: `block-blind-staging`, `block-heredoc-python-backslash`, `mutation-lock`
   (with `block-commit-during-mutation`), and one `scripts/` helper (`agent-work-status`) (recommended).
2. The shared layer plus one hook only (`block-blind-staging`) for the smallest first step.
3. Name a different set.

**Q10. F325 Android run.**
1. A clean install on the Android emulator (no phone data touched) (recommended).
2. A clean install on the S24+ (real device; its current data is backed up and restored).

**Q-S1. Models as assigned**: 1 approve.
**Q-S2. Version 0.24.0+21** (MINOR, F322 and F270 are `feat`): 1 approve.

**Answers 2026-11-01 (Harold)**: Q7-echo = 2 (Accept highlights the recommended Exact Email, Exact Domain or Entire
Domain; Task 5 R-2 and AC-2 updated); Q-S1 = 1; Q-S2 = 1.

**Approval 2026-11-01 10:18pm (Harold)**: Q-A = approved (*"All Sprint tasks and sub-tasks are approved. Do not
stop between tasks as they are all approved, please continue to complete all tasks and without addition approvals
until Manual Validation"*). MV-3a = yes (PASS). iCloud = 1 (*"yes"*: "Sign In Again" for iCloud added to Task 4
as R-4). Open, asked again at Manual Validation: MV-3c (wait for a YELLOW item, or accept the clipping check and
move "Suggested" to this sprint's Manual Validation) and the Record question (0.23.0 on the Fold from the Play
closed test).

---

# Phase 5 evidence

- **5.1.2 F-PRECHECK**: 2026-11-04, seven classes run by a read-only agent over `git diff origin/develop...HEAD` at
  fb4f6c1f (Dart, Kotlin, PowerShell, Python, YAML; no C++, Swift or shell). Classes 1 (mirror sites) and 2 (helper
  wiring) clean. 10 findings, 9 fixed in this commit, 1 asked at Manual Validation:
  - F1 MEDIUM (class 6) `_finishAccountAdded`: a failed `refreshForReAdd` was logged only, under "[OK] saved". Fixed:
    an orange SnackBar names the account and says to remove and add it again if scans look wrong.
  - F5 MEDIUM (class 4) Review No Rule Items `_loadBodyFor` split the platform id at the first dash (`gmail-imap-`
    read as `gmail`, `jean-luc@aol.com` as `jean`; the Sprint 47 class). Fixed: `BackgroundScanCore.resolvePlatformId`
    (stored id first). Grep of the other new `indexOf('-')` sites: line 337 is older display-only code; no others.
  - F6 MEDIUM (class 6) `hooklib.run` failed open with exit 0, whose stderr Claude Code never shows
    (https://code.claude.com/docs/en/hooks, read 2026-11-04). Fixed: exit 1 (`HOOK_ERROR`), a non-blocking error with
    a visible notice; no hook sets `onFailure`. Hook suites: test_pylib 33 OK, run-test-cases 176 of 176.
  - F8 MEDIUM (class 7) a saved scan's pop-up cannot re-detect a temperror, so it still suggests Block where AC-1,
    the CHANGELOG and both release notes promise it does not. NOT fixed: both fixes change a prior decision; asked
    at Manual Validation.
  - F10 LOW-MEDIUM (class 5) a suggested safe sender could be one a block rule matches; Accept then deleted that
    rule. Fixed: new `RuleConflictResolver.hasConflictingRule` (the check Accept runs, removes nothing) passed as
    `findCandidates(isBlocked:)`.
  - F2 LOW `isCovered` swallow: now `on FormatException` with a warning. F3 LOW a damaged reject list was overwritten
    (earlier rejections came back): reject now throws `StateError`, shown by the existing snackbar. F4 LOW the
    notification row showed the default as saved after a read failure: now says so. F7 LOW the enum took the class
    dartdoc: moved. F9 LOW `/startup-check` gains a hook-interpreter check.
  - Tests: new cases for F3, F4, F10 and `hasConflictingRule`. Not covered by a test: F1 (SnackBar after a failed
    refresh) and F5 (the call site; `resolvePlatformId` has its own tests). Full suite 2026-11-04 7:19am at
    6bc6ca72 plus these fixes: 3554 passed, 15 skipped, 0 failed; `flutter analyze` no issues.
- **5.1.5 WinWright sweep**: 2026-11-04 ~9:20, default sweep (`run-winwright-tests.ps1`, no arguments) on the 0.24.0
  DEV build of 3817aeb6: test_f124_rule_labels PASS (29 s), test_s75_new_controls PASS on retry (27 of 27, 23 s),
  test_f320_no_rule_review FAIL twice at step 2 ("No main window found" after step 1 passed). Rerun alone
  (`-TestName f320`, ~9:30): PASS 13 of 13, so F323's pop-up changes did not break its selectors. Cause of the
  sweep failure UNKNOWN (not "transient"): a process sampler saw windowless DEV processes at launch in both the
  failing and the passing run, so that alone does not explain it; settle by logging the PID WinWright attaches to on
  a failing step. Mouse steps skipped 0 (unlocked), DB drift none, tray check PASS, the 4 DEV background tasks paused
  and re-enabled. Live checks of the changed screens (WinWright, read-only, screenshots in the scratchpad):
  Settings > Background shows "Scan notifications" = "Only when there are No Rule items" (F322); the account list
  shows the 4 DEV accounts with no background-off line and no Sign In Again (none applies today; F324); the No Rule
  pop-up shows the `news_` "Block sender pattern, suggested rule" button and note (F323 R-3). FOUND: (1) Block Body
  read "Could not read message" on 3 of 3 AOL items; fixed a86a4fa6 (read `fetchContentText`, HTML fallback) and
  re-checked on the rebuilt app: "No outside link" on 2 of 2 (the content history holds 47 and 97 characters with no
  link for these); (2) the desktop pop-up is capped at 60% of the window (432 of 720 logical px) while its content is
  451 px (no suggestion) to 614 px (with the `news_` suggestion), so the bottom row and the suggestion are cut off
  (Harold, 2026-11-04, two screenshots); in a window Harold made taller (1280x1160 logical) everything fits, but
  Harold: *"image 18 was the default window size"* -- the requirement is that every row shows at the DEFAULT size.
  Android has the same cut-off: three Fold inner-screen screenshots of 0.23.0 (Harold, 2026-11-03 11:57-11:58,
  `validation-screenshots/sprint-83/Screenshot_20261103_115712`, `115744`, `115825`) show the authentication note
  under Block Subject cut off on 2 of 3 items (the two with an SPF failure); the third, with no note, fits. The
  unfolded Fold is wider than 600 logical px, so it takes the same desktop branch and 60% cap as Windows.
  Decision asked at Manual Validation. Manage Safe Senders checked live (2026-11-04, time not recorded): "Suggested safe senders (1)",
  karinreale@dandyblend.com, 7 No Rule emails, Accept and Reject shown (F321).
  sweep-head: 3817aeb6
- **5.1.9 MV rehearsal**: 2026-11-04, on the 0.24.0 DEV build of a86a4fa6 (PID 66460). The live part was done in the
  5.1.5 checks above (read-only, WinWright). The steps that change state were rehearsed by their tests only: before 10:15
  the DEV window had a No Rule pop-up open (Harold using it), so WinWright clicked nothing. Step tests, 12 files
  (`settings_scan_notifications_test`, `scan_complete_notifier_test` under unit/services, `f323_popup_body_fetcher_test`,
  `f323_email_detail_popup_test`, `f323_block_rules_test`, `f323_body_link_domain_test`,
  `safe_senders_management_screen_test`, `safe_sender_suggestion_service_test`, `f324_background_off_test`,
  `f324_repair_flow_test`, `f324_imap_sign_in_skip_test`, `f324_imap_sign_in_flag_test`): 102 of 102 passed, read
  10:15. Per step:
  - W-1 F322 row shows "Only when there are No Rule items": LIVE (5.1.5). Changing it and the value surviving a
    reopen: TEST only (T-2).
  - W-2 F322 effect (no toast for a No Rule 0 scan): TEST only (T-1). Precondition checked: the 4 DEV background
    tasks exist (3 Ready, yahoo Running, read before 10:15).
  - W-3 F323 Block Subject and Block Body in one row, Block Body subtitle, `news_` "Block sender pattern": LIVE
    (5.1.5, "No outside link" 2 of 2 after a86a4fa6). Tapping a found domain creates a rule: TEST only.
  - W-4 F324 background-off line and "Turn on": TEST only. No DEV account has background off, so the precondition
    is that Harold turns one off first; the step says so.
  - W-5 F321 suggestion card: LIVE (1 suggestion). Accept / Reject: TEST only (both change data Harold validates).
  - W-6 M-6 toast click during a running worker: NOT REHEARSED (needs a real toast from a running scan).
    Precondition written into the step: under the new default a toast posts only for a scan with No Rule above 0,
    so the step sets "Every completed scan" first and restores it after.
  - W-7 date/account wrap at a narrow width: TEST only (f216 date-row test, F323 344 px test).
  - A-1 F322 Android row and the native settings page: NOT REHEARSED (no Android 0.24.0 build yet; tests cover the
    row branch, not the page).
  - A-2 / W-8 F325 first-run: NOT REHEARSED by design (a live evaluation with Harold; the DEV data folder backup and
    hash are part of the step).

### Manual Validation results and answers (Harold, 2026-11-04)

**Standing facts (Harold)**
- 2026-11-04: *"if a phone image reads 0.??.?? then you can assume the play store update has happened - I have no
  other way at this time to install it."* A phone screenshot that shows the version is the evidence that the Play
  update installed. Do not ask again. (The Fold screenshots 115712, 115744 and 115825 show 0.23.0.)

**Step results**
- Image 20 (Select Account): rows opened red before the account was read. Fixed in ec5f94b8 ("Checking account..."
  while loading). Re-validation pending on the rebuilt app.
- W-1: Harold asked for "Only when one or more No Rule items". Done in 92692871. Re-validation pending.
- W-3: working as expected; image 24 showed Block Subject, Block Body and others cut off at the default window size.
  Fixed in 42d7e722 (Q1 = 1, the pop-up grows to fit, compact header). Re-validation pending.
- W-4, W-5: working as expected.
- W-6 (M-6): image 21 shows the toasts; image 22, app open: the snackbar "A screen is open, so the notification did
  not close it. Go back to Review No Rule Items when you are done."; image 23, app closed: the app opens on Review No
  Rule Items. PASS.
- A-1: Harold asked that Android use the same text as Windows ("Only when one or more No Rule items" and "Every
  Completed Scan"). Open question (it changes the Q1 = 1 Android channel exception).
- A-2 / W-8 F325 live run: Harold: *"Wait this to a future sprint"* (Class 3, approved by Harold). Card F341.

**Answers**
- Q1 = 1: pop-up fix as proposed (42d7e722).
- Q2: *"can you fix it to only suggest Block if a check finishes"*. Done in 92692871 (a saved scan without headers
  gets no Block suggestion).
- Q3 = 1: MV-3c waits for a YELLOW item.
- Q4: yes, see the standing fact.
- Q5 = 6: F309 trusted-sender hint to the backlog (F343).
- Q6 = 2: chip reads "Reply-to email mismatch", and the mismatch suggests Block. Done in 62546100.
- Q7 = 1: keep `kotlin.incremental=false`.
- Q8: Python 3.14 preferred; deterministic prompts rewritten; shared Python helpers for prompts; 3 hooks and
  agent-work-status accepted. ADR-0051 Accepted in 359b21ae; prompts card F344. Hook interpreter move asked
  separately.
- Q9: approved as written, except the `news_` item. Harold: *"no, it suggests block entire domain for the domain of
  each email that matches the pattern in the email address"*. Echo question open before coding.
- Q10 = 2: Fold background log errors to the backlog (F342).
- Recorded 17:57.

**Re-validation round 2 (Harold, 2026-11-04, on the 6:04pm build of 3d2f78a5)**
- 1 Select Account loading: OK.
- 2 W-1 text: OK, but the list opened upward over "Scan notifications". Harold: *"can you switch it to a drop-down (it
  will overlap "Test", but that is better than overlapping "Scan Notifications"*. Fixed: the list opens below.
- 3 pop-up at the default window size: looks good on Windows.
- 4 saved-scan Block suggestion: Harold knows of no YELLOW saved-scan item (test evidence only).
- 5 Reply-to chip: Harold knows of no matching item (test evidence only).
- Question A (Q9) = 2: keep "Block sender pattern", but Block Entire Domain is the Suggested item. Harold: *"while
  very common, it it is too short and possible for a potential safe sender to use to be the Suggestion"*. Done.
- Question B (A-1): keep the Android channels, name them like Windows. Open: the exact Windows names would
  mislead (the channels are two separate on/off groups); options asked.
- Question C: "2?". Open, asked again with a recommendation.
- Question D = 2: hooks stay on 3.12; the move is in F344.

**Re-validation round 3 (Harold, 2026-11-04, on the 9:56pm build of 90e924fb)**
- 1 notification list opens below: good.
- 2 `news_` sender: worked as expected. `news_9280@yaltrong.com` showed no "Suggested": the DEV row (id 8440) was
  saved 2026-11-02 20:35, before the suggestion code, and not seen since (suggestion columns null). Rows re-seen
  tonight (`news_60463@condauietrl.net`, `news_026174@eachieved.com`) store Block Entire Domain, reason
  sender_shape. Question E = 1: leave older rows; they get a suggestion when a scan sees them again.
- Questions B and C: Harold: *"There should be a sub-notification level for "Every Completed Scan" on/off and "One or
  more No Rule Items" -- there does not need to be 3 sub-notification levels"*. The two Android channels are renamed
  "Every Completed Scan" (No Rule 0) and "One or more No Rule Items" (No Rule above 0); ids unchanged; each channel's
  description says what it covers. Windows option 1 reads "Every Completed Scan".
- Harold (standing fact, 2026-11-04): production Android has one notification category, "Background Scans". The two
  channels arrive with the 0.24.0 release (the app deletes `background_scan_channel` when it creates them), so no user
  has seen the earlier names.

**Re-validation round 4 and close (Harold, 2026-11-04)**
- On the 10:55pm build of f07575af: the Scan notifications list reads "Every Completed Scan" / "Only when one or more
  No Rule items": as expected.
- Harold: *"Manual Validation complete"*. MV-3c (YELLOW item) stays open as its own carry (Q3 = 1); the F325 live run
  is F341.
- Phase 7 started 23:09: Copilot requested by hand (GraphQL lists `copilot-pull-request-reviewer`), code-reviewer and
  silent-failure-hunter started on 125 files.
