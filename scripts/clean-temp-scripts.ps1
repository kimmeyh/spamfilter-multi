<#
.SYNOPSIS
  Delete stale one-off helper scripts from the session scratchpad.

.DESCRIPTION
  IMP-3 (Sprint 72). Claude writes throwaway Python/PowerShell helpers during a
  sprint -- file edits, anchor replacements, probes. They belong in the session
  SCRATCHPAD, never in the repo, because a script that mutated one file once is
  noise in `git log` forever.

  But the scratchpad is never swept, so it accumulates across sprints. This
  script is the sweep Harold asked for: run it every few sprints and it removes
  helpers older than the retention window.

  **THE PROMOTION RULE, which matters more than the deletion.** Harold, 2026-09-22:
  *"any 'temporary' python files that are used repeatedly get moved to a scripts
  location in the repository"*. If a helper is written AGAIN in a later sprint,
  it was never temporary -- it is a tool that keeps being rediscovered at full
  cost. Promote it to `scripts/` with a real name and a header, and the next
  sprint reuses it instead of rewriting it.

  `-ReportOnly` lists what WOULD be deleted and flags likely promotion
  candidates by name similarity, so the sweep is also a review.

.PARAMETER Days
  Delete files older than this. Default 10, per Harold's instruction.

.PARAMETER ReportOnly
  List candidates and promotion suggestions; delete nothing. Safe default for a
  first look.

.PARAMETER Root
  Scratchpad root to sweep. Defaults to the Claude session scratchpad for this
  project. Every path swept is UNDER that root -- the script refuses anything
  else, because a cleanup utility pointed at the wrong directory is the most
  expensive kind of bug.

.EXAMPLE
  powershell -File scripts\clean-temp-scripts.ps1 -ReportOnly
  powershell -File scripts\clean-temp-scripts.ps1
#>
param(
    [int]$Days = 10,
    [switch]$ReportOnly,
    [string]$Root = "$env:LOCALAPPDATA\Temp\claude"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Output "Scratchpad root not found: $Root"
    Write-Output "Nothing to clean."
    exit 0
}

# Resolve once and compare resolved paths. A -like check against an unresolved
# string is defeated by `..`, and this script deletes things.
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$cutoff = (Get-Date).AddDays(-$Days)

$candidates = @(
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @('.py', '.ps1', '.txt', '.md', '.json') -and
            $_.FullName -like (Join-Path $resolvedRoot '*scratchpad*') -and
            $_.LastWriteTime -lt $cutoff
        }
)

Write-Output "Scratchpad root : $resolvedRoot"
Write-Output "Retention       : $Days days (cutoff $($cutoff.ToString('yyyy-MM-dd')))"
Write-Output "Stale files     : $($candidates.Count)"
Write-Output ''

if ($candidates.Count -eq 0) {
    Write-Output 'Nothing to clean.'
    exit 0
}

# --- PROMOTION CANDIDATES ---------------------------------------------------
# A base name that recurs across sessions is the signal Harold described: the
# same helper being rewritten instead of reused. Report it whether or not we
# are deleting, because the deletion is the cheap half.
$allHelpers = @(
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.py', '.ps1') }
)
$repeated = $allHelpers |
    Group-Object -Property Name |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object -Property Count -Descending

if ($repeated) {
    Write-Output 'PROMOTION CANDIDATES -- written more than once, so not temporary:'
    foreach ($g in $repeated) {
        Write-Output ("  {0,-38} written {1} times" -f $g.Name, $g.Count)
    }
    Write-Output ''
    Write-Output '  Move these to scripts/ with a real name and a .SYNOPSIS header,'
    Write-Output '  then delete the copies. A helper rewritten each sprint costs its'
    Write-Output '  full authoring time every time, including the bugs.'
    Write-Output ''
}

if ($ReportOnly) {
    Write-Output 'WOULD DELETE (report only):'
    $candidates | ForEach-Object {
        Write-Output ("  {0}  [{1:yyyy-MM-dd}]" -f $_.FullName.Substring($resolvedRoot.Length + 1), $_.LastWriteTime)
    }
    Write-Output ''
    Write-Output "Re-run without -ReportOnly to delete these $($candidates.Count) file(s)."
    exit 0
}

$deleted = 0
$failed = 0
foreach ($f in $candidates) {
    # Belt and braces: every deletion re-verifies it is under the root.
    if ($f.FullName -notlike "$resolvedRoot*") {
        Write-Output "SKIPPED (outside root): $($f.FullName)"
        continue
    }
    try {
        Remove-Item -LiteralPath $f.FullName -Force
        $deleted++
    } catch {
        Write-Output "FAILED: $($f.FullName) -- $_"
        $failed++
    }
}

Write-Output "Deleted: $deleted"
if ($failed -gt 0) { Write-Output "Failed : $failed (likely locked; re-run later)" }
