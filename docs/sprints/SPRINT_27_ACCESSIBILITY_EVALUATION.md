# Sprint 27 - Task B: Flutter Desktop Accessibility Tree Evaluation

**Date**: 2026-03-30
**Evaluator**: Claude Code (Haiku)
**Tool**: civyk-winwright v2.0.0
**App**: MyEmailSpamFilter v0.5.1 [DEV] (Flutter Windows Desktop)

---

## Executive Summary

**GO** - civyk-winwright can effectively automate the Flutter Windows Desktop app. The accessibility tree exposes rich element information including buttons, text, checkboxes, sliders, edit fields, and tabs with descriptive labels. Navigation and click interactions work reliably.

---

## Key Findings

### 1. Semantics Activation Requirement

**Critical Discovery**: Flutter Windows Desktop does NOT expose its semantics tree by default. The FLUTTERVIEW pane appears as a single opaque element with zero children.

**Solution**: Setting the Windows `SPI_SETSCREENREADER` system parameter flag activates Flutter's accessibility bridge. Once enabled, the full widget tree becomes available through UIA3.

**Implementation**: A PowerShell script (`mobile-app/scripts/enable-screen-reader-flag.ps1`) was created to toggle this flag. This must run BEFORE winwright can interact with the Flutter content area.

**Impact**: Low. The flag can be set programmatically at the start of any test session. It does not start an actual screen reader - it only signals to Flutter that one is active.

### 2. Element Discoverability

| Element Type | Discoverable | Label Quality | Notes |
|-------------|-------------|---------------|-------|
| Buttons | Yes | Excellent | Names match visible text (e.g., "Back to Accounts", "Start Scan") |
| Text/Labels | Yes | Excellent | Full text content exposed including multi-line |
| Tabs | Yes | Good | Shows "Tab N of M" format (e.g., "General\nTab 1 of 4") |
| CheckBoxes | Yes | Excellent | Full label text (e.g., "Read-Only Mode\nNO changes to emails...") |
| Sliders | Yes | Good | Current value shown (e.g., "7 days") |
| Edit fields | Yes | Partial | Type=Edit exposed but value/label may be empty |
| Groups | Yes | Good | Many have descriptive names (e.g., "Scan Mode\nActive: Processing safe senders and rules") |
| Lists/ScrollViews | Yes | Good | Email list items exposed as individual Buttons with full text |
| AppBar actions | Yes | Excellent | All action buttons named clearly |

### 3. Selector Syntax

Working selector format: `type=ControlType[name='Element Name']`

Examples that work:
- `type=Button[name='Back to Accounts']` - exact name match
- `type=Button[name='Settings']` - simple name match
- `type=Text[name*='Manual Scan']` - partial name match (contains)

Note: Elements have no `automationId` values (Flutter does not set these via MSAA). All selection must use `name` or `type` properties.

### 4. Interaction Capabilities Verified

| Action | Result | Notes |
|--------|--------|-------|
| Click button | OK | Navigation, tab switching, all work |
| Read text | OK | Full text content in dump_tree output |
| Navigate screens | OK | Clicked through 5+ screens successfully |
| Tab switching | OK | Clicked tab Text elements to switch tabs |
| Inspect tree | OK | Both `inspect` CLI and MCP `ww_dump_tree` work |
| NLP find | OK | `ww_find_by_description` with Jaccard scoring works well |

### 5. Screens Evaluated

| Screen | Elements Found | Interactive | Notes |
|--------|---------------|-------------|-------|
| Account Selection | 12+ | 8 | Account cards, Start Scan, Delete, Add Account |
| Scan Results | 50+ | 25+ | Full email list as Buttons, filter chips, stats |
| Scan History | 30+ | 5 | History entries as Text blocks, filter buttons |
| Settings (General) | 15+ | 8 | Rules management buttons, history retention |
| Settings (Manual Scan) | 25+ | 12 | CheckBoxes, Slider, folder management, export |

### 6. Limitations Observed

1. **No automationId**: Flutter MSAA bridge does not set UIA AutomationId. Selectors rely on `name` which can change with UI text updates.
2. **Deeply nested Groups**: The tree has 5-6 levels of unnamed Group wrappers before reaching meaningful elements. Not a blocker but adds noise.
3. **Screen reader flag must be set**: Tests will fail without the SPI_SETSCREENREADER flag. Must be automated in test setup.
4. **Snapshot format lacks names**: `ww_get_snapshot` returns bounds/roles but not names. Use `ww_dump_tree` for readable output.
5. **Tab Text elements**: Tabs show as `Text` not `Tab` control type. Selector is `type=Text[name*='Tab Name']`.

---

## Architecture for E2E Tests

### Test Setup Flow

```
1. Enable SPI_SETSCREENREADER flag (PowerShell script)
2. Build Windows app (build-windows.ps1)
3. Launch app
4. Attach winwright to process (ww_attach)
5. Run test scripts
6. Cleanup: close app, disable flag
```

### MCP Server Access Methods

Two ways to use winwright with the app:

1. **CLI** (`Civyk.WinWright.Mcp.exe inspect <pid>`) - Quick tree dumps, no session management
2. **MCP HTTP** (`serve --port 8765`) - Full interaction via JSON-RPC, supports click/type/assert/wait
3. **MCP stdio** (configured in `~/.claude/config.json`) - Direct Claude Code integration (requires restart)

### Selector Strategy

Since Flutter elements lack automationId, use this priority:
1. `type=Button[name='Exact Label']` - Best for unique buttons
2. `type=ControlType[name*='Partial']` - For elements with dynamic suffixes
3. `ww_find_by_description` - Fallback NLP-based search
4. Coordinate-based clicks (offsetX/offsetY) - Last resort

---

## Go/No-Go Decision

### GO - Proceed with Task C (Exploratory Testing)

**Rationale**:
- All major UI element types are discoverable and interactive
- Navigation between screens works reliably
- The semantics activation requirement is a one-time setup cost
- Label quality is excellent — most elements have clear, descriptive names
- winwright provides both CLI and MCP access patterns
- The lack of automationId is manageable with name-based selectors

### Risks to Monitor
- Name-based selectors are fragile to UI text changes (mitigated by test maintenance)
- Complex interactions (drag-and-drop, long-press) not yet tested

---

## Task C: Exploratory Testing Results (2026-03-30)

### Screens Tested (Complete)

All 8 major screens were systematically tested with stable results:

| Screen | Navigation | Elements | Interactions Verified |
|--------|-----------|----------|----------------------|
| Account Selection | OK | 12+ | Click account, click buttons |
| Manual Scan | OK | 10+ | Read status, button labels |
| Scan Results | OK | 50+ | Filter chips, email list items |
| Scan History | OK | 30+ | Filter buttons, history entries |
| Settings - General | OK | 15+ | Tab switching, Rules/History buttons |
| Settings - Account | OK | 5+ | Folder settings buttons |
| Settings - Manual Scan | OK | 25+ | CheckBoxes, Slider, folder chips |
| Settings - Background | OK | 20+ | Enable checkbox, frequency button |
| Manage Safe Senders | OK | 500+ | Search input, filter chips, pattern list |
| Manage Rules | OK | 3300+ | Search input, filter chips, rule list |
| Add Account | OK | 8+ | Provider buttons, help text |

### Interactions Verified

| Interaction | Status | Notes |
|------------|--------|-------|
| Button click (InvokePattern) | OK | Works for most buttons |
| Button click (mouse) | OK | Required for Flutter TabBar tabs |
| Tab switching | OK | Must use `useInvokePattern: false` |
| Text input (ww_type) | OK | Search field on Safe Senders filtered from 505 to 36 |
| Dialog interaction | OK | Account selection modal detected and clickable |
| Assertion (exists) | OK | `ww_assert` with `exists` works |
| NLP search | OK | `ww_find_by_description` with Jaccard scoring |
| Navigation (multi-step) | OK | 5+ step sequences complete reliably |

### Key Findings from Exploratory Testing

1. **Tab switching requires `useInvokePattern: false`**: Flutter TabBar tabs are rendered as `Text` elements, not `Tab` controls. InvokePattern does not trigger tab changes — a mouse click at element coordinates is required.

2. **Settings screen triggers account selection dialog**: When navigating to Settings from Account Selection, a "Select Account" dialog appears if no account is currently selected. Tests must handle this dialog.

3. **Screen reader flag persistence**: The `SPI_SETSCREENREADER` flag persists across app restarts but resets on Windows reboot. Test setup should always verify/set this flag.

4. **App closes when testing**: The app may close if the "Exit Application" button is accidentally clicked or if a destructive action occurs. Test scripts should verify app is running before each test.

### Script Replay Limitation

The `winwright run` command for script replay was tested but could not be made to work. The CLI `run` command silently fails with "0 total" steps, suggesting the JSON script schema differs from the MCP tool argument format. Without documentation on the expected script format, replay scripts cannot be created reliably.

**Workaround**: Use the MCP HTTP server (`serve --port 8765`) for interactive testing via JSON-RPC calls. This works reliably and can be scripted via shell/PowerShell scripts that make curl calls.

### Bugs Found

No application bugs were found during exploratory testing. All screens rendered correctly and all controls were interactive.

### Files Created

- `mobile-app/scripts/enable-screen-reader-flag.ps1` — Toggle SPI_SETSCREENREADER flag
- `mobile-app/scripts/ww-test-helper.sh` — Shell helper for MCP JSON-RPC calls
- `mobile-app/test/e2e/smoke_navigation.json` — Test script (non-functional with `run` command)
