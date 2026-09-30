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

.PARAMETER SpecFile
  JSON array of mutations. Each entry:
    name    -- label for the report
    file    -- path relative to the repo root
    find    -- exact text to replace (must occur once)
    replace -- replacement text
    test    -- a Flutter test path relative to mobile-app/  (runs `flutter test <test>`)
      OR
    command -- any command line, run from the repo root (e.g. the hook suite)

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\mutation-test.ps1 -SpecFile C:\...\specs.json

.NOTES
  Exit 0 when every mutation was KILLED; exit 1 when any SURVIVED or could not
  run. A SURVIVED mutation means the test does not guard what it claims to.
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

    New-MutationLock -File $s.file -Reason "mutation: $($s.name)" -Agent 'mutation-test.ps1' | Out-Null
    try {
        [IO.File]::WriteAllText($path, $text.Replace($find, $replace), $utf8NoBom)
        if ($s.test) {
            Push-Location (Join-Path $repo 'mobile-app')
            & flutter test $s.test *> $null
            $code = $LASTEXITCODE
            Pop-Location
        } elseif ($s.command) {
            Push-Location $repo
            & cmd.exe /c $s.command *> $null
            $code = $LASTEXITCODE
            Pop-Location
        } else {
            throw "spec '$($s.name)' has neither 'test' nor 'command'"
        }
        if ($code -ne 0) {
            $results += "$($s.name): KILLED"
        } else {
            $results += "$($s.name): SURVIVED"; $allKilled = $false
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
