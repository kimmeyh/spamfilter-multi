# Launch an Android emulator and run the app
param(
  [string]$ProjectPath = "$(Split-Path $PSScriptRoot -Parent)",
  [string]$EmulatorId = "pixel34",
  [switch]$InstallReleaseApk
)

function Wait-For-AdbDevice {
  Write-Host "Waiting for ADB device..."
  adb wait-for-device | Out-Null
  $devices = adb devices | Select-String "\tdevice$"
  if (-not $devices) {
    Write-Warning "No ADB devices detected. Ensure the emulator is running."
  } else {
    Write-Host "Device detected: $($devices -join ', ')"
  }
}

# Start emulator via Flutter (creates if already present)
Write-Host "Launching emulator: $EmulatorId"
flutter emulators --launch $EmulatorId | Out-Null

Wait-For-AdbDevice

Push-Location $ProjectPath
try {
  Write-Host "Project: $ProjectPath"
  if ($InstallReleaseApk) {
    # Install prebuilt release APK if present
    $apk = Join-Path $ProjectPath "build/app/outputs/flutter-apk/app-release.apk"
    if (Test-Path $apk) {
      Write-Host "Installing APK: $apk"
      adb install -r $apk | Write-Host
    } else {
      Write-Warning "APK not found at $apk. Building debug run instead."
      flutter run
      return
    }
  } else {
    # Run debug build on emulator
    flutter run
  }
}
finally {
  Pop-Location
}
