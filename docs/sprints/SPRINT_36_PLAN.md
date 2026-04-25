# Sprint 36 Plan: Store Release Docs + Duplicate-Rule Bug + Phase Cheat Sheet

**Sprint**: 36
**Date**: 2026-04-20
**Branch**: `feature/20260420_Sprint_36`
**Issue**: #244
**Type**: Mixed -- Documentation (F81), Bug fix (BUG-S35-1), Process documentation (F80)
**Estimated Effort**: ~8-10h

---

## Sprint Objective

Close the three Sprint 35 carry-ins in dependency order: (1) make the store release process reproducible by the team without Claude (F81), (2) prevent the duplicate-rule silent-save bug that surfaced during Sprint 35 F69 execution (BUG-S35-1), and (3) land the P3 deferred process improvement from Sprint 35 retro (F80 Phase Cheat Sheet). Also measure whether the Stop-hook + Sprint 35 P1/P2/P4/P5 process changes actually recover the 3-6h/day of wall-clock cost they were built to prevent.

---

## Key Design Decisions

1. **F81 ordering first**: The three items touch different parts of the repo (docs, app code, process docs). F81 has the expanded scope (5-6h revised) and covers the three silent-failure gaps surfaced during the Sprint 35 prod-worktree rebuild on 2026-04-20 -- those need to land before the next store release to prevent the same pain. Moving F81 after BUG-S35-1 would risk a second-cycle rebuild without the docs in place.

2. **BUG-S35-1 as smoke test for Sprint 35 process changes**: The retrospective explicitly marked this bug as the measurement vehicle for whether P1-P5 and the Stop-hook recover the 3-6h/day wall-clock cost. Execute this task with intentional attention to stops-per-hour and compare against Sprint 34/35 baselines in the retrospective.

3. **F80 last (and small)**: Phase Cheat Sheet is editorial, compact (~45min), and benefits from lessons learned during F81 execution (the cheat-sheet author has just done the full Phase 1-7 walk in F81). Doing F80 first would miss that insight.

4. **Stop-hook is pre-work, not a task**: Already shipped on this branch in commit `4874004`. Not a Sprint 36 task per se -- it's the enforcement mechanism that makes the rest of the sprint autonomous. Success metric for the hook is "zero procedural-question violations surfaced by user during Sprint 36 execution".

5. **Dev-to-prod build_windows_args symmetry**: F81 scope includes adding `build_windows_args: --dart-define=APP_ENV=dev --dart-define-from-file=secrets.dev.json` to the dev worktree's `pubspec.yaml` `msix_config` block. Only the prod worktree got this line during the Sprint 35 post-merge rebuild. Without the dev symmetric line, a dev MSIX build (e.g., for local testing) would ship with empty OAuth creds -- same silent failure as the prod gap that triggered the scope expansion.

---

## Tasks

### Task 1: F81 -- Store release process documentation (~5-6h, Sonnet)

**Execution order**: 1 (must land before any future store release)

**Problem**: No single team-runnable walkthrough doc for the version-bump -> rebuild -> merge -> upload sequence. Sprint 28 shipped 0.5.1.0 to the Microsoft Store, but the procedure lived in tribal knowledge (Harold's head). Sprint 35's 0.5.2.0 prep surfaced this as a gap (Issue #242) plus three additional silent-failure gaps during the prod-worktree rebuild (2026-04-20 comment on Issue #242):

1. `secrets.prod.json` was missing entirely -- no one can tell whether Sprint 28 created one or just used `secrets.dev.json` verbatim; we recreated by copying dev secrets since the project uses a single shared OAuth Desktop client.
2. `mobile-app/.gitignore` line 120 (`*.manifest`) catches `runner.exe.manifest` which is required by the Windows runner CMakeLists (`add_executable` references it directly). Fresh worktree builds fail with "No SOURCES given to target: MyEmailSpamFilter" until the manifest is hand-copied from another worktree.
3. `flutter pub run msix:create` runs `flutter build windows` internally and does NOT inherit `--dart-define` flags passed to `msix:create` itself. Without `build_windows_args` in `msix_config`, the MSIX silently ships with empty OAuth credentials -- Gmail sign-in fails at runtime for every user. Build succeeds, manifest looks correct, failure is invisible until user tries to sign in.

**Fix scope**:

- New `docs/STORE_RELEASE_PROCESS.md`:
  - Pre-release checklist (develop green, retro complete, target version chosen)
  - Version bump checklist (5 required file edits listed)
  - `secrets.prod.json` recreation procedure (3 required keys, Google Cloud Console lookup path, shortcut to copy from dev since project uses shared OAuth client)
  - Supported rebuild instructions (`flutter pub run msix:create` + mandatory `build_windows_args`)
  - MSIX verification (grep manifest for version, smoke-test OAuth client ID not empty)
  - `develop -> main` merge process (Harold-only per CLAUDE.md branch policy)
  - Microsoft Partner Center upload + submit walkthrough (find the app, create a new submission, upload MSIX, wait for cert, complete metadata, submit for review)
  - Post-submission steps (monitor status, handle rejection, bump dev to next patch)

- `mobile-app/.gitignore` fix: remove or refine the bare `*.manifest` rule on line 120; commit `runner.exe.manifest`. (Harold authorized removing items from .gitignore.)

- Update `mobile-app/secrets.prod.json.template` to use actual key names the code reads (`WINDOWS_GMAIL_DESKTOP_CLIENT_ID`, `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`, `GMAIL_REDIRECT_URI`) instead of the incorrect `GMAIL_DESKTOP_CLIENT_ID` / `GMAIL_OAUTH_CLIENT_SECRET` currently shown.

- Add `build_windows_args: --dart-define=APP_ENV=dev --dart-define-from-file=secrets.dev.json` to dev worktree's `pubspec.yaml` `msix_config` block (symmetric to prod worktree).

- Deprecate or remove `mobile-app/scripts/build-msix.ps1`:
  - If the makeappx.exe path has no current use case -> delete it
  - If it is still used for some edge case -> add an unambiguous header comment pointing to `STORE_RELEASE_PROCESS.md` for the supported path, note the PowerShell parser bug history

- Update CLAUDE.md Common Commands with a Store Release subsection referencing the new doc; one-liner `flutter pub run msix:create` example.

- Cross-reference from ADR-0035 (Production-Development Side-by-Side Builds) -> `STORE_RELEASE_PROCESS.md`.

**Acceptance criteria**:

- [ ] `docs/STORE_RELEASE_PROCESS.md` exists, covers the 6+ scope bullets above, structured as a runnable checklist
- [ ] A team member can follow the doc end-to-end against a fresh clone of the repo and produce a valid 0.5.3.0-test MSIX + upload flow rehearsal without external help (verified by Harold reading the doc cold before PR mark-ready)
- [ ] `mobile-app/.gitignore` line 120 fixed; `runner.exe.manifest` committed
- [ ] `mobile-app/secrets.prod.json.template` updated with correct key names
- [ ] Dev worktree `pubspec.yaml` has symmetric `build_windows_args` line
- [ ] `mobile-app/scripts/build-msix.ps1` either deleted or carries a clear deprecation header
- [ ] CLAUDE.md Common Commands has Store Release subsection
- [ ] ADR-0035 cross-references new doc
- [ ] Full test suite still passes (1363+ / 0)
- [ ] `flutter analyze` clean

### Task 2: BUG-S35-1 -- Manual rule creation allows duplicates (~2-3h, Sonnet)

**Execution order**: 2 (depends on green test gate from Task 1; serves as smoke test for Sprint 35 process changes)

**Problem**: Sprint 34's F56 manual rule creation UI silently accepts a TLD block rule even when an identical rule already exists in the database. Sprint 35 F69 execution created a `.xyz` TLD rule which duplicated the bundled `._.xyz` (F73 split). DB ended up with two rules with identical pattern, identical sub-type, identical execution_order, differing only by auto-generated `manual_._.xyz_<timestamp>` name. Cleanup required direct SQLite DELETE because the two rows were visually indistinguishable in the Manage Rules UI.

Same bug exists for safe senders (parallel duplicate path) -- never triggered in Sprint 35 because the test data used a domain that wasn't pre-existing, but the code path has no uniqueness check either.

**Fix**:

- Add a uniqueness validator to the manual rule creation save path (`ManualRuleCreateScreen` or its underlying service layer):
  - On save, compare the candidate rule's normalized pattern + condition_type + sub_type against existing rows in the `rules` table
  - If a match is found, return a validation error to the UI before calling any insert
  - Same logic for `safe_senders` table insert path
- Show a user-friendly error message ("A rule for .xyz already exists" or similar) with a way to view the existing rule (optional -- nice-to-have; spec confirms minimum is the error message)
- Write unit tests covering:
  - Block rule: create duplicate rejected
  - Safe sender: create duplicate rejected
  - Case-insensitive / whitespace-normalized comparison (e.g., `.XYZ` and `.xyz` should be treated as the same)
  - Parametric across all 4 block-rule types (TLD, entire_domain, exact_domain, exact_email) and 3 safe-sender types (entire_domain, exact_domain, exact_email)
- Do NOT modify existing duplicate rows in dev/prod DBs -- they'll be cleaned up via a separate one-time task if needed (out of sprint scope; add as backlog candidate if found during Phase 5 testing)

**Acceptance criteria**:

- [ ] Attempting to create a duplicate block rule shows a validation error and does not insert a row
- [ ] Attempting to create a duplicate safe sender shows a validation error and does not insert a row
- [ ] Existing duplicate rules in dev/prod DBs are not modified by this change
- [ ] Unit tests for both paths pass (new tests; existing tests still green)
- [ ] Widget test for the Save Rule error state rendering (verify error shows, save button re-enabled after error, form values preserved)
- [ ] Manual test (Phase 5): try to create `.xyz` block rule in the dev app (bundled `._.xyz` exists) -- should get error, not silent save
- [ ] Full test suite passes (1363+ / 0 plus new tests)
- [ ] `flutter analyze` clean

### Task 3: F80 -- 1-page Phase Cheat Sheet (~45min, Haiku)

**Execution order**: 3 (after F81 so the cheat-sheet author has just walked the full Phase 1-7 flow)

**Problem**: `docs/SPRINT_EXECUTION_WORKFLOW.md` is 1357+ lines. Re-reading it at phase boundaries costs context tokens and wall-clock seconds. Sprint 35 retro proposal P3 -- deferred here.

**Fix**: Prepend a ~30-line Phase Cheat Sheet near the top of `docs/SPRINT_EXECUTION_WORKFLOW.md`:

- 7-row table: Phase | Purpose | Top-3 Actions | Auto-advance trigger to next phase
- Each row's Top-3 Actions are the must-do bullets, not the full enumeration
- Auto-advance trigger is the concrete condition that signals next-phase start (tests green, PR pushed, retro committed, etc.)
- Each row links to the detailed phase section below via anchor

**Acceptance criteria**:

- [ ] Cheat sheet appears within first 50 lines of `docs/SPRINT_EXECUTION_WORKFLOW.md`
- [ ] All 7 phases represented
- [ ] Each row links to the corresponding detailed section anchor
- [ ] Total cheat sheet size <= 40 lines
- [ ] A model resuming a sprint mid-execution can identify current phase + next action from the cheat sheet alone (verified by reading just the cheat sheet and answering "what's my next action if I'm in Phase 5 and tests just passed" without consulting the full doc)

---

## Task Summary Table

| # | Task | Issue | Estimate | Model | Dependencies |
|---|------|-------|---------|-------|--------------|
| 1 | F81: Store release process documentation (expanded scope) | #242 | ~5-6h | Sonnet | None |
| 2 | BUG-S35-1: Manual rule duplicate prevention | #239 | ~2-3h | Sonnet | Task 1 green test gate |
| 3 | F80: 1-page Phase Cheat Sheet | #241 | ~45min | Haiku | Task 1 (walks Phase 1-7 flow) |

**Total estimate**: ~8-10h. Single-session feasible.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| F81 scope grows beyond 5-6h as more gaps surface during doc-writing | Medium | Medium | Hard time-box at 6h; any additional gap found -> log as backlog candidate, do not inline |
| BUG-S35-1 fix requires DB schema change (unique index) that would break existing duplicate rows | Low | High | Do NOT add unique index in migration -- fix at the application insert path only; leave existing dupes intact. Schema-level dedup is a separate backlog candidate. |
| F81 docs get too long and become the new unreadable artifact | Medium | Low | Target <= 400 lines for STORE_RELEASE_PROCESS.md; anything larger indicates scope creep. Use the F80 cheat-sheet pattern (tables + anchors) as the structural model. |
| Stop-hook produces false positives during Sprint 36 execution | Low-Medium | Medium | Emergency bypass documented; hook has 7-case test suite; iterate on regex patterns if real false positives occur. |
| `mobile-app/.gitignore` change breaks build for other team members | Low | Medium | After the fix, run `git clean -fdxn` dry-run and flutter build to confirm no accidental tracking of untracked artifacts. Commit the gitignore fix + runner.exe.manifest as one atomic commit so any team member pulling picks up both. |

---

## Architecture Impact Check (Phase 3.6.1)

**Reviewed against**:

- `docs/ARCHITECTURE.md`: No documented components affected. F81 adds process documentation. BUG-S35-1 adds validation to existing ManualRuleCreateScreen save path. F80 is editorial.
- `docs/ARSD.md`: No requirements or design specifications affected.
- `docs/adr/*.md`: ADR-0035 (Production-Development Side-by-Side Builds) is cross-referenced by F81 but not modified. No new ADR needed -- F81 documents an existing process, does not introduce a new architectural pattern.

**Result**: **No architecture impact.** No ADR/ARCHITECTURE/ARSD updates anticipated beyond the ADR-0035 cross-reference.

---

## Dependency Vulnerability Check (Phase 2.6 result)

Run on 2026-04-20 as Sprint 36 Phase 2:

- **Discontinued**: `js` (transitive only) -- no urgent action, monitor (same as Sprint 35)
- **Available updates**: 31 minor/patch (no security flags), 20 major (deferred per policy)
- **Action**: None this sprint (same state as Sprint 35 baseline)

---

## Sprint Stopping Criteria

Per `docs/SPRINT_STOPPING_CRITERIA.md`. Stop only for:

1. All tasks complete
2. Blocked on external dependency
3. User requests scope change
4. Critical bug found
5. User requests early review
6. Sprint review complete
7. Fundamental design failure
8. Context > 95%
9. Time limit reached

**4a applies**: User-found gap in sprint theme (same category, <2h, no new design) extends scope without stopping.

**Stop-hook enforcement** (Sprint 36 new): `.claude/hooks/sprint-auto-advance.ps1` fires on every Stop event and blocks turn-ends that end with procedural questions on sprint branches. Legitimate §1-9 stops use explicit "Stopping criterion N: ..." phrasing to pass the whitelist.

---

## Carry-ins from Previous Sprint Retrospective

From Sprint 35 retro:

- **Category 13 Minor Updates** (from PO/CC carry-in): F81 (this sprint Task 1, Issue #242) -- mandatory.
- **Step 6 backlog decisions**: P3 Phase Cheat Sheet -> F80 (this sprint Task 3, Issue #241).
- **Recommended Task 2** (retro suggestion): BUG-S35-1 (this sprint Task 2, Issue #239) as smoke test for Sprint 35 P1-P5 process improvements.

Sprint 35 also applied P1 (Phase Auto-Advance Rule in CLAUDE.md), P2 (Standing Approval Inventory in Phase 3.7), P4 (Model-Version Pitfalls appendix in CLAUDE.md), P5 (Sprint Resume Pattern memory), and the Phase 6.4.5 "convert PR from draft to ready" step. Sprint 36 also added the Stop-hook on 2026-04-20 after 4.7 violated the P1 rule during this sprint's own kickoff. All of these are active enforcement mechanisms and their effectiveness is the Sprint 36 retrospective metric.

---

## Sprint 36 Success Metric (tied to Sprint 35 retro)

Wall-clock execution time per task should measurably drop vs Sprints 34-35 (retro-measured ~4h per sprint of avoidable stops). Sprint 36 retrospective Category 1 (Effective while Efficient) will compare:

- Stops-per-hour (approximate): how often did Harold have to manually unstick the model?
- Stop-hook violations detected: how many blocks did the hook issue during sprint execution?
- Stop-hook false positives reported: how many times did Harold have to bypass the hook for legitimate work?

Target: zero procedural-question unsticks required from Harold; <=1 false-positive hook block requiring bypass; F81/BUG-S35-1/F80 all shipped within estimate.

---

## Manual Testing Notes

*(To be populated during Phase 5.)*

### F81 walkthrough rehearsal
*(Harold reads `STORE_RELEASE_PROCESS.md` cold, walks the checklist against a scratch branch, reports any steps that require extra context or are missing detail.)*

### BUG-S35-1 manual verification
*(In dev app: try to create a block rule for `.xyz` TLD (bundled rule exists), expect a validation error. Try to create a duplicate safe sender, expect same. Try non-duplicate cases, expect success. Confirm existing duplicate rows not modified.)*
