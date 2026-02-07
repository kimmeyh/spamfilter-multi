# Sprint 7 Plan: Background Scanning Implementation - Android (WorkManager)

**Created**: January 27, 2026
**Sprint**: Sprint 7
**Status**: [TARGET] PLANNING - Awaiting User Approval
**Feature Branch**: `feature/20260127_Sprint_7`

---

## Sprint Overview

Sprint 7 implements automatic periodic background email scanning on Android using Flutter's WorkManager package. Background scans run at user-configured intervals (15min, 30min, 1hr, daily) and flag unmatched emails for user review without modifying email state (read-only mode).

**Key Achievement**: Users can enable automatic background scanning to stay protected without manual intervention.

---

## Sprint Objectives

### Primary Objective
Implement a complete background scanning system for Android that:
- Runs automatically at user-configured intervals
- Scans all enabled email accounts
- Flags unmatched emails for review
- Notifies user when unmatched emails found
- Respects device battery and network conditions

### Business Value
- **Automation**: Continuous protection without user action
- **Convenience**: Background scans run while app closed
- **Efficiency**: Configurable frequency to balance protection vs battery
- **Awareness**: Notifications alert user to unmatched emails

### Technical Objectives
- Integrate Android WorkManager for periodic task scheduling
- Implement background scan worker using existing EmailScanner
- Database logging for debugging (scheduled vs actual times)
- Notification system with tap-through to results
- Battery/network optimization (skip scans in low-resource conditions)

---

## Scope & Dependencies

### What IS Included in Sprint 7
1. [OK] BackgroundScanWorker (execute scans in background)
2. [OK] BackgroundScanManager (schedule and manage background scans)
3. [OK] Notifications with battery/network optimization
4. [OK] Integration tests and manual testing
5. [OK] Database schema additions (BackgroundScanLog)

### What is NOT Included (Deferred to Later Sprints)
- Settings UI integration (scheduled for Sprint 5 - but can also happen in Sprint 7 if time permits)
- Windows background scanning (Sprint 8)
- iOS background scanning (planned for future phase)

### Dependencies
- **Required (must be complete)**:
  - Sprint 4: ScanResult/UnmatchedEmail storage
  - Sprint 5: Account settings (background_scan_enabled, background_scan_frequency_minutes)
  - Sprint 6: Email pattern generation and rule quick-add

- **Optional (helpful but not blocking)**:
  - Settings UI for battery threshold configuration

---

## Sprint Tasks & Model Assignments

### Task A: BackgroundScanWorker & WorkManager Integration ⭐
**Model Assignment**: Sonnet (architecture) → Haiku (implementation)
**Complexity**: Medium
**Estimated Duration**: 4-5 hours
**GitHub Issue**: #88

**Objective**: Implement the core worker that executes background scans when WorkManager triggers

**Key Responsibilities**:
1. Extend Flutter's `Worker` class
2. Load enabled accounts from database
3. For each account: Execute EmailScanner (same as manual scans)
4. Save ScanResult + UnmatchedEmail records
5. Log execution in BackgroundScanLog table
6. Handle errors with exponential backoff (max 3 retries)

**Acceptance Criteria**:
- [ ] BackgroundScanWorker extends Worker correctly
- [ ] Loads accounts with background_scan_enabled = true
- [ ] Executes EmailScanner for each account
- [ ] Results persisted to database
- [ ] BackgroundScanLog tracks execution timing and status
- [ ] Error handling with exponential backoff
- [ ] Unit tests: 80%+ coverage
- [ ] Integration tests: Scan execution flow
- [ ] All tests passing, zero flutter analyze errors

**Files to Create/Modify**:
- `lib/core/services/background_scan_worker.dart` (NEW)
- `lib/core/services/background_scan_log_store.dart` (NEW - database ops)
- Database migration: Add BackgroundScanLog table
- Tests: `test/unit/services/background_scan_worker_test.dart`
- Tests: `test/integration/background_scan_workflow_test.dart`

---

### Task B: BackgroundScanManager & Frequency Scheduling
**Model Assignment**: Haiku
**Complexity**: Low-Medium
**Estimated Duration**: 2-3 hours
**GitHub Issue**: #89

**Objective**: Implement manager for scheduling/canceling background scans and querying status

**Key Responsibilities**:
1. Schedule PeriodicWorkRequest for user-selected frequency
2. Cancel existing work when user disables or changes frequency
3. Query current schedule status and next execution time
4. Handle frequency changes (15min, 30min, 1hr, daily, disabled)

**Acceptance Criteria**:
- [ ] scheduleBackgroundScans(frequency) schedules work
- [ ] cancelBackgroundScans() cancels existing work
- [ ] getScheduleStatus() returns current schedule info
- [ ] getNextScheduledTime() calculates next execution
- [ ] Frequency change: Cancel old, schedule new
- [ ] Unit tests: 80%+ coverage
- [ ] All tests passing

**Files to Create/Modify**:
- `lib/core/services/background_scan_manager.dart` (NEW)
- Tests: `test/unit/services/background_scan_manager_test.dart`

---

### Task C: Notifications & Battery/Network Optimization
**Model Assignment**: Haiku
**Complexity**: Low-Medium
**Estimated Duration**: 3-4 hours
**GitHub Issue**: #90

**Objective**: Implement notifications for scan results and resource-aware scanning

**Key Responsibilities**:
1. Create notifications when unmatched emails found
2. Tap action navigates to ProcessResultsScreen
3. Battery optimization: Skip if battery < 20%
4. Network optimization: Skip if WiFi-only + on cellular
5. Settings integration for optimization controls

**Acceptance Criteria**:
- [ ] Notification channel created with unique ID
- [ ] Notification shows: "Background scan complete: X unmatched emails"
- [ ] Tap action navigates to ProcessResultsScreen
- [ ] Notifications only shown if unmatched_count > 0
- [ ] Battery level checking (battery_plus package)
- [ ] Network connectivity checking (connectivity_plus package)
- [ ] Skip scan if battery < 20%
- [ ] Skip if WiFi-only mode + cellular
- [ ] Unit tests: 80%+ coverage
- [ ] All tests passing

**Files to Create/Modify**:
- `lib/core/services/background_scan_notification_service.dart` (NEW)
- `lib/core/services/background_scan_worker.dart` (updated with optimization checks)
- Tests: `test/unit/services/background_scan_notification_service_test.dart`

**Dependencies**:
- `workmanager` (already used)
- `flutter_local_notifications` (already used)
- `connectivity_plus` (add to pubspec.yaml)
- `battery_plus` (add to pubspec.yaml)

---

### Task D: End-to-End Integration Tests & Manual Testing
**Model Assignment**: Haiku
**Complexity**: Medium
**Estimated Duration**: 3-4 hours
**GitHub Issue**: #91

**Objective**: Comprehensive testing of background scanning workflow

**Test Workflows**:
1. Enable background scans, verify WorkManager scheduling
2. Scan execution with multiple accounts
3. Unmatched email persistence across scans
4. Notification appears when unmatched > 0
5. Battery/network optimization prevents scan
6. Disable scanning, verify cancel behavior

**Manual Testing**:
1. Enable background scans every 15 minutes
2. Monitor Android logcat for background scan execution
3. Wait for scheduled scan, verify results appear
4. Verify notification display
5. Tap notification, verify navigation to ProcessResultsScreen
6. Review unmatched emails in results

**Acceptance Criteria**:
- [ ] 6+ integration test workflows
- [ ] Database cleanup between tests (no constraint violations)
- [ ] All integration tests passing (100% success rate)
- [ ] Manual testing documented with observations
- [ ] Verify WorkManager triggering at configured interval
- [ ] Verify notification delivery
- [ ] Verify results persistence
- [ ] Zero code analysis errors

**Files to Create/Modify**:
- `test/integration/sprint_7_background_scan_workflow_test.dart` (NEW)
- `test/integration/background_scan_with_notifications_test.dart` (NEW)
- Tests: Battery/network optimization scenarios

---

## Database Schema Changes

### New BackgroundScanLog Table

```sql
CREATE TABLE IF NOT EXISTS background_scan_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL,
  scheduled_time INTEGER NOT NULL,          -- Unix timestamp
  actual_start_time INTEGER,                 -- Unix timestamp, NULL if not started
  actual_end_time INTEGER,                   -- Unix timestamp, NULL if failed
  status TEXT NOT NULL,                      -- 'success', 'failed', 'retry'
  error_message TEXT,                        -- NULL if successful
  emails_processed INTEGER DEFAULT 0,
  unmatched_count INTEGER DEFAULT 0,
  FOREIGN KEY(account_id) REFERENCES accounts(account_id)
);
```

**Purpose**: Track background scan execution for debugging and monitoring

---

## Architecture Diagram

```
User Configures Frequency
        ↓
   Settings Screen
        ↓
BackgroundScanManager.scheduleBackgroundScans()
        ↓
   WorkManager (Android)
        ↓
   [Periodic Trigger at Interval]
        ↓
BackgroundScanWorker.perform()
        ↓
├─ Load enabled accounts
├─ For each account:
│  ├─ Check battery/network
│  ├─ Create EmailScanner
│  ├─ Execute scan
│  └─ Save results
├─ Log execution (BackgroundScanLog)
└─ Check unmatched_count
        ↓
   If unmatched > 0:
        ↓
BackgroundScanNotificationService
        ↓
   Show Notification
        ↓
   User taps → Navigate to ProcessResultsScreen
```

---

## Implementation Guidelines

### Reuse Existing Patterns
1. **EmailScanner**: Existing code, no modifications needed
2. **ScanResult/UnmatchedEmail**: Existing storage, no modifications needed
3. **Notifications**: Use `flutter_local_notifications` (already in project)
4. **Database**: Use existing DatabaseHelper and stores

### Key Design Decisions

**1. Background Mode is Read-Only**
- Background scans EVALUATE rules but do NOT execute actions
- Results show "would delete" / "would move" (proposed)
- User reviews results and confirms in ProcessResultsScreen
- Prevents accidental email deletion in background

**2. Separate Results from Manual Scans**
- Each background scan replaces previous background result
- Maintains separate UnmatchedEmail list from manual scans
- Users can keep/compare both types of results

**3. Account Filtering**
- Only scan accounts where `background_scan_enabled = true`
- Use `selected_folders` from AccountSettings
- If no folders selected: INBOX + provider junk folder

**4. Optimization Strategy**
- Battery: Skip if < 20% (configurable)
- Network: Skip if WiFi-only mode + cellular
- Respects WorkManager system constraints (Doze mode, etc.)

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| WorkManager not triggering | High | Low | Extensive integration testing, manual verification |
| Battery drain | High | Medium | Check battery level before scanning, make frequency configurable |
| Network congestion | Medium | Low | Use existing error handling + exponential backoff |
| Notification not appearing | Medium | Low | Test notification channel creation + permissions |
| Auth failures in background | Medium | Medium | Use getValidAccessToken() to refresh tokens automatically |

---

## Testing Strategy

### Unit Tests (40+ tests expected)
- BackgroundScanWorker logic
- BackgroundScanManager scheduling
- Battery/network optimization checks
- Notification building

### Integration Tests (6+ workflows)
1. Enable → Schedule → Trigger → Execute
2. Multiple accounts + folder selection
3. Error handling + retry logic
4. Notification delivery
5. Settings persistence

### Manual Testing
- Android emulator with WorkManager test APIs
- Real device testing (if available)
- Battery/network condition simulation
- Notification verification

---

## Success Criteria

### Definition of Done for Sprint 7

[OK] **Functionality**:
- [ ] Background scans execute at configured interval
- [ ] All enabled accounts scanned
- [ ] Results saved to database with ScanResult + UnmatchedEmail
- [ ] Notifications sent when unmatched > 0
- [ ] Battery/network optimizations working
- [ ] Can enable/disable/change frequency

[OK] **Code Quality**:
- [ ] All unit tests passing (80%+ coverage)
- [ ] All integration tests passing (100% success)
- [ ] Zero code analysis errors/warnings
- [ ] Code follows project patterns

[OK] **Documentation**:
- [ ] Code comments for complex logic
- [ ] Test documentation with workflows
- [ ] Manual testing results documented
- [ ] Database schema additions documented

[OK] **Performance**:
- [ ] Background scans do not block UI
- [ ] Scans complete within reasonable time (≤2 min for typical account)
- [ ] Battery impact minimal (verify with Android Profiler)

---

## Effort Estimate

| Task | Estimated | Actual* | Notes |
|------|-----------|---------|-------|
| Task A: BackgroundScanWorker | 4-5h | - | Core worker, most complex |
| Task B: BackgroundScanManager | 2-3h | - | Straightforward scheduling |
| Task C: Notifications + Optimization | 3-4h | - | Multiple components |
| Task D: Testing | 3-4h | - | Integration + manual |
| **Total** | **12-16h** | - | *Actual to be filled post-sprint |

**Confidence**: High (clear requirements, existing patterns to reuse)

---

## Timeline

**Sprint Duration**: 2-3 days (Jan 27-29, 2026)

**Suggested Execution Order**:
1. Day 1: Task A (BackgroundScanWorker) - Sonnet architecture review, then Haiku implementation
2. Day 1-2: Task B (BackgroundScanManager) - Can start in parallel after A starts
3. Day 2: Task C (Notifications + Optimization)
4. Day 2-3: Task D (Testing + Manual verification)

**Flexibility**: Tasks are loosely coupled; B can start before A finishes if architecture clear

---

## Handoff Instructions

### For Sonnet (Task A Architecture Review)
1. Review BackgroundScanWorker architecture approach
2. Verify alignment with existing EmailScanner pattern
3. Confirm database schema for BackgroundScanLog
4. Approve implementation approach before Haiku starts

### For Haiku (Tasks A/B/C/D Implementation)
1. Implement BackgroundScanWorker following Sonnet-approved design
2. Implement BackgroundScanManager (can be parallel with A)
3. Implement notifications + battery/network checks
4. Write comprehensive integration + unit tests
5. Conduct manual testing on Android emulator

---

## Files Summary

### New Files (6 files)
1. `lib/core/services/background_scan_worker.dart` - Worker implementation
2. `lib/core/services/background_scan_manager.dart` - Manager/scheduler
3. `lib/core/services/background_scan_notification_service.dart` - Notifications
4. `lib/core/services/background_scan_log_store.dart` - Database ops
5. `test/integration/sprint_7_background_scan_workflow_test.dart` - Integration tests
6. `test/integration/background_scan_with_notifications_test.dart` - Notification tests

### Modified Files (1 file)
1. `pubspec.yaml` - Add `connectivity_plus` and `battery_plus` packages

### Database Migration
1. New BackgroundScanLog table (migrations folder)

---

## Next Sprint Dependency

**Sprint 8**: Windows desktop background scanning using Task Scheduler

Sprint 7 creates the Android foundation; Sprint 8 extends to Windows with similar patterns.

---

## Approval Checklist

For user approval of Sprint 7 Plan:

- [ ] Sprint objectives clear and achievable
- [ ] Tasks breakdown is logical and complete
- [ ] Model assignments (Sonnet → Haiku) make sense
- [ ] Effort estimate (12-16 hours) seems reasonable
- [ ] Risk assessment acceptable
- [ ] Testing strategy comprehensive
- [ ] Success criteria clear and measurable
- [ ] Ready to approve plan and begin execution

---

**Sprint 7 Status**: [TARGET] AWAITING USER APPROVAL

After approval, execution will follow this sequence:
1. [OK] Phase 0 (Pre-sprint) - COMPLETE
2. [OK] Phase 1 (Planning) - Complete (this document)
3. → Phase 2 (Execution) - Begin upon approval
4. → Phase 3 (Testing) - Parallel with execution
5. → Phase 4 (PR & Review) - After all tasks complete

