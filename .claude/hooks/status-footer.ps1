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
    # 1. The harness sets this. Most reliable, so it wins.
    if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }

    # 2. Walk UP FROM THE CURRENT DIRECTORY looking for .claude/sprint_status.json.
    #    Required for the SHARED copy at ~/.claude/scripts/, which is not inside
    #    any repo: walking up from the script's own location finds the user's
    #    home, not the project. Without this the shared copy always reported
    #    "phase unknown" when the env var was absent.
    $dir = (Get-Location).Path
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.claude/sprint_status.json')) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    # 3. Fall back to walking up from the script (.claude/hooks -> repo root),
    #    which is correct for a copy that DOES live in the repo.
    return (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

$root = Get-RepoRoot
$statusPath = Join-Path $root '.claude/sprint_status.json'

# --- 1. TIME: always the live system clock, never a carried-forward value ---
#
# INVARIANT CULTURE is required, not cosmetic. Probed across cultures:
#   en-US -> '1:05pm'  '09/19/2026'   (correct)
#   de-DE -> '1:05'    '09.19.2026'   (am/pm VANISHES, dots not slashes)
#   tr-TR -> '1:05os'  '09.19.2026'   (Turkish designator)
# `tt` renders the culture's AM/PM designator, which is EMPTY in many
# cultures, and `/` in a .NET format string is a locale-aware date separator,
# not a literal. Harold's format is `09/19/2026 1:05pm`, so both are pinned.
# This also makes the footer identical on every machine, which matters because
# the same script is meant to run on his other laptop.
#
# "h" (not "hh") drops the leading zero so 1:15am does not render as 01:15am.
$inv  = [System.Globalization.CultureInfo]::InvariantCulture
$now  = Get-Date
$time = ($now.ToString('h:mmtt', $inv)).ToLowerInvariant()
$date = $now.ToString('MM/dd/yyyy', $inv)

# --- 2. SPRINT + PHASE: from the status file the auto-advance hook also reads,
# so the footer and the hook can never disagree about which phase we are in.
#
# PERFORMANCE, MEASURED (2026-09-19) -- recorded so it is not re-litigated:
#   whole call, out of process : ~885 ms  (powershell) / ~820 ms (pwsh 7)
#   this script's body alone   :  ~21 ms  (50 runs in process)
#   ConvertFrom-Json below     :   ~8.6 ms
#   regex on the raw JSON text :   ~0.4 ms
# So ~98% of the cost is INTERPRETER STARTUP, which no change to this file can
# remove. Swapping ConvertFrom-Json for a regex would save 8 ms of ~885 -- under
# 1% -- in exchange for hand-parsing JSON, which is exactly the "fragile input
# parsing" class F-PRECHECK check 4 exists to catch. The correct parser stays.
# Effectiveness first, then efficiency where it is real.
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
                        # Invariant here too: the Turkish locale lowercases
                        # 'I' to a dotless 'i', so a culture-sensitive
                        # ToLower would render "VALIDATION" as "valIdation".
                        $name = $inv.TextInfo.ToTitleCase($name.ToLowerInvariant())
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
