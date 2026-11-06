<#
.SYNOPSIS
    Test harness for the repo's hooks.

.DESCRIPTION
    Pipes each test-case JSON file into the hook it targets and asserts the
    hook's exit code against the case-name prefix:
      allow-*     -> expect exit 0 (action allowed)
      violation-* -> expect exit 2 (action blocked)
      warn-*      -> expect exit 0 AND a hookSpecificOutput.additionalContext
                     warning on stdout (Sprint 82 retro IMP-7); an allow-*
                     case must print no such warning

    Hook routing is by DIRECTORY (F130-S51 R-2, Sprint 51 -- the harness was
    previously hard-wired to sprint-auto-advance.ps1, so the other hooks had
    no test coverage at all and their false positives went unnoticed):
      test-cases/*.json                  -> sprint-auto-advance.ps1  (Stop)
      test-cases/stash-guard/*.json      -> block-carry-forward-stash.py (PreToolUse)
      test-cases/closeout/*.json         -> verify-closeout-complete.py (Stop; Python since F327, Sprint 84)
      test-cases/sprint-cards/*.json     -> require-sprint-cards.py (PreToolUse)
      test-cases/heredoc-guard/*.json    -> block-heredoc-python-backslash.py (PreToolUse)
      test-cases/staging-guard/*.json    -> block-blind-staging.py (PreToolUse)
      test-cases/commit-lock/*.json      -> block-commit-during-mutation.py (PreToolUse; F321, Sprint 83)
      test-cases/velocity-warn/*.json    -> warn-commit-without-velocity.py (PreToolUse)

    Prints a per-case PASS/FAIL line and a summary. Exits 0 if all pass, 1 if
    any fail.

.NOTES
    Test cases must be DETERMINISTIC: they must not depend on the checked-out
    branch or on the live repo's sprint phase. Use "branch_override" and point
    "cwd" at a fixture under test-cases/fixtures/ (Sprint 51: four cases were
    silently environment-dependent and flipped when the live sprint changed
    phase).

    Run:
      powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run-test-cases.ps1"
#>

# Optional: run only these routes (folder names such as 'staging-guard'; '(top)' is the top level).
# Omit to run everything, which is what AC-1 and the pre-commit run do.
param([string[]]$OnlyRoute)

# Native stderr from the blocked correction must NOT be treated as terminating.
$ErrorActionPreference = 'Continue'

$casesDir = Join-Path $PSScriptRoot 'test-cases'
if (-not (Test-Path -LiteralPath $casesDir)) { throw "Cases dir not found: $casesDir" }

# subdirectory name -> hook script
$routes = @{
    ''             = 'sprint-auto-advance.ps1'
    'stash-guard'  = 'block-carry-forward-stash.py'          # Sprint 84 F326; Python since F321 (Sprint 83 ADR-0051)
    'closeout'     = 'verify-closeout-complete.py'           # Sprint 84 F327; Python since F321 (Sprint 83 ADR-0051)
    'sprint-cards' = 'require-sprint-cards.py'               # Sprint 84 F326; Python since F321 (Sprint 83 ADR-0051)
    'heredoc-guard' = 'block-heredoc-python-backslash.py'    # Sprint 74 retro IMP-6; Python since F321 (Sprint 83)
    'staging-guard' = 'block-blind-staging.py'               # Sprint 76 retro IMP-4; Python since F321 (Sprint 83)
    'commit-lock'   = 'block-commit-during-mutation.py'      # F321 (Sprint 83): first test cases for this hook
    'velocity-warn' = 'warn-commit-without-velocity.py'      # Sprint 82 retro IMP-7; Python since Sprint 84 F326
}

# F321 (Sprint 83, ADR-0051): a hook file ending in .py runs under python, any
# other under Windows PowerShell. Both take the payload on stdin.
$pythonExe = (Get-Command python, python3 -ErrorAction SilentlyContinue | Select-Object -First 1).Source

$pass = 0
$fail = 0
$errFile = Join-Path ([System.IO.Path]::GetTempPath()) ("hook_stderr_{0}.txt" -f ([guid]::NewGuid()))

# velocity-warn cases run against REAL git state (improvement review H3): two
# throwaway repos, one with docs/CODING_VELOCITY.md modified, one with it
# staged. Case payloads name them as {{REPO_MODIFIED}} and {{REPO_STAGED}}.
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hook_repos_{0}" -f ([guid]::NewGuid()))
$fixtureRepos = @{}
foreach ($kind in 'MODIFIED', 'STAGED') {
    $repo = Join-Path $fixtureRoot $kind.ToLower()
    New-Item -ItemType Directory -Force (Join-Path $repo 'docs'), (Join-Path $repo 'mobile-app') | Out-Null
    git -C $repo init -q 2>$null
    Set-Content -LiteralPath (Join-Path $repo 'docs\CODING_VELOCITY.md') 'v1'
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'a'
    Set-Content -LiteralPath (Join-Path $repo 'mobile-app\keep.txt') 'k'
    git -C $repo add -A 2>$null
    git -C $repo -c user.email=t@t -c user.name=t commit -q -m init 2>$null
    Set-Content -LiteralPath (Join-Path $repo 'docs\CODING_VELOCITY.md') 'v2'
    if ($kind -eq 'STAGED') { git -C $repo add docs/CODING_VELOCITY.md 2>$null }
    $fixtureRepos[$kind] = $repo.Replace('\', '/')
}

# commit-lock cases (F321, Sprint 83) run against real lock folders built fresh
# for every run, because a lock goes stale after 15 minutes and a fixed
# createdUtc in a committed file would flip the cases. Placeholders in the case
# payload's cwd: {{LOCK_ACTIVE}} one fresh lock; {{LOCK_STALE}} one 60 minutes
# old (the hook deletes it); {{LOCK_BAD}} an unparseable lock (treated as
# stale); {{LOCK_NONE}} a project with no lock folder.
# The folders are rebuilt IMMEDIATELY BEFORE EACH commit-lock case (New-LockRepos):
# this suite runs for many minutes, and a fixture built once at start was stale
# by the time its case ran.
function New-LockRepos([string]$caseName) {
$lockRepos = @{}
foreach ($kind in 'ACTIVE', 'STALE', 'BAD', 'NONE') {
    $project = Join-Path $fixtureRoot ("lock_{0}_{1}" -f $caseName, $kind.ToLower())
    New-Item -ItemType Directory -Force (Join-Path $project '.claude') | Out-Null
    if ($kind -ne 'NONE') {
        $lockDir = Join-Path $project '.claude\mutation-locks'
        New-Item -ItemType Directory -Force $lockDir | Out-Null
        $created = if ($kind -eq 'STALE') { (Get-Date).ToUniversalTime().AddMinutes(-60) } else { (Get-Date).ToUniversalTime() }
        $body = if ($kind -eq 'BAD') { '{not json' } else {
            (@{ file = 'a.md'; reason = 'runner fixture'; agent = 'run-test-cases'; createdUtc = $created.ToString('o') } | ConvertTo-Json)
        }
        Set-Content -LiteralPath (Join-Path $lockDir 'a.md.json') -Value $body -Encoding UTF8
    }
    $lockRepos[$kind] = $project.Replace('\', '/')
}
return $lockRepos
}

foreach ($route in $routes.Keys | Sort-Object) {
    $routeKey = if ($route) { $route } else { '(top)' }
    if ($OnlyRoute -and ($routeKey -notin $OnlyRoute)) { continue }
    $dir  = if ($route) { Join-Path $casesDir $route } else { $casesDir }
    $hook = Join-Path $PSScriptRoot $routes[$route]

    if (-not (Test-Path -LiteralPath $dir))  { continue }
    if (-not (Test-Path -LiteralPath $hook)) { throw "Hook not found: $hook" }

    # Top-level dir: only its own files (subdirectories are other routes).
    $cases = Get-ChildItem -LiteralPath $dir -Filter '*.json' | Sort-Object Name

    foreach ($case in $cases) {
        $name = $case.BaseName
        if ($name -like 'allow-*')         { $expected = 0 }
        elseif ($name -like 'violation-*') { $expected = 2 }
        elseif ($name -like 'warn-*')      { $expected = 0 }
        else {
            Write-Host ("SKIP {0} (unknown prefix)" -f $name)
            continue
        }

        $label = if ($route) { "$route/$name" } else { $name }
        $lockRepos = if ($route -eq 'commit-lock') { New-LockRepos $name } else { @{ ACTIVE = ''; STALE = ''; BAD = ''; NONE = '' } }
        $payload = (Get-Content -Raw -LiteralPath $case.FullName).
            Replace('{{REPO_MODIFIED}}', $fixtureRepos['MODIFIED']).
            Replace('{{REPO_STAGED}}', $fixtureRepos['STAGED']).
            Replace('{{LOCK_ACTIVE}}', $lockRepos['ACTIVE']).
            Replace('{{LOCK_STALE}}', $lockRepos['STALE']).
            Replace('{{LOCK_BAD}}', $lockRepos['BAD']).
            Replace('{{LOCK_NONE}}', $lockRepos['NONE'])
        # Invoke the hook in a child process so its 'exit' does not
        # terminate us. Redirect stderr to a temp file so the corrective
        # message (emitted on block) is not surfaced as a NativeCommandError.
        # commit-lock cases: the hook must find its lock folder from the payload
        # cwd, so CLAUDE_PROJECT_DIR is cleared for the child (it would win).
        $savedProjectDir = $env:CLAUDE_PROJECT_DIR
        if ($route -eq 'commit-lock') { $env:CLAUDE_PROJECT_DIR = $null }
        try {
            if ($hook -like '*.py') {
                if (-not $pythonExe) { throw 'python not found on PATH (needed for the .py hook routes).' }
                $stdout = ($payload | & $pythonExe $hook 2>$errFile) -join "`n"
            } else {
                $stdout = ($payload | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook 2>$errFile) -join "`n"
            }
            $actual = $LASTEXITCODE
        } finally {
            $env:CLAUDE_PROJECT_DIR = $savedProjectDir
        }
        # Parse it: a stdout that merely CONTAINS the word is not a warning
        # Claude Code can read (improvement review H7).
        $warned = $false
        if ($stdout) {
            try { $warned = [bool](($stdout | ConvertFrom-Json).hookSpecificOutput.additionalContext) } catch { $warned = $false }
        }
        $warnOk = if ($name -like 'warn-*') { $warned } elseif ($name -like 'allow-*') { -not $warned } else { $true }

        if ($actual -eq $expected -and $warnOk) {
            Write-Host ("PASS {0} (exit {1})" -f $label, $actual)
            $pass++
        } else {
            Write-Host ("FAIL {0} (expected {1}, got {2}; warning printed: {3})" -f $label, $expected, $actual, $warned)
            $fail++
        }
    }
}

Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("Result: {0} passed, {1} failed, {2} total" -f $pass, $fail, ($pass + $fail))
if ($fail -gt 0) { exit 1 } else { exit 0 }
