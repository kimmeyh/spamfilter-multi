# Sprint 82 Retrospective -- Claude Code Development Team DRAFT

**[CLAUDE-AUTHORED DRAFT]** Written at Phase 7.3 Step 2, 2026-10-31, while Harold writes the Product Owner,
Scrum Master and Lead Developer feedback. This file holds only the Claude Code Development Team role. It is input
for Step 3 (combine) and is never a substitute for Harold's feedback.

## 7.7.1 findings by class (input to Categories 2 and 9)

Reviews: Copilot 0 findings; silent-failure-hunter 2 HIGH, 6 MEDIUM (1 unverified), 3 LOW; code-reviewer 0 HIGH,
3 MEDIUM, 3 LOW. Two findings were found by both toolkit reviewers (F314 cursor, PowerShell 7 lock age), so there are
15 distinct findings.

- **Silent failure: the failure reaches only the console, or nothing** (6: F314 store failure H-1, tap registration
  H-2, main.cpp registry write M-1, build-script process listing M-3, cursor-save catch L-1, status script L-3).
  RECURRING: the largest class in Sprints 78-81 too. The 5.1.2 F-PRECHECK silent-failure class did not catch them.
- **A text promises a mechanism the code does not deliver** (2: the F314 comment, ARCHITECTURE row and release notes
  claimed "results stored first" while the test header named the gap; my MV-1 rehearsal line claimed the click
  hand-off). RECURRING (Sprint 70 IMP-2, Sprint 74 IMP-2).
- **Windows PowerShell 5.1 versus PowerShell 7 behavior** (2: `.Count` on a single CimInstance in 5.1, my own build
  regression; `ConvertFrom-Json` dates in 7, M-2). RECURRING within this sprint.
- **Unreadable input becomes destructive advice** (1: F306 suggests Block Entire Domain on a temperror/permerror,
  M-4). RECURRING by an earlier sprint (Sprint 46/49 BUG-DECODE class).
- **Single findings** (root cause written, improvement optional):
  - WinWright exact-name selectors broke when F306 changed a button's accessible name (code-reviewer M-3). Root cause:
    the label change was not swept against the WinWright scripts.
  - The DEV toast registration ran in Debug builds (code-reviewer L-1). Root cause: the Dart sibling's release-only
    guard was not mirrored in C++.
  - The hourly wake-up could advance a Harold-driven phase (code-reviewer L-2). Root cause: the prompt was written for
    the 3.7-5.3 window only.
  - The iOS reversed client ID was checked for presence, not form (L-2).
  - `handleTap` pops every route, including an unsaved form (M-5); decision pending.
  - Which process gets a click when the worker and the UI both register (M-6); unverified.
  - US English: "neighbour" in a test name.

## Sprint 82 Retrospective Feedback (Claude Code Development Team role only)

### 1. Effective while as Efficient as Reasonably Possible

- **Claude Code Development Team**: The planned work landed fast: five Sonnet agents in parallel, most tasks far under
  their bands (F306 ~55 min against 180-300). The waste was in Manual Validation. MV-1 failed in Harold's hands because
  my rehearsal line asserted a mechanism I had not verified, and two Windows builds failed during the fix, one of them
  my own regression. That cost about three validation rounds.

### 2. Testing Approach

- **Claude Code Development Team**: The mutation discipline held: every new test was mutation-checked (F306 18/18,
  MV-1 5/5 and 3/3, 7.7.1 fixes 4/4). The gap was in what the tests chose to assert. The F314 test header NAMED the
  silent-persist gap and nothing acted on it; a named gap is a finding, not a disclaimer. No test runs a PowerShell
  helper under both shells, and both shell defects passed through for that reason.

### 3. Effort Accuracy

- **Claude Code Development Team**: Bands were again far too high for agent-run tasks (5 Sonnet tasks: ~185 min
  actual against 465-870 planned). The unplanned Manual Validation fixes (~120 min) and the 7.7.1 fixes are the real
  cost driver and were not in any band.

### 4. Planning Quality

- **Claude Code Development Team**: The cards were complete, but the MV-1 step was written from the plugin's API, not
  its source; the click path was never traced (Sprint 75 IMP-5). MV-3 and MV-4 needed a Play build that could not
  exist inside the sprint; the plan should have marked them next-sprint at approval.

### 5. Model Assignments

- **Claude Code Development Team**: Sonnet agents for Tasks 5, 8, 9, 10, 12 worked; each needed only a short lead
  review (one surviving mutant, Task 9 M5, closed by the lead). Seven tasks ran in the main session instead of their
  assigned tier because they were Harold-interactive or short; each Executed-by line records why.

### 6. Communication

- **Claude Code Development Team**: I wrote six wrong times in messages and records this sprint, all corrected from the
  clock or git. The footer script fixed the footer; the times inside the body still came from memory.

### 7. Requirements Clarity

- **Claude Code Development Team**: The F306 card said YELLOW gets a suggestion but did not say which YELLOW verdicts
  are evidence (a temperror is "could not check", not "failed"). That gap is finding M-4.

### 8. Documentation

- **Claude Code Development Team**: CODING_VELOCITY rows and the Executed-by lines were written late, at the gates,
  not at task completion (Rule 4; the close-out hook caught the Executed-by lines). ARCHITECTURE and CHANGELOG were
  kept current, but the F314 row stated a guarantee the code did not keep until the 7.7.1 fix.

### 9. Process Issues

- **Claude Code Development Team**: Three own-process slips: (1) the MV-1 rehearsal claimed an unverified mechanism;
  (2) I ran Python from a heredoc with backslashes twice in one turn (the hook blocked one, an anchor check stopped the
  other); (3) a re-added iCloud account silently lost its background setting, and only the log said so (Sprint 81
  IMP-1 class, found from Harold's report, not by a gate).

### 10. Risk Management

- **Claude Code Development Team**: Two risks were caught before harm: the F312 probe's HEADER.FIELDS fetch returned a
  silent zero, which I caught and switched to full headers; the build swap could delete `data\`, now guarded. The
  open risk is the Store toast click, which only the installed MSIX can prove (8.3 owner step).

### 11. Next Sprint Readiness

- **Claude Code Development Team**: Sprint 83 inherits MV-3 and MV-4 (Fold), the 8.3 Store toast check, a rebuilt
  0.23.0 AAB (the current one predates the MV-1 fix), and Apple enrollment R6QG2A9SHS (Tasks 1-3).

### 12. Architecture Maintenance

- **Claude Code Development Team**: Notification tap handling is a declared ADR-0042 exception (window raise) with
  parity navigation; iOS has no Darwin settings yet. The DEV-only LocalServer32 is a Windows-only registration with a
  policy gate. No ADR change was needed.

### 13. Minor Function Updates for the Next Sprint Plan

- **Claude Code Development Team**: MV-3 and MV-4 as Sprint 83 Manual Validation; the 8.3 Store toast click check; the
  0.23.0 AAB rebuild; the 7.7.1 decisions on M-4 (temperror suggestion), M-5 (pop on tap) and M-6 (two-process click),
  if Harold chooses next sprint.

### 14. Function Updates for the Future Backlog

- **Claude Code Development Team**: F306 v2 (Block Body and the split row, Harold Q2 = 3); a user-visible notice when a
  re-added account has background scanning off; a both-shells test harness for repo PowerShell helpers.
