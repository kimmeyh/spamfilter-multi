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
    Exit 0 always. Fails open on any error.
    Tests: .claude/hooks/test-cases/velocity-warn/ (run-test-cases.ps1;
    warn-* cases must print the warning, allow-* cases must print nothing).
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json

    $tool = [string]$payload.tool_name
    if ($tool -and $tool -ne 'Bash' -and $tool -ne 'PowerShell') { exit 0 }
    $cmd = [string]$payload.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
    if ($cmd -notmatch '\bgit\b[^\n;&|]*\bcommit\b') { exit 0 }

    $root = [string]$payload.cwd
    if ([string]::IsNullOrWhiteSpace($root)) { $root = $env:CLAUDE_PROJECT_DIR }
    if ([string]::IsNullOrWhiteSpace($root)) { exit 0 }

    # The message: the command text itself (covers -m) plus any -F file.
    $text = $cmd
    $f = [regex]::Match($cmd, '(?:^|\s)-F\s+("([^"]+)"|''([^'']+)''|(\S+))')
    if ($f.Success) {
        $path = @($f.Groups[2].Value, $f.Groups[3].Value, $f.Groups[4].Value) |
            Where-Object { $_ } | Select-Object -First 1
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $root $path }
        if (Test-Path -LiteralPath $path) {
            $text += "`n" + [IO.File]::ReadAllText($path)
        }
    }
    if ($text -notmatch '(?i)\bCloses\s+#\d+|\bTask\s+\d+\b') { exit 0 }

    # Windows PowerShell 5.1 turns a native command's stderr line into an
    # error record; under 'Stop' a git warning would end in the catch and the
    # hook would stay silent. Git output is read under 'Continue'.
    $ErrorActionPreference = 'Continue'
    $velocity = 'docs/CODING_VELOCITY.md'
    $staged = @(git -C $root diff --cached --name-only 2>$null)
    if ($staged -contains $velocity) { exit 0 }
    $modified = @(git -C $root status --porcelain -- $velocity 2>$null) |
        Where-Object { $_ }
    $stagesAll = $cmd -match '\bgit\s+add\s+(-A\b|--all\b|\.(\s|$))'
    $namesIt = $cmd -match 'CODING_VELOCITY\.md'
    if ($modified.Count -gt 0 -and ($stagesAll -or $namesIt)) { exit 0 }

    $why = if ($modified.Count -gt 0) {
        'it is modified but this command does not stage it'
    } else {
        'it has no change'
    }
    $msg = "[WARNING] Sprint 82 retro IMP-7: this commit closes a task " +
        "('Closes #N' or 'Task N') but $velocity is not in it ($why). " +
        "CODING_VELOCITY.md Rule 4: record the actual minutes, and the card's " +
        "Executed-by line, at task completion -- read the clock with Get-Date " +
        "first (IMP-6). If this commit is only part of the task, ignore this."
    $out = @{
        hookSpecificOutput = @{
            hookEventName     = 'PreToolUse'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Depth 4 -Compress
    [Console]::Out.Write($out)
    exit 0
} catch {
    exit 0  # fail open
}
