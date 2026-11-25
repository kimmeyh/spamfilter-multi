"""Repair a Flutter SDK folder that Flutter reports as "not a clone" (F336, Sprint 86; Python port of fix-flutter-git.ps1).

Usage:
  python fix-flutter-git.py                 show what would happen and stop (a dry run)
  python fix-flutter-git.py --yes           do it: add the origin remote if missing, fetch, hard-reset the SDK folder
  python fix-flutter-git.py --yes --ref 3.47.4   reset to a tag (or branch) instead of "stable"
Options: --remote-url URL (default https://github.com/flutter/flutter.git), --flutter-root DIR (default: the folder two
levels above the flutter command found on the PATH).

WARNING: `git reset --hard` DISCARDS every uncommitted change in the Flutter SDK folder and moves it to the fetched ref.
The repository pins the SDK in .fvmrc (flutter_version_sync_test fails on drift). "stable" moves, so after a reset to
"stable" the SDK may no longer match .fvmrc. Prefer --ref <the .fvmrc version>. The script prints the pinned version.

Defects found in the PowerShell original, and what the port does:
  - It reset to origin/stable with no confirmation and no mention of the .fvmrc pin: FIXED, a dry run unless --yes, the pin
    is printed, and --ref selects a tag.
  - $ErrorActionPreference = 'Stop' does not stop on a failing NATIVE command, so a failed `git fetch` was followed by
    `git reset --hard origin/stable` on a stale or missing ref and the script printed "[SUCCESS]": FIXED, every git call's
    exit code is checked and the first failure stops with exit 1 BEFORE the reset.
  - It reset to origin/stable after a shallow fetch of "stable"; a tag could not be used: FIXED, it fetches the ref and resets
    to FETCH_HEAD, which works for a branch and for a tag.
  - Flutter was found with Get-Command: KEPT, now shutil.which through common.find_tool (flutter has no environment variable
    like ANDROID_HOME; the folder is two levels above bin/flutter(.bat)).
  - `git remote | Select-String "origin"` matched any remote whose name contains "origin": FIXED, exact match on the name.

Exit codes: 0 done, or a dry run; 1 flutter was not found, the folder is not a git checkout, or a git step failed; 2 a usage
error (argparse).

What this does NOT catch: a Flutter SDK that was copied rather than cloned and has the wrong history for the ref (the fetch
is shallow, depth 1), a network or proxy failure beyond git's own exit code, and a dirty tree you wanted to keep (hence --yes).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

DEFAULT_URL = "https://github.com/flutter/flutter.git"


def pinned_version() -> str:
    try:
        return str(json.loads((sup.REPO / ".fvmrc").read_text(encoding="utf-8-sig")).get("flutter", "(unset)"))
    except (OSError, ValueError, AttributeError):
        return "(.fvmrc not readable)"


def flutter_root(explicit: str | None) -> Path | None:
    if explicit:
        return Path(explicit)
    found = sup.common.find_tool("flutter")
    if not found:
        return None
    return Path(found).resolve().parent.parent


def git(root: Path, *args: str) -> tuple[int, str]:
    """Run git in the SDK folder, output merged. A missing git is NOT_FOUND with the reason as the text."""
    return sup.run_capture(["git", *args], cwd=root, timeout=900)


def step(root: Path, label: str, *args: str) -> bool:
    sup.say(f"[INFO] {label}")
    code, out = git(root, *args)
    if out.strip():
        sup.say(out.strip())
    if code != 0:
        sup.say(f"[ERROR] git {' '.join(args)} failed (exit {code}). Stopping before any reset.")
        return False
    return True


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    parser = argparse.ArgumentParser(description="Repair a Flutter SDK folder that is not a clone.")
    parser.add_argument("--yes", action="store_true", help="run the destructive reset (without it, only describe it)")
    parser.add_argument("--ref", default="stable", help="branch or tag to reset to (default stable)")
    parser.add_argument("--remote-url", default=DEFAULT_URL)
    parser.add_argument("--flutter-root", default=None)
    args = parser.parse_args(argv)

    root = flutter_root(args.flutter_root)
    if root is None:
        sup.say("[ERROR] flutter was not found on the PATH. Pass --flutter-root.")
        return 1
    sup.say(f"[INFO] Flutter installation: {root}")
    if not (root / ".git").exists():
        sup.say(f"[ERROR] No .git entry at {root}")
        return 1
    sup.say(f"[INFO] The repository pins Flutter {pinned_version()} in .fvmrc.")
    if not args.yes:
        sup.say(f"[DRY RUN] Would: add remote origin if missing, `git fetch --depth 1 origin {args.ref}`, "
                f"`git reset --hard FETCH_HEAD` in {root} (this discards uncommitted changes there).")
        sup.say("[DRY RUN] Run again with --yes to do it.")
        return 0

    code, out = git(root, "remote")
    if code != 0:
        sup.say(f"[ERROR] git remote failed (exit {code}): {out.strip()[:200]}")
        return 1
    if "origin" in out.split():
        sup.say("[INFO] Git remote origin already configured")
    elif not step(root, "Adding the origin remote...", "remote", "add", "origin", args.remote_url):
        return 1
    if not step(root, f"Fetching {args.ref} (shallow)...", "fetch", "--depth", "1", "origin", args.ref):
        return 1
    if not step(root, "Resetting to the fetched ref...", "reset", "--hard", "FETCH_HEAD"):
        return 1
    sup.say("")
    sup.say("[SUCCESS] Flutter Git repository fixed.")
    for label, cmd in (("Current branch:", ("branch",)), ("Latest commit:", ("log", "-1", "--oneline"))):
        _, shown = git(root, *cmd)
        sup.say(label)
        sup.say(shown.strip())
    sup.say("[INFO] You can now run Flutter commands normally.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
