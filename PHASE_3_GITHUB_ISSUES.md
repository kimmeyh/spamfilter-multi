# Phase 3 GitHub Issues - Ready to Copy-Paste

Copy each issue below directly into GitHub Issues. Each is pre-formatted with labels, priority, and acceptance criteria.

---

## Issue #19: Add "Full Scan" Mode and Persistent Scan Mode Selection

**Labels**: `enhancement`, `Priority: 1`, `Phase 3`, `Android`, `Windows Desktop`

### Description
Add a 4th scan mode ("Full Scan") and move scan mode selection from a pop-up dialog to a persistent configuration button on the Scan Progress screen.

### Current Behavior
- Only 3 scan modes: Read-Only, Test Limited Emails, Full Scan with Revert
- Scan mode selected via pop-up dialog during AOL Mail provider setup
- Mode selection is ephemeral (asked every time)

### Proposed Changes
1. **Add "Full Scan" Mode**
   - Update `ScanMode` enum to include: `readonly`, `testLimit`, `testAll`, `fullScan`
   - Full Scan mode: Permanently delete/move emails without revert capability
   - Add warning dialog explaining Full Scan is permanent

2. **Persistent Scan Mode Button**
   - Add "Scan Mode" button above "Select Folders to Scan" button
   - Available for all email accounts and providers (not just AOL)
   - Store selected mode as user configuration per account
   - Initially default to "Read-Only" for safety

3. **Remove Pop-up from AOL Setup**
   - Remove scan mode selection dialog from AOL Mail "Choose Your Email Provider" process
   - Use persistent configuration instead

4. **Update Display Text**
   - "Ready to Scan" → "Ready to scan - \<mode\>"
   - "Scan Complete" → "Scan Complete - \<mode\>"
   - All other status displays should show current mode

### Files to Modify
- `mobile-app/lib/core/providers/email_scan_provider.dart` - Add `fullScan` to ScanMode enum
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Add Scan Mode button, update displays
- `mobile-app/lib/ui/screens/account_setup_screen.dart` - Remove scan mode pop-up
- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` - Store scan mode preference per account

### Warning Dialog Text
```
⚠️ Warning: Full Scan Mode

Full Scan mode will PERMANENTLY delete or move emails based on your rules.

This action CANNOT be undone.

Are you sure you want to enable Full Scan mode?

[Cancel] [Enable Full Scan]
```

### Acceptance Criteria
- [ ] "Full Scan" mode added to ScanMode enum
- [ ] "Scan Mode" button visible on Scan Progress screen for all providers
- [ ] Mode selection persists between scans
- [ ] Pop-up removed from AOL setup flow
- [ ] All status displays show "\<mode\>" suffix
- [ ] Warning dialog shown when selecting Full Scan mode
- [ ] Default mode is "Read-Only" for new accounts
- [ ] Unit tests for Full Scan mode logic
- [ ] Manual testing on Android and Windows Desktop with AOL/Gmail

### Estimated Effort
8-10 hours

---

## Issue #20: Redesign Scan Progress Screen UI

**Labels**: `enhancement`, `Priority: 1`, `Phase 3`, `Android`, `Windows Desktop`, `UI/UX`

### Description
Simplify and improve the Scan Progress screen by removing redundant text, adding "Found" and "Processed" bubbles, auto-navigating to Results after completion, and re-enabling buttons after returning from Results.

### Current UI Issues
- Redundant "\<n\>/\<n\> processed" line above bubbles
- Redundant progress line below summary text
- Redundant "Scan completed: ..." text
- Missing "Found" and "Processed" metrics
- Manual navigation to Results screen required
- Buttons remain disabled after returning from Results

### Proposed Changes

#### 1. Remove Redundant Elements
- Remove "\<n\>/\<n\> processed" line above bubble row
- Remove progress indicator line below "Scan completed" text
- Remove "Scan completed: \<n\> deleted, \<n\> moved, \<n\> safe senders, \<n\> errors" text
- Keep only the bubble row as the single source of truth

#### 2. Update Bubble Row
**Current**: `Deleted: <n>`, `Moved: <n>`, `Safe: <n>`, `Errors: <n>`  
**New**: `Found: <n>`, `Processed: <n>`, `Deleted: <n>`, `Moved: <n>`, `Safe: <n>`, `Errors: <n>`

- "Found: \<n\>" = Total emails discovered in selected folders
- "Processed: \<n\>" = Emails evaluated by rule engine (updates during scan - see Issue #21)
- **IMPORTANT**: All bubble counts should reflect what WOULD happen in Full Scan mode (the \<mode\> indicator shows whether actions were actually performed, simulated, or temporary)

#### 3. Auto-Navigate to Results
- After scan finishes, automatically navigate to "Results - \<provider\>" screen
- No manual "View Results" click required

#### 4. Re-enable Buttons After Results
- When user returns from Results screen, re-enable all buttons:
  - "Select Folders to Scan"
  - "Scan Mode"
  - "Start Live Scan"
  - "Start Demo Scan (Testing)"
  - "View Results" (to allow viewing prior scan results again)

### Bubble Colors
- Found: Blue (#2196F3)
- Processed: Purple (#9C27B0)
- Deleted: Red (#F44336)
- Moved: Orange (#FF9800)
- Safe: Green (#4CAF50)
- Errors: Red (#D32F2F)

### Platform-Specific Notes
- **Android with AOL**: Already shows bubbles as if run in full mode ✅
- **Windows Desktop with AOL**: Currently does NOT show counts correctly ❌ (needs fix)

### Files to Modify
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Remove redundant UI, add Found/Processed bubbles, auto-navigate
- `mobile-app/lib/core/providers/email_scan_provider.dart` - Track "found" and "processed" counts
- `mobile-app/lib/core/services/email_scanner.dart` - Update counts during scan

### Acceptance Criteria
- [ ] Redundant text lines removed from UI
- [ ] Bubble row shows: Found, Processed, Deleted, Moved, Safe, Errors
- [ ] "Found" count = total emails in selected folders
- [ ] "Processed" count updates during scan (basic implementation, see Issue #21 for progressive updates)
- [ ] All bubble counts show "full mode" behavior regardless of scan mode
- [ ] Auto-navigation to Results screen after scan completion
- [ ] All buttons re-enabled when returning from Results screen
- [ ] Bubble colors match specification
- [ ] Verified on both Android and Windows Desktop
- [ ] Windows Desktop AOL now shows correct counts

### Estimated Effort
6-8 hours

---

## Issue #21: Implement Progressive "Processed" Updates During Scan

**Labels**: `enhancement`, `Priority: 2`, `Phase 3`, `Android`, `Windows Desktop`, `UI/UX`

### Description
Update the "Processed: \<n\>" bubble during the scan (not just at completion) to provide real-time feedback. Make the update interval configurable.

### Current Behavior
- "Processed" count only updates when scan completes
- No feedback during long-running scans

### Proposed Changes

#### 1. Progressive Updates
- Update "Processed: \<n\>" bubble after every \<interval\>
- \<interval\> can be configured as:
  - **Emails**: Update every N emails (e.g., every 10 emails)
  - **Seconds**: Update every N seconds (e.g., every 3 seconds)

#### 2. Configuration
- Store update interval preference in user settings
- Default: **10 emails**
- Hardcode initially, add to settings UI later

#### 3. Recommended Interval Logic
- **Recommendation**: Update every **10 emails** OR **3 seconds** (whichever comes first)
- Rationale:
  - 10 emails = good balance for typical inbox sizes (not too chatty, not too slow)
  - 3 seconds = ensures UI doesn't appear frozen during slow scans
  - Whichever-comes-first = handles both fast and slow scan scenarios

### Files to Modify
- `mobile-app/lib/core/services/email_scanner.dart` - Emit progress updates during scan
- `mobile-app/lib/core/providers/email_scan_provider.dart` - Handle progressive updates
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Listen to progress stream
- `mobile-app/lib/adapters/storage/app_paths.dart` - Store user preferences (future)

### Acceptance Criteria
- [ ] "Processed" bubble updates during scan (not just at end)
- [ ] Default interval: 10 emails
- [ ] Update logic uses "10 emails OR 3 seconds, whichever comes first"
- [ ] No performance degradation from frequent UI updates
- [ ] Configuration value stored in user settings (hardcoded initially)
- [ ] Verified on both Android and Windows Desktop
- [ ] Long scans (100+ emails) show smooth progress

### Estimated Effort
4-6 hours

---

## Issue #22: Redesign Results Screen UI and Navigation

**Labels**: `enhancement`, `Priority: 1`, `Phase 3`, `Android`, `Windows Desktop`, `UI/UX`

### Description
Update the Results screen to match the Scan Progress screen design, show email address in title, use consistent bubble colors, and improve "Scan Again" navigation.

### Current UI Issues
- Title shows "Results - \<provider\>" (missing email address)
- Summary shows "Summary" (missing scan mode)
- Bubble row doesn't match Scan Progress screen
- Bubble colors inconsistent with Scan Progress screen
- Bubble counts may not reflect "full mode" behavior
- "Scan Again" button behavior unclear

### Proposed Changes

#### 1. Update Title and Summary
- **Title**: "Results - \<provider\>" → "Results - \<email-address\> - \<provider\>"
  - Example: "Results - user@aol.com - AOL Mail"
- **Summary**: "Summary" → "Summary - \<mode\>"
  - Example: "Summary - Read-Only" or "Summary - Full Scan"

#### 2. Update Bubble Row
**Current**: `Status: <status>`, `Processed: <n>`, `Total: <n>`, `Deleted: <n>`, `Moved: <n>`, `Safe senders: <n>`, `Errors: <n>`  
**New**: `Found: <n>`, `Processed: <n>`, `Deleted: <n>`, `Moved: <n>`, `Safe: <n>`, `Errors: <n>`

- Match Scan Progress screen bubble layout exactly
- Use same colors as Scan Progress screen (see Issue #20)
- **IMPORTANT**: All bubble counts should show what WOULD happen in Full Scan mode (the \<mode\> indicator shows whether actions were actually performed)

#### 3. Update "Scan Again" Button
- Return to Scan Progress screen
- Re-enable all buttons:
  - "Select Folders to Scan"
  - "Scan Mode"
  - "Start Live Scan"
  - "Start Demo Scan (Testing)"
  - "View Results" (to view prior scan results again)

### Bubble Colors (Same as Issue #20)
- Found: Blue (#2196F3)
- Processed: Purple (#9C27B0)
- Deleted: Red (#F44336)
- Moved: Orange (#FF9800)
- Safe: Green (#4CAF50)
- Errors: Red (#D32F2F)

### Files to Modify
- `mobile-app/lib/ui/screens/results_display_screen.dart` - Update title, summary, bubbles, navigation

### Acceptance Criteria
- [ ] Title shows "Results - \<email-address\> - \<provider\>"
- [ ] Summary shows "Summary - \<mode\>"
- [ ] Bubble row matches Scan Progress screen (Found, Processed, Deleted, Moved, Safe, Errors)
- [ ] Bubble colors consistent with Scan Progress screen
- [ ] All bubble counts show "full mode" behavior
- [ ] "Scan Again" returns to Scan Progress with all buttons enabled
- [ ] Verified on both Android and Windows Desktop

### Estimated Effort
4-6 hours

---

## Issue #23: Fix Folder Selection Not Scanning Selected Folders (BUG)

**Labels**: `bug`, `Priority: 1`, `Phase 3`, `Android`, `Windows Desktop`

### Description
When using "Select Folders to Scan" and choosing non-Inbox folders (e.g., "Bulk Mail" for AOL), the scan only processes emails from the Inbox folder, ignoring the selected folders.

### Current Behavior (BUG)
1. User selects "Select Folders to Scan"
2. User selects only "Bulk Mail" (deselects Inbox)
3. User clicks "Start Live Scan"
4. **BUG**: Results only include emails from Inbox (selected folder ignored)

### Expected Behavior
- Scan ONLY the folders selected by the user
- If user selects "Bulk Mail" only, scan "Bulk Mail" only
- If user selects both "Inbox" and "Bulk Mail", scan both
- If user deselects all folders, show validation error

### Root Cause (Suspected)
- Folder selection UI updates state correctly
- EmailScanner may be hardcoded to scan Inbox only
- OR folder list not passed correctly to email provider adapters

### Platforms Affected
- **Windows Desktop with AOL**: Confirmed ❌
- **Android with AOL**: Needs verification
- **Gmail (all platforms)**: Needs verification
- **Other providers**: Needs verification

### Files to Investigate
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` - Folder selection state
- `mobile-app/lib/core/services/email_scanner.dart` - Folder list passed to adapters?
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - IMAP folder selection
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail label selection

### Acceptance Criteria
- [ ] Folder selection state correctly passed to EmailScanner
- [ ] EmailScanner passes folder list to email provider adapter
- [ ] GenericIMAPAdapter scans only selected IMAP folders
- [ ] GmailApiAdapter scans only selected Gmail labels
- [ ] Verified fix on Windows Desktop with AOL (Bulk Mail only)
- [ ] Verified fix on Android with AOL (Bulk Mail only)
- [ ] Verified fix with Gmail (Spam label only)
- [ ] Error message shown if no folders selected
- [ ] Unit tests for folder selection logic

### Estimated Effort
6-8 hours (includes root cause investigation)

---

## Issue #24: Enhanced Multi-Folder Scanning with Dynamic Folder Discovery

**Labels**: `enhancement`, `Priority: 2`, `Phase 3`, `Android`, `Windows Desktop`

### Description
Enhance multi-folder scanning to dynamically discover all folders in the email account and allow multi-select folder picking beyond the hardcoded "typical junk folders."

### Current Behavior
- Folder selection limited to pre-defined folders (e.g., "Inbox", "Bulk Mail" for AOL)
- Cannot select arbitrary folders (e.g., custom user-created folders)
- No dynamic folder discovery

### Proposed Changes

#### 1. Dynamic Folder Discovery
- When "Select Folders to Scan" is clicked:
  - Connect to email account
  - Fetch all available folders/labels
  - Display in multi-select picker UI

#### 2. Include Typical Junk Folders Per Provider
- **AOL**: Inbox, Bulk Mail, Spam, Trash
- **Gmail**: Inbox, Spam, Trash (labels)
- **Yahoo**: Inbox, Bulk, Spam, Trash
- **Outlook**: Inbox, Junk Email, Deleted Items
- **iCloud**: Inbox, Junk, Deleted Messages
- **ProtonMail**: Inbox, Spam, Trash
- Pre-select typical junk folders by default

#### 3. Multi-Select Folder Picker UI
- Checkbox list of all discovered folders
- Search/filter box for large folder lists
- "Select All" / "Deselect All" buttons
- Pre-select typical junk folders for convenience
- Save folder selections per account

#### 4. Store Folder Selections
- Persist selected folders per account
- Reload previous selections when returning to folder picker
- Allow user to change selections at any time

### Provider-Specific Implementations

#### IMAP Providers (AOL, Yahoo, iCloud, ProtonMail)
- Use `ImapClient.listMailboxes()` to discover folders
- Map IMAP folder names to display names
- Handle folder hierarchy (e.g., "Archive/2024/January")

#### Gmail API
- Use Gmail Labels API to list labels
- Filter to user-created labels and system labels
- Map Gmail label IDs to display names

#### Outlook Graph API (future)
- Use Microsoft Graph API to list mail folders
- Handle folder hierarchy

### Files to Modify
- `mobile-app/lib/ui/screens/folder_selection_screen.dart` - New multi-select picker UI
- `mobile-app/lib/adapters/email_providers/email_provider.dart` - Add `listAllFolders()` method
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - Implement IMAP folder listing
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Implement Gmail label listing
- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` - Store folder selections per account

### UI Mockup (Text)
```
Select Folders to Scan

[Search folders...]

☑ Inbox
☑ Bulk Mail           ← Pre-selected (typical junk folder)
☑ Spam                ← Pre-selected (typical junk folder)
☐ Trash
☐ Sent Mail
☐ Drafts
☐ Archive
☐ Archive/2024
☐ Archive/2024/January
☐ Custom Folder

[Select All] [Deselect All]

[Cancel] [Save Selection]
```

### Acceptance Criteria
- [ ] "Select Folders to Scan" dynamically discovers all folders
- [ ] Multi-select picker UI with checkboxes
- [ ] Search/filter box for large folder lists
- [ ] "Select All" / "Deselect All" buttons
- [ ] Typical junk folders pre-selected by default per provider
- [ ] Folder selections persisted per account
- [ ] Previous selections reloaded when returning to picker
- [ ] Verified on Windows Desktop with AOL (all folders visible)
- [ ] Verified on Android with Gmail (all labels visible)
- [ ] Unit tests for folder discovery logic
- [ ] Integration tests for folder selection persistence

### Estimated Effort
10-12 hours

---

## Implementation Order Recommendation

### Phase 3.1 (Critical - Do First)
1. **Issue #23** (Bug - Folder selection not working) - Fix this first as it blocks folder scanning
2. **Issue #19** (Full Scan mode) - Core functionality needed for production use
3. **Issue #20** (Scan Progress UI redesign) - Improved UX for primary workflow

### Phase 3.2 (High Priority)
4. **Issue #22** (Results screen UI redesign) - Complete the UI consistency across screens

### Phase 3.3 (Nice to Have)
5. **Issue #21** (Progressive updates) - Polish feature, not critical
6. **Issue #24** (Dynamic folder discovery) - Power user feature, can be deferred

---

**Total Estimated Effort**: 38-50 hours (~5-6 days of focused development)

---

**End of GitHub Issues Templates**
