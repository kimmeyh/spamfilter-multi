# Sprint 36 Retrospective

**Sprint**: 36
**Dates**: 2026-04-20 (kickoff) through 2026-04-25 (retro)
**Branch**: `feature/20260420_Sprint_36`
**PR**: #245 (ready for review)
**Issues closed**: #244 (sprint), #242 (F81), #239 (BUG-S35-1), #241 (F80)
**Issues opened**: #246 (BUG-S36-1, Sprint 37 carry-in)

## Sprint Outcome

All 3 planned tasks shipped green:

- **Task 1 -- F81 (Issue #242)**: Store release process documentation. New `docs/STORE_RELEASE_PROCESS.md` (231 lines) plus 5 supporting fixes (root `.gitignore` `*.manifest` scoping, `secrets.prod.json.template` key correction, `build-msix.ps1` deprecation header, CLAUDE.md cross-link, ADR-0035 cross-reference, `runner.exe.manifest` committed).
- **Task 2 -- BUG-S35-1 (Issue #239)**: Manual rule duplicate prevention. New `ManualRuleDuplicateChecker` service + 15 unit tests + Phase 5 UX refinement (duplicate check now runs before Confirm dialog).
- **Task 3 -- F80 (Issue #241)**: 24-line Phase Cheat Sheet prepended to SPRINT_EXECUTION_WORKFLOW.md.

**Quality gates**:
- Test suite: 1378 passing / 0 failing (baseline 1363, +15 new).
- `flutter analyze`: 0 issues.
- Phase 5 manual testing on Windows dev 0.5.3 build: BUG-S35-1 pre-dialog duplicate detection verified.

**Effort**: Estimated 8-10h, actual ~3h wall-clock. Estimates ran ~40% high for doc-heavy tasks; recalibration noted.

## Sprint 35 Retrospective Carry-Ins (Status)

| Carry-in | Status |
|----------|--------|
| F81 (Cat 13) | SHIPPED |
| BUG-S35-1 (suggested Task 2) | SHIPPED |
| F80 (P3) | SHIPPED |
| Stop-hook (pre-work) | Already committed in `4874004` before sprint plan; fired once during Sprint 36, worked as intended, 0 false positives |
| Phase 1 MANDATORY policy | Already committed in `80dfa8d` before sprint Phase 4 |

## 14 Categories x 4 Roles Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Sprint Backlog Refinement was missed. Now a mandatory step.
- **Scrum Master**: Sprint Backlog Refinement was missed. Now a mandatory step.
- **Lead Developer**: Struggled with getting Claude Code running on an updated version. Was able to work out, but wasted time.
- **Claude Code Development Team**: Phase 4 execution density was good once Phase 3.7 approval was confirmed -- F81, BUG-S35-1, and F80 shipped in a single contiguous working session with no avoidable stalls. Verification-against-repo-state at resume saved one real task (1.3 was already done in kickoff 46e7b6d). One real efficiency loss: I did a Monitor-based `tail -f` of a 0-byte build output file; the build succeeded but my monitor emitted no events, so I lost ~10 min on "is the build still running?" investigation before noticing the running process directly. New memory `feedback_background_task_stdout.md` captures the pattern.

### 2. Testing Approach

- **Product Owner**: Good.
- **Scrum Master**: Good.
- **Lead Developer**: Good.
- **Claude Code Development Team**: 15 new unit tests for `ManualRuleDuplicateChecker` covered exact/case/whitespace/sub-type matrix cleanly. Parametric loops for the 4+3 sub-types kept test count modest. Phase 5.1.1 sibling sweep was trivially empty (no structural-data changes), correctly reported. **Gap**: I added DB-path uniqueness tests but no widget-level test that the Confirm dialog is skipped on duplicate. The pre-dialog refinement shipped without a widget test. Harold caught the UX defect at Phase 5; a widget test would have caught it pre-Phase 5. Addressed by IMP-2 (TESTING_STRATEGY.md mandate).

### 3. Effort Accuracy

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: F81 estimated 5-6h, shipped in ~90 min (docs tasks compress well once structure is clear). BUG-S35-1 estimated 2-3h, shipped in ~45 min for the core fix plus ~20 min for the pre-dialog refinement. F80 estimated 45 min, shipped in ~15 min. Aggregate estimate 8-10h; aggregate wall clock ~3h. Estimates are consistently high for Sonnet/Opus speed on doc-heavy sprints. Worth recalibrating doc-heavy estimates downward by ~40%.

### 4. Planning Quality

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Sprint plan was dependency-correct: F81 before BUG-S35-1 before F80 matched the retrospective intent. **Two planning defects** caught at Phase 4 execution: (a) Task 1.3 (`build_windows_args` in dev pubspec) was listed as pending but had already shipped in kickoff commit 46e7b6d. (b) Plan cited "mobile-app/.gitignore line 120" but the actual offending rule was in root `.gitignore` line 120 (PyInstaller legacy). Both surfaced 0 lasting harm but wasted inspection time. Addressed by IMP-1 (Phase 3.2.2.1 plan-to-branch-state verification gate).

### 5. Model Assignments

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Sonnet/Opus for F81 (doc-heavy with cross-file coordination) and BUG-S35-1 (code + tests) was correct. F80 marked Haiku in plan but executed on current (Opus) model because session was already running. No rework; task was trivial enough that Opus was not meaningfully better or worse. Next time honor the assignment or delete it if sessions span.

### 6. Communication

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Sprint 35 pitfall entries in CLAUDE.md (Opus 4.7 appendix) corrected some but not all of my patterns -- Stop-hook fired once early in the session. Pre-dialog duplicate check refinement: Harold's framing "Can it find the duplicate after hitting the save rule and before Confirm Block Rule?" was more specific than my code inspection -- a better code review on my part would have caught the UX defect before Phase 5. Approval verification at session resume was weak; I read SPRINT_36_PLAN.md and presumed approval. Fixed with new memory entry `feedback_approval_verification.md` and IMP-3 (`/startup-check` Phase 3.7 gate).

### 7. Requirements Clarity

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Plan was explicit on acceptance criteria per task; I could check items off without ambiguity. Two plan assumptions were stale (1.3 done, .gitignore file path), discoverable only by reading repo state. Requirements text was clear; requirements truth needed independent verification.

### 8. Documentation

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: STORE_RELEASE_PROCESS.md is 231 lines and fits the "runnable checklist" intent per F81 AC. Includes troubleshooting for the 3 silent-failure gaps. F80 cheat sheet is 24 lines; under the 40-line cap. Three CHANGELOG entries for Task 2 (core + refinement + S36-1 carry-in) could have been a single entry -- split across three commits is fine but the CHANGELOG could consolidate on merge.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (verbatim)**: "Still a few issues, but cleaned up a couple from last sprint. Mostly it appears there is a general unwillingness to follow the Sprint Execution Docs, /docs, checklist... and just try to wing it when winging it is costly to the overall process (much slower, wall clock and duration delays, unnecessary interactions that slow down the development team and in turn the whole product development process). Hoping to continue to see improvements."
- **Claude Code Development Team**: This is the most consistent retro thread across Sprints 34/35/36. Specific Sprint 36 instances of the pattern: (a) approval-verification gap at session resume -- I read SPRINT_36_PLAN.md and presumed Phase 3.7 approval; (b) plan-to-branch-state verification gap -- I wrote the plan with Task 1.3 stale and the wrong .gitignore file path because I did not run a verification pass; (c) pre-dialog duplicate UX miss -- I edited `_saveBlockRule` / `_saveSafeSender` without tracing the full caller chain through `_confirmAndSave`; (d) Monitor-on-0-byte-file -- I armed the Monitor without verifying stdout was being captured first. Each individual skip "feels faster" by 30-60 seconds but the resulting escapes cost minutes-to-hours per incident plus interaction overhead with Harold. Stop-hook fired once (worked as intended, 0 false positives). Addressed by IMP-1 (plan verification gate), IMP-2 (widget test mandate), IMP-3 (`/startup-check` approval gate), IMP-4 (CLAUDE.md pitfall entry 7 + memory `feedback_follow_the_docs.md`), IMP-5 (memory `feedback_background_task_stdout.md`).

### 10. Risk Management

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Plan pre-enumerated 5 risks; all tracked. Only one materialized (risk 3: F81 scope creep) and stayed under the 6h cap. Stop-hook false-positive rate was 0 this sprint. Emergency bypass not invoked.

### 11. Next Sprint Readiness

- **Product Owner**: A little weak -- see Process Issues.
- **Scrum Master**: A little weak -- see Process Issues.
- **Lead Developer**: A little weak -- see Process Issues.
- **Claude Code Development Team**: BUG-S36-1 (Issue #246) is fully specified with coverage matrix, acceptance criteria, and estimate. Ready for Sprint 37 inclusion. Sprint 37 Phase 1 Backlog Refinement will be mandatory (new policy); no ambiguity. No open blockers.

### 12. Architecture Maintenance

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Phase 3.6.1 architecture check was correct: no ADRs or ARCHITECTURE.md updates needed. ADR-0035 got a cross-reference but no substantive change. New `ManualRuleDuplicateChecker` is a service-layer helper; does not merit its own ADR (per ADR-0035 precedent, ADRs capture architectural decisions, not service additions).

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: None.
- **Scrum Master**: None.
- **Lead Developer**: None.
- **Claude Code Development Team**: None from me for Sprint 37. BUG-S36-1 is already the natural Sprint 37 carry-in (Issue #246, semantic subsumption coverage detection on rule creation).

### 14. Function Updates for the Future Backlog

- **Product Owner**: None.
- **Scrum Master**: None.
- **Lead Developer**: None.
- **Claude Code Development Team**: None new for the function backlog. Process improvements (IMPs 1-5) applied directly to docs/skills/memory rather than as backlog items.

## Improvements Applied (Sprint 36 retro IMPs)

All 5 improvements approved and applied:

- **IMP-1**: New Phase 3.2.2.1 plan-to-branch-state verification gate in `docs/SPRINT_EXECUTION_WORKFLOW.md`. For each task in `SPRINT_N_PLAN.md`, verify against current branch state before committing the plan. Catches Sprint-36-style stale-plan defects at plan-write time instead of Phase 4 execution.
- **IMP-2**: New widget-test mandate in `docs/TESTING_STRATEGY.md` Widget Tests section. UX flow changes (dialog appears/skips, navigation step adds/removes) require a widget test before shipping. Pure-data changes are exempt.
- **IMP-3**: New Phase 3.7 approval verification gate in `/startup-check` skill. On any `feature/*Sprint*` branch with `SPRINT_N_PLAN.md` present, the skill checks PR comments, issue comments, and memory for approval evidence before allowing Phase 4 work. Hard stop equivalent to the Phase 1 gate.
- **IMP-4**: New entry 7 in CLAUDE.md Opus 4.7 Model-Version Pitfalls appendix: "Improvising around the Sprint Execution docs when following them would feel slower in the moment." Companion memory `feedback_follow_the_docs.md` enumerates 6 specific Sprint 34-36 failure modes and the corrective behavior.
- **IMP-5**: New memory `feedback_background_task_stdout.md`. Verify a background-task output file is being written before arming a Monitor on it; 0-byte file = silent monitor regardless of build outcome.

## Metrics

- **Stops-per-hour (approximate)**: 1 unstick from Harold during Phase 4 (approval verification gap). 0 unsticks during Phase 5/6/7. Down from Sprint 34/35 baseline.
- **Stop-hook violations detected**: 1 (early session, fired correctly).
- **Stop-hook false positives**: 0.
- **Wall-clock vs estimate**: ~3h vs 8-10h estimate (~40% of estimate).
- **Test count delta**: +15 (1363 -> 1378). All passing.

## Sprint 36 Success Metric Result

The Sprint 36 plan defined success as: zero procedural-question unsticks from Harold; <=1 false-positive hook block requiring bypass; F81/BUG-S35-1/F80 all shipped within estimate.

Result:

- 1 substantive unstick (Phase 3.7 approval verification gap) -- not a procedural question on a phase boundary, but a class-of-issue gap that the new IMP-3 startup-check now closes. Stop-hook prevented procedural-question unsticks specifically (0 of those).
- 0 false-positive hook blocks.
- All 3 tasks shipped within estimate; aggregate at ~40% of estimate.

Mixed result. Stop-hook delivered its specific design goal (procedural-question prevention). The session-resume approval-verification gap is a different class of issue and is now closed by IMP-3. Sprint 37 success metric should track the new IMP-3 gate's effectiveness.
