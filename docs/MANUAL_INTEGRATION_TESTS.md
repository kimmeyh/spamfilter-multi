# Manual Integration Testing Guide

**Purpose**: Document the manual integration testing procedures conducted before PR approval to verify cross-platform functionality and user workflows.

**When to Conduct**: After Phase 3.2 (automated tests pass) and before Phase 4.5 completes (user approval of PR).

**Scope**: This guide covers testing scenarios for the current sprint features on both Windows desktop and Android platforms.

---

## Overview

Manual integration testing verifies that:
1. Features work as expected across platforms
2. No regressions in existing functionality
3. UI/UX flows are intuitive and responsive
4. Database persistence works correctly
5. Edge cases are handled gracefully

---

## Platform-Specific Setup

### Windows Desktop

**Prerequisites**:
- Flutter environment configured for Windows
- Mobile app repository cloned locally
- Secrets configured in `mobile-app/secrets.dev.json`

**Build Instructions**:
```powershell
# Navigate to scripts directory
cd mobile-app/scripts

# Build and run Windows app (clean build with secrets injection)
.\build-windows.ps1

# App launches in debug mode
# Check console output for any errors or warnings
```

**What Happens**:
- Clean rebuild of Windows desktop app
- Secrets injected at build time (Gmail credentials, AOL credentials)
- App launches in debug mode on local Windows desktop
- Console shows detailed logging output

**Troubleshooting**:
- If app fails to launch: Check `build-windows.ps1` output for errors
- If database errors appear: Verify FFI initialization in main.dart
- If credentials missing: Verify `secrets.dev.json` configured correctly

### Android Emulator

**Prerequisites**:
- Android emulator running (or physical device connected)
- `build-with-secrets.ps1` script configured
- Google Play Services available on emulator

**Build Instructions**:
```powershell
# Navigate to scripts directory
cd mobile-app/scripts

# Build, install, and run on emulator
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -Run

# App launches on emulator
```

---

## Test Scenarios

### Scenario 1: Account Management

**Objective**: Verify account addition and selection works correctly.

**Test Steps**:

1. **Fresh Start**
   - [ ] App launches to Account Selection screen
   - [ ] "Add Account" button visible and clickable
   - [ ] No accounts shown (clean state)

2. **Add Gmail Account**
   - [ ] Click "Add Account"
   - [ ] Select "Gmail" from provider list
   - [ ] OAuth flow initiates (browser or WebView opens)
   - [ ] Sign in with test Gmail account
   - [ ] Redirected back to app
   - [ ] Account appears in list with email address

3. **Add IMAP Account (AOL/Yahoo)**
   - [ ] Click "Add Account"
   - [ ] Select "AOL" or "Yahoo" from provider list
   - [ ] Enter email and app password
   - [ ] "Add Account" button submits credentials
   - [ ] Account appears in list
   - [ ] Folder discovery completes (progress shown)

4. **Account Persistence**
   - [ ] Restart app
   - [ ] Accounts still visible in list
   - [ ] No re-authentication required

**Pass Criteria**:
- [ ] All accounts visible after restart
- [ ] No authentication loops
- [ ] Account cards display correctly

**Failure Notes**:
- Document any account that fails to add
- Note any OAuth/IMAP errors
- Record any persistence issues

---

### Scenario 2: Manual Scan Execution

**Objective**: Verify scan workflow completes successfully with accurate counts.

**Test Steps**:

1. **Select Account and Scan Options**
   - [ ] Click an account to scan
   - [ ] Scan Progress screen appears
   - [ ] Scan mode selector visible (ReadOnly, SafeSendersOnly, FullScan)
   - [ ] Folder selection shows available folders
   - [ ] INBOX selected by default

2. **Start Scan**
   - [ ] Click "Start Live Scan" button
   - [ ] Confirm scan options in dialog
   - [ ] Scan progress indicators appear:
     - [ ] Status changes to "Scanning in progress"
     - [ ] Progress bubbles update in real-time
     - [ ] Found count increments with emails
     - [ ] Processed count shows evaluation results

3. **Scan Completion**
   - [ ] Scan completes without errors
   - [ ] Final counts displayed:
     - [ ] Found (total emails scanned)
     - [ ] Deleted (proposed deletes)
     - [ ] Moved (proposed moves)
     - [ ] Safe Senders (whitelisted)
     - [ ] No Rule (unmatched)
     - [ ] Errors (failed evaluations)
   - [ ] All counts are non-negative
   - [ ] Sum of categories matches total found

4. **Results Display**
   - [ ] Auto-navigate to Results screen (or manual tap)
   - [ ] Results show email address in title
   - [ ] Scan mode displayed in summary
   - [ ] Bubble row matches Scan Progress (7 bubbles, colors correct)

**Pass Criteria**:
- [ ] Scan completes without hanging
- [ ] All counts are accurate
- [ ] Results display correctly

**Failure Notes**:
- Document any scanning errors
- Note incorrect counts
- Record any UI freezes or hangs

---

### Scenario 3: Results Review and Navigation

**Objective**: Verify results can be reviewed and navigated correctly.

**Test Steps**:

1. **View Results**
   - [ ] Results screen displays
   - [ ] Summary shows scan mode
   - [ ] Email list visible
   - [ ] "Back to Accounts" button works (navigates to Account Selection)

2. **Search and Filter (if applicable)**
   - [ ] Search functionality available for searches by from/subject
   - [ ] Results update as you search
   - [ ] Results can be sorted

3. **Navigation Back**
   - [ ] Click "Back to Accounts"
   - [ ] Returns to Account Selection screen (not Scan Progress)
   - [ ] Accounts list refreshed if new accounts added

**Pass Criteria**:
- [ ] Results display completely
- [ ] Navigation works bidirectionally
- [ ] No crashes during navigation

**Failure Notes**:
- Document any missing data in results
- Note navigation errors
- Record any crashes

---

### Scenario 4: Database Persistence (Platform-Specific)

**Objective**: Verify data persists correctly across app restarts.

**Test Steps**:

1. **Windows Desktop**
   - [ ] Add an account via OAuth/IMAP
   - [ ] Run a scan
   - [ ] Note the results (counts, folders scanned)
   - [ ] Close the app completely
   - [ ] Rebuild and relaunch: `.\build-windows.ps1`
   - [ ] App launches to Account Selection
   - [ ] Previously added account is visible
   - [ ] Scan history available (if feature implemented)

2. **Android**
   - [ ] Add an account via OAuth/IMAP
   - [ ] Run a scan
   - [ ] Note the results
   - [ ] Force stop app (Settings > Apps > App Name > Force Stop)
   - [ ] Relaunch app
   - [ ] Previously added account is visible
   - [ ] Data persists correctly

**Pass Criteria**:
- [ ] Accounts persist across restarts
- [ ] No data loss
- [ ] Clean startup (no initialization errors)

**Failure Notes**:
- Document any missing accounts after restart
- Note any database errors in logs
- Record any data corruption

---

### Scenario 5: Error Handling

**Objective**: Verify graceful error handling in edge cases.

**Test Steps**:

1. **Network Errors**
   - [ ] Disable network/WiFi
   - [ ] Attempt to add IMAP account
   - [ ] Error message displayed (not crash)
   - [ ] App remains responsive
   - [ ] Re-enable network
   - [ ] Can retry and succeed

2. **Invalid Credentials**
   - [ ] Try to add account with wrong password
   - [ ] Error message shown
   - [ ] Can retry with correct credentials
   - [ ] No data corruption

3. **Large Inbox Scan**
   - [ ] Scan an inbox with 1000+ emails (if available)
   - [ ] Progress shown smoothly
   - [ ] No UI freezes
   - [ ] Counts accurate
   - [ ] Completes in reasonable time (<5 minutes)

**Pass Criteria**:
- [ ] All errors handled gracefully
- [ ] User informed of issues
- [ ] App remains responsive
- [ ] No crashes on invalid input

**Failure Notes**:
- Document any unhandled errors
- Note any crashes
- Record any hangs or freezes

---

## Console Logging (Windows Desktop)

While running Windows app via `build-windows.ps1`, monitor the console output:

**Good Signs**:
```
[INFO] App initialized successfully
[INFO] Database factory initialized (FFI)
[INFO] Loaded N safe sender patterns from database
[INFO] Rule set loaded: M rules, N safe senders
```

**Red Flags**:
```
[ERROR] Database initialization failed
[ERROR] OAuth token expired
[ERROR] TLS certificate validation failed
[WARN] Regex pattern compilation failed
```

---

## Cross-Platform Checklist

Before closing manual testing, verify:

- [ ] **Windows Desktop**
  - [ ] App builds without errors
  - [ ] All features function
  - [ ] No console warnings or errors
  - [ ] Database initializes cleanly

- [ ] **Android**
  - [ ] App installs and launches
  - [ ] All features function
  - [ ] No logcat errors
  - [ ] Database operations work

- [ ] **Both Platforms**
  - [ ] Accounts persist across restarts
  - [ ] Scan workflow complete
  - [ ] Results display correctly
  - [ ] Navigation works bidirectionally
  - [ ] Error handling graceful

---

## Sprint-Specific Test Focus

Each sprint may have specific areas to focus on. Update this section as needed:

### Sprint 4 (Database & Results)
- Verify scan results saved to database
- Verify unmatched emails persist
- Verify availability checking works

### Sprint 5 (Documentation & Workflow)
- Verify parallel testing workflow functions
- Verify new Phase 4.5 documentation is clear
- Verify Windows build executes cleanly

### Sprint 6+ (Future)
- Update this section with sprint-specific test areas

---

## Reporting Issues

If you find issues during manual testing:

1. **Document the Issue**
   - Platform (Windows / Android)
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshot/log if applicable

2. **Create GitHub Issue** (if not already reported)
   - Title: Brief description
   - Labels: `bug`, `platform:windows` or `platform:android`
   - Link to related sprint card if applicable

3. **Notify Claude Code**
   - Share issue details
   - Indicate if it blocks PR approval
   - Request fix or follow-up sprint task

---

## Quick Reference

| Scenario | Platform | Time | Status |
|----------|----------|------|--------|
| Account Management | Both | 10 min | |
| Manual Scan | Both | 15 min | |
| Results Review | Both | 5 min | |
| Persistence | Both | 10 min | |
| Error Handling | Windows | 5 min | |
| **Total** | | **45 min** | |

---

## Document Version

**Version**: 1.0
**Created**: January 26, 2026
**Last Updated**: January 26, 2026 (Sprint 5)
**Status**: Ready for use in Sprint 6+

**References**:
- `SPRINT_EXECUTION_WORKFLOW.md` - Phase 4.5 calls this document
- `CLAUDE.md` - Project overview and setup
- `mobile-app/README.md` - App-specific quick start
