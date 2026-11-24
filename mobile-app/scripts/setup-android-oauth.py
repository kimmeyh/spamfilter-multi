"""Interactive Android Gmail OAuth setup walkthrough (F336, Sprint 86; Python port of setup-android-oauth.ps1).

Usage:
  python setup-android-oauth.py                 run the five steps (needs a terminal: it prompts)
  python setup-android-oauth.py --no-build      stop after saving the secret (skip the APK build and install)
  python setup-android-oauth.py --secrets-file PATH   another secrets file (default mobile-app/secrets.dev.json)

Steps: (1) show where to copy the Desktop client secret in Google Cloud Console and ask for it (hidden input),
(2) save it into the secrets file, (3) list the redirect URIs to check, (4) build a debug APK with the secrets and
install it on the EMULATOR (build-with-secrets.py --build-type debug --env dev --install-to-emulator --start-emulator),
(5) print the sign-in options and troubleshooting.

Secrets: no secret value is ever printed (not even a prefix or a length). The secret is read with getpass, written back
atomically (temporary file in the same folder, then replace), as UTF-8 without a byte order mark, and every other key in
the file is kept. The secrets file must be gitignored; the script refuses to write a file git does not ignore.

Defects found in the PowerShell original, and what the port does:
  - It printed the full client secret from the file in step 1, and the first 10 characters plus the length in steps 2 and 5:
    FIXED, nothing secret is printed.
  - A missing secrets file left $secrets null and the script died with a null-reference error at step 2: FIXED, a clear
    message and exit 1 (copy secrets.dev.json.template first).
  - `ConvertTo-Json | Set-Content` rewrote the file with the default depth (nested values past depth 2 are flattened to
    text) and the Windows PowerShell 5 code page: FIXED, json.dump with UTF-8.
  - The build step ran the RELEASE build (the build script default), which needs a signing file this wizard never mentions
    and a prod environment that does not match secrets.dev.json: CHANGED to --build-type debug --env dev, and it adds
    --start-emulator so a missing emulator does not stop it.
  - The Android build no longer reads the Desktop client secret at all (issue #575: only ANDROID_GMAIL_CLIENT_ID reaches an
    APK, because Google documents that an installed app cannot keep a secret). The wizard therefore also reports whether
    ANDROID_GMAIL_CLIENT_ID is set. The secret step is KEPT because the same file feeds the Windows build.
  - The original wrote GMAIL_OAUTH_CLIENT_SECRET, a key NO build reads (the app reads WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET,
    gmail_windows_oauth_handler.dart), so the "kept for the Windows build" claim was false and the wizard reported success
    for a no-op (C1-1, Sprint 86 5.1.2). FIXED: the key names come from android_support.py, and a test checks each against
    String.fromEnvironment in mobile-app/lib. A leftover GMAIL_OAUTH_CLIENT_SECRET in the file is flagged, not deleted.
  - Emoji and box-drawing characters in the output: dropped (repository rule: no emoji).

Exit codes: 0 done; 1 no terminal, a missing or unreadable secrets file, an empty secret, a file git does not ignore, a
failed save, or a missing build script; the build script's own exit code when the build fails; 2 a usage error (argparse).

What this does NOT catch: a secret that is wrong (Google rejects it later with invalid_client), a redirect URI missing in the
console (step 3 only asks you to look), and whether the sign-in works on the emulator (a person does step 5).
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

CLIENT_ID_KEY = sup.WINDOWS_CLIENT_ID_KEY
LEGACY_CLIENT_ID_KEY = sup.LEGACY_CLIENT_ID_KEY
SECRET_KEY = sup.WINDOWS_CLIENT_SECRET_KEY
ANDROID_ID_KEY = sup.ANDROID_CLIENT_ID_KEY
PLACEHOLDER_PREFIXES = ("YOUR-", "REPLACE_")
BUILD_SCRIPT = sup.SCRIPTS / "build-with-secrets.py"
GUIDE = sup.REPO / "docs" / "OAUTH_SETUP.md"


class SetupRefused(Exception):
    """A step cannot continue. main() prints the text as [ERROR] and exits 1."""


def is_set(value: object) -> bool:
    text = "" if value is None else str(value).strip()
    return bool(text) and not text.upper().startswith(PLACEHOLDER_PREFIXES)


def load_secrets(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except OSError as exc:
        raise SetupRefused(f"cannot read {path}: {exc.strerror or exc}. Copy secrets.dev.json.template to "
                           "secrets.dev.json first.") from exc
    except json.JSONDecodeError as exc:
        raise SetupRefused(f"{path} is not valid JSON ({exc.msg}, line {exc.lineno})") from exc
    if not isinstance(data, dict):
        raise SetupRefused(f"{path} must be a JSON object")
    return data


def is_git_ignored(path: Path) -> bool:
    """True ONLY when git exits 0 (the file is ignored). Exit 1 (not ignored), 128 (not a repository, or git cannot tell),
    or a missing git all mean "not proven ignored", so the wizard refuses to write a secret (C6-4, Sprint 86 5.1.2).
    Tests that use a temporary folder patch this function."""
    code, _ = sup.common.git("check-ignore", "-q", str(path), cwd=path.parent)
    return code == 0


def save_secrets(path: Path, data: dict) -> None:
    """Atomic UTF-8 write: a temporary file next to the target, then replace. Raises SetupRefused on failure."""
    handle, name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(name, path)
    except OSError as exc:
        try:
            os.unlink(name)
        except OSError:
            pass
        raise SetupRefused(f"could not save {path}: {exc.strerror or exc}") from exc


def banner(text: str) -> None:
    sup.say("")
    sup.say(f"=== {text} ===")
    sup.say("")


def run_build(build_script: Path) -> int:
    if not build_script.is_file():
        sup.say(f"[FAIL] {build_script} not found")
        return 1
    argv = [sys.executable, "-I", str(build_script), "--build-type", "debug", "--env", "dev",
            "--install-to-emulator", "--start-emulator"]
    try:
        return subprocess.run(argv, stdin=subprocess.DEVNULL).returncode
    except OSError as exc:
        sup.say(f"[FAIL] could not start the build: {exc}")
        return sup.NOT_FOUND


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    parser = argparse.ArgumentParser(description="Interactive Android Gmail OAuth setup walkthrough.")
    parser.add_argument("--secrets-file", default=str(sup.MOBILE_APP / "secrets.dev.json"))
    parser.add_argument("--no-build", action="store_true", help="stop after saving the secret")
    parser.add_argument("--build-script", default=str(BUILD_SCRIPT), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if not sys.stdin.isatty():
        sup.say("[ERROR] This wizard prompts for input and needs a terminal.")
        return 1
    secrets_path = Path(args.secrets_file)
    try:
        banner("STEP 1: Get the client secret")
        secrets = load_secrets(secrets_path)
        sup.say("Current configuration:")
        client_id = secrets.get(CLIENT_ID_KEY) or secrets.get(LEGACY_CLIENT_ID_KEY) or "(not set)"
        sup.say(f"  Desktop client ID: {client_id}")
        if sup.DEAD_SECRET_KEY in secrets:
            sup.say(f"  [WARNING] {sup.DEAD_SECRET_KEY} is in the file but no build reads it; the wizard saves {SECRET_KEY}.")
        sup.say(f"  Desktop client secret: {'set' if is_set(secrets.get(SECRET_KEY)) else 'NOT SET'}")
        sup.say(f"  Android client ID ({ANDROID_ID_KEY}): {'set' if is_set(secrets.get(ANDROID_ID_KEY)) else 'NOT SET'}")
        sup.say("")
        sup.say("To get the client secret:")
        sup.say("  1. Open https://console.cloud.google.com/apis/credentials")
        sup.say("  2. Open your Desktop app client")
        sup.say("  3. Copy the 'Client secret'")
        input("Press Enter after you have opened the Google Cloud Console...")
        secret = getpass.getpass("Paste the client secret (hidden): ").strip()
        if not secret:
            raise SetupRefused("No client secret entered.")

        banner("STEP 2: Update configuration")
        if not is_git_ignored(secrets_path):
            raise SetupRefused(f"{secrets_path} is not ignored by git. Refusing to write a secret into a trackable file.")
        secrets[SECRET_KEY] = secret
        save_secrets(secrets_path, secrets)
        sup.say(f"[OK] Saved {SECRET_KEY} in {secrets_path.name} (the secret is not shown).")

        banner("STEP 3: Verify the OAuth configuration")
        sup.say("Check in Google Cloud Console that the Desktop app has these authorized redirect URIs:")
        sup.say("  - http://localhost:8080/oauth/callback")
        sup.say("  - urn:ietf:wg:oauth:2.0:oob (optional fallback)")
        input("Press Enter to continue...")
    except SetupRefused as exc:
        sup.say(f"[ERROR] {exc}")
        return 1
    except (EOFError, KeyboardInterrupt):
        sup.say("[ERROR] Input ended before the wizard finished. The secrets file was not changed after the last completed step.")
        return 1

    if not args.no_build:
        banner("STEP 4: Build the APK with credentials")
        code = run_build(Path(args.build_script))
        if code != 0:
            sup.say("[FAIL] Build failed. Check the errors above.")
            return code

    banner("STEP 5: Sign in on Android")
    sup.say("Option A - WebView OAuth (recommended): tap 'Sign in with WebView', sign in, grant permissions.")
    sup.say("Option B - Manual token entry: get tokens from https://developers.google.com/oauthplayground/")
    sup.say("  (gear icon, 'Use your own OAuth credentials', your Desktop client ID and secret, scopes gmail.modify and")
    sup.say("  userinfo.email), then paste the access and refresh tokens into the app's Manual Token Entry screen.")
    banner("TROUBLESHOOTING")
    sup.say("invalid_client: check the secret in the console, the authorized redirect URI, and that you use the Desktop client.")
    sup.say("Tokens do not validate: use the OAuth Playground with YOUR credentials and copy BOTH tokens.")
    sup.say(f"More details: {GUIDE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
