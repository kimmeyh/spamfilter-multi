<#
.SYNOPSIS
  Mutation-test a test (or a hook suite): break the code it guards, run it,
  confirm it goes red, restore the code byte for byte.

.DESCRIPTION
  Sprint 74 retro IMP-4 (Harold, 2026-09-29): promoted from session scratch
  helpers written twice in this project (a `mutate.py`, then a `mutate.ps1`,
  used for ~30 mutations in Sprint 74). Per the Sprint 72 promotion rule, a
  helper written twice was never temporary.

  Two defects of the scratch version are fixed here:
    1. Spec files are read as UTF-8. Windows PowerShell 5.1 reads files in
       the system code page by default, so an anchor containing a non-ASCII
       character (a bullet in a Dart string) never matched.
    2. Anchors follow the TARGET file's line endings. A find string written
       with "\n" now matches a CRLF file (and vice versa); the scratch version
       compared literally and an anchor on a CRLF file never matched.

  For each mutation: the anchor must match EXACTLY ONCE (otherwise it is
  reported and NOT run); a mutation lock is taken (commits are blocked while a
  tracked file is deliberately broken -- CLAUDE.md, Sprint 65 IMP-5); the file
  is mutated; the check runs; the original bytes are restored and verified;
  the lock is released. The verdict is KILLED when the check exits non-zero,
  SURVIVED when it exits 0.

  Sprint 75 retro IMP-1 (Harold, 2026-10-03): two ways a "KILLED" proved
  nothing are now refused:
    1. BASELINE: each distinct check is run ONCE on the unchanged code first
       and must pass. If the check already fails, every later "KILLED" is
       meaningless; those mutations are reported BASELINE FAILS and not run.
       A spec may set "baseline": false for a slow check (a full rebuild).
    2. INVALID: a mutant that does not COMPILE fails the check for the wrong
       reason. Sprint 75 counted two such mutants as KILLED (M80, M96 as first
       written). The check's output is now kept and scanned; a Dart or C++
       compile error makes the verdict INVALID, which counts as a failure of
       the run -- rewrite the mutation so it compiles.

.PARAMETER SpecFile
  JSON array of mutations. Each entry:
    name    -- label for the report
    file    -- path relative to the repo root
    find    -- exact text to replace (must occur once)
    replace -- replacement text
    test    -- a Flutter test path relative to mobile-app/  (runs `flutter test <test>`)
      OR
    command -- any command line, run from the repo root (e.g. the hook suite)
    baseline -- optional; false skips the unchanged-code baseline run

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\mutation-test.ps1 -SpecFile C:\...\specs.json

.NOTES
  Exit 0 when every mutation was KILLED; exit 1 when any SURVIVED, was
  INVALID, or could not run. A SURVIVED mutation means the test does not guard
  what it claims to; an INVALID one means the mutation, not the test, failed.
#>
param(
    [Parameter(Mandatory)][string]$SpecFile
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo '.claude\hooks\mutation-lock.ps1')

# Defect 1 fixed: read the spec as UTF-8, not the system code page.
$specs = Get-Content -Raw -Encoding UTF8 -LiteralPath $SpecFile | ConvertFrom-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$results = @()
$allKilled = $true

# IMP-1: compile-error signatures. Dart (flutter test): "<file>.dart:12:3:
# Error:", "Compilation failed", 'Failed to load "...": ... Error'. MSVC: error
# C1234. Matched against the check's OUTPUT, not its exit code.
$compileError = [regex]'(?m)\.dart:\d+:\d+: Error:|Compilation failed|Failed to load "[^"]+":[^\r\n]*Error|\berror C\d{4}\b'

# Run a check (flutter test or a command) and return its exit code and output.
function Invoke-Check($spec) {
    $out = [IO.Path]::GetTempFileName()
    $savedPref = $ErrorActionPreference
    # PR #440 review: under 'Stop', Windows PowerShell 5.1 turns a child
    # process's stderr into a terminating error -- a FAILING check (the
    # KILLED case) could abort the run. Run the child under 'Continue'
    # and judge its exit code (and, for INVALID, its output).
    $ErrorActionPreference = 'Continue'
    $pushed = $false
    try {
        if ($spec.test) {
            Push-Location (Join-Path $repo 'mobile-app'); $pushed = $true
            & flutter test $spec.test *> $out
        } else {
            Push-Location $repo; $pushed = $true
            & cmd.exe /c $spec.command *> $out
        }
        $code = $LASTEXITCODE
    } finally {
        if ($pushed) { Pop-Location }
        $ErrorActionPreference = $savedPref
    }
    $text = Get-Content -Raw -LiteralPath $out -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue
    return @{ Code = $code; Output = [string]$text }
}

# IMP-1: one baseline per distinct check, cached.
$baselines = @{}

foreach ($s in $specs) {
    $path = Join-Path $repo $s.file
    if (-not (Test-Path -LiteralPath $path)) {
        $results += "$($s.name): FILE NOT FOUND ($($s.file)) -- not run"; $allKilled = $false; continue
    }
    $orig = [IO.File]::ReadAllBytes($path)
    $text = [Text.Encoding]::UTF8.GetString($orig)

    # Defect 2 fixed: express find/replace in the target file's line endings.
    $crlf = $text.Contains("`r`n")
    $find = ($s.find -replace "`r`n", "`n")
    $replace = ($s.replace -replace "`r`n", "`n")
    if ($crlf) { $find = $find -replace "`n", "`r`n"; $replace = $replace -replace "`n", "`r`n" }

    $count = ([regex]::Matches($text, [regex]::Escape($find))).Count
    if ($count -ne 1) {
        $results += "$($s.name): ANCHOR MATCHED $count TIMES -- not run"; $allKilled = $false; continue
    }
    if (-not $s.test -and -not $s.command) {
        $results += "$($s.name): spec has neither 'test' nor 'command' -- not run"; $allKilled = $false; continue
    }

    # IMP-1 baseline: the check must PASS on the unchanged code.
    $checkKey = if ($s.test) { "test:$($s.test)" } else { "cmd:$($s.command)" }
    if ($s.baseline -ne $false) {
        if (-not $baselines.ContainsKey($checkKey)) {
            $baselines[$checkKey] = (Invoke-Check $s).Code
        }
        if ($baselines[$checkKey] -ne 0) {
            $results += "$($s.name): BASELINE FAILS (the check fails on unchanged code) -- not run"
            $allKilled = $false; continue
        }
    }

    New-MutationLock -File $s.file -Reason "mutation: $($s.name)" -Agent 'mutation-test.ps1' | Out-Null
    try {
        [IO.File]::WriteAllText($path, $text.Replace($find, $replace), $utf8NoBom)
        $check = Invoke-Check $s
        if ($check.Code -eq 0) {
            $results += "$($s.name): SURVIVED"; $allKilled = $false
        } elseif ($compileError.IsMatch($check.Output)) {
            # IMP-1: red for the wrong reason -- the mutant did not compile.
            $first = $compileError.Match($check.Output).Value
            $results += "$($s.name): INVALID -- the mutant did not compile ($first); rewrite it so it compiles"
            $allKilled = $false
        } else {
            $results += "$($s.name): KILLED"
        }
    } finally {
        [IO.File]::WriteAllBytes($path, $orig)
        $back = [IO.File]::ReadAllBytes($path)
        if ([Convert]::ToBase64String($back) -ne [Convert]::ToBase64String($orig)) {
            throw "RESTORE FAILED for $path -- the lock stays HELD; restore the file by hand"
        }
        Remove-MutationLock -File $s.file | Out-Null
    }
}

$results | ForEach-Object { Write-Output $_ }
if ($allKilled) { exit 0 } else { exit 1 }
