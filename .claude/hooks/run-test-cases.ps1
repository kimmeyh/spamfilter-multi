<#
.SYNOPSIS
    Test harness for the repo's hooks.

.DESCRIPTION
    Pipes each test-case JSON file into the hook it targets and asserts the
    hook's exit code against the case-name prefix:
      allow-*     -> expect exit 0 (action allowed)
      violation-* -> expect exit 2 (action blocked)

    Hook routing is by DIRECTORY (F130-S51 R-2, Sprint 51 -- the harness was
    previously hard-wired to sprint-auto-advance.ps1, so the other hooks had
    no test coverage at all and their false positives went unnoticed):
      test-cases/*.json                  -> sprint-auto-advance.ps1  (Stop)
      test-cases/stash-guard/*.json      -> block-carry-forward-stash.ps1 (PreToolUse)
      test-cases/closeout/*.json         -> verify-closeout-complete.ps1 (Stop)

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

# Native stderr from the blocked correction must NOT be treated as terminating.
$ErrorActionPreference = 'Continue'

$casesDir = Join-Path $PSScriptRoot 'test-cases'
if (-not (Test-Path -LiteralPath $casesDir)) { throw "Cases dir not found: $casesDir" }

# subdirectory name -> hook script
$routes = @{
    ''            = 'sprint-auto-advance.ps1'
    'stash-guard' = 'block-carry-forward-stash.ps1'
    'closeout'    = 'verify-closeout-complete.ps1'
}

$pass = 0
$fail = 0
$errFile = Join-Path ([System.IO.Path]::GetTempPath()) ("hook_stderr_{0}.txt" -f ([guid]::NewGuid()))

foreach ($route in $routes.Keys | Sort-Object) {
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
        else {
            Write-Host ("SKIP {0} (unknown prefix)" -f $name)
            continue
        }

        $label = if ($route) { "$route/$name" } else { $name }
        $payload = Get-Content -Raw -LiteralPath $case.FullName
        # Invoke the hook in a child powershell.exe so its 'exit' does not
        # terminate us. Redirect stderr to a temp file so the corrective
        # message (emitted on block) is not surfaced as a NativeCommandError.
        $payload | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook 1>$null 2>$errFile
        $actual = $LASTEXITCODE

        if ($actual -eq $expected) {
            Write-Host ("PASS {0} (exit {1})" -f $label, $actual)
            $pass++
        } else {
            Write-Host ("FAIL {0} (expected {1}, got {2})" -f $label, $expected, $actual)
            $fail++
        }
    }
}

Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("Result: {0} passed, {1} failed, {2} total" -f $pass, $fail, ($pass + $fail))
if ($fail -gt 0) { exit 1 } else { exit 0 }
