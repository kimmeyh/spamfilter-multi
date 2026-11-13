"""A fake `flutter` for the runner tests (F334, Sprint 85). Not a test module: unittest discovers only test*.py.

install(folder) writes a `flutter` command into folder:
    Windows  flutter.bat  -- a batch shim that runs this file's impl with the same Python (as the real SDK does)
    POSIX    flutter      -- an executable script with a shebang line
Put the folder first on PATH (patch.dict on os.environ) and shutil.which("flutter") finds the fake.

The fake behaves from environment variables, so a test controls it without editing files:
    FAKE_FLUTTER_CALLS    file; each call appends one JSON line {"argv": [...], "cwd": "..."}
    FAKE_FLUTTER_OUT      text printed on stdout and stderr for every call (default: an all-passed summary)
    FAKE_FLUTTER_RC       exit code for every call (default: 0)
    FAKE_FLUTTER_RC_BY    JSON object: first non-option argument -> exit code, e.g. {"pub": 1}
"""
from __future__ import annotations

import os
import stat
import sys
from pathlib import Path

IMPL = Path(__file__).resolve().parent / "fake_flutter_impl.py"

IMPL_SOURCE = '''
import json, os, sys
calls = os.environ.get("FAKE_FLUTTER_CALLS")
argv = sys.argv[1:]
if calls:
    with open(calls, "a", encoding="utf-8") as handle:
        handle.write(json.dumps({"argv": argv, "cwd": os.getcwd()}) + "\\n")
sys.stdout.write(os.environ.get("FAKE_FLUTTER_OUT", "00:01 +3: All tests passed!\\n"))
sys.stdout.flush()
code = int(os.environ.get("FAKE_FLUTTER_RC", "0"))
by = json.loads(os.environ.get("FAKE_FLUTTER_RC_BY", "{}") or "{}")
first = next((a for a in argv if not a.startswith("-")), "")
if first in by:
    code = int(by[first])
sys.exit(code)
'''


def install(folder: Path) -> Path:
    """Write the fake flutter command and its implementation into folder. Returns folder."""
    folder.mkdir(parents=True, exist_ok=True)
    impl = folder / "fake_flutter_impl.py"
    impl.write_text(IMPL_SOURCE, encoding="utf-8")
    python = sys.executable
    if os.name == "nt":
        (folder / "flutter.bat").write_text(f'@echo off\r\n"{python}" "{impl}" %*\r\n', encoding="utf-8")
    else:
        command = folder / "flutter"
        command.write_text(f'#!{python}\nimport runpy, sys\nsys.argv[0] = "{impl}"\n'
                           f'runpy.run_path("{impl}", run_name="__main__")\n', encoding="utf-8")
        command.chmod(command.stat().st_mode | stat.S_IEXEC)
    return folder


def read_calls(calls_file: Path) -> list[dict]:
    """The JSON lines the fake appended, in call order (empty when flutter was never called)."""
    import json

    if not calls_file.exists():
        return []
    return [json.loads(line) for line in calls_file.read_text(encoding="utf-8").splitlines() if line.strip()]
