# Phase 0: Pre-Sprint Verification Checklist

**Purpose**: Verify that conditions are right to begin a new sprint. This checklist prevents "continuation" issues where previous sprint work is incomplete or conflicting.

**When to Use**: Run this checklist at the **START of every sprint**, before beginning Phase 1: Sprint Kickoff.

**Time Required**: 5-10 minutes

---

## [OK] Phase 0 Checklist

### 0.1 Verify Previous Sprint is Merged to Develop [OK]

**Why**: Ensures you're building on top of completed, reviewed work. Prevents conflicts and confusion.

**Steps**:
```bash
# Verify last commit on develop is from previous sprint
git log develop --oneline -1
# Expected: Output should show a "Merge pull request" or sprint task commit

# Verify branch matches remote
git checkout develop
git pull origin develop
git status
# Expected: "Your branch is up to date with 'origin/develop'"
```

**Success Criteria**:
- [ ] develop branch exists and is current
- [ ] Last commit on develop is from previous sprint
- [ ] No unpulled commits from remote

**Failure Handling**: If previous sprint is NOT merged:
- Cannot start new sprint - previous work not complete
- Contact user for status
- Wait for previous PR to be approved and merged

---

### 0.2 Verify All Previous Sprint Cards Are Closed [OK]

**Why**: Open sprint cards can block new work and cause confusion about what's complete.

**Steps**:
```bash
# List all open sprint issues
gh issue list --label sprint --state open --json number,title,labels

# For each open issue, determine:
# - Is it from a PREVIOUS sprint? (Should be closed)
# - Is it from the CURRENT sprint? (Will be addressed now)
```

**Success Criteria**:
- [ ] No open issues from PREVIOUS sprints
- [ ] All previous sprint cards show "Closed" status
- [ ] Only current sprint cards are "Open"

**Failure Handling**: If previous sprint cards are still open:
```bash
# Close each card from previous sprint
gh issue close #<issue_number> --reason "completed"
```

**Reference**: See SPRINT_EXECUTION_WORKFLOW.md section "After Sprint Approval - Merge & Cleanup" (line 460)

---

### 0.3 Ensure Working Directory is Clean [OK]

**Why**: Uncommitted changes from previous sprint can cause conflicts and confusion.

**Steps**:
```bash
# Check for uncommitted changes
git status
# Expected output:
#   On branch develop
#   nothing to commit, working tree clean

# Check for untracked files
git status --short
# Expected: No output (or only non-source files)
```

**Success Criteria**:
- [ ] `git status` shows "nothing to commit, working tree clean"
- [ ] No modified tracked files
- [ ] No untracked source files

**Failure Handling**: If working directory has changes:
```bash
# Option 1: Commit if changes belong to previous sprint
git add <files>
git commit -m "cleanup: Complete previous sprint work"
git push origin develop

# Option 2: Stash if changes were experimental
git stash

# Then proceed with Phase 0 verification
```

---

### 0.4 Verify Develop Branch is Current [OK]

**Why**: Ensures you're not building on stale code. Prevents merge conflicts and ensures latest tests pass.

**Steps**:
```bash
# Make sure you're on develop
git checkout develop

# Pull latest from remote
git pull origin develop

# Verify no conflicts or errors
git status
# Expected: "Your branch is up to date with 'origin/develop'"
```

**Success Criteria**:
- [ ] On `develop` branch
- [ ] Latest commits pulled from remote
- [ ] Branch is ahead/even with remote (no behind)
- [ ] No merge conflicts

**Failure Handling**: If develop has conflicts:
```bash
# Talk to user - this indicates PR merge issues
# Do not proceed until resolved
```

---

### 0.5 Review Sprint Plan Documentation [OK]

**Why**: Ensures you understand scope before starting implementation. Prevents scope creep and alignment issues.

**Steps**:
1. Find the Sprint Plan document:
   - Example: `docs/SPRINT_4_PLAN.md` or `docs/Phase_3.5_Planning.md`

2. Read the entire plan:
   - [ ] Understand what will be built and why
   - [ ] Review Task A, B, C (and D if applicable)
   - [ ] Note acceptance criteria for each task
   - [ ] Identify dependencies and blockers

3. Verify plan matches sprint scope:
   - [ ] All 4 GitHub cards created match plan
   - [ ] No additional scope creep identified
   - [ ] Estimates are realistic

**Success Criteria**:
- [ ] Sprint plan document located
- [ ] Plan is understood and complete
- [ ] No scope ambiguity identified
- [ ] Ready to execute

**Failure Handling**: If plan is unclear:
- Ask user for clarification before starting
- Document unclear areas
- Refine plan if needed

---

### 0.6 Check for Continuation Issues [OK]

**Why**: Previous sessions may have left partial work. Ensures clean slate.

**Steps**:
```bash
# Are we on a feature branch from a previous sprint?
git branch --show-current
# If output is NOT "develop", we're in a previous sprint branch

# Check for unfinished work
git status
git log --oneline -5
```

**Success Criteria**:
- [ ] On `develop` branch (not a feature branch)
- [ ] No unfinished work from previous session
- [ ] Clean git history

**Failure Handling**: If on a feature branch:
1. Determine if it's an active PR or completed work
2. If PR exists:
   - Check PR status on GitHub
   - If approved: Merge it
   - If under review: Wait for approval
3. If PR doesn't exist:
   - Delete the branch: `git branch -d <branch>`
   - Move to develop

---

## [OK] All Phases Verified?

If you answered "yes" to all items above:

[OK] **YOU ARE READY TO PROCEED TO PHASE 1: SPRINT KICKOFF**

If any item is not complete:

[FAIL] **STOP - Do not proceed to Phase 1**
- Resolve the failing check above
- Return to Phase 0 and verify again
- Once all items pass, proceed to Phase 1

---

## Quick Reference

### Common Phase 0 Issues and Fixes

| Issue | Solution | Reference |
|-------|----------|-----------|
| Previous sprint PR not merged | Wait for PR approval and merge | 0.1 |
| Previous sprint cards still open | Close them with `gh issue close #N` | 0.2 |
| Untracked changes in directory | Commit or stash them | 0.3 |
| On wrong branch | `git checkout develop && git pull origin develop` | 0.4 |
| Plan document missing | Request sprint plan from user before proceeding | 0.5 |
| On feature branch from old sprint | Delete branch: `git branch -d <branch>` | 0.6 |

---

## After Phase 0: Next Steps

Once all Phase 0 items are verified:

1. [OK] Phase 0 Complete - Ready for Phase 1
2. → Proceed to **Phase 1: Sprint Kickoff & Planning** in SPRINT_EXECUTION_WORKFLOW.md
3. → Create sprint feature branch
4. → Create sprint GitHub cards
5. → Begin implementation

---

**Document Version**: 1.0
**Last Updated**: January 25, 2026
**Introduced In**: Sprint 4 Retrospective (Phase 4.5)
**Reference**: SPRINT_EXECUTION_WORKFLOW.md Phase 0 (lines 24-50)
