---
name: phase-check
description: Sprint phase transition checkpoint - verify current phase complete and review next phase
allowed-tools: Read
user-invocable: true
model: haiku
---

# Phase Transition Checkpoint

Verify the current sprint phase is complete and review the next phase requirements before proceeding.

## Instructions

1. **Read the Sprint Checklist**: Read `docs/SPRINT_CHECKLIST.md`

2. **Determine Current Phase**: Based on the conversation context, identify which sprint phase was just completed (Phase 2, 3, 4, 5, 6, or 7)

3. **Verify Current Phase Completion**: List all checklist items for the current phase and mark each as:
   - [OK] Complete
   - [MISSING] Not yet done
   - [N/A] Not applicable

4. **Preview Next Phase**: List all checklist items for the next phase so Claude and user know what is coming

5. **Check Sprint Documents**: Verify which required sprint documents have been created:
   - `docs/sprints/SPRINT_N_PLAN.md` (required in Phase 3)
   - `docs/sprints/SPRINT_N_RETROSPECTIVE.md` (required in Phase 7)
   - `docs/sprints/SPRINT_N_SUMMARY.md` (required in Phase 7 -- **do not defer**)
   - `docs/sprints/SPRINT_(N+1)_PLAN.md` stub with Category 13 carry-ins (required in Phase 7.7)
   - CHANGELOG.md updated (required in Phase 4+)
   - ALL_SPRINTS_MASTER_PLAN.md updated (required in Phase 7)

6. **Check machine-verifiable close-out state** (Sprint 50 escape -- these are the items that drifted silently because nobody looked):
   - **`.claude/sprint_status.json`**: READ it. Does `current_sprint.number` match the sprint number in the branch name? Is `_last_updated` recent? A stale file misleads the next session after context compaction. Report `[MISSING]` if it disagrees with the branch.
   - **Open GitHub issues**: `gh issue list --label sprint --state open`. In Phase 7 / post-merge this must be empty. **`Closes #N` does NOT auto-fire** in this repo -- PRs merge `feature -> develop`, and GitHub only auto-closes on merge to the default branch.
   - **Past Sprint Summary table** in `ALL_SPRINTS_MASTER_PLAN.md`: does it have a row for the sprint just completed?

## Output Format

```
Phase Transition Checkpoint
===========================
Current Phase: [N] - [Name]
Next Phase: [N+1] - [Name]

Current Phase Status:
- [OK/MISSING] Item 1
- [OK/MISSING] Item 2
...

Sprint Documents:
- [OK/MISSING] SPRINT_N_PLAN.md
- [OK/MISSING/DEFERRED] SPRINT_N_RETROSPECTIVE.md
- [OK/MISSING/DEFERRED] SPRINT_N_SUMMARY.md
- [OK/MISSING] CHANGELOG.md updated
- [OK/MISSING/N/A] ALL_SPRINTS_MASTER_PLAN.md updated

Next Phase Requirements:
- [ ] Item 1
- [ ] Item 2
...

Ready to proceed: [Yes/No - fix MISSING items first]
```

## Arguments

Optional: Pass the current phase number as argument (e.g., `/phase-check 6` to check Phase 6 completion).
If not provided, infer from conversation context.
