"""Run the full Flutter test suite with the evidence a failed or hung run needs (F292 Sprint 79; Python F330 Sprint 85).

Twice in Sprint 78 a full `flutter test` run lost test files ("Failed to load ... Connection closed before
test suite loaded", "did not complete") or stopped writing for 17 minutes, and nothing was recorded about the
machine at the time. This runner records, next to the run:
    - boot time and page-file size, so a run is labeled before or after a reboot (Windows; n/a elsewhere),
    - whether the DEV app is running (a process count),
    - Committed Bytes, Commit Limit and the flutter_tester count every 30 seconds (Windows commit figures;
      n/a elsewhere and when a read fails, never a silent 0.00),
    - test-RUNNER load failures only (the app's own "Failed to load credentials" lines are not counted),
    - STALLED when the log does not grow for --stall-minutes: the run's whole process tree is then killed
      (only the run's own processes, never another run's flutter_tester) and the last test line is kept.

The complete `flutter test` output goes to the log file as it is written and is never trimmed; the runner reads
only the last 400 lines for the summary line (CLAUDE.md: background logs are persisted in full, trimmed on read).

How flutter is started: `shutil.which("flutter")` finds the executable through PATH and PATHEXT. On Windows
that is `flutter.bat`; `subprocess.Popen` with an argument list and no shell starts a .bat through cmd.exe
itself, which is safe here because every argument is fixed or an integer. No `shell=True` is used.

Usage:
    python scripts/run-full-suite.py --label postreboot-1 [--out-dir DIR] [--stall-minutes 10] [--concurrency 4]
    python scripts/run-full-suite.py --label selftest --self-test-stall --stall-minutes 1     # failure-path self-test
Defaults: --out-dir <system temp>/full-suite-runs. Test seams: --poll-seconds (default 30) and --app-dir.

Files written to the out dir: suite_<label>_<stamp>.log, suite_<label>_<stamp>.csv, results.txt (one RESULT
line appended per run).

Exit codes: flutter test's own exit code; 2 STALLED; 4 no exit code or no test progress line (flutter not
found, or no tests ran); 1 the mobile-app folder is missing. The PowerShell original also had exit 3 ("the
self-test branch ran without -SelfTestStall"); it detected that by searching the log for the self-test text,
could misfire on a real log, and cannot happen here because the self-test command is chosen by the flag only,
so exit 3 is no longer produced.
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

NO_PROGRESS = "(no test progress line)"
PROGRESS_LINE = re.compile(r"^\d{2,}:\d\d \+\d+")
LOAD_FAILURE = re.compile(r'^\d{2,}:\d\d .*: loading .*\[E\]|Failed to load "|did not complete|Connection closed before test suite loaded')
SELF_TEST_CODE = "import time; print('00:00 +0: self-test, now hanging', flush=True); time.sleep(3600)"
DEV_APP_PROCESS = "MyEmailSpamFilter-Dev"
TESTER_PROCESS = "flutter_tester"


# ---------------------------------------------------------------- machine facts (best effort, never raise)
def process_ids(name: str) -> set[int]:
    """Process ids whose image name is `name` (without .exe). Empty set when the lookup fails."""
    try:
        if os.name == "nt":
            out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {name}.exe", "/FO", "CSV", "/NH"],
                                 capture_output=True, text=True, timeout=20, check=False).stdout
            return {int(row[1]) for row in csv.reader(out.splitlines()) if len(row) > 1 and row[1].isdigit()}
        out = subprocess.run(["ps", "-A", "-o", "pid=,comm="], capture_output=True, text=True, timeout=20, check=False).stdout
        found = set()
        for line in out.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and parts[0].isdigit() and Path(parts[1].strip()).name == name:
                found.add(int(parts[0]))
        return found
    except Exception:  # noqa: BLE001 - a failed lookup must not stop the run
        return set()


def commit_gb() -> tuple[str, str]:
    """(committed GB, commit limit GB) as text with two decimals; ("n/a", "n/a") when unreadable."""
    if os.name != "nt":
        return "n/a", "n/a"
    try:
        import ctypes

        class MemoryStatus(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]

        status = MemoryStatus()
        status.dwLength = ctypes.sizeof(MemoryStatus)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            return "n/a", "n/a"
        gb = 1024 ** 3
        return f"{(status.ullTotalPageFile - status.ullAvailPageFile) / gb:.2f}", f"{status.ullTotalPageFile / gb:.2f}"
    except Exception:  # noqa: BLE001
        return "n/a", "n/a"


def boot_time_text() -> str:
    try:
        if os.name == "nt":
            import ctypes

            ctypes.windll.kernel32.GetTickCount64.restype = ctypes.c_ulonglong
            return (datetime.now() - timedelta(milliseconds=ctypes.windll.kernel32.GetTickCount64())).strftime("%Y-%m-%d %H:%M:%S")
        with open("/proc/uptime", encoding="ascii") as handle:
            return (datetime.now() - timedelta(seconds=float(handle.read().split()[0]))).strftime("%Y-%m-%d %H:%M:%S")
    except Exception:  # noqa: BLE001
        return "n/a"


def pagefile_mb() -> str:
    """Allocated page-file size in MB on Windows through PowerShell when it is installed; n/a otherwise."""
    shell = shutil.which("powershell") or shutil.which("pwsh")
    if os.name != "nt" or not shell:
        return "n/a"
    try:
        out = subprocess.run([shell, "-NoProfile", "-Command",
                              "(Get-CimInstance Win32_PageFileUsage | Select-Object -First 1).AllocatedBaseSize"],
                             capture_output=True, text=True, timeout=30, check=False).stdout.strip()
        return out if out.isdigit() else "n/a"
    except Exception:  # noqa: BLE001
        return "n/a"


# ---------------------------------------------------------------- process control
def kill_tree(proc: subprocess.Popen) -> None:
    """Kill the run's own process and every process it started. Never touches other processes."""
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True, timeout=20, check=False)
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except Exception:  # noqa: BLE001
        pass
    try:
        proc.kill()
        proc.wait(timeout=20)
    except Exception:  # noqa: BLE001
        pass


def build_command(self_test: bool, concurrency: int) -> list[str] | None:
    """The command to run, or None when flutter is not installed."""
    if self_test:
        return [sys.executable, "-c", SELF_TEST_CODE]
    flutter = shutil.which("flutter")
    return [flutter, "test", f"--concurrency={concurrency}"] if flutter else None


# ---------------------------------------------------------------- log reading
def read_tail_lines(path: Path, count: int = 400) -> list[str]:
    try:
        return path.read_bytes().decode("utf-8", errors="replace").splitlines()[-count:]
    except OSError:
        return []


def count_load_failures(path: Path) -> int:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            return sum(1 for line in handle if LOAD_FAILURE.search(line))
    except OSError:
        return 0


def last_progress_line(lines: list[str]) -> str:
    found = [line for line in lines if PROGRESS_LINE.match(line)]
    return found[-1] if found else NO_PROGRESS


# ---------------------------------------------------------------- the run
def record_sample(log: Path, csv_path: Path, peaks: list[float]) -> int:
    """Append one CSV row (time, committed GB, limit GB, flutter_tester count, log KB). Returns the log size in bytes."""
    committed, limit = commit_gb()
    if re.fullmatch(r"\d+(\.\d+)?", committed):
        peaks.append(float(committed))
    size = log.stat().st_size if log.exists() else 0
    with csv_path.open("a", encoding="utf-8", newline="") as sink:
        sink.write(f"{datetime.now():%H:%M:%S},{committed},{limit},{len(process_ids(TESTER_PROCESS))},{size // 1024}\n")
    return size


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Run the full Flutter test suite with evidence for a failed or hung run.")
    parser.add_argument("--label", required=True, help='short label for the run (for example "postreboot-1"); used in file names')
    parser.add_argument("--out-dir", default=None, help="where the log, the CSV and results.txt go (default: <temp>/full-suite-runs)")
    parser.add_argument("--stall-minutes", type=float, default=10, help="minutes without log growth before the run is STALLED (default 10)")
    parser.add_argument("--concurrency", type=int, default=4, help="flutter test --concurrency (default 4)")
    parser.add_argument("--self-test-stall", action="store_true", help="failure-path self-test: write one line and hang; expect STALLED, exit 2")
    parser.add_argument("--poll-seconds", type=float, default=30, help=argparse.SUPPRESS)
    parser.add_argument("--app-dir", default=None, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    out_dir = Path(args.out_dir) if args.out_dir else Path(tempfile.gettempdir()) / "full-suite-runs"
    out_dir.mkdir(parents=True, exist_ok=True)
    app_dir = Path(args.app_dir) if args.app_dir else REPO / "mobile-app"
    if not (app_dir / "pubspec.yaml").exists():
        print(f"mobile-app not found at {app_dir}")
        return 1

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log = out_dir / f"suite_{args.label}_{stamp}.log"
    csv_path = out_dir / f"suite_{args.label}_{stamp}.csv"
    dev_procs = len(process_ids(DEV_APP_PROCESS))
    csv_path.write_text(f"boot={boot_time_text()} pagefileMB={pagefile_mb()} devAppProcs={dev_procs} label={args.label}\n"
                        "time,committedGB,limitGB,flutter_tester,logKB\n", encoding="utf-8")

    command = build_command(args.self_test_stall, args.concurrency)
    start = time.monotonic()
    stalled = False
    returncode: int | None = None
    peaks: list[float] = []
    if command is None:
        log.write_bytes(b"")
        print("RUNNER DEFECT: flutter was not found on PATH")
    else:
        popen_args: dict = {"cwd": str(app_dir), "stdin": subprocess.DEVNULL}
        if os.name == "nt":
            popen_args["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            popen_args["start_new_session"] = True
        with log.open("wb") as handle:
            try:
                proc = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT, **popen_args)
            except OSError as exc:
                print(f"RUNNER DEFECT: could not start {command[0]}: {exc}")
                proc = None
            last_size = -1
            last_growth = time.monotonic()
            while proc is not None and proc.poll() is None:
                try:
                    proc.wait(timeout=args.poll_seconds)
                except subprocess.TimeoutExpired:
                    pass
                if proc.poll() is not None:
                    break
                size = record_sample(log, csv_path, peaks)
                if size != last_size:
                    last_size = size
                    last_growth = time.monotonic()
                elif (time.monotonic() - last_growth) / 60 >= args.stall_minutes:
                    stalled = True
                    kill_tree(proc)
                    break
            if proc is not None:
                record_sample(log, csv_path, peaks)  # a closing sample: a run shorter than the poll interval still gets one
            if proc is not None and not stalled:
                returncode = proc.returncode

    minutes = int((time.monotonic() - start) / 60)
    summary = last_progress_line(read_tail_lines(log))
    if stalled:
        code = 2
    elif returncode is None:
        code = 4
    else:
        code = returncode
    # Sprint 79 7.7.1 H-3: a run with no exit code or no progress line ran no tests; it is never a pass.
    if not stalled and (returncode is None or summary == NO_PROGRESS):
        print(f"RUNNER DEFECT: no exit code or no tests ran (exit='{'' if returncode is None else returncode}'); see {log}")
        code = 4
    load_failures = count_load_failures(log)
    peak = f"{max(peaks):.2f}" if peaks else "n/a"
    state = f"STALLED({args.stall_minutes:g}m)" if stalled else f"exit={code}"
    line = (f"RESULT label={args.label} {state} minutes={minutes} loadFailures={load_failures} "
            f"peakCommittedGB={peak} devAppProcs={dev_procs} last='{summary[:80]}'")
    print(line)
    print(f"log: {log}")
    print(f"csv: {csv_path}")
    with (out_dir / "results.txt").open("a", encoding="utf-8", newline="") as sink:
        sink.write(line + "\n")
    return code


if __name__ == "__main__":
    sys.exit(main())
