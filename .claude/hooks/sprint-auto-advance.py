"""Stop hook: block a turn that ends with a procedural question or a dangling commitment while a sprint is active.

Python port of sprint-auto-advance.ps1 (F328, Sprint 84; ADR-0051, F321 layer). It enforces the Phase Auto-Advance
Rule (CLAUDE.md "Development Philosophy" item 7) and the F193 Phase 5 evidence gate. Same interface: exit 0 allow,
exit 2 block (stderr goes to Claude), bypass = a branch name containing `allow_stop_hook_bypass`, test override =
`branch_override` in the payload. The gate order, every pattern and every message are carried over unchanged:

    Gate 1   sprint feature branch only (feature/<digits>_Sprint_<N>)
    Gate 1b  the window opens at Phase 3.7 plan approval (no plan file, status plan_approved false, plan DRAFT line)
    Gate 1c  the window closes at Manual Validation (status text shape, or a retrospective file); the F193 evidence
             gate runs at that boundary and blocks a closed window whose Phase 5 artifacts are not recorded
    Gate 2   does the turn end in a question, a procedural phrase, or a dangling commitment
    Gate 3   the stopping-criteria whitelist

Port rules (R-2, R-4, R-6; the same ones verify-closeout-complete.py states):
  - PowerShell `-match` and an inline `(?i)` are case-insensitive, so every pattern here is compiled with
    re.IGNORECASE (the inline `(?i)` and `(?im)` are flags, because Python 3.11 rejects one that is not at the start).
    There is no `-cmatch` in the source, so no pattern is case-sensitive.
  - .NET allows a variable-width lookbehind; Python does not. FORM 6's `(?<!\\b(is|are|was|were|been|being)\\s)` is six
    fixed-width lookbehinds in a row, which excludes exactly the same preceding words.
  - Markdown is read as BYTES and decoded utf-8-sig, so CRLF survives (the PowerShell Get-Content -Raw saw the \\r).
  - JSON values compare the way PowerShell `-eq $true` and `-eq $false` do (see ps_eq_bool).
  - END-ANCHORED patterns (`[.!]\\s*$`) are coupled to the message's closing convention (CLAUDE.md IMP-3, Sprint 70):
    the status footer is stripped from the tail first, exactly as the PowerShell did. The cases
    violation-16, violation-24 and the footer cases added in F328 pin that.

Failure rule (R-6): ONLY the reads of sprint_status.json and of the plan's first lines keep the PowerShell
`catch { }` (an unreadable or malformed file falls through to the next gate). Anything else that raises, including
the F193 evidence evaluation that the PowerShell swallowed inside the Gate 1c try block, reaches hooklib.run, which
prints a one-line "internal error" notice and exits 1, a visible non-blocking hook error and never a silent pass.

Tests: .claude/hooks/test-cases/*.json (run-test-cases.ps1, route "(top)") and .claude/hooks/tests/test_pylib.py.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402

I = re.IGNORECASE
M = re.MULTILINE


# ----- helpers -----------------------------------------------------------------------------------------
def read_markdown(path: str) -> str:
    """File text as the PowerShell Get-Content -Raw saw it: BOM removed, line endings untouched."""
    with open(path, "rb") as handle:
        return handle.read().decode("utf-8-sig", errors="replace")


def ps_str(value) -> str:
    """PowerShell [string] cast of a JSON value: null is empty, a whole number prints without a fraction."""
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def ps_eq_bool(value, wanted: bool) -> bool:
    """PowerShell `$value -eq $true` / `$value -eq $false` for a JSON value.

    A JSON boolean compares directly; a number compares with 1 or 0 (the boolean is cast to the left operand's
    type); a string compares case-insensitively with "True" or "False"; null, a list and an object never equal."""
    if isinstance(value, bool):
        return value is wanted
    if isinstance(value, (int, float)):
        return value == (1 if wanted else 0)
    if isinstance(value, str):
        return value.lower() == ("true" if wanted else "false")
    return False


def load_status(cwd: str):
    """(status object, current_sprint dict) or (None, {}) when the file is absent, unreadable or malformed.

    The PowerShell wrapped every status read in `try { ... } catch { }`; an unreadable or malformed file falls
    through to the next gate, so this is the one place an exception is swallowed on purpose."""
    path = os.path.join(cwd, ".claude", "sprint_status.json")
    if not os.path.exists(path):
        return None, {}
    try:
        data = json.loads(read_markdown(path))
    except (OSError, ValueError):
        return None, {}
    current = data.get("current_sprint") if isinstance(data, dict) else None
    return data, current if isinstance(current, dict) else {}


# ----- Gate 1c: the status text shape that means "Manual Validation or later" ---------------------------
WINDOW_CLOSED = (
    re.compile(r"^\s*(sprint\s+\d+\s+)?(manual validation|manual-validation|phase 5\.3|phase 5\.[4-9]|phase 6|phase 7|"
               r"phase 8|retrospective|code review|awaiting harold|validation feedback|release cycle|pre-kickoff|"
               r"store release|completeness sweep|scope selection|awaiting scope)", I),
    re.compile(r"^\s*(sprint\s+\d+\s+)?(close-?out|complete[d]?\b|not planned)", I),
    re.compile(r"^[^.]{0,60}\(phase\s+(5\.[3-9]|[678])[\d.]*\s*\)", I),
)

# ----- Gate 1b (b): the plan's own DRAFT line ------------------------------------------------------------
PLAN_DRAFT_LINE = re.compile(r"^\s*\*\*Status\*\*:.*(DRAFT|awaiting .*approval|NOT APPROVED)", I)

# ----- F193 evidence markers (a bullet whose label is the marker; prose that mentions it does not count) ---
EVIDENCE_PRE = r"^\s*-\s*\**\s*{marker}\b[^:\r\n]*\**\s*:\s*(.*)$"
PLACEHOLDER = re.compile(r"^\W*(PENDING|TBD|TODO|not yet)\b", I)
BARE_NA_START = re.compile(r"^\W*N/?A\b", I)
NA_WITH_REASON = re.compile(r"^\W*N/?A\b\s*[-:(,]+\s*\S", I)
INDENTED_DETAIL = re.compile(r"^(\r?\n)+(\s{2,}\S)")
TASK_CARD = re.compile(r"^#{2,3}\s+Task\s+\S+\s+--", I | M)
PLANNING_ROW = re.compile(r"planning", I)

F193_TEMPLATE = """[BLOCKED by sprint-auto-advance -- F193 Phase 5 evidence gate]

Manual Validation is being declared for Sprint {sprint}, but these Phase 5
artifacts are not RECORDED in docs/sprints/SPRINT_{sprint}_PLAN.md:

  {names}

SPRINT_CHECKLIST.md requires them BEFORE Manual Validation starts, so that
Harold never validates unreviewed code (and, from Sprint 78, never runs a
validation step Claude has not rehearsed -- 5.1.9; from Sprint 79, never without
the tasks' CODING_VELOCITY.md actuals rows). A marker that still reads PENDING/TBD
does not count -- that placeholder exists to say the work is NOT done.

Run the missing step(s), record the evidence in the plan, then declare MV.

Why this fires here rather than at close-out: in Sprint 66 the close-out hook
caught exactly this, but only AFTER Harold had validated, the retrospective was
written, and four improvements were applied. The late review then found three
policy gates that passed while catching nothing. Sprint 62 was the same shape
and its late review found a real user-affecting bug.

If a step genuinely does not apply, record it as such WITH the reason (e.g.
"5.1.5 WinWright sweep: N/A -- no lib/ui change this sprint") rather than
leaving it PENDING.
"""

# ----- Gate 2: question-shaped phrases ---------------------------------------------------------------------
PROC_PATTERNS = [re.compile(p, I) for p in (
    r"want me to (proceed|continue|start|do|run|apply|execute|go|build|commit|push|create|update|extend|handle|follow|address|run the|skip|try)",
    r"should i (proceed|continue|start|do|run|apply|execute|go|build|commit|push|create|update|extend|handle|follow|address|ask|stop|move on)",
    r"(shall|may) i (proceed|continue|start|do|run|apply|execute|go)",
    r"ready (to|for|when) (continue|proceed|go|you|kick ?off)",
    r"awaiting (your|further|user|harold) (approval|decision|direction|input|confirmation|call|go-?ahead)",
    r"which (option|path|approach|do you)",
    r"(let|tell) me know (which|if|when|whether)",
    r"is (that|this) (ok|fine|acceptable|approved|good)",
    r"(go|any further direction|proceed)\s*\?",
    r"confirm (before|and|that)",
    r"(what|how).*(should|would) (i|you like|we)",
    r"do you want (me )?to",
    r"or (wait|defer|skip)",
)]

# The status footer ("09/18/2026 12:22am | Sprint 84 Phase 4 Execution"), removed from the tail so it cannot
# shield a commitment from the end anchor (Sprint 70 hole 2).
FOOTER = re.compile(r"^\s*\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}\s*(am|pm)\s*(\|.*)?\s*$", I | M)

# Every commitment pattern matches the ANNOUNCING PHRASE only and treats the target as opaque ([^.!?]*).
COMMITMENT_PATTERNS = [re.compile(p, I) for p in (
    # FORM 1: bare gerund, no subject. "Starting <x> now."
    r"(^|[.!?]\s+|\n)\s*[*_>#\s-]*(starting|continuing|proceeding|beginning|moving|executing|running|building|implementing|fixing|writing|creating|updating|tackling|resuming|picking up|kicking off|turning|heading|switching|diving|jumping)\b[^.!?]*[.!]\s*$",
    # FORM 2: explicit subject + modal. "I'll start <x>."
    r"\b(i|we)('ll| will|'m going to| am going to|'m| am)( now| next)? (start|begin|proceed|do|run|build|create|update|fix|implement|write|execute|extract|wire|add|move on|continue|tackle|pick up|resume|switch|turn|dive|jump)\b[^.!?]*[.!]\s*$",
    # FORM 3: hortative. "Let me start <x>." / "Let's move on."
    r"\blet('s| us| me)\b[^.!?]*\b(start|begin|proceed|do|run|move|continue|tackle|pick|resume|switch|turn|go|dive|get)\b[^.!?]*[.!]\s*$",
    # FORM 4: "next" as the operative word.
    r"(^|[.!?]\s+|\n)\s*[*_>#\s-]*next\b[^.!?]*[.!]\s*$",
    r"\b(up next|next up)\b[^.!?]*[.!]\s*$",
    r"(^|[.!?]\s+|\n)\s*[*_>#\s-]*(?!.*\b(reported|written|logged|shown|listed|described|explained|documented|covered|discussed|handled|addressed)\s+next\b)\w+(\s+\w+){0,4}\s+next[.!]\s*$",
    r"\bnext[,:]? (i|we)[^.!?]*[.!]\s*$",
    # FORM 5: directional preposition, no verb. "On to <x>."
    r"(^|[.!?]\s+|\n)\s*[*_>#\s-]*(on to|onward|onwards|off to|over to|back to)\b[^.!?]*[.!]\s*$",
    # FORM 6: verb + to/with/into target. The six lookbehinds replace one variable-width .NET lookbehind
    # `(?<!\b(is|are|was|were|been|being)\s)`: a copular verb before the gerund makes it descriptive.
    r"(?<!\bis\s)(?<!\bare\s)(?<!\bwas\s)(?<!\bwere\s)(?<!\bbeen\s)(?<!\bbeing\s)\b(proceeding|moving|continuing|switching|turning|heading|advancing|going) (to|on to|with|into|back to)\b[^.!?]*[.!]\s*$",
    # FORM 7: "now" paired with an action verb, either order.
    r"\bnow (executing|starting|beginning|building|running|implementing|fixing|writing|doing|tackling)\b[^.!?]*[.!]\s*$",
    r"\b(start|begin|resume|continue|execute|run|tackle|do)(ing|s)?\b[^.!?]{0,80}\bnow[.!]\s*$",
    # FORM 8: "time to X" / "ready to X" as a closing beat, anchored to a clause start.
    r"(^|[.!?]\s+|\n)\s*[*_>#\s-]*(time to|ready to|on to the|first up)\b[^.!?]*[.!]\s*$",
    # FORM 9: trailing relative clause committing to future work.
    r"\b(which|that)\s+(i|we)\s*('ll| will| am going to)[^.!?]*[.!]\s*$",
)]
# A gerund that is the SUBJECT of a descriptive sentence is not a commitment.
DESCRIPTIVE_GERUND = re.compile(
    r"\w+ing\b[^.!?]*\b(was|were|is|are|had been|has been|would be|will be|did|does|turned out|proved|seems|appears|means|explains|matters|costs|took)\b[^.!?]*[.!]\s*$",
    I)

# ----- Gate 3: legitimate stopping signals (SPRINT_STOPPING_CRITERIA.md 1-9) -------------------------------
LEGITIMATE_PATTERNS = [re.compile(p, I) for p in (
    r"all (sprint )?tasks (complete|done|finished)",
    r"sprint (is )?complete",
    r"blocked (on|by|waiting for) .{0,80}(external|network|credentials|secrets|api|service|tool|oauth|missing|authorization)",
    r"cannot proceed without .{0,80}(external|user input|credentials|secrets|approval|new|additional|authorization)",
    r"requires? .{0,80}(new|additional|external) (credentials|secrets|approval|api access|authorization)",
    r"stopping criterion [1-9]",
    r"(next sprint candidates|backlog refinement|sprint 3\d candidate list|candidates? in .*sprint refinement format)",
    r"priority \d+ .{0,40}(mandatory|carry-?in|core app|process|bugs?|security|hold)",
    r"(your call|your selection|which items|select items for sprint|approve the drafted plan|redirect scope)",
    r"phase 3 .{0,40}(approval|approve|exit gate|scope change)",
    r"(phase 7|sprint retrospective|retro) .{0,30}(prompt|feedback|awaiting)",
    r"please provide .{0,40}(retrospective|product owner|scrum master|lead developer) feedback",
    r"(14 categories|4 roles|7-step protocol)",
    r"scope change",
    r"expanding (beyond|outside) (sprint|task|plan) (scope|definition)",
    r"critical bug",
    r"unexpected bug (found|discovered)",
    r"(would|will) affect (sprint|data|users|production) (integrity|safety)",
    r"early (sprint )?review requested",
    r"retrospective (complete|done)",
    r"phase 7 (complete|done)",
    r"fundamental design (failure|issue|problem)",
    r"needs redesign",
    r"approach (is )?invalid",
    r"context (is )?(at|above|exceeding) 9[0-9]%",
    r"context limit approaching",
    r"/compact",
    r"time limit reached",
    r"sprint time box (reached|exceeded)",
    r"plan (is )?ambiguous",
    r"requirements? (is |are )?(unclear|ambiguous|conflicting)",
    r"two equally (valid|good|reasonable) approaches",
    r"architectural (choice|decision|tradeoff) (not|is not) covered by (the )?(plan|spec)",
    r"breaks (existing|downstream|api|contract)",
    r"would change (a )?prior (architectural|architecture|development|design) (decision|pattern)",
    r"would change the approved sprint scope",
    r"class[- ]?[123] (architecture|development|sprint|scope|decision)",
    r"(chief architect|chief developer|scrum master) (sign-?off|approval|decision)",
    r"(de-?scope|de-?scoping|defer(ring)?|fold(ing)?) .{0,60}(approved|deliverable|task|scope|to (a )?(future|next) sprint|into f\d+)",
    r"decision (is )?yours",
)]

BLOCK_TEMPLATE = """[BLOCKED by sprint-auto-advance hook]

You ended your turn with a procedural question OR a dangling future commitment (announcing the next action without executing it -- IMP-1, Sprint 61 retro) on branch '{branch}' (a sprint feature branch). This violates the Phase Auto-Advance Rule (CLAUDE.md section 7 'Development Philosophy: Co-Lead Developer Collaboration' item 7) and the Standing Approval Inventory (docs/SPRINT_EXECUTION_WORKFLOW.md Phase 3.7).

Sprint-plan approval at Phase 3 is DURABLE authorization through Manual Validation. The acceptable stopping criteria are enumerated in docs/SPRINT_STOPPING_CRITERIA.md sections 1-9. 'Confirming the next step' is not on that list.

ENFORCEMENT WINDOW: this hook applies ONLY between Phase 3.7 approval and the START of Manual Validation. If the sprint has actually reached Manual Validation / Phase 6 / Phase 7, this block is a false positive -- update .claude/sprint_status.json current_sprint.status to name the real phase (e.g. 'Phase 5.3 Manual Validation'), which is a Phase 7.7 checklist item anyway, and the hook will correctly stand down.

Required next action: identify the next action from:
  1. docs/sprints/SPRINT_N_PLAN.md (task list + acceptance criteria)
  2. TaskList tool (current task state)
  3. docs/SPRINT_EXECUTION_WORKFLOW.md (current phase steps)

State the next action in one sentence, then execute it without asking. Do NOT repeat the procedural question.

If the stop was actually for a SPRINT_STOPPING_CRITERIA reason (sections 1-9), rephrase so the reason is explicit (e.g., 'Stopping criterion 2: blocked on missing external credentials'). The hook whitelist accepts those phrasings.

If this block is a false positive (the question is legitimately required for scope/requirements/architecture ambiguity), explain the specific ambiguity directly, using phrasing like 'the plan is ambiguous here' or 'two equally valid approaches' - the whitelist accepts those too.

Emergency bypass: rename the current branch to include 'allow_stop_hook_bypass' as a suffix (e.g., 'feature/20260420_Sprint_36_allow_stop_hook_bypass') if the hook is preventing legitimate work.

Hook source: .claude/hooks/sprint-auto-advance.py
"""


# ----- Gate 1b ------------------------------------------------------------------------------------------
def plan_not_yet_approved(cwd: str, sprint_num: str, plan_path: str) -> bool:
    """Phase 3.7: the plan is drafted and awaiting approval, so asking is mandatory."""
    status, current = load_status(cwd)
    # (a) sprint_status.json is authoritative when it names THIS sprint.
    if status is not None and ps_str(current.get("number")) == sprint_num and ps_eq_bool(current.get("plan_approved"), False):
        return True
    # (b) fallback only when the status file does not name ANOTHER sprint: a completed sprint's plan keeps its
    # historical "**Status**: AWAITING PHASE 3.7 APPROVAL" line forever.
    current_number = ps_str(current.get("number")) if status is not None else ""
    names_another = bool(current_number) and current_number != sprint_num
    if not names_another:
        try:
            head = re.split(r"\r\n|\n|\r", read_markdown(plan_path))[:20]
        except OSError:
            head = []   # the PowerShell `catch { }`: an unreadable plan falls through to the next gate
        if any(PLAN_DRAFT_LINE.search(line) for line in head):
            return True
    return False


# ----- Gate 1c: the F193 evidence gate -----------------------------------------------------------------
def missing_phase5_evidence(cwd: str, sprint_num: str, plan_text: str) -> list:
    """Names of the Phase 5 artifacts not recorded in the plan (empty list = all recorded)."""
    number = int(sprint_num)
    markers = [("5.1.2 F-PRECHECK", "5.1.2"), ("5.1.5 WinWright sweep", "5.1.5")]
    if number >= 78:
        markers.append(("5.1.9 MV rehearsal", "5.1.9"))
    missing = []
    for name, marker in markers:
        pattern = re.compile(EVIDENCE_PRE.format(marker=re.escape(marker)), I | M)
        recorded = False
        for line in pattern.finditer(plan_text):
            value = line.group(1).strip()
            if value == "":
                # An EMPTY value counts only when indented detail follows it.
                if INDENTED_DETAIL.match(plan_text[line.end():]):
                    recorded = True
                    break
                continue
            is_placeholder = bool(PLACEHOLDER.search(value))
            is_bare_na = bool(BARE_NA_START.search(value)) and not NA_WITH_REASON.search(value)
            if not is_placeholder and not is_bare_na:
                recorded = True
                break
        if not recorded:
            missing.append(name)

    # Effort actuals (Sprint 78 retro IMP-1): one DONE or MOVED row per task card, planning rows excluded.
    if number >= 79:
        velocity_path = os.path.join(cwd, "docs", "CODING_VELOCITY.md")
        rows = 0
        if os.path.exists(velocity_path):
            row_rx = re.compile(r"^\|([^|\r\n]*)\|\s*" + re.escape(sprint_num) + r"\s*\|\s*(DONE|MOVED)\s*\|", I | M)
            for row in row_rx.finditer(read_markdown(velocity_path)):
                if not PLANNING_ROW.search(row.group(1)):
                    rows += 1
        cards = len(TASK_CARD.findall(plan_text))
        needed = max(1, cards)
        if rows < needed:
            missing.append(f"CODING_VELOCITY.md task actuals rows ({rows} found for Sprint {sprint_num}, {needed} "
                           f"needed: one per task card; planning rows do not count)")
    return missing


# ----- Gate 2 -------------------------------------------------------------------------------------------
def matches_commitment(trimmed: str) -> bool:
    """The turn ends on a future commitment. Checked on the last 300 characters with the footer removed."""
    tail = trimmed[-300:] if len(trimmed) > 300 else trimmed
    tail = FOOTER.sub("", tail).rstrip()
    for pattern in COMMITMENT_PATTERNS:
        if pattern.search(tail):
            if DESCRIPTIVE_GERUND.search(tail):   # suppress only when the SAME trailing sentence is descriptive
                continue
            return True
    return False


def decide(payload: dict) -> hooklib.Verdict:
    if not payload:
        return hooklib.allow()   # no payload: allow the stop (the PowerShell exited 0 on blank stdin)

    last_message = ps_str(payload.get("last_assistant_message"))
    cwd = ps_str(payload.get("cwd")) or os.getcwd()

    # ----- Gate 1: a sprint feature branch only -----
    override = ps_str(payload.get("branch_override"))
    if override:
        branch = override.strip()
    else:
        _code, out = common.git("branch", "--show-current", cwd=cwd)
        branch = out.strip()
    if not branch:
        return hooklib.allow()
    if re.search(r"allow_stop_hook_bypass", branch, I):
        return hooklib.allow()
    if not re.search(r"^feature/\d+_Sprint_\d+$", branch, I):
        return hooklib.allow()
    sprint_num = re.search(r"_Sprint_(\d+)", branch, I).group(1)

    # ----- Gate 1b: the window opens at plan approval -----
    plan_path = os.path.join(cwd, "docs", "sprints", f"SPRINT_{sprint_num}_PLAN.md")
    if not os.path.exists(plan_path):
        return hooklib.allow()   # Phase 1: surfacing Product Owner decisions is required
    if plan_not_yet_approved(cwd, sprint_num, plan_path):
        return hooklib.allow()

    # ----- Gate 1c: the window closes at Manual Validation -----
    status, current = load_status(cwd)
    is_current_sprint = status is not None and ps_str(current.get("number")) == sprint_num
    if is_current_sprint:
        status_text = ps_str(current.get("status"))
        if any(p.search(status_text) for p in WINDOW_CLOSED):
            # F193 (Sprint 67): the Phase 5 evidence gate, AT the Manual Validation boundary. Sprints >= 63 only.
            if int(sprint_num) >= 63 and ps_eq_bool(current.get("plan_approved"), True):
                if os.path.exists(plan_path):
                    missing = missing_phase5_evidence(cwd, sprint_num, read_markdown(plan_path))
                    if missing:
                        return hooklib.block(F193_TEMPLATE.format(sprint=sprint_num, names=", ".join(missing)))
            return hooklib.allow()   # past the enforcement window: asking is legitimate
        # (b) a retrospective file for THIS sprint means Phase 7 has started.
        retro_path = os.path.join(cwd, "docs", "sprints", f"SPRINT_{sprint_num}_RETROSPECTIVE.md")
        if os.path.exists(retro_path):
            return hooklib.allow()

    # ----- Gate 2: did the turn end with a procedural question or a dangling commitment? -----
    if not last_message:
        return hooklib.allow()
    trimmed = last_message.rstrip()
    ends_with_question = trimmed.endswith("?")
    matched_phrase = any(p.search(last_message) for p in PROC_PATTERNS)
    matched_commitment = matches_commitment(trimmed)
    if not (ends_with_question or matched_phrase or matched_commitment):
        return hooklib.allow()

    # ----- Gate 3: the stopping-criteria whitelist -----
    if any(p.search(last_message) for p in LEGITIMATE_PATTERNS):
        return hooklib.allow()

    return hooklib.block(BLOCK_TEMPLATE.format(branch=branch))


if __name__ == "__main__":
    hooklib.run("sprint-auto-advance", decide)
