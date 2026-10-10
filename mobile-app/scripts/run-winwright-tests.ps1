# Run all WinWright E2E tests for the Windows Desktop app
# Sprint 34, F69 -- harness extended Sprint 40, F79 (Issue #240)
#
# Prerequisites:
# - Windows desktop dev build running (build-windows.ps1)
# - civyk-winwright installed at C:\Tools\WinWright\
# - *** THE WORKSTATION MUST BE UNLOCKED AND THE SESSION ACTIVE ***
#
# KNOWN FAILURE -- "SetCursorPos failed (Win32 error 0)" MEANS THE SCREEN IS LOCKED.
# (Sprint 73. Root cause found by Harold after I twice misdiagnosed it: first as an
# unrecoverable environmental block, then as "transient session state" -- a vaguer
# wrong answer that named the observation and supplied no cause.)
#
#   Symptom: EVERY ww_click step fails with that exact message, while ww_window_state,
#   ww_invoke and all tree reads keep working. It looks like a UI regression confined to
#   the clicking surfaces and is nothing of the kind.
#
#   Why: Microsoft's SetCursorPos reference requires that "the input desktop must be the
#   current desktop when you call SetCursorPos". Locking Windows switches the input
#   desktop from Default to the Winlogon secure desktop, so a process on Default is no
#   longer on the input desktop and the call is refused. GetLastError returns 0 because
#   this is a desktop-access refusal rather than a Win32 error code being set -- which is
#   why the message reads as the otherwise nonsensical "error 0".
#
#   The ww_invoke / ww_click split is the tell: ww_invoke drives UIA InvokePattern, a
#   programmatic message needing no input desktop; ww_click SYNTHESIZES cursor input,
#   which does. These scripts MUST use ww_click for Text nodes, CheckBoxes and the F169
#   dropdown face because none of those support InvokePattern -- so a locked session
#   blocks precisely the primitive they cannot avoid.
#
#   FIX: unlock the workstation and re-run. Do NOT retry harder and do NOT record it as
#   flakiness -- retrying a locked session only fails slower.
#
#   F284 (Sprint 78): the refusal now applies ONLY when a selected script contains a
#   cursor-driven step (see $cursorTools below). A pattern-only selection (ww_invoke,
#   ww_set_checked, ww_get_value, ww_window_state, ...) needs no input desktop and is
#   allowed to run on a locked workstation. The default sweep is meant to be pattern-only.
#   Windows-only tooling by design (ADR-0042): Android UI coverage is widget tests plus
#   Fold Manual Validation; there is no WinWright equivalent there.
#
# Window size (F284 R-5): after every launch the runner forces the app window to a fixed
# size ($fixedWindowWidth x $fixedWindowHeight) so a script passes or fails the same way on
# every display. The display resolution and the achieved window size are printed in the
# summary. Scripts no longer maximize; their priming step is ww_window_state "restore".
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

# ---------------------------------------------------------------------------
# F284 R-5: fixed window size. Win32 SetWindowPos is used (not a WinWright step) so the
# size is applied the same way regardless of script content and needs no cursor or input
# desktop. SetProcessDPIAware makes every number below PHYSICAL pixels, so the recorded
# display resolution and window size are comparable across machines.
# ---------------------------------------------------------------------------
$fixedWindowWidth  = 1600
$fixedWindowHeight = 1000
$script:lastWindowSize = "not set"
$script:displaySize    = "unknown"

if (-not ("WinWrightWin" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinWrightWin {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
}
'@
}
[void][WinWrightWin]::SetProcessDPIAware()
$script:displaySize = "$([WinWrightWin]::GetSystemMetrics(0))x$([WinWrightWin]::GetSystemMetrics(1))"

function Set-FixedWindowSize {
    param([IntPtr]$Handle)
    [void][WinWrightWin]::ShowWindow($Handle, 9)                       # SW_RESTORE: leave maximized state
    # SWP_NOZORDER (0x4) | SWP_NOACTIVATE (0x10); fixed origin keeps the window on the primary display.
    [void][WinWrightWin]::SetWindowPos($Handle, [IntPtr]::Zero, 20, 20, $fixedWindowWidth, $fixedWindowHeight, 0x14)
    Start-Sleep -Milliseconds 800
    $r = New-Object WinWrightWin+RECT
    if ([WinWrightWin]::GetWindowRect($Handle, [ref]$r)) {
        $script:lastWindowSize = "$($r.Right - $r.Left)x$($r.Bottom - $r.Top)"
    }
    if ($script:lastWindowSize -ne "${fixedWindowWidth}x${fixedWindowHeight}") {
        Write-Warning "Window size is $($script:lastWindowSize), wanted ${fixedWindowWidth}x${fixedWindowHeight} (display $($script:displaySize) may be too small)."
    }
}

function Ensure-FreshAppAtHome {
    param([int]$WaitForWindowSec = 30)

    # (1) Defensive teardown of any existing dev-app instance.
    Get-Process $appProcName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    if (-not (Test-Path $devAppExe)) {
        Write-Error "Dev app exe not found at $devAppExe. Build a dev build first (build-windows.ps1)."
        return $false
    }

    # (2) Fresh launch and wait for the main window (home screen) to appear.
    # Sprint 59 hardening: since F135 (Sprint 52) the home screen is Review No
    # Rule Items, whose first load runs the covered-item sweep against the full
    # rule set BEFORE the window title appears -- measured 10-16s on the dev DB
    # (2026-08-15), vs the ~5s this wait was originally tuned for. The old
    # 12s deadline + 2s settle raced that startup and produced intermittent
    # 'No main window found' failures on step 2 of every script. Wait longer,
    # and settle for 8s after the title appears so the first script step meets
    # a genuinely idle app.
    Start-Process -FilePath $devAppExe | Out-Null
    $deadline = (Get-Date).AddSeconds($WaitForWindowSec)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process $appProcName -ErrorAction SilentlyContinue |
             Where-Object { $_.MainWindowTitle -like "*$appWindowTitle*" }
        if ($p) {
            Start-Sleep -Seconds 8                          # settle: let the home-screen sweep finish
            # F284 R-5: force the fixed window size, then let Flutter re-layout.
            $handle = @($p)[0].MainWindowHandle
            if ($handle -ne [IntPtr]::Zero) { Set-FixedWindowSize -Handle $handle; Start-Sleep -Seconds 1 }
            else { Write-Warning "No main window handle; window size NOT fixed." }
            return $true
        }
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

    # Sprint 73 retro IMP-6: REFUSE TO RUN ON A LOCKED WORKSTATION.
    #
    # This check exists because the alternative is worse than a failure: on a
    # locked session every ww_click fails with "SetCursorPos failed (Win32
    # error 0)" while ww_invoke and every tree read keep working, so the sweep
    # reports script FAILURES that read exactly like UI regressions. Sprint 73
    # lost a cycle to that -- the failure was diagnosed twice, wrongly, before
    # Harold asked whether the laptop was locked.
    #
    # Microsoft's SetCursorPos reference: "The input desktop must be the
    # current desktop when you call SetCursorPos." Locking switches the input
    # desktop from Default to the Winlogon secure desktop, so a process on
    # Default is refused. GetLastError returns 0 because it is a desktop-access
    # refusal rather than a Win32 error code -- hence the nonsensical
    # "error 0".
    #
    # Detect it the way the docs say to: OpenInputDesktop succeeds only for the
    # CURRENT input desktop, so on a locked session it fails outright.
    #
    # A retry is the WRONG fix and is deliberately not what this does -- it
    # would only fail slower. Stop with an instruction the reader can act on.
    Write-Host "[Setup] Checking the workstation is unlocked..." -ForegroundColor Cyan
    if (-not ("WinWrightDesk" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinWrightDesk {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool CloseDesktop(IntPtr h);
}
'@
    }
    $desk = [WinWrightDesk]::OpenInputDesktop(0, $false, 0x0100)  # DESKTOP_SWITCHDESKTOP
    # F284 R-3: only RECORD the state here. The refusal itself runs after the scripts are
    # selected (see "Locked-workstation gate" below), because a pattern-only selection
    # does not need the input desktop.
    $script:inputDesktopAvailable = ($desk -ne [IntPtr]::Zero)
    if ($script:inputDesktopAvailable) {
        [void][WinWrightDesk]::CloseDesktop($desk)
        Write-Host "[Setup] Workstation is unlocked -- input desktop available." -ForegroundColor Green
    } else {
        Write-Host "[Setup] Workstation is LOCKED -- only cursor-free (pattern-only) scripts can run." -ForegroundColor Yellow
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
        # Sprint 59 IMP-4: a guard that cannot run must FAIL the sweep, not
        # soft-continue -- the soft path let a PS-5.1 BOM bug disable drift
        # protection silently for the whole Sprint 59 session. An unguarded
        # sweep is only acceptable as an EXPLICIT choice (-NoSnapshotDb).
        Write-Host "[DB-SNAPSHOT] FATAL: Pre-sweep snapshot failed: $_" -ForegroundColor Red
        Write-Host "[DB-SNAPSHOT] Refusing to run the sweep without the drift guard. Fix the guard, or run with -NoSnapshotDb to explicitly waive it." -ForegroundColor Red
        exit 1
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
    # @(...) forces an array: a single Where-Object match returns a bare FileInfo
    # whose .Count is $null, which would silently skip the exclusion (Copilot
    # review, PR #262). Wrapping guarantees .Count is always an integer.
    $excluded = @($tests | Where-Object { $n = $_.Name; ($excludedFromSweep | Where-Object { $n -like "*$_*" }) })
    if ($excluded.Count -gt 0) {
        $names = ($excluded.Name -join ", ")
        Write-Host "[Runner] Excluding $($excluded.Count) dialog-settle script(s) from default sweep ($names) -- reliable execution moved to F99 (integration_test). Run explicitly with -TestName f56 / -TestName f37." -ForegroundColor DarkYellow
        $tests = @($tests | Where-Object { $n = $_.Name; -not ($excludedFromSweep | Where-Object { $n -like "*$_*" }) })
    }
}

if (@($tests).Count -eq 0) {
    Write-Warning "No tests matched pattern: $pattern"
    exit 0
}

# ---------------------------------------------------------------------------
# Locked-workstation gate (Sprint 73 retro IMP-6, narrowed by F284 R-3).
#
# $cursorTools are the tools that SYNTHESIZE cursor or keyboard input and therefore
# need the input desktop (SetCursorPos / SendInput are refused on the Winlogon secure
# desktop of a locked session):
#   ww_click, ww_hover, ww_drag_drop, ww_scroll  -- move the real cursor
#   ww_keyboard, ww_type, ww_select_text         -- synthesize key events / selection drags
# ww_type and ww_keyboard are included CONSERVATIVELY: whether ww_type uses ValuePattern
# or key events is not documented for this build, and a wrong "allow" produces false
# regression signals while a wrong "refuse" only costs an unlock. Narrow the list only
# after a locked live probe proves a tool works (ww_type is the likely candidate).
# Pattern-only tools (ww_invoke, ww_set_checked, ww_set_value, ww_select, ww_expand,
# ww_get_value, ww_window_state, ww_focus, ww_count, ...) go through UI Automation
# patterns and need no input desktop.
# ---------------------------------------------------------------------------
$cursorTools = @('ww_click', 'ww_hover', 'ww_drag_drop', 'ww_scroll', 'ww_keyboard', 'ww_type', 'ww_select_text')

function Get-CursorToolsUsed {
    param([string]$Path, [string[]]$Tools)
    $found = @()
    $doc = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($tc in @($doc.testCases)) {
        foreach ($step in @($tc.steps)) {
            if ($step.tool -and ($Tools -contains $step.tool)) { $found += $step.tool }
        }
    }
    return @($found | Sort-Object -Unique)
}

$cursorFree = @()
$cursorDriven = @()
foreach ($t in $tests) {
    $used = Get-CursorToolsUsed -Path $t.FullName -Tools $cursorTools
    if ($used.Count -gt 0) { $cursorDriven += "$($t.Name) [$($used -join ', ')]" }
    else { $cursorFree += $t.Name }
}

if (-not $script:inputDesktopAvailable) {
    if ($cursorDriven.Count -gt 0) {
        Write-Host ""
        Write-Error @"
THE WORKSTATION IS LOCKED -- unlock it and run this again.

Not a test failure and not flakiness. WinWright's ww_click synthesizes cursor
input, which Windows refuses off the input desktop; locking switches that to
the Winlogon secure desktop. These selected scripts use cursor-driven steps:
  $($cursorDriven -join "`n  ")

Stopping here deliberately: running anyway produces script failures that read
as UI regressions. (Sprint 73 retro IMP-6.) Scripts that use only UI Automation
pattern steps (ww_invoke, ww_set_checked, ...) do run on a locked workstation.
"@
        exit 1
    }
    Write-Host "[Setup] Workstation is locked, but every selected script is cursor-free, so the run is allowed: $($cursorFree -join ', ')" -ForegroundColor Green
}

Write-Host ""
# F226 (Sprint 73): warn BEFORE driving the app.
#
# Harold diagnosed the intermittent failures, and it is not residual app state
# between scripts -- the hypothesis the card was filed on:
#
#   "it uses the Product Owner screen and sometimes there is activity going
#    while testing is going on and they conflict... usually I am not aware it
#    is about to start and mess up the first run."
#
# So the sweep competes with a human using the same app. A warning plus a few
# seconds to react costs nothing and removes the commonest cause of a red run.
# A red sweep should mean a real regression; one that is red because someone
# clicked something trains everyone to discount it.
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " WINWRIGHT SWEEP STARTING -- it will DRIVE the dev app." -ForegroundColor Yellow
Write-Host " Do not click in MyEmailSpamFilter until it finishes." -ForegroundColor Yellow
Write-Host " Ctrl+C now if you are mid-task." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  starting in $i..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 1
}
Write-Host ""

Write-Host "Running $($tests.Count) WinWright test(s)..." -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# F284 (Sprint 78): the F182 synthetic no-rule seed/unseed hooks were removed with
# test_mt2c_no_rule_sweep.json (its contract is covered by the headless
# no_rule_review_screen_test).
#
# F243 (Sprint 75): pause this environment's scheduled background scans for the
# whole sweep. Since F243 a background scan RUNS while the app is open (it used
# to defer), so during a sweep it could (a) change the No Rule list under a
# script -- mt2c lost its selection mid-script on 2026-10-03 while background
# scans of a real account ran every 15 minutes -- and (b) be killed by the
# per-script cleanup below, which stops every process of this exe, leaving an
# orphaned in_progress row. Only tasks that were ENABLED are paused, and only
# those are re-enabled in the teardown, so a user's settings are restored as
# found.
# ---------------------------------------------------------------------------
$pausedBgTasks = @()
try {
    $pausedBgTasks = @(Get-ScheduledTask -TaskName 'SpamFilterBackgroundScan_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -like '*_Dev' -and $_.State -ne 'Disabled' })
    foreach ($t in $pausedBgTasks) {
        $null = Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
    }
    if ($pausedBgTasks.Count -gt 0) {
        Write-Host "[WW-BG] Paused $($pausedBgTasks.Count) dev background-scan task(s) for the sweep." -ForegroundColor DarkCyan
    }
} catch {
    Write-Warning "[WW-BG] Could not pause dev background-scan tasks: $_ -- a background scan may run during the sweep."
}

# PR #448 review: everything between the pause and the restore runs inside
# try/finally, so Ctrl+C or a terminating error ($ErrorActionPreference is
# Stop) cannot leave the user's background scans silently disabled.
try {

# F284 (Sprint 78, live sweep): the script runner SKIPS a step whose tool it
# cannot replay ("Replay of 'ww_get_value' is not supported by the script
# runner") and still reports the script PASSED -- so f124's four label checks
# silently never ran. A skipped check must never read as a pass: run the script,
# echo its output, and turn any such skip into a failure (exit code 3).
function Invoke-WinWrightScript {
    param([string]$Path)
    $out = & $winwrightExe run $Path 2>&1 | ForEach-Object { Write-Host $_; $_ }
    $code = $LASTEXITCODE
    $skipped = @($out | Where-Object { "$_" -match 'is not supported by the script runner' })
    if ($code -eq 0 -and $skipped.Count -gt 0) {
        Write-Host "[FAIL] $($skipped.Count) step(s) were SKIPPED as not replayable -- a skipped check is not a pass." -ForegroundColor Red
        return 3
    }
    return $code
}

$passed = 0
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
    $exitCode = Invoke-WinWrightScript -Path $test.FullName
    $duration = (Get-Date) - $startTime

    if ($exitCode -eq 0) {
        Write-Host "[PASS] $($test.Name) ($([int]$duration.TotalSeconds)s)" -ForegroundColor Green
        $passed++
        $results += [PSCustomObject]@{Name=$test.Name; Status="PASS"; Duration=$duration}
    } else {
        # F226: ONE retry, and it is ANNOUNCED.
        #
        # Harold's own workflow is "just run it again", and the commonest cause
        # is interference rather than a broken script. A silent retry would be
        # wrong: a genuinely broken script would then look merely flaky, which
        # is how a gate stops being believed. So the retry is printed, and a
        # script that fails BOTH attempts is still reported as a failure.
        Write-Host "[RETRY] $($test.Name) failed (exit $exitCode) -- retrying ONCE." -ForegroundColor Yellow
        Write-Host "        Most often this is interference: something else was" -ForegroundColor DarkYellow
        Write-Host "        driving the app. Leave it alone for this run." -ForegroundColor DarkYellow

        if (Ensure-FreshAppAtHome) {
            $retryStart = Get-Date
            $exitCode = Invoke-WinWrightScript -Path $test.FullName
            $duration = (Get-Date) - $retryStart
        }

        if ($exitCode -eq 0) {
            Write-Host "[PASS] $($test.Name) ($([int]$duration.TotalSeconds)s, ON RETRY)" -ForegroundColor Green
            $passed++
            $results += [PSCustomObject]@{Name=$test.Name; Status="PASS (retry)"; Duration=$duration}
        } else {
            Write-Host "[FAIL] $($test.Name) (exit code: $exitCode, FAILED TWICE)" -ForegroundColor Red
            $failed++
            $results += [PSCustomObject]@{Name=$test.Name; Status="FAIL"; Duration=$duration}
        }
    }

    Write-Host ""
}

# Defensive: ensure no stray dev-app instance survives the sweep (winwright run
# normally closes it, but a hung script could leave one). Keeps the machine clean
# and prevents a leftover instance from interfering with the post-sweep snapshot.
Get-Process $appProcName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

} finally {
# F243: restore exactly the background-scan tasks paused before the sweep.
foreach ($t in $pausedBgTasks) {
    try {
        $null = Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
    } catch {
        Write-Warning "[WW-BG] Could not re-enable '$($t.TaskName)': $_ -- re-enable it in Task Scheduler or toggle Background in Settings."
    }
}
if ($pausedBgTasks.Count -gt 0) {
    Write-Host "[WW-BG] Re-enabled $($pausedBgTasks.Count) dev background-scan task(s)." -ForegroundColor DarkCyan
}
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
        # Sprint 59 cowork-review finding 2: the IMP-4 loud-fail rule must
        # apply to BOTH ends of the sweep. A post-sweep snapshot failure means
        # the drift comparison NEVER RAN -- exiting 0 here would report
        # "success, no drift" with no drift check performed, the exact
        # indistinguishable-from-a-passing-guard class IMP-4 eliminated on the
        # pre-sweep side. (Plausible asymmetric failure: 'database is locked'
        # on the post read while the app is still up.)
        Write-Host "[DB-SNAPSHOT] FATAL: Post-sweep snapshot failed: $_" -ForegroundColor Red
        Write-Host "[DB-SNAPSHOT] The drift comparison did not run -- treating the sweep as FAILED. Re-run, or use -NoSnapshotDb to explicitly waive the guard." -ForegroundColor Red
        $driftDetected = $true
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
# F284 R-5: record the environment so a pass/fail is comparable across displays.
Write-Host "Display: $($script:displaySize) (physical px)  |  Window: $($script:lastWindowSize) (wanted ${fixedWindowWidth}x${fixedWindowHeight})"
Write-Host "Input desktop: $(if ($script:inputDesktopAvailable) { 'available (unlocked)' } else { 'LOCKED -- cursor-free scripts only' })"

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
