---
name: startup-check
description: Run environment health check for this project
allowed-tools: Bash, Read, Write
user-invocable: true
model: haiku
---

# Startup Check Skill

Run environment health check and restore saved context for this project.

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
- All Bash commands run in bash shell, NOT cmd.exe

## Instructions

Execute these checks in parallel and report a summary:

1. **Git Status**: Run `git -C "D:/Data/Harold/github/spamfilter-multi" status --short` and `git -C "D:/Data/Harold/github/spamfilter-multi" branch --show-current`

2. **GitHub CLI**: Run `gh issue list --limit 1`

3. **Memory Restore**: Check if memory should be restored
   - Read `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json`
   - Check if `pending_restore` is `true`
   - If `pending_restore` is `false` or missing: skip restore, report "No pending memory restore"
   - If `pending_restore` is `true`:
     - Read `D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md` and restore context
     - Verify saved branch matches current branch
     - Present saved tasks, recent work, and next steps
     - **Update metadata**: Set `pending_restore: false` to prevent duplicate restores (write to `D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json`)

## Output Format

Report results in this format:

```
Startup Check:
- Git: [branch] with [N uncommitted files / clean]
- GitHub CLI: [working/failed]
- Ready: [Yes/No]
```

If `pending_restore` was true and memory was restored, also show:

```
Memory Restored:
- Sprint: [sprint name]
- Saved: [date/time]
- Branch: [saved branch] [OK matches / WARNING mismatch]

## Current Tasks
[List from memory]

## Next Steps
[From memory]
```

If Ready is No, list what needs to be fixed before proceeding.
