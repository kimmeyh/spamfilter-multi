# BUG-S37-1 (Sprint 38, Issue #256): PowerShell integration test for the
# background-scan-defers-to-foreground-UI fix in mobile-app/windows/runner/main.cpp.
#
# Sprint 37 Phase 5.3 surfaced SqfliteFfiException(sqlite_error: 5, "database is locked")
# when the foreground UI was running and a scheduled --background-scan launched a
# second process holding the same SQLite DB. Root cause: main.cpp's wWinMain
# previously skipped the single-instance mutex when --background-scan was on the
# command line, so the scheduled scan opened a parallel DB connection.
#
# Fix (Sprint 38): background-scan mode performed a read-only OpenMutexW probe
# and EXITED if the foreground mutex existed.
#
# F243 (Sprint 75, Harold 2026-10-03) REVERSED that: WAL + a 30 s busy_timeout
# (database_helper.dart) and the Sprint 74 per-account scan claim now handle two
# processes on one DB, so a background launch PROCEEDS with the UI open (Windows
# now behaves like Android). This script therefore asserts the opposite of its
# Sprint 38 version: with the UI open, --background-scan must RUN -- the native
# probe logs "Foreground UI is running; background scan proceeds" and the Dart
# worker starts -- and must NOT log "Background scan skipped".
#
# Side-effect free: the launch names an account id that does not exist, so the
# worker starts, finds no matching account, and exits without touching mail.
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

# Derive the app version from pubspec.yaml (single source of truth) so this
# script never needs a manual bump -- mirrors the F118 fix in
# live_scan_logger_test.dart. Hardcoding the version here was the same
# fragility class the version-consistency gate exists to prevent.
$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$pubspecText = Get-Content $pubspecPath -Raw
if ($pubspecText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
    Write-Host "[FAIL] Could not parse version from $pubspecPath" -ForegroundColor Red
    exit 1
}
$appVersion = $Matches[1]

$logFileName = "${logPrefix}background_scan_v$appVersion.log"
$logDir = Join-Path $env:APPDATA "MyEmailSpamFilter\$dataSubDir\logs"
$logFile = Join-Path $logDir $logFileName

Write-Host "[Setup] F243 (was BUG-S37-1) integration test ($Environment variant)" -ForegroundColor Cyan
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
    # ----- Test 1 (F243): Foreground UI open; --background-scan must PROCEED -----
    Write-Host "`n[Test 1] Foreground UI running -> background scan must proceed (F243)" -ForegroundColor Yellow

    # Launch foreground UI. Start-Process (not the call operator) so the script
    # doesn't block on the GUI's message loop. WindowStyle Minimized so the
    # window doesn't steal focus during the test.
    Write-Host "  Starting foreground UI..."
    $foregroundProc = Start-Process -FilePath $exePath -WindowStyle Minimized -PassThru
    Start-Sleep -Seconds 5  # Allow Flutter engine + mutex acquisition + window creation

    if ($foregroundProc.HasExited) {
        $failures += "Foreground UI exited prematurely (exit code $($foregroundProc.ExitCode)). Cannot run the UI-open test."
        $testPassed = $false
    } else {
        if ($VerboseOutput) {
            Write-Host "  Foreground UI running as PID $($foregroundProc.Id)"
        }

        $preScanLogSize = if (Test-Path $logFile) { (Get-Item $logFile).Length } else { 0 }

        # An account id that does not exist: the worker starts, matches no saved
        # account, and exits -- no IMAP, no scan rows.
        $noSuchAccount = 'f243-no-such-account@example.invalid'
        Write-Host "  Launching --background-scan --account-id=$noSuchAccount (UI open)..."
        $scanProc = Start-Process -FilePath $exePath `
            -ArgumentList @('--background-scan', "--account-id=$noSuchAccount") -PassThru -NoNewWindow
        # Read the handle now: without it, ExitCode is empty after the process
        # ends (a known Start-Process -PassThru quirk).
        $null = $scanProc.Handle
        $finished = $scanProc.WaitForExit(90000)

        # Assertion 1a: the process finished (it did not hang)
        if ($finished) {
            Write-Host "  PASS: --background-scan finished (exit code $($scanProc.ExitCode))" -ForegroundColor Green
        } else {
            $failures += "Test 1 assertion 1a FAILED: --background-scan still running after 90 s"
            $testPassed = $false
            Stop-Process -Id $scanProc.Id -Force -ErrorAction SilentlyContinue
        }

        # Only the lines this run appended.
        $newText = ''
        if (Test-Path $logFile) {
            $all = [System.IO.File]::ReadAllText($logFile)
            if ($all.Length -gt $preScanLogSize) { $newText = $all.Substring([int]$preScanLogSize) }
        }
        if ($VerboseOutput) { Write-Host "  new log text:`n$newText" }

        # Assertion 1b: the native probe saw the UI and let the scan proceed
        if ($newText -match 'Foreground UI is running; background scan proceeds') {
            Write-Host "  PASS: native probe logged 'background scan proceeds'" -ForegroundColor Green
        } else {
            $failures += "Test 1 assertion 1b FAILED: no 'background scan proceeds' line was logged"
            $testPassed = $false
        }

        # Assertion 1c: the Dart worker actually started
        if ($newText -match '=== Background scan started ===') {
            Write-Host "  PASS: the Dart background worker started" -ForegroundColor Green
        } else {
            $failures += "Test 1 assertion 1c FAILED: the Dart worker never started (no '=== Background scan started ===')"
            $testPassed = $false
        }

        # Assertion 1d: the Sprint 38 deferral is gone
        if ($newText -match 'Background scan skipped') {
            $failures += "Test 1 assertion 1d FAILED: the launch was still deferred ('Background scan skipped')"
            $testPassed = $false
        } else {
            Write-Host "  PASS: no 'Background scan skipped' line" -ForegroundColor Green
        }

        # Teardown: stop foreground UI
        Write-Host "  Stopping foreground UI..."
        Stop-Process -Id $foregroundProc.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    # Note: what the per-account claim then decides (skip an account a live scan
    # holds; the F238 stop offer) is covered by the Dart tests
    # (mv74_2_scan_heartbeat_test, f238_*) and Manual Validation -- a real scan
    # here would have side effects on the real DB and mailbox.

} finally {
    # Always clean up: ensure no leftover processes
    Get-Process | Where-Object { $_.Path -eq $exePath } -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Report
Write-Host "`n[Summary]" -ForegroundColor Cyan
if ($testPassed) {
    Write-Host "  All assertions PASSED. F243: background scans run with the UI open." -ForegroundColor Green
    exit 0
} else {
    Write-Host "  $($failures.Count) assertion failure(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 2
}
