"""Emit the status footer line Harold asked for, deterministically (F329, Sprint 85; ADR-0051).

Python port of status-footer.ps1. Format:  <MM/dd/yyyy> <h:mmam|pm> | Sprint <N> Phase <n.n> <Name>
Example:  09/19/2026 1:15am | Sprint 70 Phase 5.3 Manual Validation

WHY THIS EXISTS (Harold, 2026-09-19). The footer was assembled by hand from three sources: the clock, the
phase from SPRINT_EXECUTION_WORKFLOW.md and the sprint number from sprint_status.json. A previous message's
`12:18am` was copied forward while the real time was `1:15am`. A stale timestamp is worse than no timestamp,
because it looks authoritative. The phase and sprint were right because they came from files that were read;
the one field filled from memory was wrong. That is the argument for a script.

The footer Claude runs is the USER-level C:\\Users\\<user>\\.claude\\scripts\\status-footer.ps1, outside this
repo; this file is the repo copy and is not that one.

Usage:
    python .claude/hooks/status-footer.py [--phase "7.5 Sprint Retrospective"] [--sprint 85]

--phase and --sprint override the values read from .claude/sprint_status.json (current_sprint.number and the
LEADING phase of current_sprint.status).

Performance (measured 2026-09-19 for the PowerShell original, recorded so it is not re-litigated): about 885 ms
for the whole out-of-process call, of which the script body was about 21 ms and the JSON parse about 8.6 ms, so
about 98% of the cost was interpreter startup, which no change to this file removes. A regex on the raw JSON text
(0.4 ms) would save under 1% in exchange for hand-parsing JSON, so the real parser stays. The Python version, measured
once on 2026-11-10 (one process start to exit on the Windows dev machine): 265 ms; the argument is unchanged.

Locale: the time is built by hand, never with a locale-aware format. The PowerShell original pinned the invariant
culture because `tt` and `/` follow the locale (de-DE lost the am/pm, tr-TR wrote its own designator). Python
strftime would not, but %p is locale-aware too, so the 12-hour clock and the am/pm are computed here.

Port review: the output is byte for byte the PowerShell output for the same clock and the same status file
(tests replay a matrix of status strings). A malformed or unreadable status file still yields a footer, with
"phase unknown", as before: a footer with an unknown phase is better than no footer.

What this does NOT catch: a wrong phase in sprint_status.json (it prints what the file says); a status string
whose leading phase is written in a form the two regexes do not read (the footer then says so, in brackets).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import common  # noqa: E402

# "n" or "n.n": a top-level phase ("Phase 4 Execution") is read too. Anchored at the START of the status text
# so prose later in the field cannot be mistaken for the phase (the Sprint 67 Gate 1c defect class).
PHASE_WITH_NAME = re.compile(r"^\s*(?:sprint\s+\d+\s+)?phase\s+(\d+(?:\.\d+)?)\s+([^.\-(]+)", re.IGNORECASE)
PHASE_NUMBER_ONLY = re.compile(r"^\s*(?:sprint\s+\d+\s+)?phase\s+(\d+(?:\.\d+)?)", re.IGNORECASE)
SHOUTED = re.compile(r"^[A-Z0-9 ]+$")


def repo_root(cwd: Path | None = None) -> Path:
    """1. CLAUDE_PROJECT_DIR (the harness sets it; it wins even when it holds no status file).
    2. Walk UP FROM THE CURRENT FOLDER for .claude/sprint_status.json (needed by a copy that is not inside any repo).
    3. The folder two levels above this file (.claude/hooks -> repo root)."""
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env)
    here = cwd or Path.cwd()
    for candidate in (here, *here.parents):
        if (candidate / ".claude" / "sprint_status.json").exists():
            return candidate
    return Path(__file__).resolve().parent.parent.parent


def clock_text(now: datetime) -> str:
    """`MM/dd/yyyy h:mmam|pm`: two-digit month and day, 12-hour clock with no leading zero, lowercase am/pm."""
    hour12 = now.hour % 12 or 12
    suffix = "am" if now.hour < 12 else "pm"
    return f"{now.month:02d}/{now.day:02d}/{now.year:04d} {hour12}:{now.minute:02d}{suffix}"


def title_case(text: str) -> str:
    """Capitalize the first character of each space-separated word of already-lowercased text (the .NET
    ToTitleCase result for text made only of letters, digits and spaces)."""
    return " ".join(word[:1].upper() + word[1:] for word in text.split(" "))


def phase_from_status(status: str) -> str:
    match = PHASE_WITH_NAME.match(status)
    if match:
        number, name = match.group(1), match.group(2).strip()
        if SHOUTED.search(name):
            name = title_case(name.lower())  # "MANUAL VALIDATION" -> "Manual Validation"
        return f"{number} {name}"
    number_only = PHASE_NUMBER_ONLY.match(status)
    if number_only:
        # A phase NUMBER with no NAME after it: say what is wrong so the gap is visible (2026-09-24).
        return f"{number_only.group(1)} [name missing -- start sprint_status.json status with 'Phase n.n <Name>']"
    return "unknown [start sprint_status.json status with 'Phase n.n <Name>']"


def build_footer(root: Path, now: datetime, phase: str | None = None, sprint: str | None = None) -> str:
    sprint_num, phase_text = sprint, phase
    if not sprint_num or not phase_text:
        status_path = root / ".claude" / "sprint_status.json"
        if status_path.exists():
            try:
                data = json.loads(status_path.read_bytes().decode("utf-8-sig"))
                current = data.get("current_sprint") if isinstance(data, dict) else None
                if isinstance(current, dict):
                    if not sprint_num and current.get("number"):
                        sprint_num = str(current["number"])
                    if not phase_text and current.get("status"):
                        phase_text = phase_from_status(str(current["status"]))
            except (OSError, ValueError):
                pass  # A malformed status file must not stop the footer.
    sprint_part = f"Sprint {sprint_num}" if sprint_num else ""
    if phase_text:
        sprint_part = f"{sprint_part} Phase {phase_text}" if sprint_part else f"Phase {phase_text}"
    if not sprint_part:
        sprint_part = "phase unknown -- check .claude/sprint_status.json"
    return f"{clock_text(now)} | {sprint_part}"


def main(argv: list | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Print the status footer line.")
    parser.add_argument("--phase")
    parser.add_argument("--sprint")
    args = parser.parse_args(argv)
    print(build_footer(repo_root(), datetime.now(), args.phase, args.sprint))
    return 0


if __name__ == "__main__":
    sys.exit(main())
