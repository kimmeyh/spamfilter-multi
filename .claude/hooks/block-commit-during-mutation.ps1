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

# Strip quoted strings before ANY matching decision.
#
# Everything below asks "does this command DO something", never "does this
# text mention something". A commit message is data, not instruction: both
# `git commit -m "explain allow_mutation_commit"` and an echoed example of a
# git command are text, and neither should change the gate's behaviour.
# Removing quoted spans first makes that distinction structural instead of
# leaving each individual regex to re-litigate it.
#
# Found by an automated security review of this very hook (2026-09-06), and
# CONFIRMED BY PROBE before fixing: a commit whose MESSAGE contained the
# override token silently bypassed the gate. That is the worst possible
# failure for this file, because the message is the one part of a commit an
# author writes freely.
$scannable = $command
$scannable = [regex]::Replace($scannable, '"[^"]*"', '""')
$scannable = [regex]::Replace($scannable, "'[^']*'", "''")

# Only guard commits. Everything else -- status, diff, add, push -- is fine
# while a mutation is in flight; it is the permanent record that must not
# capture a temporary state.
#
# Match `git` at any command position, then allow any number of GLOBAL
# options before the `commit` subcommand. The earlier pattern only tolerated
# `-C <path>`, so `git --no-pager commit` and `git --git-dir=.git commit`
# both slipped through -- confirmed by probe, not assumed.
#
# The original version of this line was looser still: it matched the words
# "git commit" anywhere, and immediately blocked the self-test written to
# verify it. Quoted-span stripping above now handles that case properly,
# which is why this pattern no longer needs its own start-of-command anchor.
if ($scannable -notmatch '\bgit\b(?:\s+(?:--[^\s]+(?:=\S+)?|-c\s+\S+|-C\s+\S+))*\s+commit\b') { exit 0 }

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }
$lockDir = Join-Path $projectDir '.claude\mutation-locks'

if (-not (Test-Path $lockDir)) { exit 0 }

$locks = @(Get-ChildItem -Path $lockDir -Filter '*.json' -ErrorAction SilentlyContinue)
if ($locks.Count -eq 0) { exit 0 }

$active     = @()
$stale      = @()
$staleFiles = @()   # exact paths, kept separate from the display strings
# UTC on both sides of every age comparison. $created is a UTC
# DateTimeOffset, so a local $now here would reintroduce the offset bug this
# block was just fixed for.
$now        = [DateTimeOffset]::UtcNow

foreach ($lock in $locks) {
    try {
        $info = Get-Content $lock.FullName -Raw | ConvertFrom-Json
        # Parse to a UTC DateTimeOffset and compare against UTC. The earlier
        # form was `[DateTime]::Parse(...).ToLocalTime()`, which DOUBLE-
        # CONVERTS when the stored value carries an explicit offset:
        # ::Parse already normalises to local, and .ToLocalTime() then shifts
        # it by the offset AGAIN. Found while testing the stale path -- a
        # freshly-written lock was reported as 240 minutes old (exactly this
        # machine's 4-hour offset) and deleted as stale, silently reopening
        # the window this hook exists to close. The lock writer uses
        # PowerShell's Z-suffixed 'o' format so production was unaffected,
        # but a clock bug that only misfires on some inputs is worth removing
        # rather than depending on one writer never changing.
        $created = [DateTimeOffset]::Parse(
            $info.createdUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    } catch {
        # An unparseable lock is treated as stale rather than as a block:
        # failing open here is correct, because the alternative is an
        # unclearable deadlock caused by a malformed file.
        $stale      += $lock.Name
        $staleFiles += $lock.FullName
        continue
    }

    if (($now - $created).TotalMinutes -gt $StaleMinutes) {
        $stale      += "$($lock.Name) (age $([int]($now - $created).TotalMinutes)m)"
        $staleFiles += $lock.FullName
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
    # Delete by EXACT PATH, collected alongside the display strings above.
    #
    # The earlier version matched each lock's name against the $stale display
    # array, which carries an "(age Nm)" suffix -- mixing a human-readable
    # status string with the identifier used for deletion. With names that
    # share a prefix, that substring match could delete an ACTIVE lock and
    # silently reopen the very window this hook exists to close. Identifiers
    # and display text are now kept strictly apart.
    $staleFiles | Remove-Item -Force -ErrorAction SilentlyContinue
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

# Deliberate, documented escape hatch.
#
# Checked against $scannable, so the token must be a real command token and
# not text inside a commit message. It must also stand alone as its own
# argument: a substring match let `-m "... allow_mutation_commit ..."`
# disable the gate, which is exactly backwards -- the freest-form part of a
# commit was the easiest place to trip the override.
if ($scannable -match '(^|\s)allow_mutation_commit(\s|$)') {
    Write-Host "[mutation-lock] Override token present; allowing commit despite $($active.Count) active lock(s)."
    exit 0
}

Write-Host $message
exit 2
