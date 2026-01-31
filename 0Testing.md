***BELOW IS NOT FOR CLAUDE CODE USE***
***BELOW IS NOT FOR Github Copilot USE***

Common request for Claude Code for assisting with testing:
Can you build and run the Windows Desktop App using D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\build-windows.ps1 so I can do additional testing.  Please monitor "adb logcat" and other testing logs during testing.  When I provide feedback analyze my feedback and logs for any issues and errors; address as needed.

# Run flutter unit tests
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter test


#-------------------------------
# If need to do a full build and run for testing - Windows:
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-windows.ps1"


# Clean Build - Windows
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter clean;
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows
# ...then run
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter run -d windows

#-------------------------------
# If need to do a full build - Android.  Note this is preferred as it leaves the Terminal/process free to monitor the output log
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator  -StartEmulator"
# ...then run
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -Run"  # To run with debugger attached (hot reload + real-time logs)
# and monitor via
adb logcat # commands

# Other steps to find errors:
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get; flutter test"
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter analyze"

# If all tests passed, then before running re-build the app
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows

**Run Phase 1 Regression Tests Only:**
cd d:\Data\Harold\github\spamfilter-multi\mobile-app

# Test pattern compilation
flutter test test/unit/pattern_compiler_test.dart

# Test safe sender lists
flutter test test/unit/safe_sender_list_test.dart

# Test YAML file loading
flutter test test/integration/yaml_loading_test.dart

# Test complete workflows
flutter test test/integration/end_to_end_workflow_test.dart

#-------------------------------
12/28/25 updated testing checklist
Checklist

Verify current status
- Confirm tests pass and builds succeed per existing docs.
- Note current blockers from feedback (account list formatting, auth-state hinting, scan progress messaging/reset).
Run desktop app (Windows) for manual testing
- Build and run.
- Validate AccountSelection list/format and auth-state hinting.
- Validate ScanProgress immediate “in-progress” message and auto-reset on re-enter.
- Validate folder selection (Inbox + provider junk folders).
- Address desktop issues
- Ensure account list includes AOL/Gmail with: "<email> - <Provider> - <Auth Method>".
- If auth missing, still list account with “Add authentication” action linking to provider setup.
- Ensure ScanProgress auto-resets on page load/return; message updates as soon as scan starts.
Run Android app for manual testing
- Emulator launch, run or install APK.
- Validate AccountSelection (ensure kimmeyh@gmail.com appears if saved).
- Validate same scan progress behaviors.
- Address Android issues
- Same account-list formatting and auth-state hinting.
- Ensure Gmail account shows when stored; if not authenticated, list it and navigate user to auth flow.
Update documentation
  - D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
- memory-bank.json (quick ref/next actions/results).
- mobile-app-plan.md (immediate focus, pre-external testing acceptance, Phase 3 browser client).
- README.md (pre-external testing acceptance and test/build/run quick refs).

Desktop (Windows) manual test walkthrough

Build and run:
Terminal: PowerShell; always cd into project before commands.
Commands:
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get
flutter test
flutter analyze
flutter build windows
Start: build\windows\x64\runner\Debug\spam_filter_mobile.exe
Validate:
AccountSelection shows all saved Gmail/AOL accounts formatted: "<email> - <Provider> - <Auth Method>".
If auth missing: show account and “Add authentication” action linking to provider auth.
ScanProgress:
On Start Demo/Start Live: replace “No Results yet…” immediately with “Scan started…” message.
Returning to ScanProgress or after scan completes: screen auto-resets; Reset button no longer needed.
Folder selection: Inbox + provider junk folders available and selectable (multi-select with “Select All”).
Android manual test walkthrough

Emulator
cd d:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\run-emulator.ps1
Run debug: cd ..; flutter run -d emulator-5554
Or build APK: cd ..; flutter build apk --release; scripts\run-emulator.ps1 -InstallReleaseApk
Validate:
AccountSelection shows saved Gmail (e.g., kimmeyh@gmail.com). If auth missing, still list and allow “Add authentication”.
ScanProgress screen behaviors identical to desktop.
Folder multi-select works and includes provider junk folders.

Pre-12/17/25 testing checklist
Manual Testing Checklist (Desktop):
Account Setup
 Launch app successfully
 Select Gmail provider
 Enter Gmail credentials (OAuth flow)
 Browser OAuth method works
 WebView OAuth method works (fallback)
 Manual token entry works (fallback)
 Select AOL provider
 Enter AOL credentials (IMAP + app password)
 Verify credentials saved to Windows Credential Manager
Multi-Account Support
 Add second Gmail account
 Add second AOL account
 Switch between accounts
 Verify account list persists after restart
Email Scanning
 Select folders to scan (Inbox + Spam/Junk)
 Choose scan mode:
 Readonly (no modifications)
 Test Limit (limit to N emails)
 Test All (with revert capability)
 Start scan
 Monitor progress (total/processed/current)
 View results summary:
 Safe senders count
 Spam deleted count
 Emails moved count
 Errors (if any)
Rules Management
 View loaded rules (5 rules from rules.yaml)
 View safe senders (426 patterns from rules_safe_senders.yaml)
 Verify rules load from %APPDATA%\com.example\spam_filter_mobile\rules\
Revert Functionality (Test All Mode)
 Run scan in "Test All" mode
 Click "Revert Last Run" button
 Confirm revert action
 Verify emails restored from Trash/Junk