"""Look for Windows OAuth credentials and explain how to get tokens into the Android app (F336, Sprint 86; Python port
of export-tokens-for-android.ps1).

Usage:
  python export-tokens-for-android.py --email you@gmail.com
  python export-tokens-for-android.py --email you@gmail.com --secrets-file PATH

What it does: asks Windows Credential Manager (`cmdkey /list:<target>`) whether four credential targets exist for the
address, then prints the two supported ways to get tokens onto Android (OAuth Playground with your own client, or sign in
again on Android) and the state of the OAuth keys in the secrets file (default mobile-app/secrets.dev.json).

It CANNOT export a token: Credential Manager does not hand back a stored secret to a script, and cmdkey only says that a
target exists. The script name is historical. No token or secret value is ever printed. The client ID and the redirect URI
are not secrets and are printed; the client secret is shown only as "set" or "NOT SET" (the original printed its first 10
characters).

Defects found in the PowerShell original, and what the port does:
  - It printed the first 10 characters of the client secret: FIXED, "set" or "NOT SET".
  - It matched cmdkey output with `-match "Target: $target"`, so the dots and plus signs in an address acted as regular
    expression characters: FIXED, a plain substring test (re.escape is not needed).
  - It ignored cmdkey's exit code and wrapped the call in try/catch with an empty handler, so a missing cmdkey looked like
    "no credentials": FIXED, a cmdkey that cannot run, or exits non-zero, is reported and the script exits 1.
  - A missing or unreadable secrets file only printed a warning and the script ended with exit 0: FIXED, exit 1 (a setup
    problem the person must fix before the tokens help).
  - cmdkey exists only on Windows: on another OS the lookup is skipped with a note (exit unchanged).
  - Emoji in the output: dropped (repository rule).

Exit codes: 0 done; 1 cmdkey failed or the secrets file is missing or unreadable; 2 a usage error (argparse; the PowerShell
script prompted for a missing -Email instead).

KNOWN LIMIT (Sprint 86 5.1.2, unverified against a live machine): the app stores tokens through flutter_secure_storage
4.1.0 (pubspec.lock) on Windows, which writes a DPAPI-encrypted file `flutter_secure_storage.dat` in the application
support folder (flutter_secure_storage_windows-4.1.0/lib/src/flutter_secure_storage_windows_ffi.dart lines 234-258 and
388-404), keyed `token_<accountId>_access` (secure_credentials_store.dart). It does not use Credential Manager, so the
cmdkey lookup above most likely never finds a token. The script still prints the two real options and the secrets-file state.

What this does NOT catch: whether a found credential still holds a valid token (cmdkey does not show values), and a credential
stored under a target name the app does not use today (the four names are the ones the original looked for).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

PLACEHOLDER = "REPLACE_WITH_YOUR_CLIENT_SECRET"


def credential_targets(email: str) -> list[str]:
    return [f"spamfilter_oauth_access_{email}", f"spamfilter_oauth_refresh_{email}", f"{email}_access", f"{email}_refresh"]


def query_target(cmdkey: str, target: str) -> tuple[bool | None, str]:
    """(exists, error). exists is None when cmdkey could not answer; error then holds the reason."""
    code, out = sup.run_capture([cmdkey, f"/list:{target}"], timeout=30)
    if code != 0:
        return None, f"cmdkey /list:{target} failed (exit {code}): {out.strip()[:200]}"
    return any("Target:" in line and target in line for line in out.splitlines()), ""


def kind_of(target: str) -> str:
    return "ACCESS" if "access" in target else "REFRESH" if "refresh" in target else "unknown"


def show_secrets(path: Path) -> bool:
    """Print the OAuth key state. False when the file is missing or unreadable."""
    sup.say("Your credentials from the secrets file:")
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(data, dict):
            raise ValueError("the file is not a JSON object")
    except (OSError, ValueError) as exc:
        sup.say(f"  [WARNING] Could not read {path}: {exc}")
        return False
    secret = data.get(sup.WINDOWS_CLIENT_SECRET_KEY)
    client_id = data.get(sup.WINDOWS_CLIENT_ID_KEY) or data.get(sup.LEGACY_CLIENT_ID_KEY) or "(not set)"
    sup.say(f"  Client ID: {client_id}")
    sup.say(f"  Redirect URI: {data.get(sup.REDIRECT_URI_KEY, '(not set)')}")
    if sup.DEAD_SECRET_KEY in data:
        sup.say(f"  [WARNING] {sup.DEAD_SECRET_KEY} is in the file but no build reads it; use {sup.WINDOWS_CLIENT_SECRET_KEY}.")
    is_set = bool(secret) and secret != PLACEHOLDER and not str(secret).upper().startswith("YOUR-")
    sup.say(f"  Client Secret: {'set' if is_set else 'NOT SET - update the secrets file'}")
    return True


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    parser = argparse.ArgumentParser(description="Look for Windows OAuth credentials and explain the Android token options.")
    parser.add_argument("--email", required=True, help="the Gmail address to look up")
    parser.add_argument("--secrets-file", default=str(sup.MOBILE_APP / "secrets.dev.json"))
    args = parser.parse_args(argv)
    failed = False

    sup.say(f"Searching for OAuth credentials for: {args.email}")
    sup.say("")
    if os.name != "nt":
        sup.say("[INFO] Windows Credential Manager exists only on Windows. Skipping the credential lookup.")
    else:
        cmdkey = sup.common.find_tool("cmdkey")
        if not cmdkey:
            sup.say("[ERROR] cmdkey was not found on the PATH, so Credential Manager cannot be checked.")
            failed = True
        else:
            found = 0
            for target in credential_targets(args.email):
                exists, error = query_target(cmdkey, target)
                if exists is None:
                    sup.say(f"[ERROR] {error}")
                    failed = True
                    break
                if exists:
                    found += 1
                    sup.say(f"[OK] Found credential: {target} (this looks like a {kind_of(target)} token)")
            if not failed and found == 0:
                sup.say("[INFO] No matching credential target was found.")

    sup.say("")
    sup.say("[NOTE] Windows Credential Manager stores tokens encrypted and a script cannot read them back. Two options:")
    sup.say("")
    sup.say("Option 1: OAuth Playground (recommended)")
    sup.say("  1. Visit https://developers.google.com/oauthplayground/")
    sup.say("  2. Gear icon, check 'Use your own OAuth credentials'")
    sup.say("  3. Enter your Desktop Client ID and Secret from the secrets file")
    sup.say("  4. Step 1: Gmail API v1, scopes https://www.googleapis.com/auth/gmail.modify and .../userinfo.email")
    sup.say("  5. Authorize APIs, then Step 2: Exchange authorization code for tokens")
    sup.say("  6. Copy the Access token and the Refresh token")
    sup.say("  7. Paste them into the Android app's Manual Token Entry screen")
    sup.say("")
    sup.say("Option 2: sign in again on Android")
    sup.say("  1. Build and install: python mobile-app/scripts/build-with-secrets.py --build-type debug --install-to-emulator")
    sup.say("  2. In the Android app use 'Sign in with WebView' or 'Manual Token Entry'")
    sup.say("")
    if not show_secrets(Path(args.secrets_file)):
        failed = True
    sup.say("")
    sup.say("In the Android app: Gmail, Manual Token Entry, paste the Access token (required) and the Refresh token")
    sup.say("(recommended), then 'Validate & Continue'.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
