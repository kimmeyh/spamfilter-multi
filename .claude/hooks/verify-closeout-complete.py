"""Stop hook: block a turn that CLAIMS sprint close-out is complete while close-out artifacts are stale or missing.

Python port of verify-closeout-complete.ps1 (F327, Sprint 84; ADR-0051, F321 layer). Same interface:
exit 0 allow, exit 2 block (stderr to Claude), bypass = a branch name containing `allow_stop_hook_bypass`,
test overrides in the payload (`branch_override`, `repo_override`, `dirty_zero_files_override`,
`skip_git_checks`). Every check keeps its number and message text (3a, 3a-1, 3a-2, 3d, 3e, 3d-2, 3d-3,
3b, 3b-2, 3c); SPRINT_CHECKLIST.md and CLAUDE.md cite them.

Port rules (R-4): parsing is carried over exactly, not improved.
  - Markdown is read as BYTES and decoded utf-8-sig, so CR and CRLF survive (Python's text mode would turn
    CRLF into LF and hide the carriage return the PowerShell regexes saw).
  - PowerShell `-match` is case-insensitive, so every pattern that used it (or an inline `(?i)`) gets
    re.IGNORECASE here; the inline `(?i)` is a flag, because Python 3.11 rejects one that is not at the start.
  - Check 3d-2 reads the FIRST line of the 7.7.1 bullet only through the same regex the PowerShell used.

Fail-open and failure rules (R-3, R-6):
  - `git` and `gh` go through common.git and common.gh, which never raise. A missing or slow gh skips the
    GitHub check, exactly as the PowerShell `catch { }` did.
  - Nothing else is swallowed. An unexpected exception reaches hooklib.run, which prints a one-line
    "internal error" notice and exits 1 (a visible hook error, the action is not silently passed).

Tests: .claude/hooks/test-cases/closeout/ (run-test-cases.ps1) and .claude/hooks/tests/test_pylib.py.
"""
import json
import os
import re
import sys
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402

I = re.IGNORECASE
M = re.MULTILINE

# ----- Gate 2: close-out claim patterns (PowerShell -match: case-insensitive) --------------------------
CLAIM_PATTERNS = [re.compile(p, I) for p in (
    r"\b(the\s+)?(sprint|phase\s*7|close[- ]?out|post[- ]?merge)\s+(work\s+|process\s+)?(is|was)\s+(now\s+)?(fully\s+|genuinely\s+)?(complete|closed|done|finished)\b",
    r"\bclose[- ]?out\b[^.\n]{0,40}\b(is|was)\s+(now\s+)?(complete|done|finished)\b",
    r"\ball\s+(the\s+)?(post[- ]?merge|checklist|close[- ]?out)\s+(items|steps)\b[^.\n]{0,40}\b(are\s+)?(now\s+)?(complete|done)\b",
    r"\beverything\s+(through|in)\s+the\s+(post[- ]?merge|checklist)\b",
    r"\bready\s+for\s+(the\s+)?next\s+sprint\b",
    r"\bsprint\s+\d+\s+is\s+(fully\s+)?(closed|complete)\b",
)]
MID_SPRINT_PATTERNS = [re.compile(p, I) for p in (
    r"\b(task|tier)\s+\d+\b[^.\n]{0,40}\b(blocked|in progress|not started|remaining|pending)\b",
    r"\bstopping criterion\s*\d",
    r"\b(is|remains)\s+blocked\b",
    r"\bsprint\s+status\b",
    r"\bstill\s+(executing|in\s+flight|running)\b",
)]

BRANCH_BYPASS = re.compile(r"allow_stop_hook_bypass", I)
SPRINT_BRANCH = re.compile(r"^feature/\d+_Sprint_(\d+)", I)
FIXTURE_CWD = re.compile(r"[\\/]test-cases[\\/]fixtures[\\/]", I)

EVIDENCE = (
    ("5.1.2 F-PRECHECK record", re.compile(r"F-PRECHECK", I)),
    ("5.1.5 WinWright sweep artifact", re.compile(r"WinWright[\s\S]{0,200}?sweep|sweep[\s\S]{0,200}?WinWright", I)),
)
SWEEP_HEAD = re.compile(r"^[\s>*_`-]*sweep-head:[\s`*_]*([0-9a-f]{7,40})\b", I | M)
FINAL_REVIEWS = re.compile(r"^\s*-\s*\**\s*7\.7\.1\b[^:\r\n]*\**\s*:\s*(.*)$", I | M)
PENDING_VALUE = re.compile(r"^[\s*_`]*PENDING", I)
IMPROVEMENT_REVIEW = re.compile(r"improvement review", I)
EXECUTED_BY = re.compile(r"^\s*(?:-\s*)?\*\*Executed-by\*\*(.*)$", I | M)
EXECUTED_BY_MINUTES = re.compile(r"(~\s*\d+\s*m\b|\d+\s*(min|mins|minutes)\b)", I)
EXECUTED_BY_PLACEHOLDER = re.compile(r"^(PENDING|TBD|TODO)$", I)
TASK_CARD = re.compile(r"^#{2,3}\s+Task\s+\S+\s+--", I | M)


# ----- helpers -----------------------------------------------------------------------------------------
def read_markdown(path: str) -> str:
    """File text as the PowerShell Get-Content -Raw saw it: BOM removed, line endings untouched."""
    with open(path, "rb") as handle:
        return handle.read().decode("utf-8-sig", errors="replace")


def _truthy(value) -> bool:
    """PowerShell truthiness of a JSON value: null, empty string, 0, false and an empty list are false."""
    if isinstance(value, (list, dict, str)):
        return len(value) > 0
    return bool(value)


def _eq_true(value) -> bool:
    """PowerShell `$x -eq $true`: true for JSON true, the number 1 and the text 'true' (any case)."""
    if value is True:
        return True
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return value == 1
    if isinstance(value, str):
        return value.lower() == "true"
    return False


def _ps_int(value) -> int:
    """PowerShell `[int]$x`: null is 0; text is parsed; garbage raises ValueError (the PowerShell cast threw)."""
    if value is None:
        return 0
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return round(value)
    if isinstance(value, str):
        text = value.strip()
        try:
            return int(text)
        except ValueError:
            return round(float(text))
    raise ValueError(f"cannot convert {type(value).__name__} to int")


def _sprint_of(status):
    sprint = status.get("current_sprint") if isinstance(status, dict) else None
    return sprint if isinstance(sprint, dict) else None


def _plan_approved(status) -> bool:
    sprint = _sprint_of(status)
    return sprint is not None and _eq_true(sprint.get("plan_approved"))


def last_message(payload: dict) -> str:
    if _truthy(payload.get("last_assistant_message")):
        return str(payload["last_assistant_message"])
    messages = payload.get("messages")
    if _truthy(messages) and isinstance(messages, list):
        assistant = [m for m in messages if isinstance(m, dict) and m.get("role") == "assistant"]
        if assistant:
            content = assistant[-1].get("content")
            return "" if content is None else str(content)
    return ""


def claims_closeout(message: str) -> bool:
    if not any(p.search(message) for p in CLAIM_PATTERNS):
        return False
    return not any(p.search(message) for p in MID_SPRINT_PATTERNS)


def _status_age_days(text: str):
    """Days since `_last_updated`, or None when the text is not a date (the PowerShell skipped it)."""
    try:
        parsed = common.parse_utc(text)
    except ValueError:
        try:
            return (datetime.now() - datetime.strptime(str(text).strip(), "%Y-%m-%d")).total_seconds() / 86400
        except ValueError:
            return None
    if re.search(r"(Z|[+-]\d{2}(:?\d{2})?)\s*$", str(text), I):
        return (common.utc_now() - parsed).total_seconds() / 86400
    # No offset: the PowerShell [datetime] cast read it as LOCAL time.
    local = parsed.replace(tzinfo=None).astimezone()
    return (common.utc_now() - local).total_seconds() / 86400


# ----- the checks --------------------------------------------------------------------------------------
def check_status(cwd: str, sprint_num: int, violations: list):
    """3a: sprint_status.json currency. Returns the parsed status (None when missing or invalid)."""
    status_path = os.path.join(cwd, ".claude/sprint_status.json")
    if not os.path.exists(status_path):
        violations.append(".claude/sprint_status.json is MISSING (SPRINT_CHECKLIST.md Phase 7.7 requires it).")
        return None
    status = None
    try:
        status = json.loads(read_markdown(status_path))
        sprint = _sprint_of(status)
        status_sprint = _ps_int(sprint.get("number") if sprint else None)
        if status_sprint != sprint_num:
            violations.append(
                f".claude/sprint_status.json current_sprint.number is {status_sprint} but the branch is Sprint {sprint_num} "
                "-- the file is stale. It is the state-restore file after context compaction, so a stale copy actively "
                "misleads the next session.")
        # PR #418 review: a checked-in test fixture hardcodes a date and ages past 30 days on the calendar alone,
        # so only a LIVE status file can be stale.
        is_fixture = bool(FIXTURE_CWD.search(cwd))
        last_updated = status.get("_last_updated") if isinstance(status, dict) else None
        if _truthy(last_updated) and not is_fixture:
            age = _status_age_days(str(last_updated))
            if age is not None and age > 30:
                violations.append(f".claude/sprint_status.json _last_updated is {age:,.0f} days old.")
    except (OSError, ValueError, TypeError):
        violations.append(".claude/sprint_status.json is not valid JSON.")
    return status if isinstance(status, dict) else None


def check_pr_recorded(status, sprint_num: int, violations: list):
    """3a-1: the sprint PR exists once the plan is approved (Phase 3.3.1 deliverable)."""
    if status is None or not _plan_approved(status):
        return
    pr_num = _sprint_of(status).get("pr_number")
    if pr_num is None or str(pr_num) == "":
        violations.append(
            f"No pull request recorded for Sprint {sprint_num} (.claude/sprint_status.json current_sprint.pr_number is null) "
            "even though plan_approved is true. Phase 3.3.1 requires a DRAFT PR created at plan approval, in parallel with "
            "the first execution task. Create it (gh pr create --draft --base develop) and record pr_number / pr_url. "
            "Keep it a DRAFT until the 7.7.5 final gate (after the 7.7.1 reviews, the retrospective and the improvement review).")


def check_zero_files(payload: dict, cwd: str, violations: list):
    """3a-2: uncommitted non-coding-agent working files (0*.txt / 0*.md at the repo root)."""
    items = None
    override = payload.get("dirty_zero_files_override")
    if override is not None:
        text = str(override)
        items = [text] if text.strip() else None
    else:
        _code, out = common.git("status", "--porcelain", "--", "0*", cwd=cwd)
        lines = [line for line in out.splitlines() if line]
        items = lines or None
    if items:
        names = ", ".join(re.sub(r"^..\s*", "", item).strip() for item in items)
        violations.append(
            f"Uncommitted non-coding-agent working file(s) at repo root: {names}. These are Harold's 0* working documents "
            "and are expected to be committed (they have been, every sprint). Stage and commit them -- do NOT read them "
            "(the deny-list blocks it), so use a neutral message rather than paraphrasing content you cannot see.")


def check_phase5_evidence(payload: dict, status, cwd: str, sprint_num: int, violations: list):
    """3d (Sprint 63+): Phase 5 evidence markers in the plan; 3e: sweep-head versus later lib/ui commits."""
    if not (sprint_num >= 63 and status is not None and _plan_approved(status)):
        return
    plan_path = os.path.join(cwd, f"docs/sprints/SPRINT_{sprint_num}_PLAN.md")
    if not os.path.exists(plan_path):
        return
    plan_text = read_markdown(plan_path)
    for name, pattern in EVIDENCE:
        if not pattern.search(plan_text):
            violations.append(
                f"Phase 5 evidence missing from SPRINT_{sprint_num}_PLAN.md: no {name}. SPRINT_CHECKLIST.md Phase 5 requires "
                "all three BEFORE Manual Validation; a close-out claim with any of them absent means Phase 5 was skipped, "
                "not finished (Sprint 62 escape: the post-hoc review then found a real bug after Harold had already validated).")

    if _truthy(payload.get("skip_git_checks")):
        return
    match = SWEEP_HEAD.search(plan_text)
    if match:
        sweep_head = match.group(1)
        code, newer_ui = common.git("log", "--oneline", f"{sweep_head}..HEAD", "--", "mobile-app/lib/ui", cwd=cwd)
        lines = [line for line in newer_ui.splitlines() if line]
        if code == 0 and lines:
            violations.append(
                f"The WinWright sweep artifact records sweep-head: {sweep_head}, but lib/ui commits exist AFTER it: "
                f"{len(lines)} commit(s). The sweep proved an OLDER UI; re-run it at HEAD and update sweep-head (this is the "
                "Sprint 61 F169 rot class -- a UI change shipped after the last sweep).")
    else:
        code, ui_changed = common.git("diff", "--name-only", "origin/develop...HEAD", "--", "mobile-app/lib/ui", cwd=cwd)
        if code != 0:
            code, ui_changed = common.git("diff", "--name-only", "develop...HEAD", "--", "mobile-app/lib/ui", cwd=cwd)
        if ui_changed.strip():
            violations.append(
                f"This sprint changed mobile-app/lib/ui but SPRINT_{sprint_num}_PLAN.md's sweep artifact records no "
                "'sweep-head: <hash>' line. Record the commit the sweep ran at so close-out can prove the sweep covered the "
                "FINAL UI (Sprint 62 retro IMP-2).")


def check_final_reviews(status, cwd: str, sprint_num: int, violations: list):
    """3d-2 (Sprint 77+): the 7.7.1 final code reviews bullet carries evidence (first line only)."""
    if not (sprint_num >= 77 and status is not None and _plan_approved(status)):
        return
    plan_path = os.path.join(cwd, f"docs/sprints/SPRINT_{sprint_num}_PLAN.md")
    if not os.path.exists(plan_path):
        return
    match = FINAL_REVIEWS.search(read_markdown(plan_path))
    if not match:
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md has no '- **7.7.1 final code reviews**: <evidence>' line. Phase 7.7.1 runs BOTH "
            "final reviews (Copilot requested by hand + pr-review-toolkit code-reviewer and silent-failure-hunter) as soon "
            "as Manual Validation is complete, before the retrospective -- and their findings must be dispositioned before "
            "the PR is announced ready (SPRINT_EXECUTION_WORKFLOW.md 7.7.1).")
        return
    value = match.group(1).strip()
    if not value.strip() or PENDING_VALUE.search(value):
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md's 7.7.1 final code reviews marker reads '{value}'. Run both final reviews "
            "(Copilot + pr-review-toolkit) now, disposition every finding, and record the evidence on that line "
            "(SPRINT_EXECUTION_WORKFLOW.md 7.7.1).")
    elif sprint_num >= 81 and not IMPROVEMENT_REVIEW.search(value):
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md's 7.7.1 final code reviews line does not record the improvement review. After the "
            "retrospective improvements are pushed, run pr-review-toolkit code-reviewer + silent-failure-hunter on ONLY "
            "those commits and add 'improvement review <result>' (or 'improvement review: no improvement commits') to that "
            "line. One pass only: fix findings under 4 code files and 600 lines, file larger ones for the next sprint "
            "(SPRINT_EXECUTION_WORKFLOW.md 7.7.1).")


def check_executed_by(status, cwd: str, sprint_num: int, violations: list):
    """3d-3 (Sprint 77+): every task card's Executed-by line is filled, with minutes from Sprint 78."""
    if not (sprint_num >= 77 and status is not None and _plan_approved(status)):
        return
    plan_path = os.path.join(cwd, f"docs/sprints/SPRINT_{sprint_num}_PLAN.md")
    if not os.path.exists(plan_path):
        return
    plan_text = read_markdown(plan_path)
    empty = 0
    no_minutes = 0
    matches = list(EXECUTED_BY.finditer(plan_text))
    for found in matches:
        value = found.group(1)
        value = re.sub(r"<!--.*?-->", "", value, flags=I)
        value = re.sub(r"<[^>]*>", "", value, flags=I)
        value = re.sub(r"\(fill(ed)? at completion\)", "", value, flags=I)
        # A bare "m" counts only after "~" (7.7.1 silent-failure L-2), judged BEFORE the strip below.
        if sprint_num >= 78 and not EXECUTED_BY_MINUTES.search(value):
            no_minutes += 1
        value = re.sub(r"[\s:*_`-]", "", value, flags=I)
        if not value.strip() or EXECUTED_BY_PLACEHOLDER.search(value):
            empty += 1
    if no_minutes > 0:
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md has {no_minutes} '**Executed-by**' line(s) with no actual minutes. Each line records "
            "the model AND its actual minutes (e.g. 'Sonnet agent ~23 min + lead ~12 = ~35 min'), copied from the "
            "CODING_VELOCITY.md row written at task completion (Sprint 78 retro IMP-1).")
    card_count = len(TASK_CARD.findall(plan_text))
    if empty > 0:
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md has {empty} task card(s) whose '**Executed-by**' line is still empty, a template "
            "placeholder, or '(filled at completion)'. Record the model that executed each task and its actual minutes "
            "(from the CODING_VELOCITY.md row) before close-out -- actuals are never left empty (Sprint 77 retro IMP-3).")
    if card_count > len(matches):
        violations.append(
            f"SPRINT_{sprint_num}_PLAN.md has {card_count} task card(s) but only {len(matches)} '**Executed-by**' line(s). "
            "Every card records the model that executed it and its actual minutes before close-out (Sprint 77 retro IMP-3).")


def check_previous_summary(cwd: str, sprint_num: int, violations: list):
    """3b: the previous sprint's SUMMARY exists once its RETROSPECTIVE does (Phase 3.2.1)."""
    prev = sprint_num - 1
    if prev <= 0:
        return
    summary = os.path.join(cwd, f"docs/sprints/SPRINT_{prev}_SUMMARY.md")
    retro = os.path.join(cwd, f"docs/sprints/SPRINT_{prev}_RETROSPECTIVE.md")
    if os.path.exists(retro) and not os.path.exists(summary):
        violations.append(f"docs/sprints/SPRINT_{prev}_SUMMARY.md is missing (Phase 3.2.1 MANDATORY -- 'do not defer').")


def check_velocity_rows(cwd: str, sprint_num: int, violations: list):
    """3b-2: CODING_VELOCITY.md has at least one Actuals Log row for this sprint (Sprint 65 retro IMP-1)."""
    path = os.path.join(cwd, "docs/CODING_VELOCITY.md")
    if not os.path.exists(path):
        return
    if not re.search(rf"\|\s*{sprint_num}\s*\|\s*DONE\s*\|", read_markdown(path), I):
        violations.append(
            f"docs/CODING_VELOCITY.md has NO Actuals Log row for Sprint {sprint_num}. Rule 4 is a coverage guarantee -- every "
            "implemented Item gets a row, recorded AT TASK COMPLETION, not batched at sprint end. Rule 6 makes it a Phase 7 "
            "exit gate. Without actuals this sprint contributes nothing to the estimate table, which is the entire purpose "
            "of the tracker, and the next sprint's estimates are guesses again. Add a row per Item: "
            f"| <Item> | {sprint_num} | DONE | <est> | <est-wall> | <act> | <act-wall> | <notes> |")


def check_open_issues(cwd: str, violations: list, notices=None):
    """3c: open sprint-labeled GitHub issues, POST-MERGE ONLY. Any git or gh failure skips the check.

    Sprint 84 5.1.2 F6-1: a gh failure still fails OPEN, but adds a notice to `notices` so the user
    learns that check 3c did not run (a silent skip looked the same as "no open cards")."""
    if notices is None:
        notices = []

    def skipped(reason: str):
        notices.append(f"check 3c did not run: gh unavailable ({reason})")

    _code, remote = common.git("remote", "get-url", "origin", cwd=cwd)
    _code, remote = common.git("remote", "get-url", "origin", cwd=cwd)
    repo_url = remote.strip()
    _code, branch_out = common.git("branch", "--show-current", cwd=cwd)
    branch = branch_out.strip()
    if not repo_url or not branch:
        return
    code, pr_json = common.gh("pr", "list", "--repo", repo_url, "--head", branch, "--state", "all",
                              "--json", "state,mergedAt", cwd=cwd)
    pr_merged = False
    if code != 0:
        skipped(common.gh_failure_reason(code))
        return
    if pr_json.strip():
        try:
            prs = json.loads(pr_json)
        except ValueError:
            skipped("unreadable gh output")  # fail open, as the PowerShell catch { } did
            return
        for pr in prs if isinstance(prs, list) else []:
            if isinstance(pr, dict) and (str(pr.get("state")).lower() == "merged" or _truthy(pr.get("mergedAt"))):
                pr_merged = True
    if not pr_merged:
        return
    code, issue_json = common.gh("issue", "list", "--repo", repo_url, "--label", "sprint", "--state", "open",
                                 "--json", "number", cwd=cwd)
    if code != 0:
        skipped(common.gh_failure_reason(code))
        return
    if not issue_json.strip():
        skipped("empty gh output")
        return
    try:
        open_issues = json.loads(issue_json)
    except ValueError:
        skipped("unreadable gh output")
        return
    if isinstance(open_issues, list) and open_issues:
        nums = ", ".join(f"#{issue.get('number')}" for issue in open_issues if isinstance(issue, dict))
        violations.append(
            f"The sprint PR has MERGED but GitHub issues labeled 'sprint' are still OPEN: {nums}. Since 2026-10-14 "
            "(Sprint 79, F288) develop is the default branch, so 'Closes #N' in the sprint PR body should have closed "
            "these cards on merge. Either a card was missing from the PR body or the keyword did not match. Close the "
            "remaining cards by hand (Post-Merge Cleanup step 'Review and close all resolved GitHub issues'). Verify "
            "with `gh issue list --label sprint --state open` returning empty.")


BLOCK_TEMPLATE = """[BLOCKED by verify-closeout-complete hook]

Your final message claims sprint/phase close-out is complete, but these
SPRINT_CHECKLIST.md artifacts contradict that:

{bullets}

Required next action: open docs/SPRINT_CHECKLIST.md, walk the 'Post-Merge
Cleanup' and 'Phase 7.7 mandatory sprint completion updates' sections item by
item, and fix each violation above. Do NOT re-assert completion until every
item is verified done -- verify by CHECKING the artifact, not by recalling
whether you did it.

This hook exists because Sprint 50's close-out reported 'complete' with five
issues open, sprint_status.json 15 sprints stale, and no next-sprint stub
(Harold, 2026-07-27). The sprint-auto-advance hook could not catch it: that
one detects turns ending in a QUESTION, and this turn ended in a confident
completion claim.

Bypass (only if a violation is genuinely not applicable): rename the branch to
include 'allow_stop_hook_bypass', or state explicitly which item does not
apply and why."""


def decide(payload: dict) -> hooklib.Verdict:
    cwd = hooklib.cwd_of(payload) or os.getcwd()
    if payload.get("repo_override"):
        cwd = str(payload["repo_override"])

    message = last_message(payload)
    if not message:
        return hooklib.allow()

    # Gate 1: sprint feature branch only.
    override = str(payload.get("branch_override") or "")
    if override:
        branch = override.strip()
    else:
        _code, out = common.git("branch", "--show-current", cwd=cwd)
        branch = out.strip()
    if not branch or BRANCH_BYPASS.search(branch):
        return hooklib.allow()
    found = SPRINT_BRANCH.search(branch)
    if not found:
        return hooklib.allow()
    sprint_num = int(found.group(1))

    # Gate 2: does the message CLAIM close-out completion?
    if not claims_closeout(message):
        return hooklib.allow()

    # Gate 3: verify the machine-checkable artifacts (same order as the PowerShell).
    violations: list = []
    status = check_status(cwd, sprint_num, violations)
    check_pr_recorded(status, sprint_num, violations)
    check_zero_files(payload, cwd, violations)
    check_phase5_evidence(payload, status, cwd, sprint_num, violations)
    check_final_reviews(status, cwd, sprint_num, violations)
    check_executed_by(status, cwd, sprint_num, violations)
    check_previous_summary(cwd, sprint_num, violations)
    check_velocity_rows(cwd, sprint_num, violations)
    notices: list = []
    check_open_issues(cwd, violations, notices)

    for line in notices:
        hooklib.notice(line)   # hooklib.run delivers it: systemMessage on allow, "Note:" on a block
    if not violations:
        return hooklib.allow()
    return hooklib.block(BLOCK_TEMPLATE.format(bullets="\n".join(f"  - {v}" for v in violations)))


if __name__ == "__main__":
    hooklib.run("verify-closeout-complete", decide)
