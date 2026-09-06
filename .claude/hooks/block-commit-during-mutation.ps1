# PreToolUse hook: block `git commit` while a mutation-test lock is held.
#
# WHY THIS EXISTS (Sprint 65, two occurrences in one sprint):
#
#   1. c2ec59b swept up a live mutation probe an agent had injected into
#      mock_email_data.dart seconds earlier. The probe disabled every demo
#      rule -- the exact opposite of what the Play reviewer path needs.
#   2. c5fb46b captured a mutated Play declaration: "Is this a news app?"
#      read Yes while the justification in the same table row explained the
#      app aggregates and publishes nothing. A FALSE declaration to Google,
#      committed to history.
#
# Both had the same cause: a commit landed on a shared working tree while a
# background agent was mid-mutation, between its deliberate break and its
# restore. Both were reviewed before committing. Neither review caught it,
# because a one-word No -> Yes inside a 150-line document is precisely what
# diff review does not catch. Vigilance was not the missing ingredient; a
# structural gate was.
#
# WHY A LOCK RATHER THAN A SEMAPHORE (Harold's question, 2026-09-06):
# the two parties are not symmetric. Agents mutate for seconds and always
# restore; commits are rare and long-lived. A counting semaphore models N
# interchangeable holders, which is not the situation. This is plain mutual
# exclusion, and the enforcement belongs on the COMMIT side -- blocking the
# mutation would stall the verification work that makes tests trustworthy,
# while blocking the commit costs only a short wait.
#
# STALENESS: a crashed agent must never deadlock the sprint, so a lock older
# than $StaleMinutes is ignored and reported as stale rather than honoured.
#
# CONTRACT for agents (documented in TESTING_STRATEGY.md):
#   New-MutationLock  -File <path> -Reason <text>   # before breaking anything
#   Remove-MutationLock                             # immediately after restoring
# The lock directory is .claude/mutation-locks/ and is gitignored.

param(
    [int]$StaleMinutes = 15
)

$ErrorActionPreference = 'Stop'

# The hook receives the tool call as JSON on stdin.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    # A hook must never break the session on its own parse failure.
    exit 0
}

$command = $payload.tool_input.command
if (-not $command) { exit 0 }

# Only guard commits. Everything else -- status, diff, add, push -- is fine
# while a mutation is in flight; it is the permanent record that must not
# capture a temporary state.
#
# The match must be anchored to a real invocation, not to the word appearing
# anywhere in the command. Caught immediately on this hook's own first live
# run: a self-test command that merely CONTAINED "git commit" inside a quoted
# JSON payload was blocked, which would have made every future test of this
# hook impossible to run. Require the command to START with git (optionally
# after cd/&&/;/|) so quoted occurrences and echoed text do not trigger it.
if ($command -notmatch '(^|[;&|]\s*|\bcd\s+[^;&|]+[;&|]\s*)git\s+(-C\s+\S+\s+)?commit\b') { exit 0 }

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }
$lockDir = Join-Path $projectDir '.claude\mutation-locks'

if (-not (Test-Path $lockDir)) { exit 0 }

$locks = @(Get-ChildItem -Path $lockDir -Filter '*.json' -ErrorAction SilentlyContinue)
if ($locks.Count -eq 0) { exit 0 }

$active = @()
$stale  = @()
$now    = Get-Date

foreach ($lock in $locks) {
    try {
        $info = Get-Content $lock.FullName -Raw | ConvertFrom-Json
        $created = [DateTime]::Parse($info.createdUtc).ToLocalTime()
    } catch {
        # An unparseable lock is treated as stale rather than as a block:
        # failing open here is correct, because the alternative is an
        # unclearable deadlock caused by a malformed file.
        $stale += $lock.Name
        continue
    }

    if (($now - $created).TotalMinutes -gt $StaleMinutes) {
        $stale += "$($lock.Name) (age $([int]($now - $created).TotalMinutes)m)"
    } else {
        $active += [PSCustomObject]@{
            File   = $info.file
            Reason = $info.reason
            Agent  = $info.agent
            Age    = [int]($now - $created).TotalMinutes
        }
    }
}

if ($stale.Count -gt 0) {
    Write-Host "[mutation-lock] Ignoring $($stale.Count) stale lock(s) older than $StaleMinutes minutes: $($stale -join ', ')"
    foreach ($lock in $locks) {
        if ($stale -match [regex]::Escape($lock.Name)) {
            Remove-Item $lock.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($active.Count -eq 0) { exit 0 }

$detail = ($active | ForEach-Object {
    "  - $($_.File)`n      reason: $($_.Reason)`n      held by: $($_.Agent) ($($_.Age)m ago)"
}) -join "`n"

$message = @"
[BLOCKED] A mutation-test lock is held. Committing now risks capturing a
DELIBERATELY BROKEN file in permanent history.

Locked:
$detail

This gate exists because it happened TWICE in Sprint 65:
  - c2ec59b committed a live probe that disabled every demo rule.
  - c5fb46b committed a FALSE Play declaration ("news app: Yes").
Both commits were diff-reviewed first. Neither review caught it, because a
one-word change inside a large document is exactly what diff review misses.

DO THIS:
  1. Wait for the agent holding the lock to restore the file and release it.
  2. Verify the tree is clean before committing:
       git diff <last-good-commit> --stat
     An EMPTY diff means the restore was byte-identical, not retyped.
  3. Re-run the commit.

If the holding agent has genuinely died, the lock self-expires after
$StaleMinutes minutes, or clear it deliberately:
    Remove-Item .claude\mutation-locks\*.json

Deliberate override (rare, and you must have verified the tree yourself):
add the literal token allow_mutation_commit to the command.
"@

# Deliberate, documented escape hatch -- same pattern as the stash guard.
if ($command -match 'allow_mutation_commit') {
    Write-Host "[mutation-lock] Override token present; allowing commit despite $($active.Count) active lock(s)."
    exit 0
}

Write-Host $message
exit 2
