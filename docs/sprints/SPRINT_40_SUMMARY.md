# Sprint 40 Summary

> Created retroactively during the Sprint 57 documentation audit (2026-08-14). Sourced from PR #261 (body + 17 commits), `docs/sprints/SPRINT_40_PLAN.md`, and `CHANGELOG.md`. See `docs/sprints/SPRINT_40_RETROSPECTIVE.md` for the accompanying retroactive retrospective.

**Sprint**: 40
**Branch**: `feature/20260525_Sprint_40`
**PR**: #261 (`feature/20260525_Sprint_40` -> `develop`)
**Dates**: 2026-05-25/26 (Backlog Refinement / Phase 1-3) through merge 2026-06-13T13:56:16Z
**Retrospective**: `docs/sprints/SPRINT_40_RETROSPECTIVE.md` (retroactive reconstruction; no live Phase 7 was run at the time)
**Status**: Complete (merged)

## Outcome

| Metric | Value |
|---|---|
| Planned scope | 7 items (F75, F25, F35, F37, F78, F79, S38-CI-7) |
| Delivered | 6 of 7 (F75, F78, F25, F35, F37, F79) + 1 in-sprint find (BUG-S40-1) |
| Cancelled (Harold-approved) | S38-CI-7 eval-run (2026-06-04 -- Opus 4.6 vs 4.7 head-to-head moot once Opus 4.8 became active model; prep artifacts only) |
| Deferred | F56 create+delete WinWright scripts + `manual_scan_flow` -> follow-up F97 (Sprint 41) |
| Tests at merge | `flutter test` full suite green (1642 passing at last recorded run in PR body); `flutter analyze` 0 issues |
| WinWright | Full sweep 7/7 PASS, zero DB drift (after the 2026-06-09 re-port fix) |

## Scope

| Item | Description | Result |
|---|---|---|
| F75 | Help walkthrough: end-to-end first-use guide (ADR-0038 Markdown asset) | Shipped |
| F78 | Widget tests for `ManualRuleCreateScreen` rendering | Shipped |
| F25 | Rule testing UI: demo-data prepopulate, plaintext->regex toggle, open-rule-in-test-tool; extracted `ManualRulePatternGenerator` | Shipped |
| F35 | Rule editing UI (`RuleEditScreen`): dual-mode guided/direct-regex, live preview, UNIQUE-constraint rethrow | Shipped |
| F37 | Folder selectors: two-level collapsible tree, provider-default-first pickers, per-provider path-separator detection | Shipped |
| F79 | WinWright unattended sweep harness + DB-drift guard | Shipped (required a 2026-06-09 re-port after the original commit did not satisfy its own "7 scripts unattended" criterion) |
| S38-CI-7 | Opus 4.6 vs 4.7 head-to-head model evaluation | CANCELLED 2026-06-04 (Harold) -- prep artifacts only under `docs/sprints/s38-ci-7-eval-briefs/`; no comparison run |
| BUG-S40-1 | AOL silent move/delete failure (found in manual testing) | Fixed same sprint |

## What Shipped

### Features

- **F75** -- Help walkthrough authored as a Markdown asset (ADR-0038 pattern), surfaced from the Help screen, covering install through ongoing daily background scanning and a safe-sender recommendation hierarchy (Entire Domain / Exact Email / TLD).
- **F25** -- Rule Testing UI: match-against list now pre-populates from Demo Scan data; plaintext-to-regex conversion on Test reuses the `ManualRuleCreateScreen` pattern generator (extracted into the new shared `ManualRulePatternGenerator`); Manage Rules can open an existing rule directly in the test tool.
- **F35** -- New `RuleEditScreen`: dual-mode guided/direct-regex editing over the existing create-flow building blocks, live pattern preview, and a UNIQUE-constraint rethrow for duplicate-pattern edits.
- **F37** -- Default Folders selector gained a two-level collapsible tree; Safe Sender / Deleted Rule selectors show provider-default-first single-select flat lists; folder path separator is now detected per provider instead of hardcoded `/`.
- **F78** -- `ManualRuleCreateScreen` widget-test coverage added for radio selection, input-field validation feedback, pattern preview rendering, and the confirmation dialog.

### Test Tooling (F79)

WinWright unattended sweep harness plus a pre/post dev-DB snapshot drift guard. The original F79 commit did not actually run all 7 scripts unattended (Sprint 34-era scripts used a legacy schema the installed WinWright `run` silently no-ops on). A 2026-06-09 follow-up commit re-ported all scripts to the current `testCases` schema, fixed an app-lifecycle assumption (`winwright run` closes the app at end-of-run, so the runner now relaunches fresh before each script), and re-verified selectors. Final state: 4 ported scripts (navigation, settings_tabs, scan_history, text_selection) + 3 new (f25, f35, f37), all read-only, 7/7 passing unattended with zero DB drift.

### Bug Fix

- **BUG-S40-1** -- AOL/Yahoo delete and move actions were silently leaving messages behind (RFC 9738 MESSAGELIMIT extension: `UID MOVE` over the server's per-command limit moved only a subset but returned tagged `OK`, and `enough_mail` 2.1.7 does not parse the `[MESSAGELIMIT]` response code). Observed on a real account: scan 1 reported 482 deleted but 271 remained and were re-"deleted" on scan 2. Fixed in `GenericIMAPAdapter.moveToFolderBatch` with chunked (50-UID) moves, inter-chunk delay, post-chunk verification search, up to 6 sweep passes for survivors, and no-progress abort. New pure helpers `chunkUids` (6 unit tests) and `partitionByMoveSurvival` (5 unit tests). Root-cause research recorded in `docs/research/BUG-S40-1-aol-uid-move.md`.

### Scope Changes (Harold-approved)

- **S38-CI-7 eval-run cancelled** (2026-06-04) -- active model moved to Opus 4.8, making a 4.6-vs-4.7 comparison moot. Prep artifacts (task briefs, rubric, comparison-matrix template) retained under `docs/sprints/s38-ci-7-eval-briefs/` as a record of the intended method.
- **F56 create+delete scripts + `manual_scan_flow` deferred to F97** -- the F35 rule-creation rework changed Add-Block-Rule input validation, invalidating the old TLD test inputs; `manual_scan_flow` performs a real network scan unsuitable for an unattended sweep. F97 was picked up in Sprint 41's plan.

### Post-merge

- PR #261 received a GitHub Copilot review; all 3 inline findings plus 1 suppressed low-confidence finding were addressed in a follow-up commit (`5e3cd29`): a docstring correction on `_moveFolderChunkedWithRetry`, a PowerShell switch-parameter bug fix in `run-winwright-tests.ps1` (`-SnapshotDb`/`-FailOnDrift` explicit-value handling), a selector-map parameter-name correction, and a stale Help-screen footer date update.

## Effort

Not recorded. `docs/sprints/SPRINT_40_PLAN.md` carries minute-based estimates (~4.5-7.5h total across the original 7-item scope, per `docs/CODING_VELOCITY.md` methodology), but no Sprint 40-specific actuals log entry was located during this reconstruction to compare against.

## Carry-Ins to Sprint 41

F97 (WinWright F56 create+delete re-port), F76 (visual regression, moved off HOLD at Sprint 39 refinement). Confirmed picked up in `docs/sprints/SPRINT_41_PLAN.md`.
