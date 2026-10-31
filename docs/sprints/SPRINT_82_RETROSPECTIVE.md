# Sprint 82 Retrospective

**Sprint**: 82 -- F314 Gmail cursor after evaluation, F312 / F315 counts first, F305 signals and F306 first No Rule
suggestion, F319 No Rule refresh from a notification, F317 agent restart safety, F318 toolkit file list, F320 WinWright
No Rule coverage, F303 Fold diagnostics (MV), iPhone Tasks 1-3 (blocked on Apple enrollment) (0.23.0)
**PR**: #521 (feature/20261027_Sprint_82 -> develop), DRAFT until 7.7.5
**Date**: 2026-10-31
**Manual Validation**: complete (Harold: "Manual Validation complete"; MV-1, MV-1b and MV-1c PASS after the
notification-click fixes; MV-2 PASS; MV-3 and MV-4 moved to Sprint 83; MV-5 waits on Apple enrollment)

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own. The 7.7.1 final code reviews
ran before the retrospective, so their findings are grouped by class below and every recurring class has a prevention
proposal.

## 7.7.1 findings by class

Reviews: Copilot "No open issues" (0 comments). silent-failure-hunter 2 High / 6 Medium (1 unverified) / 3 Low;
code-reviewer 0 High / 3 Medium / 3 Low. Two findings were found by both (F314 cursor, PowerShell 7 lock age), so 15
distinct findings. Fixed: 579f2195 (12 findings), 21575189 (M-5, Harold Q4 = 2). Harold's decisions: M-4 -> F306 v2
backlog (Q1 = 4), M-6 -> Sprint 83 with an MV step (Q3 = 3). "Recurring" = two or more this sprint, or in an earlier
sprint's 7.7.1 line.

- **A. A failure that reaches only the console, or nothing** (recurring: 6 this sprint; Sprint 81 class A, Sprints
  78-80): H-1 F314 store failure moved the Gmail cursor anyway; H-2 tap registration failures console-only; M-1
  main.cpp registry write result ignored; M-3 build-script process listing failure ignored; L-1 cursor-save catch;
  L-3 status script stopped on one unreadable file. Four of the six are in C++ or PowerShell. The Sprint 81 IMP-1
  5.1.2 question ("where does the USER learn of this?") was asked of the Dart diff only. -> IMP-1.
- **B. Text that promises a mechanism the code does not deliver** (recurring: 2; Sprint 70 IMP-2, Sprint 74 IMP-2,
  Sprint 81 class B): the F314 doc comment, ARCHITECTURE row and release notes claimed "results stored first" while
  the F314 test header NAMED the gap; my MV-1 rehearsal line claimed the click hand-off from the plugin API without
  tracing its source. -> IMP-2.
- **C. Windows PowerShell 5.1 versus PowerShell 7** (recurring: 2 this sprint): `.Count` on a single CimInstance in
  5.1 (my own build regression during MV); `ConvertFrom-Json` turns ISO strings into dates in 7 (M-2, lock age read
  -240 minutes). No repo check runs a helper under both shells. -> IMP-3.
- **D. Input that means "could not check" becomes destructive advice** (recurring: Sprint 46/49 BUG-DECODE class):
  M-4, F306 suggests Block Entire Domain on a temperror or permerror. -> IMP-4.
- **Single findings** (root cause written, improvement optional):
  - WinWright exact-name selectors broke when F306 changed a button's accessible name (code-reviewer M-3). Root cause:
    the label change was not swept against `test/winwright/`. Fixed with `name^=`.
  - The DEV toast registration ran in Debug builds (code-reviewer L-1). Root cause: the Dart sibling's release-only
    guard was not mirrored in C++.
  - The hourly wake-up could advance a Harold-driven phase (code-reviewer L-2). Root cause: the prompt was written for
    the 3.7-5.3 window only.
  - The iOS reversed client ID was checked for presence, not form (L-2).
  - `handleTap` popped every route, including an unsaved form (M-5). Root cause: the MV-1 fix tested navigation, not
    its neighbors (CLAUDE.md "what does it do to its NEIGHBOURS"). Fixed, cautious check.
  - Which process gets a click when the worker and the UI both register (M-6): unverified, Sprint 83 MV step.
  - US English: "neighbour" in a test name.

## Own-process slips (input to Category 9)

- **E. Python with backslashes run inline** (recurring: Sprints 72, 74, 75, and twice in one turn this sprint): one
  heredoc was blocked by the hook; one `python -c` was not covered by the hook and was stopped only by its own anchor
  assert. -> IMP-5.
- **F. Clock times written from memory** (recurring: six wrong times in messages and records this sprint; Sprint 70
  footer): the footer script fixed the footer line; times inside the body still came from memory. -> IMP-6.
- **G. Effort rows and Executed-by lines written at the gates, not at task completion** (recurring: Sprint 81 Cat 3,
  this sprint): the close-out hook caught 13 missing Executed-by lines. -> IMP-7.

## Sprint 82 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: The planned work landed fast: five Sonnet agents ran in parallel, and most tasks
  finished far under their bands (F306 ~55 minutes against 180-300). The waste was in Manual Validation. MV-1 failed in
  Harold's hands because my rehearsal line asserted a mechanism I had not verified, and two Windows builds failed
  during the fix, one of them my own regression. That cost about three validation rounds.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Mutation discipline held: every new test was mutation-checked (F306 18/18, MV-1
  5/5 and 3/3, 7.7.1 fixes 4/4, M-5 5/5; one M-5 mutant first SURVIVED and tightened its test). The gap was in what
  the tests chose to assert: the F314 test header NAMED the silent-persist gap and nothing acted on it. A named gap is
  a finding, not a disclaimer (IMP-2). No test runs a PowerShell helper under both shells, and both shell defects
  passed through for that reason (IMP-3). Suite 3,356 passed / 15 skipped / 0 failed; analyzer clean.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Bands were again far too high for agent-run tasks (5 Sonnet tasks: ~185 minutes
  actual against 465-870 planned). The unplanned Manual Validation fixes (~120 minutes) and the 7.7.1 fixes (~60
  minutes) are the real cost driver and were in no band.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: The cards were complete, but the MV-1 step was written from the plugin's API, not
  its source; the click path was never traced (Sprint 75 IMP-5). MV-3 and MV-4 needed a Play build that could not
  exist inside the sprint; the plan should have marked them next-sprint at approval.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sonnet agents for Tasks 5, 8, 9, 10 and 12 worked; each needed only a short lead
  review (one surviving mutant, Task 9 M5, closed by the lead). Seven tasks ran in the main session instead of their
  assigned tier because they were Harold-interactive or short; each Executed-by line records why.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Decisions were numbered with evidence and every practical option (Sprint 81
  IMP-7), and the 7.7.1 questions were answered in one round. Miss: six wrong clock times inside messages and records,
  all corrected from the clock or git (class F, IMP-6).

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. One gap: the F306 card said a YELLOW verdict gets a suggestion but did not
  say which YELLOW verdicts are evidence (a temperror is "could not check", not "failed"). That gap is finding M-4
  (class D, IMP-4).

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ARCHITECTURE and CHANGELOG were kept current, but the F314 row stated a guarantee
  the code did not keep until the 7.7.1 fix (class B). CODING_VELOCITY rows and Executed-by lines were written late,
  at the gates (class G).

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Own slips: (1) the MV-1 rehearsal claimed an unverified mechanism (class B);
  (2) Python with backslashes run inline twice in one turn (class E); (3) a re-added iCloud account silently lost its
  background setting, and only the log said so (Sprint 81 IMP-1 class, found from Harold's report, not by a gate);
  (4) the 5.1.2 silent-failure question was not asked of the PowerShell and C++ changes (class A).

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Two risks were caught before harm: the F312 probe's HEADER.FIELDS fetch returned a
  silent zero, which I caught and switched to full headers; the build swap could delete `data\`, now guarded. Open
  risks, each with what settles it: the Store toast click (the installed MSIX, 8.3 owner step); the two-process click
  (M-6, Sprint 83 MV step).

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sprint 83 inherits MV-3 and MV-4 (Fold), the M-6 MV step, the 8.3 Store toast
  check, a rebuilt 0.23.0 AAB (the current one predates the MV-1 and 7.7.1 fixes), and Apple enrollment R6QG2A9SHS
  (Tasks 1-3).

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Notification tap handling is a declared ADR-0042 exception (window raise) with
  parity navigation, now guarded against discarding input (M-5); iOS has no Darwin settings yet. The DEV-only
  `LocalServer32` is a Windows-only registration with a policy gate. `completeScan` now returns whether the results
  were stored, and the Gmail cursor moves only then. No ADR change was needed.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: MV-3 and MV-4 as Sprint 83 Manual Validation; the M-6 MV step (click account 1's
  notification while the worker scans, Harold Q3 = 3); the 8.3 Store toast click check; the 0.23.0 AAB rebuild.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: F306 v2 gains two items from Harold's decisions: no suggestion, or a "could not
  check" note, for a temperror or permerror (M-4, Q1 = 4); and a sender-name-shape suggestion when one shape spans
  many new domains (Q5 = 2; DEV evidence: `news_` plus 4-6 digits, 2,225 emails from 102 domains, all AOL Bulk, none
  in the Inbox, none a safe sender). New item: a user-visible notice when a re-added account has background scanning
  off. Numbers assigned at 7.7.

**Questions to be discussed before ending the sprint (Harold)**: none

## Completeness Validation (Phase 7.3/7.4 exit gate)

- 14 of 14 categories present; each has the combined PO/SM/Lead line (3 roles) and the Claude line (4th role).
- No placeholder text. Harold's words recorded verbatim.
- Category 13: four carry-ins. Category 14: the F306 v2 additions and one new item, numbered at 7.7.

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 The 5.1.2 silent-failure walk covers every language in the diff** (class A)
   - **Root Cause**: Sprint 81 IMP-1 added "where does the USER learn of this?" to 5.1.2, and it was applied by
     reading the Dart diff. Four of the six class A findings were in PowerShell and C++, where a failure hides as
     `-ErrorAction SilentlyContinue`, `2>$null`, an ignored return code or an empty `catch`.
   - **Proposed Solution (extending the 5.1.2 F-PRECHECK class 6 and its checklist line)**: 5.1.2 runs one listed
     search over the changed files of every type (`.dart`, `.ps1`, `.cpp`, `.yml`) for `catch`, `SilentlyContinue`,
     `2>$null`, `|| true` and Win32 calls whose result is not read, and the card records each hit with "the user
     learns of it from <screen and text>" or "need not know, because <reason>". The search pattern lives in the
     workflow so it is copied, not remembered.
   - **Effort**: about 20 minutes.
   - **Impact**: the largest recurring class is found before Manual Validation, in every language.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2), `docs/SPRINT_CHECKLIST.md`.

2. **IMP-2 A test's "does NOT catch" note that contradicts a promise blocks the promise** (class B)
   - **Root Cause**: the F314 test header named the gap ("a failed store still moves the cursor"), while the doc
     comment, ARCHITECTURE row and release notes promised the opposite. The note was treated as a disclaimer. The MV-1
     rehearsal line likewise stated a mechanism without evidence.
   - **Proposed Solution (extending Sprint 70 IMP-1 and Sprint 77 IMP-1)**: (2.1) at 5.1.2, every "does NOT catch"
     note written this sprint is compared with the card's ACs, the ARCHITECTURE row and the CHANGELOG line; a note that
     names a behavior those texts promise is a finding, fixed or the text narrowed in the same commit. (2.2) Each
     5.1.9 rehearsal line cites its evidence (a test name, a screenshot file or a command output); a line with no
     evidence is marked NOT REHEARSED, never PASS.
   - **Effort**: about 15 minutes.
   - **Impact**: a named gap cannot ship as a promise, and an MV step cannot be handed over on reasoning alone.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2, 5.1.9), `docs/TESTING_STRATEGY.md`.

3. **IMP-3 Repo PowerShell helpers are tested under both shells** (class C)
   - **Root Cause**: the repo runs scripts under Windows PowerShell 5.1 (hooks, `powershell -File`) and PowerShell 7
     (the PowerShell tool). Both defects behaved correctly in the shell they were written in.
   - **Proposed Solution (extending `.claude/hooks/run-test-cases.ps1`)**: the hook suite runs every case under both
     `powershell` and `pwsh` and reports a case that differs. At 5.1.2, a changed repo `.ps1` is run once under each
     shell (the probe command goes in the card).
   - **Effort**: about 30-45 minutes.
   - **Impact**: a shell difference is found by the suite, not by a failed build or a negative lock age.
   - **Files to Update**: `.claude/hooks/run-test-cases.ps1`, `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2).

4. **IMP-4 A suggestion or signal card names the inputs that mean "could not check"** (class D)
   - **Root Cause**: the F306 card listed the verdicts that trigger a suggestion but not the ones that mean the check
     failed to run, so a temperror read as evidence. The same shape was the Sprint 46/49 decode class.
   - **Proposed Solution (extending the Sprint 81 IMP-2 "Signal fires on" card line)**: the line becomes "Signal fires
     on: <input>, N of M DEV rows. Inputs that mean 'could not check': <list>; for these it shows <nothing / a
     could-not-check note>."
   - **Effort**: about 10 minutes.
   - **Impact**: no destructive advice from an unreadable input.
   - **Files to Update**: `docs/SPRINT_PLANNING.md` (card template), `CLAUDE.md` (Sprint 81 IMP-2 bullet).

5. **IMP-5 The backslash hook also blocks `python -c`** (class E)
   - **Root Cause**: `block-heredoc-python-backslash.ps1` covers heredocs; an inline `python -c "..."` with
     backslashes has the same failure and is not covered.
   - **Proposed Solution (extending that hook and its test cases)**: block `python -c` / `py -c` when the code
     argument contains a backslash; the message names the scratchpad-file route. Two new test cases (block and
     allow); run the hook suite.
   - **Effort**: about 20 minutes.
   - **Impact**: the class is blocked mechanically, as the heredoc form already is.
   - **Files to Update**: `.claude/hooks/block-heredoc-python-backslash.ps1`, `.claude/hooks/test-cases/heredoc-guard/`.

### Medium Priority (Next Sprint)

6. **IMP-6 A clock time in a message or record comes from the clock in the same turn** (class F)
   - **Root Cause**: the footer is generated by a script; times in the body (velocity rows, MV notes, "at 12:56")
     were written from memory.
   - **Proposed Solution (extending the Status Footer rule)**: any clock time written in a reply, commit or record is
     read with `Get-Date` in the same turn; a time not read is written as "time not recorded".
   - **Effort**: about 5 minutes.
   - **Impact**: no wrong times in the record.
   - **Files to Update**: `CLAUDE.md`, memory `feedback_timestamp_footer.md`.

7. **IMP-7 The effort row and the Executed-by line go in the task's closing commit** (class G)
   - **Root Cause**: CODING_VELOCITY Rule 4 says "at completion", and nothing checks it until close-out, so rows were
     rebuilt from commit times in Sprints 81 and 82.
   - **Proposed Solution (extending `verify-closeout-complete.ps1` check 3d with an earlier, lighter check)**: a
     PreToolUse check on `git commit` whose message carries `Closes #N` or "Task N" warns when
     `docs/CODING_VELOCITY.md` is not staged. Warn, not block, so a partial commit is still possible.
   - **Effort**: about 30-45 minutes (hook plus test cases).
   - **Impact**: actuals are recorded when they are known.
   - **Files to Update**: a new `.claude/hooks/` check and its test cases, `.claude/settings.json`.

### Low Priority (Future)

None.
