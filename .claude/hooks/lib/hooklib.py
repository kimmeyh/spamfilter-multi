"""Hook plumbing for the repo's Python hooks (F321, Sprint 83; ADR-0051).

A hook is a small file with one function, `decide(payload) -> Verdict`. This module reads the
payload, calls `decide`, writes the verdict and exits. Putting that in one place makes the
fail-open rule structural instead of something each hook must remember:

  - an empty, unparseable or non-object payload is ALLOWED (decide runs on an empty payload and
    every hook allows when there is no command);
  - ANY exception raised inside `decide` is ALLOWED, and exits HOOK_ERROR (1) with a note.

A wedged hook blocks every tool call until someone notices; one missed violation is
recoverable. The tests, not the exception handler, are what keep a hook correct.

Why 1 and not 0 (Sprint 83 5.1.2 F6): Claude Code never shows the stderr of a hook that exits
0, so an exit-0 "internal error" note was silent and a crashed guard looked like a passing one.
Exit 1 is a NON-BLOCKING error: the action still goes ahead, and the transcript shows a
"hook error" notice with the first stderr line (https://code.claude.com/docs/en/hooks, read
2026-11-04). It stays non-blocking only while no hook entry sets `onFailure: "block"`.

Exit codes match the PowerShell hooks this replaces: 0 allow, 2 block (stderr goes to Claude).
"""
from __future__ import annotations

import json
import sys
from typing import Callable, NamedTuple

from common import ALLOW, BLOCK, configure_stdio, read_stdin_text


HOOK_ERROR = 1
"""A non-blocking hook error: the action proceeds and Claude Code shows a notice."""


class Verdict(NamedTuple):
    code: int = ALLOW
    stderr: str = ""
    stdout: str = ""


def allow(stdout: str = "", stderr: str = "") -> Verdict:
    return Verdict(ALLOW, stderr, stdout)


def block(message: str) -> Verdict:
    """A block verdict. The message goes to stderr, which Claude Code feeds back to Claude."""
    return Verdict(BLOCK, message, "")


def parse_payload(raw: str) -> dict:
    """The payload as a dict; {} for anything empty, malformed or not a JSON object."""
    if not raw or not raw.strip():
        return {}
    try:
        payload = json.loads(raw)
    except ValueError:
        return {}
    return payload if isinstance(payload, dict) else {}


def tool_name(payload: dict) -> str:
    return str(payload.get("tool_name") or "")


def command_of(payload: dict) -> str:
    """The shell command a Bash or PowerShell tool call is about to run ('' when there is none)."""
    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict) and tool_input.get("command"):
        return str(tool_input["command"])
    return ""


def cwd_of(payload: dict) -> str:
    return str(payload.get("cwd") or "")


def run(name: str, decide: Callable[[dict], Verdict]) -> None:
    """Entry point for a hook file: read stdin, decide, write the verdict, exit."""
    configure_stdio()
    try:
        verdict = decide(parse_payload(read_stdin_text()))
    except Exception as exc:  # noqa: BLE001 - fail open by design, see module docstring
        # One line: the hook-error notice shows only the first stderr line.
        sys.stderr.write(f"[{name}] internal error, command allowed: {type(exc).__name__}: {exc}\n")
        sys.exit(HOOK_ERROR)
    if verdict.stdout:
        sys.stdout.write(verdict.stdout.rstrip("\n") + "\n")
    if verdict.stderr:
        sys.stderr.write(verdict.stderr.rstrip("\n") + "\n")
    sys.stdout.flush()
    sys.stderr.flush()
    sys.exit(verdict.code)


__all__ = ["ALLOW", "BLOCK", "HOOK_ERROR", "Verdict", "allow", "block", "parse_payload", "tool_name",
           "command_of", "cwd_of", "run"]
