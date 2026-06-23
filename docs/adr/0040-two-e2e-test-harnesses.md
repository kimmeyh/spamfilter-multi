# ADR-0040: Two E2E Test Harnesses -- WinWright (UIA) + Flutter `integration_test`

## Status

Accepted

## Date

2026-06-21 (documenting the F99 decision from Sprint 42; harness shipped 2026-06-20)

## Context

The desktop app's end-to-end (E2E) UI testing has, since Sprint 27, used a single
harness: **WinWright** (civyk-winwright), which drives the running Windows app
**out of process** through the Windows UI Automation (UIA/MSAA) accessibility
tree. It is good for true end-to-end coverage on a real window and for
accessibility verification.

During Sprint 41 (F97/F76) and the F99 investigation, WinWright proved
**structurally unreliable for any flow that crosses a Flutter dialog/picker
animation-settle boundary**:

- The `winwright run` script-runner has no wait/assert primitive, so a step that
  fires before an animated element (a confirm dialog's "Save" button, a folder
  picker's search field) is in the UIA tree resolves zero elements and fails.
- The standalone WinWright CLI cannot read element bounds at all (no
  `get_attribute`; `inspect` JSON carries no bounds; `run` rejects
  `ww_get_attribute`/`ww_assert*`), so layout-regression checking (F76) was not
  implementable on it.
- Out-of-process automation is additionally exposed to cursor/`SetCursorPos` and
  DPI quirks on high-resolution displays.

A tool-fit investigation (Sprint 41) confirmed that **Playwright is not a
candidate** -- it drives the browser DOM and cannot see a native Flutter desktop
widget tree. The legitimate complement is **Flutter's own `integration_test`**,
which drives the real widget tree **in the Dart VM** by `Key`/`Finder` with
`pumpAndSettle()` -- deterministic and immune to the entire UIA-exposure /
settle-race / cursor / DPI failure class.

## Decision

Run **two complementary E2E harnesses**, not one, and not a replacement:

1. **WinWright (out-of-process UIA)** -- retained for read-only navigation and
   accessibility-tree coverage on the real window (the 6 stable read-only
   scripts). Runner: `scripts/run-winwright-tests.ps1` with a pre/post DB-snapshot
   drift guard.

2. **Flutter `integration_test` (in-VM)** -- the robust lane for anything that
   crosses a dialog/picker-settle boundary or writes to the DB: rule + safe-sender
   create/delete lifecycle (was F56), folder picker (was F37), and layout-bounds
   regression (was F76). Runner: `scripts/run-integration-tests.ps1`.

Supporting decisions:

- **Per-file process isolation**: `run-integration-tests.ps1` runs each
  `integration_test/*_test.dart` in its **own `flutter test` process**. The app's
  process-wide singletons (`DatabaseHelper`, the fire-and-forget
  `RuleSetProvider.initialize()` async tail) bleed across files in a single shared
  process; per-file processes are the standard Flutter isolation pattern for
  stateful apps. Within a file, multiple `testWidgets` share one process and reset
  via the harness -- there is no app shutdown between tests.
- **DB isolation via a production test seam**: `AppPaths.testOverrideBaseDir` (a
  static field, null in production) makes the whole app resolve its data dir to an
  isolated temp dir, because the app self-initializes its own `AppPaths` and
  path_provider has no MethodChannel on Windows desktop (so neither
  `DatabaseHelper.setAppPaths()` nor channel-mocking isolates). The harness
  hard-asserts the resolved DB path is under the OS temp root before any write.
- A second seam, `FolderSelectionScreen.debugFoldersOverride`, lets the folder
  picker run headless without a live IMAP account.

## Consequences

### Positive
- The create/delete lifecycle, folder-picker, and layout-regression flows now run
  **deterministically** in-VM -- the flows WinWright could not run reliably.
- DB isolation means the in-VM lane **cannot** touch the dev/prod DB.
- Layout-regression coverage (the F76 goal) is delivered via `RenderBox`/bounds
  assertions -- immune to the anti-aliasing/DPI noise that makes pixel-diff goldens
  flaky for Flutter-on-DirectX.

### Negative / cost
- Two harnesses to maintain. Mitigated by clear "which to use when" guidance in
  `docs/TESTING_STRATEGY.md` and the long-term direction (see Out of Scope) of
  migrating WinWright read-only flows to `integration_test`.
- Two production test seams exist (`AppPaths.testOverrideBaseDir`,
  `FolderSelectionScreen.debugFoldersOverride`). Both are null/absent in
  production and documented; same category as the pre-existing `TestAppPaths`.
- `integration_test` on Windows desktop needs a display/session, so it runs in the
  local cadence today (not a headless CI runner yet).

### Out of scope (future candidates)
- Incrementally porting the WinWright read-only flows to `integration_test` so the
  in-VM lane becomes primary, retiring WinWright scripts as each is covered
  (Sprint 42 retro IMP-3, backlog).
- A headless CI runner for the `integration_test` lane (ties to F64, HOLD).

## References
- `docs/TESTING_STRATEGY.md` -- "Two E2E Harnesses" section (when to use which,
  per-file execution model, test seams).
- `docs/ARCHITECTURE.md` -- Testing Strategy section.
- F99 (`docs/ALL_SPRINTS_MASTER_PLAN.md`) and Sprint 42 retrospective.
