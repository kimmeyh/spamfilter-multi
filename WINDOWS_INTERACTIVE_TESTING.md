# Windows Application Interactive Testing Checklist

## Current Status
- ✅ Windows Application: **RUNNING**
- 📍 Location: Running on Windows 11
- 🔧 Dev Tools: **ACTIVE** at http://127.0.0.1:62201/
- 🎮 Interactive Mode: **READY**

---

## 🧪 Live Testing - Phase 5: Authentication Flow

The application window is now open on your screen. Follow these steps to test the Google OAuth authentication flow:

### Step-by-Step Authentication Test

#### Step 1: Locate the Sign-In Interface
- [ ] Find the account selection screen
- [ ] Look for "Sign In with Google" button or similar
- [ ] Note the current UI state

#### Step 2: Initiate Google Sign-In
- [ ] Click the sign-in button
- [ ] A browser window should open (usually)
- [ ] Google login page should appear

#### Step 3: Complete OAuth Flow
- [ ] Enter your test Google account email
- [ ] Enter your test Google account password
- [ ] Accept permission requests on Google's page
- [ ] Browser should redirect back to the app

#### Step 4: Verify Successful Authentication
- [ ] App window comes back to foreground
- [ ] Application shows authenticated state
- [ ] Your email address displays (if shown in UI)
- [ ] "Sign Out" button appears (if auth successful)

#### Step 5: Document Results
```
Sign-In Test Results:
- Browser redirect: [ ] Success [ ] Failed [ ] Timeout
- Permission grant: [ ] Yes [ ] No [ ] Skipped
- App receives token: [ ] Yes [ ] No [ ] Unknown
- UI updates: [ ] Yes [ ] No [ ] Partial
- Error messages: [ ] None [ ] Shown [ ] Unclear
```

---

## 🧪 Live Testing - Phase 6: Email Folder Navigation

Once authenticated, test email access:

#### Step 1: Check for Email UI
- [ ] Look for "Inbox", "Folders", or "Email" section
- [ ] Verify folder list displays
- [ ] Check for email count badges

#### Step 2: Select Inbox
- [ ] Click on "Inbox" folder
- [ ] Wait for email list to load
- [ ] Verify emails display with sender/subject

#### Step 3: Email Properties
- [ ] Check email has sender information
- [ ] Verify subject line visible
- [ ] Look for date/time
- [ ] Check for preview text (if available)

#### Step 4: Document Results
```
Email Access Test Results:
- Folder list loads: [ ] Yes [ ] No [ ] Slow
- Emails display: [ ] Yes [ ] No [ ] Partial
- Email count accurate: [ ] Yes [ ] Unsure [ ] No
- Performance: [ ] Fast [ ] Acceptable [ ] Slow
```

---

## 🧪 Live Testing - Phase 7: Rule Application in Readonly Mode

#### Step 1: Navigate to Scan Section
- [ ] Find "Scan", "Analysis", or similar section
- [ ] Look for mode selection (if visible)

#### Step 2: Select Readonly Mode (Safe for Testing)
- [ ] Select "Readonly" or "Simulation" mode
- [ ] Verify mode indicator shows "Readonly"
- [ ] Check that actions will be logged only

#### Step 3: Start Email Scan
- [ ] Click "Start Scan" or similar button
- [ ] Select "Last 7 days" for smaller dataset
- [ ] Monitor progress display

#### Step 4: Watch for Results
- [ ] Progress bar should advance
- [ ] Email count should increment
- [ ] Rules should be shown when matched

#### Step 5: Review Results
- [ ] Scan completion message appears
- [ ] Results summary shows:
  - [ ] Total emails processed
  - [ ] Rules matched
  - [ ] Actions that WOULD be taken
  - [ ] No actual changes to inbox

#### Step 6: Document Results
```
Readonly Scan Test Results:
- Mode selected: [ ] Yes [ ] No [ ] N/A
- Scan starts: [ ] Yes [ ] No [ ] Error
- Progress visible: [ ] Yes [ ] No [ ] Partial
- Results show: [ ] Yes [ ] No [ ] Timeout
- No inbox changes: [ ] Confirmed [ ] Unsure [ ] Failed
- Performance: _____ seconds for _____ emails
```

---

## 🚨 Issue Recording Template

If you encounter any issues, use this format:

```
ISSUE #: [Number]
SEVERITY: [ ] Critical [ ] Major [ ] Minor [ ] Info

TITLE:
[Brief description of issue]

STEPS TO REPRODUCE:
1. [First step]
2. [Second step]
3. [Etc.]

EXPECTED BEHAVIOR:
[What should happen]

ACTUAL BEHAVIOR:
[What actually happened]

SCREENSHOT/LOG:
[Paste any error messages or logs]

ENVIRONMENT:
- OS: Windows 11
- Build: Debug
- Commit: [Git commit hash if known]
- Time: [When it occurred]
```

---

## 📊 Real-Time Observations Checklist

### UI/UX Quality
- [ ] Window title clear and readable
- [ ] Buttons have clear labels
- [ ] Text is legible (font size, contrast)
- [ ] Icons are recognizable
- [ ] Layout is organized and logical
- [ ] No overlapping elements
- [ ] Responsive to clicks/hovers
- [ ] Colors are appropriate

### Performance Quality
- [ ] App responds immediately to clicks
- [ ] No stuttering or jank
- [ ] Smooth animations (if any)
- [ ] Loading indicators helpful
- [ ] No spinning/frozen UI
- [ ] Transitions between screens smooth

### Error Handling Quality
- [ ] Error messages are clear
- [ ] Error messages suggest solutions
- [ ] Errors don't crash the app
- [ ] User can retry failed actions
- [ ] Network errors handled gracefully
- [ ] Invalid input rejected appropriately

### Data Quality
- [ ] Email data displays correctly
- [ ] Rules parse without errors
- [ ] Metadata is accurate
- [ ] No missing or truncated data
- [ ] Timestamps are correct
- [ ] Counts are accurate

---

## 🎯 Success Criteria for This Session

- ✅ **Startup:** App launched successfully
- ⏳ **Authentication:** Complete OAuth flow (test now)
- ⏳ **Email Access:** View inbox emails (test now)
- ⏳ **Rule Testing:** Run readonly scan (test now)
- ⏳ **Error Handling:** Encounter and handle errors gracefully

---

## 🔍 Debugging While Testing

### If App Crashes
1. Check terminal window - it will show the error
2. Note the exact error message
3. Try hot restart: Press `R` in terminal
4. If restart fails, restart the app: `flutter run -d windows`

### If Something Seems Slow
1. Open DevTools: Click the VM Service URL in terminal
2. Go to "Performance" tab
3. Record a trace to see what's slow
4. Report the trace in issue

### If UI Looks Wrong
1. Check if it's a rendering issue:
   - Try window resize - does it redraw?
   - Try scrolling - any issues?
   - Try dark/light mode toggle (if available)
2. Take a screenshot for documentation
3. Note if it's consistent or intermittent

### To Get More Logs
1. In the terminal running the app, you already see logs
2. Search for errors: `Error`, `Exception`, `Failed`
3. Save terminal output: Ctrl+A, Ctrl+C to copy
4. Paste into a text file for documentation

---

## 📝 Testing Notes Template

```markdown
## Test Session: [Date & Time]
**Tester:** [Your name]
**Duration:** [Minutes spent]
**Build:** [Commit hash from git]

### Features Tested
- [ ] Authentication
- [ ] Email Loading
- [ ] Rule Matching
- [ ] Readonly Scan
- [ ] Error Recovery
- [ ] Performance

### Issues Encountered
1. [Issue with reproduction steps]
2. [Issue with reproduction steps]

### Observations
[Notable findings, performance notes, behavior notes]

### Screenshots
[Attach any important screenshots]

### Recommendations
[Suggestions for improvements]

### Session Outcome
[ ] All tests passed
[ ] Some issues found - needs fixing
[ ] Critical issues - blocking functionality
[ ] Performance concerns noted
```

---

## 🎬 How to Capture Screenshots

### Windows Screenshot
- **Full screen:** `PrintScreen` key, then paste in Paint/Word
- **Specific window:** `Alt + PrintScreen`, then paste
- **Screenshot tool:** `Shift + Windows Key + S`, then select area

### Save for Documentation
1. Take screenshot (use above methods)
2. Paste into Paint or similar
3. Save as `.png` file in project
4. Reference in test report

---

## 🔗 Useful Development Commands (While Testing)

If something goes wrong during testing:

### Hot Reload (Fastest - for code changes only)
```
Press 'r' in the terminal window
```

### Hot Restart (Preserves data)
```
Press 'R' in the terminal window
```

### Stop and Restart
```
Press 'q' in terminal to quit
Then: flutter run -d windows
```

### View Detailed Logs
Already visible in terminal, look for:
- 🔴 Red errors (problems)
- 🟡 Yellow warnings (pay attention)
- 💡 Blue info (logging)

---

## ✅ When Testing Complete

1. Document all findings in the checklist above
2. Take screenshots of each major UI screen
3. Note any crashes or errors
4. Compare with expected behavior
5. Create issues for bugs found
6. Update WINDOWS_TEST_RESULTS.md
7. Commit findings to git
8. Close the application: Press `q` in terminal

---

## 📞 Need Help?

If stuck:
1. Check the error message in the terminal
2. Try hot restart (`R`)
3. Check WINDOWS_TESTING_GUIDE.md for solutions
4. Look at flutter doctor output: `flutter doctor -v`
5. Review the logs in the terminal for clues

---

## 🎉 You're Ready!

The application is running. Follow the checklist above to test each feature. Document your findings. Report any issues you discover. Your testing helps improve the Windows version of this application!

**Start with Phase 5: Authentication Testing**

Good luck! 🚀

