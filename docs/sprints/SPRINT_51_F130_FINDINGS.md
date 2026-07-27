# Sprint 51 -- F130-S51 Process-Docs Consistency Deep Dive: Findings

**Run**: first instance of the F130 template
**Date**: 2026-07-27
**Auditor**: Claude Opus 5 (1M)
**Scope + method + the 9 defect classes**: defined in `docs/ALL_SPRINTS_MASTER_PLAN.md` under **F130** -- not restated here.

**Tier status** (the time-box is on BREADTH, per the plan):

| Tier | Surfaces | Status |
|---|---|---|
| 1 | `SPRINT_EXECUTION_WORKFLOW.md`, `SPRINT_CHECKLIST.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/hooks/*`, auto-memory | **COMPLETE** -- 9 findings, all corrected |
| 2 | Remaining SPRINT EXECUTION docs, `.claude/skills/*`, `settings.json`, `sprint_status.json` schema | NOT STARTED |
| 3 | Cross-references, dead links, anchors | NOT STARTED |

**Contradiction count (running): 9 found / 9 corrected / 0 deferred / 0 surfaced as Class-3.**

---

## Findings

| # | Instruction | Sites | Statements found | Authoritative version | Action |
|---|---|---|---|---|---|
| 1 | When the next sprint branch is created | `SPRINT_CHECKLIST.md` x2, `SPRINT_EXECUTION_WORKFLOW.md` x3 (cheat-sheet action cell, cheat-sheet exit cell, 6.6 "Why" paragraph), memory `feedback_next_branch_on_merge` `description:` + `MEMORY.md` index line | "off updated develop" (with literal `git checkout develop` + `git pull` commands in the checklist) **vs** "FROM THE CURRENT FEATURE BRANCH" in 6.6 Steps. The 6.6 section contradicted **itself** -- its "Why" paragraph said develop while its "Steps" block two lines below said feature branch. | 6.6 **Steps** (Sprint 49 retro IMP-6; Harold's directive, corrected 5x) | **CORRECTED** 2026-07-27 (commit `fe495db`). All 5 doc sites + both memory sites. Class 1 + 2 + 3 + 4. |
| 2 | Hook: may a turn end by requesting Phase 3.7 approval? | `sprint-auto-advance.ps1` Gate 1b **vs** `SPRINT_EXECUTION_WORKFLOW.md` Phase 3.7 | Hook: any question on a sprint branch with a plan file = violation. Workflow: Phase 3.7 approval request is **MANDATORY**. Gate 1b's plan-file existence test cannot distinguish "drafted, awaiting approval" from "approved, executing" -- the file exists from the moment it is drafted. | Workflow (Phase 3.7 approval **creates** the authorization the hook enforces, so it can never be auto-advanced past) | **CORRECTED** -- Gate 1b now reads `sprint_status.json.current_sprint.plan_approved` (authoritative) with the plan's `**Status**:` line as a guarded fallback. +2 test cases. Class 6. |
| 3 | Hook: what counts as a `git stash` invocation? | `block-carry-forward-stash.ps1` | Matched the literal words **anywhere** in the command string, including inside quoted content -- blocked an Edit writing docs that DOCUMENT the prohibition, and a `gh pr create` whose `--body` described the defect. Three false positives in one session, all on correct work. | Block real **invocations** only | **CORRECTED** -- strips heredoc bodies and quoted spans before matching. +8 test cases (3 reproduce the false positives). Class 6. |
| 4 | Hook test coverage | `run-test-cases.ps1` | Hard-wired to `sprint-auto-advance.ps1`, so `block-carry-forward-stash.ps1` and `verify-closeout-complete.ps1` had **no** automated coverage -- which is precisely why both false positives (findings 2 and 3) shipped unnoticed. | All hooks must be covered | **CORRECTED** -- harness now routes by directory; suite 24/24 across two hooks. Class 7 (MANDATORY behavior with no enforcing test). |
| 5 | Hook tests must be deterministic | `test-cases/violation-1/2/3`, `allow-11` | Four cases carried no `branch_override`/fixture, so they inherited the **live repo's** sprint phase. They passed only because the repo happened to be mid-execution; they flipped green/red incorrectly when Sprint 51 moved between draft and approved. A test that passes for environmental reasons is not a test. | Every case pins its own fixture | **CORRECTED** -- all four pinned to `fixtures/draft-sprint` or `fixtures/approved-sprint`. Class 7. |
| 6 | Which model tier is required for retrospectives/planning | `SPRINT_CHECKLIST.md:124`, `.claude/skills/plan-sprint/SKILL.md` **vs** `SPRINT_PLANNING.md` | Checklist: "**Verify active model is Opus** ... requires Opus per 'Activities Requiring Opus'". Skill: "assign **Opus**" / "stays Opus regardless". Planning doc (post-Sprint-49 rename): "**Activities Requiring Fable/Opus** -- top available tier, Fable 5 preferred". **Live defect**: the checklist line would have FAILED verification against the Fable 5 session that actually ran the Sprint 50 retrospective. | `SPRINT_PLANNING.md` "Activities Requiring Fable/Opus" (Sprint 49 retro) | **CORRECTED** -- checklist + skill updated to the top-available-tier wording. Class 3 (superseded text left in place after a rename). |
| 7 | Decision-Class Taxonomy (surface architecture / development / scope decisions) | `CLAUDE.md` **vs** `AGENTS.md` | CLAUDE.md carries the full `[CRITICAL]` section; **AGENTS.md had ZERO mentions**. An agent reading only AGENTS.md had no instruction to surface Class-1/2/3 decisions and would make them unilaterally -- the exact failure the taxonomy was written (Sprint 38) to prevent. | CLAUDE.md (both files must carry it -- every model tier reads one or the other) | **CORRECTED** -- section ported to AGENTS.md with Codex-appropriate wording plus a keep-in-sync note. Class 1 (same instruction, one site silently absent). |
| 8 | Memory `description:` fields teaching superseded guidance | `feedback_cheapest_first_model` (Haiku->Sonnet->**Opus**), `feedback_context_window_stopping` (cites **Opus 4.7** specifically), `feedback_table_format` ("manual **testing**") | Each `description:` is what surfaces during RECALL, so it outranks the docs in practice -- a corrected doc plus a stale memory means the stale version keeps being re-taught. | The corrected docs (Sprint 49 Fable/Opus rename; Sprint 50 IMP-1 terminology; Sprint 50 IMP-7 Executed-by) | **CORRECTED** -- 3 `description:` fields updated. `feedback_opus_pitfalls` deliberately NOT renamed: it is a version-specific historical appendix, and renaming it would falsify what it documents. Class 4. |
| 9 | `MEMORY.md` index lines (loaded into context EVERY session) | 7 lines carrying "manual testing", "Haiku->Sonnet->Opus", "planner stays Opus", "during Manual Testing" | The index is the highest-frequency instruction surface in the repo -- it is injected every session -- yet it lagged both the terminology rename and the tier rename. | Corrected docs | **CORRECTED** -- 7 index lines aligned. Class 4. |

---

## Observations (not individual findings)

- **Seven of nine findings are duplication artifacts.** Every one arose where the same instruction was written out in more than one place and the copies drifted. This validates the F130 method note: prefer ONE authoritative statement plus pointers over duplicated prose.
- **Two findings (2, 3) were enforcement firing on correct work.** That is worse than a missing hook: it teaches the operator to route around the guard, which devalues every other hook. Both are now covered by tests.
- **Finding 4 explains findings 2 and 3.** The hooks had no test coverage, so their false positives could only be discovered by tripping them in live use -- which is what happened, three times in one session.
- **Finding 6 was a live defect, not a latent one.** The stale checklist line would have failed against the model that actually ran the last retrospective.
- **Findings 8 and 9 sit on the highest-frequency surface.** `MEMORY.md` is injected into EVERY session and memory `description:` fields drive recall, so a stale line there outranks a corrected doc in practice. Any future terminology or policy rename must sweep memory in the same pass as the docs -- this is now the single most important addition to the F130 method.
