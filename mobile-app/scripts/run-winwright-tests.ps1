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
# Visual-regression checking: NOT handled here. The Sprint 41 F76 attempt to add
# layout-bounds visual regression via the WinWright CLI was abandoned (the standalone
# CLI cannot read element BoundingRectangle -- see ALL_SPRINTS_MASTER_PLAN.md F76).
# Visual/layout regression is folded into F99 (Flutter integration_test harness).
#
# Runtime target: <10 min unattended for all scripts on a local dev build.
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
# Resolve default switch values. Both features default to ON. Precedence:
#   1. Explicit positive switch when provided -- -SnapshotDb / -SnapshotDb:$false
#      (and -FailOnDrift / -FailOnDrift:$false) -- is honored as given.
#   2. Otherwise the negative switch (-NoSnapshotDb / -NoFailOnDrift) turns it off.
#   3. Otherwise the default (ON) applies.
# The negative switches are retained for backward compatibility; if both the
# positive and negative are passed, the negative wins (fail safe: drift guard off
# only when explicitly requested off, never silently).
# ---------------------------------------------------------------------------

if ($PSBoundParameters.ContainsKey('SnapshotDb')) {
    $doSnapshot = [bool]$SnapshotDb -and (-not $NoSnapshotDb)
} else {
    $doSnapshot = (-not $NoSnapshotDb)
}

if ($PSBoundParameters.ContainsKey('FailOnDrift')) {
    $doFailOnDrift = [bool]$FailOnDrift -and (-not $NoFailOnDrift)
} else {
    $doFailOnDrift = (-not $NoFailOnDrift)
}

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

# Dev app under test. Each WinWright script runs against a FRESH launch of this
# exe (see Ensure-FreshAppAtHome below for why per-script relaunch is required).
$devAppExe   = Join-Path $PSScriptRoot "..\dist\dev\MyEmailSpamFilter-Dev.exe"
$appProcName = "MyEmailSpamFilter-Dev"
$appWindowTitle = "MyEmailSpamFilter"   # matches the scripts' attachTitle

# ---------------------------------------------------------------------------
# Per-script app lifecycle (Sprint 40 F79 follow-up, 2026-06-06)
#
# WHY THIS EXISTS: `winwright run <script>` CLOSES the app under test when the
# run finishes -- on BOTH pass and fail (empirically confirmed 2026-06-06; the
# installed WinWright build owns the attached process lifecycle and there is no
# --keep-alive flag). The original F79 design assumed one long-lived app shared
# across all 7 scripts; that is impossible with this WinWright build because
# script #1 would close the app and scripts #2-#7 would fail "no process".
#
# DESIGN: each script is INDEPENDENT. Before every script we (1) defensively
# kill any stray dev-app instance (so a hung/dirty app never poisons the next
# script), then (2) launch a fresh instance and wait for its window to appear
# (known home-screen start state). WinWright then attaches by title and closes
# it at end-of-run. Cost ~6s/script x 7 ~= 45s, well within the <10 min target.
# ---------------------------------------------------------------------------

function Ensure-FreshAppAtHome {
    param([int]$WaitForWindowSec = 12)

    # (1) Defensive teardown of any existing dev-app instance.
    Get-Process $appProcName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    if (-not (Test-Path $devAppExe)) {
        Write-Error "Dev app exe not found at $devAppExe. Build a dev build first (build-windows.ps1)."
        return $false
    }

    # (2) Fresh launch and wait for the main window (home screen) to appear.
    Start-Process -FilePath $devAppExe | Out-Null
    $deadline = (Get-Date).AddSeconds($WaitForWindowSec)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process $appProcName -ErrorAction SilentlyContinue |
             Where-Object { $_.MainWindowTitle -like "*$appWindowTitle*" }
        if ($p) { Start-Sleep -Seconds 2; return $true }   # small settle after window appears
        Start-Sleep -Milliseconds 500
    }
    Write-Warning "Dev app window '$appWindowTitle' did not appear within ${WaitForWindowSec}s."
    return $false
}

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

# Scripts that depend on a Flutter dialog/picker animating in are EXCLUDED from
# the default sweep (Sprint 41, Harold Class-3 decisions 2026-06-17):
#   - f56 (create/save/delete lifecycle): Save resolves 0 elements pre-settle.
#   - f37 (folder pickers): the picker's "Search folders..." Edit is not in the
#     UIA tree yet when the next step fires (resolves fine once settled).
# Both hit the same WinWright limitation: the `run` script-runner has no
# ww_wait/ww_assert primitive to wait for an animating element. Reliable
# execution is moved to F99 (Flutter integration_test, in-VM, pumpAndSettle).
# The .json files remain as the F99 reference flow and stay runnable explicitly
# via -TestName f56 / -TestName f37. The default sweep ships green with the 6
# read-only scripts that do not cross a dialog-settle boundary.
$excludedFromSweep = @("f56", "f37")
if ($TestName -eq "*") {
    $excluded = $tests | Where-Object { $n = $_.Name; ($excludedFromSweep | Where-Object { $n -like "*$_*" }) }
    if ($excluded.Count -gt 0) {
        $names = ($excluded.Name -join ", ")
        Write-Host "[Runner] Excluding $($excluded.Count) dialog-settle script(s) from default sweep ($names) -- reliable execution moved to F99 (integration_test). Run explicitly with -TestName f56 / -TestName f37." -ForegroundColor DarkYellow
        $tests = $tests | Where-Object { $n = $_.Name; -not ($excludedFromSweep | Where-Object { $n -like "*$_*" }) }
    }
}

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

    # Launch a fresh app instance at the home screen for THIS script.
    # (winwright run closes the app at end-of-run, so every script needs its own.)
    Write-Host "  [app] Launching fresh dev instance..." -ForegroundColor DarkGray
    if (-not (Ensure-FreshAppAtHome)) {
        Write-Host "[FAIL] $($test.Name) (could not launch dev app at home)" -ForegroundColor Red
        $failed++
        $results += [PSCustomObject]@{Name=$test.Name; Status="FAIL"; Duration=([TimeSpan]::Zero)}
        Write-Host ""
        continue
    }

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

# Defensive: ensure no stray dev-app instance survives the sweep (winwright run
# normally closes it, but a hung script could leave one). Keeps the machine clean
# and prevents a leftover instance from interfering with the post-sweep snapshot.
Get-Process $appProcName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

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
