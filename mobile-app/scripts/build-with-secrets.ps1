
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
    If set, install the APK to running emulator after build and launch the app

.PARAMETER Run
    If set, use 'flutter run' instead of build+install. This attaches the
    debugger with hot reload (r/R) and real-time logs. Best for debugging.

.PARAMETER SkipUninstall
    If set, skip the uninstall step before installing. Preserves saved accounts
    and app data. Use this for iterative development. May cause version downgrade
    errors if switching between branches with different version codes.

.PARAMETER StartEmulator
    If set, automatically start an emulator if none is running. Detects available
    AVDs and launches the first one found. If a specific emulator is already running,
    uses that instead.

.PARAMETER EmulatorName
    Specify which emulator to launch (optional). If not provided, uses the first
    available AVD from 'emulator -list-avds'. Ignored if an emulator is already running.

.EXAMPLE
    .\build-with-secrets.ps1
    .\build-with-secrets.ps1 -BuildType debug
    .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
    .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -SkipUninstall
    .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator
    .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator -EmulatorName "Pixel_5_API_33"
    .\build-with-secrets.ps1 -BuildType debug -Run
    .\build-with-secrets.ps1 -BuildType release -InstallToEmulator  # Clean install
#>

param(
    [ValidateSet('debug', 'release')]
    [string]$BuildType = 'release',
    
    [switch]$InstallToEmulator,
    
    [switch]$Run,
    
    [switch]$SkipUninstall,
    
    [switch]$StartEmulator,
    
    [string]$EmulatorName = ""
)

$ErrorActionPreference = 'Stop'

# Navigate to mobile-app directory
$mobileAppDir = Split-Path -Parent $PSScriptRoot
Push-Location $mobileAppDir

try {
    Write-Host "[INFO] Building Flutter APK with OAuth secrets..." -ForegroundColor Cyan
    Write-Host ""

    # Check if secrets file exists
    $secretsFile = Join-Path $mobileAppDir "secrets.dev.json"
    if (-not (Test-Path $secretsFile)) {
        Write-Host "[ERROR]: secrets.dev.json not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please create secrets.dev.json from template:" -ForegroundColor Yellow
        Write-Host "  1. Copy secrets.dev.json.template to secrets.dev.json"
        Write-Host "  2. Fill in your Desktop OAuth credentials"
        Write-Host "  3. Run this script again"
        Write-Host ""
        exit 1
    }

    # Load secrets
    Write-Host "[INFO] Loading secrets from: $secretsFile" -ForegroundColor Gray
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
                $issuesFound += "[ERROR] Missing/placeholder CLIENT_ID"
            }
            if (-not $hasSecret) {
                $issuesFound += "[ERROR] Missing/placeholder CLIENT_SECRET"
            }
            if (-not $hasUri) {
                $issuesFound += "[ERROR] Missing REDIRECT_URI"
            }
            if ($issuesFound.Count -eq 0) {
                $isConfigured = $true
            }
        }
        if ($isConfigured) {
            Write-Host "   [OK] $providerName - configured (OAuth)" -ForegroundColor Green
            Write-Host ("      Client ID: {0}..." -f $clientId.Substring(0, [Math]::Min(30, $clientId.Length))) -ForegroundColor Gray
        } elseif ($issuesFound.Count -gt 0) {
            Write-Host "   [WARNING]  $providerName - INCOMPLETE (skipping)" -ForegroundColor Yellow
            foreach ($issue in $issuesFound) { Write-Host "      $issue" -ForegroundColor Gray }
        } else {
            Write-Host "   [WARNING]  $providerName - not configured (optional)" -ForegroundColor Gray
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
                $issuesFound += "[ERROR] Missing/placeholder EMAIL"
            }
            if (-not $hasPassword) {
                $issuesFound += "[ERROR] Missing/placeholder APP_PASSWORD"
            }
            if ($issuesFound.Count -eq 0) {
                $isConfigured = $true
            }
        }
        if ($isConfigured) {
            Write-Host "   [OK] $providerName - configured (IMAP)" -ForegroundColor Green
            Write-Host "      Email: $email" -ForegroundColor Gray
        } elseif ($issuesFound.Count -gt 0) {
            Write-Host "   [WARNING]  $providerName - INCOMPLETE (skipping)" -ForegroundColor Yellow
            foreach ($issue in $issuesFound) { Write-Host "      $issue" -ForegroundColor Gray }
        } else {
            Write-Host "   [WARNING]  $providerName - not configured (optional)" -ForegroundColor Gray
        }
        
        return $isConfigured
    }

    # Validate all providers - support multiple field name variants
    Write-Host "[INFO] Validating credentials for all providers..." -ForegroundColor Cyan
    
    # Gmail: Use Android-specific credentials for Android builds, fall back to Windows/Generic
    $gmailClientId = if ($secrets.ANDROID_GMAIL_CLIENT_ID) { 
        $secrets.ANDROID_GMAIL_CLIENT_ID 
    } elseif ($secrets.WINDOWS_GMAIL_DESKTOP_CLIENT_ID) { 
        $secrets.WINDOWS_GMAIL_DESKTOP_CLIENT_ID 
    } elseif ($secrets.GMAIL_DESKTOP_CLIENT_ID) { 
        $secrets.GMAIL_DESKTOP_CLIENT_ID 
    } else { $null }
    
    $gmailClientSecret = if ($secrets.WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET) { 
        $secrets.WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET 
    } elseif ($secrets.GMAIL_OAUTH_CLIENT_SECRET) { 
        $secrets.GMAIL_OAUTH_CLIENT_SECRET 
    } else { $null }
    
    $gmailRedirectUri = if ($secrets.ANDROID_REDIRECT_URI) { 
        $secrets.ANDROID_REDIRECT_URI 
    } elseif ($secrets.GMAIL_REDIRECT_URI) { 
        $secrets.GMAIL_REDIRECT_URI 
    } else { $null }
    
    $gmailValid = Validate-OAuthProvider "Gmail" `
        $gmailClientId `
        $gmailClientSecret `
        $gmailRedirectUri
    
    $aolValid = Validate-IMAPProvider "AOL" `
        $secrets.AOL_EMAIL `
        $secrets.AOL_APP_PASSWORD
    
    Write-Host ""
    
    # Require at least one provider to be configured
    $configuredCount = @($gmailValid, $aolValid) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    if ($configuredCount -eq 0) {
        Write-Host "[ERROR]: At least one provider must be configured" -ForegroundColor Red
        Write-Host ""
        Write-Host "To fix this:" -ForegroundColor Yellow
        Write-Host "  1. Edit secrets.dev.json" -ForegroundColor Gray
        Write-Host "  2. Configure at least Gmail or AOL with real OAuth credentials" -ForegroundColor Gray
        Write-Host "  3. Run this script again" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "[INFO] Build will include $(if ($gmailValid) { 'Gmail ' })$(if ($aolValid) { 'AOL ' })provider(s)" -ForegroundColor Green
    Write-Host ""

    # If -Run flag is set, use flutter run instead of build+install
    if ($Run) {
        Write-Host "[INFO] Running app with debugger attached (hot reload enabled)..." -ForegroundColor Cyan
        Write-Host "   Press 'r' for hot reload, 'R' for hot restart, 'q' to quit" -ForegroundColor Gray
        Write-Host ""
        
        # Find emulator device
        $deviceId = $null
        $adbOutput = adb devices 2>&1
        foreach ($line in $adbOutput -split "`n") {
            $line = $line.Trim()
            if ($line.Contains("emulator-") -and -not $line.Contains("offline")) {
                $deviceId = ($line -split "\s+")[0]
                break
            }
        }
        
        if (-not $deviceId) {
            Write-Host "[WARNING]  No emulator detected. Launching one..." -ForegroundColor Yellow
            flutter emulators --launch pixel34_updated 2>&1 | Out-Null
            Write-Host "   Waiting for emulator to boot (30 seconds)..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
            
            $adbOutput = adb devices 2>&1
            foreach ($line in $adbOutput -split "`n") {
                $line = $line.Trim()
                if ($line.Contains("emulator-") -and -not $line.Contains("offline")) {
                    $deviceId = ($line -split "\s+")[0]
                    break
                }
            }
        }
        
        if ($deviceId) {
            Write-Host "[INFO] Running on device: $deviceId" -ForegroundColor Green
            if ($BuildType -eq 'release') {
                flutter run --release --dart-define-from-file=secrets.dev.json -d $deviceId
            } else {
                flutter run --debug --dart-define-from-file=secrets.dev.json -d $deviceId
            }
        } else {
            Write-Host "[ERROR] No emulator available. Start one manually or use -InstallToEmulator instead." -ForegroundColor Red
            exit 1
        }
        
        Write-Host ""
        Write-Host "[INFO] Done!" -ForegroundColor Green
        Pop-Location
        exit 0
    }

    # Ensure no background processes are locking build outputs
    function Stop-LockingProcesses {
        Write-Host "[INFO] Stopping background build processes (Gradle/ADB)" -ForegroundColor Cyan
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
                if ($i -eq $retries) {
                    # On final retry, warn but don't throw - some files may be locked by IDE/OS
                    Write-Host "[WARNING] Could not remove all files in '$path' - some files may be locked. Build will continue." -ForegroundColor Yellow
                    # Try one more time with SilentlyContinue to remove what we can
                    try { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue } catch {}
                    return
                }
            }
        }
    }

    Stop-LockingProcesses

    # Clean build (always attempt)
    Write-Host "[INFO] Running flutter clean..." -ForegroundColor Cyan
    try {
        flutter clean | Out-Null
    } catch {
        Write-Host "[WARNING] flutter clean reported a lock; performing manual cleanup" -ForegroundColor Yellow
    }

    # Always perform safe manual cleanup to avoid Windows locks
    Write-Host "[INFO] Removing build artifacts manually (safe)" -ForegroundColor Cyan
    $pathsToRemove = @(
        (Join-Path $mobileAppDir 'build'),
        (Join-Path $mobileAppDir '.dart_tool'),
        (Join-Path $mobileAppDir 'android\app\build'),
        (Join-Path $mobileAppDir 'android\.gradle'),
        (Join-Path $mobileAppDir '.gradle')
    )
    foreach ($p in $pathsToRemove) { Remove-DirWithRetry $p }

    # Build with dart-defines for configured providers
    Write-Host "[INFO] Building APK ($BuildType) with configured provider credentials..." -ForegroundColor Cyan
    
    # Build dart-defines only for configured providers
    $dartDefines = @()
    if ($gmailValid) {
        Write-Host "   [INFO] Including Gmail (OAuth)" -ForegroundColor Cyan
        $dartDefines += "--dart-define=GMAIL_DESKTOP_CLIENT_ID=$($secrets.GMAIL_DESKTOP_CLIENT_ID)"
        $dartDefines += "--dart-define=GMAIL_OAUTH_CLIENT_SECRET=$($secrets.GMAIL_OAUTH_CLIENT_SECRET)"
        $dartDefines += "--dart-define=GMAIL_REDIRECT_URI=$($secrets.GMAIL_REDIRECT_URI)"
    }
    if ($aolValid) {
        Write-Host "   [INFO] Including AOL (IMAP)" -ForegroundColor Cyan
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
        Write-Host "[INFO] Using --dart-define-from-file=secrets.dev.json" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build apk --release --dart-define-from-file=secrets.dev.json
        } else {
            flutter build apk --debug --dart-define-from-file=secrets.dev.json
        }
    } else {
        Write-Host "[INFO] Using explicit --dart-define flags" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build apk --release $dartDefines
        } else {
            flutter build apk --debug $dartDefines
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "[INFO] Build successful!" -ForegroundColor Green
    
    $apkPath = if ($BuildType -eq 'release') {
        "build\app\outputs\flutter-apk\app-release.apk"
    } else {
        "build\app\outputs\flutter-apk\app-debug.apk"
    }
    
    Write-Host "[INFO] APK location: $apkPath" -ForegroundColor Gray
    Write-Host ""

    # Install to emulator if requested
    if ($InstallToEmulator) {
        Write-Host ""
        Write-Host "[APK Install] Starting emulator detection and installation..." -ForegroundColor Cyan

        # Step 1: Robust ADB daemon and emulator startup
        $adbStarted = $false
        $adbTries = 0
        $maxAdbTries = 5
        while (-not $adbStarted -and $adbTries -lt $maxAdbTries) {
            Write-Host "[ADB] Checking daemon status (attempt $($adbTries+1)/$maxAdbTries)..." -ForegroundColor Cyan
            # Kill all running adb processes for a clean start
            $adbProcs = Get-Process | Where-Object { $_.ProcessName -like 'adb*' }
            if ($adbProcs) {
                Write-Host "[ADB] Killing all running adb processes..." -ForegroundColor Yellow
                $adbProcs | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {} }
                Start-Sleep -Seconds 2
            }
            $adbDevices = & adb devices 2>&1
            if ($adbDevices -match "daemon not running" -or $adbDevices -match "cannot connect") {
                Write-Host "[ADB] Daemon not running or connection refused. Restarting..." -ForegroundColor Yellow
                & adb kill-server
                Start-Sleep -Seconds 2
                & adb start-server
                Start-Sleep -Seconds 2
                $adbDevices = & adb devices 2>&1
            }
            if ($adbDevices -match "List of devices attached") {
                $adbStarted = $true
                break
            }
            $adbTries++
            Start-Sleep -Seconds 2
        }
        if (-not $adbStarted) {
            Write-Host "[ERROR]: Unable to start ADB daemon after $maxAdbTries attempts." -ForegroundColor Red
            Write-Host "[INFO]: Attempting to launch emulator and retry ADB..." -ForegroundColor Yellow
            & flutter emulators --launch pixel34_updated
            Start-Sleep -Seconds 20
            $adbDevices = & adb devices 2>&1
            if ($adbDevices -match "List of devices attached") {
                $adbStarted = $true
            } else {
                Write-Host "[FATAL]: ADB still not available after emulator launch." -ForegroundColor Red
                exit 1
            }
        }

        # Step 2: Ensure emulator is running
        $emulatorDevice = $null
        $emulatorDevice = & adb devices | Select-String "emulator-" | ForEach-Object { $_.ToString().Split("`t")[0] }
        
        if (-not $emulatorDevice) {
            if ($StartEmulator) {
                Write-Host "[Step 2/6] No emulator running, auto-starting emulator..." -ForegroundColor Cyan
                
                # Detect available AVDs
                $availableAvds = @()
                try {
                    $avdList = & emulator -list-avds 2>&1
                    $availableAvds = $avdList | Where-Object { $_ -and $_.Trim() -ne "" }
                } catch {
                    Write-Host "[WARNING]: Could not list AVDs. Make sure Android SDK emulator is in PATH." -ForegroundColor Yellow
                }
                
                # Determine which emulator to launch
                $avdToLaunch = $null
                if ($EmulatorName) {
                    # User specified a name
                    if ($availableAvds -contains $EmulatorName) {
                        $avdToLaunch = $EmulatorName
                    } else {
                        Write-Host "[WARNING]: Emulator '$EmulatorName' not found. Available AVDs:" -ForegroundColor Yellow
                        $availableAvds | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
                        if ($availableAvds.Count -gt 0) {
                            $avdToLaunch = $availableAvds[0]
                            Write-Host "[INFO]: Using first available AVD: $avdToLaunch" -ForegroundColor Cyan
                        }
                    }
                } elseif ($availableAvds.Count -gt 0) {
                    # Auto-select first available
                    $avdToLaunch = $availableAvds[0]
                    Write-Host "[INFO]: Auto-selected AVD: $avdToLaunch" -ForegroundColor Cyan
                }
                
                if ($avdToLaunch) {
                    Write-Host "[INFO]: Launching emulator '$avdToLaunch'..." -ForegroundColor Cyan
                    Start-Process -FilePath "emulator" -ArgumentList @("-avd", $avdToLaunch) -WindowStyle Minimized
                    
                    # Wait for emulator to appear in adb devices (max 60 seconds)
                    Write-Host "[INFO]: Waiting for emulator to start (this may take 30-60 seconds)..." -ForegroundColor Gray
                    for ($i = 0; $i -lt 30; $i++) {
                        Start-Sleep -Seconds 2
                        $emulatorDevice = & adb devices | Select-String "emulator-" | ForEach-Object { $_.ToString().Split("`t")[0] }
                        if ($emulatorDevice) {
                            Write-Host "  [OK] Emulator detected: $emulatorDevice" -ForegroundColor Green
                            break
                        }
                        if ($i % 5 -eq 0) {
                            Write-Host "  Still waiting... ($($i*2)s elapsed)" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "[ERROR]: No AVDs found. Create one with Android Studio (Tools → Device Manager → Create Device)" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "[ERROR]: No emulator running. Start one manually or use -StartEmulator flag." -ForegroundColor Red
                Write-Host "" -ForegroundColor Gray
                Write-Host "Available options:" -ForegroundColor Yellow
                Write-Host "  1. Start emulator manually (Android Studio → Device Manager → Run)" -ForegroundColor Gray
                Write-Host "  2. Use -StartEmulator flag to auto-start" -ForegroundColor Gray
                Write-Host "  3. Use -StartEmulator -EmulatorName 'YourAVD' to specify which one" -ForegroundColor Gray
                exit 1
            }
        } else {
            Write-Host "[Step 2/6] Using running emulator: $emulatorDevice" -ForegroundColor Green
        }
        
        if (-not $emulatorDevice) {
            Write-Host "[ERROR]: Emulator still not detected after auto-start attempt." -ForegroundColor Red
            exit 1
        }

        # Step 3: Wait for emulator to finish booting
        Write-Host "[Step 3/6] Waiting for emulator to finish booting..."
        $booted = $false
        for ($i = 0; $i -lt 20; $i++) {
            $bootStatus = & adb shell getprop sys.boot_completed
            if ($bootStatus -eq "1") {
                $booted = $true
                break
            }
            Start-Sleep -Seconds 4
        }
        if (-not $booted) {
            Write-Host "[ERROR]: Emulator did not finish booting in time." -ForegroundColor Red
            exit 1
        }

        # Step 4: Uninstall previous APKs
        # ✨ MODIFIED: Conditional uninstall based on build type and -SkipUninstall flag
        if ($SkipUninstall) {
            Write-Host "[Step 4/6] Skipping uninstall (-SkipUninstall flag - preserving saved accounts)..." -ForegroundColor Cyan
        } elseif ($BuildType -eq 'release') {
            Write-Host "[Step 4/6] Uninstalling previous APKs (release build - clean install)..."
            & adb uninstall com.example.spamfiltermobile | Out-Null
            & adb uninstall com.example.spamfilter_mobile | Out-Null
        } else {
            Write-Host "[Step 4/6] Skipping uninstall (debug build - preserving saved accounts)..." -ForegroundColor Cyan
        }

        # Step 5: Install APK with retries
        Write-Host "[Step 5/6] Installing APK to emulator..."
        $maxInstallTries = 3
        $installSuccess = $false
        for ($i = 1; $i -le $maxInstallTries; $i++) {
            $installResult = & adb install -r $apkPath
            if ($installResult -match "Success") {
                $installSuccess = $true
                break
            } else {
                Write-Host "[WARNING]: APK install failed (attempt $i/$maxInstallTries). Restarting ADB and retrying..." -ForegroundColor Yellow
                & adb kill-server
                Start-Sleep -Seconds 2
                & adb start-server
                Start-Sleep -Seconds 4
            }
        }
        if (-not $installSuccess) {
            Write-Host "[ERROR]: APK install failed after $maxInstallTries attempts." -ForegroundColor Red
            exit 1
        }
        Write-Host "[SUCCESS]: APK installed to emulator!" -ForegroundColor Green

        # Launch the app automatically
        Write-Host ""
        Write-Host "[Step 6/6] Launching app on emulator..." -ForegroundColor Cyan
        adb shell am start -n com.example.spamfilter_mobile/.MainActivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] App launched successfully" -ForegroundColor Green
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
    Write-Host "[INFO] Done!" -ForegroundColor Green


} catch {
    Write-Host "[FATAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    exit 1
} # Close main try/catch block

# End of script
