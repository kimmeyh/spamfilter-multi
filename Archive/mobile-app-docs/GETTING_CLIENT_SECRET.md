# Getting OAuth Client Secret - Alternative Methods

⚠️ **SECURITY WARNING**: The downloaded OAuth client secret JSON file (e.g., `client_secret_*.json`) contains sensitive credentials and must NEVER be committed to Git. Store it locally only and add values to `mobile-app/secrets.dev.json` for build-time injection. These files are now excluded by `.gitignore`.

Your Desktop OAuth client JSON is missing `client_secret`. Here are all options:

## Option 1: Desktop Client Secret (Try First)

The JSON you downloaded should have `client_secret`, but it's missing. Try:

1. **Re-download the JSON**:
   - Go to: https://console.cloud.google.com/apis/credentials
   - Find: `577022808534-v94j401b6hvllehkp70pheo4b0injrc1`
   - Click the **download icon** (⬇️) on the right side
   - Save and check if the new JSON has `client_secret`

2. **Reset the secret** (if still missing):
   - Click on the client name
   - Look for "RESET SECRET" or "Add Secret" button
   - Click it to generate a new secret
   - Download the updated JSON

## Option 2: PKCE Without Secret (Currently Testing)

Desktop apps can use PKCE without `client_secret`. The build just completed with an empty secret.

**Test now**:
1. Open the app on your emulator
2. Click "Sign in with WebView"
3. If it works → great, no secret needed!
4. If it shows `invalid_client` → proceed to Option 3

## Option 3: Create Web Application Client (Always Has Secret)

If Desktop client doesn't work, create a Web app client:

1. Go to: https://console.cloud.google.com/apis/credentials
2. Click "**+ CREATE CREDENTIALS**" → "OAuth client ID"
3. Application type: **Web application**
4. Name: "SpamFilter Mobile Web Client"
5. Authorized redirect URIs, add:
   - `http://localhost:8080/oauth/callback`
   - `http://127.0.0.1:8080/oauth/callback`
6. Click "CREATE"
7. Copy the **Client ID** and **Client secret** (both visible)
8. Update `mobile-app/secrets.dev.json` with these values
9. Rebuild: `.\scripts\build-with-secrets.ps1 -InstallToEmulator`

**Web clients** always show both client_id and client_secret in the console.

## Option 4: Check Console UI Carefully

The secret might be there but hidden. In Google Cloud Console:

1. Go to credentials page
2. Click the **client name** (not the edit icon)
3. Look for a section labeled "Client secret"
4. There might be a **"SHOW"** or eye icon (👁️) to reveal it
5. Or a **copy icon** to copy it directly

## Current Status

- ✅ Built APK with empty `client_secret` (PKCE-only)
- ✅ Installed to emulator
- ⏳ **Test WebView sign-in now to see if PKCE works**

If WebView still fails with `invalid_client`, use Option 3 (Web application client).
