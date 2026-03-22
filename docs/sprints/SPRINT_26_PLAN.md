# Sprint 26 Plan

**Sprint**: Sprint 26 - Settings UX, Excel Export, Provider Warnings, Multi-Account
**Date**: March 22, 2026
**Branch**: `feature/20260322_Sprint_26`
**Base**: `develop`
**Estimated Total Effort**: ~23-32h

---

## Sprint Goal

Improve settings UX (folder selection, scan history links, general tab), convert background scan output to Excel format, add email provider domain warnings, and implement multi-account scanning.

---

## Tasks

### Task A: F43 - Folder Settings Selection UX (~2-3h)

**Model**: Haiku
**Execution**: Autonomous

Update Safe Sender Folder and Deleted Rule Folder selection in Settings > Account > Folder Settings to use radio button style (change on click) matching Default Folders > Select Folders behavior.

**Acceptance Criteria**:
- [ ] Safe Sender Folder changes selection on radio button click
- [ ] Deleted Rule Folder changes selection on radio button click
- [ ] No separate "Select Folder" button needed
- [ ] Consistent with Default Folders selection UX
- [ ] Tests added

### Task B: F44 - "Go to View Scan History" on Manual Scan Settings (~1-2h)

**Model**: Haiku
**Execution**: Autonomous

Add "Go to View Scan History" link to Manual Scan settings page after Default Folders section. Match the style used on Background settings page. Also update Account "View Scan History" to match Background settings page style.

**Acceptance Criteria**:
- [ ] "Go to View Scan History" link added to Manual Scan settings
- [ ] Positioned after Default Folders section
- [ ] Style matches Background settings page
- [ ] Account "View Scan History" updated to match
- [ ] Navigation works correctly

### Task C: F45 - Background Scan CSV to Excel Export (~4-6h)

**Model**: Sonnet
**Execution**: Autonomous

Convert background scan debug output from CSV to Excel (.xlsx) format using template file. Change to daily file grouping with updated field order.

**Acceptance Criteria**:
- [ ] Output format changed from CSV to Excel (.xlsx)
- [ ] Template file used for formatting
- [ ] Field order: Scan Date/Time, Received Date/Time, Status, Folder, Action, Rule, From, Subject, Match Condition, Email ID
- [ ] Daily file grouping (create new or append to existing)
- [ ] Empty scan runs produce placeholder record
- [ ] "No rule" label used instead of "None"
- [ ] Filename without time: `background_scan_account_2026-03-22`

### Task D: F47 - Email Provider Domain Warning (~3-4h)

**Model**: Haiku
**Execution**: Autonomous

Show warning popup when adding a domain-level Safe Sender or Block Rule for a known email provider domain (gmail.com, outlook.com, aol.com, etc.).

**Acceptance Criteria**:
- [ ] Warning shown for domain-level rules on provider domains
- [ ] Block rule warning explains impact on thousands of addresses
- [ ] Safe sender warning explains all emails bypass spam rules
- [ ] "Exact Email" suggested as alternative
- [ ] User can proceed if they choose (warning, not block)
- [ ] Uses existing common_email_providers.dart data

### Task E: F36 - Settings General Tab (~4-6h)

**Model**: Sonnet
**Execution**: Autonomous

Add "General" tab to Settings for app-wide settings. Move Rules Management and Data Management from Account tab to General tab.

**Acceptance Criteria**:
- [ ] New "General" tab added to Settings screen
- [ ] Rules Management moved from Account to General
- [ ] Safe Senders Management moved from Account to General
- [ ] Data Management (Import/Export) moved to General
- [ ] Account tab retains only per-account settings
- [ ] Tab order: General first, then Account
- [ ] Navigation from all existing entry points works

### Task F: F7 - Multi-Account Scanning (~8-10h)

**Model**: Sonnet
**Execution**: Autonomous

Enable scanning multiple accounts in sequence during a single scan session.

**Acceptance Criteria**:
- [ ] User can select multiple accounts to scan
- [ ] Accounts scanned sequentially with progress updates
- [ ] Results aggregated across accounts
- [ ] Errors on one account do not block other accounts
- [ ] Scan history records per-account results
- [ ] Tests added

---

## Execution Order

```
Task A (F43 folder UX) -> Task B (F44 scan history link) ->
Task C (F45 Excel export) -> Task D (F47 provider warning) ->
Task E (F36 General tab) -> Task F (F7 multi-account)
```

## Dependencies

```
Task A: independent
Task B: independent
Task C: independent (may need Excel package dependency)
Task D: independent (uses existing common_email_providers.dart)
Task E: independent
Task F: independent (but benefits from E being done first)
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Excel package compatibility | Low | Medium | Research Flutter Excel packages before starting |
| Multi-account state complexity | Medium | Medium | Lean on existing EmailScanProvider patterns |
| Settings tab migration breaks navigation | Low | High | Test all entry points after restructure |
