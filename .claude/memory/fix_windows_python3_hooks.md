---
name: Windows python3 hook error fix
description: Claude Code plugin hooks fail with "Python was not found" on Windows 11 — fix is python3→python in plugin hooks.json files
type: reference
---

## Problem

Claude Code plugin hooks call `python3` on Windows 11, which resolves to the Microsoft Store stub at `C:\Users\kimme\AppData\Local\Microsoft\WindowsApps\python3.exe`. This stub prints "Python was not found; run without arguments to install from the Microsoft Store..." and fails all hook invocations (PreToolUse, PostToolUse, Stop, UserPromptSubmit).

Meanwhile, `python` works fine and is the standard on Windows when Python 3.x is installed.

## Root Cause

The Microsoft Store app execution alias for `python3.exe` takes precedence when Windows resolves the command from non-bash contexts (e.g., hook runners invoked via CreateProcess). Real Python installations at `C:\devtools\python\` exist but are shadowed.

## Solution (Applied 2026-04-27)

Replace `python3` with `python` in all plugin hook configs:

**Files to fix** (10 edits total):
- `C:\Users\kimme\.claude\plugins\marketplaces\claude-plugins-official\plugins\hookify\hooks\hooks.json` (4 hooks: PreToolUse, PostToolUse, Stop, UserPromptSubmit)
- `C:\Users\kimme\.claude\plugins\cache\claude-plugins-official\hookify\unknown\hooks\hooks.json` (4 hooks: same)
- `C:\Users\kimme\.claude\plugins\marketplaces\claude-plugins-official\plugins\security-guidance\hooks\hooks.json` (PreToolUse)
- `C:\Users\kimme\.claude\plugins\cache\claude-plugins-official\security-guidance\unknown\hooks\hooks.json` (PreToolUse)

**Example diff**:
```json
// Before
"command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.py"

// After
"command": "python ${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.py"
```

## Verification

```powershell
# Test the fix
python C:\Users\kimme\.claude\plugins\marketplaces\claude-plugins-official\plugins\hookify\hooks\userpromptsubmit.py
# Should exit 0 with empty JSON response (no errors)
```

## Session Caching Caveat

Plugin hook configs are loaded at Claude Code session start and cached in memory. Edits to disk files take effect on the next **Claude Code restart**, not on the next conversation. If you see hook errors in a session after applying this fix, restart Claude Code to reload hooks from disk.

## Long-term Fix Options

1. **This fix** (durable): Edit the 4 hooks.json files to use `python` (10 files, 2 locations). Plugin updates will revert this; re-apply after major plugin updates.

2. **OS-level fix** (permanent): Disable the Microsoft Store app execution alias for `python3.exe`:
   - Settings → Apps → Advanced app settings → App execution aliases
   - Toggle off `python3.exe`
   - This prevents the stub from ever shadowing real Python installs

## Reference

- Fixed in Sprint 37 Session 1 (2026-04-27)
- Carry-in: May re-occur if plugins update their hooks.json files
