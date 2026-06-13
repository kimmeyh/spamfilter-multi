# S38-CI-7 -- Opus 4.6 vs 4.7 Head-to-Head Evaluation Briefs

**Sprint**: 40
**Created**: 2026-05-30
**Purpose**: Capture the IDENTICAL task briefs given to Opus 4.7 subagents during the Sprint 40 productive run, so the same briefs can be re-run on Opus 4.6 in a separate Claude Code session for apples-to-apples comparison per the master-plan S38-CI-7 specification (`docs/ALL_SPRINTS_MASTER_PLAN.md:194-206`).

## Why these are captured as artifacts (Class-3 surfacing)

The Sprint 40 plan called for S38-CI-7 to be executed in this session by dispatching Opus-4.6 subagents on throwaway `*-opus46` branches. At the execution gate, the runtime constraint was surfaced as a Class-3 (sprint-execution) decision: the in-session `Agent` tool exposes a `model` enum of `sonnet | opus | haiku` with no version pin, so subagent dispatch cannot guarantee the 4.6 vs 4.7 split the plan requires.

Capturing the briefs here lets the eval execute faithfully later -- in a separate Claude Code session pinned to Opus 4.6 -- without losing the Sprint 40 productive momentum and without producing a misleading 4.7-vs-4.7 "head-to-head" that would compare a model to itself.

## How to run the eval

1. **Set up the 4.6 environment.** Launch a Claude Code session on Opus 4.6 (the dev-mode toggle / model selector). Confirm via `feedback_opus_pitfalls.md` reference or `/help`.

2. **Create the four throwaway branches** from `develop`:
   - `git checkout develop && git pull`
   - `git checkout -b feature/20260525_Sprint_40_F78-opus46`
   - (similarly for F25, F35, F37)

3. **Run each brief verbatim** as the user prompt in the 4.6 session, one branch per task. The briefs are self-contained -- do not provide additional context beyond what is in the brief file (this is the point of the experiment: instruction-following on the SAME input).

4. **Capture per-run artifacts** on each `*-opus46` branch:
   - Full transcript (export via Claude Code session log)
   - `git diff` of the productive change
   - Round count (how many user-correction iterations were needed)
   - Process deviations (any phase-gate / checklist / approval-class violations)

5. **Score the 5 dimensions** per task per model into a matrix in `docs/sprints/SPRINT_40_RETROSPECTIVE.md`:
   1. Sprint-execution-doc process adherence
   2. Instruction-following (task spec + CLAUDE.md + standing instructions)
   3. Architecture discipline (Class-1/2 deviations)
   4. Stopping-criteria adherence (SPRINT_STOPPING_CRITERIA.md respect)
   5. Code quality (forward-looking maintainability)

6. **Feed conclusions back** into `feedback_opus_pitfalls.md` (add a 4.6 section beside the existing 4.7 section) and into model-assignment guidance.

## Files in this directory

- [F78-brief.md](F78-brief.md) -- widget tests for ManualRuleCreateScreen (Haiku in productive run; eval uses Opus 4.6)
- [F25-brief.md](F25-brief.md) -- Rule Testing UI 3 sub-features (Sonnet in productive run)
- [F35-brief.md](F35-brief.md) -- Rule editing UI (Sonnet in productive run)
- [F37-brief.md](F37-brief.md) -- Folder selectors two-level + separator (Sonnet in productive run)
- [PRODUCTIVE-RUN-NOTES.md](PRODUCTIVE-RUN-NOTES.md) -- what the Opus 4.7 productive runs actually produced, for diff comparison

## Important: do NOT merge the `*-opus46` branches

These branches exist purely for transcript and diff capture. The productive Sprint 40 work is already on `feature/20260525_Sprint_40` and (by the time you read this) merged to `develop` via the Sprint 40 PR. Re-running the same tasks on 4.6 would conflict; the comparison is read-only against the captured transcript and diff, not a candidate for merge.

## Provenance

These briefs are the verbatim user prompts dispatched to the four Sprint 40 Opus 4.7 subagents on 2026-05-30. The only differences in the 4.6 re-run will be (a) the active model and (b) the branch name -- nothing else.
