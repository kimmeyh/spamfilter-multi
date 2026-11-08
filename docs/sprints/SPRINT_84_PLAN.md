# Sprint 84 Plan

**Status**: APPROVED 2026-11-06 (Harold: *"q3 3"* plus the standard approval text, *"Sprint plan approved as
amended (with any comments I provided), proceed with execution. All Sprint tasks and sub-tasks are approved."*). Q1 = 1,
Q2 = 2, Q3 = 3. Cards: Task 0 #549, Task 1 #550, Task 2 #551, Task 3 #552, Task 4 #553, Task 5 #554, Task 6 #555,
Task 7 #556, Task 8 #557. Scope selected by Harold at Phase 8.4 pass 2 (2026-11-06).
**Branch**: `feature/20261105_Sprint_84` (cut from the Sprint 83 branch, Phase 6.6) | **PR**: draft, created at 3.3.1
(stays draft until 7.7.5)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads on 2026-11-06;
file:line evidence is in each card.

## Objective

Find and name the causes of the real background errors on the Fold (F342) and of the Doze-alarm DNS failures (F280).
Run the live first-run evaluation that Sprint 83 prepared (F341). Continue the Python tooling conversion with the
three hook batches that run on every turn (F326, F327, F328). Start iOS checks that need no Apple approval, on the iOS
Simulator (F345). Close the MV-3c carry-in.

**Scope (Harold, 2026-11-06, verbatim)**: *"Sprint 84 Scope should include the below items. Please complete sprint
planning (/docs/sprint_planning.md) for the below items and present for approval."* The items: carry-in MV-3c; F342;
F341; F280; F326, F327, F328. Plus *"1.1"*: question 1 answer 1, add **F345** (iOS Simulator smoke and screen check on
the `macos-26` runner), a card id assigned here.

**iOS (Harold, 2026-11-06)**: Apple has not approved enrollment `R6QG2A9SHS` (answer 2). F67a (#509), F304 (#510) and
F67b (#523) are NOT in this scope and stay open. If Apple approves during the sprint, adding them is a scope change for
Harold to approve then. F345 needs no Apple approval: a Simulator build is unsigned.

**Parity (Harold, 2026-11-06, verbatim)**: *"everything needs to take into account the Windows App, Android app and
the iPhone app with the ADR stating that everything should be functionally and UI the same unless it cannot be - and
where it cannot be it should be implemented as a platform exception for what is needed -- this applies to all backend
code, frontend code, data, architecture, development, security, testing, deployment."* Every card has a **Parity
(ADR-0042 / ADR-0049 / ADR-0050)** line naming the Windows, Android and iOS paths. It either claims parity and names
the OS behavior assumed identical, or declares the exception. iOS answers come from `PlatformCapabilities` (ADR-0049)
and ADR-0050. No new bare `Platform.isX` checks (the F294 policy test refuses them). The iPhone cannot run a build this
sprint (Apple), so iOS paths are proven by tests, the unsigned `ios.yml` build and, new this sprint, the iOS Simulator
(F345).

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control, then the instance fix.

## Phase 2 and 3 checks (2026-11-06)

- Top-tier model: Opus 5.5. DONE.
- 2.2 / 3.1 Sprint number: 84 (Sprint 83 merged: PR #534 -> develop `8bee2ce0`; develop -> main PR #547 `0a65fd22`,
  tag `v0.24.0`). DONE.
- 2.3 Sprint 83 cards: #535-#546 closed by the merge; #509, #510, #523 open as intended (Apple). DONE (4f9bca43).
- 2.4 Working tree clean; all work pushed (7277d81b). DONE.
- 2.6 Dependency check (`dart pub outdated --no-dev-dependencies`, 2026-11-06): discontinued `js` 0.6.7
  (transitive); 20 dependencies constrained below a resolvable version (the same set as Sprint 83). No security advisory
  found by this check. No action this sprint (a dependency change needs Harold's approval); recorded.
- Phase 8 cycle: 8.1 main merge done (#547); 8.2 pass 1 done (4f9bca43); 8.3 0.24.0 MSIX and AAB built and verified
  (e8f70c95), both submitted (Harold, 2026-11-06: Microsoft Store in certification, Play closed testing in review;
  7277d81b); 8.4 pass 2 scope selected (above). DONE.
- 3.2.1 `docs/sprints/SPRINT_83_SUMMARY.md` exists; the Past Sprint Summary row for 83 exists. DONE.
- 3.2.2 this file (replaces the Sprint 84 stub; the stub's carry-ins are kept below). DONE (draft).
- 3.3 Branch `feature/20261105_Sprint_84` exists and is pushed. DONE.
- 3.3.1 Draft PR: created with this plan (number recorded in `.claude/sprint_status.json`).
- 3.4 / 3.5 Cards: created at 3.7.0, the first action after approval (one per task).
- 3.6.1 Architecture Impact Check: below.

## Tasks, order, models and estimates

Estimates are minutes. Cards keep the backlog estimates Harold selected; re-estimates cite their reason.
`[no-history]` marks a step-type with no samples in `CODING_VELOCITY.md`.

- **Task 0 -- Version bump 0.24.1+22** (3.7.0b). PATCH: no card adds a user-facing `feat` (F280 and F342 fixes are
  `fix`; F345 is CI and an iOS resource; the hooks are tooling). Haiku. 10-15m.
- **Task 1 -- Manual Validation carry-ins** (MV-3c; the stub's 0.24.0 Android channel check). Main session. 10-20m
  plus Harold's phone time; MV-3c waits on a YELLOW No Rule item on the Fold.
- **Task 2 -- F342**: Fold background log errors (AOL, iCloud). Sonnet. 30-90m.
- **Task 3 -- F280**: Doze network availability for alarm scans. Sonnet. 45-60m -> 60-120m (3.2.2.2: the audit found
  the likely cause, `DozeScanTrigger.kt:107` has no network constraint, so the card now carries a fix and its test,
  plus three 20-minute emulator windows).
- **Task 4 -- F341**: F325 part B, live first-run evaluation (Windows, Android emulator, iOS Simulator screens).
  Main session, interactive with Harold. 90-150m -> 105-165m (adds the iOS leg from Task 8's screenshots).
- **Task 5 -- F326**: Python batch H1, three small PreToolUse hooks. Haiku. 90-150m.
- **Task 6 -- F327**: Python batch H2, `verify-closeout-complete`. Sonnet. 120-200m.
- **Task 7 -- F328**: Python batch H3, `sprint-auto-advance`. Sonnet. 150-260m.
- **Task 8 -- F345**: iOS Simulator smoke and screen check on the `macos-26` runner, plus the privacy manifest.
  Sonnet. 90-150m -> 120-210m (3.2.2.2: no Mac here, so every try is a CI run of about 10-15 minutes).
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 120-200m.

**Total**: Tasks 0-8 about 695-1,225 minutes, plus the 120-200 allowance, plus Harold's phone and first-run time.

**When can Harold come back (first Manual Validation handoff)**: Task 4 F341 is interactive and can run as soon as
Task 8 has produced the iOS Simulator screenshots, or earlier for the Windows and Android legs at a time Harold
chooses. For the code tasks, about 9-14 hours of wall-clock serially; with the parallel blocks below, about 5-8 hours.

**Order**:
1. 3.7.0 cards, 3.7.0b version bump (Task 0), 3.7.1 PR body.
2. Parallel block A (sub-agents, different files): Task 5 F326 (hooks), Task 8 F345 (`ios.yml`, `ios/`), Task 2 F342
   (read-only log analysis; any fix waits for Q1).
3. Task 3 F280 after Task 2 (the Fold log may show the same DNS failures and sharpen the arms). The emulator runs are
   serialized with any build.
4. Task 6 F327 after Task 5, then Task 7 F328 after Task 6: all three edit `.claude/settings.json` and may extend
   `.claude/hooks/lib/`, so they run one at a time.
5. Task 4 F341 with Harold at a time he chooses (needs an empty first-run state, see the card); Task 1 whenever the
   Fold shows a YELLOW No Rule item.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b)): Tasks 2, 3, 5, 6,
7 and 8 are delegated to sub-agents on their assigned tier before Manual Validation, with the delegation checklist and
the "Progress and restart" block verbatim. Tasks 0, 1 and 4 run in the main session. Anything run in the main session
executes on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand on the draft + pr-review-toolkit code-reviewer and
silent-failure-hunter, with the changed-file list), started with the retrospective prompt at Manual Validation
complete. The silent-failure-hunter prompt is scoped to the changed files and the classes this sprint touches (Harold,
2026-11-05: a hunter run *"unreasonably broad for such a small code change"* was stopped).

**Cards**: created at Phase 3.7.0. One "Closes #N" per card in the PR body.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md` Standing Approval Inventory), so
they are not asked again: (a) Task 0 the version bump and the "Last uploaded to Play" move to 0.24.0 (versionCode 21);
(b) Tasks 5-7 changes under `.claude/hooks/` and the `.claude/settings.json` registration swap for the converted hooks
only, each after its cases pass, with `.claude\hooks\run-test-cases.ps1` green after each change; (c) Task 8 a new job
in `.github/workflows/ios.yml` (shared infrastructure) and a new file in the iOS Runner target; (d) Task 3 emulator
`adb` commands (force idle, network state) on the emulator only; (e) Task 4 the DEV data folder backup and byte-for-byte
restore around the Windows clean run. Not covered, still asked: any dependency version change, any edit to
`secrets.*.json`, and the Q1 and Q2 decisions below.

## Phase 3.2.2.1 branch-state verification (summary)

- **MV-3c: open.** Sprint 83 Q3 = 1: waits for a YELLOW No Rule item on the Fold; the only No Rule item seen was RED.
- **F342: open; evidence already on disk.** Eight Fold diagnostic logs are pulled in
  `validation-screenshots/sprint-83/` (`diag_v0.21.0_2026-10-29.log` to `diag_v0.23.0_2026-11-04.log`). No grouping or
  cause exists yet (master plan F342: "unverified which code path raised each").
- **F280: open; likely cause found.** The Doze-alarm scan is enqueued with NO constraints
  (`DozeScanTrigger.kt:107-110`, `setInitialDelay(0)` only). The notification-triggered scan requires
  `NetworkType.CONNECTED` (`DozeScanTrigger.kt:186-189`), and so do the periodic task and the Dart one-off
  (`background_scan_scheduler.dart:455`, `:560`). Windows' scheduled task sets `-RunOnlyIfNetworkAvailable`
  (`powershell_script_generator.dart:63`). The experiment (R77-BAT-4, `docs/research/R76-1_BATTERY_AB_RESULTS.md:303-315`)
  was never run.
- **F341: open.** Part A is done: `docs/research/F325_FIRST_RUN_EVALUATION_S83.md`, 10 live checks at `:100-111`.
- **F326 / F327 / F328: open.** The F321 layer exists (`.claude/hooks/lib/common.py`, `hooklib.py`,
  `mutation_lock.py`); the five hooks are still PowerShell (109, 174, 141, 515 and 756 lines) and registered as
  `powershell ... .ps1` in `.claude/settings.json`. Case folders: `stash-guard` 8, `sprint-cards` 8, `velocity-warn` 12,
  `closeout` 25, top-level 55 plus `fixtures/` 40. The Python replay is `.claude/hooks/tests/test_pylib.py`.
- **F345: new.** `ios.yml` has `ios-build` (unsigned device build, `:37-56`) and `ios-testflight`; no Simulator job.
  No `PrivacyInfo.xcprivacy` in `mobile-app/ios/Runner/`. Nine integration tests exist in
  `mobile-app/integration_test/`; none run in CI (`ci.yml:61-62` runs `flutter test` only). The app targets iPhone and
  iPad (`TARGETED_DEVICE_FAMILY = "1,2"`, `project.pbxproj:368`). The repository is public.

**Phase 3.2.2.2 (re-estimates)**: F280 45-60m -> 60-120m; F341 90-150m -> 105-165m; F345 90-150m -> 120-210m
(reasons above). No other card changed.

## Phase 3.6.1 Architecture Impact Check

- **ADR-0042 / ADR-0049 (parity, PlatformCapabilities)**: F280 changes the Android Doze-alarm path, which is already a
  declared Android exception (F235). If the fix lands, ARCHITECTURE.md's background-scan section names the network
  requirement on all three platforms in the same commit.
- **ADR-0050 (iOS)**: F345 adds a Simulator test job and the privacy manifest. ADR-0050 and `docs/TESTING_STRATEGY.md`
  gain the Simulator as an iOS test level (what it proves and what it cannot). No ADR conflict.
- **ADR-0051 (Python for deterministic tooling)**: F326-F328 follow it; the hooks' registration form changes as
  ADR-0051 records. No new ADR.
- **Data model**: no change in any card.
- No ADR conflicts found.

## Carried from the Sprint 83 close-out (stub content, kept)

- **0.24.0 store updates**: built, verified and submitted (see Phase 8 above). Open on the installed Store build: the
  Step 4.2 Gmail sign-in URL check.
- **Retro carry-ins (live rules)**: IMP-1 every card that adds a new caller of a user action, a new list or a new
  pattern carries "Existing code reused"; 5.1.2 class 1 checks the code calls it, class 7 checks each test's name
  against its checks. IMP-2 (b) an MV answer that renames or changes a behavior records `Swept: grep '<old text>' -> N
  hits fixed`. IMP-3 a script, hook or tool never reports success when it did nothing or what it ran crashed
  (`scripts/test-hook.ps1` is the model; 5.1.2 question 6). IMP-4 every delegated agent's progress file records
  `RUN STARTED` / `RUN STOPPED <yyyy-mm-dd HH:MM>` from the clock.
- **Standing facts (Harold)**: a phone screenshot that shows the app version proves the Play update installed
  (2026-11-04). Fold notification access for the app is ON and stays on. The iCloud DEV account's per-account
  background scan is on, every 5 minutes.

## Questions for approval (Phase 3.7)

**Q-A. Approve this plan?**
1. Approved as written.
2. Approved with changes (say which).

**Q1. F342: what happens to a real defect the log analysis finds?** The card names the cause of each error group. A
real defect then needs a fix. The review-fix rule (fix without asking under 4 code files and 600 lines) does not cover
new findings from an investigation card.
1. Fix it in this sprint when the fix is under 4 code files and 600 lines; larger ones become backlog cards (recommended:
   these are real errors on a real phone, the reason F342 was picked).
2. Backlog cards only; nothing is fixed this sprint.
3. Ask me per defect, with the evidence.

**Q2. F280: may the fix change the F235 Doze-alarm request?** The likely fix adds a network requirement to the Doze-alarm
scan (the same `NetworkType.CONNECTED` the notification scan uses). That changes a prior development decision (Class 2):
WorkManager may then hold the scan until the network is up, which in deep Doze could delay it.
1. Pre-approved if the R77-BAT-4 decision rule is met: arm A fails at DNS in at least 25 percent of alarm scans, and the
   fix (arm B) stops it without raising wakelock time by more than 20 percent; otherwise ask me with the numbers
   (recommended).
2. Always ask me with the results before changing the request.

**Answers (Harold, 2026-11-06)**: *"q1. 1 q2 2"*. Q1 = 1: a F342 defect is fixed this sprint when the fix is under 4
code files and 600 lines; larger ones become backlog cards. Q2 = 2: F280 runs the experiment and the fix with its test
on the branch, then ASKS Harold with the arm A and arm B numbers before the Doze-alarm request change is committed as
final. Q-A = approved (2026-11-06). Q3 = 3: no code change; a full rescan of the affected folders re-sees the older
rows and fills their stored suggestion. This is a Manual Validation note for Harold, not a card.

**Mid-sprint answers (Harold, 2026-11-06 16:13)**: *"q1 a. revert q2 a fix it now"*. F280 Q = 1, revert: the arms
showed 0 `Failed host lookup` in each arm (R-5 threshold 25 percent), so the `DozeScanTrigger.kt` network constraint
and its test were removed; the results stay in `R76-1_BATTERY_AB_RESULTS.md`; F280 closes as "did not reproduce on the
emulator". Auto-advance `?` finding Q = 1, fix now: `sprint-auto-advance.py` removes the status footer before the
end-of-message `?` check (case violation-55, test updated, mutant KILLED, hook suite 196/196), under Task 7.

**Q3. New finding (2026-11-06): the Review No Rule Items pop-up shows no "Suggested" button on older rows.** Harold's
Windows screenshot: `news_40693@citorisc.net` shows Block Entire Domain with no "Suggested" mark, although a `news_`
plus 4-6 digits sender is suggested Block Entire Domain since Sprint 83 MV Q9 = 2 (`rule_suggestion.dart:298-307`).
Cause: the review screen shows only the suggestion stored at scan time (`no_rule_review_screen.dart:568`,
`item.email.suggestion`); a row is refreshed only when a scan sees the email again (`unmatched_email_store.dart:334`).
Evidence (read-only copy of the production database): 220 unaddressed rows, 0 with a stored suggestion; 68 are `news_`
senders, all stored 2026-09-24 19:08 and never seen again. The Results screen recomputes the suggestion
(`results_display_screen.dart:79`), so the two screens disagree for the same email. Same shared code on all three
platforms (no platform exception).
1. Add a card to Sprint 84 (Sonnet, about 60-120m): when a row has no stored suggestion, compute it when the pop-up
   opens. Old rows store the sender and the auth class but not the per-method SPF/DKIM/DMARC verdicts that the F323
   R-2 "could not check" guard needs, so the card first proves whether the stored class can stand in for that guard;
   if not, it reads the message headers when the pop-up opens, and shows no suggestion when they cannot be read.
   Covers every existing row with no rescan (recommended).
2. Backlog card only; this sprint does not change it.
3. No code: a full rescan of the affected folders re-sees the rows and fills the suggestion.

---

# Cards

## Task 0 -- Version bump 0.24.1+22 (3.7.0b)

**Value**: This lets a tester tell the Sprint 84 build from the 0.24.0 store builds.

**Requirements**:
- R-1: `mobile-app/pubspec.yaml` `version: 0.24.1+22` and `msix_config.msix_version: 0.24.1.0`; every version literal
  the gate checks follows.
- R-2: PROVISIONAL `docs/store-assets/RELEASE_NOTES_0.24.1_windows.md` and `_play.md` (shape: the 0.24.0 files; range:
  after 0.24.0).
- R-3: `docs/STORE_VERSION_STATUS.md` "Last uploaded to Play (any track)" moves to 0.24.0 (versionCode 21) in the same
  commit (Harold reported the upload 2026-11-06); the Dev worktree row reads 0.24.1+22.

**Affected components / files**: `mobile-app/pubspec.yaml`; version literals found by `version_consistency_test`;
`docs/store-assets/RELEASE_NOTES_0.24.1_*.md`; `docs/STORE_VERSION_STATUS.md`; `CHANGELOG.md`.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: `flutter test test/policy/version_consistency_test.dart test/policy/dev_version_ahead_test.dart
  test/policy/release_notes_test.dart` passes.

**Tests to write**: none new; T-1 (AC-1) the three existing policy gates.

**Definition of Done**: default task-level DoD.

**Model**: Haiku -- the cheapest tier fits a mechanical bump with three gates as the oracle.
**Delegation checklist included in the sub-agent prompt** (when delegated): N/A (main session, with 3.7.0).
**Executed-by** (filled at completion):
**Step-types**: DOCS, DATA. **Est-Effort**: 10-15m.

## Task 1 -- Manual Validation carry-ins (MV-3c; 0.24.0 Android channel check)

**Value**: This closes the last open Sprint 83 phone check and proves the 0.24.0 notification channels on a real phone.

**Requirements**:
- R-1 (MV-3c, Fold, YELLOW item): when a YELLOW No Rule item appears on the Fold, open its pop-up. Expected: one rule is
  marked "Suggested", and Block Subject, the regex note and the Skip row fit the cover screen with no clipping. Until
  a YELLOW item appears, the step is not testable (the only one seen was RED, "Sign-in check failed").
- R-2 (stub carry-in): after the Fold shows 0.24.0 (Settings top bar "Version 0.24.0"), Android Settings > Apps > the app
  > Notifications shows two channels, "Every Completed Scan" and "One or more No Rule Items", and no
  `background_scan_channel`.
- R-3: rehearse each step on Harold's build before handover (5.1.9), from the code and tests that produce the screen.

**Affected components / files**: none (validation); results go in this plan's Manual Validation section.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: R-1 is the shared pop-up (Windows proven in Sprint 83 MV); the Fold cover
screen is the narrow-width case. R-2 is the declared Android exception for notification channels (Sprint 83 F322,
ADR-0049 table); Windows and iOS have no channels.

**Dependencies / blockers**: a YELLOW No Rule item on the Fold (R-1); the 0.24.0 Play update reaching the Fold (R-2).

**Acceptance criteria**:
- AC-1: R-1 and R-2 each have a Fold screenshot pulled over MTP (`scripts/pull-phone-screenshots.ps1 -Sprint 84`) and
  a recorded result.

**Tests to write**: none (manual validation).

**Definition of Done**: AC-1 only (no code).

**Model**: main session (interactive with Harold) -- N/A.
**Executed-by** (filled at completion):
**Step-types**: MANUAL. **Est-Effort**: 10-20m plus Harold's phone time.

## Task 2 -- F342: Fold background log errors (AOL unfinished scans and errors, iCloud errors) (Priority 34)

**Value**: This names the cause of real background-scan errors on a real phone, so each one can be fixed or ruled out.

**Requirements**:
- R-1 (audit first): read the eight Fold logs already pulled (`validation-screenshots/sprint-83/diag_v0.21.0_*` and
  `diag_v0.23.0_*`); count errors and unfinished scans per account per day with `scripts/phone-log-health.ps1` (read its
  `param()` block first). Then pull the current 0.24.0 log over MTP and add it, so a group fixed by 0.24.0 is not
  reported as open.
- R-2: group the errors by message and stack; for each group name the code path (`file:line`) that raised it and the
  cause, or write "cause unknown" plus the check that would settle it. "Transient", "flaky" and "intermittent" are not
  causes (CLAUDE.md).
- R-3: "unfinished scan" is defined before counting (a scan row with no outcome line, an `in_progress` row the reaper
  closed, or a worker stop): name which, from the log lines.
- R-4: check the Windows DEV background log for the same groups (Windows DEV background runs every 5 minutes for all
  four accounts); report per group whether Windows shows it.
- R-5: cross-check against F280: list any group that is `Failed host lookup` on a `trigger=doze-alarm` run and hand it
  to Task 3 instead of fixing it here.
- R-6: each real defect follows Q1 (fix under the size limit, or a backlog card with effort in minutes). Each fix
  states its prevention first.

**Affected components / files**: `docs/research/F342_FOLD_BACKGROUND_ERRORS_S84.md` (new); any fix lands in the file the
group names.

**Existing behavior relied on**: the diagnostic log writes one outcome line per account scan and a worker-stop line
with the stop reason -- verified at `android_background_scan_worker.dart:139` (the `reason=timeout raw=3 ...
trigger=doze-alarm` line format) and `:165` (stop-reason names). Grouping rests on these lines.

**Callers of any guard being changed**: decided per fix; each fix card lists them.
- Catches between any NEW throw (or early exit) and the code meant to handle it: per fix, or none.

**User-reachable control**: N/A for the analysis. A fix that makes a failure visible names the screen and the exact
text (Sprint 81 retro IMP-1).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the scanner, the IMAP adapter and the error mapping are shared Dart, so a
cause found in them applies to Windows, Android and iOS, and a fix there covers all three. R-4 checks Windows. iOS has
no background run yet (F67c); a fix in shared code is noted as covering iOS by the shared path. A cause in the Android
worker or the native trigger is an Android exception and is declared as such.

**Dependencies / blockers**: the Fold over MTP for the 0.24.0 pull (Harold connects it); Q1.

**Acceptance criteria**:
- AC-1: every error group in the eight logs plus the 0.24.0 log has a count, a `file:line`, and a cause or a named next
  check.
- AC-2: the AOL unfinished scans and the iCloud errors are each accounted for by a group (2 + 2 AOL, 11 iCloud as first
  reported, or the corrected counts with the reason).
- AC-3: R-4's Windows answer is recorded per group.
- AC-4: each real defect is fixed (Q1 = 1, under the limit) with a test, or has a backlog card.

**Tests to write**:
- T-1 (AC-4) -- TEST-UNIT per fix, in the test file next to the changed code, mutation-verified
  (`scripts/mutation-test.ps1`), with its "what this does NOT catch" line.

**Definition of Done**: default task-level DoD PLUS the research file committed.

**Model**: Sonnet -- *why not the cheaper tier*: naming a cause means tracing each message through the scanner, the
IMAP adapter and the worker; counting alone would fit Haiku, the cause does not.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent, as assigned (2026-11-06 08:49-10:33). 9 groups; 1 real
defect fixed (group 4, stopped worker leaves the scan row in progress; 3 code files, 118 lines, Q1 limit met; 7 tests,
7 of 7 mutants KILLED); iCloud group needs Harold to re-enter the app-specific password (Manual Validation); backlog
F346, F347; nothing handed to F280 (0 `Failed host lookup` on doze-alarm runs). Main session re-ran the two test files
together (27 pass) and `flutter analyze` (clean).
**Step-types**: DIAG `[no-history]`, SVC-EDIT, TEST-UNIT, DOCS. **Est-Effort**: 30-90m.

## Task 3 -- F280: Doze network availability for alarm scans (Priority 36)

**Value**: This prevents Doze-alarm scans that start before the phone has a network and fail at DNS.

**Requirements** (R77-BAT-4, `docs/research/R76-1_BATTERY_AB_RESULTS.md:303-315`):
- R-1 (audit first): confirm on the emulator that the Doze-alarm request has no network constraint
  (`DozeScanTrigger.kt:107-110`) while the notification request does (`:186-189`); record the WorkManager job's
  constraints from `adb shell dumpsys jobscheduler` for both.
- R-2: arm A (as today, with the worker logging network state at start): force idle on the emulator
  (`adb shell dumpsys deviceidle force-idle`), interval 5, one 20-minute window; count alarm scans that fail at DNS
  (`Failed host lookup`) against those that reach sign-in.
- R-3: arm B (the fix under test): add `setRequiredNetworkType(NetworkType.CONNECTED)` to the Doze-alarm request,
  mirroring the notification request; same window and metric; also record wakelock time
  (`adb shell dumpsys batterystats`) and scan start delay (`trigger=doze-alarm delay=NNs`).
- R-4: arm C (charger connected, `adb shell dumpsys battery set ac 1`): same, as a control.
- R-5: apply the decision rule as written: if A fails at DNS in at least 25 percent of alarm scans and B stops it without
  raising wakelock time by more than 20 percent, keep the fix (Q2); otherwise revert it and record the cause.
- R-6: if the fix lands, the delay in deep Doze is measured and stated (the trade-off Q2 names), and the code comment
  names the platform behavior on each platform: Android WorkManager constraint; Windows `-RunOnlyIfNetworkAvailable`
  (`powershell_script_generator.dart:63`); iOS `BGAppRefreshTask` (whether it offers a network requirement is
  UNVERIFIED; read Apple's page at card time and record it as an F67c input).

**Affected components / files**:
- `mobile-app/android/app/src/main/kotlin/com/myemailspamfilter/DozeScanTrigger.kt:107-110` -- the constraint (arm B).
- `mobile-app/lib/core/services/android_background_scan_worker.dart` -- a network-state field on the start line, if the
  existing line does not carry it.
- `docs/research/R76-1_BATTERY_AB_RESULTS.md` (R77-BAT-4 results); `docs/ARCHITECTURE.md` background-scan section.

**Existing code reused**: the notification request's constraint builder (`DozeScanTrigger.kt:186-189`) -- the new code
CALLS one shared constraint value for both requests (split into a private `val networkConstraint` used by both); it
does not copy the builder.

**Existing behavior relied on**: the notification-triggered request waits for a network -- verified at
`DozeScanTrigger.kt:162-164` (comment) and `:186-189` (code). KEEP policy on the Doze request stays
(`DozeScanTrigger.kt:112-124`).

**Callers of any guard being changed**: the Doze-alarm request is built in one place (`DozeScanTrigger.kt:107`), called
from the alarm receiver only.
- Tooling that launches or kills the same executable: N/A (no process behavior change).
- Catches between any NEW throw (or early exit) and the code meant to handle it: none (a constraint adds no throw).

**User-reachable control**: N/A (no new control).

**Observable behavior -- before / after**: BEFORE: in deep Doze some interval scans fail at DNS; the failure appears as
an error on that scan in Scan History (the exact text is recorded in R-2 from the emulator screen). AFTER (if the fix
lands): those scans wait for the network and then run; no DNS-failure row. The cost (delay) is recorded in R-6.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Doze and its alarm are a declared Android exception (F235). The behavior made
the same on all three platforms is "a background scan starts only when a network is available": Windows already does
this, Android's periodic and notification scans do, and this card closes the Doze-alarm gap. iOS: recorded as an F67c
input (R-6).

**Dependencies / blockers**: Task 2 first (R-5 hand-off); the Android emulator (serialized with any build); Q2.

**Non-functional requirements**:
- Platform: Android native only; no Dart `Platform.isX` added.
- Battery: wakelock time within the decision rule's 20 percent.

**Acceptance criteria**:
- AC-1: the three arms have counts recorded in R77-BAT-4 (DNS failures / alarm scans, wakelock time, start delay).
- AC-2: the decision rule is applied as written and the outcome (fix kept or reverted) is recorded with its numbers.
- AC-3: if kept: a test proves the Doze-alarm request and the notification request carry the same network constraint.

**Tests to write**:
- T-1 (AC-3) -- TEST-UNIT (Android instrumented or Robolectric is not set up; so a Dart-side policy test in
  `test/policy/` that reads `DozeScanTrigger.kt` and asserts both requests use the shared constraint), mutation-verified
  by removing it from the Doze request. "Would NOT catch": whether WorkManager honors the constraint in Doze (that is
  AC-1's emulator measurement).

**Definition of Done**: default task-level DoD PLUS the results in R77-BAT-4 and the ARCHITECTURE.md line if the fix
lands.

**Model**: Sonnet -- *why not the cheaper tier*: emulator Doze measurement plus a native WorkManager change judged by a
decision rule; Haiku-shaped only for the one-line constraint.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent, as assigned (2026-11-06 11:09-14:15). R77-BAT-4 arms A (unfixed), B (fix), C (fix, charger) on pixel34_updated API 34: 0 Failed host lookup in each arm (2 testable scans per arm; the test accounts are rejected at login and then skipped); dumpsys shows the Doze one-off gained CONNECTIVITY with the fix. T-1 4 tests, 4 of 4 mutants KILLED. R-5: under 25 percent, so revert. Harold (2026-11-06 16:13, mid-sprint Q = 1): revert; the Kotlin change and its test were removed, not committed. Results committed in R76-1_BATTERY_AB_RESULTS.md (91cec1de). iOS: BGAppRefreshTaskRequest has no network property (F67c input).
**Step-types**: NATIVE-AND `[no-history]`, TEST-UNIT, DOCS. **Est-Effort**: 60-120m.

_**Risk & rollback**_: a constraint that holds scans too long in Doze is the risk Q2 names; rollback is reverting the one
constraint line (the test then needs its expectation reverted too).

_**Decision-class interrupts**_: Class 2 (changes the F235 request), governed by Q2.

## Task 4 -- F341: F325 part B, live first-run evaluation (Priority 32)

**Value**: This confirms, on real installs, what a new user meets in the first minutes, and turns each confirmed
problem into a card.

**Requirements** (method from the F152 template, as Sprint 83 Task 12):
- R-1: live pass on Windows with a release-equivalent build and a genuinely empty data folder. The DEV data folder is
  backed up first and restored byte for byte after (hash before and after). Harold drives; Claude records against the 7
  sections of `docs/research/F325_FIRST_RUN_EVALUATION_S83.md`.
- R-2: live pass on the Android emulator (clean install; no phone data touched).
- R-3: walk the 10 live checks (`F325_FIRST_RUN_EVALUATION_S83.md:100-111`) on each platform where they apply, and
  confirm or refute the 5 static findings: the Help walkthrough is outdated; the Gmail "Recommended" labels contradict
  each other; "Turn on" does not request the notification permission; raw exception text reaches users; the feedback
  address is plain text, not a link.
- R-4 (iOS leg): compare the first-run screens from Task 8's iOS Simulator screenshots with the Windows and Android
  screens; any difference not declared in ADR-0050 is a finding. Gmail sign-in and the notification prompt on iOS stay
  a recorded gap until F67b's device check.
- R-5: findings become backlog cards with effort in minutes; nothing is fixed in this task.

**Affected components / files**: `docs/research/F325_FIRST_RUN_EVALUATION_S83.md` (a part B section); new backlog cards in
`docs/ALL_SPRINTS_MASTER_PLAN.md`.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the evaluation itself is the parity check: R-1 Windows, R-2 Android, R-4
iOS screens. A finding on one platform is checked on the other two before it is carded.

**Dependencies / blockers**: Harold's time; Task 8 for R-4; the emulator (serialized with any build).

**Acceptance criteria**:
- AC-1: each of the 7 sections has findings or "no issues" per platform run (Windows, Android, iOS screens).
- AC-2: each of the 10 checks has a result with a screenshot or log line, per platform where it applies.
- AC-3: the data folder backup and restore are verified (hash before and after).
- AC-4: every confirmed finding is a backlog card with effort in minutes.

**Tests to write**: none (evaluation).

**Definition of Done**: AC-1 to AC-4; no code.

**Model**: main session (interactive with Harold) -- N/A.
**Executed-by** (filled at completion):
**Step-types**: MANUAL, DOCS. **Est-Effort**: 105-165m plus Harold's time.

## Task 5 -- F326: Python batch H1, three small PreToolUse hooks (Priority 35)

**Value**: This moves three commit gates to the tested Python layer, so they run the same way on every machine.

**Requirements**:
- R-1: port `.claude/hooks/block-carry-forward-stash.ps1` (109 lines), `require-sprint-cards.ps1` (174) and
  `warn-commit-without-velocity.ps1` (141) to `.py` with the F321 layer (`.claude/hooks/lib/common.py`, `hooklib.py`).
  Keep exit codes, the `allow_stash` bypass token and every message text a gate or test matches on.
- R-2: `warn-commit-without-velocity` keeps the `hookSpecificOutput.additionalContext` JSON on stdout byte for byte.
- R-3: `require-sprint-cards` keeps its fail-open path when `gh` or `.claude/sprint_status.json` cannot be read; `git` and
  `gh` calls go through `common.git` (or a non-raising `gh` wrapper added to `common.py`, reused by Task 6).
- R-4: register each `.py` in `.claude/settings.json` (form: `python "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.py"`,
  ADR-0051) only after its cases pass; keep the `.ps1` files until F329 retires the shims.
- R-5: `.claude/hooks/tests/test_pylib.py` gains the `stash-guard`, `sprint-cards` and `velocity-warn` folders.
- R-6 (Sprint 83 IMP-3): no hook reports ALLOW because it crashed; an exception in the hook is a visible failure, not a
  silent pass (the F321 layer's pattern).

**Affected components / files**: the three new `.py` files; `.claude/hooks/lib/common.py` (only if R-3 needs the `gh`
wrapper); `.claude/settings.json`; `.claude/hooks/tests/test_pylib.py`; `docs/adr/0051-*.md` conversion log.

**Existing abstraction checked**: `common.git` and the `hooklib` payload reader (F321) -- used, not re-written.
**Existing code reused**: `hooklib` payload parsing and `common.git` -- the new hooks CALL them.

**Callers of any guard being changed**: the hooks guard `git stash`, the first task commit and task-closing commits; the
callers are every Bash and PowerShell tool call that runs git. Behavior must not change; the case suites are the proof.
- Catches between any NEW throw (or early exit) and the code meant to handle it: the hook's top-level handler in
  `hooklib` (R-6).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development process only; the app is not affected. The hooks must run on
Windows (this machine) and on Linux and macOS (CI and a future Mac for iOS): R-5's replay runs on the CI Linux runner.

**Dependencies / blockers**: None (the F321 layer exists).

**Acceptance criteria**:
- AC-1: `.claude\hooks\run-test-cases.ps1` passes with the same case count as before the port.
- AC-2: each hook BLOCKs on its block cases and ALLOWs on its allow cases (`scripts/test-hook.ps1`), and is
  mutation-verified (`scripts/mutation-test.ps1`, `command` check): at least one mutant per hook, each KILLED.
- AC-3: `test_pylib.py` passes on Windows and on the CI Linux runner.

**Tests to write**:
- T-1 (AC-1, AC-2) -- the existing case folders run against the Python hooks; mutants per hook.
- T-2 (AC-3) -- `test_pylib.py` replay of the three folders.

**Definition of Done**: default task-level DoD PLUS the ADR-0051 conversion log line per hook.

**Model**: Haiku -- the cheapest tier fits a line-by-line port where the existing case suites are the oracle.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Haiku sub-agent, as assigned (2026-11-06 08:51-10:40). Three hooks ported; hook suite 178/178 before and after (main session re-ran it: 178/178); test_pylib.py 47 OK on Windows (Linux CI pending, AC-3); PowerShell vs Python parity probe 0 mismatches over 28 cases; 11 mutants KILLED (stash-M2 first SURVIVED, a test was added). R-2 judgment (main session): the Python velocity hook ends stdout with one trailing newline that the PowerShell did not; Claude Code parses the JSON, so the content is identical and the shared hooklib layer is not changed. .ps1 files kept for F329.
**Step-types**: HOOK, TEST-UNIT. **Est-Effort**: 90-150m.

## Task 6 -- F327: Python batch H2, verify-closeout-complete Stop hook (Priority 35)

**Value**: This moves the close-out gate, which blocks an incomplete sprint close, to the tested Python layer.

**Requirements**:
- R-1: port `.claude/hooks/verify-closeout-complete.ps1` (515 lines) to `.py`; keep every check number and message that
  the hook, `SPRINT_CHECKLIST.md` and CLAUDE.md cite (for example "check 3d-2", "check 3d-3").
- R-2: read markdown with `utf-8-sig`; keep CRLF and LF handling; add one CRLF fixture.
- R-3: `gh` calls go through the non-raising wrapper (Task 5 R-3) and fail open, as the PowerShell does.
- R-4: keep each check's parsing exactly (for example 3d-2 reads only the FIRST line of the 7.7.1 bullet; 3d-3's minutes
  regex); a parse that differs is a behavior change and is not allowed in a port.
- R-5: register only after the 25 `closeout` cases pass unchanged; `test_pylib.py` gains the folder.
- R-6 (Sprint 83 IMP-3): an exception is a visible failure, not a silent pass.

**Affected components / files**: `.claude/hooks/verify-closeout-complete.py` (new); `.claude/settings.json`;
`.claude/hooks/tests/test_pylib.py`; `.claude/hooks/test-cases/closeout/` (one CRLF fixture added).

**Existing code reused**: Task 5's `gh` wrapper and the `hooklib` reader -- CALLED.

**Callers of any guard being changed**: the Stop event at close-out; behavior must not change (the 25 cases).
- Catches between any NEW throw (or early exit) and the code meant to handle it: the top-level handler (R-6).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development process only (as Task 5).

**Dependencies / blockers**: Task 5 (the `gh` wrapper; one `settings.json` edit at a time).

**Acceptance criteria**:
- AC-1: the 25 `closeout` cases plus the new CRLF case pass; the full suite count is unchanged plus one.
- AC-2: at least 6 mutants, one per check family, each KILLED.
- AC-3: `test_pylib.py` passes on Windows and on the CI Linux runner.

**Tests to write**: T-1 (AC-1, AC-2) the case folder plus mutants; T-2 (AC-3) the replay.

**Definition of Done**: default task-level DoD PLUS the ADR-0051 conversion log line.

**Model**: Sonnet -- *why not the cheaper tier*: 515 lines with many check families and exact parsing quirks the
close-out depends on; a port that changes one quirk silently disables a gate.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent, as assigned (2026-11-06 11:10-12:33). verify-closeout-complete.py: 26 closeout cases pass (new CRLF case violation-15), full hook suite 179/179 (baseline 178 plus one); test_pylib.py 58 OK on Windows (Linux CI pending, AC-3); parity probe 0 mismatches over 45 payloads; 15 mutants KILLED (3 first SURVIVED, tests added). New common.gh() wrapper (never raises, 8 s timeout). Deviation: mutants ran focused test_pylib tests, not the 30-minute full suite per mutant.
**Step-types**: HOOK, TEST-UNIT. **Est-Effort**: 120-200m.

## Task 7 -- F328: Python batch H3, sprint-auto-advance Stop hook (Priority 35)

**Value**: This moves the largest gate (auto-advance and the F193 evidence gate) to the tested Python layer.

**Requirements**:
- R-1: port `.claude/hooks/sprint-auto-advance.ps1` (756 lines) pattern by pattern, one commit per pattern group.
- R-2: carry each pattern's case sensitivity: PowerShell `-match` is case-insensitive, `-cmatch` is not; Python needs
  `re.IGNORECASE` per call where the PowerShell used `-match`. Python 3.11 rejects an inline `(?i)` not at the pattern
  start (F321 finding), so flags are passed, not inlined.
- R-3: the top-level `test-cases/*.json` (55) and the `fixtures/` sprints (40) are the contract; they pass unchanged.
- R-4: the Stop registration swaps to `python "${CLAUDE_PROJECT_DIR}/.claude/hooks/sprint-auto-advance.py"` only after
  every case passes.
- R-5: re-read CLAUDE.md IMP-3 (Sprint 70): end-anchored patterns are coupled to the closing convention (the status
  footer); one case per end-anchored pattern with the footer present.
- R-6 (Sprint 83 IMP-3): an exception is a visible failure, not a silent pass.

**Affected components / files**: `.claude/hooks/sprint-auto-advance.py` (new); `.claude/settings.json`;
`.claude/hooks/tests/test_pylib.py`; new cases in `.claude/hooks/test-cases/` for R-5 if missing.

**Existing code reused**: `hooklib` reader and the `sprint_status.json` reader used by Task 5 -- CALLED.

**Callers of any guard being changed**: every Stop event; behavior must not change (the 95 cases and fixtures).
- Catches between any NEW throw (or early exit) and the code meant to handle it: the top-level handler (R-6).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development process only (as Task 5).

**Dependencies / blockers**: Task 6 (one `settings.json` edit at a time).

**Acceptance criteria**:
- AC-1: every top-level case and fixture passes; the full suite count is unchanged plus any R-5 cases.
- AC-2: one mutant per gate (1b, 1c, the F193 markers, the commitment detector, the question detector), each KILLED.
- AC-3: `test_pylib.py` passes on Windows and on the CI Linux runner.

**Tests to write**: T-1 (AC-1, AC-2) cases plus mutants; T-2 (AC-3) the replay; T-3 (R-5) footer-present cases.

**Definition of Done**: default task-level DoD PLUS the ADR-0051 conversion log line.

**Model**: Sonnet -- *why not the cheaper tier*: the most patterns of any hook, with case flags per call and
message-shape coupling that has silently disabled this gate before (Sprint 70).
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent, as assigned (2026-11-06 12:55-14:32). sprint-auto-advance.py with the same gate order, patterns and block text; Stop registration swapped to the .py last, after the mutation run; .ps1 kept for F329. Hook suite 195/195 (main session re-ran it: 195/195); test_pylib.py 74 OK on Windows (Linux CI pending, AC-3); parity probe 1 of 454 payloads differ (non-JSON stdin; neither blocks); 19 mutants KILLED. R-6 deviation: an unreadable plan or velocity file now exits 1 visibly instead of the .ps1's silent catch. Open finding (not applied; changes live gate behavior): the ? detector is end-anchored to the raw message, so a footer hides a trailing question mark; asked at Manual Validation.
**Step-types**: HOOK, TEST-UNIT. **Est-Effort**: 150-260m.

## Task 8 -- F345: iOS Simulator smoke and screen check on the macos-26 runner, plus the privacy manifest (NEW)

**Value**: This finds iOS-only defects before Apple approves the enrollment, using the iOS Simulator, which needs no
signing.

**Requirements**:
- R-1: add an `ios-simulator` job to `.github/workflows/ios.yml` on `macos-26`: build for the Simulator
  (`flutter build ios --simulator --debug`, no signing), boot an iPhone Simulator, and run the integration tests that can
  run there (`flutter test integration_test/<file> -d <simulator id>`). Triggers: the existing `push` paths, plus
  `workflow_dispatch`, plus a manual run at the 7.7.1 CI run 1.
- R-2 (audit first): for each of the nine files in `mobile-app/integration_test/`, record whether it runs on the
  Simulator (helpers may assume Windows paths or desktop window sizes); run those that do; list the others with the
  reason. A test that cannot run is not edited to pass.
- R-3: capture screenshots of the first-run screens (empty state, Add Account, Settings, Help) on an iPhone-size and an
  iPad-size Simulator (the app targets both, `TARGETED_DEVICE_FAMILY = "1,2"`), and upload them as a build artifact.
  These feed Task 4 R-4.
- R-4: add `mobile-app/ios/Runner/PrivacyInfo.xcprivacy` to the Runner target: no tracking, no tracking domains, and
  the required-reason API entries the app and its plugins use. Read Apple's current required-reason API list on Apple's
  page at card time and cite it; do not write the list from memory. Prove the file is in the built `.app` bundle.
- R-5: record what the Simulator does NOT prove (Gmail sign-in, the notification permission prompt, real background
  scheduling, real-device performance) in ADR-0050 and `docs/TESTING_STRATEGY.md`.
- R-6 (Sprint 83 IMP-3): the job fails when a test fails or when zero tests ran; it never reports green on nothing.

**Affected components / files**: `.github/workflows/ios.yml`; `mobile-app/ios/Runner/PrivacyInfo.xcprivacy` (new);
`mobile-app/ios/Runner.xcodeproj/project.pbxproj` (adds the file to the target); `docs/adr/0050-*.md`;
`docs/TESTING_STRATEGY.md`; `docs/ALL_SPRINTS_MASTER_PLAN.md` (F345 registered).

**Existing code reused**: the `ios-build` job's checkout, Flutter setup (`.fvmrc`) and `pub get` steps
(`ios.yml:37-56`) -- shared, not copied (a reusable step block or a matrix, chosen by the agent and stated in the card).

**Existing behavior relied on**: the unsigned iOS build compiles today -- verified by `ios.yml:56` and the green Sprint 81
run (master plan F67b: run 40012148625).

**User-reachable control**: N/A (CI and an iOS resource file; no user-visible change).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: this is the iOS leg of the shared integration tests that run locally on
Windows. Android integration tests in CI are not in scope (recorded). The privacy manifest is iOS-only by platform
(Apple requirement); Android's equivalent is the Play Data safety form (GP-10), Windows has none: a declared exception.

**Dependencies / blockers**: None (no Apple approval needed for an unsigned Simulator build).

**Non-functional requirements**:
- Security: no secret is added; Google client IDs stay empty in the Simulator build (as the unsigned build does).
- Cost: the repository is public; whether `macos-26` minutes are free for public repositories is UNVERIFIED (read GitHub's
  billing page at card time and record it).

**Acceptance criteria**:
- AC-1: a `workflow_dispatch` run of `ios-simulator` is green, with the run id recorded, and at least
  `app_boot_smoke_test.dart` ran and passed on the Simulator.
- AC-2: R-2's table lists all nine files with ran / did not run and the reason.
- AC-3: the screenshot artifact holds the R-3 screens for both device sizes.
- AC-4: the built `.app` contains `PrivacyInfo.xcprivacy` (a job step lists it), and the file's entries each cite the
  Apple reason code from Apple's page.
- AC-5: a deliberately failing test makes the job red (shown once on a scratch branch or by a mutation, then reverted).

**Tests to write**:
- T-1 (AC-1, AC-5) -- TEST-INTEGRATION: the existing integration tests on the Simulator; the AC-5 failing-path proof.
- T-2 (AC-4) -- a job step that fails if the manifest is missing from the bundle.

**Definition of Done**: default task-level DoD PLUS AC-1's run id and the artifact link in this card.

**Model**: Sonnet -- *why not the cheaper tier*: a new CI job on a platform this machine cannot run, Xcode project
membership and Apple's privacy rules; each try is a 10-15 minute CI round.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent, as assigned (2026-11-06 08:54 to about 17:30, across CI runs 1-7); the main session committed, dispatched runs 7 and 8 and made the run 8 gate change. CI run 8 (42315379298, commit 3ff3f581) GREEN: `ios-simulator` 8 files, 46 tests passed, 0 failed (sprint62_surfaces excluded, F348), privacy manifest in the built app; `ios-simulator-screens` success in 45 min (limit raised 75 -> 100 after run 7 was cancelled at 75 min 39 s). AC-5 proven by a red run (aee05994). The two files excluded in runs 1-6 failed because the iOS soft keyboard stayed open (run 6 probe); fixed by `dismissKeyboard` in the tests, no app change.
**Step-types**: CI `[no-history]`, TEST-INTEGRATION, DOCS. **Est-Effort**: 120-210m.

_**Risk & rollback**_: a Simulator job that is slow or flaky costs CI time; it runs on the iOS paths and by hand only, and
rollback is deleting the job.

## Phase 5 evidence

- **5.2 tests and analyze**: 2026-11-06. `flutter analyze`: No issues found. `flutter test --concurrency=4`: 3,619 passed, 15 skipped, 3 failed; all three are the known Task Scheduler 30 s timeouts (`windows_task_scheduler_service_test` x2, `powershell_script_generator_test` x1), code and tests unchanged since b00669e4, `Get-ScheduledTask` for a missing task timed at 7.1 s in-process; tracked as F349 (a4e7323d). The first run at the default concurrency also had 2 F302 timing failures; they pass alone and at `--concurrency=4` (TESTING_STRATEGY.md:31).
- **5.1.2 F-PRECHECK**: ran 2026-11-06 16:30-16:44 (Sonnet sub-agent) over `git diff origin/develop...HEAD` in Dart, Python, YAML and PowerShell; 7 classes; 14 findings, 0 HIGH. Fixed: F7-1 CHANGELOG F342 claim narrowed, F7-2/F3-1 default-closer test proves the row and its comment names the real call, F6-4 failed close writes a diagnostic line, F7-3 short-viewport tests for ErrorDisplay and the Settings placeholder, indentation (36b724ac; 4 mutants KILLED); F6-1/F6-2/F6-3 hook checks that could not run now print a systemMessage notice (e7960261; 6 mutants KILLED; rendering of systemMessage on Stop/PreToolUse unverified). Need-not-know with reason: F6-5 (rethrow caught by F6-4), F6-6 (ios.yml fails closed). Open: F1-1 four sibling empty states (4 code files: asked at Manual Validation, Question A); F6-7 the two iOS-excluded files (F345 run 6 probe, in progress). Classes 2, 4, 5 clean. 5.1.6 Android runtime launch gate: N/A -- no Android config file touched.
- **Android JVM unit tests**: N/A -- the sprint diff touches no file under `mobile-app/android/app/src` (the F280 Kotlin change was reverted uncommitted).
- **5.1.5 WinWright sweep**: 2026-11-06 19:51-20:09, sweep-head: 24ad4e04 (newer than the last lib/ui commit 36b724ac), DEV build from `build-windows.ps1` (exit 0, 19:46-19:51), workstation unlocked, 3 scripts all PASS: test_f124_rule_labels 29/29 (404 s, in the sweep this time), test_f320_no_rule_review 13/13 (196 s), test_s75_new_controls 27/27 (387 s). Tray icon PASS; DB drift none. Earlier sweep, superseded by the 36b724ac lib/ui change: 2026-11-06 15:24-15:34, sweep-head: 33d452fc (newer than the last lib/ui commit c9130577), DEV build from `build-windows.ps1` (exit 0), workstation unlocked, 3 scripts: test_f320_no_rule_review PASS, test_s75_new_controls PASS, test_f124_rule_labels FAIL twice at step 2 "No main window found" (step 1 passed), then PASS 29/29 run alone at 15:35-15:41 (318 s; Sprint 83 recorded 16-29 s). Cause of the in-sweep failure unknown; a `ww_list_windows` capture at the failing step would settle it. Tray icon PASS; DB drift none.
- **5.1.9 MV rehearsal**: 2026-11-06, 6 steps plus 1 carry-in, each with its own "Rehearsed" note in the Manual Validation section. 3 rehearsed on Harold's build inputs: MV-1 (DEV database copy, `f324_repair_flow_test` and `f324_background_off_test`, 12 pass), MV-2 (`f306_suggestion_storage_test`, `f306_review_screen_suggestion_test` and `email_scanner_no_rule_cursor_cap_test`, 18 pass; corrected the step to "Scan all emails"), MV-3 (`rule_test_screen_test` short-viewport group plus the new ErrorDisplay and Settings placeholder tests, 54 pass). 3 not rehearsable here, with reason: MV-4 and MV-5 need the Fold (0.24.0, MTP only), MV-6 is the live first-run evaluation with Harold. The F342 carry-in is rehearsed by `f342_worker_stop_closes_row_test` and `scan_history_narrow_test`. The rehearsal found the Scan History filter-chip overflow at 384 and 412 wide (fixed, 36b724ac) and the AppBar icon overflow below 384 wide (F351).

## Manual Validation (Phase 5.3) -- steps, rehearsed 2026-11-06

**Standing facts (Harold)**, carried forward from Sprint 83: Fold notification access for the app is ON and stays on. A
phone screenshot that shows a version (for example "Version 0.24.0") is the evidence the Play update installed; do not
ask again. The iCloud DEV account's per-account background scan is on, every 5 minutes.

**Builds**: Windows DEV 0.24.1+22 from `build-windows.ps1` (exit 0, 2026-11-06 15:20). Android emulator DEV 0.24.1+22
from `build-with-secrets.ps1 -BuildType debug -InstallToEmulator` (exit 0, 2026-11-06 16:30). The Fold has the 0.24.0
closed-test build; 0.24.1 reaches it only after the Play release, so 0.24.1-only phone checks are listed as carry-ins.

**Manual Validation decisions (Harold, 2026-11-07 13:30)**:
- Question A (5.1.2 F1-1, four sibling empty states that can overflow on a short screen) = 3: backlog all four, no
  change this sprint. Card F353 in the master plan.
- F350 review Q2 = highest priority: F350 is Priority 10 in the master plan. F350 Q1 (scope, part 6) is re-asked
  with the part 6 text; the first re-asks named "part 6" without saying what it was.
- New request: a default email account (card F352, next sprint); placement and startup questions asked.

**Manual Validation results, round 2 (Harold, 2026-11-07)**:
- MV-1: not complete yet (Harold). The DEV database still shows iCloud `gmail_sign_in_required = true` (read before the MV-6 swap; time not recorded).
- MV-2: N/A, precondition gone. Harold: "no older no rule rows exist". The suggestion refresh stays proven by
  `f306_suggestion_storage_test` and `f306_review_screen_suggestion_test` (rehearsal, 10 pass).
- MV-3: PASS ("working as expected").
- MV-4: PASS ("Working as expected"); Task 1 R-2 (0.24.0 channel check) done.
- MV-5: open, carried again with MV-3c: "Don't currently have any yellow no rule items".
- MV-6: Harold "REady"; live first-run evaluation started. Pre-flight: an empty DEV folder would be seeded from
  PRODUCTION (`dev_environment_seeder.dart:43-62`) and from the January `com.example` folder
  (`app_identity_migration.dart:59-80`), so the clean folder holds only the `.dev_seeded` and `.migration_complete`
  markers (a Store customer has neither source folder, so both steps do nothing for them too). No scheduled task runs
  the app; Credential Manager has no app entries, so the plugin read-through cannot add old tokens.
- MV-6 Windows attempt 1 (2026-11-07 14:14-14:21): DEV closed, 286 files hashed, folder renamed to a backup, clean
  folder with the two markers, DEV launched. It opened on Review No Rule Items, not Account Selection, so saved
  accounts were still found. Cause: the DEV exe version resource is Company `MyEmailSpamFilter`, Product
  `MyEmailSpamFilter`, and `flutter_secure_storage_windows` 4.1.0 keeps `flutter_secure_storage.dat` in
  `getApplicationSupportDirectory()` itself (`flutter_secure_storage_windows_ffi.dart:234,253`); the `_Dev` suffix is
  applied only by `AppPaths`. So DEV credentials live in `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter\`, the
  production-named folder (card F354). Not a clean first run; stopped, and restored: 286 of 286 hashes match;
  shared `.dat` unchanged (last written 2026-10-31 11:48). Evidence folder kept:
  `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev_mv6firstrun_20261107_1421`. How to continue is asked (MV-6 Q).

**Manual Validation decisions, round 2 (Harold, 2026-11-07, answered after the 18:39 message)**: "q1. a q2. a q3 a q4. b
q5. a q6. a and update the architecture documents as needed with this decision".
- q1 = a (MV-6): the first-run screens are reviewed on a clean Android emulator; Windows gets only its own checks with
  the accounts present (window size and DPI, resize to 800 x 600, Ctrl+R / F5, browser Gmail sign-in). Production
  data is not touched.
- q2 = a: F354 is Priority 14, next sprint.
- q3 = a: F350 keeps part 6.
- q4 = b (F352 D1): the default is set or removed only on Select Account; Settings > Account shows a label.
- q5 = a (F352 D2): same start screen, with the default account selected at startup.
- q6 = a (F352 D3): the F135 decision changes for the default only; the session selection stays unpersisted.
  Recorded as ADR-0052 (Accepted) and in `docs/ARCHITECTURE.md` "SelectedAccountProvider". Code changes are F352.
- MV-6 Android leg (2026-11-07 19:06-19:21, emulator `pixel34_updated`, Android 14, 2 GB RAM). The emulator DEV app
  (built 11/06 12:57, before 36b724ac) was uninstalled; a fresh DEV debug 0.24.1 was built and installed at 19:06
  (first build failed: the sqlite3 hook could not rename its downloaded `.tmp` file, cause unknown; the download
  folder under `.dart_tool` was deleted and the second build passed). Checks from `F325_FIRST_RUN_EVALUATION_S83.md`
  "What the live run checks first":
  - Clean start: Select Account, "No Accounts Yet", Add Account and "Try Demo Mode instead"; no permission prompt.
  - Check 4: the notification permission is asked when Settings > Background > Enable Background Scanning is turned
    on. After "Don't allow", scanning stays on and the screen does not say that notifications are off.
  - Check 1: the Results title says "Read-Only"; the default filter is "No rule: 12"; the dropdown says
    "Deleted (not processed): 26 / These emails matched a delete rule." and does not say they were not deleted
    because the mode is Read-Only.
  - Demo scan Results say "Live Scan": `results_display_screen.dart:1400-1401` sets that label for any live result,
    demo included.
  - Check 5: the demo Manual Scan shows both "Start Live Scan" and "Start Demo Scan (Testing)".
  - Check 3: the AOL setup dialog steps are low-contrast grey, the address is plain text (not a link), and step 2
    and 4 say "click" on a phone.
  - Check 7 and 2: the First-Use Walkthrough lists Outlook.com and ProtonMail, says tap "Start Scan" (the buttons
    are "Start Live Scan" and "Start Demo Scan (Testing)") and the "+" button (the empty screen has "Add
    Account"). Help > Account Setup recommends a Gmail App Password (IMAP); the provider list shows Gmail by
    OAuth.
  - Check 10: Help shows the GitHub issues address as plain text (`help_screen.dart:369`), not a link; no other
    feedback path seen. (Corrected 19:26: a first search used a file filter that matched nothing and reported 0.)
  - Layout at 1080 x 2340: titles cut to "Man..." and "Setti..."; the Settings tab reads "Backgrou / nd"; "Back to
    Accounts" wraps; Settings > General says content history is kept "in a file on this computer".
  - Background on the Demo account: the worker ran at once and logged "Account d***@example.com not found among
    saved accounts; nothing to scan".
  - ANR: "MyEmailSpamFilter [DEV] isn't responding" at 19:13 (logcat: Input dispatching timed out, 5000 ms), while
    the background worker started. Main thread in `BackgroundWorker.executeBackgroundTask` (workmanager,
    `BackgroundWorker.kt:439`) -> `FlutterJNI.dispatchPlatformMessage`, waiting in ART. The dialog came back at
    19:18 and 19:20 with no second ANR line in logcat. Emulator: 2 GB RAM, 1.24 GB of 1.5 GB swap in use. Cause
    unknown; emulator memory pressure on a debug build is possible but not proven. Settles by: the same step on
    a release build (the Fold) or an emulator with more RAM. Evidence: scratchpad `mv6_android\` (21 screenshots,
    three logcat files, `bugreport_anr.zip`).
  - Not checked on Android: check 6 (relaunch after adding a real account) and the Gmail native sign-in (check 2);
    both need a real account. Check 9 is the Fold.
- MV-6 Windows (2026-11-07, DEV window with Harold's accounts): the window is 1600 x 900 at 125% = 1280 x 720; at
  800 x 600 the Results screen fits, with the title cut ("Results - ..."); F5 on Results showed no visible
  change (not settled). The window was put back to 1280 x 720.

**Manual Validation results, round 3 (Harold, 2026-11-07)**:
- MV-1: PASS. Harold: "mv-1 all steps completed and working as expected". The DEV database no longer has the
  iCloud `gmail_sign_in_required` row.
- MV-6: moved to the next sprint. Harold: "mv-6 move to next sprint". The remaining work is on card F341 in the
  master plan; the Android and partial Windows results above stay as its evidence.
- Harold, 2026-11-07 (verbatim): "q1 a q2. can probably be reconciled with a reboot, however, there should be
  sufficient virtual memory cache. push it to next sprint and I will reboot before then."
  - q1 = a: Manual Validation is COMPLETE. MV-5 becomes a Phase 8 carry-in (below). Phase 7 starts: 7.7.1 final code
    reviews on the draft PR #548 and the retrospective prompt, in one turn.
  - q2: the emulator ANR goes to the next sprint as card F355; Harold reboots before then.

- **MV-1 (Windows DEV, then the Fold): re-enter the iCloud app-specific password (F342 group 1).** Precondition: the
  iCloud account is flagged; the Windows DEV database shows `gmail_sign_in_required = true` for the iCloud account
  only (AOL, Gmail, Yahoo not flagged). Steps: create a new app-specific password at account.apple.com > Sign-In and
  Security > App-Specific Passwords. In the app, open the account list (Select Account). The iCloud row reads
  "iCloud Mail rejected the sign-in. Enter your password again." with a "Sign In Again" button. Press it; the address
  is already filled in and no "Account already added" question appears; paste the new password and save. Expected:
  the iCloud row no longer shows the message; within 5 minutes Scan History shows a new iCloud Background row that is
  not an error. Repeat on the Fold (0.24.0 has the same Sign In Again flow).
  Rehearsed: 2026-11-06, flag read from a copy of the DEV database (`account_settings`, iCloud only); row text from
  `account_selection_screen.dart:338-341`; the repair flow by `f324_repair_flow_test` and `f324_background_off_test`
  (12 tests pass: address filled, no duplicate question, saving clears the flag). NOT REHEARSED: the real iCloud
  sign-in (Harold's Apple account).
- **MV-2 (Windows Production, Q3 = 3 note): older No Rule rows get their "Suggested" mark after a full rescan.**
  Precondition: in the production app, Review No Rule Items shows `news_40693@citorisc.net` with no "Suggested" mark
  (Harold's screenshot, 2026-11-06). Steps: Settings > the account > Scan Range: tick "Scan all emails" ("No date
  filter - scans entire mailbox"), run a Manual Scan of the folder that holds that message, then open Review No Rule
  Items. Expected: the `news_` rows still in the folder show "Suggested" on Block Entire Domain. A row for a message
  no longer in the folder keeps no mark (the scan cannot see it again). Then set the Scan Range back to its old value.
  Why "Scan all emails": the No Rule cursor is clamped to the scan range (S38-CI-4), so a short range does not re-read
  mail from 2026-09-24; "Scan all emails" bypasses the cursor (`email_scanner.dart:1995-2004`).
  Rehearsed: 2026-11-06, `f306_suggestion_storage_test` "a re-seen row refreshes the suggestion, and null clears it"
  and `f306_review_screen_suggestion_test` (10 tests pass); the clamp by `email_scanner_no_rule_cursor_cap_test`
  (8 pass). NOT REHEARSED: a live IMAP scan of the production account.
- **MV-3 (Windows DEV): Rule Test messages in a short window (#557).** Steps: Settings > Manage Rules > the "Test a
  pattern against sample emails" icon. Drag the window's bottom edge up to its minimum (800 x 600 pixels,
  `flutter_window.cpp:71-72`). Expected: "Enter a pattern and press Test..." shows with no yellow-and-black stripes;
  type `zzqqxx-no-such-sender` and press Test: "No matches found in N sample emails." shows the same way and scrolls.
  Rehearsed: 2026-11-06, `rule_test_screen_test` group "short phone viewport (no overflow)" (390x560 and 320x480,
  prompt and no-match states) and the new ErrorDisplay and Settings placeholder short-viewport tests (54 tests pass in
  the changed files). The 800 x 600 Windows window was not looked at.
- **MV-4 (Fold, Task 1 R-2): 0.24.0 notification channels.** Steps: Android Settings > Apps > MyEmailSpamFilter >
  Notifications. Expected: two channels, "Every Completed Scan" and "One or more No Rule Items", and no
  `background_scan_channel`. Screenshot it. Rehearsed: NOT REHEARSED on a device (the emulator has 0.24.1; the channel
  set is the same code); evidence of 0.24.0 on the Fold: the 2026-11-06 Fold screenshot reading "Version 0.24.0".
- **MV-5 (Fold, Task 1 R-1, MV-3c): a YELLOW No Rule item's pop-up on the cover screen.** Only when a YELLOW No Rule
  item appears. Expected: one rule is marked "Suggested"; Block Subject, the regex note and the Skip row fit with no
  clipping. Screenshot it. Rehearsed: carried from Sprint 83 (Windows proven in Sprint 83 MV); NOT REHEARSED on the
  cover screen width.
- **MV-6 (Task 4, F341, with Harold): live first-run evaluation.** Windows: a backup of the DEV data folder, a clean
  first run, then the backup restored. Android: the emulator (no phone data touched). iOS: the ten Simulator screens
  from CI run 5 (iPhone and iPad: empty state, add account, AOL form, Settings, Help). Observations already found on
  the iPad screens: Settings > General shows "Export folder: Documents/MyEmailSpamFilter_Dev (default)" with the text
  "in a file on this computer" (desktop wording on a tablet), and the iPad layout is the phone layout stretched to
  full width. Rehearsed: the iOS screens are CI artifacts (run 42287768277); the Windows and emulator passes are the
  live evaluation itself.

**Carry-ins after 0.24.1 reaches the Fold (Phase 8)**
- MV-5 (Harold q1 = a, 2026-11-07): when a YELLOW No Rule item appears on the Fold, open its pop-up on the cover
  screen. Expected: one rule is marked "Suggested"; Block Subject, the regex note and the Skip row fit with no
  clipping. Screenshot it.
- F342 on the phone: after Android stops a background scan, Scan History shows a Background row "Not finished" with
  "The phone stopped this background scan before it finished. The next scan will try again." in grey, and the
  diagnostic log has "closed N in-progress scan row(s) as interrupted". Rehearsed: `f342_worker_stop_closes_row_test`
  and `scan_history_narrow_test` (412 and 384 wide). Not rehearsed on a device.
  Added 2026-11-07 (7.7.1): the row is now closed BEFORE the diagnostic-log write, and the reason for an app cancel
  (AndroidX raw stop reason 1) is "Background scanning was turned off while this scan ran." This check is the only
  evidence for the narrowed claim: watch whether the run WorkManager starts right after the stop now proceeds (a scan
  start within seconds of the "closed N" line). Until then CHANGELOG and ARCHITECTURE claim only the busy retry.

## Phase 7.7.1 final code reviews

- **7.7.1 final code reviews**: Copilot (requested by hand 2026-11-07 19:36, state COMMENTED, 2 inline: 1 HIGH, 1 LOW; both fixed, replied and resolved); pr-review-toolkit code-reviewer (0 C / 0 H / 3 M / 5 L; files given 73, read 66, diff-only for 6 docs, 7 grep-sampled) and silent-failure-hunter (0 C / 0 H / 6 M / 13 L; files given 73, read 67, 2 partial, 4 process docs not read), both started 19:36 in the background on the DRAFT PR #548, `git diff origin/develop...HEAD`, `0*` and `archive/` excluded. Fix commits: 0e80c9fb, a71025e0, 9eb90397, d4178c5b, 98477e31. Five pairs were the same issue (CR M1 = SF M2, CR M2 = SF M3, CR L1 in SF M5, CR L3 = SF L10, CR L5 = SF M6).
- Disposition, by finding (fixed without asking unless marked QUESTION):
  - Copilot H (require-sprint-cards counted any non-empty dict): fixed 0e80c9fb, mutation KILLED.
  - Copilot L (iOS screens test dropped its skip reason): fixed 9eb90397 (reason on `group`).
  - CR M1 / SF M2 (F342 closes the row after the log write) and CR M1 claims: fixed d4178c5b; claims narrowed in code,
    CHANGELOG and ARCHITECTURE; the Doze-alarm recent-scan behavior is QUESTION q2.
  - SF M1 (F342 reason text for an app cancel): fixed d4178c5b. The reviewer's enum mapping was wrong; the fix keys on
    the AndroidX raw value 1 (plugin `stop_reason.dart:21` numbers it 3).
  - CR M2 / SF M3 (0.24.1 release notes claimed reverted F280 and Windows background fixes): fixed a71025e0.
  - CR M3 (CLAUDE.md and `.codex/hooks.json` pointed at unregistered `.ps1` hooks): fixed a71025e0.
  - SF M4, M5, L4, L5, L6, L7, L8, L9, CR L1 (hook checks skipped silently): fixed 98477e31, 18 mutations KILLED.
  - SF M6 / CR L5 (stash guard `list && pop` and `git -C` bypasses): fixed 98477e31.
  - CR L2 (six more `Center > Column` empty states): added to F353 (a71025e0).
  - CR L3 / SF L10 (iOS docs and header described one job and a fallback that does not exist): fixed a71025e0, 9eb90397.
  - CR L4 (F342 wiring test was text-only): replaced by two behavior tests, d4178c5b, mutations KILLED.
  - SF L1 (closed count lost on a partial failure): logged before the rethrow, d4178c5b (logcat only).
  - SF L2 (completion or error writes can overwrite `interrupted`): QUESTION q1.
  - SF L3 (registration before the `try`): moved inside, d4178c5b (verified by reading; no seam throws the constructor).
  - SF L11 (Rule Test short-viewport tests unproven): settled 2026-11-07; removing the scroll view from either
    state is KILLED by `rule_test_screen_test.dart` (scripts/mutation-test.ps1, 2 of 2).
  - SF L12 (`previous_sprint` numbers became strings): restored to integers, a71025e0; no code reader found.
  - SF L13 (hook notices reach the user only if `systemMessage` is rendered): QUESTION q3.
  - New from the hook fix: the closeout worst case is 26 s against the 20 s hook timeout (stated in the docstrings
    now): QUESTION q4.
