<#
.SYNOPSIS
  Report the state of delegated agent work from files only: each agent task's
  progress, held mutation locks with their age, and the sprint phase.

.DESCRIPTION
  F317 (Sprint 82); Python since F321 (Sprint 83, ADR-0051). This file is a thin
  entry point: the hourly wake-up still runs `scripts\agent-work-status.ps1`, and
  it calls `scripts\agent-work-status.py`, which holds the logic. The output
  format is unchanged. Read-only: it stores nothing and changes nothing.

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
$py = Get-Command python, python3, py -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $py) { Write-Error 'agent-work-status: python was not found on PATH (see ADR-0051).'; exit 2 }

# The Python script writes UTF-8; make this host read it as UTF-8 (no BOM).
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$arguments = @()
if ($ScratchFolder) { $arguments += @('--scratch-folder', $ScratchFolder) }
& $py.Source (Join-Path $PSScriptRoot 'agent-work-status.py') @arguments
exit $LASTEXITCODE
