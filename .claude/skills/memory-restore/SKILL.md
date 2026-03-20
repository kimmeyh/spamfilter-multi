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

3. **Verify branch alignment**:
   - Run `git -C "D:/Data/Harold/github/spamfilter-multi" branch --show-current`
   - Compare with branch recorded in memory file
   - Warn if branches do not match

4. **Present restored context** to the user:
   - Show sprint name and status
   - List current tasks (with completion status)
   - Show recent work summary
   - Highlight next steps to continue

5. **Clear pending flag**:
   - Update `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json` setting `pending_restore: false`
   - This prevents duplicate restores in subsequent sessions

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
