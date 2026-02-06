# Backlog Refinement Process

**Purpose**: Guide for Product Owner-led backlog refinement sessions to prioritize, estimate, and clarify future work items before sprint planning.

**Audience**: Product Owner (user), Claude Code (facilitator)

**Last Updated**: February 1, 2026

---

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **BACKLOG_REFINEMENT.md** (this doc) | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Overview

### What is Backlog Refinement?

Backlog refinement (also called "grooming") is a collaborative session where the Product Owner and development team review, prioritize, and clarify backlog items to ensure they are ready for future sprints.

### When to Conduct Refinement

Backlog refinement is **on-demand** (not before every sprint). Conduct when:

- **Product Owner requests it** (explicit trigger)
- **Significant new features** are identified that need scoping
- **Priorities have shifted** due to business changes or user feedback
- **Backlog has grown stale** (items over 3 sprints old without review)
- **Major sprint completed** that opens new possibilities
- **Technical debt accumulated** that needs prioritization

**Note**: Quick priority changes can be handled during sprint planning without full refinement.

---

## Refinement Session Structure

### Time Investment: 30-60 Minutes

| Activity | Duration | Purpose |
|----------|----------|---------|
| **Backlog Review** | 10-15 min | Scan current items, identify stale entries |
| **Prioritization** | 10-20 min | Re-order based on value/effort/risk |
| **Estimation Updates** | 5-10 min | Adjust estimates with new learnings |
| **New Items** | 5-10 min | Add newly identified work |
| **Cleanup** | 5-10 min | Remove obsolete items, update dependencies |

### Efficiency Principles

1. **Timebox strictly** - refinement should not exceed 60 minutes
2. **Focus on top priority items** - deep dive on next 2-3 sprints only
3. **Defer details** - if item is more than 3 sprints away, leave as placeholder
4. **Use relative sizing** - compare to completed work rather than absolute estimates
5. **Parallel information gathering** - Claude Code can research while discussing

---

## Step-by-Step Process

### Step 1: Prepare the Session (Claude Code - 5 minutes)

Before the refinement session begins:

```
1. Read ALL_SPRINTS_MASTER_PLAN.md (cache key sections)
2. Read ISSUE_BACKLOG.md (open issues)
3. Gather recent sprint velocity data (actual vs estimated)
4. Prepare summary of current backlog state:
   - Total items in backlog
   - Items by priority (Critical/High/Medium/Low)
   - Stale items (not reviewed in 3+ sprints)
   - Blocked items (dependencies unresolved)
```

**Output**: Brief status summary to Product Owner

### Step 2: Backlog Review (10-15 minutes)

Present current backlog state to Product Owner:

#### 2.1 Review Open Issues

```bash
# Check GitHub issues
gh issue list --state open --label "backlog" --limit 50
gh issue list --state open --label "enhancement" --limit 50
gh issue list --state open --label "bug" --limit 50
```

#### 2.2 Review Future Features

From ALL_SPRINTS_MASTER_PLAN.md:
- **Priority 1** (Required for MVP): Must complete before release
- **Priority 2** (High Value): Significant user value
- **Priority 3** (Nice to Have): Would enhance product
- **Priority 4** (Future): Long-term considerations

#### 2.3 Identify Stale Items

Items that have not been reviewed in 3+ sprints need attention:
- Still relevant? → Keep and update
- Obsolete? → Remove with reason
- Blocked? → Identify and document blocker

### Step 3: Prioritization Discussion (10-20 minutes)

Product Owner drives prioritization using these criteria:

#### 3.1 Value Assessment (What benefit does this provide?)

| Value Level | Description | Example |
|-------------|-------------|---------|
| **Critical** | Blocks core functionality or release | Fix readonly mode bypass |
| **High** | Significant user value or productivity | Background scanning |
| **Medium** | Nice to have, improves experience | UI polish items |
| **Low** | Minor enhancement, edge case | Rare platform support |

#### 3.2 Effort Assessment (How much work?)

Use relative sizing compared to completed work:

| Size | Reference Point | Typical Duration |
|------|-----------------|------------------|
| **XS** | Single file change, clear scope | 1-2 hours |
| **S** | 2-3 files, well-defined | 2-4 hours |
| **M** | Multiple files, some unknowns | 4-8 hours |
| **L** | Architectural changes, cross-cutting | 8-16 hours |
| **XL** | Major feature, multiple sprints | 16+ hours |

**Calibration**: Reference past sprints:
- Sprint 11 (UI Polish): ~14 hours (Medium-Large)
- Sprint 9 (Workflow): ~2 hours (Small)
- Sprint 3 (Safe Senders): ~8 hours (Medium)

#### 3.3 Risk Assessment (What could go wrong?)

| Risk Level | Criteria | Action |
|------------|----------|--------|
| **High** | Unknown technology, security-related, breaking changes | Spike first, prototype |
| **Medium** | Some unknowns, integration complexity | Include buffer time |
| **Low** | Well-understood, similar to past work | Standard estimates |

#### 3.4 Priority Formula

```
Priority Score = Value × (1 / Effort) × (1 / Risk)
```

Higher scores = higher priority. But Product Owner makes final call based on:
- Business urgency
- User feedback
- Technical dependencies
- Team capacity

### Step 4: Estimation Updates (5-10 minutes)

Update estimates based on new information:

#### 4.1 Apply Velocity Calibration

```
Sprint Velocity = Estimated Hours / Actual Hours

If velocity < 0.8: Estimates too optimistic, increase by 25%
If velocity > 1.2: Estimates too conservative, decrease by 15%
If 0.8 <= velocity <= 1.2: Estimates are calibrated
```

#### 4.2 Update ALL_SPRINTS_MASTER_PLAN.md

For items in "Future Features" section, update:
- Estimated effort (with calibration)
- Dependencies (based on recent changes)
- Model assignment (based on complexity)

### Step 5: Add New Items (5-10 minutes)

For newly identified work:

#### 5.1 Quick Capture Template

```markdown
### [Feature Name]
**Status**: 📋 NEW (refinement date)
**Priority**: [Critical/High/Medium/Low]
**Estimated Effort**: [XS/S/M/L/XL] (~N hours)
**Value Statement**: This enables... / This prevents...
**Dependencies**: [List any blockers]
**Notes**: [Any context from refinement discussion]
```

#### 5.2 Defer Details

For items more than 3 sprints away:
- Capture title and one-line description only
- Mark as "Needs Refinement" for future session
- Do not invest in detailed task breakdown yet

### Step 6: Cleanup and Documentation (5-10 minutes)

#### 6.1 Remove Obsolete Items

Items to remove:
- Features superseded by other work
- Bugs already fixed in other changes
- Requirements that are no longer relevant
- Items that have been in backlog for 6+ sprints without action

Document removal reason in ALL_SPRINTS_MASTER_PLAN.md or CHANGELOG.md.

#### 6.2 Update Dependencies

Review and update:
- Cross-feature dependencies
- Technical prerequisites
- External blockers (third-party libraries, API changes)

#### 6.3 Commit Changes

```bash
git add docs/ALL_SPRINTS_MASTER_PLAN.md docs/ISSUE_BACKLOG.md
git commit -m "docs: Backlog refinement - [date] - [summary of changes]"
git push
```

---

## Efficient Refinement Patterns

### Pattern 1: Quick Priority Shuffle (15 minutes)

When only priority order needs adjustment:

1. **List current top 10 items** (2 minutes)
2. **Product Owner re-ranks** (10 minutes)
3. **Update ALL_SPRINTS_MASTER_PLAN.md** (3 minutes)

Skip estimation, new items, and cleanup.

### Pattern 2: New Feature Scoping (30 minutes)

When adding significant new capability:

1. **Product Owner describes feature** (5 minutes)
2. **Claude Code researches implementation** (10 minutes - parallel with discussion)
3. **Break into tasks with estimates** (10 minutes)
4. **Add to backlog with priority** (5 minutes)

### Pattern 3: Technical Debt Review (20 minutes)

When addressing accumulated technical debt:

1. **Review open bugs and issues** (5 minutes)
2. **Identify patterns** (5 minutes)
3. **Group related items** (5 minutes)
4. **Prioritize debt reduction** (5 minutes)

### Pattern 4: Full Refinement (60 minutes)

When comprehensive review is needed (quarterly or after major release):

1. **Complete Steps 1-6** as documented above
2. **Review all backlog items**, not just top priority
3. **Archive items dormant for 6+ sprints**
4. **Reset estimates based on current velocity**

---

## Backlog Item States

### Ready State (Definition of Ready)

An item is "Ready" for sprint planning when:

| Criterion | Description |
|-----------|-------------|
| **Clear scope** | What to build is understood |
| **Acceptance criteria** | Measurable success criteria defined |
| **Estimated** | Size/effort estimate assigned |
| **No blockers** | Dependencies resolved or planned |
| **Prioritized** | Relative priority is clear |

### Not Ready States

| State | Meaning | Action Needed |
|-------|---------|---------------|
| **Needs Clarification** | Scope unclear | Product Owner input |
| **Needs Research** | Technical unknowns | Spike or investigation |
| **Blocked** | Dependency unresolved | Resolve or defer |
| **Too Large** | Cannot fit in sprint | Break into smaller items |

---

## Integration with Sprint Planning

### Before Sprint Planning

If backlog refinement was recently completed:
- Sprint planning can proceed directly
- Reference refined priorities in ALL_SPRINTS_MASTER_PLAN.md
- Select top items that fit sprint capacity

If backlog refinement was NOT recently completed:
- Quick priority review during sprint planning (10 minutes)
- Full refinement only if significant uncertainty exists

### Outputs to Sprint Planning

Refinement produces:
1. **Prioritized backlog** in ALL_SPRINTS_MASTER_PLAN.md
2. **Updated estimates** calibrated with recent velocity
3. **Resolved blockers** or documented dependencies
4. **Ready items** that meet Definition of Ready

Sprint planning consumes:
1. **Top N items** based on priority and capacity
2. **Task breakdown** from refinement or created during planning
3. **Acceptance criteria** from item descriptions

---

## Anti-Patterns to Avoid

### 1. Analysis Paralysis
- **Problem**: Spending too long on estimation
- **Solution**: Timebox strictly, use relative sizing, accept uncertainty

### 2. Premature Detail
- **Problem**: Breaking down items 5+ sprints away
- **Solution**: Defer details, capture title and priority only

### 3. Stale Backlog
- **Problem**: Items sitting for months without review
- **Solution**: Regular refinement (at least quarterly), archive dormant items

### 4. Missing Value Statements
- **Problem**: Items without clear "why"
- **Solution**: Require "This enables..." or "This prevents..." for all items

### 5. Unrealistic Estimates
- **Problem**: Estimates not calibrated with actual performance
- **Solution**: Track velocity, apply calibration factors

### 6. Feature Creep
- **Problem**: Scope expanding during refinement
- **Solution**: Timebox, defer new ideas to future refinement

---

## Refinement Artifacts

### ALL_SPRINTS_MASTER_PLAN.md Updates

After refinement, update:
- "Future Features (Prioritized)" section with new ordering
- Estimated effort based on calibration
- Dependencies and blockers
- Removed items (note removal reason)

### ISSUE_BACKLOG.md Updates

After refinement, update:
- Open issues list with current status
- Priority labels on GitHub issues
- Blocked issues with blocker description

### GitHub Issue Updates

After refinement:
```bash
# Update priority labels
gh issue edit #N --add-label "priority:high"
gh issue edit #N --remove-label "priority:medium"

# Close obsolete issues
gh issue close #N --reason "not planned" --comment "Removed during backlog refinement - [reason]"
```

---

## Quick Reference

### Refinement Checklist

```
[ ] Prepare: Read current backlog state
[ ] Review: Scan all items, identify stale entries
[ ] Prioritize: Re-order based on value/effort/risk
[ ] Estimate: Update with velocity calibration
[ ] Add: Capture new items (title + priority minimum)
[ ] Cleanup: Remove obsolete, update dependencies
[ ] Commit: Push changes to repository
```

### When to Skip Refinement

Skip full refinement if:
- Last refinement was within 2 sprints
- No significant new features identified
- Priorities unchanged since last review
- Sprint planning can handle minor adjustments

### When to Request Refinement

Request refinement if:
- Major feature direction change
- User feedback suggests new priorities
- Technical debt is blocking progress
- Backlog items over 3 sprints old
- Uncertainty about what to work on next

---

## Version History

**Version**: 1.0
**Date**: February 1, 2026
**Author**: Claude Opus 4.5
**Status**: Active

**Updates**:
- 1.0 (2026-02-01): Initial backlog refinement process document
