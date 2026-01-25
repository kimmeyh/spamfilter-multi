# Phase 3.5 Master Sprint Plan - Complete 10-Sprint Breakdown

**Status**: Master planning document for all 10 sprints of Phase 3.5
**Created**: January 25, 2026
**Last Updated**: January 25, 2026
**Total Effort**: ~60-80 hours across 10 sprints
**Target Completion**: Q1-Q2 2026

**Source & Credit**:
- Original Phase 3.5 description: User-provided
- Sprint 1-3 execution details: Completed and documented
- Sprint 4-10 recreation: Based on original Phase 3.5 plan + what remains to be done
- Planning & coordination: User oversight

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

### Primary Goals
1. **Complete Safe Sender Exception System** - Whitelist with granular exceptions
2. **Persistent Scan Results** - Archive and query historical scans
3. **User-Facing Management** - UI for rules, safe senders, unmatched emails
4. **Background Scanning** - Automatic periodic scans on all platforms
5. **Production Readiness** - Comprehensive testing, cleanup, documentation

### Business Value
- Users can define complex whitelists (domain + exceptions)
- Automatic scanning reduces manual effort
- Persistent results enable compliance auditing
- Settings UI provides complete app customization
- Database cleanup prevents performance degradation

### Technical Objectives
- Complete database-first architecture
- Clean provider-agnostic abstraction layer
- Production-grade error handling and logging
- Comprehensive test coverage (>90%)
- Performance baselines established

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

### SPRINT 4: Interactive Inbox Trainer (Unmatched Emails Processing)
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI + backend)

**Objective**: Help users create rules from unmatched emails via interactive UI (similar to Python CLI trainer)

**Feature Overview**:
Per original Phase 3.5 plan: "Process all 'No rule' messages via Interactive Inbox Trainer"
- Build UI for unmatched emails (similar to Python CLI prompts)
- Keyboard equivalents for each user action
- Quick-add rule creation from email data
- Immediate re-evaluation of inbox after rule addition

**Database Schema** (New):
```
UnmatchedEmail:
  - id (PK)
  - account_id (FK)
  - email_id
  - from_email
  - subject
  - received_date
  - status (new/rule_added/ignored)
  - rule_created_from (rule_id FK, nullable)

RuleCreationHistory:
  - id (PK)
  - unmatched_email_id (FK)
  - created_rule_id (FK)
  - creation_method (trainer/manual/quick_add)
  - created_at (timestamp)
```

**UI Screens**:

1. **Unmatched Emails List** (trainer selection screen)
   - Shows all unmatched emails from last scan
   - Display: folder • from_email • subject
   - Sort by date (newest first)
   - Badge showing count
   - Bottom action bar: (D)omain rule, (E)mail rule, (S)afe sender, (SD)omain safe, (I)gnore

2. **Domain Rule Creator**
   - Pre-fill: domain extracted from "from" email
   - Generate: SpamAutoDeleteHeader rule (or user-selected pattern)
   - Confirm: Add to rules, re-evaluate inbox
   - Show: Matching results count

3. **Email Rule Creator**
   - Pre-fill: exact email from sender
   - Create: Safe sender for this exact email
   - Confirm: Add to safe senders, re-evaluate inbox

4. **Safe Sender Manager** (from trainer)
   - Add email/domain/subdomain to safe senders
   - Manage exceptions for domains
   - Quick-add without full manager UI

**Keyboard Shortcuts** (as per original plan):
- `d` - Add domain block rule (SpamAutoDeleteHeader)
- `e` - Add exact email to safe senders
- `s` - Add email to safe senders
- `sd` - Add sender domain to safe senders
- `i` - Ignore this email (mark as processed)
- `ESC` - Return to inbox

**Tasks**:
- **Task A**: UnmatchedEmailStore (database CRUD + tracking)
- **Task B**: Interactive trainer UI screens (list, rule creators)
- **Task C**: Keyboard shortcuts + immediate re-evaluation

**Architecture**:
- After each rule creation: Re-run evaluator on saved unmatched emails
- Track which emails had rules created from them
- Update UI to show results of rule application

**Acceptance Criteria**:
- ✅ Unmatched emails display correctly
- ✅ Can create rule with (d/e/s/sd) keyboard shortcuts
- ✅ Rules apply immediately (inbox re-evaluated)
- ✅ UI shows matching results count
- ✅ Processed emails removed from trainer list
- ✅ Keyboard shortcuts work as documented

**Testing**:
- Create 10 unmatched emails via scan
- Use trainer to create rules for 5 of them
- Verify remaining 5 still show
- Verify results show in inbox

**Next Sprint Dependency**: Sprint 5 uses rule editor (advanced rule management)

---

### SPRINT 5: Rule Editor UI
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Advanced UI for viewing, creating, and managing spam filtering rules

**Per Original Plan**:
- View all rules organized by type
- Add/remove individual patterns
- Search/filter rules
- Import/export YAML files
- Validate regex patterns before saving

**Screens**:

1. **Rule List Screen**
   - Display all rules with status
   - Search/filter by rule name
   - Sort by execution order
   - Enable/disable toggle
   - Delete with confirmation
   - Bulk operations (enable/disable all, delete selected)

2. **Rule Editor Screen**
   - Create new rule or edit existing
   - Rule name (text field)
   - Conditions: Header, Subject, Body, From
   - Actions: Delete, Move (with folder selector), None
   - Execution order (numeric)
   - Add/remove individual patterns
   - Pattern validation with error messages
   - Regex preview widget (show matching examples)

3. **Pattern Validator Widget**
   - Live regex validation as user types
   - Highlight syntax errors
   - Show matching examples from inbox (if available)
   - Complexity analysis (warn about slow patterns)
   - Suggest common patterns (email, domain, etc.)

4. **Import/Export UI**
   - Import YAML rules: File picker → parse → preview → confirm
   - Export rules: Format selection → download
   - Merge vs. replace on import
   - Backup before import

**Database Schema** (extends existing):
```
RuleValidation:
  - id (PK)
  - rule_id (FK)
  - pattern
  - validation_status (valid/invalid/slow)
  - error_message (nullable)
  - last_validated (timestamp)
  - complexity_score (0-100)
```

**Tasks**:
- **Task A**: Rule list screen + database queries
- **Task B**: Rule editor screen + pattern validation
- **Task C**: Import/export functionality

**Key Features**:
- Real-time pattern validation (visual feedback)
- Prevent invalid patterns from saving
- Suggest common regex patterns
- Show pattern examples from inbox
- Clear error messages

**Acceptance Criteria**:
- ✅ Can view all rules
- ✅ Can create/edit/delete rules
- ✅ Regex validation prevents invalid patterns
- ✅ Pattern editor shows examples
- ✅ Import/export YAML works correctly
- ✅ Bulk operations work
- ✅ Execution order preserved

**Next Sprint Dependency**: Sprint 6 adds app-wide settings integration

---

### SPRINT 6: Safe Sender Manager & Advanced Filtering
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Complete safe sender management and advanced filtering options

**Per Original Plan**:
- Safe Sender Manager: View safe sender list, add/remove, test patterns, bulk import
- Advanced Filtering: Second-pass processing, rule priority, custom folder targets, sender exceptions

**Screens**:

1. **Safe Sender Manager Screen**
   - List all safe senders (email, domain, subdomain patterns)
   - Search/filter by pattern
   - Sort by type or date added
   - Show matching count (emails that would match)
   - Delete with confirmation
   - Bulk operations (delete multiple)

2. **Add Safe Sender Dialog**
   - Pattern type selector (email/domain/subdomain)
   - Pattern input field
   - Auto-detection: Suggest type based on input
   - Regex validation
   - Preview: Show what emails would match
   - Save button

3. **Exception Management** (from Sprint 3 SafeSenderDatabaseStore)
   - Add exceptions to domain safe senders
   - Example: "Allow @company.com except spammer@company.com"
   - Visual editor for exceptions
   - Test exceptions against emails

4. **Rule Priority Screen**
   - Drag-to-reorder rule execution
   - Show execution order
   - Explain rule evaluation order
   - Quick enable/disable rules
   - Visual feedback on changes

5. **Advanced Filtering Options**
   - Second-pass processing toggle
   - Custom folder targets for move actions
   - Sender-specific rule exceptions
   - Whitelist specific senders for specific rules

**Features**:
- Pattern testing: Show which emails would match
- Bulk import from contacts (platform-specific)
- Regex validation for patterns
- Exception precedence (override safe sender rules)
- Rule priority visualization

**Database Schema** (extends existing):
```
RuleExecution:
  - id (PK)
  - rule_id (FK)
  - execution_order (numeric)
  - enabled (boolean)
  - updated_at (timestamp)

SenderException:
  - id (PK)
  - rule_id (FK)
  - pattern (sender email/domain)
  - exception_type (exclude_from_rule)
  - created_at (timestamp)
```

**Tasks**:
- **Task A**: Safe sender manager UI + bulk import
- **Task B**: Rule priority screen + execution ordering
- **Task C**: Advanced filtering (second-pass, custom targets, exceptions)

**Acceptance Criteria**:
- ✅ Safe sender CRUD operations work
- ✅ Pattern testing shows matching emails
- ✅ Rule priority can be reordered
- ✅ Sender exceptions override rules
- ✅ Custom folder targets work
- ✅ Second-pass processing re-evaluates emails

**Testing**:
- Add 5 safe sender patterns (emails, domains, subdomains)
- Test exceptions on domain patterns
- Reorder rules and verify evaluation order
- Add sender exception and verify rule bypass

**Next Sprint Dependency**: Sprints 7-10 use settings + safe senders

---

### SPRINT 7: Background Scanning & Settings Infrastructure
**Status**: 📋 PLANNED
**Estimated Duration**: 14-16 hours
**Model Assignment**: Sonnet (architecture) + Haiku (implementation)
**Platforms**: Android + Windows (iOS deferred to Phase 4+)

**Objective**: Implement automatic background scanning with configurable frequency and settings

**Per Original Plan**:
- Process all emails with background sync implementation
- Configurable scan frequency (15min, 30min, 1hr, manual only)
- Battery and network optimization
- Windows MSIX installer preparation

**Sprint 7 Part A: Settings Infrastructure**

**Screens**:

1. **App Settings Screen**
   - Default scan mode: Read-Only / Test / Full Delete
   - UI Theme: Light / Dark / System
   - Logging Level: Debug / Info / Warning
   - Data retention period: 30/60/90/365 days

2. **Auto-Scan Configuration**
   - Enable/disable auto-scan
   - Scan frequency: Disabled / 15min / 30min / 1hr / Daily
   - WiFi-only mode (mobile optimization)
   - Battery threshold: Pause scanning if <N% battery

3. **Per-Account Settings**
   - Auto-scan this account: Yes/No
   - Folders to scan: Multi-select from available folders
   - Default action: Delete / Move / None
   - Rule evaluation order display

**Database Schema**:
```
AppSettings:
  - key (PK)
  - value (JSON)
  - data_type (string/number/boolean)
  - updated_at (timestamp)

AccountSettings:
  - id (PK)
  - account_id (FK)
  - auto_scan_enabled (boolean)
  - scan_frequency (interval)
  - default_action (enum)
  - folders_to_scan (JSON array)
  - updated_at (timestamp)
```

**Sprint 7 Part B: Background Scanning - Android**

**Architecture** (WorkManager):
```
Background Scan Flow (Android):
1. PeriodicWorkRequest scheduled at configured interval
2. ScanWorker triggers:
   - Check battery level (skip if <threshold)
   - Check network connectivity (WiFi-only check if enabled)
   - Load account settings
   - Execute EmailScanner for each account
   - Save results to database
3. NotificationManager:
   - Send notification if spam found
   - Show scan summary (total emails, spam count)
   - Tap opens app to results
4. Backoff strategy:
   - Exponential backoff on network failures
   - Exponential backoff on auth failures
   - Max retries: 3

**Components**:
1. **ScanWorker** (extends Worker)
   - Receives scan frequency from settings
   - Executes EmailScanner same as foreground
   - Handles exceptions gracefully
   - Returns success/retry/failure

2. **BackgroundScanManager**
   - Schedule/reschedule periodic work
   - Cancel background scanning
   - Get current schedule status

3. **NotificationService**
   - Notification channel for scan results
   - Notification content (summary)
   - Tap action → app navigation
   - Notification persistence

4. **Battery & Network Optimization**
   - Check battery level before scan
   - Skip if low battery (<threshold from settings)
   - Respect device doze mode
   - WiFi-only mode support

**Sprint 7 Part C: Windows Desktop Preparation**

- Document MSIX installer requirements
- Plan Windows Task Scheduler integration (for Sprint 8)
- Create Windows build configuration
- Desktop-specific UI layout planning

**Tasks**:
- **Task A**: Settings infrastructure (SettingsProvider, database schema)
- **Task B**: Android background scanning (ScanWorker, WorkManager)
- **Task C**: Notifications + battery optimization

**Acceptance Criteria**:
- ✅ Settings UI works and persists
- ✅ Background scan runs at configured interval (Android)
- ✅ Respects battery and connectivity settings
- ✅ Notification sent when spam found
- ✅ Scans appear in history
- ✅ Can enable/disable auto-scan
- ✅ WiFi-only mode functional

**Testing**:
- Configure auto-scan for 15 minutes
- Suspend app, wait for background execution
- Verify notification appears
- Check scan history for results
- Test battery threshold skips scan
- Test WiFi-only mode

**Dependencies**:
- `workmanager` package (background tasks)
- `flutter_local_notifications` (notifications)

**Next Sprint Dependency**: Sprint 8 extends to Windows/iOS

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
- **Path**: `docs/PHASE_3_5_MASTER_PLAN.md`
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
- Full Path: `D:\Data\Harold\github\spamfilter-multi\docs\PHASE_3_5_MASTER_PLAN.md`
- In Repository: `docs/PHASE_3_5_MASTER_PLAN.md`
- GitHub URL: `https://github.com/kimmeyh/spamfilter-multi/blob/develop/docs/PHASE_3_5_MASTER_PLAN.md`

**For Future Sprints**:
1. Reference Sprint X section above
2. Create detailed `docs/SPRINT_X_PLAN.md`
3. Create GitHub sprint cards (#N)
4. Execute following `docs/SPRINT_EXECUTION_WORKFLOW.md`
5. Update `docs/SPRINT_X_RETROSPECTIVE.md` with outcomes

---

**Document Complete**: All 10 sprints planned with detailed specifications, dependencies, and success criteria. Ready for execution.
