<#
.SYNOPSIS
    PreToolUse hook that blocks the FIRST sprint task commit when the current
    sprint has no GitHub issue cards recorded. Enforces the Phase 3 card-creation
    step.

.DESCRIPTION
    Fires on Claude Code's PreToolUse event for the Bash / PowerShell tools.
    Reads the JSON payload from stdin and:

      - ALLOWS (exit 0) unless the command is a `git commit` invocation.
      - ALLOWS if `.claude/sprint_status.json` is missing/unparseable, if the
        sprint plan is not yet approved (pre-Phase-3.7 commits are legitimate:
        the plan doc, the branch stub), or if `github_issues` is non-empty.
      - ALLOWS if the command carries the literal bypass token
        `allow_no_cards` -- the deliberate escape hatch, matching the
        established pattern in block-carry-forward-stash.ps1.
      - BLOCKS (exit 2) a `git commit` when the plan IS approved and
        `github_issues` is empty. stderr carries the corrective instruction.

    WHY: Sprint 52. Execution began straight from Phase 3.7 plan approval
    without walking the Phase 3 card-creation step. SIX task commits landed with
    no issue cards AND no CHANGELOG entries before the gap was noticed at the
    end of Phase 4, and the cards then had to be backfilled with reconstructed
    scope. `sprint_status.json` already stated the rule ("cards are created when
    scope is selected at Phase 3") -- documentation alone did not prevent it, so
    a forcing function is added. Sprint 52 retro IMP-2.

    Deliberately gated on `plan_approved`: before approval there are no cards to
    create yet, and blocking the plan-document commit would be a false positive.
    A hook that fires on correct work trains people to route around it (the
    F130-S51 R-2 lesson from the stash guard).

.NOTES
    Exit 0 = allow the tool call (default; also the fail-open path)
    Exit 2 = block the tool call; stderr is fed to Claude as a correction
    Bypass: include the literal token `allow_no_cards` in the command.
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    # Unparseable payload -- never block on our own failure.
    exit 0
}

$cmd = $null
if ($payload.tool_input -and $payload.tool_input.command) {
    $cmd = [string]$payload.tool_input.command
} elseif ($payload.command) {
    $cmd = [string]$payload.command
}
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

# Explicit human-sanctioned escape hatch.
if ($cmd -match 'allow_no_cards') { exit 0 }

# Match INVOCATIONS, not text (F130-S51 R-2 lesson from the stash guard): strip
# quoted spans and heredoc bodies so a commit MESSAGE that merely mentions
# "git commit" -- like this hook's own documentation -- cannot trip the guard.
$scan = $cmd
$scan = [regex]::Replace($scan, "(?s)<<-?\s*'?""?([A-Za-z_][A-Za-z0-9_]*)'?""?.*?^\s*\1\s*$", ' ', 'Multiline')
$scan = [regex]::Replace($scan, "'[^']*'", ' ')
$scan = [regex]::Replace($scan, '"[^"]*"', ' ')

if ($scan -notmatch 'git\s+commit\b') { exit 0 }

# Locate sprint_status.json relative to this hook (.claude/hooks/ -> .claude/).
#
# `status_path_override` in the payload points the hook at a FIXTURE instead of
# the live file. Without it, every test case would read the real sprint state
# and flip whenever the live sprint changed phase -- the exact
# environment-dependence that silently broke four cases in Sprint 51 (see
# run-test-cases.ps1 .NOTES). Test-only; never set in production payloads.
$statusPath = $null
if ($payload.status_path_override) {
    $statusPath = [string]$payload.status_path_override
    if (-not [System.IO.Path]::IsPathRooted($statusPath)) {
        $statusPath = Join-Path $PSScriptRoot $statusPath
    }
} else {
    $statusPath = Join-Path $PSScriptRoot '..\sprint_status.json'
}
if (-not (Test-Path $statusPath)) { exit 0 }

try {
    $status = Get-Content $statusPath -Raw | ConvertFrom-Json
} catch {
    exit 0
}

$sprint = $status.current_sprint
if (-not $sprint) { exit 0 }

# Pre-approval commits are legitimate (plan document, branch stub, carry-forward).
if (-not $sprint.plan_approved) { exit 0 }

$cards = $status.github_issues
if ($cards -and @($cards).Count -gt 0) { exit 0 }

$number = $sprint.number
$msg = @"
[BLOCKED] Sprint $number has no GitHub issue cards recorded.

The sprint plan is APPROVED (plan_approved: true) but
.claude/sprint_status.json has an empty `github_issues` array, so the Phase 3
card-creation step was skipped. Task commits must not land before their cards
exist.

WHY THIS GATE EXISTS (Sprint 52 retro IMP-2): execution began straight from
plan approval and SIX task commits landed with no cards and no CHANGELOG
entries before anyone noticed. The cards then had to be backfilled from
reconstructed scope, which is exactly the kind of after-the-fact record that is
never as accurate as the real thing.

DO THIS NOW:
  1. Create one card per scope theme:
       gh issue create --title "<F-number>: <title>" --label sprint --body "<scope>"
  2. Record the numbers in .claude/sprint_status.json:
       "github_issues": [<n>, <n>, ...]
  3. Re-run the commit. Reference the card in the CHANGELOG entry: (Issue #N)

Note `Closes #N` does NOT auto-fire in this GitFlow repo -- PRs merge
feature -> develop, and GitHub only auto-closes on merge to the DEFAULT branch.
Close the cards by hand at Post-Merge Cleanup.

Deliberate exception (rare): add the literal token `allow_no_cards` to the
command.
"@

[Console]::Error.WriteLine($msg)
exit 2
