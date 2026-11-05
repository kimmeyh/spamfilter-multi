"""Report the state of delegated agent work from files only (F317 Sprint 82; Python F321 Sprint 83).

Read-only: it stores nothing and changes nothing. Prints each agent task's progress, the held
mutation locks with their age, and the sprint phase. The output format is the one
scripts/agent-work-status.ps1 always printed; that script is now a thin entry point that calls
this one (the hourly wake-up still runs scripts\\agent-work-status.ps1).

Convention (docs/SPRINT_EXECUTION_WORKFLOW.md, "Progress and restart"): each agent keeps
<scratch folder>/<task-name>/progress.md with lines "UNIT <name>: DONE|STARTED", "LAST STEP:
<text>" and, last, "STATUS: FINISHED".

State per task folder:
    not started                    no progress.md in the folder
    started, nothing saved         progress.md has no UNIT lines
    in progress                    UNIT lines, no "STATUS: FINISHED" (shows the last step)
    finished                       "STATUS: FINISHED" is the last non-empty line

Usage: python scripts/agent-work-status.py [--scratch-folder PATH]
Default scratch folder: the newest session scratchpad under
<temp>/claude/D--Data-Harold-github-spamfilter-multi/<session>/scratchpad, where <temp> is
%LOCALAPPDATA%\\Temp on Windows and the system temp folder elsewhere.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402
import mutation_lock  # noqa: E402

PROJECT_SLUG = "D--Data-Harold-github-spamfilter-multi"
UNIT = re.compile(r"^UNIT .+: (DONE|STARTED)\s*$", re.I)
UNIT_DONE = re.compile(r": DONE\s*$", re.I)
LAST_STEP = re.compile(r"^LAST STEP:", re.I)


def claude_temp_roots() -> list[Path]:
    """The folders that hold session temp folders: <temp>/claude."""
    local = os.environ.get("LOCALAPPDATA")
    roots = []
    if local:
        roots.append(Path(local) / "Temp" / "claude")
    roots.append(Path(tempfile.gettempdir()) / "claude")
    seen, out = set(), []
    for r in roots:
        key = str(r).lower()
        if key not in seen:
            seen.add(key)
            out.append(r)
    return out


def project_session_ids() -> set[str]:
    """Session ids of THIS project: one <id>.jsonl transcript each under
    ~/.claude/projects/<slug>/. Used so another project's session is never picked."""
    folder = Path.home() / ".claude" / "projects" / PROJECT_SLUG
    if not folder.is_dir():
        return set()
    return {p.stem for p in folder.glob("*.jsonl")}


def newest_scratchpad() -> Path | None:
    """Sprint 83 7.7.1 (code-reviewer L-4, silent-failure-hunter L-1): sessions now live under
    <temp>/claude/<hash>/<session>/scratchpad, not only under the project slug, so the old
    slug-only lookup reported an OLD session's agents and hid the live ones. Searches every
    <temp>/claude/*/<session>/scratchpad whose <session> is a transcript of this project (or
    sits under the project slug), newest first."""
    ids = project_session_ids()
    pads: list[Path] = []
    for root in claude_temp_roots():
        if not root.is_dir():
            continue
        for parent in root.iterdir():
            if not parent.is_dir():
                continue
            for session in parent.iterdir():
                pad = session / "scratchpad"
                if pad.is_dir() and (session.name in ids or parent.name == PROJECT_SLUG):
                    pads.append(pad)
    if not pads:
        return None
    return max(pads, key=lambda p: p.stat().st_mtime)


def task_line(task: Path) -> str:
    progress = task / "progress.md"
    if not progress.exists():
        return f"  {task.name}: not started"
    # 7.7.1 L-3: a progress file that cannot be read (an agent writing it at this moment) is
    # reported, and the other folders are still listed.
    try:
        lines = [ln for ln in progress.read_text(encoding="utf-8-sig", errors="replace").splitlines()
                 if ln.strip()]
    except OSError as exc:
        return f"  {task.name}: progress.md unreadable ({exc}); check again"
    units = [ln for ln in lines if UNIT.match(ln)]
    done = sum(1 for ln in units if UNIT_DONE.search(ln))
    if lines and lines[-1].strip().upper() == "STATUS: FINISHED":
        return f"  {task.name}: finished ({done} unit(s) done)"
    steps = [ln for ln in lines if LAST_STEP.match(ln)]
    if not units and not steps:
        return f"  {task.name}: started, nothing saved"
    last = steps[-1] if steps else units[-1]
    return f"  {task.name}: in progress ({done}/{len(units)} unit(s) done) -- {last}"


def sprint_phase() -> str:
    status_file = REPO / ".claude" / "sprint_status.json"
    if status_file.exists():
        data = json.loads(status_file.read_text(encoding="utf-8-sig"))
        current = data.get("current_sprint") if isinstance(data, dict) else None
        if current:
            return f"Sprint {current.get('number')}: {current.get('status')}"
    return "unknown"


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Report delegated agent work (read-only).")
    parser.add_argument("--scratch-folder", default=None)
    args = parser.parse_args(argv)

    scratch = Path(args.scratch_folder) if args.scratch_folder else newest_scratchpad()
    print(f"Scratch folder: {scratch if scratch else ''}")
    print("Agent tasks:")
    if not scratch or not scratch.exists():
        print("  (scratch folder not found)")
    else:
        tasks = sorted((d for d in scratch.iterdir() if d.is_dir()), key=lambda d: d.name.lower())
        if not tasks:
            print("  (no task folders)")
        for task in tasks:
            print(task_line(task))

    print("Mutation locks:")
    locks = mutation_lock.lock_info(str(REPO))
    if not locks:
        print("  none held")
    for lock in locks:
        age = lock["ageMinutes"]
        flag = " [OVER 1 HOUR]" if age is not None and age > 60 else ""
        agent = "" if lock["agent"] is None else lock["agent"]
        shown_age = "" if age is None else age
        print(f"  {lock['file']} -- {lock['reason']} (agent {agent}, {shown_age} min){flag}")

    print(f"Sprint phase: {sprint_phase()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
