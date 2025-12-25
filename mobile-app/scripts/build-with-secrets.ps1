<#
.SYNOPSIS
    Build APK with OAuth secrets for all providers (Gmail + AOL)

.DESCRIPTION
    Reads secrets from secrets.dev.json and builds the Flutter APK with
    OAuth credentials for all email providers injected at compile time.
    Validates that ALL providers are properly configured before building.
    
    This ensures the app includes all provider options without needing
    a platform or provider flag.

.PARAMETER BuildType
    Type of build: debug or release (default: release)

.PARAMETER InstallToEmulator
    If set, install the APK to running emulator after build

.EXAMPLE
    .\build-with-secrets.ps1
    .\build-with-secrets.ps1 -BuildType debug
    .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
#>

param(
    [ValidateSet('debug', 'release')]
    [string]$BuildType = 'release',
    
    [switch]$InstallToEmulator
)

$ErrorActionPreference = 'Stop'

# Navigate to mobile-app directory
$mobileAppDir = Split-Path -Parent $PSScriptRoot
Push-Location $mobileAppDir

try {
    Write-Host "🔐 Building Flutter APK with OAuth secrets..." -ForegroundColor Cyan
    Write-Host ""

    # Check if secrets file exists
    $secretsFile = Join-Path $mobileAppDir "secrets.dev.json"
    if (-not (Test-Path $secretsFile)) {
        Write-Host "❌ Error: secrets.dev.json not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please create secrets.dev.json from template:" -ForegroundColor Yellow
        Write-Host "  1. Copy secrets.dev.json.template to secrets.dev.json"
        Write-Host "  2. Fill in your Desktop OAuth credentials"
        Write-Host "  3. Run this script again"
        Write-Host ""
        exit 1
    }

    # Load secrets
    Write-Host "📄 Loading secrets from: $secretsFile" -ForegroundColor Gray
    $secrets = Get-Content $secretsFile | ConvertFrom-Json

    # Validate function for OAuth providers (Gmail)
    function Validate-OAuthProvider([string]$providerName, [string]$clientId, [string]$clientSecret, [string]$redirectUri) {
        $isConfigured = $false
        $issuesFound = @()
        
        # Check if any field is provided (not empty and not placeholder)
        $hasClientId = -not ([string]::IsNullOrWhiteSpace($clientId) -or $clientId -like "YOUR-*" -or $clientId -like "REPLACE_*")
        $hasSecret = -not ([string]::IsNullOrWhiteSpace($clientSecret) -or $clientSecret -like "YOUR-*" -or $clientSecret -like "REPLACE_*")
        $hasUri = -not [string]::IsNullOrWhiteSpace($redirectUri)
        
        # If ANY field is provided, validate ALL fields
        if ($hasClientId -or $hasSecret -or $hasUri) {
            if (-not $hasClientId) {
                $issuesFound += "❌ Missing/placeholder CLIENT_ID"
            }
            if (-not $hasSecret) {
                $issuesFound += "❌ Missing/placeholder CLIENT_SECRET"
            }
            if (-not $hasUri) {
                $issuesFound += "❌ Missing REDIRECT_URI"
            }
            
            if ($issuesFound.Count -eq 0) {
                $isConfigured = $true
            }
        }
        
        if ($isConfigured) {
            Write-Host "   ✅ $providerName - configured (OAuth)" -ForegroundColor Green
            Write-Host "      Client ID: $($clientId.Substring(0, 30))..." -ForegroundColor Gray
        } elseif ($issuesFound.Count -gt 0) {
            Write-Host "   ⚠️  $providerName - INCOMPLETE (skipping)" -ForegroundColor Yellow
            foreach ($issue in $issuesFound) { Write-Host "      $issue" -ForegroundColor Gray }
        } else {
            Write-Host "   ⏭️  $providerName - not configured (optional)" -ForegroundColor Gray
        }
        
        return $isConfigured
    }

    # Validate function for IMAP providers (AOL)
    function Validate-IMAPProvider([string]$providerName, [string]$email, [string]$appPassword) {
        $isConfigured = $false
        $issuesFound = @()
        
        # Check if any field is provided (not empty and not placeholder)
        $hasEmail = -not ([string]::IsNullOrWhiteSpace($email) -or $email -like "YOUR-*" -or $email -like "your-*")
        $hasPassword = -not ([string]::IsNullOrWhiteSpace($appPassword) -or $appPassword -like "YOUR-*" -or $appPassword -like "your-*")
        
        # If ANY field is provided, validate ALL fields
        if ($hasEmail -or $hasPassword) {
            if (-not $hasEmail) {
                $issuesFound += "❌ Missing/placeholder EMAIL"
            }
            if (-not $hasPassword) {
                $issuesFound += "❌ Missing/placeholder APP_PASSWORD"
            }
            
            if ($issuesFound.Count -eq 0) {
                $isConfigured = $true
            }
        }
        
        if ($isConfigured) {
            Write-Host "   ✅ $providerName - configured (IMAP)" -ForegroundColor Green
            Write-Host "      Email: $email" -ForegroundColor Gray
        } elseif ($issuesFound.Count -gt 0) {
            Write-Host "   ⚠️  $providerName - INCOMPLETE (skipping)" -ForegroundColor Yellow
            foreach ($issue in $issuesFound) { Write-Host "      $issue" -ForegroundColor Gray }
        } else {
            Write-Host "   ⏭️  $providerName - not configured (optional)" -ForegroundColor Gray
        }
        
        return $isConfigured
    }

    # Validate all providers
    Write-Host "🔐 Validating credentials for all providers..." -ForegroundColor Cyan
    $gmailValid = Validate-OAuthProvider "Gmail" `
        $secrets.GMAIL_DESKTOP_CLIENT_ID `
        $secrets.GMAIL_OAUTH_CLIENT_SECRET `
        $secrets.GMAIL_REDIRECT_URI
    
    $aolValid = Validate-IMAPProvider "AOL" `
        $secrets.AOL_EMAIL `
        $secrets.AOL_APP_PASSWORD
    
    Write-Host ""
    
    # Require at least one provider to be configured
    $configuredCount = @($gmailValid, $aolValid) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    if ($configuredCount -eq 0) {
        Write-Host "❌ Error: At least one provider must be configured" -ForegroundColor Red
        Write-Host ""
        Write-Host "To fix this:" -ForegroundColor Yellow
        Write-Host "  1. Edit secrets.dev.json" -ForegroundColor Gray
        Write-Host "  2. Configure at least Gmail or AOL with real OAuth credentials" -ForegroundColor Gray
        Write-Host "  3. Run this script again" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "✅ Build will include $(if ($gmailValid) { 'Gmail ' })$(if ($aolValid) { 'AOL ' })provider(s)" -ForegroundColor Green
    Write-Host ""

    # Ensure no background processes are locking build outputs
    function Stop-LockingProcesses {
        Write-Host "🛑 Stopping background build processes (Gradle/ADB)" -ForegroundColor Cyan
        Push-Location (Join-Path $mobileAppDir 'android')
        try { ./gradlew.bat --stop | Out-Null } catch {}
        Pop-Location
        try { adb kill-server | Out-Null } catch {}
    }

    function Remove-DirWithRetry([string]$path, [int]$retries = 5) {
        if (-not (Test-Path $path)) { return }
        for ($i = 1; $i -le $retries; $i++) {
            try {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
                return
            } catch {
                Start-Sleep -Milliseconds (300 * $i)
                if ($i -eq $retries) { throw }
            }
        }
    }

    Stop-LockingProcesses

    # Clean build (always attempt)
    Write-Host "🧹 Running flutter clean..." -ForegroundColor Cyan
    try {
        flutter clean | Out-Null
    } catch {
        Write-Host "⚠️  flutter clean reported a lock; performing manual cleanup" -ForegroundColor Yellow
    }

    # Always perform safe manual cleanup to avoid Windows locks
    Write-Host "🧽 Removing build artifacts manually (safe)" -ForegroundColor Cyan
    $pathsToRemove = @(
        (Join-Path $mobileAppDir 'build'),
        (Join-Path $mobileAppDir '.dart_tool'),
        (Join-Path $mobileAppDir 'android\app\build'),
        (Join-Path $mobileAppDir 'android\.gradle'),
        (Join-Path $mobileAppDir '.gradle')
    )
    foreach ($p in $pathsToRemove) { Remove-DirWithRetry $p }

    # Build with dart-defines for configured providers
    Write-Host "🔨 Building APK ($BuildType) with configured provider credentials..." -ForegroundColor Cyan
    
    # Build dart-defines only for configured providers
    $dartDefines = @()
    if ($gmailValid) {
        Write-Host "   🔵 Including Gmail (OAuth)" -ForegroundColor Cyan
        $dartDefines += "--dart-define=GMAIL_DESKTOP_CLIENT_ID=$($secrets.GMAIL_DESKTOP_CLIENT_ID)"
        $dartDefines += "--dart-define=GMAIL_OAUTH_CLIENT_SECRET=$($secrets.GMAIL_OAUTH_CLIENT_SECRET)"
        $dartDefines += "--dart-define=GMAIL_REDIRECT_URI=$($secrets.GMAIL_REDIRECT_URI)"
    }
    if ($aolValid) {
        Write-Host "   🟠 Including AOL (IMAP)" -ForegroundColor Cyan
        $dartDefines += "--dart-define=AOL_EMAIL=$($secrets.AOL_EMAIL)"
        $dartDefines += "--dart-define=AOL_APP_PASSWORD=$($secrets.AOL_APP_PASSWORD)"
    }
    
    # Prefer newer flag to load all dart-defines from a file for reliability
    $supportsFromFile = $true
    try {
        flutter --version | Out-Null
    } catch {
        $supportsFromFile = $false
    }

    if ($supportsFromFile) {
        Write-Host "🔧 Using --dart-define-from-file=secrets.dev.json" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build apk --release --dart-define-from-file=secrets.dev.json
        } else {
            flutter build apk --debug --dart-define-from-file=secrets.dev.json
        }
    } else {
        Write-Host "🔧 Using explicit --dart-define flags" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build apk --release $dartDefines
        } else {
            flutter build apk --debug $dartDefines
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    
    $apkPath = if ($BuildType -eq 'release') {
        "build\app\outputs\flutter-apk\app-release.apk"
    } else {
        "build\app\outputs\flutter-apk\app-debug.apk"
    }
    
    Write-Host "📦 APK location: $apkPath" -ForegroundColor Gray
    Write-Host ""

    # Install to emulator if requested
    if ($InstallToEmulator) {
        Write-Host ""
        Write-Host "[APK Install] Starting emulator detection and installation..." -ForegroundColor Cyan
        
        # Step 1: Check for running emulator
        Write-Host "[Step 1/4] Checking for running emulator..." -ForegroundColor Cyan
        $emulatorReady = $false
        $adbRestartCount = 0
        
        while (-not $emulatorReady -and $adbRestartCount -lt 3) {
            $adbOutput = adb devices 2>&1
            $adbLines = $adbOutput -split "`n"
            
            foreach ($line in $adbLines) {
                $line = $line.Trim()
                if ($line.Length -eq 0) { continue }
                if ($line.Contains("emulator-") -and -not $line.Contains("offline")) {
                    $emulatorReady = $true
                    Write-Host "  [OK] Found running emulator: $line" -ForegroundColor Green
                    break
                }
            }
            
            if (-not $emulatorReady) {
                if ($adbRestartCount -lt 3) {
                    Write-Host "  [INFO] No emulator detected; restarting adb (attempt $($adbRestartCount+1))..." -ForegroundColor Yellow
                    adb kill-server | Out-Null
                    Start-Sleep -Seconds 2
                    adb start-server | Out-Null
                    Start-Sleep -Seconds 2
                    $adbRestartCount += 1
                }
            }
        }
        
        # Step 2: If no running emulator, try to find and start one
        if (-not $emulatorReady) {
            Write-Host "[Step 2/4] No running emulator; checking for available AVDs..." -ForegroundColor Cyan
            
            $avdList = @()
            try {
                $emulatorOutput = emulator -list-avds 2>&1 | Out-String
                foreach ($line in $emulatorOutput -split "`n") {
                    $avdName = $line.Trim()
                    if ($avdName.Length -gt 0) {
                        $avdList += $avdName
                    }
                }
            } catch {
                Write-Host "  [WARNING] Could not query emulator -list-avds" -ForegroundColor Yellow
            }
            
            if ($avdList.Count -eq 0) {
                Write-Host ""
                Write-Host "[ERROR] No AVD emulators available." -ForegroundColor Red
                Write-Host "  To create one, run:" -ForegroundColor Yellow
                Write-Host "    avdmanager create avd -n MyEmulator -k system-images;android-31;default;x86_64" -ForegroundColor Gray
                exit 1
            }
            
            # Prioritize known working AVD
            $preferredAvd = "pixel34_updated"
            if ($avdList -contains $preferredAvd) {
                $avdList = @($preferredAvd) + ($avdList | Where-Object { $_ -ne $preferredAvd })
            }
            
            Write-Host "  [OK] Found $($avdList.Count) AVD(s): $($avdList -join ', ')" -ForegroundColor Green
            
            # Try to start each AVD until one boots
            $emulatorStarted = $false
            foreach ($avdName in $avdList) {
                Write-Host ""
                Write-Host "[Step 3/4] Starting AVD: $avdName (this may take 30-90 seconds)..." -ForegroundColor Cyan
                
                # Find emulator executable
                $androidSdk = $Env:ANDROID_SDK_ROOT
                if (-not $androidSdk) { $androidSdk = $Env:ANDROID_HOME }
                
                if ($androidSdk) {
                    $emulatorPath = Join-Path $androidSdk "emulator" "emulator.exe"
                    if (Test-Path $emulatorPath) {
                        Write-Host "  [INFO] Starting via SDK: $emulatorPath -avd $avdName" -ForegroundColor Gray
                        try {
                            Start-Process -FilePath $emulatorPath -ArgumentList @("-avd", $avdName, "-netdelay", "none", "-netspeed", "full", "-no-snapshot", "-gpu", "angle") -NoNewWindow -PassThru | Out-Null
                        } catch {
                            Write-Host "  [ERROR] Failed to start emulator: $_" -ForegroundColor Red
                            continue
                        }
                    } else {
                        Write-Host "  [WARNING] Emulator exe not found at $emulatorPath" -ForegroundColor Yellow
                        continue
                    }
                } else {
                    Write-Host "  [WARNING] ANDROID_SDK_ROOT and ANDROID_HOME not set" -ForegroundColor Yellow
                    continue
                }
                
                # Wait for emulator to boot
                Write-Host "  [INFO] Waiting for boot (up to 120 seconds)..." -ForegroundColor Gray
                $bootWait = 0
                $maxBootWait = 120
                
                while ($bootWait -lt $maxBootWait) {
                    Start-Sleep -Seconds 3
                    $bootWait += 3
                    
                    $deviceOutput = adb devices 2>&1
                    foreach ($devLine in $deviceOutput -split "`n") {
                        $devLine = $devLine.Trim()
                        if ($devLine.Contains("emulator-") -and -not $devLine.Contains("offline")) {
                            $emulatorStarted = $true
                            Write-Host "  [OK] Emulator ready: $devLine" -ForegroundColor Green
                            break
                        }
                    }
                    
                    if ($emulatorStarted) { break }
                }
                
                if ($emulatorStarted) { break }
                else { Write-Host "  [WARNING] AVD boot timeout; trying next AVD..." -ForegroundColor Yellow }
            }
            
            if (-not $emulatorStarted) {
                Write-Host ""
                Write-Host "[ERROR] Failed to start any emulator." -ForegroundColor Red
                Write-Host "  Try starting manually, then install:" -ForegroundColor Yellow
                Write-Host "    adb install -r $apkPath" -ForegroundColor Gray
                exit 1
            }
            
            $emulatorReady = $true
        }
        
        # Step 3: Install APK
        Write-Host ""
        Write-Host "[Step 3/4] Installing APK..." -ForegroundColor Cyan
        $installOutput = adb install -r $apkPath 2>&1 | Out-String
        
        if ($LASTEXITCODE -eq 0 -and $installOutput.Contains("Success")) {
            Write-Host "  [OK] APK installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] APK installation failed" -ForegroundColor Red
            Write-Host "  Output: $installOutput" -ForegroundColor Yellow
            exit 1
        }
        
        # Step 4: Launch app
        Write-Host ""
        Write-Host "[Step 4/4] Launching app..." -ForegroundColor Cyan
        adb shell am start -n com.example.spamfilter_mobile/.MainActivity 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] App launched" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] App launch command may not have succeeded" -ForegroundColor Yellow
            Write-Host "  Launch manually with: adb shell am start -n com.example.spamfilter_mobile/.MainActivity" -ForegroundColor Gray
        }
        
    } else {
        Write-Host ""
        Write-Host "[INFO] APK built but not installed (use -InstallToEmulator to install):" -ForegroundColor Gray
        Write-Host "  adb install -r $apkPath" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "🎉 Done!" -ForegroundColor Green

} finally {
    Pop-Location
}
