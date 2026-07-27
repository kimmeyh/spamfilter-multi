<#
.SYNOPSIS
    PreToolUse hook that blocks `git stash` and points to the deterministic
    branch-carry-forward flow ("create branch then COMMIT the uncommitted
    files"). Enforces the Phase 6.6 carry-forward rule.

.DESCRIPTION
    Fires on Claude Code's PreToolUse event for the Bash / PowerShell tools.
    Reads the JSON payload from stdin, inspects the proposed command, and:

      - ALLOWS the call (exit 0) if:
          a) the command does not invoke `git stash`, OR
          b) the command contains the literal bypass token `allow_stash`
             (an explicit, deliberate escape hatch for the rare legitimate
             stash Harold sanctions), OR
          c) `git stash list` / `git stash show` (read-only inspection).

      - BLOCKS the call (exit 2) for any state-changing `git stash` form
        (`git stash`, `git stash push|save|pop|apply|drop|clear`). stderr
        carries the corrective instruction fed back to Claude.

    WHY: Sprint 46->47 carry-forward, Claude reached for `git stash` to carry
    an uncommitted file across a new sprint branch. The stash caused
    `0Claudedev_prompts.txt` to appear reverted and cost a recovery round. The
    documented flow (memory: feedback_follow_deterministic_process) is: create
    the next branch, THEN commit the uncommitted files -- they follow the branch;
    NEVER stash to carry forward. Memory alone did not prevent the recurrence
    (Sprint 47 retro Category 9 / Proposal 3), so a forcing function is added.

.NOTES
    Exit 0 = allow the tool call (default)
    Exit 2 = block the tool call; stderr is fed to Claude as a correction
    Bypass: include the literal token `allow_stash` anywhere in the command.
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    # If we cannot parse the payload, do not block -- fail open.
    exit 0
}

# Extract the proposed command from the tool input (Bash + PowerShell tools
# both use `command`).
$cmd = $null
if ($payload.tool_input -and $payload.tool_input.command) {
    $cmd = [string]$payload.tool_input.command
} elseif ($payload.command) {
    $cmd = [string]$payload.command
}
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

# Explicit human-sanctioned escape hatch.
if ($cmd -match 'allow_stash') { exit 0 }

# ---- F130-S51 R-2 (Sprint 51, 2026-07-27): match INVOCATIONS, not text ----
# The original matcher scanned the ENTIRE command string, so it blocked any
# command whose *content* merely mentioned the words -- e.g. writing docs that
# document this very prohibition, or a `gh pr create --body` describing the
# defect. It false-positived three times in one session while the operator was
# doing correct work. A hook that fires on correct work trains people to route
# around it, which erodes every hook's authority.
#
# Fix: strip regions that are DATA rather than executable command text before
# matching -- single/double-quoted strings and heredoc bodies. What remains is
# (approximately) the executable portion, which is where a real `git stash`
# invocation must appear. Deliberately conservative: when in doubt the text
# stays and the guard still fires, because a false BLOCK is recoverable
# (bypass token) while a false ALLOW loses work.
$scan = $cmd
# Heredoc bodies: <<'EOF' ... EOF  /  <<EOF ... EOF  (any delimiter token)
$scan = [regex]::Replace($scan, "(?s)<<-?\s*'?""?([A-Za-z_][A-Za-z0-9_]*)'?""?.*?^\s*\1\s*$", ' ', 'Multiline')
# Single-quoted and double-quoted spans (non-greedy, no escape handling needed
# for this purpose -- we only care whether an invocation survives outside them)
$scan = [regex]::Replace($scan, "'[^']*'", ' ')
$scan = [regex]::Replace($scan, '"[^"]*"', ' ')

# Read-only stash inspection is always fine.
if ($scan -match 'git\s+stash\s+(list|show)\b') { exit 0 }

# Any other `git stash ...` (including bare `git stash`) is state-changing.
if ($scan -match 'git\s+stash\b') {
    $msg = @"
[BLOCKED] git stash is disallowed for branch carry-forward.

Sprint 47 retro Proposal 3 (Phase 6.6 carry-forward rule). Stashing to carry
uncommitted work across a branch caused a file to appear reverted (Sprint
46->47) and cost a recovery round.

Use the DETERMINISTIC flow instead:
  1. Create the next branch:   git checkout -b <next-branch>
  2. COMMIT the uncommitted files on that branch -- they follow the branch.
     Uncommitted changes are already carried by the working tree across a
     git checkout -b; you do NOT need to stash them.

If you have a genuine, Harold-sanctioned reason to stash (NOT carry-forward),
re-run the command with the literal token allow_stash in it to bypass.

Reference: memory feedback_follow_deterministic_process; SPRINT_EXECUTION_WORKFLOW.md Phase 6.6.
"@
    [Console]::Error.WriteLine($msg)
    exit 2
}

exit 0
