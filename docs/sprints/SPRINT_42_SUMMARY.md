# Sprint 42 Summary

> **NOTE (Sprint 57 doc-audit, 2026-08-14)**: This summary was not found in the repository during a repo-wide sprint-documentation audit and has been reconstructed retroactively from PR #263's body/commits and the existing `SPRINT_42_PLAN.md` / `SPRINT_42_RETROSPECTIVE.md`. Figures not recoverable from those sources are not included rather than invented.

**Branch**: `feature/20260620_Sprint_42`
**PR**: [#263](https://github.com/kimmeyh/spamfilter-multi/pull/263)
**Issues**: none tracked via GitHub Issues (scope tracked as F99 / F98 / BUG-S37-2 backlog items in `ALL_SPRINTS_MASTER_PLAN.md`)
**Dates**: 2026-06-20 (planning, execution, and manual testing all same day) -> merged 2026-06-23
**Retrospective**: `docs/sprints/SPRINT_42_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | +1656 ~28 (per PR body / retrospective); `flutter test` all passing |
| Analyzer | Clean |
| integration_test | 5 test files, all green per-file |
| Manual Validation | Complete (Harold, 2026-06-20) |
| Carry-forward | None |

## Scope

Approved 2026-06-20: F99 -> F98 -> BUG-S37-2, in that order (F99 first to land regression coverage before the F98 multi-surface refactor).

| Item | Feature | Result |
|---|---|---|
| 1 | F99 -- Flutter `integration_test` E2E harness (pre-MVP) | DONE -- harness + 5 test files green |
| 2 | F98 -- Per-account background scanning (ADR-0039) | DONE -- all 23 ADR change-sites + migration, plus 2 manual-testing fixes |
| 3 | BUG-S37-2 -- Bundled-rule TLD data quality | DONE -- audit found list already complete; removed 2 typos |

## What shipped

**F99 -- `integration_test` E2E harness.** A second, in-VM E2E lane alongside WinWright's out-of-process UIA lane, absorbing three previously-deferred items: F76 (visual/layout regression), F56 (rule/safe-sender create-delete lifecycle), and F37 (folder picker) -- flows WinWright could not run reliably. Key mechanism: `AppPaths.testOverrideBaseDir`, a new test seam, was required because `RuleSetProvider.initialize()` builds its own `AppPaths()` and `path_provider` has no MethodChannel on Windows desktop, so neither `setAppPaths()` nor channel-mocking isolates the app from the real data directory. Two boot modes ship: `bootDbOnly` (fresh seeded temp DB) and `bootAppWithDevDbCopy` (copies the dev DB, deletes on teardown) -- neither ever touches the live dev DB once the harness stabilized. Five test files (boot smoke, block-rule lifecycle, safe-sender lifecycle, folder picker, layout-bounds) all pass. `run-integration-tests.ps1` runs one `flutter test` process per file (Harold's direction) to isolate process-wide singletons. The two-harness strategy (WinWright read-only + integration_test write/lifecycle/visual) is documented in `TESTING_STRATEGY.md`.

**F98 -- Per-account background scanning (ADR-0039).** Background scanning moved from one global schedule to one OS-scheduled entry per enabled account, implementing all 23 active change-sites from the ADR's inventory plus a one-time migration. Surfaces touched: CLI (`--background-scan --account-id=<id>`), Windows Task Scheduler (per-account entries), Android WorkManager (per-account unique tasks), the Settings toggle/frequency UI (now per-account), and per-account log/CSV output. The migration preserves existing behavior (global ON becomes every account inheriting enabled), is idempotent and sentinel-guarded, and does not use `ALTER TABLE`. The work also fixed a latent Android bug where the worker read a dead settings key (`background_scan_enabled`) that no longer matched the writer's key (`background_enabled`). Two fixes came out of manual testing: Test Background Scan now scopes to the current account, and DB-lock resilience was added for concurrent per-account scans (WAL mode, `busy_timeout=30s`, worker retry at 1-minute intervals up to 20 attempts, and Windows/Android start-time jitter).

**BUG-S37-2 -- Bundled TLD data quality.** An audit of the existing ccTLD blocklist found it already covered 247 of 248 IANA ccTLDs, so Harold's direction (1c) was no expansion or allow-list change was needed. Two data typos, `.sho` and `.sweeps`, were removed via a DB v7 migration plus the corresponding YAML edit (Harold 2a).

**PR #263 Copilot review follow-ups** (post-merge-prep, pre-merge): redacted PII in F98 logs plus three smaller fixes; temp-dir cleanup and null-safe session handling in the integration_test harness; smoke test changed to count rules via `COUNT(*)` rather than a fragile alternative.

## Found during Manual Validation

- F98's per-account "Test Background Scan" action was not scoped to the currently selected account -- fixed to scope correctly.
- Concurrent per-account background scans could hit SQLite DB locks -- addressed with WAL mode, a 30-second busy timeout, worker retry (20 attempts at 1-minute spacing), and randomized start-time jitter on both Windows (Task Scheduler `-RandomDelay`) and Android (WorkManager random initial delay).

## Retrospective improvements

| ID | Improvement | Disposition |
|---|---|---|
| IMP-1 | Guard so a write-capable test/harness asserts its resolved data path is under the OS temp root before any write (prevents F99-style dev-DB contamination) | Now |
| IMP-2 | Make the F98 DB-lock retry bound (20 min worst case) configurable/shorter if long hangs are observed | Backlog |
| IMP-3 | Incrementally port remaining WinWright read-only flows to `integration_test` | Backlog |
| IMP-4 | Model-pitfall memory: assert test-isolation data path resolves to a temp dir before first write-capable run | Now (applied) |
| IMP-5 | Strengthen architecture-docs-no-defer discipline: update ARCHITECTURE.md/ARSD.md/ADR index before manual-testing handoff, not after | Now (checklist line) |
| IMP-6 | Author a short ADR for the F99 two-harness E2E testing decision | Backlog |
| IMP-7 | Memory: never presume Harold's Phase 7 feedback is waived by a manual-testing sign-off; always ask | Now |

## Lessons worth carrying

1. **Design-first ADRs are the biggest estimation lever.** F98, the sprint's largest item, landed closest to estimate specifically because ADR-0039 pre-itemized all 23 change-sites; F99 (no equivalent design doc) ran roughly 1.5x its estimate.
2. **Verify the blast radius before the first write-capable run.** F99's DB-isolation work went through three attempts before finding a seam that actually isolated the app, and one early attempt wrote to the live dev DB -- caught only by grepping the resolved DB path from the log, not by trusting a passing test.
3. **A manual-testing sign-off is not a retrospective-feedback waiver.** An early retrospective draft presumed Harold's "manual testing complete" note excused Phase 7 role feedback; it did not, and Harold corrected this before giving full verbatim feedback.
4. **Architecture docs must be updated before manual-testing handoff, not caught by the PO at retro.** Harold's Category 12 check found `ARCHITECTURE.md` stale on both F98 (still described the old global-schedule model) and F99 (two-harness strategy undocumented); both were fixed during the retrospective itself rather than in-process.
