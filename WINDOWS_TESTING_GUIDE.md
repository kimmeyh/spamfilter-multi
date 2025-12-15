# Windows Testing Guide

## Quick Start

### Prerequisites
- Windows 11 or higher
- Visual Studio Community 2022 with C++ development tools
- Flutter SDK installed and in PATH
- Git installed

### Building the Windows App

#### Option 1: Debug Mode (Recommended for Development)
```powershell
cd mobile-app
flutter run -d windows
```

#### Option 2: Release Mode (Production Testing)
```powershell
cd mobile-app
flutter build windows --release
# Then run: build/windows/x64/runner/Release/spam_filter_mobile.exe
```

#### Option 3: Manual Build
```powershell
cd mobile-app
flutter build windows
```

## Testing Checklist

### Phase 1: Startup & UI (5 minutes)
```
[ ] Application launches without errors
[ ] Main window displays with correct title
[ ] UI elements are visible and properly positioned
[ ] No console errors or warnings
[ ] Application responsive to mouse/keyboard input
```

### Phase 2: Authentication (10-15 minutes)
```
[ ] Navigate to authentication section (if visible)
[ ] Click "Sign In with Google" button
[ ] Complete OAuth flow in browser
[ ] Application receives authentication token
[ ] User email displays correctly
[ ] Session persists on app restart
```

### Phase 3: Email Integration (15-20 minutes)
```
[ ] Successfully connect to Gmail account
[ ] Load email list from inbox
[ ] Display email subjects/senders correctly
[ ] Handle network delays gracefully
[ ] Show error messages for failed connections
```

### Phase 4: Rule Application (15-20 minutes)
```
[ ] Load YAML configuration file (rules.yaml)
[ ] Parse rules without errors
[ ] Display loaded rules in UI
[ ] Process test emails against rules
[ ] Show matched rules and actions
[ ] Log actions correctly in test mode
```

### Phase 5: Scan Modes (10-15 minutes)

#### Readonly Mode
```
[ ] Can initiate scan in readonly mode
[ ] Actions are logged but not executed
[ ] Email inbox unchanged after scan
[ ] Results show proposed actions
```

#### Test Limit Mode
```
[ ] Can set action limit (e.g., 5 emails)
[ ] Scan respects the limit
[ ] Stops processing after limit reached
[ ] Shows limit reached notification
```

#### Test All Mode
```
[ ] Can initiate full scan
[ ] Processes all emails in folder
[ ] Records actions for all matches
[ ] Shows final action count
```

### Phase 6: Error Handling (10 minutes)
```
[ ] Network disconnection handled gracefully
[ ] Invalid credentials rejected properly
[ ] Missing files show helpful error messages
[ ] Malformed YAML shows parsing error
[ ] App does not crash on unexpected input
```

### Phase 7: Performance (10 minutes)
```
[ ] App starts in < 5 seconds
[ ] Scanning 100 emails completes in < 3 seconds
[ ] Batch operations don't freeze UI
[ ] Memory usage stays below 200MB
[ ] No memory leaks after repeated operations
```

### Phase 8: Windows Integration (5 minutes)
```
[ ] Taskbar shows app correctly
[ ] Window can be minimized/maximized
[ ] Window resize works smoothly
[ ] Multi-monitor support (if available)
[ ] Keyboard shortcuts work
```

## Common Issues & Solutions

### Issue: Application won't launch
**Solution:** 
```powershell
flutter clean
flutter pub get
flutter run -d windows --verbose
```

### Issue: Visual Studio build tools missing
**Solution:**
```powershell
# Install Visual Studio Community 2022 with C++ development tools
# Or update existing installation: 
flutter doctor -v  # Check what's missing
```

### Issue: Gmail authentication fails
**Solution:**
- Ensure you have a valid Google account
- Check internet connection
- Clear browser cookies if OAuth flow broken
- Try in incognito mode

### Issue: Rules file not found
**Solution:**
- Place `rules.yaml` in project root or specify path in UI
- Ensure file is valid YAML format
- Check file permissions (readable)

### Issue: High memory usage
**Solution:**
- Restart application
- Close other applications
- Check for infinite loops in rule processing
- Monitor with Task Manager (Ctrl+Shift+Esc)

## Manual Testing Scenarios

### Scenario 1: First Time User
1. Launch application
2. See sign-in screen
3. Click sign-in button
4. Complete OAuth flow
5. Return to app - see authenticated state
6. Navigate to main UI

### Scenario 2: Rule Configuration
1. Launch app (already signed in)
2. Open settings/configuration
3. Load `rules.yaml` file
4. View loaded rules
5. Modify a rule (optional)
6. Save changes

### Scenario 3: Email Scanning
1. Launch app
2. Navigate to scan section
3. Select readonly mode
4. Start scan on Inbox (last 7 days)
5. Watch progress as emails are processed
6. View results showing matched rules
7. Verify no actual changes to inbox

### Scenario 4: Action Review & Revert
1. Complete email scan
2. Review proposed actions
3. Note action counts
4. Test revert functionality (if available)
5. Verify inbox returned to original state

## Debugging Tips

### Enable Verbose Logging
```powershell
flutter run -d windows --verbose
```

### Run with Console Output
```powershell
flutter run -d windows -v 2>&1 | Tee-Object debug.log
```

### Attach Debugger
```powershell
# Use VS Code with Dart/Flutter extensions:
# Open project in VS Code and press F5 to debug
```

### Monitor Performance
```powershell
# Use Windows Task Manager:
# Ctrl+Shift+Esc > Performance tab
# Monitor CPU, Memory, Disk for app process
```

## Test Report Template

```
TEST REPORT - WINDOWS APPLICATION
==================================

Date: [TODAY]
Tester: [YOUR NAME]
Build: [COMMIT HASH]
Duration: [TIME SPENT]

RESULTS SUMMARY
===============
Total Tests: 8 phases
Passed: [ ]
Failed: [ ]
Blocked: [ ]

PHASE RESULTS
=============
Phase 1 (Startup): [ ] Pass [ ] Fail [ ] Partial
Phase 2 (Auth):    [ ] Pass [ ] Fail [ ] Partial
Phase 3 (Email):   [ ] Pass [ ] Fail [ ] Partial
Phase 4 (Rules):   [ ] Pass [ ] Fail [ ] Partial
Phase 5 (Scan):    [ ] Pass [ ] Fail [ ] Partial
Phase 6 (Error):   [ ] Pass [ ] Fail [ ] Partial
Phase 7 (Perf):    [ ] Pass [ ] Fail [ ] Partial
Phase 8 (Win):     [ ] Pass [ ] Fail [ ] Partial

ISSUES FOUND
============
1. [Description]
   Severity: [ ] Critical [ ] Major [ ] Minor
   Steps to Reproduce:
   Expected: 
   Actual:

NOTES & OBSERVATIONS
====================
[Any additional findings]

RECOMMENDATIONS
===============
[Next steps and improvements]
```

## Advanced Testing

### Stress Testing
```powershell
# Load large YAML file with many rules
# Process large batch of emails (1000+)
# Monitor resource usage
# Verify graceful degradation
```

### Security Testing
```
[ ] Check secure storage of credentials
[ ] Verify OAuth token not logged
[ ] Ensure config files permissions correct
[ ] Check for SQL injection in rule parsing
[ ] Validate input sanitization
```

### Regression Testing
Run all unit tests before Windows testing:
```powershell
cd mobile-app
flutter test
```

Should show: **79 tests passing** ✓

## When You're Done

1. Close the application properly
2. Note any issues found
3. Compare results with previous builds
4. Report critical issues immediately
5. Update WINDOWS_TEST_PLAN.md with findings
6. Commit test results to repository

## Support

For detailed Windows build info:
```powershell
flutter doctor -v
```

For specific errors:
```powershell
flutter run -d windows --verbose 2>&1 | Out-File error.log
# Share error.log for debugging
```

