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

DO NOT use relative paths like `.claude/memory/current.md` â€” this can resolve to different directories depending on context.

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
     - **STALENESS CHECK**: Before acting on the saved context, validate it against current repo state:
       1. Compare the memory `last_updated` date against recent git log (`git log --oneline -10`)
       2. Check if the saved sprint work already appears in CHANGELOG.md
       3. Check if the saved sprint retrospective already exists in `docs/sprints/`
       4. If the memory is stale (subsequent sprints completed since save), report it as **STALE** and DO NOT follow the saved "Next Steps" â€” just present the info for awareness
     - Verify saved branch matches current branch
     - Present saved tasks, recent work, and next steps (with staleness warning if applicable)
     - **Clear pending flag â€” MANDATORY, NEVER SKIP**:
       This step MUST complete successfully. If all attempts fail, mark startup as "Ready: No" and ask the user for help.

       **CRITICAL**: Always use PowerShell as the FIRST attempt. The Write tool is denied in don't-ask mode for memory metadata files. PowerShell `Set-Content` reliably works in don't-ask mode on this Windows project.

       **Attempt 1 (PREFERRED â€” ALWAYS TRY FIRST)** â€” PowerShell via Bash:
       ```bash
       powershell -NoProfile -Command "Set-Content -Path 'D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json' -Value '{\"current_save\":\".claude/memory/current.md\",\"last_updated\":\"[original timestamp]\",\"sprint\":\"[sprint name]\",\"status\":\"restored\",\"pending_restore\":false}'"
       ```

       **Attempt 2** â€” Bash heredoc fallback (if PowerShell unavailable):
       ```bash
       cat > "D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json" << 'EOF'
       {"current_save":".claude/memory/current.md","last_updated":"[original timestamp]","sprint":"[sprint name]","status":"restored","pending_restore":false}
       EOF
       ```

       **Attempt 3** â€” Write tool (LAST RESORT â€” usually denied in don't-ask mode):
       Use the Write tool to write the updated JSON. Note: this will likely fail in don't-ask mode.

       **Attempt 4** â€” If all are denied by permissions, ASK THE USER:
       "I need permission to update the memory metadata file to clear the pending_restore flag. Can you approve writing to `.claude/memory/memory_metadata.json`?"

       **NEVER silently skip this step.** A stale `pending_restore:true` flag causes incorrect restores in future sessions.

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
