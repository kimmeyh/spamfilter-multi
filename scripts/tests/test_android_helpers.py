"""Tests for the Android helper scripts in mobile-app/scripts (F336, Sprint 86; ports of seven .ps1 files).

Run: python -I -m unittest discover -s scripts/tests -p "test_android_helpers*.py" -v

Files covered: android_support.py (shared), start-emulator.py, run-emulator.py, setup-android-oauth.py,
export-tokens-for-android.py, capture-diagnostic-logs.py, enable-screen-reader-flag.py, fix-flutter-git.py.

Two kinds of fake. Most tests use an IN-PROCESS stand-in for adb, emulator and cmdkey (it replaces
android_support.run_capture and records the tool path, so a tool that came from the PATH instead of ANDROID_HOME is
caught). The few tests marked REAL start a real process: a fake adb or emulator command (a .bat shim on Windows, a
shebang script elsewhere) in a temporary SDK folder, a real git, a real killed process, a real Win32 call. Process
starts are the slow part of this file, so only the failure paths and the process launches use them. A fake DECOY adb
first on the PATH proves a tool came from ANDROID_HOME and not from the PATH, and the PATH of every test is cut down to
the decoy, git and the system folder: the user's PATH holds a REAL older emulator, and a test that fell through to it
once started a real emulator while this file was being written.

No test starts a real emulator, touches a phone, builds an app, reads a real secrets file or changes the screen reader
flag.

Error paths (Sprint 85 retro i4): each script has ONE test that runs a REAL failing command and checks the non-zero exit.
    start-emulator          test_start_emulator_process_that_exits_at_once_is_failure (a real process that exits 3)
    run-emulator            test_run_emulator_failed_install_is_exit_1 (a real fake adb whose install exits 1)
    setup-android-oauth     test_setup_failing_build_script_exit_code_is_returned (a real script that exits 7)
    export-tokens           test_export_cmdkey_failure_is_reported (a real fake cmdkey that exits 3)
    capture-diagnostic-logs test_capture_failing_logcat_clear_is_exit_1 (a real fake adb whose logcat -c exits 1)
    enable-screen-reader    test_spi_real_failing_win32_call_raises (a real SystemParametersInfoW call that returns FALSE;
                            Windows only)
    fix-flutter-git         test_fix_flutter_git_real_failing_git_is_exit_1 (a real git on a folder that is not a
                            repository; test_fix_flutter_git_failed_fetch_stops_before_reset covers the stop-before-reset
                            logic with a stand-in git)

What these tests do NOT catch: a real emulator booting or a real install (the live emulator run in the sprint plan covers
that), a real Google console, a real Flutter SDK repair, the screen reader flag being set (only the read is real, and a
fake user32 stands in for a set that does not stick), and the real adb or cmdkey output format changing.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SCRIPTS = REPO / "mobile-app" / "scripts"
sys.path.insert(0, str(SCRIPTS))

IMPL = '''
import json, os, sys, time
name = sys.argv[1]
argv = sys.argv[2:]
spec = json.loads(os.environ.get("FAKE_SPEC", "{}") or "{}").get(name, {})
log = os.environ.get("FAKE_TOOL_LOG")
if log:
    with open(log, "a", encoding="utf-8") as handle:
        handle.write(json.dumps({"tool": name, "argv": argv, "dir": os.path.dirname(os.path.abspath(__file__)),
                                 "sdk_root": os.environ.get("ANDROID_SDK_ROOT")}) + "\\n")
out, rc, stay = spec.get("out", ""), spec.get("rc", 0), spec.get("stay", 0)
for key, cfg in spec.get("by", {}).items():
    if key in argv:
        out, rc, stay = cfg.get("out", out), cfg.get("rc", rc), cfg.get("stay", stay)
        break
sys.stdout.write(out)
sys.stdout.flush()
if stay:
    time.sleep(stay)
sys.exit(rc)
'''


def load(alias: str, file: str):
    spec = importlib.util.spec_from_file_location(alias, SCRIPTS / file)
    module = importlib.util.module_from_spec(spec)
    sys.modules[alias] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


sup = load("android_support", "android_support.py")
start_emulator = load("start_emulator", "start-emulator.py")
run_emulator = load("run_emulator", "run-emulator.py")
setup_oauth = load("setup_android_oauth", "setup-android-oauth.py")
export_tokens = load("export_tokens", "export-tokens-for-android.py")
capture = load("capture_logs", "capture-diagnostic-logs.py")
screen_reader = load("screen_reader", "enable-screen-reader-flag.py")
fix_git = load("fix_flutter_git", "fix-flutter-git.py")


def install_fake(folder: Path, name: str) -> Path:
    """Write a fake command `name` into folder. Returns the shim path."""
    folder.mkdir(parents=True, exist_ok=True)
    impl = folder / "fake_tool_impl.py"
    impl.write_text(IMPL, encoding="utf-8")
    if os.name == "nt":
        shim = folder / f"{name}.bat"
        shim.write_text(f'@echo off\r\n"{sys.executable}" "{impl}" {name} %*\r\n', encoding="utf-8")
    else:
        shim = folder / name
        shim.write_text(f'#!{sys.executable}\nimport runpy, sys\nsys.argv = ["{impl}", "{name}", *sys.argv[1:]]\n'
                        f'runpy.run_path("{impl}", run_name="__main__")\n', encoding="utf-8")
        shim.chmod(shim.stat().st_mode | stat.S_IEXEC)
    return shim


def read_calls(log: Path) -> list[dict]:
    if not log.exists():
        return []
    return [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines() if line.strip()]


def answer(spec: dict, argv: list[str]) -> tuple[int, str]:
    """The same rule the fake process uses: the first key of `by` that is one of the arguments picks the answer."""
    out, rc = spec.get("out", ""), spec.get("rc", 0)
    for key, cfg in spec.get("by", {}).items():
        if key in argv:
            return cfg.get("rc", rc), cfg.get("out", out)
    return rc, out


class Sandbox(unittest.TestCase):
    """A temporary SDK (ANDROID_HOME) with fake adb and emulator, a decoy adb on the PATH, and a call log."""

    def setUp(self) -> None:
        # A detached fake (the emulator, logcat) may still hold a file for a moment after the test ends; on Windows that
        # blocks the delete, and the leftover is a temporary folder the OS cleans up. It must not fail the test.
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.home = root / "sdk"
        install_fake(self.home / "platform-tools", "adb")
        install_fake(self.home / "emulator", "emulator")
        self.decoy = root / "decoy"
        install_fake(self.decoy, "adb")
        self.log = root / "calls.jsonl"
        self.spec: dict = {}
        self.mem_calls: list[dict] = []
        patcher = mock.patch.object(sup, "sleep", lambda seconds: None)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.set_env()

    def isolated_path(self) -> list[str]:
        git = shutil.which("git")
        system = os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "System32") if os.name == "nt" else "/usr/bin"
        return [str(self.decoy), *([os.path.dirname(git)] if git else []), system]

    def set_env(self) -> None:
        env = {"ANDROID_HOME": str(self.home), "FAKE_TOOL_LOG": str(self.log),
               "FAKE_SPEC": json.dumps(self.spec), "PATH": os.pathsep.join(self.isolated_path())}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)

    def use_spec(self, spec: dict) -> None:
        """For a REAL fake process: the spec reaches it through the environment."""
        self.spec = spec
        os.environ["FAKE_SPEC"] = json.dumps(spec)

    def mem(self, spec: dict) -> None:
        """For an in-process stand-in: run_capture and list_avds answer from the spec and record the tool path."""
        self.spec = spec

        def fake_run_capture(argv, cwd=None, timeout=None, env=None):
            tool = Path(argv[0])
            self.mem_calls.append({"tool": tool.stem, "dir": str(tool.parent), "argv": list(argv[1:])})
            return answer(spec.get(tool.stem, {}), list(argv[1:]))

        def fake_list_avds(emulator):
            self.mem_calls.append({"tool": "emulator", "dir": str(Path(emulator).parent), "argv": ["-list-avds"]})
            _, text = answer(spec.get("emulator", {}), ["-list-avds"])
            return [line.strip() for line in text.splitlines() if line.strip()], None

        for name, replacement in (("run_capture", fake_run_capture), ("list_avds", fake_list_avds)):
            patcher = mock.patch.object(sup, name, replacement)
            patcher.start()
            self.addCleanup(patcher.stop)

    def calls(self, tool: str | None = None) -> list[dict]:
        rows = self.mem_calls + read_calls(self.log)
        return [row for row in rows if tool is None or row["tool"] == tool]

    def assert_decoy_never_ran(self) -> None:
        """The decoy adb sits first on the PATH; any call it received means a tool came from the PATH, not ANDROID_HOME."""
        ran = [row for row in self.calls("adb") if Path(row["dir"]) == self.decoy]
        self.assertEqual(ran, [], "a tool was resolved from the PATH instead of ANDROID_HOME")

    def run_main(self, module, *argv: str) -> tuple[int, str]:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = module.main(list(argv))
        return code, buffer.getvalue()


EMULATOR_ONLINE = "List of devices attached\nemulator-5554\tdevice\n"
NO_DEVICES = "List of devices attached\n"
PHONE_ONLY = "List of devices attached\nR5CT12345XY\tdevice\n"


class SupportTests(Sandbox):
    def test_sdk_tool_prefers_android_home_over_path(self):
        found = sup.find_adb()
        self.assertEqual(Path(found), self.home / "platform-tools" / ("adb.bat" if os.name == "nt" else "adb"))
        with mock.patch.dict(os.environ, {"ANDROID_HOME": str(self.home / "nowhere")}):
            self.assertEqual(Path(sup.find_adb()).parent, self.decoy)  # no tool under ANDROID_HOME: the PATH is used

    def test_parse_emulator_serials_skips_phones_and_offline(self):
        text = "List of devices attached\nR5CT12345XY\tdevice\nemulator-5556\toffline\nemulator-5554\tdevice\n"
        self.assertEqual(sup.parse_emulator_serials(text), ["emulator-5554"])

    def test_failing_adb_is_an_error_not_an_empty_list(self):  # REAL process
        self.use_spec({"adb": {"rc": 1, "out": "boom"}})
        serials, error = sup.online_emulators(sup.find_adb())
        self.assertEqual(serials, [])
        self.assertIn("exit 1", error)

    def test_missing_executable_is_not_found_code(self):  # REAL missing executable
        code, text = sup.run_capture([str(Path(self.tmp.name) / "no-such-tool")])
        self.assertEqual(code, sup.NOT_FOUND)
        self.assertIn("could not run", text)

    def test_list_avds_keeps_only_avd_shaped_stdout_lines(self):  # REAL process
        self.use_spec({"emulator": {"out": "WARNING: a warning line\npixel34_updated\n\nOther_AVD\n"}})
        names, error = sup.list_avds(sup.find_emulator())
        self.assertEqual((names, error), (["pixel34_updated", "Other_AVD"], None))

    def test_emulator_env_sets_both_variables_for_the_child_only(self):
        with mock.patch.dict(os.environ):
            os.environ.pop("ANDROID_SDK_ROOT", None)
            env = sup.emulator_env(str(self.home))
            self.assertEqual(env["ANDROID_SDK_ROOT"], str(self.home))
            self.assertEqual(env["ANDROID_HOME"], str(self.home))
            self.assertNotIn("ANDROID_SDK_ROOT", os.environ)

    def test_wait_for_boot_polls_the_given_serial(self):
        self.mem({"adb": {"by": {"getprop": {"out": "1\n"}}}})
        self.assertTrue(sup.wait_for_boot(sup.find_adb(), "emulator-5554", seconds=4))
        self.assertEqual(self.calls("adb")[0]["argv"], ["-s", "emulator-5554", "shell", "getprop", "sys.boot_completed"])
        self.mem({"adb": {"by": {"getprop": {"out": "0\n"}}}})
        self.assertFalse(sup.wait_for_boot(sup.find_adb(), "emulator-5554", seconds=4))
        self.mem({"adb": {"rc": 1}})
        self.assertFalse(sup.wait_for_boot(sup.find_adb(), "emulator-5554", seconds=4), "a failing adb is not a boot")


class StartEmulatorTests(Sandbox):
    def test_arguments(self):
        args = start_emulator.parse_args([])
        self.assertEqual((args.avd, args.cold_boot, args.force, args.sdk_root), ("pixel34_updated", False, False, None))
        args = start_emulator.parse_args(["--avd", "x", "--cold-boot", "--force", "--sdk-root", "C:/s"])
        self.assertEqual((args.avd, args.cold_boot, args.force, args.sdk_root), ("x", True, True, "C:/s"))

    def test_launches_from_android_home_with_sdk_variables_and_cold_boot(self):  # REAL launch
        self.use_spec({"emulator": {"by": {"-avd": {"stay": 3}}}})
        self.mem({"adb": {"out": NO_DEVICES}, "emulator": {"out": "pixel34_updated\nOther_AVD\n"}})
        with mock.patch.object(start_emulator, "SETTLE_SECONDS", 0.2):
            code, out = self.run_main(start_emulator, "--cold-boot")
        self.assertEqual(code, 0, out)
        deadline = time.time() + 120  # the fake runs detached: wait for its log line
        while time.time() < deadline and not [c for c in read_calls(self.log) if "-avd" in c["argv"]]:
            time.sleep(0.5)
        launch = [c for c in read_calls(self.log) if "-avd" in c["argv"]][0]
        self.assertEqual(launch["argv"], ["-avd", "pixel34_updated", "-no-snapshot-load"])
        self.assertEqual(launch["sdk_root"], str(self.home))
        self.assertEqual(Path(launch["dir"]), self.home / "emulator")
        self.assert_decoy_never_ran()
        self.assertEqual({Path(c["dir"]) for c in self.calls("adb")}, {self.home / "platform-tools"})

    def test_already_running_emulator_is_not_started_twice(self):
        self.mem({"adb": {"out": EMULATOR_ONLINE}})
        with mock.patch.object(sup, "launch_emulator", side_effect=AssertionError("must not launch")):
            code, out = self.run_main(start_emulator)
        self.assertEqual(code, 0)
        self.assertIn("already online", out)

    def test_unknown_avd_is_exit_1_and_lists_the_real_ones(self):
        self.mem({"adb": {"out": NO_DEVICES}, "emulator": {"out": "Other_AVD\n"}})
        with mock.patch.object(sup, "launch_emulator", side_effect=AssertionError("must not launch")):
            code, out = self.run_main(start_emulator)
        self.assertEqual(code, 1)
        self.assertIn("Other_AVD", out)

    def test_missing_emulator_tool_is_exit_1(self):
        empty = str(Path(self.tmp.name) / "empty")
        with mock.patch.dict(os.environ, {"ANDROID_HOME": empty, "PATH": empty}):
            code, out = self.run_main(start_emulator)
        self.assertEqual(code, 1)
        self.assertIn("emulator not found", out)

    def test_start_emulator_process_that_exits_at_once_is_failure(self):  # REAL process that exits 3
        self.use_spec({"emulator": {"by": {"-avd": {"rc": 3}}}})
        self.mem({"adb": {"out": NO_DEVICES}, "emulator": {"out": "pixel34_updated\n"}})
        with mock.patch.object(start_emulator, "SETTLE_SECONDS", 120):  # wait() returns when the process exits
            code, out = self.run_main(start_emulator, "--force")
        self.assertEqual(code, 1, out)
        self.assertIn("exited at once", out)


class RunEmulatorTests(Sandbox):
    def make_apk(self) -> Path:
        apk = Path(self.tmp.name) / "app.apk"
        apk.write_bytes(b"fake")
        return apk

    def boot_spec(self, **overrides) -> dict:
        by = {"monkey": {"out": "Events injected: 1\n"}, "getprop": {"out": "1\n"}, "install": {"out": "Success\n"},
              "devices": {"out": EMULATOR_ONLINE}}
        by.update(overrides)
        return {"adb": {"by": by}}

    def test_arguments(self):
        args = run_emulator.parse_args([])
        self.assertEqual((args.avd, args.package_id, args.install_release_apk, args.apk),
                         ("pixel34_updated", "com.myemailspamfilter.dev", False, None))

    def test_install_uses_the_emulator_serial_and_never_kills_the_adb_server(self):
        self.mem(self.boot_spec())
        apk = self.make_apk()
        code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(apk))
        self.assertEqual(code, 0, out)
        argvs = [c["argv"] for c in self.calls("adb")]
        self.assertIn(["-s", "emulator-5554", "install", "-r", str(apk)], argvs)
        monkey = [a for a in argvs if "monkey" in a][0]
        self.assertEqual(monkey[:2], ["-s", "emulator-5554"])
        self.assertIn("com.myemailspamfilter.dev", monkey)
        self.assertFalse([a for a in argvs if "kill-server" in a])
        self.assert_decoy_never_ran()
        self.assertEqual({Path(c["dir"]) for c in self.calls("adb")}, {self.home / "platform-tools"})

    def test_phone_is_never_a_target(self):
        self.mem({"adb": {"out": PHONE_ONLY}})
        with mock.patch.object(sup, "find_emulator", return_value=None):
            code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(self.make_apk()))
        self.assertEqual(code, 1)
        for call in self.calls("adb"):
            self.assertNotIn("R5CT12345XY", call["argv"])
            self.assertNotIn("install", call["argv"])

    def test_missing_adb_is_exit_1(self):
        empty = str(Path(self.tmp.name) / "empty")
        with mock.patch.dict(os.environ, {"ANDROID_HOME": empty, "PATH": empty}):
            code, out = self.run_main(run_emulator)
        self.assertEqual(code, 1)
        self.assertIn("adb not found", out)

    def test_run_emulator_failed_install_is_exit_1(self):  # REAL fake adb whose install exits 1
        self.use_spec(self.boot_spec(install={"rc": 1, "out": "Failure [INSTALL_FAILED_OLDER_SDK]\n"}))
        code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(self.make_apk()))
        self.assertEqual(code, 1)
        self.assertIn("APK install failed", out)
        self.assertFalse([c for c in self.calls("adb") if "monkey" in c["argv"]],
                         "the app must not start after a failed install")

    def test_install_with_exit_0_but_no_success_text_is_still_a_failure(self):
        self.mem(self.boot_spec(install={"out": "Failure [INSTALL_FAILED_ALREADY_EXISTS]\n"}))
        code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(self.make_apk()))
        self.assertEqual(code, 1)

    def test_app_that_does_not_start_is_exit_1(self):
        self.mem(self.boot_spec(monkey={"out": "** No activities found to run, monkey aborted.\n"}))
        code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(self.make_apk()))
        self.assertEqual(code, 1)
        self.assertIn("did not start", out)

    def test_boot_that_never_finishes_is_exit_1(self):
        self.mem(self.boot_spec(getprop={"out": "0\n"}))
        with mock.patch.object(run_emulator, "BOOT_SECONDS", 4):
            code, out = self.run_main(run_emulator, "--install-release-apk", "--apk", str(self.make_apk()))
        self.assertEqual(code, 1)
        self.assertIn("did not finish booting", out)


class SetupOauthTests(Sandbox):
    SECRET = "S3CR3T-never-print-me"

    def write_secrets(self, **extra) -> Path:
        path = Path(self.tmp.name) / "secrets.dev.json"
        data = {"WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "id123.apps.googleusercontent.com",
                "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "REPLACE_WITH", "OTHER_KEY": "keep-me", **extra}
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def run_wizard(self, *argv: str, secret: str = SECRET, tty: bool = True) -> tuple[int, str]:
        with mock.patch.object(sys.stdin, "isatty", return_value=tty), \
                mock.patch("builtins.input", return_value=""), \
                mock.patch.object(setup_oauth, "is_git_ignored", return_value=True), \
                mock.patch.object(setup_oauth.getpass, "getpass", return_value=secret):
            return self.run_main(setup_oauth, *argv)

    def test_saves_secret_keeps_other_keys_and_prints_no_secret(self):
        path = self.write_secrets()
        code, out = self.run_wizard("--secrets-file", str(path), "--no-build")
        self.assertEqual(code, 0, out)
        saved = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(saved["WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET"], self.SECRET)
        self.assertNotIn("GMAIL_OAUTH_CLIENT_SECRET", saved, "the dead legacy key must not be written")
        self.assertEqual(saved["OTHER_KEY"], "keep-me")
        self.assertNotIn(self.SECRET, out)
        self.assertNotIn(self.SECRET[:6], out)
        self.assertFalse(path.read_bytes().startswith(b"\xef\xbb\xbf"), "no byte order mark")
        self.assertEqual([p.name for p in path.parent.glob("*.tmp")], [], "no temporary file left behind")

    def test_existing_secret_is_never_printed(self):
        path = self.write_secrets(WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET="EXISTING-VALUE-XYZ")
        code, out = self.run_wizard("--secrets-file", str(path), "--no-build")
        self.assertNotIn("EXISTING-VALUE", out)
        self.assertIn("Desktop client secret: set", out)

    def test_missing_secrets_file_is_exit_1(self):
        code, out = self.run_wizard("--secrets-file", str(Path(self.tmp.name) / "none.json"), "--no-build")
        self.assertEqual(code, 1)
        self.assertIn("template", out)

    def test_empty_secret_is_exit_1_and_file_unchanged(self):
        path = self.write_secrets()
        before = path.read_bytes()
        code, _ = self.run_wizard("--secrets-file", str(path), "--no-build", secret="   ")
        self.assertEqual(code, 1)
        self.assertEqual(path.read_bytes(), before)

    def test_no_terminal_is_exit_1(self):
        code, out = self.run_wizard("--secrets-file", str(self.write_secrets()), tty=False)
        self.assertEqual(code, 1)
        self.assertIn("needs a terminal", out)

    def test_file_git_does_not_ignore_is_refused_and_unchanged(self):
        path = self.write_secrets()
        before = path.read_bytes()
        with mock.patch.object(sys.stdin, "isatty", return_value=True), mock.patch("builtins.input", return_value=""), \
                mock.patch.object(setup_oauth, "is_git_ignored", return_value=False), \
                mock.patch.object(setup_oauth.getpass, "getpass", return_value=self.SECRET):
            code, out = self.run_main(setup_oauth, "--secrets-file", str(path), "--no-build")
        self.assertEqual(code, 1)
        self.assertIn("not ignored by git", out)
        self.assertEqual(path.read_bytes(), before)

    def test_legacy_secret_key_is_flagged_not_trusted(self):
        path = self.write_secrets(WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET="", GMAIL_OAUTH_CLIENT_SECRET="LEGACY-VALUE-ABC")
        code, out = self.run_wizard("--secrets-file", str(path), "--no-build")
        self.assertIn("no build reads it", out)
        self.assertNotIn("LEGACY-VALUE", out)
        self.assertIn("Desktop client secret: NOT SET", out.split("STEP 2")[0])

    def test_is_git_ignored_only_exit_0_counts(self):  # C6-4: 128, 1 and a missing git are all "not proven ignored"
        path = Path(self.tmp.name) / "s.json"
        for code, want in ((0, True), (1, False), (128, False), (127, False)):
            with mock.patch.object(setup_oauth.sup.common, "git", return_value=(code, "")):
                self.assertEqual(setup_oauth.is_git_ignored(path), want, f"git exit {code}")

    def test_wizard_refuses_to_write_when_git_cannot_tell(self):  # C6-4 end to end, not a repository (exit 128)
        path = self.write_secrets()
        before = path.read_bytes()
        with mock.patch.object(sys.stdin, "isatty", return_value=True), mock.patch("builtins.input", return_value=""), \
                mock.patch.object(setup_oauth.sup.common, "git", return_value=(128, "fatal: not a git repository")), \
                mock.patch.object(setup_oauth.getpass, "getpass", return_value=self.SECRET):
            code, out = self.run_main(setup_oauth, "--secrets-file", str(path), "--no-build")
        self.assertEqual(code, 1)
        self.assertIn("not ignored by git", out)
        self.assertEqual(path.read_bytes(), before)

    def test_is_git_ignored_against_the_real_repository(self):  # REAL git
        self.assertFalse(setup_oauth.is_git_ignored(REPO / "README.md"))
        self.assertTrue(setup_oauth.is_git_ignored(REPO / "mobile-app" / "secrets.dev.json"))

    def test_setup_failing_build_script_exit_code_is_returned(self):  # REAL script that exits 7
        path = self.write_secrets()
        failing = Path(self.tmp.name) / "failing_build.py"
        failing.write_text("import sys\nsys.exit(7)\n", encoding="utf-8")
        code, out = self.run_wizard("--secrets-file", str(path), "--build-script", str(failing))
        self.assertEqual(code, 7)
        self.assertIn("Build failed", out)

    def test_missing_build_script_is_exit_1(self):
        code, out = self.run_wizard("--secrets-file", str(self.write_secrets()),
                                    "--build-script", str(Path(self.tmp.name) / "absent.py"))
        self.assertEqual(code, 1)
        self.assertIn("not found", out)


@unittest.skipUnless(os.name == "nt", "cmdkey exists only on Windows")
class ExportTokensTests(Sandbox):
    def secrets(self) -> Path:
        path = Path(self.tmp.name) / "secrets.dev.json"
        path.write_text(json.dumps({"WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "id9", "GMAIL_REDIRECT_URI": "http://localhost:8080/cb",
                                    "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "TOPSECRETVALUE"}), encoding="utf-8")
        return path

    def setUp(self) -> None:
        super().setUp()
        install_fake(self.decoy, "cmdkey")

    def test_targets(self):
        self.assertEqual(export_tokens.credential_targets("a.b+c@x.com")[0], "spamfilter_oauth_access_a.b+c@x.com")
        self.assertEqual(export_tokens.kind_of("x_refresh"), "REFRESH")

    def test_email_argument_is_required(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            export_tokens.main([])
        self.assertEqual(caught.exception.code, 2)

    def test_found_target_is_reported_and_secret_is_never_printed(self):
        self.mem({"cmdkey": {"out": "Target: LegacyGeneric:target=a@x.com_access\n"}})
        code, out = self.run_main(export_tokens, "--email", "a@x.com", "--secrets-file", str(self.secrets()))
        self.assertEqual(code, 0, out)
        self.assertIn("Found credential: a@x.com_access", out)
        self.assertNotIn("TOPSECRETVALUE", out)
        self.assertNotIn("TOPSECRETVA", out)
        self.assertIn("Client Secret: set", out)

    def test_export_cmdkey_failure_is_reported(self):  # REAL fake cmdkey that exits 3
        self.use_spec({"cmdkey": {"rc": 3, "out": "cmdkey broke"}})
        code, out = self.run_main(export_tokens, "--email", "a@x.com", "--secrets-file", str(self.secrets()))
        self.assertEqual(code, 1)
        self.assertIn("failed (exit 3)", out)

    def test_missing_cmdkey_is_exit_1(self):
        with mock.patch.dict(os.environ, {"PATH": str(Path(self.tmp.name) / "empty")}):
            code, out = self.run_main(export_tokens, "--email", "a@x.com", "--secrets-file", str(self.secrets()))
        self.assertEqual(code, 1)
        self.assertIn("cmdkey was not found", out)

    def test_missing_secrets_file_is_exit_1(self):
        self.mem({"cmdkey": {"out": "* NONE *\n"}})
        code, out = self.run_main(export_tokens, "--email", "a@x.com",
                                  "--secrets-file", str(Path(self.tmp.name) / "none.json"))
        self.assertEqual(code, 1)

    def test_address_characters_are_not_regex(self):
        # cmdkey output for a DIFFERENT address must not count as found for a.b@x.com.
        self.mem({"cmdkey": {"out": "Target: LegacyGeneric:target=aXb@x.com_access\n"}})
        exists, error = export_tokens.query_target(str(self.decoy / "cmdkey.bat"), "a.b@x.com_access")
        self.assertFalse(exists)
        self.assertEqual(error, "")


class CaptureLogsTests(Sandbox):
    def log_dir(self) -> Path:
        return Path(self.tmp.name) / "logs"

    def test_start_uses_emulator_serial_only_and_records_pid(self):  # REAL logcat process
        spec = {"adb": {"by": {"devices": {"out": "List of devices attached\nR5CT12345XY\tdevice\nemulator-5554\tdevice\n"},
                               "-c": {}, "logcat": {"stay": 3}}}}
        self.use_spec(spec)
        self.mem({"adb": {"by": {"devices": spec["adb"]["by"]["devices"], "-c": {}}}})
        code, out = self.run_main(capture, "--action", "start", "--log-dir", str(self.log_dir()))
        self.assertEqual(code, 0, out)
        argvs = [c["argv"] for c in self.calls("adb") if "logcat" in c["argv"]]
        self.assertTrue(argvs)
        deadline = time.time() + 120  # the capture process logs when it starts
        while time.time() < deadline and not [c for c in read_calls(self.log) if "logcat" in c["argv"]]:
            time.sleep(0.5)
        argvs += [c["argv"] for c in read_calls(self.log) if "logcat" in c["argv"]]
        for argv in argvs:
            self.assertEqual(argv[:2], ["-s", "emulator-5554"])
        info = json.loads((self.log_dir() / ".logcat_pid").read_text(encoding="utf-8"))
        self.assertIsInstance(info["pid"], int)
        self.assertEqual(Path(info["log"]).parent, self.log_dir())
        capture.stop_process(info["pid"])

    def test_start_with_only_a_phone_is_exit_1_and_touches_nothing(self):
        self.mem({"adb": {"out": PHONE_ONLY}})
        code, out = self.run_main(capture, "--action", "start", "--log-dir", str(self.log_dir()))
        self.assertEqual(code, 1)
        self.assertIn("no online emulator", out)
        self.assertFalse([c for c in self.calls("adb") if "logcat" in c["argv"]])

    def test_capture_failing_logcat_clear_is_exit_1(self):  # REAL fake adb whose logcat -c exits 1
        self.use_spec({"adb": {"by": {"devices": {"out": EMULATOR_ONLINE}, "-c": {"rc": 1, "out": "denied"}}}})
        code, out = self.run_main(capture, "--action", "start", "--log-dir", str(self.log_dir()))
        self.assertEqual(code, 1)
        self.assertIn("logcat -c failed", out)
        self.assertFalse((self.log_dir() / ".logcat_pid").exists())

    def test_stop_kills_the_recorded_process_and_summarizes(self):  # REAL process killed
        log_dir = self.log_dir()
        log_dir.mkdir()
        log = log_dir / "diagnostic_bulk_mail_1.log"
        log.write_text("Rules loaded: 50\n", encoding="utf-8")
        victim = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
        self.addCleanup(victim.kill)
        (log_dir / ".logcat_pid").write_text(json.dumps({"pid": victim.pid, "log": str(log)}), encoding="utf-8")
        code, out = self.run_main(capture, "--action", "stop", "--log-dir", str(log_dir))
        self.assertEqual(code, 0, out)
        self.assertIsNotNone(victim.wait(timeout=60))
        self.assertFalse((log_dir / ".logcat_pid").exists())
        self.assertIn("Log capture stopped", out)

    def test_stop_without_a_capture_is_exit_1(self):
        code, out = self.run_main(capture, "--action", "stop", "--log-dir", str(self.log_dir()))
        self.assertEqual(code, 1)
        self.assertIn("no active log capture", out)

    def test_stop_with_a_vanished_process_warns_and_still_summarizes(self):
        log_dir = self.log_dir()
        log_dir.mkdir()
        log = log_dir / "diagnostic_bulk_mail_1.log"
        log.write_text("Rules loaded: 50\n", encoding="utf-8")
        (log_dir / ".logcat_pid").write_text(json.dumps({"pid": 1, "log": str(log)}), encoding="utf-8")
        with mock.patch.object(capture, "stop_process", return_value=False):
            code, out = self.run_main(capture, "--action", "stop", "--log-dir", str(log_dir))
        self.assertEqual(code, 0, out)
        self.assertIn("already gone", out)

    def test_stop_permission_error_is_not_reported_as_gone(self):  # C6-5
        log_dir = self.log_dir()
        log_dir.mkdir()
        (log_dir / ".logcat_pid").write_text(json.dumps({"pid": 4242, "log": "x"}), encoding="utf-8")
        with mock.patch.object(capture.os, "kill", side_effect=PermissionError(13, "Access is denied")), \
                mock.patch.object(capture, "windows_pid_alive", return_value=True):
            code, out = self.run_main(capture, "--action", "stop", "--log-dir", str(log_dir))
        self.assertEqual(code, 1)
        self.assertNotIn("already gone", out)
        self.assertIn("could not stop", out)
        self.assertTrue((log_dir / ".logcat_pid").exists(), "the id file stays so the capture is not forgotten")

    def test_stop_process_distinguishes_gone_from_denied(self):  # C6-5
        with mock.patch.object(capture.os, "kill", side_effect=ProcessLookupError()):
            self.assertFalse(capture.stop_process(1))
        gone = OSError(22, "The parameter is incorrect")
        gone.winerror = 87
        with mock.patch.object(capture.os, "kill", side_effect=gone):
            self.assertFalse(capture.stop_process(1))
        with mock.patch.object(capture.os, "kill", side_effect=PermissionError(13, "denied")), \
                mock.patch.object(capture, "windows_pid_alive", return_value=True), \
                self.assertRaises(PermissionError):
            capture.stop_process(1)
        if os.name == "nt":  # Windows reports an exited process as access denied: not alive means gone
            with mock.patch.object(capture.os, "kill", side_effect=PermissionError(13, "denied")), \
                    mock.patch.object(capture, "windows_pid_alive", return_value=False):
                self.assertFalse(capture.stop_process(1))
        with mock.patch.object(capture.os, "kill", return_value=None):
            self.assertTrue(capture.stop_process(1))

    def test_stop_process_real_nonexistent_pid_is_gone(self):  # REAL os.kill on a pid that just exited
        done = subprocess.Popen([sys.executable, "-c", "pass"])
        done.wait(timeout=60)
        self.assertFalse(capture.stop_process(done.pid))

    def test_start_refuses_while_a_pid_file_exists(self):  # C6-5: the old logcat would be orphaned
        log_dir = self.log_dir()
        log_dir.mkdir()
        pid_file = log_dir / ".logcat_pid"
        pid_file.write_text(json.dumps({"pid": 99, "log": "old"}), encoding="utf-8")
        self.mem({"adb": {"out": EMULATOR_ONLINE}})
        code, out = self.run_main(capture, "--action", "start", "--log-dir", str(log_dir))
        self.assertEqual(code, 1)
        self.assertIn("--action stop first", out)
        self.assertEqual(json.loads(pid_file.read_text(encoding="utf-8"))["pid"], 99, "the old id is not overwritten")
        self.assertFalse([c for c in self.calls("adb") if "logcat" in c["argv"]], "no logcat -c, no new capture")

    def test_analyze_empty_log_is_exit_1(self):  # C6-5
        log = Path(self.tmp.name) / "empty.log"
        log.write_bytes(b"")
        code, out = self.run_main(capture, "--action", "analyze", "--log-file", str(log))
        self.assertEqual(code, 1)
        self.assertIn("empty", out)

    def test_analyze_log_without_any_marker_is_exit_1_and_says_so(self):  # C6-5
        log = Path(self.tmp.name) / "nomark.log"
        log.write_text("I/flutter: nothing relevant\n", encoding="utf-8")
        code, out = self.run_main(capture, "--action", "analyze", "--log-file", str(log))
        self.assertEqual(code, 1)
        self.assertIn("no diagnostic marker found", out)

    def test_patterns_match_the_real_app_log_lines(self):  # C3-3
        self.assertTrue(capture.MATCHED.search('I/flutter: [EVAL] Email from a@x.com matched rule "R" (pattern: p)'))
        self.assertTrue(capture.NOT_MATCHED.search(
            'I/flutter: [EVAL] Email "subj" from a@x.com did not match any of 3 enabled rules or safe senders [header-only pass]'))
        self.assertFalse(capture.MATCHED.search('[EVAL] Email "s" from a@x.com matched exception in rule "R", skipping'))
        self.assertFalse(capture.MATCHED.search("✓ Email 1 matched rule A"), "the old mark text is not an app line")

    def test_pattern_literals_and_markers_appear_in_the_app_source(self):  # C3-3: a pattern the app never prints is dead
        text = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                         for p in (REPO / "mobile-app" / "lib").rglob("*.dart"))
        for literal in (capture.MATCHED_LITERAL, capture.NOT_MATCHED_LITERAL, capture.DIAG_MARK, "Rules loaded:",
                        "Safe senders loaded:", "[EVAL]"):
            self.assertIn(literal, text, f"capture-diagnostic-logs.py looks for {literal!r}, which lib/ never prints")
        self.assertIn("matched rule \"${rule.name}\"", text)

    def test_unreadable_pid_file_is_exit_1(self):
        log_dir = self.log_dir()
        log_dir.mkdir()
        (log_dir / ".logcat_pid").write_text("not json", encoding="utf-8")
        code, out = self.run_main(capture, "--action", "stop", "--log-dir", str(log_dir))
        self.assertEqual(code, 1)
        self.assertIn("unreadable", out)

    def test_analyze_counts_and_flags_a_low_rule_count(self):
        log = Path(self.tmp.name) / "a.log"
        log.write_text("=== SCAN DIAGNOSTICS ===\nline1\n"
                       '[EVAL] Email from a@x.com matched rule "A" (pattern: x, type: header, subject: "s")\n'
                       '[EVAL] Email from b@x.com matched rule "B" (pattern: y, type: header, subject: "t")\n'
                       '[EVAL] Email "hello" from c@x.com did not match any of 40 enabled rules or safe senders\n'
                       '[EVAL] Email from d@x.com matched safe sender (pattern: z)\n'
                       '[EVAL] Email "s" from e@x.com matched exception in rule "R", skipping\n'
                       "Rules loaded: 12\nSafe senders loaded: 5\nsome ERROR here\n", encoding="utf-8")
        code, out = self.run_main(capture, "--action", "analyze", "--log-file", str(log))
        self.assertEqual(code, 0)
        self.assertIn("Matched: 2 emails", out)
        self.assertIn("No match: 1 emails", out)
        self.assertIn("Only 12 rules loaded", out)
        self.assertIn("Found 1 error/exception entries", out)
        self.assertIn("Safe senders loaded: 5", out)

    def test_analyze_missing_file_is_exit_1(self):
        code, out = self.run_main(capture, "--action", "analyze", "--log-file", str(Path(self.tmp.name) / "none.log"))
        self.assertEqual(code, 1)

    def test_analyze_needs_a_log_file(self):
        code, out = self.run_main(capture, "--action", "analyze")
        self.assertEqual(code, 1)

    def test_bad_action_is_usage_error(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            capture.main(["--action", "bogus"])
        self.assertEqual(caught.exception.code, 2)


class SecretsKeyNameTests(unittest.TestCase):
    """C1-1: every secrets-file key a helper script writes or reads is a name the app compiles in."""

    def lib_text(self) -> str:
        return "\n".join(p.read_text(encoding="utf-8", errors="replace")
                         for p in (REPO / "mobile-app" / "lib").rglob("*.dart"))

    def test_every_key_the_scripts_use_is_read_by_the_app(self):
        text = self.lib_text()
        for key in sup.SECRETS_KEYS_USED:
            self.assertRegex(text, r"fromEnvironment\(\s*'" + key + "'",
                             f"{key} is not a String.fromEnvironment name in mobile-app/lib")

    def test_every_gmail_key_in_the_secrets_templates_is_read_by_the_app(self):
        # Sprint 86 5.1.2 C1-1 sibling: the dev template and example still named the pre-Sprint 36 keys, so a new
        # developer got an empty Windows Gmail secret. What this does NOT catch: a non-Gmail key nothing reads.
        import json
        text = self.lib_text()
        for name in ("secrets.dev.json.template", "secrets.dev.example.json", "secrets.prod.json.template"):
            path = REPO / "mobile-app" / name
            if not path.exists():
                continue
            for key in json.loads(path.read_text(encoding="utf-8")):
                if "GMAIL" in key:
                    self.assertRegex(text, r"fromEnvironment\(\s*'" + key + "'",
                                     f"{name} names {key}, which no String.fromEnvironment in mobile-app/lib reads")

    def test_the_dead_key_is_not_one_the_app_reads(self):
        self.assertNotRegex(self.lib_text(), r"fromEnvironment\(\s*'" + sup.DEAD_SECRET_KEY + "'")

    def test_scripts_take_their_key_names_from_android_support(self):
        self.assertEqual(setup_oauth.SECRET_KEY, sup.WINDOWS_CLIENT_SECRET_KEY)
        self.assertEqual(setup_oauth.CLIENT_ID_KEY, sup.WINDOWS_CLIENT_ID_KEY)
        self.assertEqual(setup_oauth.ANDROID_ID_KEY, sup.ANDROID_CLIENT_ID_KEY)
        for name in ("setup-android-oauth.py", "export-tokens-for-android.py"):
            source = (SCRIPTS / name).read_text(encoding="utf-8")
            for key in sup.SECRETS_KEYS_USED:
                self.assertNotIn(f'"{key}"', source, f"{name} hardcodes {key}; use android_support")
            self.assertNotIn(f'"{sup.DEAD_SECRET_KEY}"', source)

    def test_android_define_key_matches_the_build_script(self):
        build = load("bws_keys", "build-with-secrets.py")
        self.assertEqual(build.ANDROID_DART_DEFINE_KEYS, (sup.ANDROID_CLIENT_ID_KEY,))


class BuildScriptSharesEmulatorHelpersTests(Sandbox):
    """C1-2: build-with-secrets.py calls android_support for the emulator helpers instead of keeping a copy."""

    def setUp(self) -> None:
        super().setUp()
        self.build = load("bws_shared", "build-with-secrets.py")

    def test_online_emulator_uses_the_shared_parser(self):
        self.mem({"adb": {"out": "List of devices attached\nR5CT12345XY\tdevice\nemulator-5556\toffline\nemulator-5554\tdevice\n"}})
        self.assertEqual(self.build.Adb(sup.find_adb()).online_emulator(), "emulator-5554")
        self.mem({"adb": {"out": PHONE_ONLY}})
        self.assertIsNone(self.build.Adb(sup.find_adb()).online_emulator())

    def test_list_avds_failure_is_a_warning_and_an_empty_list(self):  # deliberate: the build then ends in "No AVDs found"
        with mock.patch.object(sup, "list_avds", return_value=([], "emulator -list-avds failed (exit 1)")):
            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                names = self.build.list_avds("emulator")
        self.assertEqual(names, [])
        self.assertIn("[WARNING] Could not list AVDs", buffer.getvalue())

    def test_list_avds_returns_the_shared_filtered_names(self):
        with mock.patch.object(sup, "list_avds", return_value=(["pixel34_updated"], None)):
            self.assertEqual(self.build.list_avds("emulator"), ["pixel34_updated"])

    def test_launch_emulator_goes_through_the_shared_launcher_minimized(self):
        with mock.patch.object(sup, "launch_emulator") as launch:
            self.build.launch_emulator("emu", "avd1")
        launch.assert_called_once_with("emu", "avd1", minimized=True)

    def test_no_private_copy_of_the_helpers_remains(self):
        source = (SCRIPTS / "build-with-secrets.py").read_text(encoding="utf-8")
        self.assertNotIn('"-list-avds"', source)
        self.assertNotIn('startswith("emulator-")', source)


class RunEmulatorFlutterArgvTests(unittest.TestCase):
    """C1-3: flutter run names the dev flavor (no default-flavor in pubspec.yaml; gradle defines dev and prod)."""

    def test_argv_names_the_dev_flavor_and_app_env(self):
        argv = run_emulator.flutter_run_argv("flutter", "emulator-5554")
        self.assertEqual(argv[:2], ["flutter", "run"])
        self.assertEqual(argv[argv.index("-d") + 1], "emulator-5554")
        self.assertEqual(argv[argv.index("--flavor") + 1], "dev")
        self.assertIn("--dart-define=APP_ENV=dev", argv)

    def test_matches_the_flavor_pair_build_with_secrets_uses(self):
        build = load("bws_flavor", "build-with-secrets.py")
        argv = run_emulator.flutter_run_argv("flutter", "emulator-5554")
        for part in build.flavor_args("dev"):
            self.assertIn(part, argv)

    def test_pubspec_has_no_default_flavor_and_gradle_has_a_dev_flavor(self):
        pubspec = (REPO / "mobile-app" / "pubspec.yaml").read_text(encoding="utf-8")
        self.assertNotIn("default-flavor", pubspec, "if a default flavor is added, --flavor here may become redundant")
        gradle = (REPO / "mobile-app" / "android" / "app" / "build.gradle.kts").read_text(encoding="utf-8")
        self.assertIn('create("dev")', gradle)

    def test_main_uses_the_flavored_argv(self):
        captured = {}
        with mock.patch.object(run_emulator, "ensure_emulator", return_value="emulator-5554"), \
                mock.patch.object(sup, "find_adb", return_value="adb"), \
                mock.patch.object(sup, "wait_for_boot", return_value=True), \
                mock.patch.object(sup, "run_inherit", side_effect=lambda argv, cwd=None, env=None: captured.update(argv=argv) or 0), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(run_emulator.main([]), 0)
        self.assertIn("--flavor", captured["argv"])


class ScreenReaderTests(unittest.TestCase):
    def test_unknown_action_is_usage_error(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            screen_reader.main(["bogus"])
        self.assertEqual(caught.exception.code, 2)

    def test_default_action_is_enable(self):
        with mock.patch.object(screen_reader, "run", return_value=0) as run:
            screen_reader.main([])
        run.assert_called_once_with("enable")

    @unittest.skipUnless(os.name == "nt", "Windows only")
    def test_status_reads_the_real_flag_without_changing_it(self):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = screen_reader.main(["status"])
        self.assertEqual(code, 0)
        self.assertRegex(buffer.getvalue(), r"^Screen reader flag: (True|False)\n$")

    @unittest.skipUnless(os.name == "nt", "Windows only")
    def test_spi_real_failing_win32_call_raises(self):  # REAL Win32 call that returns FALSE
        user32 = screen_reader.load_user32()
        with self.assertRaises(OSError):
            screen_reader.spi(user32, 0xFFFF, 0, None, 0)  # not a valid SPI action

    def test_enable_that_does_not_stick_is_exit_1(self):
        class StuckOff:
            """A fake user32 whose set call succeeds but whose read always says off (a seam, not a real failure)."""

            def __init__(self):
                self.SystemParametersInfoW = lambda action, param, pointer, flags: True

        with mock.patch.object(screen_reader.sup, "sleep", lambda s: None), contextlib.redirect_stdout(io.StringIO()) as out:
            code = screen_reader.run("enable", user32=StuckOff())
        self.assertEqual(code, 1)
        self.assertIn("After: False", out.getvalue())

    @unittest.skipUnless(os.name == "nt", "Windows only")
    def test_win32_error_is_reported_not_raised(self):
        class Broken:
            def __init__(self):
                self.SystemParametersInfoW = lambda *a: False

        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = screen_reader.run("status", user32=Broken())
        self.assertEqual(code, 1)
        self.assertIn("[ERROR]", out.getvalue())

    @unittest.skipIf(os.name == "nt", "only meaningful off Windows")
    def test_not_windows_is_exit_1(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(screen_reader.run("status"), 1)


class FixFlutterGitTests(Sandbox):
    def make_sdk(self, with_git: bool = True) -> Path:
        root = Path(self.tmp.name) / "flutter-sdk"
        (root / "bin").mkdir(parents=True)
        if with_git:
            (root / ".git").mkdir()  # the script only checks that the entry exists; git calls are stood in for
        return root

    def stand_in_git(self, answers: dict):
        seen: list[tuple] = []

        def fake_git(root, *args):
            seen.append(args)
            return answers.get(args[0], (0, ""))

        return seen, mock.patch.object(fix_git, "git", fake_git)

    def test_dry_run_is_the_default_and_runs_no_git(self):
        def no_git(*args, **kwargs):
            raise AssertionError("a dry run must not run git")

        with mock.patch.object(fix_git, "git", no_git):
            code, out = self.run_main(fix_git, "--flutter-root", str(self.make_sdk()))
        self.assertEqual(code, 0)
        self.assertIn("[DRY RUN]", out)
        self.assertIn("3.47.4", out, "the .fvmrc pin is printed")

    def test_flutter_root_is_two_levels_above_the_command(self):
        sdk = Path(self.tmp.name) / "sdk2"
        install_fake(sdk / "bin", "flutter")
        with mock.patch.dict(os.environ, {"PATH": str(sdk / "bin")}):
            self.assertEqual(fix_git.flutter_root(None), sdk.resolve())

    def test_flutter_missing_is_exit_1(self):
        with mock.patch.dict(os.environ, {"PATH": str(Path(self.tmp.name) / "empty")}):
            code, out = self.run_main(fix_git)
        self.assertEqual(code, 1)
        self.assertIn("flutter was not found", out)

    def test_not_a_git_checkout_is_exit_1(self):
        code, out = self.run_main(fix_git, "--yes", "--flutter-root", str(self.make_sdk(with_git=False)))
        self.assertEqual(code, 1)
        self.assertIn("No .git entry", out)

    def test_fix_flutter_git_failed_fetch_stops_before_reset(self):
        seen, patch = self.stand_in_git({"fetch": (128, "fatal: unable to access")})
        with patch:
            code, out = self.run_main(fix_git, "--yes", "--flutter-root", str(self.make_sdk()))
        self.assertEqual(code, 1, out)
        self.assertIn("Stopping before any reset", out)
        self.assertNotIn("[SUCCESS]", out)
        self.assertFalse([a for a in seen if a[0] == "reset"], "reset --hard must not run after a failed fetch")

    def test_fix_flutter_git_real_failing_git_is_exit_1(self):  # REAL git on a folder that is not a repository
        root = Path(self.tmp.name) / "broken-sdk"
        (root / ".git").mkdir(parents=True)
        code, out = self.run_main(fix_git, "--yes", "--flutter-root", str(root))
        self.assertEqual(code, 1, out)
        self.assertIn("git remote failed", out)
        self.assertNotIn("[SUCCESS]", out)

    def test_remote_name_must_match_exactly(self):
        seen, patch = self.stand_in_git({"remote": (0, "myorigin\n")})
        with patch:
            code, out = self.run_main(fix_git, "--yes", "--flutter-root", str(self.make_sdk()))
        self.assertEqual(code, 0, out)
        self.assertIn("Adding the origin remote", out)
        self.assertIn(("remote", "add", "origin", fix_git.DEFAULT_URL), seen)
        self.assertIn(("reset", "--hard", "FETCH_HEAD"), seen)

    def test_existing_origin_is_kept_and_ref_is_fetched(self):
        seen, patch = self.stand_in_git({"remote": (0, "origin\n")})
        with patch:
            code, out = self.run_main(fix_git, "--yes", "--flutter-root", str(self.make_sdk()), "--ref", "3.47.4")
        self.assertIn("already configured", out)
        self.assertFalse([a for a in seen if a[:2] == ("remote", "add")])
        self.assertIn(("fetch", "--depth", "1", "origin", "3.47.4"), seen)


class EmulatorExitReportTests(unittest.TestCase):
    """Sprint 86 7.7.1 M6: an emulator that exits at once shows WHY, not "did not appear within N s"."""

    AVD = "s86-771-exit-report-test"

    def tearDown(self):
        with contextlib.suppress(OSError):
            sup.emulator_log_path(self.AVD).unlink()

    def test_a_process_that_exits_at_once_reports_its_code_and_its_own_error_text(self):
        # A real process, not a mock: python rejects "-avd" with its own usage error on stderr and exits 2.
        proc = sup.launch_emulator(sys.executable, self.AVD)
        proc.wait(timeout=60)
        report = sup.emulator_exit_report(proc)
        self.assertIsNotNone(report)
        self.assertIn(f"exit {proc.returncode}", report)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("-a", report)  # the interpreter's own message about the unknown option reached the log
        self.assertIn(str(sup.emulator_log_path(self.AVD)), report)
        # Does NOT catch: an emulator that keeps running but never registers with adb (the wait still times out).

    def test_no_process_and_a_running_process_report_nothing(self):
        self.assertIsNone(sup.emulator_exit_report(None))
        running = mock.Mock()
        running.poll.return_value = None
        self.assertIsNone(sup.emulator_exit_report(running))


if __name__ == "__main__":
    unittest.main()
