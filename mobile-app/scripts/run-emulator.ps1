# Launch an Android emulator and run the app
param(
  [string]$ProjectPath = "$(Split-Path $PSScriptRoot -Parent)",
  [string]$EmulatorId = "pixel34",
  [switch]$InstallReleaseApk,
  [string]$PackageId = "com.example.spamfilter_mobile"
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

function Wait-For-EmulatorBoot {
  Write-Host "Waiting for emulator to complete boot..."
  $booted = ""
  $attempts = 0
  while ($booted.Trim() -ne "1" -and $attempts -lt 180) { # up to ~6 minutes
    $booted = adb shell getprop sys.boot_completed
    Start-Sleep -Seconds 2
    $attempts++
  }
  if ($booted.Trim() -ne "1") {
    Write-Warning "Emulator did not finish booting in time. APK install may fail."
  } else {
    Write-Host "Emulator boot complete."
  }
}

# Start emulator via Flutter (creates if already present)
Write-Host "Launching emulator: $EmulatorId"
flutter emulators --launch $EmulatorId | Out-Null

# Ensure ADB is running cleanly before waiting
adb kill-server | Out-Null
adb start-server | Out-Null
Wait-For-AdbDevice
Wait-For-EmulatorBoot

Push-Location $ProjectPath
try {
  Write-Host "Project: $ProjectPath"

  # Suppress Flutter Git check warning by using --suppress-analytics and checking for existing build
  $env:FLUTTER_SUPPRESS_ANALYTICS = "true"

  if ($InstallReleaseApk) {
    # Install prebuilt release APK if present
    $apk = Join-Path $ProjectPath "build/app/outputs/flutter-apk/app-release.apk"
    if (Test-Path $apk) {
      Write-Host "Installing APK: $apk"
      $installResult = adb install -r $apk 2>&1
      Write-Host $installResult
      if ($LASTEXITCODE -ne 0) {
        Write-Warning "APK install failed (exit code $LASTEXITCODE). Printing recent logs for diagnostics..."
        adb logcat -d | Select-String -Pattern "ActivityManager|AndroidRuntime|E/flutter|FATAL|Exception" -SimpleMatch | Out-String | Write-Output
        return
      }
      Write-Host "Launching app ($PackageId)..."
      adb shell monkey -p $PackageId -c android.intent.category.LAUNCHER 1 | Write-Host
    } else {
      Write-Warning "APK not found at $apk. Building debug run instead."
      # Use flutter run with error suppression
      Write-Host "Running: flutter run --no-pub --no-build-ios --no-build-macos"
      flutter run --no-pub --no-build-ios --no-build-macos
      return
    }
  } else {
    # Run debug build on emulator with Git check bypass
    Write-Host "Running: flutter run --no-pub --no-build-ios --no-build-macos"
    flutter run --no-pub --no-build-ios --no-build-macos
  }
}
finally {
  Pop-Location
  Remove-Item Env:\FLUTTER_SUPPRESS_ANALYTICS -ErrorAction SilentlyContinue
}
