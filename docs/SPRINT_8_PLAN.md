# Sprint 8 Plan: Background Scanning - Windows Desktop & MSIX Installer

**Created**: January 28, 2026
**Sprint**: Sprint 8
**Status**: 📋 PLANNED - Ready for Implementation
**Feature Branch**: `feature/20260128_Sprint_8`
**Dates**: January 28-29, 2026
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (implementation)

---

## Executive Summary

Sprint 8 extends the background scanning system from Android to Windows Desktop and introduces MSIX installer packaging for production distribution. This sprint has three parallel streams:

1. **Background Scanning - Windows Desktop** (Part A): Implement background email scanning using Windows Task Scheduler instead of Android WorkManager, with toast notifications for results.

2. **MSIX Installer & Desktop Distribution** (Part B): Configure and build MSIX package for Windows app distribution with auto-update capability.

3. **Desktop UI Adaptations** (Part C): Adjust Flutter UI for desktop-appropriate layouts and interactions.

**Key Achievement**: Windows users can enable background scanning AND the app can be distributed via MSIX installer.

### Key Metrics
- **Tasks**: 3 major tasks (A/B/C)
- **Expected Duration**: 14-16 hours (Sonnet architecture + Haiku implementation)
- **New Files to Create**: ~8 files
- **New Dependencies**: 2-3 packages (windows_notification, etc.)
- **Platform**: Windows 10+
- **Breaking Changes**: 0 (backward compatible)

---

## Sprint Objectives

### Primary Objectives

1. **Background Scanning on Windows Desktop**
   - Create/manage scheduled tasks via PowerShell
   - Detect background mode launch flag (`--background-scan`)
   - Silent operation without UI in background mode
   - Toast notifications with actionable results

2. **MSIX Packaging & Installer**
   - Generate MSIX manifest configuration
   - Build MSIX package for Windows distribution
   - Code signing setup for production
   - Auto-update capability configuration

3. **Desktop UI Optimization**
   - Handle window resizing gracefully
   - Responsive layouts for desktop
   - Keyboard navigation support

### Business Value
- **Distribution**: Windows users can install via MSIX (modern installer)
- **Automation**: Continuous protection on Windows via background scans
- **Professionalism**: MSIX installer shows production-ready status
- **User Convenience**: Auto-update support for seamless upgrades

---

## Scope

### What IS Included in Sprint 8

#### Part A: Background Scanning - Windows Desktop
1. ✅ WindowsTaskSchedulerService (create/manage/monitor scheduled tasks)
2. ✅ PowerShell script generation for task creation
3. ✅ Background mode detection (launch flag parsing)
4. ✅ Minimal UI for background execution mode
5. ✅ Toast notifications with tap-through to results
6. ✅ BackgroundScanWindowsWorker (Windows-specific implementation)

#### Part B: MSIX Configuration & Installer Build
1. ✅ MSIX manifest generation (Package.appxmanifest)
2. ✅ Build configuration updates
3. ✅ Code signing certificate configuration
4. ✅ Windows installer build process
5. ✅ Auto-update capability setup

#### Part C: Desktop UI Adaptations
1. ✅ Window resize handling
2. ✅ Responsive layouts for desktop
3. ✅ Keyboard shortcuts
4. ✅ Context menus and right-click support

### What is NOT Included (Deferred)
- iOS background scanning (Phase 4)
- macOS background scanning (future phase)
- Settings UI integration for Windows (can extend Sprint 5 in future)
- Microsoft Store submission process
- Production code signing certificate (user responsibility)

### Dependencies

**Required (must be complete)**:
- Sprint 7: Background scanning patterns established
- Sprint 5: Account settings structure
- Sprint 4: ScanResult/UnmatchedEmail storage

**External**:
- Windows 10 SDK (for WinRT toast notifications)
- MSIX tooling (Visual Studio or msixheroes)
- PowerShell 5.0+ (Windows Task Scheduler automation)

---

## Detailed Task Breakdown

### TASK A: Windows Task Scheduler Integration & Background Scanning

**Model Assignment**: Sonnet (architecture) → Haiku (implementation)
**Complexity**: Medium-High
**Estimated Duration**: 5-6 hours
**GitHub Issue**: #93

**Objective**: Implement Windows Task Scheduler integration for background scanning with robust PowerShell automation.

#### Key Responsibilities

1. **WindowsTaskSchedulerService** (main service)
   - `createScheduledTask(frequency: ScanFrequency)` - Create Windows scheduled task
   - `updateScheduledTask(frequency: ScanFrequency)` - Update frequency
   - `deleteScheduledTask()` - Remove scheduled task
   - `getScheduleStatus()` - Query current task status
   - `getNextScheduledTime()` - Calculate next execution
   - Error handling with fallback messaging

2. **PowerShell Script Generation**
   - Generate PowerShell script for task creation
   - Script includes: frequency, launch command, trigger conditions
   - Scripts saved to temp location during execution
   - Cleanup after execution

3. **Background Mode Detection**
   - Parse launch arguments: `--background-scan`
   - Set flag in main.dart app initialization
   - Route to minimal UI when background mode detected

4. **Minimal Background UI**
   - Show simple status screen: "Scanning in progress..."
   - Hide settings buttons, back buttons
   - Disable navigation stack management
   - Exit cleanly after completion

5. **BackgroundScanWindowsWorker**
   - Execute same scan logic as Android
   - Reuse EmailScanner from Sprint 4
   - Save results to database
   - Trigger notification if unmatched > 0

#### Acceptance Criteria
- [ ] WindowsTaskSchedulerService creates scheduled tasks via PowerShell
- [ ] Task runs at configured frequency (15min, 30min, 1hr, daily)
- [ ] Launch flag `--background-scan` detected correctly
- [ ] Background mode UI minimal and non-intrusive
- [ ] BackgroundScanWindowsWorker executes scans
- [ ] Results saved to database (same schema as Android)
- [ ] Can enable/disable/change frequency
- [ ] PowerShell scripts generated and executed cleanly
- [ ] Error handling with user-friendly messages
- [ ] Unit tests: 80%+ coverage
- [ ] Integration tests: Frequency scheduling, scan execution
- [ ] All tests passing, zero flutter analyze errors

#### Files to Create/Modify

**New Files**:
- `lib/core/services/windows_task_scheduler_service.dart` (PRIMARY - ~400 lines)
- `lib/core/services/background_scan_windows_worker.dart` (~200 lines)
- `lib/core/services/powershell_script_generator.dart` (~250 lines)
- `lib/ui/services/background_mode_service.dart` (~100 lines)
- `test/unit/services/windows_task_scheduler_service_test.dart`
- `test/unit/services/powershell_script_generator_test.dart`
- `test/integration/windows_background_scan_workflow_test.dart`

**Modified Files**:
- `lib/main.dart` - Add background mode detection
- `pubspec.yaml` - Add windows_notification dependency

---

### TASK B: Toast Notifications & Background Mode Handling

**Model Assignment**: Haiku
**Complexity**: Low-Medium
**Estimated Duration**: 3-4 hours
**GitHub Issue**: #94

**Objective**: Implement Windows toast notifications for background scan results with tap-through to app.

#### Key Responsibilities

1. **Toast Notification Service**
   - Create notification with scan summary
   - Show unmatched count, accounts scanned
   - Action button: "Review Results" → opens ProcessResultsScreen
   - Dismiss button: "Ignore"

2. **Background Mode Handling**
   - Detect background execution mode
   - Minimal UI: Just progress/status screen
   - Hide menu buttons, settings, navigation
   - Auto-close after scan completes

3. **Notification Metadata**
   - Title: "Spam Filter Background Scan Complete"
   - Body: "Found X unmatched emails in Y accounts"
   - Action: Open ProcessResultsScreen
   - Icon: App icon from assets

#### Acceptance Criteria
- [ ] Toast notifications created via WinRT API
- [ ] Notification shows unmatched count accurately
- [ ] Tap action opens ProcessResultsScreen with background scan results
- [ ] Background mode UI displays only progress indicator
- [ ] Can dismiss notification
- [ ] Notifications only show if unmatched_count > 0
- [ ] Background process exits cleanly after completion
- [ ] Unit tests: 80%+ coverage
- [ ] Integration test: Notification triggered on scan completion
- [ ] All tests passing

#### Files to Create/Modify

**New Files**:
- `lib/core/services/windows_toast_notification_service.dart` (~200 lines)
- `lib/ui/screens/background_scan_progress_screen.dart` (~150 lines)
- `test/unit/services/windows_toast_notification_service_test.dart`

**Modified Files**:
- `lib/main.dart` - Add background mode route detection
- `lib/ui/screens/process_results_screen.dart` - Support background scan results parameter

---

### TASK C: MSIX Configuration & Installer Build

**Model Assignment**: Haiku
**Complexity**: Medium
**Estimated Duration**: 4-5 hours
**GitHub Issue**: #95

**Objective**: Configure MSIX packaging and build process for Windows app distribution.

#### Key Responsibilities

1. **MSIX Manifest Generation** (Package.appxmanifest)
   - Package identity: `com.spamfiltermulti`
   - Version alignment with app version
   - Capabilities: Internet, file system access
   - Display name, publisher information
   - App icon and splash image

2. **Build Configuration**
   - Update `pubspec.yaml` for MSIX generation
   - Windows build configuration (release vs debug)
   - Asset bundling for installer
   - Version numbering scheme

3. **Code Signing Setup**
   - Certificate path configuration
   - Thumbprint storage (securely)
   - Test certificate generation for local builds
   - Production certificate integration

4. **MSIX Build Process**
   - Flutter MSIX package generation
   - Alternative: Manual MSIX generation with Flutter artifacts
   - Test package creation on Windows 10/11
   - Installer size optimization

5. **Auto-Update Configuration**
   - Windows App Installer (.appinstaller) file generation
   - Update check mechanism
   - Background update triggering

#### Acceptance Criteria
- [ ] MSIX manifest configured correctly
- [ ] Package identity, version, capabilities set
- [ ] MSIX builds successfully from Flutter
- [ ] App installs cleanly via MSIX installer
- [ ] App uninstalls cleanly (removes all files)
- [ ] Auto-update capability configured
- [ ] Code signing certificate integration works
- [ ] Installer is ~100MB or less
- [ ] Can install on Windows 10 and Windows 11
- [ ] Start menu shortcut created
- [ ] App appears in Add/Remove Programs
- [ ] Unit tests for configuration validation
- [ ] Build verification script passes

#### Files to Create/Modify

**New Files**:
- `windows/Package.appxmanifest` (MSIX manifest - XML)
- `scripts/build-msix.ps1` (PowerShell build script)
- `scripts/generate-appinstaller.ps1` (auto-update configuration)
- `test/unit/windows/msix_configuration_test.dart`

**Modified Files**:
- `pubspec.yaml` - MSIX generation configuration
- `windows/runner_plugins.cmake` - Plugin bundling
- `windows/CMakeLists.txt` - Build configuration

---

### TASK D: Desktop UI Adaptations & Testing

**Model Assignment**: Haiku
**Complexity**: Low-Medium
**Estimated Duration**: 2-3 hours
**GitHub Issue**: #96

**Objective**: Adapt Flutter UI for desktop environments and comprehensive testing.

#### Key Responsibilities

1. **Window Resize Handling**
   - Responsive layouts for various window sizes
   - Proper wrapping of text and buttons
   - Scrollable content for small windows
   - Minimum window size constraints

2. **Keyboard Navigation**
   - Tab navigation through UI elements
   - Enter key for primary actions
   - Escape key to close dialogs/back navigation
   - Keyboard shortcuts (Ctrl+S for scan, Ctrl+N for new rule)

3. **Desktop-Specific UI**
   - Larger touch targets for mouse (vs mobile touch)
   - Right-click context menus
   - Menu bar (File, Edit, Help)
   - Status bar showing sync status

4. **Testing**
   - Build and installation verification
   - Window resize testing
   - Keyboard navigation testing
   - MSIX installation on Windows 10/11
   - Background scanning end-to-end

#### Acceptance Criteria
- [ ] App window resizable without UI breaks
- [ ] Min window size enforced (800x600)
- [ ] Tab navigation works through all screens
- [ ] Keyboard shortcuts functioning
- [ ] Right-click menus working
- [ ] MSIX installs cleanly
- [ ] Background scan completes successfully
- [ ] Toast notification displays
- [ ] ProcessResultsScreen opens from notification
- [ ] Uninstall removes all files
- [ ] Manual testing checklist completed

#### Files to Create/Modify

**Modified Files**:
- `lib/main.dart` - Min window size, keyboard handling
- `lib/ui/screens/*.dart` - Responsive layout adjustments
- `windows/runner/main.cpp` - Window configuration

**Test Files**:
- `test/integration/windows_installer_test.dart`
- `test/integration/windows_ui_responsiveness_test.dart`

---

## Database Schema

**No new tables required** - Uses existing schema from Sprint 4-7:
- `ScanResult` table (already exists)
- `UnmatchedEmail` table (already exists)
- `BackgroundScanLog` table (from Sprint 7)

---

## Dependencies & Packages

### New Dependencies (Added to pubspec.yaml)

```yaml
dependencies:
  # Windows-specific
  windows_notification: ^0.1.0     # Toast notifications via WinRT
  win32: ^3.0.0                    # Win32 API for advanced features
```

### Existing Dependencies (Reused)
- `flutter_local_notifications` (already in Sprint 7)
- `workmanager` (already in Sprint 7, used for Android scheduling)
- Core providers and services (EmailScanner, DatabaseHelper, etc.)

---

## Implementation Guidelines

### Key Design Decisions

**1. Separate Service from Android**
- Android uses `WorkManager` (Google's cross-platform background work)
- Windows uses `Task Scheduler` (native Windows feature)
- Both implement same interface for consistency

**2. PowerShell for Automation**
- Windows Task Scheduler requires PowerShell or command-line tools
- Generated scripts ensure consistent task creation
- Admin elevation handled by PowerShell prompt
- Scripts cleaned up after execution

**3. Background Mode is Silent**
- No UI except minimal progress screen
- No user interaction expected
- Database logging for debugging
- Clean exit after scan completes

**4. Reuse Core Scanning Logic**
- `EmailScanner` unchanged (platform-agnostic)
- `ScanResult` and `UnmatchedEmail` tables reused
- Same rule evaluation, notification logic
- Minimal platform-specific code

---

## Testing Strategy

### Unit Tests (35+ expected)

**Windows Task Scheduler Service** (15 tests):
- Create task with various frequencies (15min, 30min, 1hr, daily)
- Update task frequency
- Delete task
- Query schedule status
- Calculate next execution time
- Error handling (admin privileges, invalid frequency)

**PowerShell Script Generator** (10 tests):
- Generate script for each frequency
- Validate script syntax
- Path escaping in script
- Cleanup script generation

**Windows Toast Notification Service** (10 tests):
- Create notification with unmatched count
- Validate notification format
- Tap action handling
- Dismiss button

### Integration Tests (6+ workflows)

1. **Enable Background Scanning**
2. **Scan Execution (Simulated)**
3. **Notification Workflow**
4. **Frequency Change**
5. **Disable Scanning**
6. **MSIX Installation**

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Task Scheduler requires admin elevation | High | Medium | Request UAC, provide clear instructions, fallback option |
| PowerShell execution fails | High | Low | Generate scripts with proper escaping, validate syntax before execution |
| Toast notifications not appearing | Medium | Low | Test on multiple Windows versions, use fallback notification method |
| MSIX build fails | High | Medium | Test build process early, use alternative packaging if needed |
| Background scan doesn't trigger on schedule | High | Medium | Extensive integration testing, verify Task Scheduler directly |
| Code signing certificate issues | Medium | Medium | Use test certificate for development, document production setup |
| Window resize causes UI breaks | Low | Medium | Responsive design patterns, minimum window size constraints |

---

## Success Criteria

### Definition of Done for Sprint 8

#### Part A: Windows Background Scanning
- ✅ WindowsTaskSchedulerService creates and manages scheduled tasks
- ✅ PowerShell script generation and execution working
- ✅ Background mode detection functional (--background-scan flag)
- ✅ Minimal UI displays during background execution
- ✅ BackgroundScanWindowsWorker executes scans correctly
- ✅ Results saved to database (same schema as Android)
- ✅ Can enable/disable/change frequency
- ✅ Error handling with user-friendly messages

#### Part B: MSIX Installer
- ✅ MSIX manifest configured correctly
- ✅ Build process creates MSIX successfully
- ✅ MSIX installs on Windows 10 and 11
- ✅ Start Menu shortcut created
- ✅ App appears in Add/Remove Programs
- ✅ Uninstall removes all files cleanly
- ✅ Code signing configured and working

#### Part C: Desktop UI Adaptations
- ✅ Window resizable (min 800x600)
- ✅ Responsive layouts for various sizes
- ✅ Keyboard navigation (Tab, Enter, Escape)
- ✅ Keyboard shortcuts working (Ctrl+S, Ctrl+N)
- ✅ Menu bar and context menus functional

#### Code Quality
- ✅ All unit tests passing (80%+ coverage)
- ✅ All integration tests passing (100% success)
- ✅ Zero code analysis errors/warnings
- ✅ Code follows project patterns
- ✅ New dependencies properly integrated
- ✅ No breaking changes

---

## Effort Estimate

| Task | Estimated | Breakdown | Notes |
|------|-----------|-----------|-------|
| **A: Windows Task Scheduler** | 5-6h | Design (1h) + Impl (3h) + Tests (1.5h) | Core work, requires careful error handling |
| **B: Toast Notifications** | 3-4h | Design (0.5h) + Impl (2h) + Tests (1h) | Straightforward WinRT usage |
| **C: MSIX Packaging** | 4-5h | Manifest (1h) + Build Config (1.5h) + Testing (2h) | Build verification may iterate |
| **D: Desktop UI + Testing** | 2-3h | Responsive (1h) + Keyboard (0.5h) + Manual Tests (1.5h) | UI adjustments minor, testing thorough |
| **TOTAL** | **14-18h** | | Projected range |

**Confidence**: Medium (platform-specific Windows work, some unknowns with MSIX build process)

---

## Timeline

**Sprint Duration**: 2 days (January 28-29, 2026)

**Suggested Execution Order**:

**Day 1 (Jan 28)**:
1. Sonnet: Architecture review for Task A (1h)
2. Haiku: Implement Task A (WindowsTaskSchedulerService) (3-4h)
3. Haiku: Implement Task B (Toast Notifications) in parallel (2-3h)
4. End of day: Unit tests for A+B

**Day 2 (Jan 29)**:
1. Haiku: Implement Task C (MSIX manifest, build script) (2-3h)
2. Haiku: Implement Task D (Desktop UI, keyboard handling) (1-2h)
3. Haiku: Manual testing (background scan, MSIX installation) (2-3h)
4. Haiku: Integration tests + flutter analyze/test cleanup (1h)
5. End of day: PR ready for review

---

## Stopping Criteria (When to Escalate)

**Escalate to Sonnet if**:
1. PowerShell script generation fails repeatedly → architectural issue
2. Task Scheduler integration doesn't trigger background scans → platform integration issue
3. MSIX build fails with cryptic errors → tooling/environment issue
4. WinRT toast notification API unavailable → dependency/version issue
5. Window resize causes major UI breakage → layout system issue
6. Test failures suggest architectural flaw → design reconsideration needed

**Escalate to Opus if**:
1. Multiple escalations from Sonnet (complexity exceeds Sonnet capability)
2. Critical security issue in background execution
3. Performance optimization needed (background scan too slow)
4. Windows-specific performance profiling needed

---

## Approval Checklist

For user approval of Sprint 8 Plan:

- [ ] Sprint objectives clear and achievable
- [ ] Part A (Windows background scanning) approach sound
- [ ] Part B (MSIX installer) requirements understood
- [ ] Part C (Desktop UI) scope appropriate
- [ ] Tasks breakdown is logical and complete
- [ ] Model assignments (Sonnet → Haiku) make sense
- [ ] Effort estimate (14-18 hours) seems reasonable
- [ ] Risk assessment acceptable
- [ ] Testing strategy comprehensive
- [ ] Success criteria clear and measurable
- [ ] Known challenges and mitigations addressed
- [ ] Ready to approve plan and begin execution

---

**Sprint 8 Status**: 📋 PLANNED - Ready for User Approval and Execution

**Generated**: January 28, 2026
