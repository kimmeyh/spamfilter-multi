
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

    # F94 (Sprint 63): dev/prod flavor selection, passed as --flavor AND
    # --dart-define=APP_ENV in lockstep (mirrors build-windows.ps1
    # -Environment). DEFAULT 'prod' PRESERVES the pre-F94 daily behavior:
    # the registered package com.myemailspamfilter with working Google
    # Sign-In. 'dev' builds the .dev-suffixed package (side-by-side install,
    # isolated data dir, [DEV] launcher label) against a committed STUB
    # google-services config -- dev-flavor sign-in activates when the F94
    # console registrations land; flip this default to 'dev' then.
    [ValidateSet('dev', 'prod')]
    [string]$Env = 'prod',

    # GP-2 (Sprint 64, ADR-0027 Option B): signing parameters for RELEASE
    # builds live in a JSON file OUTSIDE the repository (keys: keystorePath,
    # keystorePassword, keyAlias, keyPassword). Never committed, never inside
    # the repo tree. Debug builds ignore this entirely.
    [string]$SigningConfigPath = "$env:USERPROFILE\.myemailspamfilter\android-signing.json",

    # GP-2: 'apk' for local testing/emulator installs (default, unchanged
    # behavior); 'aab' for the Play Store upload bundle (release only).
    [ValidateSet('apk', 'aab')]
    [string]$Output = 'apk',
    
    [switch]$InstallToEmulator,
    
    [switch]$Run,
    
    [switch]$SkipUninstall,
    
    [switch]$StartEmulator,
    
    [string]$EmulatorName = ""
)

$ErrorActionPreference = 'Stop'

# Reject flag combinations that cannot work, BEFORE any long build runs.
# Both were found by the Sprint 64 Phase 5.1.1 review of the release chain.
#
# 1. -Run takes an early-exit path that sits ABOVE the GP-2 signing, SEC-9
#    client-id, and GP-9 obfuscation blocks, so a release build started that
#    way reaches gradle with none of them injected. The release guards then
#    fire "missing signing parameters" and "missing client id" at a user who
#    did nothing wrong, and the natural workaround (exporting the values by
#    hand) yields an UNOBFUSCATED build that silently violates GP-9. Use
#    -InstallToEmulator for release: it runs the full injected path.
if ($Run -and $BuildType -eq 'release') {
    Write-Host "[ERROR] -Run does not support -BuildType release: it bypasses signing, client-id, and obfuscation injection." -ForegroundColor Red
    Write-Host "        Use: -BuildType release -InstallToEmulator" -ForegroundColor Yellow
    exit 1
}

# 2. adb cannot install an .aab. -Output aab reassigns the artifact path that
#    -InstallToEmulator later hands to `adb install`, so the pair fails with
#    INSTALL_PARSE_FAILED_NOT_APK only AFTER a full release build -- which
#    reads like a signing fault and sends debugging at the wrong thing.
if ($Output -eq 'aab' -and $InstallToEmulator) {
    Write-Host "[ERROR] -Output aab cannot be installed with -InstallToEmulator (adb cannot install a bundle)." -ForegroundColor Red
    Write-Host "        Build an APK for on-device testing, or use bundletool to install the AAB." -ForegroundColor Yellow
    exit 1
}

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
    # F94: ensure the dev flavor's google-services stub is in place (the real
    # per-flavor file is gitignored and does not exist until the console
    # registrations land; the committed stub lets the dev flavor build).
    $devGsDir  = Join-Path $mobileAppDir 'android\app\src\dev'
    $devGsFile = Join-Path $devGsDir 'google-services.json'
    $devGsStub = Join-Path $mobileAppDir 'android\ci\google-services.dev-stub.json'
    if (-not (Test-Path $devGsFile) -and (Test-Path $devGsStub)) {
        New-Item -ItemType Directory -Force $devGsDir | Out-Null
        Copy-Item $devGsStub $devGsFile
        Write-Host "[INFO] F94: dev-flavor google-services STUB installed (sign-in on dev flavor pending console registrations)" -ForegroundColor Yellow
    }

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
                flutter run --release --flavor $Env --dart-define=APP_ENV=$Env --dart-define-from-file=secrets.dev.json -d $deviceId
            } else {
                flutter run --debug --flavor $Env --dart-define=APP_ENV=$Env --dart-define-from-file=secrets.dev.json -d $deviceId
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
        if ($secrets.ANDROID_GMAIL_CLIENT_ID) {
            $dartDefines += "--dart-define=ANDROID_GMAIL_CLIENT_ID=$($secrets.ANDROID_GMAIL_CLIENT_ID)"
        }
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


    $flavorArgs = @('--flavor', $Env, "--dart-define=APP_ENV=$Env")
    Write-Host "[INFO] F94: building flavor '$Env' with APP_ENV=$Env" -ForegroundColor Cyan

    # SEC-9 (Sprint 64): pass ANDROID_GMAIL_CLIENT_ID to the gradle side too,
    # via -P (--android-project-arg), so build.gradle.kts's manifest
    # placeholder reads the SAME value the Dart side gets from
    # --dart-define-from-file. Both sides source from the single
    # ANDROID_GMAIL_CLIENT_ID key in secrets.dev.json -- single source of
    # truth. Missing from secrets.dev.json -> gradle's own loud-fail (release)
    # or warning (debug) fires; this script does not duplicate that check.
    $gradleProjectArgs = @()
    if ($secrets.ANDROID_GMAIL_CLIENT_ID) {
        $gradleProjectArgs += "-PandroidGmailClientId=$($secrets.ANDROID_GMAIL_CLIENT_ID)"
    } else {
        Write-Host "[WARNING] ANDROID_GMAIL_CLIENT_ID not set in secrets.dev.json -- gradle will warn (debug) or fail (release)." -ForegroundColor Yellow
    }

    # GP-2 (Sprint 64, ADR-0027): RELEASE builds are signed with the upload
    # keystore via build-time -P injection. The signing JSON (and the keystore
    # it points at) live OUTSIDE the repository. Missing config on a release
    # build fails HERE with instructions; gradle's own GradleException is the
    # second net. Debug builds skip signing injection entirely.
    if ($BuildType -eq 'release') {
        if (-not (Test-Path $SigningConfigPath)) {
            Write-Host "[ERROR] GP-2: release signing config not found at $SigningConfigPath" -ForegroundColor Red
            Write-Host "        Create it (JSON keys: keystorePath, keystorePassword, keyAlias, keyPassword)" -ForegroundColor Red
            Write-Host "        pointing at the upload keystore (docs/adr/0027 + SPRINT_64_PLAN.md Task 6)." -ForegroundColor Red
            exit 1
        }
        $signing = Get-Content $SigningConfigPath -Raw | ConvertFrom-Json
        foreach ($k in @('keystorePath', 'keystorePassword', 'keyAlias', 'keyPassword')) {
            if (-not $signing.$k) {
                Write-Host "[ERROR] GP-2: signing config $SigningConfigPath is missing key '$k'." -ForegroundColor Red
                exit 1
            }
        }
        if (-not (Test-Path $signing.keystorePath)) {
            Write-Host "[ERROR] GP-2: keystore not found at $($signing.keystorePath)." -ForegroundColor Red
            exit 1
        }
        # ENVIRONMENT VARIABLES, not -P args, deliberately: flutter is a .bat
        # shim on Windows and cmd.exe treats &, ?, and friends in argument
        # values as metacharacters -- a password containing & silently ATE the
        # rest of the argument list on first live use (2026-08-28). Env vars
        # cross the shim byte-clean, gradle already reads them as the
        # documented fallback (ANDROID_* in build.gradle.kts), and secrets
        # stay out of process command lines. Cleared in this script's finally.
        $env:ANDROID_KEYSTORE_PATH = $signing.keystorePath
        $env:ANDROID_KEYSTORE_PASSWORD = $signing.keystorePassword
        $env:ANDROID_KEY_ALIAS = $signing.keyAlias
        $env:ANDROID_KEY_PASSWORD = $signing.keyPassword
        Write-Host "[INFO] GP-2: release signing injected via environment from $SigningConfigPath (keystore: $($signing.keystorePath))" -ForegroundColor Cyan
    }

    # GP-2 (ADR-0027): AAB is the Play Store upload format; APK stays the
    # local-testing format. -Output aab requires -BuildType release (Play
    # accepts release bundles only).
    if ($Output -eq 'aab' -and $BuildType -ne 'release') {
        Write-Host "[ERROR] GP-2: -Output aab requires -BuildType release." -ForegroundColor Red
        exit 1
    }
    $buildTarget = if ($Output -eq 'aab') { 'appbundle' } else { 'apk' }

    # GP-9 (Sprint 64): Dart-side obfuscation for RELEASE builds only (R-3:
    # debug builds are completely unchanged -- no obfuscate args added to the
    # debug branches below). Symbol files are retained OUTSIDE the repository
    # so obfuscated stack traces stay readable at crash-triage time without
    # ever committing them; the version comes from pubspec.yaml so each
    # release's symbols land in their own directory.
    $obfuscateArgs = @()
    $symbolsDir = $null
    if ($BuildType -eq 'release') {
        $pubspecPath = Join-Path $mobileAppDir 'pubspec.yaml'
        $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(\S+)' | Select-Object -First 1
        $pubspecVersion = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value } else { 'unknown-version' }
        $symbolsDir = Join-Path "$env:USERPROFILE\.myemailspamfilter\symbols" "$pubspecVersion-$Env"
        if (-not (Test-Path $symbolsDir)) {
            New-Item -ItemType Directory -Force -Path $symbolsDir | Out-Null
        }
        $obfuscateArgs = @('--obfuscate', "--split-debug-info=$symbolsDir")
        Write-Host "[INFO] GP-9: Dart obfuscation enabled; symbols will be written to $symbolsDir" -ForegroundColor Cyan
    }

    if ($supportsFromFile) {
        Write-Host "[INFO] Using --dart-define-from-file=secrets.dev.json" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build $buildTarget --release @flavorArgs --dart-define-from-file=secrets.dev.json @gradleProjectArgs @obfuscateArgs
        } else {
            flutter build $buildTarget --debug @flavorArgs --dart-define-from-file=secrets.dev.json @gradleProjectArgs
        }
    } else {
        Write-Host "[INFO] Using explicit --dart-define flags" -ForegroundColor Cyan
        if ($BuildType -eq 'release') {
            flutter build $buildTarget --release @flavorArgs $dartDefines @gradleProjectArgs @obfuscateArgs
        } else {
            flutter build $buildTarget --debug @flavorArgs $dartDefines @gradleProjectArgs
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "[INFO] Build successful!" -ForegroundColor Green

    # GP-9: print the symbol-file path for this release so crash triage knows
    # where to find them (they are never committed to the repo).
    if ($BuildType -eq 'release' -and $symbolsDir) {
        Write-Host "[INFO] GP-9: Dart obfuscation symbols written to $symbolsDir" -ForegroundColor Cyan
    }

    # F94: flavored builds ALWAYS emit app-<flavor>-<buildtype>.apk (no
    # un-flavored fallback -- with productFlavors defined it could only ever
    # pick up a stale pre-flavor artifact and install the wrong APK).
    $apkPath = "build\app\outputs\flutter-apk\app-$Env-$BuildType.apk"
    if ($Output -eq 'aab') {
        $apkPath = "build\app\outputs\bundle\${Env}Release\app-$Env-release.aab"
    }

    Write-Host "[INFO] Artifact location: $apkPath" -ForegroundColor Gray
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
            # F94: uninstall the CURRENT flavor's package; the two legacy
            # pre-rename names are kept as harmless cleanup no-ops.
            $pkg = if ($Env -eq 'dev') { 'com.myemailspamfilter.dev' } else { 'com.myemailspamfilter' }
            & adb uninstall $pkg | Out-Null
            & adb uninstall com.example.spamfiltermobile | Out-Null
            & adb uninstall com.example.spamfilter_mobile | Out-Null
        } else {
            Write-Host "[Step 4/6] Skipping uninstall (debug build - preserving saved accounts)..." -ForegroundColor Cyan
        }

        # Step 5: Install APK with retries
        #
        # Sprint 60 storage pre-flight (Harold's maintenance question): an
        # `install -r` upgrade briefly needs room for TWO copies of the APK,
        # and the AVD's /data sits chronically ~85% full -- the transient
        # squeeze produced INSTALL_FAILED_INSUFFICIENT_STORAGE failures that
        # pushed deploys into uninstall cycles (which WIPE saved accounts:
        # secure-storage keys die with the keystore on uninstall and cannot
        # be backed up). Automated here at the point of failure rather than
        # as a process/checklist step, so it maintains itself: if free space
        # is under 2x the APK size + 200MB, trim system caches first.
        $apkSizeMB = [math]::Ceiling((Get-Item $apkPath).Length / 1MB)
        $neededMB = (2 * $apkSizeMB) + 200
        $dfOut = & adb shell df -m /data 2>$null | Select-Object -Last 1
        if ($dfOut -match '\s(\d+)\s+\d+%') {
            $freeMB = [int]$Matches[1]
            if ($freeMB -lt $neededMB) {
                Write-Host "[Step 5/6] Low emulator storage (${freeMB}MB free, want ${neededMB}MB) -- trimming caches..." -ForegroundColor Yellow
                & adb shell pm trim-caches 2000M 2>$null | Out-Null
            }
        }
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
        # F94 R-5: the pre-rename package here silently no-opped since the
        # applicationId rename; launch the CURRENT flavor's package.
        $launchPkg = if ($Env -eq 'dev') { 'com.myemailspamfilter.dev' } else { 'com.myemailspamfilter' }
        # NOTE: applicationIdSuffix changes the PACKAGE, not the activity
        # class namespace -- the component is always <pkg>/com.myemailspamfilter.MainActivity.
        adb shell am start -n "$launchPkg/com.myemailspamfilter.MainActivity" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] App launched successfully ($launchPkg)" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] App launch command may not have succeeded" -ForegroundColor Yellow
            Write-Host "  Launch manually with: adb shell am start -n $launchPkg/com.myemailspamfilter.MainActivity" -ForegroundColor Gray
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
} finally {
    # GP-2: signing material never outlives the build invocation.
    Remove-Item Env:ANDROID_KEYSTORE_PATH, Env:ANDROID_KEYSTORE_PASSWORD, Env:ANDROID_KEY_ALIAS, Env:ANDROID_KEY_PASSWORD -ErrorAction SilentlyContinue
} # Close main try/catch/finally block

# End of script
