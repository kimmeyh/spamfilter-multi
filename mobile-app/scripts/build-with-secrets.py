"""Build the Android APK or Play bundle with OAuth secrets and release signing (F335, Sprint 85).

Python port of build-with-secrets.ps1 (ADR-0051). Standard library only. Runs on Windows, Linux and macOS.

What it does, in order (every refusal happens BEFORE anything is deleted):
  1. Refuses flag combinations that cannot work (--run with release, --output aab with an install or with debug).
  2. Reads the secrets file (default mobile-app/secrets.dev.json) and checks the providers. Only NAMES are printed,
     never a value.
  3. Release only: reads the signing JSON that lives OUTSIDE the repository (GP-2, ADR-0027) and the versionCode check
     (IMP-2: the build number must be above "Last uploaded to Play" in docs/STORE_VERSION_STATUS.md).
  4. Stops gradle, runs flutter clean, removes the build folders.
  5. flutter build with --flavor, APP_ENV, the secrets file and the gradle property androidGmailClientId (SEC-9;
     the gradle release gate in android/app/build.gradle.kts throws when it is missing).
  6. Aab only: the F204 check (verify-aab-play-requirements.py), then a copy to dist/android-<version>/ (IMP-1).
  7. Optional: install on an emulator and start the app (--install-to-emulator), or flutter run (--run).

Secrets: signing values cross to flutter through the CHILD process environment only (cmd.exe eats & and ? in a
command line, and secrets stay off process listings). The signing values are never set in this process environment.

Options (kebab-case of the PowerShell parameters of the same name):
  --build-type {debug,release}   default release            (-BuildType)
  --env {dev,prod}               default prod               (-Env)
  --signing-config-path PATH     default ~/.myemailspamfilter/android-signing.json   (-SigningConfigPath)
  --output {apk,aab}             default apk                (-Output)
  --install-to-emulator          (-InstallToEmulator)
  --run                          flutter run with hot reload (-Run)
  --skip-uninstall               (-SkipUninstall)
  --start-emulator               (-StartEmulator)
  --emulator-name NAME           (-EmulatorName)
  --self-test                    AVD choice self-test, builds nothing (-SelfTest)
  --secrets-file PATH            NEW; default mobile-app/secrets.dev.json

Exit codes: 0 success; 1 a refusal or a failed step; flutter's own exit code when flutter fails; 2 a usage error
(argparse; the PowerShell script raised a terminating error, exit 1).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MOBILE_APP = SCRIPTS.parent
REPO = MOBILE_APP.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402  (find_tool, configure_stdio: the shared ADR-0051 layer)

SIGNING_KEYS = ("keystorePath", "keystorePassword", "keyAlias", "keyPassword")
SIGNING_ENV = {
    "keystorePath": "ANDROID_KEYSTORE_PATH",
    "keystorePassword": "ANDROID_KEYSTORE_PASSWORD",
    "keyAlias": "ANDROID_KEY_ALIAS",
    "keyPassword": "ANDROID_KEY_PASSWORD",
}
CLIENT_ID_PROPERTY = "androidGmailClientId"
SAFE_PROPERTY_VALUE = re.compile(r"^[A-Za-z0-9._-]+$")
PUBSPEC_VERSION = re.compile(r"^version:\s*(\S+)", re.M)
PUBSPEC_CODE = re.compile(r"^version:\s*\S+\+(\d+)", re.M)
LAST_UPLOADED = re.compile(r"^\|\s*\*\*Last uploaded to Play[^|]*\*\*[^|]*\|[^|]*versionCode\s+(\d+)", re.M)
STATUS_FILE = "docs/STORE_VERSION_STATUS.md"
PACKAGE = {"dev": "com.myemailspamfilter.dev", "prod": "com.myemailspamfilter"}
MAIN_ACTIVITY = "com.myemailspamfilter.MainActivity"


class BuildRefused(Exception):
    """A pre-flight or build step refused. main() prints the text as [ERROR] and exits 1."""


def say(text: str = "") -> None:
    print(text, flush=True)


def sleep(seconds: float) -> None:
    """Indirection so tests can run the wait loops without waiting."""
    time.sleep(seconds)


# ---- secrets ---------------------------------------------------------------------------------------------------

def is_placeholder(value: object) -> bool:
    """True for an empty value or the template placeholders (YOUR-..., REPLACE_..., your-...)."""
    text = "" if value is None else str(value)
    stripped = text.strip()
    return not stripped or stripped.upper().startswith("YOUR-") or stripped.upper().startswith("REPLACE_")


def load_json_file(path: Path, what: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except OSError as exc:
        raise BuildRefused(f"cannot read {what} at {path}: {exc.strerror or exc}") from exc
    except json.JSONDecodeError as exc:
        raise BuildRefused(f"{what} at {path} is not valid JSON ({exc.msg}, line {exc.lineno})") from exc
    if not isinstance(data, dict):
        raise BuildRefused(f"{what} at {path} must be a JSON object")
    return data


def first_set(secrets: dict, *names: str) -> str | None:
    """The value of the first key that is set (truthy), like the PowerShell if/elseif chain."""
    for name in names:
        value = secrets.get(name)
        if value:
            return str(value)
    return None


def validate_providers(secrets: dict) -> tuple[bool, bool]:
    """(gmail_configured, aol_configured). Prints key NAMES and status only, never a value.

    A provider counts as configured when every field is set. A provider with SOME fields set is reported
    incomplete and skipped. Same rules as the PowerShell Validate-OAuthProvider / Validate-IMAPProvider.
    """
    gmail_id = first_set(secrets, "ANDROID_GMAIL_CLIENT_ID", "WINDOWS_GMAIL_DESKTOP_CLIENT_ID", "GMAIL_DESKTOP_CLIENT_ID")
    gmail_secret = first_set(secrets, "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET", "GMAIL_OAUTH_CLIENT_SECRET")
    gmail_uri = first_set(secrets, "ANDROID_REDIRECT_URI", "GMAIL_REDIRECT_URI")
    has_id = not is_placeholder(gmail_id)
    has_secret = not is_placeholder(gmail_secret)
    has_uri = bool(gmail_uri and gmail_uri.strip())
    gmail_ok = has_id and has_secret and has_uri
    if gmail_ok:
        say("   [OK] Gmail - configured (OAuth)")
    elif has_id or has_secret or has_uri:
        say("   [WARNING] Gmail - INCOMPLETE (skipping)")
        if not has_id:
            say("      [ERROR] Missing/placeholder CLIENT_ID")
        if not has_secret:
            say("      [ERROR] Missing/placeholder CLIENT_SECRET")
        if not has_uri:
            say("      [ERROR] Missing REDIRECT_URI")
    else:
        say("   [WARNING] Gmail - not configured (optional)")

    email = secrets.get("AOL_EMAIL")
    password = secrets.get("AOL_APP_PASSWORD")
    has_email = not (is_placeholder(email) or str(email).lower().startswith("your-"))
    has_password = not (is_placeholder(password) or str(password).lower().startswith("your-"))
    aol_ok = has_email and has_password
    if aol_ok:
        say("   [OK] AOL - configured (IMAP)")
    elif has_email or has_password:
        say("   [WARNING] AOL - INCOMPLETE (skipping)")
        if not has_email:
            say("      [ERROR] Missing/placeholder EMAIL")
        if not has_password:
            say("      [ERROR] Missing/placeholder APP_PASSWORD")
    else:
        say("   [WARNING] AOL - not configured (optional)")
    return gmail_ok, aol_ok


# ---- build arguments -------------------------------------------------------------------------------------------

def gradle_project_args(secrets: dict, build_type: str) -> list[str]:
    """SEC-9: the -P arguments that give build.gradle.kts the Android OAuth client id.

    The value must be safe on a command line that passes through a .bat shim (flutter.bat), so only
    [A-Za-z0-9._-] is accepted. A placeholder id is refused for release (it would ship a wrong redirect scheme)
    and warned about for debug. A missing id adds nothing: gradle's own gate then throws (release) or warns
    (debug); this function does not duplicate that check.
    """
    value = secrets.get("ANDROID_GMAIL_CLIENT_ID")
    if not value:
        say("[WARNING] ANDROID_GMAIL_CLIENT_ID not set in the secrets file -- gradle will warn (debug) or fail (release).")
        return []
    value = str(value)
    if is_placeholder(value):
        if build_type == "release":
            raise BuildRefused("SEC-9: ANDROID_GMAIL_CLIENT_ID is a placeholder value; a release build would ship a "
                               "wrong OAuth redirect scheme. Set the real id in the secrets file.")
        say("[WARNING] ANDROID_GMAIL_CLIENT_ID is a placeholder value -- Gmail sign-in will not work in this build.")
    if not SAFE_PROPERTY_VALUE.match(value):
        raise BuildRefused("SEC-9: ANDROID_GMAIL_CLIENT_ID contains characters outside A-Z a-z 0-9 . _ - ; it cannot "
                           "be passed safely on the flutter command line.")
    return [f"-P{CLIENT_ID_PROPERTY}={value}"]


def display_arg(arg: str) -> str:
    """An argument for the log: a -P property shows its NAME only, never its value."""
    if arg.startswith("-P") and "=" in arg:
        return arg.split("=", 1)[0] + "=<set>"
    return arg


def flavor_args(env: str) -> list[str]:
    """F94: --flavor and --dart-define=APP_ENV in lockstep."""
    return ["--flavor", env, f"--dart-define=APP_ENV={env}"]


def build_target(output: str) -> str:
    return "appbundle" if output == "aab" else "apk"


def artifact_path(env: str, build_type: str, output: str) -> str:
    """Relative to mobile-app. Flavored builds always emit app-<flavor>-<buildtype>."""
    if output == "aab":
        return f"build/app/outputs/bundle/{env}Release/app-{env}-release.aab"
    return f"build/app/outputs/flutter-apk/app-{env}-{build_type}.apk"


def obfuscate_args(symbols_dir: Path) -> list[str]:
    """GP-9: Dart obfuscation, release only. Symbols stay outside the repository."""
    return ["--obfuscate", f"--split-debug-info={symbols_dir}"]


def flutter_build_args(*, build_type: str, env: str, output: str, secrets_arg: str, gradle_args: list[str],
                       symbols_dir: Path | None) -> list[str]:
    """The full argument list after `flutter`. Order matches the PowerShell script."""
    args = ["build", build_target(output), f"--{build_type}", *flavor_args(env),
            f"--dart-define-from-file={secrets_arg}", *gradle_args]
    if build_type == "release":
        if symbols_dir is None:
            raise BuildRefused("GP-9: a release build needs a symbols folder")
        args += obfuscate_args(symbols_dir)
    return args


def flutter_run_args(*, build_type: str, env: str, secrets_arg: str, gradle_args: list[str], device: str) -> list[str]:
    return ["run", f"--{build_type}", *flavor_args(env), f"--dart-define-from-file={secrets_arg}",
            *gradle_args, "-d", device]


# ---- signing and version checks --------------------------------------------------------------------------------

def default_signing_path() -> Path:
    return Path.home() / ".myemailspamfilter" / "android-signing.json"


def load_signing(path: Path) -> dict[str, str]:
    """GP-2: the four signing values as ANDROID_* environment variables for the CHILD process only."""
    if not path.exists():
        raise BuildRefused(f"GP-2: release signing config not found at {path}. Create it (JSON keys: "
                           "keystorePath, keystorePassword, keyAlias, keyPassword) pointing at the upload keystore "
                           "(docs/adr/0027).")
    data = load_json_file(path, "signing config")
    for key in SIGNING_KEYS:
        if not data.get(key):
            raise BuildRefused(f"GP-2: signing config {path} is missing key '{key}'.")
    if not Path(str(data["keystorePath"])).exists():
        raise BuildRefused(f"GP-2: keystore not found at {data['keystorePath']}.")
    return {SIGNING_ENV[key]: str(data[key]) for key in SIGNING_KEYS}


def read_pubspec(mobile_app: Path) -> tuple[str | None, int | None]:
    """(full version text such as 0.25.0+23, build number)."""
    try:
        text = (mobile_app / "pubspec.yaml").read_text(encoding="utf-8")
    except OSError:
        return None, None
    version = PUBSPEC_VERSION.search(text)
    code = PUBSPEC_CODE.search(text)
    return (version.group(1) if version else None), (int(code.group(1)) if code else None)


def read_last_uploaded(status_file: Path) -> int | None:
    """The versionCode in the "Last uploaded to Play (any track)" row, or None when it cannot be read."""
    try:
        text = status_file.read_text(encoding="utf-8")
    except OSError:
        return None
    match = LAST_UPLOADED.search(text)
    return int(match.group(1)) if match else None


def check_version_code(mobile_app: Path) -> None:
    """IMP-2 (Sprint 76): refuse a bundle whose versionCode Play already has on any track."""
    status_file = mobile_app.parent / STATUS_FILE
    _, build_code = read_pubspec(mobile_app)
    last = read_last_uploaded(status_file)
    if build_code is None or last is None:
        raise BuildRefused(f"IMP-2: cannot read the pubspec build number or the 'Last uploaded to Play (any track)' "
                           f"row in {status_file}.")
    if build_code <= last:
        raise BuildRefused(f"IMP-2: versionCode {build_code} is not above {last}, which Play has already received. "
                           f"Bump pubspec.yaml (version and msix_version) to +{last + 1} first.")
    say(f"[INFO] IMP-2: versionCode {build_code} is above the last uploaded ({last}).")


# ---- AVD choice (Sprint 80 retro IMP-2) ------------------------------------------------------------------------

def avd_home() -> Path:
    if os.environ.get("ANDROID_AVD_HOME"):
        return Path(os.environ["ANDROID_AVD_HOME"])
    if os.environ.get("ANDROID_EMULATOR_HOME"):
        return Path(os.environ["ANDROID_EMULATOR_HOME"]) / "avd"
    return Path.home() / ".android" / "avd"


def avd_api_level(name: str, home: Path) -> int:
    """API level from <name>.avd/config.ini (image.sysdir.1) or <name>.ini (target); -1 when unreadable."""
    sources = [(home / f"{name}.avd" / "config.ini", r"image\.sysdir\.1"), (home / f"{name}.ini", "target")]
    for file, key in sources:
        if not file.is_file():
            continue
        pattern = re.compile(rf"^\s*{key}\s*=\s*.*android-(\d+)")
        for line in file.read_text(encoding="utf-8", errors="replace").splitlines():
            match = pattern.match(line)
            if match:
                return int(match.group(1))
    return -1


def select_preferred_avd(names: list[str], home: Path) -> str | None:
    """Highest API level wins; an unreadable level ranks below every readable one; ties keep list order."""
    best: str | None = None
    best_level = -2
    for name in names:
        level = avd_api_level(name, home)
        if level > best_level:
            best, best_level = name, level
    return best


def run_self_test() -> int:
    """The AVD-choice cases of the PowerShell -SelfTest, on temporary files. 0 pass, 1 fail."""
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        (home / "Old_API_29.avd").mkdir()
        (home / "pixel34.avd").mkdir()
        (home / "Old_API_29.avd" / "config.ini").write_text("image.sysdir.1=system-images\\android-29\\google_apis\\x86\\\n")
        (home / "pixel34.avd" / "config.ini").write_text(
            "image.sysdir.1 = system-images\\android-34-ext12\\google_apis_playstore\\x86_64\\\n")
        (home / "IniOnly_33.ini").write_text("target=android-33\n")
        cases = [
            (["Old_API_29", "pixel34", "IniOnly_33"], "pixel34", "highest level wins over list order"),
            (["Old_API_29", "IniOnly_33"], "IniOnly_33", "<name>.ini target is the fallback"),
            (["Unknown_A", "Old_API_29"], "Old_API_29", "an unreadable level ranks below a readable one"),
            (["Unknown_A", "Unknown_B"], "Unknown_A", "no readable level keeps the list order"),
        ]
        for names, want, why in cases:
            got = select_preferred_avd(names, home)
            if got == want:
                say(f"[PASS] {why}: {got}")
            else:
                say(f"[FAIL] {why}: got '{got}', want '{want}'")
                failures += 1
    return 1 if failures else 0


# ---- process helpers -------------------------------------------------------------------------------------------

def sdk_tool(relative: str, *names: str) -> str | None:
    """A tool through ANDROID_HOME first (this machine has a second, older SDK on PATH), then the PATH."""
    home = os.environ.get("ANDROID_HOME")
    if home:
        for suffix in ("", ".exe", ".bat"):
            candidate = Path(home) / (relative + suffix)
            if candidate.is_file():
                return str(candidate)
    return common.find_tool(*names)


def run_capture(argv: list[str], cwd: Path | None = None, timeout: float | None = None) -> tuple[int, str]:
    """Run to completion, stdout and stderr merged. Never raises for a failing or missing command."""
    try:
        done = subprocess.run(argv, cwd=str(cwd) if cwd else None, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, f"could not run {argv[0]}: {exc}\n"
    return done.returncode, done.stdout.decode("utf-8", errors="replace")


def run_inherit(argv: list[str], cwd: Path, env: dict[str, str] | None = None) -> int:
    """Run with the console attached (the build output streams); return the exit code."""
    try:
        return subprocess.run(argv, cwd=str(cwd), env=env, stdin=subprocess.DEVNULL).returncode
    except OSError as exc:
        say(f"[ERROR] could not start {argv[0]}: {exc}")
        return 127


def detached_kwargs() -> dict:
    """Popen options that give a background process none of our handles (Sprint 81 Task 11 IMP-2b)."""
    kwargs: dict = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        kwargs["creationflags"] = 0x00000008 | 0x08000000  # DETACHED_PROCESS | CREATE_NO_WINDOW
    else:
        kwargs["start_new_session"] = True
    return kwargs


class Adb:
    """adb through ANDROID_HOME, with -s <serial> once a device is chosen."""

    def __init__(self, exe: str):
        self.exe = exe
        self.serial: str | None = None

    def argv(self, *args: str) -> list[str]:
        return [self.exe, *(["-s", self.serial] if self.serial else []), *args]

    def run(self, *args: str, timeout: float | None = 120) -> tuple[int, str]:
        return run_capture(self.argv(*args), timeout=timeout)

    def start_server(self) -> None:
        """Start the server with none of our handles; a server started inline would hold a redirected log open."""
        try:
            subprocess.Popen([self.exe, "start-server"], **detached_kwargs()).wait(timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            pass

    def kill_server(self) -> None:
        run_capture([self.exe, "kill-server"], timeout=30)

    def online_emulator(self) -> str | None:
        """First emulator in state 'device' (offline and unauthorized ones are skipped)."""
        _, out = run_capture([self.exe, "devices"], timeout=30)
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0].startswith("emulator-") and parts[1] == "device":
                return parts[0]
        return None


def ensure_adb_running(adb: Adb) -> bool:
    """Up to five tries to get 'List of devices attached'. The success text is checked first: a cold start prints
    "daemon not running; starting now" AND the list in the same output (Sprint 66)."""
    for attempt in range(1, 6):
        say(f"[ADB] Checking daemon status (attempt {attempt}/5)...")
        adb.kill_server()
        if os.name == "nt":
            run_capture(["taskkill", "/F", "/IM", "adb.exe"], timeout=30)
        sleep(2)
        adb.start_server()
        _, out = run_capture([adb.exe, "devices"], timeout=30)
        if "List of devices attached" in out:
            return True
        sleep(2)
    return False


def list_avds(emulator_exe: str) -> list[str]:
    """stdout only, and only lines shaped like an AVD name (PR #490 7.7.1: a warning line is not an AVD)."""
    try:
        done = subprocess.run([emulator_exe, "-list-avds"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        say("[WARNING] Could not list AVDs. Check ANDROID_HOME.")
        return []
    names = [line.strip() for line in done.stdout.decode("utf-8", errors="replace").splitlines()]
    return [name for name in names if re.match(r"^[A-Za-z0-9._-]+$", name)]


def launch_emulator(emulator_exe: str, name: str) -> None:
    kwargs = detached_kwargs()
    if os.name == "nt":
        info = subprocess.STARTUPINFO()
        info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        info.wShowWindow = 6  # SW_MINIMIZE
        kwargs["startupinfo"] = info
    subprocess.Popen([emulator_exe, "-avd", name], **kwargs)


def choose_avd(emulator_exe: str, requested: str) -> str | None:
    available = list_avds(emulator_exe)
    if requested:
        if requested in available:
            return requested
        say(f"[WARNING] Emulator '{requested}' not found. Available AVDs:")
        for name in available:
            say(f"  - {name}")
        if available:
            chosen = select_preferred_avd(available, avd_home())
            say(f"[INFO] Using the highest-API AVD instead: {chosen}")
            return chosen
        return None
    if available:
        home = avd_home()
        chosen = select_preferred_avd(available, home)
        say(f"[INFO] Auto-selected AVD: {chosen} (API {avd_api_level(chosen, home)}, highest of {len(available)})")
        return chosen
    return None


def wait_for_emulator(adb: Adb, seconds: int = 120) -> str | None:
    for tick in range(seconds // 2):
        sleep(2)
        serial = adb.online_emulator()
        if serial:
            say(f"  [OK] Emulator detected: {serial}")
            return serial
        if tick % 5 == 0:
            say(f"  Still waiting... ({tick * 2}s elapsed)")
    return None


# ---- build steps -----------------------------------------------------------------------------------------------

def gradle_stop(mobile_app: Path) -> None:
    say("[INFO] Stopping background build processes (Gradle)")
    wrapper = mobile_app / "android" / ("gradlew.bat" if os.name == "nt" else "gradlew")
    if wrapper.exists():
        run_capture([str(wrapper), "--stop"], cwd=mobile_app / "android", timeout=120)


def remove_dir_with_retry(path: Path, retries: int = 5) -> None:
    if not path.exists():
        return
    for attempt in range(1, retries + 1):
        try:
            shutil.rmtree(path)
            return
        except OSError:
            if attempt < retries:
                sleep(0.3 * attempt)
    say(f"[WARNING] Could not remove all files in '{path}' - some files may be locked. Build will continue.")
    shutil.rmtree(path, ignore_errors=True)


def clean(mobile_app: Path, flutter: str) -> None:
    say("[INFO] Running flutter clean...")
    code, _ = run_capture([flutter, "clean"], cwd=mobile_app)
    if code != 0:
        say("[WARNING] flutter clean reported a problem; performing manual cleanup")
    say("[INFO] Removing build artifacts manually (safe)")
    for rel in ("build", ".dart_tool", "android/app/build", "android/.gradle", ".gradle"):
        remove_dir_with_retry(mobile_app / rel)


def install_dev_stub(mobile_app: Path) -> None:
    """F94: the dev flavor needs a google-services file; the committed stub stands in until the console work lands."""
    target = mobile_app / "android" / "app" / "src" / "dev" / "google-services.json"
    stub = mobile_app / "android" / "ci" / "google-services.dev-stub.json"
    if not target.exists() and stub.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(stub, target)
        say("[INFO] F94: dev-flavor google-services STUB installed (sign-in on dev flavor pending console registrations)")


def keep_bundle(mobile_app: Path, artifact: Path) -> Path:
    """IMP-1 (Sprint 76): copy the bundle where flutter clean cannot reach it: mobile-app/dist/android-<version>/."""
    version, _ = read_pubspec(mobile_app)
    keep_dir = mobile_app / "dist" / f"android-{version or 'unknown-version'}"
    keep_dir.mkdir(parents=True, exist_ok=True)
    kept = keep_dir / artifact.name
    shutil.copy2(artifact, kept)
    return kept


def verify_bundle(artifact: Path) -> bool:
    """F204: read the BUILT bundle's manifest (targetSdkVersion >= 36, no AD_ID). Runs the check script."""
    code = run_inherit([sys.executable, str(SCRIPTS / "verify-aab-play-requirements.py"), "--aab-path", str(artifact)],
                       cwd=SCRIPTS)
    return code == 0


def preflight(args: argparse.Namespace) -> None:
    """Refuse combinations that cannot work BEFORE any long step runs or anything is deleted."""
    if args.run and args.build_type == "release":
        raise BuildRefused("--run does not support --build-type release: it bypasses signing, client-id, and "
                           "obfuscation injection. Use: --build-type release --install-to-emulator")
    if args.output == "aab" and args.install_to_emulator:
        raise BuildRefused("--output aab cannot be installed with --install-to-emulator (adb cannot install a "
                           "bundle). Build an APK for on-device testing, or use bundletool to install the AAB.")
    if args.output == "aab" and args.build_type != "release":
        raise BuildRefused("GP-2: --output aab requires --build-type release.")


# ---- install and run -------------------------------------------------------------------------------------------

def find_adb_and_emulator() -> tuple[str, str]:
    adb_exe = sdk_tool("platform-tools/adb", "adb")
    emulator_exe = sdk_tool("emulator/emulator", "emulator")
    if not adb_exe:
        raise BuildRefused("adb not found. Set ANDROID_HOME to the Android SDK folder.")
    return adb_exe, emulator_exe or "emulator"


def get_emulator(adb: Adb, emulator_exe: str, start: bool, name: str) -> str:
    serial = adb.online_emulator()
    if serial:
        say(f"[Step 2/6] Using running emulator: {serial}")
        return serial
    if not start:
        raise BuildRefused("No emulator running. Start one manually or use --start-emulator.\n"
                           "  1. Start emulator manually (Android Studio, Device Manager, Run)\n"
                           "  2. Use --start-emulator to auto-start\n"
                           "  3. Use --start-emulator --emulator-name YOUR_AVD to specify which one")
    say("[Step 2/6] No emulator running, auto-starting emulator...")
    avd = choose_avd(emulator_exe, name)
    if not avd:
        raise BuildRefused("No AVDs found. Create one with Android Studio (Tools, Device Manager, Create Device).")
    say(f"[INFO] Launching emulator '{avd}'...")
    launch_emulator(emulator_exe, avd)
    say("[INFO] Waiting for emulator to start (this may take 30-60 seconds)...")
    serial = wait_for_emulator(adb)
    if not serial:
        raise BuildRefused("Emulator still not detected after auto-start attempt.")
    return serial


def install_and_launch(artifact: Path, args: argparse.Namespace) -> None:
    say()
    say("[APK Install] Starting emulator detection and installation...")
    adb_exe, emulator_exe = find_adb_and_emulator()
    adb = Adb(adb_exe)
    if not ensure_adb_running(adb):
        raise BuildRefused("Unable to start the ADB daemon after 5 attempts.")
    adb.serial = get_emulator(adb, emulator_exe, args.start_emulator, args.emulator_name)

    say("[Step 3/6] Waiting for emulator to finish booting...")
    for _ in range(20):
        _, out = adb.run("shell", "getprop", "sys.boot_completed", timeout=30)
        if out.strip() == "1":
            break
        sleep(4)
    else:
        raise BuildRefused("Emulator did not finish booting in time.")

    package = PACKAGE[args.env]
    if args.skip_uninstall:
        say("[Step 4/6] Skipping uninstall (--skip-uninstall - preserving saved accounts)...")
    elif args.build_type == "release":
        say("[Step 4/6] Uninstalling previous APKs (release build - clean install)...")
        for name in (package, "com.example.spamfiltermobile", "com.example.spamfilter_mobile"):
            adb.run("uninstall", name, timeout=60)
    else:
        say("[Step 4/6] Skipping uninstall (debug build - preserving saved accounts)...")

    # Sprint 60: an `install -r` upgrade briefly needs room for two copies of the APK. Trim caches when free
    # space is under 2x the APK size + 200 MB. `df -k` because the Android 14 toybox df has no -m (Sprint 75).
    needed_mb = 2 * -(-artifact.stat().st_size // (1024 * 1024)) + 200
    _, df_out = adb.run("shell", "df", "-k", "/data", timeout=30)
    last = df_out.strip().splitlines()[-1] if df_out.strip() else ""
    match = re.search(r"\s(\d+)\s+\d+%", last)
    if match and int(match.group(1)) // 1024 < needed_mb:
        say(f"[Step 5/6] Low emulator storage ({int(match.group(1)) // 1024}MB free, want {needed_mb}MB) -- trimming caches...")
        adb.run("shell", "pm", "trim-caches", "2000M", timeout=60)
    say("[Step 5/6] Installing APK to emulator...")
    for attempt in range(1, 4):
        code, out = adb.run("install", "-r", str(artifact), timeout=300)
        if code == 0 and "Success" in out:
            break
        say(f"[WARNING] APK install failed (attempt {attempt}/3): {out.strip().splitlines()[-1] if out.strip() else 'no output'}")
        adb.kill_server()
        sleep(2)
        adb.start_server()
        sleep(4)
    else:
        raise BuildRefused("APK install failed after 3 attempts.")
    say("[SUCCESS] APK installed to emulator!")

    say()
    say("[Step 6/6] Launching app on emulator...")
    # applicationIdSuffix changes the PACKAGE, not the activity class namespace.
    code, out = adb.run("shell", "am", "start", "-n", f"{package}/{MAIN_ACTIVITY}", timeout=60)
    if code == 0 and "Error" not in out:
        say(f"  [OK] App launched successfully ({package})")
    else:
        say("  [WARNING] App launch command may not have succeeded")
        say(f"  Launch manually with: adb shell am start -n {package}/{MAIN_ACTIVITY}")


def run_app(mobile_app: Path, flutter: str, args: argparse.Namespace, secrets_arg: str, gradle_args: list[str]) -> int:
    say("[INFO] Running app with debugger attached (hot reload enabled)...")
    say("   Press 'r' for hot reload, 'R' for hot restart, 'q' to quit")
    adb_exe, emulator_exe = find_adb_and_emulator()
    adb = Adb(adb_exe)
    serial = adb.online_emulator()
    if not serial:
        say("[WARNING] No emulator detected. Launching one...")
        avd = choose_avd(emulator_exe, args.emulator_name)
        if not avd:
            raise BuildRefused("No emulator available. Start one manually or use --install-to-emulator instead.")
        launch_emulator(emulator_exe, avd)
        serial = wait_for_emulator(adb)
    if not serial:
        raise BuildRefused("No emulator available. Start one manually or use --install-to-emulator instead.")
    say(f"[INFO] Running on device: {serial}")
    code = run_inherit([flutter, *flutter_run_args(build_type=args.build_type, env=args.env, secrets_arg=secrets_arg,
                                                   gradle_args=gradle_args, device=serial)], cwd=mobile_app)
    say()
    say("[INFO] Done!" if code == 0 else f"[ERROR] flutter run exited with {code}")
    return code


# ---- main ------------------------------------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="build-with-secrets.py",
                                     description="Build the Android APK or Play bundle with OAuth secrets.")
    parser.add_argument("--build-type", choices=("debug", "release"), default="release")
    parser.add_argument("--env", choices=("dev", "prod"), default="prod")
    parser.add_argument("--signing-config-path", type=Path, default=None)
    parser.add_argument("--output", choices=("apk", "aab"), default="apk")
    parser.add_argument("--install-to-emulator", action="store_true")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--skip-uninstall", action="store_true")
    parser.add_argument("--start-emulator", action="store_true")
    parser.add_argument("--emulator-name", default="")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--secrets-file", type=Path, default=None)
    return parser


def execute(args: argparse.Namespace, mobile_app: Path) -> int:
    preflight(args)
    secrets_file = args.secrets_file or (mobile_app / "secrets.dev.json")
    if not secrets_file.exists():
        raise BuildRefused(f"{secrets_file.name} not found at {secrets_file}. Copy secrets.dev.json.template to "
                           "secrets.dev.json, fill in your OAuth credentials, and run this script again.")
    say("[INFO] Building Flutter APK with OAuth secrets...")
    say(f"[INFO] Loading secrets from: {secrets_file}")
    secrets = load_json_file(secrets_file, "secrets file")
    say("[INFO] Validating credentials for all providers...")
    gmail_ok, aol_ok = validate_providers(secrets)
    say()
    if not (gmail_ok or aol_ok):
        raise BuildRefused("At least one provider must be configured. Edit the secrets file and configure at least "
                           "Gmail or AOL with real credentials.")
    say("[INFO] Build will include " + " ".join(n for n, ok in (("Gmail", gmail_ok), ("AOL", aol_ok)) if ok) + " provider(s)")

    flutter = common.find_tool("flutter")
    if not flutter:
        raise BuildRefused("flutter not found on PATH.")
    install_dev_stub(mobile_app)
    try:
        secrets_arg = str(secrets_file.relative_to(mobile_app))
    except ValueError:
        secrets_arg = str(secrets_file)
    gradle_args = gradle_project_args(secrets, args.build_type)

    if args.run:
        return run_app(mobile_app, flutter, args, secrets_arg, gradle_args)

    child_env = dict(os.environ)
    symbols_dir: Path | None = None
    if args.build_type == "release":
        signing = load_signing(args.signing_config_path or default_signing_path())
        child_env.update(signing)
        say("[INFO] GP-2: release signing injected via the child environment (names: " + ", ".join(sorted(signing)) + ")")
    if args.output == "aab":
        check_version_code(mobile_app)
    if args.build_type == "release":
        version, _ = read_pubspec(mobile_app)
        symbols_dir = Path.home() / ".myemailspamfilter" / "symbols" / f"{version or 'unknown-version'}-{args.env}"
        say(f"[INFO] GP-9: Dart obfuscation enabled; symbols will be written to {symbols_dir}")

    # Everything above can refuse. Nothing has been deleted yet.
    gradle_stop(mobile_app)
    clean(mobile_app, flutter)

    if symbols_dir is not None:
        symbols_dir.mkdir(parents=True, exist_ok=True)
    say(f"[INFO] Building {args.output} ({args.build_type}), flavor '{args.env}' with APP_ENV={args.env}")
    argv = [flutter, *flutter_build_args(build_type=args.build_type, env=args.env, output=args.output,
                                         secrets_arg=secrets_arg, gradle_args=gradle_args, symbols_dir=symbols_dir)]
    say("[INFO] Command: flutter " + " ".join(display_arg(a) for a in argv[1:]))
    code = run_inherit(argv, cwd=mobile_app, env=child_env)
    if code != 0:
        say("[ERROR] Build failed!")
        return code
    say()
    say("[INFO] Build successful!")
    if symbols_dir is not None:
        say(f"[INFO] GP-9: Dart obfuscation symbols written to {symbols_dir}")

    artifact = mobile_app / artifact_path(args.env, args.build_type, args.output)
    say(f"[INFO] Artifact location: {artifact_path(args.env, args.build_type, args.output)}")
    if not artifact.exists():
        raise BuildRefused(f"flutter reported success but there is no artifact at {artifact}. Check the build output above.")

    if args.output == "aab":
        if not verify_bundle(artifact):
            raise BuildRefused("F204: the built bundle does not meet Google Play requirements (targetSdkVersion >= 36, "
                               "no AD_ID). Do NOT upload it. It was not copied to dist/.")
        kept = keep_bundle(mobile_app, artifact)
        say(f"[INFO] IMP-1: bundle kept at {kept}")
    say()

    if args.install_to_emulator:
        install_and_launch(artifact, args)
    else:
        say(f"[INFO] Built but not installed (use --install-to-emulator to install):\n  adb install -r {artifact_path(args.env, args.build_type, args.output)}")
    say()
    say("[INFO] Done!")
    return 0


def main(argv: list[str] | None = None, mobile_app: Path | None = None) -> int:
    common.configure_stdio()
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()
    try:
        return execute(args, mobile_app or MOBILE_APP)
    except BuildRefused as exc:
        say(f"[ERROR] {exc}")
        return 1
    except Exception as exc:  # last net: the PowerShell script printed [FATAL ERROR] and exited 1
        say(f"[FATAL ERROR] {type(exc).__name__}: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
