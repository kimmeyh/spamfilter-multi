<#
.SYNOPSIS
    Complete Android OAuth setup walkthrough

.DESCRIPTION
    Interactive script to help you set up OAuth for Android,
    including getting the client_secret and testing the setup.
#>

$ErrorActionPreference = 'Stop'

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Android Gmail OAuth Setup - Complete Walkthrough         ║
║                                                               ║
╔═══════════════════════════════════════════════════════════════╗

"@ -ForegroundColor Cyan

Write-Host "This script will help you:" -ForegroundColor Yellow
Write-Host "  1. Get your Desktop OAuth client_secret from Google Cloud Console" -ForegroundColor Gray
Write-Host "  2. Update secrets.dev.json with the credentials" -ForegroundColor Gray
Write-Host "  3. Build and install the APK with credentials injected" -ForegroundColor Gray
Write-Host "  4. Guide you through first sign-in" -ForegroundColor Gray
Write-Host ""

# Step 1: Check if secrets file exists
$mobileAppDir = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $mobileAppDir "secrets.dev.json"

Write-Host "═══ STEP 1: Get Client Secret ═══" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $secretsPath) {
    $secrets = Get-Content $secretsPath | ConvertFrom-Json
    Write-Host "Current configuration:" -ForegroundColor Yellow
    Write-Host "  Client ID: $($secrets.GMAIL_DESKTOP_CLIENT_ID)" -ForegroundColor Gray
    Write-Host "  Client Secret: $($secrets.GMAIL_OAUTH_CLIENT_SECRET)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "To get your client_secret:" -ForegroundColor Yellow
Write-Host "  1. Open: https://console.cloud.google.com/apis/credentials" -ForegroundColor Gray
Write-Host "  2. Find your Desktop app client (577022808534...)" -ForegroundColor Gray
Write-Host "  3. Click on the client name to open details" -ForegroundColor Gray
Write-Host "  4. You should see 'Client ID' and 'Client secret'" -ForegroundColor Gray
Write-Host "  5. Click the copy icon next to 'Client secret'" -ForegroundColor Gray
Write-Host ""

Write-Host "Press Enter after you've opened the Google Cloud Console..." -ForegroundColor Yellow
$null = Read-Host

Write-Host ""
Write-Host "Now paste your Client Secret here (it will be hidden):" -ForegroundColor Yellow
Write-Host "Note: The text won't appear as you type for security" -ForegroundColor Gray
$clientSecret = Read-Host -AsSecureString

# Convert SecureString to plain text for JSON
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret)
$clientSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if ([string]::IsNullOrWhiteSpace($clientSecretPlain)) {
    Write-Host "❌ No client secret entered. Exiting." -ForegroundColor Red
    exit 1
}

# Step 2: Update secrets file
Write-Host ""
Write-Host "═══ STEP 2: Update Configuration ═══" -ForegroundColor Cyan
Write-Host ""

$secrets.GMAIL_OAUTH_CLIENT_SECRET = $clientSecretPlain
$secrets | ConvertTo-Json | Set-Content $secretsPath

Write-Host "✅ Updated secrets.dev.json" -ForegroundColor Green
Write-Host "   Client ID: $($secrets.GMAIL_DESKTOP_CLIENT_ID.Substring(0, 30))..." -ForegroundColor Gray
Write-Host "   Client Secret: $($clientSecretPlain.Substring(0, 10))... (${clientSecretPlain.Length} chars)" -ForegroundColor Gray
Write-Host ""

# Step 3: Verify redirect URI
Write-Host "═══ STEP 3: Verify OAuth Configuration ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "Please verify in Google Cloud Console that your Desktop app has these authorized redirect URIs:" -ForegroundColor Yellow
Write-Host "  • http://localhost:8080/oauth/callback" -ForegroundColor Gray
Write-Host "  • urn:ietf:wg:oauth:2.0:oob (optional, for fallback)" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
$null = Read-Host

# Step 4: Build APK
Write-Host ""
Write-Host "═══ STEP 4: Build APK with Credentials ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "Building Flutter APK with OAuth credentials injected..." -ForegroundColor Yellow
Write-Host ""

$buildScript = Join-Path $PSScriptRoot "build-with-secrets.ps1"
& $buildScript -InstallToEmulator

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Build failed. Please check errors above." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 5: Sign-in guide
Write-Host ""
Write-Host "═══ STEP 5: Sign In on Android ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "The app should now be running on your emulator." -ForegroundColor Green
Write-Host ""
Write-Host "To sign in with Gmail:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option A - WebView OAuth (Recommended):" -ForegroundColor Cyan
Write-Host "  1. Click 'Sign in with WebView' button" -ForegroundColor Gray
Write-Host "  2. Sign in with your Gmail account" -ForegroundColor Gray
Write-Host "  3. Grant permissions when prompted" -ForegroundColor Gray
Write-Host "  4. App will automatically save tokens" -ForegroundColor Gray
Write-Host ""

Write-Host "Option B - Manual Token Entry:" -ForegroundColor Cyan
Write-Host "  1. Visit: https://developers.google.com/oauthplayground/" -ForegroundColor Gray
Write-Host "  2. Click gear icon ⚙️  → Check 'Use your own OAuth credentials'" -ForegroundColor Gray
Write-Host "  3. Enter:" -ForegroundColor Gray
Write-Host "     Client ID: $($secrets.GMAIL_DESKTOP_CLIENT_ID)" -ForegroundColor DarkGray
Write-Host "     Client secret: $($clientSecretPlain.Substring(0, 10))..." -ForegroundColor DarkGray
Write-Host "  4. Select scopes: gmail.modify + userinfo.email" -ForegroundColor Gray
Write-Host "  5. Authorize APIs → Sign in" -ForegroundColor Gray
Write-Host "  6. Exchange code for tokens" -ForegroundColor Gray
Write-Host "  7. Copy Access token and Refresh token" -ForegroundColor Gray
Write-Host "  8. In Android app: Click 'Manual Token Entry'" -ForegroundColor Gray
Write-Host "  9. Paste tokens and submit" -ForegroundColor Gray
Write-Host ""

Write-Host "═══ TROUBLESHOOTING ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you see 'invalid_client':" -ForegroundColor Yellow
Write-Host "  • Verify client_secret is correct in Google Cloud Console" -ForegroundColor Gray
Write-Host "  • Check redirect URI is authorized: http://localhost:8080/oauth/callback" -ForegroundColor Gray
Write-Host "  • Ensure you're using the Desktop app client (not Android client)" -ForegroundColor Gray
Write-Host ""

Write-Host "If tokens don't validate:" -ForegroundColor Yellow
Write-Host "  • Use OAuth Playground with YOUR credentials (gear icon)" -ForegroundColor Gray
Write-Host "  • Select correct scopes (gmail.modify + userinfo.email)" -ForegroundColor Gray
Write-Host "  • Copy BOTH access token AND refresh token" -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Setup complete! Try signing in now." -ForegroundColor Green
Write-Host ""
Write-Host "For more details, see: mobile-app\ANDROID_OAUTH_SETUP.md" -ForegroundColor Gray
Write-Host ""
