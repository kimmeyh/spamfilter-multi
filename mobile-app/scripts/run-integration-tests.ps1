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

# Collect the test files. One process PER FILE (Harold direction 2026-06-20):
# the app's process-wide singletons (DatabaseHelper, the fire-and-forget
# RuleSetProvider.initialize() async tail) bleed across files when many run in a
# single `flutter test integration_test/` process. Running each file in its own
# `flutter test <file>` process is the standard Flutter pattern for stateful
# apps and isolates cleanly at the file boundary. WITHIN a file, multiple
# testWidgets share one process and reset via the harness (no app shutdown).
$files = Get-ChildItem -Path $itDir -Recurse -Filter "*_test.dart" | Sort-Object FullName
if ($TestName) {
    $files = $files | Where-Object { $_.Name -like "*$TestName*" }
}
if (@($files).Count -eq 0) {
    Write-Warning "No integration_test *_test.dart files matched. Nothing to run."
    exit 0
}

Write-Host "Running $(@($files).Count) integration_test file(s), one process each:" -ForegroundColor DarkYellow
$files | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host ""

$failed = @()
Push-Location $mobileApp
try {
    foreach ($f in $files) {
        Write-Host "------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[RUN] $($f.Name)" -ForegroundColor Cyan
        & flutter test $f.FullName
        if ($LASTEXITCODE -ne 0) {
            $failed += $f.Name
            Write-Host "[FAIL] $($f.Name) (exit $LASTEXITCODE)" -ForegroundColor Red
        } else {
            Write-Host "[PASS] $($f.Name)" -ForegroundColor Green
        }
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "integration_test summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total files: $(@($files).Count)"
Write-Host "Passed: $(@($files).Count - $failed.Count)" -ForegroundColor Green
Write-Host "Failed: $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) { 'Red' } else { 'Green' })
if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "[OK] all integration_test files passed." -ForegroundColor Green
exit 0
