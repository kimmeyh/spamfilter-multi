# Rebuilds the Flutter Windows desktop app from scratch.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File ./build-windows.ps1
# Place this script in your mobile-app/scripts directory.

param(
    [switch]$RunAfterBuild = $true
)

$ErrorActionPreference = 'Stop'

# Set working directory to the Flutter app root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Join-Path $scriptDir '..'
$projectRoot = Resolve-Path $projectRoot
Set-Location $projectRoot

Write-Host "[INFO] Running flutter clean..." -ForegroundColor Cyan
flutter clean

Write-Host "[INFO] Getting dependencies..." -ForegroundColor Cyan
flutter pub get


# Inject secrets from secrets.dev.json if present
$secretsFile = Join-Path $projectRoot "secrets.dev.json"
if (Test-Path $secretsFile) {
    Write-Host "[INFO] Using --dart-define-from-file=secrets.dev.json for build and run." -ForegroundColor Cyan
    Write-Host "[INFO] Building Windows app..." -ForegroundColor Cyan
    flutter build windows --dart-define-from-file=secrets.dev.json
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed. Exiting." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    if ($RunAfterBuild) {
        Write-Host "[INFO] Running Windows app..." -ForegroundColor Cyan
        flutter run -d windows --dart-define-from-file=secrets.dev.json
    }
} else {
    Write-Host "[WARNING] secrets.dev.json not found. Building without injected secrets." -ForegroundColor Yellow
    Write-Host "[INFO] Building Windows app..." -ForegroundColor Cyan
    flutter build windows
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed. Exiting." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    if ($RunAfterBuild) {
        Write-Host "[INFO] Running Windows app..." -ForegroundColor Cyan
        flutter run -d windows
    }
}

Write-Host "[SUCCESS] Windows app build complete." -ForegroundColor Green
