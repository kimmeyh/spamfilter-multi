# Run the Flutter integration_test E2E suite for the Windows Desktop app.
# Sprint 42, F99 -- the in-VM second lane alongside the WinWright UIA harness.
#
# WHY A SECOND HARNESS (see docs/TESTING_STRATEGY.md):
#   WinWright (run-winwright-tests.ps1) drives the live Windows UIA accessibility
#   tree out-of-process -- great for true end-to-end + accessibility coverage,
#   but flaky on Flutter dialog/picker-settle boundaries (the F56 create/save and
#   F37 picker scripts) because its `run` script-runner has no wait/assert
#   primitive. integration_test drives the real widget tree IN the Dart VM by
#   Key/Finder with pumpAndSettle() -- no settle race, no cursor/DPI dependency.
#
# DB ISOLATION:
#   Unlike the WinWright lane, this lane needs NO pre/post DB-snapshot drift
#   guard: each test boots the app against an isolated temp data dir via
#   AppPaths.testOverrideBaseDir (see integration_test/helpers/app_harness.dart)
#   and never touches the dev DB. The dev-DB-copy mode copies the DB into temp
#   and deletes the copy on teardown.
#
# Prerequisites:
#   - Flutter SDK on PATH; Windows desktop toolchain (same as build-windows.ps1).
#   - Run from mobile-app/scripts (or anywhere -- paths are resolved absolutely).
#
# Usage:
#   .\run-integration-tests.ps1                 # Run all integration_test/*_test.dart
#   .\run-integration-tests.ps1 -TestName f99   # Run tests whose file matches *f99*
#   .\run-integration-tests.ps1 -Name lifecycle # alias for -TestName
#
# Exit code: non-zero if any test fails (propagates `flutter test` exit code).

param(
    [Alias('Name')]
    [string]$TestName = ""
)

$ErrorActionPreference = "Stop"

$mobileApp = Resolve-Path (Join-Path $PSScriptRoot "..")
$itDir     = Join-Path $mobileApp "integration_test"

if (-not (Test-Path $itDir)) {
    Write-Error "integration_test directory not found at $itDir"
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Flutter integration_test E2E suite (F99)"  -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "App dir: $mobileApp"
Write-Host "Isolation: per-test temp DB (dev DB never touched)" -ForegroundColor DarkGray
Write-Host ""

# Resolve the target: a single matching file when -TestName is given, else the
# whole integration_test/ directory.
$target = $itDir
if ($TestName) {
    $matches = Get-ChildItem -Path $itDir -Recurse -Filter "*$TestName**_test.dart" | Sort-Object FullName
    if ($matches.Count -eq 0) {
        Write-Warning "No integration_test files matched '*$TestName*'. Nothing to run."
        exit 0
    }
    Write-Host "Matched $($matches.Count) file(s) for '$TestName':" -ForegroundColor DarkYellow
    $matches | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host ""
    # flutter test accepts multiple file paths.
    $target = $matches.FullName
}

Push-Location $mobileApp
try {
    # integration_test runs headless via `flutter test` (the harness mocks no
    # device; AppPaths.testOverrideBaseDir provides DB isolation). This keeps the
    # lane fast and CI-friendly and avoids opening a real window.
    & flutter test $target
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host ""
if ($code -eq 0) {
    Write-Host "[OK] integration_test suite passed." -ForegroundColor Green
} else {
    Write-Host "[FAIL] integration_test suite failed (exit $code)." -ForegroundColor Red
}
exit $code
