# Sprint 56 Summary

**Branch**: `feature/20260812_Sprint_56`
**PR**: [#310](https://github.com/kimmeyh/spamfilter-multi/pull/310)
**Issues**: #309
**Dates**: 2026-08-12 -> 2026-08-13
**Retrospective**: `docs/sprints/SPRINT_56_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1,857 passing / 0 failing / 29 skipped (unchanged -- no automated seam exists for this bug class) |
| Analyzer | Clean |
| Windows build | Green |
| Manual Validation | Complete (Harold) -- working as expected |
| Store release | 0.6.1.0 built + submitted same sprint (Submission 12) |
| Carry-forward | None |

## Scope

Approved 2026-08-12 as the sole sprint item, per Harold's explicit instruction after a live production bug report: F148 only.

| Task | Feature | Result |
|---|---|---|
| 1 | F148 | Background-scan scheduled tasks now survive Store version updates via a stable MSIX App Execution Alias |

## What shipped

**F148 -- background-scan Store-update survival.** Found live in production 2026-08-12 (Harold): after a Store update from 0.6.0.0 to 0.6.1.0, both accounts' background-scan scheduled tasks failed with `ERROR_FILE_NOT_FOUND`. Root cause: task registration used `Platform.resolvedExecutable`, a VERSIONED install path Windows deletes on every Store update. Immediate fix: both tasks manually repointed via PowerShell same-day to restore scanning. Durable fix (Harold steered toward a version-independent design rather than a heal-after-the-fact repair): registered tasks against a stable MSIX App Execution Alias (`myemailspamfilter.exe`, resolves via `%LOCALAPPDATA%\Microsoft\WindowsApps\`) that Windows keeps pointed at whichever version is currently installed. Existing installs on a stale versioned-path registration self-heal via the existing `verifyAndRepairTaskPath()` reconciliation, re-enabled for MSIX installs (previously excluded on a since-disproven belief that Task Scheduler could not launch via an alias).

**Validation.** R-1 spike proved Task Scheduler can launch an app via its MSIX App Execution Alias directly, contradicting some third-party reports. Real simulated Store update: built and installed a test MSIX at version N, confirmed the alias-registered task launched N; built and installed version N+1 over it (`Add-AppxPackage` in-place replace); confirmed the SAME unchanged task now launched N+1 automatically with log-file proof, no code intervention.

**GitHub Copilot review follow-up (PR #310).** One real finding: `_getWorkingDirectory()` still resolved to the versioned install directory for MSIX installs, so the task's `-WorkingDirectory` would have gone stale on the next Store update even though `-Execute` was already fixed. Fixed by mirroring the same alias-resolution pattern; validated against a real MSIX install with both `-Execute` and `-WorkingDirectory` alias-based.

**Store release (same sprint).** 0.6.1.0 built, verified, and submitted to Partner Center (Submission 12) carrying F148 -- certified and live shortly after, later superseded same-week by 0.6.2.0 (Submission 13, Sprint 57).

## Retrospective

All 14 categories rated Very Good. 1 improvement, applied: a `CLAUDE.md` pre-flight rule requiring a check of what `APP_ENV` independently controls before using `APP_ENV=prod` in a non-release test build -- sourced from a self-caught near-miss during T-3 validation where a test build briefly wrote a benign log into the real production data directory.

## Merge

PR #310 merged to `develop` 2026-08-13 (Harold). Issue #309 closed by hand during Post-Merge Cleanup (verified via `gh issue list --label sprint --state open` returning empty). Sprint 57 branch opened via Phase 6.6 carry-forward immediately on merge notification.
