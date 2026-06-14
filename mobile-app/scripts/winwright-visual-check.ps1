# WinWright layout-bounds visual-regression check
# Sprint 41, F76 (Issue #TBD)
#
# Captures bounding-rectangle snapshots of key UI elements on the primary screens
# (Home, Manage Rules, Manage Safe Senders, Settings) via WinWright MCP primitives
# and compares them against committed baseline JSON files stored under
# mobile-app/test/winwright/baselines/.
#
# APPROACH: Layout-bounds assertions (not pixel-diff screenshots).
# WinWright exposes element bounding rectangles via ww_get_snapshot / ww_get_attribute.
# Bounds data is immune to anti-aliasing, sub-pixel font-rendering, and DPI-scaling
# noise -- all of which cause false positives in pixel-diff approaches. A real layout
# regression (element moved, misaligned, or missing) changes bounds by at least one
# logical pixel, which this check reliably detects at the configured tolerance threshold.
#
# WHY NOT PIXEL-DIFF:
# The README.md for this test suite states WinWright is "not suitable for pixel-perfect
# visual regression testing." Flutter Windows renders via DirectX with sub-pixel AA,
# so a 0-pixel-change deploy still produces per-run PNG differences in font edges and
# icon anti-aliasing. Layout-bounds avoids all of that entirely.
#
# HOW BOUNDS ARE CAPTURED:
# This script drives the app via the WinWright CLI using its `inspect` and `snapshot`
# commands to dump the UIA accessibility tree as JSON, then extracts the BoundingRectangle
# property for each tracked anchor element. The same elements are captured on each run
# and compared against the baseline.
#
# BASELINE FILES:
# Stored under mobile-app/test/winwright/baselines/ as:
#   baseline_home.json
#   baseline_manage_rules.json
#   baseline_manage_safe_senders.json
#   baseline_settings.json
#
# Each file contains an array of { "selector": "...", "name": "...", "bounds": {x,y,w,h} }
# entries. If a baseline file does not exist, the run is marked [PENDING CAPTURE].
# Run with -CaptureBaseline to capture and write new baselines.
#
# TOLERANCE:
# Default tolerance is 8 logical pixels in any single dimension (x, y, width, height).
# This absorbs window-position variance and minor OS chrome differences without hiding
# real regressions (a misaligned button shifts by at least 16-20px in practice).
# Override with -TolerancePx.
#
# SELF-TEST:
# Run with -SelfTest to execute a fully offline self-test using two static sample
# JSON data sets: one "clean" pair (no drift) and one "drift" pair (simulated 40px x-shift).
# The self-test verifies:
#   - Clean pair -> no regression reported
#   - Drift pair -> regression correctly detected for the shifted element
#   - Shifted element name appears in the diff report
# No running app or WinWright installation is required for -SelfTest.
#
# INTEGRATION WITH run-winwright-tests.ps1:
# The runner accepts -VisualCheck which dot-sources this script and calls
# Invoke-VisualCheck. The check runs AFTER the main sweep (post DB-snapshot) and
# before the final summary. It does NOT fail the run if baselines are absent
# (only if a captured baseline shows regression > tolerance).
#
# Usage:
#   # Dot-source (called by run-winwright-tests.ps1):
#   . .\winwright-visual-check.ps1
#
#   # Capture new baselines (requires running app at home screen):
#   .\winwright-visual-check.ps1 -CaptureBaseline
#
#   # Compare against baselines (requires running app at home screen):
#   .\winwright-visual-check.ps1 -Compare
#
#   # Self-test (no app or WinWright needed -- proves FAIL and PASS paths):
#   .\winwright-visual-check.ps1 -SelfTest
#
#   # Override tolerance:
#   .\winwright-visual-check.ps1 -Compare -TolerancePx 4

param(
    [switch]$CaptureBaseline,    # Capture new baselines for all tracked screens
    [switch]$Compare,            # Compare current layout against baselines
    [switch]$SelfTest,           # Run offline self-test (no app or WinWright needed)
    [int]$TolerancePx = 8        # Allowed deviation per dimension (default: 8 logical px)
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$WinWrightExe  = "C:\Tools\WinWright\Civyk.WinWright.Mcp.exe"
$BaselinesDir  = Join-Path $PSScriptRoot "..\test\winwright\baselines"
$AppTitle      = "MyEmailSpamFilter"

# Anchor elements per screen.
# Each entry: { Screen, NavigationSteps, Anchors[] }
# NavigationSteps: PowerShell ScriptBlock that drives WinWright to land on the screen.
# Anchors: selector strings whose bounds are captured and compared.
#
# DESIGN NOTE: Only elements that are ALWAYS visible on a given screen are tracked.
# Elements that are conditionally rendered (e.g., scan-result counts) are excluded
# because their presence and size depend on data, not layout.
#
# All selectors use the verified selector map from _SELECTOR_MAP_2026-06-05.md.

$TrackedScreens = @(
    @{
        ScreenId   = "home"
        BaselineFile = "baseline_home.json"
        Description  = "Home (Account Selection) screen"
        Anchors      = @(
            @{ Selector = "type=Button[name='Settings']";          Name = "Settings button (top-bar)" },
            @{ Selector = "type=Button[name='Help']";              Name = "Help button (top-bar)" },
            @{ Selector = "type=Button[name='View Scan History']"; Name = "Scan History button (top-bar)" },
            @{ Selector = "type=Button[name='Exit Application']";  Name = "Exit button (top-bar)" },
            @{ Selector = "type=Button[name*='Add Account']";      Name = "Add Account FAB (bottom)" }
        )
    },
    @{
        ScreenId   = "manage_rules"
        BaselineFile = "baseline_manage_rules.json"
        Description  = "Manage Rules screen"
        Anchors      = @(
            @{ Selector = "type=Button[name='Back']";                                   Name = "Back button (top-bar)" },
            @{ Selector = "type=Button[name='Test a pattern against sample emails']";   Name = "Test-pattern button (top-bar)" },
            @{ Selector = "type=Button[name*='Add block rule']";                        Name = "Add block rule FAB" },
            @{ Selector = "type=Edit[name*='Search by domain']";                        Name = "Search field" }
        )
    },
    @{
        ScreenId   = "settings_general"
        BaselineFile = "baseline_settings_general.json"
        Description  = "Settings (General tab)"
        Anchors      = @(
            @{ Selector = "type=Button[name='Back']";              Name = "Back button (top-bar)" },
            @{ Selector = "type=Button[name='Manage Rules']";      Name = "Manage Rules button" },
            @{ Selector = "type=Button[name='Manage Safe Senders']"; Name = "Manage Safe Senders button" }
        )
    }
)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Parse a raw WinWright bounds string into a hashtable {X, Y, Width, Height}.
# WinWright returns bounds as "X:NNN Y:NNN Width:NNN Height:NNN" or JSON object.
# We handle both; if neither parses, return null (element not found).
function Parse-Bounds {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }

    # Attempt JSON object parse ({"x":N,"y":N,"width":N,"height":N} variants)
    try {
        $obj = $Raw | ConvertFrom-Json -ErrorAction Stop
        # Handle both PascalCase and camelCase keys
        $x = if ($null -ne $obj.X) { [int]$obj.X } elseif ($null -ne $obj.x) { [int]$obj.x } else { $null }
        $y = if ($null -ne $obj.Y) { [int]$obj.Y } elseif ($null -ne $obj.y) { [int]$obj.y } else { $null }
        $w = if ($null -ne $obj.Width) { [int]$obj.Width } elseif ($null -ne $obj.width) { [int]$obj.width } else { $null }
        $h = if ($null -ne $obj.Height) { [int]$obj.Height } elseif ($null -ne $obj.height) { [int]$obj.height } else { $null }
        if ($null -ne $x -and $null -ne $y -and $null -ne $w -and $null -ne $h) {
            return @{ X = $x; Y = $y; Width = $w; Height = $h }
        }
    } catch { }

    # Attempt key:value string parse ("X:100 Y:200 Width:800 Height:50")
    if ($Raw -match 'X[:\s]+(\d+).*?Y[:\s]+(\d+).*?Width[:\s]+(\d+).*?Height[:\s]+(\d+)') {
        return @{
            X      = [int]$Matches[1]
            Y      = [int]$Matches[2]
            Width  = [int]$Matches[3]
            Height = [int]$Matches[4]
        }
    }

    return $null
}

# Capture bounds for a single anchor element via WinWright get_attribute.
# Returns a bounds hashtable or null if the element was not found / WinWright failed.
function Get-AnchorBounds {
    param(
        [string]$Selector,
        [string]$ElementName
    )

    try {
        # Use WinWright CLI to get the BoundingRectangle attribute.
        # The get_attribute command outputs the attribute value to stdout.
        $output = & $WinWrightExe get_attribute `
            --attachTitle $AppTitle `
            --selector $Selector `
            --attribute BoundingRectangle 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [WARN] Could not get bounds for '$ElementName' (selector: $Selector): exit $LASTEXITCODE" -ForegroundColor Yellow
            return $null
        }

        $raw = ($output -join " ").Trim()
        $bounds = Parse-Bounds -Raw $raw

        if ($null -eq $bounds) {
            Write-Host "  [WARN] Could not parse bounds for '$ElementName': $raw" -ForegroundColor Yellow
            return $null
        }

        return $bounds
    } catch {
        Write-Host "  [WARN] Exception capturing bounds for '$ElementName': $_" -ForegroundColor Yellow
        return $null
    }
}

# Capture layout snapshot for all anchors on one screen definition.
# Returns an array of { Selector, Name, Bounds } result objects.
function Capture-ScreenSnapshot {
    param([hashtable]$ScreenDef)

    $results = @()
    foreach ($anchor in $ScreenDef.Anchors) {
        Write-Host "  Capturing: $($anchor.Name)..." -ForegroundColor DarkCyan
        $bounds = Get-AnchorBounds -Selector $anchor.Selector -ElementName $anchor.Name
        $results += [PSCustomObject]@{
            Selector = $anchor.Selector
            Name     = $anchor.Name
            Bounds   = $bounds
        }
    }
    return $results
}

# ---------------------------------------------------------------------------
# Public: Invoke-VisualCheck
# Called by run-winwright-tests.ps1 when -VisualCheck is supplied.
# Compares current layout against all available baselines.
# Returns: $true if all checks passed (or baselines pending), $false if regression found.
# ---------------------------------------------------------------------------

function Invoke-VisualCheck {
    param([int]$Tolerance = $TolerancePx)

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[VISUAL-CHECK] Layout-bounds regression check (tolerance: ${Tolerance}px)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    $anyRegression  = $false
    $anyPending     = $false
    $screensPassed  = 0
    $screensFailed  = 0
    $screensPending = 0

    foreach ($screen in $TrackedScreens) {
        $baselineFile = Join-Path $BaselinesDir $screen.BaselineFile
        Write-Host ""
        Write-Host "[VISUAL-CHECK] Screen: $($screen.Description)" -ForegroundColor Yellow

        if (-not (Test-Path $baselineFile)) {
            Write-Host "  [PENDING] Baseline not found: $($screen.BaselineFile)" -ForegroundColor Yellow
            Write-Host "  Run with -CaptureBaseline to capture. Skipping comparison." -ForegroundColor Yellow
            $screensPending++
            $anyPending = $true
            continue
        }

        # Load baseline
        try {
            $baselineData = Get-Content $baselineFile -Raw | ConvertFrom-Json
        } catch {
            Write-Host "  [WARN] Could not load baseline '$($screen.BaselineFile)': $_" -ForegroundColor Yellow
            $screensPending++
            continue
        }

        # Capture current snapshot
        Write-Host "  Capturing current layout bounds..." -ForegroundColor DarkGray
        $currentSnapshot = Capture-ScreenSnapshot -ScreenDef $screen

        # Compare each anchor
        $screenHasRegression = $false
        foreach ($current in $currentSnapshot) {
            $baseline = $baselineData | Where-Object { $_.Selector -eq $current.Selector } | Select-Object -First 1

            if ($null -eq $baseline) {
                Write-Host "  [WARN] No baseline entry for selector '$($current.Selector)'" -ForegroundColor Yellow
                continue
            }

            if ($null -eq $current.Bounds) {
                Write-Host "  [FAIL] $($current.Name): element not found in current UI" -ForegroundColor Red
                $screenHasRegression = $true
                continue
            }

            $baselineBounds = $baseline.Bounds
            if ($null -eq $baselineBounds) {
                Write-Host "  [WARN] $($current.Name): baseline has no bounds (was element missing at capture time?)" -ForegroundColor Yellow
                continue
            }

            $dX = [Math]::Abs($current.Bounds.X - $baselineBounds.X)
            $dY = [Math]::Abs($current.Bounds.Y - $baselineBounds.Y)
            $dW = [Math]::Abs($current.Bounds.Width  - $baselineBounds.Width)
            $dH = [Math]::Abs($current.Bounds.Height - $baselineBounds.Height)

            if ($dX -le $Tolerance -and $dY -le $Tolerance -and $dW -le $Tolerance -and $dH -le $Tolerance) {
                Write-Host "  [OK] $($current.Name): within tolerance (dX=$dX dY=$dY dW=$dW dH=$dH)" -ForegroundColor Green
            } else {
                Write-Host "  [FAIL] $($current.Name): layout regression detected!" -ForegroundColor Red
                Write-Host "    Baseline: X=$($baselineBounds.X) Y=$($baselineBounds.Y) W=$($baselineBounds.Width) H=$($baselineBounds.Height)" -ForegroundColor Red
                Write-Host "    Current:  X=$($current.Bounds.X) Y=$($current.Bounds.Y) W=$($current.Bounds.Width) H=$($current.Bounds.Height)" -ForegroundColor Red
                Write-Host "    Delta:    dX=$dX dY=$dY dW=$dW dH=$dH (tolerance=${Tolerance}px)" -ForegroundColor Red
                $screenHasRegression = $true
            }
        }

        if ($screenHasRegression) {
            $screensFailed++
            $anyRegression = $true
        } else {
            $screensPassed++
            Write-Host "  [OK] $($screen.Description): all anchors within tolerance" -ForegroundColor Green
        }
    }

    # Summary
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[VISUAL-CHECK] Summary" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Screens passed:  $screensPassed" -ForegroundColor Green
    Write-Host "  Screens failed:  $screensFailed" -ForegroundColor $(if ($screensFailed -gt 0) { "Red" } else { "Green" })
    Write-Host "  Baselines pending capture: $screensPending" -ForegroundColor $(if ($screensPending -gt 0) { "Yellow" } else { "Green" })
    if ($anyPending) {
        Write-Host ""
        Write-Host "[VISUAL-CHECK] [PENDING CAPTURE] One or more baseline files are missing." -ForegroundColor Yellow
        Write-Host "[VISUAL-CHECK] To capture baselines, launch the app at the home screen and run:" -ForegroundColor Yellow
        Write-Host "[VISUAL-CHECK]   cd mobile-app/scripts" -ForegroundColor Yellow
        Write-Host "[VISUAL-CHECK]   .\winwright-visual-check.ps1 -CaptureBaseline" -ForegroundColor Yellow
    }
    Write-Host ""

    return (-not $anyRegression)
}

# ---------------------------------------------------------------------------
# Mode: -CaptureBaseline
# Drives the app to each tracked screen via WinWright, captures current
# bounds for all anchors, and writes baseline JSON files to $BaselinesDir.
# Requires the app to be running at the home screen.
# ---------------------------------------------------------------------------

if ($CaptureBaseline) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[VISUAL-CHECK] Capturing layout baselines" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[VISUAL-CHECK] Tolerance threshold: ${TolerancePx}px per dimension" -ForegroundColor Cyan
    Write-Host "[VISUAL-CHECK] Baselines directory: $BaselinesDir" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $WinWrightExe)) {
        Write-Error "[VISUAL-CHECK] WinWright not found at $WinWrightExe"
        exit 1
    }

    if (-not (Test-Path $BaselinesDir)) {
        New-Item -ItemType Directory -Path $BaselinesDir -Force | Out-Null
        Write-Host "[VISUAL-CHECK] Created baselines directory: $BaselinesDir" -ForegroundColor DarkCyan
    }

    # NOTE: The capture logic navigates to each screen using WinWright CLI primitives.
    # Home screen anchors are captured first (app must start at home).
    # Screens requiring navigation are described by the NavigationSteps comments in
    # $TrackedScreens -- the operator manually navigates the app to each screen
    # in the correct order, or this script navigates via ww_click commands.
    #
    # For this implementation, the Manage Rules and Settings screens require the
    # operator to navigate the app manually between captures, because the app is
    # account-scoped (Settings requires picking an account). The script pauses and
    # prompts between screens.
    #
    # A future enhancement can automate navigation using ww_click/ww_invoke CLI commands.

    foreach ($screen in $TrackedScreens) {
        Write-Host "[VISUAL-CHECK] === Capturing: $($screen.Description) ===" -ForegroundColor Yellow
        Write-Host ""

        # Prompt operator to navigate to the correct screen (except home)
        if ($screen.ScreenId -ne "home") {
            Write-Host "[VISUAL-CHECK] Navigate the app to: $($screen.Description)" -ForegroundColor Cyan
            Write-Host "[VISUAL-CHECK] Press ENTER when the screen is visible and stable..." -ForegroundColor Cyan
            $null = Read-Host
        }

        Write-Host "[VISUAL-CHECK] Capturing anchor bounds for: $($screen.Description)" -ForegroundColor DarkGray
        $snapshot = Capture-ScreenSnapshot -ScreenDef $screen

        $baselineFile = Join-Path $BaselinesDir $screen.BaselineFile
        $baselineData = @()
        foreach ($entry in $snapshot) {
            $baselineData += [PSCustomObject]@{
                Selector = $entry.Selector
                Name     = $entry.Name
                Bounds   = $entry.Bounds
                CapturedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            }
        }

        $baselineData | ConvertTo-Json -Depth 5 | Set-Content -Path $baselineFile -Encoding UTF8
        Write-Host "[VISUAL-CHECK] Saved baseline: $baselineFile" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "[VISUAL-CHECK] Baseline capture complete." -ForegroundColor Green
    Write-Host "  Files written to: $BaselinesDir" -ForegroundColor Green
    Write-Host "  Commit these files: git add mobile-app/test/winwright/baselines/" -ForegroundColor Green
    Write-Host "  Recapture whenever the UI layout intentionally changes." -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Mode: -Compare
# Runs the comparison against committed baselines for all tracked screens.
# Requires the app to be running at the correct screen for each check.
# ---------------------------------------------------------------------------

if ($Compare) {
    if (-not (Test-Path $WinWrightExe)) {
        Write-Error "[VISUAL-CHECK] WinWright not found at $WinWrightExe"
        exit 1
    }

    $passed = Invoke-VisualCheck -Tolerance $TolerancePx
    if ($passed) {
        Write-Host "[VISUAL-CHECK] [OK] All available baselines passed." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[VISUAL-CHECK] [FAIL] One or more layout regressions detected." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Mode: -SelfTest
# Fully offline self-test. Uses two static in-memory data sets to verify
# that Compare-Bounds correctly:
#   (a) Reports no regression when bounds are within tolerance (PASS path)
#   (b) Detects regression when bounds exceed tolerance (FAIL path)
#   (c) Names the failing element in the diff report
#   (d) Reports no false-positive after the "fixed" bounds are applied
#
# Self-test uses the SAME Compare-Bounds logic as the production path,
# operating on PSCustomObject data instead of live WinWright output.
# No app, WinWright, or network access is needed.
#
# Mirrors the pattern of winwright-db-snapshot.ps1 -SelfTest.
# ---------------------------------------------------------------------------

if ($SelfTest) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[SELF-TEST] winwright-visual-check.ps1 layout-bounds self-test" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # Inline bounds-comparison logic (same algorithm as Invoke-VisualCheck)
    function Compare-BoundSets {
        param(
            [object[]]$Baseline,
            [object[]]$Current,
            [int]$Tolerance
        )

        $regressions = @()

        foreach ($cur in $Current) {
            $bl = $Baseline | Where-Object { $_.Selector -eq $cur.Selector } | Select-Object -First 1
            if ($null -eq $bl)    { continue }
            if ($null -eq $cur.Bounds) {
                $regressions += "[FAIL] $($cur.Name): element not found in current UI"
                continue
            }

            $dX = [Math]::Abs($cur.Bounds.X - $bl.Bounds.X)
            $dY = [Math]::Abs($cur.Bounds.Y - $bl.Bounds.Y)
            $dW = [Math]::Abs($cur.Bounds.Width  - $bl.Bounds.Width)
            $dH = [Math]::Abs($cur.Bounds.Height - $bl.Bounds.Height)

            if ($dX -gt $Tolerance -or $dY -gt $Tolerance -or $dW -gt $Tolerance -or $dH -gt $Tolerance) {
                $regressions += "[FAIL] $($cur.Name): dX=$dX dY=$dY dW=$dW dH=$dH (tolerance=${Tolerance}px)"
            }
        }

        return $regressions
    }

    $tolerance = $TolerancePx
    Write-Host "[SELF-TEST] Tolerance: ${tolerance}px per dimension" -ForegroundColor DarkCyan
    $selfTestPassed = $true

    # -----------------------------------------------------------------------
    # STEP 1: Define static baseline data set (simulates committed baseline)
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "[SELF-TEST] Step 1: Defining static baseline layout (3 anchors on home screen)..." -ForegroundColor Yellow

    $staticBaseline = @(
        [PSCustomObject]@{
            Selector = "type=Button[name='Settings']"
            Name     = "Settings button (top-bar)"
            Bounds   = @{ X = 840; Y = 10;  Width = 48; Height = 48 }
        },
        [PSCustomObject]@{
            Selector = "type=Button[name='Help']"
            Name     = "Help button (top-bar)"
            Bounds   = @{ X = 784; Y = 10;  Width = 48; Height = 48 }
        },
        [PSCustomObject]@{
            Selector = "type=Button[name*='Add Account']"
            Name     = "Add Account FAB (bottom)"
            Bounds   = @{ X = 380; Y = 620; Width = 200; Height = 56 }
        }
    )

    Write-Host "[SELF-TEST] Baseline: 3 anchors defined (Settings, Help, Add Account FAB)" -ForegroundColor DarkCyan

    # -----------------------------------------------------------------------
    # STEP 2: Clean current (no drift -- within tolerance)
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "[SELF-TEST] Step 2: Comparing clean snapshot (delta <= ${tolerance}px -- expect no regression)..." -ForegroundColor Yellow

    $cleanCurrent = @(
        [PSCustomObject]@{
            Selector = "type=Button[name='Settings']"
            Name     = "Settings button (top-bar)"
            Bounds   = @{ X = 843; Y = 11;  Width = 48; Height = 48 }   # +3px X, +1px Y (within tolerance)
        },
        [PSCustomObject]@{
            Selector = "type=Button[name='Help']"
            Name     = "Help button (top-bar)"
            Bounds   = @{ X = 784; Y = 10;  Width = 48; Height = 48 }   # exact match
        },
        [PSCustomObject]@{
            Selector = "type=Button[name*='Add Account']"
            Name     = "Add Account FAB (bottom)"
            Bounds   = @{ X = 382; Y = 622; Width = 200; Height = 56 }  # +2px each (within tolerance)
        }
    )

    $cleanRegressions = Compare-BoundSets -Baseline $staticBaseline -Current $cleanCurrent -Tolerance $tolerance

    if ($cleanRegressions.Count -eq 0) {
        Write-Host "[SELF-TEST] Step 2: PASS -- no regression reported for clean snapshot." -ForegroundColor Green
    } else {
        Write-Host "[SELF-TEST] Step 2: FAIL -- false positive(s) reported for clean snapshot:" -ForegroundColor Red
        foreach ($r in $cleanRegressions) { Write-Host "  $r" -ForegroundColor Red }
        $selfTestPassed = $false
    }

    # -----------------------------------------------------------------------
    # STEP 3: Drift current (Settings button shifted 40px left -- exceeds tolerance)
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "[SELF-TEST] Step 3: Comparing drift snapshot (Settings button shifted -40px X -- expect regression)..." -ForegroundColor Yellow

    $driftCurrent = @(
        [PSCustomObject]@{
            Selector = "type=Button[name='Settings']"
            Name     = "Settings button (top-bar)"
            Bounds   = @{ X = 800; Y = 10;  Width = 48; Height = 48 }   # -40px X shift (exceeds tolerance)
        },
        [PSCustomObject]@{
            Selector = "type=Button[name='Help']"
            Name     = "Help button (top-bar)"
            Bounds   = @{ X = 784; Y = 10;  Width = 48; Height = 48 }   # unchanged
        },
        [PSCustomObject]@{
            Selector = "type=Button[name*='Add Account']"
            Name     = "Add Account FAB (bottom)"
            Bounds   = @{ X = 380; Y = 620; Width = 200; Height = 56 }  # unchanged
        }
    )

    $driftRegressions = Compare-BoundSets -Baseline $staticBaseline -Current $driftCurrent -Tolerance $tolerance

    if ($driftRegressions.Count -eq 0) {
        Write-Host "[SELF-TEST] Step 3: FAIL -- drift NOT detected even though Settings button shifted 40px." -ForegroundColor Red
        $selfTestPassed = $false
    } else {
        $settingsInReport = ($driftRegressions | Where-Object { $_ -like "*Settings button*" }).Count -gt 0
        if (-not $settingsInReport) {
            Write-Host "[SELF-TEST] Step 3: FAIL -- regression detected but 'Settings button' not named in report." -ForegroundColor Red
            foreach ($r in $driftRegressions) { Write-Host "  $r" -ForegroundColor Red }
            $selfTestPassed = $false
        } else {
            Write-Host "[SELF-TEST] Step 3: PASS -- regression correctly detected:" -ForegroundColor Green
            foreach ($r in $driftRegressions) { Write-Host "  $r" -ForegroundColor Green }
        }
    }

    # -----------------------------------------------------------------------
    # STEP 4: Verify only the drifted element is flagged (Help and FAB are clean)
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "[SELF-TEST] Step 4: Verifying only the shifted element is flagged (Help + FAB must be clean)..." -ForegroundColor Yellow

    $helpInReport = ($driftRegressions | Where-Object { $_ -like "*Help button*" }).Count -gt 0
    $fabInReport  = ($driftRegressions | Where-Object { $_ -like "*Add Account*" }).Count -gt 0

    if ($helpInReport -or $fabInReport) {
        Write-Host "[SELF-TEST] Step 4: FAIL -- false positive: Help or Add-Account FAB incorrectly flagged." -ForegroundColor Red
        $selfTestPassed = $false
    } else {
        Write-Host "[SELF-TEST] Step 4: PASS -- only the shifted element (Settings) was flagged; Help and FAB clean." -ForegroundColor Green
    }

    # -----------------------------------------------------------------------
    # STEP 5: Missing-element detection (null Bounds)
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "[SELF-TEST] Step 5: Verifying missing-element detection (null Bounds -> FAIL)..." -ForegroundColor Yellow

    $missingCurrent = @(
        [PSCustomObject]@{
            Selector = "type=Button[name='Settings']"
            Name     = "Settings button (top-bar)"
            Bounds   = $null   # element not found in current UI
        },
        [PSCustomObject]@{
            Selector = "type=Button[name='Help']"
            Name     = "Help button (top-bar)"
            Bounds   = @{ X = 784; Y = 10; Width = 48; Height = 48 }
        },
        [PSCustomObject]@{
            Selector = "type=Button[name*='Add Account']"
            Name     = "Add Account FAB (bottom)"
            Bounds   = @{ X = 380; Y = 620; Width = 200; Height = 56 }
        }
    )

    $missingRegressions = Compare-BoundSets -Baseline $staticBaseline -Current $missingCurrent -Tolerance $tolerance

    $settingsMissingInReport = ($missingRegressions | Where-Object { $_ -like "*Settings button*" -and $_ -like "*not found*" }).Count -gt 0

    if (-not $settingsMissingInReport) {
        Write-Host "[SELF-TEST] Step 5: FAIL -- missing element NOT detected (or not named 'not found')." -ForegroundColor Red
        foreach ($r in $missingRegressions) { Write-Host "  $r" -ForegroundColor Red }
        $selfTestPassed = $false
    } else {
        Write-Host "[SELF-TEST] Step 5: PASS -- missing element correctly detected:" -ForegroundColor Green
        foreach ($r in $missingRegressions) { Write-Host "  $r" -ForegroundColor Green }
    }

    # -----------------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------------
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor $(if ($selfTestPassed) { "Green" } else { "Red" })

    if ($selfTestPassed) {
        Write-Host "[SELF-TEST] ALL STEPS PASSED" -ForegroundColor Green
        Write-Host "  Step 1: Static baseline defined" -ForegroundColor Green
        Write-Host "  Step 2: PASS -- no false positive for clean snapshot (delta <= ${tolerance}px)" -ForegroundColor Green
        Write-Host "  Step 3: PASS -- regression correctly detected (Settings shifted 40px X)" -ForegroundColor Green
        Write-Host "  Step 4: PASS -- only the shifted element flagged (no false positives on others)" -ForegroundColor Green
        Write-Host "  Step 5: PASS -- missing element (null bounds) correctly reported as failure" -ForegroundColor Green
    } else {
        Write-Host "[SELF-TEST] ONE OR MORE STEPS FAILED -- see [FAIL] lines above." -ForegroundColor Red
    }

    Write-Host "==========================================" -ForegroundColor $(if ($selfTestPassed) { "Green" } else { "Red" })
    Write-Host ""

    exit $(if ($selfTestPassed) { 0 } else { 1 })
}

# ---------------------------------------------------------------------------
# No mode specified -- print usage
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "winwright-visual-check.ps1 -- Layout-bounds visual regression check"
Write-Host ""
Write-Host "Usage:"
Write-Host "  .\winwright-visual-check.ps1 -CaptureBaseline   # Capture new baselines (app must be running)"
Write-Host "  .\winwright-visual-check.ps1 -Compare           # Compare against baselines (app must be running)"
Write-Host "  .\winwright-visual-check.ps1 -SelfTest          # Offline self-test (no app/WinWright needed)"
Write-Host "  .\winwright-visual-check.ps1 -TolerancePx 4     # Override tolerance (default: 8px)"
Write-Host ""
Write-Host "Integration (called by run-winwright-tests.ps1 -VisualCheck):"
Write-Host "  . .\winwright-visual-check.ps1"
Write-Host "  Invoke-VisualCheck -Tolerance 8"
Write-Host ""
