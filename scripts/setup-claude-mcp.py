"""Set up Claude Code MCP servers for spam filter development (F331 port of setup-claude-mcp.ps1).

Adds MCP server entries to the user-scope Claude Code configuration (~/.claude.json, key "mcpServers").
Every other key in that file is kept. A timestamped backup is written before any change to an existing file.

Usage:
    python scripts/setup-claude-mcp.py --install-all
    python scripts/setup-claude-mcp.py --install-github --install-flutter
    python scripts/setup-claude-mcp.py --install-github --dry-run

Options:
    --install-github    GitHub MCP server (npx @modelcontextprotocol/server-github); reads GITHUB_TOKEN
    --install-flutter   No MCP server exists for this yet. Prints a note and changes nothing.
    --install-yaml      No MCP server exists for this yet. Prints a note and changes nothing.
    --install-regex     No MCP server exists for this yet. Prints a note and changes nothing.
    --install-all       Same as selecting all four options above
    --dry-run           Print the change as a diff and write nothing (no backup either)
    --config-file PATH  Use this file instead of ~/.claude.json (tests and what-if runs)

Exit codes:
    0  done (or nothing to change)
    1  no server selected, node or npm not found, or the configuration file is not usable
    2  invalid command line (argparse)

Runs on Windows, macOS and Linux. Needs node and npm on PATH.
"""
from __future__ import annotations

import argparse
import copy
import os
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
REPO = SCRIPTS.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
sys.path.insert(0, str(SCRIPTS))
import common  # noqa: E402
import mcp_config  # noqa: E402

GITHUB_TOKEN_PLACEHOLDER = "YOUR_GITHUB_TOKEN_HERE"
GITHUB_SERVER = "github"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Set up Claude Code MCP servers for spam filter development.")
    parser.add_argument("--install-github", action="store_true", help="GitHub MCP server")
    parser.add_argument("--install-flutter", action="store_true", help="Flutter MCP server (none exists yet)")
    parser.add_argument("--install-yaml", action="store_true", help="YAML validation MCP (none exists yet)")
    parser.add_argument("--install-regex", action="store_true", help="Regex testing MCP (none exists yet)")
    parser.add_argument("--install-all", action="store_true", help="Install every option above")
    parser.add_argument("--dry-run", action="store_true", help="Show the change and write nothing")
    parser.add_argument("--config-file", metavar="PATH", help="Configuration file to use instead of ~/.claude.json")
    return parser


def github_entry(token: str | None) -> dict:
    return {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {"GITHUB_TOKEN": token or GITHUB_TOKEN_PLACEHOLDER},
    }


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    install_github = args.install_github or args.install_all
    placeholders = {
        "Flutter": args.install_flutter or args.install_all,
        "YAML": args.install_yaml or args.install_all,
        "Regex": args.install_regex or args.install_all,
    }
    if not (install_github or any(placeholders.values())):
        print("[ERROR] No MCP servers selected. Use --install-all or specify individual servers.", file=sys.stderr)
        print("Examples:", file=sys.stderr)
        print("  python scripts/setup-claude-mcp.py --install-all", file=sys.stderr)
        print("  python scripts/setup-claude-mcp.py --install-github --install-flutter", file=sys.stderr)
        return 1

    print("=" * 80)
    print("Claude Code MCP Server Setup")
    print("=" * 80)

    node = common.find_tool("node")
    if node is None:
        print("[ERROR] Node.js not found. Install from: https://nodejs.org/", file=sys.stderr)
        print("MCP servers require Node.js/npm to run.", file=sys.stderr)
        return 1
    print(f"[OK] Node.js found: {node}")
    if common.find_tool("npm") is None:
        print("[ERROR] npm not found. Reinstall Node.js.", file=sys.stderr)
        return 1
    print("[OK] npm found")

    path = Path(args.config_file) if args.config_file else mcp_config.default_config_path()
    try:
        current = mcp_config.load_config(path)
    except mcp_config.ConfigError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        print("Nothing was written. Fix or move the file, then run this script again.", file=sys.stderr)
        return 1
    if not path.exists():
        print(f"[INFO] No configuration file yet at {path}; one will be created")
    elif current.get("mcpServers") is not None and not isinstance(current.get("mcpServers"), dict):
        print(f"[ERROR] 'mcpServers' in {path} is not a JSON object. Nothing was written.", file=sys.stderr)
        return 1

    updated = copy.deepcopy(current)
    servers = updated.setdefault("mcpServers", {})
    if install_github:
        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            print("[WARNING] GITHUB_TOKEN not set in environment. The placeholder is written into the server entry.")
            print("  Create a classic token at https://github.com/settings/tokens (repo, issues, pull_requests),")
            print("  set GITHUB_TOKEN, then run this script again with --install-github.")
        servers[GITHUB_SERVER] = github_entry(token)
        print("[OK] GitHub MCP server configured")

    for label, selected in placeholders.items():
        if selected:
            print(f"[INFO] {label}: no MCP server exists for this yet. Nothing was configured.")
    if not install_github:
        print("[OK] No change needed: no server entry to write.")
        return 0

    before = mcp_config.render(current) if path.exists() else ""
    after = mcp_config.render(updated)
    if before == after:
        print(f"[OK] No change needed: {path}")
        return 0

    if args.dry_run:
        print("")
        print("[DRY RUN] The change that would be written:")
        if before:
            print(mcp_config.diff_text(before, after, path), end="")
        else:
            print(after, end="")
        print("[DRY RUN] Nothing was written.")
        return 0

    try:
        if path.exists():
            copy_path = mcp_config.backup(path)
            print(f"[OK] Backup written: {copy_path}")
        mcp_config.write_atomic(path, after)
    except OSError as exc:
        print(f"[ERROR] Could not write {path}: {exc}", file=sys.stderr)
        return 1
    print(f"[OK] Configuration saved to: {path}")

    print("")
    print("Restart Claude Code to load new MCP servers.")
    if install_github and not os.environ.get("GITHUB_TOKEN"):
        print("GitHub MCP still needs a real token: set GITHUB_TOKEN, then run this script again.")
    return 0


if __name__ == "__main__":
    common.configure_stdio()
    sys.exit(main())
