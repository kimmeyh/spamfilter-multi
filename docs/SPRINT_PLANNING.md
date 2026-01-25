# Sprint Planning and Development Workflow

This document describes the sprint-based development methodology used for spamfilter-multi.

**Quick Reference**:
- See **CLAUDE.md > Sprint Planning and Development Workflow** section for overview
- See **SPRINT_EXECUTION_WORKFLOW.md** for step-by-step execution checklist and procedures

---

## Overview

The spamfilter-multi project uses **time-boxed sprints** focused on delivering one key enhancement that can be:
- Fully developed and tested
- Reviewed and accepted by product managers (Claude Code and user)
- Released as a cohesive feature or bug fix

Each sprint is composed of **Cards** (GitHub issues) broken into **Tasks** assigned to models based on complexity and cognitive load.

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
- **Process**:
  1. User proposes sprint goal and selects Cards
  2. Use `/plan-sprint` skill to analyze each Card and assign models/tasks
  3. Estimate complexity (low/medium/high)
  4. Create GitHub issues with model assignments
  5. Review and commit to sprint backlog

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
- **Process**:
  1. Review each completed Card against acceptance criteria
  2. Verify tests passing and code quality acceptable
  3. Approve or request changes
  4. Collect feedback on model assignment accuracy
  5. Prepare release notes

#### Phase 4: Retrospective (Post-Sprint)
- **Duration**: 30 minutes - 1 hour
- **Participants**: All
- **Inputs**:
  - Completed Cards with feedback
  - Model assignment data from sprint
  - Issues encountered
- **Outputs**:
  - Updated `/claude/model_assignment_heuristics.json`
  - Lessons learned for next sprint
  - Process improvements identified
- **Process**:
  1. Review which model assignments were accurate (Haiku completed on first try? Sonnet needed help? Etc.)
  2. Identify failed assignments and update heuristics
  3. Discuss process improvements (was task breakdown too granular? Unclear requirements?)
  4. Plan improvements for next sprint
  5. User runs `/update-heuristics` command with outcomes

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

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All tests pass
- [ ] Code review approved

## Model Assignment
| Task | Assigned Model | Complexity | Notes |
|------|----------------|-----------|-------|
| Task A: Implement core logic | Haiku | Low | Straightforward implementation |
| Task B: Integrate with existing module | Sonnet | Medium | Requires architectural knowledge |
| Task C: Performance optimization | Opus | High | Complex optimization algorithm |

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
📋 SPRINT CARD ANALYSIS

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
- Task A: ✅ Complete (8:00 AM)
- Task B: 🔄 In Progress - [Current work description]
- Task C: ⏸️ Blocked - [Reason and escalation]

Confidence: [High/Medium/Low] that schedule remains on track
Next: [What happens next]
```

### Blockers and Escalation

If a task encounters a blocker:

1. **Document the blocker** in GitHub issue comment:
   ```markdown
   🚫 BLOCKED: [Brief description of blocker]

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
   - ✅ **Accept**: Card meets all acceptance criteria
   - 🔄 **Revise**: Minor issues, scheduled for follow-up task
   - ❌ **Reject**: Does not meet criteria, return to backlog

3. **Feedback Collection**:
   - Collect data on model assignment accuracy for heuristic updates
   - Note what worked well and what didn't

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

4. **Realistic Model Assignments**: Use `/plan-sprint` skill rather than guessing. Confidence scores reveal uncertain assignments.

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
