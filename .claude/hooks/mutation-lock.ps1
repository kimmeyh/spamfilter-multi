# Mutation-lock helpers for agents that deliberately break a tracked file to
# verify a test goes red.
#
# F321 (Sprint 83, ADR-0051): THIN POWERSHELL SHIM. The logic now lives in
# .claude/hooks/lib/mutation_lock.py (standard-library Python, runs on Windows,
# Linux and macOS). The functions below keep the interface that
# scripts/mutation-test.ps1, scripts/agent-work-status.ps1 and CLAUDE.md call.
# The lock files are unchanged (same folder, name rule and four JSON fields), so
# a lock written by the old PowerShell code is read by the Python code and the
# other way round.
#
# CONTRACT (two lines around every mutation):
#
#   . .claude\hooks\mutation-lock.ps1
#   New-MutationLock -File "docs/GOOGLE_PLAY_ACCOUNT_SETUP.md" -Reason "flip news-app answer to prove the gate fails"
#   # ... break it, run the test, confirm RED, restore it ...
#   Remove-MutationLock
#
# While a lock is held, `block-commit-during-mutation.py` refuses any
# `git commit` in this repository. See that file's header for the two Sprint 65
# incidents that made this necessary.
#
# The lock is advisory in one direction only: it does not stop the agent from
# mutating (that would defeat the verification), it stops the PERMANENT RECORD
# from capturing the temporary state.

$script:MutationLockPy = Join-Path $PSScriptRoot 'lib\mutation_lock.py'

function Get-MutationLockPython {
    $cmd = Get-Command python, python3, py -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { throw 'mutation-lock: python was not found on PATH (the lock library is Python; see ADR-0051).' }
    $cmd.Source
}

# Run the Python library and return its stdout lines. A non-zero exit throws, so
# a lock that was not written never looks like a lock that was.
function Invoke-MutationLockPython([string[]]$Arguments) {
    $py = Get-MutationLockPython
    $savedPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $py $script:MutationLockPy @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPref
    }
    if ($code -ne 0) { throw "mutation-lock: python exited $code`: $($out -join ' ')" }
    @($out | ForEach-Object { "$_" })
}

function Get-MutationLockDir {
    $projectDir = $env:CLAUDE_PROJECT_DIR
    if (-not $projectDir) {
        # Walk up to the repository root so the helper works from anywhere,
        # including mobile-app/ where the Flutter commands run.
        $dir = (Get-Location).Path
        while ($dir -and -not (Test-Path (Join-Path $dir '.git'))) {
            $parent = Split-Path $dir -Parent
            if ($parent -eq $dir) { break }
            $dir = $parent
        }
        $projectDir = $dir
    }
    Join-Path $projectDir '.claude\mutation-locks'
}

function New-MutationLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Reason,
        [string]$Agent = 'unnamed-agent'
    )
    Invoke-MutationLockPython @('new', '--file', $File, '--reason', $Reason, '--agent', $Agent) |
        ForEach-Object { Write-Host $_ }
}

function Remove-MutationLock {
    [CmdletBinding()]
    param(
        # Omit to release every lock this session holds, which is the common
        # case: an agent restores everything it broke before reporting.
        [string]$File
    )
    $arguments = @('remove')
    if ($File) { $arguments += @('--file', $File) }
    Invoke-MutationLockPython $arguments | ForEach-Object { Write-Host $_ }
}

function Get-MutationLock {
    Invoke-MutationLockPython @('list') | ForEach-Object { Write-Host $_ }
}

# Read-only (F317, Sprint 82): returns one object per held lock with its age in
# minutes, so a wake-up or status script can report a lock left behind by a
# stopped agent. Does not print, create or remove anything. An unreadable lock
# file is reported (reason "unreadable lock file: ...", ageMinutes empty) and
# does not hide the others.
function Get-MutationLockInfo {
    $json = (Invoke-MutationLockPython @('info')) -join ''
    if (-not $json.Trim()) { return @() }
    # Windows PowerShell 5.1 returns a JSON array as ONE object; piping it through
    # ForEach-Object enumerates it in 5.1 and 7 alike (found by the shim check).
    $parsed = $json | ConvertFrom-Json
    @($parsed | ForEach-Object { $_ })
}
