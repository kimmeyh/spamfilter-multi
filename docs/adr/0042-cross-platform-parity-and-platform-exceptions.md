# ADR-0042: Cross-platform parity -- same everywhere, with explicit minimal platform exceptions

**Status**: PROPOSED -- awaiting Chief Architect (Harold) approval. Sprint 61 Task 6 (F162) stops here by prior agreement; Harold approved this one mid-sprint stop as a scoped exception on 2026-08-17.
**Sprint**: 61
**Related**: ADR-0035 (production/development side-by-side), ADR-0037 (UI accessibility standards), ADR-0038 (content management for long strings), ADR-0039 (per-account background scanning), ADR-0041 (environment propagation)

## Context

The project ships one Flutter codebase to Windows and Android (with iOS/macOS/Linux architecturally supported but unvalidated). Until now, "how much should these platforms match?" was answered case by case, in code review or not at all. That produced two failure modes, both observed:

**1. Silent divergence in SHARED code, masked by one platform.** In Sprint 60, `scan_results` had a foreign key to `accounts`, but the ONLY code creating the accounts row lived in the WINDOWS background-scan worker. Windows exercised that path every 15 minutes, so it looked healthy for months. On Android nothing created the row, every interactive scan's persistence failed the FK, the error was caught and logged, and scans completed with **no history, no email actions, and no no-rule items**. The defect was in shared architecture; only the platform coverage was uneven. This is why parity is not a UI concern.

**2. Unmarked platform forks.** The repo currently has ~51 `Platform.is*` references across 12 files. Most are legitimate (Windows Task Scheduler, system tray, Win32 toast notifications, OAuth handlers, path separators). But nothing distinguished "this platform genuinely cannot do it" from "nobody got around to the other platform". In Sprint 61, `scan_history_screen` still gated the Review No Rule Items shortcut behind `Platform.isWindows` with a comment claiming that was "consistent with the other Review entry points" -- F143 had un-gated every other entry point a sprint earlier, leaving that comment actively misleading.

Harold stated the governing rule on 2026-08-17 while scoping Sprint 61, and asked that it be captured as an ADR.

## Decision

**Functionality and UI are the SAME on both platforms unless they cannot be. Where they cannot be, the difference is implemented as an explicit, minimal PLATFORM EXCEPTION covering only what is actually needed.**

This applies to **all layers**: backend code, frontend code, data, architecture, development, security, testing, and deployment. It is not a UI-only rule.

### What counts as "cannot be"

A platform exception is justified only when the platform genuinely cannot support the shared behavior:

- **The API does not exist**: Windows Task Scheduler, the Win32 system tray, Android WorkManager.
- **The platform convention conflicts**: touch long-press versus desktop Ctrl+click (F143); path separators.
- **A platform policy forbids it**: runtime permission models, store requirements.
- **The hardware/form factor makes it meaningless**: window resizing on a phone.

Not justified: "we only tested Windows", "the Android version came later", "it was easier", or an unexamined assumption that a feature is desktop-only.

### How an exception is implemented

1. **Fork at the narrowest possible point.** Prefer one platform-conditional line inside a shared widget or service over a parallel implementation. Eight screens do not get eight edits when one shared builder serves them.
2. **Declare it in a comment that names WHAT cannot be shared and WHY.** A reader must never have to guess whether a fork was deliberate. A fork whose comment has gone stale is a defect (see the `scan_history_screen` case above).
3. **Prefer the testable seam.** Where a fork is behavioral, read the platform through an injectable seam (`Theme.of(context).platform`) rather than `dart:io Platform`, so both branches can be tested. F143 established this pattern precisely because the global override trips a test invariant.
4. **Cover BOTH branches with tests.** A cross-platform behavior needs coverage proving the platform branch AND the guard that the other platform is unchanged. F143's touch-selection tests assert the touch branch and a desktop no-regression guard in the same file.
5. **Degrade, do not disappear.** Where a shared element does not fit a platform's form factor, prefer graceful degradation over silent absence, and pin the threshold with a test (F172's version label is suppressed below 600px, with a test proving it survives at the Windows minimum).

### Deliberate non-parity, recorded

Two divergences are accepted and are NOT defects:

- **Background scan scheduling**: Windows uses per-account Task Scheduler tasks (ADR-0039). Android has no equivalent today; F161 implements the WorkManager mirror. Until it lands, Android UI must not promise background scanning (Sprint 61 Task 3 coordinates the wording).
- **Store/release path**: the Microsoft Store release (Phase 8.3 of the Release Cycle) covers the Windows app. The Google Play track is a separate future path (F94, GP-*).

## Consequences

- Every future cross-platform decision cites this ADR rather than being re-litigated; divergences found in audits are filed as items referencing the rule they violate.
- Existing `Platform.is*` forks are grandfathered, not retroactively rewritten. They are reviewed opportunistically when their file is touched -- a sweeping rewrite would carry more regression risk than value.
- The rule creates real work: a shared-code change must be verified on both platforms, not just the one at hand. That cost is the point, given failure mode 1 above cost months of silent Android data loss.
- Testing burden rises for behavioral forks (both branches), which is the smallest reliable way to prevent a fork drifting into a one-platform feature.

## Open question for the Chief Architect

Whether to add a policy gate asserting that every `Platform.is*` fork in `lib/` carries an explanatory comment. It is cheaply assertable but would be noisy against the ~51 grandfathered sites, so Sprint 61 records it as deliberately unwatched pending this decision.
