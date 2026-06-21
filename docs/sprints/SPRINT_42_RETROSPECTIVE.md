# Sprint 42 Retrospective

**Sprint**: 42
**Dates**: 2026-06-20 (planning + execution + manual testing, single day)
**Branch**: `feature/20260620_Sprint_42`
**PR**: #263 -> `develop`
**Type**: Mixed -- Testing infrastructure (F99, pre-MVP), Architecture implementation (F98 / ADR-0039), Data quality (BUG-S37-2)

---

## Scope Outcome

| Item | Outcome |
|------|---------|
| **F99** -- Flutter `integration_test` E2E harness | **DONE** -- 5 test files green; isolated temp-DB harness; per-file runner; absorbs F76/F56/F37. |
| **F98** -- Per-account background scanning (ADR-0039) | **DONE** -- all 23 active change-sites + migration; +2 manual-testing fixes (account scoping, DB-lock resilience). |
| **BUG-S37-2** -- Bundled TLD data quality | **DONE** -- audit found ccTLD list already complete; removed 2 typos via DB v7 (Harold 1c + 2a). |

**Verification**: `flutter analyze` clean; `flutter test` +1656 ~28; all 5 integration_test files green per-file; manual testing complete.

---

## Role Feedback

> Phase 7 completeness rule: all 4 roles x 14 categories; no silent lines.

**Harold's three roles (Product Owner, Scrum Master, Lead Developer)**: Harold did not provide verbatim role feedback for this sprint (consistent with the recent waiver pattern; "Manual testing complete" was the sign-off). Recorded for all 14 categories as **"No issues -- expectations met (Harold waived verbatim feedback)."** Deliberate PO/SM/Lead-Dev decision, not silence.

**Claude Code Development Team**: full feedback below.

---

### Category 1 -- Effective while as Efficient as Reasonably Possible
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: Highly effective on outcome (all 3 items delivered + manual-tested in one day). **Efficiency dip on F99 DB isolation**: 3 attempts (DatabaseHelper.setAppPaths, path_provider channel-mock, finally AppPaths.testOverrideBaseDir) before the working seam, and one early attempt wrote to the dev DB. The first two were reasonable hypotheses, but I should have read `RuleSetProvider.initialize()` (which rebuilds AppPaths) BEFORE the first attempt -- that would have shown immediately that a per-instance override is clobbered. Once past isolation, F98 (the largest item) went smoothly because the ADR pre-itemized every change-site.

### Category 2 -- Testing Approach
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: F99 is a genuine capability gain -- the create/delete lifecycle and folder-picker flows now run deterministically in-VM (the exact flows WinWright could not). The "verify, don't trust green" discipline paid off twice: the loosely-asserted smoke test passed while secretly using the dev DB, and I caught it only by grepping the actual DB path from the log. F98 shipped with 12 unit tests; the manual-testing fixes added 2 more. Gap: F98's per-account scheduling has no automated end-to-end test (Task Scheduler needs a real OS) -- it relies on manual testing, which is acceptable but worth noting.

### Category 3 -- Effort Accuracy
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: **Best accuracy yet -- error-ratio ~1.3, MAPE ~45%** (vs S41's 2.4 / 140%). F98 landed within estimate, directly because ADR-0039's 24-site inventory removed the unknowns -- strong evidence that design-first ADRs are the single biggest estimation lever. F99 ran ~1.5x low (DB-isolation + per-file-process discovery were unmodeled). BUG-S37-2 ran HIGH because the audit made the "expansion" unnecessary. The 2 reactive manual-testing fixes were unestimated but small.

### Category 4 -- Planning Quality
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: The F99->F98->BUG ordering was right: F99 (pre-MVP testing foundation) first de-risked nothing for F98 directly but was the correct priority; F98's ADR made it the most predictable item despite being the largest. The plan correctly pre-flagged the only two decision points (F98 scheduling -- already locked by ADR + Harold; ccTLD strategy -- surfaced at the right moment). No scope surprises.

### Category 5 -- Model Assignments
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: Single-model (Opus) execution throughout. Appropriate -- F98's cross-cutting 23-site change and F99's harness-architecture problem-solving were judgment-heavy; BUG-S37-2's audit needed analysis. No mechanical-only stretch that would have justified a cheaper tier.

### Category 6 -- Communication
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: After Harold's "please stop stopping" directive, I shifted to continuous execution with inline checkpoints (not permission-gates), which matched intent. Decision points (ccTLD strategy) were surfaced as concrete option-sets, not open questions. The dev-DB-contamination incident was surfaced immediately and honestly rather than quietly cleaned up.

### Category 7 -- Requirements Clarity
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: ADR-0039 made F98 requirements exceptionally clear (file:line change-sites + locked decisions). The one genuine ambiguity (ccTLD scope) was a PO judgment call, correctly routed to Harold. Manual-testing feedback was precise (log + screenshot), which made both F98 fixes fast to localize.

### Category 8 -- Documentation
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: TESTING_STRATEGY.md two-harness section, ADR-0039 marked Accepted (and the index fixed when Copilot-style over-broad-ignore blocked it), per-account Help text, CHANGELOG per item, velocity ledger exit-gate satisfied. The `.claude/settings.json` `0*` ignore rule was over-broad (blocked ADRs) and was caught + narrowed mid-sprint.

### Category 9 -- Process Issues
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: **Primary issue: dev-DB contamination during F99 harness dev.** Two isolation attempts ran the real app against the real data dir (one wrote a YAML backup + seeded rows into the dev DB). Mitigated by Harold's note that the dev DB is his active churning DB, but I should not have run a write-capable harness against an un-verified data path. **Lesson**: when building test isolation, assert the resolved data path is a temp dir BEFORE any write-capable run -- not after. **Secondary**: the `0*.md`/`0*.txt` settings deny rule I added blocked all ADRs (they start with `0`); narrowed to `0[!0-9]*`. Both are "verify the blast radius before acting" misses.

### Category 10 -- Risk Management
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: F98 is a high-blast-radius change (scheduling, DB, CLI, two platforms) but the ADR-first approach + backward-compatible null-default parameters (legacy global path still works) contained it -- the full suite stayed green at every step. The DB-lock issue was a real production risk surfaced by manual testing and addressed in depth (WAL + busy_timeout + retry + jitter), not papered over. Residual: the 1min x 20 retry can make a stuck scan hang up to 20 min -- flagged to Harold.

### Category 11 -- Next Sprint Readiness
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: PR #263 open. F99 unblocks future E2E coverage (the harness + seams are reusable). No carry-ins. The F98 per-account model is the foundation if independent per-account scheduling features are wanted later.

### Category 12 -- Architecture Maintenance
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: ADR-0039 fully implemented as designed (no deviations requiring a new ADR). Two new test seams added to production code (`AppPaths.testOverrideBaseDir`, `FolderSelectionScreen.debugFoldersOverride`) -- both null/absent in production, documented, and of the same category as the existing `TestAppPaths`. The orphaned `background_scan_schedule` table remains (Option A per ADR; future-consolidation candidate). DB schema advanced v6 -> v7.

### Category 13 -- Minor Function Updates for the Next Sprint Plan
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: (a) Consider an automated check (lint/test) that fails if a write-capable test path resolves outside a temp dir (IMP-1). (b) The F98 retry cap (20 min worst case) may warrant a configurable/shorter bound if Harold sees long hangs in practice (IMP-2).

### Category 14 -- Function Updates for the Future Backlog
- **PO/SM/Lead Dev**: No issues -- expectations met (waived).
- **Claude Code Dev Team**: (a) Port the remaining WinWright read-only flows to `integration_test` over time so the in-VM lane becomes primary (IMP-3, backlog). (b) The `background_scan_schedule` table consolidation ADR (deferred by ADR-0039 Option A) remains a future candidate.

---

## Improvement Proposals (Claude -> Harold for now-vs-backlog)

| # | Proposal | Type | Recommendation |
|---|----------|------|----------------|
| IMP-1 | Add a guard so a write-capable test/harness asserts its resolved data path is under the OS temp root BEFORE any write. Would have prevented the F99 dev-DB contamination. Could be a one-line assert in the harness `bootDbOnly`/`bootAppWithDevDbCopy` and a note in TESTING_STRATEGY.md. | Process / harness | **Now** (cheap, prevents recurrence) |
| IMP-2 | Make the F98 DB-lock retry bound configurable (or shorten from 20 min worst-case) if Harold observes long hangs. Currently 1min x 20 per his spec. | Tuning | **Backlog** (revisit only if observed in practice) |
| IMP-3 | Incrementally port WinWright read-only flows to `integration_test` so the robust in-VM lane becomes primary; retire WinWright scripts as each is covered. | Testing strategy | **Backlog** |
| IMP-4 | Record an Opus 4.8 pitfall: "when building test ISOLATION, read how the app self-initializes its data path (AppPaths/path_provider) and assert the resolved path is a temp dir BEFORE the first write-capable run." Add to `feedback_opus_pitfalls.md`. | Memory | **Now** (cheap) |

---

## Documentation Updates Made This Sprint
- `docs/adr/0039-*.md` -- Accepted (carried from S41); `docs/adr/README.md` index status corrected.
- `docs/TESTING_STRATEGY.md` -- two-harness strategy section.
- `docs/sprints/SPRINT_42_PLAN.md` -- approval + decisions recorded.
- `CHANGELOG.md` -- F99, F98, BUG-S37-2, and both manual-testing fixes.
- `docs/CODING_VELOCITY.md` -- Sprint 42 ledger rows + Accuracy Trend.
- `.claude/settings.json` -- `0*` ignore rules (added, then narrowed to exclude ADRs).
- `assets/content/help/background_scanning.md` -- per-account wording.
- `docs/sprints/SPRINT_42_RETROSPECTIVE.md` -- this document.

---

## Retrospective Completeness Check
- [x] All 4 roles addressed (Harold's 3 recorded as waived; Claude Code Dev Team full).
- [x] All 14 categories by each role; no silent lines.
- [x] CODING_VELOCITY exit gate satisfied (every item has a ledger row + actuals).
- [x] Category 13 -> Sprint 43 plan candidates (IMP-1, IMP-2).
- [x] Category 14 -> backlog (IMP-3 + schedule-table consolidation).
- [x] Improvement proposals presented for now-vs-backlog (IMP-1..4).
