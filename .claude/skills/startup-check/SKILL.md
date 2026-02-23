---
name: startup-check
description: Run environment health check for this project
allowed-tools: Bash, Read
user-invocable: true
model: haiku
---

# Startup Check Skill

Run environment health check and restore saved context for this project.

## Instructions

Execute these checks in parallel and report a summary:

1. **Git Status**: Run `git status --short` and `git branch --show-current`

2. **GitHub CLI**: Run `gh issue list --limit 1`

3. **Memory Restore**: Check if memory should be restored
   - Read `.claude/memory/memory_metadata.json`
   - Check if `pending_restore` is `true`
   - If `pending_restore` is `false` or missing: skip restore, report "No pending memory restore"
   - If `pending_restore` is `true`:
     - Read `.claude/memory/current.md` and restore context
     - Verify saved branch matches current branch
     - Present saved tasks, recent work, and next steps
     - **Update metadata**: Set `pending_restore: false` to prevent duplicate restores

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
- Branch: [saved branch] [✓ matches / ⚠ mismatch]

## Current Tasks
[List from memory]

## Next Steps
[From memory]
```

If Ready is No, list what needs to be fixed before proceeding.
