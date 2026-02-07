# Troubleshooting Guide

**Purpose**: Document common issues and solutions for the spamfilter-multi project.

**Audience**: All contributors (Claude Code models, developers)

**Last Updated**: January 31, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** (this doc) | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |
| **WINDOWS_DEVELOPMENT_GUIDE.md** | Windows shell, Unicode, PowerShell | When encountering Windows-specific issues |

---

## Quick Reference: Windows Issues

For comprehensive Windows development guidance, see **`docs/WINDOWS_DEVELOPMENT_GUIDE.md`**.

**Common Quick Fixes**:
- **Unicode errors**: Set `$env:PYTHONIOENCODING = 'utf-8'` before running Python
- **Path errors in bash**: Use PowerShell for Windows paths, or forward slashes in bash
- **PowerShell cmdlets in bash**: Use PowerShell, not bash, for `Get-Process`, `Stop-Process`, etc.
- **Build executable locked**: Run `Stop-Process -Name "spam_filter_mobile" -Force`

---

## Overview

Common issues and solutions for the Spam Filter application.

---

## Common Development Errors

### Test Binding Not Initialized

**Error Message**:
```
MissingPluginException: No implementation found for method ...
```
or
```
ServicesBinding.defaultBinaryMessenger was accessed before the binding was initialized.
```

**Cause**: Flutter test bindings not initialized before accessing platform channels or widgets.

**Solution**: Add `TestWidgetsFlutterBinding.ensureInitialized()` at the start of your test.

**Example**:
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Add this line

  test('should initialize database', () async {
    final store = SafeSenderDatabaseStore();
    await store.initialize();
    expect(store.isInitialized, isTrue);
  });
}
```

**Pre-Flight Checklist**: Before creating tests, verify binding initialization is included in template.

---

### AppLogger Parameter Mismatch

**Error Message**:
```
The argument type 'String' can't be assigned to the parameter type 'Object'
```
or
```
Too many positional arguments: 1 expected, but 2 found
```

**Cause**: AppLogger methods have different signatures. `warning()` takes only message, `error()` takes message + error + stackTrace.

**API Reference**:
```dart
// [OK] CORRECT usage
AppLogger.warning('This is a warning');
AppLogger.error('Error occurred', error, stackTrace);
AppLogger.debug('Debug message');
AppLogger.scan('Scanning 150 emails');
AppLogger.email('Fetched email from sender@example.com');

// [FAIL] INCORRECT usage
AppLogger.warning('Warning', someObject);  // warning() takes only 1 parameter
AppLogger.error('Error');  // error() requires error and stackTrace parameters
```

**Solution**: Check AppLogger method signatures:
- `warning(String message)` - 1 parameter
- `error(String message, Object error, StackTrace stackTrace)` - 3 parameters
- All other methods: `methodName(String message)` - 1 parameter

---

### Windows Path in Grep

**Error Message**:
```
Grep pattern failed to match: D:\path\to\file
```
or
```
No matches found (expected matches on Windows)
```

**Cause**: Windows path separators (`\`) in grep patterns are interpreted as escape characters.

**Solution**: Use forward slashes (`/`) in grep patterns, even on Windows. Grep/ripgrep normalizes paths internally.

**Example**:
```bash
# [FAIL] INCORRECT: Backslashes cause issues
grep -r "D:\\Data\\Harold\\github" .

# [OK] CORRECT: Use forward slashes on all platforms
grep -r "D:/Data/Harold/github" .

# [OK] CORRECT: Use relative paths when possible
grep -r "docs/SPRINT" .
```

**Cross-Platform Patterns**: Always use `/` (forward slash) in file paths for grep patterns, even on Windows. This works correctly on all platforms (Windows, Linux, macOS).

---

### Windows Backslash Paths in Bash Commands

**Error Message**:
```bash
bash: cd: D:DataHaroldgithubspamfilter-multimobile-app: No such file or directory
```
or
```bash
/usr/bin/bash: line 1: cd: D:DataHaroldgithubspamfilter-multimobile-app: No such file or directory
```

**Cause**: Bash cannot handle Windows backslash paths - backslashes are escape characters in Bash.

**Root Cause**: Using Bash for Windows commands instead of PowerShell (violates CLAUDE.md Section 259-261).

**Solution**: ALWAYS use PowerShell for Windows paths, NEVER wrap PowerShell in Bash.

**Examples**:
```powershell
# [CORRECT] Direct PowerShell execution
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'D:\Data\Harold\github\spamfilter-multi\mobile-app'; flutter test"

# [WRONG] Wrapping PowerShell in Bash
bash -c "powershell -Command 'cd D:\Data\...; flutter test'"  # Loses VSCode terminal context

# [CORRECT] Using forward slashes in Bash (if Bash is required)
bash -c "cd /d/Data/Harold/github/spamfilter-multi/mobile-app && flutter test"

# [BEST] Use PowerShell directly for all Windows commands
```

**Why This Matters**:
- Wrapping PowerShell in Bash loses VSCode terminal environment variables
- Flutter toolchain context is not available in Bash-wrapped PowerShell
- Build scripts fail with "flutter not found" or similar errors

**Policy**: See CLAUDE.md Section 259-261 - "This project uses PowerShell as the primary shell environment on Windows"

---

### PowerShell Switch Parameter Syntax Error

**Error Message**:
```powershell
build-windows.ps1 : Cannot process argument transformation on parameter 'RunAfterBuild'.
Cannot convert the "0" value of type "System.Int32" to type "System.Management.Automation.SwitchParameter".
At line:1 char:108
+ ... .\build-windows.ps1 -RunAfterBuild:0
+                                        ~
```

**Cause**: PowerShell switch parameters require `$true`/`$false`, not `0`/`1`.

**Solution**: Use correct Boolean syntax for switch parameters.

**Examples**:
```powershell
# [CORRECT] PowerShell switch parameter syntax
.\build-windows.ps1 -RunAfterBuild:$true   # Enable flag
.\build-windows.ps1 -RunAfterBuild:$false  # Disable flag
.\build-windows.ps1 -RunAfterBuild         # Enable flag (shorthand when true)

# [WRONG] Using integers
.\build-windows.ps1 -RunAfterBuild:0       # ERROR - cannot convert Int32 to Switch
.\build-windows.ps1 -RunAfterBuild:1       # ERROR - cannot convert Int32 to Switch
```

**Quick Reference Table**:
| Intent | Correct Syntax | Wrong Syntax |
|--------|---------------|--------------|
| Enable flag | `-RunAfterBuild:$true` or `-RunAfterBuild` | `-RunAfterBuild:1` |
| Disable flag | `-RunAfterBuild:$false` | `-RunAfterBuild:0` |
| String parameter | `-BuildType debug` | `-BuildType:debug` (colon not needed) |
| Integer parameter | `-Timeout 5000` | `-Timeout:5000` (colon not needed) |

**Common Build Script Parameters**:
```powershell
# build-windows.ps1
.\build-windows.ps1                                    # Default: RunAfterBuild=$true
.\build-windows.ps1 -RunAfterBuild:$false              # Build without running
.\build-windows.ps1 -Clean:$false                      # Skip clean step

# build-with-secrets.ps1
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
.\build-with-secrets.ps1 -BuildType release -Run
```

**PowerShell Parameter Types**:
- **Switch**: Boolean flag (`$true`/`$false`) - Use colon syntax: `-Flag:$true`
- **String**: Text value - No colon: `-Name "value"`
- **Integer**: Number value - No colon: `-Count 10`

---

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

### Android Gmail Sign-In: "Sign in was cancelled"

**Root Cause**: SHA-1 fingerprint not registered in Firebase Console.

**Fix**: Extract SHA-1 (`mobile-app/android/get_sha1.bat`), add to Firebase Console, download fresh `google-services.json`, rebuild.

**Guide**: `ANDROID_GMAIL_SIGNIN_QUICK_START.md`

### Windows Gmail OAuth: "client_secret is missing"

**Root Cause**: `secrets.dev.json` missing or incomplete.

**Fix**: Ensure `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` is in `secrets.dev.json`, rebuild with `build-windows.ps1`.

**Guide**: `WINDOWS_GMAIL_OAUTH_SETUP.md`

### Norton Antivirus Blocks IMAP

**Symptom**: "TLS certificate validation failed" when adding AOL/Yahoo accounts.

**Root Cause**: Norton's "Email Protection" intercepts TLS connections.

**Fix**: Disable Norton Email Protection in Settings → Security → Advanced → Intrusion Prevention.

**Verify**:
```powershell
python -c "import socket, ssl; ctx = ssl.create_default_context(); s = ctx.wrap_socket(socket.socket(), server_hostname='imap.aol.com'); s.connect(('imap.aol.com', 993)); print('OK:', s.version())"
```

---

## Scanning Issues

### Phase 3.2 Folder Selection Fixes (Issue #35)

**Status**: [OK] COMPLETE (Jan 5, 2026)

**Issue #35 - Folder Selection Not Scanning Selected Folders**:
- **Problem**: Selecting non-Inbox folders (e.g., "Bulk Mail") still only scanned Inbox
- **Root Cause**: Missing state management - `scanProvider.selectedFolders` was not being set
- **Solution**: Added `_selectedFolders` field to EmailScanProvider, connected UI callback to `setSelectedFolders()`, pass to scanner
- **Files Modified**: `email_scan_provider.dart`, `scan_progress_screen.dart`

**Navigation Fix - Auto-Navigation Race Condition**:
- **Problem**: Returning to Scan Progress from Account Selection caused unwanted auto-navigation to Results
- **Root Cause**: `_previousStatus` was null on first build but scan status was completed
- **Solution**: Initialize `_previousStatus` in `initState()` before first build
- **Files Modified**: `scan_progress_screen.dart`

### Phase 3.3 Enhancement Features (Issues #36, #37)

**Status**: [OK] COMPLETE (Jan 5-6, 2026)

**Issue #36 - Progressive UI Updates**:
- **Problem**: UI updated for every email, causing performance issues with large scans
- **Solution**: Throttle updates to every 10 emails OR 3 seconds (whichever comes first)
- **Implementation**: Added `_lastProgressNotification`, `_emailsSinceLastNotification` fields
- **Files Modified**: `email_scan_provider.dart`

**Issue #37 - Dynamic Folder Discovery**:
- **Problem**: Folder selection limited to hardcoded lists
- **Solution**: Call `provider.listFolders()` dynamically, added search/filter UI, loading states
- **Features**: Gmail label discovery via API, IMAP folder listing, "Recommended" badges
- **Files Modified**: `folder_selection_screen.dart`

**Gmail Token Refresh Fix**:
- **Problem**: 401 errors when selecting folders with expired OAuth tokens
- **Solution**: Use `GoogleAuthService.getValidAccessToken()` instead of stored tokens directly
- **Impact**: Seamless token refresh, no manual re-authentication needed

**Gmail Header Format Fix**:
- **Problem**: Gmail emails not matching rules due to "Name <email>" format vs just "email"
- **Solution**: Added `_extractEmail()` helper to parse email from header format
- **Files Modified**: `gmail_api_adapter.dart`

**Counter Accumulation Bug Fix**:
- **Problem**: "No Rules" count accumulated across scans (showed impossible values)
- **Solution**: Reset `_noRuleCount = 0` in `startScan()` method
- **Files Modified**: `email_scan_provider.dart`

**Claude Code MCP Tools**:
- Custom MCP server for email rule testing (`scripts/email-rule-tester-mcp/`)
- YAML validation script (`scripts/validate-yaml-rules.ps1`)
- Regex pattern tester (`scripts/test-regex-patterns.ps1`)
- 10 custom skills in `.claude/skills.json`
- 4 automated hooks in `.claude/hooks.json`

**Build Script Enhancements**:
- `-StartEmulator`: Auto-start Android emulator if none running
- `-EmulatorName`: Specify which AVD to launch
- `-SkipUninstall`: Preserve saved accounts during debug builds

---

## UI Issues

### Phase 3.1 UI/UX Enhancements (Issues #32-#34)

**Status**: [OK] COMPLETE (Jan 4, 2026)

**Issue #32 - Full Scan Mode and Persistent Selection**:
- Added `ScanMode.fullScan` (4th mode) - permanent delete/move operations
- Added persistent "Scan Mode" button on Scan Progress screen
- Removed scan mode pop-up from account setup flow (default to readonly)
- Added warning dialog for Full Scan mode (requires user confirmation)
- Updated `recordResult()` to distinguish revertible vs permanent actions
- Files Modified: `email_scan_provider.dart`, `account_setup_screen.dart`, `scan_progress_screen.dart`

**Issue #33 - Scan Progress Screen UI Redesign**:
- Removed redundant progress bar and processed count text
- Updated to 7-bubble row: Found (Blue), Processed (Purple), Deleted (Red), Moved (Orange), Safe (Green), No rule (Grey), Errors (Dark Red)
- Added auto-navigation to Results screen when scan completes
- Re-enabled buttons after scan completes (idle or completed status)
- Added scan mode to header: "Ready to scan - <mode>" / "Scan complete - <mode>"
- Files Modified: `scan_progress_screen.dart`

**Issue #34 - Results Screen UI Redesign**:
- Added `accountEmail` parameter (required) to show email in title
- Updated title format: "Results - <email> - <provider>"
- Updated summary format: "Summary - <mode>"
- Updated bubble row to match Scan Progress (7 bubbles with exact same colors)
- Made accountEmail required in ScanProgressScreen
- Files Modified: `results_display_screen.dart`, `scan_progress_screen.dart`

**Bubble Counts Fix**:
- **Problem**: In Read-Only mode, bubbles showed "Deleted: 0" even when rules evaluated emails for deletion
- **Solution**: Changed `recordResult()` to always increment counts based on rule evaluation (proposed actions), not just executed actions
- **Impact**: All scan modes now show what WOULD happen, making Read-Only mode useful for previewing results
- Files Modified: `email_scan_provider.dart`, `email_scan_provider_test.dart` (5 tests updated)

**No Rule Tracking**:
- Added `_noRuleCount` field and getter to EmailScanProvider
- Added "No rule" bubble (grey #757575) between "Safe" and "Errors"
- Tracks emails that did not match any rules (for future rule creation)
- Increments when `action == EmailActionType.none`
- Files Modified: `email_scan_provider.dart`, `scan_progress_screen.dart`, `results_display_screen.dart`

**Test Results**: 122/122 tests passing (13 skipped integration tests requiring credentials)

### Results Screen Navigation Not Returning to Account Selection

**Symptom**: "Back to Accounts" button on Results Display screen returned to Scan Progress screen instead of Account Selection screen.

**Root Cause**: Navigation stack was Account Selection → Scan Progress → Results Display. Using `Navigator.pop()` only popped one level back to Scan Progress.

**Fix Applied (Jan 1, 2026)**: Changed navigation to use `Navigator.popUntil(context, (route) => route.isFirst)` to pop all screens until reaching Account Selection screen.

**Files Modified**: `mobile-app/lib/ui/screens/results_display_screen.dart`

**Impact**: "Back to Accounts" button now correctly navigates directly to Account Selection screen.

### Scan Progress Status Updates Delayed

**Symptom**: After clicking "Start Live Scan" and confirming scan options, screen continued to show "Ready to scan" and "No results yet" until results actually started appearing.

**Root Cause**: Status only changed when `EmailScanner.scanInbox()` called `scanProvider.startScan()`, which happened after fetching emails from server.

**Fix Applied (Jan 1, 2026)**: Added immediate call to `scanProvider.startScan(totalEmails: 0)` right after dialog closes, before scanner runs.

**Files Modified**: `mobile-app/lib/ui/screens/scan_progress_screen.dart`

**Impact**: UI immediately updates to show "Scanning in progress" and replaces "No results yet" with progress indicator.

### Account Loading Flicker on Account Selection Screen

**Symptom**: When returning to Account Selection screen, account cards briefly flicker showing loading state (spinner) before displaying full account details.

**Root Cause**: FutureBuilder creates a new Future on every widget rebuild, causing it to show `ConnectionState.waiting` state even for already-loaded accounts.

**Fix Applied (Jan 1, 2026)**: Implemented caching system in `AccountSelectionScreen`:
- Added `Map<String, AccountDisplayData?> _accountDataCache` to store loaded account data
- Modified `_loadAccountDisplayData()` to return cached data immediately if available
- Background refresh via `_refreshAccountDataInBackground()` updates cache only when data changes
- Removed loading spinner state from FutureBuilder (always shows data immediately)
- Cache cleared when accounts are deleted

**Files Modified**: `mobile-app/lib/ui/screens/account_selection_screen.dart`

**Impact**: Accounts appear instantly when returning to screen, no visual flicker, still refreshes data in background to catch credential changes.

**Applies to**: All account types (Gmail OAuth, AOL IMAP, Yahoo IMAP)

### Account Selection Navigation and Refresh Issues

**Symptom**: After completing a scan and clicking "Back to Accounts" from Results Display screen, navigation went to Platform Selection instead of Account Selection, and account list did not refresh to show newly added accounts.

**Root Cause**: Delete handler used `Navigator.pushReplacement` to replace Account Selection with Platform Selection when last account was deleted (breaking navigation stack), and Account Selection screen only refreshed accounts on 2-second timer (not on navigation events).

**Fix Applied (Jan 2, 2026)**:
- Removed pushReplacement navigation from delete handler - Account Selection now stays in navigation stack and shows built-in "Add Account" UI when empty
- Added RouteObserver and RouteAware mixin to detect navigation events and refresh account list immediately when screen becomes visible
- Added global RouteObserver in main.dart
- Account Selection implements RouteAware mixin with didPopNext() callback

**Files Modified**: `mobile-app/lib/main.dart`, `mobile-app/lib/ui/screens/account_selection_screen.dart`

**Impact**: "Back to Accounts" correctly navigates to Account Selection (not Platform Selection), account list refreshes immediately when navigating back (no delay or empty state), navigation stack preserved correctly for all account deletion scenarios.

**Applies to**: All account types (Gmail OAuth, AOL IMAP, Yahoo IMAP)

---

## Git Issues

### Flutter Source Files Not Tracked by Git

**Symptom**: Dart files in `mobile-app/lib/` do not show as modified in git status or VSCode Source Control.

**Root Cause**: Root `.gitignore` had overly broad `lib/` exclusion (intended for Python lib directories) that also excluded Flutter's `mobile-app/lib/` source code directory.

**Fix Applied (Dec 30, 2025)**: Changed line 81-82 in root `.gitignore` from `lib/` to `Archive/desktop-python/lib/` to only exclude Python package directories.

**Impact**: All Flutter/Dart source code in `mobile-app/lib/` is now properly tracked by git.

**Note**: This was a mixed-repository issue where Python gitignore rules conflicted with Flutter project structure.

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
