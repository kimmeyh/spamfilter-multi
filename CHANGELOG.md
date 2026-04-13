# Changelog

All notable changes to this project are documented in this file.
Format: `- **type**: Description (Issue #N)` where type is feat|fix|chore|docs

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
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
| **CHANGELOG.md** (this doc) | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## [Unreleased]

### 2026-04-13 (Sprint 30 - Architecture Gap Analysis)
- **docs**: Architecture gap analysis - compared 36 ADRs, ARCHITECTURE.md, ARSD.md against codebase (F60, Issue #226)
- **docs**: Identified 26 gaps across 5 categories: documentation drift, dead code, partial ADRs, missing docs, unimplemented architecture
- **docs**: Added 4 new backlog items from gap analysis: F61 (doc refresh), F62 (dead code cleanup), F63 (responsive design), F64 (CI/CD pipeline)
- **chore**: Fix startup-check skill to use PowerShell first for metadata updates (don't-ask mode compatible)
- **chore**: Close Sprint 29 issues #219, #220

### 2026-04-03 (Sprint 29 - UX + Quality + Features)
- **feat**: Make all page text selectable and copyable across 21 screens (F50, Issue #220)
- **feat**: Scan History enhancements - multi-account combined view, account/type filters, totals with tooltips, retention days in title (F48, Issue #212)
- **feat**: Default rule set creation - seed from bundled YAML on fresh install, Reset to Defaults button in Settings (F46, Issue #208)
- **test**: Add tests for email_scanner, default_rule_set_service, yaml_service parse methods (F42, Issue #203)
- **fix**: Results screen and email detail popup now support text selection (F50 testing feedback)
- **fix**: Account setup dialogs (AOL, Gmail, platform selection) now support text selection (F50 testing feedback)
- **fix**: Scan History account filter uses configured accounts, shows when multiple accounts exist (F48 testing feedback)
- **fix**: Manual Scan title shows account email instead of platform name
- **fix**: YAML round-trip test path after rules moved to assets/rules/ - fixes pre-existing test failure
- **docs**: Backlog refinement - removed completed items from ALL_SPRINTS_MASTER_PLAN.md

### 2026-04-02 (Sprint 28 - MSIX Sandbox Fix + UX Improvements)
- **fix**: Replace all hardcoded Platform.environment['APPDATA'] paths with path_provider for MSIX sandbox compatibility (B1, Issue #218)
- **fix**: Add MSIX detection (AppEnvironment.isMsixInstall) and skip Task Scheduler in MSIX context (B1, Issue #218)
- **fix**: app_identity_migration.dart uses path_provider instead of raw APPDATA (Issue #218)
- **fix**: dev_environment_seeder.dart uses path_provider instead of raw APPDATA (Issue #218)
- **fix**: background_scan_windows_worker.dart uses cached path_provider log directory (Issue #218)
- **feat**: Remove "Scan All N Accounts" button from account selection screen (F49, Issue #219)
- **feat**: View Scan History on account selection shows account selection dialog (F49, Issue #219)
- **feat**: Scan History title shows account email when filtered by account (F49, Issue #219)
- **feat**: Background settings: Scan Mode moved above Default Folders to match Manual Scan layout (F51, Issue #221)
- **fix**: Account selection dialog displays correct email and platform from cached data (Issue #219)
- **fix**: Test Background Scan runs all accounts regardless of Enable Background Scanning toggle
- **chore**: Add local MSIX testing support (create-test-cert.ps1, store/test toggle docs)

### 2026-03-30 (Sprint 27 - Desktop App E2E Testing with civyk-winwright)
- **feat**: Install civyk-winwright MCP server for automated Windows Desktop UI testing (F11)
- **feat**: Discover Flutter Desktop requires SPI_SETSCREENREADER flag for accessibility tree activation (F11)
- **feat**: Create enable-screen-reader-flag.ps1 utility for toggling Windows screen reader flag (F11)
- **feat**: Evaluate accessibility tree across 5 screens - GO decision for full E2E testing (F11)
- **feat**: Exploratory testing of all 11 screens - buttons, tabs, text input, dialogs, assertions all work (F11)
- **feat**: MCP HTTP server workflow for interactive desktop testing via JSON-RPC (F11)
- **docs**: Add automated E2E desktop testing section to TESTING_STRATEGY.md and ARCHITECTURE.md (F11)
- **docs**: Move F11 from HOLD to active in ALL_SPRINTS_MASTER_PLAN.md (F11)
- **docs**: Create SPRINT_27_ACCESSIBILITY_EVALUATION.md with full findings report (F11)
- **chore**: Fix /memory-save, /memory-restore, /startup-check skills - use Bash for .claude/ writes, add staleness validation
- **chore**: Add mandatory metadata update enforcement to /startup-check and /memory-restore skills
- **fix**: Patch Flutter SDK sqlite3 native assets PathExistsException on Windows (MSB8066 build failure)
- **fix**: Add pre-build native_assets cleanup to build-windows.ps1 (defense-in-depth for sqlite3 bug)
- **docs**: Create WINWRIGHT_SELECTORS.md quick reference for winwright selector patterns (F11)
- **docs**: Add B1 MSIX sandbox crash (Issue #218) to backlog as Priority 1 for Sprint 28
- **docs**: Add F49, F50, F51 retrospective feedback items to backlog (Issues #219-#221)

### 2026-03-22 (Sprint 26 - Settings UX, Excel Export, Provider Warnings, Multi-Account)
- **feat**: Folder settings selection UX - radio button auto-save, show current folder (F43, Issue #211)
- **feat**: "Go to View Scan History" link on Manual Scan settings page (F44, Issue #211)
- **feat**: Background scan Excel export with daily file grouping and updated field order (F45, Issue #211)
- **feat**: Email provider domain warning when creating domain-level rules (F47, Issue #211)
- **feat**: Settings General tab for app-wide settings (rules, scan history, about) (F36, Issue #211)
- **feat**: Multi-Account Scanning - "Scan All Accounts" button for sequential scanning (F7, Issue #211)
- **chore**: Action label "No rule" replaces "None" in CSV/Excel exports
- **fix**: Excel filename uses _dev suffix for dev environment, files stored in AppData dir (ADR-0035, Issue #211)
- **fix**: Live Scan Results - deleted emails removed from list immediately after block rule applied (Issue #211)
- **feat**: View Scan History icon added to Results Display and Account Selection AppBars (Issue #211)

### 2026-03-22 (Sprint 25 - Safe Sender Fixes, Scan Mode Rename, Background Scan Rebuild)
- **fix**: Safe sender INBOX skip bug - emails already in safe sender target folder were not being skipped (Issue #198)
- **fix**: Exact domain filter chip misclassification - determinePatternType and categorize priority reordered (F30, Issue #202)
- **fix**: Background scan task deleted on rebuild - add post-build Task Scheduler re-registration to build-windows.ps1 (F31, Issue #202)
- **feat**: Safe sender move diagnostic logging for debugging move execution (Issue #201)
- **chore**: Rename ScanMode enum values for clarity (readonly->readOnly, testLimit->rulesOnly, testAll->safeSendersOnly, fullScan->safeSendersAndRules) with backwards compatibility (Issue #202)
- **feat**: Live scan status indicator showing progress bar, completion, and error states in results summary card (F34, Issue #202)
- **feat**: Re-process emails via IMAP after inline rule changes - adds safe sender or block rule, then executes server-side actions on affected emails (F38, Issue #202)
- **test**: Add exact domain regex classification tests for SafeSenderCategory (Issue #202)
- **test**: Add ScanMode backwards compatibility tests for legacy DB enum names (F32, Issue #202)
- **test**: Add determinePatternType edge case and round-trip tests (F32, Issue #202)
- **test**: Add RuleSetProvider state management tests - load, add, remove, update rules and safe senders (F32, Issue #202)
- **chore**: F38 re-process changed from blocking dialog to non-blocking inline banner (Issue #202)
- **chore**: Set up prod worktree at spamfilter-multi-prod for side-by-side dev/prod execution (ADR-0035)

### 2026-03-21 (Sprint 24 - Windows Store Readiness: Privacy Policy, Store Assets, Submission)
- **feat**: Privacy policy website deployed to docs/website/ (index.html, privacy/index.html, delete/index.html) with CNAME for myemailspamfilter.com (Issue #197)
- **feat**: Microsoft Store listing created - app name reserved, store assets uploaded, MSIX package submitted for certification (Issue #197)
- **feat**: Store listing assets document with descriptions, screenshots, keywords, age ratings (Issue #197)
- **chore**: Rename Windows executable from spam_filter_mobile to MyEmailSpamFilter (CMakeLists.txt, Runner.rc, Package.appxmanifest, build-windows.ps1)
- **chore**: Rename Dart package from spam_filter_mobile to my_email_spam_filter (pubspec.yaml, 224 imports across 73 files)
- **chore**: Add msix v3.16.8 dev dependency for MSIX package building
- **chore**: Update pubspec.yaml msix_config with Partner Center identity (publisher, identity_name, publisher_display_name)
- **docs**: Add contact email (kimmeyh@outlook.com) to privacy policy website contact section
- **docs**: Update all docs referencing old executable name (WINDOWS_DEVELOPMENT_GUIDE, TROUBLESHOOTING, ALL_SPRINTS_MASTER_PLAN, ADR-0035)
- **docs**: Update LOGGING_CONVENTIONS.md with new package import name

### 2026-03-20 (Sprint 23 - Windows Store MSIX, Signing, Domain, Branding)
- **feat**: MSIX config fixes - enable store mode, fix logo path, sync version (Issue #194)
- **docs**: ADR-0036 MSIX signing strategy - Microsoft Store auto-signing for Store builds (Issue #194)
- **feat**: App icon and branding - email envelope + checkmark + funnel design (ADR-0031, Issue #194)
- **chore**: Add flutter_launcher_icons v0.14.4, generate Android adaptive icons and Windows .ico
- **chore**: Register myemailspamfilter.com domain + .net forwarding, DNS configured for GitHub Pages (Issue #166)

### 2026-03-19 (Sprint 22 - Windows Store Readiness Research)
- **docs**: Microsoft Store requirements research and codebase gap analysis (Issue #191)
- **docs**: Windows Store readiness backlog items #17-#22 added to ALL_SPRINTS_MASTER_PLAN.md (Issue #191)
- **chore**: Fix memory-save, memory-restore, startup-check skills - use absolute paths and bash-compatible commands

### 2026-03-18 (Sprint 21 - ADR-0035)
- **feat**: Production/Development side-by-side builds with environment-aware data directories (ADR-0035, Issue #189)
- **feat**: AppEnvironment class reads APP_ENV from --dart-define (dev/prod)
- **feat**: Dev builds use MyEmailSpamFilter_Dev data directory, window title shows [DEV]
- **feat**: Separate Task Scheduler task names per environment
- **feat**: First-run dev environment seeded from production database
- **feat**: Single-instance mutex per executable path prevents duplicate instances
- **feat**: build-windows.ps1 accepts -Environment parameter (dev/prod)
- **feat**: secrets.prod.json template for production credentials
- **chore**: Version bumped to 0.5.1 on develop (production stays 0.5.0)

### 2026-03-17 (Sprint 20 - Testing Feedback)
- **fix**: DB v2 migration checks for existing columns before ALTER TABLE
- **fix**: Scan Results folder display shows correct account folders after switching accounts
- **feat**: Demo-specific rules DB for consistent demo scan results (~20 safe / ~30 deleted / ~9 no-rule)
- **fix**: IMAP folder listing now recursive - shows [Gmail]/Trash, [Gmail]/Spam and other child folders
- **fix**: Non-selectable parent folders (e.g., [Gmail]) filtered from folder selection
- **fix**: Reclassify 266 TLD header patterns from exact_domain to top_level_domain
- **fix**: Convert 1,370 wildcard TLD patterns to .com and reclassify as entire_domain
- **fix**: Add Rule from scan results now sets patternCategory, patternSubType, sourceDomain
- **fix**: Quick rule from email detail popup now sets classification fields
- **fix**: YAML migration and export preserve classification fields
- **fix**: Safe sender matches in safe sender folder skipped from scan results (already where they belong)

### 2026-03-15 (Sprint 20)
- **fix**: Gmail IMAP folder scan errors - use PlatformRegistry for correct adapter routing (Issue #184)
- **feat**: Demo Scan expanded with 12 new sample emails across Safe Sender and Block Rule categories (Issue #185)
- **feat**: Speed up Add Rule re-evaluation with shared PatternCompiler cache (Issue #186)
- **chore**: Clean up all 46 analyzer warnings - zero issues remaining (Issue #187)
- **feat**: Add pattern classification fields (patternCategory, patternSubType, sourceDomain) to Rule model (Issue #149)
- **feat**: Remove YAML dual-write - database is sole source of truth for rules (Issue #149)
- **feat**: Standalone rule split script - splits 5 monolithic rules into ~3,291 individual rules (Issue #149)
- **feat**: Manage Rules UI overhaul - filter chips by category and sub-type, search, individual rule display (Issue #149)

### 2026-03-14 (Sprint 19 - Testing Feedback Round 2)
- **fix**: Safe Senders YAML export error - AppPaths not initialized in Import/Export screen (Issue #179)
- **fix**: Convert bare `@insightfinancialassociates.com` safe sender pattern to proper Entire Domain regex
- **feat**: Gmail auth method order - App Password (IMAP) listed first as Recommended, Google Sign-In second with re-auth note (Issue #178)
- **feat**: App Password instructions - selectable/copyable text, tappable URL links, updated step text, removed obsolete IMAP info box (Issue #178)
- **feat**: Scan Results Summary title now shows scanned folder names (e.g., "Summary - Read-Only - Folder(s): Bulk, Bulk Mail")
- **feat**: Live re-evaluation of all "No rule" emails after adding a block rule or safe sender from scan results
- **fix**: Scan History now filters by account - shows only scans for the current email account, not all accounts
- **test**: Added regex pattern validation tests for round-trip YAML export/import (rules and safe senders)

### 2026-02-28 (Sprint 19 - Testing Feedback Fixes)
- **fix**: Add About section in Settings > Account showing app version 0.5.0 (Issue #181)
- **fix**: Background scan worker log path updated from old com.example to MyEmailSpamFilter directory (Issue #182)
- **fix**: Demo Mode changed from toggle switch to direct-launch card on Select Email Provider screen

### 2026-02-27 (Sprint 19)
- **chore**: Tag v0.5.0 release, update pubspec.yaml version to 0.5.0+1 (Issue #181, GP-15)
- **feat**: Application identity rebranded to MyEmailSpamFilter with com.myemailspamfilter package (Issue #182, GP-1)
- **fix**: Auto-migrate app data from old com.example directory after identity change - preserves accounts, rules, credentials (Issue #182)
- **feat**: Folder selection now saves instantly on toggle - Cancel and Scan buttons removed in multi-select mode (Issue #172, F27)
- **feat**: Safe senders screen filter chips for pattern categories - Exact Email, Exact Domain, Entire Domain, Other (Issue #180, F26)
- **feat**: YAML import/export UI in Settings - export rules and safe senders to file, import from file with validation (Issue #179, F22)
- **feat**: Gmail dual-auth - choose Google Sign-In (OAuth) or App Password (IMAP) when adding Gmail account (Issue #178, F12B)

---

## [0.5.0] - 2026-02-27

First tagged release. Covers Sprints 1-18 plus hotfix #176.

### 2026-02-27 (Hotfix)
- **fix**: Windows Task Scheduler repetition trigger fails silently - changed from property-based Repetition setting to inline -RepetitionInterval/-RepetitionDuration parameters (Issue #176)

### 2026-02-25 (Sprint 18: Bug Fixes from Testing Feedback)
- **fix**: Conflict detection for "Block Entire Domain" now passes full email address to resolver instead of bare domain (Issue #154)
- **fix**: Scan History shows correct rule match info instead of "No rule" for all entries
- **fix**: Inline rule re-evaluation now updates filter counts and list membership immediately (Issue #168)
- **fix**: Background scan RepetitionDuration changed from 1 day to 365 days for reliable recurring execution
- **fix**: Settings > View Scan History now passes account context for email detail drill-down
- **feat**: Shared email provider hint in email detail popup for Gmail, Yahoo, etc. (Issue #167)

### 2026-02-24 (Sprint 18: Rule Quality and Testing Tooling)
- **fix**: Add conflict detection to inline rule assignment popup - safe sender and block rule conflicts now auto-resolved from Results screen (Issue #154)
- **docs**: Subject (S1-S6) and body (B1-B4) content rule pattern standards with guidelines, examples, and anti-patterns (Issue #141)
- **feat**: PatternCompiler.validatePattern() warns about unescaped dots, redundant wildcards, empty alternation, repeated chars (Issue #141)
- **feat**: Common email provider domain reference table - 15 providers, 50+ domains with O(1) lookup (Issue #167, F20)
- **feat**: Inline rule assignment re-evaluation - Results screen updates immediately after adding safe sender or block rule (Issue #168, F21)
- **feat**: Rule Testing and Simulation UI - test regex patterns against sample emails from recent scans with match highlighting (Issue #169, F8)
- **test**: 95 new tests (conflict resolver 16, pattern standards 48, email providers 30, rule test screen 17) - total 1088

### 2026-02-17 (Sprint 17: Scan History, Background Scan Fixes, Conflict Auto-Removal)
- **feat**: Consolidated Scan History screen replacing separate background scan log viewer - unified view of all manual and background scans with type filter chips, summary stats, and tap-to-view (Issue #158)
- **feat**: Scan history retention setting (3/7/14/30/90 days) with automatic purge of old entries (Issue #158)
- **feat**: Manual Scan screen shows configured scan mode and folders in idle status (Issue #156)
- **fix**: Clear Results screen before starting new Live Scan - no longer shows stale historical results (Issue #157)
- **fix**: Windows Task Scheduler background scan not running after reboot - changed trigger from -Once to -Daily with RepetitionInterval (Issue #161)
- **fix**: Auto-recreate missing Task Scheduler task on app startup when background scanning is enabled (Issue #161)
- **feat**: Test Background Scan button in Settings for manual verification of background scan functionality (Issue #159)
- **feat**: Auto-remove conflicting rules when adding safe sender, and vice versa - bidirectional conflict resolution (Issue #154)
- **fix**: Skip Task Scheduler management in debug mode - prevents broken scheduled tasks from temporary debug executable paths (Bug #3)
- **fix**: Prevent duplicate scan_results database records - UI-only startScan call no longer persists to database (Bug #2)
- **feat**: Reorganize Settings - move Test button before Frequency, move Scan History to Account tab (FB-4/FB-3)
- **feat**: Custom retention days input (1-999) with quick-select chips replacing dropdown (FB-2)
- **fix**: Scan History navigation - back button returns to Scan History screen instead of Scan Progress when viewing historical results (FB-1)
- **fix**: Retention days field saves on every keystroke, adds digits-only input validation with 3-char max
- **feat**: Background scan log includes full stats: Processed, Deleted, Moved, Safe, No Rule, Errors
- **fix**: Purge orphaned in_progress scan records during retention cleanup
- **feat**: Historical scan results use same interactive filter chips and folder filter as live scan results
- **fix**: Historical scan mode labels now use stored mode (not live provider default) - fullScan no longer shows "(not processed)"
- **feat**: Scan History subtitle consolidated: duration | mode | Folders in single line with updated mode names
- **fix**: Rename "Last Scan Results" to "Scan Results"
- **test**: Fix PowerShell script generator test assertion (RepetitionInterval -> Repetition.Interval)
- **docs**: Sprint retrospective improvements S1-S7 - phase transition checkpoints, mandatory sprint document creation, docs/sprints/ reorganization, /phase-check skill
- **chore**: Move 46 per-sprint documents from docs/ to docs/sprints/ with standardized uppercase naming

### 2026-02-16 (Sprint 16: Phase Renumbering)
- **docs**: Renumber sprint workflow phases from -1/0/1/2/3/4/4.5 to sequential 1-7 across 16 documents (Issue #160)

### 2026-02-15-16 (Sprint 16: User Testing Feedback)
- **feat**: Scan range slider always visible and interactive, "Scan all emails" checkbox overrides slider value (FB-1)
- **feat**: Background scan default changed to "all emails" instead of 7 days (FB-1)
- **feat**: Remove Scan Options dialog popup - Start Live Scan uses Settings directly (FB-2)
- **feat**: Simplify Manual Scan screen - remove stats bubbles, pause button, complete indicator; show progress only during active scan (FB-3)
- **feat**: View Results shows last completed scan (live or background) with scan type and timestamp (FB-4)
- **feat**: "No Results Yet" message only shown when no scan history exists at all (FB-5)
- **fix**: Auto-repair Windows Task Scheduler executable path after app rebuild (FB-6)
- **feat**: Persist individual email actions to database for historical View Results display - both manual and background scans (FB-7)
- **fix**: Historical View Results summary bubbles now show correct counts from database instead of empty live scan provider values (FB-8)

### 2026-02-14 (Sprint 16: Scan Configuration, Log Viewer, and Rule Conflict Detection)
- **feat**: Persistent days-back scan settings for Manual and Background scans with per-account overrides (Issue #153)
- **feat**: Scan Options dialog defaults to "Scan all emails" with saved preferences (Issue #150)
- **feat**: Rename "Scan Progress" screen to "Manual Scan" and remove folder selection button (Issue #151)
- **feat**: Background scan log viewer screen with account filter, summary stats, and expandable log cards (Issue #152)
- **feat**: Rule override/conflict detection - warns users when existing rules or safe senders would prevent new rule from being evaluated (Issue #139)
- **chore**: Remove unused imports from Sprint 16 changes (5 analyzer warnings fixed)
- **test**: 16 new unit tests for RuleConflictDetector (977 tests passing, 28 skipped)

### 2026-02-14-15 (Sprint 15: Bug Fixes, Performance, and Settings Management)
- **fix**: Resolve 100-delete limit bug - IMAP sequence IDs shifted after each delete, causing wrong messages to be targeted after ~100 operations. Switched to UID-based operations throughout (Issue #145)
- **feat**: Batch email processing - evaluate all emails first, then execute actions in batches using IMAP UID sequence sets. Reduces IMAP round-trips from 3N to ~3 batch operations (Issue #144)
- **feat**: Manage Safe Senders UI in Settings - view, search, delete safe sender patterns (Issue #147)
- **feat**: Manage Rules UI in Settings - view, search, delete block rules with rule type indicators (Issue #148)
- **feat**: Windows native directory browser for CSV export path selection (Issue #126)
- **feat**: Windows background scanning with Task Scheduler integration - headless scan mode, configurable frequency, per-account folder/mode settings (F5)
- **feat**: Debug CSV export toggle for background scans - writes scan results CSV after each background run
- **fix**: Background scan headless execution - account loading from SecureCredentialsStore, FK constraint compliance
- **fix**: Background scan uses correct per-account folders and scan mode (background-specific settings override)
- **fix**: Safe sender INBOX normalization for RFC 3501 compliance (mixed-case "Inbox" to "INBOX")
- **fix**: Processed count exceeding found count - batch progress messages no longer increment processedCount
- **docs**: Architecture Decision Records (ADR-0001 through ADR-0015) documenting 15 key architectural decisions
- **docs**: Sprint 14 Summary document
- **test**: Batch action result tests and batch operations mixin tests (961 tests passing, 28 skipped)

### 2026-02-07-08 (Sprint 14: Settings Restructure + UX Improvements)
- **feat**: Progressive folder-by-folder scan updates with 2-second refresh interval (Issue #128)
- **feat**: Settings Screen restructure - separate Manual Scan and Background Settings tabs (Issue #123)
- **feat**: Default Folders UI - reusable folder picker matching Select Folders screen (Issue #124)
- **feat**: Remove Scan Mode button from Scan Progress screen (single source of truth in Settings)
- **feat**: Manual and Background scans use independent scan mode settings from SettingsStore
- **feat**: Enhanced Demo Scan with 50+ sample emails for testing without live account (Issue #125)
- **feat**: Enhanced Deleted Email Processing - mark emails as read and tag with matched rule name (Issue #138)
- **fix**: Use email folder picker component for Safe Sender and Deleted Rule folder selection
- **fix**: Skip rule processing in testAll mode (safe senders evaluation only)
- **fix**: Ensure Found count is always greater than or equal to Processed count
- **chore**: Reduce analyzer warnings from 214 to 48 (target: <50) (Issue #130)
- **test**: All 937 tests passing (27 skipped)

### 2026-02-01 (Sprint 11 + Retrospective Implementation)
- **feat**: Implement functional keyboard shortcuts for Windows Desktop (Issue #107)
- **fix**: Resolve system tray icon initialization error and menu persistence (Issue #108)
- **feat**: Enhance scan options with continuous slider 1-90 days + All checkbox (Issue #109)
- **feat**: Enhance CSV export with 10 columns including scan timestamp (Issue #110)
- **CRITICAL**: Fix readonly mode bypass - now properly prevents email deletion (Issue #9)
- **CRITICAL**: Change IMAP delete to move-to-trash instead of permanent delete
- **feat**: Add Exit button to Windows AppBars with confirmation dialog
- **fix**: Add visual SnackBar feedback for Ctrl+R/F5 refresh
- **test**: Add integration test for readonly mode enforcement (prevents Issue #9 regression)
- **test**: Add integration test for delete-to-trash behavior (IMAP + Gmail)
- **docs**: Create WINDOWS_DEVELOPMENT_GUIDE.md (consolidates bash, Unicode, PowerShell, builds)
- **docs**: Create RECOVERY_CAPABILITIES.md (audit of all destructive operations)
- **docs**: Add Issue Backlog section to ALL_SPRINTS_MASTER_PLAN.md (tracks all open/fixed issues)
- **docs**: Update SPRINT_EXECUTION_WORKFLOW.md Phase 3.3 with pre-testing checklist
- **docs**: Update CLAUDE.md and QUICK_REFERENCE.md to reference new Windows guide
- **chore**: Create test email generators (generate-test-emails.ps1, send-test-emails.py)

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
**Status**: [OK] COMPLETE

**Features**:
- [OK] **Issue #36**: Progressive UI updates with throttling (every 10 emails OR 3 seconds)
- [OK] **Issue #37**: Dynamic folder discovery - fetches real folders from email providers
- [OK] **Gmail Token Refresh**: Folder discovery now uses `getValidAccessToken()` for automatic token refresh
- [OK] **Gmail Header Fix**: Extract email from "Name <email>" format for rule matching
- [OK] **Counter Bug Fix**: Reset `_noRuleCount` in `startScan()` to prevent accumulation across scans
- [OK] **Claude Code MCP Tools**: Custom MCP server for YAML validation, regex testing, rule simulation
- [OK] **Build Script Enhancements**: `-StartEmulator`, `-EmulatorName`, `-SkipUninstall` flags

**Impact**: Improved user experience with responsive UI updates, dynamic folder selection, and enhanced OAuth reliability

---

### Phase 3.2 - Bug Fixes (January 4-5, 2026)
**Status**: [OK] COMPLETE

**Fixes**:
- [OK] **Issue #35**: Folder selection now correctly scans selected folders (not just INBOX)
  - **Problem**: Selecting non-Inbox folders (e.g., "Bulk Mail") still only scanned Inbox
  - **Solution**: Added `_selectedFolders` field to EmailScanProvider, connected UI callback
- [OK] **Navigation Fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress
  - **Problem**: Returning to Scan Progress from Account Selection caused unwanted auto-navigation
  - **Solution**: Initialize `_previousStatus` in `initState()` before first build

**Files Modified**:
- `email_scan_provider.dart`
- `scan_progress_screen.dart`

---

### Phase 3.1 - UI/UX Enhancements (January 4, 2026)
**Status**: [OK] COMPLETE

**Features**:
- [OK] **Issue #32**: Full Scan mode added (4th scan mode) with persistent mode selector and warning dialogs
  - Added `ScanMode.fullScan` for permanent delete/move operations
  - Added persistent "Scan Mode" button on Scan Progress screen
  - Removed scan mode pop-up from account setup flow (default to readonly)
  - Added warning dialog for Full Scan mode (requires user confirmation)

- [OK] **Issue #33**: Scan Progress UI redesigned
  - Removed redundant progress bar and processed count text
  - Updated to 7-bubble row: Found (Blue), Processed (Purple), Deleted (Red), Moved (Orange), Safe (Green), No rule (Grey), Errors (Dark Red)
  - Added auto-navigation to Results screen when scan completes
  - Re-enabled buttons after scan completes

- [OK] **Issue #34**: Results Screen UI redesigned
  - Added `accountEmail` parameter to show email in title
  - Updated title format: "Results - <email> - <provider>"
  - Updated summary format: "Summary - <mode>"
  - Matched bubble row to Scan Progress (7 bubbles with exact same colors)

- [OK] **Bubble Counts Fix**: All scan modes now show proposed actions (what WOULD happen)
  - Changed `recordResult()` to always increment counts based on rule evaluation
  - Read-Only mode now useful for previewing results

- [OK] **No Rule Tracking**: Added "No rule" bubble (grey) to track emails with no rule match
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

---

## Version Links

[Unreleased]: https://github.com/kimmeyh/spamfilter-multi/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/kimmeyh/spamfilter-multi/releases/tag/v0.5.0
