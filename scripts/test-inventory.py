"""List every test artifact in the repository, with kind, risk tier, where it runs and timings (F350, Sprint 85).

Read-only for the repository: it changes no tracked file. It prints or writes JSON (and, with
--markdown, a summary). Python 3.12, standard library only (ADR-0051). Runs on Windows, Linux and macOS.

Artifacts (the discovery rule; the policy test mobile-app/test/policy/test_inventory_coverage_test.dart
compares `--list-paths` with its own walk of mobile-app/test, so a *_test.dart in a folder this script
does not scan fails that test):
    dart            every *_test.dart under mobile-app/test (any depth; the gitignored test/scratch is
                    skipped) and mobile-app/integration_test (any depth)
    winwright       mobile-app/test/winwright/test_*.json and mobile-app/test/e2e/*.json
    hook-case       one entry per folder of .claude/hooks/test-cases holding cases (the root folder is one
                    entry; "fixtures" holds inputs, not cases, and is skipped), with a case count
    python-unittest .claude/hooks/tests/*.py and scripts/tests/*.py (files named test*.py)

Kinds: unit, widget, integration, policy, hook-case, python-unittest, winwright.
    policy       under mobile-app/test/policy
    integration  under mobile-app/integration_test or mobile-app/test/integration
    widget       contains testWidgets( (and is not policy or integration)
    unit         any other Dart test

TIER RULE (proposed risk tier = likelihood x impact, ISTQB CTFL v4.0.1 section 5.2):
    impact is HIGH when the test is a release gate (kind policy) or when it imports or reads a lib/ file
    that matches HIGH_IMPACT_LIB (code that deletes or moves mail, credentials and secure storage, the scan
    coordinator, background workers, database migrations). Only DIRECT imports and File('lib/...') reads
    count; imports are not followed transitively, so a widget test of a screen that reaches the scanner
    through a provider is not marked. Hook-case, WinWright and Python tests have impact NORMAL
    (hook-case churn uses the guarded hook, HOOK_FOR_FOLDER).
    likelihood comes from churn: the number of commits in the last CHURN_DAYS days touching the lib/ files
    the test imports or reads (for hook cases, the guarded hook; for other kinds, the test file itself),
    in the union (a commit that touched two files counts once). HIGH when >= LIKELIHOOD_HIGH, MEDIUM
    when >= LIKELIHOOD_MEDIUM, else LOW. The thresholds were calibrated on 2026-11-10 data (647 commits
    in 60 days; the median test has 15 commits, the 75th percentile 44): 40 is about the top quarter.
    tier: impact HIGH and likelihood HIGH or MEDIUM -> high; impact HIGH and likelihood LOW -> medium;
          impact NORMAL and likelihood HIGH -> medium; every other combination -> low.
    The tier is a PROPOSAL for the F350 analysis, not a decision.

Usage:
    python scripts/test-inventory.py --out inventory.json --markdown inventory.md
    python scripts/test-inventory.py --list-paths
    python scripts/test-inventory.py --measure --only unit/foo_test.dart --limit 3 --timings cache.json
    python scripts/test-inventory.py --ci --out inventory.json
The default --out is test-inventory.json in the system temp folder (never the repository).
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import statistics
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

APP = "mobile-app"
PACKAGE = "my_email_spam_filter"
SKIP_DIRS = {"scratch", "build", ".dart_tool", "node_modules", "__pycache__", ".git"}
CHURN_DAYS = 60
LIKELIHOOD_HIGH = 40
LIKELIHOOD_MEDIUM = 10

# lib/ paths (relative to mobile-app/lib) whose failure can lose mail, leak a credential, wedge a
# scan or damage stored data. Each entry: (regex, reason).
HIGH_IMPACT_LIB = [
    (r"^adapters/email_providers/(generic_imap_adapter|gmail_api_adapter|outlook_adapter)\.dart$",
     "deletes or moves mail"),
    (r"^adapters/gmail/gmail_client\.dart$", "deletes or moves mail"),
    (r"^core/services/(email_scanner|rule_quick_action_service|data_deletion_service)\.dart$", "deletes or moves mail"),
    (r"^adapters/auth/", "credentials"),
    (r"^adapters/storage/secure_credentials_store\.dart$", "credentials"),
    (r"^core/security/", "credentials and transport security"),
    (r"^core/services/scan_coordinator\.dart$", "scan coordinator"),
    (r"^core/services/(android_background_scan_worker|background_[a-z_]+)\.dart$", "background workers"),
    (r"^core/storage/migration_manager\.dart$", "database migrations"),
    (r"^core/services/(per_account_bg_migration|f264_upgrade_migration|app_identity_migration)\.dart$", "migrations"),
]

# Hook-case folder -> the hook it replays (.claude/hooks/tests/test_pylib.py CASES).
HOOK_FOR_FOLDER = {
    "": "sprint-auto-advance.py",
    "closeout": "verify-closeout-complete.py",
    "commit-lock": "block-commit-during-mutation.py",
    "heredoc-guard": "block-heredoc-python-backslash.py",
    "sprint-cards": "require-sprint-cards.py",
    "staging-guard": "block-blind-staging.py",
    "stash-guard": "block-carry-forward-stash.py",
    "velocity-warn": "warn-commit-without-velocity.py",
}

FIX_SUBJECT = re.compile(r"^fix(\([^)]*\))?[:!\s]", re.I)
IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
FILE_READ = re.compile(r"""['"]((?:\.\./)*lib/[A-Za-z0-9_/.]+\.dart)['"]""")
GROUP = re.compile(r"""\bgroup\(\s*(['"])(.+?)\1""")
TESTCALL = re.compile(r"""\b(?:test|testWidgets)\(\s*(['"])(.+?)\1""")


def rel(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


# ---------------------------------------------------------------- discovery

def _walk_files(base: Path):
    """Yield files under base at any depth, skipping SKIP_DIRS. Walks the file system (not git) so a
    new, uncommitted test file is listed."""
    if not base.is_dir():
        return
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            yield Path(dirpath) / name


def discover(repo: Path = REPO) -> list[dict]:
    """Return one dict per test artifact: {path, kind_hint, ...}. Sorted by path."""
    found: list[dict] = []
    for base in (repo / APP / "test", repo / APP / "integration_test"):
        for f in _walk_files(base):
            if f.name.endswith("_test.dart"):
                found.append({"path": f.relative_to(repo).as_posix(), "family": "dart"})
    for f in _walk_files(repo / APP / "test" / "winwright"):
        if f.parent.name == "winwright" and f.name.startswith("test_") and f.suffix == ".json":
            found.append({"path": f.relative_to(repo).as_posix(), "family": "winwright"})
    for f in _walk_files(repo / APP / "test" / "e2e"):
        if f.suffix == ".json":
            found.append({"path": f.relative_to(repo).as_posix(), "family": "winwright"})
    cases = repo / ".claude" / "hooks" / "test-cases"
    if cases.is_dir():
        folders = [cases] + sorted(d for d in cases.iterdir() if d.is_dir() and d.name != "fixtures")
        for d in folders:
            n = len([x for x in d.glob("*.json")])
            if n:
                found.append({"path": d.relative_to(repo).as_posix(), "family": "hook-case", "case_count": n})
    for folder in (repo / ".claude" / "hooks" / "tests", repo / "scripts" / "tests"):
        if folder.is_dir():
            for f in sorted(folder.glob("test*.py")):
                found.append({"path": f.relative_to(repo).as_posix(), "family": "python-unittest"})
    found.sort(key=lambda a: a["path"])
    return found


# ---------------------------------------------------------------- parsing

def parse_dart_imports(text: str, test_rel_dir: str) -> dict:
    """Split a Dart test's imports into lib files, test helpers and file reads (all repo-relative
    to mobile-app, posix). test_rel_dir is the test's folder relative to mobile-app."""
    lib, helpers = set(), set()
    for target in IMPORT.findall(text):
        if target.startswith(f"package:{PACKAGE}/"):
            lib.add("lib/" + target[len(f"package:{PACKAGE}/"):])
        elif target.startswith(("package:", "dart:")):
            continue
        else:
            norm = os.path.normpath(os.path.join(test_rel_dir, target)).replace("\\", "/")
            if norm.startswith("lib/"):
                lib.add(norm)
            elif norm.startswith(("test/", "integration_test/")):
                helpers.add(norm)
    reads = {re.sub(r"^(\./|\.\./)+", "", m) for m in FILE_READ.findall(text)}
    return {"lib_imports": sorted(lib), "test_imports": sorted(helpers), "lib_reads": sorted(reads - lib)}


def classify_kind(rel_path: str, text: str, family: str) -> str:
    if family == "winwright":
        return "winwright"
    if family == "hook-case":
        return "hook-case"
    if family == "python-unittest":
        return "python-unittest"
    if "/test/policy/" in "/" + rel_path:
        return "policy"
    if rel_path.startswith(f"{APP}/integration_test/") or rel_path.startswith(f"{APP}/test/integration/"):
        return "integration"
    if "testWidgets(" in text:
        return "widget"
    return "unit"


def _comment_summary(text: str) -> str | None:
    """First line of the first comment block that comes before `void main`."""
    head = text.split("void main", 1)[0]
    for line in head.splitlines():
        s = line.strip()
        m = re.match(r"^///?\s?(.*)$", s)
        if not m:
            continue
        body = m.group(1).strip()
        if not body or body.startswith(("ignore_for_file", "ignore:", "@", "TODO")) or set(body) <= set("-=*# "):
            continue
        return body[:160]
    return None


def guard_summary(text: str, family: str) -> str:
    """What a test guards: the first doc comment line, else the top group/test names, else 'unknown'."""
    if family == "python-unittest":
        m = re.match(r'\s*(?:#![^\n]*\n)?\s*(?:r?"""|\'\'\')\s*(.+)', text)
        if m:
            return m.group(1).strip().rstrip('"\'')[:160]
        return "unknown"
    if family == "winwright":
        try:
            desc = json.loads(text).get("description", "")
        except (ValueError, AttributeError):
            desc = ""
        return re.split(r"(?<=\.)\s", desc, maxsplit=1)[0][:160] if desc else "unknown"
    comment = _comment_summary(text)
    if comment:
        return comment
    groups = [g[1] for g in GROUP.findall(text)][:2]
    if groups:
        return "groups: " + "; ".join(groups)[:150]
    tests = [t[1] for t in TESTCALL.findall(text)][:2]
    if tests:
        return "tests: " + "; ".join(tests)[:150]
    return "unknown"


def count_dart_tests(text: str) -> int:
    return len(TESTCALL.findall(text))


# ---------------------------------------------------------------- workflows

def parse_workflow(text: str, name: str) -> dict:
    """Parse a GitHub Actions workflow with line scanning (no YAML library). Returns
    {job_id: {name, runs_on, full_dart_suite, integration_loop, integration_files, excluded,
              python_tests}}.
    full_dart_suite: a step whose run is exactly `flutter test` (the whole mobile-app/test folder).
    integration_loop: a loop over integration_test/*_test.dart; excluded: names in EXCLUDED_TESTS."""
    jobs: dict = {}
    current = None
    in_jobs = False
    for line in text.splitlines():
        if re.match(r"^jobs:\s*$", line):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        m = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if m:
            current = m.group(1)
            jobs[current] = {"name": current, "runs_on": "", "full_dart_suite": False, "integration_loop": False,
                             "integration_files": [], "excluded": [], "moved": [], "python_tests": [], "workflow": name}
            continue
        if current is None:
            continue
        job = jobs[current]
        s = line.strip()
        if s.startswith("#"):
            continue
        m = re.match(r"^    name:\s*(.+)$", line)
        if m:
            job["name"] = m.group(1).strip().strip("'\"")
        m = re.match(r"^    runs-on:\s*(.+)$", line)
        if m:
            job["runs_on"] = m.group(1).strip()
        if re.match(r"^\s*(?:- )?run:\s*flutter test\s*$", line):
            job["full_dart_suite"] = True
        if "integration_test/*_test.dart" in line:
            job["integration_loop"] = True
        m = re.search(r"EXCLUDED_TESTS:\s*['\"]([^'\"]*)['\"]", line)
        if m:
            job["excluded"] = m.group(1).split()
        # [ "$name" = "x_test.dart" ] && continue  -- the loop skips that file (it runs in another job)
        m = re.search(r"""\[ "\$name" = "([A-Za-z0-9_]+_test\.dart)" \] && continue""", line)
        if m and m.group(1) not in job["moved"]:
            job["moved"].append(m.group(1))
        for f in re.findall(r"flutter test (integration_test/[A-Za-z0-9_]+_test\.dart)", line):
            if f not in job["integration_files"]:
                job["integration_files"].append(f)
        for p in re.findall(r"python3? (?:-I )?(?:-m unittest discover -s )?([A-Za-z0-9_./-]*tests?[A-Za-z0-9_./-]*)", line):
            if p not in job["python_tests"] and ("scripts/tests" in p or ".claude/hooks/tests" in p):
                job["python_tests"].append(p)
    return jobs


def ci_label(job: dict) -> str:
    ro = job["runs_on"]
    if ro.startswith("ubuntu"):
        return f"ci-linux ({job['workflow']}:{job['name']})"
    if ro.startswith("windows"):
        return f"ci-windows ({job['workflow']}:{job['name']})"
    if ro.startswith("macos"):
        return f"ios-simulator ({job['workflow']}:{job['name']})" if "imulator" in job["name"] else f"ci-macos ({job['workflow']}:{job['name']})"
    return f"ci ({job['workflow']}:{job['name']})"


def load_workflows(repo: Path = REPO) -> list[dict]:
    jobs = []
    wf = repo / ".github" / "workflows"
    for f in sorted(wf.glob("*.yml")) if wf.is_dir() else []:
        for job in parse_workflow(f.read_text(encoding="utf-8", errors="replace"), f.name).values():
            jobs.append(job)
    return jobs


def where_it_runs(rel_path: str, family: str, jobs: list[dict]) -> list[str]:
    """Return the places this artifact runs: 'local ...' entries and CI job labels."""
    runs: list[str] = []
    name = rel_path.rsplit("/", 1)[-1]
    if family == "dart":
        if rel_path.startswith(f"{APP}/test/"):
            runs.append("local: flutter test (Windows host)")
            for j in jobs:
                if j["full_dart_suite"]:
                    runs.append(ci_label(j))
        else:
            runs.append("local: run-integration-tests.py (Windows host)")
            for j in jobs:
                if f"integration_test/{name}" in j["integration_files"] or (
                        j["integration_loop"] and name not in j["excluded"] and name not in j["moved"]):
                    runs.append(ci_label(j))
                elif j["integration_loop"] and name in j["excluded"]:
                    runs.append(f"EXCLUDED in {ci_label(j)}")
    elif family == "winwright":
        runs.append("local only: run-winwright-tests.ps1 (Windows host, not in CI)")
    elif family == "hook-case":
        runs.append("local: .claude/hooks/run-test-cases.ps1 (Windows host)")
        for j in jobs:
            if any(".claude/hooks/tests" in p for p in j["python_tests"]):
                runs.append(ci_label(j))
    elif family == "python-unittest":
        runs.append("local: python -I -m unittest (any OS)")
        folder = rel_path.rsplit("/", 1)[0]
        for j in jobs:
            if any(p.startswith(folder) or p == rel_path for p in j["python_tests"]):
                runs.append(ci_label(j))
    return runs


def platforms_for(runs: list[str], family: str) -> list[str]:
    plats = set()
    for r in runs:
        if r.startswith("EXCLUDED"):
            continue
        if r.startswith("local") and "Windows host" in r:
            plats.add("windows-host")
        elif r.startswith("local"):
            plats.add("any-host")
        if r.startswith("ci-linux"):
            plats.add("ci-linux")
        if r.startswith("ios-simulator"):
            plats.add("ios-simulator")
        if r.startswith("ci-windows"):
            plats.add("ci-windows")
    return sorted(plats)


# ---------------------------------------------------------------- git

def git_lines(*args: str, timeout: int = 120) -> list[str]:
    code, out = common.git(*args, cwd=REPO, timeout=timeout)
    return out.splitlines() if code == 0 else []


def churn_counts(days: int = CHURN_DAYS) -> dict[str, set]:
    """The set of commits per file in the last `days` days, for lib, hooks, scripts and tests. Sets
    (not counts) so the churn of several files counts a commit that touched two of them once."""
    commits: dict[str, set] = {}
    current = ""
    for line in git_lines("log", f"--since={days}.days.ago", "--name-only", "--format=@%h", "--",
                          f"{APP}/lib", ".claude/hooks", "scripts", f"{APP}/test", f"{APP}/integration_test"):
        if line.startswith("@"):
            current = line
        elif line:
            commits.setdefault(line, set()).add(current)
    return commits


def owner_of(path: str) -> str:
    """Map a changed file to the inventory entry that owns it."""
    m = re.match(r"^(\.claude/hooks/test-cases)/(?!fixtures/)([^/]+)/[^/]+\.json$", path)
    if m:
        return f"{m.group(1)}/{m.group(2)}"
    if re.match(r"^\.claude/hooks/test-cases/[^/]+\.json$", path):
        return ".claude/hooks/test-cases"
    return path


def last_fix_evidence() -> dict[str, dict]:
    """Most recent commit with a subject starting 'fix' that touched each test (HEURISTIC: a fix
    commit that touched a test did not necessarily have the test catch the defect)."""
    result: dict[str, dict] = {}
    commit = None
    for line in git_lines("log", "--format=@%h|%cs|%s", "--name-only", "--", f"{APP}/test", f"{APP}/integration_test",
                          ".claude/hooks/test-cases", ".claude/hooks/tests", "scripts/tests", timeout=180):
        if line.startswith("@"):
            h, d, subj = (line[1:].split("|", 2) + ["", ""])[:3]
            commit = (h, d, subj) if FIX_SUBJECT.match(subj) else None
        elif line and commit:
            key = owner_of(line)
            if key not in result:
                result[key] = {"commit": commit[0], "date": commit[1], "subject": commit[2][:100], "label": "heuristic"}
    return result


# ---------------------------------------------------------------- risk tier

def impact_of_lib(path: str) -> str | None:
    sub = path[len("lib/"):] if path.startswith("lib/") else path
    for rx, reason in HIGH_IMPACT_LIB:
        if re.search(rx, sub):
            return reason
    return None


def likelihood_of(churn_total: int) -> str:
    if churn_total >= LIKELIHOOD_HIGH:
        return "high"
    if churn_total >= LIKELIHOOD_MEDIUM:
        return "medium"
    return "low"


def tier_for(impact: str, likelihood: str) -> str:
    if impact == "high":
        return "high" if likelihood in ("high", "medium") else "medium"
    return "medium" if likelihood == "high" else "low"


# ---------------------------------------------------------------- build

def build_inventory(repo: Path = REPO, timings: dict | None = None, with_git: bool = True) -> list[dict]:
    jobs = load_workflows(repo)
    churn = churn_counts() if with_git else {}
    fixes = last_fix_evidence() if with_git else {}
    timings = timings or {}
    out = []
    for art in discover(repo):
        p = art["path"]
        family = art["family"]
        full = repo / p
        text = ""
        if full.is_file():
            text = full.read_text(encoding="utf-8", errors="replace")
        kind = classify_kind(p, text, family)
        entry = {"path": p, "kind": kind, "guards": "unknown", "lib_imports": [], "lib_reads": [],
                 "test_imports": [], "test_count": None}
        impact_reasons: list[str] = []
        churn_files: list[str] = []
        if family == "dart":
            parsed = parse_dart_imports(text, os.path.dirname(p[len(APP) + 1:]))
            entry.update(parsed)
            entry["guards"] = guard_summary(text, family)
            entry["test_count"] = count_dart_tests(text)
            churn_files = [f"{APP}/{x}" for x in parsed["lib_imports"] + parsed["lib_reads"]]
            for x in parsed["lib_imports"] + parsed["lib_reads"]:
                r = impact_of_lib(x)
                if r and r not in impact_reasons:
                    impact_reasons.append(r)
            if kind == "policy":
                impact_reasons.append("release gate (test/policy)")
        elif family == "hook-case":
            folder = p.rsplit("/", 1)[-1]
            hook = HOOK_FOR_FOLDER.get("" if folder == "test-cases" else folder, "unknown")
            entry["guards"] = f"cases replayed through hook {hook}"
            entry["case_count"] = art["case_count"]
            entry["test_count"] = art["case_count"]
            churn_files = [f".claude/hooks/{hook}"]
        else:
            entry["guards"] = guard_summary(text, family)
            churn_files = [p]
            if family == "python-unittest":
                entry["test_count"] = len(re.findall(r"^\s*def test_", text, re.M))
        runs = where_it_runs(p, family, jobs)
        entry["runs_on"] = runs
        entry["platforms"] = platforms_for(runs, family)
        entry["last_fix_commit"] = fixes.get(p)
        union: set = set()
        for f in set(churn_files):
            union |= churn.get(f, set())
        total = len(union)
        entry["churn_commits_60d"] = total
        entry["churn_files_changed"] = sorted(f for f in set(churn_files) if churn.get(f))
        impact = "high" if impact_reasons else "normal"
        likelihood = likelihood_of(total)
        entry["impact"] = "high" if impact == "high" else "normal"
        entry["impact_reasons"] = impact_reasons
        entry["likelihood"] = likelihood
        entry["tier"] = tier_for(impact, likelihood)
        entry["timing"] = timings.get(p)
        out.append(entry)
    return out


def summarize(entries: list[dict]) -> dict:
    def count(key_fn):
        d: dict[str, int] = {}
        for e in entries:
            for k in key_fn(e):
                d[k] = d.get(k, 0) + 1
        return dict(sorted(d.items()))

    return {
        "artifacts": len(entries),
        "by_kind": count(lambda e: [e["kind"]]),
        "by_tier": count(lambda e: [e["tier"]]),
        "by_where_it_runs": count(lambda e: [r.split(":")[0] if r.startswith("local") else r for r in e["runs_on"]] or ["none"]),
        "by_platform": count(lambda e: e["platforms"] or ["none"]),
        "dart_test_cases": sum(e["test_count"] or 0 for e in entries if e["kind"] in ("unit", "widget", "integration", "policy")),
    }


# ---------------------------------------------------------------- measure

def machine_info() -> dict:
    return {"node": platform.node(), "os": platform.platform(), "python": platform.python_version(),
            "cpu_count": os.cpu_count()}


def parse_reporter_output(out: str) -> dict:
    """Count tests from `flutter test --reporter json` output (one JSON object per line). The pseudo
    test "loading <file>" is hidden and not counted; a line that is not JSON is ignored."""
    passed = failed = skipped = 0
    suite_success = None
    hidden: set = set()
    for line in out.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        if ev.get("type") == "testStart" and ev.get("test", {}).get("name", "").startswith("loading "):
            hidden.add(ev["test"]["id"])
        if ev.get("type") == "testDone" and ev.get("testID") not in hidden and not ev.get("hidden"):
            if ev.get("skipped"):
                skipped += 1
            elif ev.get("result") == "success":
                passed += 1
            else:
                failed += 1
        if ev.get("type") == "done":
            suite_success = ev.get("success")
    return {"tests_passed": passed, "tests_failed": failed, "tests_skipped": skipped, "suite_success": suite_success}


def measure_file(rel_path: str, timeout: int = 900) -> dict:
    """Time `flutter test <file> --reporter json` in mobile-app. Wall clock includes the Flutter tool
    start-up and compile, which is what a person waits for."""
    import subprocess

    flutter = common.find_tool("flutter", "flutter.bat")
    arg = rel_path[len(APP) + 1:]
    argv = [flutter or "flutter", "test", arg, "--reporter", "json"]
    started = datetime.now(timezone.utc).isoformat(timespec="seconds")
    t0 = time.monotonic()
    result = {"command": "flutter test " + arg + " --reporter json (cwd mobile-app)", "date": started,
              "machine": machine_info()}
    try:
        proc = subprocess.Popen(argv, cwd=str(REPO / APP), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    except OSError as exc:
        result.update({"error": f"could not start flutter: {exc}", "wall_seconds": None})
        return result
    try:
        out, _err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        common._kill_tree(proc)
        result.update({"error": f"timeout after {timeout}s", "wall_seconds": round(time.monotonic() - t0, 1)})
        return result
    result["wall_seconds"] = round(time.monotonic() - t0, 1)
    result["exit_code"] = proc.returncode
    result.update(parse_reporter_output(out))
    if proc.returncode != 0:
        # Keep the end of stderr and of the non-JSON stdout so a failed or uncompiled run is explained.
        plain = "\n".join(ln for ln in out.splitlines() if not ln.startswith("{"))
        result["output_tail"] = (_err.strip() + "\n" + plain.strip()).strip()[-600:]
    return result


def run_measure(entries: list[dict], only: list[str], limit: int | None, cache: Path) -> dict:
    data = {"timings": {}}
    if cache.is_file():
        try:
            data = json.loads(cache.read_text(encoding="utf-8"))
        except ValueError:
            data = {"timings": {}}
    todo = [e["path"] for e in entries if e["path"].endswith("_test.dart")
            and (not only or any(o in e["path"] for o in only))]
    if limit is not None:
        todo = todo[:limit]
    for p in todo:
        print(f"measuring {p} ...", flush=True)
        data["timings"][p] = measure_file(p)
        print(f"  {data['timings'][p].get('wall_seconds')} s, exit {data['timings'][p].get('exit_code')}", flush=True)
        cache.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


# ---------------------------------------------------------------- CI timing

def _parse_ts(s: str | None):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def job_durations(view: dict) -> list[dict]:
    """From `gh run view --json jobs`: per-job and per-step durations in seconds."""
    jobs = []
    for j in view.get("jobs", []):
        a, b = _parse_ts(j.get("startedAt")), _parse_ts(j.get("completedAt"))
        steps = []
        for s in j.get("steps", []):
            sa, sb = _parse_ts(s.get("startedAt")), _parse_ts(s.get("completedAt"))
            steps.append({"name": s.get("name"), "conclusion": s.get("conclusion"),
                          "seconds": round((sb - sa).total_seconds()) if sa and sb else None})
        # A skipped job reports a completedAt before its startedAt (negative); that is no duration.
        secs = round((b - a).total_seconds()) if a and b and j.get("conclusion") != "skipped" else None
        jobs.append({"name": j.get("name"), "conclusion": j.get("conclusion"),
                     "seconds": secs if secs is None or secs >= 0 else None, "steps": steps})
    return jobs


def read_ci(workflow: str = "ci.yml", limit: int = 10) -> dict:
    code, out = common.gh("run", "list", "--workflow", workflow, "--limit", str(limit), "--json",
                          "databaseId,conclusion,createdAt", cwd=REPO, timeout=60)
    if code != 0:
        return {"error": f"gh run list failed: {common.gh_failure_reason(code)}", "runs": []}
    try:
        runs = json.loads(out)
    except ValueError:
        return {"error": "gh run list returned text that is not JSON", "runs": []}
    result = {"workflow": workflow, "read": datetime.now(timezone.utc).isoformat(timespec="seconds"),
              "command": f"gh run list --workflow {workflow} --limit {limit} --json databaseId,conclusion,createdAt; "
                         "gh run view <id> --json jobs",
              "note": "Per-test-file CI time is not available: the CI log has one flutter test step for the whole suite.",
              "runs": []}
    for r in runs:
        c2, o2 = common.gh("run", "view", str(r["databaseId"]), "--json", "jobs", cwd=REPO, timeout=60)
        try:
            jobs = job_durations(json.loads(o2)) if c2 == 0 else []
        except ValueError:
            jobs = []
        result["runs"].append({"id": r["databaseId"], "conclusion": r.get("conclusion"),
                               "createdAt": r.get("createdAt"), "jobs": jobs})
    # median per job and per step over runs where the job ran to completion
    agg: dict = {}
    for r in result["runs"]:
        for j in r["jobs"]:
            if j["seconds"] is None or j["conclusion"] not in ("success", "failure"):
                continue
            a = agg.setdefault(j["name"], {"seconds": [], "steps": {}})
            a["seconds"].append(j["seconds"])
            for s in j["steps"]:
                if s["seconds"] is not None:
                    a["steps"].setdefault(s["name"], []).append(s["seconds"])
    result["median_seconds"] = {
        name: {"job": statistics.median(a["seconds"]), "runs": len(a["seconds"]),
               "steps": {k: statistics.median(v) for k, v in a["steps"].items()}}
        for name, a in agg.items()}
    return result


# ---------------------------------------------------------------- markdown

def render_markdown(entries: list[dict], summary: dict, ci: dict | None, timings: dict | None) -> str:
    L = ["# Test inventory", "", f"Artifacts: {summary['artifacts']}. Dart test cases (static count): {summary['dart_test_cases']}.", ""]
    for title, key in (("By kind", "by_kind"), ("By proposed tier", "by_tier"), ("By where it runs", "by_where_it_runs"),
                       ("By platform", "by_platform")):
        L += [f"## {title}", ""] + [f"- {k}: {v}" for k, v in summary[key].items()] + [""]
    if "android-emulator" not in summary["by_platform"]:
        L += ["Gap: no test artifact is wired to run on an Android emulator or device; none is listed under that platform.", ""]
    high = [e for e in entries if e["tier"] == "high"]
    L += [f"## High-tier entries ({len(high)})", ""]
    for e in high:
        L.append(f"- {e['path']} ({e['kind']}): {', '.join(e['impact_reasons']) or 'impact normal'}; churn {e['churn_commits_60d']}")
    L.append("")
    unknown = [e for e in entries if e["guards"] == "unknown"]
    L += [f"## Entries whose purpose is unknown ({len(unknown)})", ""] + [f"- {e['path']}" for e in unknown] + [""]
    if timings:
        L += ["## Local timings recorded", ""]
        for p, t in sorted(timings.items()):
            L.append(f"- {p}: {t.get('wall_seconds')} s, {t.get('tests_passed')} passed, {t.get('tests_failed')} failed ({t.get('date')}, {t.get('machine', {}).get('node')})")
        L.append("")
    if ci:
        L += ["## CI timing (median seconds)", "", f"Read {ci.get('read')} with: {ci.get('command')}", f"{ci.get('note', '')}", ""]
        if ci.get("error"):
            L.append(f"Error: {ci['error']}")
        for name, a in (ci.get("median_seconds") or {}).items():
            L.append(f"- {name}: {a['job']} s over {a['runs']} runs")
            for s, v in a["steps"].items():
                L.append(f"  - {s}: {v} s")
        L.append("")
    return "\n".join(L)


# ---------------------------------------------------------------- main

def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    ap = argparse.ArgumentParser(description="List every test artifact with kind, tier, where it runs and timings (F350).")
    ap.add_argument("--out", help="JSON output path (default: test-inventory.json in the system temp folder)")
    ap.add_argument("--markdown", help="also write a Markdown summary to this path")
    ap.add_argument("--list-paths", action="store_true", help="print the discovered artifact paths, one per line, and exit")
    ap.add_argument("--measure", action="store_true", help="time Dart test files with flutter test --reporter json")
    ap.add_argument("--only", nargs="*", default=[], help="with --measure: only paths containing one of these strings")
    ap.add_argument("--limit", type=int, help="with --measure: at most N files")
    ap.add_argument("--timings", help="timings cache JSON (read when building, written by --measure)")
    ap.add_argument("--ci", action="store_true", help="read recent CI run, job and step durations with gh")
    ap.add_argument("--ci-limit", type=int, default=10)
    args = ap.parse_args(argv)

    if args.list_paths:
        for a in discover():
            print(a["path"])
        return 0

    tmp = Path(tempfile.gettempdir())
    cache = Path(args.timings) if args.timings else tmp / "test-inventory-timings.json"
    entries0 = [{"path": a["path"]} for a in discover()]
    if args.measure:
        run_measure(entries0, args.only, args.limit, cache)
    timings = {}
    if cache.is_file():
        try:
            timings = json.loads(cache.read_text(encoding="utf-8")).get("timings", {})
        except ValueError:
            print(f"warning: timings cache {cache} is not valid JSON; ignored", file=sys.stderr)
    entries = build_inventory(timings=timings)
    summary = summarize(entries)
    ci = read_ci(limit=args.ci_limit) if args.ci else None
    code, head = common.git("rev-parse", "--short", "HEAD", cwd=REPO, timeout=15)
    doc = {"generated": datetime.now(timezone.utc).isoformat(timespec="seconds"), "git_head": head.strip() if code == 0 else None,
           "machine": machine_info(), "tier_rule": "see the docstring of scripts/test-inventory.py",
           "churn_days": CHURN_DAYS, "likelihood_thresholds": {"high": LIKELIHOOD_HIGH, "medium": LIKELIHOOD_MEDIUM},
           "summary": summary, "artifacts": entries, "ci_timing": ci}
    out = Path(args.out) if args.out else tmp / "test-inventory.json"
    out.write_text(json.dumps(doc, indent=2), encoding="utf-8")
    print(f"wrote {out} ({summary['artifacts']} artifacts)")
    if args.markdown:
        Path(args.markdown).write_text(render_markdown(entries, summary, ci, timings), encoding="utf-8")
        print(f"wrote {args.markdown}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
