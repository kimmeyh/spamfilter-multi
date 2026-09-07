# Mutation-lock helpers for agents that deliberately break a tracked file to
# verify a test goes red.
#
# CONTRACT (two lines around every mutation):
#
#   . .claude\hooks\mutation-lock.ps1
#   New-MutationLock -File "docs/GOOGLE_PLAY_ACCOUNT_SETUP.md" -Reason "flip news-app answer to prove the gate fails"
#   # ... break it, run the test, confirm RED, restore it ...
#   Remove-MutationLock
#
# While a lock is held, `block-commit-during-mutation.ps1` refuses any
# `git commit` in this repository. See that file's header for the two Sprint 65
# incidents that made this necessary.
#
# The lock is advisory in one direction only: it does not stop the agent from
# mutating (that would defeat the verification), it stops the PERMANENT RECORD
# from capturing the temporary state.

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

    $lockDir = Get-MutationLockDir
    if (-not (Test-Path $lockDir)) {
        New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    }

    # One lock file per mutated file, so two agents mutating different files
    # do not clobber each other's lock -- and so the block message can name
    # exactly which files are unsafe to commit.
    $safeName = ($File -replace '[\\/:*?"<>|]', '_') + '.json'
    $lockPath = Join-Path $lockDir $safeName

    [PSCustomObject]@{
        file       = $File
        reason     = $Reason
        agent      = $Agent
        createdUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -Path $lockPath -Encoding UTF8

    Write-Host "[mutation-lock] HELD on $File -- commits are blocked until Remove-MutationLock."
}

function Remove-MutationLock {
    [CmdletBinding()]
    param(
        # Omit to release every lock this session holds, which is the common
        # case: an agent restores everything it broke before reporting.
        [string]$File
    )

    $lockDir = Get-MutationLockDir
    if (-not (Test-Path $lockDir)) { return }

    if ($File) {
        $safeName = ($File -replace '[\\/:*?"<>|]', '_') + '.json'
        $lockPath = Join-Path $lockDir $safeName
        if (Test-Path $lockPath) {
            Remove-Item $lockPath -Force
            Write-Host "[mutation-lock] RELEASED on $File."
        }
    } else {
        $count = @(Get-ChildItem -Path $lockDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
        Get-ChildItem -Path $lockDir -Filter '*.json' -ErrorAction SilentlyContinue |
            Remove-Item -Force
        Write-Host "[mutation-lock] RELEASED $count lock(s)."
    }
}

function Get-MutationLock {
    $lockDir = Get-MutationLockDir
    if (-not (Test-Path $lockDir)) {
        Write-Host "[mutation-lock] none held."
        return
    }
    $locks = @(Get-ChildItem -Path $lockDir -Filter '*.json' -ErrorAction SilentlyContinue)
    if ($locks.Count -eq 0) {
        Write-Host "[mutation-lock] none held."
        return
    }
    foreach ($lock in $locks) {
        $info = Get-Content $lock.FullName -Raw | ConvertFrom-Json
        Write-Host "[mutation-lock] $($info.file) -- $($info.reason) (held by $($info.agent))"
    }
}
