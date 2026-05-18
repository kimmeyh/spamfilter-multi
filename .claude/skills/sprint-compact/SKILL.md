---
name: sprint-compact
description: Produce a compact resume-string for use with /compact that preserves sprint state and points to SPRINT_RESUME_GUIDE.md for durable context
allowed-tools: Bash, Read
user-invocable: true
model: haiku
---

# Sprint Compact Skill

Generate a `<compact-string>` (under ~2K characters) that can be passed to `/compact <string>` so the post-compact session resumes the sprint correctly.

**Purpose**: Replaces `/memory-save` for sprint resume. The compact-string carries ONLY volatile state (sprint name, current phase, last/next steps, HEAD, branch). All durable context (phase definitions, decision-class taxonomy, stopping criteria, file paths, resume sequence) lives in `docs/SPRINT_RESUME_GUIDE.md` and is referenced rather than duplicated. This keeps the compact-string small and reduces token usage at every compaction boundary.

**Source**: Sprint 38 retrospective IMP-1 (2026-05-18). User feedback: "Want to take a new approach to /memory-save and replace it with a request to produce a text summary that can be given to /compact that will allow the compact but preserve key information about the current status that tend to be missed in /compact with no string ... would like it to effective, but as compact as reasonably possible and take as few tokens as reasonably possible."

## What to Collect

Run these reads in parallel to populate the compact-string fields:

1. **Sprint name + branch**: `git -C "D:\Data\Harold\github\spamfilter-multi" rev-parse --abbrev-ref HEAD`
2. **HEAD commit**: `git -C "D:\Data\Harold\github\spamfilter-multi" log -1 --oneline`
3. **Open PR for sprint** (if any): `gh pr list --head <branch> --json number,isDraft,mergeable --jq '.[0]'`
4. **Current sprint plan**: read top 30 lines of `docs/sprints/SPRINT_N_PLAN.md` (N from branch name)
5. **Recent test/analyze state**: from the most recent conversation turn or `flutter test 2>&1 | tail -1`

Do NOT collect: full phase definitions, decision-class examples, stopping-criteria definitions, critical file paths -- those live in `SPRINT_RESUME_GUIDE.md`.

## Compact-String Format

Output exactly this template, filling in the values. Keep the entire output under 2000 characters. Use plain ASCII.

```
/compact Sprint <N> in progress on branch <branch>, HEAD=<short-hash> <commit-subject>.

PHASE: <current phase number> -- <phase name>. Phase 3.7 approval: <granted on YYYY-MM-DD | pending>.

LAST 2 STEPS COMPLETED:
- <step>
- <step>

NEXT 2 STEPS:
- <step>
- <step>

PR: #<pr-number> (<draft|ready>, <MERGEABLE|CONFLICTING>) -- <"awaiting <X>" if applicable>.

TESTS: <"+N ~M -P" from last run> | analyze: <0 issues | N issues>.

CONTEXT NOTES:
- This is a sprint, NOT vibe coding. Sprint-plan approval at Phase 3.7 is durable through Phase 7.
- Resume context: read docs/SPRINT_RESUME_GUIDE.md (carries phase definitions, decision-class taxonomy, stopping criteria, canonical "Next Steps" progression, 4-step resume sequence, critical file paths).
- Sprint plan: docs/sprints/SPRINT_<N>_PLAN.md.

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

- **Sprint N**: extract from branch name `feature/YYYYMMDD_Sprint_N` -- the N at the end. If branch is non-sprint, abort and tell user the skill applies only on sprint branches.
- **Branch**: full branch name as returned by `rev-parse --abbrev-ref HEAD`.
- **HEAD short-hash**: first 7 chars of commit SHA.
- **Commit-subject**: subject line only (first line of `--oneline`), strip the SHA prefix.
- **PHASE**: derive from conversation state. If unsure, say "<unknown -- recheck SPRINT_<N>_PLAN.md and SPRINT_CHECKLIST.md>".
- **LAST 2 STEPS / NEXT 2 STEPS**: from `SPRINT_CHECKLIST.md` for the current phase, OR from the conversation transcript if more specific.
- **PR fields**: from `gh pr list --head <branch> --json ...`. If no PR, write "PR: none".
- **TESTS**: from most recent `flutter test` output line in conversation; if not present, leave blank and note "run /full-test before /compact".
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

After collecting the fields, output ONLY the compact-string (no preamble, no commentary). The user copies it into `/compact <string>`. Keep total output under 2000 characters; if you approach 1800, trim the LAST 2 STEPS / NEXT 2 STEPS bullets to be more terse rather than dropping fields.

## Constraints

- Read-only -- do NOT modify any files in the project. This skill produces text output only.
- Do NOT save anything to `.claude/memory/current.md` -- that was the old `/memory-save` approach. The compact-string IS the persistence mechanism via `/compact`.
- Do NOT include Harold's name, email, or any other PII beyond what is necessary (sprint number, branch, file paths).

## Anti-Pattern (DO NOT DO)

- Do NOT regenerate the content of `SPRINT_RESUME_GUIDE.md` inline -- that defeats the purpose. The pointer is the value.
- Do NOT add "I will now produce..." preamble. Output starts with `/compact ...`.
- Do NOT include past-sprint history. Only the current sprint state.
- Do NOT exceed 2000 characters total -- if the natural output is longer, trim NEXT 2 STEPS bullets and CONTEXT NOTES first.
