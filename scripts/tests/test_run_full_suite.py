"""Tests for scripts/run-full-suite.py (F330, Sprint 85).

The real Flutter suite is never run: a FAKE `flutter` (a .bat on Windows, a shell script elsewhere, found
through PATH exactly as the real one is) prints lines, exits with a chosen code or hangs.

What these tests do NOT catch: they do not prove the Windows commit-charge and process-count readings on a
machine under memory pressure (those are patched to fixed values except for one shape check), nor that the
real `flutter test` writes progress lines in the format the fake imitates; the stall test proves a hung
process tree is killed, not that a real dart test process behaves the same.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("run_full_suite", SCRIPTS / "run-full-suite.py")
rfs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rfs)

FAKE_PY = '''import os, sys, time
pidfile = os.environ.get("FAKE_PIDFILE")
if pidfile:
    open(pidfile, "w").write(str(os.getpid()))
for line in open(os.environ["FAKE_LINES"], encoding="utf-8").read().splitlines():
    print(line, flush=True)
if os.environ.get("FAKE_HANG"):
    time.sleep(600)
sys.exit(int(os.environ.get("FAKE_EXIT", "0")))
'''


def pid_alive(pid: int) -> bool:
    if os.name == "nt":
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout
        return f'"{pid}"' in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)
        self.app = self.dir / "mobile-app"
        self.app.mkdir()
        (self.app / "pubspec.yaml").write_text("name: x\n", encoding="utf-8")
        self.out = self.dir / "out"
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        fake_py = self.bin / "fake_flutter.py"
        fake_py.write_text(FAKE_PY, encoding="utf-8")
        if os.name == "nt":
            (self.bin / "flutter.bat").write_text(f'@echo off\r\n"{sys.executable}" "{fake_py}" %*\r\n', encoding="ascii")
        else:
            script = self.bin / "flutter"
            script.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{fake_py}" "$@"\n', encoding="ascii")
            script.chmod(0o755)
        self.lines_file = self.dir / "lines.txt"
        self.env = {"PATH": str(self.bin) + os.pathsep + os.environ.get("PATH", ""), "FAKE_LINES": str(self.lines_file)}
        self.env_patch = mock.patch.dict(os.environ, self.env)
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        for name, value in (("pagefile_mb", "n/a"), ("boot_time_text", "n/a"), ("commit_gb", ("1.50", "9.00")), ("process_ids", set())):
            patcher = mock.patch.object(rfs, name, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def fake(self, lines: list[str], exit_code: int = 0, **extra_env: str) -> None:
        self.lines_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        os.environ["FAKE_EXIT"] = str(exit_code)
        for key, value in extra_env.items():
            os.environ[key] = value
        self.addCleanup(lambda: [os.environ.pop(k, None) for k in ("FAKE_EXIT", *extra_env)])

    def run_main(self, *extra: str, label: str = "t") -> tuple[int, str]:
        argv = ["--label", label, "--out-dir", str(self.out), "--app-dir", str(self.app), "--poll-seconds", "0.2", *extra]
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = rfs.main(argv)
        return code, buffer.getvalue()

    def result_lines(self) -> list[str]:
        return (self.out / "results.txt").read_text(encoding="utf-8").splitlines()


class Outcomes(Base):
    def test_passing_run_exit_0_and_result_line(self):
        self.fake(["00:03 +12: All tests passed!"])
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertRegex(out, r"RESULT label=t exit=0 minutes=0 loadFailures=0 peakCommittedGB=1\.50 devAppProcs=0 last='00:03 \+12: All tests passed!'")
        self.assertEqual(len(self.result_lines()), 1)

    def test_flutters_failing_exit_code_is_passed_through(self):
        self.fake(["00:02 +10 -2: Some tests failed."], exit_code=1)
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("exit=1", out)

    def test_no_progress_line_is_exit_4_even_when_flutter_exits_0(self):
        self.fake(["compiling..."], exit_code=0)
        code, out = self.run_main()
        self.assertEqual(code, 4)
        self.assertIn("RUNNER DEFECT: no exit code or no tests ran", out)
        self.assertIn("(no test progress line)", out)

    def test_flutter_not_installed_is_exit_4_not_a_pass(self):
        with mock.patch.object(rfs.shutil, "which", return_value=None):
            code, out = self.run_main()
        self.assertEqual(code, 4)
        self.assertIn("flutter was not found on PATH", out)
        self.assertIn("exit=4", out)

    def test_missing_app_folder_is_exit_1(self):
        (self.app / "pubspec.yaml").unlink()
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("mobile-app not found", out)

    def test_clock_of_100_minutes_or_more_is_a_progress_line(self):
        self.fake(["100:05 +3000: All tests passed!"])
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("last='100:05 +3000", out)

    def test_load_failures_count_runner_lines_but_not_the_apps_own_credential_line(self):
        self.fake(['Failed to load "test/a_test.dart": boom', "did not complete", "Failed to load credentials for x",
                   "00:05 +4 -1: loading test/b_test.dart [E]", "00:06 +4 -2: Some tests failed."], exit_code=1)
        _code, out = self.run_main()
        self.assertIn("loadFailures=3", out)

    def test_two_runs_append_two_result_lines(self):
        self.fake(["00:01 +1: All tests passed!"])
        self.run_main(label="one")
        self.run_main(label="two")
        lines = self.result_lines()
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[0].startswith("RESULT label=one") and lines[1].startswith("RESULT label=two"))

    def test_full_output_is_kept_in_the_log_untrimmed(self):
        self.fake([f"line {i}" for i in range(1, 1201)] + ["00:09 +7: All tests passed!"])
        _code, out = self.run_main()
        log = Path(re.search(r"^log: (.+)$", out, re.M).group(1))
        text = log.read_text(encoding="utf-8").splitlines()
        self.assertEqual(text[0], "line 1")
        self.assertEqual(len(text), 1201)

    def test_csv_has_header_line_and_a_closing_sample(self):
        self.fake(["00:01 +1: All tests passed!"])
        _code, out = self.run_main("--poll-seconds", "30")  # the run ends long before the first poll sample
        csv_path = Path(re.search(r"^csv: (.+)$", out, re.M).group(1))
        rows = csv_path.read_text(encoding="utf-8").splitlines()
        self.assertTrue(rows[0].startswith("boot="))
        self.assertEqual(rows[1], "time,committedGB,limitGB,flutter_tester,logKB")
        self.assertGreaterEqual(len(rows), 3)


class Stall(Base):
    def test_self_test_stalls_exits_2_and_records_stalled(self):
        started = time.monotonic()
        code, out = self.run_main("--self-test-stall", "--stall-minutes", "0.03")
        self.assertEqual(code, 2, out)
        self.assertIn("STALLED(0.03m)", out)
        self.assertIn("last='00:00 +0: self-test, now hanging'", out)
        self.assertLess(time.monotonic() - started, 60)

    def test_a_hung_flutter_process_tree_is_killed_but_a_bystander_is_not(self):
        pidfile = self.dir / "pid.txt"
        self.fake(["00:01 +1: running"], FAKE_HANG="1", FAKE_PIDFILE=str(pidfile))
        bystander = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
        self.addCleanup(bystander.kill)
        code, out = self.run_main("--stall-minutes", "0.03")
        self.assertEqual(code, 2, out)
        child = int(pidfile.read_text())
        deadline = time.monotonic() + 15
        while pid_alive(child) and time.monotonic() < deadline:
            time.sleep(0.2)
        self.assertFalse(pid_alive(child), "the flutter grandchild survived the stall kill")
        self.assertIsNone(bystander.poll(), "an unrelated process was killed")


class MachineFacts(unittest.TestCase):
    def test_commit_reading_is_two_numbers_or_na(self):
        committed, limit = rfs.commit_gb()
        for value in (committed, limit):
            self.assertTrue(value == "n/a" or re.fullmatch(r"\d+\.\d\d", value), value)

    def test_unreadable_process_list_is_an_empty_set_not_an_exception(self):
        with mock.patch.object(rfs.subprocess, "run", side_effect=OSError("no tasklist")):
            self.assertEqual(rfs.process_ids("flutter_tester"), set())

    def test_tail_reader_and_progress_pattern(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "l.log"
            path.write_text("\n".join(["noise"] * 500 + ["12:34 +5: ok", "trailer"]), encoding="utf-8")
            lines = rfs.read_tail_lines(path)
            self.assertEqual(len(lines), 400)
            self.assertEqual(rfs.last_progress_line(lines), "12:34 +5: ok")
            self.assertEqual(rfs.last_progress_line(["x"]), rfs.NO_PROGRESS)


if __name__ == "__main__":
    unittest.main()
