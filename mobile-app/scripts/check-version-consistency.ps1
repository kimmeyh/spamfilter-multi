# Sprint 44 retro IMP-1 -- version-consistency enforcement gate (CLI).
#
# Mirrors test/policy/version_consistency_test.dart: FAILS (exit 1) when any
# app-version literal under lib/ + windows/runner/ + scripts/ + test/ does not
# match the canonical `version:` in pubspec.yaml. (test/ added Sprint 47 retro
# Proposal 4 -- catches the F118 fragility class where a test HARDCODED a
# versioned log filename and broke on the bump.)
#
# WHY: app version literals are embedded as log-filename tokens
# (`..._v0.5.4.log`) and the Settings version-display string (`Version 0.5.4`),
# in BOTH Dart and C++ (windows/runner/main.cpp). A version bump must update
# every one. Sprint 43's F105 bump MISSED main.cpp (not on the checklist),
# shipping a stale v0.5.3 filename -- a SILENT drift that escapes normal testing.
#
# Recognized literal forms (narrow, to avoid matching dependency versions in
# comments / dates / unrelated X.Y.Z):
#   - `_v<MAJOR>.<MINOR>.<PATCH>.log`  (scan-log filename token)
#   - `Version <MAJOR>.<MINOR>.<PATCH>` (Settings version-display string)
#
# Usage:
#   .\check-version-consistency.ps1            # scan, exit 1 on any mismatch
#   .\check-version-consistency.ps1 -SelfTest  # offline self-test (no scan)

param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

# Matches the two app-version literal forms; captures the X.Y.Z.
$versionRe = '_v(\d+\.\d+\.\d+)\.log|Version\s(\d+\.\d+\.\d+)'

function Get-Versions {
    param([string]$Line)
    $out = @()
    foreach ($m in [regex]::Matches($Line, $versionRe)) {
        $v = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        $out += $v
    }
    return $out
}

if ($SelfTest) {
    Write-Host "[SELF-TEST] check-version-consistency.ps1" -ForegroundColor Cyan
    $canonical = '0.5.4'
    $cases = @(
        @{ line = 'background_scan_v0.5.3.log';                 expectMismatch = $true  ; name = 'stale log token' },
        @{ line = 'background_scan_v0.5.4.log';                 expectMismatch = $false ; name = 'matching log token' },
        @{ line = 'Version 0.5.4';                              expectMismatch = $false ; name = 'matching display' },
        @{ line = 'Version 0.5.3';                              expectMismatch = $true  ; name = 'stale display' },
        @{ line = '// flutter_local_notifications v16.2.0 ...'; expectMismatch = $false ; name = 'dependency version ignored' }
    )
    $pass = $true
    foreach ($c in $cases) {
        $mismatch = (Get-Versions -Line $c.line | Where-Object { $_ -ne $canonical }).Count -gt 0
        $ok = ($mismatch -eq $c.expectMismatch)
        if (-not $ok) { $pass = $false }
        Write-Host ("  [{0}] {1}" -f ($(if ($ok) {'PASS'} else {'FAIL'}), $c.name))
    }
    if ($pass) { Write-Host "[SELF-TEST] ALL PASSED" -ForegroundColor Green; exit 0 }
    else       { Write-Host "[SELF-TEST] FAILURES" -ForegroundColor Red;     exit 1 }
}

$appRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$pubspec = Get-Content (Join-Path $appRoot "pubspec.yaml") -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
    Write-Host "[FAIL] Could not find a 'version: X.Y.Z' line in pubspec.yaml" -ForegroundColor Red
    exit 1
}
$canonical = $Matches[1]

$dirs = @('lib', 'windows/runner', 'scripts')
$exts = @('*.dart', '*.cpp', '*.cc', '*.h', '*.ps1')
$violations = @()

foreach ($d in $dirs) {
    $full = Join-Path $appRoot $d
    if (-not (Test-Path $full)) { continue }
    Get-ChildItem -Path $full -Recurse -Include $exts -File | ForEach-Object {
        $file = $_.FullName
        # Skip the gate's own files -- they intentionally contain stale-version
        # FIXTURE strings (e.g. 'Version 0.5.3') for their self-tests.
        if ($_.Name -eq 'check-version-consistency.ps1') { return }
        $n = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file)) {
            $n++
            foreach ($v in Get-Versions -Line $line) {
                if ($v -ne $canonical) {
                    $violations += [PSCustomObject]@{ File = $file; Line = $n; Found = $v; Text = $line.Trim() }
                }
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "[FAIL] Version-literal mismatch(es) -- expected $canonical (from pubspec.yaml):" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host ("  {0}:{1} found '{2}'" -f $v.File, $v.Line, $v.Found) -ForegroundColor Red
        Write-Host ("    {0}" -f $v.Text) -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Update each literal to match pubspec.yaml. See the version checklist in docs/STORE_RELEASE_PROCESS.md." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] All app-version literals match pubspec.yaml ($canonical)." -ForegroundColor Green
exit 0
