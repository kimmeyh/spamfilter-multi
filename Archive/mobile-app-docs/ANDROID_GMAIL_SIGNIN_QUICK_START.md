# Android Gmail Sign-In Quick Setup

## Problem
"Sign-In Error Sign in was cancelled or failed" when testing Gmail Sign-In on Android emulator.

## Root Cause
SHA-1 fingerprint of your debug keystore is not registered in Firebase Console. Google rejects the sign-in request because it doesn't recognize your app's signature.

## Solution (5 Steps - 5 Minutes)

### Step 1: Extract SHA-1 Fingerprint
```bash
cd mobile-app\android
get_sha1.bat
```

Copy the SHA-1 value from output (format: `XX:XX:XX:XX:...`)

### Step 2: Register in Firebase Console
1. Open https://console.firebase.google.com/
2. Select project: `spamfilter-multi`
3. Click ⚙️ Settings (top-left)
4. Go to "Project Settings" tab
5. Scroll to "Your apps" section
6. Find your Android app
7. Click "Add fingerprint"
8. Paste the SHA-1 value
9. Click "Save"

### Step 3: Download Updated google-services.json
1. Still in Firebase Console
2. Look for "Download" button or link
3. Click to download `google-services.json`
4. Save to: `mobile-app/android/app/google-services.json` (replace existing file)

### Step 4: Clean Rebuild
```bash
cd mobile-app
flutter clean
flutter pub get
flutter build apk --release
```

### Step 5: Test on Emulator
**Important**: Ensure emulator uses Google APIs image (NOT AOSP):
- Android Studio → Virtual Device Manager
- Edit your emulator
- System image MUST contain "Google APIs" or "Google Play"
  - ✅ `Google APIs ARM64 v8a`
  - ✅ `Google Play ARM64 v8a`
  - ❌ `Android Open Source Project ARM64 v8a` (No Google Services!)

Then:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
# Launch app and test Gmail sign-in
```

**Expected Result**: Google consent screen appears → Select account → Permissions granted → ✅ Signed in

---

## Still Getting "Sign in was cancelled"?

### Checklist
- [ ] SHA-1 file shows correct fingerprint format (XX:XX:XX:XX:...)
- [ ] SHA-1 added to Firebase Console (verified in Project Settings)
- [ ] google-services.json downloaded AFTER adding SHA-1
- [ ] google-services.json placed at correct path: `mobile-app/android/app/google-services.json`
- [ ] Emulator image contains "Google APIs" (check in AVD Manager)
- [ ] `flutter clean` and `flutter pub get` run successfully
- [ ] `flutter build apk --release` completes without errors
- [ ] APK installed on correct emulator: `adb install build/app/outputs/flutter-apk/app-release.apk`

### Common Issues

**Issue**: SHA-1 fingerprint shows as different each time
- **Solution**: All debug keystores have the same SHA-1. Ensure you're using `~/.android/debug.keystore`

**Issue**: Emulator shows "Google Play Services not available"
- **Solution**: Switch to emulator with Google APIs image. Delete current emulator and create new one with proper system image

**Issue**: "PlatformException: 10"
- **Solution**: Delete google-services.json and download fresh copy from Firebase Console (AFTER adding SHA-1)

**Issue**: Still failing after all steps
- **Solution**: See detailed troubleshooting in [ANDROID_GMAIL_SIGNIN_SETUP.md](ANDROID_GMAIL_SIGNIN_SETUP.md)

---

## References

- **Detailed Guide**: [ANDROID_GMAIL_SIGNIN_SETUP.md](ANDROID_GMAIL_SIGNIN_SETUP.md)
- **SHA-1 Scripts**: `mobile-app/android/get_sha1.bat` (Windows) or `get_sha1.sh` (Linux/Mac)
- **Firebase Console**: https://console.firebase.google.com/
- **Google Sign-In Docs**: https://developers.google.com/identity/sign-in/android
- **Android App Signing**: https://developer.android.com/studio/publish/app-signing

