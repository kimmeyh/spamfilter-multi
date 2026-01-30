<#
.SYNOPSIS
    Build MSIX installer for Spam Filter Multi Windows desktop app

.DESCRIPTION
    Builds the Windows desktop app and packages it as an MSIX installer.
    Requires Windows 10 SDK and MSIX Packaging Tool or makeappx.exe.

.PARAMETER BuildType
    Build type: debug or release (default: release)

.PARAMETER Version
    Version number for the MSIX package (default: read from pubspec.yaml)

.PARAMETER SkipBuild
    Skip Flutter build step (use existing build output)

.PARAMETER OutputDir
    Output directory for MSIX package (default: build/windows/msix)

.EXAMPLE
    .\build-msix.ps1
    Build release MSIX package

.EXAMPLE
    .\build-msix.ps1 -BuildType debug
    Build debug MSIX package

.EXAMPLE
    .\build-msix.ps1 -SkipBuild
    Package existing build as MSIX (skip Flutter build)
#>

param(
    [ValidateSet('debug', 'release')]
    [string]$BuildType = 'release',

    [string]$Version,

    [switch]$SkipBuild = $false,

    [string]$OutputDir = "build\windows\msix"
)

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   Spam Filter Multi - MSIX Build Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Build Type:  $BuildType" -ForegroundColor White
Write-Host "Project Dir: $ProjectRoot" -ForegroundColor White
Write-Host ""

# Step 1: Build Flutter app (unless -SkipBuild)
if (-not $SkipBuild) {
    Write-Host "[1/5] Building Flutter Windows app..." -ForegroundColor Yellow

    Push-Location $ProjectRoot
    try {
        # Clean previous build
        Write-Host "  Cleaning previous build..." -ForegroundColor Gray
        flutter clean | Out-Null

        # Get dependencies
        Write-Host "  Getting dependencies..." -ForegroundColor Gray
        flutter pub get | Out-Null

        # Build Windows app
        Write-Host "  Building $BuildType configuration..." -ForegroundColor Gray
        if ($BuildType -eq 'release') {
            flutter build windows --release
        } else {
            flutter build windows --debug
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE"
        }

        Write-Host "  ✓ Flutter build complete" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "[1/5] Skipping Flutter build (using existing build output)" -ForegroundColor Yellow
}

# Step 2: Determine version number
Write-Host ""
Write-Host "[2/5] Determining version number..." -ForegroundColor Yellow

if (-not $Version) {
    # Read version from pubspec.yaml
    $pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
    $pubspecContent = Get-Content $pubspecPath -Raw
    if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)') {
        $Version = $matches[1]
        Write-Host "  Version from pubspec.yaml: $Version" -ForegroundColor Gray
    } else {
        $Version = "1.0.0"
        Write-Host "  Could not read version, using default: $Version" -ForegroundColor Yellow
    }
}

# MSIX requires 4-part version (x.x.x.x)
$MsixVersion = "$Version.0"
Write-Host "  MSIX version: $MsixVersion" -ForegroundColor White

# Step 3: Prepare MSIX packaging directory
Write-Host ""
Write-Host "[3/5] Preparing MSIX packaging directory..." -ForegroundColor Yellow

# Determine build output directory
if ($BuildType -eq 'release') {
    $BuildOutputDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
} else {
    $BuildOutputDir = Join-Path $ProjectRoot "build\windows\x64\runner\Debug"
}

if (-not (Test-Path $BuildOutputDir)) {
    throw "Build output directory not found: $BuildOutputDir. Run without -SkipBuild first."
}

# Create output directory
$MsixOutputDir = Join-Path $ProjectRoot $OutputDir
if (Test-Path $MsixOutputDir) {
    Write-Host "  Cleaning existing output directory..." -ForegroundColor Gray
    Remove-Item $MsixOutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $MsixOutputDir -Force | Out-Null

Write-Host "  Output directory: $MsixOutputDir" -ForegroundColor Gray

# Step 4: Update Package.appxmanifest version
Write-Host ""
Write-Host "[4/5] Updating Package.appxmanifest..." -ForegroundColor Yellow

$ManifestPath = Join-Path $ProjectRoot "windows\Package.appxmanifest"
if (Test-Path $ManifestPath) {
    $manifestContent = Get-Content $ManifestPath -Raw
    $manifestContent = $manifestContent -replace 'Version="\d+\.\d+\.\d+\.\d+"', "Version=`"$MsixVersion`""
    Set-Content -Path $ManifestPath -Value $manifestContent -NoNewline
    Write-Host "  ✓ Updated version to $MsixVersion" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Package.appxmanifest not found at $ManifestPath" -ForegroundColor Yellow
}

# Step 5: Package as MSIX using makeappx.exe
Write-Host ""
Write-Host "[5/5] Packaging as MSIX..." -ForegroundColor Yellow

# Find makeappx.exe
$WindowsSdkPath = "C:\Program Files (x86)\Windows Kits\10\bin"
$makeappxPath = $null

if (Test-Path $WindowsSdkPath) {
    $sdkVersions = Get-ChildItem $WindowsSdkPath -Directory | Sort-Object Name -Descending
    foreach ($version in $sdkVersions) {
        $candidatePath = Join-Path $version.FullName "x64\makeappx.exe"
        if (Test-Path $candidatePath) {
            $makeappxPath = $candidatePath
            break
        }
    }
}

if (-not $makeappxPath) {
    throw "makeappx.exe not found. Please install Windows 10 SDK."
}

Write-Host "  Using makeappx.exe: $makeappxPath" -ForegroundColor Gray

# Copy build output to packaging directory
$PackagingDir = Join-Path $MsixOutputDir "package_staging"
New-Item -ItemType Directory -Path $PackagingDir -Force | Out-Null
Copy-Item -Path "$BuildOutputDir\*" -Destination $PackagingDir -Recurse -Force

# Copy Package.appxmanifest to packaging directory
if (Test-Path $ManifestPath) {
    Copy-Item -Path $ManifestPath -Destination $PackagingDir -Force
}

# Create MSIX package
$MsixPath = Join-Path $MsixOutputDir "SpamFilterMulti_${Version}_x64.msix"
Write-Host "  Creating MSIX package..." -ForegroundColor Gray

& $makeappxPath pack /d $PackagingDir /p $MsixPath /nv

if ($LASTEXITCODE -ne 0) {
    throw "makeappx.exe failed with exit code $LASTEXITCODE"
}

Write-Host "  ✓ MSIX package created: $MsixPath" -ForegroundColor Green

# Cleanup staging directory
Remove-Item $PackagingDir -Recurse -Force

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   MSIX Build Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package Location: $MsixPath" -ForegroundColor White
Write-Host "Package Version:  $MsixVersion" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Sign the MSIX package with a certificate (required for installation)" -ForegroundColor White
Write-Host "2. Test installation: Add-AppxPackage -Path <path-to-msix>" -ForegroundColor White
Write-Host "3. Create AppInstaller file for auto-updates (see generate-appinstaller.ps1)" -ForegroundColor White
Write-Host ""
