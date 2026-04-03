# Launch the MSIX-installed MyEmailSpamFilter app
#
# Usage:
#   .\launch-msix.ps1           # Launch the app
#   .\launch-msix.ps1 -Uninstall  # Remove the MSIX package
#   .\launch-msix.ps1 -Install <path>  # Install an MSIX and launch

param(
    [switch]$Uninstall,
    [string]$Install
)

$appName = "KimmeyConsulting-Ohio.MyEmailSpamFilter"

# Find the installed package
$pkg = Get-AppxPackage -Name $appName -ErrorAction SilentlyContinue

if ($Uninstall) {
    if ($pkg) {
        Write-Host "Removing $appName..."
        $pkg | Remove-AppxPackage
        Write-Host "Removed."
    } else {
        Write-Host "Package not installed."
    }
    exit 0
}

if ($Install) {
    if (-not (Test-Path $Install)) {
        Write-Host "File not found: $Install" -ForegroundColor Red
        exit 1
    }
    # Remove existing install first
    if ($pkg) {
        Write-Host "Removing existing install..."
        $pkg | Remove-AppxPackage
        Start-Sleep -Seconds 2
    }
    Write-Host "Installing $Install..."
    Add-AppxPackage -Path $Install
    # Refresh package reference
    $pkg = Get-AppxPackage -Name $appName -ErrorAction SilentlyContinue
}

if (-not $pkg) {
    Write-Host "MyEmailSpamFilter is not installed as MSIX." -ForegroundColor Red
    Write-Host "Install with: .\launch-msix.ps1 -Install <path-to-msix>"
    exit 1
}

# Get the app entry point from the manifest
$manifest = Get-AppxPackageManifest $pkg
$appId = $manifest.Package.Applications.Application.Id

# Launch via explorer (most reliable method on Windows)
$aumid = "$($pkg.PackageFamilyName)!$appId"
Write-Host "Launching: $aumid"
explorer.exe "shell:AppsFolder\$aumid"

# Wait and verify
Start-Sleep -Seconds 5
$process = Get-Process -Name "MyEmailSpamFilter" -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "App running (PID: $($process.Id))" -ForegroundColor Green
} else {
    Write-Host "App may not have launched. Check Start Menu for MyEmailSpamFilter." -ForegroundColor Yellow
}
