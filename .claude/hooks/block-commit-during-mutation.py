"""PreToolUse hook: block `git commit` while a mutation-test lock is held.

Python port (F321 pilot, Sprint 83, ADR-0051) of block-commit-during-mutation.ps1.

WHY THIS EXISTS (Sprint 65, two occurrences in one sprint): a commit landed on a shared working
tree while a background agent was mid-mutation. c2ec59b captured a live probe that disabled every
demo rule; c5fb46b captured a FALSE Google Play declaration ("Is this a news app?" read Yes).
Both were diff-reviewed first and neither review caught it: a one-word change inside a large
document is exactly what diff review misses. Vigilance was not the missing ingredient; a
structural gate was. The enforcement belongs on the COMMIT side, because blocking the mutation
would stall the verification that makes tests trustworthy.

Behavior kept from the PowerShell version:
  - quoted spans are stripped before ANY matching, so a commit message that mentions the override
    token or an echoed `git commit` changes nothing;
  - `git` then any number of global options (--no-pager, --git-dir=.git, -c k=v, -C path) then
    `commit` is a commit, in any case;
  - a lock older than 15 minutes is ignored and DELETED by exact path (a crashed agent must not
    deadlock the sprint); an unparseable lock is treated as stale for the same reason;
  - the override token `allow_mutation_commit` must stand alone as its own argument.

Changes from the PowerShell version (recorded in ADR-0051 and the Sprint 83 Task 10 Result):
  - the BLOCK message goes to STDERR. The PowerShell version used Write-Host (stdout), and Claude
    Code feeds Claude the stderr of an exit-2 hook, so the reason may never have reached Claude;
  - the project folder honors the payload `cwd` when CLAUDE_PROJECT_DIR is unset (the PowerShell
    version used the process working folder), which makes the cases deterministic.

Exit 0 allow; exit 2 block. An internal error ALLOWS (hooklib.run).
Tests: .claude/hooks/test-cases/commit-lock/ (run-test-cases.ps1), .claude/hooks/tests/test_pylib.py.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402
import mutation_lock  # noqa: E402

STALE_MINUTES = 15

DQ = re.compile(r'"[^"]*"')
SQ = re.compile(r"'[^']*'")
COMMIT = re.compile(r"\bgit\b(?:\s+(?:--[^\s]+(?:=\S+)?|-c\s+\S+|-C\s+\S+))*\s+commit\b", re.I)
OVERRIDE = re.compile(r"(^|\s)allow_mutation_commit(\s|$)", re.I)

MESSAGE = """[BLOCKED] A mutation-test lock is held. Committing now risks capturing a
DELIBERATELY BROKEN file in permanent history.

Locked:
{detail}

This gate exists because it happened TWICE in Sprint 65:
  - c2ec59b committed a live probe that disabled every demo rule.
  - c5fb46b committed a FALSE Play declaration ("news app: Yes").
Both commits were diff-reviewed first. Neither review caught it, because a
one-word change inside a large document is exactly what diff review misses.

DO THIS:
  1. Wait for the agent holding the lock to restore the file and release it.
  2. Verify the tree is clean before committing:
       git diff <last-good-commit> --stat
     An EMPTY diff means the restore was byte-identical, not retyped.
  3. Re-run the commit.

If the holding agent has genuinely died, the lock self-expires after
{stale} minutes, or clear it deliberately:
    Remove-Item .claude\\mutation-locks\\*.json

Deliberate override (rare, and you must have verified the tree yourself):
add the literal token allow_mutation_commit to the command."""


def classify_locks(folder: Path, now=None):
    """Split the lock files into (active records, stale display strings, stale paths)."""
    moment = now or common.utc_now()
    active, stale_display, stale_paths = [], [], []
    for path in mutation_lock.lock_files(folder):
        try:
            record = mutation_lock.read_lock(path)
            created = common.parse_utc(record.get("createdUtc"))
        except Exception:  # noqa: BLE001 - unparseable lock is stale, never a deadlock
            stale_display.append(path.name)
            stale_paths.append(path)
            continue
        age = (moment - created).total_seconds() / 60
        if age > STALE_MINUTES:
            stale_display.append(f"{path.name} (age {int(age)}m)")
            stale_paths.append(path)
        else:
            active.append({"file": record.get("file") or "", "reason": record.get("reason") or "",
                           "agent": record.get("agent") or "", "age": int(age)})
    return active, stale_display, stale_paths


def decide(payload: dict, now=None) -> hooklib.Verdict:
    command = hooklib.command_of(payload)
    if not command:
        return hooklib.allow()
    scannable = SQ.sub("''", DQ.sub('""', command))
    if not COMMIT.search(scannable):
        return hooklib.allow()

    folder = common.find_project_root(hooklib.cwd_of(payload) or None) / mutation_lock.LOCK_SUBDIR
    if not folder.is_dir():
        return hooklib.allow()
    active, stale_display, stale_paths = classify_locks(folder, now)

    notes = []
    if stale_display:
        notes.append(f"[mutation-lock] Ignoring {len(stale_display)} stale lock(s) older than "
                     f"{STALE_MINUTES} minutes: {', '.join(stale_display)}")
        # Delete by EXACT PATH, kept apart from the display strings: matching on the display text
        # could delete an ACTIVE lock whose name shares a prefix and reopen the window.
        for path in stale_paths:
            try:
                path.unlink()
            except OSError:
                pass
    if not active:
        return hooklib.allow("\n".join(notes))

    if OVERRIDE.search(scannable):
        notes.append(f"[mutation-lock] Override token present; allowing commit despite "
                     f"{len(active)} active lock(s).")
        return hooklib.allow("\n".join(notes))

    detail = "\n".join(
        f"  - {a['file']}\n      reason: {a['reason']}\n      held by: {a['agent']} ({a['age']}m ago)"
        for a in active)
    verdict = hooklib.block(MESSAGE.format(detail=detail, stale=STALE_MINUTES))
    return verdict._replace(stdout="\n".join(notes))


if __name__ == "__main__":
    hooklib.run("block-commit-during-mutation", decide)
