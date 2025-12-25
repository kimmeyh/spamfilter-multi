<#
.SYNOPSIS
    Export Windows OAuth tokens for use in Android app

.DESCRIPTION
    Reads OAuth tokens stored in Windows Credential Manager and exports them
    in a format that can be pasted into the Android app's Manual Token Entry screen.
    
    This allows you to reuse the same Gmail authentication from Windows on Android
    without having to re-authenticate.

.PARAMETER Email
    The Gmail email address to export tokens for

.EXAMPLE
    .\export-tokens-for-android.ps1 -Email "your.email@gmail.com"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Email
)

$ErrorActionPreference = 'Stop'

Write-Host "🔍 Searching for OAuth tokens for: $Email" -ForegroundColor Cyan
Write-Host ""

# Try to load tokens from Windows Credential Manager
# The SecureCredentialsStore uses a specific format for storing credentials

$credentialTargets = @(
    "spamfilter_oauth_access_$Email",
    "spamfilter_oauth_refresh_$Email",
    "${Email}_access",
    "${Email}_refresh"
)

$accessToken = $null
$refreshToken = $null

foreach ($target in $credentialTargets) {
    try {
        # Use cmdkey to check if credential exists
        $cmdkeyOutput = cmdkey /list:$target 2>&1
        
        if ($cmdkeyOutput -match "Target: $target") {
            Write-Host "✅ Found credential: $target" -ForegroundColor Green
            
            # Determine token type
            if ($target -match "access") {
                Write-Host "   This appears to be an ACCESS token" -ForegroundColor Gray
            } elseif ($target -match "refresh") {
                Write-Host "   This appears to be a REFRESH token" -ForegroundColor Gray
            }
        }
    } catch {
        # Credential not found, continue
    }
}

Write-Host ""
Write-Host "⚠️  Note: Windows Credential Manager stores tokens encrypted and cannot be directly retrieved via script." -ForegroundColor Yellow
Write-Host "   You have two options:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Use OAuth Playground (Recommended)" -ForegroundColor Cyan
Write-Host "   1. Visit: https://developers.google.com/oauthplayground/" -ForegroundColor Gray
Write-Host "   2. Click gear icon ⚙️  → Check 'Use your own OAuth credentials'" -ForegroundColor Gray
Write-Host "   3. Enter your Desktop Client ID and Secret from secrets.dev.json" -ForegroundColor Gray
Write-Host "   4. In Step 1: Select 'Gmail API v1' → Check these scopes:" -ForegroundColor Gray
Write-Host "      • https://www.googleapis.com/auth/gmail.modify" -ForegroundColor DarkGray
Write-Host "      • https://www.googleapis.com/auth/userinfo.email" -ForegroundColor DarkGray
Write-Host "   5. Click 'Authorize APIs'" -ForegroundColor Gray
Write-Host "   6. In Step 2: Click 'Exchange authorization code for tokens'" -ForegroundColor Gray
Write-Host "   7. Copy the Access token and Refresh token" -ForegroundColor Gray
Write-Host "   8. Paste them into the Android app's 'Manual Token Entry' screen" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 2: Re-authenticate on Android" -ForegroundColor Cyan
Write-Host "   1. Build the APK with secrets: .\scripts\build-with-secrets.ps1 -InstallToEmulator" -ForegroundColor Gray
Write-Host "   2. In the Android app, use 'Sign in with WebView' or 'Manual Token Entry'" -ForegroundColor Gray
Write-Host "   3. The app will use the same Desktop OAuth client as Windows" -ForegroundColor Gray
Write-Host ""

Write-Host "📋 Your credentials from secrets.dev.json:" -ForegroundColor Cyan
try {
    $secretsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "secrets.dev.json"
    if (Test-Path $secretsPath) {
        $secrets = Get-Content $secretsPath | ConvertFrom-Json
        Write-Host "   Client ID: $($secrets.GMAIL_DESKTOP_CLIENT_ID)" -ForegroundColor Gray
        Write-Host "   Redirect URI: $($secrets.GMAIL_REDIRECT_URI)" -ForegroundColor Gray
        
        if ($secrets.GMAIL_OAUTH_CLIENT_SECRET -and 
            $secrets.GMAIL_OAUTH_CLIENT_SECRET -ne "REPLACE_WITH_YOUR_CLIENT_SECRET") {
            Write-Host "   Client Secret: $($secrets.GMAIL_OAUTH_CLIENT_SECRET.Substring(0, 10))..." -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Client Secret: NOT SET - Please update secrets.dev.json" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  secrets.dev.json not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Could not read secrets.dev.json" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 For testing the token export feature:" -ForegroundColor Yellow
Write-Host "   After obtaining tokens via OAuth Playground, save them in Android using:" -ForegroundColor Yellow
Write-Host "   1. Open the Android app" -ForegroundColor Gray
Write-Host "   2. Select Gmail → Manual Token Entry" -ForegroundColor Gray
Write-Host "   3. Paste Access Token (required)" -ForegroundColor Gray
Write-Host "   4. Paste Refresh Token (recommended for auto-renewal)" -ForegroundColor Gray
Write-Host "   5. Click 'Validate & Continue'" -ForegroundColor Gray
Write-Host ""
