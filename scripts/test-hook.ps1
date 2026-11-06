<#
.SYNOPSIS
  Run a Claude Code hook against a crafted input and report its verdict.

.DESCRIPTION
  IMP-3 promotion (Sprint 72). This is the generalized form of a `probe.ps1`
  that has been hand-written repeatedly, in this repo and others, in two
  recognisable shapes:

    1. feed a tool-call payload to a PreToolUse hook and see ALLOW or BLOCK;
    2. feed a message to a Stop hook and see whether it fires.

  Harold, 2026-09-22, on the promotion rule: *"Would they benefit from
  generalization (they were written for narrow scopes, but would be very useful
  if the scope was expanded a little?"* -- yes. The narrow versions each hard-
  coded one hook path, one payload shape and one set of patterns, so none of
  them survived the sprint that produced it.

  **Why this matters beyond convenience.** A hook is a gate, and a gate that
  passes because nothing matched is indistinguishable from a gate that passes
  because nothing is wrong (Sprint 69 F210). The only way to tell them apart is
  to feed the gate something it SHOULD catch and confirm it does. That is a
  failure-path test, and this script is what makes it a one-liner instead of a
  twenty-line throwaway.

.PARAMETER HookPath
  The hook to run. Relative paths resolve against `.claude/hooks/`. A `.py` hook runs
  under python (F321, Sprint 83); any other file runs under PowerShell. A bare name with
  no extension is not guessed: give `block-blind-staging.py` or `.ps1`.

.PARAMETER Command
  A shell command to wrap as a Bash tool-call payload (PreToolUse shape).

.PARAMETER Message
  An assistant message to wrap as a Stop payload. Use to test Stop hooks such
  as `sprint-auto-advance.ps1`.

.PARAMETER Cwd
  Working directory reported to the hook. Defaults to the repo root. Point it
  at a fixture directory to exercise a specific `sprint_status.json`.

.PARAMETER Json
  A complete payload, for a hook shape the switches above do not cover.

.PARAMETER ExpectBlock
  Assert the hook BLOCKS (exit 2; any other non-zero exit is a hook error that
  ALLOWS the command and fails this check). Exits 1 if it does not, so this can
  gate a script.

.PARAMETER ExpectAllow
  Assert the hook ALLOWS (exit 0). Exits 1 if it does not.

.NOTES
  Exit codes: 0 = the probe ran and every assertion held; 1 = an assertion
  failed OR the hook crashed (any exit other than 0 or 2); 2 = this script
  could not run the hook. A crashed hook is never reported as success, with or
  without -ExpectBlock / -ExpectAllow (Sprint 83 retro IMP-3, Harold: "the
  script should never crash with a success").

.EXAMPLE
  # Does the stash guard still catch a real stash?
  scripts\test-hook.ps1 stash-guard.ps1 -Command 'git stash push -m wip' -ExpectBlock

.EXAMPLE
  # Does the auto-advance hook fire on a bare commitment?
  scripts\test-hook.ps1 sprint-auto-advance.ps1 -Message 'Starting F219 now.'

.EXAMPLE
  # Exercise a hook against a fixture's sprint state.
  scripts\test-hook.ps1 sprint-auto-advance.ps1 -Message 'Ready for Manual Validation.' `
      -Cwd .claude\hooks\test-cases\fixtures\f193-evidence-missing
#>
param(
    [Parameter(Mandatory, Position = 0)][string]$HookPath,
    [string]$Command,
    [string]$Message,
    [string]$Cwd,
    [string]$Json,
    [switch]$ExpectBlock,
    [switch]$ExpectAllow
)

$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) {
    $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Parent $PSScriptRoot
}

# Resolve the hook: absolute, repo-relative, or a bare name under .claude/hooks.
$resolved = $HookPath
if (-not (Test-Path -LiteralPath $resolved)) {
    $try = Join-Path $repoRoot $HookPath
    if (Test-Path -LiteralPath $try) {
        $resolved = $try
    } else {
        $try = Join-Path (Join-Path $repoRoot '.claude\hooks') $HookPath
        if (Test-Path -LiteralPath $try) { $resolved = $try }
    }
}
if (-not (Test-Path -LiteralPath $resolved)) {
    Write-Output "Hook not found: $HookPath"
    Write-Output "Looked in: as given, under the repo root, and under .claude/hooks/."
    exit 2
}
$resolved = (Resolve-Path -LiteralPath $resolved).Path

if (-not $Cwd) { $Cwd = $repoRoot }
if (Test-Path -LiteralPath $Cwd) { $Cwd = (Resolve-Path -LiteralPath $Cwd).Path }

# Build the payload. Exactly one shape, chosen by which switch was supplied.
if ($Json) {
    $payload = $Json
} elseif ($Command) {
    $payload = @{
        tool_name  = 'Bash'
        tool_input = @{ command = $Command }
        cwd        = $Cwd
    } | ConvertTo-Json -Depth 6 -Compress
} elseif ($Message) {
    $payload = @{
        session_id              = 'test-hook'
        cwd                     = $Cwd
        hook_event_name         = 'Stop'
        last_assistant_message  = $Message
    } | ConvertTo-Json -Depth 6 -Compress
} else {
    Write-Output 'Supply -Command, -Message or -Json.'
    exit 2
}

# F321 (Sprint 83): a Python hook (.py) runs under python; every other hook runs under PowerShell.
if ($resolved -like '*.py') {
    # Sprint 83 7.7.1 (Copilot PR #534): ONLY "python", the interpreter .claude/settings.json
    # runs every hook with. A fallback (python3, py) would let this test pass on a machine
    # where Claude Code itself cannot start the hook, so the hook would be off and the test green.
    $py = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $py) {
        Write-Output 'python not found on PATH. .claude/settings.json runs hooks with "python", so the real hook cannot run either.'
        exit 2
    }
}
# Sprint 83 retro IMP-3: under Windows PowerShell 5.1 with ErrorActionPreference
# 'Stop', "2>&1" turns the hook's FIRST stderr line into a terminating
# NativeCommandError, so this script died (exit 1) on every hook that BLOCKS
# with a message -- -ExpectBlock failed on a hook that worked. The hook's
# stderr is its verdict text, not a probe error: read it with 'Continue'.
$ErrorActionPreference = 'Continue'
# A stderr line arrives as an ErrorRecord whose TargetObject is the original
# text (a blank line would otherwise print as "RemoteException").
$asText = { if ($_ -is [System.Management.Automation.ErrorRecord]) { "$($_.TargetObject)" } else { "$_" } }
if ($resolved -like '*.py') {
    $stderr = $payload | & $py $resolved 2>&1 | ForEach-Object $asText
} else {
    $stderr = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $resolved 2>&1 |
        ForEach-Object $asText
}
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

# Sprint 83 7.7.1 (code-reviewer pass 2 F1 HIGH, silent-failure-hunter M-3):
# Claude Code blocks ONLY on exit 2. Any other non-zero exit is a hook ERROR
# and the command is ALLOWED (a crashed Python hook exits HOOK_ERROR = 1,
# hooklib.py). Reporting it as BLOCK let -ExpectBlock pass a hook that was off.
$verdict = switch ($code) {
    0       { 'ALLOW' }
    2       { 'BLOCK (exit 2)' }
    default { "HOOK ERROR (exit $code, the command is ALLOWED)" }
}
Write-Output "hook    : $(Split-Path -Leaf $resolved)"
Write-Output "cwd     : $Cwd"
Write-Output "verdict : $verdict"
if ($stderr) {
    Write-Output '--- hook output ---'
    $stderr | ForEach-Object { Write-Output "  $_" }
}

# Assertions last, so the diagnostic output is always visible even on failure --
# a probe that fails silently is worse than no probe.
if ($ExpectBlock -and $code -ne 2) {
    Write-Output ''
    Write-Output "FAIL: expected BLOCK (exit 2), got $verdict."
    exit 1
}
if ($ExpectAllow -and $code -ne 0) {
    Write-Output ''
    Write-Output "FAIL: expected ALLOW (exit 0), got $verdict."
    exit 1
}
# Sprint 83 retro IMP-3: a crashed hook fails the probe even with no -Expect
# switch. Before this, a plain probe of a crashed hook printed "HOOK ERROR" and
# still exited 0, so a caller that read only the exit code saw success.
if ($code -ne 0 -and $code -ne 2) {
    Write-Output ''
    Write-Output "FAIL: the hook crashed ($verdict)."
    exit 1
}
if ($ExpectBlock -or $ExpectAllow) {
    Write-Output ''
    Write-Output 'PASS'
}
exit 0
