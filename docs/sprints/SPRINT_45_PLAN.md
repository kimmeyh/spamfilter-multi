# Sprint 45 Plan: Windows App Store upload readiness verification (F111)

**Sprint**: 45
**Date**: 2026-07-01 (Planning / Phase 1-3)
**Branch**: `feature/20260701_Sprint_45` (created off merged `develop` per Phase 6.6)
**PR**: created at Phase 3.3.1 (draft) -- stays DRAFT until end of Phase 7.7 (IMP-2)
**Status**: DRAFT -- pending Harold Phase 3.7 approval

**Scope (Harold-selected, 2026-07-01)**: **F111 only** -- Windows App Store upload readiness verification.

**Type**: Release-readiness verification + checklist doc (NO feature code planned; any fix surfaced at a decision point).
**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Confirm the codebase is release-ready and everything is in order to build + upload a new version to the Microsoft Store -- BEFORE any Store build/upload -- and produce a GO / NO-GO readiness checklist. Surface (not silently fix) any blocker.

---

## [!] Planning-time finding to investigate FIRST (real, not hypothetical)

A `git rev-list` at planning time shows an unexpected parity state that F111 exists precisely to catch:
- `origin/main..origin/develop` = **0 commits** (develop has nothing main lacks)
- `origin/develop..origin/main` = **15 commits** (main has 15 commits develop lacks)

So **main appears to be AHEAD of / diverged from develop**, which is the opposite of the normal `develop -> main` release flow. This is a genuine drift signal. **Task 1 investigates and reports exactly what these 15 commits are** (likely prior release commits / release-notes / a hotfix that never flowed back to develop), and whether develop is truly a clean base for the next release. This is a **Chief-Developer (Harold) decision to resolve** -- F111 REPORTS it; it does not merge to main or rewrite history.

---

## Sprint Scope (1 item -- F111 -- broken into verification tasks)

### Task 1 -- develop / main parity reconciliation (FIRST)
- Diff `origin/main` vs `origin/develop`; enumerate the 15 `main`-only commits (`git log origin/develop..origin/main --oneline`) and any `develop`-only commits; classify each (release-notes / version bump / hotfix / stranded work).
- Determine whether develop is a clean, complete base for the next Store release, or whether main contains changes that must flow back to develop first.
- **Output**: a parity report in the F111 findings doc + an explicit note of any commit that needs Harold's decision (merge main->develop? cherry-pick? accept?).
- **Model**: **Sonnet** -- *why not Haiku*: interpreting divergent git history + judging release-base cleanliness is analysis, not a mechanical diff.
- **Step-types**: git analysis + findings doc. **Est-Effort: 30-45m.**

### Task 2 -- version compatibility check (SECOND)
- Run the Sprint 44 version-consistency gate (`flutter test test/policy/version_consistency_test.dart` + `scripts/check-version-consistency.ps1`) -- confirm all app-version literals match `pubspec.yaml` (`0.5.4`).
- Confirm `pubspec.yaml` `version` + `msix_config.msix_version` are the intended Store version and are **greater than the currently-published Store version** (Harold confirms the published version; Partner Center rejects a re-used version -- see STORE_RELEASE_PROCESS Troubleshooting "Version already submitted").
- **Note**: dev worktree is `0.5.4`; a Store release ships from the PROD worktree at the dev-version-minus-1 per ADR-0035 -- verify the intended release version with Harold.
- **Model**: **Haiku** -- running the gate + reading two version fields is mechanical.
- **Step-types**: gate run + version read. **Est-Effort: 15-25m.**

### Task 3 -- MSIX build-path integrity (THIRD)
- Confirm the SUPPORTED build command is `flutter pub run msix:create` (honors `msix_config.build_windows_args` for `--dart-define-from-file` OAuth credential injection), NOT the deprecated `scripts/build-msix.ps1` (empty-credentials trap).
- Verify `msix_config` in `pubspec.yaml` is complete (identity_name, publisher, msix_version, capabilities, `store: true`, `install_certificate: false`).
- Confirm secrets availability for a prod build (`secrets.prod.json` -- present or the recreation steps in STORE_RELEASE_PROCESS Step 2 are documented/ready). Do NOT commit secrets.
- **Model**: **Haiku** -- config verification against the documented process.
- **Step-types**: config audit. **Est-Effort: 20-30m.**

### Task 4 -- Store-submission preconditions + full verification (FOURTH)
- Walk `docs/STORE_RELEASE_PROCESS.md` Pre-Release Checklist + Steps 1-4 and confirm each precondition (privacy policy current, publisher identity, capabilities, product identity appendix).
- Full green: `flutter analyze` clean, full `flutter test` green, **Windows PROD build** succeeds (`build-windows.ps1 -Environment prod` or the msix path), redaction + version gates green.
- **Model**: **Sonnet** -- *why not Haiku*: synthesizing the checklist + judging overall GO/NO-GO across all evidence is a review activity.
- **Step-types**: checklist walk + build/test verification + synthesis. **Est-Effort: 45-75m.**

### Deliverable
- **`docs/sprints/SPRINT_45_F111_STORE_READINESS.md`** -- the readiness findings doc: parity report, version verification, MSIX-path confirmation, Store-precondition checklist, verification results, and an explicit **GO / NO-GO** recommendation with any blocker called out for Harold.

---

## Estimated Effort

**Est-Effort ~110-175m | Est-Wall ~110-175m.** No feature code planned. Well under the 400-HOUR stopping threshold.

## Model Assignments (cheapest-first per Sprint 43 retro IMP-1)

- **Task 2, Task 3**: **Haiku** -- gate runs + version/config reads against the documented process.
- **Task 1, Task 4**: **Sonnet** -- *why not Haiku*: git-history interpretation (Task 1) and GO/NO-GO synthesis across all evidence (Task 4) are analysis/review, not mechanical.
- **Planning / this plan / retro**: **Opus** (per SPRINT_PLANNING.md "Activities Requiring Opus").

---

## Decision-Class interrupts (NOT pre-authorized -- surface + wait)

- **develop/main parity resolution** (Class-2/3 + Chief-Developer merge authority): if Task 1 finds main-only commits that must flow back to develop, that is Harold's call -- F111 reports; it does not merge to main or alter history.
- **Intended Store release version** (Class-3): confirm with Harold which version this release ships (dev 0.5.4 vs prod-worktree version) before asserting "version compatible".
- **GO/NO-GO** is a recommendation FOR Harold, not an autonomous release trigger. F111 does NOT build/upload to the Store -- it verifies readiness.

---

## PR lifecycle (per SPRINT_EXECUTION_WORKFLOW.md, IMP-2)

PR created draft at 3.3.1. On 3.7 approval -> update to approved plan (keep DRAFT). End of dev -> update (keep DRAFT). End of 7.7 (retro improvements done) -> `gh pr ready` (the ONE ready conversion). 7.7.5 -> notify PO/SM. NEVER mark ready earlier.
