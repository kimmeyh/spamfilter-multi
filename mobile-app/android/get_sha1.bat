@echo off
REM Get Android Debug SHA-1 Fingerprint for Firebase
REM This script displays the SHA-1 fingerprint from the Android debug keystore
REM Copy the SHA-1 value and add it to Firebase Console

echo.
echo ========================================
echo Android Debug SHA-1 Fingerprint Extractor
echo ========================================
echo.
echo This will display your debug keystore's SHA-1 fingerprint.
echo You need to add this to Firebase Console for Google Sign-In to work.
echo.

cd /d "%USERPROFILE%\.android"

echo Running keytool to extract SHA-1...
echo.

keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android

echo.
echo ========================================
echo Next Steps:
echo ========================================
echo 1. Copy the SHA-1 value from above (format: XX:XX:XX:XX...)
echo 2. Open Firebase Console: https://console.firebase.google.com/
echo 3. Select your project (spamfilter-multi)
echo 4. Go to Project Settings (gear icon)
echo 5. Find "Your apps" section
echo 6. Click on your Android app
echo 7. Click "Add fingerprint"
echo 8. Paste the SHA-1 value
echo 9. Click "Save"
echo 10. Download the updated google-services.json
echo 11. Replace the file in: mobile-app\android\app\google-services.json
echo 12. Run: flutter clean && flutter pub get && flutter build apk --release
echo.
echo For more info: https://developers.google.com/android/guides/client-auth
echo.
pause
