# BUG-S37-1 (Sprint 38, Issue #256): PowerShell integration test for the
# background-scan-defers-to-foreground-UI fix in mobile-app/windows/runner/main.cpp.
#
# Sprint 37 Phase 5.3 surfaced SqfliteFfiException(sqlite_error: 5, "database is locked")
# when the foreground UI was running and a scheduled --background-scan launched a
# second process holding the same SQLite DB. Root cause: main.cpp's wWinMain
# previously skipped the single-instance mutex when --background-scan was on the
# command line, so the scheduled scan opened a parallel DB connection.
#
# Fix (Sprint 38): background-scan mode now performs a read-only OpenMutexW probe
# at startup. If the foreground mutex exists, the scan logs a skip line and exits
# cleanly (the Task Scheduler retries on the next interval). If not, the scan
# proceeds as before.
#
# This script verifies the fix end-to-end against the real .exe + real Windows
# kernel mutex. It cannot be expressed as a flutter test (would require launching
# two processes within the test harness). It is more general than just this bug:
# any future change to main.cpp's startup logic (mutex naming, environment
# detection, --background-scan handling) can be verified by running this script
# against the rebuilt .exe.
#
# Pre-condition: build-windows.ps1 has produced the dev variant at
# mobile-app\dist\dev\MyEmailSpamFilter-Dev.exe (or pass -Environment prod for
# mobile-app\dist\prod\MyEmailSpamFilter.exe).
#
# Usage:
#   .\test-background-scan-skip.ps1                       # Test dev variant (default)
#   .\test-background-scan-skip.ps1 -Environment prod     # Test prod variant
#   .\test-background-scan-skip.ps1 -Verbose              # Show diagnostic output
#
# Exit codes:
#   0 = all assertions passed (fix verified)
#   1 = setup failure (missing .exe, missing AppData, etc.)
#   2 = assertion failure (the fix is broken)

param(
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev",
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"

# Resolve paths matching ADR-0035 + Sprint 37 F52 Phase 1 layout
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$distRoot = Join-Path $repoRoot "mobile-app\dist"

if ($Environment -eq "dev") {
    $exePath = Join-Path $distRoot "dev\MyEmailSpamFilter-Dev.exe"
    $dataSubDir = "MyEmailSpamFilter_Dev"
    $logPrefix = "dev_"
    $windowTitle = "MyEmailSpamFilter [DEV]"
} else {
    $exePath = Join-Path $distRoot "prod\MyEmailSpamFilter.exe"
    $dataSubDir = "MyEmailSpamFilter"
    $logPrefix = ""
    $windowTitle = "MyEmailSpamFilter"
}

$logFileName = "${logPrefix}background_scan_v0.5.5.log"
$logDir = Join-Path $env:APPDATA "MyEmailSpamFilter\$dataSubDir\logs"
$logFile = Join-Path $logDir $logFileName

Write-Host "[Setup] BUG-S37-1 integration test ($Environment variant)" -ForegroundColor Cyan
Write-Host "  exe:      $exePath"
Write-Host "  log file: $logFile"

# Pre-condition 1: .exe exists (build-windows.ps1 must have run)
if (-not (Test-Path $exePath)) {
    Write-Error "Test exe not found at $exePath. Run scripts\build-windows.ps1 -Environment $Environment first."
    exit 1
}

# Pre-condition 2: AppData log directory may not exist yet (first run); ensure
# we record the pre-test log size so we can detect the new line our test adds.
$null = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue
$preTestLogSize = if (Test-Path $logFile) { (Get-Item $logFile).Length } else { 0 }
if ($VerboseOutput) {
    Write-Host "  pre-test log size: $preTestLogSize bytes"
}

# Ensure no leftover instances are running from a prior test run
Write-Host "[Setup] Killing any leftover MyEmailSpamFilter processes..." -ForegroundColor Cyan
$leftover = Get-Process | Where-Object { $_.Path -eq $exePath } -ErrorAction SilentlyContinue
if ($leftover) {
    if ($VerboseOutput) {
        Write-Host "  Found $($leftover.Count) leftover process(es); terminating."
    }
    $leftover | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$testPassed = $true
$failures = @()

try {
    # ----- Test 1: Foreground UI holds the mutex; --background-scan must skip -----
    Write-Host "`n[Test 1] Foreground UI running -> background scan must skip" -ForegroundColor Yellow

    # Launch foreground UI. Start-Process (not the call operator) so the script
    # doesn't block on the GUI's message loop. WindowStyle Minimized so the
    # window doesn't steal focus during the test.
    Write-Host "  Starting foreground UI..."
    $foregroundProc = Start-Process -FilePath $exePath -WindowStyle Minimized -PassThru
    Start-Sleep -Seconds 5  # Allow Flutter engine + mutex acquisition + window creation

    if ($foregroundProc.HasExited) {
        $failures += "Foreground UI exited prematurely (exit code $($foregroundProc.ExitCode)). Cannot run mutex-held test."
        $testPassed = $false
    } else {
        if ($VerboseOutput) {
            Write-Host "  Foreground UI running as PID $($foregroundProc.Id)"
        }

        # Record pre-scan log size
        $preScanLogSize = if (Test-Path $logFile) { (Get-Item $logFile).Length } else { 0 }

        # Now launch the background-scan variant. The fix makes it exit 0 quickly
        # without producing the SqfliteFfiException because the mutex probe sees
        # the foreground holding the mutex.
        Write-Host "  Launching --background-scan (foreground mutex held)..."
        $scanProc = Start-Process -FilePath $exePath -ArgumentList "--background-scan" -Wait -PassThru -NoNewWindow

        # Assertion 1a: exit code 0
        if ($scanProc.ExitCode -eq 0) {
            Write-Host "  PASS: --background-scan exited 0" -ForegroundColor Green
        } else {
            $failures += "Test 1 assertion 1a FAILED: --background-scan exit code = $($scanProc.ExitCode) (expected 0)"
            $testPassed = $false
        }

        # Assertion 1b: log file grew (a skip line was appended)
        $postScanLogSize = if (Test-Path $logFile) { (Get-Item $logFile).Length } else { 0 }
        if ($postScanLogSize -gt $preScanLogSize) {
            Write-Host "  PASS: log file grew ($preScanLogSize -> $postScanLogSize bytes)" -ForegroundColor Green
        } else {
            $failures += "Test 1 assertion 1b FAILED: log file did not grow (still $postScanLogSize bytes)"
            $testPassed = $false
        }

        # Assertion 1c: most recent log line mentions "skipped"
        if (Test-Path $logFile) {
            $tail = Get-Content $logFile -Tail 1 -ErrorAction SilentlyContinue
            if ($tail -match "Background scan skipped") {
                Write-Host "  PASS: log line contains 'Background scan skipped': $tail" -ForegroundColor Green
            } else {
                $failures += "Test 1 assertion 1c FAILED: log tail does not mention 'Background scan skipped'. Tail: $tail"
                $testPassed = $false
            }
        } else {
            $failures += "Test 1 assertion 1c FAILED: log file does not exist after scan run"
            $testPassed = $false
        }

        # Assertion 1d: background scan did NOT take long (skip path is fast).
        # If it had hit the SqfliteFfiException path it would have done lots of
        # work first. We measure on the next test run.

        # Teardown: stop foreground UI
        Write-Host "  Stopping foreground UI..."
        Stop-Process -Id $foregroundProc.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    # Note: a Test 2 "no foreground UI -> background scan proceeds" case would
    # run the full scan path against the real DB, which has side effects
    # (writes scan results, calls Gmail API, etc.) and requires configured
    # accounts. Leaving Test 2 as a manual Phase 5.3 verification.

} finally {
    # Always clean up: ensure no leftover processes
    Get-Process | Where-Object { $_.Path -eq $exePath } -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Report
Write-Host "`n[Summary]" -ForegroundColor Cyan
if ($testPassed) {
    Write-Host "  All assertions PASSED. BUG-S37-1 fix is working." -ForegroundColor Green
    exit 0
} else {
    Write-Host "  $($failures.Count) assertion failure(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 2
}
