"""Tests for mobile-app/scripts/r76_battery_arm.py (F332, Sprint 85).

adb is replaced by a fake executable placed first on PATH. The fake logs every call, answers `date`
from a clock file, copies a fixture folder on `pull`, and can be switched to "device offline" or
"pull fails". The arm's sleeps advance that clock, so the window is timed the way a device times it.
Nothing here touches a device.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_full_run_sequence_and_meta: the order of the device steps, the dumps and the pulled log.
      NOT caught: a wrong flag or setting that the fake accepts silently (the fake answers any command).
  test_window_sleeps_sum_to_declared_minutes: the loop never sleeps past the window end (F332 defect).
      NOT caught: a window that is correct on a real device clock but drifts on a slow adb round trip.
  test_cadence_posts_notifications_with_debug_titles: posts per cadence and their numbering.
      NOT caught: whether the notification is accepted by the app (only a DEBUG build accepts it).
  test_pull_failure_is_named_and_device_restored: a failed pull exits 1, names the step, and still wakes
      the device. NOT caught: a pull that succeeds but copies an empty folder.
  test_device_offline_changes_nothing: no device means no step runs and exit 2.
      NOT caught: a device that answers `date` but rejects every other command.
  test_bad_arm_label_and_bad_numbers_exit_2: usage checks run before adb. NOT caught: labels that are
      valid but collide with an existing folder (the run overwrites it).
  test_missing_adb_exits_2: no adb on PATH. NOT caught: an adb on PATH that is an old or wrong version.
  test_android_home_is_preferred: ANDROID_HOME/platform-tools/adb(.exe) is preferred over PATH.
      NOT caught: an SDK adb that exists but does not run (find_adb checks existence only).
  test_end_to_end_through_adb_on_path (ArmEndToEndTests): the real subprocess path through the fake
      executable on PATH, one 1 minute window. Slow on Windows (about 2 seconds per adb call).
      NOT caught: any output text the in-process tests do not assert.

The in-process FakeDevice answers the same as the fake executable. It exists so most tests do not start
a process per adb call, which costs about 2 seconds each on the Windows development machine.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS_TESTS = Path(__file__).resolve().parent
REPO = SCRIPTS_TESTS.parents[1]
ARM_PATH = REPO / "mobile-app" / "scripts" / "r76_battery_arm.py"
FIXTURES = SCRIPTS_TESTS / "fixtures" / "phone_log_health"
PKG = "com.example.test.dev"
BASE_CLOCK = 1_700_000_000

_spec = importlib.util.spec_from_file_location("r76_battery_arm_mod", ARM_PATH)
arm_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(arm_mod)

FAKE_ADB_PY = r'''
import json, os, shutil, sys
state = os.environ["FAKE_ADB_STATE"]
args = sys.argv[1:]
with open(os.path.join(state, "calls.jsonl"), "a", encoding="utf-8") as fh:
    fh.write(json.dumps(args) + "\n")
if os.environ.get("FAKE_ADB_OFFLINE") == "1":
    print("error: no devices/emulators found")
    sys.exit(1)
with open(os.path.join(state, "clock"), encoding="utf-8") as fh:
    clock = int(fh.read().strip())
if args[:2] == ["shell", "date"]:
    print(clock)
    sys.exit(0)
if args[:1] == ["pull"]:
    if os.environ.get("FAKE_ADB_PULL_FAIL") == "1":
        print("adb: error: failed to stat remote object", file=sys.stderr)
        sys.exit(1)
    shutil.copytree(os.environ["FAKE_ADB_DIAG"], args[2], dirs_exist_ok=True)
    sys.exit(0)
if args[:2] == ["shell", "dumpsys"]:
    print("dump of " + " ".join(args[2:]))
    sys.exit(0)
print("")
sys.exit(0)
'''


class FakeDevice:
    """In-process stand-in for the fake adb executable: the same answers, no process per call.

    A Python child process costs about 2 seconds per call on the Windows development machine, and a
    60 minute arm makes about 35 calls. The tests use this object; ArmEndToEndTest runs the real
    executable once, through PATH, so the subprocess path is still covered.
    """

    def __init__(self, state: Path, diag_src: Path) -> None:
        self.state = state
        self.diag_src = diag_src
        self.offline = False
        self.pull_fails = False

    def __call__(self, args: list[str]) -> tuple[int, str]:
        with (self.state / "calls.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(args) + "\n")
        if self.offline:
            return 1, "error: no devices/emulators found\n"
        clock = int((self.state / "clock").read_text(encoding="utf-8").strip())
        if args[:2] == ["shell", "date"]:
            return 0, f"{clock}\n"
        if args[:1] == ["pull"]:
            if self.pull_fails:
                return 1, ""
            shutil.copytree(self.diag_src, args[2], dirs_exist_ok=True)
            return 0, ""
        if args[:2] == ["shell", "dumpsys"]:
            return 0, "dump of " + " ".join(args[2:]) + "\n"
        return 0, ""


class FakeAdbCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="r76test_"))
        self.bin = self.tmp / "bin"
        self.state = self.tmp / "state"
        self.diag_src = self.tmp / "diag_src"
        self.out_root = self.tmp / "out"
        for folder in (self.bin, self.state, self.diag_src, self.out_root):
            folder.mkdir(parents=True)
        shutil.copyfile(FIXTURES / "diag_sample_s84.log", self.diag_src / "diag_sample_s84.log")
        fake = self.bin / "fake_adb.py"
        fake.write_text(FAKE_ADB_PY, encoding="utf-8")
        python = sys.executable
        if os.name == "nt":
            (self.bin / "adb.bat").write_text(f'@echo off\r\n"{python}" -I "{fake}" %*\r\n', encoding="utf-8")
        else:
            wrapper = self.bin / "adb"
            wrapper.write_text(f'#!/bin/sh\nexec "{python}" -I "{fake}" "$@"\n', encoding="utf-8")
            wrapper.chmod(wrapper.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        self.sleeps: list[int] = []
        self.set_clock(BASE_CLOCK)
        self.device = FakeDevice(self.state, self.diag_src)
        self.env = {
            "PATH": f"{self.bin}{os.pathsep}{os.environ.get('PATH', '')}",
            "FAKE_ADB_STATE": str(self.state),
            "FAKE_ADB_DIAG": str(self.diag_src),
            "PKG": PKG,
        }
        patcher = mock.patch.dict(os.environ, self.env)
        patcher.start()
        self.addCleanup(patcher.stop)
        os.environ.pop("ANDROID_HOME", None)
        os.environ.pop("OUT_ROOT", None)
        os.environ.pop("DIAG_DIR", None)
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def set_clock(self, value: int) -> None:
        (self.state / "clock").write_text(str(value), encoding="utf-8")

    def get_clock(self) -> int:
        return int((self.state / "clock").read_text(encoding="utf-8").strip())

    def fake_sleep(self, seconds: float) -> None:
        self.sleeps.append(int(seconds))
        self.set_clock(self.get_clock() + int(seconds))

    def calls(self) -> list[list[str]]:
        log = self.state / "calls.jsonl"
        if not log.exists():
            return []
        return [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines() if line.strip()]

    def run_arm(self, name: str, minutes: int, cadence: int, through_exe: bool = False) -> tuple[int, str]:
        """Runs one arm. through_exe=False uses the in-process device; True runs the fake adb executable
        that find_adb() finds on PATH."""
        if through_exe:
            adb = arm_mod.find_adb()
            self.assertIsNotNone(adb, "the fake adb must be found on PATH")
            runner = None
        else:
            adb = "in-process-fake"
            runner = self.device
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = arm_mod.run_arm(name, minutes, cadence, adb, self.out_root, PKG,
                                   "/sdcard/Documents/MyEmailSpamFilter_Dev/diagnostics",
                                   sleep=self.fake_sleep, runner=runner)
        return code, buf.getvalue()

    def meta(self, name: str) -> str:
        return (self.out_root / name / "meta.txt").read_text(encoding="utf-8")


class ArmRunTests(FakeAdbCase):
    def test_full_run_sequence_and_meta(self) -> None:
        """Device steps happen in the protocol order, every dump is written, the log is pulled, exit 0."""
        code, out = self.run_arm("arm1", 2, 0)
        self.assertEqual(code, 0, out)
        calls = self.calls()
        def index(args: list[str]) -> int:
            matches = [i for i, c in enumerate(calls) if c == args]
            self.assertTrue(matches, f"adb was never called with {args}")
            return matches[0]
        self.assertLess(index(["shell", "am", "set-standby-bucket", PKG, "working_set"]),
                        index(["shell", "dumpsys", "battery", "unplug"]))
        self.assertLess(index(["shell", "dumpsys", "battery", "unplug"]),
                        index(["shell", "dumpsys", "batterystats", "--reset"]))
        self.assertLess(index(["shell", "dumpsys", "deviceidle", "force-idle"]),
                        index(["shell", "dumpsys", "deviceidle", "unforce"]))
        self.assertLess(index(["shell", "dumpsys", "deviceidle", "unforce"]),
                        index(["shell", "dumpsys", "battery", "reset"]))
        self.assertEqual(calls[-1], ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
        arm_dir = self.out_root / "arm1"
        for name in ("before_alarm", "before_jobscheduler", "before_batterystats_pkg", "before_deviceidle",
                     "before_netstats", "after_alarm", "after_netstats", "after_batterystats_full_pkg",
                     "after_batterystats_checkin"):
            self.assertTrue((arm_dir / f"{name}.txt").is_file(), name)
        self.assertIn("dump of alarm", (arm_dir / "before_alarm.txt").read_text(encoding="utf-8"))
        pulled = arm_dir / "diag" / "diag_sample_s84.log"
        self.assertEqual(pulled.read_bytes(), (FIXTURES / "diag_sample_s84.log").read_bytes())
        meta = self.meta("arm1")
        self.assertIn("arm1 start epoch=", meta)
        self.assertIn("end epoch=", meta)
        self.assertIn("notifications_posted=0", meta)
        self.assertNotIn("FAILED", meta)

    def test_window_sleeps_sum_to_declared_minutes(self) -> None:
        """The loop sleeps only up to the window end. The shell slept a whole cadence and overshot;
        with a 12 minute window and a 5 minute cadence it ran 15 minutes (F332 port defect)."""
        code, _out = self.run_arm("arm2", 12, 5)
        self.assertEqual(code, 0)
        self.assertEqual(self.sleeps[0], 120, "the 2 minute screen-off wait comes first")
        loop_sleeps = self.sleeps[1:]
        self.assertEqual(sum(loop_sleeps), 12 * 60, f"window slept {sum(loop_sleeps)} s, not 720 s")
        self.assertEqual(loop_sleeps, [300, 300, 120])

    def test_cadence_posts_notifications_with_debug_titles(self) -> None:
        """Each post numbers its title, body and tag, and the count reaches meta.txt."""
        code, _out = self.run_arm("arm3", 12, 5)
        self.assertEqual(code, 0)
        posts = [c for c in self.calls() if c[:4] == ["shell", "cmd", "notification", "post"]]
        self.assertEqual(len(posts), 3)
        self.assertEqual(posts[0], ["shell", "cmd", "notification", "post", "-t", "r761 test 1",
                                    "r761tag1", "r761 body 1"])
        self.assertEqual(posts[2][5], "r761 test 3")
        self.assertIn("notifications_posted=3", self.meta("arm3"))

    def test_no_cadence_posts_nothing(self) -> None:
        code, _out = self.run_arm("arm4", 2, 0)
        self.assertEqual(code, 0)
        self.assertFalse([c for c in self.calls() if "notification" in c])

    def test_pull_failure_is_named_and_device_restored(self) -> None:
        """A failed pull exits 1, is named in meta.txt and on stdout, and the device still wakes."""
        self.device.pull_fails = True
        code, out = self.run_arm("arm5", 2, 0)
        self.assertEqual(code, 1)
        self.assertIn("WARNING: no diagnostic log pulled", out)
        meta = self.meta("arm5")
        self.assertIn("WARNING: no diagnostic log pulled", meta)
        self.assertIn("FAILED adb step: pull", meta)
        self.assertEqual(self.calls()[-1], ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])


class ArmEndToEndTests(FakeAdbCase):
    def test_end_to_end_through_adb_on_path(self) -> None:
        """The real subprocess path: find_adb() finds the fake executable on PATH and every call runs it.
        Slow on Windows (about 2 seconds per call), so it runs one 1 minute window only.
        NOT caught: anything the in-process tests above miss in the output text (they check it)."""
        code, out = self.run_arm("arm7", 1, 0, through_exe=True)
        self.assertEqual(code, 0, out)
        calls = self.calls()
        self.assertEqual(calls[0], ["shell", "date", "+%s"])
        self.assertEqual(calls[-1], ["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
        self.assertTrue((self.out_root / "arm7" / "diag" / "diag_sample_s84.log").is_file())


class UsageTests(FakeAdbCase):
    def test_device_offline_changes_nothing(self) -> None:
        """No device answers the first `date`: exit 2 and no device step runs."""
        self.device.offline = True
        code, out = self.run_arm("arm6", 2, 0)
        self.assertEqual(code, 2)
        self.assertIn("no device or emulator answered", out)
        self.assertEqual(self.calls(), [["shell", "date", "+%s"]])
        self.assertEqual(self.sleeps, [])

    def test_bad_arm_label_and_bad_numbers_exit_2(self) -> None:
        """Checked before adb is looked up: no call reaches the fake device."""
        # time.sleep is patched so a mutant that lets a bad value through fails fast, not after 2 minutes.
        with mock.patch.object(arm_mod.time, "sleep"):
            for argv in (["../escape", "2"], ["arm 7", "2"], ["arm8", "0"], ["arm8", "2", "-1"]):
                with self.subTest(argv=argv), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(arm_mod.main(argv), 2)
            with self.subTest(argv=["arm8", "x"]), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as caught:
                    arm_mod.main(["arm8", "x"])
                self.assertEqual(caught.exception.code, 2)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.out_root / "escape").exists())

    def test_missing_adb_exits_2(self) -> None:
        """No adb on PATH at all: exit 2 and a message that names ANDROID_HOME."""
        empty = self.tmp / "empty"
        empty.mkdir()
        with mock.patch.dict(os.environ, {"PATH": str(empty)}):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = arm_mod.main(["arm9", "2"])
        self.assertEqual(code, 2)
        self.assertIn("adb not found", buf.getvalue())

    def test_android_home_is_preferred(self) -> None:
        """ANDROID_HOME/platform-tools/adb(.exe) wins over the adb on PATH. find_adb only checks that the
        file exists, so an empty file stands in for the SDK's adb on every OS."""
        home = self.tmp / "sdk"
        (home / "platform-tools").mkdir(parents=True)
        target = home / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
        target.write_bytes(b"")
        with mock.patch.dict(os.environ, {"ANDROID_HOME": str(home)}):
            self.assertEqual(arm_mod.find_adb(), str(target))


if __name__ == "__main__":
    unittest.main()
