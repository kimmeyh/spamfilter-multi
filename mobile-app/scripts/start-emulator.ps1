# Start the Android emulator (pixel34_updated AVD) -- Sprint 60.
#
# WHY THIS SCRIPT EXISTS (discovered during Sprint 60's F150/F156 work):
#  - The pixel34_updated AVD belongs to the SDK installation at
#    C:\Android\android-sdk. Its OWN emulator.exe must be used -- the other
#    installed SDK's emulator (%LOCALAPPDATA%\Android\Sdk) fails with
#    "Can't find 'Linux version' string in kernel image file".
#  - ANDROID_SDK_ROOT must point at that SDK or the emulator panics with
#    "Cannot find AVD system path".
#  - The netsimd.exe crash dialog that sometimes appears on start is a KNOWN
#    BENIGN emulator sidecar failure (network-simulation daemon); click
#    "Close program" -- the emulator falls back to its legacy network stack
#    and everything (adb, installs, app networking) keeps working.
#
# Usage:
#   .\start-emulator.ps1              # start pixel34_updated
#   .\start-emulator.ps1 -Avd <name>  # start a different AVD
#
# This ONLY starts the emulator. To put current code on it afterwards:
#   .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator

param(
    [string]$Avd = "pixel34_updated",
    # PR #335 review (Copilot): SDK root configurable for other machines/CI;
    # default stays this box's validated install (the AVD lives under it).
    [string]$SdkRoot = "C:\Android\android-sdk"
)

$sdkRoot = $SdkRoot
$emulator = Join-Path $sdkRoot "emulator\emulator.exe"

if (-not (Test-Path $emulator)) {
    Write-Error "Emulator not found at $emulator -- has the SDK moved?"
    exit 1
}

$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_HOME = $sdkRoot

Write-Host "[emulator] Starting AVD '$Avd' from $sdkRoot ..." -ForegroundColor Cyan
Start-Process -FilePath $emulator -ArgumentList "-avd", $Avd

Write-Host "[emulator] Launched. Boot takes ~30-60s; check with: adb devices" -ForegroundColor Cyan
Write-Host "[emulator] If a netsimd.exe crash dialog appears, click 'Close program' -- it is benign." -ForegroundColor DarkGray
