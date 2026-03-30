---
name: memory-restore
description: Restore sprint context from saved memory file
allowed-tools: Bash, Read, Write
user-invocable: true
model: haiku
---

# Memory Restore Skill

Restore sprint context from a previous session to continue work.

## CRITICAL: File Paths

All memory files MUST use these exact absolute paths:
- **Memory file**: `D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md`
- **Metadata file**: `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json`

DO NOT use relative paths like `.claude/memory/current.md` — this can resolve to different directories depending on context.

## CRITICAL: Bash Commands on Windows

This runs in bash on Windows. Use these patterns:
- Use `git -C "D:/Data/Harold/github/spamfilter-multi" <command>` instead of `cd` then `git`
- DO NOT use `cd /d` (that is CMD syntax, not bash)
- Use forward slashes in paths

## Instructions

1. **Check for saved memory**:
   - Read `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json` for metadata
   - Check `pending_restore` flag:
     - If `false` or missing: Report "No pending memory to restore" and stop
     - If `true`: Continue with restore

2. **Read saved context**:
   - Read `D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md` for saved context

3. **Verify branch alignment and staleness**:
   - Run `git -C "D:/Data/Harold/github/spamfilter-multi" branch --show-current`
   - Compare with branch recorded in memory file
   - Warn if branches do not match
   - **STALENESS CHECK**: Before acting on the saved context, validate it against current repo state:
     1. Compare the memory `last_updated` date against recent git log (`git -C "D:/Data/Harold/github/spamfilter-multi" log --oneline -10`)
     2. Check if the saved sprint's work already appears in CHANGELOG.md (grep for the sprint name/number)
     3. Check if the saved sprint's retrospective already exists in `docs/sprints/`
     4. If the memory is stale (subsequent sprints completed since save), report it as **STALE** and DO NOT follow the saved "Next Steps" — just present the info for awareness

4. **Present restored context** to the user:
   - Show sprint name and status
   - List current tasks (with completion status)
   - Show recent work summary
   - Highlight next steps to continue

5. **Clear pending flag — MANDATORY, NEVER SKIP**:
   This step MUST complete successfully. If all attempts fail, report "Ready: No" and ask the user for help.

   - **Attempt 1** — Bash echo (preferred, works in Git Bash on Windows):
     ```bash
     echo '{"current_save":".claude/memory/current.md","last_updated":"[original timestamp]","sprint":"[sprint name]","status":"restored","pending_restore":false}' > "D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json"
     ```
   - **Attempt 2** — PowerShell fallback (if Bash is denied or fails):
     ```bash
     powershell -NoProfile -Command "Set-Content -Path 'D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json' -Value '{\"current_save\":\".claude/memory/current.md\",\"last_updated\":\"[original timestamp]\",\"sprint\":\"[sprint name]\",\"status\":\"restored\",\"pending_restore\":false}'"
     ```
   - **Attempt 3** — If both are denied, ASK THE USER for permission. Do not silently skip.
   - **NEVER silently skip this step.** A stale `pending_restore:true` flag causes incorrect restores in future sessions.

6. **Offer to continue** from where the previous session left off

## Output Format

```
Memory Restored:
- Sprint: [sprint name]
- Saved: [date/time]
- Branch: [branch name] [OK matches / WARNING mismatch - current is X]

## Current Tasks
[List tasks from memory file]

## Recent Work
[Summary from memory file]

## Next Steps
[Next steps from memory file]

---
Ready to continue. What would you like to work on?
```

## No Pending Restore

If `pending_restore` is false or missing:
```
No pending memory to restore.
(Memory was either already restored or /memory-save was not run before last exit)
```

## Error Handling

If no memory file exists:
```
No saved memory found at D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md
Use /memory-save to create a save point before ending a session.
```
