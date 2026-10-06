<#
.SYNOPSIS
    PreToolUse hook that blocks staging EVERYTHING (`git add -A`, `--all`,
    `.`) unless the same command ran `git status` first. Enforces the
    CLAUDE.md rule "Don't stage a commit without looking at what you are
    staging" (Sprint 52 IMP-4).

.DESCRIPTION
    Fires on the Bash and PowerShell tools. Reads the JSON payload from stdin:

      - ALLOWS (exit 0) staging named paths, any command that runs
        `git status` BEFORE its `git add -A/--all/.`, and any command carrying
        the bypass token `allow_blind_staging`.
      - BLOCKS (exit 2) `git add -A`, `git add --all` or `git add .` with no
        earlier `git status` in the same command. stderr carries the fix.

    WHY: the rule existed and was broken again in Sprint 76 -- `git add -A`
    ran before `git status`, and a `0*` working file of Harold's went into a
    version-bump commit with no mention (retro IMP-4: prevention first, a rule
    alone did not prevent the recurrence).

    Text inside quotes is ignored, so a commit message that MENTIONS
    `git add -A` is not blocked -- a guard that fires on correct work trains
    people to bypass it.

.NOTES
    Exit 0 = allow; Exit 2 = block (stderr fed to Claude).
    Bypass: include the literal token allow_blind_staging in the command.
    Tests: .claude/hooks/test-cases/staging-guard/ (run-test-cases.ps1).
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0  # unparseable payload: fail open
}

if ($payload.tool_name -and $payload.tool_name -notin @('Bash', 'PowerShell')) { exit 0 }

$cmd = $null
if ($payload.tool_input -and $payload.tool_input.command) {
    $cmd = [string]$payload.tool_input.command
}
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
if ($cmd -match 'allow_blind_staging') { exit 0 }

# Drop quoted text (commit messages, echo strings) so only real commands count.
$code = [regex]::Replace($cmd, '"[^"]*"|''[^'']*''', '""')

# `git [-C <dir>] add -A|--all|.` -- the "." must be a whole argument.
$stageAll = [regex]::new('\bgit(?:\s+-C\s+\S+)?\s+add\s+(?:-A\b|--all\b|\.(?=\s|$|;|&|\|))')
$status = [regex]::new('\bgit(?:\s+-C\s+\S+)?\s+status\b')

$add = $stageAll.Match($code)
if (-not $add.Success) { exit 0 }

$st = $status.Match($code)
if ($st.Success -and $st.Index -lt $add.Index) { exit 0 }

[Console]::Error.WriteLine(@"
[BLOCKED] Staging everything without looking first:
  $($add.Value)

CLAUDE.md (Sprint 52 IMP-4; enforced from the Sprint 76 retro, IMP-4): run
``git status --short`` FIRST and account for every entry -- in Sprint 76 a
``git add -A`` before the status check swept Harold's 0* working file into a
version-bump commit with no mention.

Do this instead, in ONE command:
  git status --short; git add -A; git commit ...
or stage the paths you mean by name.

If staging everything unseen is genuinely intended, re-run with the literal
token allow_blind_staging in the command.
"@)
exit 2
