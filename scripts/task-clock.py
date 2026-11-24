"""Record when a sprint task starts and finishes, from the clock -- never from a typed time (F363, Sprint 86).

The task clock. Every Phase 4-5 task is started and finished with this script; the gates in
.claude/hooks/task-clock-gate.py refuse an edit with no task open and a task-closing commit with no finish,
and close-out check 3d-3 refuses a card whose minutes do not match the ledger. Subagent tasks are started and
stopped by the gate hook itself when the Agent prompt names `Task <N>`; `finish` is still run at handback.

Usage:
    python scripts/task-clock.py start  <task> [--root DIR]
    python scripts/task-clock.py stop   <task> [--root DIR]          end one work segment (interleaved tasks)
    python scripts/task-clock.py finish <task> --model TEXT [--note TEXT] [--root DIR]
    python scripts/task-clock.py status [--root DIR]

`finish` closes every open segment of the task, records the finish time, and then writes, from the ledger:
  - the task card's `**Executed-by**:` line in docs/sprints/SPRINT_<N>_PLAN.md: "<model> -- <M> min (task clock
    <start> to <finish>, <k> segment(s))[; <note>]";
  - the task's row in the CODING_VELOCITY.md Coverage Ledger (Est from the card's Est-Effort line);
  - current_sprint.task_status[<task>] = "DONE" in .claude/sprint_status.json;
and prints the end-of-task checklist (R-5), each line OK or FAIL. Exit 0 when every line is OK.

Exit codes: 0 done; 1 a checklist line failed or the task was not found; 2 this script could not run (no
sprint_status.json found, an unreadable ledger, bad arguments). The ledger is
docs/sprints/SPRINT_<N>_TASK_CLOCK.json (committed with the sprint).

What this does NOT catch: a task that was worked on with no segment open (the edit gate covers tracked files;
a task done only in conversation is caught at close-out, check 3d-3); a wrong --model text.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / ".claude" / "hooks" / "lib"))
import task_clock as tc  # noqa: E402

VELOCITY = Path("docs") / "CODING_VELOCITY.md"
VELOCITY_HEADER = "| Item | Sprint | Status | Est-Effort | Est-Wall | Act-Effort | Act-Wall | Notes |"
EXECUTED_BY_LINE = re.compile(r"^(\s*(?:-\s*)?\*\*Executed-by\*\*:?)(.*)$", re.M)
EST_LINE = re.compile(r"^\*\*Est-Effort\*\*:\s*(.+)$", re.M)
EST_RANGE = re.compile(r"(\d+)(?:\s*-\s*(\d+))?\s*m")


class Failure(Exception):
    """This script could not run (exit 2)."""


def resolve(root_arg: str | None) -> tuple[Path, int, dict]:
    root = tc.find_root(root_arg or Path.cwd())
    if root is None:
        raise Failure("no .claude/sprint_status.json found at or above the folder (use --root)")
    status = tc.read_status(root)
    return root, tc.current_sprint_number(status), status


def cmd_start(root: Path, sprint: int, task: str, now=None) -> int:
    ledger = tc.load(root, sprint)
    if ledger["tasks"].get(task, {}).get("finished"):
        print(f"Task {task} is already finished ({tc.show(ledger['tasks'][task]['finished'])}); not reopened.")
        return 1
    changed = tc.start(ledger, task, "main", now)
    tc.save(root, sprint, ledger)
    entry = ledger["tasks"][task]
    print(f"Task {task} {'started' if changed else 'already running'}: segment open since "
          f"{tc.show([s for s in entry['segments'] if s['end'] is None and s['by'] == 'main'][-1]['start'])}.")
    return 0


def cmd_stop(root: Path, sprint: int, task: str, now=None) -> int:
    ledger = tc.load(root, sprint)
    closed = tc.stop(ledger, task, by="main", now=now)
    tc.save(root, sprint, ledger)
    print(f"Task {task}: {closed} segment(s) stopped.")
    return 0 if closed else 1


def card_est(section: str) -> str:
    found = EST_LINE.search(section)
    if not found:
        return "--"
    numbers = EST_RANGE.search(found.group(1))
    if not numbers:
        return "--"
    return f"{numbers.group(1)}-{numbers.group(2)}" if numbers.group(2) else numbers.group(1)


def write_executed_by(root: Path, sprint: int, task: str, value: str) -> str:
    path = tc.plan_path(root, sprint)
    text = path.read_text(encoding="utf-8")
    span = tc.card_section(text, task)
    if span is None:
        raise LookupError(f"no '### Task {task} --' card in {path.name}")
    section = text[span[0]:span[1]]
    found = EXECUTED_BY_LINE.search(section)
    if not found:
        raise LookupError(f"Task {task} card has no '**Executed-by**' line")
    new_section = section[:found.start()] + found.group(1) + " " + value + section[found.end():]
    path.write_text(text[:span[0]] + new_section + text[span[1]:], encoding="utf-8", newline="\n")
    return section


def write_velocity_row(root: Path, sprint: int, task: str, title: str, est: str, total: int, notes: str) -> None:
    path = root / VELOCITY
    lines = path.read_text(encoding="utf-8").split("\n")
    try:
        head = lines.index(VELOCITY_HEADER)
    except ValueError as exc:
        raise LookupError(f"{VELOCITY} has no Coverage Ledger header") from exc
    end = head + 2
    while end < len(lines) and lines[end].startswith("|"):
        end += 1
    label = f"Task {task}: {title}"
    row = f"| {label} | {sprint} | DONE | {est} | {est} | {total} | {total} | {notes} |"
    prefix = f"| Task {task}: "
    for index in range(head + 2, end):
        cells = lines[index].split("|")
        if lines[index].startswith(prefix) and len(cells) > 2 and cells[2].strip() == str(sprint):
            lines[index] = row
            break
    else:
        lines.insert(end, row)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_status(root: Path, task: str) -> None:
    path = root / tc.STATUS_FILE
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    data["current_sprint"].setdefault("task_status", {})[task] = "DONE"
    path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def checklist(root: Path, sprint: int, task: str, total: int) -> list:
    """The R-5 end-of-task lines as (ok, text)."""
    lines = []
    ledger = tc.load(root, sprint)
    entry = ledger["tasks"].get(task, {})
    lines.append((bool(tc.first_start(entry)), f"ledger start: {tc.show(tc.first_start(entry))}"))
    lines.append((bool(entry.get("finished")), f"ledger finish: {tc.show(entry.get('finished'))}"))
    lines.append((total > 0, f"ledger minutes: {total}"))
    velocity = (root / VELOCITY).read_text(encoding="utf-8")
    row = re.search(rf"^\| Task {re.escape(task)}: [^\n]*\| {sprint} \| DONE \|[^\n]*$", velocity, re.M)
    lines.append((bool(row) and f"| {total} | {total} |" in (row.group(0) if row else ""),
                  "CODING_VELOCITY Coverage Ledger row with the ledger minutes"))
    plan = tc.plan_path(root, sprint).read_text(encoding="utf-8")
    span = tc.card_section(plan, task)
    found = EXECUTED_BY_LINE.search(plan[span[0]:span[1]]) if span else None
    lines.append((bool(found) and f"{total} min" in found.group(2), "plan Executed-by line names the ledger minutes"))
    status = tc.read_status(root)
    lines.append((status["current_sprint"].get("task_status", {}).get(task) == "DONE",
                  "sprint_status.json task_status DONE"))
    return lines


def cmd_finish(root: Path, sprint: int, task: str, model: str, note: str | None, now=None) -> int:
    ledger = tc.load(root, sprint)
    entry = ledger["tasks"].get(task)
    if not entry or not entry["segments"]:
        print(f"FAIL Task {task} has no start in the ledger; run 'start' when work begins (it cannot be backdated).")
        return 1
    plan_text = tc.plan_path(root, sprint).read_text(encoding="utf-8")
    span = tc.card_section(plan_text, task)
    if span is None:
        print(f"FAIL no '### Task {task} --' card in {tc.plan_path(root, sprint).name}")
        return 1
    if not EXECUTED_BY_LINE.search(plan_text[span[0]:span[1]]):
        # Checked BEFORE the ledger is touched, so a refused finish leaves no half-written state.
        print(f"FAIL Task {task} card has no '**Executed-by**' line; add one, then run finish again")
        return 1
    stamp = tc.now_text(now)
    for _key, segment in tc.open_segments(ledger, task):
        segment["end"] = stamp
    entry["finished"] = entry.get("finished") or stamp
    total = tc.minutes(entry)
    tc.save(root, sprint, ledger)

    heading = tc.CARD_HEADING.search(plan_text, span[0])
    title = re.sub(r"\s*\(Priority[^)]*\).*$", "", heading.group(2)).strip()
    cards = {t: c for c, t in tc.card_map(plan_text).items()}
    if task in cards:
        title += f" (#{cards[task]})"
    started, finished = tc.show(tc.first_start(entry)), tc.show(entry["finished"])
    count = len(entry["segments"])
    value = f"{model} -- {total} min (task clock {started} to {finished}, {count} segment(s))"
    if note:
        value += f"; {note}"
    write_executed_by(root, sprint, task, value)
    notes = f"Task clock (F363): started {started}, finished {finished}, {count} segment(s). {model}."
    if note:
        notes += f" {note}"
    write_velocity_row(root, sprint, task, title.replace("|", "/"), card_est(plan_text[span[0]:span[1]]), total,
                       notes.replace("|", "/"))
    write_status(root, task)

    failed = 0
    print(f"Task {task} finished: {total} min.")
    for ok, text in checklist(root, sprint, task, total):
        print(f"  {'OK  ' if ok else 'FAIL'} {text}")
        failed += 0 if ok else 1
    return 1 if failed else 0


def cmd_status(root: Path, sprint: int, now=None) -> int:
    ledger = tc.load(root, sprint)
    if not ledger["tasks"]:
        print(f"Sprint {sprint}: no task started.")
        return 0
    for key in sorted(ledger["tasks"], key=lambda k: (len(k), k)):
        entry = ledger["tasks"][key]
        running = [s["by"] for s in entry["segments"] if s.get("end") is None]
        state = "finished " + tc.show(entry["finished"]) if entry.get("finished") else (
            "running (" + ", ".join(running) + ")" if running else "stopped")
        print(f"Task {key}: {state}; started {tc.show(tc.first_start(entry))}; {tc.minutes(entry, now)} min")
    return 0


def main(argv: list | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sprint task clock (F363).")
    parser.add_argument("action", choices=["start", "stop", "finish", "status"])
    parser.add_argument("task", nargs="?")
    parser.add_argument("--model")
    parser.add_argument("--note")
    parser.add_argument("--root")
    args = parser.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        if args.action != "status" and not (args.task and args.task.isdigit()):
            raise Failure("a task number is required, for example: start 3")
        if args.action == "finish" and not args.model:
            raise Failure("finish needs --model (the model that executed the task, e.g. 'Opus main session')")
        root, sprint, _status = resolve(args.root)
        if args.action == "start":
            return cmd_start(root, sprint, args.task)
        if args.action == "stop":
            return cmd_stop(root, sprint, args.task)
        if args.action == "finish":
            return cmd_finish(root, sprint, args.task, args.model, args.note)
        return cmd_status(root, sprint)
    except (Failure, tc.LedgerError) as exc:
        print(f"task-clock: {exc}", file=sys.stderr)
        return 2
    except (LookupError, OSError, KeyError, ValueError) as exc:
        print(f"FAIL {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
