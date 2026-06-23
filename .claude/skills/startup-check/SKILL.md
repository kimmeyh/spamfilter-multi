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
- **Memory file**: D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md
- **Metadata file**: D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json

DO NOT use relative paths like .claude/memory/current.md -- this can resolve to different directories depending on context.

## CRITICAL: Bash Commands on Windows

This runs in bash on Windows. Use these patterns:
- Use git -C "D:/Data/Harold/github/spamfilter-multi" <command> instead of cd then git
- DO NOT use cd /d (that is CMD syntax, not bash)
- Use forward slashes in paths
- All Bash commands run in bash shell, NOT cmd.exe

## Instructions

Execute these checks in parallel and report a summary:

1. **Git Status**: Run git -C "D:/Data/Harold/github/spamfilter-multi" status --short and git -C "D:/Data/Harold/github/spamfilter-multi" branch --show-current

2. **GitHub CLI**: Run gh issue list --limit 1

2.5. **Sprint Phase 3.7 Approval Verification Gate** (Sprint 36 retro IMP-3)

   **When**: If the current branch matches feature/*Sprint* AND docs/sprints/SPRINT_N_PLAN.md exists for the current sprint number.

   **Why**: Existence of SPRINT_N_PLAN.md and a draft PR are Phase 3.2.2 / 3.3.1 artifacts that PRECEDE Phase 3.7 approval. They are not approval evidence on their own. Sprint 36 escape (2026-04-21): Claude resumed a session with the plan committed, read the plan, and started Task 1 work without verifying Phase 3.7 approval. Harold caught it manually.

   **Procedure**:

   a. Identify the sprint number from the branch name (e.g., feature/20260420_Sprint_36 -> Sprint 36).
   b. Confirm docs/sprints/SPRINT_N_PLAN.md exists.
   c. Search for Phase 3.7 approval evidence in three sources, in order:
      1. **PR comments**: gh pr view <PR-number> --json comments,reviews and look for an approval-language comment (e.g., ''approved'', ''go ahead'', ''start Phase 4'', ''plan looks good'') authored by the user.
      2. **Issue comments**: gh issue view <sprint-issue> --json comments and look for the same.
      3. **Memory file**: Read .claude/memory/current.md for any prior-session note recording approval; check .claude/memory/memory_metadata.json for sprint number match.
   d. **If approval evidence is found in ANY source**: report ''Phase 3.7 approval verified (source: PR comment / issue comment / memory)'' and proceed to Memory Restore step.
   e. **If approval evidence is NOT found in any source**: report startup as ''Ready: PHASE 3.7 APPROVAL NOT VERIFIED'' and present the SPRINT_N_PLAN.md summary (objective + task list + estimated effort) back to the user with the prompt:
      > ''Sprint N plan is committed at docs/sprints/SPRINT_N_PLAN.md and draft PR #X exists, but I see no Phase 3.7 approval on record (no approval comment on the PR, no approval comment on the issue, no approval note in memory). Please confirm: do you approve Phase 4 execution of this plan? Reply ''''approved'''' to proceed, or describe revisions needed.''
   f. **DO NOT** start any Phase 4 task work, file edits, or commit-staging actions until the user explicitly approves in this session OR existing approval evidence is located. This gate is a hard stop, equivalent to the Phase 1 Backlog Refinement gate.

   **Companion memory**: feedback_approval_verification.md (added Sprint 36).

3. **Memory Restore**: Check if memory should be restored
   - Read D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json
   - Check if pending_restore is true
   - If pending_restore is false or missing: skip restore, report ''No pending memory restore''
   - If pending_restore is true:
     - Read D:/Data/Harold/github/spamfilter-multi/.claude/memory/current.md and restore context
     - **STALENESS CHECK**: Before acting on the saved context, validate it against current repo state:
       1. Compare the memory last_updated date against recent git log (git log --oneline -10)
       2. Check if the saved sprint work already appears in CHANGELOG.md
       3. Check if the saved sprint retrospective already exists in docs/sprints/
       4. If the memory is stale (subsequent sprints completed since save), report it as **STALE** and DO NOT follow the saved ''Next Steps'' -- just present the info for awareness
     - Verify saved branch matches current branch
     - Present saved tasks, recent work, and next steps (with staleness warning if applicable)
     - **Clear pending flag -- MANDATORY, NEVER SKIP**:
       This step MUST complete successfully. If all attempts fail, mark startup as ''Ready: No'' and ask the user for help.

       **CRITICAL**: Always use PowerShell as the FIRST attempt. The Write tool is denied in don''t-ask mode for memory metadata files. PowerShell Set-Content reliably works in don''t-ask mode on this Windows project.

       **Attempt 1 (PREFERRED -- ALWAYS TRY FIRST)** -- PowerShell via Bash:
       bash
       powershell -NoProfile -Command "Set-Content -Path ''D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json'' -Value ''{\"current_save\":\".claude/memory/current.md\",\"last_updated\":\"[original timestamp]\",\"sprint\":\"[sprint name]\",\"status\":\"restored\",\"pending_restore\":false}''"
       

       **Attempt 2** -- Bash heredoc fallback (if PowerShell unavailable):
       bash
       cat > "D:/Data/Harold/github/spamfilter-multi/.claude/memory/memory_metadata.json" << ''EOF''
       {"current_save":".claude/memory/current.md","last_updated":"[original timestamp]","sprint":"[sprint name]","status":"restored","pending_restore":false}
       EOF
       

       **Attempt 3** -- Write tool (LAST RESORT -- usually denied in don''t-ask mode):
       Use the Write tool to write the updated JSON. Note: this will likely fail in don''t-ask mode.

       **Attempt 4** -- If all are denied by permissions, ASK THE USER:
       ''I need permission to update the memory metadata file to clear the pending_restore flag. Can you approve writing to .claude/memory/memory_metadata.json?''

       **NEVER silently skip this step.** A stale pending_restore:true flag causes incorrect restores in future sessions.

## Output Format

Report results in this format:


Startup Check:
- Git: [branch] with [N uncommitted files / clean]
- GitHub CLI: [working/failed]
- Phase 3.7 Approval: [verified (source) / NOT VERIFIED -- present plan summary and ask / N/A (not on a sprint feature branch)]
- Ready: [Yes/No]


If pending_restore was true and memory was restored, also show:


Memory Restored:
- Sprint: [sprint name]
- Saved: [date/time]
- Branch: [saved branch] [OK matches / WARNING mismatch]

## Current Tasks
[List from memory]

## Next Steps
[From memory]


If Ready is No, list what needs to be fixed before proceeding.
