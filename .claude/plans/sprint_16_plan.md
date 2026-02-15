# Sprint 16 Plan: UX Polish, Scan Configuration, and Rule Intelligence

**Sprint Number**: 16
**Branch**: `feature/20260215_Sprint_16`
**Start Date**: February 15, 2026
**Status**: PLANNING
**Estimated Total Effort**: 25-35 hours

---

## Sprint Objective

Address user testing feedback from Sprint 15: add persistent days-back scan configuration for both manual and background scans, simplify scan UI by removing redundant controls, add background scan log viewer, and implement rule override detection to warn users of conflicts.

---

## Sprint Scope Summary

| Priority | Issue | Title | Effort | Model |
|----------|-------|-------|--------|-------|
| 1 | #153 | Days back / All emails setting for Manual and Background scans | 4-6h | Haiku |
| 2 | #150 | Scan Options default to "Scan all emails" with days slider | 3-4h | Haiku |
| 3 | #151 | Rename Scan Progress to Manual Scan, remove folder selector | 2-3h | Haiku |
| 4 | #152 | Background scan log viewer | 8-10h | Haiku |
| 5 | #139 | Rule override detection | 8-12h | Sonnet |

**Total Estimated**: 25-35 hours

**Deferred to Sprint 17**: #149 (Manage Rules UI overhaul - split, search, filter)

---

## Execution Order and Rationale

### Group A: Scan Configuration (Issues #153, #150, #151) - Do Together

These three issues are tightly coupled and should be executed in sequence. They all touch the scan options flow and settings storage.

**Dependency**: #153 must complete before #151 (per user requirement). #150 is closely related to #153 (both deal with days-back UX).

**Order**:
1. **#153** first - Add persistent days-back settings to SettingsStore and Settings UI for both Manual and Background tabs
2. **#150** second - Update Scan Options dialog to default to "Scan all emails" and use the new persistent setting from #153
3. **#151** third - Rename screen, remove folder selector (depends on #153 being done so manual scans pull all config from Settings)

### Group B: Background Scan Log Viewer (Issue #152) - Independent

Independent of all other issues. Builds on existing background scan infrastructure from Sprint 15.

### Group C: Rule Override Detection (Issue #139) - Independent

Independent research and implementation. Uses Sonnet for the conflict detection algorithm design.

---

## Issue #153: Days Back / All Emails Setting for Manual and Background Scans

**Priority**: 1 (FIRST - blocks #151)
**Type**: Enhancement
**Estimated Effort**: 4-6 hours
**Model**: Haiku

### Problem Statement

The "days back" scan setting is currently ephemeral (only in the Live Scan dialog, lost after each scan). Background scan hardcodes 7 days with no user control. Users need persistent, configurable days-back settings for both scan types.

### Current State

- Manual scan: Days-back selected via `_ScanOptionsDialog` each time (ephemeral, defaults to 7)
- Background scan: Hardcoded to 7 days in `EmailScanner.scanInbox()` default parameter
- SettingsStore: No `daysBack` keys exist for either manual or background scans
- No per-account override for days-back

### Tasks

#### Task 153.A: Add Days-Back Settings to SettingsStore
- Add keys: `keyManualScanDaysBack`, `keyBackgroundScanDaysBack`
- Add per-account override keys: `manual_days_back`, `background_days_back`
- Value 0 = "All emails" (no date filter), 1-90 = days back
- Default: 0 (all emails) for manual, 7 for background
- Add getter/setter methods following existing pattern (e.g., `getManualScanDaysBack()`, `setManualScanDaysBack()`)
- Add per-account methods: `getAccountManualDaysBack()`, `getAccountBackgroundDaysBack()`

#### Task 153.B: Add Days-Back UI to Settings > Manual Scan Tab
- Add "Scan Range" section with:
  - "Scan all emails" checkbox (checked = daysBack 0)
  - Days slider (1-90 days, default 7) visible below
  - If checkbox on: slider value ignored, scan all emails
  - If checkbox off: use slider value
- Persist selection to SettingsStore

#### Task 153.C: Add Days-Back UI to Settings > Background Scan Tab
- Same UI pattern as Manual tab
- Default: 7 days (background scans should not default to all emails)
- Persist selection to SettingsStore

#### Task 153.D: Wire Background Scan to Use Setting
- Update `BackgroundScanWindowsWorker` to load days-back from SettingsStore
- Replace hardcoded 7-day default with configured value
- Pass `daysBack` to `scanner.scanInbox()`

#### Task 153.E: Wire Manual Scan to Use Setting
- Update `ScanProgressScreen._startRealScan()` to load days-back from SettingsStore as default
- Pre-populate `_ScanOptionsDialog` with saved value instead of hardcoded 7

#### Task 153.F: Testing
- Unit tests for new SettingsStore methods
- Verify background scan uses configured days-back
- Verify manual scan dialog pre-populates from Settings

### Acceptance Criteria

- [ ] Settings > Manual has days back / all emails toggle with slider
- [ ] Settings > Background has days back / all emails toggle with slider
- [ ] Manual scan dialog pre-populates from saved setting
- [ ] Background scans use configured setting instead of hardcoded 7
- [ ] Per-account override supported for both scan types
- [ ] All existing tests pass

### Files Affected

- `mobile-app/lib/core/storage/settings_store.dart` - New keys and methods
- `mobile-app/lib/ui/screens/settings_screen.dart` - New UI sections
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Pre-populate dialog
- `mobile-app/lib/core/services/background_scan_windows_worker.dart` - Use setting

---

## Issue #150: Scan Options Default to "Scan All Emails" with Days Slider

**Priority**: 2
**Type**: Enhancement
**Estimated Effort**: 3-4 hours
**Model**: Haiku

### Problem Statement

The Scan Options popup defaults to 7 days. It should default to "Scan all emails" and use the persistent setting from #153.

### Current State

- `_ScanOptionsDialog` in `scan_progress_screen.dart` has `int _daysBack = 7` hardcoded
- "Scan All" checkbox exists but is unchecked by default
- No connection to SettingsStore

### Tasks

#### Task 150.A: Update Dialog Defaults
- Load saved manual days-back from SettingsStore (from #153)
- If saved value is 0: default checkbox to checked ("Scan all emails")
- If saved value is 1-90: default slider to that value, checkbox unchecked
- Slider defaults to 7 when checkbox is checked (visual only)

#### Task 150.B: Interaction Logic
- If user clicks slider: uncheck "Scan all emails", use slider value
- If user re-checks "Scan all emails": slider value ignored, return 0
- On dialog OK: save selection back to SettingsStore for next time

#### Task 150.C: Testing
- Test dialog loads from SettingsStore
- Test interaction between checkbox and slider
- Test saved value persists for next dialog open

### Acceptance Criteria

- [ ] Scan Options dialog defaults from saved setting (from #153)
- [ ] First-time default is "Scan all emails" (checkbox checked)
- [ ] Slider interaction unchecks "Scan all emails"
- [ ] Re-checking "Scan all emails" overrides slider
- [ ] Selection persists for next dialog open

### Files Affected

- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Dialog update

---

## Issue #151: Rename Scan Progress to Manual Scan and Remove Folder Selector

**Priority**: 3 (after #153)
**Type**: Enhancement
**Estimated Effort**: 2-3 hours
**Model**: Haiku

### Problem Statement

"Scan Progress" name is confusing. The folder selector on this screen is redundant now that Settings > Manual tab has folder configuration.

### Current State

- Screen title: "Scan Progress"
- "Select Folders to Scan" button opens FolderSelectionScreen as bottom sheet
- Manual scans already load folders from Settings > Manual tab (implemented in Sprint 14)

### Tasks

#### Task 151.A: Rename Screen
- Change title from "Scan Progress" to "Manual Scan"
- Update any navigation references to the screen name
- Update AppBar text

#### Task 151.B: Remove Folder Selector
- Remove "Select Folders to Scan" button
- Remove folder selection bottom sheet logic
- Manual scans always use folders from Settings > Manual > Selected Folders
- Keep the folder display (show which folders will be scanned, from Settings)

#### Task 151.C: Testing
- Verify screen title shows "Manual Scan"
- Verify no folder selection UI present
- Verify scans use Settings > Manual > Selected Folders

### Acceptance Criteria

- [ ] Screen title shows "Manual Scan" instead of "Scan Progress"
- [ ] No folder selection UI on the scan screen
- [ ] Manual scans use Settings > Manual > Selected Folders
- [ ] All existing tests pass

### Files Affected

- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Rename, remove folder UI

---

## Issue #152: Background Scan Log Viewer

**Priority**: 4
**Type**: Enhancement
**Estimated Effort**: 8-10 hours
**Model**: Haiku

### Problem Statement

Users have no way to review background scan history from within the app. Background scans run silently with no visibility into results.

### Current State

- Background scans log to file via `AppLogger`
- Debug CSV export writes scan results CSV after each run (added Sprint 15)
- No in-app UI to view scan history
- No persistent storage of scan run metadata

### Tasks

#### Task 152.A: Background Scan Log Storage
- Create `BackgroundScanLog` model:
  - `id`, `accountId`, `startTime`, `endTime`, `status` (success/error/partial)
  - `foldersScanned`, `emailsFound`, `emailsProcessed`
  - `deletedCount`, `movedCount`, `safeCount`, `noRuleCount`, `errorCount`
  - `daysBack`, `scanMode`
- Create database table `background_scan_logs`
- Write log entry at end of each background scan run

#### Task 152.B: Log Entry Creation
- Update `BackgroundScanWindowsWorker` to create log entries
- Capture all scan statistics from `EmailScanProvider`
- Record success/error/partial status
- Store folder list and scan configuration used

#### Task 152.C: Log Viewer UI
- New `BackgroundScanLogScreen` accessible from Settings > Background tab
- List view of scan history with:
  - Timestamp, duration, status
  - Summary stats (found/processed/deleted/moved/safe/errors)
  - Account name
- Sort by date (newest first)
- Filter by account and date range

#### Task 152.D: Per-Scan Detail View
- Drill-down into individual scan run
- Folder-by-folder breakdown
- Email-level detail (if CSV was exported)
- Export to CSV button for individual scan runs

#### Task 152.E: Testing
- Unit tests for BackgroundScanLog model
- Database tests for log table CRUD
- UI tests for log viewer screen

### Acceptance Criteria

- [ ] Background scan log viewer accessible from app UI
- [ ] Shows scan history with timestamps, status, and summary stats
- [ ] Per-scan drill-down showing summary results
- [ ] Export to CSV capability for individual scan runs
- [ ] Filter by account and date range
- [ ] All existing tests pass

### Files Affected

- `mobile-app/lib/core/models/background_scan_log.dart` (NEW)
- `mobile-app/lib/core/storage/database_helper.dart` - New table
- `mobile-app/lib/core/services/background_scan_windows_worker.dart` - Log creation
- `mobile-app/lib/ui/screens/background_scan_log_screen.dart` (NEW)
- `mobile-app/lib/ui/screens/settings_screen.dart` - Navigation to log viewer

---

## Issue #139: Rule Override Detection

**Priority**: 5
**Type**: Enhancement
**Estimated Effort**: 8-12 hours
**Model**: Sonnet

### Problem Statement

When a user creates a new rule, no warning is given if an existing higher-priority rule would override it. This leads to confusion when new rules never match because a broader rule catches emails first.

### Current State

- Rules sorted by `executionOrder` (lower = higher priority)
- First matching rule wins, stops evaluation
- Safe senders always evaluated first (take precedence over all rules)
- No conflict detection exists

### Tasks

#### Task 139.A: Rule Conflict Detection Service
- Create `RuleConflictDetector` service
- Given a new/modified rule, identify existing rules that would override it:
  - Rules with lower executionOrder that match overlapping patterns
  - Safe sender patterns that cover the same addresses
- Detect reverse conflicts: new rule overriding existing rules

#### Task 139.B: Pattern Overlap Analysis
- Compare patterns for potential overlap:
  - Domain pattern vs. subdomain pattern (subset detection)
  - Exact email vs. domain pattern
  - Broader regex vs. narrower regex
- Conservative approach: flag potential overlaps, not just definite ones

#### Task 139.C: Warning UI Integration
- Show warning when user adds/edits a rule and conflict detected
- Warning shows:
  - Conflicting rule name and priority
  - Why the conflict occurs (pattern overlap description)
  - Suggested actions (reorder, modify, or proceed anyway)
- Non-blocking: user can dismiss and proceed

#### Task 139.D: Safe Sender Conflict Detection
- When adding a delete rule: warn if matching safe sender exists
- When adding a safe sender: warn if matching delete rule exists
- Show which patterns conflict

#### Task 139.E: Testing
- Test conflict detection between rules with overlapping patterns
- Test safe sender vs. rule conflict detection
- Test edge cases: identical patterns, subset patterns, regex overlap
- Test UI warning display

### Acceptance Criteria

- [ ] Conflict detection identifies overlapping rules
- [ ] Warning shown when adding/editing rules with conflicts
- [ ] Safe sender vs. delete rule conflicts detected
- [ ] Warning is informative (shows conflicting rule, reason)
- [ ] Warning is non-blocking (user can proceed)
- [ ] All existing tests pass

### Files Affected

- `mobile-app/lib/core/services/rule_conflict_detector.dart` (NEW)
- `mobile-app/lib/ui/screens/results_display_screen.dart` - Warning on quick-add
- `mobile-app/lib/ui/screens/rules_management_screen.dart` - Warning on delete (if applicable)

---

## Sprint Schedule

| Phase | Task | Effort | Model | Status |
|-------|------|--------|-------|--------|
| 1 | Sprint Kickoff and Planning | 1-2h | - | IN PROGRESS |
| 2.1 | #153 Days back settings (SettingsStore + UI + wiring) | 4-6h | Haiku | PENDING |
| 2.2 | #150 Scan Options dialog defaults | 3-4h | Haiku | PENDING |
| 2.3 | #151 Rename screen, remove folder selector | 2-3h | Haiku | PENDING |
| 2.4 | #152 Background scan log viewer | 8-10h | Haiku | PENDING |
| 2.5 | #139 Rule override detection | 8-12h | Sonnet | PENDING |
| 3 | Code Review and Testing | 2-3h | - | PENDING |
| 4 | Push and Create PR | 1h | - | PENDING |
| 4.5 | Sprint Review | 1h | - | PENDING |

---

## Execution Groups and Dependencies

```
Group A (Sequential - Scan Config):
  #153 (Days back settings)
    |
    v
  #150 (Scan Options defaults) --- depends on #153 for SettingsStore keys
    |
    v
  #151 (Rename screen, remove folder UI) --- depends on #153 for settings completeness

Group B (Independent):
  #152 (Background scan log viewer) --- can run any time

Group C (Independent):
  #139 (Rule override detection) --- can run any time, uses Sonnet
```

**Recommended Execution**: Groups A, then B, then C.
- Group A first because #153 is a blocker and the three issues share code context
- Group B next since it builds on background scan knowledge from Sprint 15
- Group C last since it requires Sonnet and is the most architecturally complex

---

## Model Assignments

| Task | Model | Rationale |
|------|-------|-----------|
| #153 (Days back settings) | Haiku | Settings CRUD, straightforward UI |
| #150 (Scan Options defaults) | Haiku | Dialog UI update, simple logic |
| #151 (Rename and simplify) | Haiku | Simple rename and removal |
| #152 (Background scan log) | Haiku | New model + UI, follows existing patterns |
| #139 (Rule override detection) | Sonnet | Algorithm design, pattern overlap analysis |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Pattern overlap detection (#139) too complex | Medium | Medium | Conservative approach (flag potential, not definite) |
| Settings migration for days-back | Low | Low | New keys only, no migration needed |
| Background scan log storage growth | Low | Low | Configurable retention period, auto-cleanup |
| Background scan log model design | Low | Medium | Follow existing model patterns, keep schema simple |

---

## Dependencies

- Sprint 15 complete (PR #146 merged) - [OK]
- All issues are open and ready for work
- #153 must be completed before #151
- No external dependencies

---

## Success Criteria

- [ ] #153 implemented - Persistent days-back settings for manual and background scans
- [ ] #150 implemented - Scan Options defaults to "Scan all emails"
- [ ] #151 implemented - Screen renamed to "Manual Scan", folder selector removed
- [ ] #152 implemented - Background scan log viewer with history and stats
- [ ] #139 implemented - Rule override warnings on add/edit
- [ ] All tests passing (961+)
- [ ] Analyzer warnings stable (under 10)
- [ ] Manual testing confirms all features
- [ ] PR created targeting develop branch
