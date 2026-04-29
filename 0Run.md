***BELOW IS NOT FOR CLAUDE CODE USE***
***BELOW IS NOT FOR Github Copilot USE***

# WINDOWS APP
# *** build + launch DEV variant (creates Release-dev/MyEmailSpamFilter-Dev.exe, runs it)
  powershell -NoProfile -ExecutionPolicy Bypass -File "D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\build-windows.ps1" -Environment dev

# *** build + launch PROD variant (creates Release-prod/MyEmailSpamFilter.exe, runs it)
  powershell -NoProfile -ExecutionPolicy Bypass -File "D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\build-windows.ps1" -Environment prod

# *** RUN DEV variant manually
Start-Process "D:\Data\Harold\github\spamfilter-multi\mobile-app\dist\dev\MyEmailSpamFilter-Dev.exe"

# *** RUN PROD variant manually
Start-Process "D:\Data\Harold\github\spamfilter-multi\mobile-app\dist\prod\MyEmailSpamFilter.exe"


# Run Android Emulator -------------------------
#   Preferred method
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -Run"
# or  -StartEmulator?

# NOTE: Log file is: D:\Data\Harold\github\spamfilter-multi\mobile-app\test_results.txt
# Emulator notes:  
#   Do a Hot restart by issuing a R - treid once and it did ot work
    db shell input keyevent R

#   Press back button to exit
    adb shell "am start -a android.settings.SETTINGS" ;&  Start-Sleep -Seconds 2 ; adb shell input keyevent 4

#   Or press home button
    adb shell "am start -a android.settings.SETTINGS" ;&  Start-Sleep -Seconds 2 ; adb shell input keyevent 3

#   Or open recent apps
    adb shell "am start -a android.settings.SETTINGS" ;&  Start-Sleep -Seconds 2 ; adb shell input keyevent 187

# another way
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter emulators --launch pixel34
  # in another PowerShell window, run flutter
  flutter run

#   Another way
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\run-emulator.ps1 -InstallReleaseApk

# Runs the Android emulator app using the "abd monkey" command below with the package name
adb shell monkey -p com.example.spamfiltermobile -c android.intent.category.LAUNCHER 1



# Build & Run APK on Emulator
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
flutter build apk --release
flutter install

***NOTE*** Hot Reload During Development
# Once the app is running:
#    Press r - Hot reload (preserves state)
#    Press R - Hot restart (resets state)
#    Press q - Quit


I added aol account, ran scan.  Return from scan went to the aol account setup screen instead of the Select Account screen.