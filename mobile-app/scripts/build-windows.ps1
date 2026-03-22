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

# Step 1: Clean previous build (optional)
if (-not $SkipClean) {
    Write-Host "[1/5] Cleaning previous build..." -ForegroundColor Cyan
    flutter clean
    Write-Host "[DONE] Clean complete" -ForegroundColor Green
    Write-Host ""
}

# Step 2: Get dependencies
Write-Host "[2/5] Installing dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Dependency installation failed. Exiting." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[DONE] Dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 3: Analyze code
Write-Host "[3/5] Analyzing code (flutter analyze)..." -ForegroundColor Cyan
flutter analyze --no-fatal-infos 2>&1 | Select-Object -First 10
Write-Host "[DONE] Code analysis complete" -ForegroundColor Green
Write-Host ""

# Step 4: Build Windows app
Write-Host "[4/5] Building Windows app in $buildMode mode..." -ForegroundColor Cyan

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
Write-Host "[5/5] Verifying build output..." -ForegroundColor Cyan
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

# Final step: Run app if requested
if ($RunAfterBuild) {
    Write-Host "[6/6] Launching Windows app..." -ForegroundColor Cyan

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
