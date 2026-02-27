# Sprint Planning and Development Workflow

This document describes the sprint-based development methodology used for spamfilter-multi.

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** (this doc) | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Overview

The spamfilter-multi project uses **time-boxed sprints** focused on delivering one key enhancement that can be:
- Fully developed and tested
- Reviewed and accepted by product managers (Claude Code and user)
- Released as a cohesive feature or bug fix

Each sprint is composed of **Cards** (GitHub issues) broken into **Tasks** assigned to models based on complexity and cognitive load.

---

## Backlog Refinement (On-Demand)

**When**: Requested by Product Owner (not before every sprint)
**Duration**: 30-60 minutes (timeboxed)
**Purpose**: Keep future features prioritized, estimated, and ready for sprint planning

**Triggers for Refinement**:
- Product Owner explicitly requests it
- Significant new features need scoping
- Priorities have shifted due to business changes
- Backlog has grown stale (items over 3 sprints old)
- Major sprint completed that opens new possibilities

**Process Summary**:
1. **Review** - Scan current backlog, identify stale entries
2. **Prioritize** - Re-order based on value, effort, and risk
3. **Estimate** - Update estimates with velocity calibration
4. **Add** - Capture newly identified work items
5. **Cleanup** - Remove obsolete items, update dependencies
6. **Commit** - Push changes to repository

**Detailed Process**: See `BACKLOG_REFINEMENT.md` for complete step-by-step guide.

**Quick Priority Changes**: Minor priority adjustments can be handled during sprint planning without full refinement session.

---

## Sprint Structure

### Sprint Duration
- **Standard sprint length**: 1-2 weeks (user-defined at sprint kickoff)
- **Sprint phases**: Planning → Execution → Review → Retrospective
- **Naming convention**: `Sprint N` where N is sequential (Sprint 1, Sprint 2, etc.)

### Roles
- **Product Managers**: Claude Code and user (define sprint goals, accept completed work)
- **Developers**: Claude Code models (Haiku, Sonnet, Opus) executing assigned tasks
- **Sprint Master**: User (facilitates ceremonies, manages blockers, updates heuristics)

### Sprint Phases

#### Phase 1: Planning (Kickoff)
- **Duration**: 30 minutes - 1 hour
- **Participants**: All
- **Inputs**:
  - Sprint goal (1-2 sentence vision)
  - Prioritized backlog of potential Cards
- **Outputs**:
  - Sprint backlog (Cards selected for sprint)
  - Task breakdown for each Card (with model assignments)
  - Acceptance criteria for each Card
  - **SPRINT_<N>_SUMMARY.md** for previous sprint (background process)
  - **SPRINT_N_PLAN.md** for current sprint (MANDATORY - see SPRINT_EXECUTION_WORKFLOW.md § 3.2.2)
- **Process**:
  1. **Create SPRINT_<N>_SUMMARY.md** for previous sprint (background process - see SPRINT_EXECUTION_WORKFLOW.md § 3.2.1)
     - Use retrospective, CHANGELOG, git history, and GitHub issues as sources
     - Update "Past Sprint Summary" table in ALL_SPRINTS_MASTER_PLAN.md
     - Keeps master plan focused on current/future work
  2. User proposes sprint goal and selects Cards
  3. Use `/plan-sprint` skill to analyze each Card and assign models/tasks
  4. Estimate complexity (low/medium/high)
  5. Create GitHub issues with model assignments
  6. Review and commit to sprint backlog

**Example Goal**: "Improve email security by implementing DKIM validation for OAuth providers"

#### Phase 2: Execution (Daily/Throughout Sprint)
- **Duration**: Bulk of sprint time
- **Participants**: Claude Code models (as assigned)
- **Inputs**: Assigned Cards from sprint backlog
- **Outputs**:
  - Completed tasks with passing tests
  - Pull requests linked to Cards
  - Daily progress updates
- **Process**:
  1. Haiku picks up assigned Cards/Tasks, works autonomously
  2. If blocked or needs design input → escalates to Sonnet
  3. If Sonnet cannot complete → escalates to Opus
  4. All task status updates recorded in GitHub issue comments
  5. Blockers reported immediately to user
  6. Code changes linked to GitHub issues

#### Phase 3: Review (Sprint Conclusion)
- **Duration**: 1-2 hours
- **Participants**: All
- **Inputs**:
  - Completed Cards with pull requests
  - Test results and code quality metrics
- **Outputs**:
  - Acceptance decision for each Card (accept/reject/rework)
  - Release notes entries
  - Data for heuristic updates
  - **MANDATORY**: Updated CHANGELOG.md entry
  - **MANDATORY**: Updated ALL_SPRINTS_MASTER_PLAN.md
- **Process**:
  1. Review each completed Card against acceptance criteria
  2. Verify tests passing and code quality acceptable
  3. Approve or request changes
  4. Collect feedback on model assignment accuracy
  5. **Update CHANGELOG.md** (MANDATORY - see SPRINT_EXECUTION_WORKFLOW.md Phase 7.7)
     - Add entry under `## [Unreleased]` section
     - Format: `### YYYY-MM-DD` with sprint summary
     - Include all user-facing changes from sprint
  6. **Update ALL_SPRINTS_MASTER_PLAN.md** (MANDATORY - see SPRINT_EXECUTION_WORKFLOW.md Phase 7.7)
     - Add actual duration vs estimated to current sprint section
     - Record lessons learned
     - Update future sprint dependencies
     - **NOTE**: Full sprint details archived to SPRINT_<N>_SUMMARY.md during next sprint planning (Phase 3)
  7. Prepare release notes (if needed for major releases)
  8. **Build and Launch Application** (MANDATORY - Phase 5.3 in SPRINT_EXECUTION_WORKFLOW.md)
     - Claude Code MUST build and launch the app BEFORE declaring ready for manual testing
     - Windows: `cd mobile-app/scripts && .\build-windows.ps1`
     - Android: `cd mobile-app/scripts && .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
     - Verify build succeeds and app launches without errors
     - User should NOT have to build the app themselves

#### Phase 4: Retrospective (Post-Sprint)
- **Duration**: 30 minutes - 1 hour
- **Participants**: All
- **Inputs**:
  - Completed Cards with feedback
  - Model assignment data from sprint
  - Issues encountered
  - Updated CHANGELOG.md and ALL_SPRINTS_MASTER_PLAN.md (from Phase 5)
- **Outputs**:
  - Updated `/claude/model_assignment_heuristics.json`
  - Lessons learned for next sprint
  - Process improvements identified
  - SPRINT_N_RETROSPECTIVE.md document (if detailed review conducted)
- **Process**:
  1. Review which model assignments were accurate (Haiku completed on first try? Sonnet needed help? Etc.)
  2. Identify failed assignments and update heuristics
  3. Discuss process improvements (was task breakdown too granular? Unclear requirements?)
  4. Plan improvements for next sprint
  5. User runs `/update-heuristics` command with outcomes
  6. **Verify MANDATORY updates completed** (from Phase 3):
     - [ ] CHANGELOG.md updated
     - [ ] ALL_SPRINTS_MASTER_PLAN.md updated with actuals and lessons learned
  7. Create detailed retrospective document if needed (see `docs/SPRINT_RETROSPECTIVE.md`)

---

## GitHub Issue Workflow

All sprint work is tracked via GitHub issues using standardized templates in `.github/ISSUE_TEMPLATE/`.

### Issue Types and Templates

#### 1. Sprint Card (`sprint_card.yml`)
The main work item representing a deliverable feature or bug fix.

**Structure**:
```markdown
**Sprint**: Sprint 5
**Category**: Enhancement
**Priority**: High

## Description
Clear statement of what needs to be done and why.

## Value Statement
**This enables**: [What capability this unlocks]
**This prevents**: [What problem this solves]

## Acceptance Criteria
- [ ] Criterion 1 (quantifiable: "All unit and integration tests pass" not "comprehensive testing")
- [ ] Criterion 2 (measurable: "Reduce analyzer warnings to 0" not "improve code quality")
- [ ] All tests pass
- [ ] Code review approved

**IMPORTANT**: All acceptance criteria must be quantifiable and measurable. Avoid subjective terms like "comprehensive", "good quality", or "works well".

**Examples**:
- [FAIL] BAD: "Comprehensive testing"
- [OK] GOOD: "All unit and integration tests are error free and produce expected results"
- [FAIL] BAD: "Code quality improvements"
- [OK] GOOD: "Reduce all warnings in production code that can be accomplished in 1 hour"

## Model Assignment
| Task | Assigned Model | Complexity | Effort Est. | Notes |
|------|----------------|-----------|-------------|-------|
| Task A: Implement core logic | Haiku | Low | 1h | Straightforward implementation |
| Task B: Integrate with existing module | Sonnet | Medium | 2h | Requires architectural knowledge |
| Task C: Performance optimization | Opus | High | 1.5h | Complex optimization algorithm |

**Total Estimated Effort**: 4.5h + 20% buffer (0.9h) = 5.4h

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Task A breaks existing tests | Low | Medium | Run full test suite after implementation |
| Task B requires API changes | Medium | High | Review API design with architect before coding |
| Task C performance targets not met | Medium | Medium | Benchmark before and after, have rollback plan |

**Risk Level**: Medium (even for maintenance work, document "Low - maintenance work" if no risks identified)

## Sprint Backlog Tracking
- [ ] Planning: Assigned to sprint backlog
- [ ] Execution: In progress
- [ ] Review: Ready for acceptance
- [ ] Retrospective: Accepted/Rejected + Heuristic feedback recorded
```

**Labels**: `sprint`, `card`, `priority:high/medium/low`, `phase:3.x`

#### 2. Bug Report (`bug_report.yml`)
Issues reporting bugs discovered during development or testing.

**Structure**:
```markdown
**Platform**: Android / Windows / macOS / iOS / Linux
**Flutter Version**: 3.x.x
**Dart Version**: 3.x.x

## Description
Brief summary of the bug.

## Steps to Reproduce
1. Step 1
2. Step 2
3. Expected: X
4. Actual: Y

## Logs and Screenshots
Attach relevant logs, screenshots, or error messages.

## Model Assignment Recommendation
- **Suggested Model**: Haiku (if straightforward) / Sonnet (if requires design knowledge) / Opus (if needs deep investigation)
- **Reasoning**: Why this model is recommended
```

**Labels**: `bug`, `platform:android/windows/macos/ios/linux`, `priority:critical/high/medium`, `sprint` (if assigned to sprint)

#### 3. Feature Request (`feature_request.yml`)
Issues proposing new capabilities or enhancements.

**Structure**:
```markdown
## Use Case
Describe the user problem or opportunity.

## Proposed Solution
Detailed description of the proposed feature.

## Alternatives Considered
Other approaches considered and why they were not chosen.

## Impact Analysis
- **Affected Components**: Which parts of the codebase are impacted?
- **Breaking Changes**: Does this break existing functionality?
- **Dependencies**: Are new dependencies required?

## Model Assignment Recommendation
- **Suggested Model**:
- **Task Breakdown**: How should this be broken into tasks?
```

**Labels**: `feature-request`, `enhancement`, `priority:high/medium/low`

#### 4. Test Failure (`test_failure.yml`)
Issues for test failures requiring investigation and fix.

**Structure**:
```markdown
**Test File**: `test/unit/rule_evaluator_test.dart`
**Test Name**: `test_spam_rule_with_header_matching`
**Flutter Version**: 3.x.x
**Platform**: Windows / macOS / Linux / Android / iOS

## Failure Output
[Paste full error message and stack trace]

## Steps to Reproduce
1. Run: `flutter test test/unit/rule_evaluator_test.dart`
2. Expected: All tests pass
3. Actual: Test fails with above error

## Investigation Notes
Any relevant context or prior debugging attempts.

## Model Assignment
- **Suggested Model**: Haiku (simple fix) / Sonnet (requires architecture understanding)
```

**Labels**: `test-failure`, `sprint` (if blocking sprint), `priority:high/medium`

### Issue Labeling Strategy

Use consistent labels for organization:

**Category**:
- `sprint` - Part of sprint backlog
- `card` - Main work item (vs task)
- `bug` - Bug report
- `feature-request` - Feature proposal
- `test-failure` - Test issue

**Priority** (for non-sprint items):
- `priority:critical` - Breaks core functionality
- `priority:high` - Should be in next sprint
- `priority:medium` - Nice to have
- `priority:low` - Backlog

**Platform** (if relevant):
- `platform:android`
- `platform:windows`
- `platform:macos`
- `platform:ios`
- `platform:linux`

**Phase**:
- `phase:3.5` (current)
- `phase:4.0` (planned)
- `phase:future` (long-term backlog)

---

## Model Assignment Methodology

### Core Principles

The goal is to maximize efficiency by:
1. **Haiku handles 70%+ of work** (straightforward tasks where speed and cost matter)
2. **Sonnet handles 20-25% of work** (architectural, complex refactoring)
3. **Opus handles 5-10% of work** (deep debugging, critical path)

Tasks are assigned based on **complexity**, **risk**, and **cognitive load** - not by effort estimate.

### Model Capability Matrix

#### Haiku - Efficient Implementer
**Strengths**:
- Straightforward feature implementation
- Bug fixes with clear root cause
- Unit tests and integration tests
- Code documentation and comments
- Simple refactoring (rename, extract method)
- Regex pattern creation and testing
- Mobile app UI components with existing patterns

**Limitations**:
- Does not handle architectural decisions well
- Struggles with ambiguous requirements
- May miss cross-cutting concerns
- Limited context for very large changes

**Task Examples**:
- "Add new filter rule type following existing patterns" → Haiku
- "Fix off-by-one error in email counter" → Haiku
- "Update UI label from 'Inbox' to 'Primary Folder'" → Haiku
- "Create 15 new regex patterns for spam detection" → Haiku
- "Write unit tests for RuleEvaluator edge cases" → Haiku

#### Sonnet - Architect and Problem Solver
**Strengths**:
- Architectural decisions and design
- Complex refactoring affecting multiple components
- Performance optimization (algorithm-level)
- Ambiguous requirement clarification
- Cross-cutting concerns (logging, error handling)
- Integration between multiple systems
- Investigating root causes of complex bugs

**Limitations**:
- Not needed for simple, well-defined work
- May over-engineer straightforward solutions
- Slower execution than Haiku (but better design)

**Task Examples**:
- "Refactor EmailProvider interface to support new OAuth flow" → Sonnet
- "Design caching strategy for email folder list" → Sonnet
- "Investigate intermittent test failures in scan provider" → Sonnet
- "Implement DKIM validation across all email adapters" → Sonnet
- "Optimize email scanning performance for large inboxes" → Sonnet (algorithm-level, not just code cleanup)

#### Opus - Deep Problem Solver
**Strengths**:
- Deep debugging of complex, multi-component issues
- Performance optimization at systemic level
- Novel algorithm implementation
- Critical security issues
- Architecture-wide refactoring
- Edge cases and race conditions

**Limitations**:
- Overkill for routine work (wastes tokens)
- Should only be engaged when Sonnet is stuck

**Task Examples**:
- "Fix intermittent race condition in token refresh during concurrent email scans" → Opus
- "Implement efficient pattern matching for 10,000+ regex rules" → Opus
- "Root cause analysis of 50% performance regression in email filtering" → Opus
- "Security audit and hardening of OAuth token storage" → Opus

### Assignment Algorithm

Use the `/plan-sprint` skill to analyze Cards and assign models. The skill uses the following heuristic scoring system:

**Complexity Scoring** (0-40 points):
- **File Impact**:
  - 1 file modified = +10 (Haiku territory)
  - 2-3 files modified = +20 (Sonnet zone)
  - 4+ files or architecture-wide = +30 (Opus likely)

- **Cognitive Load**:
  - "Bug fix" or "add" in scope = +5 (Haiku)
  - "Refactor" or "optimize" = +15 (Sonnet)
  - "Design" or "architecture" = +25 (Opus)

- **Risk Factors**:
  - UI-only changes = +5
  - Core model changes = +20
  - New dependencies = +15
  - Security-related = +20

**Model Assignment Thresholds**:
- **Score ≤ 15**: Assign to Haiku
- **Score 16-25**: Assign to Sonnet (or Haiku with Sonnet backup)
- **Score > 25**: Assign to Opus

**Confidence Scoring**:
- **High confidence** (85%+): Prior similar task completed by assigned model
- **Medium confidence** (60-84%): Score is borderline or task type is new
- **Low confidence** (<60%): High-risk assignment, manual review recommended

### Escalation Patterns

**Haiku → Sonnet**:
- Haiku encounters architectural decision needed
- Haiku finds cross-cutting concerns affecting multiple components
- Task requires understanding design rationale from existing code
- Test failures suggest design issue, not implementation issue

**Sonnet → Opus**:
- Sonnet completes design but hits fundamental algorithmic challenge
- Performance profiling reveals systemic bottleneck
- Security analysis uncovers critical vulnerability
- Sonnet attempts fail and require fresh perspective

### Recording Assignment Outcomes

After sprint review, update the heuristic database with assignment accuracy:

```json
{
  "date": "2026-01-31",
  "sprint": "Sprint 5",
  "assignment_outcomes": [
    {
      "card": "Issue #45 - Add DKIM validation",
      "assigned_model": "haiku",
      "actual_model_needed": "haiku",
      "status": "success",
      "completed_on_first_try": true,
      "time_to_completion": "2 hours"
    },
    {
      "card": "Issue #48 - Optimize folder discovery",
      "assigned_model": "sonnet",
      "actual_model_needed": "opus",
      "status": "escalated",
      "reason": "Complex algorithm optimization required",
      "escalation_point": "After 3 hours of Sonnet work"
    }
  ]
}
```

The user runs `/update-heuristics` after sprint retrospective with this data.

---

## Planning Process (Using `/plan-sprint` Skill)

### Quick Start: Analyzing a Single Card

**Input**: Card description from GitHub issue
```
Sprint Goal: Improve email security
Card: Add DKIM validation for all OAuth providers
Details: Implement DKIM header validation in RuleEvaluator, add to all adapter implementations, create tests
```

**Run `/plan-sprint` skill**:
```
/plan-sprint Issue #45 - Add DKIM validation for all OAuth providers
```

**Output**:
```
[CHECKLIST] SPRINT CARD ANALYSIS

Card: Add DKIM validation for all OAuth providers
Complexity Score: 18/40

Task Breakdown:
  1. Task A: Add DKIM validation logic to RuleEvaluator
     - Model: Haiku
     - Complexity: Low
     - Files: 1 (rule_evaluator.dart)
     - Rationale: Clear implementation following existing pattern

  2. Task B: Integrate DKIM check into GenericIMAP and Gmail adapters
     - Model: Sonnet
     - Complexity: Medium
     - Files: 2 (generic_imap_adapter.dart, gmail_api_adapter.dart)
     - Rationale: Requires understanding both adapter patterns

  3. Task C: Write comprehensive tests for DKIM validation
     - Model: Haiku
     - Complexity: Low
     - Files: 1 (rule_evaluator_test.dart)
     - Rationale: Testing patterns well-established

Recommended GitHub Labels: sprint, card, phase:3.5, priority:high

Confidence: High (83%) - Similar pattern used for header validation in Issue #37
```

### Analyzing Multiple Cards (Sprint Planning)

**Input**: 5-10 Cards selected for sprint

```
/plan-sprint sprint-backlog
[Paste list of Cards or issue numbers]
```

**Output**: Table with all Cards, model assignments, confidence scores

---

## Execution Tracking

### Daily Status Updates

While executing tasks, models update the GitHub issue with progress:

**Task Status Comment Template**:
```markdown
**Status Update** - [Date] [Time]
- Task A: [OK] Complete (8:00 AM)
- Task B: [PENDING] In Progress - [Current work description]
- Task C: [BLOCKED] - [Reason and escalation]

Confidence: [High/Medium/Low] that schedule remains on track
Next: [What happens next]
```

### Blockers and Escalation

If a task encounters a blocker:

1. **Document the blocker** in GitHub issue comment:
   ```markdown
   [STOP] BLOCKED: [Brief description of blocker]

   Root cause: [Why this is blocking progress]
   Attempted solutions: [What did not work]
   Needs: [What is required to unblock - input from user, design decision, escalation to Sonnet/Opus]
   ```

2. **Escalate immediately** if:
   - Architectural decision needed (Haiku → Sonnet)
   - Algorithmic breakthrough required (Sonnet → Opus)
   - User input needed for requirements
   - External dependency blocked

3. **User resolves blocker** within 24 hours or notes issue for sprint review

### Sprint Burn-Down

Sprints use voluntary status tracking (not mandatory metrics):
- User may track approximate task counts as optional visibility
- Focus is on completion quality, not velocity (avoid artificial rushing)
- If sprint scope becomes unrealistic, re-plan rather than compromise quality

---

## Review and Acceptance

### Sprint Review Meeting (End of Sprint)

**Participants**: Claude Code (Haiku, Sonnet, Opus), User

**Agenda** (60-90 minutes):

1. **Card Presentation** (5 min per Card)
   - Completed task overview
   - Demo if applicable (show running tests, screenshot of UI changes)
   - Link to merged pull request
   - Review against acceptance criteria

2. **Acceptance Decision**:
   - [OK] **Accept**: Card meets all acceptance criteria
   - [PENDING] **Revise**: Minor issues, scheduled for follow-up task
   - [FAIL] **Reject**: Does not meet criteria, return to backlog

3. **Feedback Collection**:
   - Collect data on model assignment accuracy for heuristic updates
   - Note what worked well and what did not

### Release Notes

Accepted Cards are added to `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/) format:

**Example Entry**:
```markdown
### 2026-01-31
- **feat**: Add DKIM validation for Gmail OAuth emails (Issue #45)
- **feat**: Implement dynamic folder discovery for all email providers (Issue #37)
- **fix**: Resolve race condition in concurrent email scans (Issue #51)
```

---

## Retrospective and Heuristic Updates

### Retrospective Meeting (60 minutes, post-sprint)

**Process**:

1. **Model Assignment Review** (20 min)
   - Which models delivered successfully on first assignment?
   - Which assignments escalated? Why?
   - Update success/failure data

2. **Process Improvements** (20 min)
   - What went well? (accelerators)
   - What was difficult? (blockers)
   - What should we change next sprint?

3. **Heuristic Updates** (20 min)
   - User runs `/update-heuristics` with sprint data
   - Database is updated with new patterns and success rates
   - Thresholds adjusted if needed

### Running `/update-heuristics`

**Command** (run after retrospective):
```
/update-heuristics sprint:5 outcomes:[json-data]
```

**Effect**:
- Adds new task patterns if any novel work types were encountered
- Updates success rates for existing patterns
- Records escalations in learning log
- Suggests threshold adjustments if needed

**Example Heuristic Update**:
```json
Before Sprint 5:
{
  "pattern": "Add validation logic to RuleEvaluator",
  "recommended_model": "haiku",
  "success_rate": 0.92,
  "sample_size": 12
}

After Sprint 5 (with 1 new success):
{
  "pattern": "Add validation logic to RuleEvaluator",
  "recommended_model": "haiku",
  "success_rate": 0.923,
  "sample_size": 13
}

Plus new entry in learning log:
{
  "date": "2026-01-31",
  "pattern": "Add validation logic with adapter integration",
  "status": "escalated_to_sonnet",
  "reason": "Underestimated complexity of multi-adapter changes"
}
```

---

## Best Practices

### For Effective Sprint Planning

1. **Clear Sprint Goal**: 1-2 sentences that fit on a slide. Example: "Improve security by implementing DKIM validation." NOT "Work on various quality improvements."

2. **Right-Sized Cards**: Each Card should be completable in 4-8 hours with 1-2 models. If larger, break into multiple Cards.

3. **Clear Acceptance Criteria**: Measurable, specific criteria. Example: "All tests pass" or "Gmail DKIM validation working on 100 test emails" - NOT "Works well" or "No regressions."
   - **Quantifiable Criteria**: Every acceptance criterion must be measurable. Avoid subjective terms like "comprehensive", "good quality", or "works well".
   - **Value Statement**: Each task must include "This enables..." or "This prevents..." statement explaining why the work matters.
   - **Explicit Criteria from Issues**: Sprint plan should repeat acceptance criteria from GitHub issues (must match exactly). All criteria reflected in sprint execution/completion checklists.

4. **Realistic Model Assignments**: Use `/plan-sprint` skill rather than guessing. Confidence scores reveal uncertain assignments.

5. **Effort Estimation**: Include estimated hours for each task, even for maintenance sprints.
   - **Base Estimates**: Estimate implementation time for each task
   - **20% Buffer for Unknowns**: Add 20% time buffer to manual testing tasks for potential debugging
   - **Examples**:
     - Task A: 1h implementation
     - Task B: 2h implementation + manual testing
     - Task C: 1.5h implementation
     - **Total**: 4.5h + 20% buffer on Task B (0.4h) = 4.9h estimated
   - **Track Actuals**: Log actual time duration and Claude Code effort time spent per task for future estimation calibration

6. **Risk Assessment**: Every sprint task must document risks (even if "Low - maintenance work").
   - **Risk Description**: What could go wrong?
   - **Likelihood**: Low / Medium / High
   - **Impact**: Low / Medium / High
   - **Mitigation Strategy**: How to prevent or minimize the risk
   - **Examples**:
     - "Breaking existing tests (Low/Medium): Run full test suite after implementation"
     - "API changes required (Medium/High): Review design before coding"
     - "Performance targets not met (Medium/Medium): Benchmark before/after with rollback plan"

7. **Integration Test Coverage**: For tasks that include comprehensive testing, include all impacted integration tests that combine components.
   - Do NOT only add unit tests - integration tests verify components work together
   - Example: EmailScanner integration test (scanner + provider + evaluator working together)
   - Example: Rule loading integration test (YAML service + RuleSetProvider + LocalRuleStore)
   - Integration tests should cover data flow, state management, error handling across boundaries

8. **Stretch Goals** (For Low-Complexity Sprints): Include 1-2 "stretch goal" tasks to utilize full capacity.
   - Stretch goals are optional tasks that can be completed if primary tasks finish early
   - Should be low-risk, low-complexity tasks that add value
   - Examples: Additional test coverage, minor documentation improvements, code cleanup
   - Clearly mark as "Stretch Goal" in sprint plan
   - Do NOT block sprint completion if stretch goals are not completed

### For Smooth Execution

1. **Model Autonomy**: Once assigned, models work independently until blocked or escalated. Avoid context-switching with multiple questions.

2. **Immediate Escalation**: If blocked, escalate immediately rather than struggling silently for hours.

3. **Test-First Validation**: Tests passing is the primary acceptance signal, not code review opinion.

4. **Document Decisions**: Architecture decisions made during sprint are recorded in commit messages and code comments for future reference.

### For Accurate Model Assignment Over Time

1. **Track Outcomes**: Record every assignment (success/escalation/failure) after each sprint.

2. **Watch for Patterns**: After 3-4 sprints, look for patterns (e.g., "Haiku always escalates on OAuth changes" = needs Sonnet from start).

3. **Adjust Thresholds**: If success rate drops below 80% for any model assignment category, investigate and adjust scoring.

4. **Learn from Escalations**: When Sonnet escalates to Opus, add entry to learning log for future reference.

---

## FAQ

**Q: What if a Card grows larger mid-sprint?**
A: Document the scope change, re-run `/plan-sprint` to see if model assignment should change, escalate if needed. Sprint scope can be adjusted post-retrospective for future sprints.

**Q: Can Haiku refuse a task?**
A: Yes. If Haiku determines it cannot complete successfully, it should escalate to Sonnet immediately (don't struggle). Escalations are tracked in heuristics for learning.

**Q: How do we handle urgent bugs not in sprint?**
A: Urgent production bugs can be pulled into sprint as interrupt work. Update sprint goal and adjust other Cards as needed. Track interrupts in retrospective.

**Q: What if a task is still in progress at sprint end?**
A: Move incomplete work back to backlog or create follow-up Card. Partially completed work is not accepted unless acceptance criteria are fully met.

**Q: Can we run multiple sprints in parallel?**
A: Not recommended. Sequential sprints allow learning from retrospectives to improve future sprints. If workload requires multiple streams, use different teams.

---

## Related Documentation

- **CLAUDE.md** - Quick reference and development philosophy
- **CHANGELOG.md** - Released features and bug fixes
- **ISSUE_BACKLOG.md** - Current open issues and priorities
- **.github/ISSUE_TEMPLATE/** - GitHub issue templates for Cards and tasks
- **`.claude/model_assignment_heuristics.json`** - Machine-readable heuristic database
