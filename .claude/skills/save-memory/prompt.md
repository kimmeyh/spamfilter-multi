# Save Memory Skill

Save current sprint context to a memory file for resuming later sessions.

## When to Use

- Before ending a Claude Code session
- When switching to a different task/project
- To checkpoint progress during long sprints
- Before context window fills up

## Execution

Run the save-memory script to create a context snapshot:

```powershell
.\.claude\scripts\save-memory.ps1
```

This creates `.claude/memory/current.md` with a template. After running, **you must edit the file** to add:

1. **Current Tasks**: Update the task list with actual in-progress work
2. **Recent Work**: Summarize what was completed this session
3. **Next Steps**: What should be done when resuming
4. **Blockers/Notes**: Any important context

## Parameters

- `-SprintName`: Override auto-detected sprint name (default: extracted from git branch)
- `-CustomNotes`: Add notes directly without editing file

Example with parameters:
```powershell
.\.claude\scripts\save-memory.ps1 -SprintName "Sprint 12" -CustomNotes "Backlog refinement in progress"
```

## Output Files

- `.claude/memory/current.md` - Current context (edit this!)
- `.claude/memory/memory_metadata.json` - Metadata for tracking

## On Resume

When starting a new session, read `.claude/memory/current.md` to restore context:

```powershell
Get-Content .\.claude\memory\current.md
```

Or Claude Code can read it automatically if instructed in CLAUDE.md.
