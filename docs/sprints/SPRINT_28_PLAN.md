# Sprint 28 Plan

**Sprint**: Sprint 28 - MSIX Sandbox Fix + UX Improvements
**Date**: April 2, 2026
**Branch**: `feature/20260402_Sprint_28`
**Base**: `develop`
**Estimated Total Effort**: ~12-14h

---

## Sprint Goal

Fix the Microsoft Store certification blocker (MSIX sandbox crash at launch) and implement UX improvements from Sprint 27 retrospective feedback.

---

## Background

Microsoft Store certification failed with `File system error (-2015295536)` at app launch. Root cause: `sqfliteFfiInit()` fails inside the MSIX sandbox due to DLL loading/path restrictions. Additionally, hardcoded `%APPDATA%` paths and `Platform.resolvedExecutable` usage cause issues in the virtualized MSIX environment.

UX improvements from Sprint 27 retrospective: remove unnecessary "Scan All Accounts" button, add account selection to Scan History navigation, and reorder Background settings sections.

**Backlog items**: B1 (Issue #218), F49 (Issue #219), F51 (Issue #221)

---

## Tasks

### Task 1: Fix sqflite FFI initialization for MSIX sandbox (~4h)

**Model**: Sonnet
**Execution**: Autonomous
**Issue**: #218 (Task 1)

Evaluate and implement the best approach for sqlite3 to work inside the MSIX sandbox.

**Current state**:
- `main.dart:36` calls `sqfliteFfiInit()` with no parameters
- `main.dart:37` sets `databaseFactory = databaseFactoryFfi`
- Import: `package:sqflite_common_ffi/sqflite_ffi.dart` (line 7)
- `sqlite3` v3.1.4 is already a transitive dependency with build hooks that bundle the DLL

**Options to evaluate**:
- **Option A** (Preferred): Add `sqlite3_flutter_libs` dependency to bundle sqlite3 as a proper Flutter plugin native asset. Keep sqflite API. Least code change.
- **Option B**: Configure `sqfliteFfiInit()` with explicit DLL path pointing to bundled sqlite3.dll
- **Option C**: Replace `sqflite_common_ffi` entirely with `sqlite3` v3.x direct API or `drift`

**Evaluation criteria**: Least code change, best MSIX compatibility, no API migration risk.

**Acceptance Criteria**:
- [ ] sqlite3 DLL loads correctly inside MSIX sandbox
- [ ] Database opens and reads/writes correctly
- [ ] No `.dart_tool/` directory created in read-only install directory
- [ ] Existing sqflite API calls continue to work (no migration needed)
- [ ] `flutter build windows` succeeds
- [ ] `dart run msix:create` succeeds

### Task 2: Replace hardcoded APPDATA paths with path_provider (~2h)

**Model**: Sonnet
**Execution**: Autonomous
**Issue**: #218 (Task 2)

Replace all `Platform.environment['APPDATA']` usage with `AppPaths` methods that use `path_provider`.

**Files to modify** (6 occurrences):

| File | Line | Current Usage | Fix |
|------|------|---------------|-----|
| `lib/main.dart` | 49 | Background scan log path | Use `AppPaths.logsDirectory` |
| `lib/core/services/background_scan_windows_worker.dart` | 30 | Background scan log path | Use `AppPaths.logsDirectory` |
| `lib/core/services/background_scan_windows_worker.dart` | 279 | Excel export directory | Use `AppPaths.logsDirectory` |
| `lib/core/services/app_identity_migration.dart` | 29 | Old app data path | Use `path_provider` `getApplicationSupportDirectory()` |
| `lib/core/services/app_identity_migration.dart` | 35 | New app data path | Use `path_provider` `getApplicationSupportDirectory()` |
| `lib/core/services/dev_environment_seeder.dart` | 28 | App data path | Use `path_provider` `getApplicationSupportDirectory()` |

**Note**: `AppPaths` already has `logsDirectory` (line 167) and `appSupportDirectory` (line 90). The background scan log and worker paths need `AppPaths` to be initialized before use. `main.dart:49` runs before `AppPaths.initialize()`, so we may need to initialize AppPaths earlier or defer the log file creation.

**Acceptance Criteria**:
- [ ] Zero occurrences of `Platform.environment['APPDATA']` in `lib/` directory
- [ ] Background scan log writes to correct path in MSIX and non-MSIX
- [ ] Excel export writes to correct path
- [ ] Legacy app identity migration still works for non-MSIX installs
- [ ] Dev environment seeder still works

### Task 3: Handle Platform.resolvedExecutable in MSIX context (~1h)

**Model**: Sonnet
**Execution**: Autonomous
**Issue**: #218 (Task 3)

Add MSIX detection and adapt Task Scheduler behavior.

**Current state**:
- `windows_task_scheduler_service.dart:259,369` uses `Platform.resolvedExecutable`
- Inside MSIX, this path is under `C:\Program Files\WindowsApps\...` (read-only, changes on updates)
- Task Scheduler registration will fail or point to stale paths after updates

**Fix approach**:
- Add MSIX detection: check if `Platform.resolvedExecutable` contains `WindowsApps`
- If MSIX: skip Task Scheduler registration (MSIX apps should use StartupTask or BackgroundTask APIs)
- Log MSIX detection at startup for diagnostics
- Background scanning in MSIX builds will need a different mechanism (future sprint)

**Acceptance Criteria**:
- [ ] MSIX detected correctly when running from WindowsApps directory
- [ ] Task Scheduler registration skipped in MSIX context (no crash)
- [ ] Non-MSIX builds continue to use Task Scheduler normally
- [ ] Diagnostic log message indicates MSIX vs non-MSIX mode

### Task 4: Build and test MSIX package locally (~2h)

**Model**: Sonnet
**Execution**: Autonomous (with user verification)
**Issue**: #218 (Task 4)

Build MSIX package and verify it works.

**Steps**:
1. Run `flutter build windows --release`
2. Run `dart run msix:create` to build MSIX
3. Install MSIX on local machine
4. Launch app from Start Menu
5. Verify: app launches, database loads, rules load
6. Verify: manual scan starts (read-only mode)
7. Verify: settings screens work
8. Document any remaining issues

**Acceptance Criteria**:
- [ ] MSIX builds successfully
- [ ] App installs from MSIX package
- [ ] App launches without "File system error"
- [ ] Database creates and loads rules
- [ ] Manual scan in read-only mode works
- [ ] Settings screens accessible

### Task 5: Remove "Scan All Accounts" button (~0.5h)

**Model**: Haiku
**Execution**: Autonomous
**Issue**: #219

Remove the "Scan All N Accounts" button from the account selection screen.

**File**: `lib/ui/screens/account_selection_screen.dart`
- Remove button at lines 732-742
- Remove `_scanAllAccounts()` method at lines 396-487
- Clean up any related state/variables

**Acceptance Criteria**:
- [ ] "Scan All N Accounts" button no longer appears
- [ ] Individual account "Start Scan" buttons still work
- [ ] No dead code remaining from removed feature

### Task 6: Add account selection dialog to View Scan History + show account in history (~2h)

**Model**: Haiku
**Execution**: Autonomous
**Issue**: #219

Two changes:
1. On the Account Selection screen, the "View Scan History" AppBar button should show the same account selection dialog as the "Settings" button (pattern at `_openSettings()` lines 511-559), then navigate to `ScanHistoryScreen` with the selected `accountId` and `accountEmail`.

2. Update `ScanHistoryScreen` to show the account email in the title when filtered by account.

**Files**:
- `lib/ui/screens/account_selection_screen.dart` — modify `_buildHistoryButton()` (lines 571-584) to show dialog
- `lib/ui/screens/scan_history_screen.dart` — update title from static "Scan History" (line 100) to `"Scan History - ${widget.accountEmail}"` when account is provided

**Current patterns**:
- `ScanHistoryScreen` constructor already accepts `accountId`, `accountEmail`, `platformId`, `platformDisplayName`
- `_openSettings()` already shows the account selection dialog pattern to reuse
- `ResultsDisplayScreen` already shows account in title: `"Results - ${widget.accountEmail} - ${widget.platformDisplayName}"` (line 483)

**Acceptance Criteria**:
- [ ] View Scan History on account selection screen shows account selection dialog
- [ ] After selecting account, navigates to Scan History filtered for that account
- [ ] Scan History title shows account email when filtered (e.g., "Scan History - kimmeyharold@aol.com")
- [ ] Cancel in dialog returns to account selection (no navigation)
- [ ] Other View Scan History buttons (from Settings, Results) continue to work

### Task 7: Reorder Background settings - Scan Mode above Default Folders (~0.5h)

**Model**: Haiku
**Execution**: Autonomous
**Issue**: #221

In `_buildBackgroundScanTab()` (settings_screen.dart lines 633-711), move the Scan Mode section (lines 689-697) above the Default Folders section (lines 679-687) to match the Manual Scan tab order.

**Desired order** (matching Manual Scan tab):
1. Enable Background Scanning (checkbox)
2. Test (test button, scan history link)
3. Frequency (dropdown)
4. **Scan Mode** (moved up from position 6)
5. Scan Range (slider)
6. Default Folders (folder chips)
7. Debug (CSV export checkbox)

**Acceptance Criteria**:
- [ ] Scan Mode section appears before Default Folders on Background tab
- [ ] Section order matches Manual Scan tab (Mode, Range, Folders)
- [ ] All settings still save and load correctly

---

## Risks

| Risk | Mitigation |
|------|------------|
| sqlite3_flutter_libs may not fully resolve MSIX DLL loading | Test Option B (explicit path) as fallback |
| MSIX testing requires local install which may conflict with dev build | Use separate test account or VM |
| Background scanning disabled in MSIX may frustrate Store users | Document as known limitation; implement MSIX-native background in future sprint |
| Removing Scan All Accounts may break multi-account scan results references | Search for any code that depends on multi-account scan flow |

---

## Test Plan

- [ ] `flutter test` — all existing tests pass
- [ ] `flutter analyze` — 0 issues
- [ ] `flutter build windows` — succeeds
- [ ] `dart run msix:create` — MSIX builds
- [ ] MSIX install and launch — no crash
- [ ] Manual scan in read-only mode — works from MSIX
- [ ] Account selection screen — no "Scan All" button, Scan History shows dialog
- [ ] Scan History — shows account email in title
- [ ] Background settings — Scan Mode above Default Folders
- [ ] Windows build (non-MSIX) — all features still work
