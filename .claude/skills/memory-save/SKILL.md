---
name: memory-save
description: Save current sprint context to memory for later restoration
allowed-tools: Bash, Read, Write
user-invocable: true
model: haiku
---

# Memory Save Skill

Save current sprint context before ending a session, so work can be resumed later.

## CRITICAL: File Paths

All memory files MUST use these exact absolute paths:
- **Memory file**: `D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md`
- **Metadata file**: `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json`

DO NOT use relative paths like `.claude/memory/current.md` — this can resolve to different directories depending on context.

## CRITICAL: Writing to .claude/ paths

The Write tool is BLOCKED for `.claude/` paths in don't-ask mode. You MUST use one of these alternatives:

**Preferred — Python** (handles markdown with backticks cleanly):
```bash
python << 'EOF'
content = r"""<your markdown content here>"""
with open(r'D:\Data\Harold\github\spamfilter-multi\.claude\memory\current.md', 'w', encoding='utf-8') as f:
    f.write(content)
print('Saved current.md')
EOF
```

**Fallback — PowerShell** (use for simple content like JSON metadata):
```bash
powershell -NoProfile -Command "Set-Content -Path 'D:\Data\Harold\github\spamfilter-multi\.claude\memory\memory_metadata.json' -Value '<json content>' -Encoding UTF8"
```

**DO NOT use**:
- The Write tool (blocked for `.claude/` paths in don't-ask mode)
- Bash `echo '...' > file` (blocked in don't-ask mode, and backticks get interpreted as commands)

## CRITICAL: Bash Commands on Windows

This runs in bash on Windows. Use these patterns:
- Use `git -C "D:/Data/Harold/github/spamfilter-multi" <command>` instead of `cd` then `git`
- DO NOT use `cd /d` (that is CMD syntax, not bash)
- Use forward slashes in paths

## Instructions

1. **Get current context**:
   - Run `git -C "D:/Data/Harold/github/spamfilter-multi" branch --show-current` to get branch name
   - Extract sprint number from branch (e.g., "Sprint_12" -> "Sprint 12")
   - Get current date/time

2. **Gather session context** from the conversation:
   - Current tasks (from todo list or discussion)
   - Recent work completed this session
   - Next steps to continue
   - Any blockers or important notes

3. **Write the memory file** using Python (see "Writing to .claude/ paths" above):
   - Use a bash heredoc with Python to write the markdown content to `D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md`
   - Use Python raw triple-quoted strings to avoid backtick and escape issues
   - Structure the content as:
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

4. **Update metadata** using PowerShell at `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json`:

   ```bash
   powershell -NoProfile -Command "Set-Content -Path 'D:\Data\Harold\github\spamfilter-multi\.claude\memory\memory_metadata.json' -Value '{\"current_save\":\".claude/memory/current.md\",\"last_updated\":\"[ISO timestamp]\",\"sprint\":\"[sprint name]\",\"status\":\"active\",\"pending_restore\":true}' -Encoding UTF8"
   ```

   **IMPORTANT**: The `pending_restore: true` flag signals that this save should be restored on next startup. The `/startup-check` skill will clear this flag after restoring.

5. **Verify save** by reading both files back to confirm they were written correctly.

6. **Confirm save** by showing the user a summary.

## Output Format

```
Memory Saved:
- Sprint: [sprint name]
- Branch: [branch name]
- Tasks: [N] tasks recorded
- Next Steps: [brief summary]
- File: D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md

Ready to resume with /startup-check in a new session.
```
