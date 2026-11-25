"""Print the fixed parts of a subagent prompt, taken from the repository, never from memory (F344, Sprint 86).

Every prompt that starts a subagent pastes the same two fixed parts. Doing it by hand is how a brief went out
without them (Sprint 75: the prompts without the checklist returned work that did not compile or passed vacuously).
Callers: the 7.7.1 code-reviewer prompt, the 7.7.1 silent-failure-hunter prompt, the 7.7.1 improvement review, the
background CI-fix agent, a delegated task from Phase 4.1, and the SPRINT_PLANNING.md delegation checklist (item 8).

Usage:
    python scripts/subagent-brief.py block [--task NAME] [--scratch PATH] [--doc PATH]
    python scripts/subagent-brief.py files [--range A...B] [--root DIR]

block   prints the "PROGRESS AND RESTART (apply to yourself)" block, read from the fenced block in
        docs/SPRINT_EXECUTION_WORKFLOW.md, so the paste is byte for byte the canonical text. --task replaces
        <task-name>, --scratch replaces <SCRATCH> (the session scratchpad path). Without them the placeholders stay.
files   prints "Files to review (N):" and the files the review must read, then the exclusion sentence, from
        `git diff --name-only --diff-filter=d <range>`: deleted files are left out (a reviewer cannot read them),
        the `0*` files at the repo root and everything under `archive/` are listed as Excluded, not given.
        --range defaults to origin/develop...HEAD (the 7.7.1 review); the improvement review passes
        `<last 7.7.1 fix commit>..HEAD`. Each reviewer's report must end "Files read: M of N" against this N.

Exit codes: 0 printed; 1 `files` found nothing to review (an empty range, or only excluded files: the message says
which); 2 this script could not run (the doc or the block is missing or incomplete, git failed or the range is
bad, bad arguments).

What this does NOT catch: whether the reviewer actually READ the files it was given (the reviewer's "Files read:
M of N" line is checked by a person); a reviewer prompt written without calling this script; a changed file whose
name starts with `0` but is not a Harold working document at the repo root is excluded too (the rule is by
name, as CLAUDE.md states it); an untracked or uncommitted file (the range sees commits only).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

DEFAULT_DOC = REPO / "docs" / "SPRINT_EXECUTION_WORKFLOW.md"
BLOCK_START = "PROGRESS AND RESTART (apply to yourself)"
BLOCK_RULES = ("FIRST ACTION: read", "STATUS: FINISHED", "MUTATION LOCK", "NEVER repeat a release or store action",
               "Resumed:")
DEFAULT_RANGE = "origin/develop...HEAD"
EXCLUSION_SENTENCE = ("Do not read or report on the `0*` files at the repo root (Harold's working documents) or "
                      "anything under `archive/`.")


class Failure(Exception):
    """This script could not run (exit 2)."""


def extract_block(doc_text: str) -> str:
    """The canonical block: from BLOCK_START to the closing code fence. Raises Failure if absent or cut short."""
    start = doc_text.find(BLOCK_START)
    if start < 0:
        raise Failure(f'the block "{BLOCK_START}" is not in the document')
    end = doc_text.find("```", start)
    if end < 0:
        raise Failure("the block is not closed by a code fence")
    block = doc_text[start:end].rstrip() + "\n"
    missing = [rule for rule in BLOCK_RULES if rule not in block]
    if missing:
        raise Failure("the block lost a required rule: " + "; ".join(missing))
    return block


def cmd_block(args: argparse.Namespace) -> int:
    doc = Path(args.doc) if args.doc else DEFAULT_DOC
    try:
        text = doc.read_bytes().decode("utf-8-sig")
    except OSError as exc:
        raise Failure(f"cannot read {doc}: {exc}") from exc
    block = extract_block(text.replace("\r\n", "\n"))
    if args.task:
        block = block.replace("<task-name>", args.task)
    if args.scratch:
        block = block.replace("<SCRATCH>", args.scratch)
    sys.stdout.write(block)
    return 0


def is_excluded(path: str) -> bool:
    low = path.lower()
    return low.startswith("archive/") or ("/" not in path and path.startswith("0"))


def split_files(names: list) -> tuple[list, list]:
    """(to review, excluded), each sorted, from changed file names."""
    given = sorted(n for n in names if not is_excluded(n))
    excluded = sorted(n for n in names if is_excluded(n))
    return given, excluded


def cmd_files(args: argparse.Namespace) -> int:
    root = Path(args.root) if args.root else REPO
    code, out = common.git("-c", "core.quotepath=false", "diff", "--name-only", "--diff-filter=d", args.range,
                           cwd=root, timeout=60)
    if code != 0:
        raise Failure(f"git diff failed (exit {code}) for range {args.range!r} in {root}; "
                      "is the range spelled right and is it a git repository?")
    names = [line.strip().replace("\\", "/") for line in out.splitlines() if line.strip()]
    given, excluded = split_files(names)
    if not given:
        why = (f"only excluded files changed ({len(excluded)})" if excluded
               else "no file changed in that range")
        print(f"FAIL nothing to review in {args.range}: {why}.")
        return 1
    print(f"Files to review ({len(given)}):")
    for name in given:
        print(f"- {name}")
    if excluded:
        print(f"Excluded ({len(excluded)}): " + ", ".join(excluded))
    print(EXCLUSION_SENTENCE)
    print(f'End your report with "Files read: M of {len(given)}" and name every file you did not read, with the reason.')
    return 0


def main(argv: list | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Print the fixed parts of a subagent prompt.")
    sub = parser.add_subparsers(dest="action", required=True)
    block = sub.add_parser("block", help="print the Progress and restart block")
    block.add_argument("--task", help="replaces <task-name>")
    block.add_argument("--scratch", help="replaces <SCRATCH>")
    block.add_argument("--doc", help="document holding the block (default: SPRINT_EXECUTION_WORKFLOW.md)")
    files = sub.add_parser("files", help="print the files a review must read")
    files.add_argument("--range", default=DEFAULT_RANGE, help=f"git range (default: {DEFAULT_RANGE})")
    files.add_argument("--root", help="repository folder (default: this repository)")
    args = parser.parse_args(argv)
    try:
        return cmd_block(args) if args.action == "block" else cmd_files(args)
    except Failure as exc:
        print(f"subagent-brief: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
