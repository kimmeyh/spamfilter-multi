# Sprint 52 Retrospective

**Sprint**: 52
**Branch**: `feature/20260730_Sprint_52`
**Dates**: 2026-07-30 -> 2026-08-02
**Scope**: F133-S52, F131, F134, F135, F136, plus mid-sprint F134-ALL (SC-1) and F133-REMEDIATE (SC-2/SC-3)
**Issues**: #289, #290, #291

**Harold's feedback is recorded verbatim.** He wears the Product Owner, Scrum
Master and Lead Developer hats and supplied a single combined line per category;
that combined line is reproduced against all three roles as permitted by the
Phase 7.4 protocol. Claude Code Development Team lines come from
`docs/sprints/drafts/SPRINT_52_RETROSPECTIVE_claude_draft.md`.

---

## Sprint 52 Outcome

| Measure | Value |
|---|---|
| Commits | 16 |
| Files changed | 40 (+3,332 / -1,607) |
| Tests | 1,815 -> **1,828** passing, 0 failing, 29 skipped |
| Analyzer | Clean throughout |
| Windows build | Green |
| Manual Validation | **Complete** -- Harold, 2026-08-02 |
| Carry-forward | **None** |

**Delivered**: accessibility audit of all 27 screens + remediation (9/9 items),
canonical AppBar order repo-wide, session-scoped account selection with per-tab
Settings resolution, No-Rule default screen, Skip button, F131 root cause,
3 dead screens deleted (911 lines), 4 new/updated test gates.

**Found and fixed during Manual Validation**: MV-1 (Accounts icon reached
nothing -- an F134/F135 intersection defect), the Manual Scan icon gap, and
silent Refresh buttons on 4 screens.

---

## Sprint 52 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Scope roughly doubled mid-sprint (SC-1, SC-2, SC-3) and still landed. The efficiency loss I own is Task 2: I re-ran the two `test_f56_*` scripts that `run-winwright-tests.ps1:237` already documented as excluded, then read their known settle failure as new evidence. That was ~20 minutes re-deriving a fact the repo already recorded. The pattern -- not checking whether a failure is already known-and-documented before investigating it -- is worth naming.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The strongest part of the sprint, specifically because tests were verified to FAIL before being trusted -- four mutation checks (Skip `onTap`, Accounts `popUntil`, No-Rule silent refresh, contrast/AppBar gates). The clearest lesson was the Manage-Rules assertion: my first version ("some node has a label >2 chars") PASSED while being worthless, and only tightening it revealed my matcher was wrong. A green assertion that cannot fail is not coverage. The gap exposed: `appbar_action_order_test.dart` is a source-text gate, structurally incapable of catching MV-1 where the handler itself went nowhere.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two of the largest tasks ran low -- Task 4 ~95m (est 45-75), Task 7 ~165m (est 90-150) -- and Task 2 ran ~2x low (~70m vs 20-35m). The common factor: all three had hidden breadth discovered during execution (28 nullable-accountId sites, 27 screens instead of 8, five doc surfaces carrying a wrong claim). Estimates were accurate for the mechanical tasks (3, 5, 6) and low wherever the work involved finding out how much work there was.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The plan was sound for what it knew. What it did not know was that F134's acceptance criterion was repo-wide while its task listed 3 screens, and that F133's audit would find 5-of-27 Semantics coverage. AC-3 being repo-wide was knowable at planning time from the AC text alone, and I did not catch it. I also deviated on F135 R-1 on "large refactor" grounds, which Harold correctly rejected: "large" is not a stopping criterion, and Criterion 9 is a 400-hour threshold this sprint was nowhere near.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No escalation needed; Harold explicitly offered Fable 5 for complexity and it was not required. The work was breadth-heavy rather than depth-heavy -- many mechanical edits plus a few genuine diagnoses (F131 root cause, the MV-1 intersection). Opus handled both registers without a tier change.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold corrected my framing three times, each the same shape -- I reported a conclusion more narrowly or more confidently than the evidence supported. "Flagging and stopping are 2 different things" (I stopped when I should have flagged and continued); "again no need to stop, you replanned a task that had already been approved"; and MV-1, where I diagnosed "the No-Rule screen" from one screenshot until Harold's "have not found a screen where the icon is working" revealed it was global. What worked: surfacing deviations explicitly at Manual Validation rather than burying them.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold's steering was consistently precise and well-timed -- the Task 5 button reuse, the "all screens OR all screens except Manual Scan" pattern, the R-8 re-scope. Where I went wrong was not asking: I invented an opt-in design for the Manual Scan icon when the codebase already had ONE consistent pattern (default-on with self-referential suppression) that I could have read off the existing five actions.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Wrong findings were struck through rather than deleted across four documents. That was deliberate -- the F131 failure mode was a wrong fix recorded as verified, and deleting the evidence would have destroyed the lesson. Gap caught late: Sprint 52 had NO GitHub issue cards and NO CHANGELOG entries through six task commits; both belong at Phase 3 and were backfilled at the end of Phase 4.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two real ones, both mine. (1) **Phase 3 card creation was skipped entirely** -- I went from plan approval straight into execution, and six commits landed with no issue cards and no CHANGELOG entries, even though `sprint_status.json` explicitly states cards are created at Phase 3. (2) **Re-investigating a documented exclusion** (Task 2). Neither was caught by a hook.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The riskiest change was deleting 911 lines of screens. I verified dead THREE ways before asking -- class/filename search, zero test references, and the decisive one (the background-scan path never calls `runApp`, so the progress screen cannot render on any path). That was the right caution given a broken glob earlier in the same sprint produced a false "0 imports" result. The `git add -A` in two commits was sloppier than it should have been: it swept in `0Backlog Refinement.txt` -- correct per the `0*` rule, but by luck rather than intent.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Nothing carries forward. R-7 and R-8 were closed at Harold's direction before validation, so the F133 remediation set is 9/9. Issues #289/#290/#291 are open and accurate, `sprint_status.json` is current, and Sprint 52 is a clean handoff.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: `StandardAppBarActions` became a genuine single source of truth, and MV-1 proved its value -- the fix landed once and every screen got it. The `openManualScan` consolidation removed a platform-lookup duplication I had myself introduced one commit earlier. No ADR was required; `docs/ACCESSIBILITY_STANDARDS.md` extends ADR-0037 rather than superseding it, which was right for a standards doc.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: None. (Process improvements are carried in the Improvement Suggestions list below rather than as function updates.)

### 14. Function Updates for the Future Backlog

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: Two candidates, both Claude-side and neither urgent: (a) Tooling: a behavior-level AppBar gate that pumps each screen and asserts every action's handler NAVIGATES rather than asserting source text -- Medium, ~2h; (b) the five rule-editing screens carry no `accountId` so they cannot show Manual Scan/Settings/Accounts -- whether that is right is a product decision, not a defect -- Low.

---

## Summary

Sprint 52 delivered its approved scope plus two Harold-directed expansions that
roughly doubled it, and finished with nothing carried forward. All 14 categories
rated Very Good by the Product Owner, Scrum Master and Lead Developer.

**What went well**: the testing discipline. Four gates were mutation-verified --
proven to fail against the real defect before being trusted. That discipline
caught a worthless assertion of my own that had passed on incidental data.

**What the sprint exposed**: source-text gates verify shape, not behavior. The
AppBar order gate proved every screen called the shared builder and could not
see that the Accounts handler went nowhere. Manual Validation caught it instead,
which is the process working -- but a cheaper catch was available.

**Where I cost time**: skipping Phase 3 card creation (backfilled late),
re-investigating an exclusion the repo already documented, and reporting the
MV-1 diagnosis more narrowly than the evidence supported.

**Best decision**: striking through wrong findings instead of deleting them.
F131's real lesson was that a wrong fix recorded as verified is worse than no
note at all -- and that lesson only survives if the wrong note survives with it.

---

## Improvement Suggestions

Harold approved **all five** on 2026-08-02 ("all now"). All are applied.

| ID | Improvement | Disposition | Evidence |
|---|---|---|---|
| IMP-1 | **Behavior-level AppBar gate.** A widget test that presses every standard AppBar action and asserts the navigator stack changed, rather than asserting source text. | **APPLIED** | `mobile-app/test/ui/widgets/appbar_action_navigation_test.dart` (renamed from `accounts_icon_navigation_test.dart` once it stopped being Accounts-specific). Loops over all four navigating actions, so a future action is covered as soon as it appears. **Mutation-verified**: stubbing the Scan History handler to `() {}` fails it with "pressing 'View Scan History' must PUSH a route" -- i.e. it catches the MV-1 defect class on an action OTHER than the one that originally broke. |
| IMP-2 | **Phase 3 card-creation gate.** Block the first sprint task commit when the plan is approved but no issue cards are recorded. | **APPLIED** | New PreToolUse hook `.claude/hooks/require-sprint-cards.ps1`, registered in `.claude/settings.json`. Gated on `plan_approved` so pre-approval commits (the plan document itself) are NOT blocked -- a hook that fires on correct work trains people to route around it (the F130-S51 R-2 lesson). Bypass token `allow_no_cards`. 7 new harness cases; suite **34 -> 41, all passing**. |
| IMP-3 | **Check known-issues before investigating a failure.** Grep the runner/README/script header for the failing test name first. | **APPLIED** | New line in `CLAUDE.md` "Things Claude Should NOT Do". |
| IMP-4 | **No bare `git add -A` in sprint commits.** Stage explicit paths, or confirm `git status --short` first. | **APPLIED** | New line in `CLAUDE.md` "Things Claude Should NOT Do". |
| IMP-5 | **Read the existing pattern before designing a new member of a shared abstraction.** | **APPLIED** | New line in `CLAUDE.md` "Things Claude Should NOT Do". |

Two durable lessons were also written to memory rather than left in this
document, because they generalize beyond this sprint:

- `feedback_source_gates_verify_shape` -- source-text gates verify SHAPE, not
  BEHAVIOR; pair each with a test that presses the control.
- `feedback_mutation_verify_new_tests` -- prove a new test FAILS against the real
  defect before trusting it; be most suspicious of one that passes first run.

**Note on IMP-1's scope**: the retro proposed extending the existing
`verify-closeout-complete.ps1` for IMP-2. That was the wrong hook -- it is a
*Stop* hook firing at close-out, long after the six card-less commits would
already have landed. A PreToolUse gate on `git commit` is the only placement
that catches the problem when it happens rather than reporting it afterwards.
