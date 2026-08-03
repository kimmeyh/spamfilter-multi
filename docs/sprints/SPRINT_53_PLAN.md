# Sprint 53 Plan

**Branch**: `feature/20260803_Sprint_53`
**Dates**: 2026-08-03 --
**Scope defined by Harold** (verbatim, 2026-08-03): "F138 - icons not needed in this context - can be closed | secrets.dev.json - OK to fix now as it doesn't affect dev or the sprint | include in this sprint the full manual smoke pass on the built MSIX (Gmail sign-in, About screen, no [DEV] suffix)" -- then: "This fully defines the scope for sprint 53."

**Context**: PR #292 (Sprint 52) merged to `develop`, then PR #293 merged `develop` -> `main` on 2026-08-03. This sprint builds a release-candidate MSIX and runs the full manual smoke pass Harold explicitly scoped in. **The actual develop -> main merge, Partner Center upload, and certification submission are OUT OF SPRINT-53 SCOPE** -- corrected 2026-08-03 after Harold flagged the task card had scope-crept into the full release pipeline ("this task is meant to be a smoke test, correct?"). Those steps happen later, as a separate Harold-initiated action, once the smoke pass result is known.

**Already complete before this plan** (commit `7a9f231`, Sprint 53 branch): `msix_config.msix_version` bumped `0.5.8.0` -> `0.5.9.0` (had been stale through Sprints 51-52 -- only `pubspec.yaml`'s top-level `version:` had moved); new `docs/STORE_VERSION_STATUS.md` quick-check cache for live-Store-version + dev-version, wired into `STORE_RELEASE_PROCESS.md` and `sprint_status.json`; F138 decided and recorded closed in the master plan; `secrets.dev.json` (prod worktree, gitignored) cleaned of stray comment/space-key entries.

---

## Task 1 -- F-STORE-53: Build a release-candidate MSIX and run the full manual smoke pass (Priority 10)

**Value**: Proves the accumulated Sprint 51+52 work (accessibility remediation, AppBar consistency, session-scoped account selection, the Skip button, and the MV-1/legacy-account/refresh-feedback fixes found across four PR-292 review rounds) is release-ready, and proves the `msix_version` bump is correct, BEFORE committing to the merge-to-main and Partner Center steps. Catching a build defect here costs a rebuild; catching it after upload costs a rejected/pulled Store submission.

**Requirements** (numbered, detailed):
- R-1: A release-candidate MSIX is built with `windows_build_args`/prod dart-defines active. Built from a checkout that has the Sprint 53 branch's `msix_version` bump (`0.5.9.0`) -- this does NOT require merging to `develop`/`main` first; a local prod-worktree checkout of the feature branch (or `main` merged locally and discarded after, per `STORE_RELEASE_PROCESS.md`'s own pre-merge sanity-build option) satisfies this.
- R-2: The build is proven to be a PROD build, not dev, by BOTH the build-log check and the compiled-binary `--print-env` probe (Step 4.0 Checks A and B) -- this is the exact defect class (F119/F119-b/F119-c) that cost three prior sprints when skipped or done incompletely.
- R-3: The manifest version inside the packaged MSIX reads `0.5.9.0` (Step 4.1).
- R-4: OAuth credentials are embedded and functional -- proven by an actual Gmail sign-in on the installed build, not just a build-log inspection (Step 4.2).
- R-5: The MSIX size is in the expected ~16-17 MB range (Step 4.3).
- R-6: **Full manual smoke pass on the installed build** (Harold's explicit scope): Gmail sign-in completes end-to-end; About screen shows "Version 0.5.9" with NO `[DEV]` suffix; window title shows "MyEmailSpamFilter" with NO `[DEV]` suffix; app uses the `MyEmailSpamFilter` (not `_Dev`) data directory.

**Explicitly OUT of Sprint 53 scope** (corrected 2026-08-03 -- Harold: "this task is meant to be a smoke test, correct?"):
- Merging `feature/20260803_Sprint_53` -> `develop` -> `main` (Harold-only, and not needed to build a release-candidate MSIX per R-1).
- Uploading to Partner Center / submitting for certification.
- Release notes for the Store listing.
- Updating `docs/STORE_VERSION_STATUS.md`'s Live/certified row (nothing changes there until an actual submission certifies).
These become a separate action once Harold decides to proceed with the release, informed by this sprint's smoke-pass result.

**Affected components / files**:
- Release-candidate MSIX -- build output only, not committed to git, discarded or kept locally after verification (not uploaded this sprint).

**Dependencies / blockers**:
- None. This task needs no merge and no Partner Center access to complete.
- Gmail sign-in (R-4, R-6) requires Harold's real Google account credentials at the interactive OAuth step -- Claude cannot complete a real sign-in headlessly. This is a Harold-in-the-loop task by nature, same as every prior Store release.

**Non-functional requirements**:
- Platform: Windows Desktop only (Store release scope; Android/iOS out of scope per `STORE_RELEASE_PROCESS.md` line 7).
- Security: never handle real Google OAuth credentials programmatically; the sign-in step is Harold-performed, Claude observes/reports outcome only.

**Acceptance criteria** (measurable, traceable):
- AC-1: Build log (or msix:create's echoed inner command) shows `--dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json` in the build invocation.
- AC-2 (behavioral): Given the built MSIX installed on the build machine, When `MyEmailSpamFilter.exe --print-env` is run, Then it prints `APP_ENV=prod`, `displaySuffix=` (empty), `dataDirSuffix=` (empty), `windowTitle=MyEmailSpamFilter`, `NATIVE_APP_ENV=prod` -- all five lines, no `dev` anywhere.
- AC-3: `AppxManifest.xml` inside the unpacked MSIX shows `Version="0.5.9.0"`.
- AC-4 (behavioral): Given the MSIX installed via `Add-AppxPackage`, When the app is launched and Gmail sign-in is attempted, Then the OAuth browser page opens with the real client ID (`577022808534-...`) in the URL, and sign-in completes successfully (Harold-performed).
- AC-5 (behavioral): Given the installed app is running, When the title bar and About screen are inspected, Then both read version 0.5.9 with NO `[DEV]` suffix anywhere (Harold-performed, per Step 4.0 Check C -- this is the definitive proof, stronger than the headless probe alone).
- AC-6: MSIX file size is between 5 MB and 50 MB (sanity range per Step 4.3; expected ~16-17 MB).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1, AC-3) -- this is a release-process verification step, not new automated test code. Evidence is captured in the sprint retrospective / summary (build log excerpt, manifest grep output) rather than a new test file.
- T-2 (verifies AC-2) -- same: the `--print-env` probe is an existing headless verification mechanism (`main.dart`, Sprint 47/49), not new code this sprint. Its output is the evidence artifact.
- T-3 (verifies AC-4, AC-5) -- manual verification only, performed by Harold on the installed build. No automated test can exercise a real OAuth flow or visually confirm a title bar. Recorded as a Harold-confirmed checklist item in the sprint retrospective.
- No new `flutter test` coverage is added by this task -- it is a verification/smoke-test task against code already shipped and tested in Sprint 52 (1,859 passing, re-confirmed clean on this branch 2026-08-03). Automated coverage for the build-time invariants already exists (`test/policy/msix_config_test.dart`, `test/policy/version_consistency_test.dart`).

**Definition of Done**: default task-level DoD PLUS:
- All 6 acceptance criteria explicitly confirmed with evidence (build log excerpt, `--print-env` output, manifest grep, MSIX file size, Harold's direct confirmation of Gmail sign-in + About/title-bar check).
- Result (pass/fail per AC) recorded in the sprint retrospective/summary.
- No merge, no upload, no certification submission performed as part of this task.

**Model**: Sonnet -- *why not Haiku*: this task carries direct release risk (the exact F119/F119-b/F119-c defect class that cost three prior sprints when a verification step was skipped or a build-config key was subtly wrong); it requires careful multi-step verification with judgment about what "looks wrong," not mechanical execution. Not escalated to Opus/Fable: no debugging of an unknown root cause is anticipated -- this is the routine, already-hardened release path, not a novel investigation.

**Executed-by**: _(fill at completion)_

**Step-types**: NATIVE-WIN (build/package), TEST-POLICY (pre-build gate re-verification)

**Est-Effort**: 30-50m -- **[no-history]**: no prior CODING_VELOCITY.md entry exists for a routine, no-bug-found smoke-test-only cycle (all three prior Store-release entries -- F119, F119-b, F119-c -- are emergency debug cycles, and all prior full releases bundled the Partner Center step this task no longer includes). Estimate is a reasoned band: build (~10-15m), verification checks (~10-20m incl. Harold's Gmail sign-in wait), reporting (~10m). Record the actual in `docs/CODING_VELOCITY.md` regardless of variance so this becomes the seed for the next routine smoke-test-only cycle.

_**Risk & rollback**_: Primary risk is a false-pass smoke test (build looks prod but is not) -- mitigated by the mandatory two-layer Check A/B verification, which is exactly the gap that let three prior defects reach the Store. No rollback needed: nothing is uploaded or merged as part of this task, so a failed smoke pass simply means fixing the defect and re-running the build locally, with zero user-facing or Store-facing impact.

---

## Sprint-Level Notes

- **No code changes are in scope.** This sprint is smoke-test verification against already-shipped, already-tested Sprint 52 code (1,859 tests passing, re-confirmed on this branch 2026-08-03). F137 (dead `process_results_screen.dart`) remains an open backlog candidate, not selected for this sprint.
- **F138 is closed** (Harold, 2026-08-03) -- recorded in `docs/ALL_SPRINTS_MASTER_PLAN.md`.
- **`secrets.dev.json` cleanup is already done** (prod worktree, gitignored -- no commit, confirmed by Harold as not affecting dev or this sprint's scope).
- **The merge-to-main / Partner Center upload / certification submission are NOT part of Sprint 53.** Corrected 2026-08-03 after Harold caught the task card had scope-crept into the full release pipeline. This sprint proves the release-candidate build is sound; the actual release is a separate, later, Harold-initiated action.
- Given the narrow, single-task scope, Phase 3.3.1's two deliverables (issue card + draft PR) still apply -- both created before task execution per the `require-sprint-cards.ps1` gate.
