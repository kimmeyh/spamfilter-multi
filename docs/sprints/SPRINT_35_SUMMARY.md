# Sprint 35 Summary

> **NOTE (Sprint 57 doc-audit, 2026-08-14)**: This summary was not found in the repository during a repo-wide sprint-documentation audit and has been reconstructed retroactively from PR #238's body/commits and the existing `SPRINT_35_PLAN.md` / `SPRINT_35_RETROSPECTIVE.md`. Figures not recoverable from those sources are not included rather than invented.

**Branch**: `feature/20260419_Sprint_35`
**PR**: [#238](https://github.com/kimmeyh/spamfilter-multi/pull/238)
**Issues**: #237 (sprint), #239 (BUG-S35-1), #240 (F79), #241 (F80)
**Dates**: 2026-04-19 -> 2026-04-20
**Retrospective**: `docs/sprints/SPRINT_35_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1362 -> **1363** passing / 0 failing |
| Analyzer | Clean |
| Windows build | Green (fresh dev build validated via WinWright execution) |
| WinWright E2E scripts | 7 of 7 PASS |
| Manual Validation | Complete (interactive MCP-driven execution, 2026-04-19) |
| Carry-forward | F81 (store release process doc) made mandatory Sprint 36 Task |

## Scope

Small intentional recovery sprint after the 14-task Sprint 34. Two tasks, both completed.

| Task | Item | Result |
|---|---|---|
| 1 | BUG-S34-1 | Fixed stale `expect(resetResult.rules, 5)` assertion in `default_rule_set_service_test.dart` (escaped F73 review in Sprint 34, broke develop after PR #236 merge). Changed to `greaterThan(100)` to match sibling assertions post-monolithic-split. Restored green baseline before F69 work. |
| 2 | F69 | Executed all 7 WinWright E2E scripts shipped in Sprint 34 against a fresh Windows dev build. All 7 reached PASS. Closed the Sprint 34 acceptance gap ("Tests pass on Windows desktop dev build" was never checked in Sprint 34). |

## What shipped

**BUG-S34-1 fix.** One-line test assertion correction plus a comment documenting the post-F73 expected rule count for future reviewers.

**F69 WinWright E2E execution.** Sprint 34 had shipped 7 JSON test scripts, a README, and a `run-winwright-tests.ps1` runner, but never actually run them against a live build. Sprint 35 discovered the Sprint 34 JSON `run` schema is not supported by the WinWright CLI (Sprint Stopping Criterion 7 -- fundamental design failure), and pivoted under Harold's approval (Option 1) to interactive MCP-driven execution instead. All 7 scripts (navigation, manual scan flow, settings tabs, text selection, F56 create-block-rule, F56 create-safe-sender, scan history) reached PASS against a fresh v0.5.1 Windows dev build.

**F56 script lifecycle hardening (in-scope per SS-4a).** Running the F56 create-rule scripts left two test artifacts in the dev DB that could not be unambiguously deleted via the UI (a `.xyz` block rule collided visually with a bundled `._.xyz` rule from the Sprint 34 F73 split). Both scripts were updated in-sprint to a full create -> verify-present -> delete -> verify-absent lifecycle, and test data was retuned to non-colliding values (`.museum`, `winwright-e2e-test.invalid`) so future runs self-clean.

**WinWright run policy formalized.** Added conditional-run and state-restoration rules to `docs/TESTING_STRATEGY.md` and `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 5.3, per Harold's in-sprint directive.

**Store submission (post-merge, 2026-04-20).** After PR #238 merged to develop and develop merged to main, the prod worktree was rebuilt to MSIX (`v0.5.2.0`) and submitted to Microsoft Store Partner Center. The rebuild surfaced 3 additional gaps -- missing `secrets.prod.json`, a `.gitignore` pattern (`*.manifest`) that caught a required build file, and `msix:create` silently stripping dart-defines without an explicit `build_windows_args` entry (would have shipped credential-less OAuth, a silent-failure defect). All three were scoped into F81 for Sprint 36.

**Process improvements applied (4.6 -> 4.7 doc updates, retro Step 5/7).** Category 9 (Process Issues) identified a wall-clock regression versus the Opus 4.6 era; four of five proposed doc changes were applied same-sprint: Phase Auto-Advance Rule (CLAUDE.md), Standing Approval Inventory (SPRINT_EXECUTION_WORKFLOW.md Phase 3.7), Model-Version Pitfalls appendix (CLAUDE.md), and Sprint Resume Pattern memory. The fifth (1-page Phase Cheat Sheet) was backlogged as F80.

## Found during execution

- **BUG-S35-1** (Issue #239): Manual rule creation UI accepts duplicate TLD entries -- discovered incidentally during F69 execution, logged rather than fixed in-scope (>2h estimated).
- **F79** (Issue #240, HOLD): Full WinWright suite sweep as an on-demand capability, distinct from per-sprint conditional runs.

## Retrospective improvements (4 of 5 applied; 1 backlogged)

| ID | Improvement | Status |
|---|---|---|
| P1 | Phase Auto-Advance Rule in CLAUDE.md | Applied |
| P2 | Standing Approval Inventory in SPRINT_EXECUTION_WORKFLOW.md Phase 3.7 | Applied |
| P3 | 1-page Phase Cheat Sheet | Backlogged as F80 (Issue #241) |
| P4 | Model-Version Pitfalls appendix in CLAUDE.md | Applied |
| P5 | Sprint Resume Pattern memory | Applied |
| -- | Phase 5.1.1 step 2a test-assertion sibling sweep (Category 2 closure) | Applied |

## Lessons worth carrying

1. **A recorded acceptance criterion that is never checked is a real gap, not a formality.** Sprint 34 shipped the WinWright scripts but never ran them against a live build; Sprint 35 existed specifically to close that gap.
2. **Probe tooling assumptions during setup, not mid-execution.** The WinWright JSON `run` schema incompatibility was discovered while running the suite, not while planning it -- costing a stopping-criterion pivot mid-task.
3. **A structural data change needs a sibling-assertion sweep.** BUG-S34-1 was a single missed assertion among several siblings that had already been updated for the same change; the gap is now closed by a mechanical workflow step (Phase 5.1.1 step 2a).
