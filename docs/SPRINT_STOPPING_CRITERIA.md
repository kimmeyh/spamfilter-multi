# Sprint Stopping Criteria

**Purpose**: Clarify when Claude Code models should STOP working and what actions to take based on the reason for stopping.

**Audience**: Claude Code models executing sprint tasks; User reviewing sprint execution.

**Last Updated**: January 31, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** (this doc) | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |

---

## Overview

During sprint execution, models work autonomously until one of these stopping criteria is met. This document clarifies:
- When to STOP working
- Why stopping is necessary
- What action to take when stopping

**Key Principle**: Stopping is NOT failure. Stopping at the right time prevents wasted effort and enables rapid feedback.

---

## Primary Stopping Criteria

### 1. ✅ NORMAL COMPLETION - All Sprint Tasks Finished

**When**: All tasks defined in sprint plan are complete and tested.

**Indicators**:
- [ ] All Task A, B, C... marked complete in GitHub issues
- [ ] All tests passing (100% pass rate)
- [ ] Code analysis shows zero errors
- [ ] Local code review completed
- [ ] No known blockers or regressions

**Action**:
1. Proceed to Phase 3.3 (Manual Testing in parallel)
2. Once testing complete → Phase 4 (PR creation)
3. User will conduct Phase 4.5 (Sprint Review) before merge

**Timing**: This is the expected normal path. No user approval needed - this was pre-approved in sprint plan approval.

---

### 2. 🔄 BLOCKED - Cannot Proceed Without External Input

**When**: Encountered a blocker that cannot be resolved by the assigned model.

**Blockers Include**:
- Architectural decision needed (Haiku → escalate to Sonnet)
- Complex algorithm required (Sonnet → escalate to Opus)
- User input needed for requirements clarification
- External API issue (email provider auth, network problem)
- Missing dependency or environment issue
- Unforeseen complexity exceeds model's scope

**Indicators**:
- [ ] Error persists after 2-3 attempts to resolve
- [ ] Root cause requires knowledge outside model's domain
- [ ] Attempted solutions failed
- [ ] Clear that escalation is needed

**Action**:
1. Document blocker in GitHub issue comment (template below)
2. Share blocking issue with user immediately (no waiting)
3. User or escalated model provides input
4. Resume execution

**Blocker Documentation Template**:
```markdown
🚫 BLOCKED: [Brief description]

Root Cause: [Why this is blocking progress]

Attempted Solutions:
- [Approach 1] - [Why it did not work]
- [Approach 2] - [Why it did not work]

Escalation Needed To: [Sonnet / Opus / User]

What's Required to Unblock:
- [Input or decision needed]
- [Alternative approach]
```

**Example**:
```markdown
🚫 BLOCKED: EmailProvider interface refactor affecting all adapters

Root Cause: Current interface has hardcoded assumptions about folder
structure. New requirement is per-provider folder discovery, which
requires interface redesign affecting all 3 adapters (Gmail, IMAP, Outlook).

Attempted Solutions:
- Added adapter-specific method to interface → Creates duplication
- Used strategy pattern → Adds excessive complexity
- Extended interface → Breaks existing implementations

Escalation Needed To: Sonnet

What's Required to Unblock:
- Design decision: Should folder discovery be interface method or
  adapter responsibility? Trade-offs between consistency and flexibility.
```

**Timing**: Stop immediately, do not continue past blocker. Each minute of continued effort is wasted.

---

### 3. 📋 SCOPE CHANGE - Sprint Plan Changed Mid-Sprint

**When**: User requests scope change or adds/removes tasks during sprint.

**Indicators**:
- [ ] User provides new requirement mid-sprint
- [ ] Acceptance criteria modified
- [ ] Task scope expanded significantly
- [ ] New task added after sprint started
- [ ] Task complexity underestimated by 2x+

**Action**:
1. Document the scope change request in GitHub issue
2. Notify user immediately with analysis:
   - Original estimate for task
   - New estimate if scope changed
   - Impact on sprint timeline
   - Recommendation: (a) Reduce other tasks, (b) Extend sprint, (c) Move to next sprint
3. Wait for user decision
4. Update sprint plan with new scope
5. Resume or adjust execution

**Decision Matrix**:
| Scope Change | Original Estimate | New Estimate | Recommendation |
|--------------|-------------------|--------------|-----------------|
| +10% effort | 2 hours | 2.2 hours | Include, minor impact |
| +25% effort | 2 hours | 2.5 hours | Reduce other task or extend |
| +50% effort | 2 hours | 3 hours | Move to next sprint |
| +100% effort | 2 hours | 4 hours | Definitely move to next sprint |

**Timing**: Stop execution, get user decision, then resume.

---

### 4. 🐛 DISCOVERY - Unexpected Bug Found That Affects Sprint

**When**: Found a bug in existing code that is blocking or significantly impacting sprint work.

**Bug Categories**:
- **Critical** (blocks sprint): Must fix to proceed
- **High** (affects work quality): Should fix this sprint
- **Medium** (visible but not blocking): Can defer to next sprint
- **Low** (edge case, no user impact): Defer to backlog

**Indicators**:
- [ ] Unit test fails unexpectedly
- [ ] Code analysis reports new issue
- [ ] Manual testing discovers regression
- [ ] Existing feature broken by new changes

**Action** (Per Bug Category):

**Critical Bugs**:
1. Fix immediately (this is part of sprint work)
2. Add test case to prevent regression
3. Document in GitHub issue why bug was found and fixed
4. Continue sprint execution

**High-Priority Bugs**:
1. Fix if time allows within sprint
2. If cannot fix: Create GitHub issue with `bug` label
3. Add to next sprint backlog
4. Document decision in sprint review

**Medium/Low-Priority Bugs**:
1. Create GitHub issue with `bug` label and priority
2. Do NOT fix during sprint (context switch)
3. Continue sprint execution
4. Add to backlog for future sprint

**Timing**: Decision depends on bug severity. Critical bugs stop sprint; others are deferred.

---

### 5. ⏸️ REVIEW REQUEST - User Requests Sprint Review Early

**When**: User explicitly requests sprint review before all tasks complete.

**Indicators**:
- [ ] User message: "Let's do a sprint review"
- [ ] User message: "Can you pause and do retrospective?"
- [ ] User wants feedback on direction before finishing

**Action**:
1. Complete current task to stable state
2. Commit any in-progress work
3. Proceed to Phase 4.5 (Sprint Review)
4. Provide feedback, collect user feedback
5. Decide: (a) Resume sprint, (b) Wrap up and merge, (c) Adjust scope

**Timing**: Stop when requested by user. This is a legitimate reason to pause.

---

### 6. 🏁 SPRINT REVIEW COMPLETE - Phase 4.5 Done

**When**: Phase 4.5 (Sprint Review) is complete, documentation improved, ready for PR merge.

**Indicators**:
- [ ] Windows build successful
- [ ] User feedback collected
- [ ] Improvement suggestions implemented
- [ ] Documentation updated
- [ ] PR ready for user approval

**Action**:
1. Notify user: "Phase 4.5 complete, PR ready for review and approval"
2. Wait for user to review PR
3. Once approved: Merge to develop branch
4. Cleanup: Delete feature branch, close sprint cards
5. Begin next sprint

**Timing**: This is the normal end of sprint. Wait for user approval before merge.

---

### 7. ❌ FAILURE - Cannot Proceed, Needs Redesign

**When**: Fundamental design issue discovered that requires rethinking approach.

**Indicators**:
- [ ] Test failures suggest design flaw, not implementation bug
- [ ] Attempted solutions create fragile/complex code
- [ ] Performance issues at systemic level
- [ ] Architecture does not support requirements

**Action**:
1. Document the design issue in GitHub issue
2. Escalate to Sonnet or Opus for design review
3. Propose alternative approaches (2-3 options)
4. Wait for design decision
5. Restart implementation with new design

**Example**:
```markdown
Design Issue: RuleEvaluator Sequential Execution Too Slow

Current Design: Rules evaluated one-by-one sequentially
Performance: ~5ms per email (unacceptable for 10,000+ emails)

Attempted Optimization:
- Parallel rule evaluation → Test failures (thread safety issues)
- Batch evaluation → Still slow, fundamental algorithm issue

Root Cause: Sequential evaluation of every rule against every email
is O(n*m) complexity. With 1000 rules × 10,000 emails = 10M comparisons.

Proposed Alternatives:
1. Index-based rule dispatch (group rules by From domain)
2. Bloom filter pre-filtering (eliminate obvious non-matches)
3. Decision tree compilation (optimize rule checking order)

Needs: Architectural decision on which approach best fits our
constraints (performance, maintainability, test coverage).
```

**Timing**: Stop immediately, escalate to appropriate model/user, redesign before continuing.

---

### 8. 📊 CONTEXT LIMIT APPROACHING - Efficiency Break

**When**: Context usage approaches limit and continued work becomes inefficient.

**Indicators**:
- [ ] Context usage > 80% of available budget
- [ ] Models report context pressure affecting quality
- [ ] Token usage rising faster than work completion
- [ ] No major milestones achievable in remaining context

**Action**:
1. Summarize current state of sprint
2. Commit all current work
3. Notify user: "Context usage at X%, stopping for efficiency"
4. Suggest user compacts/continues in fresh conversation
5. (OPTIONAL) User can `/compact` and continue with fresh context

**Timing**: Proactive stopping to maintain quality. Better to stop at 80% than continue at reduced effectiveness.

---

### 9. ⏰ TIME LIMIT REACHED - Scheduled End of Sprint

**When**: Sprint duration reaches planned limit (e.g., "Sprint lasts until Friday 5 PM").

**Indicators**:
- [ ] Scheduled sprint end time reached
- [ ] User indicates sprint should wrap up
- [ ] Week/milestone boundary reached

**Action**:
1. Complete current task to stable state
2. Commit all work
3. Proceed to Phase 4 (PR creation) if not already there
4. Proceed to Phase 4.5 (Sprint Review)
5. Wrap up and await merge

**Timing**: Respect scheduled sprint boundaries. Better to complete remaining tasks next sprint than to extend indefinitely.

---

### 10. 🚫 SHOULD NOT STOP - Implementation Decision

**When**: Need to make implementation decision during task execution.

**Examples**:
- Should I use method A or method B?
- Should I refactor this class or extend it?
- Should I add parameter X to this function?
- Should I change method signature from `foo(Map<String, String> headers)` to `foo(EmailMessage message)`?

**Decision Rule**:
1. Does task acceptance criteria specify which approach? → Use that approach
2. Does task acceptance criteria leave it open? → Use best engineering judgment, document decision, continue
3. Does decision fundamentally change task scope? → STOP and ask (Criterion 3: Scope Change)

**Action**: Make decision, document in code comments/commit message, continue. Do NOT stop for approval.

**Example - Correct Behavior**:
```
Task A: "Fix pattern matching to use extracted email instead of raw header"
Acceptance Criteria: "Email pattern matching should use message.from field"

Claude realizes: Need to change method signature to access message.from
Claude checks: Does this change task scope? → No, it enables acceptance criteria
Claude decision: Change signature, document in commit message, continue
Claude does NOT ask: "Should I change the method signature?"
```

**Timing**: This is NOT a stopping criterion. Make decision and continue immediately.

---

## What Should NOT Cause Stopping

These are NOT valid reasons to stop:

| Item | Why NOT | Correct Action |
|------|---------|-----------------|
| **Single test fails** | Part of normal development | Fix the test, continue |
| **Code analysis warning** | Address it or document why | Fix it, continue |
| **Waiting for git push** | Async operation, use background | Push in parallel while continuing |
| **Uncertainty about approach** | Think out loud, document, continue | Make best guess, test, iterate |
| **Feature looks incomplete** | May be intentionally minimal | Complete acceptance criteria, continue |
| **Feeling tired/stuck** | Not an external blocker | Take a break, then continue |
| **Minor code style issue** | Fix on next commit, continue | Document as tech debt, continue |

---

## Decision Tree: Should I Stop?

```
START: Am I working on sprint tasks?
│
├─ Are all sprint tasks complete?
│  ├─ YES → Stop (Criterion 1: Normal Completion)
│  └─ NO → Continue
│
├─ Am I blocked on something?
│  ├─ YES → Stop (Criterion 2: Blocked - document and escalate)
│  └─ NO → Continue
│
├─ Did scope change mid-sprint?
│  ├─ YES → Stop (Criterion 3: Scope Change - wait for user decision)
│  └─ NO → Continue
│
├─ Did I find an unexpected bug?
│  ├─ CRITICAL → Stop and fix it (Criterion 4: Bug - Critical)
│  ├─ HIGH → Consider fixing (Criterion 4: Bug - High)
│  ├─ MEDIUM/LOW → Defer (Criterion 4: Bug - Medium/Low)
│  └─ NO BUG → Continue
│
├─ Did user request sprint review early?
│  ├─ YES → Stop (Criterion 5: Review Request)
│  └─ NO → Continue
│
├─ Is Phase 4.5 (Sprint Review) complete?
│  ├─ YES → Stop (Criterion 6: Sprint Review Complete)
│  └─ NO → Continue
│
├─ Is there a fundamental design issue?
│  ├─ YES → Stop (Criterion 7: Failure - Redesign Needed)
│  └─ NO → Continue
│
├─ Is context limit approaching (>80%)?
│  ├─ YES → Stop (Criterion 8: Context Limit)
│  └─ NO → Continue
│
├─ Has scheduled sprint time limit been reached?
│  ├─ YES → Stop (Criterion 9: Time Limit)
│  └─ NO → Continue
│
└─ DEFAULT → KEEP WORKING (Do not stop for other reasons)
```

---

## Stopping Checklist

When stopping for ANY reason, complete this checklist:

- [ ] Current work committed (or stashed if temporary)
- [ ] GitHub issue updated with status
- [ ] Blockers documented (if applicable)
- [ ] User notified of stopping reason and next steps
- [ ] Next action clearly identified
- [ ] No uncommitted changes left in working directory

---

## Examples of Correct Stopping Decisions

### Example 1: Found Critical Bug

**Situation**: Executing Task B, discovered a bug in existing code that breaks the feature I am building.

**Decision**: STOP and fix
- Bug is critical (blocking sprint work)
- Fix is straightforward (1-2 hours)
- Fix improves code quality
- Update test suite while fixing

**Action**: Fix bug, update tests, continue Task B.

---

### Example 2: Test Failure Points to Design Issue

**Situation**: Writing tests for new feature, discovered that current design cannot support the test case.

**Decision**: STOP and escalate
- Issue is architectural (not implementation)
- Requires design review (Sonnet-level)
- Continuing would create fragile code
- Need guidance before proceeding

**Action**: Document design issue, escalate to Sonnet, wait for guidance.

---

### Example 3: Rule Evaluation Algorithm Too Slow

**Situation**: Implemented Task A successfully, but performance tests show 100x worse than expected.

**Decision**: STOP and redesign
- Issue is systemic (algorithm, not code)
- Simple optimization will not solve it
- Need architectural change
- Cannot continue to Task B until resolved

**Action**: Document performance issue, escalate to Opus, redesign approach.

---

### Example 4: New Requirement Added Mid-Sprint

**Situation**: Completed Task A and B, working on Task C when user adds new requirement.

**Decision**: STOP and clarify scope
- Requirement is new (not in original plan)
- Impact on timeline is unclear
- Need user decision on priority

**Action**: Analyze new requirement, propose solutions, wait for user decision.

---

### Example 5: Context Usage at 80%

**Situation**: Completed Task A and B, working on Task C when context usage reaches 80%.

**Decision**: STOP for efficiency
- Continuing risks degraded quality
- Task C is not critical (Tasks A, B complete)
- Fresh context will be more efficient

**Action**: Commit current work, notify user, suggest `/compact` for fresh start.

---

## Stopping Communication Template

When stopping for any reason, use this template to communicate:

```markdown
**STOP: [Stopping Reason]**

Status: [What was completed, what remains]

Reason: [Why stopping is necessary]

Blocker/Issue: [If applicable, describe the issue]

Action Taken:
- [Step 1]
- [Step 2]
- [Step 3]

Next Steps: [What needs to happen to resume]

User Decision Needed: [If yes, specify what decision]
```

**Example**:
```markdown
**STOP: Blocked on Architectural Decision**

Status: Task A (100% complete), Task B (80% complete), Task C (not started)

Reason: Discovered design limitation that affects Task B and C.

Blocker: RuleEvaluator needs refactoring to support safe sender exceptions.
Current sequential evaluation does not allow for exception handling.

Action Taken:
- Documented design issue in GitHub Issue #92
- Identified 3 alternative approaches
- Committed current Task A work

Next Steps:
1. Sonnet reviews design alternatives
2. Sonnet recommends approach
3. Resume Task B with new design

User Decision Needed: None (escalation to Sonnet handles this)
```

---

## Document Version Control

**Version**: 1.0
**Created**: January 27, 2026
**Applies To**: All sprints post Sprint 6
**Reference**: SPRINT_EXECUTION_WORKFLOW.md, CLAUDE.md Development Philosophy
**Related**: PHASE_0_PRE_SPRINT_CHECKLIST.md, SPRINT_PLANNING.md

---

## See Also

- **SPRINT_EXECUTION_WORKFLOW.md**: Complete sprint execution procedure
- **CLAUDE.md §168-186**: Sprint planning and development workflow
- **PHASE_0_PRE_SPRINT_CHECKLIST.md**: Pre-sprint verification
