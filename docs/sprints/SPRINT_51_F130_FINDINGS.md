# Sprint 51 -- F130-S51 Process-Docs Consistency Deep Dive: Findings

**Run**: first instance of the F130 template
**Date**: 2026-07-27
**Auditor**: Claude Opus 5 (1M)
**Scope + method + the 9 defect classes**: defined in `docs/ALL_SPRINTS_MASTER_PLAN.md` under **F130** -- not restated here.

**Tier status** (the time-box is on BREADTH, per the plan):

| Tier | Surfaces | Status |
|---|---|---|
| 1 | `SPRINT_EXECUTION_WORKFLOW.md`, `SPRINT_CHECKLIST.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/hooks/*`, auto-memory | **COMPLETE** -- 10 findings, all corrected |
| 2 | Remaining SPRINT EXECUTION docs, `.claude/skills/*` (10 files), `settings.json`, `sprint_status.json` schema | **COMPLETE** 2026-07-28 -- 16 findings, all corrected |
| 3 | Cross-references, dead links, anchors | **COMPLETE** 2026-07-28 -- folded into the Tier 2 pass (6 dead references found and corrected; see findings 21-26) |

**Contradiction count (final): 28 found / 28 corrected / 0 outstanding.**
(Tier 1: 10. Tier 2: 11 contradictions + 6 dead references. Finding 27 was caught by the DoD re-grep,
not by the audit pass. Finding 28 -- the retired restore path -- was surfaced as a Class-3 decision
per R-6, decided by Harold on 2026-07-28, and applied the same day.)

**Method note for the next run**: Tier 2 was executed by two parallel read-only audit agents (one on
`.claude/skills/*`, one on the remaining `docs/*` SPRINT EXECUTION set), each given the 8-10
known-authoritative facts as an explicit checklist to test each file against. That framing -- audit
AGAINST a stated ground truth rather than "look for problems" -- is what produced findings with exact
line numbers and no false positives. Every reported path was independently verified with
`Test-Path` before any correction, which caught that two script sets live in OPPOSITE roots
(findings 21/23). Recommend repeating this shape.

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


### Tier 2 findings (2026-07-28)

| # | Instruction | Sites | Statements found | Authoritative version | Action |
|---|---|---|---|---|---|
| 11 | The msix credential-injection key name | `CLAUDE.md:467` **vs** `pubspec.yaml:131`, `test/policy/msix_config_test.dart`, `STORE_RELEASE_PROCESS.md` (7 sites) | CLAUDE.md named the critical field **`build_windows_args`**. That is the F119 typo -- not a real msix key, silently ignored, and the exact defect that shipped a **credential-less 0.5.4 to the Store**. `msix_config_test.dart` is a build-failing gate asserting that string NEVER appears. So the most-read doc in the repo instructed using the one key a test forbids. | `windows_build_args` (pubspec + the gate + STORE_RELEASE_PROCESS, all correct) | **CORRECTED** -- CLAUDE.md now names `windows_build_args`, states the transposed form is the F119 defect, and cites the gate. **Highest-consequence finding of the audit.** Class 2. |
| 12 | Is `.claude/sprint_status.json` a Phase 7.7 close-out item? | `SPRINT_RETROSPECTIVE.md` "What to Update (Phase 7.7)" **vs** `SPRINT_CHECKLIST.md:152` | The checklist makes it mandatory with a full field list and a "VERIFY BY READING IT" warning. The retrospective doc that actually DRIVES Phase 7.7 enumerated 8 documents and **never mentioned it**. This is the precise orphan-instruction shape F130 was chartered to find -- and the direct cause of the file drifting **15 sprints**. | `SPRINT_CHECKLIST.md` Phase 7.7 | **CORRECTED** -- new numbered subsection in SPRINT_RETROSPECTIVE.md with the full field list, the verify-by-reading rule, and a keep-in-step pointer. Class 1. |
| 13 | Full-suite test command | `TESTING_STRATEGY.md:508/543/548`, `QUALITY_STANDARDS.md:458/476`, `SPRINT_PLANNING.md:322` (6 sites) **vs** `TESTING_STRATEGY.md:31` | The Concurrency Policy (Sprint 49 IMP-5) requires `flutter test --concurrency=4` for FULL suites; six full-suite instructions -- including TESTING_STRATEGY's own execution section -- said bare `flutter test`, the exact command that produces phantom isolate-load failures. | `TESTING_STRATEGY.md:31` | **CORRECTED** -- all 6 sites now carry `--concurrency=4`; targeted single-file runs deliberately left unflagged. Class 1 + 4. |
| 14 | Full-suite test command (skill) | `.claude/skills/full-test/SKILL.md:19` | The repo's designated "run all tests" skill prescribed bare `flutter test` -- the single highest-impact instance of finding 13, because it is the path a session actually invokes. | `TESTING_STRATEGY.md:31` | **CORRECTED** -- skill now runs `--concurrency=4` with a one-line rationale. Class 1. |
| 15 | Expected test count | `.claude/skills/full-test/SKILL.md:25` | "All **185+** tests should pass" -- a Sprint-5-era figure. Against the current ~1,814-test suite this bar passes while ~1,600 tests are missing, so the skill could report success on a catastrophically truncated run. | `.claude/sprint_status.json` -> `test_metrics` | **CORRECTED** -- replaced with a pointer to `sprint_status.json` (self-maintaining) plus the current baseline as of Sprint 51. Class 3. |
| 16 | Top model tier name | `.claude/skills/plan-sprint/SKILL.md` (7 sites: description line, `What It Does`, rationale bullet, escalation heading, examples) **vs** its own line 34 | The file states the corrected ladder ("Fable/Opus, Fable 5 when enabled") on line 34 while hardcoding **Opus** as the top tier throughout the rest. Same class as Tier-1 finding 6, in a file that finding did not reach. | `SPRINT_PLANNING.md` "Activities Requiring Fable/Opus" | **CORRECTED** -- all sites now read Fable/Opus. Class 3. |
| 17 | May complexity score select the model tier? | `.claude/skills/plan-sprint/SKILL.md` §2-§3 **vs** its own line 30 | Line 30: "Model assignment is **bottom-up**: do NOT score complexity and then pick a tier." Sections 2-3 immediately below were pure score->tier mapping (`If score <= 15 (Haiku territory)`, `score > 25 (Opus likely)`, matrix cells labelled "Haiku zone"/"Opus likely"). A reader following the sections executes exactly what the rule forbids. | The CHEAPEST-FIRST ladder (Sprint 43 retro IMP-1) | **CORRECTED** -- score reframed as an ADVISORY input feeding the "why not the cheaper tier" justification; tier labels stripped from the bands; the breakdown examples now show the score shaping HOW WORK IS SPLIT (isolate the expensive part into one small task) rather than which tier runs it. Class 2. |
| 18 | Estimating unit -- planning guidance | `SPRINT_PLANNING.md:886-893` **vs** `SPRINT_PLANNING.md:376` + `CODING_VELOCITY.md` | "Include estimated **hours** for each task" with an all-hours worked example -- in the same file that elsewhere specifies "TWO-metric MINUTE-based per CODING_VELOCITY.md". Hour-anchored estimates ran **4-14x high** (Sprint 39 retro), which is why the minute model replaced them. No `[no-history]` rule mentioned. | `CODING_VELOCITY.md` (minute-based, two-metric) | **CORRECTED** -- rewritten to minutes with Est-Effort/Est-Wall, the `[no-history]` rule, and a pointer to the Estimate Table. Class 3. |
| 19 | Estimating unit -- the canonical plan template | `SPRINT_PLANNING.md:279-285` | The Model Assignment example table used `1h`/`2h`/`1.5h` and a `4.5h + 20% buffer` total. Being the template block, it propagated the hour anchor into **every new sprint plan**. It also omitted the "why not the cheaper tier" column that the same document mandates. | `CODING_VELOCITY.md` + the cheapest-first rule | **CORRECTED** -- converted to Est-Effort/Est-Wall minutes, added the mandatory justification column, and showed a `[no-history]` row. Class 3 + 1. |
| 20 | Estimating unit -- backlog sizing | `BACKLOG_REFINEMENT.md:138-149` and `:178` | T-shirt table anchored in hours (XS = "1-2 hours") calibrated against Sprints 3/9/11, all pre-Sprint-39. Measured reality: a UI-MOVE is **3-6 minutes** -- the table ran roughly an order of magnitude high. The velocity formula was likewise `Estimated Hours / Actual Hours`. | `CODING_VELOCITY.md` Estimate Table + Accuracy Trend | **CORRECTED** -- sizing re-anchored to minutes from measured medians; calibration now points at the Estimate Table instead of remembered sprint totals; velocity restated as the maintained median error-ratio, with an explicit Est-Effort vs Est-Wall warning. Class 3. |
| 21 | Where the E2E runners live | `TESTING_STRATEGY.md:419`, `ARCHITECTURE.md:591/772/778` | Cited `scripts/run-winwright-tests.ps1` / `scripts/run-integration-tests.ps1` at the repo root; both are actually under `mobile-app/scripts/`. | Verified on disk | **CORRECTED**. Class 5 (dead reference). |
| 22 | Where the redaction gate lives | `ARCHITECTURE.md:726` | Cited `scripts/check-log-redaction.ps1`; actual path `mobile-app/scripts/`. Matters because it is named as the enforcement mechanism for a build-failing privacy gate. | Verified on disk | **CORRECTED**. Class 5. |
| 23 | Where the YAML/regex scripts live | `TESTING_STRATEGY.md:741/753` | Cited `mobile-app/scripts/validate-yaml-rules.ps1` / `test-regex-patterns.ps1`; both are actually at the **repo root** `scripts/` -- the exact INVERSE of findings 21-22. Two script families in opposite roots, each documented as being in the other's. | Verified on disk | **CORRECTED** -- both now state the correct root explicitly, with a "NOT `mobile-app/scripts/`" note to stop the swap recurring. Class 5. |
| 24 | Widget-test location | `TESTING_STRATEGY.md:193` | `mobile-app/test/widgets/` does not exist; widget tests live in `mobile-app/test/ui/` (`screens/` + `widgets/`). | Verified on disk | **CORRECTED**. Class 5. |
| 25 | Hook + skill configuration files | `QUALITY_STANDARDS.md:455`, `TROUBLESHOOTING.md:412-413` | Referenced `.claude/hooks.json` and `.claude/skills.json`; **neither exists**. Hooks are `.ps1` scripts in `.claude/hooks/` registered via `.claude/settings.json`; skills are directories under `.claude/skills/`. The "4 automated hooks" count was also wrong -- there are **3** hooks; the 4th script is the hooks' own test harness. | Verified on disk | **CORRECTED** -- both docs now describe the real layout, and the hook count is corrected with the harness called out. Class 5 + 3. |
| 26 | Retrospective doc path + section numbering | `SPRINT_RETROSPECTIVE.md` | Instructed creating `docs/SPRINT_N_RETROSPECTIVE.md`; per-sprint docs live in `docs/sprints/`. Section numbering also collided after finding 12's insertion. | `CLAUDE.md` doc-structure section | **CORRECTED** -- path fixed, sections renumbered. Class 5. |
| 27 | The msix key, AGAIN -- second site | `AGENTS.md:455`, `ALL_SPRINTS_MASTER_PLAN.md:213` | Caught **only by the DoD re-grep** after correcting finding 11: AGENTS.md carried the byte-identical wrong `build_windows_args` sentence, and the master plan's F-STORE-READINESS scope cited the same wrong key. Fixing CLAUDE.md alone would have left two live surfaces still teaching the typo -- the exact "fixing one site while others still teach the old recipe" failure the DoD rule exists to catch, and the same CLAUDE.md-vs-AGENTS.md divergence as Tier-1 finding 7. | `windows_build_args` | **CORRECTED** -- both sites. **This finding is the argument for the re-grep rule: it was invisible to the audit pass and visible only to verification.** Class 1. |
| -- | Encoding corruption (not a contradiction) | `.claude/skills/memory-restore/SKILL.md` (7 occurrences) | UTF-8 em-dashes read as CP-1252 (`U+00E2 U+20AC U+201D`), violating the no-special-Unicode rule. The sibling `startup-check/SKILL.md` had the identical content clean. | ASCII `--` | **CORRECTED** -- all 7 replaced; full skill tree re-scanned clean. |

---

## Hook gap found in use (2026-07-29) -- NOT corrected, recorded for the next F130 run

**`sprint-auto-advance.ps1` has no concept of a NON-SPRINT conversation on a sprint branch.**

Observed twice on 2026-07-29 while diagnosing a machine-local Microsoft Store / AppXSvc fault
(ENV-1) during Sprint 51. The work was not sprint work at all, but the branch was
`feature/20260727_Sprint_51`, so the hook read two legitimate questions as Phase-Auto-Advance
violations:

1. "Should I record this as a backlog item, or leave it out of the project record?" -- a
   scope question about the PROJECT RECORD, not a sprint phase.
2. "Do you want to add the exclusion or uninstall?" -- a question about modifying
   **security software on Harold's machine**, which no sprint plan authorizes and which Claude
   must not decide unilaterally.

Both are in the same family as the already-recorded Phase-1 false positive
(`feedback_hook_phase1_gap`): the hook keys on *branch name + question shape* and has no signal
for "this turn is not about the sprint". The existing whitelist escapes (name a stopping
criterion, or assert plan ambiguity) do not fit, because neither is true -- the honest framing is
"this is not sprint work".

**Why it matters beyond annoyance**: the pressure the hook applies is to answer anyway and keep
going. For a question about uninstalling a user's backup/security software, complying with that
pressure would be the wrong behavior. A hook that pushes toward acting unilaterally on a
user-owned decision is worse than one that occasionally lets a question through.

**Candidate fixes (for the next F130 run -- deliberately NOT applied here, since hook changes
during a sprint were themselves a Sprint 51 finding)**:
- Add a whitelist phrase for out-of-scope work, e.g. "not sprint work" / "your machine" /
  "outside the sprint plan", mirroring the existing criterion/ambiguity escapes.
- Or detect that the turn's tool calls touched no repo files under the sprint plan's
  "Affected components" and treat that as non-sprint context.

Recorded, not fixed. Count NOT incremented -- this is a new observation from live use rather than
one of the 28 audited contradictions.

---

## Surfaced for Harold -- DECIDED AND APPLIED 2026-07-28 (Class-3, R-6)

**Harold's decision: option (1) -- point `/startup-check` at `sprint_status.json` and retire
`/memory-restore`.** Applied the same day. What changed:

- **`/startup-check` step 3 rewritten.** It now reads `.claude/sprint_status.json` instead of
  `.claude/memory/current.md`. There is no `pending_restore` flag to clear any more, so the entire
  write-back-with-four-permission-fallbacks block is gone -- the skill is read-only for state. The
  staleness check was KEPT and strengthened to four explicit tests (branch match, sprint-number match,
  `_last_updated` vs `git log`, and work-already-in-CHANGELOG), because a Phase-7.7-maintained file can
  still lag the working tree between close-outs.
- **`/startup-check` step 2.5(c) reordered.** Phase 3.7 approval evidence now comes from
  `sprint_status.json` (`plan_approved: true` **with** a matching `current_sprint.number`) first, then
  PR comments, then issue comments. The memory-file source is gone. The number-match requirement is
  the point: a `plan_approved: true` left over from a prior sprint is stale state, not approval.
- **`/memory-restore` converted to a tombstone** rather than deleted, so an invocation lands on a page
  explaining what to use instead rather than on a missing command. It records why, and routes to
  `sprint_status.json` / `/startup-check` / `SPRINT_RESUME_GUIDE.md` / auto-memory by need.
- **`CLAUDE.md` + `AGENTS.md` skill listings updated** (both carried the identical line -- the same
  paired-file divergence as findings 7 and 27).
- **The old files are deliberately left on disk, unmodified**, as a historical record. They are inert.
  The tombstone explicitly says not to "refresh" them, because refreshing is what would recreate the
  trap.

Also corrected in the same pass: `SPRINT_RESUME_GUIDE.md` "Critical File Locations" carried a bare
`flutter test` (finding 13's class, a site outside the Tier 2 sweep) and did not mention
`sprint_status.json` at all. Both fixed.

### Original finding, for the record

**The `/memory-restore` + `/startup-check` restore path drives a retired mechanism.**
`memory-save/SKILL.md:127` states plainly: *"Do NOT save anything to `.claude/memory/current.md` -- that
was the old `/memory-save` approach."* But `/memory-restore` (whole file) and `/startup-check` step 3
still read `.claude/memory/current.md` + `memory_metadata.json` as THE restore path. Both files are
self-labelled `[STALE -- DO NOT TRUST]` and frozen at **Sprint 39** (2026-05-24), with
`pending_restore: false`.

It does not misfire today only because that flag is false. **The moment anything sets it,
`/startup-check` restores Sprint-39 context into a Sprint-51+ session.** The live mechanism is
`docs/SPRINT_RESUME_GUIDE.md` + `.claude/sprint_status.json` (which IS current).

This touches the session-startup contract, so per R-6 it is Harold's call rather than mine. Options:
(1) point `/startup-check` step 3 at `sprint_status.json` and retire `/memory-restore`; (2) keep both
and add a staleness guard that refuses to restore a snapshot older than N sprints; (3) leave as-is.
**Recommend (1)** -- one authoritative restore path, consistent with R-4.

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

## F129 outcome: what WinWright can and cannot cover (Sprint 51)

Harold ran a Live Scan on 2026-07-28 (18 no-rule items, 16 senders, `darngoodyarn@homelivingcares.com` x3) so the coverage could be built against real data rather than an empty pool. Result:

**Delivered as WinWright coverage** -- `test_f129_no_rule_review.json`, 10/10 green:
- MT-3 entry point on the home screen opens the Review "No Rule" screen.
- Cross-account filter chips render per configured account; counts are addressable (`All Accounts (18)`, `kimmeyharold@aol.com (18)`, `18 items`).
- Refresh re-enters `_loadItems` (the sweep path) and the screen survives with chips intact.
- Read-only, returns home -- inherently net-zero on the dev DB.

**Initially judged NOT deliverable -- then FIXED at the source (Harold: "add all semantic tree elements as needed for accessibility and WinWright testing"):**
- **Per-item selection**: the 18 item rows rendered as unnamed Groups and a control-type census returned **ZERO CheckBox nodes**. I first reported this as "no exposed checkboxes"; Harold's screenshot showed 18 checkboxes plainly, and the correction matters -- they render fine, they were absent from the *accessibility tree*. Root defect: a bare `Checkbox` announces only "checkbox", so 18 rows produced 18 indistinguishable controls. **FIXED**: each checkbox carries `Semantics(label: 'Select <sender>', checked:)` + a `Tooltip` with the same text; each row carries `<sender> - <subject>`.
- **The account-picker gate**: reaching Manage Rules requires Settings, which opens an account-picker whose entries were **bare `ListTile`s with no accessible name** -- unusable with a screen reader and unaddressable by automation. **FIXED** with the same pattern. A mutating MT-2c script written against the broken picker was proved unrunnable and deleted rather than committed as a known-broken artifact.

**The pattern that works** (learned by test, not assumption): `Tooltip` carries the name into the Windows UIA projection; `Semantics(label:)` carries it to assistive technology. Both are needed -- `Semantics` alone does not project. Two traps found: `explicitChildNodes: true` on a row **suppresses** a child checkbox's own node, and `find.bySemanticsLabel` cannot match a label that Flutter merges onto a shared node (the label was present the whole time; the *assertion* was wrong). Assert by walking the semantics tree instead.
- **Assertions of any kind**: `ww_assert*` is not replayable by the runner (README line 195), so verification must be expressed as clicks. The 3 pre-existing Sprint 41 scripts contain 10 assert steps that silently skip today -- they are weaker than they appear.

**Covered instead at the widget level, where it is provable**: a new `no_rule_review_screen_test` case models Harold's exact data shape (3 items from one sender + 2 uncovered) and asserts that a **pre-existing** covering rule removes all three on the FIRST load with no user action -- the app's own log confirms "Swept 3 item(s) already covered by current rules/safe senders". That is MT-2c's actual contract, proven deterministically rather than inferred from a count chip.

**Net judgment**: WinWright covers navigation and screen identity well; it cannot cover list-item interaction in this Flutter app until the UIA projection improves or the app adopts a projection-friendly pattern. Widget tests carry the behavioral load. This mirrors the Sprint 41 F76 lesson -- prove the tool primitive before building on it -- and is why the F129 estimate was correctly flagged `[no-history]`.

---

## F129 accessibility work: the pattern, and how far it reaches (Sprint 51)

Harold's instruction ("add all semantic tree elements as needed for accessibility and WinWright testing") turned a blocked test task into an accessibility fix. Three screens were audited; the same defect class appears at every level.

**The pattern that works** -- `Semantics` OUTSIDE, `Tooltip` INSIDE, real control innermost:

```dart
Semantics(                       // screen readers: Tooltip alone sets NO label
  label: 'Select $sender',
  checked: isSelected,
  child: Tooltip(                // UIA projection: Semantics alone does NOT project
    message: 'Select $sender',
    child: Checkbox(...),        // innermost = the hit target
  ),
)
```

Each element was established by a failing test, not by reasoning:
- **Tooltip alone** -> the widget test for the semantics label FAILS (screen readers hear only "checkbox").
- **Semantics alone** -> the name never appears in the Windows UIA tree (automation cannot see it).
- **Tooltip wrapping Semantics** (my first attempt) -> two stacked Button nodes; a click lands on the wrapper and the real control never activates. Observed live on the account picker.
- **`explicitChildNodes: true` on a parent row** -> SUPPRESSES a child checkbox's own node entirely.

**Fixed and verified:**
1. **Account rows** (Select Account screen) -- announce `<email> - <provider> - <auth method>`; error rows name the failing account and reason. 3 widget tests.
2. **No-Rule item rows + checkboxes** -- rows announce `<sender> - <subject>`; each checkbox announces `Select <sender>` so 18 rows are no longer 18 identical "checkbox" controls. Pinned by a widget test asserting against the semantics tree.
3. **Account-picker dialog** -- entries announce `Select account <email>`. This was the gate blocking Settings; a WinWright probe now selects an account **by name** (steps 1-3 pass), which was impossible before.

**A second harness finding -- RETRACTED AS STATED, then replaced by what the evidence actually supports (2026-07-28).** It was recorded mid-sprint that `ww_click`'s default `useInvokePattern: true` "reports success without activating the widget" on Flutter controls. Tested against dev build 0.5.8, that general claim **did not reproduce**: with the default flag `Manage Rules` opened, the `Background` tab switched, and a No-Rule `CheckBox` toggled. It was stated as a rule on insufficient evidence and is withdrawn in that form.

**What replaced it is narrower, sharper, and was proven by making the scripts pass** -- a per-control-type tool rule:

| Control | Tool | Why |
|---|---|---|
| `Button` (any kind) | `ww_invoke` | `ww_click` reported success without activating controls on a cold-launched app |
| TabBar tab (`Text`) | `ww_click` + `useInvokePattern: false` | needs a real mouse press |
| Static `Text` | `ww_click` + `useInvokePattern: false` | `Element does not support InvokePattern. ControlType: Text` |
| `CheckBox` | `ww_click` + `useInvokePattern: false` | exposes TogglePattern, not InvokePattern |
| `RadioButton` | ~~no reliable path~~ **[SUPERSEDED -- see note]** | ~~neither it nor its parent Group selects~~ |

> **[CORRECTION added 2026-07-31, Sprint 52 F131 -- this row was wrong.]** The `RadioButton` row above is
> the one finding in this document that did not survive re-testing, and the way it failed is worth
> keeping. Sprint 51 targeted the parent `Group` (`type=Group[name*='Top-Level Domain']`) because a
> Sprint 41 script comment recommended it, observed nothing happen, and generalised that into "radios
> have no reliable path". A `Group` is a container with no selection behavior, so the click was always
> going to do nothing. The correct rule is `ww_click` + `useInvokePattern: false` **on the `RadioButton`
> itself**, verified live 2026-07-31 (input name flips to `Enter TLD (...)`; confirm dialog reads
> `Type: Top-Level Domain / Source: *.museum`). `ww_invoke` *correctly* fails on a radio because radios
> expose `SelectionItemPattern`, not `InvokePattern`. **The app was never broken; the selector was.**
> Authoritative version of this table now lives in `docs/WINWRIGHT_SELECTORS.md`.

**Three further harness behaviours**, each found by a failing run rather than reasoning:
1. **The semantics tree is built lazily ON QUERY, not on a timer** -- first query returns an opaque `FLUTTERVIEW` pane, second returns the full tree, and a 10-second wait does not help. This alone caused two failed runs while I misdiagnosed it as a settle-timing problem.
2. **`ww_invoke` does not verify visibility** -- it reports success on an off-screen element without pressing it (`Save Rule` below the fold); `ww_click` correctly errors `element_offscreen`.
3. **The search box cannot be cleared by automation** -- `clearFirst` appends, `ww_clear` throws COM, `ctrl+a`/`Delete` does not reach the field.

**And the part of the original finding that always stood**: `{"success": true}` means *dispatched*, not *effective*. Since `ww_assert*` is not replayable, the only in-script proof is a following step that can only resolve if the app actually advanced. Both new scripts are authored as such pairs. (This also confirms the 3 Sprint 41 scripts' 10 silently-skipped assert steps are weaker than they look -- that finding stands.)

**A defect in my own F129 change, found only because a script drove it.** The account-picker entries I added mid-sprint shipped **broken**: `Semantics(button:)` without `excludeSemantics` left the inner `ListTile`'s node in place, so each entry projected as **two stacked Buttons with the same name**. A name-based selector matched the outer wrapper, which has no tap handler -- the click reported success and the dialog never dismissed, silently blocking the entire Settings path. Adding `excludeSemantics: true` then collapsed the node correctly but **removed the tap target**. The working shape is `excludeSemantics: true` **plus `onTap:` on the `Semantics` node itself**. The generalisable lesson: **a tree dump proves a name exists; only an interaction proves the node still works.** Semantics work must be validated by a script that drives the control, not by inspection.

**Settings screen -- earlier claim CORRECTED (2026-07-28).** It was recorded that Settings renders its "Rules Management" rows as unnamed Groups and that Manage Rules was therefore unreachable by name. A live tree dump disproves this: `[Button] "Manage Safe Senders"` and `[Button] "Manage Rules"` are both present and correctly named, matching `_SELECTOR_MAP_2026-06-05.md` and the two committed `test_f56_*` scripts that already click them. The 4 tabs do project as `Text` nodes, but that is documented Flutter TabBar behavior, not a defect. **`settings_screen.dart` required no changes.** The genuine blocker was the account-picker dialog in front of Settings, fixed earlier this sprint -- with that gate open, Manage Rules is reachable end-to-end, verified live.

---

## Observations (not individual findings)

- **Seven of nine findings are duplication artifacts.** Every one arose where the same instruction was written out in more than one place and the copies drifted. This validates the F130 method note: prefer ONE authoritative statement plus pointers over duplicated prose.
- **THREE findings (2, 3, 10) were enforcement firing on correct work** -- including finding 10, in a hook written the day before, which fired on the very message reporting this audit's progress. That is worse than a missing hook: it teaches the operator to route around the guard, which devalues every other hook. Both are now covered by tests.
- **Finding 4 explains findings 2 and 3.** The hooks had no test coverage, so their false positives could only be discovered by tripping them in live use -- which is what happened, three times in one session.
- **Finding 6 was a live defect, not a latent one.** The stale checklist line would have failed against the model that actually ran the last retrospective.
- **Findings 8 and 9 sit on the highest-frequency surface.** `MEMORY.md` is injected into EVERY session and memory `description:` fields drive recall, so a stale line there outranks a corrected doc in practice. Any future terminology or policy rename must sweep memory in the same pass as the docs -- this is now the single most important addition to the F130 method.
