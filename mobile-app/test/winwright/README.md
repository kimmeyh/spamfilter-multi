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

## Test Scripts (current set)

> **F100 (Sprint 43): the 6 read-only scripts were RETIRED.** Their coverage now lives in the in-VM
> `integration_test` lane at `mobile-app/integration_test/read_only_flows_test.dart` (navigation /
> settings-tabs / scan-history / text-selection / F25 rule-test / F35 rule-edit), which drives the real
> widget tree with `pumpAndSettle()` -- no out-of-process selector-settle flakiness, no live-window
> dependency. The retired scripts were `test_navigation`, `test_settings_tabs`, `test_scan_history`,
> `test_text_selection`, `test_f25_rule_test_tool`, and `test_f35_rule_edit`. See ALL_SPRINTS_MASTER_PLAN.md
> F100 and docs/TESTING_STRATEGY.md (two-harness section).

Sprint 51 (F129) added 3 read-only scripts covering the Sprint-50-touched surfaces. These DO run in the
default sweep and pass green with zero DB drift (verified 2026-07-28):

| Script | Purpose | Origin |
|--------|--------|--------|
| `test_f129_no_rule_review.json` | MT-3 entry point + account filter chips + reload path on the Review "No Rule" screen | S51 F129 (new) |
| `test_f124_rule_labels.json` | F124: Manage Rules category/sub-type display -- row accessible names, the details dialog's labelled `Category`/`Sub-Type` fields and their values, and all 7 filter chips (each paired with the `Clear` button that exists only while a filter is active) | S51 F129 (new) |
| `test_mt2c_no_rule_sweep.json` | MT-2c: the covered-item sweep is idempotent across an in-place Refresh AND a full screen re-entry -- named rows must SURVIVE (guards over-collection, the Sprint 50 bug shape) | S51 F129 (new) |

The create/lifecycle flows below are kept as the F99 reference and remain EXCLUDED from any default
sweep -- their reliable unattended execution lives in `integration_test`:

| Script | Purpose | Origin |
|--------|--------|--------|
| `test_f37_folder_selector.json` | F37: open Safe Sender + Deleted Rule folder pickers (no selection change) -- EXCLUDED from default sweep (dialog-settle race -> F99) | S40 (new) |
| `test_f56_create_block_rule.json` | F56: create TLD block rule (`museum`), delete it (net zero DB drift) -- EXCLUDED from default sweep (F99) | S41 F97 (new) |
| `test_f56_create_safe_sender.json` | F56: create Entire Domain safe sender (`winwright-test.com`), delete it (net zero DB drift) -- EXCLUDED from default sweep (F99) | S41 F97 (new) |

> **Note on the F56 scripts (CORRECTED 2026-07-31, Sprint 52 F131)**: the Sprint 51 note here said the
> radios "do not select" and that the create path "is not drivable". **Both claims were wrong, and the
> cause was a bad selector, not the app.** Sprint 41 had documented a workaround of clicking the parent
> `Group` (`type=Group[name*='Top-Level Domain']`); Sprint 51 followed it, saw nothing happen, and
> generalised that to "radios cannot be selected". Clicking a `Group` hits a container with no selection
> behavior. Targeting the **`RadioButton` itself** with `useInvokePattern: false` works -- verified live
> 2026-07-31: the input's name flips from `Enter email, domain, or URL` to `Enter TLD (...)`, and the
> confirm dialog reads `Type: Top-Level Domain / Source: *.museum`. `ww_invoke` correctly *fails* on a
> radio (`does not support InvokePattern`) because radios expose `SelectionItemPattern` -- that is proper
> UIA behavior, not a defect.
>
> What remains true is narrower: these two scripts are **still EXCLUDED from the default sweep**, because
> the script runner skips `ww_wait` and rejects `ww_assert` and therefore cannot bridge a Flutter
> dialog-settle boundary. Run explicitly via `-TestName f56` and a step will succeed while the *next*
> selector resolves 0 elements (observed 2026-07-31 at `Button[name='Save']` and `Edit[name*='Enter TLD']`).
> That is a **runner limitation, not an app defect** -- do not read a failure of these scripts as a
> regression. Reliable execution of the lifecycle belongs in `integration_test` (F99), which has
> `pumpAndSettle`. `test_mt2c_no_rule_sweep.json` still asserts sweep *stability* against the existing
> rule set, and the sweep-with-a-new-rule contract stays covered deterministically in
> `test/ui/screens/no_rule_review_screen_test.dart`.

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

## Sprint 51 Execution Notes (F129, 2026-07-28)

### Which tool to use for which control (the rule that makes scripts pass)

Established by three consecutive failing runs on 2026-07-28 and then proven by a green sweep. Getting
this wrong is the single biggest cause of "the selector resolved but nothing happened".

| Control | Tool | Why |
|---|---|---|
| `Button` (incl. `OutlinedButton`, `IconButton`, FAB, dialog buttons) | **`ww_invoke`** | `ww_click` reported success WITHOUT activating controls on a cold-launched app |
| TabBar tab (projects as `Text`) | `ww_click` + `useInvokePattern: false` | tabs need a real mouse press |
| Static `Text` label | `ww_click` + `useInvokePattern: false` | `Element does not support InvokePattern. ControlType: Text` |
| `CheckBox` | `ww_click` + `useInvokePattern: false` | exposes TogglePattern, not InvokePattern |
| `RadioButton` | `ww_click` + `useInvokePattern: false` **on the RadioButton itself** | exposes `SelectionItemPattern`, not `InvokePattern`, so `ww_invoke` correctly fails. Do **not** target the parent `Group` -- a Group is a container with no selection behavior (corrected Sprint 52 F131) |

**A mid-sprint claim that `useInvokePattern: true` "reports success without activating the widget" was
tested and NOT reproduced as stated, and is withdrawn** -- with the default flag, `Manage Rules` opened,
the `Background` tab switched, and a No-Rule checkbox toggled. The accurate statement is the table
above: prefer `ww_invoke` for Buttons because it proved reliable from a cold launch, and fall back to
the mouse path only for the control types that cannot accept InvokePattern.

### Three harness behaviours that silently break scripts

1. **Flutter builds its UIA semantics tree LAZILY, in response to a query -- not on a timer.** On a
   freshly launched app the first tree query returns an opaque single `FLUTTERVIEW` pane with no
   children; the second returns the full tree. **A 10-second wait does not help**, because waiting is
   not the trigger. Start every script with `ww_window_state` -- it doubles as the priming query.
2. **`ww_invoke` does not verify visibility.** It happily reports success on an **off-screen** element
   without pressing it (observed on `Save Rule` below the fold). `ww_click` correctly errors
   `element_offscreen`. Always `maximize` first.
3. **A step reporting success proves DISPATCH, not effect.** Since the runner cannot replay
   `ww_assert*`, the only in-script proof is a **following step that can only resolve if the app
   actually advanced** -- a control that exists solely on the next screen, or a `Clear` button that
   renders only while a filter/selection is active. Author every navigation as such a pair; otherwise a
   green run proves reachability, never behaviour.

### Controls that resist automation on this build (do not sink time into them)

- ~~**The Add-Block-Rule `Rule Type` RadioButtons do not select.**~~ **RETRACTED 2026-07-31 (Sprint 52,
  F131) -- this was a selector bug, not an app limitation.** The Sprint 51 entry targeted the parent
  `Group`; a Group has no selection behavior, so nothing happened. `ww_click` +
  `useInvokePattern: false` on `type=RadioButton[name^='Top-Level Domain']` selects correctly (verified
  live: input name flips to `Enter TLD (...)`, confirm dialog reads `Type: Top-Level Domain`). See the
  per-control-type table above. Kept here deliberately rather than deleted: the failure mode -- reading
  "my selector did nothing" as "the app cannot do this" -- is the thing to avoid repeating.
- **The search box cannot be cleared.** `ww_type clearFirst: true` **appends** (observed `museum` +
  `gmail` -> `museumgmail`), `ww_clear` throws a COM `HRESULT` exception, and `ctrl+a`/`Delete` does not
  reach the Flutter field. Type into it at most **once** per screen visit; leaving and re-entering the
  screen resets it.
- Both of these are why the two `test_f56_*` create/delete scripts stay EXCLUDED from the default
  sweep, and why `test_mt2c_no_rule_sweep.json` deliberately asserts sweep *stability* using the
  existing rule set instead of creating a rule first.

### Semantics required for name-based selection (F129)

Rows built from a `Card`/`ListTile` project as **unnamed `Group`s** unless wrapped. The wrapper order
below was established by failing tests -- each variant was tried and rejected:

```dart
Semantics(                       // OUTER: carries the name into the UIA tree
  label: 'Select $sender',
  checked: isSelected,
  child: Tooltip(                // INNER: what actually projects to UIA
    message: 'Select $sender',
    child: Checkbox(...),        // the real control, innermost
  ),
)
```

- `Tooltip` alone -> projects, but no screen-reader label.
- `Semantics` alone -> labels the Flutter tree, does **not** reach UIA.
- `Tooltip` **wrapping** `Semantics` -> two stacked nodes; clicks land on the wrapper, control never fires.
- `explicitChildNodes: true` on the parent row -> **suppresses** the child checkbox's own node.

Applied in Sprint 51 to `no_rule_review_screen.dart` and `account_selection_screen.dart` (rows +
account-picker dialog). **`settings_screen.dart` needed no change** -- its `OutlinedButton`s already
project as named Buttons (`Manage Rules`, `Manage Safe Senders`), confirmed live 2026-07-28. The
account-picker dialog, not the Settings screen, was what previously blocked reaching Manage Rules.

**A wrapper that names a node can also make it unclickable -- check both.** The account-picker entries
went through three shapes before working, and the two broken ones each *looked* fine in a tree dump:

1. `Semantics(button:)` **without** `excludeSemantics` -> the inner `ListTile` keeps its own node, so
   the entry projects as **two stacked Buttons with the same name**. A name selector matches the outer
   wrapper, which has no handler: the click reports success and the dialog never dismisses. This is
   what shipped mid-sprint and it broke the whole Settings path.
2. Adding `excludeSemantics: true` -> collapses to one correctly named node, but **drops the
   `ListTile`'s gesture node**, so the entry becomes unclickable by automation.
3. **Working shape**: `excludeSemantics: true` **plus `onTap:` on the `Semantics` node itself**, so the
   merged node carries both the name and the action. The child keeps its own `onTap` so ordinary
   mouse/touch input is unaffected.

The lesson generalises: after adding semantics to make something *addressable*, run a script that
actually *drives* it. A tree dump proves the name exists; only an interaction proves the node still
works.

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

**Default sweep (post-F100): empty.** The 6 read-only scripts that formed the default sweep
(navigation, settings_tabs, scan_history, text_selection, f25_rule_test_tool, f35_rule_edit) were
RETIRED in Sprint 43 (F100) -- their coverage moved to `integration_test/read_only_flows_test.dart`
(in-VM `pumpAndSettle`, run via `.\scripts\run-integration-tests.ps1`). The remaining WinWright scripts
(`test_f56_*`, `test_f37_folder_selector`) cross a Flutter dialog/picker-settle boundary the WinWright
`run` script-runner cannot bridge (no `ww_wait`/`ww_assert`), so they were already EXCLUDED from the
sweep and their reliable execution lives in F99; they remain runnable explicitly (`-TestName f56` /
`-TestName f37`) as the UIA reference flows.

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
