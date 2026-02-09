# Sprint 14 Plan: Settings Restructure + UX Improvements

**Sprint Duration**: February 7-8, 2026
**Sprint Goal**: Restructure settings for background scan readiness, improve scan progress UX, add demo infrastructure
**Model Assignment**: Sonnet (primary), Haiku (testing, cleanup)
**Branch**: `feature/20260207_Sprint_14`

---

## Sprint Overview

**Approved Issues**: 5 issues, 41-62 hours estimated
- #128: Progressive Folder-by-Folder Scan Updates (5-8h)
- #123 + #124: Settings Screen Restructure + Default Folders UI (13-18h)
- #125: Enhanced Demo Scan - 50+ sample emails (8-12h)
- #138: Enhanced Deleted Email Processing (11-18h)
- #130: Reduce Analyzer Warnings to <50 (4-6h) **FINAL TASK**

**Key Priorities**:
1. **HIGH**: #128, #123+#124, #130 (critical path, blocks future work)
2. **MEDIUM**: #125, #138 (enhances testing and email processing)

**Deferred to Sprint 15**: #139 (Rule Override Detection)

---

## Issue #128: Progressive Folder-by-Folder Scan Updates

**Priority**: HIGH
**Type**: Enhancement (was Bug)
**Effort**: 5-8 hours (Sonnet)
**Model**: Sonnet

### Problem
Users experience 20+ second gaps with no status updates during scan, think app is frozen.

### Current Behavior (Sprint 13)
- 0-20 seconds: Shows "Scanning..." with no updates
- ~20 seconds: First update
- ~35 seconds: Second update
- ~50 seconds: Final update/completion

### Desired Behavior
- Update every ~2 seconds with folder progress messages
- Show current folder being scanned + count
- Show transition messages between folders
- Show "Scan complete." when finished

### Implementation Tasks

**A. Update EmailScanProvider throttling** (1h):
- Change `_progressTimeInterval` from 3s to 2s
- Update status message format to include folder info
- Add "Scan complete." message in `completeScan()`

**B. Modify adapters for folder-by-folder fetching** (3-5h):
- Refactor `fetchMessages()` to yield results per folder
- Report folder name + count during fetch
- Update Gmail, AOL, Generic IMAP adapters
- Maintain backward compatibility

**C. Update EmailScanner to report folder progress** (1-2h):
- Call `setCurrentFolder()` before processing each folder's emails
- Update status messages with folder names
- Show email counts per folder

**D. Testing** (1h):
- Test with Gmail (750+ emails, multiple folders)
- Test with AOL (multiple folders)
- Verify 2-second update frequency
- Verify "Scan complete." message appears

### Acceptance Criteria
- [ ] Status updates every ~2 seconds during scan
- [ ] Status message includes current folder name
- [ ] Status message includes count of emails found so far
- [ ] Folder transition messages shown
- [ ] "Scan complete." message shown when scan finishes
- [ ] Works for Gmail, IMAP, AOL providers
- [ ] No performance degradation

### Files Affected
- `mobile-app/lib/core/providers/email_scan_provider.dart` - Update throttling, add completion message
- `mobile-app/lib/core/services/email_scanner.dart` - Add folder progress tracking
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Folder-by-folder fetch
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - Folder-by-folder fetch

---

## Issue #123 + #124: Settings Screen Restructure + Default Folders UI

**Priority**: HIGH
**Type**: Enhancement
**Effort**: 13-18 hours (Sonnet)
**Model**: Sonnet

### Problem
- Account Settings has redundant override sections (Folder, Scan Mode, Background)
- Manual Scan settings missing Default Folders UI
- Background settings missing Default Folders UI and Scan Mode settings
- Scan Screen > Select Folders section will be removed in future update (must provide Default Folders UI NOW)
- TWO scan mode selectors: Scan Page button (per-scan override) + Settings (persistent default, UNUSED)

### Solution
1. Remove Scan Page "Scan Mode:" button (single source of truth = Settings)
2. Remove all override sections from Account Tab
3. Add Default Folders UI to Manual Scan tab
4. Add Scan Mode selector + Default Folders UI to Background tab
5. Manual and Background have COMPLETELY INDEPENDENT scan mode settings

### Implementation Tasks

**A. Remove Scan Page Scan Mode UI** (1-2h):
- Remove "Scan Mode:" button from ScanProgressScreen (line 278-284)
- Remove `_showScanModeDialog()` method and related dialog logic
- Remove all override mechanism code

**B. Update Scan Initialization Logic** (1-2h):
- Update `account_setup_screen.dart:194` - Replace hardcoded `ScanMode.readonly` with `await settingsStore.getManualScanMode()`
- Update `account_maintenance_screen.dart:355` - Replace hardcoded `ScanMode.readonly` with `await settingsStore.getManualScanMode()`
- Background scan initialization already uses correct method (no changes)
- Test: Manual scans use Manual Scan Mode from Settings
- Test: Background scans use Background Scan Mode from Settings

**C. Settings Screen Restructure** (8-10h):
- **Account Tab**: Remove Folder Override, Scan Mode Override, Background Scan Override sections
- **Manual Scan Tab**:
  - Keep Scan Mode selector (becomes authoritative)
  - Add Default Folders UI (reuse FolderSelectionScreen component)
  - Populate with saved folders or provider defaults
- **Background Tab**:
  - Add Scan Mode selector (SEPARATE from Manual Scan, uses `getBackgroundScanMode()`)
  - Add Default Folders UI (reuse FolderSelectionScreen component)
  - Default to Read-Only if not set

**D. Default Folders UI Component** (4-6h):
- Create reusable DefaultFoldersSelector widget
- UI matches SelectFoldersToScan.png screenshot
- Populate with current saved folders for that scan type (Manual/Background)
- If no saved folders, use provider defaults:
  - Gmail: INBOX, [Gmail]/Spam
  - AOL: INBOX, Bulk Mail
- Integrate into both Manual Scan and Background tabs

**E. Testing** (2h):
- Test Account Tab cleanup (no override sections)
- Test Manual Scan Mode from Settings applies to scans
- Test Background Scan Mode from Settings (separate from Manual)
- Test Default Folders UI for Manual and Background
- Test provider defaults populate correctly
- All existing tests pass

### Acceptance Criteria
- [ ] Scan Page "Scan Mode:" button removed
- [ ] Scan initialization reads from SettingsStore (not hardcoded)
- [ ] Account Tab: All override sections removed
- [ ] Manual Scan Tab: Scan Mode selector active, Default Folders UI added
- [ ] Background Tab: Scan Mode selector added, Default Folders UI added
- [ ] Manual and Background scan modes are independent
- [ ] Default Folders UI matches Select Folders screen
- [ ] Provider defaults populate when no saved folders
- [ ] All tests pass

### Files Affected
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Remove Scan Mode button
- `mobile-app/lib/ui/screens/account_setup_screen.dart` - Use SettingsStore for scan mode
- `mobile-app/lib/ui/screens/account_maintenance_screen.dart` - Use SettingsStore for scan mode
- `mobile-app/lib/ui/screens/settings_screen.dart` - Restructure tabs, add Default Folders UI
- `mobile-app/lib/ui/widgets/default_folders_selector.dart` - NEW: Reusable component
- `mobile-app/test/ui/screens/settings_screen_test.dart` - Update tests

---

## Issue #125: Enhanced Demo Scan - 50+ Sample Emails

**Priority**: MEDIUM
**Type**: Enhancement, Testing Infrastructure
**Effort**: 8-12 hours (Haiku)
**Model**: Haiku

### Problem
No way to test UI and demonstrate features without live email account.

### Solution
Create comprehensive demo scan mode with 50+ sample emails for testing and demos.

### Implementation Tasks

**A. Create Mock Email Data** (3-4h):
- Generate 50+ sample EmailMessage objects
- Various folder names (INBOX, Spam, Junk, Promotions, etc.)
- Mix of matched and unmatched emails
- "No Rule" sample emails
- Various spam patterns from integration tests
- Include domain patterns, subject patterns, body patterns
- Include subdomains and wildcards

**B. Create MockEmailProvider** (2-3h):
- Implement SpamFilterPlatform interface
- Return mock email data
- Simulate folder discovery
- Mock delete/move operations (track actions, don't actually do anything)

**C. Integrate Demo Mode into UI** (2-3h):
- Add "Demo Mode" toggle in Platform Selection screen
- When enabled, use MockEmailProvider instead of real provider
- Show demo indicator in scan progress
- Allow rule creation from demo emails

**D. Testing** (1-2h):
- Test demo scan completes successfully
- Test rule creation from demo emails
- Test UI displays demo emails correctly
- Verify no crashes with mock provider

### Acceptance Criteria
- [ ] 50+ sample emails created with variety
- [ ] MockEmailProvider implements full interface
- [ ] Demo Mode toggle added to Platform Selection
- [ ] Demo scan works end-to-end
- [ ] Can create rules from demo emails
- [ ] All tests pass

### Files Affected
- `mobile-app/lib/core/services/mock_email_data.dart` - NEW: Sample email generator
- `mobile-app/lib/adapters/email_providers/mock_email_provider.dart` - NEW: Mock provider
- `mobile-app/lib/ui/screens/platform_selection_screen.dart` - Add Demo Mode toggle
- `mobile-app/test/integration/demo_mode_test.dart` - NEW: Demo mode tests

---

## Issue #138: Enhanced Deleted Email Processing

**Priority**: MEDIUM-HIGH
**Type**: Enhancement
**Effort**: 11-18 hours (Sonnet)
**Model**: Sonnet

### Problem
When deleting spam, emails are only moved to folder. No indication of which rule matched or that email was processed.

### Solution
Mark deleted emails as read AND flag/categorize them with the rule name used.

### Implementation Tasks

**A. Research Provider APIs** (1-2h):
- Gmail: Labels API for adding labels
- AOL: IMAP KEYWORD flags or Categories API
- Generic IMAP: KEYWORD flags
- Outlook: Categories API (when supported)
- Document auto-create behavior for each provider

**B. Add Mark-as-Read before Delete** (2-3h):
- Update SpamFilterPlatform interface with `markAsRead()` method
- Implement for Gmail, AOL, Generic IMAP
- Call before `deleteMessage()` in email_scanner.dart
- Test with all providers

**C. Capture Matched Rule in Delete Action** (1-2h):
- Pass matched rule name to `deleteMessage()` method
- Update SpamFilterPlatform interface
- Update all adapter implementations
- Track rule name in email action result

**D. Implement Provider-Specific Flagging** (5-8h):
- **Gmail**: Use Labels API to add label with rule name
  - Check if label exists
  - Create label if doesn't exist (auto-create)
  - Apply label to email
- **AOL**: Use IMAP KEYWORD or Categories API
  - Research which is supported
  - Implement keyword/category creation and application
- **Generic IMAP**: Use KEYWORD flag
  - Add keyword with rule name
  - Create if doesn't exist (server-dependent)
- **Outlook**: Use Categories API (if/when supported)
  - Defer to future if not yet implemented

**E. Testing** (2-3h):
- Test mark-as-read with Gmail, AOL, IMAP
- Test rule name flagging with all providers
- Test auto-create labels/categories/keywords
- Verify emails properly tagged
- All existing tests pass

### Acceptance Criteria
- [ ] Emails marked as read before delete
- [ ] Gmail: Labels created and applied with rule name
- [ ] AOL: Keywords/Categories created and applied
- [ ] IMAP: KEYWORD flags added
- [ ] Auto-create works for all providers
- [ ] Readonly mode respects both actions
- [ ] All tests pass

### Files Affected
- `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart` - Add markAsRead(), update deleteMessage()
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Implement mark+flag
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - Implement mark+flag
- `mobile-app/lib/core/services/email_scanner.dart` - Call markAsRead() before delete
- `mobile-app/test/integration/enhanced_delete_test.dart` - NEW: Test mark+flag behavior

---

## Issue #130: Reduce Analyzer Warnings to <50 (FINAL TASK)

**Priority**: HIGH (Quality Gate)
**Type**: Technical Debt
**Effort**: 4-6 hours (Haiku)
**Model**: Haiku

### Problem
Current codebase has 214 analyzer warnings creating noise that can mask new issues.

### Solution
Fix high-count, low-complexity warnings to reduce total to <50.

### Implementation Tasks

**A. Capture Baseline** (5min):
- Run `flutter analyze` at Sprint 14 start
- Save baseline: 214 warnings
- Commit baseline to plan

**B. Identify New Warnings from Sprint 14** (30min):
- Run `flutter analyze` after all Sprint 14 tasks complete
- Compare to baseline
- Document any NEW warnings introduced

**C. Fix New Warnings** (1-2h):
- Fix ALL new warnings from Sprint 14 work (highest priority)
- Ensure Sprint 14 code is clean

**D. Fix High-Count Baseline Warnings** (2-3h):
- `unnecessary_brace_in_string_interps` (~50) - Remove `{}`
- `curly_braces_in_flow_control_structures` (~30) - Add `{}`
- `unused_import` (~20) - Remove imports
- `dangling_library_doc_comments` (~15) - Move comments
- Continue until <50 total warnings

**E. Verify and Test** (30min-1h):
- Run `flutter analyze` - Confirm <50 warnings
- Run `flutter test` - Confirm 100% pass rate
- No new warnings introduced by cleanup
- Commit analyzer cleanup

### Acceptance Criteria
- [ ] Baseline captured at Sprint 14 start (214 warnings)
- [ ] Final count captured before cleanup
- [ ] ALL new warnings from Sprint 14 fixed
- [ ] High-count baseline warnings fixed
- [ ] Final analyzer count <50 warnings
- [ ] All tests pass (100% pass rate)
- [ ] No new warnings from cleanup work

### Files Affected
- Multiple files across `mobile-app/lib/` and `mobile-app/test/`
- Will be identified during execution

---

## Testing Strategy

### Unit Tests
- Maintain 100% pass rate throughout sprint
- Add new tests for:
  - Folder progress tracking (#128)
  - Settings restructure (#123)
  - Mock email provider (#125)
  - Enhanced delete processing (#138)

### Integration Tests
- Test end-to-end scenarios:
  - Progressive scan with multiple folders (#128)
  - Settings changes apply to scans (#123)
  - Demo mode full workflow (#125)
  - Enhanced delete with all providers (#138)

### Manual Testing (Sprint Review)
- Test with real Gmail account (750+ emails, multiple folders)
- Test settings changes persist and apply
- Test demo mode for screenshots and demos
- Test enhanced delete flagging with real emails

---

## Risk Assessment

**Over-Capacity Risk**: 41-62h estimated vs. ~24-40h typical capacity

**Mitigation**:
- Focus on HIGH priority items first (#128, #123+#124, #130)
- #125 and #138 can slip to Sprint 15 if needed without blocking future work
- Continuous testing to catch issues early
- Follow stopping criteria strictly (SPRINT_STOPPING_CRITERIA.md)

**Technical Risks**:
1. **#128**: Adapter refactoring may be complex - fallback to simpler status message improvements
2. **#123**: Settings restructure touches many screens - thorough testing required
3. **#138**: Provider API research may reveal limitations - defer unsupported providers

---

## Definition of Done

### For Each Issue
- [ ] Implementation complete per acceptance criteria
- [ ] Unit tests added/updated and passing
- [ ] Integration tests added/updated and passing
- [ ] Code reviewed (self-review with analyzer)
- [ ] No new analyzer warnings introduced
- [ ] Documentation updated (inline comments, CHANGELOG.md)

### For Sprint 14
- [ ] All 5 issues complete or deferred with justification
- [ ] Issue #130 (analyzer warnings) complete LAST
- [ ] All tests passing (100%)
- [ ] Analyzer warnings <50
- [ ] CHANGELOG.md updated with all changes
- [ ] Branch ready for PR to develop
- [ ] Manual testing checklist complete

---

## Execution Notes

- **Autonomous Execution**: All 5 issues and sub-tasks pre-approved by user
- **No Additional Approval Needed**: Unless blocking condition per SPRINT_STOPPING_CRITERIA.md
- **Stopping Criteria**: Reference D:\Data\Harold\github\spamfilter-multi\docs\SPRINT_STOPPING_CRITERIA.md
- **Execution Order**: #128 → #123+#124 → #125 → #138 → #130 (FINAL)
- **Branch**: `feature/20260207_Sprint_14`
- **Target**: Ready for full manual testing after #130 complete

---

**Plan Created**: February 7, 2026
**Model**: Claude Sonnet 4.5
**Status**: APPROVED - Begin Execution
