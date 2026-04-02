# Sprint 27 Retrospective

**Sprint**: Sprint 27 - Desktop App E2E Testing with civyk-winwright
**Date**: March 29 - April 2, 2026
**Branch**: `feature/20260329_Sprint_27`
**PR**: #217

---

## Sprint Goal

Set up automated desktop app E2E testing using civyk-winwright MCP server. Evaluate Flutter accessibility tree feasibility, perform exploratory testing of all Windows Desktop screens, and document the new testing layer.

## Outcome: [OK] Complete

All 4 tasks completed. GO decision made on civyk-winwright for Flutter Windows Desktop testing.

---

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| A | Install civyk-winwright v2.0.0 | [OK] Complete |
| B | Evaluate Flutter accessibility tree | [OK] Complete (GO decision) |
| C | Desktop app exploratory testing (11 screens) | [OK] Complete |
| D | Documentation updates (7 docs, 4 new files) | [OK] Complete |

### Additional Work (Unplanned)
- Fixed Flutter SDK sqlite3 native assets build failure (PathExistsException)
- Added pre-build cleanup to build-windows.ps1
- Created B1 MSIX sandbox crash backlog item (Issue #218) from Microsoft Store certification failure
- Created F49, F50, F51 backlog items from retrospective feedback
- Created WINWRIGHT_SELECTORS.md quick reference

---

## Key Findings

1. **Flutter Desktop requires SPI_SETSCREENREADER flag** for accessibility tree activation. Without it, FLUTTERVIEW is a single opaque pane with zero children.

2. **All 11 app screens are automatable** via civyk-winwright UIA3/MSAA bridge. Buttons, checkboxes, sliders, edit fields, tabs, dialogs all work.

3. **Tab switching requires `useInvokePattern: false`** — Flutter TabBar tabs render as Text elements, not Tab controls. InvokePattern does not trigger tab changes.

4. **Script replay (`winwright run`) is non-functional** — JSON script format is undocumented. MCP HTTP server with curl-based JSON-RPC is the viable automation path.

5. **Flutter SDK 3.38.5 has a Windows build bug** — `install_code_assets` runs twice, causing PathExistsException for sqlite3.dll. Patched with skip-if-exists logic.

---

## Retrospective Feedback

### User Feedback (All "Very Good")

| Category | Rating |
|----------|--------|
| Effective while Efficient | Very Good |
| Sprint Execution | Very Good |
| Testing Approach | Very Good |
| Effort Accuracy | Very Good |
| Planning Quality | Very Good |
| Model Assignments | Very Good |
| Communication | Very Good |
| Requirements Clarity | Very Good |
| Documentation | Very Good |
| Process Issues | Very Good |
| Risk Management | Very Good |
| Next Sprint Readiness | Very Good |

**Minor function updates for Sprint 28**:
- F49 (Issue #219): Remove "Scan All Accounts" button, add account selection to View Scan History on Select Account screen
- F50 (Issue #220): Make all page text selectable and copyable to clipboard
- F51 (Issue #221): Background settings - move Scan Mode above Default Folders

### Claude Feedback

| Category | Rating | Notes |
|----------|--------|-------|
| Effective while Efficient | Very Good | SPI_SETSCREENREADER discovery unblocked sprint early |
| Sprint Execution | Very Good | All tasks completed autonomously after plan approval |
| Testing Approach | Very Good | Systematic screen-by-screen with multiple interaction types |
| Effort Accuracy | Good | Estimated 8-10h, actual ~6-8h. sqlite3 fix was unplanned |
| Planning Quality | Very Good | GO/NO-GO gate for Task B before Task C was correct |
| Model Assignments | Very Good | Haiku handled all tasks; no escalation needed |
| Communication | Good | Should have notified user before interactive testing |
| Requirements Clarity | Very Good | Acceptance criteria well-defined and measurable |
| Documentation | Very Good | Comprehensive evaluation report created |
| Process Issues | Minor | Metadata update was silently skipped; now fixed |
| Risk Management | Very Good | Script replay limitation documented honestly |
| Next Sprint Readiness | Very Good | B1 MSIX bug fully documented with fix plan |

---

## Improvements Implemented

| # | Improvement | Status |
|---|------------|--------|
| 1 | Coordinate interactive testing — notify user before/after winwright interactions | [OK] Feedback memory saved |
| 2 | Mandatory metadata update with 3-attempt escalation in /startup-check and /memory-restore | [OK] Implemented in skills |
| 3 | Pre-build native_assets cleanup in build-windows.ps1 | [OK] Added to build script |
| 4 | winwright selector quick reference (WINWRIGHT_SELECTORS.md) | [OK] Created |

---

## Metrics

- **Tests**: 1170 passing, 28 skipped, 1 pre-existing failure (yaml roundtrip - unrelated)
- **Analyze**: 0 issues
- **New files**: 6 (enable-screen-reader-flag.ps1, ww-test-helper.sh, smoke_navigation.json, SPRINT_27_PLAN.md, SPRINT_27_ACCESSIBILITY_EVALUATION.md, WINWRIGHT_SELECTORS.md)
- **Docs updated**: 8 (CHANGELOG, CLAUDE.md, ARCHITECTURE, TESTING_STRATEGY, ALL_SPRINTS_MASTER_PLAN, TROUBLESHOOTING, build-windows.ps1, skill files)
- **Issues created**: 4 (#218 B1 MSIX crash, #219 F49, #220 F50, #221 F51)
- **Bugs found during testing**: 0 (all screens functional)
