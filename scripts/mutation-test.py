"""Mutation-test a test (or a hook suite): break the code it guards, run it, confirm it goes red, restore the
code byte for byte (F329, Sprint 85; ADR-0051). Python port of scripts/mutation-test.ps1.

History (Sprint 74 retro IMP-4): promoted from session helpers written twice in this project. Two defects of
the scratch versions stay fixed: the spec is read as UTF-8, and the anchor follows the TARGET file's line
endings (a find string written with LF matches a CRLF file and the other way round).

For each mutation: the anchor must match EXACTLY ONCE (otherwise it is reported and NOT run); a mutation lock
is taken (commits are blocked while a tracked file is deliberately broken, CLAUDE.md Sprint 65 IMP-5); the file
is mutated; the check runs; the original bytes are restored and verified; the lock is released.
    KILLED       the check exited non-zero
    SURVIVED     the check exited 0 (the test does not guard what it claims to)
Sprint 75 retro IMP-1: two ways a "KILLED" proved nothing are refused.
    BASELINE FAILS  each distinct check runs ONCE on the unchanged code first and must pass; otherwise every
                    later "KILLED" is meaningless and those mutations are not run. A spec may set
                    "baseline": false for a slow check (a full rebuild).
    INVALID         a mutant that does not COMPILE fails the check for the wrong reason. The check output is
                    scanned for a Dart or C++ compile error. NEW in the port: a mutated .py file is compiled
                    with compile() before the check runs (Python is a target language now, ADR-0051); a
                    SyntaxError is INVALID and the check is not run.
Added in the port: TIMED OUT (a check that runs past its "timeout" seconds, default 1800, is stopped with its
process tree; it fails the run and is not counted KILLED); an empty spec is an error (it used to pass with
nothing run); a RESTORE FAILED line is part of the report instead of a throw that lost the report.

Spec file: a JSON array (a single object is accepted) of mutations, each:
    name      label for the report
    file      path relative to the repo root
    find      exact text to replace (must occur once)
    replace   replacement text
    test      a Flutter test path relative to mobile-app/  (runs `flutter test <test>`)
      OR
    command   any command line, run from the repo root (for example `python -I -m unittest ...`)
    baseline  optional; false skips the unchanged-code baseline run
    timeout   optional; seconds the check may run (default 1800)

Usage:
    python scripts/mutation-test.py SPEC.json [--repo DIR]

An interrupt (Ctrl-C) restores the file before the script ends. A HARD kill (Stop-Process, TerminateProcess, a
wrapping `timeout` command) cannot be handled by any program: the mutant stays in the file AND the lock stays held
(measured 2026-11-10), so `python .claude/hooks/lib/mutation_lock.py list` names the file; restore it with
`git diff` / `git checkout -- <file>` (or your saved copy), then `mutation_lock.py remove`. Do not wrap this
script in a short `timeout`; give a slow check its own "timeout" in the spec.

Exit 0 when every mutation was KILLED; exit 1 when any SURVIVED, was INVALID, TIMED OUT, failed its baseline,
or was NOT RUN (the check could not start: exit 127 or 9009); exit 2 for an unreadable spec.

What this does NOT catch: a mutant that is red for a reason other than the guarded behavior but is not a
compile error (a test that fails for any change to the file passes this check); a check that is red because of
a machine problem the same way on every run of that mutant (the baseline run is what catches an always-red check).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402
import mutation_lock  # noqa: E402

DEFAULT_TIMEOUT_SECONDS = 1800

# Compile-error signatures, matched against the check's OUTPUT, not its exit code.
# Dart (flutter test): "<file>.dart:12:3: Error:", "Compilation failed", 'Failed to load "...": ... Error'.
# MSVC: error C1234. Python: a traceback ends in SyntaxError / IndentationError / TabError.
COMPILE_ERROR = re.compile(
    r'(?m)\.dart:\d+:\d+: Error:|Compilation failed|Failed to load "[^"]+":[^\r\n]*Error|\berror C\d{4}\b'
    r'|^(?:SyntaxError|IndentationError|TabError):')


# Exit codes a shell gives when it cannot find or start the command: 127 (POSIX sh, and this script's own
# could-not-start code), 9009 (cmd.exe). Sprint 85 5.1.2 L1: with "baseline": false these were KILLED.
NOT_STARTED_CODES = (127, 9009)


class CheckResult:
    def __init__(self, code: int, output: str, timed_out: bool = False, not_started: bool = False):
        self.code = code
        self.output = output
        self.timed_out = timed_out
        # True when the check never ran (no flutter, the command could not start, or the shell could not
        # find it). Such a run proves nothing about the mutant, so it is NOT RUN, never KILLED.
        self.not_started = not_started or code in NOT_STARTED_CODES


def kill_tree(proc) -> None:
    """Kill the check and everything it started. Windows: taskkill /T (common._kill_tree). POSIX: the whole
    process group (the shell is only the first process of a `command` check). NOT run on Linux in Sprint 85:
    the POSIX branch is covered by a test that patches os.name, not by a real group kill."""
    if os.name == "nt":
        common._kill_tree(proc)
        return
    try:
        os.killpg(proc.pid, getattr(signal, "SIGKILL", 9))
    except OSError:
        proc.kill()


def invoke_check(spec: dict, repo: Path) -> CheckResult:
    """Run a check (flutter test, or a command line) and return its exit code and output.

    The child runs to completion whatever its exit code: a FAILING check is the KILLED case, never an error
    here. On a timeout the whole process tree is killed (kill_tree)."""
    if spec.get("test"):
        flutter = shutil.which("flutter")
        if not flutter:
            return CheckResult(127, "flutter was not found on PATH", not_started=True)
        argv: object = [flutter, "test", str(spec["test"])]
        cwd, shell = repo / "mobile-app", False
    else:
        argv, cwd, shell = str(spec["command"]), repo, True
    timeout = spec.get("timeout") or DEFAULT_TIMEOUT_SECONDS
    # A same-size mutant written in the same second as the source it replaces can be hidden by a stale .pyc
    # (Python compares the source's whole-second mtime and size). No bytecode is written during a mutation run,
    # and the mutant's mtime is also moved forward (see mutate_file), so a Python check always sees the mutant.
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    try:
        # POSIX: a new session, so the shell and everything it starts share one process group to kill.
        proc = subprocess.Popen(argv, cwd=str(cwd), shell=shell, stdin=subprocess.DEVNULL, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                start_new_session=(os.name != "nt"))
    except OSError as exc:
        return CheckResult(127, f"could not start the check: {exc}", not_started=True)
    try:
        out, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_tree(proc)
        try:
            out, _ = proc.communicate(timeout=2)
        except Exception:  # noqa: BLE001 - the pipes may stay open if the kill failed
            out = b""
        return CheckResult(124, out.decode("utf-8", errors="replace"), timed_out=True)
    return CheckResult(proc.returncode, out.decode("utf-8", errors="replace"))


def python_compile_error(path: Path, text: str) -> str | None:
    """The SyntaxError text when `text` (the mutated source of a .py file) does not compile, else None.
    Compiled from BYTES, as the interpreter reads a file: a leading BOM or a coding line is then handled."""
    text = text.encode("utf-8")
    if path.suffix.lower() != ".py":
        return None
    try:
        compile(text, str(path), "exec", dont_inherit=True)
    except (SyntaxError, ValueError) as exc:  # ValueError: source with a null byte
        return f"{type(exc).__name__}: {exc}"
    return None


def anchor_forms(text: str, find: str, replace: str) -> tuple[str, str]:
    """find and replace in the target file's line endings (CRLF when the file holds any CRLF)."""
    find = find.replace("\r\n", "\n")
    replace = replace.replace("\r\n", "\n")
    if "\r\n" in text:
        find = find.replace("\n", "\r\n")
        replace = replace.replace("\n", "\r\n")
    return find, replace


def mutate_file(path: Path, mutated: bytes) -> None:
    """Write the mutant and move its mtime at least two seconds past the original's (stale .pyc guard).
    The RESTORE keeps a normal write time on purpose: build tools that compare mtimes (flutter test) must see
    the restored file as newer than the moment the mutant was compiled, so they compile it again."""
    before = path.stat()
    path.write_bytes(mutated)
    os.utime(path, ns=(before.st_atime_ns, max(path.stat().st_mtime_ns, before.st_mtime_ns + 2_000_000_000)))


def restore(path: Path, original: bytes) -> bool:
    """Write the original bytes back and verify them. True when the file is byte for byte restored."""
    try:
        path.write_bytes(original)
        return path.read_bytes() == original
    except OSError:
        return False


def run_mutations(specs: list, repo: Path, progress=None) -> tuple[list, bool]:
    """Run every mutation. Returns (report lines, all killed)."""
    results: list = []
    all_killed = True
    baselines: dict = {}
    for spec in specs:
        name = spec.get("name", "(unnamed)")
        rel = spec.get("file", "")
        path = repo / rel
        if not rel or not path.is_file():
            results.append(f"{name}: FILE NOT FOUND ({rel}) -- not run")
            all_killed = False
            continue
        original = path.read_bytes()
        try:
            text = original.decode("utf-8")
        except UnicodeDecodeError:
            results.append(f"{name}: NOT UTF-8 ({rel}) -- not run")
            all_killed = False
            continue

        find, replace = anchor_forms(text, str(spec.get("find", "")), str(spec.get("replace", "")))
        count = text.count(find)
        if count != 1:
            results.append(f"{name}: ANCHOR MATCHED {count} TIMES -- not run")
            all_killed = False
            continue
        if not spec.get("test") and not spec.get("command"):
            results.append(f"{name}: spec has neither 'test' nor 'command' -- not run")
            all_killed = False
            continue

        mutated = text.replace(find, replace, 1)
        syntax = python_compile_error(path, mutated)

        # IMP-1 baseline: the check must PASS on the unchanged code (a Python syntax-invalid mutant never
        # reaches the check, so it needs no baseline).
        if syntax is None and spec.get("baseline") is not False:
            key = ("test", spec["test"]) if spec.get("test") else ("cmd", spec["command"])
            if key not in baselines:
                if progress:
                    progress(f"baseline: {key[0]} {key[1]}")
                baselines[key] = invoke_check(spec, repo)
            if baselines[key].code != 0:
                results.append(f"{name}: BASELINE FAILS (the check fails on unchanged code) -- not run")
                all_killed = False
                continue

        if syntax is not None:
            results.append(f"{name}: INVALID -- the mutant did not compile ({syntax}); rewrite it so it compiles")
            all_killed = False
            continue

        if progress:
            progress(f"mutant: {name}")
        mutation_lock.new_lock(rel, f"mutation: {name}", "mutation-test.py", start=str(repo))
        restored = False
        try:
            mutate_file(path, mutated.encode("utf-8"))
            check = invoke_check(spec, repo)
            if check.timed_out:
                results.append(f"{name}: TIMED OUT -- the check ran past its limit and was stopped; not counted KILLED")
                all_killed = False
            elif check.not_started:
                results.append(f"{name}: NOT RUN -- the check did not start (exit {check.code}); not counted KILLED")
                all_killed = False
            elif check.code == 0:
                results.append(f"{name}: SURVIVED")
                all_killed = False
            elif COMPILE_ERROR.search(check.output):
                first = COMPILE_ERROR.search(check.output).group(0)
                results.append(f"{name}: INVALID -- the mutant did not compile ({first}); rewrite it so it compiles")
                all_killed = False
            else:
                results.append(f"{name}: KILLED")
        finally:
            restored = restore(path, original)
            if restored:
                mutation_lock.remove_lock(rel, start=str(repo))
        if not restored:
            results.append(f"{name}: RESTORE FAILED for {path} -- the lock stays HELD; restore the file by hand "
                           "(git diff, or git checkout the file); later mutations were not run")
            return results, False
    return results, all_killed


def load_specs(spec_file: Path) -> list:
    raw = json.loads(spec_file.read_bytes().decode("utf-8-sig"))
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list) or not all(isinstance(item, dict) for item in raw):
        raise ValueError("the spec must be a JSON array of objects")
    return raw


def main(argv: list | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Mutation-test a test: break the code, confirm red, restore.")
    parser.add_argument("spec_file")
    parser.add_argument("--repo", default=str(REPO), help="repo root the spec paths are relative to")
    args = parser.parse_args(argv)
    try:
        specs = load_specs(Path(args.spec_file))
    except (OSError, ValueError) as exc:
        print(f"Could not read the spec {args.spec_file}: {exc}", file=sys.stderr)
        return 2
    if not specs:
        print("The spec holds no mutations -- nothing was tested.", file=sys.stderr)
        return 1
    results, all_killed = run_mutations(specs, Path(args.repo).resolve(),
                                        progress=lambda line: print(f"[mutation-test] {line}", file=sys.stderr, flush=True))
    for line in results:
        print(line)
    return 0 if all_killed else 1


if __name__ == "__main__":
    sys.exit(main())
