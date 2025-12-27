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

Write-Host "[SUCCESS] Windows app build complete." -ForegroundColor Green
