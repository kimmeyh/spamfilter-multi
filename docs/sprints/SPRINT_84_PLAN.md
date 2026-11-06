# Sprint 84 Plan

**Status**: DRAFT, waiting for Phase 3.7 approval. Scope selected by Harold at Phase 8.4 pass 2 (2026-11-06).
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
**Executed-by** (filled at completion):
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
**Executed-by** (filled at completion):
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
**Executed-by** (filled at completion):
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
**Executed-by** (filled at completion):
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
**Executed-by** (filled at completion):
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
**Executed-by** (filled at completion):
**Step-types**: CI `[no-history]`, TEST-INTEGRATION, DOCS. **Est-Effort**: 120-210m.

_**Risk & rollback**_: a Simulator job that is slow or flaky costs CI time; it runs on the iOS paths and by hand only, and
rollback is deleting the job.
