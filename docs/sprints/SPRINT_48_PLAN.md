# Sprint 48 Plan: F119-b Store dev-leak fix + 0.5.6 corrected resubmit

**Sprint**: 48
**Date**: 2026-07-20 (retroactively documented -- see note below)
**Branch**: `feature/20260720_Sprint_48` (created FROM `feature/20260711_Sprint_47` per Harold's carry-forward directive)
**PR**: #274 -> develop (merged 2026-07-20)
**Status**: COMPLETE (merged develop -> main; 0.5.6 submitted to Partner Center)

**Note on retroactive documentation**: Sprint 48 was an **emergency hotfix**, not a pre-planned sprint. It was triggered mid-Sprint-47-close-out when Harold's manual test of the LIVE Store `0.5.5` build showed it STILL running as `[DEV]` -- a critical production bug (SPRINT_STOPPING_CRITERIA Criterion 4). Work started immediately (diagnose-before-patching) rather than through Phases 1-3. This plan is written after the fact (Harold's request, 2026-07-20) to record what the plan WOULD have been, so the sprint has a proper Phase 3 artifact. Estimating method: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Diagnose and fix the root cause of the `0.5.5` Store MSIX shipping as `APP_ENV=dev` (despite the F119 fix and a build log that showed `--dart-define=APP_ENV=prod`), harden the release process so the class of defect cannot silently recur, bump to `0.5.6`, and produce a Store-submittable MSIX that is PROVEN to run as prod at the compiled level before submission.

---

## Sprint Scope (1 task + release execution)

### Task 1 -- F119-b: 0.5.5 Store MSIX ships as APP_ENV=dev (a SECOND root cause) (Priority: critical, hotfix)

**Value**: This prevents the Store from serving a broken (dev-mode, empty-Gmail-credentials) build to the first ~20 public users, and prevents the whole defect class from silently recurring on future releases.

**Requirements**:
- R-1: Determine WHY `0.5.5` compiled as dev when the F119 `windows_build_args` key was correct and the build log showed `APP_ENV=prod`.
- R-2: Fix the root cause so a rebuilt MSIX compiles as `APP_ENV=prod`.
- R-3: Add an automated gate that fails the build on the root-cause condition (so it cannot reach the Store again).
- R-4: Add a release-process check that verifies the COMPILED environment (not just the build log, which lied for both 0.5.4 and 0.5.5).
- R-5: Bump `0.5.5 -> 0.5.6` (Partner Center rejects a re-used version).

**Affected components / files**:
- `mobile-app/secrets.prod.json` + `secrets.dev.json` -- remove malformed keys (root cause).
- `mobile-app/test/policy/msix_config_test.dart` -- new well-formed-secrets gate.
- `mobile-app/lib/main.dart` -- `--print-env` compiled-truth probe.
- `docs/STORE_RELEASE_PROCESS.md` -- Step 4.0 rewrite (Check A log + Check B compiled).
- The 8 version-literal files for the 0.5.6 bump (gated set + `test-background-scan-skip.ps1`).

**Dependencies / blockers**: None at start. The corrected build + Store resubmit is the deliverable; the actual Partner Center upload is a Harold action.

**Non-functional requirements**:
- Security: `secrets.*.json` must never be committed (gitignored); backups also gitignored.
- Platform: the `--print-env` probe must exit cleanly before any Flutter binding/DB init so it works headless.

**Acceptance criteria**:
- AC-1: Root cause identified and proven (not guessed) -- diagnose-before-patching.
- AC-2: A freshly built prod MSIX's `.exe --print-env` prints `APP_ENV=prod`, empty `displaySuffix`/`dataDirSuffix`, `windowTitle=MyEmailSpamFilter` (no `[DEV]`).
- AC-3: `msix_config_test.dart` FAILS if any `secrets.*.json` (excl. example/template/backup) has a key with spaces or an empty name.
- AC-4: Manifest version = `0.5.6.0`; version-consistency gate green; full suite green; analyze clean.
- AC-5: `STORE_RELEASE_PROCESS.md` Step 4.0 requires the compiled `--print-env` check.

**Tests to write**:
- T-1 (AC-3) -- TEST-POLICY in `msix_config_test.dart`: a secrets file with a space-in-key fails; a clean file passes.
- T-2 (AC-4) -- the existing version-consistency gate covers the 0.5.6 literals (extended to `test/`+`scripts/` in Sprint 47).

**Definition of Done**: default Task-Level DoD PLUS: the compiled `--print-env` on a real prod build shows `APP_ENV=prod` before any Store submission (AC-2 is the hard gate).

**Model**: **Opus** -- *why not cheaper*: a "compiles as dev while the log says prod" bug is the deepest debug class; the first hypothesis (dart-define/from-file ordering) was wrong and required tracing flutter's `extractDartDefines` source + the msix package's arg converter + the actual JSON to find the space-in-key cause. A wrong guess ships a 3rd broken Store build.

**Step-types**: NATIVE-WIN/tooling investigation + SVC-EDIT (main.dart) + TEST-POLICY + DOCS + version-bump.

**Est-Effort**: 90-180m (hotfix; investigation-heavy, Store re-release on the line).

**Risk & rollback**: Risk -- a 3rd dev-leak to the Store. Mitigation -- the compiled `--print-env` proof before submission (positive proof, not log-trust). Rollback -- secrets backups retained; version bump is gate-backstopped and reversible.

**Decision-class interrupts**: F119-b Store re-release + version bump = release-control (Harold's exclusive upload action); the sprint fixes + verifies, does not upload.

---

## Actual outcome (what happened)

- **Root cause (proven)**: `secrets.prod.json` (and `secrets.dev.json`) contained a JSON key with SPACES (`"comment OR try this"`) plus junk keys. `--dart-define-from-file` turns every JSON key into a `key=value` dart-define; a space in the key corrupts flutter's dart-define stream and silently DROPS `APP_ENV=prod` -> `String.fromEnvironment` falls back to `dev`. Independent of the F119 key typo; the two masked each other across 0.5.4/0.5.5.
- **Fix**: cleaned both secrets files to credential-keys-only (values preserved, backups gitignored); added the secrets-wellformedness gate; added `--print-env`; rewrote Step 4.0; bumped to 0.5.6; converted `test-background-scan-skip.ps1` to derive the version from pubspec (Harold catch).
- **Verification**: full suite green (1763 pass / 29 skip); analyze clean; the rebuilt 0.5.6 prod MSIX `--print-env` -> **`APP_ENV=prod`** (compiled proof); manifest `0.5.6.0`; 16 MB.
- **Release**: merged PR #274 -> develop -> main; 0.5.6 SUBMITTED to Partner Center for certification (Harold, 2026-07-20).
- **Carry-forward**: 4 stranded Sprint-47 post-merge commits were cherry-pick-carried onto the Sprint 48 branch (branched from the Sprint 47 feature branch per Harold's directive).
- **Backlog added**: F-VERSION-DERIVE (make the 6 production log-filename sites derive the version too).

## Model Assignments

- **Opus**: F119-b diagnosis + fix (deep-debug class). Planner/retro/this doc: Opus (per SPRINT_PLANNING.md).
