# WinWright E2E Tests for Windows Desktop App

**Sprint**: 34, F69
**Tool**: civyk-winwright v2.0.0 (`C:\Tools\WinWright\Civyk.WinWright.Mcp.exe`)
**Target**: MyEmailSpamFilter Windows Desktop (Flutter, MSAA accessibility tree)

These end-to-end tests exercise the running Windows Desktop app via Windows UI Automation. Tests are stored as JSON scripts that civyk-winwright records and replays. Each script is a sequence of inspect/click/type/wait actions.

## Prerequisites

1. **Windows desktop dev build running**:
   ```powershell
   cd mobile-app/scripts
   .\build-windows.ps1
   ```

2. **Screen reader flag enabled** (activates Flutter Semantics tree -- without this, the FLUTTERVIEW pane appears as a single opaque element):
   ```powershell
   cd mobile-app/scripts
   .\enable-screen-reader-flag.ps1 enable
   ```

3. **WinWright doctor passes**:
   ```powershell
   C:\Tools\WinWright\Civyk.WinWright.Mcp.exe doctor
   ```

## Test Scripts

| Script | Purpose | Sprint | Status |
|--------|--------|--------|--------|
| `test_navigation.json` | Click through Account Selection -> Settings -> Manage Rules -> back | 34 | New |
| `test_manual_scan_flow.json` | Run a manual scan on selected account, verify Scan Progress -> Results screens | 34 | New |
| `test_settings_tabs.json` | Cycle through all 4 Settings tabs (General, Scan, Background, Account overrides) | 34 | New |
| `test_text_selection.json` | Verify SelectionArea on Manage Rules / Manage Safe Senders / Help screens | 34 | New |
| `test_f56_create_block_rule.json` | F56: open Manage Rules, tap FAB, create TLD block rule, verify in list | 34 | New |
| `test_f56_create_safe_sender.json` | F56: open Manage Safe Senders, tap FAB, create entire-domain safe sender | 34 | New |
| `test_scan_history.json` | Open Scan History, tap most recent entry, verify counts displayed | 34 | New |

## Running Tests

**Single test**:
```powershell
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe run mobile-app/test/winwright/test_navigation.json
```

**All tests** (via wrapper):
```powershell
cd mobile-app/scripts
.\run-winwright-tests.ps1
```

## Test Recording (for adding new tests)

WinWright supports recording sessions:
```powershell
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe record --output new_test.json
# Interact with the app
# Press Ctrl+C to stop recording
```

Then refine the recorded script and add to this directory.

## F69 Acceptance Criteria

- [x] WinWright test scripts created for navigation, scan flow, settings, history
- [x] F56 rule creation E2E tests included (block rule + safe sender)
- [x] Test runner PowerShell wrapper for batch execution
- [x] Tests documented in TESTING_STRATEGY.md (Sprint 34 update)

## Known Limitations (from Sprint 27 evaluation)

1. **Screen reader flag required**: Tests fail without `SPI_SETSCREENREADER` set. Wrapper script enables it before running.
2. **No automationId**: Flutter MSAA bridge does not expose UIA AutomationId. All selectors use `name` or `type`.
3. **Tab elements show as Text**: Use `type=Text[name*='Tab Name']` for tab selection.
4. **Snapshot lacks names**: Use `dump_tree` (readable) instead of `get_snapshot` (bounds only).
5. **Element name changes break tests**: When renaming UI text, update affected scripts.

## Selector Patterns

Working selector format: `type=ControlType[name='Element Name']`

Common patterns:
- `type=Button[name='Start Scan']` -- exact match
- `type=Button[name*='Settings']` -- contains match
- `type=Text[name*='Manage Rules']` -- partial text match
- `type=CheckBox[name*='Read-Only Mode']` -- checkbox by partial label

See ADR-0037 for the project-wide Semantics labeling standard that makes these selectors stable.
