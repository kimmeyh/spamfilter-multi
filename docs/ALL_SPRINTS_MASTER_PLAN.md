# All Sprints Master Plan

**Purpose**: Master planning document for current sprint, next sprint, and future features under consideration.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: February 13, 2026 (Sprint 14 Completion)

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** (this doc) | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
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

Historical sprint information has been moved to individual summary documents in `docs/sprints/` and CHANGELOG.md. For detailed retrospectives, see:

| Sprint | Summary Document | Status | Duration |
|--------|------------------|--------|----------|
| 1 | docs/sprints/SPRINT_1_RETROSPECTIVE.md | [OK] Complete | ~4h (Jan 19-24, 2026) |
| 2 | docs/sprints/SPRINT_2_RETROSPECTIVE.md | [OK] Complete | ~6h (Jan 24, 2026) |
| 3 | docs/sprints/SPRINT_3_SUMMARY.md | [OK] Complete | ~8h (Jan 24-25, 2026) |
| 8 | docs/sprints/SPRINT_8_SUMMARY.md | [OK] Complete | ~12h (Jan 31, 2026) |
| 9 | docs/sprints/SPRINT_9_SUMMARY.md | [OK] Complete | ~2h (Jan 30-31, 2026) |
| 10 | docs/sprints/SPRINT_10_SUMMARY.md | [OK] Complete | ~20h (Feb 1, 2026) |
| 11 | docs/sprints/SPRINT_11_SUMMARY.md | [OK] Complete | ~12h (Jan 31 - Feb 1, 2026) |
| 12 | docs/sprints/SPRINT_12_SUMMARY.md | [OK] Complete | ~48h (Feb 1-6, 2026) |
| 13 | docs/sprints/SPRINT_13_PLAN.md | [OK] Complete | ~3h (Feb 6, 2026) |
| 14 | docs/sprints/SPRINT_14_PLAN.md | [OK] Complete | ~8h (Feb 7-13, 2026) |
| 15 | docs/sprints/SPRINT_15_PLAN.md | [OK] Complete | ~16h (Feb 14-15, 2026) |
| 16 | docs/sprints/SPRINT_16_PLAN.md | [OK] Complete | ~6h (Feb 15-16, 2026) |
| 17 | docs/sprints/SPRINT_17_SUMMARY.md | [OK] Complete | ~20h (Feb 17-21, 2026) |

**Key Achievements**:
- **Sprint 1**: Database foundation (SQLite schema, migration infrastructure)
- **Sprint 2**: Database rule storage and integration
- **Sprint 3**: Safe sender exceptions with database storage
- **Sprint 8**: Windows Background Scanning & MSIX Installer (Task Scheduler, toast notifications, MSIX packaging)
- **Sprint 9**: Development workflow improvements (documentation refactoring, AppLogger, comprehensive testing, monitoring tools)
- **Sprint 10**: Cross-Platform UI Enhancements (Material Design 3, Fluent Design, UI polish)
- **Sprint 11**: UI Polish & Production Readiness (keyboard shortcuts, CSV export, critical bug fixes for Issue #9 readonly bypass and delete-to-trash)
- **Sprint 12**: MVP Core Features (Settings, Scan Results Processing, Interactive Rule Management) + Sprint 11 retrospective actions
- **Sprint 13**: Account-Specific Folder Settings (per-account deleted rule folder, safe sender folder, subject cleaning, settings UI refactor)
- **Sprint 14**: Settings Restructure + UX Improvements (progressive scan updates, Demo Mode, enhanced delete processing, plus-sign safe sender fix)
- **Sprint 15**: Bug Fixes, Performance, and Settings Management (100-delete limit fix via UID migration, batch email processing, Safe Senders/Rules management UIs, Windows directory browser, Windows background scanning with Task Scheduler, 15 ADRs)
- **Sprint 16**: UX Polish, Scan Configuration, and Rule Intelligence (persistent days-back settings, scan options defaults, Manual Scan rename, background scan log viewer, rule override/conflict detection, scan result persistence for historical View Results, 8 rounds of user testing feedback)

See CHANGELOG.md for detailed feature history.

---

## Current Sprint

**No Active Sprint**

**Status**: AWAITING SPRINT 17 PLANNING

**Last Completed Sprint**: Sprint 16 (February 15-16, 2026)
- PR #155: https://github.com/kimmeyh/spamfilter-multi/pull/155
- Features completed:
  - #153: Persistent days-back settings for Manual and Background scans
  - #150: Scan Options defaults to "Scan all emails" with saved preferences
  - #151: Renamed "Scan Progress" to "Manual Scan", removed folder selector
  - #152: Background scan log viewer with account filter and summary stats
  - #139: Rule override/conflict detection with warning dialogs
  - FB-1 through FB-8: User testing feedback (scan slider, simplified UI, result persistence)
  - 10 new ADRs (ADR-0016 through ADR-0025)
- Retrospective: `docs/sprint_16_retrospective.md`
- New issues filed from testing feedback:
  - #156: Manual Scan status text formatting
  - #157: Clear Results screen before new Live Scan
  - #158: Consolidated Scan History (unified background + manual)
  - #159: Test Background Scan button
  - #160: Renumber Sprint Execution Workflow phases

**Next Sprint Candidates**:

### Option 1: Scan History and UX Improvements
**Estimated Duration**: 20-30 hours
**Objective**: Consolidate scan history and continue UX improvements

**Tasks** (from GitHub issues):
- **#158**: Consolidated Scan History - unified background/manual view (~12-16h)
- **#156**: Manual Scan status text formatting (~1-2h)
- **#157**: Clear Results screen before new Live Scan (~2-3h)
- **#159**: Test Background Scan button (~3-4h)
- **#149**: Manage Rules UI overhaul - split combined rules, search, filter (~12-16h)

### Option 2: Technical Improvements
**Estimated Duration**: 12-18 hours
**Objective**: Technical debt and rule management improvements

**Tasks**:
- **#154**: Auto-remove safe sender entries when converting to delete rules (~4-6h) -- **BUG confirmed by user testing 2026-02-23**: Changing `no-reply@notification.circle.so` from Safe Sender to Block Entire Domain fails silently; safe sender entry not removed, block rule does not take effect
- **F12B**: Gmail Dual-Auth UX and Account Tracking (~10-16h)

### Option 3: Custom Sprint (User-Defined)
User selects specific issues from backlog based on priorities.

---

**Sprint 11 Retrospective Actions**: [OK] **ALL COMPLETE**
All 4 retrospective actions (R1-R4) were completed in Sprint 12:
- [OK] R1: Readonly mode integration tests (Issue #117)
- [OK] R2: SPRINT_EXECUTION_WORKFLOW.md updates (Issue #115)
- [OK] R3: Windows environment documentation (Issue #116)
- [OK] R4: Delete-to-trash integration tests (Issue #118)

**Sprint 12 MVP Features**: [OK] **ALL COMPLETE**
All MVP features and technical debt completed in Sprint 12:
- [OK] F1: Processing Scan Results
- [OK] F2: User Application Settings
- [OK] F3: Interactive Rule & Safe Sender Management
- [OK] F9: Database Test Refactoring (Issue #57)
- [OK] F10: Foreign Key Constraint Testing (Issue #58)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| F1/F2/F3 scope too large for single sprint | Medium | High | Prioritize F2 first, defer F3 UI polish if needed |
| Database schema changes break existing data | Low | High | Migration scripts, backup before upgrade |
| Pattern testing UI complexity | Medium | Medium | Start with simple exact match, add regex later |

**Dependencies**: Sprints 1-3, 11 (database foundation, readonly fix, delete-to-trash)

---

## Next Sprint

**SPRINT 14: TBD (To Be Determined by Product Owner)**

**Status**: [CHECKLIST] AWAITING PLANNING

**Candidates**:
- Sprint 12 (MVP Core Features + Sprint 11 Retrospective Actions)
- Background Scanning (Windows) + Persistent Gmail Authentication (original Sprint 13 scope, deferred)
- Playwright UI Tests for Windows Desktop + Android UI Testing Strategy

**Note**: Sprint 13 was originally planned for F5 (Windows Background Scanning) + F12 (Persistent Gmail Auth) but was replanned during execution based on user priorities. The completed Sprint 13 focused on account-specific folder settings and UI refinements instead.

**Original Sprint 13 Scope (Deferred)**:

The features below were originally planned for Sprint 13 but have been deferred to a future sprint:

### F5: Background Scanning - Windows Desktop
**Status**: [CHECKLIST] DEFERRED (from original Sprint 13 plan)
**Estimated Effort**: 14-16 hours

**Overview**: Background scanning on Windows Desktop with Task Scheduler integration.

**Tasks**:
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
**Status**: [OK] RESOLVED (2026-02-22 - Architecture Review)
**Estimated Effort**: 0 hours (no code changes needed)

**Resolution**: F12 is not a code problem. Investigation during the ADR-0029/0034 architecture review revealed that token lifetime depends on **app verification status**, not code implementation:

| App Status | Token Lifetime | User Cap |
|------------|---------------|----------|
| Testing mode (unverified) | 7 days | 100 hand-picked |
| Published + Unverified | Standard (months) | 100 total |
| Published + Verified (CASA) | Standard (months) | Unlimited |

The existing codebase already has all required infrastructure:
- `google_auth_service.dart`: `getValidAccessToken()`, `_refreshToken()`, secure token storage
- `SecureCredentialsStore`: Platform-native encrypted refresh token storage
- Automatic token refresh with retry logic

**Decision** (see ADR-0029, ADR-0034):
- **Phase 1**: Unverified OAuth for alpha/beta (accept 7-day tokens for 100 testers)
- **Phase 2**: Gmail app passwords via IMAP for general users (no token expiry)
- **Phase 3 (ON HOLD)**: CASA verification for unlimited OAuth users
- **CASA Trigger**: Pursue CASA verification when: (a) app has 2,500+ active Gmail IMAP users at $3 annually or yearly revenue exceeds $5,000 (covering annual CASA cost)

**Original Tasks** (Task D research, Task E implementation, Task F testing): All resolved without code changes. Research completed during architecture review; implementation already exists; testing not needed (behavior is Google-side, not app-side).

**Dependencies**: None remaining. ADR-0029 and ADR-0034 are now Accepted.

---

## Future Features (Prioritized)

**Last Refined**: February 1, 2026 (Backlog Refinement Session)

Priority based on: Product Owner prioritization for MVP development.

### Priority 1: MVP Core Features (Sprint 12 - In Progress)

#### F2: User Application Settings (HIGHEST PRIORITY)
**Status**: [LAUNCH] SPRINT 12
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
**Status**: [LAUNCH] SPRINT 12
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
**Status**: [LAUNCH] SPRINT 12
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
**Status**: [LAUNCH] SPRINT 12
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
**Status**: [LAUNCH] SPRINT 12
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
**Status**: [OK] COMPLETED (Sprint 15, PR #146)
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
**Status**: [OK] RESOLVED (2026-02-22 - Architecture Review)
**Estimated Effort**: 0 hours (no code changes needed - resolved as verification issue, not code issue)
**Platform**: All (Windows, Android, iOS)

**Resolution**: Token lifetime depends on app verification status (Testing=7 days, Published+Unverified=months with 100 user cap, Verified=months with no cap). All required code infrastructure already exists in `google_auth_service.dart`. See ADR-0029 and ADR-0034 for the phased Gmail authentication strategy.

**Research Questions -- ANSWERED**:
- Samsung/iPhone achieve long-lived access because they are **verified apps** with CASA certification
- `access_type=offline` is already implemented; token lifetime is a verification status issue
- Google restricts ALL Gmail content scopes as restricted (CASA required for verification)
- App verification status **does** affect token lifetime (the key finding)

**Decision**: Three-phase approach (ADR-0029 + ADR-0034):
1. Unverified OAuth for alpha/beta (100 testers, 7-day tokens)
2. Gmail app passwords via IMAP for general users (no token expiry)
3. CASA verification ON HOLD until revenue trigger: 2,500+ users at $3/yr or $5,000/yr revenue

**Follow-up**: See F12B (Gmail Dual-Auth UX and Account Tracking) for implementation work to support the dual-path strategy.

---

#### F12B: Gmail Dual-Auth UX and Account Tracking
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 10-16 hours
**Platform**: All (Windows, Android, iOS)
**Business Value**: In-app walkthroughs for both Gmail auth methods, per-account auth method tracking, correct adapter routing

**Overview**: Implements the dual-path Gmail authentication strategy decided in ADR-0029 and ADR-0034. Adds auth method selection UI, in-app setup walkthroughs for OAuth and app passwords, per-account auth method persistence, and adapter routing. Also removes unused `AuthMethod.apiKey`.

**See**: [Feature Details - F12B](#f12b-gmail-dual-auth-ux-and-account-tracking)

---

### Priority 3: UI Automation Testing (Sprint 14)

#### F11: Playwright UI Tests for Windows Desktop + Android UI Testing Strategy
**Status**: [CHECKLIST] PLANNED (Sprint 14)
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
**Status**: [CHECKLIST] PLANNED
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
**Status**: [IDEA] IDEA
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
**Status**: [IDEA] IDEA
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
**Status**: [CHECKLIST] PLANNED
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

### Priority 8: Settings Management UI + Performance

#### F17: Manage Safe Senders UI in Settings
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 6-8 hours
**Issue**: To be created
**Business Value**: Users can view, edit, and delete safe sender patterns without database access

**Overview**: Add a "Manage Safe Senders" section to Settings that displays all safe sender patterns with ability to view details, edit, and delete.

**Key Features**:
- List all safe sender patterns with pattern type (exact email, domain, subdomain)
- Show pattern details (date added, created by, exception patterns)
- Delete individual safe sender patterns
- Search/filter safe senders
- Export safe senders to YAML (already exists via RuleSetProvider)

**Dependencies**: None (database storage already complete)

---

#### F18: Manage Rules UI in Settings
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 8-10 hours
**Issue**: To be created
**Business Value**: Users can view, edit, and delete block rules without YAML editing

**Overview**: Add a "Manage Rules" section to Settings that displays all block rules with ability to view details, edit, enable/disable, and delete.

**Key Features**:
- List all rules with name, action (delete/move), enabled status
- Show rule details (patterns, conditions, execution order)
- Enable/disable individual rules
- Delete individual rules
- Reorder rules (execution priority)
- Export rules to YAML (already exists via RuleSetProvider)

**Dependencies**: None (database storage already complete)

---

#### F19: Batch Email Processing (Performance)
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 10-16 hours
**Issue**: [#144](https://github.com/kimmeyh/spamfilter-multi/issues/144)
**Business Value**: Significant performance improvement for users with large spam volumes

**Overview**: Process emails in batches of 10 instead of one-at-a-time to reduce network round-trips.

**Key Features**:
- Batch IMAP commands (STORE, MOVE) for 10 emails at a time
- Graceful error handling (if 1 of 10 fails, other 9 still process)
- Individual error reporting per email
- Configurable batch size (default: 10)
- Works with Gmail API batch requests and IMAP message sequence sets

**Dependencies**: None

---

### Priority 9: Scan Results Enhancements

#### F20: Common Email Provider Domain Reference Table
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 3-4 hours
**Issue**: To be created
**Business Value**: Enables smarter rule suggestions and processing for emails from common providers vs organizational domains

**Overview**: Maintain an application-level reference table of common email provider domains (gmail.com, aol.com, yahoo.com, outlook.com, hotmail.com, live.com, protonmail.com, etc.). Loaded into memory at scan time for matching against Deleted, Safe, and No Rule results.

**Key Features**:
- Application-managed table (not user-editable settings)
- Loaded into memory at scan time for fast matching
- Covers major providers: Gmail, AOL, Yahoo, Microsoft (outlook.com, hotmail.com, live.com, msn.com), Proton (protonmail.com, proton.me, pm.me), iCloud, Zoho, GMX, mail.com
- Used by rule suggestion logic to distinguish personal provider emails from business/organizational domains
- Database-backed with seed data on first launch

**Dependencies**: None

---

#### F21: Inline Rule Assignment from Scan Results with Visual Tracking
**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 12-16 hours
**Issue**: To be created
**Business Value**: Users can assign rules to unmatched emails directly from scan results and track progress visually

**Overview**: While reviewing Scan Results (from either View Scan History or Start Live Scan), users can add rules to emails with "No rule" matches. After assigning, the list and detail views update to reflect the new assignment.

**Key Features**:
- Add Safe Sender or Block Rule directly from No Rule email entries in Scan Results
- Rule type options: Exact Email, Exact Domain, Entire Domain, Block Email, Block Exact Domain, Block Entire Domain, Block Subject
- After adding a rule, the Scan Results list item updates to show assignment: `<folder> . <subject> . No rule . New rule: <Safe Sender/Block Rule> . <rule name>`
- Visual tracking so user can see which No Rule items now have rules assigned during review session
- Re-opening email detail view after rule assignment shows the newly matched rule highlighted in bold (same styling as existing rule matches)
- Re-evaluation of rules against the email when detail view is opened (not cached scan-time result)

**Dependencies**: F3 (Interactive Rule & Safe Sender Management), F20 (Common Email Provider Domains - for smart suggestions)

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

**Status**: [OK] RESOLVED (2026-02-22)

**Original Problem Statement**:
Current Gmail authentication requires frequent re-authentication (daily or weekly), while native email apps like Samsung Android Mail and iPhone Mail only require authentication once every 18-24+ months. This creates poor user experience for background scanning scenarios.

**Root Cause Analysis (Completed 2026-02-22)**:

The frequent re-authentication is caused by **Google's app verification status**, not missing code:

| App Status | Refresh Token Lifetime | User Cap |
|------------|----------------------|----------|
| Testing mode (Cloud Console) | 7 days | 100 hand-picked test users |
| Published + Unverified | Standard (months) | 100 total lifetime users |
| Published + Verified (CASA) | Standard (months/years) | Unlimited |

Samsung and iPhone email apps achieve 18-24+ month tokens because they are **CASA-verified apps** with system-level OAuth integration. This is a verification privilege, not a code technique.

**Existing Code Infrastructure** (already implemented, no changes needed):
- `google_auth_service.dart`: `getValidAccessToken()`, `_refreshToken()`, `access_type=offline`
- `SecureCredentialsStore`: Platform-native encrypted storage (Windows Credential Manager, Android Keystore, iOS Keychain)
- `GmailApiAdapter`: Uses refreshed tokens automatically

**Resolution**: Three-phase Gmail authentication strategy (ADR-0029 + ADR-0034):
1. **Alpha/Beta**: Unverified OAuth (7-day tokens, 100 test users) -- validates flow
2. **General Availability**: Gmail app passwords via IMAP (no token expiry, unlimited users)
3. **ON HOLD**: CASA verification when revenue justifies cost (2,500+ users at $3/yr or $5,000/yr revenue)

**No files need modification** for this feature. All token refresh, secure storage, and graceful degradation logic already exists.

---

### F12B: Gmail Dual-Auth UX and Account Tracking

**Status**: [CHECKLIST] PLANNED
**Estimated Effort**: 10-16 hours
**Platform**: All (Windows, Android, iOS)
**Business Value**: Enables Gmail users to choose between OAuth (alpha/beta) and app passwords (GA), with in-app guidance and correct adapter routing per account.
**Dependencies**: F12 (resolved), ADR-0029 (accepted), ADR-0034 (accepted)

**Problem Statement**:
With the dual-path Gmail authentication strategy (ADR-0034), the app needs to:
1. Let Gmail users choose their auth method (OAuth vs app password)
2. Guide users through setup for each method with in-app walkthroughs
3. Track which auth method each Gmail account uses
4. Route to the correct adapter (`GmailApiAdapter` for OAuth, `GenericImapAdapter` for app password) on reconnect
5. Remove unused auth methods from the `AuthMethod` enum (`apiKey` is defined but never used)

**Task A: Gmail Auth Method Selection UI** (~3-4h, Sonnet)
- Add auth method choice to Gmail platform selection flow
- When user selects "Gmail" in `platform_selection_screen.dart`, present two options:
  - "Sign in with Google (OAuth)" -- for alpha/beta testers (note: tokens expire after 7 days for unverified app)
  - "Use Gmail App Password (IMAP)" -- for general users (note: requires 2FA enabled)
- Store selected auth method with account record
- Route to appropriate adapter based on selection

**Task B: In-App Setup Walkthrough - Gmail OAuth** (~2-3h, Haiku)
- Create walkthrough screen/dialog explaining:
  - What to expect: Google consent screen, "unverified app" warning, how to proceed
  - Token behavior: access may expire after 7 days, user will need to re-authenticate
  - When re-authentication is needed: clear prompt with "Sign in again" button
  - What data the app accesses (read email, move to trash, list folders)
- Show walkthrough on first Gmail OAuth setup, with "Do not show again" option

**Task C: In-App Setup Walkthrough - Gmail App Password** (~2-3h, Haiku)
- Create walkthrough screen/dialog with step-by-step instructions:
  1. Go to Google Account (myaccount.google.com)
  2. Security > 2-Step Verification (must be enabled first)
  3. App Passwords > Select app > Generate
  4. Copy the 16-character password
  5. Enter it in the app
- Include note: "App passwords require 2-Step Verification to be enabled on your Google account"
- Include note: "App passwords do not expire -- you only need to set this up once"
- Show walkthrough on first Gmail app password setup, with "Do not show again" option

**Task D: Per-Account Auth Method Tracking** (~3-4h, Sonnet)
- Modify `PlatformRegistry` to support Gmail with two auth methods:
  - Current: Gmail is hardcoded to `AuthMethod.oauth2`
  - New: Gmail offers `AuthMethod.oauth2` OR `AuthMethod.appPassword`
- Store selected auth method in `accounts` database table (new column or use existing metadata)
- On scan/reconnect, use stored auth method to select correct adapter:
  - `AuthMethod.oauth2` -> `GmailApiAdapter` (existing Gmail REST API path)
  - `AuthMethod.appPassword` -> `GenericImapAdapter` with Gmail IMAP config (`imap.gmail.com:993`)
- Add Gmail IMAP config to `GenericImapAdapter` factory (new `.gmail()` constructor or config entry)

**Task E: Remove Unused Auth Methods** (~1-2h, Haiku)
- Remove `AuthMethod.apiKey` from enum (ProtonMail Bridge -- not implemented, no adapter exists)
- Audit all `AuthMethod` references and remove dead code paths
- Update tests to reflect removed enum value

**Files to Modify**:
- `lib/adapters/email_providers/platform_registry.dart` - Gmail dual-auth config, remove apiKey
- `lib/adapters/email_providers/spam_filter_platform.dart` - Remove `apiKey` from AuthMethod enum
- `lib/adapters/email_providers/generic_imap_adapter.dart` - Add `.gmail()` factory constructor
- `lib/ui/screens/platform_selection_screen.dart` - Gmail auth method choice UI
- `lib/ui/screens/account_setup_screen.dart` - Route to correct setup flow
- `lib/core/storage/database_helper.dart` - Store auth method per account (if not already tracked)
- New: `lib/ui/screens/gmail_oauth_walkthrough.dart` (or dialog widget)
- New: `lib/ui/screens/gmail_app_password_walkthrough.dart` (or dialog widget)

**Acceptance Criteria**:
- [ ] Gmail platform selection offers choice: OAuth or App Password
- [ ] In-app walkthrough shown for Gmail OAuth setup (explains consent screen, 7-day tokens, re-auth)
- [ ] In-app walkthrough shown for Gmail App Password setup (step-by-step Google Account instructions)
- [ ] Selected auth method stored per Gmail account in database
- [ ] On reconnect/scan, correct adapter used based on stored auth method
- [ ] Gmail IMAP via app password works end-to-end (connect, scan, move, delete)
- [ ] Gmail OAuth continues to work as before (no regression)
- [ ] `AuthMethod.apiKey` removed from codebase
- [ ] All existing tests pass, new tests added for dual-auth routing
- [ ] Walkthroughs have "Do not show again" option

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Gmail IMAP config differences from AOL/Yahoo | Low | Medium | Test with real Gmail account; Gmail IMAP is well-documented |
| Google deprecates app passwords | Low (years) | High | CASA path ready when triggered; monitor Google announcements |
| User confusion with two auth options | Medium | Medium | Clear walkthrough explains trade-offs; recommend app password for non-testers |

---

## Issue Backlog

**Last Updated**: February 1, 2026

This section tracks all open and fixed GitHub issues from code review and sprint work. For detailed issue descriptions, root causes, and acceptance criteria, see `ISSUE_BACKLOG.md`.

### Status Summary

| Status | Count | Issues |
|--------|-------|--------|
| [OK] Fixed | 12 | #4, #8, #18, #38, #39, #40, #41, #43, #107, #108, #109, #110 |
| ⏸️ HOLD | 2 | #44, #49 |

### [OK] Fixed Issues

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

## Google Play Store Readiness

**Added**: February 15, 2026
**Status**: Planning (features identified, architectural decisions pending)
**Objective**: Identify and plan all features, configurations, and policy compliance needed to publish the app on the Google Play Store.

### Current App Assessment

The app is approximately 60-70% ready for Play Store publication. Core spam filtering functionality is complete and production-ready. The remaining work is primarily administrative (signing, permissions, policies, branding) and compliance-related (Gmail API verification, privacy policy, data safety declarations).

**What is already done**:
- Core spam filtering functionality (complete and tested)
- Secure credential storage via `flutter_secure_storage` (encrypted at rest)
- OAuth 2.0 implementation for Gmail (Android + Windows)
- IMAP support for AOL, Yahoo, generic providers
- 185+ automated tests passing
- Multi-account support
- Background scanning architecture (WorkManager on Android, Task Scheduler on Windows)
- Notification infrastructure (`flutter_local_notifications`)
- Accessibility helper foundation (`accessibility_helper.dart`)
- MSIX configuration for Windows (in `pubspec.yaml`)

### Gap Analysis Summary

| Area | Current State | Play Store Required | Gap Severity |
|------|--------------|---------------------|-------------|
| Application ID | `com.example.spamfiltermobile` | Unique reverse-domain ID | BLOCKING |
| Release Signing | Debug keys only | Production keystore + Play App Signing | BLOCKING |
| App Bundle Format | APK builds only | AAB (Android App Bundle) required | BLOCKING |
| Privacy Policy | None | Publicly hosted URL required | BLOCKING |
| Gmail OAuth Verification | Unverified (dev-only) | Restricted scope verification + CASA audit | BLOCKING |
| Android Permissions | INTERNET only (debug/profile) | INTERNET, POST_NOTIFICATIONS, WAKE_LOCK, etc. | BLOCKING |
| Data Safety Form | Not started | Required in Play Console | BLOCKING |
| Content Rating | Not started | IARC questionnaire required | BLOCKING |
| App Version | 0.1.0 | Must be 1.0.0+ for release | HIGH |
| Adaptive Icons | No (only legacy mipmap) | Required for Android 8+ (API 26+) | HIGH |
| ProGuard/R8 Rules | None configured | Needed for obfuscation and size | HIGH |
| Store Listing Assets | None | Icon 512x512, feature graphic 1024x500, screenshots | HIGH |
| App Label | `spamfilter_mobile` | User-friendly display name | HIGH |
| Target SDK | Flutter default (~34) | API 35 required now; API 36 expected by Aug 2026 | MEDIUM |
| 16 KB Page Size | Unknown | Required for updates by May 1, 2026 | MEDIUM |
| Localization | None (all strings hardcoded) | English sufficient, but l10n structure recommended | LOW |
| Crash Reporting | Firebase Analytics included but unused | Recommended for production monitoring | LOW |
| Database Encryption | SQLite unencrypted | Recommended for scan results data | LOW |

### Feature List: Google Play Store Publication

#### GP-1: Application Identity and Branding

**Priority**: BLOCKING
**Estimated Effort**: 4-6 hours
**ADR**: ADR-0026 (Application Identity and Package Naming) - **Accepted**

**Decision (2026-02-23)**:
- **Domain**: `myemailspamfilter.com` (available, to be registered)
- **Application ID**: `com.myemailspamfilter`
- **App Name**: `MyEmailSpamFilter`

**Description**: Change the application from development defaults to production-ready identity.

**Prerequisite**: Register `myemailspamfilter.com` domain before starting implementation.

**Tasks**:

*Task A: Android Identity Update* (~1-2h, Haiku)
- Update `applicationId` to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- Update `namespace` to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- Update `android:label` to `MyEmailSpamFilter` in `AndroidManifest.xml`
- Update any Kotlin/Java package references if they exist

*Task B: Windows MSIX Identity Update* (~1h, Haiku)
- Update `identity_name` to `MyEmailSpamFilter` in `pubspec.yaml` msix_config
- Update `display_name` to `MyEmailSpamFilter` in `pubspec.yaml` msix_config
- Update `publisher_display_name` to `MyEmailSpamFilter` in `pubspec.yaml` msix_config

*Task C: Firebase Re-registration* (~1-2h, Haiku)
- Re-register Android app in Firebase Console with new package name `com.myemailspamfilter`
- Add SHA-1 fingerprint for new package
- Download new `google-services.json`
- Place in `mobile-app/android/app/google-services.json`

*Task D: Codebase References Update* (~1h, Haiku)
- Search entire codebase for `com.example.spamfiltermobile` and `spam_filter_mobile` references
- Update AppPaths storage directory name if hardcoded
- Update any test fixtures that reference the old package name
- Verify OAuth redirect URI is unaffected (should be independent)

*Task E: Verification* (~1h, Haiku)
- Build and run on Android emulator (verify new package name)
- Build and run on Windows (verify MSIX identity)
- Run full test suite
- Verify Google Sign-In still works with new package name + new `google-services.json`

**Note**: Existing debug installations must be uninstalled before installing the renamed app. Saved credentials under the old package name will be orphaned (users re-authenticate once).

---

#### GP-2: Release Signing and Play App Signing

**Priority**: BLOCKING
**Estimated Effort**: 4-6 hours
**ADR Required**: ADR-0027 (Android Release Signing Strategy)

**Description**: Configure production signing for release builds and enroll in Google Play App Signing.

**Tasks**:
- Generate a production keystore (upload key)
- Configure `signingConfigs.release` in `build.gradle.kts`
- Secure keystore file (NEVER commit to git)
- Create keystore backup strategy (loss = cannot update app)
- Enroll in Play App Signing (Google manages the signing key)
- Build AAB (Android App Bundle) instead of APK
- Configure `flutter build appbundle` in build scripts
- Update `build-apk.ps1` to `build-aab.ps1` or add AAB target
- Test signed release build on physical device

**Decision Points** (ADR-0027):
- Where to store the keystore securely (local only vs cloud backup)?
- Upload key vs app signing key management approach?
- How to integrate signing into existing PowerShell build scripts?
- Should signing credentials be injected at build time (like secrets.dev.json) or stored locally?

---

#### GP-3: Android Manifest Permissions

**Priority**: BLOCKING
**Estimated Effort**: 4-6 hours
**ADR Required**: ADR-0028 (Android Permission Strategy)

**Description**: Declare all required permissions in the main AndroidManifest.xml and implement runtime permission requests for dangerous permissions.

**Current State**: Only `INTERNET` is declared (and only in debug/profile manifests, not main).

**Permissions Needed**:

| Permission | Type | Why Needed |
|-----------|------|-----------|
| `INTERNET` | Normal | Network access for IMAP/Gmail API |
| `POST_NOTIFICATIONS` | Dangerous (API 33+) | Background scan completion notifications |
| `RECEIVE_BOOT_COMPLETED` | Normal | Resume scheduled background scans after reboot |
| `WAKE_LOCK` | Normal | Keep CPU awake during background scan |
| `FOREGROUND_SERVICE` | Normal | Run background scan as foreground service (API 34+) |
| `FOREGROUND_SERVICE_DATA_SYNC` | Normal (API 34+) | Foreground service type for data sync |

**Tasks**:
- Add all required permissions to main `AndroidManifest.xml`
- Implement runtime permission request for `POST_NOTIFICATIONS` (Android 13+)
- Create permission request UI flow (explain why notification permission is needed)
- Handle permission denial gracefully (background scans work but no notifications)
- Register notification channel before requesting permission
- Test on Android 13+ (API 33+) and older API levels
- Declare foreground service type for background scanning (API 34+)

**Decision Points** (ADR-0028):
- When to request notification permission (on first launch vs when enabling background scans)?
- How to handle permission denial (silent degradation vs repeated prompts)?
- Whether to use `SCHEDULE_EXACT_ALARM` or `SCHEDULE_INEXACT_ALARM` for background scheduling?
- Foreground service approach for long-running scans (API 34+ requires foreground service type)?

---

#### GP-4: Gmail API OAuth Verification

**Priority**: ON HOLD (deferred until revenue trigger)
**Estimated Effort**: 40-80 hours (includes CASA audit timeline of 2-6 months)
**ADR**: ADR-0029 (Gmail API Scope and Verification Strategy) - **Accepted**

**Decision (2026-02-22)**: CASA verification is ON HOLD. Pursue CASA verification when: (a) app has 2,500+ active Gmail IMAP users at $3 annually or yearly revenue exceeds $5,000 (covering annual CASA cost). Until then, Gmail users use app passwords via IMAP (Phase 2) and alpha/beta testers use unverified OAuth (Phase 1). See ADR-0029 and ADR-0034 for full strategy.

**Description**: Complete Google's three-tier OAuth verification process required for public apps using restricted Gmail scopes.

**CASA Security Assessment** (for when triggered):
- Based on OWASP ASVS standard
- Approved labs: TAC Security, Leviathan Security, DEKRA, Bishop Fox, Prescient Security
- Cost: Tier 2 ($500-$1,800/app), Tier 3 ($4,500-$8,000+/app)
- Some sources report $15,000-$75,000+ for full restricted scope verification
- Timeline: 2-6 months from start to approval
- Renewal: Annual (every 12 months)

**Tasks** (deferred until CASA trigger):
- Register a domain for the app (needed for brand verification)
- Create Google Cloud project for production (separate from development)
- Configure OAuth consent screen for production
- Submit for brand verification
- Prepare scope justification documentation
- Record demonstration video showing OAuth flow and scope usage
- Prepare for CASA security assessment
- Engage approved CASA assessor
- Complete assessment and submit Letter of Assessment (LOA) to Google
- Budget for annual renewal

**Scope Decision** (ADR-0029 - Accepted):
- Use `gmail.modify` scope (current implementation, covers all features)
- No incremental authorization (both scopes are restricted, adds UX complexity with no verification benefit)
- Budget allocation for initial assessment and annual renewals?
- Is a separate production Google Cloud project needed?
- Timeline for verification process (this is the longest lead-time item)?

---

#### GP-5: Privacy Policy and Legal Documents

**Priority**: BLOCKING
**Estimated Effort**: 8-16 hours (including legal review)
**ADR Required**: ADR-0030 (Privacy and Data Governance Strategy)

**Description**: Create and publish a comprehensive privacy policy, terms of service, and data handling documentation required by both Google Play Store and Google API Services User Data Policy.

**Requirements**:
- Privacy policy must be on a publicly accessible, non-geofenced URL
- Must comprehensively disclose: data accessed, collected, used, shared, and stored
- Must be consistent with Play Store Data Safety form declarations
- Must comply with Google API Services User Data Policy (additional requirements for Gmail access)
- Must address GDPR (EU) and CCPA (California) requirements
- Must describe user data deletion process

**Google API Services User Data Policy Specific Requirements**:
- Data use limited to practices explicitly disclosed in privacy policy
- Prohibited: selling data, serving ads based on email content, surveillance
- Must request minimum scopes necessary (principle of least privilege)
- Human access to user data prohibited except with explicit consent
- Must be able to delete user data upon request

**Tasks**:
- Draft privacy policy covering all data handling practices
- Draft terms of service
- Host privacy policy on a public URL (website needed)
- Create in-app privacy policy link
- Document data retention and deletion policies
- Create account/data deletion mechanism (required by Jan 28, 2026 policy)
- Implement in-app data deletion feature
- Create web-accessible data deletion request process
- Legal review of all documents

**Decision Points** (ADR-0030):
- Where to host privacy policy (GitHub Pages, dedicated website, app landing page)?
- What data retention period for scan results?
- How to implement account deletion (in-app only vs also web-based)?
- Whether to collect any analytics/crash reporting data (impacts privacy disclosures)?
- How to handle GDPR data subject access requests?
- Legal review approach (self-drafted vs attorney-reviewed)?

---

#### GP-6: Play Store Listing and Assets

**Priority**: HIGH
**Estimated Effort**: 8-12 hours

**Description**: Create all required and recommended Play Store listing assets.

**Required Assets**:
| Asset | Specification |
|-------|-------------|
| App Icon (Play Store) | 512 x 512 px, max 1024 KB |
| Feature Graphic | 1024 x 500 px, JPG or 24-bit PNG (no alpha) |
| Phone Screenshots | Min 2, max 8; sides 320-3840 px, 16:9 aspect ratio |
| App Title | Max 30 characters |
| Short Description | Max 80 characters |
| Full Description | Max 4,000 characters |
| Developer Email | Public contact email |

**Recommended Assets**:
| Asset | Specification |
|-------|-------------|
| Tablet Screenshots | For large screen support |
| Promotional Video | YouTube URL |
| 7-inch Tablet Screenshots | 2-8 screenshots |
| 10-inch Tablet Screenshots | 2-8 screenshots |

**Tasks**:
- Design professional app icon (512x512 for store + adaptive icon for device)
- Create feature graphic (1024x500)
- Capture app screenshots on phone (2-8 screenshots showing key features)
- Write app title, short description, and full description
- Set up developer contact email
- Complete content rating questionnaire (IARC)
- Complete Data Safety form
- Select app category and tags
- Prepare release notes for first version

---

#### GP-7: Adaptive Icons and App Branding

**Priority**: HIGH
**Estimated Effort**: 4-6 hours
**ADR Required**: ADR-0031 (App Icon and Visual Identity)

**Description**: Create adaptive icons (required for Android 8+/API 26+), replace legacy mipmap icons, and establish visual identity.

**Current State**: Only legacy `ic_launcher.png` files exist in mipmap density folders. No adaptive icon (foreground/background) layers, no round icon variant.

**Tasks**:
- Design app icon with foreground and background layers
- Create `ic_launcher_foreground.xml` (or PNG) for adaptive icon
- Create `ic_launcher_background.xml` (or solid color)
- Generate all density variants (mdpi through xxxhdpi)
- Create round icon variant (`ic_launcher_round`)
- Update `AndroidManifest.xml` with `android:roundIcon`
- Create branded splash screen (replace white placeholder)
- Create 512x512 high-res icon for Play Store listing

**Decision Points** (ADR-0031):
- App icon design approach (shield/filter metaphor, email icon, abstract)?
- Color scheme and brand identity?
- Use flutter_launcher_icons package for generation or manual creation?
- Splash screen design (branded vs minimal)?

---

#### GP-8: Android Target SDK and 16 KB Page Size Compliance

**Priority**: MEDIUM
**Estimated Effort**: 4-8 hours

**Description**: Ensure the app meets current and upcoming Android API level and memory page size requirements.

**Requirements**:
- **Now**: Target API 35 (Android 15) for new app submissions
- **By August 2026** (projected): Target API 36 (Android 16)
- **By May 1, 2026**: Support 16 KB memory page sizes for app updates

**16 KB Page Size Requirements**:
- Flutter stable 3.32.8 or later
- Android Gradle Plugin 8.7.3 or newer
- NDK r28 or newer preferred
- All native dependencies must be compatible

**Tasks**:
- Verify current Flutter version and upgrade if needed
- Update Android Gradle Plugin to 8.7.3+
- Verify NDK version compatibility
- Update `targetSdkVersion` to 35 (or 36 when available)
- Update `compileSdkVersion` accordingly
- Test app on Android 15 emulator/device
- Verify all dependencies are 16 KB page size compatible
- Run Android lint checks for API 35 compatibility
- Test on large screen / foldable devices (adaptive app quality)

---

#### GP-9: ProGuard/R8 Code Optimization

**Priority**: HIGH
**Estimated Effort**: 4-6 hours

**Description**: Configure R8 (ProGuard replacement) for code shrinking, obfuscation, and optimization in release builds.

**Current State**: No `proguard-rules.pro` file exists. Release builds are unobfuscated and unoptimized.

**Tasks**:
- Create `proguard-rules.pro` with keep rules for:
  - Firebase Analytics classes
  - Google API client libraries
  - enough_mail IMAP library
  - flutter_secure_storage
  - flutter_appauth OAuth classes
  - google_sign_in classes
  - workmanager classes
  - Reflection-dependent classes
- Enable `minifyEnabled true` for release builds
- Enable `shrinkResources true` for release builds
- Test release build thoroughly (R8 can break reflection-dependent code)
- Measure APK/AAB size reduction
- Verify all OAuth flows work after obfuscation
- Verify IMAP connections work after obfuscation

---

#### GP-10: Data Safety Form Declarations

**Priority**: BLOCKING
**Estimated Effort**: 2-4 hours (after privacy policy is complete)

**Description**: Complete the Google Play Data Safety form accurately, consistent with the privacy policy.

**Data the App Handles**:

| Data Type | Collected? | Shared? | Processing | Encryption |
|-----------|-----------|---------|-----------|-----------|
| Email address | Yes (for account login) | No | On-device only | Yes (flutter_secure_storage) |
| Email message metadata | Transient (scan only) | No | On-device only | No (in-memory only) |
| Email message content | Transient (scan only) | No | On-device only | No (in-memory only) |
| OAuth tokens | Yes | No | On-device only | Yes (flutter_secure_storage) |
| IMAP passwords | Yes | No | On-device only | Yes (flutter_secure_storage) |
| Scan results | Yes (local DB) | No | On-device only | No (SQLite unencrypted) |
| Spam filter rules | Yes (local DB) | No | On-device only | No (SQLite unencrypted) |
| App settings | Yes (local DB) | No | On-device only | No (SQLite unencrypted) |

**Key Declarations**:
- No data shared with third parties
- No advertising SDKs
- No analytics data collected (Firebase Analytics included but not initialized)
- All data encrypted in transit (TLS/HTTPS for IMAP and Gmail API)
- Authentication tokens encrypted at rest
- Users can request data deletion

**Tasks**:
- Complete all sections of the Data Safety form in Play Console
- Cross-reference with privacy policy for consistency
- Document which third-party libraries collect data (if any)
- Verify Firebase Analytics is either removed or properly disclosed

---

#### GP-11: Account and Data Deletion Feature

**Priority**: HIGH (required by Google Play policy effective Jan 28, 2026)
**Estimated Effort**: 8-12 hours
**ADR Required**: ADR-0032 (User Data Deletion Strategy)

**Description**: Implement user account and data deletion, discoverable both within the app and via a web interface.

**Google Play Requirement**: If the app allows users to create accounts, it must allow them to request account deletion. The deletion option must be discoverable both in-app and outside the app (e.g., via a website).

**Tasks**:
- Create in-app "Delete Account" feature in Settings
- Delete all local data for account: credentials, tokens, scan results, settings
- Delete all local data for app-wide settings if last account removed
- Revoke OAuth tokens with Google/providers on account deletion
- Create web-based data deletion request process (or landing page with instructions)
- Show confirmation dialog before deletion (irreversible)
- Handle partial deletion gracefully (e.g., if token revocation fails but local data is deleted)
- Document data deletion in privacy policy

**Decision Points** (ADR-0032):
- What constitutes an "account" in this app (email provider login vs local app account)?
- Should deletion be per-account or all-app-data?
- How to handle the web-based deletion requirement (website form vs email request)?
- What data to retain after deletion (if any) for security/compliance?
- Should deleted account data be wiped immediately or scheduled for deletion?

---

#### GP-12: Firebase Analytics Decision

**Priority**: MEDIUM
**Estimated Effort**: 2-4 hours
**ADR Required**: ADR-0033 (Analytics and Crash Reporting Strategy)

**Description**: Decide whether to use Firebase Analytics / Crashlytics for production monitoring, or remove the Firebase dependency entirely.

**Current State**: Firebase BOM and Analytics are included in `build.gradle.kts` dependencies but are NOT actively initialized or used in Dart code. The `google-services.json` file is present for Firebase project configuration.

**Impact**: Any analytics/crash reporting must be disclosed in the Data Safety form and privacy policy. This directly affects GP-5 and GP-10.

**Tasks**:
- Decide: Enable Firebase Analytics + Crashlytics, or remove Firebase entirely?
- If enabling: Initialize Firebase in `main.dart`, configure Crashlytics, update privacy disclosures
- If removing: Remove `firebase-bom` and `firebase-analytics` from `build.gradle.kts`, remove `google-services.json` if no longer needed for OAuth
- Note: `google-services.json` may still be needed for Google Sign-In on Android regardless of Firebase usage

**Decision Points** (ADR-0033):
- Is crash reporting valuable enough to justify privacy disclosure complexity?
- Firebase Analytics vs Crashlytics-only vs no telemetry?
- If analytics enabled, what events to track (only crashes, or also usage patterns)?
- User opt-in vs opt-out for analytics?
- Impact on privacy policy and Data Safety form?

---

#### GP-13: Persistent Gmail Authentication for Production

**Priority**: [OK] RESOLVED (merged with F12, 2026-02-22)
**Estimated Effort**: 0 hours (no code changes needed)

**Resolution**: Merged with F12. Token lifetime is determined by app verification status, not code implementation. All required code infrastructure already exists. See ADR-0029 and ADR-0034 for the phased Gmail authentication strategy and CASA verification trigger.

---

#### GP-14: IMAP vs Gmail REST API Architecture Decision

**Priority**: [OK] RESOLVED (ADR-0034 Accepted, 2026-02-22)
**Estimated Effort**: 0 hours (no migration needed - dual-path uses existing adapters)
**ADR**: ADR-0034 (Gmail Access Method for Production) - **Accepted**

**Decision**: Dual-path approach. Gmail REST API with OAuth for alpha/beta testers (existing `GmailApiAdapter`). Gmail app passwords via IMAP for general users (existing `GenericImapAdapter`). CASA verification deferred until revenue trigger (2,500+ users at $3/yr or $5,000/yr). No code changes needed -- both adapters already exist and are tested.

---

#### GP-15: Version Numbering and Release Strategy

**Priority**: HIGH
**Estimated Effort**: 2-4 hours

**Description**: Establish version numbering for Play Store releases and plan the release lifecycle.

**Current State**: Version is `0.1.0` in `pubspec.yaml`. Play Store requires `versionCode` to increment with every upload.

**Tasks**:
- Set initial release version (e.g., `1.0.0`)
- Establish `versionCode` numbering scheme (must increment monotonically)
- Update `pubspec.yaml` version
- Update `msix_config` version to match
- Plan release cycle (how often to publish updates)
- Decide on release track strategy (internal testing -> closed testing -> open testing -> production)
- Document version management process

---

#### GP-16: Google Play Developer Account Setup

**Priority**: BLOCKING
**Estimated Effort**: 2-4 hours

**Description**: Register for a Google Play Developer account and complete identity verification.

**Requirements**:
- One-time $25 registration fee
- Developer identity verification (becoming mandatory in select regions Sep 2026, globally 2027)
- Provide legal name, address, email, phone number
- Accept Google Play Developer Distribution Agreement

**Tasks**:
- Register Google Play Developer account
- Complete identity verification
- Set up payment profile (even for free apps)
- Configure developer profile (public-facing)
- Create developer contact email

---

### Architectural Decisions Required

The following ADRs capture decisions for Play Store publication. ADR-0029 and ADR-0034 have been accepted; the remaining are proposed with decision criteria and key considerations.

| ADR | Title | Blocking Feature | Status |
|-----|-------|-----------------|--------|
| ADR-0026 | Application Identity and Package Naming | GP-1 | **Accepted** |
| ADR-0027 | Android Release Signing Strategy | GP-2 | Proposed |
| ADR-0028 | Android Permission Strategy | GP-3 | Proposed |
| ADR-0029 | Gmail API Scope and Verification Strategy | GP-4 | **Accepted** |
| ADR-0030 | Privacy and Data Governance Strategy | GP-5 | Proposed |
| ADR-0031 | App Icon and Visual Identity | GP-7 | Proposed |
| ADR-0032 | User Data Deletion Strategy | GP-11 | Proposed |
| ADR-0033 | Analytics and Crash Reporting Strategy | GP-12 | Proposed |
| ADR-0034 | Gmail Access Method for Production | GP-14 | **Accepted** |

### Estimated Total Effort

| Category | Effort Range | Notes |
|----------|-------------|-------|
| Technical features (GP-1,2,3,7,8,9,15) | 26-42 hours | Build config, permissions, icons, SDK |
| Policy and compliance (GP-4,5,10,16) | 52-104 hours | Gmail verification is 2-6 months elapsed |
| User-facing features (GP-6,11,12,13) | 26-40 hours | Store listing, deletion, analytics, auth |
| Architecture decisions (ADR-0026 through 0034) | 8-16 hours | Research and document decisions |
| **Total** | **112-202 hours** | Plus 2-6 months for Gmail verification |

### Critical Path

GP-4 (Gmail API OAuth Verification) is ON HOLD until the revenue trigger is met. GP-13 (Persistent Gmail Auth) and GP-14 (Gmail API method) are RESOLVED. This significantly simplifies the Play Store readiness path -- the app can launch with Gmail app password support without any CASA verification.

**Recommended Sequencing** (updated 2026-02-22):
1. **Immediate**: GP-16 (Developer Account) + GP-1 (Application Identity) + ADR-0026
2. **Early**: GP-5 (Privacy Policy) + ADR-0030
3. **Sprint Work**: GP-2,3,7,8,9 (Technical features) + ADR-0027, ADR-0028, ADR-0031
4. **After Privacy Policy**: GP-10 (Data Safety Form) + GP-11 (Account Deletion) + ADR-0032
5. **Before Submission**: GP-6 (Store Listing) + GP-15 (Versioning)
6. **Decision**: GP-12 (Analytics) + ADR-0033
7. **Deferred**: GP-4 (CASA Verification) -- trigger: 2,500+ Gmail IMAP users at $3/yr or $5,000/yr revenue

### Cost Estimates

| Item | Cost | Frequency |
|------|------|-----------|
| Google Play Developer Account | $25 | One-time |
| CASA Security Assessment (Tier 2) | $500-$1,800 | Annual |
| CASA Security Assessment (Tier 3) | $4,500-$8,000+ | Annual |
| Domain registration (for brand verification) | $12-$20/year | Annual |
| Privacy policy hosting | $0-$10/month | Monthly (or free via GitHub Pages) |
| **Minimum Annual Cost** | ~$550-$1,850 | After initial $25 |
| **Maximum Annual Cost** | ~$4,600-$8,100+ | If Tier 3 CASA required |

---

## Version History

**Version**: 3.3
**Date**: February 15, 2026
**Author**: Claude Opus 4.6
**Status**: Active

**Updates**:
- 3.3 (2026-02-15): Added Google Play Store Readiness section
  - Deep dive analysis of Play Store requirements vs current app state
  - 16 features identified (GP-1 through GP-16) with effort estimates
  - 9 architectural decisions identified (ADR-0026 through ADR-0034) in Proposed status
  - Gap analysis, critical path, cost estimates, and recommended sequencing
  - Gmail API restricted scope verification identified as longest lead-time item (2-6 months)
- 3.2 (2026-02-06): Sprint 13 completed - Account-Specific Folder Settings
  - Actual scope: F16A (Subject Cleaning), F15 (Settings UI), F14 (Deleted Rule Folder), F13 (Safe Sender Folder)
  - Original scope (F5 + F12) deferred based on user priorities
  - Duration: ~3 hours (estimated 26-33 hours, 9x faster due to scope simplification)
  - Added Sprint 13 to Past Sprint Summary
  - Updated Current Sprint status to "READY TO START" for Sprint 12
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
