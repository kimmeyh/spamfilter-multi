# Rebuilds the Flutter Windows desktop app from scratch.
#
# USAGE:
#   .\build-windows.ps1                          # Dev build, run app after build (default)
#   .\build-windows.ps1 -Environment prod        # Production build
#   .\build-windows.ps1 -RunAfterBuild:$false    # Build without running
#   .\build-windows.ps1 -Release                 # Release build (default)
#   .\build-windows.ps1 -Debug                   # Debug build (slower, larger executable)
#
# EXECUTION:
#   powershell -NoProfile -ExecutionPolicy Bypass -File ./build-windows.ps1
#
# NOTE: Place this script in your mobile-app/scripts directory.

param(
    [switch]$RunAfterBuild = $true,
    [switch]$Release = $true,
    [switch]$Debug = $false,
    [switch]$SkipClean = $false,
    [switch]$AnalyzeSize = $false,
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'

# Determine build mode
if ($Debug) {
    $Release = $false
    $buildMode = "debug"
    $buildTarget = "build\windows\x64\runner\Debug\MyEmailSpamFilter.exe"
} else {
    $buildMode = "release"
    $buildTarget = "build\windows\x64\runner\Release\MyEmailSpamFilter.exe"
}

# Set working directory to the Flutter app root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Join-Path $scriptDir '..'
$projectRoot = Resolve-Path $projectRoot
Set-Location $projectRoot

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Flutter Windows Desktop App Build Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Build Mode: $buildMode"
Write-Host "  Build Target: $buildTarget"
Write-Host "  Clean Before Build: $(-not $SkipClean)"
Write-Host "  Run After Build: $RunAfterBuild"
Write-Host "  Analyze Size: $AnalyzeSize"
Write-Host ""

# Determine environment-aware paths and task names (F31)
$appDataDir = if ($Environment -eq 'prod') {
    "$env:APPDATA\MyEmailSpamFilter\MyEmailSpamFilter"
} else {
    "$env:APPDATA\MyEmailSpamFilter\MyEmailSpamFilter_Dev"
}
$dbPath = Join-Path $appDataDir "spam_filter.db"
$taskName = if ($Environment -eq 'prod') { "SpamFilterBackgroundScan" } else { "SpamFilterBackgroundScan_Dev" }

# Step 1: Clean previous build (optional)
if (-not $SkipClean) {
    Write-Host "[1/6] Cleaning previous build..." -ForegroundColor Cyan
    flutter clean
    Write-Host "[DONE] Clean complete" -ForegroundColor Green
    Write-Host ""
}

# Step 2: Get dependencies
Write-Host "[2/6] Installing dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Dependency installation failed. Exiting." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[DONE] Dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 3: Analyze code
Write-Host "[3/6] Analyzing code (flutter analyze)..." -ForegroundColor Cyan
flutter analyze --no-fatal-infos 2>&1 | Select-Object -First 10
Write-Host "[DONE] Code analysis complete" -ForegroundColor Green
Write-Host ""

# Step 4: Build Windows app
Write-Host "[4/6] Building Windows app in $buildMode mode..." -ForegroundColor Cyan

# Select secrets file based on environment (ADR-0035)
$secretsFileName = if ($Environment -eq 'prod') { "secrets.prod.json" } else { "secrets.dev.json" }
$secretsFile = Join-Path $projectRoot $secretsFileName

$buildCommand = "flutter build windows"

# Add build mode
if ($Debug) {
    $buildCommand += " --debug"
} else {
    $buildCommand += " --release"
}

# Add environment dart-define (ADR-0035)
$buildCommand += " --dart-define=APP_ENV=$Environment"
Write-Host "       Environment: $($Environment.ToUpper())" -ForegroundColor $(if ($Environment -eq 'prod') { 'Green' } else { 'Yellow' })

# Add secrets if present
if (Test-Path $secretsFile) {
    Write-Host "       Using secrets from $secretsFileName" -ForegroundColor Yellow
    $buildCommand += " --dart-define-from-file=$secretsFileName"
} else {
    Write-Host "       [WARNING] $secretsFileName not found" -ForegroundColor Yellow
    # Fallback to secrets.dev.json if prod file missing
    $fallbackSecrets = Join-Path $projectRoot "secrets.dev.json"
    if (($Environment -eq 'prod') -and (Test-Path $fallbackSecrets)) {
        Write-Host "       Falling back to secrets.dev.json" -ForegroundColor Yellow
        $buildCommand += " --dart-define-from-file=secrets.dev.json"
    }
}

# Add size analysis if requested
if ($AnalyzeSize) {
    Write-Host "       Code size analysis enabled" -ForegroundColor Yellow
    $buildCommand += " --analyze-size"
}

# Execute build
Write-Host "       Command: $buildCommand" -ForegroundColor Gray
Invoke-Expression $buildCommand
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed. Exiting." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[DONE] Build complete" -ForegroundColor Green
Write-Host ""

# Step 5: Verify build output
Write-Host "[5/6] Verifying build output..." -ForegroundColor Cyan
if (Test-Path $buildTarget) {
    $exeInfo = Get-Item $buildTarget
    $exeSize = [math]::Round($exeInfo.Length / 1MB, 2)
    Write-Host "       Executable: $($exeInfo.Name)" -ForegroundColor Green
    Write-Host "       Path: $buildTarget" -ForegroundColor Green
    Write-Host "       Size: $exeSize MB" -ForegroundColor Green
    Write-Host "[DONE] Build output verified" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build output not found at: $buildTarget" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 6: Re-register background scan Task Scheduler task (F31)
# After flutter clean + rebuild, the old scheduled task points to a deleted executable.
# This step deletes the stale task and re-creates it with the correct executable path
# if background scanning is enabled in the user's settings database.
Write-Host "[6/6] Checking background scan task..." -ForegroundColor Cyan

# Only repair task for release builds (debug mode uses temp runner paths)
if (-not $Debug) {
    $fullExePath = (Resolve-Path $buildTarget).Path

    # Delete old task (safe even if it does not exist)
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "       Removed old scheduled task '$taskName'" -ForegroundColor Gray
    } catch {
        # Task did not exist - that is fine
    }

    # Check if sqlite3 is available and DB exists
    $sqlite3Path = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($sqlite3Path -and (Test-Path $dbPath)) {
        try {
            # Query background scan settings from SQLite database
            $bgEnabled = & sqlite3 $dbPath "SELECT value FROM app_settings WHERE key = 'background_scan_enabled';" 2>$null
            $bgFrequency = & sqlite3 $dbPath "SELECT value FROM app_settings WHERE key = 'background_scan_frequency';" 2>$null

            if ($bgEnabled -eq 'true') {
                # Determine trigger based on frequency (minutes)
                $workDir = Split-Path $fullExePath -Parent
                switch ($bgFrequency) {
                    '15'   { $trigger = New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 365) }
                    '30'   { $trigger = New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365) }
                    '60'   { $trigger = New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365) }
                    '1440' { $trigger = New-ScheduledTaskTrigger -Daily -At "09:00AM" }
                    default { $trigger = New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 365) }
                }

                $action = New-ScheduledTaskAction -Execute $fullExePath -Argument "--background-scan" -WorkingDirectory $workDir
                $settings = New-ScheduledTaskSettingsSet `
                    -AllowStartIfOnBatteries `
                    -DontStopIfGoingOnBatteries `
                    -StartWhenAvailable `
                    -RunOnlyIfNetworkAvailable `
                    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
                    -RestartCount 3 `
                    -RestartInterval (New-TimeSpan -Minutes 5)

                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
                Write-Host "       Re-registered '$taskName' with frequency: ${bgFrequency}min" -ForegroundColor Green
                Write-Host "       Executable: $fullExePath" -ForegroundColor Gray
            } else {
                Write-Host "       Background scanning is disabled in settings (task not re-registered)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "       [WARNING] Could not read DB settings: $_" -ForegroundColor Yellow
            Write-Host "       Task will be re-registered on next app launch" -ForegroundColor Yellow
        }
    } else {
        if (-not (Test-Path $dbPath)) {
            Write-Host "       No settings database found (first-time build)" -ForegroundColor Gray
        } else {
            Write-Host "       sqlite3 not found in PATH (task will be re-registered on app launch)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "       Skipped (debug builds use temporary runner paths)" -ForegroundColor Gray
}
Write-Host "[DONE] Background scan task check complete" -ForegroundColor Green
Write-Host ""

# Final step: Run app if requested
if ($RunAfterBuild) {
    Write-Host "Launching Windows app..." -ForegroundColor Cyan

    $runCommand = "flutter run -d windows --dart-define=APP_ENV=$Environment"
    if (Test-Path $secretsFile) {
        $runCommand += " --dart-define-from-file=$secretsFileName"
    }
    if ($Debug) {
        $runCommand += " --debug"
    } else {
        $runCommand += " --release"
    }

    Write-Host "       Command: $runCommand" -ForegroundColor Gray
    Invoke-Expression $runCommand
} else {
    Write-Host "[INFO] Skipping app launch (-RunAfterBuild=false)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To run the app manually, execute one of:" -ForegroundColor Cyan
    Write-Host "  powershell -Command ""& '.\$buildTarget'""" -ForegroundColor Gray
    Write-Host "  flutter run -d windows" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "[SUCCESS] Windows build process complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
