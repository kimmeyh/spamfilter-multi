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
| `test_navigation.json` | Click through Account Selection -> Settings -> Manage Rules -> back | 34 | PASS (S35) |
| `test_manual_scan_flow.json` | Run a manual scan on selected account, verify Scan Progress -> Results screens | 34 | PASS (S35) |
| `test_settings_tabs.json` | Cycle through all 4 Settings tabs (General, Account, Manual Scan, Background) | 34 | PASS (S35) |
| `test_text_selection.json` | Verify SelectionArea on Manage Rules / Manage Safe Senders / Help screens | 34 | PASS (S35) |
| `test_f56_create_block_rule.json` | F56: full lifecycle -- create `.museum` TLD block rule, verify in list, delete, verify removed | 34 | PASS (S35) |
| `test_f56_create_safe_sender.json` | F56: full lifecycle -- create `winwright-e2e-test.invalid` safe sender, verify, delete, verify removed | 34 | PASS (S35) |
| `test_scan_history.json` | Open Scan History, tap most recent entry, verify counts displayed | 34 | PASS (S35) |

## Sprint 35 Execution Notes (F69 closeout)

All 7 scripts validated against a fresh Windows desktop dev build on 2026-04-19, driven via WinWright MCP primitives (`mcp__winwright__ww_*`) rather than the JSON `run` command. The JSON files document the test intent; the MCP-driven execution uses the same selectors/assertions interactively. Findings:

- **Settings header button opens Account Selection dialog first** (per `_openSettings()` design — "Settings requires accountId"), then navigates to Settings. Scripts must dismiss/select account before reaching Settings. Not a bug; intended behavior.
- **Settings Tab 2 is "Account"** (singular), shown as `name="Account\nTab 2 of 4"`. Selectors using bare `name*='Account'` collide with the "Saved Accounts" header text on the Account Selection screen — use `name*='Tab 2 of 4'` for unambiguous tab selection.
- **Add Block Rule input field name is dynamic**: changes to "Enter TLD..." after selecting the TLD radio (was "Enter email, domain, or URL"). Use `type=Edit` selector instead of name match.
- **`Save Rule` button can be off-screen** in 1600x900 window; `ww_invoke` (UIA InvokePattern) bypasses scroll requirement.
- **Manage Rules count**: 3500 rules visible after F73 split (3055 entire-domain + 41 exact-domain + 131 exact-email + 269 TLD + a few other categories), confirms F73 monolithic-split rebuild is loaded.
- **Lifecycle update for F56 scripts**: original Sprint 34 scripts created rules but never removed them, leaving test artifacts in the dev DB. As of Sprint 35, both F56 scripts now do create -> verify -> delete -> verify-absent. Test data was retuned to avoid bundle collision: `.museum` TLD (real IANA, not on spam list) replaces `.xyz` (collided with bundled `._.xyz` from F73 split), and `winwright-e2e-test.invalid` replaces `test-trusted-domain.com` (uses RFC 6761 reserved TLD that cannot collide with any real domain).

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
