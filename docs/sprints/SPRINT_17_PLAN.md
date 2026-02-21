# Sprint 17 Plan: Scan History, Background Scan Fixes, Conflict Auto-Removal

**Sprint**: 17
**Branch**: `feature/20260215_Sprint_17` (continuation from Sprint 16)
**PR**: #162 targeting `develop`
**Planned Duration**: ~8-12h
**Start Date**: February 17, 2026

---

## Sprint Objective

Implement scan history consolidation, fix background scanning reliability, and add bidirectional rule/safe-sender conflict auto-removal.

## Tasks

### Task A: Consolidated Scan History Screen (Issue #158)
- **Model**: Opus
- **Description**: Replace separate background scan log viewer with unified Scan History screen showing both manual and background scans
- **Acceptance Criteria**:
  - Unified chronological list of all scans
  - Filter chips: All / Manual / Background
  - Summary stats (total, completed, errors, emails processed)
  - Tap entry to view detailed results
  - Scan history retention setting (3/7/14/30/90 days) with auto-purge

### Task B: Manual Scan Screen Shows Config (Issue #156)
- **Model**: Opus
- **Description**: Show configured scan mode and folders in Manual Scan screen idle state
- **Acceptance Criteria**:
  - Scan mode displayed when idle
  - Configured folders displayed when idle

### Task C: Clear Results Before Live Scan (Issue #157)
- **Model**: Opus
- **Description**: Clear stale results from Results screen before starting new live scan
- **Acceptance Criteria**:
  - No stale historical results shown during new scan
  - Results screen shows fresh data only

### Task D: Fix Windows Task Scheduler Background Scan (Issue #161)
- **Model**: Opus
- **Description**: Background scan not running after reboot - fix trigger configuration
- **Acceptance Criteria**:
  - Changed trigger from -Once to -Daily with RepetitionInterval
  - Auto-recreate missing Task Scheduler task on app startup
  - Skip Task Scheduler management in debug mode

### Task E: Test Background Scan Button (Issue #159)
- **Model**: Opus
- **Description**: Add test button in Settings for manual verification of background scan functionality
- **Acceptance Criteria**:
  - Test button in Settings triggers background scan
  - Results visible in scan history

### Task F: Auto-Remove Conflicting Rules (Issue #154)
- **Model**: Opus
- **Description**: When adding safe sender, auto-remove conflicting block rules, and vice versa
- **Acceptance Criteria**:
  - Bidirectional conflict detection and removal
  - User notification of removed conflicts

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| A | Medium - Complex UI with multiple data sources | Reuse existing ResultsDisplayScreen patterns |
| D | High - Windows Task Scheduler platform-specific | Test on actual Windows machine |
| F | Medium - Pattern matching edge cases | Comprehensive unit tests |

---

**Created**: February 17, 2026
**Status**: [OK] Complete
