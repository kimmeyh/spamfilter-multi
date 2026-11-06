"""PreToolUse hook: block a sprint task commit while a Phase 3.3.1 deliverable is missing (F326, Sprint 84).

Python port of require-sprint-cards.ps1 (ADR-0051, F321 layer). Same interface: exit 0 allow, exit 2
block (stderr to Claude), bypass token `allow_no_cards`, same gate message text.

  - ALLOWS every command that is not a `git commit` (after quoted spans and heredoc bodies are removed,
    so a commit MESSAGE that mentions `git commit` does not trip the gate).
  - ALLOWS when `.claude/sprint_status.json` is missing or unreadable (fail open), when
    `current_sprint.plan_approved` is not set (pre-approval commits are legitimate), or when BOTH
    `github_issues` is non-empty AND `current_sprint.pr_number` is set.
  - ALLOWS a command carrying the literal bypass token `allow_no_cards` (checked on the raw command,
    as the PowerShell hook did).
  - BLOCKS a `git commit` once the plan is approved and either deliverable is missing.

`status_path_override` in the payload points the gate at a fixture (tests only; relative paths resolve
against this folder, as in the PowerShell hook).

Tests: .claude/hooks/test-cases/sprint-cards/ (run-test-cases.ps1) and .claude/hooks/tests/test_pylib.py.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import hooklib  # noqa: E402

HOOKS_DIR = os.path.dirname(os.path.abspath(__file__))
BYPASS = re.compile(r"allow_no_cards", re.I)
HEREDOC = re.compile(r"<<-?\s*'?\"?([A-Za-z_][A-Za-z0-9_]*)'?\"?.*?^\s*\1\s*$", re.S | re.M)
SINGLE_QUOTED = re.compile(r"'[^']*'")
DOUBLE_QUOTED = re.compile(r'"[^"]*"')
GIT_COMMIT = re.compile(r"git\s+commit\b", re.I)


def command_text(payload: dict) -> str:
    """tool_input.command, else a top-level command (the PowerShell hook read both)."""
    cmd = hooklib.command_of(payload)
    if not cmd and payload.get("command"):
        cmd = str(payload["command"])
    return cmd


def invocation_text(cmd: str) -> str:
    scan = HEREDOC.sub(" ", cmd)
    scan = SINGLE_QUOTED.sub(" ", scan)
    return DOUBLE_QUOTED.sub(" ", scan)


def status_path(payload: dict) -> str:
    override = payload.get("status_path_override")
    if override:
        path = str(override)
        return path if os.path.isabs(path) else os.path.join(HOOKS_DIR, path)
    return os.path.join(HOOKS_DIR, "..", "sprint_status.json")


def read_status(path: str):
    """The parsed sprint_status.json, or None when it cannot be read (fail open)."""
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8-sig") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def _non_empty(value) -> bool:
    """PowerShell `-ne $null -and [string]$x -ne ''`: a JSON null or empty string is absent."""
    return value is not None and str(value) != ""


def _has_items(value) -> bool:
    """PowerShell `$cards -and @($cards).Count -gt 0`."""
    if isinstance(value, list):
        return len(value) > 0
    return bool(value)


def missing_message(number, has_cards: bool, has_pr: bool) -> str:
    missing = []
    if not has_cards:
        missing.append("GitHub issue cards (`github_issues` is empty)")
    if not has_pr:
        missing.append("a draft PR (`pr_number` is null)")
    missing_text = " AND ".join(missing)

    fixes = []
    if not has_cards:
        fixes.append("\n".join([
            "  Cards:",
            '    gh issue create --title "<F-number>: <title>" --label sprint --body "<scope>"',
            '    -> record the numbers in .claude/sprint_status.json "github_issues": [<n>, ...]',
        ]))
    if not has_pr:
        fixes.append("\n".join([
            "  Draft PR (MUST be --draft; it stays draft until the Phase 7.7.5 final gate):",
            "    git push -u origin <sprint-branch>",
            f'    gh pr create --draft --base develop --title "Sprint {number}: <title>" --body "<approved plan>"',
            "    -> record pr_number / pr_url in .claude/sprint_status.json",
        ]))
    fix_text = "\n".join(fixes)

    return "\n".join([
        f"[BLOCKED] Sprint {number} is missing a Phase 3.3.1 deliverable: {missing_text}.",
        "",
        "The sprint plan is APPROVED (plan_approved: true), so BOTH the issue cards and",
        "the draft PR are due -- Phase 3.3.1 creates them together, in parallel with the",
        "first execution task. Task commits must not land before they exist.",
        "",
        "WHY THIS GATE EXISTS (Sprint 52 retro IMP-2 + IMP-6): execution began straight",
        "from plan approval. SIX task commits landed with no cards and no CHANGELOG",
        "entries before the gap was noticed, and the draft PR was not created until",
        "Phase 7 -- an entire sprint with no PR. Both were backfilled from reconstructed",
        "scope, which is never as accurate as the real record. The usual trigger is a",
        "branch that ALREADY EXISTS from the previous sprint's Phase 6.6 carry-forward:",
        "the first commit on it is prior-sprint close-out work, so Phase 3.3.1 is never",
        "walked.",
        "",
        "DO THIS NOW:",
        fix_text,
        "",
        "Then re-run the commit. Reference the card in the CHANGELOG entry: (Issue #N)",
        "",
        "Notes:",
        "  - Keep the PR a DRAFT until the 7.7.5 final gate. The 7.7.1 final code",
        "    reviews (Copilot by hand + pr-review-toolkit) run on the draft when",
        "    Manual Validation completes, BEFORE the retrospective.",
        "  - Since 2026-10-14 (Sprint 79, F288) `develop` is the GitHub default",
        "    branch, so `Closes #N` in the sprint PR body closes the card when the PR",
        "    merges into develop. At Post-Merge Cleanup, VERIFY the cards closed and",
        "    close any that did not by hand.",
        "",
        "Deliberate exception (rare): add the literal token `allow_no_cards` to the",
        "command.",
    ])


def decide(payload: dict) -> hooklib.Verdict:
    cmd = command_text(payload)
    if not cmd.strip() or BYPASS.search(cmd):
        return hooklib.allow()
    if not GIT_COMMIT.search(invocation_text(cmd)):
        return hooklib.allow()

    status = read_status(status_path(payload))
    if not isinstance(status, dict):
        return hooklib.allow()
    sprint = status.get("current_sprint")
    if not isinstance(sprint, dict) or not sprint.get("plan_approved"):
        return hooklib.allow()

    has_cards = _has_items(status.get("github_issues"))
    has_pr = _non_empty(sprint.get("pr_number"))
    if has_cards and has_pr:
        return hooklib.allow()
    number = sprint.get("number")
    number_text = "" if number is None else str(number)  # PowerShell prints a $null number as ""
    return hooklib.block(missing_message(number_text, has_cards, has_pr))


if __name__ == "__main__":
    hooklib.run("require-sprint-cards", decide)
