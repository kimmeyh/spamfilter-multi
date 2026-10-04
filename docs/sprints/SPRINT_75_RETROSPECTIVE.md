# Sprint 75 Retrospective

**Sprint**: 75 -- F238, F216, F214, F236, F239, F215, Task 7 carry-ins; F243 added at Manual Validation
**Branch / PR**: `feature/20261002_Sprint_75` -> `develop`, PR #448 (draft until Phase 7.7)
**Version**: 0.17.0+8 (no bump -- exception: no Store release after Sprint 74)
**Manual Validation**: COMPLETE (Harold, 2026-10-03)

Harold's feedback below is VERBATIM from his combined Product Owner / Scrum Master / Lead
Developer response ("Very Good" in every category; none for categories 13-14; no questions).

## Sprint 75 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Effective -- all approved work shipped, plus four Manual Validation fixes and F243 the same day. Less efficient than it looked: about 110 min of review rework, two shell commands that hung waiting on stdin (a bare `cat >`), a JSON spec whose backslashes a bash heredoc ate, and an Android install that failed three times on script defects before the APK it had built could be installed.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Strong where it ran end to end (real screens over real databases; a native integration test against the built exe; every new test mutation-checked -- M71-M115). Two weak spots: (1) twice a mutant that did not COMPILE was reported KILLED (M80, M96 as first written) -- `mutation-test.ps1` judges only the exit code; (2) the cheaper-tier agent's tests needed rework -- one did not compile, one passed vacuously (no slider rendered). The new tests also earned their keep: the refusal test caught a half-wired fix (`showLiveRefusal` gated the row but not its parent block).

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Planned tasks came in at or under estimate (F238 ~45 of 180-300 min via agent; F239 ~240 of 240-480). The unplanned share was large again -- the 5.1.1 review fixes (~110 min), F243 (~90 min) and four MV fixes -- consistent with the Sprint 70 finding that review and rework are a predictable line item.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The cards held up; R-6 (stop if the spike fails) did exactly its job. Planning missed one pre-flight: the spike needed a Google account on the emulator, which was absent ("Accounts: 0"); that cost a Manual Validation round.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Fable (F238) and Sonnet (F216, Task 7 widget tests) delivered clean, mutation-checked work and flagged their own judgment calls. The Haiku batch (F214/F236/F215) needed about 35 min of rework: a non-compiling test, a vacuous test, a Windows/Android parity defect in F236, and a session-specific path in a script. The difference tracked the delegation prompt more than the model: the Sonnet prompt spelled out "mutation-check, name what it does not catch".

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Question 1 (Windows background sign-in) took three rewordings before it was answerable -- I described the mechanism, not what Harold would SEE. Plain before/after wording worked first time.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Clear. F243 arrived as one sentence at Manual Validation and was turned into a full card with the per-account scope stated as the assumption; Harold's "the same that is done after adding AOL and Yahoo" was precise enough to implement by reusing the same code path.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0011 and ADR-0039 amendments, ARCHITECTURE, CHANGELOG and plan evidence kept current per commit. Two documented claims were wrong until review: ADR-0011 claimed six identical rules the code did not keep, and ADR-0039's Manual Validation recipe used Test Background Scan, which runs in-process on Windows.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: (1) The heredoc guard caught three Python heredocs, but a bash heredoc writing a JSON spec still lost its backslashes -- the guard covers Python only. (2) A bare `cat >` waited on stdin twice. (3) The WinWright sweep and the full suite run concurrently lost 16 test files at load -- the rule is now "never together". (4) F243's side effect on the test harness (background scans running, and being killed, during the sweep) was found only at the fourth sweep.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Good: the spike was gated (R-6) and R-2 stayed off until proven, the v11 migration ran on a hash-verified backup, and every Class-1/3 change was surfaced. Missed: the 5.1.1 review found a HIGH (the per-folder catch swallowed the NEW sign-in exception) -- the same swallow class the Sprint 73 rule names; I applied that rule when REMOVING a pattern but not when ADDING an exception type.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Ready. 0.17.0 release follows this sprint (Harold's hold decision); phone checks (MV74-1/3, F238/F239 on device) move to Sprint 76 per Q3 at approval. Backlog gained F244, F245, F246.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: F243 removed a Windows-only behavior (the foreground deferral) and brought Windows to Android's model -- one fewer ADR-0042 divergence. Account-add now has ONE finish path for every provider (`_finishAccountAdded`). DB v11 added one nullable column with a guarded migration.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: None beyond the already-planned Sprint 76 phone checks (recorded in the Sprint 75 plan).

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: Already added during Manual Validation on Harold's decisions -- F244 (notify on a needs-sign-in skip), F245 (no duplicate No Rule rows from repeated background scans), F246 (server-side Gmail token exchange for Android background renewal). No further items.

## Summary

Every planned item shipped and validated. F243 (Windows background scans while the app is open) and four Manual Validation fixes were added and validated the same day. The F239 renewal spike failed and was stopped as planned. Harold rated every category Very Good. The Claude-side lessons cluster in three places: verification tools that report success they did not prove (compile-failed mutants counted as KILLED; WinWright runs not isolated from background scans), shell mechanics (stdin-waiting `cat`, backslash-eating heredocs beyond Python), and two rules applied in only one direction (the swallow-class grep when adding an exception; MV recipes not traced to the code they test).

## Improvement Recommendations

Harold's decision (Phase 7.5, 2026-10-04): **"do now: imp-1, 2, 3, 4, 5, 6"** -- all six implemented this sprint. Each one prevents first and extends an existing control.

### High Priority (Implement Now)

1. **IMP-1 -- a compile failure was counted as "caught"**
   - **Root Cause**: `scripts/mutation-test.ps1` judged only the check's exit code; M80 and M96 (as first written) did not compile and were reported KILLED.
   - **Proposed Solution**: run each check once on the unchanged code first (`BASELINE FAILS` if red); keep the check's output and report a Dart/C++ compile error as `INVALID` (fails the run).
   - **Effort**: ~30 min. **Impact**: a KILLED now means a test caught a behavior change.
   - **Files to Update**: `scripts/mutation-test.ps1`, CLAUDE.md (the promoted-script bullet).
   - **DONE**: self-test of all four verdicts on real cases -- KILLED (M84), SURVIVED (comment-only), INVALID (M80's original form: `.dart:337:10: Error:`), BASELINE FAILS (`cmd /c exit 1`).

2. **IMP-2 -- heredoc corruption beyond Python; a stdin-waiting `cat`**
   - **Root Cause**: the guard covered Python heredocs only; a JSON spec written through a `cat` heredoc lost every `\\`; a bare `cat > file` waited on stdin twice.
   - **Proposed Solution**: extend `block-heredoc-python-backslash.ps1` -- block any heredoc body with a DOUBLE backslash, and a bare `cat >` with no input. Single backslashes (Windows paths in commit messages) stay allowed.
   - **Effort**: ~30 min. **Files**: the hook, 5 new cases in `test-cases/heredoc-guard/`, CLAUDE.md.
   - **DONE**: hook suite 91/91 (86 + 5); M116 (bare-cat block disabled) and M117 (double-backslash block disabled) KILLED.

3. **IMP-3 -- the swallow-class walk must also run when ADDING an exception**
   - **Root Cause**: the Sprint 73 rule fired only when removing a pattern; F239's new exception was swallowed by the per-folder catch (review H-1).
   - **Proposed Solution**: extend the CLAUDE.md Sprint 73 bullet: list every catch between a new throw site and its handler, in the card.
   - **Effort**: ~10 min. **DONE**: CLAUDE.md.

4. **IMP-5 -- Manual Validation steps traced to the code they test**
   - **Root Cause**: two wrong recipes (Test Background Scan is in-process on Windows; the app was open and the setting off).
   - **Proposed Solution**: extend the Sprint 74 IMP-2 bullet (user-visible text) to MV steps: state preconditions, confirm the step reaches the code.
   - **Effort**: ~10 min. **DONE**: CLAUDE.md.

### Medium Priority

5. **IMP-4 -- tooling that launches or kills the exe counts as a "caller"**
   - **Root Cause**: F243 changed when the background process runs; the WinWright runner and pre-build cleanup kill every process of the exe -- found at the fourth sweep.
   - **Proposed Solution**: extend the card template's "Callers of any guard" field with a tooling line.
   - **Effort**: ~15 min. **DONE**: `docs/SPRINT_PLANNING.md` (augmented template).

6. **IMP-6 -- one delegation checklist in every coding sub-agent prompt**
   - **Root Cause**: the Haiku batch's prompt lacked the checks the Sonnet/Fable prompts spelled out; its output needed ~35 min of rework.
   - **Proposed Solution**: a six-item checklist beside the Model field (run tests, compiling mutation check, prove the test can fail, "does not catch" line, both platform paths, report judgment calls), plus a card line recording that it was included.
   - **Effort**: ~15 min. **DONE**: `docs/SPRINT_PLANNING.md`.

### Low Priority (Future)

None.
