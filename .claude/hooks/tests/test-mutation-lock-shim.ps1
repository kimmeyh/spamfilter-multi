<#
.SYNOPSIS
    Checks the PowerShell shim .claude\hooks\mutation-lock.ps1 against its Python library (F321, Sprint 83).

.DESCRIPTION
    The shim keeps the interface that scripts\mutation-test.ps1, scripts\agent-work-status.ps1 and CLAUDE.md
    call: New-MutationLock, Remove-MutationLock, Get-MutationLock, Get-MutationLockInfo. This script runs the
    full cycle in a throwaway project folder (CLAUDE_PROJECT_DIR points at it, so the real lock folder is never
    touched) and exits 1 on the first wrong result.

    What this does NOT catch: a difference that only appears under Windows PowerShell 5.1 (run it with
    `powershell`, not `pwsh`, to cover the shell the hooks and the wake-up use), and the Python library's own
    behavior, which test_pylib.py covers.

    Run: powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\tests\test-mutation-lock-shim.ps1
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$shim = Join-Path (Split-Path -Parent $here) 'mutation-lock.ps1'
$project = Join-Path ([System.IO.Path]::GetTempPath()) ("lockshim_{0}" -f ([guid]::NewGuid()))
New-Item -ItemType Directory -Force (Join-Path $project '.claude') | Out-Null
$saved = $env:CLAUDE_PROJECT_DIR
$env:CLAUDE_PROJECT_DIR = $project
$failures = @()
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "PASS $what" } else { Write-Host "FAIL $what"; $script:failures += $what }
}

try {
    . $shim
    $lockDir = Join-Path $project '.claude\mutation-locks'

    New-MutationLock -File 'docs/a b.md' -Reason 'shim check' -Agent 'shim-agent' | Out-Null
    Check (Test-Path (Join-Path $lockDir 'docs_a b.md.json')) 'New-MutationLock writes <safe name>.json'

    $info = @(Get-MutationLockInfo)
    Check ($info.Count -eq 1) 'Get-MutationLockInfo returns one object for one lock'
    Check ($info[0].file -eq 'docs/a b.md') 'info.file'
    Check ($info[0].reason -eq 'shim check') 'info.reason'
    Check ($info[0].agent -eq 'shim-agent') 'info.agent'
    Check ($info[0].ageMinutes -ge 0 -and $info[0].ageMinutes -le 2) 'info.ageMinutes is a small number'

    # A second, unreadable lock is reported and does not hide the first.
    Set-Content -LiteralPath (Join-Path $lockDir 'broken.json') -Value '{not json'
    $info = @(Get-MutationLockInfo)
    Check ($info.Count -eq 2) 'unreadable lock is listed beside the good one'
    Check (@($info | Where-Object { $_.reason -like 'unreadable lock file*' }).Count -eq 1) 'unreadable lock is described'
    Remove-Item -LiteralPath (Join-Path $lockDir 'broken.json')

    New-MutationLock -File 'other.md' -Reason 'bystander' | Out-Null
    Remove-MutationLock -File 'docs/a b.md'
    Check (-not (Test-Path (Join-Path $lockDir 'docs_a b.md.json'))) 'Remove-MutationLock -File removes that lock'
    Check (Test-Path (Join-Path $lockDir 'other.md.json')) 'Remove-MutationLock -File leaves the other lock'
    Remove-MutationLock -File 'other.md'

    New-MutationLock -File 'one' -Reason 'r' | Out-Null
    New-MutationLock -File 'two' -Reason 'r' | Out-Null
    Check (@(Get-MutationLockInfo).Count -eq 2) 'two locks held'
    Remove-MutationLock
    Check (@(Get-MutationLockInfo).Count -eq 0) 'Remove-MutationLock with no file releases every lock'
    Check (@(Get-MutationLockInfo).Count -eq 0 -and $null -eq (Get-MutationLockInfo | Select-Object -First 1)) 'Get-MutationLockInfo returns nothing when none are held'
} finally {
    $env:CLAUDE_PROJECT_DIR = $saved
    Remove-Item -LiteralPath $project -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) { Write-Host ("{0} check(s) failed" -f $failures.Count); exit 1 }
Write-Host 'All shim checks passed.'
exit 0
