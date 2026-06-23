# Bug Report: npx-based plugin MCP servers fail to connect on Windows (`spawn EINVAL`)

## Summary

On Windows, every plugin/MCP server configured to launch via the bare command
`npx` fails with **"Failed to connect"**. The underlying cause is a Node.js
child-process spawn throwing `EINVAL` because Claude Code spawns `npx` directly
(without a shell), and on Windows `npx` resolves to `npx.cmd` — a batch shim that
modern Node.js refuses to spawn directly for security reasons (CVE-2024-27980).

This is **not** an environment-specific misconfiguration on my machine. It will
reproduce for any Windows user running a recent Node.js (>= 18.20.2 / >= 20.12.2,
and all Node 22.x) with any MCP server whose config uses `"command": "npx"` —
which includes the official-marketplace `context7` and `playwright` plugins.

## Impact

- **Scope:** All Windows users of MCP servers launched via bare `npx`.
  The two official-marketplace plugins shipping this config (`context7`,
  `playwright`) are affected out of the box.
- **Symptom:** `claude mcp list` shows the server as `✘ Failed to connect`.
  The `/mcp` panel may also surface a 30s connection timeout, which is a
  misleading secondary symptom (see "Note on the timeout symptom" below).
- **Severity:** High for affected users — the server never works, and the error
  message ("Failed to connect" / "connection timed out") points away from the
  real cause, so users cannot self-diagnose.

## Environment

| Component | Version |
|-----------|---------|
| Claude Code | 2.1.177 |
| OS | Windows 11 (10.0.26200.8524) |
| Node.js | v22.9.0 |
| npm | 11.4.2 |
| npx | 11.4.2 |

`npx` install layout (typical Windows Node install):

```
C:\devtools\nodejs\npx        <- extensionless shim (used by Git Bash)
C:\devtools\nodejs\npx.cmd    <- the actual Windows executable shim
C:\devtools\nodejs\npx.ps1    <- PowerShell shim
```

When Claude Code spawns `npx` directly (no shell) on Windows, the OS/Node
resolves it to `npx.cmd`. Node then refuses to spawn the `.cmd` file directly.

## Affected configuration (as shipped)

`context7` plugin `.mcp.json`:

```json
{
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  }
}
```

`playwright` plugin `.mcp.json`:

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest"]
  }
}
```

Any user MCP config of the same shape (`"command": "npx"`) is equally affected.

## Root cause

Since Node.js 18.20.2 / 20.12.2 (the CVE-2024-27980 fix), `child_process.spawn`
**throws `EINVAL` when asked to spawn a `.cmd` or `.bat` file without
`shell: true`.** On Windows, `npx` is `npx.cmd`, so a direct
`spawn("npx", args)` hits exactly this restriction.

Minimal, deterministic reproduction (no Claude Code required — pure Node):

```js
const { spawnSync } = require("child_process");

// FAILS: direct spawn of the .cmd shim
let r = spawnSync("npx.cmd", ["--version"], { stdio: "pipe" });
console.log("direct npx.cmd ->", r.error ? r.error.code : "ok", (r.stdout||"").toString().trim());
// direct npx.cmd -> EINVAL

// WORKS: route through cmd.exe
r = spawnSync("cmd", ["/c", "npx", "--version"], { stdio: "pipe" });
console.log("cmd /c npx   ->", r.error ? r.error.code : "ok", (r.stdout||"").toString().trim());
// cmd /c npx   -> ok 11.4.2
```

Observed output on the environment above:

```
direct npx.cmd -> EINVAL
cmd /c npx   -> ok 11.4.2
```

The `EINVAL` at spawn time is what Claude Code surfaces as "Failed to connect":
the server process never starts, so the MCP handshake never begins.

Corroborating evidence that this is a `.cmd`-spawn problem, not a package or
network problem:
- The `serena` and `winwright` MCP servers on the same machine connect fine —
  both launch a real `.exe` on PATH (`serena-mcp-server`, `Civyk.WinWright.Mcp.exe`),
  not a `.cmd` shim.
- `npx -y @upstash/context7-mcp --help` and `npx @playwright/mcp@latest --help`
  both run fine **from a shell** (Git Bash / cmd), because the shell resolves
  and executes the `.cmd` shim. The failure only appears on **direct, shell-less
  spawn**, which is how Claude Code launches MCP servers.

## Steps to reproduce

1. On Windows 11 with Node.js >= 18.20.2 (e.g. Node 22.x), install the official
   `context7` or `playwright` plugin (or configure any MCP server with
   `"command": "npx"`).
2. Run `claude mcp list`.
3. Observe `✘ Failed to connect` for the npx-based server(s).

## Expected behavior

npx-based MCP servers connect successfully on Windows, the same as on macOS/Linux.

## Suggested fix (in Claude Code itself)

The durable fix belongs in Claude Code's MCP process spawner, so that **every**
user's npx-based server works without each plugin author special-casing Windows.

When launching a stdio MCP server on Windows where `command` resolves to a
`.cmd`/`.bat` shim (the common case: `npx`, `npm`, `pnpm`, `yarn`), Claude Code
should either:

- **Option A (preferred):** spawn with `shell: true` on Windows, or
- **Option B:** rewrite the launch to `cmd.exe /c <command> <args...>`, or
- **Option C:** prefer the `.cmd` extension and set `shell: true` (Node requires
  the shell for `.cmd` regardless of explicit extension).

Node's own guidance after CVE-2024-27980 is to pass `shell: true` (or invoke via
`cmd /c`) when the target is a batch shim — so Option A aligns with upstream.

A secondary improvement: when a spawn throws `EINVAL` on Windows for a `.cmd`
target, surface a clearer error than "Failed to connect" / "connection timed
out" (e.g. "Windows could not launch '<cmd>' directly; this usually means the
server command is a .cmd shim that must run through a shell").

## Workaround (user side, until fixed)

Change the server's `command`/`args` to route through `cmd.exe`:

```json
{
  "context7": {
    "command": "cmd",
    "args": ["/c", "npx", "-y", "@upstash/context7-mcp"]
  }
}
```

```json
{
  "playwright": {
    "command": "cmd",
    "args": ["/c", "npx", "@playwright/mcp@latest"]
  }
}
```

For plugin-managed servers this must be applied to the plugin's `.mcp.json`
(both the loaded cache copy and the marketplace source copy), and it may be
reverted by a future plugin update — which is exactly why the real fix belongs
in Claude Code's spawner rather than per-plugin config.

## Note on the timeout symptom

The first time an npx server is launched on a cold npx cache, `npx -y <pkg>` must
download the package, which can exceed Claude Code's 30-second MCP connection
timeout and produce a "connection timed out after 30000ms" message. That cold-
cache timeout is a **separate, secondary** symptom. Even with a fully warmed npx
cache, the `EINVAL` failure above persists — so warming the cache does **not**
fix the issue, and the timeout message should not be mistaken for the root cause.
(A larger or configurable first-launch timeout would still be a reasonable
independent enhancement.)
