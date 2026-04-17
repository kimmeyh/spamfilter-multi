# Sprint Retrospective Guide

**Purpose**: Conduct structured sprint reviews and retrospectives to continuously improve development effectiveness, efficiency, and process quality.

**Audience**: Claude Code models conducting sprint retrospectives; User providing feedback

**Last Updated**: January 31, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** (this doc) | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Overview](#overview)
2. [Sprint Review Process](#sprint-review-process)
3. [Retrospective Categories](#retrospective-categories)
4. [Gathering Feedback](#gathering-feedback)
5. [Documentation Updates](#documentation-updates)
6. [Continuous Improvement](#continuous-improvement)

---

## Overview

### What is a Sprint Retrospective?

A sprint retrospective is a structured feedback session conducted after sprint work is complete but before final PR approval. It serves to:

- **Evaluate Effectiveness**: Did we deliver what was planned?
- **Assess Efficiency**: Could we have worked smarter?
- **Identify Process Issues**: What blocked or slowed us down?
- **Capture Lessons Learned**: What should we remember for next sprint?
- **Plan Improvements**: What changes will we make?

### Mandatory vs Optional

[WARNING] **Sprint reviews are MANDATORY** for all sprints. They ensure:
- Quality standards are met
- Process improvements are captured
- Team knowledge is built
- Issues are identified early

### Timing

Conduct the sprint retrospective:
1. **After**: All code is written, tested, and pushed to remote
2. **After**: PR is created and description is written
3. **Before**: User approves PR for merge to develop
4. **Duration**: 30-60 minutes depending on sprint complexity

---

## Sprint Review Process

### Phase 7 Integration

Sprint retrospectives are integrated into Phase 7 of the sprint execution workflow. See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 7 for the complete checklist.

**Summary of Steps**:

1. **Pre-Review: Windows Build Verification** (7.1)
   - Build and test Windows desktop app
   - Verify build succeeds before proceeding
   - Identify any platform-specific issues

2. **Offer Sprint Review** (7.2)
   - Ask user if they want to conduct review
   - Review is mandatory but can be quick
   - Timing: While user reviews PR, before merge

3. **Gather User Feedback** (7.3)
   - Collect feedback on key topics (see below)
   - User can provide brief feedback or detailed analysis
   - Focus on actionable improvements

4. **Identify Improvements** (7.4)
   - Claude analyzes feedback
   - Proposes specific improvements
   - Categorizes by priority (High/Medium/Low)

5. **Select Improvements** (7.5)
   - User reviews proposed improvements
   - Selects which to implement now vs later
   - Documents decisions

6. **Update Documentation** (7.7)
   - Apply agreed-upon improvements to relevant documents
   - Update version/date on modified documents
   - Create new documents if needed

7. **Summarize Review** (7.8)
   - Provide summary of review findings
   - List which improvements were selected
   - Confirm PR is ready for user approval

---

## Retrospective Categories

[CRITICAL] **All 14 categories below are MANDATORY. For each category, feedback MUST be collected from ALL FOUR roles: Product Owner, Scrum Master, Lead Developer, AND the Claude Code Development Team. A retrospective with any role missing for any category is INCOMPLETE and the sprint is NOT considered complete.**

In this single-developer project, Harold wears the Product Owner, Scrum Master, AND Lead Developer hats; Claude Code provides the Development Team perspective. Even when one human person provides three of the four perspectives, each role MUST be addressed separately because each role looks at the sprint through a different lens:

- **Product Owner**: business value, user-facing impact, scope/priority, backlog implications
- **Scrum Master**: process adherence, ceremony quality, blockers, team health, workflow friction
- **Lead Developer**: technical quality, code/architecture, engineering decisions, technical debt
- **Claude Code Development Team**: execution-side observations -- what the model(s) saw during implementation, where prompts/instructions were ambiguous, where tooling helped or hurt, where automation could be improved

If a role has nothing to say for a category, write `Product Owner: No issues -- expectations met.` (or equivalent) -- but the role MUST be explicitly addressed. Silence is NOT acceptable.

### The 14 Mandatory Categories

1. **Effective while as Efficient as Reasonably Possible** -- Did we deliver the right outcome with the least reasonable effort? (Replaces former "Effectiveness & Efficiency" + "Sprint Execution".)
2. **Testing Approach**
3. **Effort Accuracy**
4. **Planning Quality**
5. **Model Assignments**
6. **Communication**
7. **Requirements Clarity**
8. **Documentation**
9. **Process Issues**
10. **Risk Management**
11. **Next Sprint Readiness**
12. **Architecture Maintenance**
13. **Minor Function Updates for the Next Sprint Plan** -- Small enhancements/fixes uncovered during this sprint that should be folded into the NEXT sprint's plan (not full backlog items, but inline scope additions).
14. **Function Updates for the Future Backlog** -- Larger or non-urgent enhancements/ideas uncovered during this sprint that should be added to `ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" for future sprint scoping.

---

### Category Definitions

#### 1. Effective while as Efficient as Reasonably Possible

**Questions**:
- Did we deliver all planned tasks with the right level of quality?
- Were tasks completed on first attempt or did we need rework?
- Did we encounter unnecessary overhead, repeated work, or process friction?
- Were there faster approaches we could have taken without sacrificing quality?
- Did we follow the sprint workflow properly? Were any phases skipped or rushed?
- Were blockers communicated and resolved promptly?

**What to Look For**:
- Tasks completed vs tasks planned (and quality of completion)
- Rework cycles
- Time spent on non-value-adding activities
- Opportunities to parallelize work
- Adherence to SPRINT_EXECUTION_WORKFLOW.md
- Phases skipped, rushed, or executed out of order
- Blocker resolution time
- Communication gaps or misunderstandings

**Example Feedback (per role)**:
> **Product Owner**: All 12 planned features shipped, but 4 rounds of UX testing on F55 felt excessive.
> **Scrum Master**: Phase 7 was nearly skipped despite reminders -- need a hard gate.
> **Lead Developer**: Task A required 3 rework cycles due to unclear acceptance criteria.
> **Claude Code Development Team**: Auto-push state-machine bug took 3 surface-patch attempts before escalation to Opus -- escalation criterion needs to be explicit.

#### 2. Testing Approach

**Questions**:
- Did automated tests catch bugs before user testing?
- Was test coverage adequate for the scope?
- Were tests easy to understand and maintain?
- Did we test the right scenarios?

**What to Look For**:
- Bugs found by automated tests vs manual testing
- Edge cases covered vs missed
- Integration test vs unit test balance

**Example Feedback (per role)**:
> **Product Owner**: All user-facing flows passed automated tests; manual QA caught only UX nuances.
> **Scrum Master**: Phase 5.3 (manual testing) was actually executed this sprint -- good.
> **Lead Developer**: Need a database migration test fixture; we keep finding migration regressions in manual testing.
> **Claude Code Development Team**: Test discovery worked well via flutter test but writing async timer tests required multiple iterations.

#### 3. Effort Accuracy

**Questions**:
- Did actual effort match estimated effort?
- Which tasks took longer than expected? Why?
- Which tasks were faster than expected? Why?
- How can we improve future estimates?

**What to Look For**:
- Estimated hours vs actual hours per task
- Tasks with > 50% variance
- Patterns in estimation errors

**Example Feedback (per role)**:
> **Product Owner**: Sprint landed in expected window.
> **Scrum Master**: 3 of 12 tasks ran > 50% over estimate -- pattern is UI tasks with multi-tab navigation.
> **Lead Developer**: Help system grew from 12 to 19 sections -- under-scoped initial design.
> **Claude Code Development Team**: Token usage tracked Sonnet estimates well; Opus calls for Round 4 root-cause were not budgeted.

#### 4. Planning Quality

**Questions**:
- Were task descriptions clear and complete?
- Did acceptance criteria provide enough guidance?
- Were dependencies identified correctly?
- Was scope appropriate for sprint duration?

**What to Look For**:
- Number of clarification questions asked during execution
- Scope creep
- Missing dependencies discovered late
- Tasks that required re-planning

**Example Feedback (per role)**:
> **Product Owner**: Plan correctly identified the security + features mix; scope was right.
> **Scrum Master**: Sprint plan did not include explicit back-button spec for F55; that omission cost 3 testing rounds.
> **Lead Developer**: SEC-11 was rightly scoped as "infrastructure only" -- good engineering call.
> **Claude Code Development Team**: Plan-as-prompt was clear for the 12 listed tasks; ambiguity entered when "navigation consistency" required interpretation.

#### 5. Model Assignments

**Questions**:
- Were Haiku/Sonnet/Opus assignments appropriate?
- Did any tasks require escalation to higher model?
- Could simpler tasks have used a lower-cost model?

**What to Look For**:
- Tasks completed by assigned model without escalation
- Tasks that required model escalation
- Cost optimization opportunities
- Assignment heuristic accuracy

**Example Feedback (per role)**:
> **Product Owner**: Cost was acceptable.
> **Scrum Master**: Escalation to Opus for Round 4 happened after 2 failed surface fixes -- should have been 1.
> **Lead Developer**: Sonnet handled most implementation cleanly; Opus call was correct for state-machine debugging.
> **Claude Code Development Team**: Sonnet would have benefited from a navigation invariants mental model loaded earlier -- suggests adding a NAVIGATION.md reference doc.

#### 6. Communication

**Questions**:
- Were progress updates clear and timely?
- Did we narrate investigations or work silently?
- Were blockers communicated immediately?

**What to Look For**:
- Silent tool usage
- Delayed blocker communication
- Commit message clarity
- PR description completeness

**Example Feedback (per role)**:
> **Product Owner**: PR descriptions were thorough.
> **Scrum Master**: Mid-sprint check-ins were on time.
> **Lead Developer**: Commit messages followed convention.
> **Claude Code Development Team**: Investigation narration was good; one stretch of 5 silent grep calls before reporting findings.

#### 7. Requirements Clarity

**Questions**:
- Were requirements clear from the start?
- How many clarification questions were needed?
- Did we discover hidden requirements mid-sprint?
- Were non-functional requirements specified?

**What to Look For**:
- Mid-sprint scope changes
- Ambiguous acceptance criteria
- Missing quality standards

**Example Feedback (per role)**:
> **Product Owner**: F55 back-button intent was clearer in my head than in the plan.
> **Scrum Master**: Round 1 reinterpretation cost a fix-and-retest cycle.
> **Lead Developer**: SEC-11 infrastructure-only boundary was crisp -- good model.
> **Claude Code Development Team**: Where requirements named exact files/screens, execution was first-pass correct; abstract requirements triggered interpretation.

#### 8. Documentation

**Questions**:
- Was documentation updated alongside code?
- Are docs accurate and up-to-date?
- Did we document decisions and trade-offs?

**What to Look For**:
- Docs updated in same commit as code
- Broken links or outdated references
- Missing ADRs
- CHANGELOG.md completeness

**Example Feedback (per role)**:
> **Product Owner**: CHANGELOG was readable.
> **Scrum Master**: ARCHITECTURE.md updated in same sprint -- good.
> **Lead Developer**: SEC-1b backlog note correctly captured for F56.
> **Claude Code Development Team**: Doc updates landed cleanly; consider auto-generating ADR scaffolds when new lib/core/security/ modules appear.

#### 9. Process Issues

**Questions**:
- What errors or blockers were encountered?
- How long did they take to resolve?
- Are these errors documented for future reference?

**What to Look For**:
- Common errors
- Time spent debugging vs implementing
- Errors not in TROUBLESHOOTING.md

**Example Feedback (per role)**:
> **Product Owner**: No process surprises from my side.
> **Scrum Master**: Phase 7 reminder fired but the gate was soft -- needs to be hard.
> **Lead Developer**: SelectionArea + AlertDialog gotcha is now in code comments -- should also go in TROUBLESHOOTING.md.
> **Claude Code Development Team**: Write tool kept getting denied for .claude/memory/*.json; PowerShell-first updated in skill docs.

#### 10. Risk Management

**Questions**:
- Were risks identified before sprint?
- Did identified risks materialize?
- Were there unexpected risks?
- Were mitigations effective?

**What to Look For**:
- Risk register completeness
- Risks that occurred vs risks identified
- Mitigation effectiveness

**Example Feedback (per role)**:
> **Product Owner**: SEC-11 partial-scope risk was called out in plan -- well-managed.
> **Scrum Master**: SEC-1b ReDoS rejection had no fallback for already-stored vulnerable patterns -- not in risk register.
> **Lead Developer**: Cert pinning rotation procedure is a future operational risk -- documented.
> **Claude Code Development Team**: No model-side risks materialized; context stayed below 85%.

#### 11. Next Sprint Readiness

**Questions**:
- Is the codebase in good state for next sprint?
- Are there blockers for next sprint?
- Do we know what next sprint will focus on?
- Are there process improvements to apply first?

**What to Look For**:
- Unfinished work that blocks next sprint
- Technical debt that should be addressed
- Process documentation that needs updating
- Backlog grooming status

**Example Feedback (per role)**:
> **Product Owner**: F56 (manual rule UI) is the obvious next candidate.
> **Scrum Master**: ALL_SPRINTS_MASTER_PLAN.md updated; ready to plan.
> **Lead Developer**: No technical debt blocking next sprint.
> **Claude Code Development Team**: Skills updated; memory cleared; ready to plan from a clean slate.

#### 12. Architecture Maintenance

**Questions**:
- Did this sprint introduce changes that affect documented architecture?
- Are all architecture documents current after this sprint's changes?
- Do any ADRs need creation, updates, or superseding?
- Were any architectural decisions made during execution that were not in the sprint plan?

**What to Look For**:
- New services, screens, database tables, or patterns not reflected in ARCHITECTURE.md
- Changes that conflict with existing ADR decisions
- Design pattern changes not reflected in ARSD.md
- Implicit architectural decisions made during coding that should be documented

**Example Feedback (per role)**:
> **Product Owner**: Architecture sections in CHANGELOG were clear to read.
> **Scrum Master**: Architecture compliance check (Phase 7.4.1) was executed.
> **Lead Developer**: PatternCompiler provenance + new lib/core/security/ directory documented.
> **Claude Code Development Team**: Schema v3 migration tested; future SQLCipher swap documented as known follow-up.

#### 13. Minor Function Updates for the Next Sprint Plan

**Purpose**: Capture small enhancements, fixes, or polish items uncovered during this sprint that should be folded into the NEXT sprint's plan as inline scope additions (not full backlog items).

**Questions**:
- What small UX/UI nits did manual testing surface that did not make this sprint's scope?
- Were there minor refactors or cleanups noticed during code review that fit the next sprint's theme?
- Are there sub-1-hour touch-ups that should ride along with related work next sprint?

**What to Look For**:
- "While I am in this file" candidates
- UX nits too minor for a backlog item but too noticeable to ignore
- Refactors that unlock the next sprint's work

**Output**: Each entry MUST be added to the NEXT sprint's plan during Phase 3 planning. Format: `[ROLE] <one-line description> -- target: Sprint N+1 plan, est: <Xh>`

**Example Feedback (per role)**:
> **Product Owner**: Help icon on Demo Scan results screen (~15 min).
> **Scrum Master**: Add Phase 7 hard-gate reminder to checklist (~30 min).
> **Lead Developer**: Extract Navigator.push boilerplate into pushScreen() helper (~1h).
> **Claude Code Development Team**: Add a /sprint-status skill to summarize Phase progress (~1h).

#### 14. Function Updates for the Future Backlog

**Purpose**: Capture larger or non-urgent enhancements/ideas uncovered during this sprint that should be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" for future scoping.

**Questions**:
- What did this sprint surface as a "we should really build that someday" item?
- What user feedback during testing pointed at a future feature?
- What technical debt is too large for inline cleanup?

**What to Look For**:
- New feature ideas (assign F-number when added to master plan)
- Larger refactors or migrations
- Tooling/automation opportunities
- Cross-sprint themes (e.g., "Android security pass")

**Output**: Each entry MUST be added to `ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a new feature/issue number. Format: `[ROLE] <title> -- estimated: <Xh>, priority: <High|Medium|Low>, depends on: <list>`

**Example Feedback (per role)**:
> **Product Owner**: F-XX: Recently-added rules filter on Manage Rules screen -- Medium, ~4h.
> **Scrum Master**: Process: standardize sprint plan template to require back-button spec for any nav-touching feature -- Low, ~30 min.
> **Lead Developer**: F-XX: SQLCipher driver swap + plaintext-to-encrypted migration (completes SEC-11) -- High, ~8h, dedicated QA sprint.
> **Claude Code Development Team**: Tooling: linter rule that warns when Navigator.push is added without a corresponding pop site -- Medium, ~2h.

---

## Gathering Feedback

### Sprint Retrospective Feedback Collection (Phase 7.3) -- MANDATORY 4 ROLES x 14 CATEGORIES

[CRITICAL] **A Sprint Retrospective is NEVER considered complete unless all 14 categories are addressed by all 4 roles (Product Owner, Scrum Master, Lead Developer, Claude Code Development Team). Missing roles or categories = retrospective is INCOMPLETE = sprint is NOT complete.**

Claude MUST present each of the 14 categories to the user (who fills the PO + SM + Lead Dev roles) and MUST contribute the Claude Code Development Team perspective itself. Each role provides:

- **Brief feedback**: 1-2 sentences -- minimum acceptable
- **Detailed feedback**: Full analysis with examples
- **Explicit "no issues"**: e.g., `Product Owner: No issues -- expectations met.` -- still counts as addressed

Empty/silent rows are NOT acceptable. If a role has nothing to say, that role must explicitly say so.

**Mandatory Feedback Template** (copy verbatim into `docs/sprints/SPRINT_N_RETROSPECTIVE.md`):

```markdown
## Sprint N Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 2. Testing Approach

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 3. Effort Accuracy

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 4. Planning Quality

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 5. Model Assignments

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 6. Communication

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 7. Requirements Clarity

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 8. Documentation

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 9. Process Issues

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 10. Risk Management

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 11. Next Sprint Readiness

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 12. Architecture Maintenance

- **Product Owner**: [feedback]
- **Scrum Master**: [feedback]
- **Lead Developer**: [feedback]
- **Claude Code Development Team**: [feedback]

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner**: [item or "None"]
- **Scrum Master**: [item or "None"]
- **Lead Developer**: [item or "None"]
- **Claude Code Development Team**: [item or "None"]

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner**: [item or "None"]
- **Scrum Master**: [item or "None"]
- **Lead Developer**: [item or "None"]
- **Claude Code Development Team**: [item or "None"]
```

### Completeness Validation Gate (Phase 7.3 exit criterion)

Before exiting Phase 7.3, Claude MUST verify:

- [ ] All 14 categories are present in the retrospective document
- [ ] Each category contains explicit feedback from ALL 4 roles (Product Owner, Scrum Master, Lead Developer, Claude Code Development Team)
- [ ] No feedback line is empty or contains only `[feedback]` placeholder text
- [ ] Category 13 entries (if any) are documented for carry-in to Sprint N+1 plan
- [ ] Category 14 entries (if any) have follow-up tasks tracked for `ALL_SPRINTS_MASTER_PLAN.md` update in Phase 7.7

If ANY box above is unchecked, Phase 7 is INCOMPLETE. Sprint cannot be declared complete. Stop and request the missing feedback.

### Claude Analysis (Phase 7.4)

After receiving user feedback, Claude analyzes and proposes improvements:

1. **Categorize Feedback**: Group by theme (process, testing, communication, etc.)
2. **Identify Root Causes**: Why did issues occur?
3. **Propose Solutions**: Specific, actionable improvements
4. **Prioritize**: High/Medium/Low based on impact and effort
5. **Estimate Effort**: How long to implement each improvement?

**Analysis Template**:

```markdown
## Improvement Recommendations

### High Priority (Implement Now)

1. **[Issue]**: Brief description
   - **Root Cause**: Why it happened
   - **Proposed Solution**: Specific action
   - **Effort**: Estimated time to implement
   - **Impact**: What will improve
   - **Files to Update**: List of documentation/code files

### Medium Priority (Next Sprint)

[Same format]

### Low Priority (Future)

[Same format]
```

### User Approval (Phase 7.5)

User reviews proposed improvements and selects:
- **Implement Now**: Apply before merging PR
- **Implement Next Sprint**: Add to Sprint N+1 backlog
- **Reject**: Not valuable, skip

---

## Documentation Updates

### What to Update (Phase 7.7)

After user approves improvements, update relevant documents:

#### 1. ALL_SPRINTS_MASTER_PLAN.md

Update per the Maintenance Guide at the top of the document:
- Update "Last Completed Sprint" section with Sprint N details
- Add row to "Past Sprint Summary" table
- Remove completed items from "Next Sprint Candidates" table
- Remove completed feature/bug detail sections
- Update priorities or add new items discovered during sprint

```markdown
### Last Completed Sprint: Sprint N - [Title]
**Completed**: YYYY-MM-DD | **Duration**: ~Xh | **PR**: #NNN
**Tasks**: Brief list of what was done

**Improvements Implemented**:
- [Improvement 1] → Updated [file]
- [Improvement 2] → Updated [file]
```

#### 2. SPRINT_EXECUTION_WORKFLOW.md

Apply process improvements:
- Add new checklist items
- Clarify ambiguous steps
- Add examples where needed
- Update decision criteria

#### 3. SPRINT_PLANNING.md

Update planning methodology:
- Refine model assignment heuristics
- Add acceptance criteria templates
- Update estimation guidelines

#### 4. SPRINT_STOPPING_CRITERIA.md

Add new stopping criteria discovered:
- When to stop and ask vs continue
- New escalation patterns

#### 5. TROUBLESHOOTING.md

Add new errors/solutions:
- Common errors encountered
- Root causes and fixes
- Prevention strategies

#### 6. PERFORMANCE_BENCHMARKS.md

Update performance baselines:
- New benchmark data from sprint
- Performance improvements achieved
- Regression detection

#### 7. CHANGELOG.md

Add sprint completion entry:
```markdown
### YYYY-MM-DD

**Sprint N Complete** (PR #NNN):
- **feat**: [Major feature 1]
- **feat**: [Major feature 2]
- **fix**: [Critical bug fix]
- **refactor**: [Code improvement]
- **test**: [Test coverage improvement]
- **docs**: [Documentation update]
```

#### 8. Create Sprint Retrospective Document

Create `docs/SPRINT_N_RETROSPECTIVE.md` with full retrospective details:
- User feedback (full quotes)
- Claude analysis
- Improvements selected
- Documentation updates applied
- Action items for next sprint

**NOTE**: This retrospective document is separate from SPRINT_<N>_SUMMARY.md:
- **SPRINT_N_RETROSPECTIVE.md**: Created during Phase 7 (this phase) - Full retrospective with feedback and improvements
- **SPRINT_<N>_SUMMARY.md**: Created during next sprint planning (Phase 3.2.1) - Historical archive of sprint details

#### 9. Sprint Summary Document (Created Next Sprint)

**SPRINT_<N>_SUMMARY.md** is created as a background process during planning for Sprint N+1:
- **When**: Phase 3.2.1 of next sprint (see SPRINT_EXECUTION_WORKFLOW.md)
- **Purpose**: Archive historical sprint details for reference
- **Content**: Sprint objective, tasks, deliverables, duration, lessons learned, improvements
- **Sources**: Retrospective, CHANGELOG, git history, GitHub issues (NOT from ALL_SPRINTS_MASTER_PLAN.md -- completed details are already removed)
- **Reference**: Added to "Past Sprint Summary" table in ALL_SPRINTS_MASTER_PLAN.md

This is a background process that does not block current sprint completion.

---

## Continuous Improvement

### Improvement Tracking

Track improvements across sprints to measure progress:

```markdown
## Process Improvement Log

| Sprint | Category | Improvement | Status | Impact |
|--------|----------|-------------|--------|--------|
| 8 | Testing | Added parallel log monitoring | [OK] Implemented | Caught 3 errors in real-time |
| 8 | Documentation | Created QUICK_REFERENCE.md | [OK] Implemented | Reduced file lookup time by 50% |
| 9 | Logging | Keyword-based logging with AppLogger | [OK] Implemented | Easy log filtering |
| 9 | Process | Added risk assessment to sprint plans | [OK] Implemented | Identified 2 risks proactively |
```

### Metrics to Track

Monitor sprint-over-sprint trends:

1. **Effort Accuracy**: % variance between estimated and actual effort
2. **Rework Rate**: % of tasks requiring revision
3. **Test Coverage**: % of code covered by tests
4. **Bug Escape Rate**: Bugs found in production vs testing
5. **Model Assignment Accuracy**: % of tasks completed by assigned model
6. **Sprint Velocity**: Tasks completed per sprint
7. **Process Adherence**: % of workflow steps followed
8. **Documentation Currency**: % of docs updated in same PR as code

### Learning Patterns

Identify patterns over multiple sprints:

**Example**:
> After 3 sprints, we notice:
> - Refactoring tasks always take 2x longer than estimated
> - Database migration tasks always require Sonnet (never Haiku)
> - UI tasks have 90% test coverage, backend has 60%
> - Communication improves when Claude narrates diagnostic work
>
> **Actions**:
> - Multiply refactoring estimates by 2x
> - Always assign database tasks to Sonnet
> - Focus test coverage improvements on backend
> - Add "narrate investigations" to workflow checklist

---

## Quick Reference

### When to Conduct Retrospective

**[OK] Always**:
- After every sprint (mandatory)
- After PR created and before merge
- When sprint work is complete

**[FAIL] Never**:
- During sprint execution (too early)
- After PR already merged (too late)
- When context will be lost

### Retrospective Checklist

Use this quick checklist during Phase 7:

- [ ] Windows build verified (7.1)
- [ ] **MANDATORY: Feedback collected on ALL 14 categories from ALL 4 roles** (Product Owner, Scrum Master, Lead Developer, Claude Code Development Team) (7.3) -- retrospective is INCOMPLETE without this
- [ ] **MANDATORY: Completeness Validation Gate passed** (no empty role-feedback lines, all 14 categories present, Category 13 + 14 follow-ups tracked) (7.3 exit)
- [ ] Claude analyzed feedback and proposed improvements (7.4)
- [ ] User selected improvements to implement (7.5)
- [ ] ALL_SPRINTS_MASTER_PLAN.md updated per Maintenance Guide (7.7) -- includes Category 14 backlog additions
- [ ] Next Sprint Plan stub updated with Category 13 carry-ins (7.7)
- [ ] Relevant workflow docs updated with improvements (7.7)
- [ ] CHANGELOG.md updated with sprint entry (7.7)
- [ ] Sprint retrospective document created (7.7)
- [ ] Summary provided to user (7.8)
- [ ] PR ready for approval

### Common Pitfalls to Avoid

1. **Skipping Retrospective**: "We're in a hurry, let's skip it"
   - **Why Bad**: Lose valuable learning, repeat mistakes
   - **Fix**: Make retrospective non-negotiable, even if brief

2. **Vague Feedback**: "Everything was fine"
   - **Why Bad**: No actionable improvements
   - **Fix**: Ask specific questions, use examples

3. **No Follow-Through**: Document improvements but never implement
   - **Why Bad**: Process stagnates, team loses trust
   - **Fix**: Track implementation status, review in next sprint

4. **Blame Culture**: "Task B failed because Haiku messed up"
   - **Why Bad**: Defensive, not constructive
   - **Fix**: Focus on systems/process, not individuals

5. **Analysis Paralysis**: Spend 2 hours debating minor improvements
   - **Why Bad**: Waste time on low-impact items
   - **Fix**: Prioritize ruthlessly, timebox discussions

---

## Recommendation Presentation Format

### How to Present Recommendations to User

After analyzing user feedback (Phase 7.4), Claude should present improvement recommendations in a specific order and format for user approval.

**Presentation Order**: Recommendations MUST be presented LAST, after all analysis is complete, grouped by implementation dependency, and numbered for easy approval.

**Numbering System**:
- Use `<n>` for top-level recommendations (e.g., 1, 2, 3)
- Use `<n.n>` for sub-group items (e.g., 1.1, 1.2, 1.3)
- Each number is unique for easy approval ("Approve recommendations 1, 3.1, 3.2, 5")

### Recommendation Grouping Strategy

Group recommendations by **implementation order** based on dependencies:

**Group 1: Foundation - Planning & Requirements** (implement first)
- Risk assessment requirements
- Acceptance criteria improvements
- Sprint planning enhancements
- These affect all downstream work

**Group 2: Execution Process** (implement second)
- Workflow improvements
- Testing requirements
- Documentation standards
- Communication guidelines
- These affect how work is done

**Group 3: Quality & Validation** (implement third)
- Code quality standards
- Tool validation requirements
- Test coverage requirements
- Cross-platform validation
- These affect final deliverables

**Group 4: Meta-Process** (implement last)
- Retrospective improvements
- Metrics tracking
- Continuous improvement
- These improve the process itself

### Presentation Template

```markdown
## Sprint N Retrospective Recommendations

Based on feedback analysis, here are proposed improvements grouped by implementation order:

### Group 1: Foundation - Planning & Requirements

**1. Risk Assessment Requirements** (Affects: Sprint planning, all tasks)
- **What**: Every sprint task must document risks with likelihood/impact/mitigation
- **Why**: Proactive risk identification prevents issues
- **Implementation**: Update SPRINT_PLANNING.md templates, add risk column
- **Effort**: 30 minutes
- **Impact**: High - prevents unexpected blockers

  **1.1 Add Risk Column to Sprint Plans**
  - Add "Risks" section to each task template
  - Include even for "Low - maintenance work" tasks

  **1.2 Risk Validation Checklist**
  - Add to task completion checklists
  - Verify mitigations executed before marking complete

  **1.3 Risk Review Gate**
  - Before pushing to remote, review all task risks
  - Confirm mitigations executed (no user approval needed)

**2. Quantifiable Acceptance Criteria** (Affects: Sprint planning, task validation)
- **What**: All acceptance criteria must be measurable
- **Why**: Prevents ambiguity, enables objective completion verification
- **Examples**:
  - [FAIL] "Comprehensive testing"
  - [OK] "All unit and integration tests are error free and produce expected results"
  - [FAIL] "Code quality improvements"
  - [OK] "Reduce all warnings in production code that can be accomplished in 1 hour"
- **Implementation**: Update sprint plan templates with examples
- **Effort**: 15 minutes
- **Impact**: High - eliminates rework from unclear requirements

  **2.1 Value Statement Requirement**
  - Each task must include "This enables..." or "This prevents..." statement
  - Clarifies task purpose and business value

  **2.2 Explicit Acceptance Criteria in Plans**
  - Sprint plan must repeat acceptance criteria from GitHub issues
  - Criteria must match exactly between issue and plan
  - All criteria reflected in sprint execution/completion checklists

[... continue with Groups 2, 3, 4 ...]

### Recommendation Summary

**Total Recommendations**: 25
**By Priority**:
- High: 12 recommendations (Groups 1-2)
- Medium: 8 recommendations (Group 3)
- Low: 5 recommendations (Group 4)

**Approval Format**:
User can approve by number: "Approve 1, 1.1, 1.2, 2, 3.1, 5, 7, 8.1, 9"

**What would you like to approve?**
```

### Implementation After Approval

1. **Parse Approvals**: Extract approved recommendation numbers
2. **Group by Document**: Group approved items by which file they affect
3. **Apply Changes**: Update each affected document
4. **Commit**: Single commit with all approved changes
5. **Summarize**: List what was implemented and which documents changed

### Common Recommendation Categories

Use these standard categories when presenting recommendations:

1. **Planning & Requirements**
   - Risk assessment
   - Acceptance criteria
   - Effort estimation
   - Sprint scope

2. **Execution Process**
   - Workflow steps
   - Testing requirements
   - Code review standards
   - Communication protocols

3. **Quality & Validation**
   - Code quality standards
   - Test coverage requirements
   - Tool validation
   - Cross-platform testing

4. **Documentation**
   - Required updates (CHANGELOG, master plan)
   - Documentation standards
   - Example/template requirements

5. **Meta-Process**
   - Retrospective improvements
   - Metrics tracking
   - Continuous improvement
   - Learning capture

---

## Version History

**Version**: 2.0
**Date**: April 16, 2026
**Author**: Claude Opus 4.6
**Status**: Active

**Updates**:
- 2.0 (2026-04-16): MANDATORY 14 categories x 4 roles (Product Owner, Scrum Master, Lead Developer, Claude Code Development Team). Added Categories 13 (minor next-sprint carry-ins) and 14 (future-backlog additions). Replaced "Effectiveness & Efficiency" + "Sprint Execution" with "Effective while as Efficient as Reasonably Possible". Retrospective is now INCOMPLETE if any role/category is unaddressed -- sprint cannot be declared complete (Sprint 33 retrospective gap)
- 1.2 (2026-04-13): Added Category 13 "Architecture Maintenance" to retrospective categories and feedback template (Sprint 30 improvement)
- 1.1 (2026-01-31): Added "Recommendation Presentation Format" section with grouping strategy, numbering system, and template
- 1.0 (2026-01-31): Initial version extracted from Sprint 8 retrospective and SPRINT_EXECUTION_WORKFLOW.md Phase 7
