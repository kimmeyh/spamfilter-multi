"""Test harness for the repo's hooks (F329, Sprint 85; ADR-0051). Python port of run-test-cases.ps1.

Pipes each test-case JSON file into the hook it targets and asserts the hook's exit code against the
case-name prefix:
    allow-*     expect exit 0 (action allowed) and NO hookSpecificOutput.additionalContext warning
    violation-* expect exit 2 (action blocked)
    warn-*      expect exit 0 AND a hookSpecificOutput.additionalContext warning on stdout
                (Sprint 82 retro IMP-7)

Hook routing is by DIRECTORY (F130-S51 R-2):
    test-cases/*.json               -> sprint-auto-advance.py          (Stop)
    test-cases/stash-guard/*.json   -> block-carry-forward-stash.py    (PreToolUse)
    test-cases/closeout/*.json      -> verify-closeout-complete.py     (Stop)
    test-cases/sprint-cards/*.json  -> require-sprint-cards.py         (PreToolUse)
    test-cases/heredoc-guard/*.json -> block-heredoc-python-backslash.py (PreToolUse)
    test-cases/staging-guard/*.json -> block-blind-staging.py          (PreToolUse)
    test-cases/commit-lock/*.json   -> block-commit-during-mutation.py (PreToolUse)
    test-cases/velocity-warn/*.json -> warn-commit-without-velocity.py (PreToolUse)

Prints a PASS/FAIL line per case and a summary. Exit 0 when every case passes, 1 when any fails, 2 when the
runner itself could not run (a missing hook or python, a fixture that would not build, an unknown --only-route, or
a run in which no case ran: "0 total" is never a pass).

Port review (docs/sprints/SPRINT_85_PLAN.md Task 9; progress folder port_review.md). Differences from the
PowerShell runner: an unknown case prefix and a missing route folder are FAIL (they were a SKIP or silent);
fixture git failures stop the run; a case that runs past 120 seconds is a FAIL; case files are read as UTF-8; a
route folder with no cases is a FAIL. The hooks run under `python` on PATH (python3 if there is no python), as the
PowerShell runner did, not under whatever interpreter runs this file.

Test cases must be DETERMINISTIC: use "branch_override" and point "cwd" at a fixture under test-cases/fixtures/.
Three placeholders are filled in at run time (real git state / real lock folders are needed):
    {{REPO_MODIFIED}} {{REPO_STAGED}}                    velocity-warn: docs/CODING_VELOCITY.md modified / staged
    {{LOCK_ACTIVE}} {{LOCK_STALE}} {{LOCK_BAD}} {{LOCK_NONE}}   commit-lock: rebuilt IMMEDIATELY BEFORE EACH case,
        because a lock goes stale after 15 minutes and a suite that runs for minutes outlives a fixed fixture.

Usage:
    python .claude/hooks/run-test-cases.py [--only-route staging-guard [stash-guard ...]] [--python PATH]
'--only-route' names a folder; '(top)' is the top level. Omit it to run everything (AC-1 and the pre-commit run).

What this does NOT catch: a hook whose registration in .claude/settings.json is wrong (it runs the file
directly); the live harness stdin framing; a hook that only misbehaves on an input no recorded case contains.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
import common  # noqa: E402
import mutation_lock  # noqa: E402

CASES_DIR = HERE / "test-cases"
CASE_TIMEOUT_SECONDS = 120

# subdirectory name ('' = the top level) -> hook script
ROUTES = {
    "": "sprint-auto-advance.py",
    "stash-guard": "block-carry-forward-stash.py",
    "closeout": "verify-closeout-complete.py",
    "sprint-cards": "require-sprint-cards.py",
    "heredoc-guard": "block-heredoc-python-backslash.py",
    "staging-guard": "block-blind-staging.py",
    "commit-lock": "block-commit-during-mutation.py",
    "velocity-warn": "warn-commit-without-velocity.py",
}


class RunnerError(Exception):
    """The runner could not run (not a failed case)."""


def _git(repo: Path, *args: str) -> None:
    code, _out = common.git("-C", str(repo), "-c", "commit.gpgsign=false", *args)
    if code != 0:
        raise RunnerError(f"fixture git failed (exit {code}): git -C {repo} {' '.join(args)}")


def build_velocity_repos(root: Path) -> dict:
    """Two throwaway repos: docs/CODING_VELOCITY.md modified, and the same file staged."""
    repos = {}
    for kind in ("MODIFIED", "STAGED"):
        repo = root / kind.lower()
        (repo / "docs").mkdir(parents=True)
        (repo / "mobile-app").mkdir()
        _git(repo, "init", "-q")
        (repo / "docs" / "CODING_VELOCITY.md").write_text("v1", encoding="utf-8")
        (repo / "a.txt").write_text("a", encoding="utf-8")
        (repo / "mobile-app" / "keep.txt").write_text("k", encoding="utf-8")
        _git(repo, "add", "-A")
        _git(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init")
        (repo / "docs" / "CODING_VELOCITY.md").write_text("v2", encoding="utf-8")
        if kind == "STAGED":
            _git(repo, "add", "docs/CODING_VELOCITY.md")
        repos[kind] = common.normalize_path(str(repo))
    return repos


def build_lock_projects(root: Path, case_name: str) -> dict:
    """Four project folders for one commit-lock case: a fresh lock, a 60 minute old lock, an
    unparseable lock, and no lock folder."""
    projects = {}
    now = common.utc_now()
    # mutation_lock finds its folder from CLAUDE_PROJECT_DIR first. In a hook context that variable names the
    # REAL repo, so it is removed while the fixtures are written: a fixture lock must never reach the real
    # .claude/mutation-locks/ (it would block every commit for 15 minutes).
    saved = os.environ.pop("CLAUDE_PROJECT_DIR", None)
    try:
        for kind in ("ACTIVE", "STALE", "BAD", "NONE"):
            project = root / f"lock_{case_name}_{kind.lower()}"
            (project / ".claude").mkdir(parents=True)
            if kind == "BAD":
                lock_dir = project / ".claude" / "mutation-locks"
                lock_dir.mkdir()
                (lock_dir / "a.md.json").write_text("{not json", encoding="utf-8")
            elif kind != "NONE":
                # Made by the same Python helper agents use (F329 R-4), so the commit-lock cases prove the
                # commit gate reads the locks that helper writes.
                created = now - timedelta(minutes=60) if kind == "STALE" else now
                mutation_lock.new_lock("a.md", "runner fixture", "run-test-cases", start=str(project), now=created)
            projects[kind] = common.normalize_path(str(project))
    finally:
        if saved is not None:
            os.environ["CLAUDE_PROJECT_DIR"] = saved
    return projects


def expand(payload: str, repos: dict, locks: dict | None) -> str:
    out = payload.replace("{{REPO_MODIFIED}}", repos["MODIFIED"]).replace("{{REPO_STAGED}}", repos["STAGED"])
    for kind in ("ACTIVE", "STALE", "BAD", "NONE"):
        out = out.replace("{{LOCK_" + kind + "}}", locks[kind] if locks else "")
    return out


def warning_printed(stdout: str) -> bool:
    """True when stdout parses as JSON with a non-empty hookSpecificOutput.additionalContext. A stdout
    that merely contains the word is not a warning Claude Code can read (improvement review H7)."""
    if not stdout.strip():
        return False
    try:
        return bool(json.loads(stdout)["hookSpecificOutput"]["additionalContext"])
    except (ValueError, KeyError, TypeError):
        return False


def expected_exit(name: str) -> int | None:
    if name.startswith("allow-") or name.startswith("warn-"):
        return 0
    if name.startswith("violation-"):
        return 2
    return None


def run_hook(python: str, hook: Path, payload: str, clear_project_dir: bool) -> tuple[int | None, str]:
    """Run one hook as a child process. Returns (exit code, stdout); (None, reason) when it ran too long."""
    env = dict(os.environ)
    if clear_project_dir:
        # commit-lock cases: the hook must find its lock folder from the payload cwd, and CLAUDE_PROJECT_DIR wins.
        env.pop("CLAUDE_PROJECT_DIR", None)
    try:
        done = subprocess.run([python, str(hook)], input=payload.encode("utf-8"), capture_output=True,
                              env=env, timeout=CASE_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        return None, f"timed out after {CASE_TIMEOUT_SECONDS} seconds"
    return done.returncode, done.stdout.decode("utf-8", errors="replace")


def run_all(only_routes: list | None = None, python: str | None = None, cases_dir: Path = CASES_DIR,
            hooks_dir: Path = HERE, routes: dict | None = None, out=print) -> tuple[int, int]:
    """Run the suite. Returns (passed, failed). `out` receives each report line."""
    # The interpreter .claude/settings.json runs every hook with: "python" on PATH (as the PowerShell runner
    # did, which also accepted python3); sys.executable is NOT assumed to be the same program.
    python = python or common.find_tool("python", "python3")
    if not python:
        raise RunnerError("python not found on PATH (needed to run the hooks).")
    routes = routes if routes is not None else ROUTES
    if not cases_dir.is_dir():
        raise RunnerError(f"Cases dir not found: {cases_dir}")
    known = {route or "(top)" for route in routes}
    unknown = sorted(set(only_routes or []) - known)
    if unknown:
        # A mistyped --only-route used to run nothing and report "0 total" with exit 0 (a vacuous pass).
        raise RunnerError(f"unknown route(s): {', '.join(unknown)}; known: {', '.join(sorted(known))}")
    passed = failed = 0
    with tempfile.TemporaryDirectory(prefix="hook_repos_") as tmp:
        root = Path(tmp)
        repos = build_velocity_repos(root / "repos")
        for route in sorted(routes):
            key = route or "(top)"
            if only_routes and key not in only_routes:
                continue
            folder = cases_dir / route if route else cases_dir
            hook = hooks_dir / routes[route]
            if not hook.exists():
                raise RunnerError(f"Hook not found: {hook}")
            if not folder.is_dir():
                out(f"FAIL {key} (route folder missing: {folder})")
                failed += 1
                continue
            # Top-level folder: only its own files (subfolders are other routes).
            case_files = sorted(folder.glob("*.json"), key=lambda p: p.name.lower())
            if not case_files:
                out(f"FAIL {key} (route folder holds no cases: {folder})")
                failed += 1
                continue
            for case in case_files:
                name = case.stem
                label = f"{route}/{name}" if route else name
                expected = expected_exit(name)
                if expected is None:
                    out(f"FAIL {label} (unknown prefix: a case name starts with allow-, violation- or warn-)")
                    failed += 1
                    continue
                locks = build_lock_projects(root / "locks", name) if route == "commit-lock" else None
                payload = expand(case.read_bytes().decode("utf-8-sig"), repos, locks)
                actual, stdout = run_hook(python, hook, payload, clear_project_dir=(route == "commit-lock"))
                if actual is None:
                    out(f"FAIL {label} ({stdout})")
                    failed += 1
                    continue
                warned = warning_printed(stdout)
                if name.startswith("warn-"):
                    warn_ok = warned
                elif name.startswith("allow-"):
                    warn_ok = not warned
                else:
                    warn_ok = True
                if actual == expected and warn_ok:
                    out(f"PASS {label} (exit {actual})")
                    passed += 1
                else:
                    out(f"FAIL {label} (expected {expected}, got {actual}; warning printed: {warned})")
                    failed += 1
    return passed, failed


def main(argv: list | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Run the recorded hook test cases.")
    parser.add_argument("--only-route", nargs="+", default=None, metavar="ROUTE")
    parser.add_argument("--python", default=None, help="interpreter that runs each hook (default: python on PATH)")
    args = parser.parse_args(argv)
    try:
        passed, failed = run_all(args.only_route, args.python, out=lambda line: print(line, flush=True))
    except RunnerError as exc:
        print(f"RUNNER ERROR: {exc}", file=sys.stderr)
        return 2
    print()
    print(f"Result: {passed} passed, {failed} failed, {passed + failed} total")
    if passed + failed == 0:
        print("RUNNER ERROR: no case ran, so nothing was checked.", file=sys.stderr)
        return 2
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
