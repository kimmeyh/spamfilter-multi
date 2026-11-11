"""Gate: no live code RUNS a script file that the repository no longer has (Sprint 85 5.1.2 M2).

Why: the F335 port deleted `build-with-secrets.ps1`, and `mobile-app/scripts/setup-android-oauth.ps1:100` still ran
it through `Join-Path $PSScriptRoot "build-with-secrets.ps1"`. Nothing failed until a person ran step 4 of the OAuth
walkthrough. The ADR-0051 ports delete many scripts; every caller has to move with them.

What it checks: every tracked script, hook, workflow and JSON config file outside `archive/`, `docs/` and the test
folders. A line that RUNS something (Join-Path, -File, a leading or chained `&`, `.\\`, python, bash, pwsh,
powershell, a JSON "command") and names a `*.ps1`, `*.py` or `*.sh` file must name a file that some tracked path has.

What it does NOT catch: a call built from pieces (`"build-" + name`), a script named only in prose or a comment (those
are history, and docs/ keeps many on purpose), a name that still exists somewhere else in the repo (it matches by file
name, not by path), and untracked files such as `.claude/settings.local.json`.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

EXTENSIONS = (".ps1", ".psm1", ".py", ".sh", ".bat", ".cmd", ".yml", ".yaml", ".json")
SKIP_PREFIXES = ("archive/", "Archive/", "docs/")
SCRIPT_NAME = re.compile(r"(?<![\w.-])([A-Za-z0-9_][\w-]*\.(?:ps1|py|sh))\b")
RUNS = re.compile(r"Join-Path|-File\b|^\s*&|[;|]\s*&|\.\\|\bpython3?\b|\bbash\b|\bpwsh\b|\bpowershell\b"
                  r"|\"command\"\s*:")

# Lines that name a missing script without running it: docstring text of a hook. (file, script name).
ALLOWED = {
    (".claude/hooks/block-heredoc-python-backslash.py", "block-heredoc-python-backslash.ps1"),  # port history
    (".claude/hooks/block-heredoc-python-backslash.py", "script.py"),  # an example in the block message
}


def skipped(path: str) -> bool:
    base = path.rsplit("/", 1)[-1]
    return (not path.endswith(EXTENSIONS) or path.startswith(SKIP_PREFIXES) or base.startswith("0")
            or "/tests/" in path or "/test-cases/" in path or base.startswith("test_"))


def missing_runs(path: str, text: str, known: set) -> list:
    """(line number, script name) for each line of [text] that runs a script whose name is not in [known]."""
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#") or not RUNS.search(line):
            continue
        for match in SCRIPT_NAME.finditer(line):
            name = match.group(1)
            if name.lower() not in known and (path, name) not in ALLOWED:
                found.append((number, name))
    return found


class NoRunsOfMissingScripts(unittest.TestCase):
    def test_every_script_a_line_runs_exists(self):
        listed = subprocess.run(["git", "-C", str(REPO), "ls-files"], capture_output=True, text=True, check=True)
        files = listed.stdout.splitlines()
        self.assertGreater(len(files), 100, "git ls-files returned too few files to trust this check")
        known = {f.rsplit("/", 1)[-1].lower() for f in files}
        problems = []
        checked = 0
        for path in files:
            if skipped(path):
                continue
            full = REPO / path
            if not full.is_file():
                continue
            checked += 1
            text = full.read_text(encoding="utf-8", errors="replace")
            problems += [f"{path}:{n}: runs {name}, which no tracked file has"
                         for n, name in missing_runs(path, text, known)]
        self.assertGreater(checked, 50, "too few files checked; the file filter is wrong")
        self.assertEqual(problems, [], "\n".join(problems))

    def test_the_m2_shape_is_caught(self):
        line = '$buildScript = Join-Path $PSScriptRoot "build-with-secrets.ps1"\n& $buildScript -InstallToEmulator'
        self.assertEqual(missing_runs("mobile-app/scripts/x.ps1", line, {"build-with-secrets.py"}),
                         [(1, "build-with-secrets.ps1")])

    def test_other_run_shapes_are_caught(self):
        known = {"present.py"}
        for line in ("python -I scripts/gone.py --x", "& .\\gone.ps1", '"command": "python .claude/hooks/gone.py"',
                     "powershell -NoProfile -File C:/x/gone.ps1", "bash scripts/gone.sh"):
            self.assertEqual(len(missing_runs("a.ps1", line, known)), 1, line)

    def test_comments_prose_and_existing_scripts_pass(self):
        known = {"present.py"}
        for line in ("# was run by gone.ps1 before Sprint 85", "Write-Host 'see gone.ps1'", "python present.py"):
            self.assertEqual(missing_runs("a.ps1", line, known), [], line)


if __name__ == "__main__":
    unittest.main()
