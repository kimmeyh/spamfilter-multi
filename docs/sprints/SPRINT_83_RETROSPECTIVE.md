# Sprint 83 Retrospective

**Sprint**: 83 -- F322 scan notification choice, F323 F306 v2 (could-not-check, Block Body, news_ sender shape), F324
account settings and IMAP Sign In Again, F270 v1 suggested safe senders, F305 R-2 signal counts, F308 / F310 rule
mining, F309 research, F321 Python tooling pilot, F237, F325 static pass, MV-3 / MV-4 phone evidence (0.24.0)
**PR**: #534 (feature/20261031_Sprint_83 -> develop), DRAFT until 7.7.5
**Date**: 2026-11-05
**Manual Validation**: complete (Harold, 2026-11-04: "Manual Validation complete"; re-validation rounds 2 to 4 PASS;
F325 live run moved to F341)

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own. The 7.7.1 final code reviews
ran before the retrospective, so their findings are grouped by class below and every recurring class has a prevention
proposal.

## 7.7.1 findings by class

Reviews: Copilot COMMENTED, 3 inline (2 MEDIUM, 1 LOW). code-reviewer pass 1 (49 of 125 files read) and pass 2 (75 of
76 files read, closing the gap); silent-failure-hunter (49 of 52 production files read). One HIGH found by both (H-1).
Fix commits bab21526, 76f8a2bb, 4308c893, c1d9a2c6, d91ee027, d7168716, 4f9ffe5b; every guard fix mutation-checked,
all KILLED. Three decisions wait on Harold (Q1 to Q3). "Recurring" = two or more this sprint, or in an earlier
sprint's 7.7.1 line.

- **A. A second copy that drifts from the first** (recurring: 3 this sprint; Sprint 72 C-2b
  `_resolveEffectiveScanMode`): the account list's "Turn on" set the setting and scheduled by its own path, without
  the frequency and permission steps Settings runs (CR M-1, SFH M-2); the IMAP platform ids lived in two lists
  (`BackgroundScanCore`, `DataDeletionService`); the safe-sender miner built the BLOCK-rule regex shape instead of
  the safe-sender builder the app saves with (pass-2 F8). Sprint 72 IMP-5 put "Existing abstraction checked" on the
  card for a new MEMBER of a shared abstraction; none of these three was a new member. Each was a new CALLER or a new
  COPY. -> IMP-1.
- **B. Text that still describes the behavior before a Manual Validation change** (recurring: 8 this sprint;
  Sprint 82 class B): ARCHITECTURE v17 paragraph (news_ suggestion, body read), the 11-01 CHANGELOG news_ line,
  the 0.24.0 release notes still PROVISIONAL, ADR-0051 "Proposed" in three files after Harold accepted it, the F325
  status and cap, the Task 2 card channel names, the "green = DMARC pass" wording in four places, the F308 / README
  hand-deleted wording. Every MV answer that changed a name or a behavior was made in code and its tests; the text
  elsewhere that named the old thing was not searched. -> IMP-2.
- **C. A tool that reports success when it did nothing** (recurring: 5 this sprint; Sprint 69 F210, Sprint 82 class
  A): `test-hook.ps1` reported a crashed hook (exit 1, ALLOWED by Claude Code) as BLOCK, so `-ExpectBlock` passed a
  hook that was off (pass-2 F1 HIGH); `agent-work-status` reported an old session's scratchpad; `mutation_lock
  remove` printed nothing when it matched no lock; `rule_miner.ps1` silently ignored `-SentJsonl`; the notifier
  logged "posted" for a channel the user had turned off. -> IMP-3.
- **D. A test name that claims more than the test asserts** (recurring: 3 this sprint; Sprint 70 IMP-1): "absent
  for news_ with letters" had no news_ case (F6); "body and sender-shape rules never remove" asserted body only and
  the sender-shape half was false (F7); a layout test anchored on a comment (Copilot). -> IMP-1 (same checklist).
- **Single findings (root cause recorded, no improvement required)**:
  - H-1 Block Body on HTML-only mail: the pop-up reads `fetchContentText` (HTML as text) but the rule path reads
    text/plain only, so a Block Body rule from an HTML-only email cannot match that email. Root cause: the card
    fixed the pop-up's "Could not read message" and did not trace what the saved rule would be matched against.
    Decision pending (Q1).
  - SFH M-1 refused IMAP login repeated on every background run, CR M-3 pop-up logins counting toward the lockout:
    decision pending (Q2). Re-save clearing the lockout count: decision pending (Q3).
  - The Reset snackbar label overflowed by 90 px at 344 px: caught by the new widget test at the Fold cover width
    before commit. The narrow-width test rule worked as intended.

## Own-process slips (input to Category 9)

- The Copilot thread replies were not posted: the auto-mode classifier blocked the GitHub write. The text is ready.
- Three task velocity rows read "time not recorded" (Tasks 2, 4, 10): their agents ran across 5-hour and weekly
  usage-limit stops, and the start times were not kept. -> IMP-4.
- The full suite at 7.7.1 read 3,587 passed / 15 skipped / 8 failed. 5 of the 8 pass when run alone. The other 3
  (`windows_task_scheduler_service_test`) time out at 30 s because `Get-ScheduledTask` for a missing task took 7 to
  21 s on this machine at 02:40 to 03:30 with CPU at 4%. The service and its test are unchanged since Sprint 80
  (b00669e4). Cause of the slow query: unknown; re-timing it after a reboot settles it. Not a 7.7.1 regression.

## Sprint 83 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: 12 approved tasks ran as parallel Sonnet worktree agents and merged without a
  conflict; the agent progress files let every agent resume after the usage-limit stops without redoing work. Waste:
  the MV rounds 2 to 4 changed names and behavior, and the text describing the old behavior was found by the review,
  not swept at the change (class B).

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: every task merged with mutation-verified tests (for example F308 19 of 19, F310
  24 of 24, F270 24 of 24 KILLED), and every 7.7.1 guard fix was mutation-checked. The narrow-width widget test
  caught a real snackbar overflow. Gap: three tests had names their assertions did not support (class D), and the
  full suite's Task Scheduler tests depend on how fast this machine answers a CIM query.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: research and mining tasks ran well under their estimates (Task 8 ~14 of 60-90
  minutes, Task 6 ~26 of 60-90, Task 5 ~71 of 165-270); Task 3 (~167 of 120-240) and Task 7 (~133 of 180-300) were
  inside. Tasks 2, 4 and 10 have no actual: the time across usage-limit stops was not kept (IMP-4).

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: the cards held through execution; the scope changes came from Manual Validation
  answers (notification names, the news_ suggestion, the pop-up layout), which is where they belong.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Sonnet agents did all 12 implementation tasks; the main session (Opus) merged,
  rehearsed MV and ran 7.7.1. A Sonnet agent also did the four 7.7.1 doc findings correctly. No escalation was needed.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: the MV questions carried their evidence and options and were answered in one
  round each. Standing facts were recorded (the Play version on a phone screenshot, the production channel name).

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No issues -- expectations met. The one gap is H-1: the Block Body card did not
  state which body text the saved rule is matched against.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: 8 stale-text findings (class B), all fixed in d91ee027 and 4f9ffe5b; the release
  notes are re-derived and pass the 500-character gate (Play 479).

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: the Copilot replies are blocked by the auto-mode classifier (a GitHub write);
  the velocity actuals for three tasks were lost across usage-limit stops (IMP-4).

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: the Android channel rename was checked against production (0.23.x has only
  "Background Scans", which 0.24.0 deletes), so no user sees a renamed channel. Open risk: H-1, a Block Body rule
  that cannot match the HTML-only email it was made from, until Q1 is answered.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ready after Q1 to Q3 are answered and applied; F341 to F344 are carded.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0049 updated for the channel names; ADR-0051 accepted; ARCHITECTURE v17
  paragraph corrected (CR M-4); one shared IMAP id constant (`PlatformRegistry.imapPlatformIds`) and one
  background-enable path (`BackgroundScanEnabler`) replace copies.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: None

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: None beyond any 7.7.1 decision (Q1 to Q3) that Harold sends to the backlog.

## Completeness Validation (Phase 7.3/7.4 exit gate)

- [x] All 14 categories are present
- [x] Each category has all 4 roles
- [x] No line is empty or a placeholder
- [x] Category 13: none
- [x] Category 14: none (pending Q1 to Q3)

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 A second copy that drifts (class A) and test names that overclaim (class D)**
   - **Root Cause**: the Sprint 72 IMP-5 check fires for a new MEMBER of a shared abstraction. A new CALLER of an
     existing user action, or a new COPY of a constant set, triggers nothing. The 5.1.2 self-review does not read
     test names against their assertions.
   - **Proposed Solution**: two 5.1.2 self-review questions. (a) "For each new entry point to an existing user
     action, and each new list or set of ids, name the existing function or constant and show the new code calls
     it." (b) "Read each new test's name against its expect lines; a claim in the name with no assertion is a
     finding."
   - **Effort**: ~15 minutes
   - **Impact**: the three class A and three class D findings are caught before review.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2), `docs/SPRINT_PLANNING.md` (card template note).

2. **IMP-2 Text left behind by a Manual Validation change (class B)**
   - **Root Cause**: an MV answer that renames or changes a behavior is made in code and tests; no step searches for
     text that names the old thing. ADR status lives in three places with nothing tying them together.
   - **Proposed Solution**: (a) a policy test: each ADR file's Status word equals its row in `docs/adr/README.md`
     (mechanical; it would have caught F11). (b) Each MV answer that changes a name or a behavior records "Swept:
     grep '<old text>' -> N hits fixed" on its answer line.
   - **Effort**: ~40 minutes (test ~25, rule ~15)
   - **Impact**: removes the largest finding class of this sprint; (a) makes one part of it impossible.
   - **Files to Update**: new `mobile-app/test/policy/adr_status_consistency_test.dart`,
     `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.3 answers).

3. **IMP-3 A tool that reports success when it did nothing (class C)**
   - **Root Cause**: tool code is written for the case it was built for; the "nothing matched" and "unexpected exit"
     branches fall into a success message. 5.1.2's "where does the USER learn of this?" is asked of app code, not
     of scripts and hooks.
   - **Proposed Solution**: extend that 5.1.2 question to scripts, hooks and tools: "what does this print when its
     input matched nothing, or the call it made did nothing?" Every verdict mapping has an explicit default branch
     that reports an error (the `test-hook.ps1` switch is the model).
   - **Effort**: ~15 minutes
   - **Impact**: the five class C findings each fail this question.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2), `docs/TESTING_STRATEGY.md`.

### Medium Priority (Next Sprint)

4. **IMP-4 Velocity actuals lost across usage-limit stops**
   - **Root Cause**: an agent's progress file records units, not clock times, so a run split by a stop has no total.
   - **Proposed Solution**: the progress-file convention adds "RUN STARTED <clock>" and "RUN STOPPED <clock>" lines;
     the velocity row sums them.
   - **Effort**: ~10 minutes
   - **Impact**: no "time not recorded" rows for long agent tasks.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` ("Progress and restart"), `scripts/agent-work-status.py`
     (optional: print the summed time).

### Low Priority (Future)

None.

## Improvement Decisions

Harold, 2026-11-05, verbatim: *"imp-1 why are we copying code - can't we take the 6 copies and merge them into
one and then, if needed, the prior copied section can have code before/after to do what is needed (or seperate
functions). Does that make more sense and align to the KISS principle/12-factor app better - note this is a
discussion before deciding what to do. imp-2 b imp-3 the script should never crash with a success. Update the
script as needed imp-4 do now | Review questions Q1 1 q2 1 q3 2 q4 did it use gh cli? 1"*

- **IMP-1**: DISCUSSION PENDING (Harold asked a question before deciding). Facts given in reply: the 3 class A
  copies were already merged into one shared function or list by the 7.7.1 fixes (bab21526, 76f8a2bb,
  c1d9a2c6); the other 3 of the 6 are class D (test names), not code copies. IMP-1 is a self-review check that
  catches the NEXT copy. The Q1 fix applied the principle: one `selectBodyText` and one Gmail decoder.
- **IMP-2**: part (b) only. `SPRINT_EXECUTION_WORKFLOW.md` 5.4: an MV answer that renames or changes a behavior
  records `Swept: grep '<old text>' -> N hits fixed`. Part (a), the ADR status policy test, is not done.
- **IMP-3**: done. `scripts/test-hook.ps1` exits 1 when the hook it runs crashes, with or without `-ExpectBlock` /
  `-ExpectAllow` (before: exit 0 without a switch). Found while proving it on a REAL hook: under Windows
  PowerShell 5.1 the script died (exit 1) on every Python hook that blocks with a message, because
  `$ErrorActionPreference = 'Stop'` made the hook's stderr a terminating error; fixed. Probe, 8 cases (real
  `block-blind-staging.py` BLOCK / ALLOW with both switches, a crashing hook with and without a switch, synthetic
  block and allow, and the PowerShell stash guard): all as expected. Prevention: the 5.1.2 question "what does it
  print and return when its input matched nothing, the call did nothing, or the thing it runs crashed?" for every
  script, hook and tool, and the rule in `TESTING_STRATEGY.md` "Testing Tools and Scripts".
- **IMP-4**: done. The Progress and restart block adds `RUN STARTED` / `RUN STOPPED <yyyy-mm-dd HH:MM>` lines;
  `agent-work-status` prints the summed run time on a finished task, "time not recorded" when there are no RUN
  lines (never 0), and names a run with no stop. Test: `test_pylib` `test_run_time_adds_up_runs_split_by_stops`.
- **Q1 = 1, Q2 = 1, Q3 = 2**: done in c9f21abf (5 mutants, all KILLED).
- **Q4 = 1** (yes, it was the GitHub CLI, `gh api`): the 3 replies are posted and the 3 threads resolved.
