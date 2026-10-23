# Sprint 80 Retrospective

**Sprint**: 80 -- Fold checks on 0.20.0, platform capabilities and policy seam (F294, ADR-0049), iPhone readiness
(F295, ADR-0050), CI Flutter version in sync (F296), rule-learning tools (F267, F268, F269), rule edits reload (F298),
No Rule Review clean-up (F276), AAB checks (F204), and three Manual Validation tasks (15-17: Windows window at once,
tray icon and menu, Android new-mail diagnostic line) (0.21.0)
**PR**: #490 (feature/20261018_Sprint_80 -> develop)
**Date**: 2026-10-22
**Manual Validation**: complete (Harold: "Manual Validation complete"; MV-1 to MV-5 PASS; ADR-0049 and ADR-0050
accepted, "q1 1 q2 1 q3 1")

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own (Step 2 draft, with one
correction found while writing this file: the background Android build did not hang in the script. It printed its error
and reached `exit 1` at 23:46; the task stayed open until the adb server was restarted the next morning, cause
unknown).

## Sprint 80 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective. All 17 remaining cards are done: Tasks 0-10 and 12-14 as planned, and
  Tasks 15-17 added at Manual Validation. Harold removed Task 11 (F289) from scope (Q4b = 2). MV-1 to MV-5 all passed,
  and both ADRs were accepted. The pre-MV build went from approval to handover in about 10 hours, because Sonnet and
  Haiku agents ran Tasks 6-10 and 14 in parallel. Less efficient: MV-4 needed a second round. My rehearsal said the
  tray icon was present, but I had reasoned from tests and an unchanged code block. I had not looked at the
  notification area. Harold's images 14-16 showed the icon missing, which cost one validation round and Task 16
  (~55 m).

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong at unit level. The suite grew from 3,092 to 3,189 passed, with 0 failed and
  `flutter analyze` clean. Every task's new tests were mutation-verified (for example T16-M1 to M4 and T17-M1 to M4
  plus K1, all KILLED). JVM tests ran for the Android changes (19/19). Gaps: (a) the tray defect lived in native plugin
  code (`tray.cpp` drops an empty icon path), where no Flutter test can see it. Only observation through UI
  Automation proved the fix. (b) The Task 17 emulator check found that the first start after install wrote no log
  lines at all. The cause is unknown, and it is not in the Task 17 code. (c) Task 7's widget harness first used a
  fixed wait that was flaky; I replaced it with a condition wait.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Mostly accurate. Fifteen of the 17 task rows with work are inside or under their
  bands. Over: Task 7 (~80 against 30-60, the real-screen widget harness) and Task 16 (~55 against 30-45, the second
  defect where the right-click menu never opened). Under: Task 5 (~26 against 90-120) and Task 6 (~10 against 20-45).
  With parallel agents, the planned bands for research cards are too wide. Unlike Sprint 79, each actuals row was
  written when its task was completed, and the F193 gate did not block the handover.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good for the code cards. Two misses: (a) Task 13's card premise was false. It
  assumed a Review action fails on mail that is gone, but Review actions never touch the message, so I redesigned the
  task during execution as a presence check. (b) Two MV step facts were stale when Harold ran them. MV-3 named a row
  (`noreply@speedpay.com`) that had left Review on 10-19 12:33, when a safe sender was added. MV-1 stated a base count
  of 2202, but the count was 2204 because Harold added 2 rules at 22:24 on 10-21. Both facts were read correctly at
  the 10-19 rehearsal (Sprint 79 IMP-1) and changed before Harold's run.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: The cheapest-first ladder held. Haiku did Task 6. Sonnet agents did Tasks 7, 8, 9,
  10 and 14 and the Task 4b/4c migration. Opus did the ADRs (4a, 5), the Manual Validation work and Tasks 13, 15, 16
  and 17 (native and plugin diagnosis). No escalations. Task 7 ran longest on Sonnet (~75 m), but the tier was not the
  cause.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Decisions were asked as numbered lists, and the MV steps and open questions were
  re-presented in full each time. Misses: (a) I asked about R-2 notification access again after Harold had said it was
  on. Harold: "Stop asing it is on and will remain on". (b) The R-6 step did not give enough detail to act on. Harold:
  "this is not enough information to answer this question". I rewrote it with the screen, its title and the chips to
  look for. (c) I asked for the ADR decisions without explaining what each ADR decides. Harold: "need details on the
  adr's". A decision question needs a summary inside it, not only a file name.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. The parity rule was quoted in the plan and applied per card. Task 17 is
  Android-only because Windows has no notification-listener API (ADR-0042 declared exception, unchanged). Harold's
  mid-sprint answers (Q3-Q6, and Q1-Q3 at the end) were unambiguous.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0049 (amends ADR-0042) and ADR-0050 were written, then accepted at Manual
  Validation. `ARCHITECTURE.md` has the new Platform Seam section. The F295 research doc gives a vendor source for each
  claim. CHANGELOG has an entry per fix. The master plan holds the iOS cards (F67a-d, F95, F95b), F300 and F301.
  Gaps: (a) ADR-0029 already recorded the Gmail 7-day sign-in, but nothing tied it to the closed-test phones, so it
  read as a new mystery for two sprints (Sprint 79 R-6 left it unverified). (b) Tasks 16 and 17 were added after the
  pre-MV architecture update, and `ARCHITECTURE.md` did not describe them until the 7.4.1 check below.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) The MV-4 rehearsal used reasoning instead of observation (see 1). 5.1.9 item 3
  already names the tray as a WinWright case, so the rule existed and I did not follow it. (b) The background Android
  build task stayed open for about 11 hours. `build-with-secrets.ps1 -StartEmulator` auto-selected the first AVD in
  the list, `Nexus_5X_API_29_x86`, which does not boot. The script printed its error and reached `exit 1` at 23:46.
  The task did not end until I restarted the adb server the next morning. The cause is unknown: my first guess (the
  adb server holding the task's output pipe) did not reproduce (IMP-2b below). (c) I asked questions again
  after Harold had answered them (see 6a).

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. The F294 migration moved 62 platform checks behind one seam, with a policy
  test that fails on any new bare check. Builds were serialized, and only docs were edited while builds ran. Each open
  risk is named with what settles it: (a) R-2, the new-mail trigger has never fired on a real phone. The Task 17 line
  in the first 0.21.0 Fold log settles it. (b) R-4, `MainActivity` was created twice at boot on 10-07. The cause is
  unknown, and from now on the Task 17 `launch:` part records the start reason. (c) Gmail on the closed-test phones
  expires every 7 days (F301).

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready. Phase 8 carries three items: read the Fold `new-mail-diagnostics` line after
  the 0.21.0 release; see CI green on Flutter 3.47.4 on PR #490; re-derive the 0.21.0 release notes at 7.7. Backlog
  candidates for the next scope selection: F301 (Gmail 7-day), F300 (WinWright sweep time), and the iOS cards once
  Harold decides to go ahead with iOS.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sound. `PlatformCapabilities` and `PlatformPolicy` are now the one place where a
  platform difference is kept (ADR-0049). ADR-0050 declares iOS's two behavior exceptions before any iOS code exists.
  The Windows tray now resolves its icon from the exe folder, like every other bundled asset, and not from the current
  directory. A test keeps the `<queries>` list and `MAIL_APPS` equal.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: None as carry-ins. The two items in my draft (the build script's AVD choice and
  adb pipe, and observation in the 5.1.9 record for native UI) are proposed below as IMP-1 and IMP-2 for Harold's
  decision.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: None new. F301 was added at Manual Validation (Harold Q3 = 1). Two unexplained
  observations (the first start after install wrote no log lines; R-4) are proposed below as IMP-5, a Phase 8 check,
  not as cards.

**Questions to be discussed before ending the sprint (Harold)**: none

## Completeness Validation (Phase 7.3/7.4 exit gate)

- 14 of 14 categories present; each has the combined PO/SM/Lead line (3 roles) and the Claude line (4th role).
- No placeholder text. Harold's words recorded verbatim.
- Category 13: no carry-ins. Category 14: no backlog additions (F301 was already added at Manual Validation).
- **7.4.1 Architecture compliance**: the sprint's code matches ADR-0049 (seam), ADR-0050 (iOS exceptions, no iOS code
  yet), ADR-0044 (new-mail trigger) and ADR-0019 (tray). Two `ARCHITECTURE.md` gaps were found and fixed in this
  commit: the `WindowsSystemTrayService` row now names the exe-folder icon path and `popUpContextMenu()` (Task 16),
  and the "Scan when new mail arrives" paragraph now describes the `new-mail-diagnostics` line and the `<queries>`
  list kept equal to `MAIL_APPS` (Task 17).

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 A native UI step is rehearsed by looking at it, and the record names what was seen**
   - **Root Cause**: the MV-4 rehearsal accepted tests and an unchanged code block as proof that the tray icon was
     present. 5.1.9 item 3 already sends the tray to WinWright, but the `Record` bullet accepts any "how", so a
     reasoned rehearsal reads the same as an observed one.
   - **Proposed Solution (prevention first, extending the connected 5.1.9 rule)**: the 5.1.9 `Record` bullet in
     `SPRINT_EXECUTION_WORKFLOW.md`, and the 5.1.9 line in `SPRINT_CHECKLIST.md`, add one sentence. For a step whose
     expected result is a native OS surface (tray icon or menu, window, notification, toast, native dialog), the
     `Rehearsed:` line names the observation: the UIA element found, or the screenshot path. A test or a code read is
     not accepted for that step. No new gate: the F193 gate already requires the 5.1.9 marker.
     - **1.1 (optional)**: add one tray-presence assertion to the launch step of an existing WinWright sweep script, so
       the 5.1.5 sweep catches a missing tray icon in every sprint that runs it. Effort about 30-45 minutes; not yet
       checked that the notification area is reachable from that script's session.
   - **Effort**: about 10 minutes (1.1: 30-45 minutes more).
   - **Impact**: a missing native element is found before handover, not by Harold.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.9), `docs/SPRINT_CHECKLIST.md`; for 1.1, one script
     under `mobile-app/test/winwright/` (to be named after reading the sweep runner).

2. **IMP-2 `build-with-secrets.ps1 -StartEmulator` picks a bootable AVD, and its exit ends the caller's task**
   - **Root Cause**: (a) with no `-EmulatorName`, line 688 takes `$availableAvds[0]`. That is the first name in the
     list, `Nexus_5X_API_29_x86`, which does not boot on this machine. (b) After `exit 1`, the background task stayed
     open about 11 hours. The likely cause, not proven, is the adb server that the script's first `adb` call started:
     it inherits the task's output pipe and keeps it open.
   - **Proposed Solution (extending the script's existing AVD choice and adb start code, not a new tool)**: (a) with no
     `-EmulatorName`, choose the AVD with the highest API level, read from each AVD's `config.ini`
     (`image.sysdir.1`). This rule is generic, not a machine-specific name. (b) First confirm the pipe cause by a
     reproduction: run the script in the background with no emulator and see whether the task ends at `exit 1`. If
     confirmed, start the adb server detached (`Start-Process adb start-server`) before the first `adb devices`, so it
     never holds the caller's pipe. If not confirmed, record the cause as unknown and change only (a). A `-SelfTest`
     switch asserts the AVD choice on sample `config.ini` files.
   - **Effort**: about 45-60 minutes.
   - **Impact**: a background build fails in about 1 minute with a readable error, not after a night.
   - **Files to Update**: `mobile-app/scripts/build-with-secrets.ps1`.

### Medium Priority (Next Sprint)

3. **IMP-3 A question carries what it decides, and a fact Harold declares standing is not asked again**
   - **Root Cause**: three Sprint 80 questions came back. (a) R-2 was asked again after Harold had said it was on.
     (b) R-6 named a screenshot but not the screen, its title or what to look for. (c) The ADR decisions named files,
     not what each ADR decides.
   - **Proposed Solution (extending the CLAUDE.md "PLAIN NUMBERED LIST" and "RE-PRESENT them in full" rules)**:
     - **3.1** Each decision question states, in 1-3 lines, what is being decided and what each option does. A file
       name or card number alone is not enough.
     - **3.2** A step that asks Harold to look at something names the screen, its title and the exact item to find.
     - **3.3** When Harold says a condition is standing ("it is on and will remain on"), record it in the plan's MV
       section under "Standing facts (Harold)", with his words. A re-presented list drops any question that a standing
       fact answers.
   - **Effort**: about 15 minutes.
   - **Impact**: fewer round trips; Harold is not asked twice.
   - **Files to Update**: `CLAUDE.md`.

4. **IMP-4 A step fact that can change before Harold's run is written as a change, or read again at handover**
   - **Root Cause**: Sprint 79 IMP-1 made the rehearsal read each fact from the live system, and it did (10-19). The
     facts then changed before Harold ran the steps on 10-21 and 10-22: he added 2 rules (2202 -> 2204), and a safe
     sender removed the named Review row.
   - **Proposed Solution (extending the same 5.1.9 "Facts in a step" bullet)**: a count or row that Harold or the
     app can change between the rehearsal and his run is written as a change ("note the count; expect one more") or
     as a rule for choosing ("any row in Review"), not as a fixed value. If a fixed value is needed, read it again in
     the same turn as the handover.
   - **Effort**: about 10 minutes.
   - **Impact**: a step stays true across the days between handover and validation.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.9), `docs/SPRINT_CHECKLIST.md`.

### Low Priority (Future)

5. **IMP-5 The Phase 8 Fold-log read also checks the first start after the update**
   - **Root Cause**: on the emulator, the first start after the install wrote no log lines (cause unknown). If a Play
     update does the same, the first 0.21.0 Fold start may have no `new-mail-diagnostics` line, and that could read
     as a Task 17 failure.
   - **Proposed Solution (extending the existing Phase 8 next action, no card)**: the `sprint_status.json` Phase 8
     line says to look for the line from the first start AND a later start. If the first start is missing on the Fold
     too, open a backlog card then, with the evidence. R-4 is already covered by the `launch:` part of the same line.
   - **Effort**: about 5 minutes.
   - **Impact**: a missing first-start line is not taken as a Task 17 failure, and the cause gets phone evidence.
   - **Files to Update**: `.claude/sprint_status.json` (Phase 8 next action).

## Improvement Decisions

Harold, 2026-10-22, verbatim: *"do now imp-1 and 1.1, imp-2a and b, imp-3, imp-5 - why imp-4? How many times has
this happened, what is the long-term benefit"*

- **IMP-1 Native UI steps rehearsed by looking** -- APPLIED. `SPRINT_EXECUTION_WORKFLOW.md` 5.1.9 gains the "Native
  OS surfaces are rehearsed by looking" bullet; the `SPRINT_CHECKLIST.md` 5.1.9 line carries the same rule.
- **IMP-1.1 Tray check in the sweep** -- APPLIED. `run-winwright-tests.ps1`: `Test-TrayIconAppears` runs first in every
  sweep (a FAIL fails the sweep) and alone with `-TrayCheckOnly`. It passes only when a tray button with a NEW UI
  Automation runtime ID appears after a fresh start, so a production instance or a stale icon cannot pass it; it
  stops only the window instance, never a running background scan. Evidence: live PASS (0 buttons before, new
  button after); `mutation-test.ps1` IMP11-M1 (wrong name) and IMP11-M2 (no window) KILLED. M1 first SURVIVED: the
  ID list was piped as one item and always read as "new"; fixed and re-run. Not caught: the right-click menu (the
  Task 16 second defect), which needs cursor input; the README and 5.1.9 name the screenshot rehearsal for it. Not
  run: a full sweep (it takes over the laptop); the sweep calls the same function. README updated.
- **IMP-2a Bootable AVD choice** -- APPLIED. `build-with-secrets.ps1`: with no `-EmulatorName`, the AVD with the
  highest API level (`config.ini` `image.sysdir.1`, else `<name>.ini` `target`); the emulator binary is resolved
  through `ANDROID_HOME` (PATH found the 2017 launcher in `tools\` first). Evidence: `-SelfTest` 4/4 PASS; on this
  machine it now picks `pixel34_updated` (API 34) over `Nexus_5X_API_29_x86`; IMP2-M1 and IMP2-M2 KILLED.
- **IMP-2b adb pipe** -- REPRODUCED, NOT CONFIRMED; no change, as the proposal stated. Two background repros on
  2026-10-22 both ended at their `exit 1` at once: (1) `adb kill-server`, `adb devices` (a new server), `exit 1`;
  (2) the script's own `Start-Process emulator -avd Nexus_5X_API_29_x86`, `adb devices`, `exit 1`. The cause of the
  11-hour open task is **unknown**. What would settle it: the process tree of the next background task that stays
  open after its script prints an error (`Get-CimInstance Win32_Process` with ParentProcessId). With IMP-2a the
  script no longer starts the AVD that failed.
- **IMP-3 Questions carry what they decide; standing facts are not asked again** -- APPLIED. `CLAUDE.md`: two
  sub-bullets under the numbered-list rule (3.1, 3.2) and one under the re-present rule (3.3). `SPRINT_80_PLAN.md`
  gains "Standing facts (Harold)" with the R-2 statement.
- **IMP-4 Changeable step facts written as changes** -- SKIPPED (Harold, "d1 1"). CORRECTION to the answer that
  decision was based on: Claude said both steps still passed with no round lost. MV-1 did pass. MV-3 did NOT run as
  written: its named Review row was gone (plan "MV-3 NOT SHOWN by the step"), which cost one question to Harold (Q6)
  and a log check before it passed on field evidence. Harold was told and confirmed, verbatim: *"1. skip until we see
  this problem again in a future sprint"*. Trigger to re-propose: a step fact that changed between rehearsal and
  Harold's run costs a question or a round again.
- **IMP-5 Phase 8 checks the first and a later start** -- APPLIED. `sprint_status.json` Phase 8 next action.

### After the 7.7.1 final code reviews (Harold, 2026-10-23)

Harold, verbatim: *"Based on the increasing number of PR review findings, it would seem that retrospectives and
suggested improvements should come after the PR reviews are completed - in order to find suggested improvements
that would prevent them from occurring (improved sprint cards, checklist gates...)"*. Claude's check of the record:
the 7.7.1 lines show 19, 17 and 24 findings in Sprints 78-80 (high every sprint rather than rising fast), most from
silent-failure-hunter (9, 15, 16) and most of one class, and the 5.1.2 F-PRECHECK silent-failure class reported
"clean" in Sprint 80 before the hunter found 16.

- **Q3 Final code reviews before the retrospective** -- APPLIED (Harold "q3 1", from Sprint 81).
  `SPRINT_EXECUTION_WORKFLOW.md` gains the "Phase 7 order" block, and 3.3.1, 6.x, 7.7, 7.7.1 and 7.7.5 now set the
  PR ready when Manual Validation completes; `SPRINT_CHECKLIST.md` and `CLAUDE.md` match. The findings feed the
  retrospective by class (every recurring class gets a 7.5 prevention proposal), and a 7.7.1 improvement review
  covers the retrospective's own commits. Prevention: `verify-closeout-complete.ps1` check 3d-2 now requires the
  7.7.1 line to record the improvement review from Sprint 81 (hook cases allow-11 and violation-14; suite 138/138).
- **Finding 16 (IMAP UID fallback)** -- BACKLOG F302, Sprint 81 (Harold "q1 2 OK to add a seperate field for
  sequence number and if no UID mark the UID field with a standard value to indicate there is no valid UID for the
  amil record").
- **Finding 9, Android half (Kotlin diagnostics)** -- BACKLOG F303, Sprint 81 (Harold "q2 1"). Correction: the Q2
  option 2 text said the cause "now reaches the log"; it does not -- a Kotlin failure returns null and the cause goes
  to logcat only, which adb policy blocks on the phones. F303 records this.
- **Q4 Four suggestions from the hsbc repository's agent** -- APPLIED (Harold "q4 1", from Sprint 81), with Claude's
  additions:
  1. The PR stays DRAFT until the 7.7.5 gate. The 7.7.1 reviews run on the draft. Standing fact (Harold): Copilot
     reviews can be requested by hand on a draft PR.
  2. "Recurring" is defined: two or more findings in the sprint share a class, or the class appears in an earlier
     sprint's 7.7.1 line. A single finding of a new class gets its root cause written down; an improvement is
     optional.
  3. The 7.7.1 improvement review is ONE pass. Its findings are fixed if small enough (Q5); otherwise they go to the
     next sprint's Phase 1 refinement. Its fixes are not reviewed again.
  4. At 7.7.5: `gh pr ready`, then CI green on that HEAD, then the readiness announcement. This order is required
     because `ci.yml` skips draft PRs (Sprint 62). Toolkit review prompts name the excluded files (`0*` at the repo
     root, `archive/`).
  Updated: `SPRINT_EXECUTION_WORKFLOW.md` (Phase 7 order, 3.3.1, 6.x, 7.7, 7.7.1, 7.7.5), `SPRINT_CHECKLIST.md`,
  `CLAUDE.md`, the hook messages in `verify-closeout-complete.ps1` and `require-sprint-cards.ps1`.
- **Q5 Improvement-review fix limit** -- under 4 code files AND under 600 lines, the same as the 7.7.1 limit
  (Harold "q5 2").
- **Q6 CI on draft PRs** -- OPEN. Harold said CI runs on drafts; `ci.yml` lines 20, 45 and 88 skip them
  (`if: github.event.pull_request.draft == false`) and 5 Sprint 80 runs show "skipped".
