<#
.SYNOPSIS
    PreToolUse hook that WARNS (never blocks) when a task-closing commit does
    not carry its docs/CODING_VELOCITY.md row. Sprint 82 retro IMP-7.

.DESCRIPTION
    Fires on the Bash and PowerShell tools. When the command runs `git commit`
    and the commit message (an inline -m, or the file named by -F) contains
    `Closes #N` or `Task N`, the hook checks that docs/CODING_VELOCITY.md will
    be in the commit: already staged, or modified in the working tree and
    staged by the same command (`git add -A` / `--all` / `.`, or named).

    When it will not be, the hook exits 0 and prints JSON with
    hookSpecificOutput.additionalContext, which Claude Code delivers to the
    model next to the tool result. Stderr on exit 0 is never shown to the
    model (code.claude.com/docs/en/hooks, read 2026-10-31), so a warning must
    use the JSON form.

    WHY: CODING_VELOCITY.md Rule 4 says the actual is recorded at task
    completion. Nothing checked it until close-out, so in Sprints 81 and 82 the
    rows and the Executed-by lines were rebuilt from commit times at the gates
    (the close-out hook caught 13 missing Executed-by lines in Sprint 82).
    Warn, not block (Harold, 2026-10-31): a partial commit of a task is valid.

.NOTES
    Exit 0 always. An unparseable payload is ignored silently (fail open);
    any later error, an unreadable -F file, or unreadable git state is
    REPORTED through additionalContext ("the check did not run"), so a broken
    gate does not look like a passing one.
    Tests: .claude/hooks/test-cases/velocity-warn/ (run-test-cases.ps1;
    warn-* cases must print the warning, allow-* cases must print nothing).
#>

$ErrorActionPreference = 'Stop'

function Send-Context([string]$text) {
    $out = @{
        hookSpecificOutput = @{
            hookEventName     = 'PreToolUse'
            additionalContext = $text
        }
    } | ConvertTo-Json -Depth 4 -Compress
    [Console]::Out.Write($out)
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0  # unparseable payload: fail open (a hook that throws blocks every call)
}

try {
    $tool = [string]$payload.tool_name
    if ($tool -and $tool -ne 'Bash' -and $tool -ne 'PowerShell') { exit 0 }
    $cmd = [string]$payload.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
    if ($cmd -notmatch '\bgit\b[^\n;&|]*\bcommit\b') { exit 0 }

    $cwd = [string]$payload.cwd
    if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = $env:CLAUDE_PROJECT_DIR }
    if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }

    # The message: the command text itself (covers -m) plus any -F file.
    $text = $cmd
    $unreadMessage = $null
    $f = [regex]::Match($cmd, '(?:^|\s)-F\s+("([^"]+)"|''([^'']+)''|(\S+))')
    if ($f.Success) {
        $path = @($f.Groups[2].Value, $f.Groups[3].Value, $f.Groups[4].Value) |
            Where-Object { $_ } | Select-Object -First 1
        # A Git Bash path (/c/Users/...) is rooted for .NET but on the wrong
        # drive; map it to C:\Users\...
        if ($path -match '^/([A-Za-z])/(.*)$') { $path = "$($Matches[1]):\$($Matches[2])" }
        if ($path -match '[$%]') {
            $unreadMessage = "$path (a variable the hook cannot expand)"
        } else {
            if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $cwd $path }
            if (Test-Path -LiteralPath $path) {
                $text += "`n" + [IO.File]::ReadAllText($path)
            } else {
                $unreadMessage = "$path (not found)"
            }
        }
    }
    $closesTask = $text -match '(?i)\bCloses\s+#\d+|\bTask\s+\d+\b'
    if (-not $closesTask) {
        if ($unreadMessage) {
            Send-Context ("[WARNING] Sprint 82 retro IMP-7: the commit message file " +
                "$unreadMessage could not be read, so the CODING_VELOCITY check did " +
                "not run. If this commit closes a task, confirm its velocity row " +
                "and Executed-by line are in it.")
        }
        exit 0
    }

    # Windows PowerShell 5.1 turns a native command's stderr line into an
    # error record; under 'Stop' a git warning would end in the catch. Git
    # output is read under 'Continue', and each exit code is checked.
    $ErrorActionPreference = 'Continue'
    $velocity = 'docs/CODING_VELOCITY.md'
    # Paths from the repo root: a pathspec is relative to -C, so a session in
    # mobile-app\ would otherwise look for mobile-app/docs/... (review M2).
    $root = git -C $cwd rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Send-Context ("[WARNING] Sprint 82 retro IMP-7: this commit closes a task, " +
            "but git state could not be read from '$cwd', so the CODING_VELOCITY " +
            "check did not run. Confirm the velocity row is in the commit.")
        exit 0
    }
    $staged = @(git -C $root diff --cached --name-only 2>$null)
    if ($staged -contains $velocity) { exit 0 }
    $modified = @(git -C $root status --porcelain -- $velocity 2>$null) |
        Where-Object { $_ }
    $stagesAll = ($cmd -match '\bgit\s+add\s+(-A\b|--all\b|-u\b|--update\b|\.(?=\s|$|[;&|]))') -or
        ($cmd -match '\bgit\b[^\n;&|]*\bcommit\b[^\n;&|]*\s-[A-Za-z]*a') -or
        ($cmd -match '\bgit\b[^\n;&|]*\bcommit\b[^\n;&|]*\s--all\b')
    $namesIt = $cmd -match '\bgit\s+add\b[^\n;&|]*(CODING_VELOCITY\.md|\sdocs/?(?=\s|$|[;&|]))'
    if ($modified.Count -gt 0 -and ($stagesAll -or $namesIt)) { exit 0 }

    $why = if ($modified.Count -gt 0) {
        'it is modified but this command does not stage it'
    } else {
        'it has no change'
    }
    Send-Context ("[WARNING] Sprint 82 retro IMP-7: this commit closes a task " +
        "('Closes #N' or 'Task N') but $velocity is not in it ($why). " +
        "CODING_VELOCITY.md Rule 4: record the actual minutes, and the card's " +
        "Executed-by line, at task completion -- read the clock with Get-Date " +
        "first (IMP-6). If this commit is only part of the task, ignore this.")
    exit 0
} catch {
    # Still exit 0 (the hook only warns), but say the check did not run, so
    # a broken gate is not mistaken for a passing one (review H1).
    Send-Context ("[WARNING] warn-commit-without-velocity.ps1 failed: " +
        "$($_.Exception.Message). The CODING_VELOCITY check did not run.")
    exit 0
}