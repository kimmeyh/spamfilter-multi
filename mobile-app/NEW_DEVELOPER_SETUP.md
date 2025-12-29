# New Developer Setup (Windows 11) — Flutter Mobile App

This guide gets a new Windows 11 developer from zero to running the mobile app. It reflects the exact steps that worked on this machine.

Scope: Windows 11 only. macOS/Linux to be documented later.

## You Will Install
- Flutter SDK (3.38.3 stable)
- Microsoft OpenJDK 17
- Android SDK (CLI tools, platform-tools, build-tools, optional emulator)
- VS Code with Flutter/Dart extensions

## Quick Start (Recommended)

1) Install Chocolatey (*Admin PowerShell*)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco --version
```

2) Install Flutter and Java 17
```powershell
choco install flutter microsoft-openjdk17 -y
```

3) Android SDK install and location
- Recommended: install Android Studio and set SDK location to `C:\Android\android-sdk` in SDK Manager.
- Ensure the following are installed (from SDK Manager or CLI):
  - Android SDK Command-line Tools (latest)
  - Android SDK Platform-Tools
  - At least one Android Platform (API 34 or newer)
  - Android SDK Build-Tools (e.g., 35.0.0)

CLI alternative (PowerShell):
```powershell
$env:ANDROID_SDK_ROOT = "C:\Android\android-sdk"
New-Item -ItemType Directory -Force -Path $env:ANDROID_SDK_ROOT | Out-Null

# If you downloaded cmdline-tools zip, place it at:
# C:\Android\android-sdk\cmdline-tools\latest

& "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\sdkmanager.bat" `
  "platform-tools" "platforms;android-34" "build-tools;35.0.0"

# Accept licenses separately
& "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
```

4) Point Flutter at JDK 17
```powershell
flutter config --jdk-dir "C:\Program Files\Microsoft\jdk-17.0.16.8-hotspot"
```

5) PATH and verification
- Add `C:\Android\android-sdk\platform-tools` to PATH (User or System).
- Close and reopen the terminal.
```powershell
flutter doctor -v
```
Expected: “No issues found!” or only optional platform warnings.

## Project Bootstrap
```powershell
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
flutter pub get
flutter analyze
flutter test
flutter run
```

Notes:
- If `flutter test` reports “Test directory does not contain any test files”, add a smoke test:
  ```powershell
  @'
  import 'package:flutter_test/flutter_test.dart';
  void main() {
    test('smoke', () {
      expect(true, isTrue);
    });
  }
  '@ | Set-Content .\test\smoke_test.dart
  flutter test
  ```
- If `flutter run` reports “No supported devices connected”, launch an emulator or connect a physical Android device (see Emulator section below). Once a device appears in `flutter devices`, re-run `flutter run`.
- Dependency updates: if `flutter pub get` shows “newer versions incompatible with dependency constraints”, you can review with:
  ```powershell
  flutter pub outdated
  ```
  and later update `pubspec.yaml` as needed.

## Android Emulator (optional)
Install emulator and a system image, create and launch an AVD, then install your APK.

```powershell
# Install emulator + API 34 image (x86_64)
& "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\sdkmanager.bat" `
  "emulator" "system-images;android-34;google_apis;x86_64"

# Create AVD (Pixel 5 / API 34)
& "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\avdmanager.bat" create avd `
  -n pixel34 -k "system-images;android-34;google_apis;x86_64" --device "pixel_5" --force

# Launch emulator
& "$env:ANDROID_SDK_ROOT\emulator\emulator.exe" -avd pixel34

# Verify device
adb devices
flutter devices

# Run the app on the emulator
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
flutter run

# Install a built APK (example)
adb install -r D:\Data\Harold\github\spamfilter-multi\mobile-app\build\app\outputs\flutter-apk\app-release.apk
```

Notes:
- If `sdkmanager` prompts for acceptance interactively, you can run the licenses step alone:
  ```powershell
  & "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
  ```
- On first boot the emulator may take several minutes.
- If you prefer ARM (closer to physical devices), use `system-images;android-34;google_apis;arm64-v8a` (slower on cold start).

Quick launcher (Flutter-managed):
```powershell
flutter emulators
flutter emulators --launch pixel34
adb wait-for-device
flutter devices
```

## VS Code
- Install VS Code and the following extensions:
  - Flutter (Dart-Code.flutter)
  - Dart (Dart-Code.dart-code)

## Common Fixes

### Norton Antivirus 360 / Email Protection Blocks IMAP

**Symptom**: TLS certificate validation error when adding an AOL/Yahoo account or scanning.

**Root Cause**: Norton's "Email Protection" feature performs man-in-the-middle TLS inspection of email traffic. The Android emulator trust store does not include Norton's custom root CA, causing SSL handshake failures.

**Solution**: Disable Email Protection in Norton 360:
1. Open **Norton 360**
2. Go to **Settings > Security > Advanced > Intrusion Prevention** (or **Firewall > Advanced**)
3. Disable **"Email Protection"** or **"SSL Scanning"**
   - ⚠️ **Important**: Safe Web exclusions alone do NOT work. Email Protection must be fully disabled.
4. Restart the app and test again

**To verify the fix** (Windows PowerShell):
```powershell
python -c "import socket, ssl; c=ssl.create_default_context(); s=socket.create_connection(('imap.aol.com',993),timeout=10); t=c.wrap_socket(s, server_hostname='imap.aol.com'); print('Issuer:', dict(x[0] for x in t.getpeercert()['issuer'])); t.close()"
```
- ✅ **Expected**: Issuer shows `DigiCert Inc` or `Yahoo` (NOT Norton)
- ❌ **If still Norton**: Email Protection is still active

**For physical devices**: Norton's root CA is pre-installed on Android phones, so no changes needed.

**Full details**: See [README.md § Troubleshooting](./README.md#troubleshooting)

### Flutter Using Wrong JDK
- Flutter using the wrong JDK (bundled with Android Studio):
  ```powershell
  flutter config --jdk-dir "C:\Program Files\Microsoft\jdk-17.0.16.8-hotspot"
  flutter doctor -v
  ```
- No devices/emulators found by `adb`:
  - Ensure `C:\Android\android-sdk\platform-tools` is on PATH.
  - For physical devices: enable USB debugging and accept the fingerprint prompt.
- Licenses not accepted:
  ```powershell
  & "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
  ```

## Verification Checklist
- [x] Flutter SDK installed (3.38.3 stable)
- [x] Microsoft OpenJDK 17 installed
- [x] Android SDK at `C:\Android\android-sdk`
- [x] Licenses accepted via `sdkmanager --licenses`
- [x] VS Code with Flutter/Dart extensions
- [x] `cd mobile-app && flutter pub get && flutter test && flutter run`
