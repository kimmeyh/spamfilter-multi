# Sprint 46 Plan: CI/CD pipeline (F64) + Body rules cleanup (F33) + Scan results bulk actions (F39)

**Sprint**: 46
**Date**: 2026-07-02 (Planning / Phase 1-3)
**Branch**: `feature/20260702_Sprint_46` (created off merged `develop` per Phase 6.6)
**PR**: created at Phase 3.3.1 (draft) -- stays DRAFT until end of Phase 7.7 (IMP-2)
**Status**: DRAFT -- pending Harold Phase 3.7 approval

**Scope (Harold-selected, 2026-07-02)**: **F64, F33, F39** -- all three taken off HOLD this refinement and assigned Priority 10/20/30.

**Standing constraint (Harold 2026-07-02)**: hold on major changes elsewhere until the `0.5.4` Windows Store rollout completes (targeted Sat/Sun 2026-07-04/05 on a stable network). This sprint's three items do not touch release/version/MSIX config, so they do not conflict with that hold.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Deliver three previously-HOLD backlog items now activated by Harold: a CI/CD pipeline (GitHub Actions parity with the existing Claude Code sprint-workflow gates), a one-time body-rules cleanup script (URL-pattern normalization + duplicate consolidation), and the bulk multi-select/rule-application feature for Scan Results.

---

## Sprint Scope (3 items)

### Task 1 -- F64: CI/CD pipeline with GitHub Actions (Priority 10, FIRST)
- Add a GitHub Actions workflow (`.github/workflows/ci.yml`) triggered on PR to `develop`: `flutter analyze`, `flutter test`, Windows build verification.
- Mirror the same gates already run manually in Phase 5 (analyze clean, full suite green, Windows build succeeds) so CI is a safety net, not a new bar.
- Do not remove or weaken the existing Claude Code Phase-5 manual verification -- CI is additive.
- **Acceptance criteria**:
  - [ ] Workflow file added, triggers on PR to `develop`
  - [ ] Runs `flutter analyze` (fails workflow on issues)
  - [ ] Runs `flutter test` (fails workflow on any red test)
  - [ ] Runs a Windows build step (`build-windows.ps1` or equivalent `flutter build windows`) and fails on build error
  - [ ] Workflow visibly runs on the Sprint 46 PR itself (self-verifying)
- **Model**: **Haiku** -- *why not higher*: a standard Flutter GitHub Actions workflow is a well-documented, mechanical config task with no architectural judgment calls.
- **Step-types**: HOOK/tooling (workflow YAML) + DOCS (README/CLAUDE.md CI note). **Est-Effort: 20-35m** (HOOK median ~6m under-runs historically; padded for GitHub-Actions-specific YAML + Windows runner nuances, a step-type not yet in the Estimate Table).

### Task 2 -- F33: Body rules cleanup script (Priority 20, SECOND)
- One-time Dart CLI script: identify URL-targeting body rules vs non-URL body rules; convert URL-targeting patterns to proper URL-matching regex (mirroring the header Exact-Domain/Entire-Domain pattern conventions, adapted for URLs-in-body-content); leave non-URL body rules unchanged.
- Consolidate duplicate patterns (e.g., `.domain.com` and `domain.com` treated as the same target).
- Back up the DB before making changes; produce a report (patterns converted / duplicates removed / unchanged count).
- **Acceptance criteria** (from `ALL_SPRINTS_MASTER_PLAN.md` F33 detail):
  - [ ] Script identifies body rules that are URL-targeting vs non-URL patterns
  - [ ] URL-targeting patterns converted to proper URL-matching regex
  - [ ] Non-URL body rules left unchanged
  - [ ] Duplicate patterns consolidated
  - [ ] Backup DB before changes
  - [ ] Report: patterns converted, duplicates removed, unchanged patterns
  - [ ] All tests pass after cleanup
- **Model**: **Sonnet** -- *why not Haiku*: classifying URL-vs-non-URL body rules and generating correct URL-matching regex from arbitrary legacy patterns requires judgment (ReDoS-safety, false-positive risk on live production rule data), not mechanical transformation.
- **Step-types**: DATA (migration/script + regex generation) + TEST-UNIT. **Est-Effort: 45-70m** (DATA median ~17m per the Estimate Table's BUG-S37-2 basis, but that was a fixed TLD list; this is a data-driven classify+rewrite over ~thousands of live rules.yaml body patterns, closer in kind to F91's DB-MIGRATE+regex work at 13-20m -- padded up for the classification-judgment component and no prior basis at this shape).

### Task 3 -- F39: Scan Results multi-select and bulk rule application (Priority 30, THIRD)
- Add multi-select to the Scan Results screen (live + history): per-item checkbox/radial, Ctrl+click and Shift+click range-select on Windows desktop, selection scoped to the currently filtered list.
- Add a bulk-action surface (right-click context menu on desktop) offering the 7 actions: Add Safe Sender (Exact Email / Exact Domain / Entire Domain), Add Block Rule (Exact Email / Exact Domain / Entire Domain), Remove Current Rule.
- Windows-desktop-first per the "hold on major changes" constraint and platform priority; touch-friendly mobile selection (long-press, floating action bar) can follow the same selection-state plumbing but is not required to land in the same session if it meaningfully expands scope -- flag if so rather than silently deferring.
- Reuse the existing single-email quick-add safe-sender/block-rule logic already in `results_display_screen.dart`'s email detail sheet (~L1367+) as the per-item action to fan out over the selection, rather than reimplementing rule-creation logic.
- **Acceptance criteria** (from `ALL_SPRINTS_MASTER_PLAN.md` F39 detail):
  - [ ] UI investigation: confirm selection/action pattern for Windows desktop (primary this sprint)
  - [ ] Multi-select works with Ctrl+click and Shift+click on desktop
  - [ ] Radial/checkbox per item for direct select/unselect
  - [ ] Selection scoped to current filter results only
  - [ ] Right-click context menu shows the 7 bulk action options
  - [ ] Bulk action applies the chosen rule to all selected emails
  - [ ] Works in both live scan results and scan history views
- **Model**: **Sonnet** -- *why not Haiku*: new selection-state architecture (range-select math, filter-scoping interaction) across a large existing screen (`results_display_screen.dart`) with reuse of existing single-item logic is multi-file/architectural, not mechanical.
- **Step-types**: UI-GESTURE (selection mechanics) + UI-NEW (bulk action menu) + SVC-EDIT (fan-out over existing single-item rule-add path) + TEST-WIDGET. **Est-Effort: 90-150m** (UI-GESTURE ~7-15m + UI-NEW ~30-40m + SVC-EDIT ~5-18m + TEST-WIDGET ~20-25m per-type medians, summed and padded -- this is the largest/most novel item this sprint, matches its ~12-16h legacy hour-estimate directionally once converted through the ~6x hour-to-minute recalibration from Sprint 41).

---

## Estimated Effort

**Est-Effort ~155-255m | Est-Wall ~155-255m** (assume serial; F64 has no dependency on F33/F39 and could run in parallel if useful, but each item is a distinct model/agent and independently PR-reviewable). Well under the 400-hour stopping threshold.

## Model Assignments (cheapest-first per Sprint 43 retro IMP-1)

- **Task 1 (F64)**: **Haiku** -- mechanical GitHub Actions config against a well-documented pattern.
- **Task 2 (F33)**: **Sonnet** -- *why not Haiku*: URL-vs-non-URL classification + regex generation over live production rule data requires judgment (ReDoS safety, false-positive risk).
- **Task 3 (F39)**: **Sonnet** -- *why not Haiku*: new multi-select architecture across a large existing screen, range-select math, filter-scoping.
- **Planning / this plan / retro**: **Opus** (per `SPRINT_PLANNING.md` "Activities Requiring Opus").

---

## Decision-Class interrupts (NOT pre-authorized -- surface + wait)

- **F39 platform scope** (Class-3, sprint-execution): if Windows-desktop-only multi-select (deferring Android/iOS touch selection) is not sufficient to satisfy the acceptance criteria as written ("Platform-appropriate UI for Windows, Android, and iOS"), that is a scope reduction requiring Harold's sign-off before treating the item as done -- surface at Phase 5.3, not silently.
- **F64 CI workflow scope** (Class-1/2, low risk): if `flutter build windows` in a GitHub-hosted runner proves environment-incompatible (e.g., missing Windows Desktop toolchain on `windows-latest`, secrets-injection for OAuth build args), that is a design decision (skip Windows build step in CI vs. self-hosted runner vs. analyze+test-only CI) -- surface rather than silently descoping.
- **F33 regex rewrite risk**: this script touches live production `rules.yaml` body patterns. Any pattern where URL-vs-non-URL classification is ambiguous must be left unchanged (per acceptance criteria) rather than guessed -- if a nontrivial fraction of patterns are ambiguous, surface the classification heuristic for Harold's review before running the rewrite for real (dry-run report first, apply second).

---

## PR lifecycle (per SPRINT_EXECUTION_WORKFLOW.md, IMP-2)

PR created draft at 3.3.1. On 3.7 approval -> update to approved plan (keep DRAFT). End of dev -> update (keep DRAFT). End of 7.7 (retro improvements done) -> `gh pr ready` (the ONE ready conversion). 7.7.5 -> notify PO/SM. NEVER mark ready earlier.
