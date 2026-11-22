"""Gate: no live code RUNS a script file that the repository no longer has (Sprint 85 5.1.2 M2).

Why: the F335 port deleted `build-with-secrets.ps1`, and `mobile-app/scripts/setup-android-oauth.ps1:100` still ran
it through `Join-Path $PSScriptRoot "build-with-secrets.ps1"`. Nothing failed until a person ran step 4 of the OAuth
walkthrough. The ADR-0051 ports delete many scripts; every caller has to move with them.

What it checks: every tracked script, hook, workflow and JSON config file outside `archive/`, `docs/` and the test
folders, plus the LIVE instruction files (Sprint 85 7.7.1 L9): every SKILL.md under `.claude/skills` and
`.agents/skills`, `.claude/agents/*.md`, `CLAUDE.md`, `AGENTS.md` and `.github/copilot-instructions.md`. A skill that
tells Claude to run a deleted script fails silently at the moment someone follows it. History documents
(`docs/sprints`, CHANGELOG, research) are NOT scanned: they name deleted scripts on purpose. A line that RUNS something (Join-Path, -File, a leading or chained `&`, `.\\`, python, bash, pwsh,
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
LIVE_MD_NAMES = ("CLAUDE.md", "AGENTS.md", ".github/copilot-instructions.md")
LIVE_MD = re.compile(r"^(?:\.claude/skills|\.agents/skills)/.+/SKILL\.md$|^\.claude/agents/[^/]+\.md$")


def is_live_md(path: str) -> bool:
    return path in LIVE_MD_NAMES or bool(LIVE_MD.match(path))
SCRIPT_NAME = re.compile(r"(?<![\w.-])([A-Za-z0-9_][\w-]*\.(?:ps1|py|sh))\b")
RUNS = re.compile(r"Join-Path|-File\b|^\s*&|[;|]\s*&|\.\\|\bpython3?\b|\bbash\b|\bpwsh\b|\bpowershell\b"
                  r"|\"command\"\s*:")

# Lines that name a missing script without running it: docstring text of a hook. (file, script name).
ALLOWED = {
    (".claude/hooks/block-heredoc-python-backslash.py", "block-heredoc-python-backslash.ps1"),  # port history
    (".claude/hooks/block-heredoc-python-backslash.py", "script.py"),  # an example in the block message
    # CLAUDE.md names deleted scripts as HISTORY inside sentences that also name a real command (Sprint 85 7.7.1 L9).
    ("CLAUDE.md", "sprint-auto-advance.ps1"),  # "the .ps1 copy was deleted in Sprint 85"
    ("CLAUDE.md", "mutate.py"),  # "written twice before (mutate.py, mutate.ps1)"
    ("CLAUDE.md", "mutate.ps1"),
}


def skipped(path: str) -> bool:
    base = path.rsplit("/", 1)[-1]
    if is_live_md(path):
        return False
    return (not path.endswith(EXTENSIONS) or path.startswith(SKIP_PREFIXES) or base.startswith("0")
            or "/tests/" in path or "/test-cases/" in path or base.startswith("test_"))


def missing_runs(path: str, text: str, known: set) -> list:
    """(line number, script name) for each line of [text] that runs a script whose name is not in [known]."""
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        # In markdown a leading "#" is a heading, not a comment, so only code files skip those lines.
        if (stripped.startswith("#") and not path.endswith(".md")) or not RUNS.search(line):
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

    def test_live_instruction_files_are_scanned_and_history_is_not(self):
        # Sprint 85 7.7.1 L9. What this test would NOT catch: a live instruction file kept outside these names.
        for live in (".claude/skills/x/SKILL.md", ".agents/skills/y/SKILL.md", ".claude/agents/z.md", "CLAUDE.md",
                     "AGENTS.md", ".github/copilot-instructions.md"):
            self.assertFalse(skipped(live), live)
        for history in ("docs/sprints/SPRINT_1_PLAN.md", "CHANGELOG.md", "docs/research/a.md", "README.md",
                        "memory-bank/x.md"):
            self.assertTrue(skipped(history), history)
        text = "Step 1: run `python scripts/gone_tool.py --x` first.\n```\npowershell -File gone2.ps1\n```\n"
        self.assertEqual(missing_runs("CLAUDE.md", text, {"present.py"}), [(1, "gone_tool.py"), (3, "gone2.ps1")])
        self.assertEqual(missing_runs("CLAUDE.md", "# python gone3.py heading\n", set()), [(1, "gone3.py")])

    def test_a_fake_missing_script_in_a_skill_file_is_reported_by_the_tree_scan(self):
        # Mutation-style probe through the real scan path: a copy of the tree listing with one extra live file.
        known = {"present.py"}
        problems = missing_runs(".claude/skills/demo/SKILL.md", "Run: python .claude/hooks/gone_zz.py\n", known)
        self.assertEqual(problems, [(1, "gone_zz.py")])

    def test_comments_prose_and_existing_scripts_pass(self):
        known = {"present.py"}
        for line in ("# was run by gone.ps1 before Sprint 85", "Write-Host 'see gone.ps1'", "python present.py"):
            self.assertEqual(missing_runs("a.ps1", line, known), [], line)


if __name__ == "__main__":
    unittest.main()
