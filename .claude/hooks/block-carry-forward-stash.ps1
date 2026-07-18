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

# Read-only stash inspection is always fine.
if ($cmd -match 'git\s+stash\s+(list|show)\b') { exit 0 }

# Any other `git stash ...` (including bare `git stash`) is state-changing.
if ($cmd -match 'git\s+stash\b') {
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
