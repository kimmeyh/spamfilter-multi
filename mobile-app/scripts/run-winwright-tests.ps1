# Run all WinWright E2E tests for the Windows Desktop app
# Sprint 34, F69 -- harness extended Sprint 40, F79 (Issue #240)
#
# Prerequisites:
# - Windows desktop dev build running (build-windows.ps1)
# - civyk-winwright installed at C:\Tools\WinWright\
#
# Usage:
#   .\run-winwright-tests.ps1                          # Run all tests with DB snapshot guard
#   .\run-winwright-tests.ps1 -TestName f56            # Run tests matching pattern
#   .\run-winwright-tests.ps1 -DryRun                  # Preflight + snapshot only, no sweep
#   .\run-winwright-tests.ps1 -DryRun -TestSnapshotOnly # Snapshot self-test only (no WinWright needed)
#
# DB snapshot guard (-SnapshotDb, default true):
#   Captures a snapshot of the dev DB (rules, safe_senders, settings tables) before the
#   sweep and again after. If any row was added, removed, or modified in any of the three
#   tables, the run exits non-zero with the offending rows printed. This enforces the
#   "State-restore rule" documented in docs/TESTING_STRATEGY.md: every WinWright script
#   must leave the dev DB in the same state it found it.
#
# Runtime target: <10 min unattended for all 7 scripts on a local dev build.
# (Measured manually; do not run this script as part of the automated Flutter test suite.)
#
# See docs/TESTING_STRATEGY.md for full cadence policy (end-of-sprint full sweep when
# lib/ui/** touched) and mobile-app/test/winwright/README.md for script details.

param(
    [string]$TestName      = "*",
    [switch]$SkipScreenReaderFlag,

    # DB snapshot guard (Sprint 40, F79)
    [switch]$SnapshotDb,            # Enable pre/post dev-DB snapshot (default: true unless -NoSnapshotDb)
    [switch]$NoSnapshotDb,          # Explicitly disable DB snapshot (overrides default-on behaviour)
    [switch]$FailOnDrift,           # Fail run if drift detected (default: true unless -NoFailOnDrift)
    [switch]$NoFailOnDrift,         # Allow drift without failing (diagnostic mode only)

    # Execution modes (Sprint 40, F79)
    [switch]$DryRun,                # Skip the actual WinWright sweep; do preflight + snapshot only
    [switch]$TestSnapshotOnly       # Run winwright-db-snapshot.ps1 -SelfTest and exit (no app needed)
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve default switch values:
#   -SnapshotDb defaults to $true (omit the switch to keep it on).
#   -FailOnDrift defaults to $true (omit the switch to keep it on).
#   Explicit -NoSnapshotDb / -NoFailOnDrift override the defaults.
# ---------------------------------------------------------------------------

$doSnapshot   = (-not $NoSnapshotDb)
$doFailOnDrift = (-not $NoFailOnDrift)

# ---------------------------------------------------------------------------
# Mode: -TestSnapshotOnly
# Runs the winwright-db-snapshot.ps1 self-test and exits.
# Does NOT require a running app or WinWright installation.
# ---------------------------------------------------------------------------

if ($TestSnapshotOnly) {
    Write-Host "[Runner] -TestSnapshotOnly: delegating to winwright-db-snapshot.ps1 -SelfTest" -ForegroundColor Cyan
    $snapshotScript = Join-Path $PSScriptRoot "winwright-db-snapshot.ps1"
    if (-not (Test-Path $snapshotScript)) {
        Write-Error "Snapshot helper not found at $snapshotScript"
        exit 1
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $snapshotScript -SelfTest
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

$winwrightExe = "C:\Tools\WinWright\Civyk.WinWright.Mcp.exe"
$testDir      = Join-Path $PSScriptRoot "..\test\winwright"
$snapshotScript = Join-Path $PSScriptRoot "winwright-db-snapshot.ps1"

# ---------------------------------------------------------------------------
# DryRun skips the actual sweep but still does preflight and snapshot.
# ---------------------------------------------------------------------------

if ($DryRun) {
    Write-Host "[Runner] -DryRun mode: preflight and snapshot will run; WinWright sweep will be SKIPPED." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Preflight: verify WinWright and test directory exist
# (Skip WinWright checks in -DryRun mode since the app may not be running)
# ---------------------------------------------------------------------------

if (-not $DryRun) {
    if (-not (Test-Path $winwrightExe)) {
        Write-Error "WinWright not found at $winwrightExe. Install per docs/TESTING_STRATEGY.md."
        exit 1
    }

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
}

# ---------------------------------------------------------------------------
# Pre-sweep DB snapshot
# ---------------------------------------------------------------------------

$snapshotBefore = $null
$snapshotAfter  = $null

if ($doSnapshot) {
    if (-not (Test-Path $snapshotScript)) {
        Write-Error "Snapshot helper not found at $snapshotScript. Cannot enforce DB-snapshot guard."
        exit 1
    }

    # Dot-source the helper to load its functions into this scope
    . $snapshotScript

    try {
        $snapshotBefore = Invoke-DbSnapshot
    } catch {
        Write-Host "[DB-SNAPSHOT] WARNING: Pre-sweep snapshot failed: $_" -ForegroundColor Yellow
        Write-Host "[DB-SNAPSHOT] Continuing without DB snapshot guard. Use -NoSnapshotDb to suppress this warning." -ForegroundColor Yellow
        $doSnapshot = $false
    }
}

# ---------------------------------------------------------------------------
# DryRun: stop here after pre-snapshot
# ---------------------------------------------------------------------------

if ($DryRun) {
    Write-Host ""
    Write-Host "[Runner] -DryRun: Skipping WinWright sweep." -ForegroundColor Yellow
    if ($doSnapshot -and $snapshotBefore) {
        # Take post-snapshot immediately (same state, no drift expected)
        $snapshotAfter = Invoke-DbSnapshot
        $driftResult   = Compare-DbSnapshots -Before $snapshotBefore -After $snapshotAfter
        Write-DriftReport -DriftResult $driftResult
        Write-Host "[Runner] DryRun snapshot cycle complete (no tests executed)." -ForegroundColor Cyan
    }
    Write-Host "[Runner] DryRun finished." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Find and run tests
# ---------------------------------------------------------------------------

$pattern = "test_*$TestName*.json"
$tests = Get-ChildItem -Path $testDir -Filter $pattern | Sort-Object Name

if ($tests.Count -eq 0) {
    Write-Warning "No tests matched pattern: $pattern"
    exit 0
}

Write-Host ""
Write-Host "Running $($tests.Count) WinWright test(s)..." -ForegroundColor Green
Write-Host ""

$passed  = 0
$failed  = 0
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

# ---------------------------------------------------------------------------
# Post-sweep DB snapshot + drift check
# (Always take the post-snapshot, even if tests failed, so we report drift
#  even on a partial run)
# ---------------------------------------------------------------------------

$driftDetected = $false

if ($doSnapshot -and $snapshotBefore) {
    try {
        $snapshotAfter = Invoke-DbSnapshot
        $driftResult   = Compare-DbSnapshots -Before $snapshotBefore -After $snapshotAfter
        Write-DriftReport -DriftResult $driftResult

        if ($driftResult.HasDrift -and $doFailOnDrift) {
            $driftDetected = $true
        }
    } catch {
        Write-Host "[DB-SNAPSHOT] WARNING: Post-sweep snapshot failed: $_" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "WinWright E2E Test Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total:  $($tests.Count)"
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($driftDetected) {
    Write-Host "DB Drift: DETECTED -- see [LEAK] lines above" -ForegroundColor Red
} elseif ($doSnapshot) {
    Write-Host "DB Drift: none" -ForegroundColor Green
}

Write-Host ""

$results | Format-Table -AutoSize

if ($failed -gt 0 -or $driftDetected) {
    exit 1
}
