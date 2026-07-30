---
name: startup-check
description: Run environment health check for this project
allowed-tools: Bash, Read, Write
user-invocable: true
model: haiku
---

# Startup Check Skill

Run environment health check and restore saved context for this project.

## CRITICAL: Where sprint state actually lives (changed Sprint 51, F130-S51)

**The authoritative sprint-state file is `.claude/sprint_status.json`.** It is a Phase 7.7 close-out
checklist item, so it is maintained every sprint, and it carries the approval flags, task status, test
metrics, and next actions this skill needs.

Use this exact absolute path:
- **Sprint state**: D:/Data/Harold/github/spamfilter-multi/.claude/sprint_status.json

DO NOT use relative paths -- they can resolve to different directories depending on context.

**RETIRED -- do not read these**: `.claude/memory/current.md` and `.claude/memory/memory_metadata.json`.
That was the pre-Sprint-39 `/memory-save` mechanism; `memory-save/SKILL.md` states plainly that nothing
should be written there any more. Both files are frozen at **Sprint 39 (2026-05-24)** and self-labelled
`[STALE -- DO NOT TRUST]`. This skill used to restore from them whenever `pending_restore` was true,
which meant a single stray flag would have injected Sprint-39 context into a Sprint-51+ session. That
restore path was removed on Harold's approval (2026-07-28). Durable process context lives in
`docs/SPRINT_RESUME_GUIDE.md`.

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
      1. **Sprint state (authoritative)**: Read D:/Data/Harold/github/spamfilter-multi/.claude/sprint_status.json. Approval is recorded as `current_sprint.plan_approved: true` WITH `current_sprint.number` matching the sprint number from the branch. A `plan_approved: true` whose `number` does NOT match the current branch is NOT evidence -- it is stale state from a prior sprint; ignore it and keep looking.
      2. **PR comments**: gh pr view <PR-number> --json comments,reviews and look for an approval-language comment (e.g., ''approved'', ''go ahead'', ''start Phase 4'', ''plan looks good'') authored by the user.
      3. **Issue comments**: gh issue view <sprint-issue> --json comments and look for the same.
   d. **If approval evidence is found in ANY source**: report ''Phase 3.7 approval verified (source: PR comment / issue comment / memory)'' and proceed to Memory Restore step.
   e. **If approval evidence is NOT found in any source**: report startup as ''Ready: PHASE 3.7 APPROVAL NOT VERIFIED'' and present the SPRINT_N_PLAN.md summary (objective + task list + estimated effort) back to the user with the prompt:
      > ''Sprint N plan is committed at docs/sprints/SPRINT_N_PLAN.md and draft PR #X exists, but I see no Phase 3.7 approval on record (no approval comment on the PR, no approval comment on the issue, no approval note in memory). Please confirm: do you approve Phase 4 execution of this plan? Reply ''''approved'''' to proceed, or describe revisions needed.''
   f. **DO NOT** start any Phase 4 task work, file edits, or commit-staging actions until the user explicitly approves in this session OR existing approval evidence is located. This gate is a hard stop, equivalent to the Phase 1 Backlog Refinement gate.

   **Companion memory**: feedback_approval_verification.md (added Sprint 36).

3. **Sprint State Restore**: Read D:/Data/Harold/github/spamfilter-multi/.claude/sprint_status.json

   This replaces the retired `.claude/memory/current.md` restore (removed Sprint 51, F130-S51, on
   Harold''s approval). There is **no `pending_restore` flag any more** and nothing to clear -- this
   file is read-only for the purposes of this skill, so the whole write-back-with-4-fallbacks dance is
   gone.

   Report from it:
   - `current_sprint`: number, branch, status, `plan_approved`
   - `sprint_51_task_status` (or the equivalent per-sprint task block, if present)
   - `test_metrics`: last recorded passing/skipped/failing counts
   - `next_actions`: what the previous session determined comes next

   **STALENESS CHECK -- still mandatory.** The file is maintained at Phase 7.7, so between close-outs it
   can lag the working tree. Before acting on anything it says:
   1. Does `current_sprint.branch` match the actual current branch? If not, the file is stale -- trust
      git, report the mismatch, and do NOT act on `next_actions`.
   2. Does `current_sprint.number` match the sprint number in the branch name? Same rule.
   3. Compare `_last_updated` against `git log --oneline -10`. If commits landed after that timestamp,
      treat `next_actions` and `test_metrics` as possibly-superseded and say so.
   4. If the file describes a sprint whose work already appears in CHANGELOG.md as complete, report it
      as **STALE** and present the contents for awareness only.

   **Never present stale state as current.** A stale sprint-state file that is reported confidently is
   worse than no file at all -- that is exactly how it drifted 15 sprints unnoticed before Sprint 50.

   For durable process context (phase definitions, decision classes, stopping criteria, the 4-step
   resume sequence), read `docs/SPRINT_RESUME_GUIDE.md` -- not this skill.

## Output Format

Report results in this format:


Startup Check:
- Git: [branch] with [N uncommitted files / clean]
- GitHub CLI: [working/failed]
- Phase 3.7 Approval: [verified (source) / NOT VERIFIED -- present plan summary and ask / N/A (not on a sprint feature branch)]
- Ready: [Yes/No]


Then always show the sprint state read from `.claude/sprint_status.json`:


Sprint State (.claude/sprint_status.json, last updated [_last_updated]):
- Sprint: [current_sprint.number] on [current_sprint.branch] [OK matches current branch / WARNING mismatch -- file is STALE, trusting git]
- Plan approved: [plan_approved true/false]
- Status: [current_sprint.status]
- Tests (last recorded): [tests_passing] passing / [tests_skipped] skipped / [tests_failing] failing

## Task Status
[From the per-sprint task block, if present]

## Next Actions
[From next_actions -- prefix with "POSSIBLY SUPERSEDED:" if commits landed after _last_updated]


If the file is stale by any of the four staleness checks, say so explicitly on the Sprint State line
and do NOT present `next_actions` as authoritative.

If Ready is No, list what needs to be fixed before proceeding.
