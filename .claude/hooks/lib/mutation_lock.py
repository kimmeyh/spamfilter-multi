"""Mutation-lock library and command line (F321 pilot, Sprint 83; ADR-0051).

Python port of the logic in mutation-lock.ps1. An agent that deliberately breaks a tracked file
to prove a test goes red takes a lock first; block-commit-during-mutation.py refuses any
`git commit` while a lock is held (Sprint 65: two commits captured a live mutation).

Lock files: <project>/.claude/mutation-locks/<safe file name>.json, one per mutated file, JSON
{file, reason, agent, createdUtc}. The format and the name sanitizing are unchanged, so a lock
written by the PowerShell version is read by this one and the other way round.

Command line (what the PowerShell shim mutation-lock.ps1 calls):

    python mutation_lock.py new    --file F --reason R [--agent A]   take a lock
    python mutation_lock.py remove [--file F]                        release one lock, or all
    python mutation_lock.py list                                     print held locks
    python mutation_lock.py info                                     JSON array with ageMinutes

The lock folder is found as mutation-lock.ps1 found it: CLAUDE_PROJECT_DIR, else walk up from the
working folder to the first folder with `.git` (or `.claude`).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402

LOCK_SUBDIR = Path(".claude") / "mutation-locks"
_UNSAFE = re.compile(r'[\\/:*?"<>|]')


def lock_dir(start: str | None = None) -> Path:
    return common.find_project_root(start) / LOCK_SUBDIR


def safe_name(file: str) -> str:
    """The lock file name for a mutated file (path separators and reserved characters -> '_')."""
    return _UNSAFE.sub("_", file) + ".json"


def new_lock(file: str, reason: str, agent: str = "unnamed-agent",
             start: str | None = None, now: datetime | None = None) -> Path:
    folder = lock_dir(start)
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / safe_name(file)
    record = {"file": file, "reason": reason, "agent": agent,
              "createdUtc": common.format_utc(now or common.utc_now())}
    path.write_text(json.dumps(record, indent=4) + "\n", encoding="utf-8")
    return path


def lock_files(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    return sorted(folder.glob("*.json"), key=lambda p: p.name.lower())


def remove_lock(file: str | None = None, start: str | None = None) -> int:
    """Release the lock for `file`, or every lock when `file` is None. Returns how many."""
    folder = lock_dir(start)
    if file:
        path = folder / safe_name(file)
        if path.exists():
            path.unlink()
            return 1
        return 0
    count = 0
    for path in lock_files(folder):
        path.unlink()
        count += 1
    return count


def read_lock(path: Path) -> dict:
    """The lock record. Raises on an unreadable or non-object file."""
    record = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(record, dict):
        raise ValueError("lock file is not a JSON object")
    return record


def lock_info(start: str | None = None, now: datetime | None = None) -> list[dict]:
    """One dict per held lock with its age in whole minutes. Read-only (F317, Sprint 82).

    One unreadable lock file must not hide the others: it is reported with ageMinutes None.
    """
    moment = now or common.utc_now()
    rows = []
    for path in lock_files(lock_dir(start)):
        try:
            record = read_lock(path)
            created = common.parse_utc(record.get("createdUtc"))
            rows.append({
                "file": record.get("file"), "reason": record.get("reason"),
                "agent": record.get("agent"), "createdUtc": record.get("createdUtc"),
                "ageMinutes": round((moment - created).total_seconds() / 60)})
        except Exception as exc:  # noqa: BLE001 - reported, not raised
            rows.append({"file": str(path), "reason": f"unreadable lock file: {exc}",
                         "agent": None, "createdUtc": None, "ageMinutes": None})
    return rows


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Mutation locks (ADR-0051 pilot).")
    sub = parser.add_subparsers(dest="action", required=True)
    p_new = sub.add_parser("new")
    p_new.add_argument("--file", required=True)
    p_new.add_argument("--reason", required=True)
    p_new.add_argument("--agent", default="unnamed-agent")
    p_remove = sub.add_parser("remove")
    p_remove.add_argument("--file", default=None)
    sub.add_parser("list")
    sub.add_parser("info")
    args = parser.parse_args(argv)

    if args.action == "new":
        new_lock(args.file, args.reason, args.agent)
        print(f"[mutation-lock] HELD on {args.file} -- commits are blocked until Remove-MutationLock.")
    elif args.action == "remove":
        if args.file:
            if remove_lock(args.file):
                print(f"[mutation-lock] RELEASED on {args.file}.")
        elif lock_dir().is_dir():
            print(f"[mutation-lock] RELEASED {remove_lock()} lock(s).")
    elif args.action == "list":
        rows = lock_info()
        if not rows:
            print("[mutation-lock] none held.")
        for row in rows:
            print(f"[mutation-lock] {row['file']} -- {row['reason']} (held by {row['agent']})")
    else:
        print(json.dumps(lock_info()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
