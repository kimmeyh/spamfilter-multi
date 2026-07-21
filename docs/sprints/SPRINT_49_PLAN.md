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

### Task 2 -- F-VERSION-DERIVE: derive the app version, stop hardcoding it (Priority: medium; Harold-selected 2026-07-21)

**Value**: This makes a version bump a ONE-file change (pubspec.yaml) / This prevents the F105/F118-class drift where a missed literal ships a stale version string.

**Requirements**:
- R-1: The Dart-side version-bearing strings (scan-log filenames in `main.dart`, `background_scan_windows_worker.dart`, `live_scan_logger.dart`; the About `Version X.Y.Z` string in `settings_screen.dart`) derive from a single runtime source instead of hardcoded literals.
- R-2: The native `main.cpp` log-filename literals derive from the app version CMake already knows (`FLUTTER_VERSION` compile definition, the F119-c plumbing pattern) instead of hardcoded literals.
- R-3: The derived version must be correct in the HEADLESS background-scan path and in the MSIX sandbox (validate `package_info_plus` there before removing literals; the engine runs fully in `--background-scan` mode, but verify).
- R-4: `pubspec.yaml` remains the single source of truth; the version-consistency gate continues to guard whatever literals legitimately remain (pubspec, doc-comments dropped or genericized).

**Affected components / files**: `lib/main.dart`, `lib/core/services/background_scan_windows_worker.dart`, `lib/core/services/live_scan_logger.dart`, `lib/ui/screens/settings_screen.dart`, `windows/runner/main.cpp` (FLUTTER_VERSION macro, strip the `+build` suffix), `lib/core/storage/settings_store.dart` doc-comments (genericize to `live_scan_v<version>.log`), version gate + its PS1 mirror (adjust expectations if the literal set shrinks).

**Dependencies / blockers**: None (F119-c already landed the CMake plumbing pattern).

**Non-functional requirements**:
- Platform: Windows headless (`--background-scan`) and MSIX-sandbox contexts must resolve the same version as the foreground app.
- Support: log filenames must remain deterministic per installed version (they are support/diagnostic artifacts).

**Acceptance criteria**:
- AC-1: `grep -rE "_v[0-9]+\.[0-9]+\.[0-9]+\.log|Version [0-9]+\.[0-9]+\.[0-9]+" lib/ windows/runner/` finds ZERO hardcoded app-version literals (comments genericized).
- AC-2 (behavioral): Given a version bump edited ONLY in `pubspec.yaml`, When the app builds and runs (foreground AND `--background-scan`), Then log filenames and the About string all show the new version.
- AC-3: The version-consistency gate + PS1 mirror stay green and still fail on any reintroduced literal.
- AC-4: Full suite green; analyze clean.

**Tests to write**:
- T-1 (AC-1) -- TEST-POLICY: extend/adjust the version gate so a reintroduced hardcoded literal in the converted files fails.
- T-2 (AC-2) -- TEST-UNIT: log-filename builders produce `..._v<pubspec-version>.log` (derive expected from pubspec, the F118 pattern).

**Definition of Done**: default Task-Level DoD + a manual headless `--background-scan` smoke run confirming the versioned log filename.

**Model**: **Sonnet-tier** -- *why not Haiku*: touches the native `main.cpp` + headless/MSIX contexts where a wrong assumption ships a support-breaking log rename. (Executed by the active session model.)

**Step-types**: SVC-EDIT x4 + NATIVE-WIN + TEST-UNIT/POLICY. **Est-Effort: 90-180m.**

**Risk & rollback**: Risk -- version resolves wrong/absent in headless or MSIX context -> misnamed logs. Mitigation -- R-3 validation before removing literals; keep a deterministic fallback. Rollback -- revert to literals (gate still guards them).

### Task 3 -- F-PRECHECK: pre-PR self-review checklist for recurring Copilot classes (Priority: medium; Harold-selected 2026-07-21)

**Value**: This enables catching the recurring review-finding classes ourselves before the PR / This prevents multi-round Copilot review churn (23 comments over 6 rounds in Sprint 46; 4 real findings in Sprint 47).

**Requirements**:
- R-1: A concise, mandatory pre-PR checklist covering the six recurring classes: (a) mirror/parallel-site sync (Dart gate + PS1 mirror, manual + background paths, two call sites of one helper), (b) helper wired into the PRODUCTION path not just display, (c) doc-comment-vs-code drift, (d) fragile input parsing, (e) API scope matches caller intent, (f) silent failure (catch that empties/deletes instead of reporting).
- R-2: The checklist lives in the process docs where the pre-PR step already runs (SPRINT_EXECUTION_WORKFLOW.md Phase 5.1 area) and is referenced from SPRINT_CHECKLIST.md.
- R-3: Each class carries a one-line concrete detection action (e.g. "grep for the sibling site"), not abstract advice.

**Affected components / files**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (Phase 5.1.x sub-step), `docs/SPRINT_CHECKLIST.md` (one-line pointer), memory note so it survives sessions.

**Dependencies / blockers**: None. (A `.claude/agents/` reviewer sub-agent variant would need Harold's `.claude/` write approval -- OPTIONAL stretch, not required for DoD.)

**Non-functional requirements**: N/A (process docs).

**Acceptance criteria**:
- AC-1: The six classes are documented with detection actions in the Phase 5.1 pre-PR step; SPRINT_CHECKLIST references it.
- AC-2: The checklist is exercised once against the Sprint 49 diff itself before the PR is marked ready (dogfood run recorded in the PR description).

**Tests to write**: None (process/docs deliverable); the dogfood run (AC-2) is the verification.

**Definition of Done**: default Task-Level DoD items 1/5/7/8 (docs-applicable subset) + AC-2 dogfood run.

**Model**: **Haiku-tier** -- mechanical doc authoring from an already-analyzed class list. (Executed by the active session model.)

**Step-types**: DOCS + HOOK-lite. **Est-Effort: 45-90m.**

**Risk & rollback**: Low -- docs only. Rollback -- remove the section.

---

## Estimated Effort Summary

- Task 1 (F119-c): DONE (~75m actual)
- Task 2 (F-VERSION-DERIVE): 90-180m
- Task 3 (F-PRECHECK): 45-90m
- **Remaining Est-Effort: ~135-270m (~2.5-4.5h)**

## Deferred this refinement (Harold 2026-07-21 selection: 6, 7 only)

BUG-DECODE + F33-PROD, F-COPILOT-INSTR, CI_* secrets, NO-RULE-POLISH, F-WINSTORE-ASSETS (best after 0.5.7 live), F108-RETEST -- remain as candidates for Sprint 50 / the Android-track kickoff. Android/Google Play track: HOLD until 0.5.7 verified LIVE.

## Model Assignments

- **Fable 5**: F119-c diagnosis + fix (Harold-directed escalation); session continues on Fable 5 for Tasks 2-3 (cheapest-first tiers recorded per task above).
