# civyk-winwright Selector Quick Reference

**Purpose**: Quick reference for winwright selector syntax when automating the Flutter Windows Desktop app.

**Prerequisite**: The `SPI_SETSCREENREADER` flag must be enabled before winwright can see Flutter elements. Run:
```powershell
.\mobile-app\scripts\enable-screen-reader-flag.ps1 enable
```

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
