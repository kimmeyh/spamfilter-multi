# Troubleshooting Guide

Common issues and solutions for the Spam Filter application.

## Build Issues

### Flutter: "The term 'flutter' is not recognized"

**Cause**: Flutter not in PATH or PowerShell session not refreshed.

**Solution**: Restart PowerShell or reboot computer to reload PATH.

### Android SDK not found

**Cause**: ANDROID_HOME environment variable not set.

**Solution**:
```powershell
[Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Android\android-sdk', 'User')
```

### Visual Studio not found (Windows build)

**Cause**: Missing C++ workload for Windows desktop builds.

**Solution**: Install Visual Studio 2022 with "Desktop development with C++" workload.

---

## Authentication Issues

### Gmail: "Sign in was cancelled" (Android)

**Cause**: SHA-1 fingerprint not registered in Firebase Console.

**Solution**: See [OAuth Setup - Android](OAUTH_SETUP.md#android-setup).

### Gmail: "client_secret is missing" (Windows)

**Cause**: `secrets.dev.json` missing or incomplete.

**Solution**: See [OAuth Setup - Secrets](OAUTH_SETUP.md#secrets-configuration).

### AOL: "TLS certificate validation failed"

**Cause**: Norton Antivirus "Email Protection" intercepting TLS connections.

**Solution**:
1. Open Norton Security
2. Go to Settings → Security → Advanced
3. Disable "Email Protection" or add exception for IMAP
4. Retry connection

**Verify Fix**:
```powershell
python -c "import socket, ssl; ctx = ssl.create_default_context(); s = ctx.wrap_socket(socket.socket(), server_hostname='imap.aol.com'); s.connect(('imap.aol.com', 993)); print('OK:', s.version())"
```

---

## Scanning Issues

### Folder selection not working

**Symptom**: Selected folders ignored, only INBOX scanned.

**Cause**: Fixed in Issue #35 (Jan 2026). Ensure you have latest code.

**Solution**: Pull latest changes and rebuild.

### "No rule" count keeps increasing

**Symptom**: "No rule" bubble shows impossible values across scans.

**Cause**: Fixed in Phase 3.3. Counter was not reset between scans.

**Solution**: Pull latest changes and rebuild.

### Gmail emails not matching rules

**Symptom**: Rules work for AOL but not Gmail.

**Cause**: Gmail returns "Name <email>" format, rules expect just "email".

**Solution**: Fixed in Phase 3.3. The `_extractEmail()` helper now parses the format.

---

## UI Issues

### Auto-navigation to Results when returning to Scan Progress

**Cause**: Race condition in status change detection. Fixed in Issue #39.

**Solution**: Pull latest changes and rebuild.

### Account cards flicker on Account Selection screen

**Cause**: FutureBuilder recreating futures on rebuild. Fixed Dec 2025.

**Solution**: Account data is now cached. Pull latest changes.

---

## Git Issues

### Flutter source files not tracked

**Symptom**: Files in `mobile-app/lib/` do not show in git status.

**Cause**: Root `.gitignore` had overly broad `lib/` exclusion.

**Solution**: Fixed Dec 2025. The exclusion is now specific to `Archive/desktop-python/lib/`.

---

## Test Issues

### Tests fail with "Credential not found"

**Cause**: Integration tests require real credentials.

**Solution**: These tests are skipped by default (13 skipped). To run them, configure `secrets.dev.json` with valid credentials.

### Pattern matching tests fail

**Cause**: Dart RegExp does not support Python-style inline flags like `(?i)`.

**Solution**: Fixed in Issue #38. PatternCompiler now strips these flags automatically.

---

## Performance Issues

### Slow regex pattern matching

**Cause**: Patterns with catastrophic backtracking (e.g., nested quantifiers).

**Solution**: Validate patterns with:
```powershell
.\scripts\validate-yaml-rules.ps1 -TestRegex
```

### UI updates too frequently during scan

**Cause**: Fixed in Issue #36. Updates are now throttled (every 10 emails or 3 seconds).

---

## Common Commands

### Clean rebuild (Flutter)
```powershell
cd mobile-app
flutter clean
flutter pub get
```

### Reset Android emulator data
```powershell
adb -e emu kill
# Then restart emulator from Android Studio
```

### Check Flutter doctor
```powershell
flutter doctor -v
```

### Run all tests
```powershell
cd mobile-app
flutter test
```

---

## Getting Help

1. Check [CHANGELOG.md](../CHANGELOG.md) for recent fixes
2. Search [GitHub Issues](https://github.com/kimmeyh/spamfilter-multi/issues)
3. Review [CLAUDE.md](../CLAUDE.md) for architecture details
