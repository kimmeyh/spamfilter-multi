"""Start the local TEST IMAP servers used to validate custom IMAP accounts (F331 port of
start-test-imap-servers.ps1; Sprint 77 F192, SEC-15, SEC-8b).

Two servers:
  1. GreenMail (Java, all platforms): IMAP SSL/TLS on port 3993 with GreenMail's built-in self-signed
     certificate. --new-certificate restarts it with a fresh keystore, so an app that trusted the old
     certificate sees a changed one. GreenMail offers no STARTTLS on IMAP.
  2. Dovecot inside Ubuntu WSL (Windows only): STARTTLS on port 143 and SSL/TLS on 993, Ubuntu's self-signed
     certificate. LOGIN is refused until STARTTLS succeeds. Reached from Windows at localhost through WSL.

Test account on both servers: user "tester", password "testpass". GreenMail's address is
tester@spamfilter.test but it signs in as "tester". Test data only; nothing here touches a real mailbox.
The GreenMail jar (Maven Central 2.1.14, SHA-1 checked) is kept in the work folder, outside the repository:
%LOCALAPPDATA%\\spamfilter-test-imap on Windows, ~/.local/share/spamfilter-test-imap elsewhere.

Usage:
    python scripts/start-test-imap-servers.py                 start both (Dovecot only on Windows)
    python scripts/start-test-imap-servers.py --new-certificate
    python scripts/start-test-imap-servers.py --stop          stop GreenMail and the WSL Dovecot keepalive

Options:
    --stop              stop both servers and exit
    --new-certificate   restart GreenMail with a freshly generated self-signed keystore
    --work-dir PATH     work folder (default described above)

Exit codes:
    0  servers started and their ports accept connections (or --stop finished)
    1  a required tool is missing (java, keytool, WSL), a port is already in use, the jar checksum fails,
       or a server did not open its port
    N  the Dovecot setup script in WSL exited with code N (the setup's own exit code, as the header of the
       PowerShell original promised)
    2  invalid command line (argparse)

Each server is reported as running only after its port accepts a TCP connection. A port that is already in
use stops the start before any process is launched, so another process's listener is never mistaken for
the test server.

The GreenMail processes keep running after this script exits, as the original did. Run it in a terminal or
redirect its output to a file, because the long-running processes keep an inherited pipe open.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
REPO = SCRIPTS.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

JAR_NAME = "greenmail-standalone-2.1.14.jar"
JAR_URL = ("https://repo1.maven.org/maven2/com/icegreen/greenmail-standalone/2.1.14/"
           "greenmail-standalone-2.1.14.jar")
JAR_SHA_URL = JAR_URL + ".sha1"
GREENMAIL_PORT = 3993
DOVECOT_PORTS = (143, 993)
WSL_DISTRO = "Ubuntu"
JAVA_OPTIONS = [
    "-Dgreenmail.setup.test.all",
    "-Dgreenmail.users=tester:testpass@spamfilter.test",
    "-Dgreenmail.hostname=0.0.0.0",
]
KEYSTORE_PASSWORD = "changeit"
KEEPALIVE_NAME = "spamfilter-keepalive"


class StartError(Exception):
    """A step failed. `code` is the exit code main() returns."""

    def __init__(self, message: str, code: int = 1) -> None:
        super().__init__(message)
        self.code = code


def default_work_dir() -> Path:
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
        return Path(base) / "spamfilter-test-imap"
    return Path.home() / ".local" / "share" / "spamfilter-test-imap"


def port_in_use(port: int, host: str = "127.0.0.1") -> bool:
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


def wait_for_port(port: int, tries: int = 60, delay: float = 0.5, proc: subprocess.Popen | None = None) -> bool:
    """True once a TCP connection to 127.0.0.1:port succeeds. False after `tries` probes or when `proc` exits."""
    for _ in range(tries):
        if proc is not None and proc.poll() is not None:
            return False
        if port_in_use(port):
            return True
        time.sleep(delay)
    return False


def ensure_jar(work_dir: Path, jar_url: str = JAR_URL, sha_url: str = JAR_SHA_URL) -> Path:
    """Download the GreenMail jar once and check its SHA-1. A mismatch deletes the jar and fails."""
    jar = work_dir / JAR_NAME
    if jar.exists():
        return jar
    try:
        with urllib.request.urlopen(jar_url, timeout=120) as response:
            data = response.read()
        with urllib.request.urlopen(sha_url, timeout=60) as response:
            want = response.read().decode("ascii", errors="replace").split()[0].lower()
    except (OSError, IndexError) as exc:
        raise StartError(f"could not download GreenMail: {exc}") from exc
    have = hashlib.sha1(data).hexdigest().lower()
    if have != want:
        raise StartError(f"GreenMail jar checksum mismatch ({have} vs {want}); the download was discarded")
    work_dir.mkdir(parents=True, exist_ok=True)
    jar.write_bytes(data)
    return jar


def _powershell_lines(script: str) -> list[str]:
    shell = common.find_tool("powershell", "pwsh")
    if shell is None:
        return []
    result = subprocess.run([shell, "-NoProfile", "-Command", script], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=60, check=False)
    return result.stdout.splitlines()


def find_greenmail_pids() -> list[int]:
    """Process ids of running GreenMail java processes (matched by its jar name), on any OS."""
    pids: list[int] = []
    if sys.platform == "win32":
        script = ("Get-CimInstance Win32_Process -Filter \"Name = 'java.exe'\" | "
                  "ForEach-Object { \"$($_.ProcessId) $($_.CommandLine)\" }")
        lines = _powershell_lines(script)
    else:
        ps = common.find_tool("ps")
        if ps is None:
            return []
        result = subprocess.run([ps, "-axo", "pid=,command="], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=60, check=False)
        lines = result.stdout.splitlines()
    for line in lines:
        head, _, rest = line.strip().partition(" ")
        if head.isdigit() and "greenmail-standalone" in rest:
            pids.append(int(head))
    return pids


def kill_pid(pid: int) -> None:
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True, check=False)
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass


def stop_greenmail() -> list[str]:
    messages = []
    for pid in find_greenmail_pids():
        kill_pid(pid)
        messages.append(f"Stopped GreenMail (pid {pid})")
    return messages


def detached_kwargs() -> dict:
    if sys.platform == "win32":
        return {"creationflags": subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP}
    return {"start_new_session": True}


def start_greenmail(work_dir: Path, jar: Path, java: str, keytool: str | None, port: int,
                    new_certificate: bool) -> subprocess.Popen:
    if port_in_use(port):
        raise StartError(f"port {port} is already in use by another process, so GreenMail cannot start. "
                         "Close that process and run this script again.")
    options = list(JAVA_OPTIONS)
    if new_certificate:
        if keytool is None:
            raise StartError("keytool not found (it ships with the JDK); cannot make a new certificate")
        keystore = work_dir / "greenmail-alt.p12"
        if keystore.exists():
            keystore.unlink()
        result = subprocess.run(
            [keytool, "-genkeypair", "-alias", "greenmail", "-keyalg", "RSA", "-keysize", "2048",
             "-validity", "30", "-dname", "CN=localhost", "-storetype", "PKCS12",
             "-keystore", str(keystore), "-storepass", KEYSTORE_PASSWORD, "-keypass", KEYSTORE_PASSWORD],
            capture_output=True, text=True, check=False)
        if result.returncode != 0 or not keystore.exists():
            raise StartError(f"keytool failed (exit {result.returncode})")
        options += [f"-Dgreenmail.tls.keystore.file={keystore}",
                    f"-Dgreenmail.tls.keystore.password={KEYSTORE_PASSWORD}"]
    options += ["-jar", str(jar)]
    out_log = open(work_dir / "greenmail.out.log", "w", encoding="utf-8")
    err_log = open(work_dir / "greenmail.err.log", "w", encoding="utf-8")
    proc = subprocess.Popen([java, *options], stdin=subprocess.DEVNULL, stdout=out_log, stderr=err_log,
                            **detached_kwargs())
    if not wait_for_port(port, proc=proc):
        if proc.poll() is not None:
            raise StartError(f"GreenMail exited with code {proc.returncode}; see {work_dir / 'greenmail.err.log'}")
        proc.kill()
        raise StartError(f"GreenMail did not open port {port}")
    return proc


def wsl_run(wsl: str, command: str, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([wsl, "-d", WSL_DISTRO, "-u", "root", "--", "bash", "-lc", command], **kwargs)


def start_dovecot(work_dir: Path) -> None:
    """Windows only. Keeps one WSL session open, runs the setup script, then checks ports 143 and 993."""
    wsl = common.find_tool("wsl.exe", "wsl")
    if wsl is None:
        raise StartError("WSL not found. Dovecot needs Ubuntu in WSL (Windows only).")
    setup = SCRIPTS / "test-imap" / "dovecot-wsl-setup.sh"
    if not setup.exists():
        raise StartError(f"Dovecot setup script missing: {setup}")

    # WSL stops a distribution shortly after its last session closes, and Dovecot stops with it.
    # A sleep renamed spamfilter-keepalive holds the session open; [s] keeps pgrep from matching itself.
    check = wsl_run(wsl, "pgrep -f [s]pamfilter-keepalive >/dev/null", capture_output=True, check=False)
    if check.returncode != 0:
        keep_out = open(work_dir / "wsl-keepalive.out.log", "w", encoding="utf-8")
        keep_err = open(work_dir / "wsl-keepalive.err.log", "w", encoding="utf-8")
        subprocess.Popen([wsl, "-d", WSL_DISTRO, "-u", "root", "--", "bash", "-lc",
                          f"exec -a {KEEPALIVE_NAME} sleep infinity"],
                         stdin=subprocess.DEVNULL, stdout=keep_out, stderr=keep_err, **detached_kwargs())

    drive = str(setup)[0].lower()
    wsl_path = "/mnt/" + drive + str(setup)[2:].replace("\\", "/")
    command = f"tr -d '\\r' < '{wsl_path}' > /tmp/dovecot-wsl-setup.sh && bash /tmp/dovecot-wsl-setup.sh"
    result = wsl_run(wsl, command, check=False)
    if result.returncode != 0:
        raise StartError(f"Dovecot setup in WSL failed (exit {result.returncode}); see the lines above",
                         code=result.returncode or 1)
    for port in DOVECOT_PORTS:
        if not wait_for_port(port, tries=20):
            raise StartError(f"Dovecot did not open port {port} on localhost (WSL localhost forwarding or Dovecot itself)")


def stop_dovecot() -> str:
    wsl = common.find_tool("wsl.exe", "wsl")
    if wsl is None:
        return "WSL not found; no Dovecot to stop."
    command = ("pkill -f [s]pamfilter-keepalive || true; "
               "if pkill -x dovecot; then echo Stopped Dovecot in WSL.; else echo Dovecot in WSL was not running.; fi")
    result = wsl_run(wsl, command, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    return result.stdout.strip() or "Dovecot stop finished."


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Start the local test IMAP servers (GreenMail, Dovecot in WSL).")
    parser.add_argument("--stop", action="store_true", help="stop both servers and exit")
    parser.add_argument("--new-certificate", action="store_true",
                        help="restart GreenMail with a freshly generated self-signed keystore")
    parser.add_argument("--work-dir", metavar="PATH", help="work folder for the jar and logs")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    work_dir = Path(args.work_dir) if args.work_dir else default_work_dir()
    work_dir.mkdir(parents=True, exist_ok=True)

    if args.stop:
        for message in stop_greenmail():
            print(message)
        if sys.platform == "win32":
            print(stop_dovecot())
        return 0

    try:
        java = common.find_tool("java")
        if java is None:
            raise StartError("java not found. GreenMail runs on Java; install a JDK or JRE.")
        keytool = common.find_tool("keytool") if args.new_certificate else None
        jar = ensure_jar(work_dir)
        for message in stop_greenmail():
            print(message)
        proc = start_greenmail(work_dir, jar, java, keytool, GREENMAIL_PORT, args.new_certificate)
        suffix = " (NEW certificate)" if args.new_certificate else ""
        print(f"GreenMail running (pid {proc.pid}): IMAP SSL/TLS on port {GREENMAIL_PORT}, self-signed{suffix}")
        if sys.platform == "win32":
            start_dovecot(work_dir)
            print("Dovecot verified: ports 143 (STARTTLS) and 993 (SSL/TLS) accept connections.")
        else:
            print("Dovecot (ports 143 and 993) runs in WSL and is Windows only; skipped on this system.")
    except StartError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return exc.code

    print("")
    print("Use in the app (Add Account > Custom IMAP Server), username tester:")
    print(f"  SSL/TLS : server localhost or 127.0.0.1, port {GREENMAIL_PORT} (GreenMail; email tester@spamfilter.test)"
          " or 993 (Dovecot)")
    print("  STARTTLS: server localhost, port 143 (Dovecot)")
    print("  Password: testpass")
    print("From the Fold, use this PC's Wi-Fi address with port 3993 (GreenMail binds all interfaces).")
    return 0


if __name__ == "__main__":
    common.configure_stdio()
    sys.exit(main())
