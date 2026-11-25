"""Tests for scripts/subagent-brief.py (F344, Sprint 86).

`files` runs against a throwaway git repository built in a temp folder; `block` reads the real workflow document
once (the canonical text) and fake documents for the failure cases.

Run: python -I -m unittest discover -s scripts/tests -p "test_subagent_brief*.py" -v

Test list and what each does NOT catch:
  test_block_prints_the_canonical_block: the printed text equals the fenced block in the real document, and a
      --task value replaces <task-name>. NOT caught: a block whose rules are present but wrong in meaning
      (progress_and_restart_block_test.dart checks the key phrases the same way).
  test_block_missing_document_exits_two: REAL FAILING INPUT (AC-2): a document path that does not exist -> exit 2
      and a stderr message naming the file; nothing on stdout.
  test_block_missing_block_exits_two: REAL FAILING INPUT: a document with no block -> exit 2, message names the block.
  test_block_cut_short_exits_two: a block that lost "STATUS: FINISHED" is refused, not printed half.
  test_files_lists_changed_files_and_excludes_0_and_archive: N counts only given files; 0* at the root and
      archive/ are Excluded; a 0* file in a subfolder is given. NOT caught: a Harold document that does not start
      with 0.
  test_files_leaves_out_deleted_files: a deleted file is not listed.
  test_files_empty_range_exits_one: nothing changed -> exit 1 with a visible FAIL line.
  test_files_only_excluded_exits_one: only a 0* file changed -> exit 1 and the message says excluded.
  test_files_bad_range_exits_two: REAL FAILING INPUT: an unknown ref -> exit 2 and the range is named.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "subagent-brief.py"
_spec = importlib.util.spec_from_file_location("subagent_brief_mod", TOOL)
brief = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(brief)

GOOD_BLOCK = ("PROGRESS AND RESTART (apply to yourself)\n1. Your progress folder is <SCRATCH>\\<task-name>\\ .\n"
              "2. FIRST ACTION: read it.\n5. MUTATION LOCK: restore.\n6. NEVER repeat a release or store action.\n"
              "4. The LAST line is \"STATUS: FINISHED\".\n7. Your reply starts with \"Resumed:\".\n")


def run_main(*argv: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = brief.main(list(argv))
    return code, out.getvalue(), err.getvalue()


@unittest.skipUnless(shutil.which("git"), "git is required")
class FilesTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.invalid")
        self.git("config", "user.name", "t")
        self.git("config", "commit.gpgsign", "false")
        self.write("keep.txt", "k")
        self.write("gone.txt", "g")
        self.commit("base")
        self.git("tag", "base")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def git(self, *args: str) -> None:
        subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True)

    def write(self, name: str, text: str) -> None:
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def commit(self, message: str) -> None:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)

    def files(self, *extra: str) -> tuple[int, str, str]:
        return run_main("files", "--root", str(self.repo), "--range", "base..HEAD", *extra)

    def test_files_lists_changed_files_and_excludes_0_and_archive(self) -> None:
        self.write("lib/a.dart", "a")
        self.write("docs/0notes.md", "in a subfolder, so it is given")
        self.write("0feedback.txt", "root 0 file")
        self.write("archive/old.md", "old")
        self.commit("work")
        code, out, _ = self.files()
        self.assertEqual(code, 0)
        self.assertIn("Files to review (2):", out)
        self.assertIn("- lib/a.dart", out)
        self.assertIn("- docs/0notes.md", out)
        self.assertNotIn("- 0feedback.txt", out)
        self.assertIn("Excluded (2): 0feedback.txt, archive/old.md", out)
        self.assertIn('"Files read: M of 2"', out)

    def test_files_leaves_out_deleted_files(self) -> None:
        (self.repo / "gone.txt").unlink()
        self.write("new.txt", "n")
        self.commit("work")
        code, out, _ = self.files()
        self.assertEqual(code, 0)
        self.assertIn("Files to review (1):", out)
        self.assertNotIn("gone.txt", out)

    def test_files_empty_range_exits_one(self) -> None:
        code, out, _ = self.files()
        self.assertEqual(code, 1)
        self.assertIn("FAIL nothing to review", out)
        self.assertIn("no file changed", out)

    def test_files_only_excluded_exits_one(self) -> None:
        self.write("0feedback.txt", "x")
        self.commit("work")
        code, out, _ = self.files()
        self.assertEqual(code, 1)
        self.assertIn("only excluded files changed (1)", out)

    def test_files_bad_range_exits_two(self) -> None:
        code, out, err = run_main("files", "--root", str(self.repo), "--range", "no-such-ref..HEAD")
        self.assertEqual(code, 2)
        self.assertIn("no-such-ref..HEAD", err)
        self.assertEqual(out, "")


class BlockTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def doc(self, text: str) -> str:
        path = self.tmp / "doc.md"
        path.write_text(text, encoding="utf-8")
        return str(path)

    def test_block_prints_the_canonical_block(self) -> None:
        real = brief.DEFAULT_DOC.read_text(encoding="utf-8")
        start = real.index(brief.BLOCK_START)
        expected = real[start:real.index("```", start)].replace("\r\n", "\n").rstrip() + "\n"
        code, out, _ = run_main("block")
        self.assertEqual(code, 0)
        self.assertEqual(out, expected)
        code, out, _ = run_main("block", "--task", "f344-helpers", "--scratch", "C:\\scratch")
        self.assertEqual(code, 0)
        self.assertIn("C:\\scratch\\f344-helpers\\", out)
        self.assertNotIn("<task-name>", out)

    def test_block_replaces_placeholders_in_a_fake_document(self) -> None:
        code, out, _ = run_main("block", "--doc", self.doc("intro\n```text\n" + GOOD_BLOCK + "```\nafter\n"),
                                "--task", "t1")
        self.assertEqual(code, 0)
        self.assertIn("<SCRATCH>\\t1\\", out)
        self.assertNotIn("after", out)

    def test_block_missing_document_exits_two(self) -> None:
        code, out, err = run_main("block", "--doc", str(self.tmp / "nope.md"))
        self.assertEqual(code, 2)
        self.assertIn("nope.md", err)
        self.assertEqual(out, "")

    def test_block_missing_block_exits_two(self) -> None:
        code, out, err = run_main("block", "--doc", self.doc("# no block here\n"))
        self.assertEqual(code, 2)
        self.assertIn("PROGRESS AND RESTART", err)
        self.assertEqual(out, "")

    def test_block_cut_short_exits_two(self) -> None:
        cut = GOOD_BLOCK.replace('4. The LAST line is "STATUS: FINISHED".\n', "")
        code, out, err = run_main("block", "--doc", self.doc("```text\n" + cut + "```\n"))
        self.assertEqual(code, 2)
        self.assertIn("STATUS: FINISHED", err)
        self.assertEqual(out, "")


if __name__ == "__main__":
    unittest.main()
