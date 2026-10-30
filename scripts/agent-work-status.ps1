<#
.SYNOPSIS
  Report the state of delegated agent work from files only: each agent task's
  progress, held mutation locks with their age, and the sprint phase.

.DESCRIPTION
  F317 (Sprint 82). Read-only: it stores nothing and changes nothing.

  Convention (docs/SPRINT_EXECUTION_WORKFLOW.md, "Progress and restart"): each
  agent keeps <ScratchFolder>\<task-name>\progress.md with lines
  "UNIT <name>: DONE|STARTED", "LAST STEP: <text>" and, last, "STATUS: FINISHED".

  State per task folder:
    not started                    -- no progress.md in the folder
    started, nothing saved         -- progress.md has no UNIT lines
    in progress                    -- UNIT lines, no "STATUS: FINISHED" (shows the last step)
    finished                       -- "STATUS: FINISHED" is the last non-empty line

  Also prints every held mutation lock (.claude\mutation-locks) with its age in
  minutes (a lock over 60 minutes is flagged), and the sprint phase from
  .claude\sprint_status.json (current_sprint.status).

.PARAMETER ScratchFolder
  Folder whose subfolders are agent task folders. Default: the newest session
  scratchpad under %LOCALAPPDATA%\Temp\claude\D--Data-Harold-github-spamfilter-multi\<session>\scratchpad.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\agent-work-status.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\agent-work-status.ps1 -ScratchFolder C:\temp\scratch
#>
param(
    [string]$ScratchFolder
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo '.claude\hooks\mutation-lock.ps1')

if (-not $ScratchFolder) {
    $root = Join-Path $env:LOCALAPPDATA 'Temp\claude\D--Data-Harold-github-spamfilter-multi'
    if (Test-Path $root) {
        $newest = Get-ChildItem -Path $root -Directory |
            ForEach-Object { Join-Path $_.FullName 'scratchpad' } |
            Where-Object { Test-Path $_ } |
            ForEach-Object { Get-Item $_ } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) { $ScratchFolder = $newest.FullName }
    }
}

Write-Host "Scratch folder: $ScratchFolder"
Write-Host 'Agent tasks:'
if (-not $ScratchFolder -or -not (Test-Path $ScratchFolder)) {
    Write-Host '  (scratch folder not found)'
} else {
    $tasks = @(Get-ChildItem -Path $ScratchFolder -Directory -ErrorAction SilentlyContinue)
    if ($tasks.Count -eq 0) { Write-Host '  (no task folders)' }
    foreach ($t in $tasks) {
        $pf = Join-Path $t.FullName 'progress.md'
        if (-not (Test-Path $pf)) {
            Write-Host ("  {0}: not started" -f $t.Name)
            continue
        }
        $lines = @(Get-Content -Path $pf -Encoding UTF8 | Where-Object { $_.Trim() -ne '' })
        $units = @($lines | Where-Object { $_ -match '^UNIT .+: (DONE|STARTED)\s*$' })
        $done = @($units | Where-Object { $_ -match ': DONE\s*$' }).Count
        $finished = ($lines.Count -gt 0) -and ($lines[-1].Trim() -eq 'STATUS: FINISHED')
        if ($finished) {
            Write-Host ("  {0}: finished ({1} unit(s) done)" -f $t.Name, $done)
        } elseif ($units.Count -eq 0 -and -not ($lines | Where-Object { $_ -match '^LAST STEP:' })) {
            Write-Host ("  {0}: started, nothing saved" -f $t.Name)
        } else {
            $last = @($lines | Where-Object { $_ -match '^LAST STEP:' }) | Select-Object -Last 1
            if (-not $last) { $last = $units | Select-Object -Last 1 }
            Write-Host ("  {0}: in progress ({1}/{2} unit(s) done) -- {3}" -f $t.Name, $done, $units.Count, $last)
        }
    }
}

Write-Host 'Mutation locks:'
$locks = @(Get-MutationLockInfo)
if ($locks.Count -eq 0) { Write-Host '  none held' }
foreach ($l in $locks) {
    $flag = if ($l.ageMinutes -gt 60) { ' [OVER 1 HOUR]' } else { '' }
    Write-Host ("  {0} -- {1} (agent {2}, {3} min){4}" -f $l.file, $l.reason, $l.agent, $l.ageMinutes, $flag)
}

$statusFile = Join-Path $repo '.claude\sprint_status.json'
$phase = 'unknown'
if (Test-Path $statusFile) {
    $j = Get-Content $statusFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($j.current_sprint) { $phase = "Sprint $($j.current_sprint.number): $($j.current_sprint.status)" }
}
Write-Host "Sprint phase: $phase"
