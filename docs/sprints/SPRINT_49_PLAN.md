# Sprint 49 Plan: F119-c native [DEV]-title fix + 0.5.7 corrected resubmit

**Sprint**: 49
**Date**: 2026-07-21
**Branch**: `feature/20260720_Sprint_49` (created FROM `feature/20260720_Sprint_48` per Harold's carry-forward directive)
**PR**: draft -> develop (created after F119-c implementation)
**Status**: Task 1 (F119-c) Harold-directed and implemented ("This fix will be included in this sprint", 2026-07-21, escalated to Fable 5 for the deep dive). Remaining Sprint 49 scope selection from the Phase 1 refinement candidates is still OPEN with Harold.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Diagnose and permanently fix the recurring `[DEV]` window title in Store builds (three defective releases: 0.5.4, 0.5.5, 0.5.6), so that the single `APP_ENV` dart-define drives every compiled surface and the release process can PROVE both surfaces before submission. Ship the corrected build as `0.5.7`.

---

## Sprint Scope

### Task 1 -- F119-c: Store MSIX native window title compiles as [DEV] (Priority: critical)

**Value**: This prevents a fourth consecutive defective Store release / This ends the class of "one compiled surface silently disagrees with the other" build-integrity bugs.

**Requirements**:
- R-1: Determine why the Store-installed 0.5.6 STILL shows `[DEV]` in the title bar despite the Dart side being proven prod (`--print-env`, clean About text, prod data dir).
- R-2: Fix the root cause structurally (no reliance on human memory / undocumented environment variables).
- R-3: Extend the compiled-truth probe to cover EVERY independently-compiled surface.
- R-4: Correct the F119-b historical record where its causal claim is now known wrong.
- R-5: Bump `0.5.6 -> 0.5.7` for the resubmit.

**Affected components / files**:
- `windows/runner/CMakeLists.txt` -- derive `SPAMFILTER_APP_ENV` from the `APP_ENV` dart-define in `ephemeral/generated_config.cmake` (deterministic base64 token match; env-var fallback).
- `windows/runner/main.cpp` -- hoisted macro guard + `--native-app-env=` passthrough to Dart.
- `lib/main.dart` -- `--print-env` prints `NATIVE_APP_ENV`.
- `test/policy/msix_config_test.dart` -- F119-c policy pins (CMake derivation, passthrough, probe line).
- `docs/STORE_RELEASE_PROCESS.md` -- three-defect root-cause list; Step 4.0 requires `NATIVE_APP_ENV=prod`.
- Version-literal files for the 0.5.7 bump (11 sites, gate-backstopped).
- Record corrections: `ALL_SPRINTS_MASTER_PLAN.md` Store status, `SPRINT_48_RETROSPECTIVE.md` addendum, memory.

**Dependencies / blockers**: None. The Partner Center upload of 0.5.7 is a Harold action after verification.

**Non-functional requirements**:
- Platform: Windows-native (CMake/C++) change; no behavior change on other platforms. The `--native-app-env` arg must be tolerated by all arg parsers (verified: `BackgroundModeService` uses contains/prefix matching).
- Security: no secrets touched.

**Acceptance criteria**:
- AC-1: Root cause proven from source (CMakeLists env-var-only sourcing + msix path never setting it), not guessed.
- AC-2 (behavioral): Given a build with `--dart-define=APP_ENV=prod` and NO `SPAMFILTER_APP_ENV` env var (the exact msix:create condition), When `MyEmailSpamFilter.exe --print-env` runs, Then it prints BOTH `APP_ENV=prod` AND `NATIVE_APP_ENV=prod`.
- AC-3: `build-windows.ps1` local dev/prod paths keep working unchanged (env var kept as fallback; both mechanisms agree).
- AC-4: Policy pins fail the suite if the CMake derivation, the `--native-app-env` passthrough, or the probe line is removed.
- AC-5: Version gate green at 0.5.7; full suite green; analyze clean.
- AC-6: After the Store 0.5.7 install, the title bar reads `MyEmailSpamFilter` with NO `[DEV]` (final Harold verification).

**Tests to write**:
- T-1 (AC-4) -- TEST-POLICY in `msix_config_test.dart`: pins for the CMake token, the passthrough, and the probe output line.
- T-2 (AC-2) -- release-process check (not a unit test): the no-env-var A-test build + `--print-env` probe, now a mandatory Step 4.0 check.

**Definition of Done**: default Task-Level DoD PLUS: the A-test (AC-2) executed and green on a real build BEFORE the PR is offered for merge; AC-6 pending the Store install.

**Model**: **Fable 5** (Harold-directed escalation) -- *why not cheaper*: third recurrence of a "proven-fixed" release defect; required overturning the prior sprint's own accepted diagnosis (F119-b) against its recorded evidence, and tracing a cross-layer chain (flutter tool -> generated CMake config -> CMake configure -> C++ preprocessor -> Win32 title) that two earlier Opus passes missed.

**Step-types**: NATIVE-WIN (CMake/C++) + SVC-EDIT + TEST-POLICY + DOCS + version-bump.

**Est-Effort**: 60-120m.

**Risk & rollback**: Risk -- a fourth defective release. Mitigation -- AC-2 A-test proves the exact failing condition is fixed; Step 4.0 now checks both surfaces; policy pins prevent silent regression. Rollback -- the CMake change is additive (env var path intact); revert restores Sprint 37 behavior.

**Decision-class interrupts**: Class-2 (modifies the Sprint 37 F52 env-var-only design) -- surfaced to Harold with options 1/2/3; Harold selected option 1 (structural fix) on 2026-07-21. Store upload remains Harold-exclusive.

---

## Remaining Sprint 49 scope (OPEN -- Harold selection pending)

From the Phase 1 refinement candidates (presented 2026-07-20): BUG-DECODE + F33-PROD, F-VERSION-DERIVE, F-PRECHECK + F-COPILOT-INSTR, F-WINSTORE-ASSETS, CI_* secrets. Harold interrupted the selection question; re-present at the next natural break (after the 0.5.7 resubmit is in motion).

## Model Assignments

- **Fable 5**: F119-c diagnosis + fix (Harold-directed escalation). Planner/docs: same session.
