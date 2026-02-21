# Android Gmail Sign-In Troubleshooting Guide

## Issue: "Sign-In Error Sign in was cancelled or failed" on Android Emulator

This guide addresses the most common causes of Gmail Sign-In failures on Android emulators.

## Root Causes (Check in Order)

### 1. ✅ DEBUG SHA-1 FINGERPRINT NOT REGISTERED (Most Common)

**Symptom**: Sign-in button clicked → Google consent screen → Error "Sign in was cancelled or failed"

**Root Cause**: Your app's SHA-1 fingerprint is not registered in Firebase Console. Google rejects the sign-in request because the fingerprint doesn't match.

**Solution**:

```bash
# Windows (PowerShell or Command Prompt)
cd mobile-app\android
get_sha1.bat

# Linux/Mac
cd mobile-app/android
chmod +x get_sha1.sh
./get_sha1.sh
```

**Output Example**:
```
Certificate fingerprints:
     SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
```

**Firebase Console Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `spamfilter-multi`
3. Click Settings ⚙️ (top-left)
4. Go to "Project Settings"
5. Click "Your apps" section
6. Find your Android app
7. Click "Add fingerprint"
8. Paste the SHA-1: `AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12`
9. Click "Save"
10. **Download fresh google-services.json**
11. Replace: `mobile-app/android/app/google-services.json`

**Test**:
```bash
flutter clean
flutter pub get
flutter build apk --release
# Install on emulator and test
```

---

### 2. ✅ WRONG EMULATOR IMAGE (No Google Play Services)

**Symptom**: App launches but Google Sign-In button is greyed out or doesn't respond

**Root Cause**: Emulator uses "Android Open Source Project (AOSP)" image without Google Play Services

**Solution - Use Correct Emulator Image**:

In Android Studio:
1. Open AVD Manager (Virtual Device Manager)
2. Create/Edit emulator
3. Select system image: **Must contain "Google APIs" or "Google Play"**
   - ✅ Good: `Google APIs ARM64 v8a`
   - ✅ Good: `Google Play ARM64 v8a`
   - ❌ Bad: `Android Open Source Project ARM64 v8a`

**Delete Old Emulator**:
```bash
# List all emulators
$ANDROID_HOME\emulator\emulator -list-avds

# Delete old AOSP emulator
# (easier via Android Studio AVD Manager)
```

**Create New Emulator**:
1. Android Studio → Virtual Device Manager
2. "Create Device"
3. Choose Pixel 5 or similar
4. Choose API 34 (Android 14)
5. **Select "Google APIs ARM64 v8a" system image**
6. Name: `Pixel_5_API_34_Google_APIs`
7. Click "Finish"

---

### 3. ⚠️ NORTON 360 EMAIL PROTECTION (TLS Interception)

**Symptom**: 
```
AuthenticationException: Authentication failed
IMAP: TLS certificate validation failed
```

**Root Cause**: Norton 360's "Email Protection" module intercepts all email traffic (IMAP/SMTP/POP3) and performs certificate chain inspection with a self-signed "Norton Web/Mail Shield Root" CA.

**Solution - Disable Norton Email Protection**:

1. Open Norton 360
2. Settings → Security
3. Find "Intrusion Prevention" or "Email Protection"
4. **Disable "Email Protection"** (NOT just "Safe Web")
5. Restart app/emulator

**Why Safe Web Exclusions Don't Work**:
- Safe Web only prevents browser MITM
- Email Protection runs at the network layer (intercepts all email protocol traffic)
- Both must be disabled or properly configured

**Verification**:
```powershell
# On Windows host, test TLS certificate
$hostname = "imap.aol.com"
$port = 993
$tcpClient = New-Object System.Net.Sockets.TcpClient($hostname, $port)
$sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
$sslStream.AuthenticateAsClient($hostname)
$cert = $sslStream.RemoteCertificate
$cert.Issuer  # Should NOT contain "Norton"
# Output: CN=DigiCert ... (NOT "Norton Web/Mail Shield Root")
```

---

### 4. ✅ GOOGLE-SERVICES.JSON NOT UPDATED

**Symptom**: PlatformException: 10 (Google Play Services error)

**Root Cause**: google-services.json doesn't match registered SHA-1 fingerprint

**Solution**:

1. Add SHA-1 to Firebase Console (see Root Cause #1)
2. **Download fresh google-services.json**
   - Firebase Console → Project Settings → Download button
3. Replace file: `mobile-app/android/app/google-services.json`
4. Rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

---

### 5. ✅ FIREWALL/NETWORK ISSUES

**Symptom**: Google consent screen never loads (blank or timeout)

**Root Cause**: 
- Emulator cannot access google.com or accounts.google.com
- DNS not resolving
- Network routing issues

**Solution**:

```bash
# Test network from emulator
adb shell ping google.com
adb shell ping accounts.google.com

# Check DNS
adb shell getprop net.dns1
adb shell getprop net.dns2

# If DNS missing, configure manually
adb shell setprop net.dns1 8.8.8.8
adb shell setprop net.dns2 8.8.4.4
```

**Emulator Network Settings**:
1. Close emulator
2. Edit emulator (AVD Manager)
3. Advanced Settings → Network
4. Set to "Automatic" or "Custom TCP/IP"
5. Restart emulator

---

## Complete Setup Checklist

- [ ] **SHA-1 fingerprint extracted** (Run `get_sha1.bat` or `get_sha1.sh`)
- [ ] **SHA-1 added to Firebase Console** (Project Settings → Your apps → Android app)
- [ ] **google-services.json downloaded** (Firebase Console → Download)
- [ ] **google-services.json placed** at `mobile-app/android/app/google-services.json`
- [ ] **Emulator image verified** (Google APIs or Google Play, NOT AOSP)
- [ ] **Norton Email Protection disabled** (If you have Norton 360)
- [ ] **firebaseauth dependency added** to pubspec.yaml
- [ ] **google_sign_in dependency added** to pubspec.yaml
- [ ] **Project clean rebuild done**:
  ```bash
  cd mobile-app
  flutter clean
  flutter pub get
  flutter build apk --release
  ```

---

## Testing Sign-In

### Manual Test
1. Build and install APK:
   ```bash
   flutter build apk --release
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. Launch app on emulator
3. Navigate to Gmail account setup
4. Click "Sign In with Google"
5. Google consent screen should appear
6. Select test Gmail account
7. Grant permissions
8. ✅ Should return to app with user email displayed

### Debug Output
```bash
# View logs during sign-in
flutter run -v 2>&1 | grep -i "signin\|google\|auth"

# Or via adb
adb logcat | grep "GoogleSignIn"
```

---

## FAQ

**Q: I added SHA-1 but still get "Sign in was cancelled"**
A: Delete and re-download google-services.json from Firebase Console. The file must be updated AFTER adding the fingerprint.

**Q: My SHA-1 is different each time I run the script**
A: All debug keystores have the same SHA-1. If it's different, verify you're using `~/.android/debug.keystore`.

**Q: Can I test without Firebase?**
A: Not with google_sign_in plugin. Firebase + proper SHA-1 registration is required.

**Q: How do I get a different SHA-1 for release builds?**
A: Release builds use a different keystore. You'll need to:
1. Create a release keystore (if not already created)
2. Extract its SHA-1 fingerprint
3. Add it separately to Firebase Console
4. Download google-services.json again

**Q: Norton is disabled but still getting certificate errors**
A: Restart emulator completely (`adb emu kill` then restart). Certificate interception may continue until network stack resets.

---

## Related Files

- SHA-1 Extraction: `mobile-app/android/get_sha1.bat` (Windows)
- SHA-1 Extraction: `mobile-app/android/get_sha1.sh` (Linux/Mac)
- Firebase Setup: [Firebase Console](https://console.firebase.google.com/)
- Google Sign-In Docs: [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android)
- Fingerprint Help: [Android App Signing](https://developer.android.com/studio/publish/app-signing)

---

## Still Having Issues?

1. **Check logs**:
   ```bash
   adb logcat -s GoogleSignIn -v long
   ```

2. **Clear app data**:
   ```bash
   adb shell pm clear com.example.spamfilter_mobile
   ```

3. **Reinstall from scratch**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   adb uninstall com.example.spamfilter_mobile
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

4. **Check Firebase Console**:
   - Verify SHA-1 is listed
   - Verify Android app is enabled
   - Verify Google Sign-In is enabled (Authentication section)

5. **Test on real device**:
   - Extract SHA-1 from release keystore
   - Add to Firebase
   - Build release APK
   - Install on physical Android device

