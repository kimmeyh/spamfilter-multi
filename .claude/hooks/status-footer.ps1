<#
.SYNOPSIS
  Emits the status footer line Harold asked for, deterministically.

.DESCRIPTION
  Format: <MM/dd/yyyy> <h:mmam|pm> | Sprint <N> Phase <n.n> <Name>
  Example: 09/19/2026 1:15am | Sprint 70 Phase 5.3 Manual Validation

  WHY THIS EXISTS (Harold, 2026-09-19). The footer was assembled by hand from
  three sources -- `date`, the phase from SPRINT_EXECUTION_WORKFLOW.md, and the
  sprint number from sprint_status.json. On 2026-09-19 Harold asked whether the
  timestamp was really the system clock. It was not: the previous message's
  `12:18am` had been copied forward while the real time was `1:15am`. A stale
  timestamp is worse than no timestamp, because it looks authoritative.

  The phase and sprint number were correct in that same footer -- because they
  came from files that were actually read. The one field filled from memory was
  the one that was wrong. That is the argument for scripting it: ~80% of this
  repo's process is deterministic, and a deterministic step done by hand is a
  step that eventually gets done from memory.

.PARAMETER Phase
  Override the phase, as "n.n Name" (e.g. "7.5 Sprint Retrospective"). When
  omitted the phase is parsed from .claude/sprint_status.json current_sprint.status,
  whose leading fact is the phase by convention.

.PARAMETER Sprint
  Override the sprint number. When omitted it is read from sprint_status.json.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\status-footer.ps1
  09/19/2026 1:15am | Sprint 70 Phase 5.3 Manual Validation
#>
param(
    [string]$Phase,
    [string]$Sprint
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }
    # Walk up from this script: .claude/hooks -> .claude -> repo root
    return (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

$root = Get-RepoRoot
$statusPath = Join-Path $root '.claude/sprint_status.json'

# --- 1. TIME: always the live system clock, never a carried-forward value ---
# "h" (not "hh") drops the leading zero so 1:15am does not render as 01:15am.
$now = Get-Date
$time = ($now.ToString('h:mmtt')).ToLower()
$date = $now.ToString('MM/dd/yyyy')

# --- 2. SPRINT + PHASE: from the status file the auto-advance hook also reads,
# so the footer and the hook can never disagree about which phase we are in.
$sprintNum = $Sprint
$phaseText = $Phase

if (-not $sprintNum -or -not $phaseText) {
    if (Test-Path -LiteralPath $statusPath) {
        try {
            $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
            $cs = $st.current_sprint
            if (-not $sprintNum -and $cs.number) { $sprintNum = [string]$cs.number }
            if (-not $phaseText -and $cs.status) {
                # The phase is the LEADING fact of the status string by
                # convention ("Sprint 70 Phase 5.3 MANUAL VALIDATION -- ...").
                # Anchored, so prose later in the field cannot be mistaken for
                # the phase -- the same defect class that broke Gate 1c in
                # Sprint 67, where an unanchored search matched "Manual
                # Validation" inside a sentence describing an approval scope.
                $m = [regex]::Match(
                    [string]$cs.status,
                    '(?i)^\s*(?:sprint\s+\d+\s+)?phase\s+(\d+\.\d+)\s+([^.\-(]+)')
                if ($m.Success) {
                    $num  = $m.Groups[1].Value
                    $name = ($m.Groups[2].Value).Trim()
                    # Title Case a SHOUTED name ("MANUAL VALIDATION").
                    if ($name -cmatch '^[A-Z0-9 ]+$') {
                        $ti = (Get-Culture).TextInfo
                        $name = $ti.ToTitleCase($name.ToLower())
                    }
                    $phaseText = "$num $name"
                }
            }
        } catch {
            # A malformed status file must not stop the footer being emitted --
            # a footer with an unknown phase is still better than no footer.
        }
    }
}

$parts = @("$date $time")
$sprintPart = ''
if ($sprintNum) { $sprintPart = "Sprint $sprintNum" }
if ($phaseText) {
    $sprintPart = if ($sprintPart) { "$sprintPart Phase $phaseText" } else { "Phase $phaseText" }
}
if (-not $sprintPart) { $sprintPart = 'phase unknown -- check .claude/sprint_status.json' }

Write-Output (($parts + $sprintPart) -join ' | ')
