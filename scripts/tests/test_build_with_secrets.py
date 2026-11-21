"""Tests for mobile-app/scripts/build-with-secrets.py and build-apk.py (F335, Sprint 85; ports of the .ps1 files).

Run: python -I -m unittest discover -s scripts/tests -p test_build_with_secrets.py -v

Every test uses FAKE secrets, a fake signing file, a fake flutter and a temporary mobile-app folder. No test
starts a real build, reads a real secrets file, or writes outside the temporary folder.

Test list and what each does NOT catch:
  test_gradle_property_injected (AC-2 / SEC-9): the ANDROID_GMAIL_CLIENT_ID value reaches the argument list as
      -PandroidGmailClientId=<value>; a missing id adds nothing; a placeholder is refused for release; a value with
      a cmd.exe metacharacter is refused. NOT caught: the gradle side (android_client_id_test.dart and the real
      release build cover build.gradle.kts).
  test_build_arguments_and_flavor_mapping (T-1): the full flutter argument list for debug apk, release apk and
      release aab, both flavors, with --flavor and APP_ENV in lockstep and --obfuscate only on release; the
      artifact path per combination. NOT caught: a flag flutter itself rejects (the real build proves that).
  test_version_code_check (AC-3 / IMP-2): a build number equal to or below "Last uploaded to Play" is refused, one
      above passes, an unreadable row or pubspec is refused. NOT caught: the wording of the real status table
      changing (test_real_status_row_is_readable pins the real file).
  test_real_status_row_is_readable: the real docs/STORE_VERSION_STATUS.md row parses to an int. NOT caught: the
      number being correct.
  test_signing_config: missing file, missing key and missing keystore are refused; a good file maps to the four
      ANDROID_* names. NOT caught: a keystore that is the wrong key.
  test_preflight_combinations: the three refused flag pairs. NOT caught: an unrefused pair that fails later.
  test_provider_validation_prints_no_values: a fake client id, secret, password and email never appear in the
      output. NOT caught: a value printed by a later step (the end-to-end tests check that output too).
  test_end_to_end_release_aab: main() with a fake flutter: clean before build, the exact build argument list, the
      child sees the four signing variables, this process never does, no secret value on the command line or in
      the output, the bundle passes the real F204 script and lands in dist/android-<version>/. NOT caught: real
      gradle, real signing, a real manifest.
  test_refusal_deletes_nothing (defect 12): an IMP-2 refusal and a missing signing file leave the build folder
      intact and never call flutter. NOT caught: a refusal added later that runs after the clean.
  test_failed_f204_is_not_kept (defect 13): a bundle that fails the F204 check exits 1 and is not copied to dist.
      NOT caught: the F204 rules themselves (test_verify_aab_play_requirements.py).
  test_flutter_failure_exit_code: a failing flutter build returns flutter's exit code. NOT caught: a signal.
  test_debug_apk_end_to_end: a debug build passes no signing variables, no --obfuscate, and finds the apk.
      NOT caught: install to an emulator (no device is used; adb steps are not covered by a host test).
  test_missing_artifact_is_error: flutter exit 0 without the artifact is exit 1. NOT caught: a stale artifact
      (the clean removes build/ first).
  test_avd_choice: the four cases of the PowerShell self-test. NOT caught: an AVD folder in a layout this
      machine does not have.
  test_self_test_option: --self-test exits 0. NOT caught: more than those four cases.
  test_build_apk_wrapper: build-apk.py calls the builder with release and apk; --verbose-output runs analyze first.
      NOT caught: the real flutter analyze.
  test_display_arg_masks_property_values: a -P argument is logged as name=<set>. NOT caught: a value logged by
      another line.
  test_gmail_needs_the_android_client_id_only (issue #575): Gmail counts as configured from ANDROID_GMAIL_CLIENT_ID
      alone, and WINDOWS_* keys never make it count. NOT caught: whether the id is a real Google client.
  AndroidDefinesTests (issue #575): the Android build gets a filtered temporary defines file holding only
      ANDROID_DART_DEFINE_KEYS, outside the repository, deleted after success, a flutter failure and a refusal.
      NOT caught: see the class docstring.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SCRIPTS = REPO / "mobile-app" / "scripts"
sys.path.insert(0, str(HERE))
import fake_flutter  # noqa: E402


def load(name: str, file: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / file)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


tool = load("build_with_secrets_under_test", "build-with-secrets.py")
verify = load("verify_aab_under_test", "verify-aab-play-requirements.py")

CLIENT_ID = "123456789-fakeclientidprefix.apps.googleusercontent.com"
CLIENT_SECRET = "FAKE-CLIENT-SECRET-VALUE"
AOL_PASSWORD = "fake-aol-app-password"
AOL_EMAIL = "fake.person@example.invalid"
KEY_PASSWORD = "fake&key?password"
STORE_PASSWORD = "fake-store-password"

FAKE_IMPL = r'''
import json, os, shutil, sys
argv = sys.argv[1:]
names = ["ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
record = {"argv": argv, "cwd": os.getcwd(), "env": {n: os.environ[n] for n in names if n in os.environ},
          "build_dir_present": os.path.isdir("build")}
for arg in argv:
    if arg.startswith("--dart-define-from-file="):
        path = arg.split("=", 1)[1]
        record["defines_path"] = path
        with open(path, encoding="utf-8") as defines:
            record["defines_keys"] = sorted(json.load(defines))
with open(os.environ["FAKE_CALLS"], "a", encoding="utf-8") as handle:
    handle.write(json.dumps(record) + "\n")
if argv and argv[0] == "build":
    code = int(os.environ.get("FAKE_BUILD_RC", "0"))
    src, dst = os.environ.get("FAKE_ARTIFACT_SRC"), os.environ.get("FAKE_ARTIFACT_DST")
    if code == 0 and src and dst:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
    sys.exit(code)
sys.exit(0)
'''

STATUS_TEXT = ("| Item | Value | Date | Notes |\n|---|---|---|---|\n"
               "| **Last uploaded to Play (any track)** | 0.24.1 (versionCode 22) | 2026-11-10 | note |\n")


def quiet(callable_, *args, **kwargs):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        result = callable_(*args, **kwargs)
    return result, buf.getvalue()


class Project:
    """A temporary mobile-app folder with a pubspec, status file, secrets, signing file and a fake flutter."""

    def __init__(self, test: unittest.TestCase, version: str = "9.9.9+23", uploaded_row: str = STATUS_TEXT):
        self.root = Path(tempfile.mkdtemp(prefix="f335-"))
        test.addCleanup(lambda: __import__("shutil").rmtree(self.root, ignore_errors=True))
        self.mobile = self.root / "mobile-app"
        (self.mobile / "build").mkdir(parents=True)
        (self.mobile / "build" / "keep.txt").write_text("sentinel")
        (self.mobile / "pubspec.yaml").write_text(f"name: x\nversion: {version}\n")
        (self.root / "docs").mkdir()
        (self.root / "docs" / "STORE_VERSION_STATUS.md").write_text(uploaded_row)
        self.secrets = self.mobile / "secrets.dev.json"
        self.secrets.write_text(json.dumps({
            "ANDROID_GMAIL_CLIENT_ID": CLIENT_ID, "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "x-win-id",
            "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": CLIENT_SECRET, "ANDROID_REDIRECT_URI": "com.example:/cb",
            "AOL_EMAIL": AOL_EMAIL, "AOL_APP_PASSWORD": AOL_PASSWORD}))
        keystore = self.root / "fake.jks"
        keystore.write_text("not a keystore")
        self.signing = self.root / "signing.json"
        self.signing.write_text(json.dumps({"keystorePath": str(keystore), "keystorePassword": STORE_PASSWORD,
                                            "keyAlias": "upload", "keyPassword": KEY_PASSWORD}))
        self.calls = self.root / "calls.jsonl"
        bin_dir = fake_flutter.install(self.root / "bin")
        (bin_dir / "fake_flutter_impl.py").write_text(FAKE_IMPL, encoding="utf-8")
        self.home = self.root / "home"
        self.home.mkdir()
        good = self.root / "good.aab"
        verify_bundle(good, 36)
        self.good_aab = good
        env = {"PATH": str(bin_dir) + os.pathsep + os.environ.get("PATH", ""), "FAKE_CALLS": str(self.calls),
               "USERPROFILE": str(self.home), "HOME": str(self.home)}
        self._env = mock.patch.dict(os.environ, env)
        self._env.start()
        test.addCleanup(self._env.stop)
        # Rebind Path.home-based defaults: both variables above point at the temporary folder.

    def calls_list(self) -> list[dict]:
        return fake_flutter.read_calls(self.calls)

    def set_artifact(self, relative: str, source: Path) -> None:
        os.environ["FAKE_ARTIFACT_SRC"] = str(source)
        os.environ["FAKE_ARTIFACT_DST"] = str(self.mobile / relative)


def verify_bundle(path: Path, target: int, permissions: list[str] | None = None) -> None:
    import zipfile
    manifest = verify.build_manifest(target, permissions if permissions is not None else [verify.INTERNET_PERMISSION])
    with zipfile.ZipFile(path, "w") as bundle:
        bundle.writestr("BundleConfig.pb", b"x")
        bundle.writestr(verify.MANIFEST_ENTRY, manifest)


class PropertyInjectionTests(unittest.TestCase):
    def test_gradle_property_injected(self) -> None:
        args, _ = quiet(tool.gradle_project_args, {"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID}, "release")
        self.assertEqual(args, [f"-PandroidGmailClientId={CLIENT_ID}"])
        args, out = quiet(tool.gradle_project_args, {}, "release")
        self.assertEqual(args, [])
        self.assertIn("ANDROID_GMAIL_CLIENT_ID not set", out)
        with self.assertRaises(tool.BuildRefused):
            quiet(tool.gradle_project_args, {"ANDROID_GMAIL_CLIENT_ID": "YOUR-CLIENT-ID"}, "release")
        args, out = quiet(tool.gradle_project_args, {"ANDROID_GMAIL_CLIENT_ID": "YOUR-CLIENT-ID"}, "debug")
        self.assertEqual(args, ["-PandroidGmailClientId=YOUR-CLIENT-ID"])
        self.assertIn("placeholder", out)
        for bad in ("abc&calc", "a b", "x?y", "a%PATH%", "a|b", 'a"b'):
            with self.subTest(value=bad), self.assertRaises(tool.BuildRefused):
                quiet(tool.gradle_project_args, {"ANDROID_GMAIL_CLIENT_ID": bad}, "debug")

    def test_display_arg_masks_property_values(self) -> None:
        self.assertEqual(tool.display_arg(f"-PandroidGmailClientId={CLIENT_ID}"), "-PandroidGmailClientId=<set>")
        self.assertEqual(tool.display_arg("--flavor"), "--flavor")
        self.assertEqual(tool.display_arg("--dart-define=APP_ENV=prod"), "--dart-define=APP_ENV=prod")


class ArgumentTests(unittest.TestCase):
    def test_build_arguments_and_flavor_mapping(self) -> None:
        sym = Path("/sym")
        gradle = ["-PandroidGmailClientId=ID"]
        debug = tool.flutter_build_args(build_type="debug", env="dev", output="apk", defines_arg="defines.json",
                                        gradle_args=gradle, symbols_dir=None)
        self.assertEqual(debug, ["build", "apk", "--debug", "--flavor", "dev", "--dart-define=APP_ENV=dev",
                                 "--dart-define-from-file=defines.json", "-PandroidGmailClientId=ID"])
        no_defines = tool.flutter_build_args(build_type="debug", env="dev", output="apk", defines_arg=None,
                                             gradle_args=[], symbols_dir=None)
        self.assertFalse(any(a.startswith("--dart-define-from-file") for a in no_defines))
        rel_apk = tool.flutter_build_args(build_type="release", env="prod", output="apk",
                                          defines_arg="defines.json", gradle_args=gradle, symbols_dir=sym)
        self.assertEqual(rel_apk[:3], ["build", "apk", "--release"])
        self.assertEqual(rel_apk[-2:], ["--obfuscate", f"--split-debug-info={sym}"])
        rel_aab = tool.flutter_build_args(build_type="release", env="prod", output="aab",
                                          defines_arg="defines.json", gradle_args=gradle, symbols_dir=sym)
        self.assertEqual(rel_aab[:3], ["build", "appbundle", "--release"])
        self.assertIn("--flavor", rel_aab)
        self.assertEqual(rel_aab[rel_aab.index("--flavor") + 1], "prod")
        self.assertIn("--dart-define=APP_ENV=prod", rel_aab)
        self.assertNotIn("--obfuscate", debug)
        with self.assertRaises(tool.BuildRefused):
            tool.flutter_build_args(build_type="release", env="prod", output="aab", defines_arg="s", gradle_args=[],
                                    symbols_dir=None)
        self.assertEqual(tool.artifact_path("prod", "debug", "apk"), "build/app/outputs/flutter-apk/app-prod-debug.apk")
        self.assertEqual(tool.artifact_path("dev", "release", "apk"), "build/app/outputs/flutter-apk/app-dev-release.apk")
        self.assertEqual(tool.artifact_path("prod", "release", "aab"), "build/app/outputs/bundle/prodRelease/app-prod-release.aab")
        run = tool.flutter_run_args(build_type="debug", env="prod", defines_arg="s.json", gradle_args=gradle,
                                    device="emulator-5554")
        self.assertEqual(run[0], "run")
        self.assertIn("-PandroidGmailClientId=ID", run)
        self.assertEqual(run[-2:], ["-d", "emulator-5554"])


class VersionCodeTests(unittest.TestCase):
    def check(self, version: str, row: str = STATUS_TEXT):
        project = Project(self, version=version, uploaded_row=row)
        return quiet(tool.check_version_code, project.mobile)

    def test_version_code_check(self) -> None:
        _, out = self.check("0.25.0+23")
        self.assertIn("versionCode 23 is above the last uploaded (22)", out)
        for bad in ("0.24.1+22", "0.24.0+21", "0.25.0+1"):
            with self.subTest(version=bad), self.assertRaises(tool.BuildRefused) as caught:
                self.check(bad)
            self.assertIn("not above 22", str(caught.exception))
            self.assertIn("+23 first", str(caught.exception))
        with self.assertRaises(tool.BuildRefused):
            self.check("0.25.0+23", row="| nothing here |\n")
        with self.assertRaises(tool.BuildRefused):
            self.check("0.25.0")  # no build number in the pubspec

    def test_real_status_row_is_readable(self) -> None:
        value = tool.read_last_uploaded(REPO / "docs" / "STORE_VERSION_STATUS.md")
        self.assertIsInstance(value, int)


class SigningTests(unittest.TestCase):
    def test_signing_config(self) -> None:
        project = Project(self)
        env = tool.load_signing(project.signing)
        self.assertEqual(sorted(env), ["ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEYSTORE_PATH", "ANDROID_KEY_ALIAS",
                                       "ANDROID_KEY_PASSWORD"])
        self.assertEqual(env["ANDROID_KEY_PASSWORD"], KEY_PASSWORD)
        with self.assertRaises(tool.BuildRefused):
            tool.load_signing(project.root / "missing.json")
        data = json.loads(project.signing.read_text())
        for key in tool.SIGNING_KEYS:
            broken = dict(data)
            del broken[key]
            path = project.root / f"no-{key}.json"
            path.write_text(json.dumps(broken))
            with self.subTest(key=key), self.assertRaises(tool.BuildRefused) as caught:
                tool.load_signing(path)
            self.assertIn(key, str(caught.exception))
        data["keystorePath"] = str(project.root / "absent.jks")
        project.signing.write_text(json.dumps(data))
        with self.assertRaises(tool.BuildRefused):
            tool.load_signing(project.signing)


class PreflightTests(unittest.TestCase):
    def parse(self, *argv: str):
        return tool.build_parser().parse_args(list(argv))

    def test_preflight_combinations(self) -> None:
        tool.preflight(self.parse())
        tool.preflight(self.parse("--build-type", "debug", "--run"))
        tool.preflight(self.parse("--output", "aab"))
        for argv in (["--run", "--build-type", "release"], ["--output", "aab", "--install-to-emulator"],
                     ["--output", "aab", "--build-type", "debug"]):
            with self.subTest(argv=argv), self.assertRaises(tool.BuildRefused):
                tool.preflight(self.parse(*argv))


class ProviderTests(unittest.TestCase):
    def test_provider_validation_prints_no_values(self) -> None:
        secrets = {"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID, "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": CLIENT_SECRET,
                   "ANDROID_REDIRECT_URI": "com.example:/cb", "AOL_EMAIL": AOL_EMAIL, "AOL_APP_PASSWORD": AOL_PASSWORD}
        (gmail, aol), out = quiet(tool.validate_providers, secrets)
        self.assertTrue(gmail and aol)
        for value in (CLIENT_ID, CLIENT_SECRET, AOL_EMAIL, AOL_PASSWORD, "com.example"):
            self.assertNotIn(value, out)
        (gmail, aol), out = quiet(tool.validate_providers, {"AOL_EMAIL": AOL_EMAIL})
        self.assertFalse(gmail or aol)
        self.assertIn("INCOMPLETE", out)
        (gmail, aol), _ = quiet(tool.validate_providers, {})
        self.assertFalse(gmail or aol)

    def test_gmail_needs_the_android_client_id_only(self) -> None:
        # Issue #575: the Android app signs in with ANDROID_GMAIL_CLIENT_ID alone (no secret, no redirect key).
        (gmail, _), out = quiet(tool.validate_providers, {"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID})
        self.assertTrue(gmail)
        windows_only = {"WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "x-win-id", "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": CLIENT_SECRET,
                        "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback", "ANDROID_REDIRECT_URI": "x:/cb"}
        (gmail, _), out = quiet(tool.validate_providers, windows_only)
        self.assertFalse(gmail, "Windows keys must not make Gmail count as configured for Android")
        self.assertIn("WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET", out)  # a NAME, printed as information
        self.assertNotIn(CLIENT_SECRET, out)
        (gmail, _), out = quiet(tool.validate_providers, {"ANDROID_GMAIL_CLIENT_ID": "YOUR-CLIENT-ID"})
        self.assertFalse(gmail)
        self.assertIn("INCOMPLETE", out)


class AndroidDefinesTests(unittest.TestCase):
    """Issue #575: the Android build receives only ANDROID_DART_DEFINE_KEYS.

    What these tests would NOT catch: a key added to ANDROID_DART_DEFINE_KEYS by a person who believes Android
    reads it (the allow-list is the policy, and the tests only pin that the Windows secret is not in it); a Dart
    change that starts reading a Windows key on Android (the build would silently get an empty value); and flutter
    itself reading some other file (the fake flutter only proves which path was passed).
    """

    ALL_KEYS = {"GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback", "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "x-win-id",
                "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": CLIENT_SECRET, "ANDROID_GMAIL_CLIENT_ID": CLIENT_ID,
                "ANDROID_REDIRECT_URI": "com.example:/cb", "AOL_EMAIL": AOL_EMAIL, "AOL_APP_PASSWORD": AOL_PASSWORD}

    def test_filtered_defines_hold_exactly_the_allowed_keys(self) -> None:
        self.assertNotIn("WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET", tool.ANDROID_DART_DEFINE_KEYS)
        kept, dropped = tool.android_dart_defines(self.ALL_KEYS)
        self.assertEqual(kept, {"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID})
        self.assertEqual(set(kept) | set(dropped), set(self.ALL_KEYS))
        self.assertIn("WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET", dropped)
        kept, dropped = tool.android_dart_defines({"AOL_EMAIL": AOL_EMAIL})
        self.assertEqual(kept, {})
        self.assertEqual(dropped, ["AOL_EMAIL"])

    def test_defines_file_is_outside_the_repo_and_removable(self) -> None:
        path = tool.write_android_defines_file({"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID})
        try:
            self.assertEqual(path.suffix, ".json")
            self.assertFalse(str(path.resolve()).lower().startswith(str(REPO.resolve()).lower()))
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), {"ANDROID_GMAIL_CLIENT_ID": CLIENT_ID})
        finally:
            tool.remove_quietly(path)
        self.assertFalse(path.exists())
        tool.remove_quietly(path)  # a second delete is quiet

    def run_build(self, project: Project, *argv: str) -> tuple[int, str, dict]:
        project.secrets.write_text(json.dumps(self.ALL_KEYS))
        code, out = quiet(tool.main, list(argv) + ["--secrets-file", str(project.secrets)], mobile_app=project.mobile)
        builds = [c for c in project.calls_list() if c["argv"][0] == "build"]
        return code, out, builds[-1] if builds else {}

    def test_build_receives_only_the_filtered_file_and_it_is_removed(self) -> None:
        project = Project(self)
        project.set_artifact("build/app/outputs/flutter-apk/app-prod-debug.apk", project.good_aab)
        code, out, build = self.run_build(project, "--build-type", "debug")
        self.assertEqual(code, 0, out)
        self.assertEqual(build["defines_keys"], ["ANDROID_GMAIL_CLIENT_ID"])
        self.assertIn(f"--dart-define-from-file={build['defines_path']}", build["argv"])
        self.assertNotIn(str(project.secrets), " ".join(build["argv"]))
        self.assertNotIn("secrets.dev.json", " ".join(build["argv"]))
        self.assertFalse(Path(build["defines_path"]).exists(), "the temporary defines file must be deleted")
        self.assertIn("Not passed (the Android app does not read them): ", out)
        self.assertIn("WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET", out)
        for value in (CLIENT_SECRET, CLIENT_ID, AOL_PASSWORD, AOL_EMAIL):
            self.assertNotIn(value, out)

    def test_aol_only_release_is_refused_and_aol_is_not_claimed(self) -> None:
        # Sprint 85 7.7.1 L3. What this test would NOT catch: a Gmail key that is set but rejected by Google.
        project = Project(self)
        project.secrets.write_text(json.dumps({"AOL_EMAIL": AOL_EMAIL, "AOL_APP_PASSWORD": AOL_PASSWORD}))
        code, out = quiet(tool.main, ["--build-type", "release", "--secrets-file", str(project.secrets)],
                          mobile_app=project.mobile)
        self.assertEqual(code, 1, out)
        self.assertIn("A release build needs a real ANDROID_GMAIL_CLIENT_ID", out)
        self.assertNotIn("Build will include", out)
        self.assertEqual([c for c in project.calls_list() if c["argv"][0] == "build"], [])

    def test_aol_only_debug_builds_with_a_warning_and_aol_is_not_claimed(self) -> None:
        # The .ps1 rule ("Gmail or AOL") is kept for debug: AOL testing needs no Gmail id. What this test would
        # NOT catch: whether Gmail sign-in in that build fails in the way the warning says.
        project = Project(self)
        project.secrets.write_text(json.dumps({"AOL_EMAIL": AOL_EMAIL, "AOL_APP_PASSWORD": AOL_PASSWORD}))
        project.set_artifact("build/app/outputs/flutter-apk/app-prod-debug.apk", project.good_aab)
        code, out = quiet(tool.main, ["--build-type", "debug", "--secrets-file", str(project.secrets)],
                          mobile_app=project.mobile)
        self.assertIn("Gmail sign-in will not work in this debug build", out)
        self.assertNotIn("Build will include", out)
        self.assertNotIn("AOL provider", out)
        self.assertEqual(len([c for c in project.calls_list() if c["argv"][0] == "build"]), 1, out)
        self.assertEqual(code, 0, out)

    def test_gmail_and_aol_secrets_file_builds_and_says_aol_is_ignored(self) -> None:
        project = Project(self)
        project.set_artifact("build/app/outputs/flutter-apk/app-prod-debug.apk", project.good_aab)
        code, out, _build = self.run_build(project, "--build-type", "debug")
        self.assertEqual(code, 0, out)
        self.assertIn("Build will include the Gmail provider", out)
        self.assertNotIn("Gmail AOL", out)
        self.assertIn("AOL keys in the secrets file are ignored", out)

    def test_defines_file_is_removed_when_flutter_fails(self) -> None:
        project = Project(self)
        with mock.patch.dict(os.environ, {"FAKE_BUILD_RC": "3"}):
            code, out, build = self.run_build(project, "--build-type", "debug")
        self.assertEqual(code, 3, out)
        self.assertFalse(Path(build["defines_path"]).exists())

    def test_run_option_gets_the_filtered_file_and_it_is_removed(self) -> None:
        project = Project(self)
        seen: dict = {}

        def fake_run_app(mobile_app, flutter, args, defines_arg, gradle_args) -> int:
            seen["path"] = defines_arg
            seen["keys"] = sorted(json.loads(Path(defines_arg).read_text(encoding="utf-8")))
            return 0

        with mock.patch.object(tool, "run_app", side_effect=fake_run_app):
            code, out, _ = self.run_build(project, "--build-type", "debug", "--run")
        self.assertEqual(code, 0, out)
        self.assertEqual(seen["keys"], ["ANDROID_GMAIL_CLIENT_ID"])
        self.assertFalse(Path(seen["path"]).exists())

    def test_defines_file_is_removed_on_a_refusal(self) -> None:
        project = Project(self)
        created: list[Path] = []
        real = tool.write_android_defines_file

        def spy(defines: dict) -> Path:
            created.append(real(defines))
            return created[-1]

        with mock.patch.object(tool, "write_android_defines_file", side_effect=spy):
            code, out, _ = self.run_build(project, "--signing-config-path", str(project.root / "absent.json"))
        self.assertEqual(code, 1)
        self.assertIn("GP-2", out)
        self.assertEqual(len(created), 1)
        self.assertFalse(created[0].exists())


class EndToEndTests(unittest.TestCase):
    def run_main(self, project: Project, *argv: str) -> tuple[int, str]:
        return quiet(tool.main, list(argv) + ["--secrets-file", str(project.secrets)], mobile_app=project.mobile)

    def test_end_to_end_release_aab(self) -> None:
        project = Project(self)
        project.set_artifact("build/app/outputs/bundle/prodRelease/app-prod-release.aab", project.good_aab)
        before = dict(os.environ)
        code, out = self.run_main(project, "--build-type", "release", "--output", "aab",
                                  "--signing-config-path", str(project.signing))
        self.assertEqual(code, 0, out)
        calls = project.calls_list()
        self.assertEqual([c["argv"][0] for c in calls], ["clean", "build"])
        build = calls[1]
        self.assertEqual(build["argv"][:3], ["build", "appbundle", "--release"])
        self.assertIn(f"-PandroidGmailClientId={CLIENT_ID}", build["argv"])
        # Issue #575: the release bundle gets the filtered defines file, never the secrets file.
        self.assertEqual(build["defines_keys"], ["ANDROID_GMAIL_CLIENT_ID"])
        self.assertIn(f"--dart-define-from-file={build['defines_path']}", build["argv"])
        self.assertFalse(Path(build["defines_path"]).exists())
        self.assertEqual(build["env"], {"ANDROID_KEYSTORE_PATH": str(project.root / "fake.jks"),
                                        "ANDROID_KEYSTORE_PASSWORD": STORE_PASSWORD, "ANDROID_KEY_ALIAS": "upload",
                                        "ANDROID_KEY_PASSWORD": KEY_PASSWORD})
        joined = " ".join(build["argv"])
        for secret in (STORE_PASSWORD, KEY_PASSWORD, CLIENT_SECRET, AOL_PASSWORD):
            self.assertNotIn(secret, joined)
            self.assertNotIn(secret, out)
        self.assertNotIn(CLIENT_ID, out)
        self.assertFalse(any(name in os.environ for name in tool.SIGNING_ENV.values()))
        self.assertEqual(before.get("ANDROID_KEY_PASSWORD"), os.environ.get("ANDROID_KEY_PASSWORD"))
        kept = project.mobile / "dist" / "android-9.9.9+23" / "app-prod-release.aab"
        self.assertTrue(kept.is_file())
        self.assertFalse((project.mobile / "build" / "keep.txt").exists(), "the clean removed the build folder")
        self.assertTrue((project.home / ".myemailspamfilter" / "symbols" / "9.9.9+23-prod").is_dir())

    def test_refusal_deletes_nothing(self) -> None:
        project = Project(self, version="9.9.9+22")  # equal to the uploaded 22
        code, out = self.run_main(project, "--output", "aab", "--signing-config-path", str(project.signing))
        self.assertEqual(code, 1)
        self.assertIn("IMP-2", out)
        self.assertEqual(project.calls_list(), [])
        self.assertTrue((project.mobile / "build" / "keep.txt").exists())
        project2 = Project(self)
        code, out = self.run_main(project2, "--signing-config-path", str(project2.root / "absent.json"))
        self.assertEqual(code, 1)
        self.assertIn("GP-2", out)
        self.assertEqual(project2.calls_list(), [])
        self.assertTrue((project2.mobile / "build" / "keep.txt").exists())

    def test_failed_f204_is_not_kept(self) -> None:
        project = Project(self)
        bad = project.root / "bad.aab"
        verify_bundle(bad, 35)
        project.set_artifact("build/app/outputs/bundle/prodRelease/app-prod-release.aab", bad)
        code, out = self.run_main(project, "--output", "aab", "--signing-config-path", str(project.signing))
        self.assertEqual(code, 1)
        self.assertIn("F204", out)
        self.assertFalse((project.mobile / "dist").exists())

    def test_flutter_failure_exit_code(self) -> None:
        project = Project(self)
        with mock.patch.dict(os.environ, {"FAKE_BUILD_RC": "3"}):
            code, out = self.run_main(project, "--build-type", "debug")
        self.assertEqual(code, 3)
        self.assertIn("Build failed", out)

    def test_debug_apk_end_to_end(self) -> None:
        project = Project(self)
        project.set_artifact("build/app/outputs/flutter-apk/app-prod-debug.apk", project.good_aab)
        code, out = self.run_main(project, "--build-type", "debug")
        self.assertEqual(code, 0, out)
        build = project.calls_list()[-1]
        self.assertEqual(build["argv"][:3], ["build", "apk", "--debug"])
        self.assertEqual(build["env"], {})
        self.assertNotIn("--obfuscate", build["argv"])
        self.assertIn(f"-PandroidGmailClientId={CLIENT_ID}", build["argv"])
        self.assertFalse((project.mobile / "dist").exists())

    def test_missing_artifact_is_error(self) -> None:
        project = Project(self)
        code, out = self.run_main(project, "--build-type", "debug")
        self.assertEqual(code, 1)
        self.assertIn("no artifact", out)


class AvdTests(unittest.TestCase):
    def test_avd_choice(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / "Old_API_29.avd").mkdir()
            (home / "pixel34.avd").mkdir()
            (home / "Old_API_29.avd" / "config.ini").write_text("image.sysdir.1=system-images\\android-29\\x\n")
            (home / "pixel34.avd" / "config.ini").write_text("image.sysdir.1 = system-images\\android-34-ext12\\x\n")
            (home / "IniOnly_33.ini").write_text("target=android-33\n")
            pick = tool.select_preferred_avd
            self.assertEqual(pick(["Old_API_29", "pixel34", "IniOnly_33"], home), "pixel34")
            self.assertEqual(pick(["Old_API_29", "IniOnly_33"], home), "IniOnly_33")
            self.assertEqual(pick(["Unknown_A", "Old_API_29"], home), "Old_API_29")
            self.assertEqual(pick(["Unknown_A", "Unknown_B"], home), "Unknown_A")
            self.assertIsNone(pick([], home))

    def test_self_test_option(self) -> None:
        code, out = quiet(tool.main, ["--self-test"])
        self.assertEqual(code, 0)
        self.assertEqual(out.count("[PASS]"), 4)


class WrapperTests(unittest.TestCase):
    def test_build_apk_wrapper(self) -> None:
        apk = load("build_apk_under_test", "build-apk.py")
        fake_builder = mock.Mock()
        fake_builder.main.return_value = 0
        fake_builder.run_inherit.return_value = 0
        fake_builder.common.find_tool.return_value = "flutter"
        with mock.patch.object(apk, "load_builder", return_value=fake_builder):
            code, _ = quiet(apk.main, [])
        self.assertEqual(code, 0)
        fake_builder.main.assert_called_once_with(["--build-type", "release", "--output", "apk"],
                                                  mobile_app=apk.DEFAULT_PROJECT.resolve())
        fake_builder.run_inherit.assert_not_called()
        fake_builder.main.reset_mock()
        with mock.patch.object(apk, "load_builder", return_value=fake_builder):
            code, _ = quiet(apk.main, ["--verbose-output"])
        self.assertEqual(fake_builder.run_inherit.call_args.args[0], ["flutter", "analyze"])
        self.assertEqual(code, 0)
        fake_builder.main.reset_mock()
        fake_builder.run_inherit.return_value = 1
        with mock.patch.object(apk, "load_builder", return_value=fake_builder):
            code, _ = quiet(apk.main, ["--verbose-output"])
        self.assertEqual(code, 1)
        fake_builder.main.assert_not_called()


if __name__ == "__main__":
    unittest.main()
