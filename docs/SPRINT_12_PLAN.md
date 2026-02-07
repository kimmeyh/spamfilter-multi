# Sprint 12 Plan

**Sprint**: Sprint 12 - MVP Core Features + Sprint 11 Retrospective Actions
**Start Date**: February 6, 2026
**Target Completion**: February 6, 2026
**Status**: [OK] COMPLETE
**PR**: [#129](https://github.com/kimmeyh/spamfilter-multi/pull/129)

---

## Sprint Goals

Implement core MVP features (Settings, Scan Results Processing, Interactive Rule Management) plus address Sprint 11 retrospective technical debt items.

**IMPORTANT**: This sprint includes BOTH MVP features (F2, F1, F3) AND Sprint 11 retrospective actions (R1-R4) AND technical debt (F9, F10).

---

## Tasks - MVP Core Features

### Task F2: User Application Settings (Issue #120)
**Priority**: HIGH
**Estimated Effort**: 6-8 hours
**Model Assignment**: Sonnet
**Issue**: #120

**Objective**: Implement user-configurable application settings with UI and database storage.

**Acceptance Criteria**:
- [ ] SQLite-backed app settings storage
- [ ] Settings screen with Manual Scan and Background Scan defaults
- [ ] Per-account setting overrides support
- [ ] Settings persist across app restarts
- [ ] All settings accessible from main navigation

**Technical Approach**:
1. Create SettingsStore for SQLite operations
2. Create SettingsScreen UI with Material Design
3. Implement settings categories (Manual Scan, Background Scan)
4. Add per-account override functionality
5. Wire up navigation to settings screen

**Files to Create**:
- `mobile-app/lib/core/storage/settings_store.dart`
- `mobile-app/lib/ui/screens/settings_screen.dart`
- `mobile-app/test/unit/storage/settings_store_test.dart`

**Files to Modify**:
- Main navigation screen (add Settings menu item)

---

### Task F1: Processing Scan Results (Issue #121)
**Priority**: HIGH
**Estimated Effort**: 8-10 hours
**Model Assignment**: Sonnet
**Issue**: #121

**Objective**: Enhance scan results processing with email body parsing and action buttons.

**Acceptance Criteria**:
- [ ] EmailBodyParser for domain extraction from email body links
- [ ] Enhanced email detail view with action buttons (safe sender, create rule, delete)
- [ ] Batch actions for bulk processing
- [ ] Email preview with parsed body content
- [ ] Quick actions directly from results list

**Technical Approach**:
1. Create EmailBodyParser service
2. Update email detail view UI
3. Add action buttons to detail view
4. Implement batch action UI
5. Wire up actions to backend services

**Files to Create**:
- `mobile-app/lib/core/services/email_body_parser.dart`
- `mobile-app/test/unit/services/email_body_parser_test.dart`

**Files to Modify**:
- `mobile-app/lib/ui/screens/email_detail_view.dart`
- `mobile-app/lib/ui/screens/results_display_screen.dart`

---

### Task F3: Interactive Rule & Safe Sender Management (Issue #122)
**Priority**: HIGH
**Estimated Effort**: 6-8 hours
**Model Assignment**: Sonnet
**Issue**: #122

**Objective**: Enable quick-add safe sender and rule creation from scan results.

**Acceptance Criteria**:
- [ ] Quick-add safe sender from email
- [ ] Quick-add rule from email with pattern suggestions
- [ ] Pattern normalization utilities for regex pattern suggestions
- [ ] Confirmation dialogs for quick actions
- [ ] Immediate UI feedback after adding

**Technical Approach**:
1. Add pattern normalization utilities
2. Create quick-add dialogs
3. Wire up safe sender quick-add
4. Wire up rule quick-add with suggestions
5. Update email scan provider with new functionality

**Files to Create**:
- `mobile-app/lib/core/utils/pattern_normalization.dart`

**Files to Modify**:
- `mobile-app/lib/core/providers/email_scan_provider.dart`

---

## Tasks - Sprint 11 Retrospective Actions

### Task R1: Readonly Mode Integration Tests (Issue #117)
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Haiku
**Issue**: #117

**Objective**: Prevent regression of Issue #9 (readonly mode deleting emails).

**Acceptance Criteria**:
- [ ] Test that `ScanMode.readonly` prevents platform.takeAction() calls
- [ ] Test that other scan modes allow actions appropriately
- [ ] Integration tests cover all scan modes
- [ ] Tests use actual EmailScanner (not mocks)

**Files to Create**:
- `mobile-app/test/integration/email_scanner_readonly_mode_test.dart`
- `mobile-app/test/unit/services/scan_mode_enforcement_test.dart`

---

### Task R2: Update SPRINT_EXECUTION_WORKFLOW.md (Issue #115)
**Priority**: MEDIUM
**Estimated Effort**: 1 hour
**Model Assignment**: Haiku
**Issue**: #115

**Objective**: Clarify Claude Code responsibilities for manual testing.

**Acceptance Criteria**:
- [ ] Document that Claude Code builds and runs app before user testing
- [ ] Add pre-testing sanity check list
- [ ] Clarify monitoring requirements

**Files to Modify**:
- `docs/SPRINT_EXECUTION_WORKFLOW.md` (Phase 3.3)

---

### Task R3: Document Windows Workarounds (Issue #116)
**Priority**: MEDIUM
**Estimated Effort**: 1-2 hours
**Model Assignment**: Haiku
**Issue**: #116

**Objective**: Document Windows environment workarounds.

**Acceptance Criteria**:
- [ ] Unicode encoding fixes (`PYTHONIOENCODING=utf-8`)
- [ ] PowerShell command best practices
- [ ] Common error scenarios with solutions

**Files to Create/Modify**:
- `docs/TROUBLESHOOTING.md` (add Windows section)

---

### Task R4: Delete-to-Trash Integration Tests (Issue #118)
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Haiku
**Issue**: #118

**Objective**: Verify IMAP moves to Trash (not permanent delete).

**Acceptance Criteria**:
- [ ] Test IMAP adapter uses MOVE command
- [ ] Test Gmail adapter uses trash API
- [ ] Verify no EXPUNGE commands
- [ ] Integration tests cover delete operations

**Files to Create**:
- `mobile-app/test/integration/delete_to_trash_test.dart`
- `mobile-app/test/unit/adapters/delete_to_trash_behavior_test.dart`

---

## Tasks - Technical Debt

### Task F9: Database Test Refactoring (Issue #57)
**Priority**: MEDIUM
**Estimated Effort**: 3-4 hours
**Model Assignment**: Haiku
**Issue**: #57

**Objective**: Refactor database tests to use actual DatabaseHelper.

**Acceptance Criteria**:
- [ ] Tests use actual DatabaseHelper with in-memory database
- [ ] Remove duplicated schema declarations
- [ ] All database tests passing
- [ ] Improved test reliability

**Files to Modify**:
- Multiple test files using database

---

### Task F10: Test Compilation Errors Fix (Issue #119)
**Priority**: HIGH
**Estimated Effort**: 2-3 hours
**Model Assignment**: Haiku
**Issue**: #119

**Objective**: Fix test compilation errors across multiple files.

**Acceptance Criteria**:
- [ ] Add test helpers for database initialization
- [ ] Fix test compilation errors across multiple files
- [ ] All tests compile and pass
- [ ] Zero test compilation warnings

**Files to Create**:
- `mobile-app/test/helpers/database_test_helper.dart`

**Files to Modify**:
- Multiple test files with compilation errors

---

## Sprint Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| **Total Tasks** | 10 (3 MVP + 4 retrospective + 2 technical debt + 1 critical fix) | 10 |
| **Estimated Effort** | 35-45 hours | ~40 hours |
| **Test Coverage** | 915 tests passing | 915 tests passing |
| **Code Analysis** | 0 errors | 0 errors |
| **Lines Added** | ~3,000 lines | ~3,500 lines |

---

## Testing Strategy

### Automated Tests
- Run full test suite (915 tests)
- Add integration tests for readonly mode and delete-to-trash
- Verify zero code analysis errors
- No regressions in existing functionality

### Manual Testing
- Windows Desktop: Settings screen functional
- Windows Desktop: Email detail view with action buttons
- Windows Desktop: Quick-add safe sender and rule
- Verify all settings persist across app restarts

---

## Definition of Done

- [ ] All 10 tasks completed
- [ ] All automated tests passing (915/915)
- [ ] 27 tests skipped (integration tests requiring credentials)
- [ ] Zero code analysis errors
- [ ] Manual testing on Windows Desktop passed
- [ ] Documentation updated
- [ ] Commits follow conventional commit format
- [ ] PR targets `develop` branch

---

## References

- **Sprint 11 Summary**: docs/SPRINT_11_SUMMARY.md
- **Master Plan**: docs/ALL_SPRINTS_MASTER_PLAN.md (Sprint 12 section)
- **Workflow**: docs/SPRINT_EXECUTION_WORKFLOW.md

---

**Document Version**: 1.0
**Created**: February 7, 2026
**Author**: Claude Code (Sonnet 4.5)
