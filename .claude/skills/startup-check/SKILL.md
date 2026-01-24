---
name: startup-check
description: Run environment health check for this project
allowed-tools: Bash, Read
user-invocable: true
model: haiku
---

# Startup Check Skill

Run environment health check for this project.

## Instructions

Execute these checks in parallel and report a summary:

1. **Serena MCP**: Call `mcp__plugin_serena_serena__activate_project` with `project="spamfilter-multi"`, then `mcp__plugin_serena_serena__check_onboarding_performed`

2. **Git Status**: Run `git status --short` and `git branch --show-current`

3. **GitHub CLI**: Run `gh issue list --limit 1`

4. **File Access**: Read first 5 lines of `mobile-app/lib/main.dart`

## Output Format

Report results in this format:

```
Startup Check:
- Serena: [activated/failed - reason]
- Git: [branch] with [N uncommitted files / clean]
- GitHub CLI: [working/failed]
- File Access: [working/failed]
- Ready: [Yes/No]
```

If Ready is No, list what needs to be fixed before proceeding.
