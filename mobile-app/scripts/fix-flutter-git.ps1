# Fix Flutter Git Repository
# This script fixes the "Flutter directory is not a clone" error

$ErrorActionPreference = 'Stop'

Write-Host "[INFO] Fixing Flutter Git repository..." -ForegroundColor Cyan

# Find Flutter installation
$flutterBat = (Get-Command flutter).Source
Write-Host "[DEBUG] Flutter bat file: $flutterBat"
$flutterPath = Split-Path (Split-Path $flutterBat -Parent) -Parent
Write-Host "[INFO] Flutter installation: $flutterPath"

Push-Location $flutterPath
try {
    # Check if .git exists
    if (-not (Test-Path ".git")) {
        Write-Host "[ERROR] No .git directory found at $flutterPath" -ForegroundColor Red
        exit 1
    }

    # Check if already configured
    $hasRemote = git remote | Select-String "origin"
    if ($hasRemote) {
        Write-Host "[INFO] Git remote already configured" -ForegroundColor Green
        git remote -v
    } else {
        Write-Host "[INFO] Adding Flutter remote..."
        git remote add origin https://github.com/flutter/flutter.git
    }

    # Fetch stable branch (shallow clone for speed)
    Write-Host "[INFO] Fetching stable branch (this may take a moment)..."
    git fetch --depth 1 origin stable

    # Reset to stable
    Write-Host "[INFO] Resetting to origin/stable..."
    git reset --hard origin/stable

    # Verify
    Write-Host ""
    Write-Host "[SUCCESS] Flutter Git repository fixed!" -ForegroundColor Green
    Write-Host "Current branch:" -ForegroundColor Yellow
    git branch
    Write-Host "Latest commit:" -ForegroundColor Yellow
    git log -1 --oneline
}
catch {
    Write-Host "[ERROR] Failed to fix Flutter Git: $_" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "[INFO] You can now run Flutter commands normally" -ForegroundColor Cyan
