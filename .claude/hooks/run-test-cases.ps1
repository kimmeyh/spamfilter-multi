<#
.SYNOPSIS
    Test harness for sprint-auto-advance.ps1.

.DESCRIPTION
    Pipes each .claude/hooks/test-cases/*.json file into sprint-auto-advance.ps1
    and asserts the hook's exit code against the case-name prefix:
      allow-*     -> expect exit 0 (stop allowed)
      violation-* -> expect exit 2 (stop blocked)

    Prints a per-case PASS/FAIL line and a summary. Exits 0 if all pass, 1 if
    any fail.

.NOTES
    Test cases that must be deterministic regardless of the checked-out branch
    use the "branch_override" field in their JSON payload (honored by the hook
    for test purposes only).

    Run:
      powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run-test-cases.ps1"
#>

# Native stderr from the blocked correction must NOT be treated as terminating.
$ErrorActionPreference = 'Continue'

$hook     = Join-Path $PSScriptRoot 'sprint-auto-advance.ps1'
$casesDir = Join-Path $PSScriptRoot 'test-cases'

if (-not (Test-Path -LiteralPath $hook))     { throw "Hook not found: $hook" }
if (-not (Test-Path -LiteralPath $casesDir)) { throw "Cases dir not found: $casesDir" }

$cases = Get-ChildItem -LiteralPath $casesDir -Filter '*.json' | Sort-Object Name
$pass = 0
$fail = 0
$errFile = Join-Path ([System.IO.Path]::GetTempPath()) ("aa_hook_stderr_{0}.txt" -f ([guid]::NewGuid()))

foreach ($case in $cases) {
    $name = $case.BaseName
    if ($name -like 'allow-*')          { $expected = 0 }
    elseif ($name -like 'violation-*')  { $expected = 2 }
    else {
        Write-Host ("SKIP {0} (unknown prefix)" -f $name)
        continue
    }

    $payload = Get-Content -Raw -LiteralPath $case.FullName
    # Invoke the hook in a child powershell.exe so its 'exit' does not terminate
    # us. Redirect the child's stderr to a temp file so the corrective message
    # (emitted on block) is not surfaced as a NativeCommandError.
    $payload | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook 1>$null 2>$errFile
    $actual = $LASTEXITCODE

    if ($actual -eq $expected) {
        Write-Host ("PASS {0} (exit {1})" -f $name, $actual)
        $pass++
    } else {
        Write-Host ("FAIL {0} (expected {1}, got {2})" -f $name, $expected, $actual)
        $fail++
    }
}

Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("Result: {0} passed, {1} failed, {2} total" -f $pass, $fail, ($pass + $fail))
if ($fail -gt 0) { exit 1 } else { exit 0 }
