# Run Windows Emulator
#   cd D:\Data\Harold\github\spamfilter-multi\mobile-app
#   flutter run -d windows
# If needed confirm dependencies and then re-build the app
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows
# single command line
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter run -d windows

# Run Android Emulator
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter emulators --launch Pixel_7_API_34
  # in another PowerShell window, run flutter
  flutter run

# Build & Run APK on Emulator
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
flutter build apk --release
flutter install

***NOTE*** Hot Reload During Development
# Once the app is running:
#    Press r - Hot reload (preserves state)
#    Press R - Hot restart (resets state)
#    Press q - Quit