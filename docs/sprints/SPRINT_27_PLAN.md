# Sprint 27 Plan

**Sprint**: Sprint 27 - Desktop App E2E Testing with civyk-winwright
**Date**: March 29, 2026
**Branch**: `feature/20260329_Sprint_27`
**Base**: `develop`
**Estimated Total Effort**: ~8-10h

---

## Sprint Goal

Set up automated desktop app E2E testing using civyk-winwright MCP server. Evaluate Flutter accessibility tree feasibility, perform exploratory testing of all Windows Desktop screens, and document the new testing layer in project docs.

---

## Background

Playwright cannot directly test Flutter Desktop apps (Skia/Impeller rendering, not browser-based). civyk-winwright is a Playwright-inspired MCP server that provides ~59 tools for Windows desktop automation via UIA3/MSAA, including script recording/replay.

Flutter Windows exposes MSAA accessibility by default (not full UIA). civyk-winwright uses UIA3 which can bridge to MSAA. The richness of the automation tree for Flutter apps is unknown and must be evaluated first.

**Backlog item**: F11 (moved from HOLD)

---

## Tasks

### Task A: Install civyk-winwright (~1h)

**Model**: Haiku
**Execution**: Autonomous

Install civyk-winwright v2.0.0 binary, add MCP server config, verify with `winwright doctor`.

**Acceptance Criteria**:
- [x] Binary downloaded and extracted to `C:\Tools\WinWright\`
- [x] MCP server config added to `~/.claude/config.json`
- [x] `winwright doctor` passes (OS, .NET, UIA3 checks)

**Status**: [OK] Complete

### Task B: Evaluate Flutter App Accessibility Tree (~2-3h)

**Model**: Haiku
**Execution**: Autonomous

Build the Windows app, launch it, take accessibility snapshots, and evaluate what elements are discoverable.

**Acceptance Criteria**:
- [x] Windows app built and launched
- [x] Accessibility tree snapshot captured via winwright
- [x] Element discoverability documented (buttons, text fields, lists, tabs)
- [x] Basic interactions tested (click, type, navigate)
- [x] Findings documented with MSAA limitations observed
- [x] Go/no-go decision on full test scripting

**Status**: [OK] Complete
**Decision**: GO - proceed with Task C
**Key Finding**: Flutter semantics tree requires SPI_SETSCREENREADER flag to activate, but once enabled, all UI elements are richly exposed. See `SPRINT_27_ACCESSIBILITY_EVALUATION.md` for full report.

### Task C: Desktop App Exploratory Testing (~3-4h)

**Model**: Haiku
**Execution**: Autonomous

Systematically test all screens via winwright MCP tools.

**Acceptance Criteria**:
- [x] All major screens tested (account selection, setup, scan, results, settings, rules, safe senders, scan history)
- [x] Bugs documented as GitHub issues (none found - all screens functional)
- [x] Repeatable test scripts created via record/replay (if supported)
  - Script replay via `winwright run` does not work (JSON schema undocumented)
  - MCP HTTP server with curl-based scripts is the viable alternative

**Status**: [OK] Complete
**Key Findings**: All 11 screens tested successfully. Tab switching requires `useInvokePattern: false`. Text input works. No bugs found. Script replay is a limitation. See `SPRINT_27_ACCESSIBILITY_EVALUATION.md` Task C section.

### Task D: Documentation Updates (~2h)

**Model**: Haiku
**Execution**: Autonomous

Update project documentation to reflect the new testing layer.

**Acceptance Criteria**:
- [x] ALL_SPRINTS_MASTER_PLAN.md: F11 moved from HOLD, detail section updated
- [x] TESTING_STRATEGY.md: New "Automated E2E Tests (Desktop)" section
- [x] ARCHITECTURE.md: Testing layer documentation
- [x] CHANGELOG.md: Sprint 27 entries
- [x] CLAUDE.md: Updated Common Commands section
- [x] SPRINT_27_PLAN.md created (this file)
- [x] SPRINT_27_ACCESSIBILITY_EVALUATION.md: Full findings report with Task B and Task C results

**Status**: [OK] Complete

---

## Risks

| Risk | Mitigation |
|------|------------|
| Flutter MSAA tree too sparse for automation | Document limitations, evaluate Flutter web build + Playwright as fallback |
| civyk-winwright does not work with Flutter rendering | Try adding Flutter Semantics widgets; fall back to Flutter integration_test |
| winwright freeware license concern | Document in ADR; evaluate FlaUI-MCP (MIT) if needed |

---

## Tools and References

- **civyk-winwright**: v2.0.0, installed at `C:\Tools\WinWright\Civyk.WinWright.Mcp.exe`
- **GitHub**: https://github.com/civyk-official/civyk-winwright
- **License**: Freeware (closed source)
- **Alternative**: FlaUI-MCP (MIT, shanselman/FlaUI-MCP) if licensing concern arises
