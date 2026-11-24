"""Task clock: the ledger of when each sprint task started and finished (F363, Sprint 86).

One per-sprint ledger, `docs/sprints/SPRINT_<N>_TASK_CLOCK.json`, written ONLY from the clock read by this
code -- never from a time Claude types. Used by:
  - scripts/task-clock.py              start / stop / finish / status (the main session, by hand)
  - .claude/hooks/task-clock-gate.py   the gates and the automatic starts and stops around subagents
  - .claude/hooks/verify-closeout-complete.py check 3d-3 (every card clocked, minutes match the ledger)

Why (register d2; Sprint 85): six of sixteen task cards closed with "actual minutes not recorded, 0 min
logged". A rule that the start time is written when the task starts existed (Sprint 85 retro i7) and was not
followed, because nothing ran at that moment. The ledger is written by a script or a hook at the moment the
event happens, so the time cannot be lost or invented later.

Ledger shape:
    {"sprint": 86,
     "tasks": {"10": {"segments": [{"start": "2026-11-24T01:02:03", "end": null, "by": "main",
                                     "agent_id": null}],
                      "finished": null}},
     "agents": {"<agentId>": "3"}}
Times are LOCAL wall-clock ISO strings with seconds (what Harold reads on his clock). A task's minutes are
the UNION of its segments (overlapping agent runs on one task are not double-counted), rounded up.

Failure rule (R-7): every reader returns a LedgerError for a ledger that exists but cannot be read, so each
gate can BLOCK with "the check did not run" instead of passing in silence. A MISSING ledger is not an error:
it is an empty ledger (no task has started yet).
"""
from __future__ import annotations

import json
import math
import os
import re
import tempfile
from datetime import datetime
from pathlib import Path

STATUS_FILE = ".claude/sprint_status.json"
ACTIVE_PHASES = re.compile(r"^\s*Phase\s+[45]\b", re.I)
TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"
SHOW_FORMAT = "%Y-%m-%d %H:%M"


class LedgerError(Exception):
    """A ledger or status file exists but cannot be read or written."""


# --------------------------------------------------------------------------------------------- paths

def find_root(start: str | os.PathLike | None) -> Path | None:
    """The first folder at or above `start` holding .claude/sprint_status.json; else CLAUDE_PROJECT_DIR when it
    holds one; else None. The payload's own folder wins so test fixtures never touch the real repo."""
    if start:
        here = Path(start)
        try:
            here = here.resolve()
        except OSError:
            pass
        for candidate in (here, *here.parents):
            if (candidate / STATUS_FILE).is_file():
                return candidate
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env and (Path(env) / STATUS_FILE).is_file():
        return Path(env)
    return None


def ledger_path(root: Path, sprint: int) -> Path:
    return root / "docs" / "sprints" / f"SPRINT_{sprint}_TASK_CLOCK.json"


def plan_path(root: Path, sprint: int) -> Path:
    return root / "docs" / "sprints" / f"SPRINT_{sprint}_PLAN.md"


# --------------------------------------------------------------------------------------------- status

def read_status(root: Path) -> dict:
    """sprint_status.json as a dict. Raises LedgerError when it exists but is not a readable JSON object."""
    path = root / STATUS_FILE
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise LedgerError(f"{STATUS_FILE} could not be read ({exc})") from exc
    if not isinstance(data, dict):
        raise LedgerError(f"{STATUS_FILE} is not a JSON object")
    return data


def active_sprint(status: dict) -> int | None:
    """The sprint number when the clock gates apply (plan approved, Phase 4 or 5); None otherwise.
    Outside Phases 4-5 (refinement, planning, release) the gates do nothing (R-7)."""
    sprint = status.get("current_sprint")
    if not isinstance(sprint, dict):
        raise LedgerError(f"{STATUS_FILE} has no current_sprint object")
    if sprint.get("plan_approved") is not True:
        return None
    if not ACTIVE_PHASES.search(str(sprint.get("status") or "")):
        return None
    try:
        return int(sprint.get("number"))
    except (TypeError, ValueError) as exc:
        raise LedgerError(f"{STATUS_FILE} current_sprint.number is not a number") from exc


def current_sprint_number(status: dict) -> int:
    sprint = status.get("current_sprint")
    try:
        return int(sprint["number"])  # type: ignore[index]
    except (TypeError, KeyError, ValueError) as exc:
        raise LedgerError(f"{STATUS_FILE} current_sprint.number is missing") from exc


# --------------------------------------------------------------------------------------------- ledger

def empty_ledger(sprint: int) -> dict:
    return {"sprint": sprint, "tasks": {}, "agents": {}}


def load(root: Path, sprint: int) -> dict:
    """The ledger; an empty one when the file does not exist. Raises LedgerError when it cannot be read."""
    path = ledger_path(root, sprint)
    if not path.exists():
        return empty_ledger(sprint)
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise LedgerError(f"{path.name} could not be read ({exc})") from exc
    if not isinstance(data, dict) or not isinstance(data.get("tasks"), dict):
        raise LedgerError(f"{path.name} has no 'tasks' object")
    data.setdefault("agents", {})
    if not isinstance(data["agents"], dict):
        raise LedgerError(f"{path.name} 'agents' is not an object")
    for key, task in data["tasks"].items():
        if not isinstance(task, dict) or not isinstance(task.get("segments"), list):
            raise LedgerError(f"{path.name} task {key} has no 'segments' list")
    return data


def save(root: Path, sprint: int, ledger: dict) -> None:
    """Write the ledger atomically (temp file + replace), so a crash never leaves half a file."""
    path = ledger_path(root, sprint)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(ledger, indent=2, sort_keys=True) + "\n"
    try:
        fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=path.name, suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(tmp, path)
    except OSError as exc:
        raise LedgerError(f"{path.name} could not be written ({exc})") from exc


def now_text(now: datetime | None = None) -> str:
    return (now or datetime.now()).strftime(TIME_FORMAT)


def parse_time(text: str) -> datetime:
    return datetime.strptime(text, TIME_FORMAT)


def task_entry(ledger: dict, task: str) -> dict:
    return ledger["tasks"].setdefault(str(task), {"segments": [], "finished": None})


def open_segments(ledger: dict, task: str | None = None) -> list:
    """(task, segment) pairs with no end; for one task, or for every task when `task` is None."""
    found = []
    for key, entry in ledger["tasks"].items():
        if task is not None and key != str(task):
            continue
        for segment in entry["segments"]:
            if segment.get("end") is None:
                found.append((key, segment))
    return found


def start(ledger: dict, task: str, by: str = "main", now: datetime | None = None) -> bool:
    """Open a segment. False (no change) when one opened by the same actor is already open, or the task finished."""
    entry = task_entry(ledger, task)
    if entry.get("finished"):
        return False
    if any(seg.get("by") == by and seg.get("end") is None for seg in entry["segments"]):
        return False
    entry["segments"].append({"start": now_text(now), "end": None, "by": by, "agent_id": None})
    return True


def stop(ledger: dict, task: str, by: str | None = None, agent_id: str | None = None,
         now: datetime | None = None) -> int:
    """Close open segments of `task` (only those by `by`, or with `agent_id`, when given). Returns how many."""
    closed = 0
    for key, segment in open_segments(ledger, task):
        if by is not None and segment.get("by") != by:
            continue
        if agent_id is not None and segment.get("agent_id") != agent_id:
            continue
        segment["end"] = now_text(now)
        closed += 1
    return closed


def extend_agent_stop(ledger: dict, task: str, agent_id: str, now: datetime | None = None) -> bool:
    """A LATER SubagentStop of the same agent moves its last closed segment's end forward. SubagentStop fires
    each time a background agent stops with no live children of its own, so an agent that pauses for its own
    background work stops more than once; only the last stop is when it finished (Sprint 86 Task 2: the first
    stop closed the segment at 87 of 150 minutes). Not applied once the task is finished. Returns True when
    an end moved."""
    entry = ledger["tasks"].get(task)
    if not entry or entry.get("finished"):
        return False
    stamp = now_text(now)
    for segment in reversed(entry["segments"]):
        if segment.get("agent_id") == agent_id and segment.get("end"):
            if parse_time(stamp) > parse_time(segment["end"]):
                segment["end"] = stamp
                return True
            return False
    return False


def minutes(entry: dict, now: datetime | None = None) -> int:
    """Union of the segments in whole minutes, rounded up (an open segment counts to `now`)."""
    spans = []
    for segment in entry.get("segments", []):
        begin = parse_time(segment["start"])
        end = parse_time(segment["end"]) if segment.get("end") else (now or datetime.now())
        if end > begin:
            spans.append((begin, end))
    spans.sort()
    total = 0.0
    current = None
    for begin, end in spans:
        if current is None or begin > current[1]:
            if current is not None:
                total += (current[1] - current[0]).total_seconds()
            current = [begin, end]
        else:
            current[1] = max(current[1], end)
    if current is not None:
        total += (current[1] - current[0]).total_seconds()
    if total > 0:
        return math.ceil(total / 60)
    # A started task that finished within the same second still took time; "0 min" is the Sprint 85 text the
    # close-out check refuses, so a clocked task never reports it.
    return 1 if entry.get("segments") else 0


def first_start(entry: dict) -> str | None:
    starts = [seg["start"] for seg in entry.get("segments", [])]
    return min(starts) if starts else None


def show(text: str | None) -> str:
    return parse_time(text).strftime(SHOW_FORMAT) if text else "none"


# --------------------------------------------------------------------------------------------- plan

CARD_HEADING = re.compile(r"^#{2,3}\s+Task\s+(\S+)\s+--\s*(.*)$", re.M)
CARDS_LINE = re.compile(r"Task\s+(\d+)\s+#(\d+)")
TASK_REF = re.compile(r"(?:\bSprint\s+(\d+)\s+)?\bTask\s+(\d+)\b", re.I)


def card_map(plan_text: str) -> dict:
    """card number -> task number, from the plan header's `Task N #card` pairs."""
    header = plan_text.split("\n## ", 1)[0]
    return {card: task for task, card in CARDS_LINE.findall(header)}


def task_refs(text: str, sprint: int) -> list:
    """Task numbers named as `Task N` (or `Sprint S Task N` with S == sprint), in order, without repeats."""
    seen = []
    for match in TASK_REF.finditer(text or ""):
        if match.group(1) and int(match.group(1)) != sprint:
            continue
        number = match.group(2)
        if number not in seen:
            seen.append(number)
    return seen


def card_section(plan_text: str, task: str) -> tuple[int, int] | None:
    """(start, end) offsets of the `### Task <task> --` card in the plan, or None."""
    headings = list(CARD_HEADING.finditer(plan_text))
    for index, heading in enumerate(headings):
        if heading.group(1) == str(task):
            end = headings[index + 1].start() if index + 1 < len(headings) else len(plan_text)
            nxt = plan_text.find("\n## ", heading.end())
            if 0 <= nxt < end:
                end = nxt
            return heading.start(), end
    return None


__all__ = [name for name in dir() if not name.startswith("_")]
