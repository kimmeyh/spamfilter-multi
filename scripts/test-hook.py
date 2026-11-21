"""Run a Claude Code hook against a crafted input and report its verdict (F329, Sprint 85; ADR-0051).

Python port of scripts/test-hook.ps1 (IMP-3 promotion, Sprint 72). A hook is a gate, and a gate that passes
because nothing matched is indistinguishable from a gate that passes because nothing is wrong (Sprint 69
F210). The only way to tell them apart is to feed the gate something it SHOULD catch. This script makes that
a one-liner:

    1. feed a tool-call payload to a PreToolUse hook (--command) and see ALLOW or BLOCK;
    2. feed a message to a Stop hook (--message) and see whether it fires;
    3. feed any other payload (--json).

Usage:
    python scripts/test-hook.py HOOK [--command TEXT | --message TEXT | --json TEXT] [--cwd DIR]
                                [--expect-block] [--expect-allow]

HOOK is absolute, repo-relative, or a bare name under .claude/hooks/. A `.py` hook runs under `python` (the
interpreter .claude/settings.json runs every hook with; there is deliberately no python3 or py fallback, so
this check cannot pass on a machine where Claude Code itself cannot start the hook). Any other file runs
under PowerShell. A bare name without an extension is not guessed.

Exit codes: 0 the probe ran and every assertion held; 1 an assertion failed OR the hook crashed (any exit
other than 0 or 2) OR the hook ran past 60 seconds; 2 this script could not run the hook (not found, no
python, more than one of --command / --message / --json, or none of them). A crashed hook is never reported
as success, with or without --expect-* (Sprint 83 retro IMP-3). Claude Code blocks ONLY on exit 2; any other
non-zero exit is a hook error and the command is ALLOWED.

Examples:
    python scripts/test-hook.py block-carry-forward-stash.py --command "git stash push -m wip" --expect-block
    python scripts/test-hook.py sprint-auto-advance.py --message "Starting F219 now."
    python scripts/test-hook.py sprint-auto-advance.py --message "Ready for Manual Validation." \
        --cwd .claude/hooks/test-cases/fixtures/f193-evidence-missing

Port review (docs/sprints/SPRINT_85_PLAN.md Task 9): the .ps1 examples named hooks that do not exist; more than
one payload switch silently kept the first; there was no time limit. Fixed here.

What this does NOT catch: a difference between this payload and the real harness payload (field names the hook
reads that this script does not send); the registration in .claude/settings.json.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

HOOK_TIMEOUT_SECONDS = 60


def resolve_hook(hook_path: str, repo_root: Path) -> Path | None:
    """The hook file: as given, under the repo root, or under .claude/hooks/. None when not found."""
    for candidate in (Path(hook_path), repo_root / hook_path, repo_root / ".claude" / "hooks" / hook_path):
        if candidate.is_file():
            return candidate.resolve()
    return None


def build_payload(command: str | None, message: str | None, json_text: str | None, cwd: str) -> str | None:
    """The stdin payload for exactly one shape; None when none was supplied."""
    if json_text:
        return json_text
    if command:
        return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd},
                          separators=(",", ":"))
    if message:
        return json.dumps({"session_id": "test-hook", "cwd": cwd, "hook_event_name": "Stop",
                           "last_assistant_message": message}, separators=(",", ":"))
    return None


def verdict_of(code: int) -> str:
    if code == 0:
        return "ALLOW"
    if code == 2:
        return "BLOCK (exit 2)"
    return f"HOOK ERROR (exit {code}, the command is ALLOWED)"


def run_probe(resolved: Path, payload: str, python: str | None) -> tuple[int, str]:
    """Run the hook with the payload on stdin. Returns (exit code, stderr and stdout merged, in order).
    Raises subprocess.TimeoutExpired when the hook runs past the limit."""
    if resolved.suffix.lower() == ".py":
        argv = [python, str(resolved)]
    else:
        shell = common.find_tool("powershell", "pwsh")
        if not shell:
            raise FileNotFoundError("a .ps1 hook needs PowerShell, which was not found on PATH.")
        argv = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(resolved)]
    done = subprocess.run(argv, input=payload.encode("utf-8"), stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=HOOK_TIMEOUT_SECONDS)
    return done.returncode, done.stdout.decode("utf-8", errors="replace")


def main(argv: list | None = None, repo_root: Path | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Run a hook against a crafted payload and report its verdict.")
    parser.add_argument("hook")
    parser.add_argument("--command")
    parser.add_argument("--message")
    parser.add_argument("--json", dest="json_text")
    parser.add_argument("--cwd")
    parser.add_argument("--expect-block", action="store_true")
    parser.add_argument("--expect-allow", action="store_true")
    args = parser.parse_args(argv)

    root = repo_root or Path(os.environ.get("CLAUDE_PROJECT_DIR") or REPO)
    resolved = resolve_hook(args.hook, root)
    if resolved is None:
        print(f"Hook not found: {args.hook}")
        print("Looked in: as given, under the repo root, and under .claude/hooks/.")
        return 2

    cwd = args.cwd or str(root)
    if Path(cwd).exists():
        cwd = str(Path(cwd).resolve())

    supplied = [name for name, value in (("--command", args.command), ("--message", args.message),
                                          ("--json", args.json_text)) if value]
    if len(supplied) > 1:
        print(f"Supply only one of --command, --message and --json (got {', '.join(supplied)}).")
        return 2
    payload = build_payload(args.command, args.message, args.json_text, cwd)
    if payload is None:
        print("Supply --command, --message or --json.")
        return 2

    python = None
    if resolved.suffix.lower() == ".py":
        # Sprint 83 7.7.1 (Copilot PR #534): ONLY "python", the interpreter .claude/settings.json runs hooks with.
        python = shutil.which("python")
        if not python:
            print('python not found on PATH. .claude/settings.json runs hooks with "python", '
                  "so the real hook cannot run either.")
            return 2

    try:
        code, output = run_probe(resolved, payload, python)
    except subprocess.TimeoutExpired:
        print(f"hook    : {resolved.name}")
        print(f"FAIL: the hook ran past {HOOK_TIMEOUT_SECONDS} seconds and was stopped.")
        return 1
    except OSError as exc:
        print(f"Could not run the hook: {exc}")
        return 2

    verdict = verdict_of(code)
    print(f"hook    : {resolved.name}")
    print(f"cwd     : {cwd}")
    print(f"verdict : {verdict}")
    if output.strip():
        print("--- hook output ---")
        for line in output.splitlines():
            print(f"  {line}")

    # Assertions last, so the diagnostic output is always visible even on failure.
    if args.expect_block and code != 2:
        print()
        print(f"FAIL: expected BLOCK (exit 2), got {verdict}.")
        return 1
    if args.expect_allow and code != 0:
        print()
        print(f"FAIL: expected ALLOW (exit 0), got {verdict}.")
        return 1
    if code not in (0, 2):
        print()
        print(f"FAIL: the hook crashed ({verdict}).")
        return 1
    if args.expect_block or args.expect_allow:
        print()
        print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
