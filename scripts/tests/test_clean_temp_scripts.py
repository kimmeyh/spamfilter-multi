"""Tests for scripts/clean-temp-scripts.py (F330, Sprint 85).

What these tests do NOT catch: they use small fixture trees; they do not prove behavior on a root with
hundreds of thousands of files (speed), on a locked file held open by another process (the failure is
simulated by patching Path.unlink), or on Windows junctions (only a symbolic link is tried, and the test is
skipped where the account may not create one).
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("clean_temp_scripts", SCRIPTS / "clean-temp-scripts.py")
cts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cts)

OLD = time.time() - 30 * 86400


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name).resolve()
        self.root = self.base / "claude"
        self.root.mkdir()

    def make(self, rel: str, old: bool = True, root: Path | None = None) -> Path:
        path = (root or self.root) / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("x", encoding="utf-8")
        if old:
            os.utime(path, (OLD, OLD))
        return path

    def run_main(self, *argv: str) -> tuple[int, str]:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            try:
                code = cts.main(list(argv))
            except SystemExit as exc:
                code = exc.code
        return code, buffer.getvalue()


class Selection(Base):
    def test_report_only_lists_stale_helpers_and_deletes_nothing(self):
        stale = self.make("projA/s1/scratchpad/old.py")
        fresh = self.make("projA/s1/scratchpad/new.py", old=False)
        code, out = self.run_main("--report-only", "--root", str(self.root))
        self.assertEqual(code, 0)
        self.assertIn("Stale files     : 1", out)
        self.assertIn("WOULD DELETE (report only):", out)
        self.assertIn(os.path.join("projA", "s1", "scratchpad", "old.py"), out)
        self.assertNotIn("new.py", out)
        self.assertTrue(stale.exists() and fresh.exists())

    def test_delete_removes_only_stale_scratchpad_files_of_swept_types(self):
        stale = [self.make("p/s/scratchpad/a.py"), self.make("p/s/scratchpad/b.TXT"), self.make("p/s/scratchpad/sub/c.json")]
        keep = [
            self.make("p/s/scratchpad/fresh.py", old=False),
            self.make("p/s/scratchpad/data.bin"),            # type not swept
            self.make("p/s/notes/old.py"),                   # not in a scratchpad folder
            self.make("p/my-scratchpad-notes/old.py"),       # the word is only part of a folder name
        ]
        code, out = self.run_main("--root", str(self.root))
        self.assertEqual(code, 0)
        self.assertIn("Deleted: 3", out)
        for path in stale:
            self.assertFalse(path.exists(), path)
        for path in keep:
            self.assertTrue(path.exists(), path)

    def test_a_sibling_folder_whose_name_starts_like_the_root_is_never_touched(self):
        sibling = self.make("p/s/scratchpad/old.py", root=self.base / "claude2")
        self.make("p/s/scratchpad/old.py")
        self.run_main("--root", str(self.root))
        self.assertTrue(sibling.exists())

    def test_days_zero_selects_a_file_changed_a_moment_ago(self):
        self.make("p/s/scratchpad/now.py", old=False)
        time.sleep(0.05)
        _code, out = self.run_main("--report-only", "--days", "0", "--root", str(self.root))
        self.assertIn("Stale files     : 1", out)

    def test_nothing_stale(self):
        self.make("p/s/scratchpad/new.py", old=False)
        code, out = self.run_main("--root", str(self.root))
        self.assertEqual(code, 0)
        self.assertIn("Nothing to clean.", out)

    def test_symbolic_links_are_neither_followed_nor_deleted(self):
        outside = self.make("outside_target.py", root=self.base / "elsewhere")
        link = self.root / "p" / "s" / "scratchpad" / "link.py"
        link.parent.mkdir(parents=True)
        try:
            os.symlink(outside, link)
        except (OSError, NotImplementedError):
            self.skipTest("symbolic links cannot be created here")
        _code, report = self.run_main("--report-only", "--root", str(self.root))
        self.assertNotIn("link.py", report)  # not listed at all (the delete-time guard is a second layer)
        self.run_main("--root", str(self.root))
        self.assertTrue(outside.exists())
        self.assertTrue(link.is_symlink())


class Promotion(Base):
    def test_same_name_in_the_same_project_is_a_candidate_with_project_prefix(self):
        self.make("projA/s1/scratchpad/helper.py")
        self.make("projA/s2/scratchpad/helper.py")
        _code, out = self.run_main("--report-only", "--root", str(self.root))
        self.assertIn("PROMOTION CANDIDATES", out)
        self.assertIn("projA/helper.py", out)
        self.assertIn("written 2 times", out)

    def test_same_name_in_different_projects_is_not_a_candidate(self):
        self.make("projA/s1/scratchpad/helper.py")
        self.make("projB/s1/scratchpad/helper.py")
        _code, out = self.run_main("--report-only", "--root", str(self.root))
        self.assertNotIn("PROMOTION CANDIDATES", out)


class FailurePaths(Base):
    def test_missing_root_exits_0_with_message(self):
        code, out = self.run_main("--root", str(self.base / "absent"))
        self.assertEqual(code, 0)
        self.assertIn("Scratchpad root not found", out)
        self.assertIn("Nothing to clean.", out)

    def test_negative_days_is_rejected_with_exit_2(self):
        victim = self.make("p/s/scratchpad/old.py")
        with contextlib.redirect_stderr(io.StringIO()):
            code, _out = self.run_main("--days", "-1", "--root", str(self.root))
        self.assertEqual(code, 2)
        self.assertTrue(victim.exists())

    def test_a_failed_delete_is_reported_and_counted(self):
        self.make("p/s/scratchpad/a.py")
        self.make("p/s/scratchpad/b.py")
        with mock.patch.object(Path, "unlink", side_effect=PermissionError("locked")):
            code, out = self.run_main("--root", str(self.root))
        self.assertEqual(code, 0)  # same as the PowerShell original
        self.assertEqual(out.count("FAILED:"), 2)
        self.assertIn("Deleted: 0", out)
        self.assertIn("Failed : 2", out)

    def test_an_unreadable_folder_is_reported_not_hidden(self):
        self.make("p/s/scratchpad/a.py")
        self.make("q/s/scratchpad/b.py")
        real_scandir = os.scandir

        def flaky(path):
            if os.path.basename(str(path)) == "q":
                raise PermissionError("denied")
            return real_scandir(path)

        with mock.patch.object(os, "scandir", side_effect=flaky):
            _code, out = self.run_main("--report-only", "--root", str(self.root))
        self.assertIn("Unreadable folders: 1", out)
        self.assertIn("Stale files     : 1", out)

    def test_deletion_is_skipped_for_a_file_that_resolves_outside_the_root(self):
        victim = self.make("p/s/scratchpad/a.py")
        outside = self.base / "outside"
        outside.mkdir()
        with mock.patch.object(Path, "resolve", autospec=True,
                               side_effect=lambda self_, strict=False: outside / "x.py" if self_ == victim else self_):
            _code, out = self.run_main("--root", str(self.root))
        self.assertIn("SKIPPED (outside root)", out)
        self.assertTrue(victim.exists())


if __name__ == "__main__":
    unittest.main()
