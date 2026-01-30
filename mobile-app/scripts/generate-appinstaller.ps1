<#
.SYNOPSIS
    Generate AppInstaller file for Spam Filter Multi MSIX auto-updates

.DESCRIPTION
    Creates an AppInstaller XML file that enables automatic updates for the MSIX package.
    Users install via the .appinstaller file, and the app checks for updates automatically.

.PARAMETER MsixUri
    Public HTTP/HTTPS URL where the MSIX package is hosted (required)

.PARAMETER Version
    Version number of the MSIX package (default: read from pubspec.yaml)

.PARAMETER OutputPath
    Output path for the .appinstaller file (default: build/windows/msix/SpamFilterMulti.appinstaller)

.PARAMETER UpdateCheckHours
    Hours between automatic update checks (default: 24)

.EXAMPLE
    .\generate-appinstaller.ps1 -MsixUri "https://example.com/releases/SpamFilterMulti_1.0.0_x64.msix"
    Generate AppInstaller file with default settings

.EXAMPLE
    .\generate-appinstaller.ps1 -MsixUri "https://example.com/releases/latest.msix" -UpdateCheckHours 12
    Generate AppInstaller file that checks for updates every 12 hours
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MsixUri,

    [string]$Version,

    [string]$OutputPath = "build\windows\msix\SpamFilterMulti.appinstaller",

    [int]$UpdateCheckHours = 24
)

# Script configuration
$ErrorActionPreference = 'Stop'

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AppInstaller Generator for Spam Filter Multi" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Determine version number
if (-not $Version) {
    # Read version from pubspec.yaml
    $pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
    $pubspecContent = Get-Content $pubspecPath -Raw
    if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)') {
        $Version = $matches[1]
        Write-Host "Version from pubspec.yaml: $Version" -ForegroundColor White
    } else {
        throw "Could not read version from pubspec.yaml. Please specify -Version parameter."
    }
}

# MSIX requires 4-part version (x.x.x.x)
$MsixVersion = "$Version.0"

Write-Host "MSIX URI:              $MsixUri" -ForegroundColor White
Write-Host "MSIX Version:          $MsixVersion" -ForegroundColor White
Write-Host "Update Check Interval: Every $UpdateCheckHours hours" -ForegroundColor White
Write-Host ""

# Generate AppInstaller XML
$appInstallerXml = @"
<?xml version="1.0" encoding="utf-8"?>
<AppInstaller
    xmlns="http://schemas.microsoft.com/appx/appinstaller/2018"
    Version="$MsixVersion"
    Uri="$MsixUri">

  <MainBundle
      Name="SpamFilterMulti"
      Publisher="CN=SpamFilterMulti"
      Version="$MsixVersion"
      Uri="$MsixUri" />

  <UpdateSettings>
    <OnLaunch
        HoursBetweenUpdateChecks="$UpdateCheckHours"
        ShowPrompt="true"
        UpdateBlocksActivation="false" />
    <AutomaticBackgroundTask />
  </UpdateSettings>

</AppInstaller>
"@

# Create output directory if it does not exist
$OutputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Resolve full output path
$FullOutputPath = Join-Path $ProjectRoot $OutputPath

# Write AppInstaller file
Set-Content -Path $FullOutputPath -Value $appInstallerXml -Encoding UTF8

Write-Host "✓ AppInstaller file generated successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Output File: $FullOutputPath" -ForegroundColor White
Write-Host ""
Write-Host "Deployment Instructions:" -ForegroundColor Yellow
Write-Host "1. Upload both the .msix and .appinstaller files to your web server" -ForegroundColor White
Write-Host "2. Ensure files are accessible at the specified URI" -ForegroundColor White
Write-Host "3. Users install via: https://your-server.com/path/to/SpamFilterMulti.appinstaller" -ForegroundColor White
Write-Host "4. The app will automatically check for updates every $UpdateCheckHours hours" -ForegroundColor White
Write-Host ""
Write-Host "Update Workflow:" -ForegroundColor Yellow
Write-Host "1. Build new MSIX version: .\build-msix.ps1" -ForegroundColor White
Write-Host "2. Update .appinstaller file: .\generate-appinstaller.ps1 -MsixUri <new-uri>" -ForegroundColor White
Write-Host "3. Upload new .msix and updated .appinstaller to server" -ForegroundColor White
Write-Host "4. Installed apps will automatically detect and prompt for update" -ForegroundColor White
Write-Host ""
