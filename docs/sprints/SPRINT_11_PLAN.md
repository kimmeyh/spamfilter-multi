# Sprint 11 Plan

**Sprint**: Sprint 11 - UI Polish & Production Readiness
**Start Date**: February 1, 2026
**Target Completion**: February 1, 2026
**Status**: [OK] COMPLETE
**PR**: [#114](https://github.com/kimmeyh/spamfilter-multi/pull/114)

---

## Sprint Goals

Implement UI Polish features and address critical production readiness issues including keyboard shortcuts, system tray fixes, scan option enhancements, CSV export improvements, and critical bug fixes for readonly mode and delete safety.

**IMPORTANT**: This sprint includes BOTH original Sprint 11 tasks (Issues #107-#110) AND Sprint 11 Retrospective recommendations after PR #112 was reverted.

---

## Tasks - Original Sprint 11 Work

### Task A1: Functional Keyboard Shortcuts (Issue #107)
**Priority**: HIGH
**Estimated Effort**: 3-4 hours
**Model Assignment**: Sonnet
**Issue**: #107

**Objective**: Implement functional keyboard shortcuts for Windows Desktop.

**Acceptance Criteria**:
- [ ] **Ctrl+Q**: Quit application with confirmation dialog
- [ ] **Ctrl+N**: New scan (navigate to account selection)
- [ ] **Ctrl+R / F5**: Refresh current screen with visual SnackBar feedback
- [ ] Implementation uses Flutter Shortcuts + Actions API
- [ ] All shortcuts tested on Windows Desktop

**Technical Approach**:
1. Create custom Intent classes for each action
2. Create Action classes to handle each intent
3. Wire up keyboard bindings in main.dart
4. Add confirmation dialog for Quit action
5. Test all shortcuts on Windows

**Files to Modify**:
- `mobile-app/lib/main.dart`

---

### Task A2: System Tray Icon & Menu (Issue #108)
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet
**Issue**: #108

**Objective**: Fix system tray initialization error and ensure menu persistence.

**Acceptance Criteria**:
- [ ] Fix initialization error - create menu BEFORE setSystemTrayInfo()
- [ ] Menu items persist after minimize/restore
- [ ] Menu Items: Run Scan Now, View Results, Settings, Exit
- [ ] No PlatformException errors on startup

**Technical Approach**:
1. Create system tray menu before calling setSystemTrayInfo()
2. Ensure menu initialization order is correct
3. Test minimize/restore persistence
4. Verify all menu items functional

**Files to Modify**:
- `mobile-app/lib/core/services/windows_system_tray_service.dart`

---

### Task B1: Enhanced Date Range Selector (Issue #109)
**Priority**: MEDIUM
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet
**Issue**: #109

**Objective**: Improve scan date range selector with continuous slider.

**Acceptance Criteria**:
- [ ] Continuous Slider: 1-90 days with smooth discrete labels
- [ ] All Time Checkbox: Overrides slider when checked
- [ ] Visual Design: Cleaner layout, better spacing
- [ ] Consistent with existing scan options UI

**Technical Approach**:
1. Replace discrete slider with continuous slider
2. Add day labels at key intervals (1, 7, 15, 30, 60, 90)
3. Implement "All Time" checkbox with override logic
4. Update UI layout for better spacing
5. Test slider interaction

**Files to Modify**:
- `mobile-app/lib/ui/screens/scan_progress_screen.dart`

---

### Task B2: Enhanced CSV Export (Issue #110)
**Priority**: MEDIUM
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet
**Issue**: #110

**Objective**: Enhance CSV export with additional columns and timestamp.

**Acceptance Criteria**:
- [ ] 10 Columns: scanId, timestamp, sender, subject, folder, action, rule, snippet, messageId, scanMode
- [ ] Timestamp: ISO 8601 format for scan execution time
- [ ] Headers: Clear column names for data analysis
- [ ] File saved to Downloads folder

**Technical Approach**:
1. Add new columns to CSV export
2. Format timestamp as ISO 8601
3. Include all required fields
4. Test CSV generation
5. Verify column headers are clear

**Files to Modify**:
- `mobile-app/lib/ui/screens/results_display_screen.dart`

---

### Task C: Critical Bug Fixes

#### CRITICAL FIX: Issue #9 - Readonly Mode Bypass
**Priority**: CRITICAL
**Estimated Effort**: 3-4 hours
**Model Assignment**: Sonnet
**Issue**: #9

**Problem**: Readonly mode was deleting emails during testing (526 emails deleted).

**Root Cause**: `_shouldExecuteAction()` returned true regardless of scan mode.

**Solution**:
- [ ] Proper scan mode checking in EmailScanner.scanInbox()
- [ ] Readonly mode NEVER calls platform.takeAction()
- [ ] Integration test to prevent regression

**Files to Modify**:
- `mobile-app/lib/core/services/email_scanner.dart`
- `mobile-app/lib/core/providers/email_scan_provider.dart`

---

#### CRITICAL FIX: Permanent Delete → Move to Trash
**Priority**: CRITICAL
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet
**Issue**: Related to #9

**Problem**: IMAP adapter was using EXPUNGE (permanent delete).

**Risk**: Emails permanently deleted, not recoverable.

**Solution**:
- [ ] Change to MOVE command targeting Trash folder
- [ ] All deletes now recoverable (move to Trash, not permanent)
- [ ] Integration test to verify Trash behavior

**Files to Modify**:
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`

---

### Task D: Windows UI Polish

#### Exit Button for Windows AppBars
**Priority**: MEDIUM
**Estimated Effort**: 1-2 hours
**Model Assignment**: Haiku
**Issue**: None (integrated)

**Problem**: Windows 11 top-right X button not working in Flutter.

**Solution**:
- [ ] Custom Exit button in AppBar with confirmation dialog
- [ ] Dialog: "Are you sure you want to exit?" with Exit/Cancel options
- [ ] Apply to all screens with AppBar

**Files to Create**:
- `mobile-app/lib/ui/widgets/app_bar_with_exit.dart`

**Files to Modify**:
- Multiple screen files

---

## Tasks - Sprint 11 Retrospective Recommendations

### Recommendation 1: Integration Test - Readonly Mode
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet

**Purpose**: Prevent regression of Issue #9 (readonly bypass).

**Acceptance Criteria**:
- [ ] Test that `ScanMode.readonly` prevents platform.takeAction() calls
- [ ] Test that `ScanMode.fullScan` allows platform.takeAction() calls
- [ ] Test that `ScanMode.testLimit` respects email limit
- [ ] Test that readonly logs proposed actions without executing

**Files to Create**:
- `mobile-app/test/integration/email_scanner_readonly_mode_test.dart`

---

### Recommendation 2: Integration Test - Delete-to-Trash
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet

**Purpose**: Validate all deletes are recoverable.

**Acceptance Criteria**:
- [ ] IMAP adapter moves to Trash (not EXPUNGE)
- [ ] Gmail adapter uses trash API (not permanent delete)
- [ ] Move to Junk uses move command (not copy+delete)

**Files to Create**:
- `mobile-app/test/integration/delete_to_trash_test.dart`

---

### Recommendation 3 & 3.1: Pre-Testing Checklist
**Priority**: MEDIUM
**Estimated Effort**: 1 hour
**Model Assignment**: Haiku

**Purpose**: Clarify Claude Code responsibilities for manual testing.

**Acceptance Criteria**:
- [ ] Build succeeds without errors
- [ ] App launches without crashes
- [ ] No immediate console errors
- [ ] App running and ready for user testing
- [ ] Claude Code monitoring app output in background

**Files to Modify**:
- `docs/SPRINT_EXECUTION_WORKFLOW.md` (Phase 3.3)

---

### Recommendation 4 & 4.1: Windows Development Guide
**Priority**: MEDIUM
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet

**Purpose**: Comprehensive Windows development reference.

**Acceptance Criteria**:
- [ ] Shell selection (PowerShell vs Bash decision tree)
- [ ] Unicode encoding issues and solutions
- [ ] PowerShell best practices
- [ ] Build script usage
- [ ] Common error scenarios with fixes

**Files to Create**:
- `docs/WINDOWS_DEVELOPMENT_GUIDE.md`

**Files to Modify**:
- `CLAUDE.md`
- `docs/QUICK_REFERENCE.md`

---

### Recommendation 5: Issue Backlog in Master Plan
**Priority**: LOW
**Estimated Effort**: 1 hour
**Model Assignment**: Haiku

**Purpose**: Track all open/fixed issues in one place.

**Acceptance Criteria**:
- [ ] Status summary (fixed vs open)
- [ ] Detailed issue list with fix dates
- [ ] Test coverage metrics
- [ ] References to ISSUE_BACKLOG.md

**Files to Modify**:
- `docs/ALL_SPRINTS_MASTER_PLAN.md`

---

### Recommendation 6: Recovery Capabilities Audit
**Priority**: MEDIUM
**Estimated Effort**: 2-3 hours
**Model Assignment**: Sonnet

**Purpose**: Document recovery for all destructive operations.

**Acceptance Criteria**:
- [ ] All operations are recoverable (no permanent data loss)
- [ ] Gmail uses `trash()` API (not `delete()`)
- [ ] IMAP uses `MOVE` to Trash (not `EXPUNGE`)
- [ ] Recovery procedures documented for Gmail + IMAP
- [ ] Risk assessment: LOW (all safety features verified)

**Files to Create**:
- `docs/RECOVERY_CAPABILITIES.md`

---

### Recommendation 7: Test Data Replenishment
**Priority**: LOW
**Estimated Effort**: 2-3 hours
**Model Assignment**: Haiku

**Purpose**: Replenish test emails after destructive testing.

**Acceptance Criteria**:
- [ ] Configurable email count and spam ratio
- [ ] 7 spam templates + 7 legitimate templates
- [ ] Dry-run mode
- [ ] JSON export for manual creation
- [ ] SMTP/Gmail API sending support (framework ready)

**Files to Create**:
- `mobile-app/scripts/generate-test-emails.ps1`
- `mobile-app/scripts/send-test-emails.py`

---

## Sprint Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| **Total Tasks** | 14 (4 original + 7 retrospective + 3 critical fixes) | 14 |
| **Estimated Effort** | 35-45 hours | ~40 hours |
| **Test Coverage** | 138 tests passing | 138 tests passing |
| **Code Analysis** | 0 errors | 0 errors |
| **Critical Bugs Fixed** | 2 (Issue #9, permanent delete) | 2 |

---

## Testing Strategy

### Automated Tests
- Run full test suite (138 tests)
- Add 2 new integration tests (readonly mode, delete-to-trash)
- Verify zero code analysis errors
- No regressions in existing functionality

### Manual Testing
- Windows Desktop: Keyboard shortcuts functional
- Windows Desktop: System tray menu persists
- Scan Options: Continuous slider works (1-90 days)
- CSV Export: 10 columns with timestamp
- Readonly mode: VERIFIED no emails deleted
- Delete operations: VERIFIED move to Trash (recoverable)

---

## Definition of Done

### Sprint 11 Original Tasks
- [ ] Keyboard shortcuts functional on Windows (Ctrl+Q, Ctrl+N, Ctrl+R/F5)
- [ ] System tray icon works without initialization errors
- [ ] System tray menu persists after minimize/restore
- [ ] Scan options slider continuous (1-90 days) with discrete labels
- [ ] CSV export includes 10 columns with scan timestamp
- [ ] Exit button works on Windows AppBars
- [ ] Readonly mode NEVER deletes emails (Issue #9 fixed)
- [ ] Delete operations move to Trash (not permanent)
- [ ] All tests pass (138/138)
- [ ] Zero analyzer warnings

### Sprint 11 Retrospective Recommendations
- [ ] Integration test for readonly mode enforcement
- [ ] Integration test for delete-to-trash behavior
- [ ] Pre-testing checklist in SPRINT_EXECUTION_WORKFLOW.md
- [ ] Consolidated Windows development guide
- [ ] Issue Backlog section in ALL_SPRINTS_MASTER_PLAN.md
- [ ] Recovery capabilities audit completed
- [ ] Test data replenishment scripts created

---

## Risk Assessment

**Risk Level**: LOW [OK]

All critical bugs fixed and validated:
- Readonly mode bypass fixed (Issue #9)
- Permanent delete changed to recoverable Trash move
- Integration tests prevent regression
- All operations documented as recoverable

---

## References

- **Sprint 10 Summary**: docs/sprints/SPRINT_10_SUMMARY.md
- **Sprint 11 Retrospective**: docs/sprints/SPRINT_11_RETROSPECTIVE.md
- **Master Plan**: docs/ALL_SPRINTS_MASTER_PLAN.md
- **Workflow**: docs/SPRINT_EXECUTION_WORKFLOW.md

---

**Document Version**: 1.0
**Created**: February 7, 2026
**Author**: Claude Code (Sonnet 4.5)
