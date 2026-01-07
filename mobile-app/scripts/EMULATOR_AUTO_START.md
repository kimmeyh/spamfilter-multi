# Emulator Auto-Start Feature

## Overview

The `build-with-secrets.ps1` script now includes intelligent emulator auto-start functionality. This eliminates the need to manually launch Android emulators before building and testing.

## New Parameters

### `-StartEmulator`
Automatically starts an Android emulator if none is currently running.

**Behavior**:
- Detects if an emulator is already running (uses existing one)
- Lists available AVDs using `emulator -list-avds`
- Launches the first available AVD automatically
- Waits up to 60 seconds for emulator to start
- Proceeds with build/install once detected

### `-EmulatorName <AVDName>`
Specifies which emulator to launch (optional).

**Behavior**:
- Only used if `-StartEmulator` is set
- Ignored if an emulator is already running
- Falls back to first available AVD if specified name not found
- Example: `-EmulatorName "Pixel_5_API_33"`

## Usage Examples

### Basic Auto-Start (uses first available AVD)
```powershell
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator
```

**What happens**:
1. Checks if emulator is running → none found
2. Runs `emulator -list-avds` → finds available AVDs
3. Launches first AVD (e.g., "Pixel_5_API_33")
4. Waits for emulator to appear in `adb devices`
5. Waits for boot to complete
6. Builds APK, installs, and launches app

### Specify Exact Emulator
```powershell
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator -EmulatorName "Pixel_6_API_34"
```

**What happens**:
- Same as above, but launches "Pixel_6_API_34" specifically
- Falls back to first available if "Pixel_6_API_34" not found

### Combined with Other Flags
```powershell
# Auto-start + preserve accounts + debug build
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator -SkipUninstall

# Auto-start + release build
.\build-with-secrets.ps1 -BuildType release -InstallToEmulator -StartEmulator
```

## Error Handling

### No AVDs Found
```
[ERROR]: No AVDs found. Create one with Android Studio (Tools → Device Manager → Create Device)
```

**Solution**: Create an AVD in Android Studio first.

### Emulator Not in PATH
```
[WARNING]: Could not list AVDs. Make sure Android SDK emulator is in PATH.
```

**Solution**: Add Android SDK `emulator` directory to PATH:
```powershell
# Example Windows PATH entry:
C:\Users\<YourName>\AppData\Local\Android\Sdk\emulator
```

### Emulator Timeout
```
[ERROR]: Emulator still not detected after auto-start attempt.
```

**Solution**: 
- Check if emulator window appeared but didn't connect
- Verify ADB is working: `adb devices`
- Try starting emulator manually first

## Comparison: Manual vs Auto-Start

### Before (Manual Workflow)
```powershell
# Step 1: Start emulator manually
# (Open Android Studio → Device Manager → Click Play)
# Wait 30-60 seconds for boot

# Step 2: Run build script
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
```

### After (Auto-Start Workflow)
```powershell
# Single command does everything:
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator
```

## Technical Details

### AVD Detection
Uses `emulator -list-avds` to enumerate all available Android Virtual Devices. Example output:
```
Pixel_5_API_33
Pixel_6_Pro_API_34
Tablet_API_33
```

### Emulator Launch
Uses PowerShell's `Start-Process` to launch emulator in background:
```powershell
Start-Process -FilePath "emulator" -ArgumentList @("-avd", $avdToLaunch) -WindowStyle Minimized
```

### Detection Loop
Polls `adb devices` every 2 seconds for up to 60 seconds:
```powershell
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $emulatorDevice = & adb devices | Select-String "emulator-"
    if ($emulatorDevice) { break }
}
```

### Status Messages
Progress is displayed every 10 seconds:
```
[INFO]: Waiting for emulator to start (this may take 30-60 seconds)...
  Still waiting... (0s elapsed)
  Still waiting... (10s elapsed)
  Still waiting... (20s elapsed)
  [OK] Emulator detected: emulator-5554
```

## Best Practices

### Development Workflow
1. **First build of the day**: Use `-StartEmulator` to auto-launch
2. **Subsequent builds**: Emulator stays running, no need for flag
3. **Testing different AVDs**: Use `-EmulatorName` to switch

### CI/CD Integration
```powershell
# Automated build pipeline
.\build-with-secrets.ps1 `
    -BuildType release `
    -InstallToEmulator `
    -StartEmulator `
    -EmulatorName "CI_Test_Device"
```

### Troubleshooting
```powershell
# If emulator not starting, check available AVDs:
emulator -list-avds

# Check if emulator is in PATH:
Get-Command emulator

# Check current running emulators:
adb devices
```

## Limitations

1. **Cannot select specific emulator if multiple are running**
   - Uses whichever emulator `adb devices` finds first
   - Workaround: Stop unwanted emulators before running script

2. **Requires Android SDK emulator in PATH**
   - Script cannot launch emulator if `emulator` command not found
   - Workaround: Add SDK emulator directory to system PATH

3. **60-second timeout may not be enough for slow machines**
   - Default timeout is 60 seconds (30 loops × 2 seconds)
   - Workaround: Start emulator manually if timeout occurs

## Related Files

- `build-with-secrets.ps1` - Main build script (lines 406-477)
- `CLAUDE.md` - Project documentation (Android Development section)
- `README.md` - User-facing documentation

## See Also

- Android SDK Emulator documentation: https://developer.android.com/studio/run/emulator-commandline
- ADB documentation: https://developer.android.com/tools/adb
- Flutter device management: https://docs.flutter.dev/get-started/install/windows#set-up-the-android-emulator
