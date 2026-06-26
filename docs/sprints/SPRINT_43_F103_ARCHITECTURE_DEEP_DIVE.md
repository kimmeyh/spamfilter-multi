# Sprint 43 F103 -- Periodic Architecture Deep Dive (findings)

**Run of the F71 reusable template** against the codebase at Sprint 43.
**Date**: 2026-06-23. **Scope**: ADR drift, ARCHITECTURE.md / ARSD.md alignment, platform-architecture, dead-code / deprecated-class detection, test-coverage-vs-architecture gaps.

**Outcome**: the architecture is in good health -- the Sprint 42 retro (Category 12) already forced an ARCHITECTURE.md refresh and ADR-0040 was authored, so most docs are current. Findings below are small; trivial ones fixed this sprint, the rest surfaced for the Chief Architect / backlog.

---

## 1. ADR drift (40 ADRs vs implementation)

| ADR | Finding | Disposition |
|-----|---------|-------------|
| Index (README) | 40 ADR files, 40 index rows -- **in sync**. ADR-0039 (Accepted) + ADR-0040 (Accepted) present and dated. | OK |
| **ADR-0037** (UI/Accessibility Standards) | Status is **"Proposed (pending user review)"**, but `AccessibilityHelper` + `Semantics(` are in active use across 3+ UI files -- the standards ARE implemented. Status appears stale. | **SURFACE (Class-1)**: status change is a Chief-Architect call. Recommend Harold reviews -> Accepted. Not auto-changed. (Backlog note F107.) |
| ADR-0039 (per-account bg-scan) | Implemented in F98 exactly as designed; ARCHITECTURE.md bg-scan flow updated to match (Sprint 42 Cat-12 fix). | OK |
| ADR-0040 (two E2E harnesses) | Matches F99 implementation (per-file runner, AppPaths.testOverrideBaseDir + debugFoldersOverride seams). | OK |
| ADR-0013 (per-account settings) | F98 added `background_frequency` per-account key via the same inheritance pattern -- consistent. | OK |
| ADR-0030 (privacy/data governance) | Extended this sprint (F102) with the Logging & Redaction section -- now matches the enforced gate. | OK |

## 2. ARCHITECTURE.md / ARSD.md alignment

- **ARCHITECTURE.md**: current (refreshed Sprint 42 Cat-12; F102 added the redaction layer this sprint). Background-scan flow, two-harness testing section, ccTLD line all match code. **OK.**
- **ARSD.md**: BR-6 cites ADR-0039 (updated Sprint 42). Version still marked "1.0 (Draft)" and it defers current-state to CHANGELOG -- acceptable for a requirements-standards doc. **Minor**: consider promoting from "Draft" once the requirement set stabilizes. (Backlog, low.)

## 3. Platform-architecture

- **Windows**: MSIX packaging, single-instance mutex, env-aware app-data paths (ADR-0035) -- all present and consistent. Per-account Task Scheduler (F98) matches ADR-0039. **OK.**
- **Android**: per-account WorkManager (F98) matches ADR-0039; flavors still deferred (F94, HOLD, gated on Firebase/GCP). **OK (deferral is documented).**
- **iOS / Linux / macOS**: architecture supports them (AppPaths is platform-agnostic) but unvalidated -- a known, documented limitation (F67/F95 HOLD). **OK.**

## 4. Dead-code / deprecated-class detection

| Item | Finding | Disposition |
|------|---------|-------------|
| `outlook_adapter.dart` | 9 `UnimplementedError` stubs. **NOT dead code** -- it is the intentional placeholder for H5 (Outlook adapter, HOLD/backlog). Keep. | OK (tracked H5) |
| `background_scan_schedule` table | Still unread by the live path (only `data_deletion_service` clears it). Known per ADR-0039 Option A; documented future-consolidation candidate. | OK (no action; consolidation is a future ADR) |
| `@deprecated` markers | None found needing removal. | OK |

## 5. Test-coverage vs architecture

- New Sprint-42 services (`PerAccountBgMigration`, `sanitizeAccountId`) **are** covered (`per_account_bg_scan_test.dart`, 12 tests). F99 harness has 5 integration_test files. F102 added the redaction-gate test. **No new gap.**
- 109 test files; suite green at +1658 ~28.
- **Minor gap (pre-existing)**: `outlook_adapter` has no tests -- expected (stub; tests come with H5).

---

## Findings disposition summary

- **Fixed this sprint (trivial)**: none required code changes -- the deep dive found no trivial code defects (the architecture docs were already refreshed in Sprint 42, and F102 handled the redaction layer).
- **Surfaced to Chief Architect (Class-1)**: ADR-0037 status appears stale (Proposed -> should likely be Accepted, since the accessibility standards are implemented). Filed as **F107** (backlog) for Harold's decision -- not auto-changed.
- **Backlog (low)**: ARSD.md "1.0 (Draft)" -> consider promoting once requirements stabilize (rolled into F107 / next architecture review).
- **No dead code to remove**; no ADR-vs-code contradictions; no new test gaps.

**Conclusion**: architecture is healthy and docs are current. The one real drift item (ADR-0037 status) is surfaced for Harold rather than auto-resolved (Class-1).
