<#
.SYNOPSIS
    Stop-hook that blocks a turn which CLAIMS sprint/phase close-out is complete
    while machine-checkable close-out artifacts are still stale or missing.

.DESCRIPTION
    Sprint 50 close-out escape (Harold, 2026-07-27): Claude reported the
    post-merge close-out as done while three SPRINT_CHECKLIST.md items were
    untouched -- five GitHub issues still open, .claude/sprint_status.json
    stale by 15 sprints, and no next-sprint plan stub. The existing
    sprint-auto-advance hook could not catch it: that hook only detects a turn
    ending in a QUESTION. This turn ended in a confident completion claim, so
    it passed straight through.

    The gap this closes: "ended with a question" was enforced; "ended with work
    undone" was not.

    Detection is deliberately narrow -- it fires ONLY when the assistant's
    final message makes a close-out/completion claim AND a mechanically
    verifiable artifact contradicts it. It never guesses at intent, and it
    never fires on ordinary progress narration.

    Checks (all cheap, all filesystem/CLI, no network beyond `gh` which is
    skipped if unavailable or slow):
      1. .claude/sprint_status.json current_sprint.number matches the branch's
         sprint number, and _last_updated is not absurdly old.
      2. docs/sprints/SPRINT_<N>_SUMMARY.md exists for the PREVIOUS sprint once
         the current sprint branch exists (Phase 3.2.1 background process).
      3. No GitHub issues labeled `sprint` remain open when the close-out claim
         is made (skipped if `gh` is missing or errors).

.NOTES
    Exit 0 = allow stop. Exit 2 = block with guidance on stderr.
    Bypass: branch name containing 'allow_stop_hook_bypass'.
    Test override: payload.branch_override / payload.repo_override.
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0   # Never break the session on a malformed payload.
}

$cwd = [string]$payload.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }
if ($payload.repo_override) { $cwd = [string]$payload.repo_override }

# Last assistant message
$lastMessage = ''
try {
    if ($payload.last_assistant_message) {
        $lastMessage = [string]$payload.last_assistant_message
    } elseif ($payload.messages) {
        $assistantMsgs = @($payload.messages | Where-Object { $_.role -eq 'assistant' })
        if ($assistantMsgs.Count -gt 0) {
            $lastMessage = [string]$assistantMsgs[-1].content
        }
    }
} catch { $lastMessage = '' }

if (-not $lastMessage) { exit 0 }

# ----- Gate 1: sprint feature branch only --------------------------------
$branchOverride = [string]$payload.branch_override
if ($branchOverride) {
    $branch = $branchOverride.Trim()
} else {
    try { $branch = (& git -C $cwd branch --show-current 2>$null).Trim() } catch { $branch = '' }
}
if (-not $branch) { exit 0 }
if ($branch -match 'allow_stop_hook_bypass') { exit 0 }
if ($branch -notmatch '^feature/\d+_Sprint_(\d+)') { exit 0 }
$sprintNum = [int]$Matches[1]

# ----- Gate 2: does the message CLAIM close-out completion? ---------------
# Narrow on purpose. Ordinary progress reports must not trip this.
# Claim patterns are deliberately NARROW and anchored: they must match a claim
# about the SPRINT/CLOSE-OUT itself, never a claim about an individual task.
#
# F130-S51 (2026-07-27, the day after this hook shipped): the original line-1
# pattern used '\b(sprint|...)\b[^.\n]{0,80}\bcomplete\b', whose 80-character
# bridge matched ordinary mid-sprint status like
#   "Sprint status: Task 1 Tier 1 complete, Task 2 complete, Task 3 blocked"
# -- and then blocked the turn for having open sprint issues, which is the
# CORRECT state mid-sprint (they close at that sprint's merge). A hook firing
# on correct work is finding #2/#3 of this very audit; fixed rather than
# bypassed.
$claimPatterns = @(
    # "the sprint / phase 7 / close-out is (now) complete" -- short bridge only,
    # and the subject must be adjacent to the verb.
    '(?i)\b(the\s+)?(sprint|phase\s*7|close[- ]?out|post[- ]?merge)\s+(work\s+|process\s+)?(is|was)\s+(now\s+)?(fully\s+|genuinely\s+)?(complete|closed|done|finished)\b'
    '(?i)\bclose[- ]?out\b[^.\n]{0,40}\b(is|was)\s+(now\s+)?(complete|done|finished)\b'
    '(?i)\ball\s+(the\s+)?(post[- ]?merge|checklist|close[- ]?out)\s+(items|steps)\b[^.\n]{0,40}\b(are\s+)?(now\s+)?(complete|done)\b'
    '(?i)\beverything\s+(through|in)\s+the\s+(post[- ]?merge|checklist)\b'
    '(?i)\bready\s+for\s+(the\s+)?next\s+sprint\b'
    '(?i)\bsprint\s+\d+\s+is\s+(fully\s+)?(closed|complete)\b'
)

# Mid-sprint signals: if the message says the sprint is still in flight, it is
# reporting progress, not claiming close-out. These win over a claim match.
$midSprintPatterns = @(
    '(?i)\b(task|tier)\s+\d+\b[^.\n]{0,40}\b(blocked|in progress|not started|remaining|pending)\b'
    '(?i)\bstopping criterion\s*\d'
    '(?i)\b(is|remains)\s+blocked\b'
    '(?i)\bsprint\s+status\b'
    '(?i)\bstill\s+(executing|in\s+flight|running)\b'
)

$claimsCloseout = $false
foreach ($pat in $claimPatterns) {
    if ($lastMessage -match $pat) { $claimsCloseout = $true; break }
}
if ($claimsCloseout) {
    foreach ($pat in $midSprintPatterns) {
        if ($lastMessage -match $pat) { $claimsCloseout = $false; break }
    }
}
if (-not $claimsCloseout) { exit 0 }

# ----- Gate 3: verify the machine-checkable artifacts --------------------
$violations = @()

# 3a. sprint_status.json currency
$statusPath = Join-Path $cwd '.claude/sprint_status.json'
if (-not (Test-Path -LiteralPath $statusPath)) {
    $violations += ".claude/sprint_status.json is MISSING (SPRINT_CHECKLIST.md Phase 7.7 requires it)."
} else {
    try {
        $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        $statusSprint = [int]$status.current_sprint.number
        if ($statusSprint -ne $sprintNum) {
            $violations += ".claude/sprint_status.json current_sprint.number is $statusSprint but the branch is Sprint $sprintNum -- the file is stale. It is the state-restore file after context compaction, so a stale copy actively misleads the next session."
        }
        if ($status._last_updated) {
            try {
                $age = (Get-Date) - [datetime]$status._last_updated
                if ($age.TotalDays -gt 30) {
                    $violations += (".claude/sprint_status.json _last_updated is {0:N0} days old." -f $age.TotalDays)
                }
            } catch { }
        }
    } catch {
        $violations += ".claude/sprint_status.json is not valid JSON."
    }
}

# 3b. previous sprint summary exists (Phase 3.2.1 background process)
$prevSprint = $sprintNum - 1
if ($prevSprint -gt 0) {
    $prevSummary = Join-Path $cwd ("docs/sprints/SPRINT_{0}_SUMMARY.md" -f $prevSprint)
    $prevRetro   = Join-Path $cwd ("docs/sprints/SPRINT_{0}_RETROSPECTIVE.md" -f $prevSprint)
    if ((Test-Path -LiteralPath $prevRetro) -and -not (Test-Path -LiteralPath $prevSummary)) {
        $violations += "docs/sprints/SPRINT_${prevSprint}_SUMMARY.md is missing (Phase 3.2.1 MANDATORY -- 'do not defer')."
    }
}

# 3c. open sprint-labeled GitHub issues
try {
    $ghOut = & gh issue list --repo (& git -C $cwd remote get-url origin 2>$null) --label sprint --state open --json number 2>$null
    if ($LASTEXITCODE -eq 0 -and $ghOut) {
        $openIssues = $ghOut | ConvertFrom-Json
        if ($openIssues.Count -gt 0) {
            $nums = ($openIssues | ForEach-Object { "#$($_.number)" }) -join ', '
            $violations += "GitHub issues labeled 'sprint' are still OPEN: $nums. Note 'Closes #N' does NOT auto-fire on a feature->develop merge in this GitFlow repo -- the checklist step 'Review and close all resolved GitHub issues' exists for exactly this."
        }
    }
} catch { }   # gh unavailable/slow -> skip silently

if ($violations.Count -eq 0) { exit 0 }

# ----- Block -------------------------------------------------------------
$msg = @"
[BLOCKED by verify-closeout-complete hook]

Your final message claims sprint/phase close-out is complete, but these
SPRINT_CHECKLIST.md artifacts contradict that:

$($violations | ForEach-Object { "  - $_" } | Out-String)
Required next action: open docs/SPRINT_CHECKLIST.md, walk the 'Post-Merge
Cleanup' and 'Phase 7.7 mandatory sprint completion updates' sections item by
item, and fix each violation above. Do NOT re-assert completion until every
item is verified done -- verify by CHECKING the artifact, not by recalling
whether you did it.

This hook exists because Sprint 50's close-out reported 'complete' with five
issues open, sprint_status.json 15 sprints stale, and no next-sprint stub
(Harold, 2026-07-27). The sprint-auto-advance hook could not catch it: that
one detects turns ending in a QUESTION, and this turn ended in a confident
completion claim.

Bypass (only if a violation is genuinely not applicable): rename the branch to
include 'allow_stop_hook_bypass', or state explicitly which item does not
apply and why.
"@

[Console]::Error.WriteLine($msg)
exit 2
