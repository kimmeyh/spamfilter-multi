<#
.SYNOPSIS
    Stop-hook that blocks Claude from ending a turn with a procedural question
    while a sprint is active. Enforces the Phase Auto-Advance Rule
    (CLAUDE.md section 7) and Standing Approval Inventory
    (SPRINT_EXECUTION_WORKFLOW.md Phase 3.7).

.DESCRIPTION
    Fires on Claude Code's Stop event. Reads the JSON payload from stdin,
    inspects the last assistant message, and:

      - ALLOWS the stop (exit 0) if:
          a) branch is not a sprint branch (feature/YYYYMMDD_Sprint_N), OR
          b) the message does not end in a question, OR
          c) the message contains a legitimate stopping signal matching
             SPRINT_STOPPING_CRITERIA.md criterion 1-9 (the §1-9 whitelist)

      - BLOCKS the stop (exit 2) if:
          all of -
            - branch matches feature/\d+_Sprint_\d+
            - last message ends in a question mark or a question-shaped phrase
            - no legitimate §1-9 signal present

        When blocked, stderr contains a corrective instruction that is fed
        back to Claude as the next turn.

    Established 2026-04-20 during Sprint 36 kickoff after Opus 4.7 was observed
    violating the Phase Auto-Advance Rule even though the rule lives in
    CLAUDE.md. Documentation-only controls proved insufficient for this model
    version; a hard forcing function is required.

.PARAMETER (none)
    Hook reads JSON from stdin per Claude Code Stop hook contract:
      {
        "last_assistant_message": "...",
        "cwd": "...",
        "transcript_path": "...",
        "session_id": "...",
        "hook_event_name": "Stop"
      }

.NOTES
    Exit 0 = allow stop (default)
    Exit 2 = block stop, stderr is fed to Claude as correction
    Any other exit = non-blocking warning (stderr shown, stop proceeds)

    Bypass mechanism: if the branch name contains the literal token
    "allow_stop_hook_bypass", the hook unconditionally allows the stop.
    Useful for emergency one-off sessions where the hook misfires.
#>

$ErrorActionPreference = 'Stop'

# ----- Read stdin JSON payload --------------------------------------------
$stdinText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinText)) {
    exit 0  # No payload, allow stop (non-blocking)
}

try {
    $payload = $stdinText | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "sprint-auto-advance hook: could not parse stdin as JSON. Bypassing. Error: $_"
    exit 0
}

$lastMessage = [string]$payload.last_assistant_message
$cwd         = [string]$payload.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }

# ----- Gate 1: Are we on a sprint branch? ---------------------------------
# Sprint branch = feature/YYYYMMDD_Sprint_N per CLAUDE.md branch policy.
try {
    $branch = (& git -C $cwd branch --show-current 2>$null).Trim()
} catch {
    $branch = ''
}

if (-not $branch) { exit 0 }
if ($branch -match 'allow_stop_hook_bypass') { exit 0 }
if ($branch -notmatch '^feature/\d+_Sprint_\d+$') { exit 0 }

# ----- Gate 2: Did Claude end with a procedural question? -----------------
if (-not $lastMessage) { exit 0 }

$trimmed = $lastMessage.TrimEnd()
$endsWithQuestionMark = $trimmed.EndsWith('?')

# Question-shaped phrases that indicate procedural asking
# (distinct from legitimate §1-9 stopping signals further down)
$procPatterns = @(
    '(?i)want me to (proceed|continue|start|do|run|apply|execute|go|build|commit|push|create|update|extend|handle|follow|address|run the|skip|try)'
    '(?i)should i (proceed|continue|start|do|run|apply|execute|go|build|commit|push|create|update|extend|handle|follow|address|ask|stop|move on)'
    '(?i)(shall|may) i (proceed|continue|start|do|run|apply|execute|go)'
    '(?i)ready (to|for|when) (continue|proceed|go|you|kick ?off)'
    '(?i)awaiting (your|further|user|harold) (approval|decision|direction|input|confirmation|call|go-?ahead)'
    '(?i)which (option|path|approach|do you)'
    '(?i)(let|tell) me know (which|if|when|whether)'
    '(?i)is (that|this) (ok|fine|acceptable|approved|good)'
    '(?i)(go|any further direction|proceed)\s*\?'
    '(?i)confirm (before|and|that)'
    '(?i)(what|how).*(should|would) (i|you like|we)'
    '(?i)do you want (me )?to'
    '(?i)or (wait|defer|skip)'
)

$matchedProcPhrase = $false
foreach ($pat in $procPatterns) {
    if ($lastMessage -match $pat) {
        $matchedProcPhrase = $true
        break
    }
}

# If no question mark AND no procedural phrase, allow the stop.
# (Statements ending in a period are fine.)
if (-not ($endsWithQuestionMark -or $matchedProcPhrase)) {
    exit 0
}

# ----- Gate 3: §1-9 whitelist (legitimate stopping criteria) --------------
# These signal a real SPRINT_STOPPING_CRITERIA.md reason to stop, not a
# procedural permission-ask. If any is present, allow the stop.
$legitimatePatterns = @(
    '(?i)all (sprint )?tasks (complete|done|finished)'              # §1 Normal completion
    '(?i)sprint (is )?complete'                                     # §1
    '(?i)blocked (on|by|waiting for) .{0,80}(external|network|credentials|secrets|api|service|tool|oauth|missing|authorization)'  # §2
    '(?i)cannot proceed without .{0,80}(external|user input|credentials|secrets|approval|new|additional|authorization)' # §2
    '(?i)requires? .{0,80}(new|additional|external) (credentials|secrets|approval|api access|authorization)'  # §2
    '(?i)stopping criterion [1-9]'                              # Explicit §N invocation
    '(?i)scope change'                                              # §3
    '(?i)expanding (beyond|outside) (sprint|task|plan) (scope|definition)'                # §3
    '(?i)critical bug'                                              # §4
    '(?i)unexpected bug (found|discovered)'                         # §4
    '(?i)(would|will) affect (sprint|data|users|production) (integrity|safety)'  # §4
    '(?i)early (sprint )?review requested'                          # §5
    '(?i)retrospective (complete|done)'                             # §6
    '(?i)phase 7 (complete|done)'                                   # §6
    '(?i)fundamental design (failure|issue|problem)'                # §7
    '(?i)needs redesign'                                            # §7
    '(?i)approach (is )?invalid'                                    # §7
    '(?i)context (is )?(at|above|exceeding) 9[0-9]%'                # §8
    '(?i)context limit approaching'                                 # §8
    '(?i)/compact'                                                  # §8
    '(?i)time limit reached'                                        # §9
    '(?i)sprint time box (reached|exceeded)'                        # §9

    # Also allow genuine clarifying questions on ambiguous plan / scope /
    # architecture decisions that the plan does not specify. The test is
    # presence of a phrase that signals "the plan is ambiguous here",
    # not just a generic procedural ask.
    '(?i)plan (is )?ambiguous'
    '(?i)requirements? (is |are )?(unclear|ambiguous|conflicting)'
    '(?i)two equally (valid|good|reasonable) approaches'
    '(?i)architectural (choice|decision|tradeoff) (not|is not) covered by (the )?(plan|spec)'
    '(?i)breaks (existing|downstream|api|contract)'
)

foreach ($pat in $legitimatePatterns) {
    if ($lastMessage -match $pat) {
        exit 0
    }
}

# ----- All gates passed: block the stop -----------------------------------
$correction = @"
[BLOCKED by sprint-auto-advance hook]

You ended your turn with a procedural question on branch '$branch' (a sprint feature branch). This violates the Phase Auto-Advance Rule (CLAUDE.md section 7 'Development Philosophy: Co-Lead Developer Collaboration' item 7) and the Standing Approval Inventory (docs/SPRINT_EXECUTION_WORKFLOW.md Phase 3.7).

Sprint-plan approval at Phase 3 is DURABLE authorization through Phase 7. The acceptable stopping criteria are enumerated in docs/SPRINT_STOPPING_CRITERIA.md sections 1-9. 'Confirming the next step' is not on that list.

Required next action: identify the next action from:
  1. docs/sprints/SPRINT_N_PLAN.md (task list + acceptance criteria)
  2. TaskList tool (current task state)
  3. docs/SPRINT_EXECUTION_WORKFLOW.md (current phase steps)

State the next action in one sentence, then execute it without asking. Do NOT repeat the procedural question.

If the stop was actually for a SPRINT_STOPPING_CRITERIA reason (sections 1-9), rephrase so the reason is explicit (e.g., 'Stopping criterion 2: blocked on missing external credentials'). The hook whitelist accepts those phrasings.

If this block is a false positive (the question is legitimately required for scope/requirements/architecture ambiguity), explain the specific ambiguity directly, using phrasing like 'the plan is ambiguous here' or 'two equally valid approaches' - the whitelist accepts those too.

Emergency bypass: rename the current branch to include 'allow_stop_hook_bypass' as a suffix (e.g., 'feature/20260420_Sprint_36_allow_stop_hook_bypass') if the hook is preventing legitimate work.

Hook source: .claude/hooks/sprint-auto-advance.ps1
"@

[Console]::Error.WriteLine($correction)
exit 2
