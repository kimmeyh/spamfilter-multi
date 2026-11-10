"""Install the custom Email Rule Tester MCP server (F331 port of install-custom-mcp.ps1).

Steps:
  1. find node
  2. npm install in scripts/email-rule-tester-mcp (skipped by --dry-run)
  3. start the server for a few seconds and look for its start-up line (a warning only, as before)
  4. add the server to the user-scope Claude Code configuration (~/.claude.json, key "mcpServers")

Usage:
    python scripts/install-custom-mcp.py
    python scripts/install-custom-mcp.py --dry-run
    python scripts/install-custom-mcp.py --config-file <path>

Options:
    --dry-run           Run the read-only steps, print the configuration change as a diff, write nothing
    --config-file PATH  Use this file instead of ~/.claude.json (tests and what-if runs)

Exit codes:
    0  installed (or dry run finished), including when the start-up line was not seen (a warning)
    1  node not found, server file missing, npm install failed, or the configuration file is not usable
    2  invalid command line (argparse)

Every other top-level key of the configuration is kept. A timestamped backup is written before any change to an
existing file. Runs on Windows, macOS and Linux.
"""
from __future__ import annotations

import argparse
import copy
import subprocess
import sys
import threading
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
REPO = SCRIPTS.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
sys.path.insert(0, str(SCRIPTS))
import common  # noqa: E402
import mcp_config  # noqa: E402

MCP_DIR = SCRIPTS / "email-rule-tester-mcp"
SERVER_NAME = "email-rule-tester"
START_MARKER = "Email Rule Tester MCP server running"
SMOKE_TIMEOUT_SECONDS = 10.0


def smoke_test(node: str, server: Path, timeout: float = SMOKE_TIMEOUT_SECONDS) -> bool:
    """Start the server, wait up to `timeout` seconds for the start-up line on stderr, then stop it.

    The server speaks MCP over stdin and stdout and waits for input, so it is always stopped here.
    Returns True when the start-up line was seen.
    """
    proc = subprocess.Popen(
        [node, str(server)], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        text=True, encoding="utf-8", errors="replace")
    seen = threading.Event()
    collected: list[str] = []

    def reader() -> None:
        assert proc.stderr is not None
        for line in proc.stderr:
            collected.append(line)
            if START_MARKER in line:
                seen.set()

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    try:
        deadline = time.monotonic() + timeout
        while not seen.is_set() and time.monotonic() < deadline and proc.poll() is None:
            seen.wait(0.1)
        return seen.is_set()
    finally:
        if proc.poll() is None:
            proc.kill()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        thread.join(timeout=2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Install the custom Email Rule Tester MCP server.")
    parser.add_argument("--dry-run", action="store_true",
                        help="run the read-only steps, print the configuration change, write nothing")
    parser.add_argument("--config-file", metavar="PATH",
                        help="configuration file to use instead of ~/.claude.json")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    print("=" * 80)
    print("Email Rule Tester MCP Installation")
    print("=" * 80)
    print("")

    server = MCP_DIR / "server.js"

    print("[1/4] Checking Node.js installation...")
    node = common.find_tool("node")
    if node is None:
        print("  [ERROR] Node.js not found!", file=sys.stderr)
        print("  Install from: https://nodejs.org/", file=sys.stderr)
        return 1
    print(f"  [OK] Node.js found: {node}")
    if not server.exists():
        print(f"  [ERROR] MCP server file missing: {server}", file=sys.stderr)
        return 1

    print("[2/4] Installing npm dependencies...")
    if args.dry_run:
        print("  [DRY RUN] Would run: npm install (skipped)")
    else:
        npm = common.find_tool("npm")
        if npm is None:
            print("  [ERROR] npm not found!", file=sys.stderr)
            return 1
        result = subprocess.run([npm, "install"], cwd=str(MCP_DIR), check=False)
        if result.returncode != 0:
            print(f"  [ERROR] npm install failed (exit {result.returncode})", file=sys.stderr)
            return 1
        print("  [OK] Dependencies installed")

    print("[3/4] Testing MCP server...")
    if smoke_test(node, server):
        print("  [OK] Server starts successfully")
    else:
        print(f"  [WARNING] Start-up line not seen within {SMOKE_TIMEOUT_SECONDS:.0f} seconds; the server may have issues")

    print("[4/4] Configuring Claude Code...")
    path = Path(args.config_file) if args.config_file else mcp_config.default_config_path()
    try:
        current = mcp_config.load_config(path)
    except mcp_config.ConfigError as exc:
        print(f"  [ERROR] {exc}", file=sys.stderr)
        print("  Nothing was written. Fix or move the file, then run this script again.", file=sys.stderr)
        return 1
    if current.get("mcpServers") is not None and not isinstance(current.get("mcpServers"), dict):
        print(f"  [ERROR] 'mcpServers' in {path} is not a JSON object. Nothing was written.", file=sys.stderr)
        return 1

    updated = copy.deepcopy(current)
    updated.setdefault("mcpServers", {})[SERVER_NAME] = {"command": node, "args": [str(server)]}
    before = mcp_config.render(current) if path.exists() else ""
    after = mcp_config.render(updated)

    if before == after:
        print(f"  [OK] Configuration already up to date: {path}")
    elif args.dry_run:
        print("")
        print("[DRY RUN] The change that would be written:")
        print(mcp_config.diff_text(before, after, path) if before else after, end="")
        print("[DRY RUN] Nothing was written.")
    else:
        try:
            if path.exists():
                print(f"  [OK] Backup written: {mcp_config.backup(path)}")
            mcp_config.write_atomic(path, after)
        except OSError as exc:
            print(f"  [ERROR] Could not write {path}: {exc}", file=sys.stderr)
            return 1
        print(f"  [OK] Configuration saved to: {path}")

    print("")
    print("Next steps: restart Claude Code, then ask: 'What MCP tools are available?'")
    print(f"MCP server location: {server}")
    print(f"Claude configuration: {path}")
    return 0


if __name__ == "__main__":
    common.configure_stdio()
    sys.exit(main())
