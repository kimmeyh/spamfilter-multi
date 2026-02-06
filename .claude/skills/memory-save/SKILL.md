---
name: memory-save
description: Save current sprint context to memory for later restoration
allowed-tools: Bash, Read, Write
user-invocable: true
model: claude-3-5-haiku-latest
---

# Memory Save Skill

Save current sprint context before ending a session, so work can be resumed later.

## Instructions

1. **Get current context**:
   - Run `git branch --show-current` to get branch name
   - Extract sprint number from branch (e.g., "Sprint_12" → "Sprint 12")
   - Get current date/time

2. **Gather session context** from the conversation:
   - Current tasks (from todo list or discussion)
   - Recent work completed this session
   - Next steps to continue
   - Any blockers or important notes

3. **Write the memory file** to `.claude/memory/current.md` with this structure:
   ```markdown
   # Sprint Context Save

   **Sprint**: [sprint name]
   **Date**: [YYYY-MM-DD HH:MM:SS]
   **Branch**: [branch name]
   **Status**: In Progress

   ## Current Tasks

   - [ ] Task 1
   - [x] Completed task

   ## Recent Work

   - What was done this session

   ## Next Steps

   - What to do when resuming

   ## Blockers/Notes

   Any blockers or important context

   ---

   **Instructions for Claude on Resume**:
   1. Read this context file on startup
   2. Verify git branch matches sprint
   3. Continue from "Next Steps" section above
   ```

4. **Update metadata** at `.claude/memory/memory_metadata.json`:
   ```json
   {
     "current_save": ".claude/memory/current.md",
     "last_updated": "[ISO timestamp]",
     "sprint": "[sprint name]",
     "status": "active",
     "pending_restore": true
   }
   ```

   **IMPORTANT**: The `pending_restore: true` flag signals that this save should be restored on next startup. The `/startup-check` skill will clear this flag after restoring.

5. **Confirm save** by showing the user a summary

## Output Format

```
Memory Saved:
- Sprint: [sprint name]
- Branch: [branch name]
- Tasks: [N] tasks recorded
- Next Steps: [brief summary]
- File: .claude/memory/current.md

Ready to resume with /memory-restore in a new session.
```
