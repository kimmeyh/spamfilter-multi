# Sprint 53 Plan

**Branch**: `feature/20260803_Sprint_53`
**Dates**: 2026-08-03 --
**Scope defined by Harold** (verbatim, 2026-08-03): "F138 - icons not needed in this context - can be closed | secrets.dev.json - OK to fix now as it doesn't affect dev or the sprint | include in this sprint the full manual smoke pass on the built MSIX (Gmail sign-in, About screen, no [DEV] suffix)" -- then: "This fully defines the scope for sprint 53."

**Context**: PR #292 (Sprint 52) merged to `develop`, then PR #293 merged `develop` -> `main` on 2026-08-03. This sprint completes the Store release that unlocks: version bump verification, MSIX build, mandatory verification checks, upload to Partner Center, and the full manual smoke pass Harold explicitly added to scope.

**Already complete before this plan** (commit `7a9f231`, Sprint 53 branch): `msix_config.msix_version` bumped `0.5.8.0` -> `0.5.9.0` (had been stale through Sprints 51-52 -- only `pubspec.yaml`'s top-level `version:` had moved); new `docs/STORE_VERSION_STATUS.md` quick-check cache for live-Store-version + dev-version, wired into `STORE_RELEASE_PROCESS.md` and `sprint_status.json`; F138 decided and recorded closed in the master plan; `secrets.dev.json` (prod worktree, gitignored) cleaned of stray comment/space-key entries.

---

## Task 1 -- F-STORE-53: Build, verify, and upload MyEmailSpamFilter 0.5.9.0 to Microsoft Partner Center (Priority 10)

**Value**: This ships the accumulated Sprint 51+52 work (accessibility remediation, AppBar consistency, session-scoped account selection, the Skip button, and the MV-1/legacy-account/refresh-feedback fixes found across four PR-292 review rounds) to real users, and closes out the version-bump gap Harold caught mid-session.

**Requirements** (numbered, detailed):
- R-1: The MSIX is built from the prod worktree (`spamfilter-multi-prod`) on `main`, using the ONLY supported command path (`flutter pub run msix:create`), per `STORE_RELEASE_PROCESS.md` Step 3.
- R-2: The build is proven to be a PROD build, not dev, by BOTH the build-log check and the compiled-binary `--print-env` probe (Step 4.0 Checks A and B) -- this is the exact defect class (F119/F119-b/F119-c) that cost three prior sprints when skipped or done incompletely.
- R-3: The manifest version inside the packaged MSIX reads `0.5.9.0` (Step 4.1).
- R-4: OAuth credentials are embedded and functional -- proven by an actual Gmail sign-in on the installed build, not just a build-log inspection (Step 4.2).
- R-5: The MSIX size is in the expected ~16-17 MB range (Step 4.3).
- R-6: **Full manual smoke pass on the installed build** (Harold's explicit scope addition): Gmail sign-in completes end-to-end; About screen shows "Version 0.5.9" with NO `[DEV]` suffix; window title shows "MyEmailSpamFilter" with NO `[DEV]` suffix; app uses the `MyEmailSpamFilter` (not `_Dev`) data directory.
- R-7: The MSIX is uploaded to Partner Center, release notes are written for Store users (user-visible behavior only -- omit internal/process changes), and the submission is submitted for certification.
- R-8: `docs/STORE_VERSION_STATUS.md` and `.claude/sprint_status.json`'s `store_release` block are updated once certification completes (may land as a follow-up commit if certification takes the usual 24-72h).

**Affected components / files**:
- `spamfilter-multi-prod/mobile-app/build/windows/x64/runner/Release/my_email_spam_filter.msix` -- build output, not committed to git
- `docs/STORE_VERSION_STATUS.md` -- Live/certified row, updated post-certification
- `.claude/sprint_status.json` -- `store_release` block, updated post-certification
- `CHANGELOG.md` -- move `[Unreleased]` entries under `## [0.5.9] - <date>` once released (Step 7)
- `docs/ALL_SPRINTS_MASTER_PLAN.md` -- "Last Completed Sprint" store-status line, once certification completes

**Dependencies / blockers**:
- None to START the build. Certification turnaround (24-72h, per Microsoft) blocks R-8's completion but not R-1 through R-7.
- Gmail sign-in (R-4, R-6) requires Harold's real Google account credentials at the interactive OAuth step -- Claude cannot complete a real sign-in headlessly. This is a Harold-in-the-loop task by nature, same as every prior Store release.

**Non-functional requirements**:
- Platform: Windows Desktop only (Store release scope; Android/iOS out of scope per `STORE_RELEASE_PROCESS.md` line 7).
- Security: never handle real Google OAuth credentials programmatically; the sign-in step is Harold-performed, Claude observes/reports outcome only.

**Acceptance criteria** (measurable, traceable):
- AC-1: `flutter build` log (or msix:create's echoed inner command) shows `--dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json` in the build invocation.
- AC-2 (behavioral): Given the built MSIX installed on the prod worktree's build machine, When `MyEmailSpamFilter.exe --print-env` is run, Then it prints `APP_ENV=prod`, `displaySuffix=` (empty), `dataDirSuffix=` (empty), `windowTitle=MyEmailSpamFilter`, `NATIVE_APP_ENV=prod` -- all five lines, no `dev` anywhere.
- AC-3: `AppxManifest.xml` inside the unpacked MSIX shows `Version="0.5.9.0"`.
- AC-4 (behavioral): Given the MSIX installed via `Add-AppxPackage`, When the app is launched and Gmail sign-in is attempted, Then the OAuth browser page opens with the real client ID (`577022808534-...`) in the URL, and sign-in completes successfully (Harold-performed).
- AC-5 (behavioral): Given the installed app is running, When the title bar and About screen are inspected, Then both read version 0.5.9 with NO `[DEV]` suffix anywhere (Harold-performed, per Step 4.0 Check C -- this is the definitive proof, stronger than the headless probe alone).
- AC-6: MSIX file size is between 5 MB and 50 MB (sanity range per Step 4.3; expected ~16-17 MB).
- AC-7: Submission appears in Partner Center with status "Submitted for certification" or further along, and the version shown matches `0.5.9.0`.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1, AC-3) -- this is a release-process verification step, not new automated test code. Evidence is captured in the sprint retrospective / summary (build log excerpt, manifest grep output) rather than a new test file.
- T-2 (verifies AC-2) -- same: the `--print-env` probe is an existing headless verification mechanism (`main.dart`, Sprint 47/49), not new code this sprint. Its output is the evidence artifact.
- T-3 (verifies AC-4, AC-5) -- manual verification only, performed by Harold on the installed build. No automated test can exercise a real OAuth flow or visually confirm a title bar. Recorded as a Harold-confirmed checklist item in the sprint retrospective.
- No new `flutter test` coverage is added by this task -- it is a verification/release task against code already shipped and tested in Sprint 52 (1,859 passing at merge time). Automated coverage for the build-time invariants already exists (`test/policy/msix_config_test.dart`, `test/policy/version_consistency_test.dart`) and was re-run clean as part of the pre-build check (Sprint 53 commit `7a9f231`).

**Definition of Done**: default task-level DoD PLUS:
- All 7 acceptance criteria explicitly confirmed with evidence (build log excerpt, `--print-env` output, manifest grep, MSIX file size, Harold's direct confirmation of Gmail sign-in + About/title-bar check).
- Submission visible in Partner Center at "Submitted for certification" or later.
- `docs/STORE_VERSION_STATUS.md` updated once certification completes (may be a same-sprint follow-up commit given the 24-72h turnaround).

**Model**: Sonnet -- *why not Haiku*: this task carries direct release risk (the exact F119/F119-b/F119-c defect class that cost three prior sprints when a verification step was skipped or a build-config key was subtly wrong); it requires careful multi-step verification with judgment about what "looks wrong," not mechanical execution. Not escalated to Opus/Fable: no debugging of an unknown root cause is anticipated -- this is the routine, already-hardened release path, not a novel investigation.

**Executed-by**: _(fill at completion)_

**Step-types**: NATIVE-WIN (build/package), TEST-POLICY (pre-build gate re-verification), DOCS (release notes, version-status updates)

**Est-Effort**: 60-100m -- **[no-history]**: no prior CODING_VELOCITY.md entry exists for a routine, no-bug-found release cycle (all three prior Store-release entries -- F119, F119-b, F119-c -- are emergency debug cycles for a defect this exact process was hardened to prevent, not a clean baseline). Estimate is a reasoned band: Step 3 build (~10-15m), Step 4 verification (~20-30m incl. Harold's Gmail sign-in wait), Step 6 Partner Center upload + release notes (~20-30m), Step 7 post-submission bookkeeping (~10-15m). Record the actual in `docs/CODING_VELOCITY.md` regardless of variance so this becomes the seed for the next routine release.

_**Risk & rollback**_: Primary risk is shipping a dev-flagged or credential-empty build (F119 class) -- mitigated by the mandatory two-layer Check A/B verification BEFORE upload, which is exactly the gap that let three prior defects reach the Store. Secondary risk: Partner Center rejects the submission (version-already-used, missing metadata) -- mitigated by AC-3's version check and Step 6's confirmation that prior-submission metadata carried over correctly. Rollback: if certification fails, Partner Center emails a rejection reason; fix, bump the version again (Store does not permit re-submitting the same version number), rebuild, resubmit -- no user-facing rollback needed since a failed certification never reaches users.

---

## Sprint-Level Notes

- **No code changes are in scope.** This sprint is release execution against already-shipped, already-tested Sprint 52 code (1,859 tests passing at merge). F137 (dead `process_results_screen.dart`) remains an open backlog candidate, not selected for this sprint.
- **F138 is closed** (Harold, 2026-08-03) -- recorded in `docs/ALL_SPRINTS_MASTER_PLAN.md`.
- **`secrets.dev.json` cleanup is already done** (prod worktree, gitignored -- no commit, confirmed by Harold as not affecting dev or this sprint's scope).
- Given the narrow, single-task scope, Phase 3.3.1's two deliverables (issue card + draft PR) still apply -- both created before task execution per the `require-sprint-cards.ps1` gate.
