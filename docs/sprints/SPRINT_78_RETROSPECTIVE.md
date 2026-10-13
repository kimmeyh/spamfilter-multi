# Sprint 78 Retrospective

**Sprint**: 78 -- one MyEmailSpamFilter folder, "Scan every" redesign, Review No Rule Items on the Results pieces,
mouse-free WinWright sweep, dev-only content history (0.19.0)
**PR**: #470 (feature/20261009_Sprint_78 -> develop)
**Date**: 2026-10-13
**Manual Validation**: complete (Harold: "Manual Validation complete"; W1-W4 PASS; W3 re-check after MV-1/2/4 PASS;
further phone testing moved to Sprint 79 by Harold: "push any further testing to next sprint")

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own.

## Sprint 78 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective. All planned code tasks (F282, F281, F283, F284, R76-4, F199-b) were done
  on 2026-10-10 in about 2.5 hours of wall time, and all four Windows validation steps passed on the first try. That
  is the first sprint under the 5.1.9 rehearsal rule, and it worked: Sprint 77 lost three rounds to failed steps.
  Manual Validation found six changes (MV-1 to MV-4, MV-6, MV-7), all fixed with tests in about 30 minutes after
  diagnosis. Less efficient: the Fold work did not finish. Steps 8-11 and F277 move to Sprint 79, and the overnight
  F277 run cannot be used (three accounts were on, see 10).

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong at unit and widget level. The suite grew from 2,990 to 3,009 tests, and every
  mutation was KILLED (F282-M1..M4, R764-M1..M4, F284-M1..M3, and MV-1, MV-2 x2, MV-3, MV-4, MV-6, MV-7 x4). Two gaps.
  (a) MV-4: the search text had been hardcoded black since an older "Issue 2b" change. `text_contrast_test.dart`
  measures grey shades against white only, so black text on a dark surface passed it. (b) MV-7 and MV-6 were visible
  in the Fold logs for days (558 AOL scans in 3.4 days) and were found only when Harold noticed the scan rate. No tool
  reads the pulled logs for scan health. The WinWright sweep must run again: MV-1 to MV-4 changed `lib/ui` after the
  sweep head b1e5d7b.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Planned code work ran far under the estimate. The plan said 1,010-1,545 minutes;
  the commits show planned implementation from 10:16 to 12:53 on 2026-10-10 (with one Sonnet sub-agent in parallel),
  plus planning on 2026-10-09/10. The real miss: **no `CODING_VELOCITY.md` row was written for Sprint 78**, and the
  `Executed-by` lines name the model but no minutes. Sprint 77 IMP-3 said actuals are never left empty, but its gate
  (3d-3) only checks that the line is not empty, and the velocity check (3b-2) runs only at close-out. So the actuals
  will be reconstructed from commit times, which is weaker data.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. Four read-only audit agents gave file:line evidence. The decision questions
  were answered before approval, and R76-4 was reshaped to dev-only before any code. One gap: the phone tasks (1 and 2)
  depended on Harold's overnight windows, and the plan did not list their preconditions in a form checked before a run
  starts. This is why the F277 run had three accounts on.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: One interactive Opus 5.5 session ran most tasks, under the recorded single-session
  deviation (a). A Sonnet sub-agent did the F284 tooling half in parallel. ADR-0047 and the F281 research ran on the
  top tier, as assigned. No escalations.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Mostly good. Decisions were asked as numbered lists, and an ambiguous answer ("at 90
  days") got one clarifying question. Two misses. (a) Harold asked me to hold the changes until his feedback was
  complete, and I started a full-suite run anyway. He stopped it. (b) I gave the F277 one-account reminder after he
  said the run was already set up. The reminder had to come before the run.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. Harold's verbatim statements (parity, prevention first, the R76-4 Class-1
  approval and its dev-only reshape) were quoted at the top of the plan. The MV-5 audit settled the meaning of the
  Review list ("all unaddressed emails AND that do not have current rules"). Harold then chose retention alone, so no
  code change was needed.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0047 accepted; ADR-0039 and ADR-0042 amended; `ARCHITECTURE.md` and `CHANGELOG.md`
  updated with each change, the MV-7 Doze rule included. The F281 research is in the repo. Drift to fix at 7.7: the
  plan header still reads "DRAFT -- awaiting Phase 3.7 approval", and the velocity rows are missing (see 3).

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) Effort actuals were not recorded at task completion, although Sprint 77 IMP-3
  was meant to stop this. The gates check too late (close-out) and too little (a non-empty line). (b) Field defects sat
  in pulled logs without being read for health. (c) Phone-run preconditions were stated, not checked before the run.
  (d) The MV-6 cause included an older code comment, `background_scan_core.dart:435`, that said the row closes as
  `error`. The status did change, but `completed_at` was never set, so the card still read "In progress". This is the
  existing "verify the mechanism a comment asserts" rule; nothing new is proposed.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good on the planned risks. R76-4 can capture only in dev builds, deletion gaps were
  closed (R7), and the F283 rebuild kept the Results suite unchanged. Risks carried to Sprint 79: (1) MV-7 is tested
  on the host only and is not yet seen on a phone; it ships in 0.19.0. (2) The Gmail `invalid_grant` on the Fold has an
  unverified cause (possibly the Google "Testing" refresh-token expiry). (3) The 0xc0000409 crash did not recur during
  W3.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready. The carry-ins are listed under 13. F286 (notifications), F288 (git-flow) and
  F289 (remaining WinWright mouse steps) are already in the backlog.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sound. One export folder rule for every writer (F282). One set of list pieces and
  one pop-up are shared by Results and Review (F283), so MV-1, MV-2 and MV-4 fixed both screens at once. One
  `RulesReadyGate` stops a rule reload from rebuilding the app root (MV-3). The Doze alarm and the periodic worker no
  longer both scan inside one interval (MV-7, recorded in ADR-0039 and `ARCHITECTURE.md`).

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: Harold's move of further testing to Sprint 79: Fold steps 8-11 (Step 9 needs
  Notification access; iCloud background on if it should be covered); F277 three runs on 0.19.0 with one account on;
  MV-7 on the phone; the Gmail `invalid_grant` cause; Android parity of F281, F282 and F283 on 0.19.0.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue
number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: None new. F289 was created during Manual Validation.

### Questions to be discussed before ending the sprint

- **Product Owner / Scrum Master / Lead Developer (combined)**: none

## 7.4.1 Architecture Compliance Check

- Sprint code against `ARCHITECTURE.md`: export folders (F282), "Scan every" (F281), the shared Results/Review pieces
  (F283), content history (R76-4) and the MV-7 Doze rule were already described. Two gaps, fixed now: the app-root
  `RulesReadyGate` (MV-3) was not described anywhere, and the `scan_results.completed_at` note did not say a failed
  scan sets it (MV-6).
- `docs/ARSD.md`: no statement about these features, so nothing became wrong. ADRs: ADR-0047 Accepted; ADR-0039 and
  ADR-0042 amended in this PR; ADR-0045 unchanged (MV-5 withdrawn). No change diverged from approved architecture.

## Summary

Harold rated all 14 categories Very Good, with no carry-ins, backlog items or questions. The rehearsal rule from Sprint
77 worked: W1-W4 passed on the first try. Manual Validation produced six changes, all fixed with mutation-checked
tests. Claude's feedback names four misses: effort actuals not recorded at task completion; field defects left unread
in pulled phone logs; phone-run preconditions stated but not checked; and a dark-text defect that the contrast gate
could not see. Testing on the phone moves to Sprint 79.

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 Actuals are written when the task finishes, and the gate checks there**
   - **Root Cause**: Sprint 77 IMP-3 gated the `Executed-by` line at close-out and accepts any non-empty text. Close-out
     is the latest possible point, and a model name with no minutes passes.
   - **Proposed Solution (prevention first, extending the connected gates)**: (a) extend the F193 evidence gate in
     `sprint-auto-advance.ps1`, which already requires the Phase 5 markers at the Manual Validation boundary, so it also
     requires a `CODING_VELOCITY.md` row for this sprint before handover; (b) extend close-out check 3d-3 so each
     `Executed-by` line must contain a minutes figure (`~NNm` or `NN min`). Instance fix: add the Sprint 78 rows,
     reconstructed from commit times and marked as reconstructed.
   - **Effort**: about 40 minutes, plus a violation case and an allow case per gate.
   - **Impact**: the estimate table gets real data every sprint; the miss is caught days earlier.
   - **Files to Update**: `.claude/hooks/sprint-auto-advance.ps1`, `.claude/hooks/verify-closeout-complete.ps1`,
     `.claude/hooks/test-cases/`, `docs/CODING_VELOCITY.md`, `docs/sprints/SPRINT_78_PLAN.md` Executed-by lines.

2. **IMP-2 Every phone pull prints a scan-health summary**
   - **Root Cause**: the logs that showed MV-7 (558 AOL scans in 3.4 days) and the three-account F277 run were pulled
     and stored, but only read when Harold asked a question.
   - **Proposed Solution (extend the existing pull tool)**: after copying, `scripts/pull-phone-screenshots.ps1` reads
     the newest `diag_*.log` files and prints per account: completed scans per hour, scans closer together than half
     the interval, scans that started and never finished, errors, and the triggers seen. A fixture log test proves it
     flags a double-scan pattern.
   - **Effort**: about 45 minutes.
   - **Impact**: MV-7 would have shown at the first 0.18.0 pull on 2026-10-09, and the F277 run problem at the first
     overnight pull.
   - **Files to Update**: `scripts/pull-phone-screenshots.ps1` (or a helper it calls), a fixture log and its test.

### Medium Priority (Next Sprint)

3. **IMP-3 Phone runs start only after their preconditions are seen**
   - **Root Cause**: the 5.1.9 rehearsal covers Windows steps. Phone steps were handed over with preconditions in text,
     and nothing confirmed them before an 8-hour run.
   - **Proposed Solution (extend 5.1.9)**: for each phone step, Claude reads the last pulled log and screenshots to
     confirm the preconditions, such as which accounts have background on and whether Notification access is granted.
     A long run starts only after Harold sends one screenshot of each account's Background tab, and Claude confirms it.
     The Sprint 79 F277 card gets this check.
   - **Effort**: about 15 minutes (workflow text, checklist line, F277 card).
   - **Impact**: no lost overnight runs.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` 5.1.9, `docs/SPRINT_CHECKLIST.md`, the Sprint 79 F277 card.

4. **IMP-4 The contrast gate also catches theme-blind black text**
   - **Root Cause**: `text_contrast_test.dart` checks grey shades against white only. The hardcoded black search text
     (MV-4) passed it in dark mode.
   - **Proposed Solution (extend the existing gate)**: a `TextStyle` in `lib/ui` with a hardcoded `Colors.black`,
     `black87` or `black54` text color fails unless an exemption names the fixed light background behind it. Today one
     text site remains: `rule_test_screen.dart:635`, black87 on an amber highlight, which gets an exemption. The gate
     gets a self-check, and a mutation proves it fails.
   - **Effort**: about 25 minutes.
   - **Impact**: the next dark-text defect fails the build, not Manual Validation.
   - **Files to Update**: `mobile-app/test/policy/text_contrast_test.dart`.

### Low Priority (Future)

None.
