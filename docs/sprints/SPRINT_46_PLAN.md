# Sprint 46 Plan: CI/CD pipeline (F64) + Body rules cleanup (F33) + Scan results bulk actions (F39)

**Sprint**: 46
**Date**: 2026-07-02 (Planning / Phase 1-3)
**Branch**: `feature/20260702_Sprint_46` (created off merged `develop` per Phase 6.6)
**PR**: [#270](https://github.com/kimmeyh/spamfilter-multi/pull/270) (draft) -- stays DRAFT until end of Phase 7.7 (IMP-2)
**Status**: APPROVED (Harold 2026-07-02) -- proceeding to Phase 4 execution

**Scope (Harold-selected, 2026-07-02)**: **F64, F33, F39** -- all three taken off HOLD this refinement and assigned Priority 10/20/30.

**Standing constraint (Harold 2026-07-02)**: hold on major changes elsewhere until the `0.5.4` Windows Store rollout completes (targeted Sat/Sun 2026-07-04/05 on a stable network). This sprint's three items do not touch release/version/MSIX config, so they do not conflict with that hold.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

**Standing authorization note (Harold 2026-07-02)**: normal per-task stopping-criteria discipline is relaxed for THIS sprint specifically -- Harold anticipates needing to answer implementation-scope questions during execution and has pre-authorized asking them. Questions must be grouped (all answerable-together questions asked in one batch) and surfaced as early in the process as possible, not discovered late. This does not relax the other 8 SPRINT_STOPPING_CRITERIA or the Decision-Class Taxonomy protocol -- it specifically permits mid-task scope/approach questions for this sprint's 3 items.

## Plan clarifications resolved at Phase 3.7 (Harold 2026-07-02)

1. **F39 platform scope -- REDUCED to Windows only.** Android/iOS touch-selection is explicitly OUT of scope this sprint (not deferred-if-needed; deferred as decided). Acceptance criteria below updated accordingly.
2. **F64 CI/CD path -- GitHub Actions confirmed** after alternatives review (self-hosted runner, analyze+test-only both considered and rejected -- see Task 1 below for the pros/cons and rationale).
3. **F33 restructured** around classifying existing body-rule patterns into groups FIRST, then determining the update approach per group (rather than one classify+rewrite pass) -- see Task 2 below.

---

## Sprint Objective

Deliver three previously-HOLD backlog items now activated by Harold: a CI/CD pipeline (GitHub Actions parity with the existing Claude Code sprint-workflow gates), a one-time body-rules cleanup script (URL-pattern normalization + duplicate consolidation), and the bulk multi-select/rule-application feature for Scan Results.

---

## Sprint Scope (3 items)

### Task 1 -- F64: CI/CD pipeline with GitHub Actions (Priority 10, FIRST)

**CI/CD path decision (Harold 2026-07-02, after alternatives review)**: **GitHub Actions**, confirmed.

| Alternative | Pros | Cons | Outcome |
|---|---|---|---|
| **GitHub Actions (chosen)** | No infra to maintain; `windows-latest` has VS Build Tools preinstalled (`flutter build windows` works out of the box); tight PR integration (required status checks); OAuth secrets solved via GitHub encrypted repo secrets -> written to `secrets.dev.json` at CI time, never committed; matches existing `gh`-CLI-centric workflow | Windows runner minutes cost more than Linux (mitigated: analyze/test on `ubuntu-latest`, only build step on `windows-latest`); ~2-5 min cold start; no control over runner image updates | **Selected** |
| Self-hosted runner (Harold's dev machine) | Exact existing toolchain, zero environment drift, no per-minute cost | Competes with dev work for machine resources; must be online/awake for CI to fire; larger security exposure running PR-triggered code; becomes the infra being automated away from; single point of failure | Rejected |
| Analyze+test only (skip Windows build in CI) | Fast, cheap, avoids all Windows-runner/secrets complexity | Does not catch Windows-build-breaking regressions until manual Phase 5; undercuts F64's original "build verification" acceptance criterion | Rejected |

- Add a GitHub Actions workflow (`.github/workflows/ci.yml`) triggered on PR to `develop`: `flutter analyze` + `flutter test` on `ubuntu-latest` (fast/cheap), Windows build verification on `windows-latest`.
- OAuth secrets for the Windows build step: use GitHub encrypted repo secrets, written to a CI-local `secrets.dev.json` at workflow-run time (never committed, cleaned up after the run).
- Mirror the same gates already run manually in Phase 5 (analyze clean, full suite green, Windows build succeeds) so CI is a safety net, not a new bar.
- Do not remove or weaken the existing Claude Code Phase-5 manual verification -- CI is additive.
- **Acceptance criteria**:
  - [ ] Workflow file added, triggers on PR to `develop`
  - [ ] Runs `flutter analyze` on `ubuntu-latest` (fails workflow on issues)
  - [ ] Runs `flutter test` on `ubuntu-latest` (fails workflow on any red test)
  - [ ] Runs a Windows build step on `windows-latest` (`flutter build windows` or equivalent) and fails on build error, with OAuth secrets injected from GitHub encrypted repo secrets
  - [ ] Workflow visibly runs on the Sprint 46 PR itself (self-verifying)
- **Model**: **Haiku** -- *why not higher*: a standard Flutter GitHub Actions workflow is a well-documented, mechanical config task with no architectural judgment calls (the judgment call -- which CI path -- was already made above).
- **Step-types**: HOOK/tooling (workflow YAML) + DOCS (README/CLAUDE.md CI note). **Est-Effort: 25-40m** (HOOK median ~6m under-runs historically; padded for GitHub-Actions-specific YAML + Windows runner + secrets-injection nuances, a step-type not yet in the Estimate Table; +5m over original estimate for the secrets-injection step).

### Task 2 -- F33: Body rules cleanup script (Priority 20, SECOND)

**Restructured approach (Harold 2026-07-02)**: break existing body-rule patterns into GROUPS first, then determine the right update/consolidation approach per group -- rather than one single classify-and-rewrite pass over the whole set. Grouping first surfaces natural pattern families (and their edge cases) before any rewrite logic is committed to, and lets ambiguous groups be reviewed independently instead of blocking the whole script.

- **Step A -- Group** (analysis-only, no writes): scan all body-condition rules in `rules.yaml`; bucket into candidate groups by structural shape, e.g.:
  - **G1 -- bare domain / subdomain fragments** (e.g., `adamshetzner.com`, `.adamshetzner.com`) -- candidates for the header Exact-Domain/Entire-Domain-equivalent URL pattern
  - **G2 -- full/partial URLs with path or query** (e.g., `http://spam.com/click?id=`) -- need URL-anchored regex, not bare-domain regex
  - **G3 -- keyword/phrase body content** (non-URL, e.g., "click here to unsubscribe") -- explicitly left unchanged
  - **G4 -- already-correct URL regex** (matches the target convention already) -- no-op, just confirms
  - **G5 -- ambiguous / does not cleanly fit G1-G4** -- flagged for Harold review, NOT auto-rewritten
  - Produce a report of pattern counts per group before any conversion logic runs.
- **Step B -- Per-group conversion**: for G1 and G2 (the groups needing rewrite), generate the corrected URL-matching regex per that group's own shape/rule, and consolidate duplicates within/across groups (e.g., `.domain.com` and `domain.com` -> one rule). G3/G4 pass through unchanged. G5 is reported, not touched.
- Back up the DB before making changes; produce a final report (patterns converted / duplicates removed / unchanged count / flagged-ambiguous count), grouped by G1-G5.
- **Acceptance criteria** (from `ALL_SPRINTS_MASTER_PLAN.md` F33 detail, refined per the group-first approach):
  - [ ] Step A dry-run report: pattern counts per group (G1-G5), presented before any rewrite runs
  - [ ] URL-targeting patterns (G1, G2) converted to proper URL-matching regex, per-group-appropriate shape
  - [ ] Non-URL body rules (G3) left unchanged
  - [ ] Already-correct patterns (G4) confirmed as no-ops
  - [ ] Ambiguous patterns (G5) flagged and left unchanged, not guessed
  - [ ] Duplicate patterns consolidated within/across groups
  - [ ] Backup DB before changes
  - [ ] Final report: patterns converted, duplicates removed, unchanged patterns, ambiguous-flagged count -- by group
  - [ ] All tests pass after cleanup
- **Model**: **Sonnet** -- *why not Haiku*: grouping/classifying body rules by structural shape and generating correct per-group URL-matching regex requires judgment (ReDoS-safety, false-positive risk on live production rule data), not mechanical transformation.
- **Step-types**: DATA (grouping analysis + regex generation) + TEST-UNIT. **Est-Effort: 55-85m** (DATA median ~17m per the Estimate Table's BUG-S37-2 basis, but that was a fixed TLD list; this is a data-driven group-then-convert pass over ~thousands of live rules.yaml body patterns, closer in kind to F91's DB-MIGRATE+regex work at 13-20m -- padded up for the two-step group-then-convert structure and no prior basis at this shape; +10m over the original single-pass estimate for the grouping step).

### Task 3 -- F39: Scan Results multi-select and bulk rule application (Priority 30, THIRD)

**Scope decision (Harold 2026-07-02)**: **reduced to Windows desktop only.** Android/iOS touch-selection (long-press, floating action bar) is explicitly OUT of scope this sprint -- not a "if time permits" stretch, a firm exclusion. `ALL_SPRINTS_MASTER_PLAN.md` F39 acceptance criteria updated to reflect Windows-only for Sprint 46; mobile selection remains a future backlog candidate if/when prioritized.

- Add multi-select to the Scan Results screen (live + history): per-item checkbox/radial, Ctrl+click and Shift+click range-select on Windows desktop, selection scoped to the currently filtered list.
- Add a bulk-action surface (right-click context menu, Windows desktop) offering the 7 actions: Add Safe Sender (Exact Email / Exact Domain / Entire Domain), Add Block Rule (Exact Email / Exact Domain / Entire Domain), Remove Current Rule.
- Reuse the existing single-email quick-add safe-sender/block-rule logic already in `results_display_screen.dart`'s email detail sheet (~L1367+) as the per-item action to fan out over the selection, rather than reimplementing rule-creation logic.
- **Acceptance criteria** (Windows-only, reduced from `ALL_SPRINTS_MASTER_PLAN.md` F39 original multi-platform detail per Harold 2026-07-02):
  - [ ] Multi-select works with Ctrl+click and Shift+click on desktop
  - [ ] Radial/checkbox per item for direct select/unselect
  - [ ] Selection scoped to current filter results only
  - [ ] Right-click context menu shows the 7 bulk action options
  - [ ] Bulk action applies the chosen rule to all selected emails
  - [ ] Works in both live scan results and scan history views
  - [ ] Android/iOS multi-select explicitly deferred (not attempted this sprint)
- **Model**: **Sonnet** -- *why not Haiku*: new selection-state architecture (range-select math, filter-scoping interaction) across a large existing screen (`results_display_screen.dart`) with reuse of existing single-item logic is multi-file/architectural, not mechanical.
- **Step-types**: UI-GESTURE (selection mechanics) + UI-NEW (bulk action menu) + SVC-EDIT (fan-out over existing single-item rule-add path) + TEST-WIDGET. **Est-Effort: 70-115m** (reduced from the original 90-150m estimate now that mobile touch-selection is out of scope -- UI-GESTURE ~7-15m + UI-NEW ~30-40m + SVC-EDIT ~5-18m + TEST-WIDGET ~20-25m per-type medians, summed and padded for desktop-only scope, the largest/most novel item this sprint).

---

## Estimated Effort

**Est-Effort ~150-240m | Est-Wall ~150-240m** (assume serial; F64 has no dependency on F33/F39 and could run in parallel if useful, but each item is a distinct model/agent and independently PR-reviewable). Well under the 400-hour stopping threshold.

## Model Assignments (cheapest-first per Sprint 43 retro IMP-1)

- **Task 1 (F64)**: **Haiku** -- mechanical GitHub Actions config against a well-documented pattern.
- **Task 2 (F33)**: **Sonnet** -- *why not Haiku*: URL-vs-non-URL classification + regex generation over live production rule data requires judgment (ReDoS safety, false-positive risk).
- **Task 3 (F39)**: **Sonnet** -- *why not Haiku*: new multi-select architecture across a large existing screen, range-select math, filter-scoping.
- **Planning / this plan / retro**: **Opus** (per `SPRINT_PLANNING.md` "Activities Requiring Opus").

---

## Decision-Class interrupts

**Resolved at Phase 3.7 (Harold 2026-07-02) -- no longer open**:
- ~~F39 platform scope~~ -- RESOLVED: reduced to Windows-only, firm exclusion (see Task 3).
- ~~F64 CI/CD path~~ -- RESOLVED: GitHub Actions confirmed after alternatives review (see Task 1 comparison table).

**Still open -- surface + wait if triggered** (relaxed stopping rules apply this sprint per Harold's standing authorization above; group related questions, surface as early as possible):
- **F33 G5-ambiguous patterns**: any body-rule pattern that does not cleanly fit groups G1-G4 is flagged and left unchanged, not guessed. If G5 turns out to be a nontrivial fraction of the total (rough threshold: >10% of body rules), surface the G5 examples + proposed handling for Harold's review before finalizing the report, rather than silently leaving a large chunk of the backlog untouched.
- **F33 group-boundary judgment calls**: if a pattern's G1-vs-G2 classification (bare-domain vs. full-URL-with-path) is genuinely ambiguous in a way that affects a whole sub-family of patterns (not a one-off), surface that sub-family's classification call rather than deciding unilaterally -- this is exactly the kind of question Harold asked to see grouped and early.

---

## PR lifecycle (per SPRINT_EXECUTION_WORKFLOW.md, IMP-2)

PR created draft at 3.3.1. On 3.7 approval -> update to approved plan (keep DRAFT). End of dev -> update (keep DRAFT). End of 7.7 (retro improvements done) -> `gh pr ready` (the ONE ready conversion). 7.7.5 -> notify PO/SM. NEVER mark ready earlier.
