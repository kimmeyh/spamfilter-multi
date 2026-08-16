# civyk-winwright Selector Quick Reference

**Purpose**: Quick reference for winwright selector syntax when automating the Flutter Windows Desktop app.

**Prerequisites (MUST check both, every WinWright session -- F153, Sprint 59)**:

1. The `SPI_SETSCREENREADER` flag must be enabled before winwright can see Flutter elements. CHECK FIRST, do not assume:
```powershell
.\mobile-app\scripts\enable-screen-reader-flag.ps1 status   # must print True
.\mobile-app\scripts\enable-screen-reader-flag.ps1 enable   # if False
```
   (Persistence across reboots is unverified -- it survived within-day sessions in Sprints 58-59, but a reboot may clear it. Always run `status`.)
2. **Prime the semantics tree with one `ww_get_snapshot` immediately after `ww_attach`/`ww_launch`, before any other query.** Flutter builds its semantics tree lazily on the first *semantic* query: the first raw query (`ww_dump_tree`) after app launch returns only an opaque `FLUTTERVIEW` pane even with the flag on; after one `ww_get_snapshot`, every subsequent query (including `ww_dump_tree`) returns the full tree. Verified directly in F153's Sprint 59 re-test; this lazy init is the likely cause of F140's Sprint 54 "empty tree" measurements.

---

## Selector Syntax

Selectors use the format `type=ControlType[property='value']`.

### Basic Selectors

| Selector | Matches |
|----------|---------|
| `type=Button[name='Settings']` | Button with exact name "Settings" |
| `type=Text[name^='General']` | Text starting with "General" |
| `type=Text[name*='Manual Scan']` | Text containing "Manual Scan" |
| `type=CheckBox[name*='Enable Background']` | CheckBox containing "Enable Background" |
| `type=Edit` | Any Edit (text input) field |
| `#Close` | Element with automationId "Close" (Win32 only) |
| `#TitleBar` | Title bar (Win32) |

### Property Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` | Exact match | `name='Back'` |
| `^=` | Starts with | `name^='General'` |
| `*=` | Contains | `name*='Scan'` |

### Control Types

Flutter elements map to these UIA control types:

| Flutter Widget | UIA Control Type | Notes |
|---------------|-----------------|-------|
| ElevatedButton, TextButton, IconButton | `Button` | Most interactive elements |
| Text, title text | `Text` | Also used for TabBar tabs |
| Checkbox | `CheckBox` | Full label in name property |
| Slider | `Slider` | Current value in name |
| TextField | `Edit` | Placeholder text in name when empty |
| Container groups | `Group` | Often have descriptive names |
| Window | `Window` | Top-level app window |
| Title bar buttons | `Button` | Have automationId (#Close, #Minimize-Restore, etc.) |

---

## Flutter-Specific Notes

### Tab Switching

Flutter TabBar tabs render as `Text` elements, NOT `Tab` controls. Prefer `useInvokePattern: false` to force a mouse click:

```json
{"name": "ww_click", "arguments": {
  "appId": "...",
  "selector": "type=Text[name^='Background']",
  "useInvokePattern": false
}}
```

### Which tool for which control (verified 2026-07-28, Sprint 51 F129)

| Control | Tool | Why |
|---------|------|-----|
| `Button` (any kind, incl. dialog buttons) | **`ww_invoke`** | `ww_click` reported success without activating controls on a cold-launched app |
| TabBar tab (projects as `Text`) | `ww_click` + `useInvokePattern: false` | needs a real mouse press |
| Static `Text` label | `ww_click` + `useInvokePattern: false` | `Element does not support InvokePattern. ControlType: Text` |
| `CheckBox` | `ww_click` + `useInvokePattern: false` | exposes TogglePattern, not InvokePattern |
| `RadioButton` | `ww_click` + `useInvokePattern: false` **on the RadioButton itself** | exposes `SelectionItemPattern`, not `InvokePattern`, so `ww_invoke` correctly fails. Do **not** target the parent `Group` -- a Group is a container with no selection behavior (corrected 2026-07-31, Sprint 52 F131) |

### Three behaviours that silently break scripts

1. **The semantics tree is built lazily, on query -- not on a timer.** A cold-launched app returns an
   opaque `FLUTTERVIEW` pane on the *first* tree query and the full tree on the *second*; a 10-second
   wait does not help. Start scripts with `ww_window_state`, which doubles as the priming query.
2. **`ww_invoke` does not check visibility** -- it reports success on an off-screen element without
   pressing it. `ww_click` errors `element_offscreen` instead. Maximize first.
3. **A click reporting success is not proof of effect.** `{"success": true}` means *dispatched*. The
   runner cannot replay `ww_assert*`, so the only in-script evidence is a **following step that can
   only resolve if the app actually advanced** (a control unique to the next screen, or a `Clear`
   button that renders only while a filter is active). Without that pairing, a green run proves
   reachability, never behaviour.

Full detail, including the search box that cannot be cleared and the semantics wrapper shapes that
name a node while making it unclickable: `mobile-app/test/winwright/README.md` (Sprint 51 notes).

### Scrolling and patterns: what actually works (F153 re-test, Sprint 59 -- SUPERSEDES F140's Sprint 54 negative result)

F140 (Sprint 54) concluded that Flutter exposes no UIA patterns at all and that off-screen content is unreachable. **The F153 re-test (2026-08-15, flag enabled + tree primed from the start) refutes the practical conclusion.** F140's measurement was likely confounded twice: the `SPI_SETSCREENREADER` flag was apparently never actually enabled during the original spike, and the lazy-semantics-init behavior (see Prerequisites above) makes the first query look empty even with the flag on.

Verified capabilities (each tested directly against the running dev app):

- **`ww_invoke` works on Buttons** -- pure `InvokePattern` dispatch (no mouse fallback in that tool), succeeded on AppBar buttons repeatedly. Consistent with the Sprint 51 table above; F140's "not even InvokePattern" claim is wrong.
- **`ww_scroll` mode=direction WORKS and the direction is correct** (`down` advances the document). Tested on the Help screen; content visibly moved and element bounds updated live. Sprint 58's observed direction-inversion did not reproduce. Selector for the scroll container: `type="Pane"`.
- **Each direction-mode call moves only ~165px regardless of `amount` (line vs page)** -- reaching content far down a long page (Help is ~6000px) takes many repeated calls. Works, but budget for it. Use a known element's live `bounds.y` (via `ww_dump_tree` with a selector) as the position probe between calls.
- **Off-screen elements ARE in the tree**, with real out-of-viewport bounds and `isOffscreen: true` -- the entire Help Column is queryable without any scrolling. Finding/reading a value never requires scroll-to-reach; only *clicking* does (`ww_click` refuses off-screen targets; `ww_invoke` does not check -- see behavior 2 above).
- **The F140 poster-child gap is closed**: `Version 0.8.0 [DEV]` on Settings > General was read directly via `ww_dump_tree` (`name*="Version 0.8"`, `isOffscreen: false`) -- the version text now sits at the TOP of the tab (the F140-era duplicate-near-top mitigation), and the whole General tab fits the default window with its bottom element (`Go to View Scan History`) already on-screen. Release verification (F139) can automate the version read instead of requiring a Harold visual check.

Verified residual gaps (do NOT use these):

- **`ww_scroll` mode=into_view is broken on Flutter, two ways**: by `handleId` it throws `PropertyNotSupportedException` (Flutter elements do not support the `RuntimeId` UIA property, which that path requires); by `selector` it returns `{"success": true, "method": "none"}` while moving NOTHING -- a false success. Use direction mode instead.
- **`ww_scroll` mode=find_target is a tree lookup, not a scroll, on these screens**: since Flutter exposes whole subtrees up front, it returns `found: true, stepsRequired: 0` for content thousands of px below the fold. Fine for existence checks; proves nothing about visibility.
- `ww_dump_tree includePatterns: true` still prints no pattern annotations -- pattern *reporting* is incomplete even though pattern *invocation* works. Do not infer capability from the dump; test the verb.

The F145 caution below (WinWright geometry can misreport during animated transitions -- never assert scroll-target correctness from snapshots) remains fully in force.

### WinWright can produce a FALSE FAILURE, not just a blind spot (F145, Sprint 55)

F140 established that WinWright cannot read scroll patterns at all. F145's Tooling-Capability Pre-Flight spike (per `SPRINT_PLANNING.md`, run live against the app per Harold's explicit "try WinWright first" instruction) found something worse: WinWright's `bounds`/`visible` reporting is not merely blind to scroll position -- it actively **misreported** a correct deep-link as broken.

Sequence: `ww_attach` to a running dev build, `ww_click` the real Help icon on the Select Account screen (`selector: name=Help`), then `ww_get_snapshot`. The snapshot showed "Account Setup" (the SECOND Help section) as the topmost `visible: true` text, with "Select Account" (the correct target) reported `visible: false` above the viewport -- i.e., WinWright reported the deep-link landed one section too far. A deterministic `flutter_test` cross-check of the identical scenario (`HelpScreen(initialSection: HelpSection.selectAccount)`, `tester.getTopLeft`) proved the deep-link was actually CORRECT: the target section's title Y exactly matched the Scrollable's top Y.

**Conclusion**: for element geometry/visibility on a Flutter Windows app, WinWright's snapshot can disagree with the actual rendered state -- most likely because its snapshot is taken against a UIA tree that has not caught up with an animated transition (`Scrollable.ensureVisible`'s 300ms scroll) at the moment WinWright reads it, with no settle/wait primitive to bridge that gap (the same class of gap F131/F99 already found for dialogs). A regression test built on this signal would have reported a FALSE FAILURE for correct app behavior -- worse than a false pass, since it erodes trust in the whole suite. **Do not use WinWright to assert scroll-target correctness, even via bounds/visible as an indirect proxy** -- use `integration_test` (`tester.getTopLeft` against the Scrollable's own top) instead, which is what F145's `help_deep_link_test.dart` does.

Ironically, this same investigation surfaced a REAL bug the WinWright false-positive was standing in front of: `HelpScreen._scrollTo` computed its target offset while preceding sections' async `FutureBuilder` content had not yet resolved (still showing a 14px loading placeholder instead of real, taller content), landing the target increasingly short of the viewport top the further down the page it was (confirmed via `integration_test`: not the ~26px WinWright's false report suggested, but up to ~4000px short for the last section). Fixed by retrying the scroll after content settles (`help_screen.dart`, bounded 2-frame retry). See `integration_test/help_deep_link_test.dart` for the full regression suite (22 HelpSection cases + 3 conditional-resolution cases + the null-section no-op case).

### No automationId

Flutter's MSAA bridge does NOT set UIA `AutomationId` on elements. All selection must use `name` or `type` properties. The `#id` selector only works for Win32 elements (title bar, minimize/maximize/close buttons).

### Multi-line Names

Some elements have multi-line names (e.g., tabs show "General\nTab 1 of 4"). Use `name^='General'` (starts with) to match the first line.

### Dialog Detection

Modal dialogs appear as a `Group` with `name='Alert'`:
```
[Group] name="Alert"
  [Text] name="Select Account"
  [Button] name="KIMMEYHAROLD@AOL.COM"
  [Button] name="Cancel"
```

---

## MCP HTTP Server Usage

### Start Server
```bash
"C:/Tools/WinWright/Civyk.WinWright.Mcp.exe" serve --port 8765
```

### Initialize Session
```bash
curl -s -i -X POST http://localhost:8765/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
# Extract Mcp-Session-Id header from response
```

### Attach to Running App
```bash
curl -s -X POST http://localhost:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ww_attach","arguments":{"processId":PID,"appId":"app"}}}'
```

### Common Operations

**Click a button:**
```bash
ww_call "ww_click" '{"appId":"...","selector":"type=Button[name='"'"'Settings'"'"']","useInvokePattern":false}'
```

**Dump accessibility tree:**
```bash
ww_call "ww_dump_tree" '{"appId":"...","format":"text","maxDepth":15,"maxElements":200,"compact":true}'
```

**Type text:**
```bash
ww_call "ww_type" '{"appId":"...","selector":"type=Edit","text":"search term"}'
```

**Assert element exists:**
```bash
ww_call "ww_assert" '{"appId":"...","selector":"type=CheckBox[name*='"'"'Enable Background'"'"']","assertion":"exists"}'
```

**NLP search (when selector unknown):**
```bash
ww_call "ww_find_by_description" '{"appId":"...","description":"back accounts button"}'
```

---

## CLI Usage

```bash
# Quick tree dump (no session needed)
"C:/Tools/WinWright/Civyk.WinWright.Mcp.exe" inspect PID

# Environment check
"C:/Tools/WinWright/Civyk.WinWright.Mcp.exe" doctor
```

---

## Screen Reader Flag

The flag persists across app restarts but resets on Windows reboot.

```powershell
# Enable (required before winwright can see Flutter elements)
.\mobile-app\scripts\enable-screen-reader-flag.ps1 enable

# Check status
.\mobile-app\scripts\enable-screen-reader-flag.ps1 status

# Disable (cleanup after testing)
.\mobile-app\scripts\enable-screen-reader-flag.ps1 disable
```
