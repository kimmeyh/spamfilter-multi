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

# 3a-1. the sprint PR exists (Phase 3.3.1 deliverable, verified at close-out)
#
# Sprint 52 IMP-6 (Harold, 2026-08-02): the sprint ran to Phase 7 with NO pull
# request at all. The PR lifecycle has four checkpoints (3.3.1, 3.7, end of
# Phase 5, 7.7) and EACH carries a "create it now if it does not exist"
# fallback -- so every checkpoint quietly assumed a later one would catch it,
# and the miss stayed silent through all four. The primary guard is
# require-sprint-cards.ps1 (blocks task commits); this is the backstop that
# makes a close-out claim impossible while pr_number is still null.
#
# PRECONDITION ADDED 2026-08-16 (F170, Sprint 61) after this check fired as a
# FALSE POSITIVE three times in one session. Phase 3.3.1 creates the draft PR
# AT PLAN APPROVAL -- so before approval a null pr_number is the CORRECT state,
# not a miss. That window is not a rare edge: Harold's standing release cycle
# runs merge -> `develop`, merge -> `main`, Backlog Refinement pass 1
# (completeness sweep), Microsoft Store release, Backlog Refinement pass 2
# (scope selection), THEN Phase 3 planning. `pr_number` is legitimately null
# across that entire span, which is exactly when close-out claims are made
# ("Sprint N closed, ready for next sprint").
#
# Same defect class as check 3c below and as the sprint-auto-advance Gate 1c
# fix: a post-condition tested without its PRECONDITION. Gated on the same
# signal require-sprint-cards.ps1 uses -- `plan_approved` -- so the three
# sprint hooks now agree on when a PR is owed.
if ($status -and $null -ne $status.current_sprint -and
    $status.current_sprint.plan_approved -eq $true) {
    $prNum = $status.current_sprint.pr_number
    if ($null -eq $prNum -or [string]$prNum -eq '') {
        $violations += "No pull request recorded for Sprint $sprintNum (.claude/sprint_status.json current_sprint.pr_number is null) even though plan_approved is true. Phase 3.3.1 requires a DRAFT PR created at plan approval, in parallel with the first execution task. Create it (gh pr create --draft --base develop) and record pr_number / pr_url. Keep it a DRAFT until the end of Phase 7.7."
    }
}

# 3a-2. uncommitted non-coding-agent working files (0*.txt / 0*.md at root)
#
# Harold, 2026-08-02: "there are often file changes made by the non-coding agent
# team during sprints ... I have yet to see one that didn't end up being
# committed across all sprints." These are his working documents -- testing
# feedback, retrospective feedback, prompts, backlog notes -- authored while the
# sprint runs. The default is COMMIT, and leaving one behind at close-out is a
# miss rather than a decision.
#
# This is deliberately a close-out gate, not a per-commit one: the files change
# repeatedly mid-sprint and blocking each time would fire on correct work. It
# only needs to be true by the END of the sprint.
# `dirty_zero_files_override` lets a test case supply the porcelain output
# directly. Without it a fixture would need its OWN git repo, and a nested
# repo commits as a broken gitlink that does not survive a fresh clone (every
# other fixture here is a plain directory). Test-only; never set in production.
try {
    $dirty = $null
    if ($null -ne $payload.dirty_zero_files_override) {
        $dirty = [string]$payload.dirty_zero_files_override
        if ([string]::IsNullOrWhiteSpace($dirty)) { $dirty = $null }
    } else {
        $dirty = & git -C $cwd status --porcelain -- '0*' 2>$null
    }
    if ($dirty) {
        $names = @($dirty | ForEach-Object { ($_ -replace '^..\s*', '').Trim() }) -join ', '
        $violations += "Uncommitted non-coding-agent working file(s) at repo root: $names. These are Harold's 0* working documents and are expected to be committed (they have been, every sprint). Stage and commit them -- do NOT read them (the deny-list blocks it), so use a neutral message rather than paraphrasing content you cannot see."
    }
} catch { }

# 3d. Phase 5 evidence artifacts exist (Sprint 62 retro IMP-1, Harold-approved
#     2026-08-23). Sprint 62 reached Manual Validation with 5.1.1 (automated
#     code review), 5.1.2 (F-PRECHECK), and 5.1.5 (WinWright sweep) silently
#     unrun -- caught only by the line-by-line checklist walk before Phase 7,
#     after which the review surfaced a REAL user-affecting bug (C-2) that
#     should have been found before Harold validated. A close-out claim now
#     requires all three evidence markers in the sprint plan.
#
#     Enforced for Sprint 63 onward only: earlier plans predate the artifact
#     conventions, and this hook's history (F130-S51, the 3a-1 and 3c false
#     positives) says a check that fires on historically-correct state trains
#     bypass. Marker matching is deliberately loose -- the artifact FORMAT
#     lives in SPRINT_EXECUTION_WORKFLOW.md 5.1.2/5.1.5; this only proves the
#     evidence sections exist at all.
if ($sprintNum -ge 63 -and $status -and $null -ne $status.current_sprint -and
    $status.current_sprint.plan_approved -eq $true) {
    $planPath = Join-Path $cwd ("docs/sprints/SPRINT_{0}_PLAN.md" -f $sprintNum)
    if (Test-Path -LiteralPath $planPath) {
        $planText = Get-Content -LiteralPath $planPath -Raw
        $evidence = @(
            @{ Name = '5.1.1 automated code review record'; Pattern = '(?i)(5\.1\.1|automated code review|code[- ]reviewer)' },
            @{ Name = '5.1.2 F-PRECHECK record';            Pattern = '(?i)F-PRECHECK' },
            @{ Name = '5.1.5 WinWright sweep artifact';     Pattern = '(?i)WinWright[\s\S]{0,200}?sweep|sweep[\s\S]{0,200}?WinWright' }
        )
        foreach ($e in $evidence) {
            if ($planText -notmatch $e.Pattern) {
                $violations += "Phase 5 evidence missing from SPRINT_${sprintNum}_PLAN.md: no $($e.Name). SPRINT_CHECKLIST.md Phase 5 requires all three BEFORE Manual Validation; a close-out claim with any of them absent means Phase 5 was skipped, not finished (Sprint 62 escape: the post-hoc review then found a real bug after Harold had already validated)."
            }
        }

        # 3e. Sweep-at-HEAD (Sprint 62 retro IMP-2, Harold-approved 2026-08-23):
        #     the sweep artifact must record the commit it ran at as
        #     `sweep-head: <hash>`, and no lib/ui commit may be newer -- this is
        #     what would have caught Sprint 61 shipping F169 (chips -> dropdown)
        #     with every script selector left rotting. Git-dependent, so it
        #     skips silently in fixture tests (skip_git_checks) or when git
        #     cannot resolve the recorded hash.
        if (-not $payload.skip_git_checks) {
            $sweepHead = $null
            if ($planText -match '(?im)^\s*-?\s*sweep-head:\s*([0-9a-f]{7,40})\b') {
                $sweepHead = $Matches[1]
            }
            if ($sweepHead) {
                try {
                    $newerUi = & git -C $cwd log --oneline "$sweepHead..HEAD" -- 'mobile-app/lib/ui' 2>$null
                    if ($LASTEXITCODE -eq 0 -and $newerUi) {
                        $violations += "The WinWright sweep artifact records sweep-head: $sweepHead, but lib/ui commits exist AFTER it: $(@($newerUi).Count) commit(s). The sweep proved an OLDER UI; re-run it at HEAD and update sweep-head (this is the Sprint 61 F169 rot class -- a UI change shipped after the last sweep)."
                    }
                } catch { }
            } else {
                try {
                    $uiChanged = & git -C $cwd diff --name-only 'origin/develop...HEAD' -- 'mobile-app/lib/ui' 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        $uiChanged = & git -C $cwd diff --name-only 'develop...HEAD' -- 'mobile-app/lib/ui' 2>$null
                    }
                    if ($uiChanged) {
                        $violations += "This sprint changed mobile-app/lib/ui but SPRINT_${sprintNum}_PLAN.md's sweep artifact records no 'sweep-head: <hash>' line. Record the commit the sweep ran at so close-out can prove the sweep covered the FINAL UI (Sprint 62 retro IMP-2)."
                    }
                } catch { }
            }
        }
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

# 3c. open sprint-labeled GitHub issues -- POST-MERGE ONLY
#
# "Review and close all resolved GitHub issues" lives under the checklist's
# `## Post-Merge Cleanup` section, whose FIRST item is `PR merged to develop`.
# So open sprint issues are only a violation once the sprint PR has actually
# merged. Before that they are the CORRECT state: closing a sprint's task cards
# while its code is still sitting in an unmerged PR would mark the work resolved
# before it exists on develop.
#
# Fixed 2026-07-30 (Sprint 51) after this check blocked a turn at Phase 7.7 with
# PR #285 legitimately open and Ready-for-Review. Same defect class as the
# sprint-auto-advance Gate 1c fix earlier in this sprint: the check tested a
# post-condition without testing its PRECONDITION. A hook that fires on correct
# work trains people to bypass it, which costs more than the escape it prevents.
try {
    $repoUrl = & git -C $cwd remote get-url origin 2>$null

    # Precondition: has THIS sprint's PR merged? Only then is issue-closing due.
    $prMerged = $false
    $branch = (& git -C $cwd branch --show-current 2>$null)
    if ($branch) {
        $prJson = & gh pr list --repo $repoUrl --head $branch.Trim() --state all --json state,mergedAt 2>$null
        if ($LASTEXITCODE -eq 0 -and $prJson) {
            $prs = $prJson | ConvertFrom-Json
            foreach ($pr in $prs) {
                if ($pr.state -eq 'MERGED' -or $pr.mergedAt) { $prMerged = $true }
            }
        }
        # No PR found for this branch at all -> cannot be post-merge either.
    }

    if ($prMerged) {
        $ghOut = & gh issue list --repo $repoUrl --label sprint --state open --json number 2>$null
        if ($LASTEXITCODE -eq 0 -and $ghOut) {
            $openIssues = $ghOut | ConvertFrom-Json
            if ($openIssues.Count -gt 0) {
                $nums = ($openIssues | ForEach-Object { "#$($_.number)" }) -join ', '
                $violations += "The sprint PR has MERGED but GitHub issues labeled 'sprint' are still OPEN: $nums. 'Closes #N' does NOT auto-fire on a feature->develop merge in this GitFlow repo -- the Post-Merge Cleanup step 'Review and close all resolved GitHub issues' exists for exactly this. Verify with ``gh issue list --label sprint --state open`` returning empty."
            }
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
