# Phase 3.5 Master Sprint Plan - Complete 10-Sprint Breakdown

**Status**: Master planning document for all 10 sprints of Phase 3.5
**Created**: January 25, 2026
**Last Updated**: January 25, 2026
**Total Effort**: ~60-80 hours across 10 sprints
**Target Completion**: Q1-Q2 2026

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

### SPRINT 4: Scan Results Persistence
**Status**: 📋 PLANNED
**Estimated Duration**: 10-12 hours
**Model Assignment**: Haiku (backend) + Sonnet (architecture)

**Objective**: Store scan results in database for historical analysis

**Architecture**:
```
ScanResult:
  - id (PK)
  - account_id (FK)
  - scan_date (timestamp)
  - folder_name
  - total_emails
  - total_matched
  - total_no_rule

ScanResultDetail:
  - id (PK)
  - scan_result_id (FK)
  - email_id
  - from_email
  - subject
  - matched_rule (nullable)
  - action_type (delete/move/safe/none)
  - executed (boolean)
```

**Tasks**:
- **Task A**: ScanResultDatabaseStore (CRUD for scan results)
- **Task B**: EmailScanner integration (save results after scan)
- **Task C**: Query builder for historical analysis (date range, account, etc.)

**Key Considerations**:
- Database cleanup: Archive old results (>90 days) or delete
- Performance: Index on scan_date and account_id for fast queries
- Concurrency: Handle multiple scans from same account

**Acceptance Criteria**:
- ✅ All scans automatically saved to database
- ✅ Can query results by date range and account
- ✅ Can export scan history to CSV
- ✅ 100+ scan results queries under 100ms

**Next Sprint Dependency**: Sprint 5 references unmatched emails

---

### SPRINT 5: Unmatched Email Processing
**Status**: 📋 PLANNED
**Estimated Duration**: 8-10 hours
**Model Assignment**: Haiku (backend) + Sonnet (UI)

**Objective**: Help users process emails that didn't match any rules

**Features**:
1. **Unmatched Email List Screen**
   - Shows emails with no rule match
   - Sorted by frequency (sender domain)
   - Quick stats (total unmatched, top senders)

2. **Quick Rule Creation**
   - Add domain rule (block all from domain)
   - Add email rule (block this email)
   - Add to safe senders (whitelist)
   - Immediate re-evaluation of unmatched list

3. **Pattern Suggestions**
   - Analyze unmatched emails
   - Suggest domain patterns for blocking
   - Suggest email patterns for whitelisting

**Architecture**:
- Extends ScanResultDetail with rule suggestion logic
- Evaluates "what rules would help" for each unmatched email
- Tracks user rule creation from this screen

**Tasks**:
- **Task A**: UnmatchedEmailAnalyzer (identify patterns)
- **Task B**: QuickRuleCreator (add rules from unmatched screen)
- **Task C**: UI screen for unmatched email management

**Acceptance Criteria**:
- ✅ Unmatched email list displays correctly
- ✅ Can create rule from unmatched email
- ✅ Rule immediately evaluates existing unmatched emails
- ✅ Can add email to safe senders
- ✅ Pattern suggestions accurate

**Next Sprint Dependency**: Sprint 6 adds app-wide settings

---

### SPRINT 6: Settings Infrastructure
**Status**: 📋 PLANNED
**Estimated Duration**: 10-12 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Implement app-wide and per-account settings

**Settings Categories**:

1. **App-Wide Settings**:
   - Default scan mode (read-only / test / full)
   - Auto-scan enabled (yes/no)
   - Scan frequency (daily / weekly / manual)
   - Result retention (30/60/90/365 days)
   - UI theme (light/dark)
   - Logging level (debug/info/warning)

2. **Per-Account Settings**:
   - Auto-scan this account (yes/no)
   - Folders to scan (INBOX, Bulk, etc.)
   - Default action (delete/move/none)
   - Rule execution order
   - Exception handling (strict/lenient)

3. **Database Schema**:
   - app_settings table (key-value store)
   - account_settings table (per account)
   - settings_history table (audit trail)

**Architecture**:
- SettingsProvider (ChangeNotifier)
- SettingsDatabaseStore (CRUD)
- SettingsScreen UI (app + per-account tabs)
- Navigation drawer integration

**Tasks**:
- **Task A**: SettingsDatabaseStore and SettingsProvider
- **Task B**: App settings UI screen
- **Task C**: Per-account settings UI

**Acceptance Criteria**:
- ✅ All settings persisted to database
- ✅ Settings load correctly on app restart
- ✅ UI reflects current settings
- ✅ Changes apply immediately
- ✅ Settings exportable to JSON

**Next Sprint Dependency**: Sprints 7-8 use auto-scan settings

---

### SPRINT 7: Background Scanning - Android (WorkManager)
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (WorkManager) + Haiku (integration)
**Platform**: Android only

**Objective**: Implement periodic background scanning on Android

**Architecture**:
```
WorkManager flow:
1. PeriodicWorkRequest scheduled
2. Worker runs at configured interval (15min/30min/1hr/daily)
3. EmailScanner executes (same as foreground)
4. Results saved to database
5. Notification sent if spam found
6. Battery/connectivity checks
7. Exponential backoff on failures
```

**Components**:
1. **ScanWorker** (extends Worker)
   - Executes scan in background
   - Handles network failures
   - Logs to database

2. **NotificationService**
   - Send notification for spam found
   - Tap opens app to results
   - Notification channel management

3. **Settings Integration**
   - Read auto-scan frequency from settings
   - Respect user preferences

4. **Battery Optimization**
   - Check battery level before scanning
   - Adaptive frequency (slower when low battery)
   - Respect device doze mode

**Tasks**:
- **Task A**: ScanWorker implementation (background scanning)
- **Task B**: WorkManager integration (schedule/reschedule)
- **Task C**: Notification and battery optimization

**Acceptance Criteria**:
- ✅ Background scan runs at configured interval
- ✅ Respects device battery and connectivity
- ✅ Handles app termination gracefully
- ✅ Notification sent when spam found
- ✅ Scan visible in scan history
- ✅ Can enable/disable from settings

**Next Sprint Dependency**: Sprint 8 extends to iOS/Windows

---

### SPRINT 8: Background Scanning - iOS & Windows
**Status**: 📋 PLANNED
**Estimated Duration**: 12-14 hours
**Model Assignment**: Sonnet (BGTaskScheduler/Task Scheduler)
**Platforms**: iOS + Windows Desktop

**Objective**: Implement background scanning on iOS and Windows

**iOS Implementation** (BGTaskScheduler):
```
iOS background task flow:
1. BGAppRefreshTaskRequest registered
2. System schedules task (iOS decides timing)
3. Task woken up by system
4. ScanWorker executes (same logic)
5. Results saved
6. Local notification sent
7. Task completed or rescheduled
```

**Windows Implementation** (Task Scheduler):
```
Windows task flow:
1. WinRT Task Scheduler API
2. Create scheduled task for periodic execution
3. Trigger: Daily at configured time OR every X hours
4. Action: Launch app or background service
5. Results saved to database
6. Toast notification sent
7. App tile badge updated
```

**Components**:
1. **iOS BGTask implementation**
   - BGAppRefreshTaskRequest
   - Local notifications
   - Memory constraints handling

2. **Windows Task Scheduler integration**
   - PowerShell scripts for task creation
   - Registry configuration
   - Toast notification UWP API

3. **Platform abstraction**
   - Common BackgroundScanInterface
   - Platform-specific implementations
   - Fallback for unsupported platforms

**Tasks**:
- **Task A**: iOS BGTaskScheduler implementation
- **Task B**: Windows Task Scheduler integration
- **Task C**: Cross-platform notification abstraction

**Acceptance Criteria**:
- ✅ iOS: Background refresh works (test via app suspend/resume)
- ✅ Windows: Task Scheduler integration works
- ✅ Notifications sent on all platforms
- ✅ Scans appear in history
- ✅ Battery/CPU impact minimal

**Testing Challenges**:
- iOS background testing difficult (simulator limitation)
- Windows requires real system task scheduler

**Next Sprint Dependency**: Sprint 9 adds rule builder UI

---

### SPRINT 9: Rule Builder UI
**Status**: 📋 PLANNED
**Estimated Duration**: 10-12 hours
**Model Assignment**: Sonnet (architecture) + Haiku (UI)

**Objective**: Advanced UI for creating and managing rules

**Screens**:

1. **Rule List Screen**
   - Display all rules
   - Search/filter by name
   - Sort by execution order
   - Enable/disable toggle
   - Delete with confirmation

2. **Rule Editor Screen**
   - Create new rule or edit existing
   - Name, conditions, actions
   - Add multiple conditions (OR logic)
   - Add multiple patterns per condition
   - Regex validation with preview
   - Test rule against sample emails

3. **Rule Builder Wizard**
   - Step 1: Rule type (block domain / block email / safe sender)
   - Step 2: Pattern entry
   - Step 3: Action (delete / move / none)
   - Step 4: Exceptions (optional)
   - Step 5: Review and save

4. **Safe Sender Manager**
   - List all safe senders
   - Add new safe sender (email/domain/subdomain)
   - View exceptions for each safe sender
   - Bulk import from contacts

**Components**:
- RuleListScreen
- RuleEditorScreen
- RuleBuilderWizard
- SafeSenderManagerScreen
- PatternValidator (regex validation)
- RegexPreviewWidget (show matching examples)

**Tasks**:
- **Task A**: Rule list and editor screens
- **Task B**: Rule builder wizard
- **Task C**: Safe sender manager and pattern validation

**Acceptance Criteria**:
- ✅ Can view all rules
- ✅ Can create new rule
- ✅ Can edit existing rule
- ✅ Regex validation works
- ✅ Exceptions handled correctly
- ✅ Rules apply immediately after save
- ✅ Can undo deletion (with confirmation)

**Next Sprint Dependency**: Sprint 10 adds database cleanup

---

### SPRINT 10: Polish & Testing (Final Sprint)
**Status**: 📋 PLANNED
**Estimated Duration**: 12-15 hours
**Model Assignment**: Haiku (testing) + Sonnet (optimization/architecture)

**Objective**: Production readiness - cleanup, optimization, comprehensive testing

**Components**:

1. **Database Cleanup Service**
   - Archive scans older than configured days
   - Delete archived scans after retention period
   - Defragment database
   - Analyze and optimize indices

2. **Database Backup/Restore**
   - Export database to JSON (portable)
   - Import database from JSON
   - Export rules to YAML (already done)
   - Import rules from YAML

3. **Performance Optimization**
   - Profile database queries
   - Index commonly-queried fields
   - Cache frequently accessed data
   - Optimize regex compilation

4. **Comprehensive Testing**
   - Integration test suite (50+ tests)
   - End-to-end workflows (account setup → scan → view results)
   - Platform-specific tests (Android, Windows, iOS)
   - Stress testing (1000+ rules, 10000+ emails)
   - Long-running stability tests

5. **Documentation Updates**
   - User guide for all new features
   - Developer guide for extensions
   - API documentation for providers
   - Troubleshooting guide

6. **Code Quality**
   - Remove dead code
   - Refactor duplicated logic
   - Update deprecations
   - Final code analysis pass

**Tasks**:
- **Task A**: Database cleanup and maintenance service
- **Task B**: Backup/restore functionality
- **Task C**: Performance optimization and profiling
- **Task D**: Comprehensive integration test suite
- **Task E**: Documentation and code quality

**Acceptance Criteria**:
- ✅ All tests passing (90%+ coverage)
- ✅ Zero code analysis errors
- ✅ Database efficiently indexed
- ✅ Backup/restore works correctly
- ✅ Cleanup removes old data safely
- ✅ Performance baseline established
- ✅ User-facing documentation complete

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
