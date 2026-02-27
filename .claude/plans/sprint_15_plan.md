# Sprint 15 Plan: Bug Fixes, Performance, and Settings Management

**Sprint Number**: 15
**Branch**: `feature/20260214_Sprint_15`
**Start Date**: February 14, 2026
**Status**: PLANNING
**Estimated Total Effort**: 42-58 hours

---

## Sprint Objective

Fix critical 100-delete limit bug, implement batch processing for performance, add Settings management UI for safe senders and rules, add Windows directory browser, and implement Windows background scanning.

---

## Sprint Scope Summary

| Priority | Feature/Issue | Title | Effort | Model |
|----------|---------------|-------|--------|-------|
| 1 | #145 | Bug: Scan stops after 100 deletes | 4-8h | Sonnet |
| 2 | F19/#144 | Batch Email Processing | 10-16h | Sonnet |
| 3 | F17 | Manage Safe Senders UI | 6-8h | Haiku |
| 4 | F18 | Manage Rules UI | 8-10h | Haiku |
| 5 | #126 | Windows Directory Browser | 3-4h | Haiku |
| 6 | F5 | Background Scanning - Windows | 14-16h | Sonnet |

**Total Estimated**: 45-62 hours

---

## Issue #145: Bug - Scan stops after deleting 100 emails

**Priority**: CRITICAL
**Type**: Bug Fix
**Estimated Effort**: 4-8 hours
**Model**: Sonnet

### Problem Statement

When running manual scan with "Process Safe Senders and Rules" mode, the scan stops processing after exactly 100 delete operations. Safe sender moves do not count toward this limit.

### Test Data

| Test | Found | Processed | Deleted | Safe |
|------|-------|-----------|---------|------|
| 1 | - | 102 | 100 | - |
| 2 | - | 106 | 100 | - |
| 3 | 491 | 105 | 100 | 4 |

### Root Cause Hypothesis

- AOL IMAP server rate limiting on MOVE commands
- IMAP connection dropping silently after 100 operations
- Server error not being propagated correctly

### Tasks

#### Task 145.A: Investigation and Logging
- Add detailed logging around IMAP MOVE operations
- Log connection state before/after each delete
- Capture any IMAP server responses/errors
- Test with enhanced logging to identify exact failure point

#### Task 145.B: Implement Fix
Based on investigation, implement one of:
1. **Reconnect Strategy**: Reconnect IMAP session every N deletes (e.g., 50)
2. **Error Recovery**: Catch connection drops and reconnect automatically
3. **Batch Operations**: Use IMAP message sequence sets for batch moves
4. **Rate Limiting**: Add delay between operations if server throttling

#### Task 145.C: Testing
- Test with AOL account having >100 spam emails
- Verify scan completes all found emails
- Test error recovery scenarios
- Add unit/integration tests for new functionality

### Acceptance Criteria

- [ ] Scan processes >100 delete operations successfully
- [ ] Errors are caught and handled gracefully
- [ ] User notified of any partial failures
- [ ] Progress continues after recoverable errors
- [ ] All existing tests pass (939+)

### Files Affected

- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`
- `mobile-app/lib/core/services/email_scanner.dart`

---

## F19 / Issue #144: Batch Email Processing

**Priority**: HIGH
**Type**: Enhancement
**Estimated Effort**: 10-16 hours
**Model**: Sonnet
**Note**: May naturally resolve #145 if batching avoids the 100-limit

### Problem Statement

Email processing is slow because each email requires 3 sequential IMAP commands:
1. `markAsRead()` - STORE command
2. `applyFlag()` - STORE command
3. `takeAction()` (move/delete) - MOVE command

For 100 spam emails, this results in 300 network round-trips.

### Solution

Implement batch processing with configurable batch size (default: 10 emails at a time).

### Tasks

#### Task F19.A: Batch Collection
- Collect up to N emails (configurable, default 10) that need the same action type
- Group by: delete, move-to-junk, safe-sender-move

#### Task F19.B: Batch Execution
- Use IMAP message sequence sets for batch STORE commands
- Use IMAP message sequence sets for batch MOVE commands
- Handle partial failures (if 1 of 10 fails, other 9 still process)

#### Task F19.C: Error Handling
- Individual error reporting per email
- Graceful degradation to single-email mode on batch failure
- User notification of partial failures

#### Task F19.D: Testing
- Test with various batch sizes
- Test error scenarios (partial batch failure)
- Performance benchmarking (before/after)

### Acceptance Criteria

- [ ] Emails processed in batches of 10 (configurable)
- [ ] 70%+ reduction in network round-trips
- [ ] Graceful error handling for partial failures
- [ ] Individual error reporting per email
- [ ] Works with Gmail API and IMAP providers

### Files Affected

- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`
- `mobile-app/lib/core/services/email_scanner.dart`

---

## F17: Manage Safe Senders UI in Settings

**Priority**: MEDIUM
**Type**: Enhancement
**Estimated Effort**: 6-8 hours
**Model**: Haiku

### Problem Statement

Users cannot view, edit, or delete safe sender patterns without direct database access. Settings > Safe Senders was mentioned as missing in Sprint 14 testing.

### Solution

Add a "Manage Safe Senders" section to Settings that displays all safe sender patterns.

### Tasks

#### Task F17.A: Safe Senders List Screen
- List all safe sender patterns from database
- Show pattern type (exact email, domain, subdomain)
- Show date added
- Pull-to-refresh functionality

#### Task F17.B: Safe Sender Detail/Edit
- View pattern details
- Edit pattern (with validation)
- Delete individual patterns (with confirmation)

#### Task F17.C: Search/Filter
- Search safe senders by pattern or email
- Filter by pattern type

### Acceptance Criteria

- [ ] Settings > Safe Senders shows all patterns
- [ ] Can view, edit, delete individual patterns
- [ ] Search/filter functionality works
- [ ] Changes persist to database
- [ ] UI matches existing Settings design

### Files Affected

- `mobile-app/lib/ui/screens/settings_screen.dart`
- `mobile-app/lib/ui/screens/safe_senders_management_screen.dart` (NEW)
- `mobile-app/lib/core/storage/database_helper.dart`

---

## F18: Manage Rules UI in Settings

**Priority**: MEDIUM
**Type**: Enhancement
**Estimated Effort**: 8-10 hours
**Model**: Haiku

### Problem Statement

Users cannot view, edit, or delete block rules without YAML editing or direct database access.

### Solution

Add a "Manage Rules" section to Settings that displays all block rules.

### Tasks

#### Task F18.A: Rules List Screen
- List all rules from database
- Show rule name, action (delete/move), enabled status
- Show execution order
- Toggle enable/disable

#### Task F18.B: Rule Detail/Edit
- View rule details (patterns, conditions)
- Edit rule properties
- Delete individual rules (with confirmation)

#### Task F18.C: Reorder Rules
- Drag-and-drop reordering for execution priority
- Or up/down buttons for priority adjustment

### Acceptance Criteria

- [ ] Settings > Manage Rules shows all rules
- [ ] Can view, edit, delete, enable/disable rules
- [ ] Can reorder rules (execution priority)
- [ ] Changes persist to database
- [ ] UI matches existing Settings design

### Files Affected

- `mobile-app/lib/ui/screens/settings_screen.dart`
- `mobile-app/lib/ui/screens/rules_management_screen.dart` (NEW)
- `mobile-app/lib/core/storage/database_helper.dart`

---

## Issue #126: Windows Directory Browser Widget

**Priority**: LOW
**Type**: Enhancement
**Estimated Effort**: 3-4 hours
**Model**: Haiku

### Problem Statement

CSV export path selection requires typing full path. Native folder picker would improve UX.

### Solution

Implement native Windows folder picker using `file_picker` package.

### Tasks

#### Task 126.A: Integrate file_picker
- Add/update `file_picker` package dependency
- Create reusable directory picker widget

#### Task 126.B: Update CSV Export
- Replace text input with folder picker button
- Show selected path
- Remember last used path

### Acceptance Criteria

- [ ] Native Windows folder picker dialog opens
- [ ] Selected path displayed in UI
- [ ] Last used path remembered
- [ ] Works on Windows desktop

### Files Affected

- `mobile-app/pubspec.yaml`
- `mobile-app/lib/ui/screens/results_display_screen.dart`
- `mobile-app/lib/ui/widgets/directory_picker.dart` (NEW)

---

## F5: Background Scanning - Windows Desktop

**Priority**: LOW (this sprint) - Foundation only
**Type**: Enhancement
**Estimated Effort**: 14-16 hours
**Model**: Sonnet

### Problem Statement

Users must manually run scans. Background scanning with Task Scheduler would automate spam filtering.

### Solution

Implement Windows background scanning with Task Scheduler integration.

### Tasks

#### Task F5.A: Command-Line Background Mode
- Add `--background-scan` command-line argument
- Headless scan execution (no UI)
- Log results to file

#### Task F5.B: Task Scheduler Integration
- Register periodic scan task with Windows Task Scheduler
- Configurable frequency from settings
- Use PowerShell/schtasks for registration

#### Task F5.C: System Tray Enhancements
- Show scan status in system tray tooltip
- Notification balloon on scan completion
- "Run Scan Now" from tray menu

#### Task F5.D: Testing
- Test scheduled task execution
- Test notification delivery
- Test various scan frequencies

### Acceptance Criteria

- [ ] `--background-scan` runs headless scan
- [ ] Task Scheduler task registered successfully
- [ ] System tray shows scan status
- [ ] Notifications shown on completion
- [ ] Configurable scan frequency

### Files Affected

- `mobile-app/lib/main.dart` - Command-line argument parsing
- `mobile-app/lib/core/services/windows_background_service.dart` (NEW)
- `mobile-app/lib/core/services/windows_system_tray_service.dart`
- `mobile-app/lib/core/services/windows_task_scheduler.dart` (NEW)

---

## Sprint Schedule

| Phase | Task | Effort | Model | Status |
|-------|------|--------|-------|--------|
| 1 | Sprint Kickoff & Planning | 1h | - | IN PROGRESS |
| 2.1 | #145 Investigation | 2-3h | Sonnet | PENDING |
| 2.2 | #145 Fix Implementation | 2-4h | Sonnet | PENDING |
| 2.3 | F19 Batch Processing | 10-16h | Sonnet | PENDING |
| 2.4 | F17 Safe Senders UI | 6-8h | Haiku | PENDING |
| 2.5 | F18 Rules UI | 8-10h | Haiku | PENDING |
| 2.6 | #126 Directory Browser | 3-4h | Haiku | PENDING |
| 2.7 | F5 Background Scanning | 14-16h | Sonnet | PENDING |
| 3 | Code Review & Testing | 2-3h | - | PENDING |
| 4 | Push & Create PR | 1h | - | PENDING |
| 4.5 | Sprint Review | 1h | - | PENDING |

---

## Model Assignments

| Task | Model | Rationale |
|------|-------|-----------|
| #145 (Bug Fix) | Sonnet | Debugging, IMAP protocol |
| F19 (Batch Processing) | Sonnet | IMAP protocol, error handling |
| F17 (Safe Senders UI) | Haiku | UI implementation, straightforward |
| F18 (Rules UI) | Haiku | UI implementation, straightforward |
| #126 (Directory Browser) | Haiku | Simple widget integration |
| F5 (Background Scanning) | Sonnet | Windows integration, Task Scheduler |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| #145 root cause differs from hypothesis | Medium | Medium | Thorough investigation first |
| Batch processing adds complexity | Low | Medium | Graceful fallback to single-email mode |
| Task Scheduler permissions | Medium | Medium | Document admin requirements |
| Large sprint scope | Medium | Medium | Prioritize #145 and F19 first |
| UI screens take longer than estimated | Medium | Low | Defer F5 if needed |

---

## Dependencies

- AOL account with >100 spam emails for testing #145
- Windows desktop for F5 testing
- Sprint 14 complete (PR #143 merged) ✓

---

## Success Criteria

- [ ] #145 resolved - scans process >100 deletes
- [ ] F19 implemented - batch processing with 70%+ round-trip reduction
- [ ] F17 implemented - Manage Safe Senders in Settings
- [ ] F18 implemented - Manage Rules in Settings
- [ ] #126 implemented - Windows directory browser
- [ ] F5 implemented - Background scanning with Task Scheduler
- [ ] All tests passing (939+)
- [ ] Analyzer warnings <50
- [ ] Manual testing confirms all features
- [ ] PR created and ready for review

---

## Execution Order

1. **#145** (CRITICAL) - Fix first to unblock user
2. **F19/#144** - Batch processing may help #145 and improves performance
3. **F17** - Safe Senders UI (user mentioned missing in Sprint 14)
4. **F18** - Rules UI (complements F17)
5. **#126** - Directory browser (small, quick win)
6. **F5** - Background scanning (largest, do last)

If time runs short, F5 can be partially completed or deferred to Sprint 16.
