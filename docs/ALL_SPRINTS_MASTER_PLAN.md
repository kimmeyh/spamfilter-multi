# All Sprints Master Plan

**Purpose**: Master planning document for current sprint, next sprint, and future features under consideration.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: February 1, 2026 (Backlog Refinement)

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
| 11 | SPRINT_11_RETROSPECTIVE.md | ✅ Complete | ~12h (Jan 31 - Feb 1, 2026) |

**Key Achievements**:
- **Sprint 1**: Database foundation (SQLite schema, migration infrastructure)
- **Sprint 2**: Database rule storage and integration
- **Sprint 3**: Safe sender exceptions with database storage
- **Sprint 9**: Development workflow improvements (25 process enhancements)
- **Sprint 11**: UI Polish & Production Readiness (keyboard shortcuts, CSV export, critical bug fixes for Issue #9 readonly bypass and delete-to-trash)

See CHANGELOG.md for detailed feature history.

---

## Current Sprint

**SPRINT 12: MVP Core Features + Sprint 11 Retrospective Actions**

**Status**: 📋 PLANNED (ready to start)

**Estimated Duration**: 48-54 hours (multi-session sprint)

**Model Assignment**: Sonnet (architecture, F1-F3) + Haiku (F9, F10, retrospective items)

**Objective**: Implement core MVP features (Settings, Scan Results Processing, Interactive Rule Management) plus address Sprint 11 retrospective technical debt

**Tasks**:

### Sprint 11 Retrospective Actions (High Priority)
- **Task R1**: Create integration test for readonly mode enforcement
  - Test that `ScanMode.readonly` prevents `platform.takeAction()` calls
  - Test that `ScanMode.fullScan` allows actions
  - Prevents regression of Issue #9
  - **Effort**: 2-3 hours

- **Task R2**: Update SPRINT_EXECUTION_WORKFLOW.md Phase 3.3
  - Clarify that Claude Code builds and runs app before user testing
  - Document monitoring requirements
  - Add pre-testing sanity check list
  - **Effort**: 1-2 hours

- **Task R3**: Document Windows environment workarounds
  - Unicode encoding fixes (`PYTHONIOENCODING=utf-8`)
  - PowerShell command best practices
  - Add to TROUBLESHOOTING.md or WINDOWS_DEVELOPMENT_GUIDE.md
  - **Effort**: 1-2 hours

- **Task R4**: Add delete-to-trash integration tests
  - Verify IMAP moves to Trash (not expunge)
  - Verify Gmail uses trash API
  - Test recovery workflow
  - **Effort**: 2-3 hours

### Technical Debt (From Backlog Refinement)
- **Task F9**: Database Test Refactoring (Issue #57)
  - Refactor tests to use actual DatabaseHelper (in-memory)
  - Remove duplicated schema declarations
  - **Effort**: 2-3 hours

- **Task F10**: Foreign Key Constraint Testing (Issue #58)
  - Enable foreign keys in DatabaseHelper at connection time
  - Update test to verify constraints are enforced
  - **Effort**: 1-2 hours

### MVP Features (From Backlog Refinement)
- **Task F2**: User Application Settings (HIGHEST PRIORITY)
  - Settings UI for app-wide and per-account configuration
  - Manual Scan Defaults (scan mode, folders, confirmations)
  - Background Scan Defaults (frequency, enabled, folders)
  - Per-account overrides
  - SQLite storage for settings
  - **Effort**: 14-16 hours

- **Task F1**: Processing Scan Results
  - Persistent scan result storage (SQLite table)
  - Enhanced scan results list UI
  - Email detail screen with view options
  - Action buttons (safe sender, create rule, delete, ignore)
  - Batch actions for bulk processing
  - **Effort**: 14-16 hours

- **Task F3**: Interactive Rule & Safe Sender Management
  - Quick-add safe sender from email (exact or domain)
  - Create rule from email (pattern suggestions)
  - Safe sender exceptions
  - Pattern testing UI
  - **Effort**: 16-18 hours

**Acceptance Criteria**:
- [ ] Readonly mode integration test prevents Issue #9 regression
- [ ] Delete-to-trash behavior verified with integration tests
- [ ] SPRINT_EXECUTION_WORKFLOW.md updated with pre-testing checklist
- [ ] Windows environment issues documented
- [ ] Database tests use actual DatabaseHelper (no schema duplication)
- [ ] Foreign key constraints enforced and tested
- [ ] Settings screen functional with all categories
- [ ] Settings persist across app restarts
- [ ] Scan results stored and retrievable
- [ ] Email detail view shows headers and body
- [ ] Safe sender can be added from email detail
- [ ] Rules can be created from email detail
- [ ] Pattern testing shows match preview
- [ ] All tests pass (100% pass rate)
- [ ] Zero analyzer warnings
- [ ] Manual testing on Windows Desktop passes

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| F1/F2/F3 scope too large for single sprint | Medium | High | Prioritize F2 first, defer F3 UI polish if needed |
| Database schema changes break existing data | Low | High | Migration scripts, backup before upgrade |
| Pattern testing UI complexity | Medium | Medium | Start with simple exact match, add regex later |

**Dependencies**: Sprints 1-3, 11 (database foundation, readonly fix, delete-to-trash)

---

## Next Sprint

**SPRINT 13: Background Scanning (Windows) + Persistent Gmail Authentication**

**Status**: 📋 PLANNED

**Estimated Duration**: 22-28 hours

**Model Assignment**: Sonnet (architecture, F12 research) + Haiku (implementation)

**Objective**: Background scanning on Windows Desktop with Task Scheduler integration, plus persistent Gmail authentication like Samsung/iPhone email apps

**Tasks**:

### F5: Background Scanning - Windows Desktop
- **Task A**: Task Scheduler Integration
  - Register periodic scan task with Windows Task Scheduler
  - Command-line arguments for background mode (`--background-scan`)
  - Configurable frequency from settings (F2)

- **Task B**: System Tray Enhancements
  - Show scan status in system tray
  - Notification balloon on scan completion
  - "Run Scan Now" from tray menu

- **Task C**: MSIX Installer
  - Package app as MSIX for distribution
  - Auto-start registration (optional)
  - Update mechanism

### F12: Persistent Gmail Authentication (Long-Lived Tokens)
- **Task D**: Research Phase
  - Investigate how Samsung Android email app achieves long-lived Gmail access (18-24+ months)
  - Investigate how iPhone Mail app maintains persistent Gmail access
  - Research Google OAuth 2.0 offline access and refresh token best practices
  - Document findings and recommended approach

- **Task E**: Implementation
  - Implement recommended authentication approach
  - Secure refresh token storage (per platform)
  - Automatic token refresh before expiration
  - Handle token revocation gracefully (prompt re-auth)
  - Test token persistence across app restarts and device reboots

- **Task F**: Testing & Validation
  - Verify tokens persist for extended periods (simulate time passage if possible)
  - Test re-authentication flow when tokens expire/revoke
  - Document expected token lifetime

**Acceptance Criteria**:
- [ ] Background scans run on schedule (F5)
- [ ] System tray shows scan status (F5)
- [ ] Notifications show scan results (F5)
- [ ] MSIX installer works on clean Windows install (F5)
- [ ] Auto-start functional (when enabled) (F5)
- [ ] Gmail authentication persists across app restarts (F12)
- [ ] Gmail authentication persists across device reboots (F12)
- [ ] Refresh tokens stored securely (F12)
- [ ] Automatic token refresh works without user intervention (F12)
- [ ] Token revocation handled gracefully with re-auth prompt (F12)
- [ ] Research findings documented (F12)
- [ ] All tests pass

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Task Scheduler permissions | Medium | Medium | Document admin requirements, fallback to user-level scheduling |
| MSIX signing requirements | Medium | Low | Self-signed for testing, defer store submission |
| Google OAuth policy restrictions | Medium | High | Research thoroughly, may need to apply for verification |
| Token storage security | Medium | High | Use platform-specific secure storage (Keychain, Credential Manager) |
| Long-lived token behavior varies by platform | Medium | Medium | Test on all target platforms |

**Dependencies**: Sprint 12 (F2 Settings for frequency configuration)

---

## Future Features (Prioritized)

**Last Refined**: February 1, 2026 (Backlog Refinement Session)

Priority based on: Product Owner prioritization for MVP development.

### Priority 1: MVP Core Features (Sprint 12 - In Progress)

#### F2: User Application Settings (HIGHEST PRIORITY)
**Status**: 🚀 SPRINT 12
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

#### F1: Processing Scan Results
**Status**: 🚀 SPRINT 12
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

#### F3: Interactive Rule & Safe Sender Management
**Status**: 🚀 SPRINT 12
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

#### F9: Database Test Refactoring (Issue #57)
**Status**: 🚀 SPRINT 12
**Estimated Effort**: 2-3 hours
**Business Value**: Prevent test schema drift from production schema
**Issue**: [#57](https://github.com/kimmeyh/spamfilter-multi/issues/57)

**Problem**: Database helper tests manually copy schema DDL, which can drift from production DatabaseHelper implementation.

**Solution**:
- Refactor tests to initialize actual DatabaseHelper (with in-memory or temp path)
- Remove duplicated schema declarations
- Tests always validate real production DDL

---

#### F10: Foreign Key Constraint Testing (Issue #58)
**Status**: 🚀 SPRINT 12
**Estimated Effort**: 1-2 hours
**Business Value**: Ensure foreign key constraints are enforced as expected
**Issue**: [#58](https://github.com/kimmeyh/spamfilter-multi/issues/58)

**Problem**: Foreign key constraint test does not verify constraints are enforced because PRAGMA foreign_keys is not enabled in DatabaseHelper.

**Solution**:
- Enable foreign keys in DatabaseHelper at connection time
- Update test to explicitly enable foreign keys for in-memory DB
- Assert that insert with non-existent foreign key throws error

---

### Priority 2: Windows Background Scanning + Persistent Gmail Auth (Sprint 13)

#### F5: Background Scanning - Windows Desktop
**Status**: 📋 PLANNED (Sprint 13)
**Estimated Effort**: 14-16 hours
**Platform**: Windows Desktop
**Business Value**: Background scanning + easy app distribution on Windows

**Overview**: Background scanning on Windows desktop + MSIX installer for app distribution.

**Key Features**:
- Task Scheduler integration for periodic scans
- System tray integration with scan status
- MSIX installer for easy distribution
- Auto-start on Windows login (optional)

**Dependencies**: F2 (User Application Settings)

**See**: [Feature Details - F5](#f5-background-scanning-windows-detail)

---

#### F12: Persistent Gmail Authentication (Long-Lived Tokens)
**Status**: 📋 PLANNED (Sprint 13)
**Estimated Effort**: 8-12 hours
**Platform**: All (Windows, Android, iOS)
**Business Value**: Users only need to authenticate Gmail once every 18-24+ months (like Samsung/iPhone email apps)

**Overview**: Research and implement long-lived Gmail authentication similar to native email apps (Samsung Android, iPhone Mail) that only require re-authentication every 18-24+ months instead of frequently.

**Research Questions**:
- How do Samsung Android and iPhone Mail apps achieve long-lived Gmail access?
- What OAuth 2.0 scopes and parameters enable persistent refresh tokens?
- What are Google's policies on offline access for third-party apps?
- Are there differences between "installed app" vs "web app" OAuth flows?
- Does app verification status affect token lifetime?

**Key Features**:
- Research best practices for long-lived OAuth tokens
- Implement offline access with proper refresh token handling
- Secure refresh token storage (platform-specific secure storage)
- Automatic token refresh before expiration
- Graceful handling of token revocation (prompt re-auth)
- Document expected token lifetime and any limitations

**Technical Considerations**:
- Google OAuth 2.0 `access_type=offline` parameter
- Proper handling of `prompt=consent` for initial authorization
- Secure storage: Windows Credential Manager, Android Keystore, iOS Keychain
- Token refresh scheduling (before expiration)
- Handling Google account security events (password change, suspicious activity)

**Dependencies**: Current Gmail OAuth implementation (google_sign_in package)

**See**: [Feature Details - F12](#f12-persistent-gmail-authentication-detail)

---

### Priority 3: UI Automation Testing (Sprint 14)

#### F11: Playwright UI Tests for Windows Desktop + Android UI Testing Strategy
**Status**: 📋 PLANNED (Sprint 14)
**Estimated Effort**: 12-16 hours
**Business Value**: Automated UI regression testing, reduced manual testing burden

**Overview**: Build comprehensive Playwright tests for Windows Desktop UI and determine recommended approach for Android UI testing.

**Key Features**:
- **Windows Desktop (Playwright)**:
  - End-to-end UI tests for all screens
  - Account selection and authentication flows
  - Scan configuration and execution
  - Results display and actions
  - Settings screen interactions
  - Keyboard shortcut verification
  - System tray integration tests

- **Android UI Testing Strategy**:
  - Research Flutter integration testing options
  - Evaluate Patrol, integration_test package, Appium
  - Document recommended approach
  - Implement initial test suite

**Dependencies**: Sprint 12 (F1-F3 UI complete), Sprint 13 (F5 Windows background scanning)

**Acceptance Criteria**:
- [ ] Playwright tests cover all Windows Desktop screens
- [ ] Tests run in CI/CD pipeline
- [ ] Android testing approach documented
- [ ] Initial Android UI tests implemented
- [ ] Test coverage report generated

---

### Priority 4: Rule Testing & Simulation (After Sprint 14)

#### F8: Rule Testing & Simulation
**Status**: 📋 PLANNED
**Estimated Effort**: 6-8 hours
**Business Value**: Test rules before deployment

**Overview**: UI for testing rules against sample emails before saving.

**Potential Features**:
- Load sample emails from actual inbox
- Test rule against samples
- Show which emails match and why
- Pattern highlighting in email content

**Dependencies**: F3 (Interactive Rule Management)

**Notes**: Partially covered by F3 (pattern testing). Full simulation may be deferred.

---

### Priority 5: Provider Optimizations (After F8)

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

### Priority 6: Multi-Account Scanning (After F6)

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

### Priority 7: Android Background Scanning (After F7)

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

### HOLD: Low Priority Items

The following items are on HOLD until higher priority work is complete:

#### Issue #49: Sent Messages Scan for Safe Senders
**Status**: ⏸️ HOLD
**Issue**: [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)
**Description**: Scan sent folder to auto-populate safe senders
**Notes**: Large feature, deferred to post-MVP

#### Issue #44: Outlook.com OAuth Implementation
**Status**: ⏸️ HOLD
**Issue**: [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44)
**Description**: Complete Outlook.com/Office 365 OAuth with MSAL
**Notes**: New provider, requires MSAL integration, deferred

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

### F12: Persistent Gmail Authentication (Detail)

**Problem Statement**:
Current Gmail authentication requires frequent re-authentication (daily or weekly), while native email apps like Samsung Android Mail and iPhone Mail only require authentication once every 18-24+ months. This creates poor user experience for background scanning scenarios.

**Research Areas**:

1. **Google OAuth 2.0 Token Lifetime**:
   - Default access token lifetime: 1 hour
   - Refresh token lifetime: varies (can be long-lived with proper configuration)
   - Factors affecting refresh token lifetime:
     - User's Google account security settings
     - App verification status
     - OAuth consent screen configuration
     - Scopes requested

2. **Native Email App Approach**:
   - Samsung Android Mail: Uses device account manager integration
   - iPhone Mail: Uses Apple's centralized account system
   - Both leverage system-level OAuth token management
   - May use different OAuth client types (device vs web)

3. **Best Practices for Long-Lived Access**:
   - Request `access_type=offline` for refresh tokens
   - Use `prompt=consent` only on first authorization
   - Store refresh tokens securely (platform-specific)
   - Implement proactive token refresh (before expiration)
   - Handle incremental authorization properly

**Implementation Approach**:

1. **Secure Token Storage**:
   - **Windows**: Windows Credential Manager (via `flutter_secure_storage`)
   - **Android**: Android Keystore (via `flutter_secure_storage`)
   - **iOS**: iOS Keychain (via `flutter_secure_storage`)

2. **Token Refresh Strategy**:
   ```dart
   // Pseudocode for token refresh
   Future<String> getValidAccessToken() async {
     final credentials = await secureStorage.read('gmail_credentials');
     if (credentials.accessTokenExpired) {
       if (credentials.hasRefreshToken) {
         // Refresh token before expiration
         final newCredentials = await refreshAccessToken(credentials.refreshToken);
         await secureStorage.write('gmail_credentials', newCredentials);
         return newCredentials.accessToken;
       } else {
         // No refresh token - require re-auth
         throw AuthenticationRequiredException();
       }
     }
     return credentials.accessToken;
   }
   ```

3. **Graceful Degradation**:
   - If refresh fails (token revoked), prompt user to re-authenticate
   - Show clear message explaining why re-auth is needed
   - Preserve account configuration (only re-auth, do not lose settings)

**Expected Outcomes**:
- Users authenticate once and remain authenticated for 18-24+ months
- Background scans work reliably without user intervention
- Token refresh happens automatically and transparently
- Clear error handling when re-authentication is required

**Files to Modify**:
- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Token refresh logic
- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` - Secure token storage
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Use refreshed tokens

**Testing**:
- Verify token persists across app restarts
- Verify token persists across device reboots
- Simulate token expiration and verify refresh
- Simulate token revocation and verify re-auth prompt
- Test on Windows, Android (iOS if available)

---

## Issue Backlog

**Last Updated**: February 1, 2026

This section tracks all open and fixed GitHub issues from code review and sprint work. For detailed issue descriptions, root causes, and acceptance criteria, see `ISSUE_BACKLOG.md`.

### Status Summary

| Status | Count | Issues |
|--------|-------|--------|
| ✅ Fixed | 12 | #4, #8, #18, #38, #39, #40, #41, #43, #107, #108, #109, #110 |
| ⏸️ HOLD | 2 | #44, #49 |

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

9. **Issue #107**: Functional keyboard shortcuts (Fixed: Feb 1, 2026 - Sprint 11)
   - Implemented Ctrl+N (New Scan), Ctrl+R/F5 (Refresh), Ctrl+Q (Quit)
   - Visual feedback with SnackBar for refresh action

10. **Issue #108**: System tray icon initialization error (Fixed: Feb 1, 2026 - Sprint 11)
    - Fixed icon path and initialization
    - Right-click menu persistence fixed

11. **Issue #109**: Scan Options slider labels (Fixed: Feb 1, 2026 - Sprint 11)
    - Changed from discrete to continuous slider (1-90 days) per user feedback
    - Clear day count display

12. **Issue #110**: Enhanced CSV export (Fixed: Feb 1, 2026 - Sprint 11)
    - Added Scan Date timestamp column
    - Additional export columns implemented

### ⏸️ HOLD Issues

1. **Issue #44**: Outlook.com OAuth implementation
   - **Priority**: HOLD
   - **Labels**: `enhancement`, `platform:outlook`, `HOLD`
   - **Description**: Complete Outlook.com/Office 365 OAuth implementation with MSAL
   - **File**: `outlook_adapter.dart` (stub)

2. **Issue #49**: Sent Messages Scan for Safe Senders
   - **Priority**: HOLD
   - **Labels**: `enhancement`, `HOLD`
   - **Description**: Scan sent folder to auto-populate safe senders
   - **Notes**: Large feature, deferred to post-MVP

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

**Version**: 3.0
**Date**: February 1, 2026
**Author**: Claude Opus 4.5
**Status**: Active

**Updates**:
- 3.1 (2026-02-01): Added F12 (Persistent Gmail Authentication) to Sprint 13
  - Research how Samsung/iPhone email apps achieve 18-24+ month authentication
  - Implement long-lived refresh token handling
  - Sprint 13 now includes F5 + F12 (22-28 hours estimated)
- 3.0 (2026-02-01): Backlog refinement - reprioritized features per Product Owner:
  - Sprint 12: F2 (Settings), F1 (Scan Results), F3 (Rule Management), F9, F10, Sprint 11 retrospective actions
  - Sprint 13: F5 (Windows Background Scanning)
  - Sprint 14: F11 (Playwright UI Tests + Android UI Testing Strategy) - NEW
  - Priority order: F5 → F12 → F11 → F8 → F6 → F7 → F4
  - Issues #107-110 completed in Sprint 11 (marked as fixed)
  - Moved to HOLD: Issues #49, #44
  - Added Sprint 11 to Past Sprint Summary
- 2.0 (2026-01-31): Restructured to focus on current/future sprints, moved historical info to summary docs
- 1.0 (2026-01-25): Initial version with complete Phase 3.5 breakdown
