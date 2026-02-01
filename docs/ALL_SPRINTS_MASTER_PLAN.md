# All Sprints Master Plan

**Purpose**: Master planning document for current sprint, next sprint, and future features under consideration.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: January 31, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** (this doc) | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases -1 to 4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Past Sprint Summary](#past-sprint-summary)
2. [Current Sprint](#current-sprint)
3. [Next Sprint](#next-sprint)
4. [Future Features (Prioritized)](#future-features-prioritized)
5. [Feature Details](#feature-details)

---

## Past Sprint Summary

Historical sprint information has been moved to individual summary documents and CHANGELOG.md. For detailed retrospectives, see:

| Sprint | Summary Document | Status | Duration |
|--------|------------------|--------|----------|
| 1 | SPRINT_1_RETROSPECTIVE.md | ✅ Complete | ~4h (Jan 19-24, 2026) |
| 2 | SPRINT_2_RETROSPECTIVE.md | ✅ Complete | ~6h (Jan 24, 2026) |
| 3 | SPRINT_3_SUMMARY.md | ✅ Complete | ~8h (Jan 24-25, 2026) |
| 9 | SPRINT_9_RETROSPECTIVE.md | ✅ Complete | ~2h (Jan 30-31, 2026) |

**Key Achievements**:
- **Sprint 1**: Database foundation (SQLite schema, migration infrastructure)
- **Sprint 2**: Database rule storage and integration
- **Sprint 3**: Safe sender exceptions with database storage
- **Sprint 9**: Development workflow improvements (25 process enhancements)

See CHANGELOG.md for detailed feature history.

---

## Current Sprint

**SPRINT 10: Advanced UI & Polish**

**Status**: 📋 PLANNED (not yet started)

**Estimated Duration**: 12-14 hours

**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Complete feature parity across platforms + UI/UX polish

**Tasks**:
- **Task A**: Android-specific enhancements
  - Material Design 3 components
  - Bottom navigation with proper back handling
  - Floating action buttons for quick actions
  - Pull-to-refresh for scan results

- **Task B**: Windows Desktop enhancements
  - Fluent Design principles
  - System tray integration
  - Keyboard shortcuts (Ctrl+N for new scan, etc.)
  - Toast notifications for background scans

- **Task C**: Cross-platform UI polish
  - Consistent color scheme across platforms
  - Loading states and skeleton screens
  - Empty states with helpful messaging
  - Error screens with recovery actions
  - Accessibility improvements (screen reader support, high contrast)

**Acceptance Criteria**:
- [ ] Material Design 3 components implemented on Android
- [ ] Fluent Design implemented on Windows Desktop
- [ ] All screens have loading states and empty states
- [ ] Keyboard shortcuts functional on Windows
- [ ] System tray integration works on Windows
- [ ] Pull-to-refresh works on Android
- [ ] All tests pass (100% pass rate)
- [ ] Zero analyzer warnings

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Platform-specific UI inconsistencies | Medium | Medium | Test on both platforms, document platform differences |
| Accessibility requirements unclear | Low | High | Reference Flutter accessibility guidelines, test with screen reader |
| System tray integration complex | Medium | Low | Use well-tested Flutter packages, have fallback UI |

**Dependencies**: Sprints 1-3, 9 (database, safe senders, workflow improvements)

---

## Next Sprint

**SPRINT 11: Production Readiness & Testing**

**Status**: 📋 PLANNED

**Estimated Duration**: 14-16 hours

**Model Assignment**: Sonnet (optimization) + Haiku (testing)

**Objective**: Production-ready release with comprehensive testing and optimization

**Tasks**:
- **Task A**: Database Management
  - Implement database vacuum on app startup (if needed)
  - Add database backup/restore functionality
  - Create database diagnostic tool for support

- **Task B**: Comprehensive Testing Suite
  - End-to-end tests for all critical user paths
  - Performance benchmarking for large rule sets (100+ rules, 1000+ safe senders)
  - Stress testing with 10,000+ email inbox
  - Cross-platform smoke tests (Android, Windows, iOS if available)

- **Task C**: Error Handling & Logging
  - Implement crash reporting (Sentry or Firebase Crashlytics)
  - Add analytics for feature usage (privacy-preserving)
  - Comprehensive error messages for all failure modes
  - Log rotation and size limits

- **Task D**: Performance Optimization
  - Profile app startup time (target: <2s)
  - Optimize database queries (add missing indexes)
  - Reduce memory footprint for large scans
  - Lazy loading for UI lists

**Acceptance Criteria**:
- [ ] Database vacuum implemented and tested
- [ ] Backup/restore functionality works correctly
- [ ] All end-to-end tests pass on Android and Windows
- [ ] Performance benchmarks meet targets (startup <2s, scan 1000 emails <30s)
- [ ] Crash reporting integrated and tested
- [ ] App startup time <2 seconds on test device
- [ ] Memory usage <200MB for 1000 email scan
- [ ] All tests pass (100% pass rate)
- [ ] Test coverage ≥85%

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Performance targets not achievable | Medium | High | Profile early, identify bottlenecks, have fallback targets |
| Crash reporting adds overhead | Low | Medium | Benchmark overhead, make opt-in if needed |
| Testing 10k inbox requires real account | High | Low | Use test data generator, supplement with real account if available |

**Dependencies**: Sprint 10 (UI polish complete)

---

## Future Features (Prioritized)

Priority based on: Development and testing support for implementing pre-product release.

### Priority 1: Core User Workflows (Required for MVP)

#### F1: Processing Scan Results
**Status**: 📋 PLANNED
**Estimated Effort**: 14-16 hours
**Business Value**: Users can review and process unmatched emails interactively

**Overview**: Backend storage + UI for reviewing and processing unmatched emails (emails that did not match any rules during scan).

**Key Features**:
- Persistent scan result storage (SQLite table)
- One unmatched list per scan type (manual, background)
- Email availability checking (verify email still exists before action)
- Provider-specific email identifiers (Message-ID, IMAP UID, etc.)

**Dependencies**: Database foundation (Sprint 1-3 complete)

**See**: [Feature Details - F1](#f1-processing-scan-results-detail)

---

#### F2: User Application Settings
**Status**: 📋 PLANNED
**Estimated Effort**: 14-16 hours
**Business Value**: Flexible scanning configuration for manual and background scans

**Overview**: Comprehensive settings UI for app-wide and per-account configuration.

**Key Features**:
- Manual Scan Defaults (scan mode, folder selection)
- Background Scan Defaults (frequency, enabled/disabled, folders)
- Per-account overrides (scan frequency, default folders, enabled status)

**Dependencies**: None (can be implemented standalone)

**See**: [Feature Details - F2](#f2-user-application-settings-detail)

---

#### F3: Interactive Rule & Safe Sender Management
**Status**: 📋 PLANNED
**Estimated Effort**: 16-18 hours
**Business Value**: Quick-add rules and safe senders from scan results without YAML editing

**Overview**: Interactive UI to add rules and safe senders directly from unmatched emails during scan result review.

**Key Features**:
- Quick-add safe sender from email
- Create rule from email (with pattern suggestions)
- Safe sender exceptions (denylist specific patterns while allowing domain)
- Pattern testing UI (test rule before saving)

**Dependencies**: F1 (Processing Scan Results), Database foundation

**See**: [Feature Details - F3](#f3-interactive-rule-safe-sender-management-detail)

---

### Priority 2: Platform-Specific Features (Enhances UX)

#### F4: Background Scanning - Android (WorkManager)
**Status**: 📋 PLANNED
**Estimated Effort**: 14-16 hours
**Platform**: Android
**Business Value**: Automatic periodic background scanning per user settings

**Overview**: Automatic periodic background scanning on Android with user-configured frequency.

**Key Features**:
- WorkManager for periodic background jobs
- Configurable scan frequency (hourly, daily, weekly)
- Battery-aware scheduling (defer when battery low)
- Notification on scan completion with results summary

**Dependencies**: F2 (User Application Settings for frequency configuration)

**See**: [Feature Details - F4](#f4-background-scanning-android-detail)

---

#### F5: Background Scanning - Windows Desktop
**Status**: 📋 PLANNED
**Estimated Effort**: 14-16 hours
**Platform**: Windows Desktop
**Business Value**: Background scanning + easy app distribution on Windows

**Overview**: Background scanning on Windows desktop + MSIX installer for app distribution.

**Key Features**:
- Task Scheduler integration for periodic scans
- System tray integration with scan status
- MSIX installer for easy distribution
- Auto-start on Windows login (optional)

**Dependencies**: F2 (User Application Settings), F4 (Background scanning patterns established)

**See**: [Feature Details - F5](#f5-background-scanning-windows-detail)

---

### Priority 3: Advanced Features (Nice to Have)

#### F6: Provider-Specific Optimizations
**Status**: 💡 IDEA
**Estimated Effort**: 10-12 hours
**Business Value**: Improved performance and reliability for AOL and Gmail

**Overview**: Provider-specific optimizations leveraging unique API capabilities.

**Potential Features**:
- AOL: Bulk folder operations
- Gmail: Label-based filtering (faster than IMAP folder scans)
- Gmail: Batch email operations via API
- Outlook: Graph API integration (when implemented)

**Dependencies**: Core functionality complete (F1-F3)

**Notes**: Defer until MVP complete. May not be needed if current performance acceptable.

---

#### F7: Multi-Account Scanning
**Status**: 💡 IDEA
**Estimated Effort**: 8-10 hours
**Business Value**: Scan multiple email accounts in parallel

**Overview**: Scan multiple email accounts simultaneously (parallel execution).

**Potential Features**:
- Parallel scanning with progress tracking
- Per-account result aggregation
- Unified unmatched email list (with account filtering)

**Dependencies**: F1 (Processing Scan Results)

**Notes**: Defer until MVP complete. Current sequential scanning may be sufficient.

---

#### F8: Rule Testing & Simulation
**Status**: 💡 IDEA
**Estimated Effort**: 6-8 hours
**Business Value**: Test rules before deployment

**Overview**: UI for testing rules against sample emails before saving.

**Potential Features**:
- Load sample emails from actual inbox
- Test rule against samples
- Show which emails match and why
- Pattern highlighting in email content

**Dependencies**: F3 (Interactive Rule Management)

**Notes**: Partially covered by F3 (pattern testing). Full simulation may not be needed.

---

#### F9: Database Test Refactoring (Issue #57)
**Status**: 🐛 TECHNICAL DEBT
**Estimated Effort**: 2-3 hours
**Business Value**: Prevent test schema drift from production schema
**Issue**: [#57](https://github.com/kimmeyh/spamfilter-multi/issues/57)

**Problem**: Database helper tests manually copy schema DDL, which can drift from production DatabaseHelper implementation.

**Solution**:
- Refactor tests to initialize actual DatabaseHelper (with in-memory or temp path)
- Remove duplicated schema declarations
- Tests always validate real production DDL

**Priority**: Low (technical debt, not blocking)

---

#### F10: Foreign Key Constraint Testing (Issue #58)
**Status**: 🐛 TECHNICAL DEBT
**Estimated Effort**: 1-2 hours
**Business Value**: Ensure foreign key constraints are enforced as expected
**Issue**: [#58](https://github.com/kimmeyh/spamfilter-multi/issues/58)

**Problem**: Foreign key constraint test does not verify constraints are enforced because PRAGMA foreign_keys is not enabled in DatabaseHelper.

**Solution**:
- Enable foreign keys in DatabaseHelper at connection time
- Update test to explicitly enable foreign keys for in-memory DB
- Assert that insert with non-existent foreign key throws error

**Priority**: Low (technical debt, not blocking)

---

## Feature Details

### F1: Processing Scan Results (Detail)

**Database Schema**:
```sql
CREATE TABLE scan_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL,
  scan_type TEXT NOT NULL CHECK(scan_type IN ('manual', 'background')),
  email_id TEXT NOT NULL,  -- Provider-specific (Message-ID, IMAP UID, etc.)
  from_address TEXT NOT NULL,
  subject TEXT NOT NULL,
  folder_name TEXT NOT NULL,  -- Current folder location
  received_date INTEGER NOT NULL,  -- Unix timestamp
  scan_date INTEGER NOT NULL,      -- Unix timestamp
  status TEXT NOT NULL CHECK(status IN ('pending', 'processed', 'deleted', 'unavailable')),
  UNIQUE(account_id, scan_type, email_id)
);

CREATE INDEX idx_scan_results_account_type ON scan_results(account_id, scan_type);
CREATE INDEX idx_scan_results_status ON scan_results(status);

-- Rules need date_added field for tracking
ALTER TABLE rules ADD COLUMN date_added INTEGER;  -- Unix timestamp
CREATE INDEX idx_rules_date_added ON rules(date_added);

ALTER TABLE safe_senders ADD COLUMN date_added INTEGER;  -- Unix timestamp
CREATE INDEX idx_safe_senders_date_added ON safe_senders(date_added);
```

**UI Screens**:

1. **Scan Results List** (Enhanced):
   - One wrapped line per email showing:
     - `<folder-name> • From: <email> • Subject: <subject>`
   - From email filtered/adjusted for viewability (extract from "Name <email>" format)
   - Subject filtered/adjusted for viewability (truncate if needed)
   - Tap email to see detail view

2. **Email Detail Screen** (Enhanced):
   - **View Options**:
     - View full message header
     - View message body (with domain link extraction)
     - Find all domains referenced in body links
   - **Action Buttons**:
     - Add to Safe Senders (3 options):
       - Specific email address (ex. `^john\.doe@aol\.com$`)
       - Specific domain (ex. `^[^@\s]+@(?:[a-z0-9-]+\.)*ibm\.com$`)
       - Wildcard/regex domain pattern
     - Create Auto-Delete Rule (6 types):
       - From Header (email or domain pattern)
       - Message Header Content (free-form match)
       - Subject Text (free-form match)
       - Body Text (free-form match, ex. `800\-571\-7438` or `audacious,\ llc`)
       - Body URL Domains (extracted from links, domain pattern)
     - Delete Email
     - Ignore (mark as processed, no action)

3. **Batch Actions**: Select multiple emails for bulk processing

**Domain Extraction from Email Body**:
- Parse body HTML/text for URLs
- Extract all unique domains from href links
- Present domains for quick "block all from this domain" rule creation
- Pattern format: `/accountryside\.com$` or `^[^@\s]+@(?:[a-z0-9-]+\.)*5hourenergy\.com$`

**API Methods**:
- `ScanResultStore.addUnmatchedEmail(accountId, scanType, email, folderName)`
- `ScanResultStore.getUnmatchedEmails(accountId, scanType, status)`
- `ScanResultStore.markEmailProcessed(id, status)`
- `ScanResultStore.checkEmailAvailability(accountId, emailId)` - Verify email still exists
- `EmailBodyParser.extractDomains(bodyHtml, bodyText)` - Extract all domains from links

**Email Availability Checking**:
- Before showing email detail, verify email still exists in inbox
- If deleted/moved externally, mark as "unavailable" in scan results
- Use provider-specific identifiers (Message-ID for Gmail, IMAP UID for IMAP)

**Rule Creation with date_added**:
- All new rules (auto-delete or safe sender) include `date_added` timestamp
- UI can filter/sort rules by date added
- Helps identify recently added rules for debugging

**Technical Notes**:
- One unmatched list per scan type (manual, background) to avoid mixing results
- Scan results cleared when new scan of same type starts
- Email content NOT stored (only metadata + folder location) to save space
- Rules enabled by default when user creates them from UI

---

### F2: User Application Settings (Detail)

**UI Entry Points**:
- **Account Selection Screen**: Settings button (⚙️) → App-wide settings
- **Scan Progress Screen**: Settings button (⚙️) → Provider/email address setup

**Settings Categories**:

1. **Manual Scan Defaults**
   - Scan Mode:
     - Read-Only (checkbox)
     - Process safe senders (checkbox)
     - Process rules (checkbox for All, OR individual checkboxes):
       - Auto Delete Header From
       - Auto Delete Header Text
       - Auto Delete Subject Text
       - Auto Delete Body Text
       - Auto Delete Body URL domains
   - Select folders to scan (uses current dynamic folder discovery)
   - Default Folders: Inbox, Junk, All Folders
   - Confirmation Dialogs: Enable/Disable

2. **Background Scan Defaults** (defaults for all future newly added provider/email addresses)
   - Enabled: Yes/No
   - Frequency: Every `<n>` minutes (configurable, ex. 15, 30, 60)
   - Scan Mode: (same options as Manual Scan Defaults above)
   - Default Folders: Inbox only, Inbox + Junk, All Folders

3. **Provider/Email Address Setups** (per-account overrides)
   - Authentication (manage credentials, re-authenticate)
   - Background Scans:
     - Enabled: Yes/No (override global default)
     - Frequency: Every `<n>` minutes (override global default)
     - Scan Mode: (same options as Manual Scan Defaults above)
     - Default Folders: Account-specific folder selection

**Storage**:
- Settings stored in SQLite `app_settings` table
- Per-account overrides in `account_settings` table
- Granular rule type toggles stored as bit flags or JSON

**UI**:
- Settings screen with tabbed interface (Manual, Background, Provider/Email Addresses)
- Provider/email address settings accessible from:
  - Account Selection screen → Settings button
  - Scan Progress screen → Settings button (direct to current account)
- Clear indication when setting is overridden
- Rule type checkboxes dynamically show/hide based on "Process rules (All)" toggle

---

### F3: Interactive Rule & Safe Sender Management (Detail)

**User Workflows**:

1. **Add Safe Sender from Email**:
   - User clicks "Add Safe Sender" on email in scan results
   - UI shows: Exact email OR entire domain
   - Pattern preview: `^john\.doe@company\.com$` or `^[^@\s]+@(?:[a-z0-9-]+\.)*company\.com$`
   - User confirms → Added to safe senders database

2. **Create Rule from Email**:
   - User clicks "Create Rule" on email in scan results
   - UI suggests patterns based on email:
     - From: Exact email or domain pattern
     - Subject: Keywords or regex pattern
     - Body: Keywords or regex pattern
   - User selects field(s) and action (delete/move)
   - Pattern testing: Show which sample emails match
   - User confirms → Rule added to database

3. **Safe Sender Exceptions**:
   - User can add exceptions to safe sender patterns
   - Example: Allow `@company.com` but block `spam@company.com`
   - Stored in `safe_sender_exceptions` table
   - Evaluated AFTER safe sender check

**Pattern Suggestions**:
- From patterns:
  - Exact: `^sender@domain\.com$`
  - Domain: `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$`
- Subject patterns:
  - Keywords: `\bkeyword1\b|\bkeyword2\b`
  - Exact match: `^exact subject line$`
- Body patterns:
  - Keywords with context: `\bspecial offer\b.*\bclick here\b`

**UI Components**:
- Pattern builder wizard (step-by-step)
- Pattern testing panel (test against sample emails)
- Pattern preview (show regex with explanation)

---

### F4: Background Scanning - Android (Detail)

**WorkManager Configuration**:
```dart
PeriodicWorkRequest scanWork = PeriodicWorkRequest.Builder(
  EmailScanWorker.class,
  scanFrequencyHours, TimeUnit.HOURS
)
  .setConstraints(Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .setRequiresBatteryNotLow(true)
    .build())
  .build();

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
  "background_email_scan",
  ExistingPeriodicWorkPolicy.REPLACE,
  scanWork
);
```

**Scan Frequency Options**:
- Hourly (minimum Android allows: 15 minutes, but respect battery)
- Daily (recommended default)
- Weekly

**Notification**:
- Show notification on scan completion
- Summary: "Scanned 150 emails, 12 matched rules (5 deleted, 7 moved)"
- Tap notification → Open Results screen

**Battery Awareness**:
- Defer scan if battery <15%
- Use WorkManager constraints for network and battery

---

### F5: Background Scanning - Windows Detail

**Task Scheduler Integration**:
```xml
<Task>
  <Triggers>
    <CalendarTrigger>
      <Repetition>
        <Interval>PT1H</Interval> <!-- Hourly -->
      </Repetition>
    </CalendarTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>spamfilter.exe</Command>
      <Arguments>--background-scan</Arguments>
    </Exec>
  </Actions>
</Task>
```

**System Tray Integration**:
- Show icon in system tray with scan status
- Right-click menu:
  - "Run Scan Now"
  - "View Results"
  - "Settings"
  - "Exit"
- Notification balloon on scan completion

**MSIX Installer**:
- Package app as MSIX for Windows Store distribution
- Auto-update capability via Windows Store
- Installer registers app for auto-start (optional)

**Auto-Start**:
- Optional: Start app on Windows login (minimized to system tray)
- Controlled by setting in app preferences

---

## Issue Backlog

**Last Updated**: February 1, 2026

This section tracks all open and fixed GitHub issues from code review and sprint work. For detailed issue descriptions, root causes, and acceptance criteria, see `ISSUE_BACKLOG.md`.

### Status Summary

| Status | Count | Issues |
|--------|-------|--------|
| ✅ Fixed | 8 | #4, #8, #18, #38, #39, #40, #41, #43 |
| 🔄 Open | 1 | #44 |

### ✅ Fixed Issues

1. **Issue #4**: Silent regex compilation failures (Fixed: Jan 3, 2026)
   - PatternCompiler now logs and tracks invalid patterns
   - 9 new tests added

2. **Issue #8**: Header matching bug in RuleEvaluator (Fixed: Jan 3, 2026)
   - Rules now properly check email headers instead of From field
   - 32 new tests with 97.96% coverage

3. **Issue #18**: Missing RuleEvaluator unit tests (Fixed: Jan 3, 2026)
   - Comprehensive test suite created
   - File: `test/unit/rule_evaluator_test.dart`

4. **Issue #38**: Python-style inline regex flags (Fixed: Jan 6, 2026)
   - PatternCompiler strips `(?i)`, `(?m)`, `(?s)`, `(?x)` flags
   - Also fixed 23 double-@ patterns in rules_safe_senders.yaml

5. **Issue #39**: Auto-navigation race condition (Fixed: Jan 7, 2026)
   - Update `_previousStatus` inside condition block

6. **Issue #40**: Hardcoded test limit (Fixed: Jan 7, 2026)
   - Added configurable slider (5-200)

7. **Issue #41**: Cross-account folder leakage (Fixed: Jan 7, 2026)
   - Per-account folder storage with `_selectedFoldersByAccount` map
   - 7 new tests added

8. **Issue #43**: print() vs Logger inconsistency (Fixed: Jan 7, 2026)
   - Replaced 6 print() statements with Logger calls

### 🔄 Open Issues

1. **Issue #44**: Outlook.com OAuth implementation
   - **Priority**: Deferred
   - **Labels**: `enhancement`, `platform:outlook`
   - **Description**: Complete Outlook.com/Office 365 OAuth implementation with MSAL
   - **File**: `outlook_adapter.dart` (stub)

### Test Coverage

| Metric | Value |
|--------|-------|
| Total Tests | 138 |
| Passing | 138 |
| Skipped | 13 (integration tests requiring credentials) |

### References

- [GitHub Issues](https://github.com/kimmeyh/spamfilter-multi/issues)
- [ISSUE_BACKLOG.md](ISSUE_BACKLOG.md) - Detailed issue descriptions
- [CHANGELOG.md](../CHANGELOG.md) - Recent fixes

---

## Version History

**Version**: 2.0
**Date**: January 31, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Updates**:
- 2.0 (2026-01-31): Restructured to focus on current/future sprints, moved historical info to summary docs
- 1.0 (2026-01-25): Initial version with complete Phase 3.5 breakdown
