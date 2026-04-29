# Rebuilds the Flutter Windows desktop app from scratch.
#
# USAGE (interactive PowerShell session):
#   .\build-windows.ps1                          # Dev build, run app after build (default)
#   .\build-windows.ps1 -Environment prod        # Production build
#   .\build-windows.ps1 -RunAfterBuild:$false    # Build without running (interactive only)
#   .\build-windows.ps1 -Release                 # Release build (default)
#   .\build-windows.ps1 -Debug                   # Debug build (slower, larger executable)
#
# USAGE (powershell -File ... invocation):
#   The colon-prefixed switch syntax (-RunAfterBuild:$false) only parses
#   correctly in an interactive PowerShell session. When invoked via
#   `powershell -File ...`, use one of:
#     powershell -NoProfile -ExecutionPolicy Bypass -File ./build-windows.ps1 -Environment prod
#     powershell -NoProfile -ExecutionPolicy Bypass -Command "& './build-windows.ps1' -RunAfterBuild:`$false -Environment prod"
#
# EXECUTION:
#   powershell -NoProfile -ExecutionPolicy Bypass -File ./build-windows.ps1
#
# Sprint 37 F52 Phase 1: builds dev and prod can coexist on disk via
# env-specific variant subdirs (Release-dev/, Release-prod/) and
# env-specific .exe names (MyEmailSpamFilter-Dev.exe, MyEmailSpamFilter.exe).
# The script kills stale Dart VMs before flutter clean and launches the
# variant binary directly (no flutter run) so back-to-back environment
# builds do not contaminate each other's AOT artifacts.
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
# Sprint 37 F52 Phase 1: post-build the canonical Flutter output
# (build\windows\x64\runner\Release\MyEmailSpamFilter.exe) is copied to
# an env-specific subdir with an env-specific .exe name so that prod
# and dev builds can coexist on disk and run simultaneously without
# rebuild. The build itself still produces the same output path -- we
# layer the multi-variant capability on top via copy + rename.
if ($Debug) {
    $Release = $false
    $buildMode = "debug"
    $buildTarget = "build\windows\x64\runner\Debug\MyEmailSpamFilter.exe"
} else {
    $buildMode = "release"
    $buildTarget = "build\windows\x64\runner\Release\MyEmailSpamFilter.exe"
}

# F52 Phase 1: env-specific persistent output directory and executable name.
# These are the user-facing run targets after the build completes.
#
# Variant directories live OUTSIDE build/ (under mobile-app/dist/) so
# they survive `flutter clean`, which wipes the entire build/ tree. The
# original Sprint 37 implementation placed variants under build/ and
# discovered during Phase 5.3 testing that back-to-back builds wiped
# the prior variant. Moving variants to dist/ is the architectural fix
# (option A from Sprint 37 mid-sprint scope decision, 2026-04-29).
if ($Debug) {
    # Debug builds skip multi-variant copy (debug runner paths are temporary).
    $variantDir = $null
    $variantExeName = $null
    $variantBuildTarget = $null
} else {
    $variantDir = if ($Environment -eq 'prod') {
        "dist\prod"
    } else {
        "dist\dev"
    }
    $variantExeName = if ($Environment -eq 'prod') {
        "MyEmailSpamFilter.exe"
    } else {
        "MyEmailSpamFilter-Dev.exe"
    }
    $variantBuildTarget = Join-Path $variantDir $variantExeName
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
Write-Host "  Environment: $($Environment.ToUpper())"
Write-Host "  Build Target: $buildTarget"
if ($variantBuildTarget) {
    Write-Host "  Variant Target: $variantBuildTarget"
}
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
# Sprint 37 F52 Phase 1 fix: terminate stale Dart VMs and any running app
# instances before `flutter clean`. Without this, Windows file locks held
# by leftover dart.exe / dartvm.exe / MyEmailSpamFilter*.exe processes
# cause `flutter clean` to silently no-op on locked files, then
# `flutter build` short-circuits ("nothing changed") and produces a stale
# AOT. Concretely: building -Environment dev then -Environment prod
# back-to-back without this step ships a prod variant containing the
# previous dev AOT (window title reads [DEV] despite APP_ENV=prod).
if (-not $SkipClean) {
    Write-Host "[1/6] Cleaning previous build..." -ForegroundColor Cyan

    $staleProcessNames = @('MyEmailSpamFilter', 'MyEmailSpamFilter-Dev', 'dart', 'dartvm')
    foreach ($procName in $staleProcessNames) {
        $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($running) {
            Write-Host "       Terminating $($running.Count) stale $procName process(es) holding build/ locks" -ForegroundColor Yellow
            $running | Stop-Process -Force -ErrorAction SilentlyContinue
            # Brief pause so the OS releases file handles before flutter clean
            Start-Sleep -Milliseconds 500
        }
    }

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
# Pre-build cleanup: Remove native_assets to prevent PathExistsException (sqlite3.dll)
# Flutter SDK bug: install_code_assets runs twice, second copy fails if file exists.
# See docs/TROUBLESHOOTING.md "Windows build: MSB8066 / PathExistsException"
$nativeAssetsDir = Join-Path $projectRoot "build\native_assets"
if (Test-Path $nativeAssetsDir) {
    Remove-Item -Path $nativeAssetsDir -Recurse -Force -ErrorAction SilentlyContinue
}
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

# Sprint 37 F52 Phase 1: export SPAMFILTER_APP_ENV so CMake (configuring
# the Windows runner) sees it at build time. CMakeLists.txt picks this up
# and bakes it into the .exe via target_compile_definitions, so the
# window title is determined by the binary itself rather than by a
# runtime command-line check. Required for direct-launch variants and
# for Microsoft Store MSIX uploads (where the Store launcher does NOT
# pass --dart-define on the command line).
$env:SPAMFILTER_APP_ENV = $Environment
Write-Host "       SPAMFILTER_APP_ENV exported as: $env:SPAMFILTER_APP_ENV" -ForegroundColor Gray

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

    # Sprint 37 F52 Phase 1: copy the canonical Flutter output to an
    # env-specific persistent dir + filename so dev and prod can coexist
    # on disk. Variant dirs live under mobile-app/dist/ (NOT build/) so
    # `flutter clean` does not wipe them. Whichever was built last is
    # reflected in the canonical build/.../Release/ path, but each env's
    # persistent target is the dist/ variant subdir.
    if (-not $Debug -and $variantBuildTarget) {
        Write-Host "       Copying to variant target: $variantBuildTarget" -ForegroundColor Cyan
        $sourceDir = Split-Path $buildTarget -Parent

        # Ensure parent dist/ exists
        $variantParent = Split-Path $variantDir -Parent
        if ($variantParent -and -not (Test-Path $variantParent)) {
            New-Item -ItemType Directory -Path $variantParent -Force | Out-Null
        }

        # Recreate variant dir cleanly so resources/dlls match the latest build.
        if (Test-Path $variantDir) {
            Remove-Item -Path $variantDir -Recurse -Force
        }
        Copy-Item -Path $sourceDir -Destination $variantDir -Recurse
        # Rename the .exe inside the variant dir to the env-specific name.
        $copiedExe = Join-Path $variantDir "MyEmailSpamFilter.exe"
        if ((Test-Path $copiedExe) -and ($variantExeName -ne "MyEmailSpamFilter.exe")) {
            Rename-Item -Path $copiedExe -NewName $variantExeName
        }
        if (Test-Path $variantBuildTarget) {
            Write-Host "       Variant build: $variantBuildTarget" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Variant copy failed: $variantBuildTarget not found" -ForegroundColor Red
            exit 1
        }
    }

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
    # Sprint 37 F52 Phase 1: scheduled task points at the env-specific
    # variant .exe so dev and prod tasks reference distinct binaries
    # (matching the env-specific $taskName).
    $taskExeTarget = if ($variantBuildTarget -and (Test-Path $variantBuildTarget)) {
        $variantBuildTarget
    } else {
        $buildTarget
    }
    $fullExePath = (Resolve-Path $taskExeTarget).Path

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
# Sprint 37 F52 Phase 1 fix: launch the variant binary DIRECTLY instead of
# invoking `flutter run`. `flutter run` rebuilds, reattaches a Dart VM,
# and leaves dart.exe processes holding file locks under build/ -- which
# was the root cause of the back-to-back -Environment dev / prod build
# producing a prod variant with the dev AOT baked in. Direct launch via
# Start-Process spawns the variant .exe with no Dart VM attached, so a
# subsequent build can `flutter clean` cleanly.
if ($RunAfterBuild) {
    Write-Host "Launching Windows app..." -ForegroundColor Cyan

    if ($Debug) {
        # Debug builds skip variant copy and have no persistent .exe to
        # launch directly; fall back to `flutter run` for hot-reload.
        $runCommand = "flutter run -d windows --dart-define=APP_ENV=$Environment"
        if (Test-Path $secretsFile) {
            $runCommand += " --dart-define-from-file=$secretsFileName"
        }
        $runCommand += " --debug"
        Write-Host "       Command: $runCommand" -ForegroundColor Gray
        Invoke-Expression $runCommand
    } elseif ($variantBuildTarget -and (Test-Path $variantBuildTarget)) {
        # Release builds: launch the env-specific variant binary directly.
        # No Dart VM is attached after launch, so future `flutter clean`
        # invocations are not blocked by file locks.
        $launchTarget = (Resolve-Path $variantBuildTarget).Path
        Write-Host "       Variant target: $launchTarget" -ForegroundColor Gray
        Start-Process -FilePath $launchTarget
        Write-Host "[DONE] App launched (no Dart VM attached)" -ForegroundColor Green
    } else {
        # Fallback: variant target missing for some reason -- launch
        # canonical Release/MyEmailSpamFilter.exe.
        $launchTarget = (Resolve-Path $buildTarget).Path
        Write-Host "       Fallback target: $launchTarget" -ForegroundColor Yellow
        Start-Process -FilePath $launchTarget
        Write-Host "[DONE] App launched (canonical fallback)" -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] Skipping app launch (-RunAfterBuild=false)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To run the app manually, execute one of:" -ForegroundColor Cyan
    if ($variantBuildTarget -and (Test-Path $variantBuildTarget)) {
        Write-Host "  powershell -Command ""& '.\$variantBuildTarget'""" -ForegroundColor Gray
        Write-Host "  (env-specific variant build for $Environment)" -ForegroundColor Gray
    } else {
        Write-Host "  powershell -Command ""& '.\$buildTarget'""" -ForegroundColor Gray
    }
    Write-Host "  flutter run -d windows --dart-define=APP_ENV=$Environment" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "[SUCCESS] Windows build process complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
