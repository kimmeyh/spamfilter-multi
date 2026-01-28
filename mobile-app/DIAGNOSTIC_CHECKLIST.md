# Diagnostic Testing Checklist

**Issue**: AOL "Bulk Mail Testing" folder showing 0/335 rule matches
**Goal**: Capture device logs to identify root cause

---

## Pre-Test Checklist

### Setup (5 minutes)
- [ ] Have PowerShell window open in `mobile-app/scripts/` directory
- [ ] Android device or emulator connected (or will connect it now)
- [ ] `adb devices` shows your device (if not, it will wait for it)
- [ ] Android app built and installed with latest diagnostic code

### Latest Code (Important!)
- [ ] If you haven't rebuilt recently, pull latest: `git pull origin feature/20260127_Sprint_7`
- [ ] Diagnostic code in these commits:
  - `307b747` - Initial diagnostic logging
  - `b066679` - Diagnostic test procedure
  - `83c1588` - Java desugaring fix
  - `8b34b63` - Diagnostic tools and guides (just committed)

---

## Test Execution (15 minutes)

### Step 1: Start Log Capture
```powershell
cd mobile-app/scripts
.\capture-diagnostic-logs.ps1 -Action Start
```

**Expected output**:
```
[HH:MM:SS] Device found: emulator-5554
[HH:MM:SS] Clearing previous logs...
[HH:MM:SS] Starting log capture to: diagnostic_bulk_mail_YYYYMMDD_HHMMSS.log
[HH:MM:SS] Log capture started (Process ID: 12345)

Next Steps:
1. In the app, go to: Account Selection → Select kimmeyharold@aol.com
2. Click 'Start Live Scan' (NOT Demo Scan)
3. Select 'Bulk Mail Testing' folder
4. Wait for scan to complete or process ~20 emails
5. Once done, run: .\capture-diagnostic-logs.ps1 -Action Stop
```

- [ ] Log capture started successfully
- [ ] Log file being created (filename shown above)
- [ ] No errors in startup

### Step 2: Run Scan in App
In your Android app:
- [ ] App loaded and ready
- [ ] Navigate to Account Selection screen
- [ ] Select kimmeyharold@aol.com account (AOL IMAP)
- [ ] Click "Start Live Scan" button (NOT "Demo Scan")
- [ ] Select "Bulk Mail Testing" folder (or "Bulk Mail" or similar)
- [ ] Wait for scan to complete or at least 20 emails processed
- [ ] Note the results shown on app:
  - [ ] Scan mode: ____________________
  - [ ] Total found: ____________________
  - [ ] Rules matched: ____________________
  - [ ] No rules matched: ____________________

### Step 3: Stop Log Capture
Once scan is done, in PowerShell:
```powershell
.\capture-diagnostic-logs.ps1 -Action Stop
```

**Expected output**:
```
[HH:MM:SS] Stopping log capture process (PID: 12345)...
[HH:MM:SS] Log capture stopped.
[HH:MM:SS] Log file: diagnostic_bulk_mail_YYYYMMDD_HHMMSS.log

======================================================================
                      DIAGNOSTIC SUMMARY
======================================================================

=== SCAN DIAGNOSTICS ===
[actual diagnostic output here]

etc...
```

- [ ] Log capture stopped successfully
- [ ] Analysis output shown
- [ ] Diagnostic summary visible

---

## Results Interpretation

### Note the Key Numbers

From the analysis output, find and record these:

**From "DIAGNOSTIC SUMMARY" section**:
- [ ] Rules loaded: __________ (expected: 40-50+)
- [ ] First rule enabled: __________ (expected: true)
- [ ] Safe senders loaded: __________

**From "RULE MATCHES" section**:
- [ ] ✓ Matched count: __________ (expected: most of 335)
- [ ] ✗ No Match count: __________ (should = 335 - matched)

**From "ERRORS AND WARNINGS" section**:
- [ ] Any errors?: __________ (expected: No errors found)

---

## Quick Diagnosis

Based on your numbers above, identify the issue:

### If "Rules loaded: 0"
```
❌ PROBLEM A: Database Empty
├─ Cause: Migration didn't run or YAML files missing
├─ Fix time: 15-30 minutes
└─ Action: Claude will fix database initialization
```

### If "Rules loaded: 47+, First rule enabled: false"
```
❌ PROBLEM B: Rules Disabled
├─ Cause: All rules have enabled flag = 0
├─ Fix time: 5-15 minutes
└─ Action: Claude will enable rules in database
```

### If "Rules loaded: 47+, First rule enabled: true, ✓ Matched: 0"
```
❌ PROBLEM C: Content Mismatch
├─ Cause: Rules don't match Bulk Mail email headers/content
├─ Fix time: 30-60 minutes
└─ Action: Claude will debug rule patterns
```

### If "✓ Matched: 200+ out of 335"
```
✅ WORKING CORRECTLY
├─ Status: System functioning as designed
├─ Next: Review which emails aren't matching
└─ Action: Identify and improve non-matching rules
```

---

## Sharing Results with Claude

After running the test:

### Option A: Share the Analysis Output (Easiest)
Just paste the terminal output from Step 3 (the "DIAGNOSTIC SUMMARY" section)

### Option B: Share the Raw Log File (Most Detailed)
The log file is created in `mobile-app/scripts/`:
- File pattern: `diagnostic_bulk_mail_YYYYMMDD_HHMMSS.log`
- Example: `diagnostic_bulk_mail_20260128_143022.log`

### Option C: Run Custom Analysis
If you want to look deeper yourself:
```powershell
.\capture-diagnostic-logs.ps1 -Action Analyze -LogFile "diagnostic_bulk_mail_20260128_143022.log"
```

---

## Troubleshooting This Test

### Problem: "adb not found in PATH"
- [ ] Install Android SDK tools
- [ ] Add to PATH: `C:\Users\<username>\AppData\Local\Android\Sdk\platform-tools`
- [ ] Restart PowerShell

### Problem: "No devices detected"
- [ ] Connect Android device or start emulator
- [ ] Run `adb devices` to verify connection
- [ ] Script will wait for device if none connected

### Problem: Log file is empty
- [ ] Scan may not have started
- [ ] Check if app was actually running the scan
- [ ] Verify device still connected (`adb devices`)

### Problem: "Rules loaded: 0" is expected
- [ ] If you're seeing other issues, skip the checklist and share the output
- [ ] All outputs are valid data for diagnosis

---

## Questions or Issues?

Refer to these docs:
- **Quick start**: See `../../DIAGNOSTIC_TEST_PROCEDURE.md`
- **Log interpretation**: See `../../DIAGNOSTIC_LOG_INTERPRETATION.md`
- **Technical details**: See `../../INVESTIGATION_RULES_ZERO_MATCHES.md`
- **Full overview**: See `../../INVESTIGATION_READY_FOR_TESTING.md`

---

## Estimated Timeline

- **Test execution**: 15 minutes
- **Analysis**: 2-3 minutes (Claude)
- **Fix implementation**: 15-60 minutes (Claude) depending on issue type
- **Verification**: 5-10 minutes (you, re-run test)

**Total**: ~1-2 hours for complete resolution

---

**Ready! Start with Step 1 when you're prepared to run the test.**
