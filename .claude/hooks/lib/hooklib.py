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


def payload_problem(raw: str) -> str:
    """Why a NON-EMPTY payload was not usable ('' when it is empty or a JSON object).

    Sprint 84 5.1.2 F6-3: parse_payload turns bad input into {} and every hook then allows, so
    without this a payload the hook could not read looked the same as a payload with nothing wrong.
    """
    if not raw or not raw.strip():
        return ""
    try:
        payload = json.loads(raw)
    except ValueError as exc:
        return f"not valid JSON ({exc})"
    return "" if isinstance(payload, dict) else f"JSON {type(payload).__name__}, not an object"


_NOTICES_SEEN: set = set()
_PENDING: list = []


def notice(text: str) -> None:
    """Queue a one-line non-blocking notice, once per process per text; run() delivers it.

    Sprint 84 5.1.2 F6-2/F6-3: for a gate or check that skipped itself, so the skip is not silent.
    Claude Code never shows stderr of a hook that exits 0, so run() delivers the queue as the
    `systemMessage` JSON field (merged into any JSON the hook prints) and, on a block, as a
    "Note:" in the stderr reason. Never raises."""
    text = text.replace("\n", " ")
    if text in _NOTICES_SEEN:
        return
    _NOTICES_SEEN.add(text)
    _PENDING.append(text)


def system_message(text: str) -> str:
    """The stdout JSON that makes Claude Code show `text` to the user as a warning without
    blocking (the common `systemMessage` output field; the hooks reference says it is shown to
    the user)."""
    return json.dumps({"systemMessage": text})


def apply_notices(verdict: Verdict, notices: list) -> Verdict:
    """The verdict with `notices` delivered. stdout stays ONE valid JSON object when it is JSON.

    - block (exit 2): a "Note:" paragraph is added to the stderr reason.
    - allow with no stdout: stdout becomes {"systemMessage": ...}.
    - allow with a JSON object on stdout: `systemMessage` is added (joined with "; " to an
      existing one) and every other key is kept.
    - allow with PLAIN TEXT stdout (block-commit-during-mutation's notes): text cannot carry a
      JSON field without breaking it, so the notice goes to stderr instead (not shown by Claude Code
      at exit 0: the one case this cannot make visible).
    """
    if not notices:
        return verdict
    text = "; ".join(notices)
    if verdict.code != ALLOW:
        base = verdict.stderr.rstrip("\n")
        return verdict._replace(stderr=(base + "\n\n" if base else "") + "Note: " + text)
    out = verdict.stdout.strip()
    if not out:
        return verdict._replace(stdout=system_message(text))
    try:
        body = json.loads(out)
    except ValueError:
        body = None
    if isinstance(body, dict):
        existing = body.get("systemMessage")
        body["systemMessage"] = f"{existing}; {text}" if isinstance(existing, str) and existing else text
        return verdict._replace(stdout=json.dumps(body, separators=(",", ":")))
    base = verdict.stderr.rstrip("\n")
    return verdict._replace(stderr=(base + "\n" if base else "") + "Note: " + text)


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
        raw = read_stdin_text()
        problem = payload_problem(raw)
        if problem:
            # Still allowed (exit 0): a notice, not a block.
            notice(f"[{name}] input unreadable ({problem}); allowed without checking")
        verdict = apply_notices(decide(parse_payload(raw)), list(_PENDING))
    except Exception as exc:  # noqa: BLE001 - fail open by design, see module docstring
        # One line: the hook-error notice shows only the first stderr line.
        sys.stderr.write(f"[{name}] internal error, command allowed: {type(exc).__name__}: {exc}\n")
        for queued in _PENDING:
            sys.stderr.write(f"Note: {queued}\n")
        sys.exit(HOOK_ERROR)
    if verdict.stdout:
        sys.stdout.write(verdict.stdout.rstrip("\n") + "\n")
    if verdict.stderr:
        sys.stderr.write(verdict.stderr.rstrip("\n") + "\n")
    sys.stdout.flush()
    sys.stderr.flush()
    sys.exit(verdict.code)


__all__ = ["ALLOW", "BLOCK", "HOOK_ERROR", "Verdict", "allow", "block", "parse_payload", "payload_problem", "notice", "apply_notices", "system_message", "tool_name",
           "command_of", "cwd_of", "run"]
