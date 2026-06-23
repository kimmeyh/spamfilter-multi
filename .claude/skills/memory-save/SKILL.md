---
name: memory-save
description: Produce a lightweight sprint resume-string (for the user to paste into the context-reduction command) that preserves sprint-execution-process state and points to SPRINT_RESUME_GUIDE.md for durable context
allowed-tools: Bash, Read
user-invocable: true
model: haiku
---

# Memory Save Skill (resume-string generator)

**Naming note (Sprint 40, 2026-05-25)**: renamed from `sprint-compact` to `memory-save`. The Claude Code harness was auto-triggering context reduction simply because the skill NAME (and description) contained the word "compact" -- invoking the old name fired a real context-reduction every time (observed 3x, including with ~590K context tokens free). The old heavyweight file-based `memory-save` skill is retired; this lightweight resume-string generator takes its name. Do NOT reintroduce the word "compact" into the skill name or description.

Generate a `<resume-string>` (under ~2K characters) that the USER pastes into Claude Code's built-in context-reduction command so the post-reduction session resumes the sprint-execution process correctly. This skill ONLY produces the string; it never runs any command itself.

**Purpose**: the lightweight successor to the old file-based context save. The resume-string carries ONLY volatile state (process stage, sprint number/branch, current phase, last/next steps, HEAD, PR). All durable context (phase definitions, decision-class taxonomy, stopping criteria, file paths, resume sequence) lives in `docs/SPRINT_RESUME_GUIDE.md` and is referenced rather than duplicated. This keeps the resume-string small and reduces token usage at every reduction boundary.

**CRITICAL framing (Sprint 39 retro fix, 2026-05-25)**: do NOT assume "a sprint is in progress." Assume the **sprint-execution-docs PROCESS is in progress** -- which spans the full lifecycle INCLUDING the gaps between sprints. The process has distinct STAGES (see Step 1); detect the current one and write the string for it. A sprint just merged with the next not yet planned is a valid, common state and MUST be representable -- do not force-fit it into an "in progress" template or abort.

**Source**: Sprint 38 retrospective IMP-1 (2026-05-18); Sprint 39 retro stage-awareness fix (2026-05-25). User feedback: "effective, but as compact as reasonably possible and take as few tokens as reasonably possible" + "do not assume a sprint is in progress, but the sprint execution docs process is in process."

## Step 1: Detect the Process Stage

Determine which ONE stage the process is in (use git/PR state + conversation):

- **BETWEEN-SPRINTS**: last sprint's PR is MERGED (or no open sprint PR) and no plan exists for the next sprint. NEXT ACTION = start next sprint Phase 1/2. (This was the previously-missing stage.)
- **REFINEMENT**: Backlog Refinement (Phase 1) underway; no `SPRINT_N_PLAN.md` for the next sprint yet.
- **PLANNING**: drafting `SPRINT_N_PLAN.md` (Phase 2-3) but Phase 3.7 approval NOT yet granted.
- **EXECUTION**: Phase 3.7 approved; Phases 4-6 (build/test/PR) in progress.
- **RETRO**: Phase 7 retrospective in progress (or follow-ups pending before Chief-Developer merge).

If unsure, state the stage as `<unknown -- recheck SPRINT_RESUME_GUIDE.md + git/PR state>`.

## What to Collect (Step 2)

**CRITICAL -- KEEP THIS SKILL LIGHTWEIGHT (Sprint 40 fix, 2026-05-25)**: this skill is invoked when context may be high. Reading large files here adds tokens for no benefit. Keep it minimal regardless of the compaction-trigger question. To do that:

- Use ONLY the lightweight git/PR commands below. They cost almost nothing.
- Do NOT read SPRINT_N_SUMMARY.md, SPRINT_N_RETROSPECTIVE.md, ARCHITECTURE.md, or ANY memory (`feedback_*.md`) file. Those are durable context that lives in `SPRINT_RESUME_GUIDE.md` and is REFERENCED by name, not read.
- Reading `SPRINT_N_PLAN.md` (item 4) is OPTIONAL and only the TOP 30 LINES, and ONLY if you genuinely lack the phase/task state from the conversation. If the conversation already tells you the stage and next steps, SKIP item 4 entirely.
- Derive LAST/NEXT steps from the CONVERSATION, not from re-reading docs.

Run these reads in parallel to populate the compact-string fields:

1. **Sprint name + branch**: `git -C "D:\Data\Harold\github\spamfilter-multi" rev-parse --abbrev-ref HEAD`
2. **HEAD commit**: `git -C "D:\Data\Harold\github\spamfilter-multi" log -1 --oneline`
3. **PR (open OR merged)**: `gh pr list --head <branch> --state all --json number,isDraft,state --jq '.[0]'` -- capture MERGED vs OPEN(draft/ready). MERGED is a valid, expected value (BETWEEN-SPRINTS).
4. **Current sprint plan**: read top 30 lines of `docs/sprints/SPRINT_N_PLAN.md` (N from branch). For BETWEEN-SPRINTS/REFINEMENT/PLANNING, note that no plan exists yet for the NEXT sprint (N+1).
5. **Recent test/analyze state**: from the most recent conversation turn or `flutter test 2>&1 | tail -1`

Do NOT collect: full phase definitions, decision-class examples, stopping-criteria definitions, critical file paths -- those live in `SPRINT_RESUME_GUIDE.md`.

## Compact-String Format

**OUTPUT-SAFETY RULE (Sprint 40 fix, 2026-05-25)**: Harold observed that invoking this skill auto-triggered compaction THREE times -- even with ~590K context tokens free (41% used), so it was NOT a real token-limit event. Root cause not fully confirmed, but the one thing unique to this skill is that its body/output literally contains the compaction slash-command token. Theory-independent mitigation: NEVER write the literal compaction slash-command token (slash + "compact") anywhere in the skill body OR your output. In the resume-string template, write the leading token as `<slash>compact` -- the USER replaces `<slash>` with a real `/` when they paste it into the command. Emit the whole resume-string inside a fenced code block (```), preceded by a short label line like "Resume-string -- replace <slash> with / and run as the compaction command:".

Output exactly this template, filling in the values. Keep the entire output under 2000 characters. Use plain ASCII. The FIRST LINE is stage-dependent -- pick the matching variant (note the `<slash>` placeholder, NOT a literal slash):

- EXECUTION/RETRO: `<slash>compact Sprint <N> <STAGE> on branch <branch>, HEAD=<short-hash> <commit-subject>.`
- BETWEEN-SPRINTS: `<slash>compact Sprint <N> COMPLETE/MERGED; Sprint <N+1> not yet started. Branch <branch>, HEAD=<short-hash> <commit-subject>.`
- REFINEMENT/PLANNING: `<slash>compact Sprint-execution process at <STAGE> for Sprint <N+1>. Branch <branch>, HEAD=<short-hash> <commit-subject>.`

```
<stage-dependent first line above>

STAGE: <BETWEEN-SPRINTS | REFINEMENT | PLANNING | EXECUTION | RETRO>. Phase 3.7 approval: <granted YYYY-MM-DD | pending | N/A (no active sprint plan)>.

LAST 2 STEPS COMPLETED:
- <step>
- <step>

NEXT 2 STEPS:
- <step>
- <step>

PR: #<n> (<draft|ready|MERGED>, <MERGEABLE|CONFLICTING|n/a>) -- <"awaiting <X>" if applicable>. (or "PR: none")

TESTS: <"+N ~M -P" from last run> | analyze: <0 issues | N issues | n/a>.

CONTEXT NOTES:
- This is the sprint-execution-docs PROCESS, NOT vibe coding. The process is always in progress even between sprints. Phase 3.7 approval (when an active plan exists) is durable through Phase 7.
- Resume context: read docs/SPRINT_RESUME_GUIDE.md (phase definitions, decision-class taxonomy, stopping criteria, "Next Steps" progression, resume sequence, critical file paths).
- Sprint plan: docs/sprints/SPRINT_<N>_PLAN.md (note if it does NOT exist yet for the next sprint -> Phase 1 gate applies).
- <stage-specific note: for BETWEEN-SPRINTS, list the pre-scoped next-sprint items + any open Chief-Architect ratification items>.

KEY GUARDRAILS (full text in memory entries, just listed here):
- feedback_decision_class_taxonomy.md -- arch/dev/sprint-scope decisions need Chief signoff at natural breaks
- feedback_stopping_400hr.md -- wall-clock hours are NOT a stop signal unless estimate >400hr
- feedback_echo_requirements.md -- echo multi-surface requirements back in 1 sentence
- feedback_phase7_prompt_protocol.md -- 7-step Phase 7 protocol, do not collapse/reorder/skip
- feedback_mirror_working_code.md -- broken path with working sibling? mirror the sibling, don't guess
- feedback_auto_advance_hook.md -- stop-hook will block paraphrased procedural questions on sprint branches

NEXT ACTION: <one sentence verb-first description of the very next action to take>.
```

## Field Rules

- **Sprint N**: from branch name `feature/YYYYMMDD_Sprint_N`. If the branch's sprint is merged/complete, ALSO name the next sprint (N+1) for the BETWEEN-SPRINTS/REFINEMENT/PLANNING first-line variants. A non-sprint branch (e.g. `develop` after a merge) is ALLOWED -- do NOT abort; report the stage as BETWEEN-SPRINTS and derive N from the most recent merged sprint PR.
- **STAGE**: from Step 1.
- **Branch**: full branch name as returned by `rev-parse --abbrev-ref HEAD`.
- **HEAD short-hash**: first 7 chars of commit SHA.
- **Commit-subject**: subject line only (first line of `--oneline`), strip the SHA prefix.
- **LAST 2 STEPS / NEXT 2 STEPS**: from the conversation transcript (most specific) or `SPRINT_CHECKLIST.md` for the current phase. For BETWEEN-SPRINTS, NEXT steps = sync develop + start next-sprint Phase 1.
- **PR fields**: from `gh pr list --head <branch> --state all --json ...`. MERGED is a valid value. If no PR, write "PR: none".
- **TESTS**: from most recent `flutter test` output line in conversation; if not present, leave blank and note "run full tests before compacting".
- **NEXT ACTION**: a single imperative sentence. Do not list multiple actions.

## What NOT to Include

The compact-string deliberately omits these (they live in `SPRINT_RESUME_GUIDE.md`):

- Phase-by-phase workflow definitions
- Decision-class taxonomy examples
- Stopping-criteria explanations
- Standing Approval Inventory contents
- Resume sequence steps
- Critical file path listings
- Memory entry full-text (only names referenced)

## Output

After collecting the fields, output ONLY the fenced resume-string block + its one label line (no other preamble or commentary). The user replaces `<slash>` with `/` and runs it as the compaction command. Keep total output under 2000 characters; if you approach 1800, trim the LAST 2 STEPS / NEXT 2 STEPS bullets to be more terse rather than dropping fields.

## Constraints

- Read-only -- do NOT modify any files in the project. This skill produces text output only.
- Do NOT save anything to `.claude/memory/current.md` -- that was the old `/memory-save` approach. The compact-string IS the persistence mechanism (run by the user as the compaction command).
- Do NOT include Harold's name, email, or any other PII beyond what is necessary (sprint number, branch, file paths).

## Anti-Pattern (DO NOT DO)

- Do NOT assume "a sprint is in progress" -- detect the STAGE first (BETWEEN-SPRINTS is common and valid).
- Do NOT abort on a non-sprint branch -- report BETWEEN-SPRINTS instead.
- Do NOT run the compaction command yourself -- this skill PRODUCES the string; the USER decides when to compact.
- NEVER write the literal compaction slash-command token (slash + "compact") in the body or output -- use the `<slash>compact` placeholder. This is the theory-independent fix for the auto-trigger Harold observed.
- Do NOT regenerate the content of `SPRINT_RESUME_GUIDE.md` inline -- that defeats the purpose. The pointer is the value.
- Do NOT add "I will now produce..." preamble. Output is the label line + the fenced block only.
- Do NOT include past-sprint history beyond the just-completed sprint's outcome line.
- Do NOT exceed 2000 characters total -- if the natural output is longer, trim NEXT 2 STEPS bullets and CONTEXT NOTES first.
