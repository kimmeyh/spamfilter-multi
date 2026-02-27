# Phase 3 GitHub Issues Created - Summary

Created: January 4, 2026

## Issues Created

All 6 Phase 3 issues have been successfully created in the GitHub repository with proper labels and priorities.

---

## Phase 3.1 (Critical - Do First)

### Issue #32: Add "Full Scan" Mode and Persistent Scan Mode Selection
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/32  
**Labels**: `enhancement`, `Priority: 1`, `Phase 3.1`, `Android`, `Windows Desktop`  
**Effort**: 8-10 hours

Add 4th scan mode ("Full Scan") with permanent delete/move capability, move scan mode selection to persistent button, remove pop-up from AOL setup, update all status displays to show mode.

---

### Issue #33: Redesign Scan Progress Screen UI
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/33  
**Labels**: `enhancement`, `Priority: 1`, `Phase 3.1`, `Android`, `Windows Desktop`, `UI/UX`  
**Effort**: 6-8 hours

Remove redundant UI elements, add "Found" and "Processed" bubbles, auto-navigate to Results after scan completion, re-enable buttons after returning from Results, fix Windows Desktop bubble counts.

---

### Issue #34: Redesign Results Screen UI and Navigation
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/34  
**Labels**: `enhancement`, `Priority: 1`, `Phase 3.1`, `Android`, `Windows Desktop`, `UI/UX`  
**Effort**: 4-6 hours

Update title to show email address, add mode to summary, match Scan Progress bubble layout and colors, improve "Scan Again" navigation.

---

## Phase 3.2 (High Priority)

### Issue #35: Fix Folder Selection Not Scanning Selected Folders (BUG)
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/35  
**Labels**: `bug`, `Priority: 1`, `Phase 3.2`, `Android`, `Windows Desktop`  
**Effort**: 6-8 hours (includes investigation)

Fix bug where selecting non-Inbox folders (e.g., "Bulk Mail") still scans Inbox only. Ensure all platforms scan only the selected folders.

---

## Phase 3.3 (Nice to Have)

### Issue #36: Implement Progressive "Processed" Updates During Scan
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/36  
**Labels**: `enhancement`, `Priority: 2`, `Phase 3.3`, `Android`, `Windows Desktop`, `UI/UX`  
**Effort**: 4-6 hours

Update "Processed" bubble during scan (not just at completion), use "10 emails OR 3 seconds, whichever comes first" logic, make interval configurable.

---

### Issue #37: Enhanced Multi-Folder Scanning with Dynamic Folder Discovery
**URL**: https://github.com/kimmeyh/spamfilter-multi/issues/37  
**Labels**: `enhancement`, `Priority: 2`, `Phase 3.3`, `Android`, `Windows Desktop`  
**Effort**: 10-12 hours

Dynamically discover all folders/labels in email account, multi-select picker UI with search/filter, pre-select typical junk folders, persist selections per account.

---

## Implementation Order

### Phase 3.1 (Do First)
1. Issue #32 - Full Scan Mode
2. Issue #33 - Scan Progress UI
3. Issue #34 - Results Screen UI

**Phase 3.1 Total Effort**: 18-24 hours (~2-3 days)

### Phase 3.2 (High Priority)
4. Issue #35 - Folder Selection Bug

**Phase 3.2 Total Effort**: 6-8 hours (~1 day)

### Phase 3.3 (Nice to Have)
5. Issue #36 - Progressive Updates
6. Issue #37 - Dynamic Folder Discovery

**Phase 3.3 Total Effort**: 14-18 hours (~2 days)

---

## Total Project Effort
**38-50 hours** (~5-6 days of focused development)

---

## Labels Created

The following labels were created for Phase 3:

- `Phase 3` (color: #0052CC) - Phase 3 Development Goals
- `Phase 3.1` (color: #B60205) - Phase 3.1 - Critical
- `Phase 3.2` (color: #D93F0B) - Phase 3.2 - High Priority
- `Phase 3.3` (color: #FBCA04) - Phase 3.3 - Nice to Have
- `Android` (color: #3DDC84) - Android platform
- `Windows Desktop` (color: #0078D4) - Windows Desktop platform
- `UI/UX` (color: #D4C5F9) - User interface and experience

---

## Key Design Decisions

### Bubble Colors (Issues #33, #34)
- Found: Blue (#2196F3)
- Processed: Purple (#9C27B0)
- Deleted: Red (#F44336)
- Moved: Orange (#FF9800)
- Safe: Green (#4CAF50)
- Errors: Red (#D32F2F)

### Mode Display Format
All "<mode>" displays use consistent formatting:
- "Read-Only"
- "Test Limited Emails"
- "Full Scan with Revert"
- "Full Scan"

### Progressive Update Interval (Issue #36)
- Default: 10 emails OR 3 seconds (whichever comes first)
- Configurable (hardcoded initially, settings UI later)

### Full Scan Warning Dialog (Issue #32)
```
⚠️ Warning: Full Scan Mode

Full Scan mode will PERMANENTLY delete or move emails based on your rules.

This action CANNOT be undone.

Are you sure you want to enable Full Scan mode?

[Cancel] [Enable Full Scan]
```

---

## Testing Strategy

### Manual Testing Checklist
For each issue, test on:
- [ ] Windows Desktop with AOL Mail
- [ ] Windows Desktop with Gmail OAuth
- [ ] Android Emulator with AOL Mail
- [ ] Android Emulator with Gmail OAuth

### Regression Testing
After each issue is complete:
- [ ] Run full test suite (`flutter test`)
- [ ] Verify no test regressions
- [ ] Manual smoke test on both platforms

### User Acceptance Testing
After all Phase 3.1 issues complete:
- [ ] End-to-end workflow test (account setup → scan → results)
- [ ] Multi-folder scanning with various folder combinations
- [ ] All 4 scan modes tested (Read-Only, Test Limited, Test All, Full Scan)

---

## Next Steps

1. **Review** all created issues on GitHub
2. **Start with Phase 3.1** - Issues #32, #33, #34
3. **Test thoroughly** on both Android and Windows Desktop
4. **Update documentation** after each phase completion
5. **Move to Phase 3.2** after Phase 3.1 is complete and tested

---

**All Phase 3 issues are now tracked in GitHub and ready for implementation!** 🎉

---

**Created by**: Claude Code  
**Date**: January 4, 2026  
**Branch**: feature/20260104_Scan_upgrades
