# All Sprints Master Plan - Complete Sprint Breakdown

**Status**: Master planning document for all sprints (Phase 3.5+)
**Created**: January 25, 2026
**Last Updated**: January 31, 2026
**Total Effort**: ~60-80 hours across 10 sprints (Phase 3.5)
**Target Completion**: Q1-Q2 2026

**Source & Credit**:
- Original Phase 3.5 description: User-provided
- Sprint 1-3 execution details: Completed and documented
- Sprint 4-10 recreation: Based on original Phase 3.5 plan + what remains to be done
- Planning & coordination: User oversight

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** (this doc) | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 3.5 Goals & Objectives](#phase-35-goals--objectives)
3. [Sprint 1-10 Complete Breakdown](#sprint-1-10-complete-breakdown)
4. [Cross-Sprint Dependencies](#cross-sprint-dependencies)
5. [Resource Allocation](#resource-allocation)
6. [Risk Management](#risk-management)
7. [Success Criteria](#success-criteria)

---

## Overview

Phase 3.5 represents the "Safe Sender & Advanced Features" phase, implementing comprehensive exception handling, persistence, and user-facing management tools. This phase builds on the database foundations from Sprints 1-2 and extends the architecture to support complex user workflows.

**Key Characteristics**:
- 10 sequential sprints with clear dependencies
- Mix of backend (Sprints 1-3, 6, 10) and frontend (Sprints 4-5, 7-9)
- Platform-specific work (Sprints 7-8 for background scanning)
- Progressive feature rollout from core to polish

---

## Phase 3.5 Goals & Objectives

### Primary Goals (Per Original Requirements)
1. **Processing Scan Results** - Backend storage + UI for reviewing and processing unmatched emails
2. **User Application Settings** - Comprehensive settings UI for manual/background scans and per-account configuration
3. **Interactive Rule/Safe Sender Management** - UI to add rules and safe senders from scan results
4. **Background Scanning Implementation** - Automatic periodic scans per user settings
5. **Production Readiness** - Testing, optimization, and release preparation

### Business Value
- Users can review and process unmatched emails interactively
- Quick-add rules and safe senders directly from scan results
- Flexible scanning configuration (manual vs background, frequency, scope)
- Platform-specific optimizations (AOL and Gmail)
- Complete rule management without manual YAML editing

### Technical Objectives
- Persistent scan result storage (unmatched emails)
- One unmatched list per scan type (manual, background)
- Smart email availability checking (external moves/deletes)
- Provider-specific email identifiers (Message-ID, IMAP UID, etc.)
- Safe sender exceptions (denylist override after matching)
- Background scanning per provider/email configuration
- Normalization for From/Subject/Body pattern matching

---

## Sprint 1-10 Complete Breakdown

### SPRINT 1: Database Foundation (COMPLETE ✅)
**Status**: ✅ COMPLETE (January 24, 2026)
**Dates**: January 19-24, 2026
**Duration**: ~4 hours actual (vs 9-13 estimated)

**Objective**: Establish SQLite database schema and migration infrastructure

**Tasks**:
- **Task A**: DatabaseHelper with full schema (Rule, SafeSender, MigrationState tables)
- **Task B**: YAML-to-SQLite migration with rollback capability
- **Task C**: Migration state machine for tracking progress

**Deliverables**:
- `lib/core/storage/database_helper.dart` (668 lines)
- `lib/core/storage/migration_manager.dart` (400+ lines)
- Unit tests (40+ tests, 95%+ coverage)

**Key Decisions**:
- SQLite for multi-platform persistence (no native dependencies)
- State machine pattern for reliable migrations
- Automatic schema versioning

**Outcomes**:
- ✅ 40+ tests passing
- ✅ Zero regressions
- ✅ Issue #51 fixed (rule name display)

**Next Sprint Dependency**: Sprint 2 builds on this database foundation

---

### SPRINT 2: Database Rule Storage & Integration (COMPLETE ✅)
**Status**: ✅ COMPLETE (January 24, 2026)
**Dates**: January 22-24, 2026
**Duration**: 6.8 hours actual (vs 12-17 estimated)

**Objective**: Integrate database into RuleSetProvider with dual-write pattern

**Tasks**:
- **Task A**: RuleDatabaseStore (SQLite CRUD operations for rules)
- **Task B**: RuleSetProvider refactoring (load rules from database)
- **Task C**: YAML export maintenance (keep YAML files in sync for version control)

**Deliverables**:
- `lib/core/storage/rule_database_store.dart` (429 lines)
- `lib/core/providers/rule_set_provider.dart` (updated)
- Tests (20+ tests, 94%+ coverage)

**Architecture Pattern**: Dual-Write
- Database is PRIMARY storage (SQLite)
- YAML is SECONDARY storage (version control backup)
- All writes go to both, reads from database

**Key Decisions**:
- Maintain YAML export for version control and portability
- Provider pattern for state management
- Error handling with graceful degradation

**Outcomes**:
- ✅ 264 tests passing
- ✅ Zero regressions
- ✅ Model assignments: 100% accuracy (5/5 tasks)

**Next Sprint Dependency**: Sprint 3 adds SafeSender storage

---

### SPRINT 3: Safe Sender Exceptions (IN PROGRESS 🔵)
**Status**: 🔵 COMPLETE (January 25, 2026)
**Dates**: January 24-25, 2026
**Estimated Duration**: 10-14 hours
**Actual Duration**: ~8 hours

**Objective**: Implement safe sender database storage with exception patterns

**Tasks**:
- **Task A**: SafeSenderDatabaseStore (database CRUD for safe senders with exceptions)
- **Task B**: SafeSenderEvaluator (two-level matching: safe sender check + exception check)
- **Task C**: RuleSetProvider integration (load safe senders from database)
- **BONUS**: Issue #71 fix (YAML migration not running - critical bug)

**Deliverables**:
- `lib/core/storage/safe_sender_database_store.dart` (350+ lines)
- `lib/core/services/safe_sender_evaluator.dart` (280+ lines)
- `lib/core/providers/rule_set_provider.dart` (updated +35 lines)
- `test/integration/aol_folder_scan_test.dart` (143 lines - new integration test)
- Tests (77 per task = 154 total, 100% coverage)

**Architecture**: Two-Level Exception Logic
```
1. Check if email matches safe sender patterns
   - If YES → return SAFE_SENDER action (don't evaluate rules)
2. If safe sender match, check exceptions
   - If email matches exception pattern → ignore safe sender, evaluate rules
3. Otherwise → evaluate rules normally
```

**Pattern Types**:
- **Email**: Exact match (user@example.com)
- **Domain**: All emails from domain (@example.com)
- **Subdomain**: Domain + all subdomains (@sub.example.com)

**Exception Patterns**:
- Domain exceptions: Allow @company.com except spammer@company.com
- Subdomain exceptions: Allow @*.company.com except @blocked.company.com

**Key Decisions**:
- JSON serialization for exception patterns in database
- Auto-detection of pattern type (email/domain/subdomain)
- Graceful handling of invalid patterns

**Critical Bug Fixed**:
- **Issue #71**: YAML migration never ran on app startup
  - Root cause: MigrationManager created but never called
  - Fix: Added migration check to RuleSetProvider.initialize()
  - Impact: Rules now match correctly in AOL folder scans

**Outcomes**:
- ✅ 341 tests passing (zero regressions)
- ✅ 13 skipped tests (credentials-dependent - expected)
- ✅ Issue #71 critical bug fixed
- ✅ Integration test validates AOL folder scanning
- ✅ PR #72 created and ready for review

**Next Sprint Dependency**: Sprint 4-5 need persistent scan results

---

### SPRINT 4: Processing Scan Results (Backend & UI)
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (backend + UI)

**Objective**: Persistent scan result storage + UI to review and process unmatched emails

**Per Original Requirements**:
- Scan results stored in database (one per scan type: manual, background)
- UI to review last unmatched emails from manual or background scan
- Quick-add rules and safe senders from unmatched email list
- Check for external moves/deletes when reviewing historical results

**Database Schema** (New):

```
ScanResult:
  - id (PK)
  - account_id (FK)
  - scan_type (manual/background)
  - scan_date (timestamp)
  - total_emails (count)
  - matched_count (count)
  - no_rule_count (count)
  - status (success/partial/failed)
  - completed_at (timestamp, nullable)

UnmatchedEmail:
  - id (PK)
  - scan_result_id (FK)
  - provider_email_id (provider-specific identifier)
  - from_email (normalized)
  - subject
  - folder_name
  - received_date
  - still_exists (boolean, for later reviews)
  - processed (boolean)
  - rule_applied_id (FK, nullable)
  - created_at (timestamp)

ProviderEmailIdentifier:
  - id (PK)
  - provider (gmail/aol)
  - message_id_field (IMAP UID, Gmail message ID, etc.)
  - notes
```

**Backend Tasks**:

1. **ScanResultStore** (database CRUD)
   - Save scan results at scan completion
   - Replace previous result of same type (manual/background)
   - Query unmatched emails from last manual scan
   - Query unmatched emails from last background scan

2. **UnmatchedEmailStore** (database CRUD)
   - Retrieve unmatched emails with provider identifiers
   - Check if email still exists in folder (per provider)
   - Mark email as processed when user adds rule
   - Update still_exists status when reviewing later

3. **Provider Email Identifier**
   - Gmail: Use message ID from Gmail API
   - AOL/IMAP: Use IMAP UID + folder
   - Implement abstraction for future providers

**UI Screens**:

1. **Process Results Screen** (entry point)
   - Shows last scan summary (manual or background)
   - Two tabs: Manual Scan Results / Background Scan Results
   - List of unmatched emails (scrollable, loads on demand)
   - Each email shows: `<folder> • <from> • <subject>`

2. **Email Detail View**
   - Full from header
   - Full subject
   - Email headers (view header button)
   - Email body (view body button)
   - Links extracted from body (clickable)
   - Domains from links highlighted

3. **Quick-Add Actions** (from detail or list)
   - Add to Safe Senders:
     - Exact email: `user@example.com`
     - Domain: `@example.com`
     - Wildcard domain: `^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$`
   - Add Auto-Delete Rule:
     - From Header: specific email, domain, or wildcard
     - Subject: pattern to match
     - Body: pattern to match
     - URL domain: extract from body links

4. **Email Status Feedback**
   - "Not found" if email moved/deleted externally
   - Confirmation when rule/safe sender added
   - Progress as user scrolls (load next batch)

**Email Availability Check**:
- When reviewing later: Check if email still in folder
- Use provider-specific methods:
  - Gmail: Query by message ID
  - IMAP: Check UID still valid
- Show "missing" state if not found
- Don't list missing emails in processing view

**Normalization for Pattern Matching**:
- **From Header**: Lowercase, remove special chars, keep [0-9a-z_-]
- **Subject/Body**: Lowercase, preserve: letters/numbers, underscore, hyphen, period, brackets, URL chars
- **Fuzzy matching support**: Try exact, try spaces removed, try common letter replacements (l→1, e→3)

**Tasks**:
- **Task A**: ScanResultStore + UnmatchedEmailStore (database layer)
- **Task B**: Provider email identifier abstraction (Gmail, AOL/IMAP)
- **Task C**: Process results UI (list, detail, quick-add)
- **Task D**: Email availability checking + normalization

**Acceptance Criteria**:
- ✅ Scan results persist correctly
- ✅ One result per scan type (replaces previous)
- ✅ Unmatched emails list displays with proper format
- ✅ Email details show headers/body/links
- ✅ Email availability checked on later reviews
- ✅ Missing emails not shown in list
- ✅ Quick-add creates rules in database
- ✅ Pattern normalization working correctly

**Testing**:
- Perform manual scan, verify results saved
- Perform background scan, verify replaces previous background result
- Review results UI: all fields display correctly
- Check external delete: email shows as missing
- Quick-add safe sender, verify in database
- Quick-add auto-delete rule, verify in database

**Dependencies**:
- Sprint 1-3: Database schema, RuleSet, SafeSender models
- Continue: Pattern normalization helpers, provider abstraction

**Next Sprint Dependency**: Sprint 5 adds User Application Settings UI

---

### SPRINT 5: User Application Settings (Backend & UI)
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (backend + UI)

**Objective**: Comprehensive settings UI for app-wide and per-account configuration

**Per Original Requirements**:
- Manual Scan Defaults (mode, rules to apply, folders)
- Background Scan Defaults (frequency, mode, rules for all future accounts)
- Provider/Email-Specific Settings (auth, background frequency, mode)
- Settings accessible from Account Selection and Scan Progress screens

**Database Schema** (New):

```
AppSettings:
  - key (PK, text)
  - value (JSON)
  - data_type (string/number/boolean/json)
  - updated_at (timestamp)

AccountSettings:
  - id (PK)
  - account_id (FK)
  - background_scan_enabled (boolean)
  - background_scan_frequency_minutes (number)
  - scan_mode_read_only (boolean)
  - scan_mode_process_safe_senders (boolean)
  - scan_mode_process_rules (boolean)
    - auto_delete_from_header (boolean)
    - auto_delete_header_text (boolean)
    - auto_delete_subject (boolean)
    - auto_delete_body (boolean)
    - auto_delete_body_urls (boolean)
  - selected_folders (JSON array)
  - updated_at (timestamp)
```

**UI Navigation**:

1. **Account Selection Screen** (enhancement)
   - Add Settings button (top-right or menu)
   - Navigate to: App Settings → Manual Scan Defaults

2. **Scan Progress Screen** (enhancement)
   - Add Settings button (top-right or menu)
   - Navigate to: Settings → Provider/Email Setup

**Settings Screens**:

1. **Main Settings Screen** (entry point from Account Selection)
   - Two tabs: Manual Scan / Background Scans
   - Each tab contains collapsible sections
   - Links to Provider/Email-specific settings

2. **Manual Scan Defaults** (Tab 1)

   **Scan Mode Section**:
   - Read-Only (checkbox) - don't process any rules
   - Process Safe Senders (checkbox)
   - Process Rules (checkbox for all)
     - Sub-checkboxes (only when "Process Rules" checked):
       - Auto Delete: Header From
       - Auto Delete: Header Text
       - Auto Delete: Subject
       - Auto Delete: Body
       - Auto Delete: Body URLs

   **Folder Selection**:
   - Use existing "Select Folders" functionality
   - "Select Folders to Scan" button
   - Shows available folders per provider

3. **Background Scan Defaults** (Tab 2)

   **Frequency Setting**:
   - Dropdown: Disabled / Every 15 min / Every 30 min / Every 1 hour / Daily

   **Scan Mode** (same as Manual):
   - Read-Only (checkbox)
   - Process Safe Senders (checkbox)
   - Process Rules (checkbox + sub-checkboxes)

   **Note**: These are defaults for newly-added accounts

4. **Provider/Email-Specific Settings** (separate screen)
   - Account selector (if multiple)
   - Provider info (auth status, last sync)
   - Background Scans:
     - Enabled (checkbox)
     - Frequency (same dropdown as defaults)
     - Scan Mode (same as above)
   - Folder selection (same as above)

**Tasks**:
- **Task A**: Settings database layer (AppSettings, AccountSettings CRUD)
- **Task B**: Settings UI screens (Manual/Background defaults, Provider setup)
- **Task C**: Settings integration (apply settings to scans, persistence)

**Key Features**:
- Settings auto-persist to database
- Changes apply immediately to next scan
- Defaults apply to newly-added accounts
- Per-account override of defaults
- Clear explanations for each setting

**Implementation Notes**:
- Manual Scan Defaults: Set once, apply to all manual scans
- Background Scan Defaults: Template for new accounts
- Provider Settings: Override defaults for specific account
- Folder selection: Use existing dynamic folder discovery

**Acceptance Criteria**:
- ✅ Manual Scan Defaults screen displays correctly
- ✅ Background Scan Defaults screen displays correctly
- ✅ Can enable/disable each rule type independently
- ✅ Folder selection works
- ✅ Settings persist to database
- ✅ Settings apply to next scan immediately
- ✅ Provider/Email settings override defaults
- ✅ New accounts use default settings

**Testing**:
- Set manual scan mode to read-only
- Run manual scan, verify no rules applied
- Set background frequency to 15 minutes
- Check database for settings saved
- Add new account, verify uses defaults
- Override defaults for one account, verify applies

**Dependencies**:
- Sprint 4: Scan results storage (Settings need to know scan types)
- Continue: Background scan scheduler (will use these settings)

**Next Sprint Dependency**: Sprint 6 uses settings in background scanning

---

### SPRINT 6: Interactive Rule & Safe Sender Management from Scan Results
**Status**: 📋 PLANNED
**Estimated Duration**: 16-18 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI + backend)

**Objective**: Interactive UI to add rules and safe senders directly from unmatched emails during scan result review

**Per Original Requirements**:
- User adds safe senders from scan results (types 1-4)
- User adds auto-delete rules from scan results (From/Subject/Body/URL)
- Safe sender exceptions (denylist) for types 2-3
- Date added tracking for all rules
- New rules enabled when user selects to add them
- Rule condition buckets: From Header, Header Text, Subject, Body, Body URLs

**Database Schema** (Updated from Sprint 1):

```
Rule:
  - id (PK)
  - name (text)
  - enabled (boolean)
  - condition_type (from_header/header_text/subject/body/body_url)
  - patterns (JSON array of regex strings)
  - actions (JSON: {delete: bool, move_folder: string})
  - execution_order (numeric)
  - date_added (timestamp)  # ← NEW

SafeSender:
  - id (PK)
  - pattern (text, regex)
  - pattern_type (1/2/3/4 from original spec)
  - exceptions (JSON array of exception patterns)  # ← NEW
  - date_added (timestamp)  # ← NEW

SafeSenderException:  # ← NEW
  - id (PK)
  - safe_sender_id (FK)
  - exception_pattern (text, regex)
  - description (text)
  - created_at (timestamp)
```

**UI Flows**:

1. **Add Safe Sender from Scan Result**

   Dialog Flow:
   ```
   Select Safe Sender Type
     ↓
   Type 1: Exact email (user@example.com)
     → Pattern: ^user@example\.com$
     → Show: Will match only this email

   Type 2: Specific domain (@example.com)
     → Pattern: @example\.com$
     → Show: Will match any@example.com
     → Option: Add exceptions (denylist)

   Type 3: Domain + subdomains (@*.example.com)
     → Pattern: @(?:[a-z0-9-]+\.)*example\.com$
     → Show: Will match any@sub.example.com
     → Option: Add exceptions (denylist)

   Type 4: Any subdomain match
     → Pattern: @(?:[a-z0-9-]+\.)*(?:[a-z0-9-]+\.)*example\.com$
     → Show: Will match across many variations
     → Option: Add exceptions (denylist)

   Confirm and Save
     → Add to SafeSender table
     → Set date_added = now()
   ```

   **Exception Denylist** (for Types 2-3):
   - "Allow domain except these addresses"
   - Add pattern that overrides safe sender match
   - Example: Safe @company.com, except spammer@company.com
   - Stored as JSON in exceptions field
   - Evaluated AFTER safe sender match (per Sprint 3 SafeSenderEvaluator)

2. **Add Auto-Delete Rule from Scan Result**

   Rule Creation Dialog:
   ```
   Select Rule Type (Condition Bucket)
     ↓
   From Header:
     → Use normalized from_email
     → Pre-fill: sender@example.com
     → Show: Type 1, 2, 3, or 4 pattern
     → Action: Delete or Move

   Header Text:
     → Free-form header match
     → Pre-fill: extracted header content
     → Action: Delete or Move

   Subject:
     → Pre-fill: email subject (normalized)
     → Apply normalization (lowercase, remove special chars)
     → Action: Delete or Move

   Body:
     → Pre-fill: matched keyword or URL
     → Show examples: "phone number", "domain name"
     → Action: Delete or Move

   Body URL Domain:
     → Extract domains from links
     → Show: list of domains found in email
     → Select one or more to block
     → Action: Delete or Move

   Confirm and Save
     → Add to Rule table
     → Set date_added = now()
     → Set enabled = true
   ```

3. **Email Details Screen** (enhanced from Sprint 4)

   **Quick-Add Buttons**:
   - "Add to Safe Senders" → Dialog flow
   - "Add Auto-Delete From" → From Header pattern
   - "Add Auto-Delete Subject" → Subject pattern
   - "Add Auto-Delete Body" → Body pattern
   - "Block URL Domain" → Extract and suggest domains

   **Text Selection Helper**:
   - Long-press on text to select
   - Context menu: "Add this as Body pattern"
   - URL detection: "Block this domain"

**Pattern Type Detection**:

Auto-detect when user enters pattern:
```
Input: john.doe@example.com
  → Type 1 (exact email)
  → Pattern: ^john\.doe@example\.com$

Input: @example.com
  → Type 2 (domain only)
  → Pattern: @example\.com$

Input: @*.example.com (user suggestive notation)
  → Type 3 (domain + subdomains)
  → Pattern: @(?:[a-z0-9-]+\.)*example\.com$
```

**Normalization Requirements**:

- **From Header**:
  - Lowercase
  - Remove special characters, keep [0-9a-z_-]
  - Examples: `John.Doe@Example.COM` → `johndoe@example.com`

- **Subject/Body**:
  - Lowercase
  - Preserve: [0-9a-z], underscore, hyphen, period, brackets, URL special chars
  - Allow user-specified fuzzy matching:
    - Exact match (normal regex)
    - Spaces removed (try again without spaces)
    - Common letter replacements (l→1, e→3, o→0, i→1, etc.)
  - Examples: `Really Bad Word!` → `reallybadword` (can match "rea!lly bad word" or "really b@d word")

**Tasks**:
- **Task A**: Safe sender quick-add UI + exception denylist management
- **Task B**: Auto-delete rule quick-add UI + pattern type detection
- **Task C**: Text selection helper + URL domain extraction
- **Task D**: Pattern normalization + fuzzy matching support

**Database Updates**:
- Add `date_added` field to Rule and SafeSender
- Add `exceptions` JSON field to SafeSender (for denylist)
- Update rule evaluation to check exceptions AFTER safe sender match

**Acceptance Criteria**:
- ✅ Can add safe sender types 1-4 from scan result
- ✅ Can add exceptions to safe sender types 2-3
- ✅ Can add auto-delete rules from scan result (all condition buckets)
- ✅ Pattern type auto-detected correctly
- ✅ Normalization removes special characters correctly
- ✅ Fuzzy matching works (exact, spaces removed, letter replacements)
- ✅ New rules show in rule list
- ✅ Date added tracked for all rules
- ✅ Exceptions evaluated correctly (denylist overrides safe sender)

**Testing**:
- Add safe sender type 1 (exact email)
- Add safe sender type 3 (domain + subdomains) with exception
- Add auto-delete from header rule
- Add auto-delete subject rule
- Add auto-delete body URL domain rule
- Verify fuzzy matching: "rea!lly bad word" matches "reallybadword" rule
- Verify exception: Safe sender match overridden by exception

**Next Sprint Dependency**: Sprint 7 implements background scanning using these rules

---

### SPRINT 7: Background Scanning Implementation - Android (WorkManager)
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (implementation)
**Platform**: Android

**Objective**: Automatic periodic background scanning on Android with user-configured frequency

**Per Original Requirements**:
- Background scans run every <n> minutes (user configured: 15/30/60 min, daily, or disabled)
- Scans check all user-enabled provider/email addresses
- Only flags unmatched emails, does NOT process rules/delete/move
- Uses account-specific settings (background_scan_enabled, scan_frequency)
- Uses app-level scan mode defaults (read-only + what to process)
- Separate unmatched list from manual scans (per Sprint 4)

**Architecture** (Android WorkManager):

```
Background Scan Flow:
1. User configures frequency in Settings (Sprint 5)
   - BackgroundScanManager schedules PeriodicWorkRequest
   - Frequency: 15min / 30min / 1hr / daily

2. WorkManager triggers at configured interval:
   - System decides exact timing (may batch with other work)
   - Worker runs even if app not in foreground

3. BackgroundScanWorker executes:
   - Load account settings (which accounts enabled for background)
   - Load app settings (scan mode: read-only, what to process)
   - For each enabled account:
     - Create EmailScanner (uses same logic as manual)
     - Fetch emails from selected folders
     - Evaluate against rules
     - Track unmatched emails
   - Save ScanResult to database (replaces previous background result)
   - Save UnmatchedEmail list (per Sprint 4 schema)

4. Post-Scan:
   - Check if unmatched count > 0
   - If yes: Send notification with summary
   - User can tap to review in "Process Results" UI

5. Error Handling:
   - Auth failures: Log, exponential backoff, retry next interval
   - Network failures: Log, exponential backoff, retry next interval
   - Max retries: 3, then skip this interval
```

**Database Schema** (Updated from Sprint 5):

```
AccountSettings:  # Already in Sprint 5
  - background_scan_enabled (boolean)
  - background_scan_frequency_minutes (number)
  - selected_folders (JSON array)

BackgroundScanLog:  # NEW for tracking
  - id (PK)
  - account_id (FK)
  - scheduled_time (timestamp)
  - actual_start_time (timestamp)
  - actual_end_time (timestamp)
  - status (success/failed/retry)
  - error_message (text, nullable)
  - emails_processed (count)
  - unmatched_count (count)
```

**Components**:

1. **BackgroundScanWorker** (extends Worker)
   ```dart
   class BackgroundScanWorker extends Worker {
     @override
     Future<Result> perform() async {
       // 1. Load enabled accounts
       // 2. For each account:
       //    - Check if background scans enabled
       //    - Load selected folders
       //    - Create EmailScanner
       //    - Execute scan (same as manual)
       //    - Save results
       // 3. Log execution
       // 4. Send notification if unmatched > 0
       return Result.success();  // WorkManager will reschedule
     }
   }
   ```

2. **BackgroundScanManager**
   - `scheduleBackgroundScans()` - called from Settings when user enables/changes frequency
   - `cancelBackgroundScans()` - called when user disables
   - `getScheduleStatus()` - show current status to user
   - `getNextScheduledTime()` - show when next scan will run

3. **BackgroundScanNotificationService**
   - Create notification channel (unique ID)
   - Build notification: "Background scan complete: X unmatched emails"
   - Tap action: Navigate to "Process Results" screen
   - Show only if unmatched_count > 0 (don't spam for clean scans)

4. **Battery & Network Optimization**
   - Check `BatteryManager.getBatteryLevel()`
   - Skip scan if battery < 20% (configurable in settings)
   - Check network connectivity (`connectivity_plus` package)
   - Skip if WiFi-only mode enabled and on cellular
   - Respect device doze mode (WorkManager handles this)

5. **Frequency Scheduler**
   - 15 minutes: PeriodicWorkRequest(duration: 15 min)
   - 30 minutes: PeriodicWorkRequest(duration: 30 min)
   - 1 hour: PeriodicWorkRequest(duration: 60 min)
   - Daily: PeriodicWorkRequest(duration: 1 day)
   - Disabled: Cancel existing PeriodicWorkRequest

**Key Implementation Details**:

**Scan Result Storage** (per Sprint 4):
- Each background scan replaces previous background ScanResult
- Maintains separate UnmatchedEmail list from manual scans
- One list of unmatched emails per scan type

**Unmatched Email Flagging** (NOT Processing):
- Run rules evaluation on all emails
- Emails NOT matching any rule → add to UnmatchedEmail table
- Do NOT execute delete/move actions (read-only by default)
- Track for user review later

**Account Filter**:
- Only scan accounts where `background_scan_enabled = true`
- Use `selected_folders` from AccountSettings
- If no folders selected, scan INBOX + provider junk folder (AOL: Bulk, Gmail: SPAM)

**Scan Mode** (from Sprint 5 defaults):
- Read-Only: Always (never delete/move in background)
- Process Safe Senders: Check box from settings
- Process Rules: Check box + which rule types to check
  - But don't EXECUTE, only EVALUATE
  - Track "would delete" "would move" for display later

**Tasks**:
- **Task A**: BackgroundScanWorker + WorkManager integration
- **Task B**: BackgroundScanManager + frequency scheduling
- **Task C**: Notifications + battery/network optimization

**Acceptance Criteria**:
- ✅ Background scans run at configured interval
- ✅ Scans check all enabled accounts
- ✅ Use selected folders + account settings
- ✅ Skip if battery low or network unavailable (when configured)
- ✅ Notification sent when unmatched emails found
- ✅ Results appear in "Process Results" UI
- ✅ Unmatched list separate from manual scans
- ✅ Can enable/disable + change frequency
- ✅ Logs tracked for debugging

**Testing**:
- Enable background scans every 15 minutes
- Wait (or use WorkManager test API to trigger)
- Verify scan runs in background
- Verify notification appears (if unmatched found)
- Disable low-battery threshold, verify scans run
- Enable WiFi-only, verify skips on cellular
- Review results in "Process Results" UI

**Dependencies**:
- `workmanager` (background scheduling)
- `flutter_local_notifications` (notifications)
- `connectivity_plus` (network detection)
- `battery_plus` (battery level)
- Sprint 4: ScanResult/UnmatchedEmail storage
- Sprint 5: Settings (frequency, enabled accounts)

**Next Sprint Dependency**: Sprint 8 implements Windows background scanning

---

### SPRINT 8: Background Scanning - Windows Desktop & MSIX Installer
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (implementation)
**Platforms**: Windows Desktop

**Objective**: Background scanning on Windows desktop + MSIX installer for app distribution

**Part A: Background Scanning - Windows Desktop**

**Architecture** (Windows Task Scheduler):
```
Windows Background Scan Flow:
1. App creates scheduled task (PowerShell script)
2. Task Scheduler manages execution:
   - Trigger: Configured interval (15min, 30min, 1hr, daily)
   - Action: Launch app with special flag
   - Conditions: Only when user logged in
3. App detects background mode:
   - Execute scan silently (no UI)
   - Save results to database
4. Toast notification:
   - Show results summary
   - Tap opens app to results
5. Error handling:
   - Failed scans logged
   - Retry on next scheduled interval
```

**Components**:
1. **WindowsTaskScheduler integration**
   - Create scheduled task via PowerShell
   - Read current task settings
   - Update/delete tasks
   - Task status monitoring

2. **Background Mode Detection**
   - Launch flag: `--background-scan`
   - Minimal UI in background mode
   - Silent operation (no progress screen)
   - Database logging only

3. **Toast Notifications** (Windows 10+)
   - Use windows_notification package
   - Toast with action buttons
   - System tray indicator
   - Tap opens results

4. **MSIX Installer**
   - Build MSIX package
   - Code signing configuration
   - Microsoft Store preparation
   - Auto-update capability

**Part B: MSIX Installer & Desktop Distribution**

**MSIX Configuration**:
- Package identity: com.spamfiltermulti
- Version: Sync with app version
- Publisher: User's organization/name
- Capabilities: Internet, file system access
- Auto-updates: Windows App Installer support

**Build Process**:
1. Generate MSIX manifest
2. Build Flutter Windows release
3. Package into MSIX container
4. Code sign with developer certificate
5. Test installation on Windows 10/11

**Installer Features**:
- Automatic installation to user's Program Files
- Start menu shortcut
- Add/Remove Programs support
- Auto-update capability
- Uninstall support

**Part C: Desktop-Specific UI Adjustments**

**Windows Desktop UI**:
- Larger UI for desktop (vs mobile)
- Window resize support
- Multi-window support (results in separate window)
- Keyboard navigation (Tab, Enter, ESC)
- Right-click context menus
- Drag & drop rule ordering

**Tasks**:
- **Task A**: Windows Task Scheduler integration (PowerShell scripts, task management)
- **Task B**: Toast notifications + background mode detection
- **Task C**: MSIX configuration + installer build

**Acceptance Criteria**:
- ✅ Background scan runs at configured interval (Windows)
- ✅ Can enable/disable auto-scan from settings
- ✅ Toast notification shows scan results
- ✅ MSIX installer builds successfully
- ✅ App installs/uninstalls via MSIX
- ✅ Auto-updates work
- ✅ Desktop UI layout responsive

**Testing**:
- Create scheduled task manually, verify execution
- Enable auto-scan, wait for task to run
- Verify notification appears
- Check scan history for results
- Test MSIX installation on Windows 10 & 11
- Verify uninstall removes all files

**Dependencies**:
- `windows_notification` (toast notifications)
- Flutter Windows platform channel for PowerShell
- MSIX tooling

**Known Limitations**:
- Task Scheduler requires local admin for system-wide tasks
- Background scan only while user logged in
- Toast notifications require Windows 10+

**Note on iOS**:
- Background scanning for iOS deferred to Phase 4 (Sprint beyond 3.5)
- iOS has significant background execution restrictions
- Plan: Use APNs (Apple Push Notification service) for trigger

**Next Sprint Dependency**: Sprint 9 adds advanced UI/Polish

---

### SPRINT 9: Advanced UI & Polish
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Complete feature parity across platforms + UI/UX polish

**Per Original Plan**:
- Android specific enhancements
- Windows Desktop specific enhancements
- UI/UX polish for production

**Part A: Scan Results Persistence & History**

**Database Schema** (new):
```
ScanResult:
  - id (PK)
  - account_id (FK)
  - scan_date (timestamp)
  - platform (Android/Windows/iOS)
  - folder_name
  - total_emails (count)
  - total_matched (count)
  - total_no_rule (count)
  - total_deleted_proposed (count)
  - total_moved_proposed (count)

ScanResultDetail:
  - id (PK)
  - scan_result_id (FK)
  - email_id
  - from_email
  - subject
  - folder
  - matched_rule_id (FK, nullable)
  - action_type (delete/move/safe/none)
  - executed (boolean)
```

**Screens**:

1. **Scan History Screen**
   - List all completed scans
   - Date, account, folder, summary stats
   - Filter by date range / account
   - Sort by date (newest first)
   - Tap to view scan details

2. **Scan Details Screen**
   - Scan summary (date, account, stats)
   - Email list from scan
   - Show: folder • from • subject • rule • action
   - Export scan to CSV
   - Delete scan history

3. **Statistics Dashboard**
   - Total emails scanned (all time)
   - Top spam senders
   - Most-used rules
   - Rule effectiveness
   - Trends (emails/day, spam rate)

**Part B: Platform-Specific Enhancements**

**Android Enhancements**:
- Material Design 3 implementation
- Swipe actions on email list (delete/move)
- Floating action button for quick actions
- Bottom navigation for main screens
- App shortcuts (add rule, scan, settings)

**Windows Desktop Enhancements**:
- Maximize/minimize/close window controls
- Multi-window support (detach results)
- Keyboard shortcuts (Ctrl+S scan, Ctrl+N new rule, etc.)
- Context menus (right-click options)
- Resizable columns in lists
- Status bar with sync status

**Part C: UI/UX Polish & Accessibility**

**Polish Items**:
- Dark mode support (all platforms)
- High contrast theme
- Keyboard navigation (Tab, Arrow keys, Enter)
- Screen reader support (accessibility labels)
- Responsive layouts (handle window resize)
- Loading indicators and progress
- Error messages with solutions
- Empty state UI (no results message)

**Consistency Across Platforms**:
- Same color palette
- Same typography
- Same spacing/padding
- Consistent button sizes
- Consistent icon usage

**Tasks**:
- **Task A**: Scan history + results persistence (database, UI)
- **Task B**: Platform-specific enhancements (Android + Windows)
- **Task C**: UI/UX polish + accessibility features

**Acceptance Criteria**:
- ✅ Scan history displays correctly
- ✅ Can filter/search scan history
- ✅ Statistics dashboard accurate
- ✅ Dark mode works on all platforms
- ✅ Keyboard navigation functional
- ✅ Screen reader compatibility
- ✅ Window resize handled
- ✅ Consistent UI across platforms
- ✅ Empty state messages helpful

**Testing**:
- Run 5 scans, verify history shows all
- Filter history by date range
- Export scan to CSV, verify format
- Test dark mode on all screens
- Test keyboard navigation (Tab through UI)
- Test window resize on Windows
- Verify accessibility on Android

**Next Sprint Dependency**: Sprint 10 adds database cleanup/optimization

---

### SPRINT 10: Production Readiness & Testing (Final Sprint)
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (optimization) + Haiku (testing)

**Objective**: Phase 3.5 completion - production-ready release with comprehensive testing and optimization

**Part A: Database Management**

**Cleanup Service**:
- Auto-archive scans older than configured retention
- Manual cleanup UI (Archive/Delete buttons)
- Database vacuum (defragment)
- Index analysis and optimization
- Cleanup scheduler (runs weekly)

**Backup/Restore**:
- Export all data to JSON (portable format)
- Import from JSON with merge/replace options
- Export rules to YAML (already implemented)
- Import from YAML with validation
- Backup scheduling (automatic daily backups)
- Restore point recovery

**Performance Optimization**:
- Database index analysis (add missing indices)
- Query optimization (profile slow queries)
- Cache frequently-accessed data (rules, settings)
- Regex compilation optimization
- Memory profiling (peak usage analysis)
- Batch operations optimization

**Part B: Comprehensive Testing**

**Unit Tests**:
- All business logic (RuleSet, Evaluator, Settings)
- Database operations (CRUD, migration, cleanup)
- Pattern matching (regex compilation, caching)
- Notification scheduling (background tasks)
- Total: 200+ tests

**Integration Tests**:
- Full scan workflow (account setup → scan → results)
- Rule creation from trainer
- Safe sender management end-to-end
- Background scan execution
- Settings persistence and application
- Multi-account switching
- Total: 50+ integration tests

**Platform Tests**:
- Android emulator (multiple API versions)
- Windows desktop (both 32 and 64-bit)
- iOS simulator (if applicable, limited)
- Real device testing (at least 1 real Android, 1 real Windows)

**Stress Tests**:
- 1000 rules loaded and evaluated
- 10000 emails scanned in sequence
- Large email bodies (1MB+)
- Rapid scan requests (queue management)
- Low memory conditions
- Network failures and recovery

**User Acceptance Tests**:
- Real email accounts (AOL, Gmail)
- Existing user rules (from desktop app)
- All UI workflows (setup, scan, results, settings)
- Background scanning scenarios
- Error recovery (auth failures, network issues)
- Multi-user testing

**Part C: Documentation & Code Quality**

**User Documentation**:
- Quick start guide (setup + first scan)
- Full feature documentation
- Troubleshooting guide (common issues)
- FAQ (frequently asked questions)
- Video tutorials (if applicable)
- Rule creation guide with examples

**Developer Documentation**:
- API reference (all public classes)
- Architecture overview
- Extension guide (new email provider)
- Database schema reference
- Build/deployment instructions
- Contributing guidelines

**Code Quality**:
- Remove dead code and unused imports
- Resolve all code analysis warnings
- Update deprecated API usage
- Add missing docstrings
- Refactor duplicated logic
- Final lint pass (zero errors)

**Part D: Release Preparation**

**Build Artifacts**:
- Android APK (debug + release)
- Windows executable + MSIX installer
- Signing certificates configured
- Version numbers aligned

**Release Notes**:
- Feature summary
- Bug fixes from Sprints 1-10
- Known limitations
- System requirements
- Installation instructions
- Upgrade path from previous versions

**App Store Preparation** (Google Play, Windows Store):
- Screenshots (showing key features)
- Promotional graphics
- App description and keywords
- Privacy policy
- Terms of service
- Support contact information

**Tasks**:
- **Task A**: Database management (cleanup, backup/restore, optimization)
- **Task B**: Comprehensive testing (unit, integration, platform, stress, UAT)
- **Task C**: Documentation (user, developer, release notes)
- **Task D**: Code quality and release preparation

**Acceptance Criteria**:
- ✅ 200+ unit tests passing (90%+ coverage)
- ✅ 50+ integration tests passing
- ✅ Zero code analysis errors
- ✅ All platform tests pass
- ✅ Stress tests handle 1000+ rules
- ✅ Backup/restore works correctly
- ✅ User documentation complete
- ✅ Release builds successful
- ✅ APK and MSIX ready for distribution

**Testing Checklist**:
- [ ] Run `flutter test` - all 200+ tests pass
- [ ] Run `flutter analyze` - zero errors
- [ ] Build Android APK - no errors
- [ ] Build Windows executable - no errors
- [ ] Test on real Android device
- [ ] Test on real Windows machine
- [ ] Manual UAT on both platforms
- [ ] Stress test with 1000 rules
- [ ] Backup/restore workflow
- [ ] Background scanning (Android + Windows)
- [ ] Settings persistence
- [ ] Multi-account switching

**Metrics for Success**:
- ✅ Test coverage: >90%
- ✅ Code analysis: 0 errors
- ✅ Performance: Scan 1000 emails < 30 seconds
- ✅ Memory: Peak usage < 200MB
- ✅ Battery: Background scan < 5% impact
- ✅ Release: Ready for app store distribution

---

## Cross-Sprint Dependencies

### Sprint Dependency Graph

```
Sprint 1: Database Foundation
    ↓
Sprint 2: Rule Database Storage
    ↓
Sprint 3: Safe Sender Exceptions
    ↓ (parallel paths)
    ├─→ Sprint 4: Scan Persistence
    │      ↓
    │   Sprint 5: Unmatched Processing
    │
    └─→ Sprint 6: Settings Infrastructure
           ├─→ Sprint 7: Android Background Scanning
           │      ↓
           │   Sprint 8: iOS/Windows Background Scanning
           │
           └─→ Sprint 9: Rule Builder UI
                  ↓
               Sprint 10: Polish & Testing
```

### Critical Path
- Sprint 1 → Sprint 2 → Sprint 3 (database foundation, sequential)
- Sprint 3 → Sprint 4 (scan persistence depends on evaluator)
- Sprint 4 → Sprint 5 (unmatched processing depends on results)
- Sprint 6 → Sprint 7 → Sprint 8 (settings enable background scanning)
- Sprint 9 depends on Sprints 3 & 6 (rules + settings)
- Sprint 10 depends on all previous (comprehensive testing)

### Parallel Execution Opportunities
- **Sprints 4-5 can run slightly parallel** with 6-9 (different teams)
- **Sprints 7-8 can run in parallel** (different platforms)

---

## Resource Allocation

### Model Assignment by Sprint

| Sprint | Haiku | Sonnet | Total | Duration |
|--------|-------|--------|-------|----------|
| 1 | 2 | 1 | 3 | ~4h |
| 2 | 2 | 1 | 3 | ~7h |
| 3 | 2 | 1 | 3 | ~8h |
| 4 | 2 | 1 | 3 | ~11h |
| 5 | 2 | 1 | 3 | ~9h |
| 6 | 2 | 1 | 3 | ~11h |
| 7 | 2 | 1 | 3 | ~13h |
| 8 | 2 | 1 | 3 | ~13h |
| 9 | 2 | 1 | 3 | ~11h |
| 10 | 3 | 1 | 4 | ~14h |
| **TOTAL** | **21** | **10** | **31** | **~101h** |

### Time Estimates

**Actual vs Estimated**:
- Sprint 1: 4h actual vs 9-13h estimated (2.3x faster)
- Sprint 2: 6.8h actual vs 12-17h estimated (1.8x faster)
- Sprint 3: 8h actual vs 10-14h estimated (1.3x faster)
- Average: 1.8x faster than estimated

**Projection for Sprints 4-10**:
- Using 1.5x speedup factor: ~67h actual vs ~101h estimated
- Full Phase 3.5: ~82h actual (vs ~115h estimated)

---

## Risk Management

### Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Background scanning platform-specific issues | Medium | High | Early prototyping (Sprint 7-8 early) |
| Database performance with 10k+ scans | Low | High | Index design, query optimization |
| OAuth token refresh failures | Low | High | Token refresh fallback mechanism |
| Regex compilation performance with 1000+ rules | Low | Medium | Caching, incremental compilation |
| UI responsiveness during large scans | Medium | Medium | Throttling updates, background workers |
| Test flakiness in integration tests | Medium | Medium | Mock external services, stable test data |

### Contingency Plans

1. **Background scanning fails**: Fallback to manual trigger UI (still have core feature)
2. **Performance issues**: Implement progressive loading, background optimization
3. **Platform incompatibilities**: Focus on core platforms (Android/Windows), defer iOS
4. **Database scalability**: Implement archive/cleanup (Sprint 10), query optimization

---

## Success Criteria

### Phase 3.5 Completion Checklist

**Functional**:
- ✅ Safe sender exceptions fully functional
- ✅ Scan results persistent and queryable
- ✅ Background scanning on all platforms
- ✅ Rule builder UI complete
- ✅ Settings UI complete
- ✅ Unmatched email processing

**Quality**:
- ✅ 90%+ test coverage
- ✅ Zero code analysis errors
- ✅ All tests passing
- ✅ Zero regressions from Phase 3.0

**Performance**:
- ✅ Scan with 1000+ rules under 30 seconds
- ✅ Database queries under 100ms
- ✅ Background scan battery impact <5%
- ✅ App memory usage <150MB

**Documentation**:
- ✅ User guide for all features
- ✅ Developer guide for extensions
- ✅ API documentation
- ✅ Troubleshooting guide

**Operational**:
- ✅ Database backup/restore works
- ✅ Cleanup removes old data safely
- ✅ Performance baselines established
- ✅ Monitoring/logging in place

---

## Document Management

**This Document**:
- **Path**: `docs/ALL_SPRINTS_MASTER_PLAN.md`
- **Purpose**: Central reference for all 10 sprints
- **Update Frequency**: After each sprint completes (outcomes, lessons learned)
- **Audience**: Claude Code agents, developers, user

**Related Documents**:
- `docs/SPRINT_EXECUTION_WORKFLOW.md` - How to execute each sprint
- `docs/SPRINT_[N]_PLAN.md` - Detailed plan for each sprint
- `docs/SPRINT_[N]_RETROSPECTIVE.md` - Outcomes for completed sprints
- `docs/SPRINT_INDEX.md` - Index of all sprint documents

**Revision History**:
- v1.0 (Jan 25, 2026): Initial comprehensive 10-sprint plan

---

## Quick Reference

**Finding This Document**:
- Full Path: `D:\Data\Harold\github\spamfilter-multi\docs\ALL_SPRINTS_MASTER_PLAN.md`
- In Repository: `docs/ALL_SPRINTS_MASTER_PLAN.md`
- GitHub URL: `https://github.com/kimmeyh/spamfilter-multi/blob/develop/docs/ALL_SPRINTS_MASTER_PLAN.md`

**For Future Sprints**:
1. Reference Sprint X section above
2. Create detailed `docs/SPRINT_X_PLAN.md`
3. Create GitHub sprint cards (#N)
4. Execute following `docs/SPRINT_EXECUTION_WORKFLOW.md`
5. Update `docs/SPRINT_X_RETROSPECTIVE.md` with outcomes

---

**Document Complete**: All 10 sprints planned with detailed specifications, dependencies, and success criteria. Ready for execution.
