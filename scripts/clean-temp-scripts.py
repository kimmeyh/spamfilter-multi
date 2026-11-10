"""Delete stale one-off helper scripts from the session scratchpad (IMP-3 Sprint 72; Python port F330, Sprint 85).

Claude writes throwaway Python and PowerShell helpers during a sprint. They belong in the session scratchpad,
never in the repository. The scratchpad is never swept, so it grows across sprints; this is the sweep: it
removes helper files (.py .ps1 .txt .md .json) older than the retention window.

THE PROMOTION RULE matters more than the deletion (Harold, 2026-09-22): a helper written AGAIN in a later
sprint was never temporary. The report lists every name that appears more than once in the SAME project
folder, so the sweep is also a review. Move such a helper to scripts/ with a real name and a header.

Only files under a folder named "scratchpad" below the root are candidates, and every path is checked to be
inside the resolved root before it is deleted (a cleanup tool pointed at the wrong folder is the most
expensive kind of bug). Symbolic links are never followed or deleted.

Usage:
    python scripts/clean-temp-scripts.py --report-only      # list, delete nothing
    python scripts/clean-temp-scripts.py [--days N] [--root PATH]

Default root: %LOCALAPPDATA%\\Temp\\claude on Windows, <system temp>/claude elsewhere.

Exit codes: 0 done (also when the root is missing or nothing is stale, and when a delete failed: the failure
is printed with a "Failed :" count; the PowerShell original did the same); 2 bad arguments (negative --days).
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

STALE_EXTENSIONS = {".py", ".ps1", ".txt", ".md", ".json"}
HELPER_EXTENSIONS = {".py", ".ps1"}


def default_root() -> Path:
    local = os.environ.get("LOCALAPPDATA")
    if os.name == "nt" and local:
        return Path(local) / "Temp" / "claude"
    return Path(tempfile.gettempdir()) / "claude"


def walk_files(root: Path) -> tuple[list[Path], int]:
    """Every regular file with a swept extension under root (links skipped, not followed) and the number of
    unreadable folders. Other files are not listed: nothing in this tool looks at them."""
    files: list[Path] = []
    unreadable = 0
    pending = [str(root)]
    while pending:  # os.scandir keeps the type information from the directory read: no stat call per file
        folder = pending.pop()
        try:
            with os.scandir(folder) as entries:
                for entry in entries:
                    # follow_symlinks=False: a link (file or folder) is neither descended into nor listed
                    if entry.is_dir(follow_symlinks=False):
                        pending.append(entry.path)
                    elif os.path.splitext(entry.name)[1].lower() in STALE_EXTENSIONS and entry.is_file(follow_symlinks=False):
                        files.append(Path(entry.path))
        except OSError:
            unreadable += 1
    return files, unreadable


def in_scratchpad(path: Path, root: Path) -> bool:
    """True when a folder between the root and the file is named "scratchpad" (case-insensitive)."""
    parts = path.relative_to(root).parts[:-1]
    return any(part.casefold() == "scratchpad" for part in parts)


def mtime(path: Path) -> datetime:
    return datetime.fromtimestamp(path.stat().st_mtime)


def repeated_helpers(files: list[Path], root: Path) -> list[tuple[str, int]]:
    """(project/file name, count) for helper names that occur more than once in the same project folder.

    The scratchpad layout is <root>/<project-key>/<session>/scratchpad/..., so the project is the first path
    segment. A recurring name in DIFFERENT projects is not recurring work and is not reported.
    """
    counts: Counter = Counter()
    display: dict = {}
    for path in files:
        if path.suffix.lower() not in HELPER_EXTENSIONS:
            continue
        parts = path.relative_to(root).parts
        project = parts[0] if len(parts) > 1 else ""
        key = (project.casefold(), path.name.casefold())
        counts[key] += 1
        display.setdefault(key, f"{project}/{path.name}" if project else path.name)
    found = [(display[key], n) for key, n in counts.items() if n > 1]
    return sorted(found, key=lambda item: (-item[1], item[0].casefold()))


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Delete stale helper scripts from the session scratchpad.")
    parser.add_argument("--days", type=int, default=10, help="delete files older than this many days (default 10)")
    parser.add_argument("--report-only", action="store_true", help="list candidates and promotion suggestions; delete nothing")
    parser.add_argument("--root", default=None, help="scratchpad root to sweep (default: the Claude temp folder)")
    args = parser.parse_args(argv)
    if args.days < 0:
        parser.error("--days must not be negative")

    root_arg = Path(args.root) if args.root else default_root()
    if not root_arg.is_dir():
        print(f"Scratchpad root not found: {root_arg}")
        print("Nothing to clean.")
        return 0

    root = root_arg.resolve()
    cutoff = datetime.now() - timedelta(days=args.days)
    files, unreadable = walk_files(root)
    candidates = sorted(
        (p for p in files if p.suffix.lower() in STALE_EXTENSIONS and in_scratchpad(p, root) and mtime(p) < cutoff),
        key=lambda p: str(p.relative_to(root)).casefold(),
    )

    print(f"Scratchpad root : {root}")
    print(f"Retention       : {args.days} days (cutoff {cutoff:%Y-%m-%d})")
    print(f"Stale files     : {len(candidates)}")
    if unreadable:
        print(f"Unreadable folders: {unreadable} (skipped; their files were not examined)")
    print()
    if not candidates:
        print("Nothing to clean.")
        return 0

    repeated = repeated_helpers(files, root)
    if repeated:
        print("PROMOTION CANDIDATES -- same name, SAME project, written more than once:")
        for name, count in repeated:
            print(f"  {name:<48} written {count} times")
        print()
        print("  Move these to scripts/ with a real name and a header,")
        print("  then delete the copies. A helper rewritten each sprint costs its")
        print("  full authoring time every time, including the bugs.")
        print()

    if args.report_only:
        print("WOULD DELETE (report only):")
        for path in candidates:
            print(f"  {path.relative_to(root)}  [{mtime(path):%Y-%m-%d}]")
        print()
        print(f"Re-run without --report-only to delete these {len(candidates)} file(s).")
        return 0

    deleted = failed = 0
    for path in candidates:
        # Every deletion re-verifies it is under the resolved root (a link or a moved folder could change that).
        try:
            inside = path.resolve().is_relative_to(root)
        except OSError:
            inside = False
        if not inside:
            print(f"SKIPPED (outside root): {path}")
            continue
        try:
            path.unlink()
            deleted += 1
        except OSError as exc:
            print(f"FAILED: {path} -- {exc}")
            failed += 1
    print(f"Deleted: {deleted}")
    if failed:
        print(f"Failed : {failed} (likely locked; re-run later)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
