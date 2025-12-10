# Build release APK for manual testing
param(
  [string]$ProjectPath = "$(Split-Path $PSScriptRoot -Parent)",
  [switch]$VerboseOutput
)

Push-Location $ProjectPath
try {
  Write-Host "Project: $ProjectPath"
  if ($VerboseOutput) { flutter analyze }
  flutter pub get
  flutter build apk

  $apkDir = Join-Path $ProjectPath "build/app/outputs/flutter-apk"
  $apkPath = Join-Path $apkDir "app-release.apk"
  if (Test-Path $apkPath) {
    Write-Host "APK built: $apkPath"
  } else {
    Write-Error "APK not found in $apkDir"
  }
}
finally {
  Pop-Location
}
