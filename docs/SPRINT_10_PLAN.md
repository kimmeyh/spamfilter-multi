# Sprint 10 Plan

**Sprint**: Sprint 10 - Cross-Platform UI Enhancements
**Start Date**: February 1, 2026
**Target Completion**: February 1, 2026
**Status**: [OK] COMPLETE
**PR**: [#111](https://github.com/kimmeyh/spamfilter-multi/pull/111)

---

## Sprint Goals

Implement comprehensive UI enhancements across Android and Windows Desktop platforms with Material Design 3, Fluent Design principles, and cross-platform polish.

---

## Tasks

### Task A: Android Material Design 3 Integration
**Priority**: HIGH
**Estimated Effort**: 4-6 hours
**Model Assignment**: Sonnet
**Issue**: #104

**Objective**: Update Android UI to Material Design 3 with modern navigation patterns.

**Acceptance Criteria**:
- [ ] Enable Material Design 3 (`useMaterial3: true`)
- [ ] Replace BottomNavigationBar with Material 3 NavigationBar
- [ ] Update FloatingActionButton to `.extended` variant with label
- [ ] Implement pull-to-refresh pattern with RefreshIndicator
- [ ] Add platform-aware theming (Android vs desktop elevation differences)
- [ ] All 122 automated tests passing
- [ ] Zero code analysis errors

**Technical Approach**:
1. Update theme configuration in `lib/main.dart`
2. Create platform-aware theme system in `lib/ui/theme/app_theme.dart`
3. Update navigation components in screens
4. Implement pull-to-refresh on account selection screen
5. Test Material 3 widgets on Android device/emulator

**Files to Create**:
- None (modifications only)

**Files to Modify**:
- `lib/main.dart`
- `lib/ui/theme/app_theme.dart`
- `lib/ui/screens/account_selection_screen.dart`
- `lib/ui/screens/scan_progress_screen.dart`
- `lib/ui/screens/results_display_screen.dart`

---

### Task B: Windows Desktop Fluent Design
**Priority**: HIGH
**Estimated Effort**: 6-8 hours
**Model Assignment**: Sonnet
**Issue**: #105

**Objective**: Apply Fluent Design principles to Windows Desktop platform.

**Acceptance Criteria**:
- [ ] Apply Fluent Design principles (flat cards with 0 elevation, 4px corner radius)
- [ ] Implement system tray integration with minimize-to-tray
- [ ] Add desktop keyboard shortcuts (Ctrl+Q, Ctrl+N, Ctrl+R, F5)
- [ ] Implement Windows notification system
- [ ] Platform-specific UI adaptations using `Platform.isWindows` checks
- [ ] Manual testing on Windows Desktop completed
- [ ] Known issues documented for Sprint 11

**Technical Approach**:
1. Update theme for Windows-specific styling
2. Implement system tray service
3. Configure keyboard shortcuts with Flutter Shortcuts/Actions API
4. Create notification service for Windows
5. Add platform checks for Windows-only features

**Files to Create**:
- `lib/core/services/windows_notification_service.dart`

**Files to Modify**:
- `lib/ui/theme/app_theme.dart`
- `lib/main.dart`

**Known Limitations**:
- Keyboard shortcuts may need full implementation in Sprint 11
- System tray initialization error to be fixed in Sprint 11

---

### Task C: Cross-Platform UI Polish
**Priority**: MEDIUM
**Estimated Effort**: 6-8 hours
**Model Assignment**: Sonnet
**Issue**: #106

**Objective**: Implement reusable UI components for loading, empty states, and errors.

**Acceptance Criteria**:
- [ ] Create reusable SkeletonLoader widget with shimmer animation
- [ ] Add EmptyStateWidget for no-content scenarios
- [ ] Enhance ErrorDisplayWidget with retry buttons
- [ ] Update all screens to use new loading/empty/error states
- [ ] Improve accessibility with semantic labels
- [ ] Fix type errors (CardThemeData, DialogThemeData)
- [ ] All 122 automated tests passing

**Technical Approach**:
1. Create skeleton loader widget with shimmer package
2. Create empty state widget with icon and message
3. Enhance error display with retry functionality
4. Apply new widgets across all screens
5. Add semantic labels for screen readers
6. Fix Flutter type compatibility issues

**Files to Create**:
- `lib/ui/widgets/skeleton_loader.dart`
- `lib/ui/widgets/empty_state_widget.dart`

**Files to Modify**:
- `lib/ui/widgets/error_display_widget.dart`
- All screen files (`lib/ui/screens/*.dart`)
- `lib/core/services/windows_notification_service.dart` (simplified)

---

### Task D: Documentation Updates
**Priority**: LOW
**Estimated Effort**: 1-2 hours
**Model Assignment**: Haiku
**Issue**: None (integrated task)

**Objective**: Fix Windows database path references and document bash errors.

**Acceptance Criteria**:
- [ ] Fix Windows database path references in 4 documentation files
- [ ] Add bash path error documentation
- [ ] Update SPRINT_EXECUTION_WORKFLOW.md with approval gates reminder
- [ ] Document mandatory parallel PR creation during manual testing

**Files to Modify**:
- `CLAUDE.md`
- `docs/app_paths.dart`
- `docs/QUICK_REFERENCE.md`
- `docs/SPRINT_8_RETROSPECTIVE.md`
- `docs/WINDOWS_BASH_COMPATIBILITY.md`
- `docs/SPRINT_EXECUTION_WORKFLOW.md`

---

## Sprint Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| **Total Tasks** | 4 | 4 |
| **Estimated Effort** | 17-25 hours | ~20 hours |
| **Test Coverage** | 122 tests passing | 122 tests passing |
| **Code Analysis** | 0 errors | 0 errors |
| **Documentation** | All paths fixed | [OK] Complete |

---

## Dependencies

- Flutter SDK (Material Design 3 support)
- Windows SDK (system tray, notifications)
- Android SDK (Material 3 testing)

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| Keyboard shortcuts not functional | Document as known issue, implement in Sprint 11 |
| System tray initialization fails | Create Issue #108 for Sprint 11 |
| Material 3 breaking changes | Test thoroughly, rollback if needed |

---

## Testing Strategy

### Automated Tests
- Run full test suite (122 tests)
- Verify zero code analysis errors
- No regressions in existing functionality

### Manual Testing
- Windows Desktop: Build, launch, verify UI polish
- Windows Desktop: Test keyboard shortcuts (note placeholders)
- Windows Desktop: Verify system tray behavior
- Android: Verify Material 3 navigation and pull-to-refresh

---

## Definition of Done

- [ ] All 4 tasks completed
- [ ] All automated tests passing (122/122)
- [ ] Code analysis clean (0 errors)
- [ ] Manual testing completed on Windows Desktop
- [ ] Documentation updated
- [ ] Issues created for known limitations (keyboard shortcuts, system tray)
- [ ] Commits follow conventional commit format
- [ ] PR targets `develop` branch
- [ ] Sprint retrospective completed

---

## Issues to Create for Sprint 11

Based on Sprint 10 findings, create issues for:
- **Issue #107**: Implement functional keyboard shortcuts (Ctrl+N, Ctrl+R/F5, Ctrl+Q, Help)
- **Issue #108**: Fix system tray icon initialization error
- **Issue #109**: Enhance scan options slider with day labels (1, 7, 15, 30, All)
- **Issue #110**: Enhance CSV export with additional columns and filtering

---

## References

- **Sprint 9 Retrospective**: docs/SPRINT_9_RETROSPECTIVE.md
- **Master Plan**: docs/ALL_SPRINTS_MASTER_PLAN.md
- **Architecture**: docs/ARCHITECTURE.md
- **Workflow**: docs/SPRINT_EXECUTION_WORKFLOW.md

---

**Document Version**: 1.0
**Created**: February 7, 2026
**Author**: Claude Code (Sonnet 4.5)
