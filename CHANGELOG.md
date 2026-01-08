# Changelog

All notable changes to this project are documented in this file.
Format: `- **type**: Description (Issue #N)` where type is feat|fix|chore|docs

## [Unreleased]

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

### Phase 3.3 (January 5-6, 2026)
- Progressive UI updates with throttling
- Dynamic folder discovery from email providers
- Gmail token refresh and header parsing fixes
- Claude Code MCP tools and automation

### Phase 3.2 (January 4-5, 2026)
- Folder selection bug fixes
- Navigation fixes

### Phase 3.1 (January 4, 2026)
- Full Scan mode (4th scan mode)
- Scan Progress and Results UI redesign
- No Rule tracking

### Phase 3.0 and Earlier
See git history for detailed changes prior to Phase 3.1.
