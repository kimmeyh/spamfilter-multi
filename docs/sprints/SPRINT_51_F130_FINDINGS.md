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

**Contradiction count (running): 10 found / 10 corrected / 0 deferred / 0 surfaced as Class-3.**

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
| 10 | Close-out hook: what counts as a "close-out complete" claim? | `verify-closeout-complete.ps1` (written 2026-07-26, fired wrongly 2026-07-27) | Its first claim-pattern used an 80-character bridge between the subject and "complete", so ordinary mid-sprint status -- *"Sprint status: Task 1 Tier 1 complete, Task 2 complete, Task 3 blocked"* -- read as a close-out claim. It then blocked the turn for having OPEN sprint issues, which is the CORRECT state mid-sprint (they close at that sprint's merge). **Third hook in this sprint to fire on correct work**, and the newest one -- written the day before. | A claim about the SPRINT/CLOSE-OUT itself, never about an individual task | **CORRECTED** -- patterns anchored (subject adjacent to verb, short bridge) plus a mid-sprint exclusion list ("Task N blocked", "stopping criterion", "Sprint status", "still executing") that overrides a claim match. +5 test cases incl. one reproducing this exact false positive. Class 6. |

---

## Environment finding (not a docs contradiction, but it blocked Task 3)

**Dev credential store was absent; restored 2026-07-28.**

- **Symptom**: every existing WinWright script failed at the account-selection step (`Button[name*='kimmeyharold@aol.com']` resolved 0 elements), and the dev Select Account screen rendered "Saved Accounts" with no rows -- blocking F129 selector discovery on two of three target screens.
- **My first two diagnoses were WRONG, and both were stated before checking**: (a) that I had renamed the dev credentials during the Sprint 50 screenshot session -- in fact every rename that session was in the PROD directory (`credentials.demoshoot`, `spam_filter.db.demoshoot` are still there); (b) that a prod->dev copy could not work because DPAPI is app-scoped -- it is **user**-scoped, so the copy works fine.
- **Actual state**: `MyEmailSpamFilter_Devlutter_secure_storage.dat` did not exist. The Sprint 19 `app_identity_migration` copies that file from the legacy `com.example\spam_filter_mobile` path, but it targets the PROD data directory; the dev directory was introduced later by ADR-0035, so dev never received a migrated store. Dev logs show credentials loading successfully as recently as 2026-07-26, so the store existed at some point and was lost/never persisted in its own path.
- **Fix**: copied prod's `flutter_secure_storage.dat` to the dev data directory (verified it decrypts under the current Windows user and carries `saved_accounts = kimmeyharold@aol.com,kimmeyh@gmail.com`, matching the two rows already in the dev `accounts` table). Harold confirmed both accounts render. The previously-failing script now passes steps 1-7 including account selection.
- **Residual (real, separate)**: (1) `test_f56_create_safe_sender.json` step 8 (`Button[name='Save']` on the confirm dialog) still resolves 0 elements -- pre-existing selector drift in a Sprint 41 script, now a known F129 input rather than a mystery. (2) The account rows are NOT exposed as named elements in the UIA tree even though they render -- `inspect` shows zero matches while the UI clearly shows both accounts -- so tree inspection cannot be trusted as the sole source for selector discovery on that screen.
- **Backlog candidate**: `app_identity_migration` does not seed the dev data directory, so a fresh dev environment starts with no credential store even when a valid one exists. Worth an explicit dev-bootstrap step or a documented manual copy.

---

## F129 tooling finding: WinWright's UIA projection under-reports Flutter semantics

Discovered while doing selector discovery for the F129 scripts (Sprint 51). This is a **tooling-capability finding of the kind SPRINT_PLANNING.md's "Tooling-Capability Pre-Flight" exists to catch** -- and it was found before scripts were written, which is the point of that rule.

**The instruments disagree with each other on the same process at the same moment:**

| Instrument | App-bar buttons (tooltip-based) | Account rows (Semantics label) |
|---|---|---|
| CLI `winwright inspect <pid>` | **named** (Help, Settings, `Review "No Rule" Items`, ...) | **unnamed** |
| MCP `ww_get_snapshot` | **unnamed** | **unnamed** |
| Flutter widget test (`find.bySemanticsLabel`) | n/a | **NAMED -- label present and correct** |

**Conclusion**: the labels ARE in Flutter's semantics tree (3 widget tests prove it); the Windows UIA projection does not surface `Semantics(label:)` on a merged container, and the MCP snapshot path surfaces even less than the CLI path. So "the element has no name in `ww_get_snapshot`" is NOT evidence that the app lacks accessibility markup -- a conclusion I drew and had to retract mid-task.

**Consequences for F129 (recorded so the next author does not repeat the discovery):**
1. Verify accessibility markup with **Flutter widget tests** (`find.bySemanticsLabel`, `getSemantics().hasFlag`), never with a WinWright tree dump. The widget test is authoritative; the UIA tree is a lossy projection of it.
2. Scripts can only address elements the CLI projection actually names -- in practice, widgets carrying a **`tooltip:`** (IconButton/AppBar actions) and screen titles. `Semantics(label:)` on a container is not addressable today.
3. The account-selection screen therefore cannot be driven by name-based selectors regardless of markup quality, which caps what F129 scripts can cover from the home screen.
4. Two harness behaviors compound this: the CLI runner **terminates the attached app after every run** (pass or fail), so iterative discovery needs a relaunch per attempt; and `ww_dump_tree` / `ww_wait` are **not replayable** by the script runner, so a script cannot introspect mid-run.

**Accessibility value delivered regardless of the tooling limit**: the Semantics work is a real fix. Before it, an account row was an unnamed node -- a screen-reader user heard nothing actionable. It now announces `<email> - <provider> - <auth method>` with a "Select account to scan" hint, and the error row names the failing account and the reason. Pinned by 3 widget tests so it cannot regress.

---

## Observations (not individual findings)

- **Seven of nine findings are duplication artifacts.** Every one arose where the same instruction was written out in more than one place and the copies drifted. This validates the F130 method note: prefer ONE authoritative statement plus pointers over duplicated prose.
- **THREE findings (2, 3, 10) were enforcement firing on correct work** -- including finding 10, in a hook written the day before, which fired on the very message reporting this audit's progress. That is worse than a missing hook: it teaches the operator to route around the guard, which devalues every other hook. Both are now covered by tests.
- **Finding 4 explains findings 2 and 3.** The hooks had no test coverage, so their false positives could only be discovered by tripping them in live use -- which is what happened, three times in one session.
- **Finding 6 was a live defect, not a latent one.** The stale checklist line would have failed against the model that actually ran the last retrospective.
- **Findings 8 and 9 sit on the highest-frequency surface.** `MEMORY.md` is injected into EVERY session and memory `description:` fields drive recall, so a stale line there outranks a corrected doc in practice. Any future terminology or policy rename must sweep memory in the same pass as the docs -- this is now the single most important addition to the F130 method.
