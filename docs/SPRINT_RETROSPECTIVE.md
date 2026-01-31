# Sprint Retrospective Guide

**Purpose**: Conduct structured sprint reviews and retrospectives to continuously improve development effectiveness, efficiency, and process quality.

**When to Use**: After PR submission (Phase 4.5 of SPRINT_EXECUTION_WORKFLOW.md), before PR approval and merge.

**Related Documents**:
- `docs/ALL_SPRINTS_MASTER_PLAN.md` - Update with actuals and lessons learned
- `docs/SPRINT_EXECUTION_WORKFLOW.md` - Phase 4.5 integration
- `docs/SPRINT_PLANNING.md` - Planning methodology
- `docs/PERFORMANCE_BENCHMARKS.md` - Performance tracking

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

⚠️ **Sprint reviews are MANDATORY** for all sprints. They ensure:
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

### Phase 4.5 Integration

Sprint retrospectives are integrated into Phase 4.5 of the sprint execution workflow. See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 4.5 for the complete checklist.

**Summary of Steps**:

1. **Pre-Review: Windows Build Verification** (4.5.0)
   - Build and test Windows desktop app
   - Verify build succeeds before proceeding
   - Identify any platform-specific issues

2. **Offer Sprint Review** (4.5.1)
   - Ask user if they want to conduct review
   - Review is mandatory but can be quick
   - Timing: While user reviews PR, before merge

3. **Gather User Feedback** (4.5.2)
   - Collect feedback on key topics (see below)
   - User can provide brief feedback or detailed analysis
   - Focus on actionable improvements

4. **Identify Improvements** (4.5.3)
   - Claude analyzes feedback
   - Proposes specific improvements
   - Categorizes by priority (High/Medium/Low)

5. **Select Improvements** (4.5.4)
   - User reviews proposed improvements
   - Selects which to implement now vs later
   - Documents decisions

6. **Update Documentation** (4.5.6)
   - Apply agreed-upon improvements to relevant documents
   - Update version/date on modified documents
   - Create new documents if needed

7. **Summarize Review** (4.5.7)
   - Provide summary of review findings
   - List which improvements were selected
   - Confirm PR is ready for user approval

---

## Retrospective Categories

### 1. Effectiveness & Efficiency

**Questions**:
- Did we deliver all planned tasks?
- Were tasks completed on first attempt or did we need rework?
- Did we work efficiently or encounter unnecessary overhead?
- Were there faster approaches we could have taken?

**What to Look For**:
- Tasks completed vs tasks planned
- Rework cycles (how many times did we revise code?)
- Time spent on non-value-adding activities
- Opportunities to parallelize work

**Example Feedback**:
> "Task A required 3 rework cycles due to unclear acceptance criteria. Future sprints should include more specific examples in task descriptions."

### 2. Sprint Execution

**Questions**:
- Did we follow the sprint workflow properly?
- Were there phases that felt unclear or unnecessary?
- Did we encounter blockers? How were they resolved?
- Was communication effective throughout?

**What to Look For**:
- Adherence to SPRINT_EXECUTION_WORKFLOW.md
- Phases that were skipped or rushed
- Blockers and how long they lasted
- Communication gaps or misunderstandings

**Example Feedback**:
> "Phase 3.3 (Manual Testing) lacked parallel log monitoring, causing us to miss errors until user reported them."

### 3. Testing Approach

**Questions**:
- Did tests catch bugs before user testing?
- Was test coverage adequate?
- Were tests easy to understand and maintain?
- Did we test the right scenarios?

**What to Look For**:
- Bugs found by automated tests vs manual testing
- Test coverage percentage
- Edge cases covered vs missed
- Integration test vs unit test balance

**Example Feedback**:
> "No database operation tests existed, leading to undetected migration bugs. Need comprehensive database test suite."

### 4. Effort Accuracy

**Questions**:
- Did actual effort match estimated effort?
- Which tasks took longer than expected? Why?
- Which tasks were faster than expected? Why?
- How can we improve future estimates?

**What to Look For**:
- Estimated hours vs actual hours per task
- Tasks with >50% variance
- Patterns in estimation errors (always underestimate refactoring, etc.)

**Example Tracking**:
```markdown
| Task | Estimated | Actual | Variance | Reason |
|------|-----------|--------|----------|--------|
| Task A | 2h | 4h | +100% | Unclear requirements, needed 3 revisions |
| Task B | 3h | 2h | -33% | Simpler than expected, existing helper used |
| Task C | 1h | 1h | 0% | Accurate |
```

### 5. Planning Quality

**Questions**:
- Were task descriptions clear and complete?
- Did acceptance criteria provide enough guidance?
- Were dependencies identified correctly?
- Was scope appropriate for sprint duration?

**What to Look For**:
- Number of clarification questions asked during execution
- Scope creep (tasks added mid-sprint)
- Missing dependencies discovered late
- Tasks that required re-planning

**Example Feedback**:
> "Task acceptance criteria were vague ('comprehensive testing'). Future tasks need quantifiable criteria ('minimum 20 tests covering CRUD operations')."

### 6. Model Assignments

**Questions**:
- Were Haiku/Sonnet/Opus assignments appropriate?
- Did any tasks require escalation to higher model?
- Could simpler tasks have used lower-cost model?
- How confident were we in assignments (before sprint)?

**What to Look For**:
- Tasks completed by assigned model without escalation
- Tasks that required model escalation (Haiku → Sonnet → Opus)
- Cost optimization opportunities
- Assignment heuristic accuracy

**Example Analysis**:
```markdown
**Task A** (Assigned: Sonnet, Actual: Sonnet)
- ✅ Correct assignment - architectural decisions required
- Confidence: High (85%)

**Task B** (Assigned: Sonnet, Actual: Haiku would have worked)
- ⚠️ Over-assignment - straightforward find/replace
- Opportunity: Could have saved tokens with Haiku
- Confidence: Medium (70%)

**Task C** (Assigned: Haiku, Actual: Sonnet needed)
- ❌ Under-assignment - complex edge cases required deeper reasoning
- Lesson: Testing tasks with >10 edge cases = Sonnet minimum
- Confidence: Low (50%)
```

### 7. Communication

**Questions**:
- Were progress updates clear and timely?
- Did we narrate investigations or work silently?
- Were blockers communicated immediately?
- Was technical reasoning explained well?

**What to Look For**:
- "Silent tool usage" (running commands without explaining why)
- Delayed blocker communication
- Commit messages clarity
- PR description completeness

**Example Feedback**:
> "Claude ran 5 analyzer checks silently without explaining findings. Future sprints should narrate diagnostic work: 'Checking analyzer status to see if warnings were fixed...'"

### 8. Requirements Clarity

**Questions**:
- Were requirements clear from the start?
- How many clarification questions were needed?
- Did we discover hidden requirements mid-sprint?
- Were non-functional requirements specified?

**What to Look For**:
- Number of AskUserQuestion calls
- Mid-sprint scope changes
- Ambiguous acceptance criteria
- Missing quality standards

**Example Feedback**:
> "Task said 'improve performance' but did not specify target (50ms? 100ms?). Need quantifiable non-functional requirements."

### 9. Documentation

**Questions**:
- Was documentation updated alongside code?
- Are docs accurate and up-to-date?
- Is documentation discoverable and well-organized?
- Did we document decisions and trade-offs?

**What to Look For**:
- Docs updated in same commit as code
- Broken links or outdated references
- Missing architecture decision records
- CHANGELOG.md completeness

**Example Feedback**:
> "Completed Sprint 9 but did not add entry to CHANGELOG.md. Add CHANGELOG update as mandatory sprint completion checklist item."

### 10. Process Issues

**Questions**:
- What errors or blockers were encountered?
- How long did they take to resolve?
- Are these errors documented for future reference?
- What process changes would prevent recurrence?

**What to Look For**:
- Common errors (test binding initialization, path escaping, etc.)
- Time spent debugging vs implementing
- Errors not in TROUBLESHOOTING.md
- Process gaps

**Example Feedback**:
> "Encountered 'Test binding not initialized' error for 10 minutes. Add to TROUBLESHOOTING.md and create test template with binding pre-configured."

### 11. Risk Management

**Questions**:
- Were risks identified before sprint?
- Did identified risks materialize?
- Were there unexpected risks?
- Were mitigations effective?

**What to Look For**:
- Risk register completeness
- Risks that occurred vs risks identified
- Mitigation effectiveness
- Unidentified risks that occurred

**Example Analysis**:
```markdown
**Identified Risk**: Refactoring might break existing tests
- Likelihood: Medium, Impact: High
- Mitigation: Run tests after each file refactored
- **Outcome**: Did not occur - mitigation effective ✅

**Unidentified Risk**: Windows build script incompatible with new dependency
- Likelihood: (not identified), Impact: Medium
- **Outcome**: Occurred - lost 2 hours debugging
- **Lesson**: Always test build scripts after dependency changes
```

### 12. Next Sprint Readiness

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

**Example Feedback**:
> "ALL_SPRINTS_MASTER_PLAN.md not updated with Sprint 9 actuals. Must update before planning Sprint 10 to ensure lessons learned are captured."

---

## Gathering Feedback

### User Feedback Collection (Phase 4.5.2)

Claude should ask user for feedback on the following topics. User can provide:
- **Brief feedback**: 1-2 sentences per topic
- **Detailed feedback**: Full analysis with examples
- **Skip**: "N/A" or "No feedback" for topics not relevant

**Feedback Template**:

```markdown
## Sprint N Retrospective Feedback

### 1. Effectiveness & Efficiency
[User feedback]

### 2. Sprint Execution
[User feedback]

### 3. Testing Approach
[User feedback]

### 4. Effort Accuracy
[User feedback]

### 5. Planning Quality
[User feedback]

### 6. Model Assignments
[User feedback]

### 7. Communication
[User feedback]

### 8. Requirements Clarity
[User feedback]

### 9. Documentation
[User feedback]

### 10. Process Issues
[User feedback]

### 11. Risk Management
[User feedback]

### 12. Next Sprint Readiness
[User feedback]
```

### Claude Analysis (Phase 4.5.3)

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

### User Approval (Phase 4.5.4)

User reviews proposed improvements and selects:
- **Implement Now**: Apply before merging PR
- **Implement Next Sprint**: Add to Sprint N+1 backlog
- **Reject**: Not valuable, skip

---

## Documentation Updates

### What to Update (Phase 4.5.6)

After user approves improvements, update relevant documents:

#### 1. ALL_SPRINTS_MASTER_PLAN.md

Update the completed sprint section with:
```markdown
### Sprint N: [Title] (COMPLETED - YYYY-MM-DD)

**Estimated Duration**: Xh
**Actual Duration**: Yh (Z% variance)
**Model Used**: Haiku/Sonnet/Opus
**Tasks Completed**: N/N
**Lessons Learned**:
- [Key lesson 1]
- [Key lesson 2]
- [Key lesson 3]

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

---

## Continuous Improvement

### Improvement Tracking

Track improvements across sprints to measure progress:

```markdown
## Process Improvement Log

| Sprint | Category | Improvement | Status | Impact |
|--------|----------|-------------|--------|--------|
| 8 | Testing | Added parallel log monitoring | ✅ Implemented | Caught 3 errors in real-time |
| 8 | Documentation | Created QUICK_REFERENCE.md | ✅ Implemented | Reduced file lookup time by 50% |
| 9 | Logging | Keyword-based logging with AppLogger | ✅ Implemented | Easy log filtering |
| 9 | Process | Added risk assessment to sprint plans | ✅ Implemented | Identified 2 risks proactively |
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

**✅ Always**:
- After every sprint (mandatory)
- After PR created and before merge
- When sprint work is complete

**❌ Never**:
- During sprint execution (too early)
- After PR already merged (too late)
- When context will be lost

### Retrospective Checklist

Use this quick checklist during Phase 4.5:

- [ ] Windows build verified (4.5.0)
- [ ] User feedback collected on 12 categories (4.5.2)
- [ ] Claude analyzed feedback and proposed improvements (4.5.3)
- [ ] User selected improvements to implement (4.5.4)
- [ ] ALL_SPRINTS_MASTER_PLAN.md updated with actuals (4.5.6)
- [ ] Relevant workflow docs updated with improvements (4.5.6)
- [ ] CHANGELOG.md updated with sprint entry (4.5.6)
- [ ] Sprint retrospective document created (4.5.6)
- [ ] Summary provided to user (4.5.7)
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

After analyzing user feedback (Phase 4.5.3), Claude should present improvement recommendations in a specific order and format for user approval.

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
  - ❌ "Comprehensive testing"
  - ✅ "All unit and integration tests are error free and produce expected results"
  - ❌ "Code quality improvements"
  - ✅ "Reduce all warnings in production code that can be accomplished in 1 hour"
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

**Version**: 1.1
**Date**: January 31, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Updates**:
- 1.1 (2026-01-31): Added "Recommendation Presentation Format" section with grouping strategy, numbering system, and template
- 1.0 (2026-01-31): Initial version extracted from Sprint 8 retrospective and SPRINT_EXECUTION_WORKFLOW.md Phase 4.5
