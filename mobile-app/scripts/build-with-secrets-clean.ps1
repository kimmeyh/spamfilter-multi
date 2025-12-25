<#
.SYNOPSIS
    Build APK with OAuth secrets for Gmail and AOL (clean, ASCII-only version)

.DESCRIPTION
    Reads secrets from secrets.dev.json and builds the Flutter APK with
    configured provider credentials injected at compile time.
    
    Validates that at least one provider is configured, then:
    1. Cleans old build artifacts
    2. Builds APK with dart-define-from-file
    3. Optionally detects/starts emulator, installs APK, and launches app

.PARAMETER BuildType
    Type of build: debug or release (default: release)

.PARAMETER InstallToEmulator
    If set, install the APK to an emulator after build

.EXAMPLE
    .\build-with-secrets-clean.ps1
    .\build-with-secrets-clean.ps1 -BuildType debug -InstallToEmulator
#>

param(
    [ValidateSet('debug', 'release')]
    [string]$BuildType = 'release',
    
    [switch]$InstallToEmulator
)

$ErrorActionPreference = 'Stop'
$mobileAppDir = Split-Path -Parent $PSScriptRoot
Push-Location $mobileAppDir

try {
    Write-Host "[BUILD] Starting APK build with OAuth secrets..." -ForegroundColor Cyan
    Write-Host ""

    # === STEP 1: Validate secrets ===
    $secretsFile = Join-Path $mobileAppDir "secrets.dev.json"
    if (-not (Test-Path $secretsFile)) {
        Write-Host "[ERROR] secrets.dev.json not found at: $secretsFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "To fix this:" -ForegroundColor Yellow
        Write-Host "  1. Copy secrets.dev.json.template to secrets.dev.json" -ForegroundColor Gray
        Write-Host "  2. Fill in your Gmail OAuth or AOL credentials" -ForegroundColor Gray
        Write-Host "  3. Run this script again" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "[SECRETS] Loading from: $secretsFile" -ForegroundColor Cyan
    $secrets = Get-Content $secretsFile | ConvertFrom-Json
    
    # Check if at least one provider is configured
    $hasGmail = -not [string]::IsNullOrWhiteSpace($secrets.GMAIL_DESKTOP_CLIENT_ID) -and $secrets.GMAIL_DESKTOP_CLIENT_ID -notlike "*YOUR*" -and $secrets.GMAIL_DESKTOP_CLIENT_ID -notlike "*REPLACE*"
    $hasAol = -not [string]::IsNullOrWhiteSpace($secrets.AOL_EMAIL) -and $secrets.AOL_EMAIL -notlike "*YOUR*" -and $secrets.AOL_EMAIL -notlike "*your*"
    
    if (-not ($hasGmail -or $hasAol)) {
        Write-Host "[ERROR] No providers configured in secrets.dev.json" -ForegroundColor Red
        Write-Host "  Configure at least Gmail or AOL and try again" -ForegroundColor Yellow
        exit 1
    }
    
    $providers = @()
    if ($hasGmail) { $providers += "Gmail (OAuth)" }
    if ($hasAol) { $providers += "AOL (IMAP)" }
    
    Write-Host "[OK] Providers: $($providers -join ', ')" -ForegroundColor Green
    Write-Host ""

    # === STEP 2: Clean build artifacts ===
    Write-Host "[CLEAN] Removing build artifacts..." -ForegroundColor Cyan
    
    @(
        "build",
        ".dart_tool",
        "android/app/build",
        "android/.gradle",
        ".gradle"
    ) | ForEach-Object {
        $path = $_
        if (Test-Path $path) {
            try { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    
    Write-Host "[OK] Cleanup done" -ForegroundColor Green
    Write-Host ""

    # === STEP 3: Build APK ===
    Write-Host "[BUILD] Building $BuildType APK with dart-define-from-file..." -ForegroundColor Cyan
    
    if ($BuildType -eq 'release') {
        flutter build apk --release --dart-define-from-file=secrets.dev.json
    } else {
        flutter build apk --debug --dart-define-from-file=secrets.dev.json
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed" -ForegroundColor Red
        exit 1
    }
    
    $apkPath = if ($BuildType -eq 'release') {
        "build/app/outputs/flutter-apk/app-release.apk"
    } else {
        "build/app/outputs/flutter-apk/app-debug.apk"
    }
    
    if (-not (Test-Path $apkPath)) {
        Write-Host "[ERROR] APK not found at: $apkPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] APK built: $apkPath" -ForegroundColor Green
    Write-Host ""

    # === STEP 4: Install to emulator (optional) ===
    if ($InstallToEmulator) {
        Write-Host "[INSTALL] Starting emulator detection and installation..." -ForegroundColor Cyan
        
        # Check for running emulator
        Write-Host "[STEP 1/4] Checking for running emulator..." -ForegroundColor Cyan
        $emulatorReady = $false
        $adbRestarts = 0
        
        while (-not $emulatorReady -and $adbRestarts -lt 3) {
            $devices = @(adb devices 2>&1 | Select-String "emulator-" | Select-String -NotMatch "offline")
            if ($devices.Count -gt 0) {
                $emulatorReady = $true
                Write-Host "  [OK] Emulator found: $($devices[0])" -ForegroundColor Green
            } else {
                if ($adbRestarts -lt 3) {
                    Write-Host "  [WAIT] No emulator; restarting adb..." -ForegroundColor Yellow
                    adb kill-server 2>&1 | Out-Null
                    Start-Sleep -Seconds 2
                    adb start-server 2>&1 | Out-Null
                    Start-Sleep -Seconds 2
                    $adbRestarts += 1
                }
            }
        }
        
        # If no running emulator, try to find and start one
        if (-not $emulatorReady) {
            Write-Host "[STEP 2/4] Finding available AVDs..." -ForegroundColor Cyan
            
            $avdList = @()
            try {
                $avdOutput = emulator -list-avds 2>&1 | Out-String
                $avdList = $avdOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
            } catch {
                Write-Host "  [WARN] Could not list AVDs" -ForegroundColor Yellow
            }
            
            if ($avdList.Count -eq 0) {
                Write-Host "  [ERROR] No AVDs found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Create one:" -ForegroundColor Yellow
                Write-Host "  avdmanager create avd -n MyEmulator -k system-images;android-31;default;x86_64" -ForegroundColor Gray
                exit 1
            }
            
            # Prefer pixel34_updated if available
            if ($avdList -contains "pixel34_updated") {
                $avdList = @("pixel34_updated") + ($avdList | Where-Object { $_ -ne "pixel34_updated" })
            }
            
            Write-Host "  [OK] Found: $($avdList -join ', ')" -ForegroundColor Green
            
            # Try to start each AVD
            $started = $false
            foreach ($avdName in $avdList) {
                Write-Host ""
                Write-Host "[STEP 3/4] Starting AVD: $avdName (30-90 seconds)..." -ForegroundColor Cyan
                
                # Find SDK emulator
                $sdkRoot = $Env:ANDROID_SDK_ROOT
                if (-not $sdkRoot) { $sdkRoot = $Env:ANDROID_HOME }
                
                if ($sdkRoot) {
                    $emulatorExe = Join-Path $sdkRoot "emulator" "emulator.exe"
                    if (Test-Path $emulatorExe) {
                        Write-Host "  [INFO] Launching: $emulatorExe -avd $avdName" -ForegroundColor Gray
                        try {
                            Start-Process -FilePath $emulatorExe -ArgumentList @("-avd", $avdName, "-netdelay", "none", "-netspeed", "full", "-no-snapshot", "-gpu", "angle") -NoNewWindow -PassThru | Out-Null
                        } catch {
                            Write-Host "  [ERROR] Could not start emulator" -ForegroundColor Red
                            continue
                        }
                        
                        # Wait for boot
                        Write-Host "  [WAIT] Waiting for boot..." -ForegroundColor Gray
                        $waited = 0
                        $maxWait = 120
                        
                        while ($waited -lt $maxWait) {
                            Start-Sleep -Seconds 3
                            $waited += 3
                            
                            $running = @(adb devices 2>&1 | Select-String "emulator-" | Select-String -NotMatch "offline")
                            if ($running.Count -gt 0) {
                                Write-Host "  [OK] Emulator ready" -ForegroundColor Green
                                $started = $true
                                break
                            }
                        }
                        
                        if ($started) { break }
                        else { Write-Host "  [FAIL] Boot timeout" -ForegroundColor Yellow }
                    } else {
                        Write-Host "  [WARN] Emulator exe not found" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  [WARN] ANDROID_SDK_ROOT not set" -ForegroundColor Yellow
                }
            }
            
            if (-not $started) {
                Write-Host "[ERROR] Could not start any emulator" -ForegroundColor Red
                exit 1
            }
        }
        
        # Install APK
        Write-Host ""
        Write-Host "[STEP 4/4] Installing APK..." -ForegroundColor Cyan
        $installOut = adb install -r $apkPath 2>&1 | Out-String
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] APK installed" -ForegroundColor Green
            
            # Launch app
            Write-Host "  [INFO] Launching app..." -ForegroundColor Gray
            adb shell am start -n com.example.spamfilter_mobile/.MainActivity 2>&1 | Out-Null
            Write-Host "  [OK] App launched" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Installation failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[INFO] To install to emulator:" -ForegroundColor Yellow
        Write-Host "  adb install -r $apkPath" -ForegroundColor Gray
        Write-Host "  Or run with -InstallToEmulator flag" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "[OK] Done!" -ForegroundColor Green

} finally {
    Pop-Location
}
