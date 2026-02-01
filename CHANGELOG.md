# Changelog

All notable changes to this project are documented in this file.
Format: `- **type**: Description (Issue #N)` where type is feat|fix|chore|docs

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** (this doc) | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## [Unreleased]

### 2026-02-01 (Sprint 11)
- **feat**: Implement functional keyboard shortcuts for Windows Desktop (Issue #107)
- **fix**: Resolve system tray icon initialization error and menu persistence (Issue #108)
- **feat**: Enhance scan options with continuous slider 1-90 days + All checkbox (Issue #109)
- **feat**: Enhance CSV export with 10 columns including scan timestamp (Issue #110)
- **CRITICAL**: Fix readonly mode bypass - now properly prevents email deletion (Issue #9)
- **CRITICAL**: Change IMAP delete to move-to-trash instead of permanent delete
- **feat**: Add Exit button to Windows AppBars with confirmation dialog
- **fix**: Add visual SnackBar feedback for Ctrl+R/F5 refresh

### 2026-01-25
- **feat**: Implement SafeSenderDatabaseStore with exception support (Issue #66, Sprint 3 Task A)
- **feat**: Implement SafeSenderEvaluator with pattern matching and exceptions (Issue #67, Sprint 3 Task B)
- **feat**: Update RuleSetProvider to use SafeSenderDatabaseStore (Issue #68, Sprint 3 Task C)

### 2026-01-12
- **test**: Add Flutter integration tests for Windows Desktop UI (Issue #46)
- **feat**: Update Results screen to show folder • subject • rule format (Issue #47)
- **feat**: Add AOL Bulk/Bulk Email folder recognition as junk folders (Issue #48)

### 2026-01-07
- **chore**: Archive memory-bank files, consolidate documentation into CLAUDE.md
- **chore**: Clean up TODO comments, delete obsolete gmail_adapter.dart, create Issue #44 for Outlook
- **docs**: Add coding style guidelines - no contractions in documentation
- **fix**: Replace print() with Logger in production code (Issue #43)
- **fix**: Resolve navigation race condition, configurable test limit, per-account folders (Issues #39, #40, #41)
- **fix**: Strip Python-style inline regex flags (?i) for Dart compatibility (Issue #38)
- **fix**: Remove duplicate @ symbol from 23 safe sender patterns (Issue #38)

### 2026-01-06
- **feat**: Complete Phase 3.3 enhancements and bug fixes
- **chore**: Update .gitignore to exclude local Claude settings and log files
- **feat**: Add Claude Code MCP tools, skills, and hooks for enhanced development workflow
- **fix**: Extract email address from Gmail "From" header for rule matching
- **fix**: Reset _noRuleCount in startScan() to prevent accumulation
- **fix**: Add token refresh to Gmail folder discovery (Issue #37)
- **feat**: Dynamic folder discovery with enhanced UI (Issue #37)
- **feat**: Implement progressive UI updates with throttling (Issue #36)

### 2026-01-05
- **fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress
- **fix**: Folder selection now correctly scans selected folders (Issue #35)

### 2026-01-04
- **docs**: Update documentation for Phase 3.1 completion
- **feat**: Add "No rule" bubble to track emails with no rule match
- **fix**: Bubble counts now show proposed actions in all scan modes
- **fix**: Redesign Results Screen UI to match Scan Progress design (Issue #34)
- **feat**: Redesign Scan Progress UI - remove redundant elements, add bubbles, auto-navigate (Issue #33)
- **feat**: Add Full Scan mode with persistent mode selector and warning dialog (Issue #32)

---

## Version History

### Phase 3.3 - Enhancement Features (January 5-6, 2026)
**Status**: ✅ COMPLETE

**Features**:
- ✅ **Issue #36**: Progressive UI updates with throttling (every 10 emails OR 3 seconds)
- ✅ **Issue #37**: Dynamic folder discovery - fetches real folders from email providers
- ✅ **Gmail Token Refresh**: Folder discovery now uses `getValidAccessToken()` for automatic token refresh
- ✅ **Gmail Header Fix**: Extract email from "Name <email>" format for rule matching
- ✅ **Counter Bug Fix**: Reset `_noRuleCount` in `startScan()` to prevent accumulation across scans
- ✅ **Claude Code MCP Tools**: Custom MCP server for YAML validation, regex testing, rule simulation
- ✅ **Build Script Enhancements**: `-StartEmulator`, `-EmulatorName`, `-SkipUninstall` flags

**Impact**: Improved user experience with responsive UI updates, dynamic folder selection, and enhanced OAuth reliability

---

### Phase 3.2 - Bug Fixes (January 4-5, 2026)
**Status**: ✅ COMPLETE

**Fixes**:
- ✅ **Issue #35**: Folder selection now correctly scans selected folders (not just INBOX)
  - **Problem**: Selecting non-Inbox folders (e.g., "Bulk Mail") still only scanned Inbox
  - **Solution**: Added `_selectedFolders` field to EmailScanProvider, connected UI callback
- ✅ **Navigation Fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress
  - **Problem**: Returning to Scan Progress from Account Selection caused unwanted auto-navigation
  - **Solution**: Initialize `_previousStatus` in `initState()` before first build

**Files Modified**:
- `email_scan_provider.dart`
- `scan_progress_screen.dart`

---

### Phase 3.1 - UI/UX Enhancements (January 4, 2026)
**Status**: ✅ COMPLETE

**Features**:
- ✅ **Issue #32**: Full Scan mode added (4th scan mode) with persistent mode selector and warning dialogs
  - Added `ScanMode.fullScan` for permanent delete/move operations
  - Added persistent "Scan Mode" button on Scan Progress screen
  - Removed scan mode pop-up from account setup flow (default to readonly)
  - Added warning dialog for Full Scan mode (requires user confirmation)

- ✅ **Issue #33**: Scan Progress UI redesigned
  - Removed redundant progress bar and processed count text
  - Updated to 7-bubble row: Found (Blue), Processed (Purple), Deleted (Red), Moved (Orange), Safe (Green), No rule (Grey), Errors (Dark Red)
  - Added auto-navigation to Results screen when scan completes
  - Re-enabled buttons after scan completes

- ✅ **Issue #34**: Results Screen UI redesigned
  - Added `accountEmail` parameter to show email in title
  - Updated title format: "Results - <email> - <provider>"
  - Updated summary format: "Summary - <mode>"
  - Matched bubble row to Scan Progress (7 bubbles with exact same colors)

- ✅ **Bubble Counts Fix**: All scan modes now show proposed actions (what WOULD happen)
  - Changed `recordResult()` to always increment counts based on rule evaluation
  - Read-Only mode now useful for previewing results

- ✅ **No Rule Tracking**: Added "No rule" bubble (grey) to track emails with no rule match
  - Added `_noRuleCount` field and getter to EmailScanProvider
  - Tracks emails that did not match any rules (for future rule creation)

**Test Results**: 122/122 tests passing

**Files Modified**:
- `email_scan_provider.dart`
- `account_setup_screen.dart`
- `scan_progress_screen.dart`
- `results_display_screen.dart`

---

### Phase 3.0 and Earlier
See git history for detailed changes prior to Phase 3.1.

**Key Milestones**:
- Phase 2.2: Rule evaluation and pattern compiler enhancements
- Phase 2.1: Adapter and provider implementations
- Phase 2.0: AppPaths, SecureCredentialsStore, EmailScanProvider
- Phase 1: Core models, services, and foundation (27 tests)
