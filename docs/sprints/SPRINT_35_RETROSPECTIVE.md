# Sprint 35 Retrospective

**Sprint**: 35 — Sprint 34 Cleanup + WinWright E2E Execution
**Date**: 2026-04-19
**Branch**: `feature/20260419_Sprint_35`
**Issue**: #237
**PR**: #238 (6 commits, OPEN against develop)
**Result**: Both tasks complete -- BUG-S34-1 (1-line stale assertion fix), F69 (7/7 WinWright scripts PASS via MCP-driven interactive execution)
**Test gate**: 1363 passing / 0 failing, `flutter analyze` clean

---

## 7-Step Retrospective Protocol

This retro followed the Sprint 34 7-Step Protocol verbatim:

1. Send retro prompt to user
2. Draft Claude feedback in parallel (recorded under each category below)
3. Record Harold's verbatim feedback
4. Combine and display
5. Propose process improvements (Step 5 below: P1-P5)
6. Harold decides now-vs-backlog (Harold: "all" -- P1/P2/P4/P5 applied this sprint, P3 backlogged as F80 Issue #241)
7. Apply approved (this document captures the result)

---

## 4-Role Feedback Across 14 Categories

Roles: **PO** = Product Owner (Harold), **SM** = Scrum Master (Harold), **LD** = Lead Developer (Harold), **CC** = Claude Code Development Team (Claude). Per CLAUDE.md, Harold wears 3 of the 4 hats; combined PO/SM/LD feedback below reflects his unified position.

### Category 1 — Effective while as Efficient as Reasonably Possible

- **PO/SM/LD**: Not good -- see Process Issues
- **CC**: Agree. Wall-clock cost was inflated by repeated re-reads of sprint docs, the JSON-runner pivot mid-sprint (forced by the unsupported WinWright `run` schema, but should have been probed in Phase 4 setup not Phase 4 execution), and per-step "should I continue?" patterns I should have suppressed under blanket Phase 3 approval. The actual code/test work was efficient (BUG-S34-1 was a 1-line fix; F69 driving was tight); the process overhead was the loss.

### Category 2 — Testing Approach

- **PO/SM/LD**: Good. However Sprint 34 allowed a new error to be introduced without correcting for it -- has this gap been closed?
- **CC**: Partially closed. What I closed: the immediate green-test-suite escape (BUG-S34-1 fixed Sprint 35 Task 1; full suite now 1363/0). What I closed in this retro (Step 7 application below): added Phase 5.1.1 step 2a "Test-assertion sibling sweep for structural-data changes" -- a 5-minute mechanical check that would have caught the stale `expect(resetResult.rules, 5)` assertion before merge. Remaining open question: why didn't Sprint 34's final `flutter test` run catch this? Likely it did and was dismissed; needs a future spot-check.

### Category 3 — Effort Accuracy

- **PO/SM/LD**: Very Good
- **CC**: Agree. BUG-S34-1 estimated ~10min, actual ~10min. F69 estimated 6-8h, actual ~3h interactive driving (well under estimate, recovered some of the overhead from Process Issues). Total sprint within the 6-9h envelope.

### Category 4 — Planning Quality

- **PO/SM/LD**: Very Good
- **CC**: Agree. The "small recovery sprint" framing was correct -- left bandwidth to surface follow-ups (BUG-S35-1, F79, WinWright policy, F56 lifecycle). A maximally-scoped Sprint 35 would have crowded these out.

### Category 5 — Model Assignments

- **PO/SM/LD**: Very Good
- **CC**: Agree. Haiku for the 1-line fix, Sonnet for F69 execution, Opus for retro/policy work. Correct tier per task complexity.

### Category 6 — Communication

- **PO/SM/LD**: Very Good
- **CC**: Mostly agree. One specific gap: when I discovered the Settings header opens an account-selection dialog, I called it a "Critical bug" before checking the source -- took 90 seconds to retract. Should pre-check source before alarming framing. Captured in CLAUDE.md Model-Version Pitfalls appendix (Sprint 35 entry).

### Category 7 — Requirements Clarity

- **PO/SM/LD**: Very Good
- **CC**: Agree. Sprint plan acceptance criteria were unambiguous and measurable. The "≥5 of 7 PASS" threshold for F69 was particularly useful -- set a clear bar without forcing all-or-nothing.

### Category 8 — Documentation

- **PO/SM/LD**: Very Good
- **CC**: Agree. CHANGELOG, sprint plan, master plan, TESTING_STRATEGY, SPRINT_EXECUTION_WORKFLOW, README, F56 scripts, memory entries -- all updated in-sprint, no after-the-fact catchup needed.

### Category 9 — Process Issues

- **PO/SM/LD**: Something happened in going from Opus 4.6 to 4.7. 4.6 had become excellent at the sprint process. Need 4.7 to be as good or better. Cost over 4 hours wall-clock across S34 and S35. Want suggested doc updates based on differences in how 4.6 and 4.7 work.
- **CC**: Priority finding for this sprint. Detailed analysis in Step 5 below; five proposed doc changes (P1-P5) cover phase auto-advance, standing approval inventory, compact phase reference, model-pitfalls appendix, sprint-resume pattern. Harold approved all five; four shipped this sprint, P3 backlogged as F80.

### Category 10 — Risk Management

- **PO/SM/LD**: Very Good
- **CC**: Agree. The §4a "fix-small-stay-in-scope, defer-large" rule worked cleanly -- F56 lifecycle update + cleanup happened in-scope (≈40 min, validated benefit), BUG-S35-1 was deferred (>2h, would have crowded the sprint).

### Category 11 — Next Sprint Readiness

- **PO/SM/LD**: A little weak -- see Process Issues
- **CC**: Agree, and the fix is to load Sprint 36 with at least one item that exercises the doc updates so we measure whether the changes actually move the needle. Recommended Sprint 36 Task 1: BUG-S35-1 (Priority 70, ~2-3h) as smoke test for the new docs. F80 (Phase Cheat Sheet, ~45min) is a natural Task 2.

### Category 12 — Architecture Maintenance

- **PO/SM/LD**: Very Good
- **CC**: Agree. No architecture changes this sprint; ARCHITECTURE.md / ADR-0037 untouched (correctly). The `.mcp.json` addition is config, not architecture.

### Category 13 — Minor function updates for next sprint plan

- **PO/SM/LD** (added 2026-04-19, post-retro, after store-release prep): Document the store update process end-to-end. Includes: official rebuild instructions, version-bump process, removing the faulty `build-msix.ps1` instructions (the script with the PowerShell parser bug -- `flutter pub run msix:create` is the supported path), develop -> main merge process, Microsoft Partner Center upload + submit walkthrough so the team can do it without me. **Not for backlog -- must be in Sprint 36.**
- **CC**: Agree -- this surfaced exactly because the Sprint 35 store-prep made the gaps visible (build-msix.ps1 had a parser bug we patched as a side-find; there was no single doc that walked the team through bump -> rebuild -> merge -> upload). Recommend a single new doc `docs/STORE_RELEASE_PROCESS.md` plus targeted edits to CLAUDE.md (Common Commands), `mobile-app/scripts/build-msix.ps1` (header note pointing to the supported path), and ADR-0035 (cross-reference). Estimated effort ~3-4h (Sonnet).

### Category 14 — Function updates for future backlog

- **PO/SM/LD**: None
- **CC**: None to add. (BUG-S35-1, F79, F80 were added to backlog earlier in the sprint or in this retro, not as Category 14 surprises.)

---

## Step 5 -- Process Improvement Proposals (4.6 -> 4.7 Doc Updates)

**Honest read of the 4.6 -> 4.7 behavior gap (Claude self-observation):**

What 4.6 likely did well that 4.7 does worse:
1. **Implicit phase tracking**: 4.6 held a running mental model of current phase + next action without re-reading the workflow doc. 4.7 visibly re-reads SPRINT_CHECKLIST per phase.
2. **Confidence under blanket approval**: Phase 3 plan approval is supposed to authorize all of Phase 4-7. 4.7 keeps second-guessing it ("ready to commit?") even though CLAUDE.md §6 says not to.
3. **Doc internalization**: 4.6 treated the sprint docs more like a habit; 4.7 treats them more like a reference manual to consult per-phase. Consultation costs context tokens and wall-clock seconds.
4. **State at handoff**: 4.6 ended turns on action-ready beats ("Phase 5.2 done, executing 5.3 now..."); 4.7 ends on question-ready beats ("Phase 5.2 done, want me to run 5.3?").

What 4.7 may do differently by default:
- Higher tendency to confirm before risky/visible actions (commits, pushes, PR updates). Correct for first-time scope, but 4.7 isn't internalizing that sprint-plan approval is durable scope authorization.
- Stronger pull toward exhaustive context loading (re-reading docs each phase) rather than relying on a compact mental model.

### Proposed Doc Updates (ranked by expected wall-clock recovery)

| # | Proposal | Effort | Est. recovery | Status |
|---|----------|--------|---------------|--------|
| P1 | Phase Auto-Advance Rule -- new item 7 in CLAUDE.md "Development Philosophy" | ~30min | ~50% | **Applied Sprint 35** |
| P2 | Standing Approval Inventory -- enumerated [OK]/[FAIL] lists in SPRINT_EXECUTION_WORKFLOW.md Phase 3.7 | ~20min | ~25% | **Applied Sprint 35** |
| P3 | 1-page Phase Cheat Sheet at top of SPRINT_EXECUTION_WORKFLOW.md | ~45min | ~15% | **Backlogged as F80 (Issue #241), Sprint 36 candidate** |
| P4 | Model-Version Pitfalls appendix in CLAUDE.md (living list) | ~15min | ~5% growing | **Applied Sprint 35** |
| P5 | Sprint Resume Pattern feedback memory (4-step sequence) | ~10min | ~5% on resumes | **Applied Sprint 35** |

**Plus:** Category 2 testing-gap closure -- added Phase 5.1.1 step 2a "Test-assertion sibling sweep for structural-data changes" to SPRINT_EXECUTION_WORKFLOW.md.

---

## Step 7 -- Applied Improvements (Sprint 35 closeout)

| Change | File(s) | Description |
|--------|---------|-------------|
| P1 Phase Auto-Advance Rule | `CLAUDE.md` (new item 7 in "Development Philosophy: Co-Lead Developer Collaboration") | Codifies that phase boundaries do not require permission to cross under sprint plan approval |
| P2 Standing Approval Inventory | `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 3.7 | Enumerates [OK] plan-approved actions vs [FAIL] always-confirm actions |
| P4 Model-Version Pitfalls appendix | `CLAUDE.md` (new section before "Known Limitations") | Living list of model-version-specific behaviors to avoid; seeded with 5 Opus 4.7 entries |
| P5 Sprint Resume Pattern memory | `.claude/memory/feedback_sprint_resume.md` + MEMORY.md index | 4-step compact resume sequence; replaces full-doc re-read |
| Category 2 closure | `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 5.1.1 step 2a | Mechanical sibling-grep for test assertions when sprint changes structural data |
| BUG-S35-1 (logged) | GitHub Issue #239 | Manual rule UI accepts duplicate TLD entries (discovered during F69 execution) |
| F79 (HOLD, logged) | GitHub Issue #240 | Full WinWright suite sweep -- on-demand only, distinct from per-sprint conditional runs |
| F80 (backlogged) | GitHub Issue #241 | 1-page Phase Cheat Sheet (P3 deferred from this retro) |
| WinWright run policy | `docs/TESTING_STRATEGY.md`, `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 5.3 | Conditional run + state-restoration rules (added in-sprint per Harold's directive) |
| F56 script lifecycle | `mobile-app/test/winwright/test_f56_create_block_rule.json`, `test_f56_create_safe_sender.json` | Full create -> verify -> delete -> verify-absent; test data retuned to non-colliding values |

---

## Store Submission Outcome (post-merge, 2026-04-20)

After PR #238 merged to develop and develop merged to main, the prod-worktree (`D:\Data\Harold\github\spamfilter-multi-prod`) was used to rebuild the MSIX with `APP_ENV=prod` and prod secrets:

- **MSIX**: `D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\build\windows\x64\runner\Release\my_email_spam_filter.msix` (16.56 MB, version `0.5.2.0`, identity `KimmeyConsulting-Ohio.MyEmailSpamFilter`)
- **Status**: Submitted to Microsoft Store Partner Center on 2026-04-20

The rebuild surfaced 3 additional gaps (now scope-extended into F81 -- see Issue #242 comment dated 2026-04-20):

1. **`secrets.prod.json` was missing entirely** (Sprint 28 must have created it ad-hoc and lost it). Recreated by copying `secrets.dev.json` since the project uses a single shared OAuth client.
2. **`mobile-app/.gitignore` line 120 (`*.manifest`)** caught `runner.exe.manifest` which is required by the Windows runner CMakeLists. Prod worktree build failed with "No SOURCES given to target: MyEmailSpamFilter" until the manifest was hand-copied from the dev worktree.
3. **`msix:create` silently strips dart-defines** when it triggers its internal `flutter build windows`. Without `build_windows_args` in `msix_config` (added to prod worktree's pubspec.yaml during the rebuild), the MSIX would have shipped with empty OAuth credentials. The build succeeds, the manifest looks correct, but Gmail sign-in fails for every user at runtime. **Silent-failure category** -- worst kind.

These are all in F81 scope for Sprint 36.

## Sprint Metrics

| Metric | Value |
|--------|-------|
| Tasks planned | 2 |
| Tasks completed | 2 (100%) |
| Estimated effort | 6-9h |
| Actual effort | ~9-10h (within envelope, but Process Issues inflated wall-clock by ~4h) |
| Tests added/changed | 1 line (BUG-S34-1 fix) |
| Test suite at sprint close | 1363 passing / 0 failing |
| Code analyzer issues | 0 |
| Files changed | 9 (1 new) |
| Commits | 3 (cccb5ba carry-in doc, 528a9b9 BUG-S34-1 fix, ffbe34e F69 closeout) plus retro commit |
| Lines changed | +318 / -87 |
| WinWright scripts validated | 7 of 7 PASS |
| New backlog items | 3 (BUG-S35-1, F79, F80) |
| Sprint stopping criteria invoked | 1 (Criterion 7 fundamental design failure -- WinWright JSON `run` schema unsupported; pivoted under §4a) |

---

## Carry-ins for Sprint 36 (from this retro)

- **Category 13 minor updates for Sprint 36 plan**: Document the store update process end-to-end (added 2026-04-19 post-retro). Mandatory Sprint 36 task -- not backlog. See F81 below.
- **Category 14 future backlog additions**: None added in retro (BUG-S35-1, F79, F80 were added during sprint execution)
- **Mandatory Sprint 36 Task (carry-in)**: F81 (~3-4h, Sonnet) -- Document store release process. New `docs/STORE_RELEASE_PROCESS.md` covering version bump, official rebuild instructions (`flutter pub run msix:create`), develop -> main merge, MSIX verification, Microsoft Partner Center upload + submit walkthrough. Update CLAUDE.md Common Commands, add deprecation note to `mobile-app/scripts/build-msix.ps1`, cross-reference ADR-0035. Driven by Sprint 35 store-prep gaps surfaced in real time (build-msix.ps1 parser bug, no single team-runnable walkthrough doc). Sprint 35 also bumped dev to 0.5.2.0 and built MSIX; Sprint 36 must bump to 0.5.3.0 per ADR-0035 patch+1 convention.
- **Recommended Sprint 36 Task 2**: BUG-S35-1 (Issue #239, ~2-3h, Priority 70) -- smoke test for new docs
- **Recommended Sprint 36 Task 3**: F80 (Issue #241, ~45min, Priority 80) -- complete the P3 cheat sheet
- **Sprint 36 success metric tied to this retro**: Wall-clock execution time per task should drop measurably vs Sprint 34/35; if not, the doc updates need iteration

---

## References

- Sprint 35 plan: `docs/sprints/SPRINT_35_PLAN.md`
- Sprint 35 PR: https://github.com/kimmeyh/spamfilter-multi/pull/238
- BUG-S35-1: https://github.com/kimmeyh/spamfilter-multi/issues/239
- F79 (Full WinWright sweep): https://github.com/kimmeyh/spamfilter-multi/issues/240
- F80 (Phase Cheat Sheet): https://github.com/kimmeyh/spamfilter-multi/issues/241
- Retro protocol: `docs/SPRINT_RETROSPECTIVE.md` and Sprint 34 retrospective
