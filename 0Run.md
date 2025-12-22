# Run Windows Emulator
#   cd D:\Data\Harold\github\spamfilter-multi\mobile-app
#   flutter run -d windows
# If needed confirm dependencies and then re-build the app
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows
# single command line
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter run -d windows
# NOTE: Log file is: 

# Run Android Emulator
#   Preferred method
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Data\Harold\github\spamfilter-multi/mobile-app/scripts/run-emulator.ps1
# NOTE: Log file is: D:\Data\Harold\github\spamfilter-multi\mobile-app\test_results.txt

# another way
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter emulators --launch pixel34
  # in another PowerShell window, run flutter
  flutter run

#   Another way
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\run-emulator.ps1 -InstallReleaseApk

# Runs the Android emulator app using the "abd monkey" command below with the package name
adb shell monkey -p com.example.spamfilter_mobile -c android.intent.category.LAUNCHER 1



# Build & Run APK on Emulator
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
flutter build apk --release
flutter install

***NOTE*** Hot Reload During Development
# Once the app is running:
#    Press r - Hot reload (preserves state)
#    Press R - Hot restart (resets state)
#    Press q - Quit