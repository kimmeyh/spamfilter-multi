# Sprint 85 Plan

**Status**: APPROVED by Harold 2026-11-10 (Phase 3.7; see "Approval record" below). Scope selected at Phase 8.4
pass 2 (2026-11-10).
**Branch**: `feature/20261108_Sprint_85` (cut from the Sprint 84 branch, Phase 6.6) | **PR**: #559 (draft until 7.7.5)
**Cards**: #560-#575 (Task 0-15)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads on 2026-11-10;
file:line evidence is in each card.

## Objective

Decide how the project tests, from evidence, so tests stay effective and get faster (F350). Add the default email
account (F352). Separate Windows DEV credentials from production (F354). Settle the Android "isn't responding" report
(F355) and the two `interrupted`-row questions (F357). Finish the live first-run evaluation (F341). Remove the "Create
rule" page (F307). Convert the remaining repo tooling to Python and retire the PowerShell copies (F329-F335).

**Scope (Harold, 2026-11-10, verbatim)**: *"Sprint 85 Scope should include the below items. Please complete sprint
planning (/docs/sprint_planning.md) for the below items and present for approval."* The items: F350, F352, F354, F355,
F357, F341, F307, F329, F330, F331, F332, F333, F334, F335. Kept from the Sprint 85 stub: the F342 Fold check after
0.24.1 (it decides F357) and MV-3c (Task 1).

**iOS (Harold, 2026-11-10: "2 b")**: Apple has not approved enrollment `R6QG2A9SHS`. F67a (#509), F304 (#510) and F67b
(#523) are NOT in this scope and stay open. If Apple approves during the sprint, adding them is a scope change for
Harold to approve then.

**Parity (Harold, 2026-11-10; the pasted text was cut off after "fron", read as the Sprint 84 wording)**: *"everything
needs to take into account the Windows App, Android app and the iPhone app with the ADR stating that everything should
be functionally and UI the same unless it cannot be - and where it cannot be it should be implemented as a platform
exception for what is needed -- this applies to all backend code, fron[tend code, data, architecture, development,
security, testing, deployment]."* Every card has a **Parity (ADR-0042 / ADR-0049 / ADR-0050)** line naming the Windows,
Android and iOS paths: it claims parity and names the OS behavior assumed identical, or declares the exception. iOS
answers come from `PlatformCapabilities` (ADR-0049) and ADR-0050; no new bare `Platform.isX` checks (F294 policy
test). The iPhone cannot run a build this sprint (Apple), so iOS paths are proven by tests, the unsigned `ios.yml`
build and the iOS Simulator job (F345). Tooling cards (F329-F335) are development-machine code, not app code: their
parity line names the machines they run on.

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control, then the instance fix.

## Phase 2 and 3 checks (2026-11-10)

- Top-tier model: Opus 5.5. DONE.
- 2.2 / 3.1 Sprint number: 85 (Sprint 84 merged: PR #548 -> develop `cc251012`; develop -> main PR #558 `962a1b25`,
  tag `v0.24.1`). DONE.
- 2.3 Sprint 84 cards: #549-#557 closed by the merge; #509, #510, #523 open as intended (Apple). DONE (53670f58).
- 2.4 Working tree clean; all work pushed (381f766c). DONE.
- 2.6 Dependency check (`dart pub outdated --no-dev-dependencies`, 2026-11-10): discontinued `js` 0.6.7 (transitive,
  unchanged since Sprint 83); 10 of 110 packages resolve below their latest version, 1 of them direct. No security
  advisory reported by this check. No action this sprint (a dependency change needs Harold's approval); recorded.
- Phase 8 cycle: 8.1 main merge done (#558); 8.2 pass 1 done (53670f58); 8.3 0.24.1 MSIX and AAB built and verified
  (ca0a886f) and submitted to both stores (Harold, 2026-11-10, 381f766c); 8.4 pass 2 scope selected (above). DONE.
- 3.2.1 `docs/sprints/SPRINT_84_SUMMARY.md` exists; the Past Sprint Summary row for 84 exists. DONE.
- 3.2.2 this file (replaces the Sprint 85 stub; the stub's carry-ins are kept below). DONE (draft).
- 3.3 Branch `feature/20261108_Sprint_85` exists and is pushed. DONE.
- 3.3.1 Draft PR: created with this plan (number recorded in `.claude/sprint_status.json`).
- 3.4 / 3.5 Cards: created at 3.7.0, the first action after approval (one per task).
- 3.6.1 Architecture Impact Check: below.

## Tasks, order, models and estimates

Estimates are minutes. Cards keep the backlog estimates Harold selected; re-estimates cite their reason.
`[no-history]` marks a step-type with no samples in `CODING_VELOCITY.md`.

- **Task 0 -- Version bump 0.25.0+23** (3.7.0b). MINOR: F352 adds a user-facing capability (`feat`). Main session.
  10-15m.
- **Task 1 -- Carry-ins**: the F342 Fold check after 0.24.1 (decides F357) and MV-3c. Main session. 15-30m plus
  Harold's phone time; each waits on the Fold (0.24.1 installed; a YELLOW No Rule item).
- **Task 2 -- F350**: risk-based test analysis. Opus (main session) for the tiers and recommendations, with a Sonnet
  sub-agent for the inventory script and timings. 150-210m.
- **Task 3 -- F352**: default email account. Sonnet. 120-240m.
- **Task 4 -- F354**: Windows DEV credentials in the production-named folder. Opus. 60-120m (R-1 audit, then Q2).
- **Task 5 -- F355**: Android "isn't responding" on enabling background scans. Opus (main session; emulator and
  Fold). 30-90m. After Harold's reboot.
- **Task 6 -- F357**: `interrupted` rows. Sonnet. 30-60m. After Task 1's F342 Fold check.
- **Task 7 -- F341**: live first-run evaluation, the remainder. Main session, interactive with Harold. 90-150m.
- **Task 8 -- F307**: remove the "Create rule" page. Haiku. 30-60m -> 45-75m (3.2.2.2: the Review No Rule Items
  caller moved to `no_rule_review_screen.dart:593-603`, and four test files plus a doc comment name the screen).
- **Task 9 -- F329**: Python batch H4 (hook test tooling) and retiring the PowerShell copies. Sonnet. 225-355m ->
  240-380m (3.2.2.2: `run-test-cases.ps1` is 189 lines, not 131; `test-hook.ps1` 203, not 150; and the five unregistered
  `.ps1` hook twins, 1,695 lines, are deleted here, as the Sprint 84 summary records).
- **Task 10 -- F330**: Python batch S1, repo helper scripts. Sonnet. 150-250m.
- **Task 11 -- F331**: Python batch S2, MCP set-up and test mail servers. Haiku. 90-150m.
- **Task 12 -- F332**: Python batch S3, phone log health and the battery arm script. Haiku. 90-150m.
- **Task 13 -- F333**: Python batch S4, mobile-app check and gate scripts. Sonnet. 180-300m.
- **Task 14 -- F334**: Python batch S5, test runners and test mail. Haiku. 150-250m.
- **Task 15 -- F335**: Python batch S6, Android build scripts. Sonnet. 180-300m.
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 150-250m.

**Total**: Tasks 0-15 about 1,630-2,770 minutes, plus the 150-250 allowance, plus Harold's phone and first-run time.
This is about 2.3 times Sprint 84's planned size (695-1,225m); eight of the sixteen tasks are tooling ports.

**When can Harold come back (first Manual Validation handoff)**: Task 7 F341 and Task 1 are interactive and run at
times Harold chooses. Task 5 F355 needs Harold's reboot first. For the code tasks, about 27-46 hours of work serially;
with the parallel blocks below, about 12-20 hours of wall clock.

**Order**:
1. 3.7.0 cards, 3.7.0b version bump (Task 0), 3.7.1 PR body.
2. Parallel block A (sub-agents, no shared files): Task 3 F352 (Dart UI and `SettingsStore`), Task 10 F330, Task 11
   F331, Task 12 F332 (each its own `scripts/` files). Task 2 F350 starts its inventory sub-agent here (read-only plus
   one new script and doc).
3. Parallel block B: Task 13 F333, Task 14 F334, Task 8 F307. Task 4 F354 R-1 audit (read-only) runs here, then Q2.
4. Task 15 F335 alone with respect to builds: it proves itself by building an AAB, so no Windows build runs at the same
   time (CLAUDE.md, shared `build/`). Task 4 F354's fix (a Windows DEV build) and Task 7 F341's Windows legs are
   serialized with it.
5. Task 9 F329 last among the tooling cards: it converts `run-test-cases`, `test-hook` and `mutation-test`, which the
   other cards use for their checks, and it retires the shims once every caller is updated.
6. Task 5 F355 after Harold's reboot; Task 1 when the Fold shows 0.24.1 (and, for MV-3c, a YELLOW item); Task 6 F357
   after Task 1's F342 check; Task 7 F341 with Harold.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b)): Tasks 3, 6, 8 and
9-15 are delegated to sub-agents on their assigned tier before Manual Validation, with the delegation checklist and the
"Progress and restart" block verbatim. Tasks 0, 1, 2 (its analysis), 4, 5 and 7 run in the main session. Anything run in
the main session executes on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand on the draft + pr-review-toolkit code-reviewer and
silent-failure-hunter, with the changed-file list), started with the retrospective prompt at Manual Validation
complete. The silent-failure-hunter prompt is scoped to the changed files and the classes this sprint touches.

**Cards**: created at Phase 3.7.0. One "Closes #N" per card in the PR body.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md` Standing Approval Inventory), so
they are not asked again: (a) Task 0 the version bump and the "Last uploaded to Play" move to 0.24.1 (versionCode 22);
(b) Task 9 changes under `.claude/hooks/` (the runner, the footer script, deleting the five unregistered `.ps1` twins
and the two shims once nothing calls them), with the hook suite green after each change; no `.claude/settings.json`
change is planned (all hooks are already registered as `.py`); (c) Tasks 10-15 deleting each converted `.ps1`/`.sh`
original in the same commit as its Python replacement (ADR-0051 `:111`), with every caller and doc updated; (d) Task 5
emulator `adb` commands on the emulator only; (e) Task 4 a read-only Process Monitor or log check of which credential
file the installed Store app opens; (f) Task 7 the DEV data folder backup and byte-for-byte restore around a clean
Windows run (after Task 4). Not covered, still asked: any dependency version change (Task 10 PyYAML, if needed), any edit
to `secrets.*.json`, Q2's F354 fix approach, and any move or copy of production credentials.

## Phase 3.2.2.1 branch-state verification (summary)

- **F350: open.** No `docs/research/F350_RISK_BASED_TESTING.md`. Counts today: 344 Dart test files, 10 integration
  test files, 6 WinWright scripts, 294 files under `.claude/hooks/test-cases/`, workflows `ci.yml` and `ios.yml`.
- **F352: open.** `SelectedAccountProvider` is still session-only by design
  (`selected_account_provider.dart:17-23`, "Deliberately NOT persisted"); 0 references to `default_account_id` in
  `lib/`. ADR-0052 exists (`docs/adr/0052-default-account-persisted.md`).
- **F354: open.** `flutter_secure_storage_windows` 4.1.0 (`pubspec.lock`) writes the fixed name
  `flutter_secure_storage.dat` into `getApplicationSupportDirectory()` and has no path option
  (`flutter_secure_storage_windows_ffi.dart:234`, `:252-258`). Eleven `getApplicationSupportDirectory()` calls in `lib/`
  (`main.dart:161`, `app_paths.dart:43,69`, `app_identity_migration.dart:33,34,45`,
  `background_scan_windows_worker.dart:42`, `dev_environment_seeder.dart:33`, `diagnostic_logger.dart:191`,
  `export_directories.dart:271`, `live_scan_logger.dart:44`).
- **F355: open.** Evidence is in the Sprint 84 session scratchpad `mv6_android\` (`bugreport_anr.zip` 6.6 MB, three
  logcat files, 21 screenshots); `anr_trace.txt` is empty. Harold reboots first.
- **F357: open.** The recent-scan check is `recentScanShouldSkip` / `checksRecentScan`
  (`android_background_scan_worker.dart:312`, `:328`, used at `:435-457`); the completion and error writes are at
  `scan_result_store.dart:419` and `:458`; F342 writes `interrupted` at `background_scan_core.dart:421-436`.
- **F341: open.** Remaining live checks 2, 6 and 9 and the iOS Simulator screens
  (`docs/research/F325_FIRST_RUN_EVALUATION_S83.md:102-111`); the clean Windows run needs F354.
- **F307: open.** `rule_quick_add_screen.dart` (846 lines); callers `no_rule_review_screen.dart:593-603` (moved from
  `:520`) and `email_detail_view.dart:551`; named in the `RuleConflictResolver` doc comment
  (`rule_conflict_resolver.dart:5,44`) and four test files (`f298_quick_add_test.dart`,
  `no_rule_review_heuristics_test.dart`, `rule_quick_add_screen_test.dart`, `subject_rule_keyword_test.dart:59`).
- **F329: open, larger.** `run-test-cases.ps1` 189 lines, `status-footer.ps1` 160, `test-hook.ps1` 203,
  `mutation-test.ps1` 167; shims `mutation-lock.ps1` 106 and `agent-work-status.ps1` 48 (its `.py` exists). Five
  unregistered `.ps1` hook twins remain beside their registered `.py` versions: `block-carry-forward-stash` 109,
  `require-sprint-cards` 174, `sprint-auto-advance` 756, `verify-closeout-complete` 515,
  `warn-commit-without-velocity` 141. `.claude/settings.json` registers only `.py` hooks.
- **F330-F335: open.** Every listed file exists, no Python version of any exists yet; line counts match the cards
  except where noted in the card. `send-test-emails.py` (308 lines) is already Python.

**Phase 3.2.2.2 (re-estimates)**: F307 30-60m -> 45-75m; F329 225-355m -> 240-380m (reasons above). No other card
changed.

## Phase 3.6.1 Architecture Impact Check

- **ADR-0052 (default account, Accepted 2026-11-07)**: Task 3 implements it. ARCHITECTURE.md's account-selection
  section gains the stored default in the same commit.
- **ADR-0035 (side-by-side DEV and prod data)**: Task 4 changes how DEV credentials are separated on Windows. The fix
  approach is Harold's decision (Q2); ADR-0035 gains the credential store in the same commit as the fix.
- **ADR-0042 / ADR-0049 (parity, PlatformCapabilities)**: Task 4 is a Windows exception (Android and iOS secure storage
  is per package). Task 5 and Task 6 touch the Android background worker, already a declared Android exception.
- **ADR-0051 (Python for deterministic tooling)**: Tasks 9-15 follow it; originals deleted in the same change
  (`0051:111`). ADR-0051's file table is updated as each batch lands.
- **Data model**: one new `SettingsStore` key, `default_account_id` (Task 3); no schema change.
- **Testing docs**: Task 2's approved recommendations update `docs/TESTING_STRATEGY.md`.
- No ADR conflicts found.

## Carried from the Sprint 84 close-out (stub content, kept)

- **0.24.1 store updates**: built, verified and submitted (see Phase 8 above). Open on the installed Store build: the
  Step 4.2 Gmail sign-in URL check.
- **Retro rules now in effect**: i3 (a port card has a "Port of existing code" line), i4 (a move/rename/retire card has
  an "Old name search" line), i5 (5.1.9 lists each new guard test with its mutation verdict), i6 (5.1.2 class 1 searches
  nested shapes with multiline grep). Tracked: i1 (class A text that promises more than ships), i7 (a wasted first-run
  attempt). i2 and q3 are steps in F329 (Task 9).
- **Standing facts (Harold)**: a phone screenshot that shows the app version proves the Play update installed
  (2026-11-04). Fold notification access for the app is ON and stays on. The iCloud DEV account's per-account
  background scan is on, every 5 minutes.

## Approval record (Phase 3.7, Harold, 2026-11-10)

Harold: *"q1. 1 q2. 2 q3. 1"* and *"Sprint plan approved as amended (with any comments I provided), proceed with
execution. All Sprint tasks and sub-tasks are approved."*

- Q-A: approved as amended.
- Q1 = 1: version 0.25.0+23.
- Q2 = 2: DEV gets its own product name in the Windows exe version resource; every DEV support-folder path moves to a
  DEV folder, including the credential file; `AppPaths` drops its own `_Dev` suffix on Windows; a one-time copy keeps
  DEV's accounts; production files are never moved or deleted. Task 4 R-1 still runs first, as evidence for the
  change and its callers.
- Q3 = 1: `build-with-secrets.ps1` is deleted (ADR-0051); CLAUDE.md and every release doc move to the Python command.

## Questions for approval (Phase 3.7)

**Q-A. Approve this plan?**
1. Approved as written.
2. Approved with changes (say which).

**Q1. Version: is 0.25.0+23 right?** F352 adds a user-facing capability (a default account), so the workflow rule
(3.7.0b) is a MINOR bump. "Last uploaded to Play" moves to 0.24.1 (versionCode 22) in the same commit.
1. 0.25.0+23 (recommended: the rule, and testers can tell the build from 0.24.1).
2. 0.24.2+23 (PATCH).

**Q2. F354: how is the DEV credential store separated?** Today a Windows DEV run reads and writes
`%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter\flutter_secure_storage.dat`, the production-named folder; the plugin has
no path option (`flutter_secure_storage_windows_ffi.dart:234,252-258`). Not yet known: whether the installed Store
(MSIX) app reads the same file. If it does, deleting an account in DEV removes its production credentials. This is an
architecture decision (ADR-0035).
1. Audit first (R-1: which file the Store app opens, and what each of the 11 `getApplicationSupportDirectory()`
   callers would do), then ask me with the evidence and a recommended fix before any code (recommended: the right fix
   depends on whether MSIX redirects the folder).
2. Pre-approve "DEV gets its own product name in the Windows exe version resource": every support-folder path for DEV
   moves to a DEV folder, including the credential file; `AppPaths` drops its own `_Dev` suffix on Windows; a one-time
   copy keeps DEV's accounts. Largest change; separates everything.
3. Pre-approve "DEV keeps the same file but uses a `dev.` key prefix": smallest change; DEV and prod entries never
   collide, but they still share one file, so a corrupt-file delete by the plugin (`:341`) would remove both.
4. Backlog card only; this sprint does not change it (then the clean Windows run in F341 stays blocked).

**Q3. F335: after the Android build script moves to Python, what do you type?** ADR-0051 deletes the `.ps1` original in
the same change (`0051:111`), so `.\build-with-secrets.ps1 -BuildType release -Output aab` becomes
`python scripts\build_with_secrets.py --build-type release --output aab` (or similar). CLAUDE.md, the release docs and
your own habits use the old command.
1. Delete the `.ps1` as ADR-0051 says; update CLAUDE.md, `GOOGLE_PLAY_RELEASE_PROCESS.md` and every doc (recommended
   for consistency with the other batches).
2. Keep a 3-line `.ps1` that only calls the Python script with the same parameters, so the old command still works
   (an ADR-0051 exception, recorded there).

---

# Cards

## Task 0 -- Version bump 0.25.0+23 (3.7.0b)

**Value**: This lets a tester tell the Sprint 85 build from the 0.24.1 store builds.

**Requirements**:
- R-1: `mobile-app/pubspec.yaml` `version: 0.25.0+23` and `msix_config.msix_version: 0.25.0.0` (Q1); every version
  literal the gate checks follows.
- R-2: PROVISIONAL `docs/store-assets/RELEASE_NOTES_0.25.0_windows.md` and `_play.md` (shape: the 0.24.1 files; range:
  after 0.24.1).
- R-3: `docs/STORE_VERSION_STATUS.md` "Last uploaded to Play (any track)" moves to 0.24.1 (versionCode 22) in the same
  commit (Harold reported the upload 2026-11-10); the Dev worktree row reads 0.25.0+23.

**Affected components / files**: `mobile-app/pubspec.yaml`; version literals found by `version_consistency_test`;
`docs/store-assets/RELEASE_NOTES_0.25.0_*.md`; `docs/STORE_VERSION_STATUS.md`; `CHANGELOG.md`.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: one version for all platforms (ADR-0043); the iOS build reads the same
pubspec.

**Dependencies / blockers**: Q1.

**Acceptance criteria**:
- AC-1: `flutter test test/policy/version_consistency_test.dart test/policy/dev_version_ahead_test.dart
  test/policy/release_notes_test.dart` passes.

**Tests to write**: none new; T-1 (AC-1) the three existing policy gates.

**Definition of Done**: default task-level DoD.

**Model**: main session (runs with 3.7.0 in the approval turn; a sub-agent would cost more than the task). Shape: Haiku.
**Delegation checklist included in the sub-agent prompt** (when delegated): N/A (main session).
**Executed-by** (filled at completion):
**Step-types**: DOCS, DATA. **Est-Effort**: 10-15m.

## Task 1 -- Carry-ins: the F342 Fold check after 0.24.1, and MV-3c

**Value**: This proves the F342 fix on a real phone and supplies the evidence F357 needs; it closes the last Sprint 83
phone check.

**Requirements**:
- R-1 (F342 Fold check): once the Fold shows 0.24.1 (Settings top bar "Version 0.24.1"), pull the diagnostic log over
  MTP (`scripts/pull-phone-screenshots.ps1 -Sprint 85`; read its `param()` block first). Find each worker stop since
  the update. Check: (a) the scan row for a stopped scan is closed, and Scan History shows "The phone stopped this
  background scan before it finished. The next scan will try again." (or the app-cancel text); (b) the next background
  scan starts, and whether a Doze-alarm restart was skipped by the recent-scan check (F357 q2); (c) any completion that
  replaced `interrupted` within milliseconds (F357 q1).
- R-2 (MV-3c, Fold, YELLOW item): when a YELLOW No Rule item appears on the Fold, open its pop-up. Expected: one rule is
  marked "Suggested", and Block Subject, the regex note and the Skip row fit the cover screen with no clipping.
- R-3: rehearse each step before handover (5.1.9), from the code and tests that produce the screen.

**Affected components / files**: none (validation); results go in this plan's Manual Validation section and feed
Task 6.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: R-1 checks the Android worker-stop path (declared Android exception;
Windows and iOS have no WorkManager stop event). R-2 is the shared pop-up at the narrow cover-screen width.

**Dependencies / blockers**: 0.24.1 reaching the Fold from Play (R-1); a YELLOW No Rule item on the Fold (R-2).

**Acceptance criteria**:
- AC-1: R-1's three checks each have a log line or a Fold screenshot and a recorded result.
- AC-2: R-2 has a Fold screenshot and a recorded result, or is carried again with the reason.

**Tests to write**: none (manual validation).

**Definition of Done**: AC-1 and AC-2 only (no code).

**Model**: main session (interactive with Harold) -- N/A.
**Executed-by** (filled at completion):
**Step-types**: MANUAL, DIAG. **Est-Effort**: 15-30m plus Harold's phone time.

## Task 2 -- F350: Risk-based test analysis: effective, and as efficient and quick as reasonably possible (Priority 10)

**Value**: This lets each change run the tests that matter for its risk, so defects are still caught and verification
takes minutes instead of a full run every time.

**Requirements** (the master-plan card, `ALL_SPRINTS_MASTER_PLAN.md` F350, all six parts):
- R-1 (inventory): a script that can run again (Python, ADR-0051) lists every test file: what it guards, kind, measured
  local time and CI time, where it runs, when it last caught a real defect, risk tier. A policy test fails when a new
  test file is missing from the inventory.
- R-2 (effectiveness): gates that cannot fail or repeat another gate; source-text gates with no behavior test beside
  them; defect classes from Sprints 78-85 that no test caught, each with the cheapest test that would have caught it;
  tests that fail for unrelated reasons (F349, F302).
- R-3 (efficiency): cost of each test kind in each place it runs; why local runs are slow (concurrency 2/4/6/8,
  antivirus, real-PowerShell tests, the 500-message tests); the Sprint 84 timeline for two tasks with the steps that
  could run in parallel.
- R-4 (risk tiers): risk = likelihood x impact (ISTQB CTFL v4.0.1 section 5.2, fetched and quoted, or marked
  unverified). High impact: code that can delete or move mail, credentials, the scan coordinator, background workers,
  DB migrations, release gates. High likelihood: recent churn. Proposal: high-tier tests on every change; others when
  their file or an imported file changes; a shared-file change runs everything; CI full suite as backstop.
- R-5 (mutation-proof policy): when to re-run a proof; what the policy would have missed in Sprints 70-84; whether
  proof spec files are kept in the repository.
- R-6 (full runs, Harold q3 = a): which of today's three full-suite runs per sprint are needed, and where; whether the
  iOS screens job runs on every change or only at sprint end.
- R-7: each recommendation is asked as a numbered decision, prevention first; approved ones become cards or updates to
  the testing and workflow docs and the CI files in this sprint when under the size limit, else backlog cards.

**Affected components / files**: `docs/research/F350_RISK_BASED_TESTING.md` (new); `scripts/test_inventory.py` (new,
name settled in the card); a policy test in `mobile-app/test/policy/`; approved doc and CI changes.

**Existing code reused**: `scripts/run-full-suite.ps1` timings and the CI run history (`gh run list`) as the time
sources -- the inventory CALLS them, it does not re-time by hand.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the inventory records, per test, which platforms its path runs on
(Windows host, Android emulator, iOS Simulator, CI Linux), so the tiers keep coverage for every platform; a platform
with no automated coverage for a high-risk path is listed as a gap.

**Dependencies / blockers**: none (F349 is an input). Recommendations wait for Harold's decisions (R-7).

**Acceptance criteria**:
- AC-1: the inventory covers every test file; the policy test fails when a new test file is missing (mutation-checked).
- AC-2: every time is measured, with command and date.
- AC-3: the Sprint 84 timeline is rebuilt from the records.
- AC-4: every outside source is fetched and quoted or marked unverified.
- AC-5: a stated target (for example a small fix verified in its development time plus about 15 minutes).
- AC-6: no test is removed or skipped without Harold's decision.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT (policy) in `mobile-app/test/policy/`: the inventory lists every `*_test.dart`; a
  `unittest` for the inventory script's parser.

**Definition of Done**: default task-level DoD PLUS the research file committed and Harold's decisions recorded.

**Model**: Opus (main session) for R-2 to R-7 -- *why not the cheaper tier*: a research spike and risk judgment
(`SPRINT_PLANNING.md:94-108`, "Research Spikes"). R-1 and the timings: Sonnet sub-agent -- *why not Haiku*: timing
runs need judgment about noise (antivirus, concurrency) and the CI history.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes (R-1 sub-agent)
**Executed-by** (filled at completion):
**Step-types**: RESEARCH `[no-history]`, SCRIPT, TEST-UNIT, DOCS. **Est-Effort**: 150-210m.

## Task 3 -- F352: Default email account (Priority 12)

**Value**: This opens the app on the account the user works with most, without asking each time.

**Requirements** (ADR-0052; Harold 2026-11-07: q4 = b, q5 = a, q6 = a):
- R-1: one stored app-wide value, `default_account_id` in `SettingsStore`; no second store.
- R-2: Select Account: each row has a control that sets this account as the default, or removes the default; the
  default row is marked.
- R-3: Settings > Account shows a read-only label when the shown account is the default.
- R-4: at startup the default seeds `SelectedAccountProvider` once; the start screen does not change (Review No Rule
  Items when accounts exist, `main_navigation_screen.dart:92-94`); account-scoped screens skip the picker.
- R-5: picking another account changes only the session; it is not kept after a restart.
- R-6: deleting the default account clears the default (no stale id); no automatic default for a single account;
  background scans do not change.

**Affected components / files**: `lib/core/storage/settings_store.dart` (the key); `lib/core/providers/
selected_account_provider.dart` (startup seed; its doc comment updated to ADR-0052); the Select Account screen;
Settings > Account; the account-delete path; `main.dart` startup; `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: `SettingsStore` (app-wide keys) -- the new key is added there, as the provider's own
comment requires (`selected_account_provider.dart:17-23`).

**Existing behavior relied on**: the selection is session-only and starts empty -- verified at
`selected_account_provider.dart:17-23`; the start screen rule -- verified at `main_navigation_screen.dart:92-94`.

**Callers of any guard being changed**: the resolver that decides whether a destination shows the picker
(`account_selection_screen.dart:654-676`: keep a valid selection, drop a stale one, auto-pick a single account, else
prompt) and the readers of `SelectedAccountProvider.accountId`: Settings (`settings_screen.dart:335`, `:351`), Scan
History (`scan_history_screen.dart:99`), Review No Rule Items (`no_rule_review_screen.dart:245`), Help
(`help_screen.dart:138`). Each now finds a selection at startup when a default exists, and must still prompt when none
exists. The delete path (`account_selection_screen.dart:845`, `clearIfSelected`) also clears the stored default (R-6).

**User-reachable control**: Select Account, a per-row "Set as default" / "Remove default" control; Settings > Account,
the read-only "Default account" label.

**Observable behavior -- before / after**: BEFORE: every start has no account selected; the first account-scoped screen
asks which account. AFTER: if the user set a default on Select Account, the app starts with that account selected and
does not ask; the row on Select Account and Settings > Account say it is the default; with no default, nothing changes.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Flutter screens and `SettingsStore` (SQLite on all three
platforms); no platform exception. The OS behavior assumed identical: none (no OS call).

**Non-functional requirements**:
- Account-scoping: the default is an account id; every account-scoped screen still reads the selection.
- Accessibility: the control and the label have semantics labels (ADR-0037).

**Dependencies / blockers**: None.

**Acceptance criteria** (ADR-0052 draft AC-1 to AC-7):
- AC-1: each Select Account row has a control that sets or removes the default, and the default row is marked.
- AC-2: Settings > Account shows a label when the shown account is the default.
- AC-3: removing it returns to "no default".
- AC-4 (behavioral): Given a default is set, When the app restarts, Then the start screen is the same and the default
  account is selected, and account-scoped screens skip the picker.
- AC-5: picking another account works as today and is not kept after a restart.
- AC-6: deleting the default account leaves no default and no stale id.
- AC-7: one `default_account_id` key in `SettingsStore`, no second store.

**Tests to write**:
- T-1 (AC-7, AC-6) -- TEST-UNIT in `test/unit/storage/`: set, read, clear; delete-account clears it.
- T-2 (AC-1, AC-3) -- TEST-WIDGET for Select Account: the control sets and removes; the mark follows.
- T-3 (AC-2) -- TEST-WIDGET for Settings > Account: the label shows only for the default.
- T-4 (AC-4, AC-5) -- TEST-WIDGET for startup seeding: default selected, picker skipped; another pick not persisted.
Each new guard test is mutation-checked (retro i5).

**Definition of Done**: default task-level DoD PLUS ADR-0052 marked Implemented and ARCHITECTURE.md updated.

**Model**: Sonnet -- *why not Haiku*: it changes startup selection semantics across five screens and the account-delete
path; the "caller safe by accident" check (IMP-1) needs judgment.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent as assigned, 2026-11-10 15:25-17:40. One key
(`default_account_id`) in `SettingsStore`; `SelectedAccountProvider.createSeeded` seeds before `runApp` (a stale id is
cleared; an error starts the provider empty); `DataDeletionService.deleteAccountData` clears the default inside the same
transaction; star control on the healthy Select Account row, "Default account" mark, read-only label in Settings >
Account. Callers: the resolver (`account_selection_screen.dart:654-676`) returns the seeded default and skips the
picker; settings_screen:335 accepts it only if the account is saved; scan_history:99, no_rule_review:245 and help:138
now start pre-filtered to the default (none acts on mail); the delete path `:845` is unchanged. 21 tests (12 unit, 9
widget, one at 360 px), 11/11 mutants KILLED, `flutter analyze` clean. Full suite +3669 ~15 -5: 4 are F349 Task
Scheduler timeouts, 1 is a gitignored `test/scratch` file. Not covered: a real restart and phone layout (Manual
Validation).
Phase 5 follow-ups (main session, 2026-11-10): (1) MV rehearsal on the pixel34 emulator (412 dp): a Gmail row needing
sign-in showed its address one letter per line, because the trailing Row held "Sign In Again" plus the new star, play
and delete; even a healthy row's title was 80 dp at 360 dp. Fix: below 600 dp the icons go on their own line under the
subtitle, and "Sign In Again" sits under its reason (`account_selection_screen.dart`); guard
`account_row_phone_width_test.dart` (360 and 412 dp, both states; 2/2 mutants KILLED). The earlier 360 px test checked
only for an overflow error, not a squeezed title. (2) 5.1.2 M1: an EMPTY account list (what a failed credential read
returns) no longer clears the stored default (2 tests, mutant KILLED). (3) L9: a source-order test that `main()` builds
the seeded provider before `runApp` and passes it in (mutant KILLED). (4) L2: the unused `clearDefaultAccountIfMatches`
removed. (5) L3: one source for the "Default account" words (`SettingsScreen.defaultAccountLabel`). (6) L7 decision:
the "Missing credentials" error row has no star on purpose: it cannot scan, and its one action, delete, also clears a
default on it (comment in the code). AC-1 reads "each row that can scan".
**Step-types**: SVC-EDIT, UI-ADD, TEST-UNIT, TEST-WIDGET, DOCS. **Est-Effort**: 120-240m.

## Task 4 -- F354: Windows DEV keeps its account credentials in the production-named folder (Priority 14)

**Value**: This prevents a DEV account change from touching production credentials.

**Requirements**:
- R-1 (audit first): confirm which credential file the installed Store (MSIX) app opens (Process Monitor, or a log
  line from a DEV build that prints the resolved path, compared with the MSIX package folder under
  `%LOCALAPPDATA%\Packages\`). Record, for each of the 11 `getApplicationSupportDirectory()` callers, which folder it
  resolves to on DEV, prod non-MSIX and MSIX. No production file is opened for writing.
- R-2: present the evidence and a recommended fix to Harold (Q2 = 1), or apply the pre-approved option (Q2 = 2 or 3).
- R-3: the fix gives DEV its own credential store, with a one-time copy so DEV keeps its accounts; production files are
  never moved or deleted.
- R-4: a test that DEV and prod resolve different credential paths.

**Affected components / files**: per Q2; candidates `windows/runner/Runner.rc` and `windows/runner/CMakeLists.txt`
(option 2), the credential store wrapper in `lib/adapters/storage/` (option 3), `app_paths.dart`,
`docs/adr/0035-production-development-side-by-side.md`.

**Existing behavior relied on**: the plugin's fixed file name and folder -- verified at
`flutter_secure_storage_windows_ffi.dart:234`, `:252-258` (4.1.0, the `pubspec.lock` version).

**Callers of any guard being changed**: the 11 `getApplicationSupportDirectory()` callers listed in the 3.2.2.1 summary
(option 2 changes all of them for DEV).
- Tooling that launches or kills the same executable: `build-windows.ps1`, the WinWright runner, the DEV Task Scheduler
  background task (it runs the DEV exe every 5 minutes) -- each must find the DEV store after the change.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Windows exception. Android and iOS keep credentials per package (Android
Keystore-backed storage per applicationId; iOS keychain per bundle ID), so DEV and prod are already separate there;
declared in the ADR-0049 table.

**Non-functional requirements**:
- Security: no credential value is logged or copied outside the DEV and prod stores; the copy is DEV -> DEV only.

**Dependencies / blockers**: Q2.

**Acceptance criteria**:
- AC-1: R-1's per-caller table and the MSIX answer are recorded with evidence.
- AC-2: after the fix, a DEV account add or delete leaves the production credential file byte-for-byte unchanged
  (hash before and after).
- AC-3: DEV keeps its existing accounts after the change.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT: DEV and prod resolve different credential paths (mutation-checked).

**Definition of Done**: default task-level DoD PLUS ADR-0035 updated.

**Model**: Opus (main session) -- *why not Sonnet*: credential storage, a Class-1 decision, and a migration where a
mistake loses production sign-ins.
**Delegation checklist included in the sub-agent prompt** (when delegated): N/A (main session).
**Executed-by** (filled at completion): Opus main session as assigned, 2026-11-10, interleaved with agent reviews
(active time not recorded). Code: `Runner.rc` ProductName from `SPAMFILTER_IS_DEV` (CMake sets it when the env is not
prod); `AppPaths.dataDirectoryPath` the one place the `_Dev` suffix is applied (5 callers moved to it);
`DevCredentialSeparation` before any credential read; `AppIdentityMigration` production-only;
`PlatformCapabilities.sharesCredentialStoreAcrossEnvironments`. Tests: 4 new files plus the capability tests (53 with
the F352 files, all pass); M1-M10 mutants KILLED; `flutter analyze` clean. Real-file proof (DEV build 0.25.0+23,
17:57): the exe ProductName is `MyEmailSpamFilter_Dev`; the production `flutter_secure_storage.dat` is unchanged (hash
prefix 464DC179B98A1F67 and 11/07 timestamp before and after); DEV holds an identical copy; the March DEV file is kept as
`.pre_f354_20261110_175703`; marker written; the 17:58 Task Scheduler worker on the new exe found all 4 accounts and
scanned Yahoo successfully; the UI tree shows the home screen. Backups of both files before the run:
`<SCRATCH>\s85_f354\backup\`. Callers checked after the fact: `DevEnvironmentSeeder` uses the support folder's
PARENT, so it resolves the same folders. A blank `ww_screenshot` during the check was the monitor being asleep, not the
app (README note added). The marker is now consumed on this machine; MV re-checks the result, not the first copy.
**Step-types**: DIAG `[no-history]`, NATIVE-WIN, SVC-EDIT, TEST-UNIT, DOCS. **Est-Effort**: 60-120m.

_**Risk & rollback**_: risk: DEV loses its accounts, or a production file is touched. Mitigation: hash the production
file before and after; back up the DEV store first. Rollback: restore the DEV backup; revert the commit.

_**Decision-class interrupts**_: Class 1 (ADR-0035): Q2.

**Result (Phase 4) -- R-1 audit (2026-11-10, main session, read-only)**:
- Folder rule: `path_provider_windows` 2.3.0 (`pubspec.lock`) returns `RoamingAppData\<CompanyName>\<ProductName>` from
  the exe version resource (`path_provider_windows_real.dart:119-120`, `:180-215`). Every build had CompanyName and
  ProductName `MyEmailSpamFilter` (`Runner.rc:92`, `:98`).
- Credential file: `flutter_secure_storage.dat` in that folder, no path option (`flutter_secure_storage_windows_ffi.dart:234`,
  `:252-258`); DPAPI, user scope, no entropy, flags 0 (`:404-411`), so a byte copy decrypts for the same user.
- Store app (MSIX): shares the file. Microsoft (learn.microsoft.com desktop-to-uwp-behind-the-scenes, ms.date
  2026-09-30): *"If the file is opened from the real AppData location, then no virtualization for that file occurs."*
  Observed: `%LOCALAPPDATA%\Packages\KimmeyConsulting-Ohio.MyEmailSpamFilter_3t07cykjy5226` has no redirected app data;
  the production DB in `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter` was written at 08:37 on 2026-11-10. The card's
  risk is CONFIRMED: a DEV account delete removed the production sign-in.
- Also found: a stale `MyEmailSpamFilter_Dev\flutter_secure_storage.dat` (630 bytes, 2026-03-15) that a DEV folder switch
  would have loaded; `%APPDATA%\com.example\spam_filter_mobile` still exists and the DEV folder has no
  `.migration_complete`, so `AppIdentityMigration` would have copied February data into DEV.
- The 11 `getApplicationSupportDirectory()` callers, DEV before -> DEV after (prod and MSIX unchanged in every row):
  - `app_paths.dart:69` data root: `..._Dev` (suffix added) -> `..._Dev` (support folder already DEV; suffix not re-added,
    `AppPaths.dataDirectoryPath`).
  - `main.dart:161` background log, `background_scan_windows_worker.dart:42` log, `diagnostic_logger.dart:191` fallback
    log, `live_scan_logger.dart:44` log: each appended the suffix by hand -> each now calls `AppPaths.dataDirectoryPath`
    (without it each would have become `..._Dev_Dev`).
  - `app_identity_migration.dart:33`, `:45`: `.parent.parent` (Roaming) and the new folder -> now skipped in DEV (production
    only), see above.
  - `dev_environment_seeder.dart:33`: uses `.parent` (`Roaming\MyEmailSpamFilter`) -> same parent either way; unchanged.
  - `export_directories.dart:271`: last-resort export fallback -> the DEV folder instead of the production folder (better).
  - `app_paths.dart:43`: a doc comment, not a call.
  - The credential plugin itself (not in `lib/`): production-named folder -> DEV folder.
- Tooling that runs the same exe: `build-windows.ps1` and the WinWright runner launch the DEV exe by path (no change);
  the DEV Task Scheduler task runs the DEV exe, whose background path now runs `DevCredentialSeparation` first.

**Result (Phase 4) -- R-2/R-3 fix (Q2 = 2)**: `Runner.rc` ProductName from `SPAMFILTER_PRODUCT_NAME`
(`MyEmailSpamFilter_Dev` when `SPAMFILTER_IS_DEV`, set by `runner/CMakeLists.txt` when `SPAMFILTER_APP_ENV` is not
`prod`); `AppPaths.dataDirectoryPath` as the one place the suffix is applied (prevention: gate
`test/policy/data_dir_suffix_single_source_test.dart`); `DevCredentialSeparation` (one-time copy, keeps an earlier DEV
file as `.pre_f354_<timestamp>`, marker only after success, never writes the production file); `AppIdentityMigration`
production-only; capability `PlatformCapabilities.sharesCredentialStoreAcrossEnvironments` (ADR-0049). ADR-0035 Sprint 85
update; ADR-0049 site mapping. Where does the USER learn of a failed copy (5.1.2): DEV-only; the DEV app shows no
accounts; it retries at every launch. CORRECTED by the 5.1.2 review (M3): the original text said "the log says ...",
but `Logger` writes nothing in a release build (`logger-2.7.0/lib/src/filters/development_filter.dart:7`, "In release
mode ALL logs are omitted"; default filter at `logger.dart:23`), and the DEV app is a release build. Now the reason is
kept (`DevCredentialSeparation.lastError`) and written to the background scan log (always on) and the diagnostic log
(when on), after each can be opened (`main.dart`).

## Task 5 -- F355: Android "isn't responding" when background scanning is turned on (Priority 16)

**Value**: This settles whether turning on background scans can freeze the Android app.

**Requirements**:
- R-1: after Harold's reboot, repeat the step on the emulator: Settings > Background > Enable Background Scanning, on a
  debug build and a release build; record ANR or not, memory and swap.
- R-2: repeat on the Fold (0.24.1 from Play); Harold taps, Claude pulls the log over MTP.
- R-3: if it repeats, find what holds the main thread (`BackgroundWorker.executeBackgroundTask` ->
  `FlutterJNI.dispatchPlatformMessage`, workmanager `BackgroundWorker.kt:439`, from the Sprint 84 trace) by reading the
  plugin source at the `pubspec.lock` version; fix with prevention first, and a test.
- R-4: if it does not repeat in 3 tries per build, close with the evidence.
- R-5: keep the Sprint 84 evidence (`mv6_android\` in the Sprint 84 session scratchpad): copy it to this sprint's
  scratchpad folder before the scratchpad sweep (it holds account data, so it stays out of the repo).

**Affected components / files**: none unless R-3 finds a cause; then the Android worker or the enable path.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the Android WorkManager start is a declared Android exception. The shared
enable path (Settings > Background) runs on all three platforms; a cause found there is fixed for all three.

**Dependencies / blockers**: Harold's reboot (2026-11-07: "push it to next sprint and I will reboot before then").

**Acceptance criteria**:
- AC-1: R-1 and R-2 are recorded (build, device, result, memory).
- AC-2: a confirmed freeze has a fix and a test; otherwise the card closes with the evidence that it does not repeat.

**Tests to write**:
- T-1 (AC-2) -- only if a fix lands: TEST-UNIT or TEST-INTEGRATION next to the changed code, mutation-checked.

**Definition of Done**: default task-level DoD (code parts only if a fix lands).

**Model**: Opus (main session) -- *why not Sonnet*: native-thread deep debugging across the plugin and the engine, and
it needs the emulator and the Fold interactively.
**Delegation checklist included in the sub-agent prompt** (when delegated): N/A (main session).
**Executed-by** (filled at completion): Opus main session as assigned. PARTIAL: R-1 and R-5 done; R-2 (Fold) waits for
Manual Validation.
**Result (Phase 5) -- R-1, emulator `pixel34_updated` (Android 14, 2 GB RAM, 1.5 GB swap), 2026-11-10**: 9 tries, 0 ANR
(no "isn't responding" dialog in a uiautomator dump 20 s after each tap; 0 `ANR in` / `Input dispatching timed out` /
`am_anr` lines in logcat). Every try started `dev.fluttercommunity.workmanager.BackgroundWorker` within 1 s of the tap,
the path of the Sprint 84 trace.
- Debug build (`app-prod-debug.apk`, 21:32-21:51 build), tries 1-3 on kimmeyh@gmail.com 21:54-21:59: each scan stopped
  after about 2 s at "Gmail needs you to sign in again" (expired emulator token); MemAvailable 511-657 MB, SwapFree
  154-338 MB. Tries 4-6 on the Demo account (the Sprint 84 set-up) 22:38-22:40: MemAvailable 643-673 MB, SwapFree
  549-550 MB.
- Release build (`app-prod-release.apk`, fresh install, 22:41-22:47 build), Demo account 22:48-22:51: tries 1 and 2
  showed the Android notification prompt (as Sprint 84 did) and were answered "Don't allow"; no ANR with the prompt open
  15 s or after it; try 3 had no prompt. MemAvailable 706-737 MB, SwapFree 703-791 MB.
- Not the same as Sprint 84: the emulator was cold-booted for this run (Sprint 84: 1.24 GB of 1.5 GB swap in use; here
  at most about 1.36 GB in use during the debug tries), and the Sprint 84 build was the dev flavor. Evidence:
  `<SCRATCH>\s85_f355\` (screens, dumps, logcats per try). R-5: the Sprint 84 `mv6_android\` folder is already in this
  session's scratchpad; no copy needed.
**Step-types**: DIAG `[no-history]`, MANUAL. **Est-Effort**: 30-90m.

## Task 6 -- F357: Background scan rows marked `interrupted`: the recent-scan check and the completion overwrite (Priority 34)

**Value**: This makes sure a background scan that Android stopped is retried when it should be.

**Requirements**:
- R-1 (q2): from Task 1's Fold evidence, decide whether a Doze-alarm restart should ignore an `interrupted` row in the
  recent-scan check (`recentScanShouldSkip`, `android_background_scan_worker.dart:312`; used at `:435-457`). If yes,
  change the check to ignore `interrupted` rows.
- R-2 (q1): from the same evidence, decide whether a completion or error write in the milliseconds after the stop
  handler may replace `interrupted` (`scan_result_store.dart:419`, `:458`). The retro recommendation was N/A
  ("completed" is the more accurate record); Harold chose to decide it with the Fold evidence.
- R-3: both decisions recorded with the Fold log lines that support them; ask Harold with the evidence before a change
  that alters either (Class 2: it changes when a background scan runs).

**Affected components / files**: `android_background_scan_worker.dart` (R-1), `scan_result_store.dart` (R-2), only if
a change is decided.

**Callers of any guard being changed**: `recentScanShouldSkip` -- called from `recentScanReason`
(`android_background_scan_worker.dart:438-457`) for the runs `checksRecentScan` selects (`:328`, Doze alarm and
notification-triggered runs); the periodic WorkManager run does not check. `BackgroundScanCore` receives it as
`skipAfterWait` (`:505`); Windows passes null (`background_scan_core.dart:210`).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: R-1 is the Android worker (declared exception; Windows has one scheduler
and no recent-scan check). R-2's store writes are shared Dart on all three platforms.

**Dependencies / blockers**: Task 1 R-1 (the F342 Fold check after 0.24.1).

**Acceptance criteria**:
- AC-1: both decisions recorded with Fold log lines.
- AC-2: any change has a test, mutation-checked.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT next to `recentScanShouldSkip` (an `interrupted` row does not skip), if R-1 changes it.

**Definition of Done**: default task-level DoD.

**Model**: Sonnet -- *why not Haiku*: it changes a guard with several callers, and the decision rests on reading a
phone log against the code.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion):
**Step-types**: SVC-EDIT, TEST-UNIT. **Est-Effort**: 30-60m.

_**Decision-class interrupts**_: Class 2 (R-3).

## Task 7 -- F341: F325 part B, live first-run evaluation, the remainder (Priority 32)

**Value**: This shows what a new user meets on first launch, on each platform, so the confusing parts get fixed.

**Requirements** (`docs/research/F325_FIRST_RUN_EVALUATION_S83.md:102-111`; Sprint 84 results in
`SPRINT_84_PLAN.md`):
- R-1: check 6 (relaunch after adding an account without scanning: is "All reviewed" misleading?) on Windows and the
  Android emulator.
- R-2: check 2 (Gmail: the contradictory recommendation; Windows browser sign-in versus Android native sign-in), with
  Harold for the browser step.
- R-3: check 9 (Fold folded and unfolded: Results, the pop-up and the toolbar near 600 px), with Harold.
- R-4: the clean Windows first run, after Task 4 separates the DEV credential store (DEV data folder backed up and
  restored byte for byte).
- R-5: the iOS Simulator first-run screens from the F345 job, compared with Windows and Android.
- R-6: each confirmed finding becomes its own card (or joins F356 when it is one of its six observations).

**Affected components / files**: `docs/research/F325_FIRST_RUN_EVALUATION_S83.md` (results); new backlog cards.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: the evaluation itself covers Windows, Android and iOS (Simulator); a
difference found is recorded as a parity gap or a declared exception.

**Dependencies / blockers**: Task 4 (R-4); Harold for R-2 and R-3; the Fold.

**Acceptance criteria**:
- AC-1: each remaining check has a result with a screenshot or log line.
- AC-2: each confirmed finding has a card.

**Tests to write**: none (evaluation).

**Definition of Done**: AC-1 and AC-2 only (no code).

**Model**: main session (interactive with Harold) -- N/A.
**Executed-by** (filled at completion):
**Result (Phase 5) -- R-1 check 6, Android emulator** (`pixel34_updated`, release 0.25.0 fresh install, 2026-11-10
22:52-23:00): a Custom IMAP account for the local GreenMail test server (`10.0.2.2:3993`, user `tester`; certificate
trusted through the app's own dialog; "[OK] Connection successful!") was saved and NOT scanned; app force-stopped and
started again. The start screen read **"No unaddressed items" / "All "No rule" emails have been reviewed."** with
No rule (0), All Accounts (0); Scan History totals all 0 (no scan ever ran). CONFIRMED misleading: nothing was reviewed.
Also seen: the toolbar title "Review No Rule Items" is not visible (its text box is 68 px wide, F356 observation 1
family); on Custom IMAP setup, Username comes before Email Address. Screens: `<SCRATCH>\s85_f355\c6_relaunch.png`,
`c6_history.png`, `c_5.png`.
**Result (Phase 5) -- R-5, iOS Simulator** (iOS run 42916648939 on this branch, job "iOS Simulator screens" success;
10 screens, iPhone and iPad, in `<SCRATCH>\s85_ios_screens\`): compared with the Android emulator captures
(`r_start.png`, `d_add.png`, `d1_settings.png`). Start screen, provider list and AOL form match in text and order.
Differences: (a) no back arrow on the iOS screens: the test opens each screen as the first route
(`ios_first_run_screens_test.dart:85`, `home: screen`), so not a parity gap; (b) light theme on iOS versus dark on the
emulator: device setting, not a gap; (c) the iPad puts the version in the toolbar: the wide layout, same as Windows.
Shared defects seen on both phones: "Backgrou / nd" tab wrap (F356 observation 6) and "in a file on this computer"
on a phone (F356 observation 7).
**Result (Phase 5) -- R-6**: check 6 is a new card, F358 ("All reviewed" shows before any scan has run,
`no_rule_review_screen.dart:1031-1043`). The hidden "Review No Rule Items" title joins F356 observation 5 (titles cut
off). Username before Email on Custom IMAP setup: recorded here only; not a defect on its own (the server may use a
user name that is not the address).
**Step-types**: MANUAL, DOCS. **Est-Effort**: 90-150m.

## Task 8 -- F307: Remove the "Create rule" page (RuleQuickAddScreen) (Priority 36)

**Value**: This removes a second rule-creation path that the Review No Rule Items pop-up (F306) replaced.

**Requirements**:
- R-1 (audit first): confirm F306's pop-up covers the page's four condition kinds (From header, subject, body, body URL);
  any kind it does not cover is reported to Harold before removal.
- R-2: remove `lib/ui/screens/rule_quick_add_screen.dart` and its two callers: the "Create rule" button on Review No
  Rule Items (`no_rule_review_screen.dart:593-603`, `_openCreateRule`) and the email detail view entry
  (`email_detail_view.dart:551`).
- R-3: update `RuleConflictResolver`'s doc comment (`rule_conflict_resolver.dart:5`, `:44`); remove or rewrite the four
  test files that use the screen (`f298_quick_add_test.dart`, `rule_quick_add_screen_test.dart`, the screen cases in
  `no_rule_review_heuristics_test.dart`, `subject_rule_keyword_test.dart:59`), keeping any check that still guards
  shared code.

**Affected components / files**: the files in R-2 and R-3; `CHANGELOG.md`; Help content if it names the page
(`mobile-app/assets/content/`).

**Old name search**: `RuleQuickAddScreen`, `rule_quick_add_screen`, "Create rule" -- every hit in `lib/`, `test/`,
`assets/content/`, `docs/` updated or kept with a reason, recorded in the card at completion.

**Observable behavior -- before / after**: BEFORE: Review No Rule Items has a "Create rule" button and the email detail
view opens the "Create rule" page. AFTER: neither entry exists; rules are made from the Review No Rule Items pop-up.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Flutter screens; removed on all three platforms at once.

**Dependencies / blockers**: F306 (shipped Sprint 82). Harold's 2026-10-25 target was Sprint 86; he selected it for
Sprint 85.

**Acceptance criteria**:
- AC-1: R-1's coverage answer recorded.
- AC-2: `grep RuleQuickAddScreen` in `lib/` and `test/` returns 0; `flutter analyze` clean; full suite green.

**Tests to write**:
- T-1 (AC-2) -- TEST-WIDGET: Review No Rule Items has no "Create rule" control (fails if it returns).

**Definition of Done**: default task-level DoD.

**Result (Phase 4) -- R-1 audit (Haiku sub-agent, 2026-11-10; claims re-checked in the source by the main session)**:
- From header: COVERED by the pop-up (Block Email, Block Exact Domain, Block Entire Domain;
  `email_detail_popup.dart:1103-1187`, `rule_quick_action_service.dart:447-464`).
- Subject: COVERED (Block Subject, `email_detail_popup.dart:1206-1227`, `rule_quick_action_service.dart:465-474`).
- Body text (a free phrase): NOT COVERED. The pop-up's only body action, Block Body, uses the domain of the first
  outside link (`body_link_domain.dart:67-93`).
- Body URL: PARTIAL (a link domain, not a URL pattern).
- BUT the page never offered Subject, Body or Body URL either: only `_fromPatternController` is ever filled
  (`rule_quick_add_screen.dart:110`); no field binds the other three controllers (`:49-51`), so their conditions are
  always empty (`:193-201`); the "Edit pattern" button is `onPressed: () {}` (`:715-719`). The page makes From-only
  rules today, and its Edit button is a control that does nothing.
- Card rule applied: a kind not covered means STOP before removal. Nothing removed. Decision held for Harold at Manual
  Validation (asked late, per the approval). Removal work is ready to run in one agent pass once decided.
**Model**: Haiku -- the cheapest tier fits a removal with a written coverage check and the analyzer and suite as oracles.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion):
**Step-types**: UI-REMOVE `[no-history]`, TEST-WIDGET. **Est-Effort**: 45-75m.

## Task 9 -- F329: Python batch H4: the hook test tooling, then retire the PowerShell copies (Priority 36)

**Value**: This finishes the hook conversion, so one language runs and tests every hook, and the old copies cannot be
edited by mistake.

**Requirements** (master-plan card F329, with the Sprint 84 additions):
- R-1 (port): convert `.claude/hooks/run-test-cases.ps1` (189 lines, with the Sprint 83 `.py` route), `scripts/
  test-hook.ps1` (203, with `.py` dispatch) and `scripts/mutation-test.ps1` (167) to Python. The runner keeps the
  allow-, violation- and warn- rules and the fixture repos; `mutation-test` keeps the baseline, INVALID and
  restore-byte-for-byte rules (Sprint 74 and 75 retro).
- R-2: `.claude/hooks/status-footer.ps1` (160) to Python; its output format byte for byte. (The footer Claude runs is
  the user-level `C:\Users\kimme\.claude\scripts\status-footer.ps1`, outside this repo; it is not changed.)
- R-3: delete the five unregistered `.ps1` hook twins (`block-carry-forward-stash`, `require-sprint-cards`,
  `sprint-auto-advance`, `verify-closeout-complete`, `warn-commit-without-velocity`; 1,695 lines). The registered
  `.py` versions are unchanged.
- R-4: retire `.claude/hooks/mutation-lock.ps1` and `scripts/agent-work-status.ps1` only after every caller is updated
  in the same commit (the hourly wake-up text, CLAUDE.md, docs).
- R-5 (retro i2 = b): a fault-injection test in `test_pylib.py`: each Stop and PreToolUse hook runs with `git` and `gh`
  forced to fail (not found, non-zero exit, timeout); each check ends in a violation or a notice, never a silent pass.
- R-6 (retro q3 = a): confirm how a hook notice shows on Harold's screen: make a hook skip a check on purpose in a live
  session; Harold takes a screenshot of the warning line; record the path in this plan.

**Affected components / files**: the files in R-1 to R-4 and their new `.py` versions; `.claude/hooks/tests/
test_pylib.py`; CLAUDE.md; `docs/TESTING_STRATEGY.md`; ADR-0051 file table.

**Port of existing code**: originals reviewed for defects FIRST, each with file:line and whether the port fixes or keeps
it, written into this card before the port (R-1); failure-path cases come from the spec, not from the originals.

**Old name search**: `run-test-cases.ps1`, `test-hook.ps1`, `mutation-test.ps1`, `status-footer.ps1`,
`mutation-lock.ps1`, `agent-work-status.ps1`, and the five twin names -- every hit in docs, CLAUDE.md, settings,
scripts, skills, `.codex/` and the hourly wake-up text updated or kept with a reason, recorded at completion.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development tooling on the Windows machine; the Python runs the same on
macOS and Linux (CI), which the `.ps1` did not.

**Dependencies / blockers**: run last among the tooling cards (they use `mutation-test` and `test-hook`); R-6 needs
Harold for the screenshot.

**Acceptance criteria**:
- AC-1: the Python runner reports the same case counts as the PowerShell runner did (both recorded).
- AC-2: `mutation-test` kills its own sample spec; INVALID and baseline-fail cases behave as before.
- AC-3: R-5's fault-injection test passes and is mutation-checked (a hook made to pass silently is caught).
- AC-4: the Old name search hits are all updated or kept with a reason.
- AC-5: R-6 has a screenshot path.

**Tests to write**:
- T-1 (AC-1, AC-2) -- `unittest` for the runner and `mutation-test` (fixture cases).
- T-2 (AC-3) -- the fault-injection test in `test_pylib.py`.

**Definition of Done**: default task-level DoD PLUS the hook suite and `test_pylib` green after each change.

**Model**: Sonnet -- *why not Haiku*: the runner and `mutation-test` carry subtle rules (baseline, INVALID, byte-exact
restore, line endings) whose loss would silently weaken every gate.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent as assigned, 2026-11-10 19:50-20:53; main session review and
CLAUDE.md, ADR-0051 and memory edits 20:53-21:05. PARTIAL: R-6 waits for Harold at Manual Validation. Port review
(full text in the scratchpad `s85_f329\port_review.md`), defects fixed: the old runner SKIPPED an unknown case prefix and
a missing route folder silently and passed with "0 total" (now FAIL, exit 2); fixture git errors were hidden by
`2>$null`; case files were read in the system code page; no time limit on a hook or a check; `mutation-test` lost its
whole report on `RESTORE FAILED`, passed an empty spec, and counted a Python syntax-error mutant as KILLED (now INVALID).
New defect found and fixed while testing: a stale `.pyc` could hide a same-size mutant written in the same second.
AC-1: PowerShell runner 208/0/208 before deletion, Python runner 208/0/208. AC-2: KILLED, INVALID, BASELINE FAILS,
SURVIVED and anchor-not-found cases proven on a fixture; same verdicts as the old tool except the intended INVALID.
R-2: 21 of 22 footer inputs byte-identical; the one difference is non-ASCII text (UTF-8 now, OEM code page before;
ADR-0051 rule 3). R-3: no `.ps1` registered in `.claude/settings.json`; five twins deleted. R-4: `mutation-lock.ps1`
and `agent-work-status.ps1` (thin shims) deleted after every caller moved; the commit gate is proven to block a lock made
by the Python command line. AC-3 (R-5): 8 fault-injection tests; 8 of 8 mutants (a hook made silent on a git failure)
KILLED. Tests: hook unittests 145, scripts unittests 337, runner 208/208 (main session re-ran all three, all green).
88 mutants in total, all KILLED, run with the new `scripts/mutation-test.py` after its own 15 mutants. AC-4: old names
updated or kept as history (CLAUDE.md :165-166 incident text, sprint records, CHANGELOG, `F77-hookify-decision.md`).
`ci.yml` hook step now discovers all of `.claude/hooks/tests`, so the new tests run on Linux (unproven until CI run 1).
Open for Harold: `.codex/hooks/sprint-auto-advance.ps1`, an unregistered Codex copy outside the R-3 list, left in place.
**Step-types**: HOOK, PORT-PY `[no-history]`, TEST-UNIT, DOCS. **Est-Effort**: 240-380m.

_**Risk & rollback**_: risk: a converted runner reports green while skipping cases. Mitigation: AC-1 counts compared
with the old runner before it is deleted. Rollback: revert the commit (the `.ps1` files return with it).

## Task 10 -- F330: Python batch S1: repo helper scripts (Priority 37)

**Value**: This moves four everyday helpers to the tested Python layer.

**Requirements**:
- R-1 (port): `scripts/clean-temp-scripts.ps1` (151), `scripts/run-full-suite.ps1` (132),
  `scripts/validate-yaml-rules.ps1` (239), `scripts/test-regex-patterns.ps1` (191) to Python; originals deleted in the
  same commit (ADR-0051 `:111`).
- R-2: list the .NET-to-Python `re` differences first (named groups `(?<n>)` versus `(?P<n>)`, inline flag position)
  and handle each.
- R-3: YAML: first check whether a minimal reader of this repo's restricted YAML (single-quoted strings, lists) is
  enough; only if not, ask Harold about PyYAML (a dependency change).
- R-4: parameters and exit codes kept (or every caller and doc updated in the same commit); the `/validate-rules` skill
  still works.

**Affected components / files**: the four scripts and their `.py` replacements; `.claude/skills/validate-rules`;
CLAUDE.md "Validation Scripts"; docs that name them.

**Port of existing code**: each original reviewed for defects FIRST (file:line, fixed or kept), recorded before the
port.

**Old name search**: the four `.ps1` names -- hits updated or kept with a reason, recorded at completion.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development tooling; runs on Windows, macOS and Linux.

**Dependencies / blockers**: R-3 may need Harold (PyYAML).

**Acceptance criteria**:
- AC-1: each script gives the same output and exit code as the original on the same input (recorded).
- AC-2: a `unittest` file per script, each mutation-checked.
- AC-3: `/validate-rules` runs.

**Tests to write**: T-1 (AC-1, AC-2) -- one `unittest` file per script, including a failure-path case each.

**Definition of Done**: default task-level DoD.

**Model**: Sonnet -- *why not Haiku*: regex-dialect translation and a YAML reader decision; a silent difference would
pass a bad rule.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent as assigned, 2026-11-10 15:26-17:05. Port review found 24
defects in the originals, recorded before the port (the largest: `validate-yaml-rules.ps1` lost every regex error
through a variable-scope defect, and its default paths never existed, so `/validate-rules` always failed). 87
unittests, 64 of 64 mutants KILLED. R-3: the line scan is enough (rules.yaml 1824 single-quoted items, 0 double-quoted,
0 non-empty flow lists), so no PyYAML. Old-name hits: CLAUDE.md:193 and :813 updated; CHANGELOG.md:189,
CODING_VELOCITY.md:243 and sprint docs kept as history.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT, DOCS. **Est-Effort**: 150-250m.

## Task 11 -- F331: Python batch S2: Claude and MCP set-up scripts, test mail servers (Priority 37)

**Value**: This moves the set-up scripts to the tested Python layer.

**Requirements**:
- R-1 (port): `scripts/install-custom-mcp.ps1` (121), `scripts/setup-claude-mcp.ps1` (203),
  `scripts/start-test-imap-servers.ps1` (149) to Python; originals deleted in the same commit.
- R-2: the MCP scripts find `claude` and `node` with `common.find_tool` and write the user-level MCP configuration
  with a backup first.
- R-3: `start-test-imap-servers` starts the test servers the way `TESTING_STRATEGY.md` documents (verify the command on
  the day, do not assume).
- R-4: parameters and exit codes kept.

**Affected components / files**: the three scripts and their `.py` replacements; docs that name them.

**Port of existing code**: each original reviewed for defects FIRST, recorded before the port.

**Old name search**: the three `.ps1` names -- hits updated or kept with a reason, recorded at completion.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development tooling; runs on Windows, macOS and Linux.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: a dry run of each MCP script shows the same change as the original (no write to the real configuration during
  the test).
- AC-2: the test servers start and accept a connection.
- AC-3: a `unittest` file per script, mutation-checked.

**Tests to write**: T-1 (AC-1, AC-3) -- `unittest` with a temporary configuration file; T-2 (AC-2) -- start, connect,
stop.

**Definition of Done**: default task-level DoD.

**Model**: Haiku -- the cheapest tier fits deterministic set-up scripts with a dry-run oracle.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Haiku sub-agent as assigned, 2026-11-10 15:27-16:47. The originals wrote
`~/.claude/config.json`, which Claude Code does not read for MCP servers (it reads `~/.claude.json`,
https://code.claude.com/docs/en/mcp), so their registration never took effect; the port writes `~/.claude.json` with a
backup first. 32 unittests, 16 of 16 mutants KILLED. AC-1 dry run matches the original's entries (temporary profile);
AC-2 live: GreenMail and Dovecot started, ports 3993, 143 and 993 accepted connections, `--stop` closed all three.
R-3: TESTING_STRATEGY.md names no start command; the command is in SPRINT_77_PLAN.md:387 and the script header.
Old-name hits: docs updated; SPRINT_77_PLAN.md and this plan's R-1 kept as history.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT. **Est-Effort**: 90-150m.

## Task 12 -- F332: Python batch S3: phone log health and the battery arm script (Priority 37)

**Value**: This moves the phone log report to the tested Python layer.

**Requirements**:
- R-1 (port): `scripts/phone-log-health.ps1` (267) and `mobile-app/scripts/r76_battery_arm.sh` (77) to Python;
  originals deleted in the same commit. `pull-phone-screenshots.ps1` stays (Windows-bound, F337).
- R-2: the same report lines for two Sprint 82 phone log samples, kept as fixtures (account data removed from the
  fixtures).
- R-3: parameters and exit codes kept.

**Affected components / files**: the two scripts and their `.py` replacements; fixtures; docs that name them.

**Port of existing code**: each original reviewed for defects FIRST, recorded before the port.

**Old name search**: `phone-log-health.ps1`, `r76_battery_arm.sh` -- hits updated or kept with a reason.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development tooling; reads Android logs; runs on any OS.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: the report matches the original for both fixtures.
- AC-2: `unittest` file, mutation-checked.

**Tests to write**: T-1 (AC-1, AC-2) -- `unittest` with the two fixtures and one malformed-log case.

**Definition of Done**: default task-level DoD.

**Model**: Haiku -- deterministic log parsing with fixtures as the oracle.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Haiku sub-agent as assigned, 2026-11-10 15:27 to the 16:43 commit (3356c223).
Phone report P1-P11 mutants KILLED. The fixture logs missed that commit (`.gitignore:150 *.log`) and were force-added
in the follow-up commit; the fixtures use Sprint 83 and 84 samples, the newest available, not Sprint 82.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT. **Est-Effort**: 90-150m.

## Task 13 -- F333: Python batch S4: mobile-app check and gate scripts (Priority 37)

**Value**: This moves the release and content gates to the tested Python layer.

**Requirements**:
- R-1 (port): `mobile-app/scripts/check-log-redaction.ps1` (113), `check-version-consistency.ps1` (125),
  `validate-content-manifest.ps1` (143), `verify-aab-play-requirements.ps1` (305, with its built-in protobuf reader),
  `update_iana_tlds.ps1` (66) and `update_iana_tlds.sh` (61) to Python; originals deleted in the same commit.
- R-2: `verify-aab-play-requirements` keeps its protobuf reader (standard library); confirm the two F204 rules it
  asserts (targetSdkVersion at least 36, no `AD_ID`) are still Play's requirements, from Google's page, quoted.
- R-3: `check-version-consistency` stays in step with the `version_consistency` Dart test; the Dart gate tests that call
  these scripts still pass; `build-with-secrets` calls the new AAB check (until Task 15 converts it).

**Affected components / files**: the six scripts and their `.py` replacements; the Dart policy tests that call them;
`build-with-secrets.ps1` (its call to the AAB check); docs.

**Port of existing code**: each original reviewed for defects FIRST, recorded before the port.

**Old name search**: the six names -- hits updated or kept with a reason.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development and release tooling; the AAB check is Android-only by nature.

**Dependencies / blockers**: before Task 15 (it calls the AAB check).

**Acceptance criteria**:
- AC-1: each script keeps its exit codes; `-SelfTest`-style self-checks still run.
- AC-2: the AAB check passes on `dist\android-0.24.1+22\app-prod-release.aab` and fails on crafted manifests for each
  rule.
- AC-3: the Dart gate tests pass; a `unittest` per script, mutation-checked.

**Tests to write**: T-1 (AC-1 to AC-3) -- `unittest` per script, including crafted failing inputs.

**Definition of Done**: default task-level DoD.

**Model**: Sonnet -- *why not Haiku*: a binary protobuf reader and release gates where a silent pass ships a bad bundle.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent as assigned, 2026-11-10 16:17-17:39. Five ports, six originals
deleted; `build-with-secrets.ps1:657` calls the Python AAB check. Outputs identical to the originals on the repo, the
0.24.1 AAB (targetSdk 36, AD_ID absent) and the live IANA list (version 2026111000, 1436 TLDs). Port fixes: the IANA
updater validated nothing it downloaded; the AAB reader checked a protobuf length after moving the cursor. 50
unittests, 66 mutants KILLED (two first SURVIVED and got stronger tests). R-2 sources fetched 2026-11-10: targetSdk 36
is Google's requirement (developer.android.com target-sdk page); "AD_ID absent" is NOT a Google requirement, it is this
project's rule matching its Data safety answer (support.google.com answer 6048248). Follow-ups: version consistency
does not sweep `.py`; ADR-0038 claims the manifest check runs at the end of `build-windows.ps1`, and no such call
exists.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT. **Est-Effort**: 180-300m.

## Task 14 -- F334: Python batch S5: mobile-app test runners and test mail (Priority 37)

**Value**: This moves the test runners and test-mail tools to the tested Python layer.

**Requirements**:
- R-1 (port): `mobile-app/scripts/run-tests.ps1` (120), `run-integration-tests.ps1` (102), `monitor-tests.ps1` (169),
  `check_scans.ps1` (18), `check_task.ps1` (16), `test-background-scan-skip.ps1` (215), `generate-test-emails.ps1` (229),
  `ww-test-helper.sh` (40) to Python; reuse `send-test-emails.py`; originals deleted in the same commit. A script that
  only works on Windows (`check_task.ps1` reads Task Scheduler) is listed for F337 instead, with the reason.
- R-2: runners write the FULL output to a file and trim only on read (CLAUDE.md background-log rule).
- R-3: parameters kept.

**Affected components / files**: the scripts and their `.py` replacements; docs that name them.

**Port of existing code**: each original reviewed for defects FIRST, recorded before the port.

**Old name search**: the eight names -- hits updated or kept with a reason.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development tooling; Task Scheduler scripts are Windows-bound.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: `run-tests` runs one test file and reports the same pass count as `flutter test`.
- AC-2: a `unittest` per script, mutation-checked.

**Tests to write**: T-1 (AC-1, AC-2) -- `unittest` per script.

**Definition of Done**: default task-level DoD.

**Model**: Haiku -- wrappers around `flutter test` and mail generation, with the test runs as the oracle.
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Haiku sub-agent as assigned, 2026-11-10 16:17 to about 17:30 (handback received
by 17:38). PARTIAL until Phase 5. Ported and originals deleted: `run-tests`, `check_scans`, `generate-test-emails`, with
the shared helper `flutter_support.py`. Ported, original KEPT until proven on an idle machine:
`run-integration-tests` (selection and argv identical; no real integration run yet), `monitor-tests` (both full-suite
runs completed, failing sets differed while other agents edited the tree), `test-background-scan-skip` (real `.exe` run
not done; `build-windows.ps1:517` still calls the `.ps1`). Windows-bound, listed for F337: `check_task.ps1` (Task
Scheduler), `ww-test-helper.sh` (WinWright MCP helper; no callers, hardcoded session ids). AC-1 PASS (run-tests on
`app_paths_data_dir_test.dart`: 5 passed, same as `flutter test`). 55 unittests, 14/14 mutants KILLED. Remaining (Phase
5, main session): the three proofs, then delete the three originals, switch `build-windows.ps1:517`, and update
ADR-0040:52,56.
DONE 2026-11-10 19:29-19:46 (main session, Opus, idle machine; logs in the scratchpad `s85_f334\proof_*`):
`run-integration-tests` old and new both passed `app_boot_smoke_test.dart` (exit 0), and both warn and exit 0 when no
file matches. `monitor-tests` on an unchanged tree (HEAD fcdb97c4): old and new both 3,687 total, 3,672 passed, 15
skipped, 0 failed. The original reported 0 tests and exit 0 when started outside `mobile-app\` (no `test` folder), and
printed an empty exit code; the port has neither defect. `test-background-scan-skip` old and new both PASS against the
DEV exe (same four assertions 1a-1d). `build-windows.ps1` now runs the Python check, and a missing check script FAILS
the run instead of a warning and skip; the exact block was run in a harness both ways (missing: exit 1; present: the
real check passed). Originals deleted; ADR-0040, ADR-0035 and ADR-0051 updated.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT. **Est-Effort**: 150-250m.

## Task 15 -- F335: Python batch S6: Android build scripts (Priority 37)

**Value**: This moves the Android build to the tested Python layer, which also runs on the macOS and Linux CI runners.

**Requirements**:
- R-1 (audit first): confirm whether `build-with-secrets-clean.ps1` (254) is redundant; if so, delete it instead of
  converting.
- R-2 (port): `mobile-app/scripts/build-with-secrets.ps1` (953) and `build-apk.ps1` (24) to Python, per Q3.
- R-3: the Python version injects the same gradle properties the SEC-9 gate needs (CLAUDE.md Sprint 66 IMP-1), keeps the
  IMP-1 `dist\` copy, the IMP-2 versionCode check and the F204 AAB check, and finds tools through the environment
  (`ANDROID_HOME`, `common.find_tool`).
- R-4: never run at the same time as a Windows build (shared `build/`).

**Affected components / files**: the scripts and their `.py` replacements; CLAUDE.md; `GOOGLE_PLAY_RELEASE_PROCESS.md`;
`STORE_RELEASE_PROCESS.md`; every doc that names the old command.

**Port of existing code**: the original reviewed for defects FIRST, recorded before the port.

**Old name search**: `build-with-secrets.ps1`, `build-with-secrets-clean.ps1`, `build-apk.ps1` -- hits updated or kept
with a reason (per Q3).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Android build tooling; runs on Windows here and on Linux in CI.

**Dependencies / blockers**: Task 13 (the AAB check); Q3; no Windows build at the same time.

**Acceptance criteria**:
- AC-1: a debug APK and a release AAB build from the Python entry point; the AAB passes the F204 check.
- AC-2: the SEC-9 gate still fires when a property is removed (mutation).
- AC-3: the IMP-2 check refuses a versionCode not above "Last uploaded to Play".

**Tests to write**: T-1 (AC-2, AC-3) -- `unittest` for the property injection and the versionCode check; the AAB build
itself as the integration check.

**Definition of Done**: default task-level DoD.

**Model**: Sonnet -- *why not Haiku*: the release-signing path and the SEC-9 credential gate; a dropped property ships a
credential-less build (the F119 class).
**Delegation checklist included in the sub-agent prompt** (when delegated): yes
**Executed-by** (filled at completion): Sonnet sub-agent as assigned, 2026-11-10 18:12-18:58. R-1:
`build-with-secrets-clean.ps1` deleted, not ported (no flavor, no SEC-9 property, no release signing). Port review: 17
defects fixed (among them the client id prefix and the AOL address printed to the log, refusals that ran after the clean,
and a bundle copied to `dist\` before the F204 check). AC-1: debug APK and release AAB built from the Python entry point;
the AAB passed F204 and is at `mobile-app\dist\android-0.25.0+23\app-prod-release.aab` (not uploaded). AC-2: the
SEC-9 property mutant is KILLED and the gradle gate is unchanged; no live release build was run with the property
removed. AC-3: versionCode at or below 22 refused (mutant KILLED). 17 unittests, 20/20 mutants KILLED; main session
re-ran 290 Python and 26 Dart policy tests, all pass. Not done: `--install-to-emulator` and `--run` were not run on a
device; the cause of one 22-minute gradle hang on the first debug attempt is unknown (the second attempt passed).
Held for Manual Validation: every key of `secrets.dev.json`, including `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`, is passed
to the Android release build, and shared code reads it (`gmail_windows_oauth_handler.dart:29-32`). Old behavior, kept
by the port; a decision for Harold.
**Step-types**: PORT-PY `[no-history]`, TEST-UNIT, BUILD. **Est-Effort**: 180-300m.

_**Risk & rollback**_: risk: a release bundle built without a credential property. Mitigation: AC-2 mutation, and the
built AAB checked for the OAuth scheme (`GOOGLE_PLAY_RELEASE_PROCESS.md` Step 4). Rollback: revert the commit.

## Phase 5 evidence

- **5.2 tests and analyze**: 2026-11-10 21:04-21:09 at e110499b. `python scripts/run-full-suite.py --concurrency 6`: 3,672 passed, 15 skipped, 0 failed, 0 load failures. `flutter analyze`: No issues found (21:10). A stale gitignored probe, `test/scratch/s84_mv_f342_history_rehearsal_test.dart`, failed earlier full runs; it was backed up to the scratchpad and deleted. Rerun at 33f9d420 (after the 5.1.2 fixes), 2026-11-10 23:12-23:18: 3,677 passed, 15 skipped, 2 failed. (1) `powershell_script_generator_test` "the real New-ScheduledTaskTrigger gets a StartBoundary in the past", 30 s timeout: known, F349 names this test. (2) `f259_gmail_label_cursor_test` "the other callers of the lookup", empty log after the 10 s wait; passes alone (16/16). Its own lines were not kept, so that failure's cause is unproven. Found while looking: a queued DiagnosticLogger write picks its folder when it runs, so tests that reset with `debugSetDir(null)` sent lines into the NEXT test's folder after its tearDown (86 leftover `f259_diag_*` folders in %TEMP%); then readers listed the writer's transient `.lock` file. Fixed: `DiagnosticLogger.debugReset()` (waits for the queue; 13 resets in 11 files), `test/helpers/diagnostic_log_reader.dart` (12 readers in 9 files), gate `test/policy/diagnostic_logger_reset_test.dart` (4 mutants KILLED). Final run 23:29-23:34: `run-full-suite.py --label s85-final-2`: 3,682 passed, 15 skipped, 0 failed, 0 load failures; 0 diagnostic temp folders left. `flutter analyze`: No issues found (23:2x, before the final run).
- **5.1.2 F-PRECHECK**: ran 2026-11-10 21:04-21:41 (sub-agent, read-only) over `git diff origin/develop...HEAD` in Dart, Python, PowerShell, YAML and JSON; 7 classes; 3 MEDIUM, 6 LOW (+ unverified suspicions), 0 HIGH. Fixed 21:42-22:36 (main session): M1 an empty account list no longer clears the default (`selected_account_provider.dart`); M2 `setup-android-oauth.ps1` ran the deleted `build-with-secrets.ps1` (now the `.py`, with a missing-file check), prevention = new gate `scripts/tests/test_no_runs_of_missing_scripts.py` (any live line that runs a script file no tracked path has; mutant KILLED); M3 `Logger` is silent in release builds, so the F354 failure reason now goes to the background scan log and the diagnostic log, card text corrected (mutants KILLED); L1 `mutation-test.py` reports a check that could not start (127, 9009, OSError) as NOT RUN, never KILLED; L2 unused helper removed; L3 one label source; L4 two script hints updated; L6 the test-hook tests FAIL instead of skip on CI when `python` is missing; L7 decision recorded (no star on the error row); L9 source-order test for the seed (mutant KILLED). Held for Harold: L5 (`.claude/settings.local.json:50` runs the deleted `validate-yaml-rules.ps1`; a settings change needs approval). Not fixed, LOW, recorded: L8 `validate-yaml-rules.py` passes with 0 patterns (same as the PowerShell original); test-inventory.py:586 and :646 quiet fallbacks; phone-log-health.py:76 skips bad timestamps. Also found in the MV rehearsal and fixed: the Select Account phone-row layout (F352 card). One unexplained failure: the first run of `test_mutation_test.py` after the L1 edit failed 1 test under the Android build's load (64.9 s against 42 s); output not kept; 3 later runs 31/31.
- **5.2.3 architecture documentation**: F354 in ADR-0035 "Sprint 85 Update"; F352 in ADR-0052 and `ARCHITECTURE.md:524`. Found stale and fixed 2026-11-10: `ARCHITECTURE.md` SecureCredentialsStore said "Windows: Credential Manager"; it now names the DPAPI file `flutter_secure_storage.dat` (plugin 4.1.0, `pubspec.lock:421`) and the F354 DEV separation. The DEV data path on `ARCHITECTURE.md:74` is unchanged by F354 and still correct.
- **Android JVM unit tests**: N/A -- the sprint diff touches no file under `mobile-app/android/app/src`.
- **5.1.6 runtime launch gate**: N/A -- `build.gradle.kts` changed in comments and message text only (F335); no manifest, plugin or native change.
- **5.1.5 WinWright sweep**: 2026-11-10, sweep-head: e110499b (newer than the last `lib/` commit 7fea8327), DEV build from `build-windows.ps1`, workstation unlocked, 3 scripts. Sweep 21:10-21:16: test_f320_no_rule_review PASS; test_f124_rule_labels and test_s75_new_controls FAIL (every cursor step, "SetCursorPos failed") while an unsecured screen saver (`Mystify.scr`) had run since 17:19. The lock gate reported "unlocked", which is correct: Microsoft's "Desktops" page states "Unsecured screen savers run on Winsta0\Default", so the saver did not switch the input desktop; the mechanism is unknown. After the saver process was ended: test_s75_new_controls 27/27 PASS (21:21); test_f124_rule_labels failed once at step 29 ("IsEnabled [#30010] is not supported" on the second Back; its retry failed at step 2, "No main window found", the Sprint 84 symptom), then 29/29 PASS run alone (21:22-21:23). Tray icon PASS; DB drift none in every run. Prevention: the runner now ends a running unsecured screen saver in its preflight and says so (`Stop-UnsecuredScreenSaver`, `run-winwright-tests.ps1`); it leaves a secure saver alone and fails loudly if a saver cannot be ended. Tested both ways (saver running: ended, 1 -> 0 processes; none running: empty list).
  sweep-head: e110499b
