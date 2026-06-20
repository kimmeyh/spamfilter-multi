# WinWright E2E Tests for Windows Desktop App

**Origin**: Sprint 34, F69. **Schema + harness migrated Sprint 40, F79 follow-up (2026-06-09).**
**Tool**: civyk-winwright (`C:\Tools\WinWright\Civyk.WinWright.Mcp.exe`)
**Target**: MyEmailSpamFilter Windows Desktop (Flutter, MSAA accessibility tree)

These end-to-end tests exercise the Windows Desktop app via Windows UI Automation. Scripts are
JSON in WinWright's `testCases` recorded-script schema (see "Script Schema" below) and are replayed
by `winwright run` via the `run-winwright-tests.ps1` harness.

## [IMPORTANT] Script Schema (current WinWright build)

The installed WinWright `run` command expects a **`testCases`-based recorded-script schema**, NOT the
legacy `{name, steps:[{action,...}]}` format the original Sprint 34 scripts used. A script is:

```json
{
  "version": "1", "appId": "", "mode": "test",
  "attachTitle": "MyEmailSpamFilter",
  "runConfig": { "captureScreenshots": false, "screenshotFormat": "png",
    "screenshotOnFailureOnly": false, "continueOnFailure": false,
    "stepTimeoutMs": 15000, "maxFailures": 0 },
  "testCases": [
    { "id": "NAV-1", "title": "...",
      "steps": [
        { "tool": "ww_click",  "selector": "type=Button[name='Settings']" },
        { "tool": "ww_invoke", "selector": "type=Button[name='Back']" }
      ] } ]
}
```

Hard-won rules for authoring (verified 2026-06-09 against the installed build):

- **`attachTitle` (or `launchPath`) is mandatory.** Omit it and `run` reports `0 total` (silent no-op)
  and `heal` fatal-errors. Use `attachTitle: "MyEmailSpamFilter"`.
- **Each step is `{ "tool": "<ww_toolname>", ...params }`** -- the tool name is the MCP tool, params are
  that tool's params (`ww_click`/`ww_invoke`/`ww_type`/`ww_set_checked` + `selector`/`text`/`check`).
- **The runner does NOT replay `ww_wait` or `ww_assert` steps** -- it skips `ww_wait` and rejects the
  `ww_assert` action schema. Do not put them in scripts. Instead:
  - **Verification is implicit**: a step's selector must resolve within `stepTimeoutMs` or the step
    errors and the test fails. A script that clicks all the way through IS the assertion that each
    screen rendered. The runner has built-in per-step waiting; no explicit waits needed.
- **Use `ww_invoke` (not `ww_click`) for Back / animating / off-screen buttons.** `ww_click` does a
  bounds-stability check and errors with "Element bounds kept changing - it may be animating" during
  screen transitions; `ww_invoke` fires the UIA InvokePattern directly and is immune.
- **`name='Close'` is ambiguous**: the window titlebar Close button and in-app dialog Close buttons
  share the name. A stray `ww_invoke type=Button[name='Close']` will close the WHOLE APP. Verify which
  one is on screen before targeting it.
- **Re-author by recording**: `ww_record` (start/test_start/.../export) emits exactly-correct schema.
  Note asserts/waits are NOT captured by record (only click/type/set_checked actions are).

## [IMPORTANT] App Lifecycle: each script runs against a FRESH app

`winwright run <script>` **closes the app under test when it finishes -- on BOTH pass and fail**
(the installed build owns the attached process lifecycle; there is no `--keep-alive` flag). Therefore
the original F79 assumption of "one long-lived app shared across all 7 scripts" is impossible -- script
#1 would close the app and #2-#7 would fail "no process".

`run-winwright-tests.ps1` handles this: before every script it **kills any stray dev-app instance and
launches a fresh one at the home screen** (`Ensure-FreshAppAtHome`), then `winwright run` attaches by
title and closes it at end-of-run. Consequences for script authors:
- **Every script starts at the home (Account Selection) screen** and should END back at home (so manual
  reruns and the implicit start-state stay consistent).
- Per-script relaunch costs ~6s x N scripts; the full 7-script sweep runs in well under the 10-min target.

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

## Test Scripts (current set -- S40 scripts all PASS sweep 2026-06-09; F56 scripts authored S41 F97, pending sweep verification)

| Script | Purpose | Origin |
|--------|--------|--------|
| `test_navigation.json` | Home -> account-scoped Settings -> Manage Rules -> back to home | S34 (ported S40) |
| `test_settings_tabs.json` | Cycle all 4 Settings tabs (General, Account, Manual Scan, Background) | S34 (ported S40) |
| `test_scan_history.json` | Open Scan History from home top-bar and return | S34 (ported S40) |
| `test_text_selection.json` | Help screen reachable; Manage Rules renders rule-pattern text (ADR-0037) | S34 (ported S40) |
| `test_f25_rule_test_tool.json` | F25: open Test-pattern tool from Manage Rules, plaintext->regex toggle, run Test | S40 (new) |
| `test_f35_rule_edit.json` | F35: open a rule's Edit screen, toggle Guided/Direct-regex mode, leave without saving | S40 (new) |
| `test_f37_folder_selector.json` | F37: open Safe Sender + Deleted Rule folder pickers (no selection change) | S40 (new) |
| `test_f56_create_block_rule.json` | F56: create TLD block rule (`museum`), delete it (net zero DB drift) -- EXCLUDED from default sweep (F99) | S41 F97 (new) |
| `test_f56_create_safe_sender.json` | F56: create Entire Domain safe sender (`winwright-test.com`), delete it (net zero DB drift) -- EXCLUDED from default sweep (F99) | S41 F97 (new) |

The **6 default-sweep scripts** (navigation, settings_tabs, scan_history, text_selection, f25, f35) are
**read-only** -- they navigate, open dialogs/screens, and back out without persisting changes, so the
pre/post DB-snapshot guard reports zero drift. `test_f37_folder_selector` is also read-only but is
EXCLUDED from the default sweep (dialog-settle race -> F99); see the exclusion note above.

The 2 F56 scripts **write then delete**: each testCase creates one row and a second testCase deletes it,
leaving net DB drift of zero. They are EXCLUDED from the default sweep and run explicitly via
`-TestName f56`. If a script fails mid-run (after create, before delete) a row will remain in the DB and
the snapshot guard will report drift -- delete the `*.museum` (block rule) / `winwright-test.com`
(safe sender) row manually from the app and re-run.

### Deferred (NOT in the current set)

- **`test_manual_scan_flow.json`**: removed -- it ran a real network scan against the live AOL inbox
  (slow, network-dependent, and mutating in non-read-only mode), unsuitable for an unattended UI sweep.
  A demo-data / read-only-mode scan smoke test is a candidate follow-up.

## Verified Selector Map

`_SELECTOR_MAP_2026-06-05.md` in this directory captures the live UIA selectors for every target screen
(Account Selection, Settings + tabs, Manage Rules, rule-details dialog, F25 Test tool, F35 Edit screen,
F37 folder pickers, Add-Block-Rule create screen) as verified on 2026-06-09, plus the canonical step
grammar and state-restore danger list. Update it when UI text changes.

## Sprint 40 Execution Notes (F79 follow-up, 2026-06-09)

The Sprint 34 scripts could not run against the installed WinWright build (schema mismatch -> `0 total`).
All scripts were re-authored to the `testCases` schema with selectors re-verified against the live UI.
Key UI actuals confirmed:

- **Settings is account-scoped**: the home top-bar `Settings` button opens an in-Flutter "Select Account"
  overlay (an `Alert` group, NOT an OS dialog -- `ww_wait mode:dialog` will not see it). Pick an account
  button (e.g. `kimmeyharold@aol.com`) to enter Settings, or `Cancel`. Intended behavior.
- **Settings tabs** use `name="<Tab>\nTab N of 4"`: `General` (1), `Account` (2), `Manual Scan` (3),
  `Background` (4). Match `name*='Account'` etc.; the `Tab N of 4` suffix disambiguates.
- **F25 Test tool** entry is the Manage-Rules top-bar `Test a pattern against sample emails` button; the
  plaintext input field's Name is `Regex pattern` but changes to `Treat input as plain text...` once the
  plaintext checkbox is checked -- target it by role (`type=Edit`) to be mode-independent.
- **F35 Edit / F25 Test** also reachable from the rule-details dialog footer (`Edit` / `Test` buttons).
  The edit screen's back button is `Go back to previous screen` and returns to Manage Rules directly
  (NOT the details dialog). `Save Changes` is below the fold -> `ww_invoke`.
- **F37 folder tree** lives on Settings > **Account** tab (`Folder Settings`): buttons
  `Safe Sender Folder` / `Deleted Rule Folder` open per-provider folder pickers whose selection
  **auto-saves** ("Changes saved automatically") -- read-only scripts must NOT click a folder RadioButton.

## Running Tests

**All tests -- F79 harness (recommended)**. The harness launches a fresh dev app per script, so you do
NOT need to pre-launch the app (it only needs a dev build present at `dist/dev/MyEmailSpamFilter-Dev.exe`):
```powershell
cd mobile-app/scripts

# Full unattended sweep with pre/post DB snapshot guard (<10 min)
.\run-winwright-tests.ps1

# Only matching tests (substring of the filename, e.g. just F37)
.\run-winwright-tests.ps1 -TestName f37

# Snapshot self-test (no running app needed -- proves FAIL path logic)
.\run-winwright-tests.ps1 -TestSnapshotOnly

# DryRun: preflight + snapshot only, no sweep
.\run-winwright-tests.ps1 -DryRun
```

The runner exits non-zero if any script fails OR if any row drifts in the `rules`,
`safe_senders`, or `app_settings` tables of the dev DB (enforces the state-restore rule).
See `mobile-app/scripts/winwright-db-snapshot.ps1` for the snapshot helper and
`docs/TESTING_STRATEGY.md` for the full cadence policy.

**Single script directly** (note: you must have the app running at home first, since the bare exe
attaches by title and the harness's per-script launch is bypassed):
```powershell
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe run mobile-app/test/winwright/test_navigation.json
```

## Adding / re-authoring tests

Record against the live app to get exactly-correct schema, then refine:
```powershell
# Via MCP (preferred): ww_record action=start -> drive the app -> action=export (attachTitle=MyEmailSpamFilter)
# or via CLI:
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe record --output new_test.json   # Ctrl+C to stop
```
Then: keep only action steps (`ww_click`/`ww_invoke`/`ww_type`/`ww_set_checked`), drop any `ww_wait`/
`ww_assert`, use `ww_invoke` for Back/animating buttons, ensure the script starts and ends at home, and
make it read-only (back out of anything that persists) so the DB-drift guard stays green.

## Visual Regression Testing -- moved to F99 (Flutter integration_test)

The Sprint 41 F76 attempt to add layout-bounds visual-regression assertions to this WinWright
sweep was **abandoned and reverted** (2026-06-17). Root cause: the standalone WinWright CLI
(`Civyk.WinWright.Mcp.exe`) cannot read element bounds. Its only commands are
`mcp | serve | run | heal | inspect | doctor`; there is no `get_attribute` command (the F76
helper invented one, so every call returned `exit 1` and baselines captured as `null`),
`inspect <pid>` JSON carries no bounds fields, and the `run` script-runner rejects
`ww_get_attribute` / `ww_assert*` ("not supported by the script runner"). `BoundingRectangle`
is reachable only via the MCP interface, which a standalone runner `.ps1` has no session for.

Visual / layout-regression detection is folded into **F99** (parallel Flutter `integration_test`
harness, pre-MVP), which provides golden-image and `RenderBox` layout assertions natively and
robustly. See `docs/ALL_SPRINTS_MASTER_PLAN.md` items F76 (why abandoned) and F99 (delivery vehicle).

## F69 / F79 Acceptance Criteria

- [x] WinWright scripts for navigation, settings tabs, scan history, text selection
- [x] F25/F35 new-UI coverage scripts (Sprint 40)
- [x] One-command runner launches the dev app per script and runs all unattended (F79 Part 1)
- [x] Pre/post DB-snapshot drift guard integrated; default sweep green with zero net DB change (F79 Part 2)
- [x] Tests documented here + cadence in TESTING_STRATEGY.md
- [x] F56 create+delete lifecycle scripts AUTHORED (S41 F97); input format confirmed live (`test_f56_*.json`). Reliable unattended EXECUTION moved to F99 (`integration_test`) -- excluded from the default sweep (`-TestName f56` to run explicitly); see ALL_SPRINTS_MASTER_PLAN.md F97/F99.

**Default sweep = 6 read-only scripts** (navigation, settings_tabs, scan_history, text_selection, f25_rule_test_tool, f35_rule_edit), all green with `DB Drift: none`. Two scripts that cross a Flutter dialog/picker-settle boundary are EXCLUDED from the default sweep and moved to F99 (`integration_test`, in-VM `pumpAndSettle`): `test_f56_*` (create/save/delete) and `test_f37_folder_selector` (folder picker's `Edit "Search folders..."` not in the UIA tree pre-settle). The WinWright `run` script-runner has no `ww_wait`/`ww_assert` primitive to bridge the settle. Both remain runnable explicitly (`-TestName f56` / `-TestName f37`) as the F99 reference flows.

## F76 (visual regression) -- ABANDONED, folded into F99

The Sprint 41 F76 layout-bounds visual-check was reverted (2026-06-17): the standalone WinWright
CLI cannot read element `BoundingRectangle` (no `get_attribute` command; `inspect` has no bounds;
the `run` script-runner rejects `ww_get_attribute`/`ww_assert*`). Visual/layout-regression detection
is delivered in F99 via Flutter `integration_test` golden-image + `RenderBox` assertions. See the
"Visual Regression Testing -- moved to F99" section above and ALL_SPRINTS_MASTER_PLAN.md F76/F99.

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
