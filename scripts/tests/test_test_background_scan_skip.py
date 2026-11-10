"""Tests for mobile-app/scripts/test-background-scan-skip.py (port of test-background-scan-skip.ps1, F334, Sprint 85).

The real check launches the Windows dev or prod .exe, which must not run here: a dev instance may be open,
and the cleanup stops every process at that PATH. So every test injects a fake WindowsOps (no process is
started) and fake log text. The one real-exe run is not done by these tests (see the sprint plan).

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_derive_version_reads_top_level_version_only: "version: 0.25.0+23" -> 0.25.0; an indented "version:"
      under another key is ignored. NOT caught: a pubspec whose version line has a leading tab.
  test_check_new_log_text_passes_only_with_all_assertions: the four assertions, each failing alone. NOT
      caught: a log line that contains the text in a different sentence (the match is a substring).
  test_not_windows_exits_one_before_any_setup: off Windows nothing is launched. NOT caught: a Windows host
      without the dist folder (that is the next test).
  test_missing_exe_exits_one: the dist .exe is absent -> exit 1, nothing launched. NOT caught: an .exe that
      exists but is stale (built from an older commit).
  test_proceeds_path_passes_and_cleans_up: the fake writes the two expected lines -> exit 0; the foreground
      and the scan are stopped; the leftover-process sweep ran. NOT caught: the real native mutex behavior
      (the fake writes the log text the probe would write).
  test_deferred_launch_fails_with_exit_two: the fake writes "Background scan skipped" instead -> exit 2 with
      assertion 1d named. NOT caught: a deferral message that is worded differently in main.cpp.
  test_foreground_that_exits_early_fails_with_exit_two: the UI process has already exited -> exit 2 and the
      scan is never launched. NOT caught: a UI that stays alive but shows no window.
  test_cleanup_runs_even_when_an_assertion_fails: the finally block stops processes on the exe path after a
      failure. NOT caught: a process that the path filter cannot see (the path is read by PowerShell).
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOL = REPO / "mobile-app" / "scripts" / "test-background-scan-skip.py"
_spec = importlib.util.spec_from_file_location("test_background_scan_skip_mod", TOOL)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

PROCEEDS = "Foreground UI is running; background scan proceeds"
STARTED = "=== Background scan started ==="


class FakeProc:
    def __init__(self, pid: int, returncode=None) -> None:
        self.pid = pid
        self.returncode = returncode

    def poll(self):
        return self.returncode


class FakeOps:
    """Stands in for WindowsOps. `live` is the set of process ids running from the exe path.

    start_background writes log_text to the log file and adds `scan_child` to `live` (a process the scan
    leaves behind), so the final sweep has something to stop. stop_pid removes the id from `live`.
    """

    def __init__(self, log: Path, log_text: str = "", *, windows: bool = True, ui_exits: bool = False,
                 leftover=(), scan_child: int | None = None, scan_finishes: bool = True) -> None:
        self.is_windows = windows
        self.log = log
        self.log_text = log_text
        self.ui_exits = ui_exits
        self.scan_child = scan_child
        self.scan_finishes = scan_finishes
        self.live = set(leftover)
        self.started: list[str] = []
        self.stopped: list[int] = []

    def start_foreground(self, exe):
        self.started.append("foreground")
        self.live.add(100)
        return FakeProc(100, returncode=3 if self.ui_exits else None)

    def start_background(self, exe):
        self.started.append("background")
        with self.log.open("a", encoding="utf-8") as handle:
            handle.write(self.log_text)
        if self.scan_child is not None:
            self.live.add(self.scan_child)
        return FakeProc(200)

    def wait(self, proc, seconds):
        return self.scan_finishes

    def running_from(self, exe):
        return sorted(self.live)

    def stop_pid(self, pid):
        self.stopped.append(pid)
        self.live.discard(pid)


class Fixture(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.mobile = self.root / "mobile-app"
        (self.mobile / "dist" / "dev").mkdir(parents=True)
        (self.mobile / "pubspec.yaml").write_text("name: x\nversion: 0.25.0+23\n", encoding="utf-8")
        self.exe = self.mobile / "dist" / "dev" / "MyEmailSpamFilter-Dev.exe"
        self.exe.write_bytes(b"stand-in")
        self.appdata = self.root / "AppData"
        self.log = (self.appdata / "MyEmailSpamFilter" / "MyEmailSpamFilter_Dev" / "logs"
                    / "dev_background_scan_v0.25.0.log")
        self.log.parent.mkdir(parents=True)
        self.log.write_text("earlier run line\n", encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_check(self, ops, environment="dev") -> tuple[int, str]:
        buf = io.StringIO()
        code = tool.run(environment, self.mobile, str(self.appdata), ops, sleep=lambda s: None,
                        out=lambda text="": buf.write(text + "\n"))
        return code, buf.getvalue()


class PureTests(unittest.TestCase):
    def test_derive_version_reads_top_level_version_only(self) -> None:
        self.assertEqual(tool.derive_version("name: x\nversion: 0.25.0+23\n"), "0.25.0")
        self.assertIsNone(tool.derive_version("dependencies:\n  version: 1.2.3\n"))

    def test_check_new_log_text_passes_only_with_all_assertions(self) -> None:
        good = f"{PROCEEDS}\n{STARTED}\n"
        self.assertEqual(tool.check_new_log_text(good, True), [])
        self.assertEqual(len(tool.check_new_log_text(STARTED, True)), 1)               # 1b missing
        self.assertEqual(len(tool.check_new_log_text(PROCEEDS, True)), 1)              # 1c missing
        self.assertEqual(len(tool.check_new_log_text(good + "Background scan skipped\n", True)), 1)  # 1d
        self.assertEqual(len(tool.check_new_log_text(good, False)), 1)                 # 1a


class RunTests(Fixture):
    def test_not_windows_exits_one_before_any_setup(self) -> None:
        ops = FakeOps(self.log, windows=False)
        code, out = self.run_check(ops)
        self.assertEqual(code, 1)
        self.assertIn("needs Windows", out)
        self.assertEqual(ops.started, [])

    def test_missing_exe_exits_one(self) -> None:
        self.exe.unlink()
        ops = FakeOps(self.log)
        code, out = self.run_check(ops)
        self.assertEqual(code, 1)
        self.assertIn("Test exe not found", out)
        self.assertEqual(ops.started, [])

    def test_proceeds_path_passes_and_cleans_up(self) -> None:
        ops = FakeOps(self.log, log_text=f"{PROCEEDS}\n{STARTED}\n", leftover=[7])
        code, out = self.run_check(ops)
        self.assertEqual(code, 0)
        self.assertIn("All assertions PASSED", out)
        self.assertEqual(ops.started, ["foreground", "background"])
        self.assertIn(7, ops.stopped)
        self.assertIn(100, ops.stopped)

    def test_deferred_launch_fails_with_exit_two(self) -> None:
        ops = FakeOps(self.log, log_text=f"{PROCEEDS}\n{STARTED}\nBackground scan skipped\n")
        code, out = self.run_check(ops)
        self.assertEqual(code, 2)
        self.assertIn("assertion 1d FAILED", out)

    def test_foreground_that_exits_early_fails_with_exit_two(self) -> None:
        ops = FakeOps(self.log, ui_exits=True)
        code, out = self.run_check(ops)
        self.assertEqual(code, 2)
        self.assertIn("exited prematurely", out)
        self.assertNotIn("background", ops.started)

    def test_cleanup_runs_even_when_an_assertion_fails(self) -> None:
        # the scan leaves process 300 behind; only the finally sweep can stop it
        ops = FakeOps(self.log, log_text="nothing useful\n", scan_child=300)
        code, _out = self.run_check(ops)
        self.assertEqual(code, 2)
        self.assertIn(300, ops.stopped)
        self.assertEqual(ops.live, set())


if __name__ == "__main__":
    unittest.main()
