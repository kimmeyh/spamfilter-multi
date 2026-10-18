# Sprint 79 Retrospective

**Sprint**: 79 -- phone checks on 0.19.0, per-account background-scan notifications on both platforms (F286, F287),
locked-PC sweep (F291), git-flow (F288), full-suite runner (F292), backlog presentation (F293), reload after a YAML
import (F297), workmanager 0.10.10 (0.20.0)
**PR**: #480 (feature/20261013_Sprint_79 -> develop)
**Date**: 2026-10-18
**Manual Validation**: complete (Harold: "Manual Validation complete"; MV-1 PASS, four toasts one per account with
replacement; MV-2 PASS, "no rules 116"; phone checks after the 0.20.0 release, Q9 = 2)

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own (Step 2 draft, updated with two
facts found while writing this file: the DEV task trigger has read PT5M since 10-12, and Sprint 78 IMP-3 was skipped).

## Sprint 79 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective. Tasks 0 and 3-9 were delivered in full, and the in-sprint part of Task 1.
  Harold moved the phone remainders of Tasks 1, 2 and 7 to Sprint 80 on 10-16. Both Manual Validation steps passed
  on the first round. The worker stop line now fires, proven on the emulator (`reason=timeout raw=3`). Less
  efficient: Task 1 took about 310 minutes against 60-110, mostly the WorkManager stop-handler hunt, and part of that
  hunt went the wrong way: I told Harold that plugin versions 0.10.7-0.10.9 did not fix the wrong-thread defect, from
  the changelog alone. The plugin source showed that 0.10.9 does fix it.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong at unit level. The suite reached 3,061 passed, 0 failed through
  `run-full-suite.ps1`. Mutations were killed for F286, F287, F297, the stop-reason naming and the scheduler note (N3
  first SURVIVED; extending the source gate killed it). The 5.1.9 rehearsal found the DEV app's toast setting off,
  which became a precondition, so MV-1 passed first time. Gaps: (a) the rehearsal proved behavior but not the step
  TEXT: the MV-1 step said the DEV tasks run every 20 minutes. Their trigger has read every 5 minutes (PT5M) since
  10-12, and an earlier edit had changed a correct 5 to the wrong 20, source unknown. (b) The s75 WinWright launch
  failed once in the full sweep and passed alone; cause unknown (candidate: the single-instance mutex).

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Mixed. Seven of nine task rows are inside or under their bands (Tasks 0, 3, 4, 5,
  6, 8, 9). Task 1 was far over (~70 + ~240 against 60-110): the band covered recording phone results, not two fixes
  and a plugin defect hunt with three emulator builds. Tasks 2 (~40) and 7 (~70) are inside their bands but partial.
  The rows were written at Phase 5, not as each task finished, so the Sprint 78 IMP-1 gate blocked the first Manual
  Validation handover (3 of 9 cards had rows). The gate worked; the habit it backs did not.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good for the code cards: each was decided before approval, and none needed a scope
  question during execution. Weak for the phone-night cards, the same gap Sprint 78 named. The F277 arms depended on
  the AOL interval, which nothing compared with the planned arm before each night. The planned Night C ran as arm B,
  and the planned arm A night ran at interval 5. Only 10-17/18 was a true arm A. Harold skipped Sprint 78 IMP-3 (the
  screenshot-before-each-run check), so the cost here was two nights, not a new decision.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: One interactive Opus session ran most tasks, as in Sprints 77-78. A Sonnet agent did
  one read-only trace (R-9, about 3 minutes). No escalations. The top tier was justified for the stop-handler diagnosis
  (plugin source, thread model, AndroidX numbering) and more than the doc and velocity rows needed.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Decisions were asked as numbered lists (Fix, Upgrade), and the MV steps were
  re-presented in full. Misses: (a) the unverified plugin claim (see 1), corrected in the plan, the commit and to
  Harold; (b) the MV step's 20-minute interval; (c) the first MV handover was blocked by the Stop hook (see 3), so it
  reached Harold one cycle late. "mv-2 (phone)" was ambiguous, and I asked instead of guessing.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. The parity rule was quoted at the top of the plan and applied per card: F287
  uses the same notifier and text as Android, with a declared exception only where the OS differs. The mid-sprint
  answers (move to backlog, Fix = 1, Upgrade = 1) were unambiguous.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0048 (supersedes ADR-0018), ADR-0039 (renamed `recentScanShouldSkip`, the
  periodic skip and `skipAfterWait`) and `ARCHITECTURE.md` (skip rules, IMAP command timeouts, `reloadFromDatabase()`)
  were updated before Manual Validation. CHANGELOG entries were added per fix. The master plan holds F298, F299 and
  the Sprint 80 targets. Gap: `pull-phone-screenshots.ps1` skips Samsung Settings screenshots
  (`Screenshot_..._Device care.png`, `_Settings.png`), so the 10-18 battery evidence needed a second, custom pull.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) Velocity rows written at Phase 5, not per task (see 3). (b) An external-system
  claim (plugin behavior) made from a secondary source, the CLAUDE.md "open it before claiming it" class again. (c) An
  MV step statement (the interval) that the rehearsal did not read from the system it describes. (d) An unreachable D:
  drive stopped work once; Harold reconnected it.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. The workmanager upgrade (0.10.6 to 0.10.10) ran with the full suite and an
  emulator check, as Harold asked. The diagnostic pub-cache hold was restored with SHA-256 verification. The DEV tasks
  were disabled during each DEV build. The 0.10.9 30-second Dart-initialization watchdog is a new risk, held by F299.
  Fix 2 (native debug hook) waits on the phone result, by Harold's decision.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready. Sprint 80 carries F277 arm A (one 4.2-hour night recorded) and arm C, the
  decision rule and the unexplained 0.3% versus 1.5% B-night spread; the MV76-1 phone remainder; F292 post-reboot runs;
  F298; F299; and the Fix 2 decision after the 0.20.0 phone test. Cards #471, #472, #433 and #428 stay open.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sound. One completion notifier serves both platforms (ADR-0048). One shared provider
  reload serves every YAML import path. AndroidX stop reasons are named by one helper that does not trust the plugin's
  enum. The scheduler line now carries a note when the Doze alarm did not arm or cancel, so a partial failure no
  longer reads "ok".

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: None beyond the Sprint 80 carries in 11. The two small tooling fixes I found (the
  screenshot pattern, MV step facts) are proposed below as improvements instead.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: None. F298 and F299 are already in the master plan.

**Questions to be discussed before ending the sprint (Harold)**: none

## Completeness Validation (Phase 7.3/7.4 exit gate)

- 14 of 14 categories present; each has the combined PO/SM/Lead line (3 roles) and the Claude line (4th role).
- No placeholder text. Harold's words recorded verbatim.
- Category 13: no carry-ins. Category 14: no backlog additions.
- **7.4.1 Architecture compliance**: the sprint's code changes match ADR-0048, ADR-0039 (Sprint 79 amendment) and
  `ARCHITECTURE.md` as updated at 5.2.3; no gap found.

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 Every fact in an MV step is read from the system it describes, during the rehearsal**
   - **Root Cause**: 5.1.9 rehearses a step's BEHAVIOR (the toast appeared) but not its stated FACTS (interval,
     counts, paths). The 20-minute interval was never read from Task Scheduler, which said PT5M.
   - **Proposed Solution (prevention first, extending the connected 5.1.9 rule)**: the 5.1.9 text in
     `SPRINT_EXECUTION_WORKFLOW.md` and `SPRINT_CHECKLIST.md` adds: every number, interval, path or count in a step
     is read from the live system during the rehearsal, and the step's `Rehearsed:` line names where (for example
     "interval PT5M: Get-ScheduledTask"). No new gate: the F193 gate already requires the 5.1.9 marker, and the
     source names make a missing read visible in review.
   - **Effort**: about 10 minutes.
   - **Impact**: a wrong fact in a step is caught before handover, not by Harold.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.9), `docs/SPRINT_CHECKLIST.md` (5.1.9 line).

2. **IMP-2 The phone pull collects Samsung Settings screenshots**
   - **Root Cause**: the default DCIM pattern allows no suffix plus one exception (`_One UI Home`, Sprint 78). Samsung
     names Settings captures for the Settings screen (`_Device care`, `_Settings`), which hold the F277 battery
     evidence, so the default pull skipped them.
   - **Proposed Solution (extending the existing exception list, not a new tool)**: `$exactScreenshot` becomes
     `^Screenshot_\d{8}_\d{6}(_One UI Home|_Device care|_Settings)?\.png$`, with the header and comment updated. Other
     apps' screenshots stay excluded (Harold's Sprint 77 rule). A small `-SelfTest` asserts 4 names in and
     `_Instagram` / `_Chrome` out, so a later edit cannot widen or break the list silently.
   - **Effort**: about 20 minutes.
   - **Impact**: battery screenshots arrive on the normal pull; no second search.
   - **Files to Update**: `scripts/pull-phone-screenshots.ps1`.

### Medium Priority (Next Sprint)

3. **IMP-3 A claim about a dependency's behavior cites its source at the resolved version**
   - **Root Cause**: the plugin claim came from the changelog, a secondary source, while the source was in the pub
     cache.
   - **Proposed Solution (extending the existing CLAUDE.md "Before claiming what an EXTERNAL system contains" rule)**:
     add the Sprint 79 instance and one line: a claim about a package's behavior cites `file:line` in the pub-cache
     source of the version `pubspec.lock` resolves; a changelog is a lead, not evidence.
   - **Effort**: about 10 minutes.
   - **Impact**: fewer wrong turns in plugin diagnosis.
   - **Files to Update**: `CLAUDE.md`.

### Low Priority (Future)

4. **IMP-4 Write the velocity row in the task's final commit**
   - **Root Cause**: rows were written at Phase 5; the Sprint 78 IMP-1 gate caught it at the MV boundary.
   - **Proposed Solution**: none new. The gate worked and cost one cycle. Recommendation: **skip**; reconsider if it
     recurs in Sprint 80.
   - **Effort**: 0.
   - **Files to Update**: none.

Not re-proposed: the phone-run precondition check (Sprint 78 IMP-3, skipped by Harold). It would have saved the two
F277 nights noted in 4; it stays Harold's call.

## Improvement Decisions

Harold, 2026-10-18: *"1"* (apply IMP-1, IMP-2 and IMP-3 now; skip IMP-4).

- **IMP-1 MV step facts read from the live system** -- APPLIED. `SPRINT_EXECUTION_WORKFLOW.md` 5.1.9 gains a
  "Facts in a step" rule (each stated number, interval, path, name or count is read live and its source named on the
  `Rehearsed:` line); `SPRINT_CHECKLIST.md` 5.1.9 line carries the same sentence.
- **IMP-2 Phone pull collects Samsung Settings screenshots** -- APPLIED. `pull-phone-screenshots.ps1`: the default
  pattern adds `_Device care` and `_Settings` to the `_One UI Home` exception (other apps stay skipped); the pattern
  moved above `param()`-dependent code, and a new `-SelfTest` checks 4 names collected and 4 skipped. Self-test PASS;
  mutations KILLED: the old pattern (drops the two Settings names) and an any-suffix pattern (admits `_Instagram`,
  `_Chrome`, `_Settings_extra`). File restored byte for byte under a mutation lock.
- **IMP-3 Dependency claims cite the source at the resolved version** -- APPLIED. `CLAUDE.md` "Before claiming what an
  EXTERNAL system contains" gains the Sprint 79 instance and the `file:line`-in-pub-cache rule.
- **IMP-4 Velocity row in each task's final commit** -- SKIPPED (Harold; Claude's recommendation). Reconsider if it
  recurs in Sprint 80.
