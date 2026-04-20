# Run all WinWright E2E tests for the Windows Desktop app
# Sprint 34, F69
#
# Prerequisites:
# - Windows desktop dev build running (build-windows.ps1)
# - civyk-winwright installed at C:\Tools\WinWright\
#
# Usage:
#   .\run-winwright-tests.ps1                     # Run all tests
#   .\run-winwright-tests.ps1 -TestName f56       # Run tests matching pattern

param(
    [string]$TestName = "*",
    [switch]$SkipScreenReaderFlag
)

$ErrorActionPreference = "Stop"

$winwrightExe = "C:\Tools\WinWright\Civyk.WinWright.Mcp.exe"
$testDir = Join-Path $PSScriptRoot "..\test\winwright"

# Verify winwright exists
if (-not (Test-Path $winwrightExe)) {
    Write-Error "WinWright not found at $winwrightExe. Install per docs/TESTING_STRATEGY.md."
    exit 1
}

# Verify test directory
if (-not (Test-Path $testDir)) {
    Write-Error "Test directory not found at $testDir"
    exit 1
}

# Enable screen reader flag (required for Flutter Semantics tree)
if (-not $SkipScreenReaderFlag) {
    Write-Host "[Setup] Enabling SPI_SETSCREENREADER flag..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "enable-screen-reader-flag.ps1") enable
    Start-Sleep -Seconds 2
}

# Verify winwright doctor
Write-Host "[Setup] Running winwright doctor..." -ForegroundColor Cyan
& $winwrightExe doctor
if ($LASTEXITCODE -ne 0) {
    Write-Error "winwright doctor failed. Resolve before running tests."
    exit 1
}

# Find tests matching pattern
$pattern = "test_*$TestName*.json"
$tests = Get-ChildItem -Path $testDir -Filter $pattern | Sort-Object Name

if ($tests.Count -eq 0) {
    Write-Warning "No tests matched pattern: $pattern"
    exit 0
}

Write-Host ""
Write-Host "Running $($tests.Count) WinWright test(s)..." -ForegroundColor Green
Write-Host ""

$passed = 0
$failed = 0
$results = @()

foreach ($test in $tests) {
    Write-Host "[TEST] $($test.Name)" -ForegroundColor Yellow

    $startTime = Get-Date
    & $winwrightExe run $test.FullName
    $exitCode = $LASTEXITCODE
    $duration = (Get-Date) - $startTime

    if ($exitCode -eq 0) {
        Write-Host "[PASS] $($test.Name) ($([int]$duration.TotalSeconds)s)" -ForegroundColor Green
        $passed++
        $results += [PSCustomObject]@{Name=$test.Name; Status="PASS"; Duration=$duration}
    } else {
        Write-Host "[FAIL] $($test.Name) (exit code: $exitCode)" -ForegroundColor Red
        $failed++
        $results += [PSCustomObject]@{Name=$test.Name; Status="FAIL"; Duration=$duration}
    }

    Write-Host ""
}

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "WinWright E2E Test Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total:  $($tests.Count)"
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host ""

$results | Format-Table -AutoSize

if ($failed -gt 0) {
    exit 1
}
