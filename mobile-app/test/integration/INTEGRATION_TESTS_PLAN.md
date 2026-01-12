# Integration Tests Planning Document

## Overview

This document tracks the Phase 3.4 Flutter-based integration tests for the Windows Desktop app/UI. These tests validate the email scanning workflow without requiring actual email provider connections.

## Current Status: ✅ All Tests Passing

- **Total Integration Tests**: 61 passing, 10 skipped (require credentials)
- **Full Test Suite**: 185 passing, 13 skipped

## Test Files

### 1. `folder_selection_test.dart` (15 tests)

**Purpose**: Tests folder selection logic, canonical folder recognition, and provider configurations.

**Test Groups**:
- **Canonical Folder Recognition** (7 tests)
  - AOL "Bulk Mail" → junk
  - AOL "Bulk Email" → junk  
  - Gmail "SPAM" → junk
  - Yahoo "Bulk" → junk
  - Inbox recognition
  - Trash recognition
  - Custom folder recognition

- **Pre-selection Logic** (2 tests)
  - Default pre-selection (Inbox + Junk folders)
  - AOL provider folder pre-selection

- **Sorting Logic** (1 test)
  - Inbox first, then junk folders, then alphabetical

- **Search/Filter** (1 test)
  - Case-insensitive folder name filtering

- **GenericIMAPAdapter Configurations** (4 tests)
  - AOL adapter configuration
  - Yahoo adapter configuration
  - iCloud adapter configuration
  - Custom IMAP adapter configuration

### 2. `results_display_test.dart` (9 tests)

**Purpose**: Tests results display formatting, summary statistics, and error handling.

**Test Groups**:
- **EmailActionResult Data Model** (3 tests)
  - Folder name in results
  - Subtitle format: `<folder> • <subject> • <rule>`
  - Results from different folders distinguishable

- **Summary Statistics** (3 tests)
  - Action type counts (delete, move, safe sender, no rule)
  - Scan mode display names
  - getSummary() map format

- **Error Handling** (1 test)
  - Error results tracking

- **Folder Name in Results** (2 tests)
  - Folder preservation in results
  - Phase 3.4 result tile format

### 3. `scan_provider_state_test.dart` (23 tests)

**Purpose**: Tests EmailScanProvider state management, scan lifecycle, and multi-account support.

**Test Groups**:
- **Scan Lifecycle** (7 tests)
  - Initial idle state
  - startScan transition
  - recordResult progress updates
  - completeScan transition
  - pauseScan/resumeScan
  - errorScan state
  - reset state clear

- **Multi-Account Folder Selection** (3 tests)
  - Folder isolation per account (Issue #41)
  - Default folders when no selection
  - setSelectedFolders requires account ID

- **Scan Mode Behavior** (4 tests)
  - Readonly mode (no revert)
  - TestLimit mode (limited revert)
  - TestAll mode (full revert)
  - FullScan mode (permanent, no revert)

- **No Rule Tracking** (2 tests)
  - Counting emails with no rule match
  - noRuleCount reset on new scan

- **Current Folder Tracking** (1 test)
  - setCurrentFolder updates

- **Summary Generation** (1 test)
  - getSummary map correctness

- **Provider Junk Folders Configuration** (5 tests)
  - AOL junk folders
  - Gmail junk folders
  - Yahoo junk folders
  - Outlook junk folders
  - iCloud junk folders

## Key API Notes

### EmailScanProvider Workflow

The actual email scanner workflow is:
1. `initializeScanMode(mode, testLimit?)` - Set scan mode
2. `startScan(totalEmails)` - Initialize scan, reset counts
3. For each email:
   - `updateProgress(email, message)` - Increments `processedCount`
   - `recordResult(EmailActionResult)` - Tracks action counts
4. `completeScan()` - Mark scan complete

**Important**: Tests must call `updateProgress()` before `recordResult()` to match the actual workflow. `recordResult()` does NOT increment `processedCount`.

### Method Name Reference

| Test Expectation | Actual Method |
|-----------------|---------------|
| `setError()` | `errorScan()` |
| `setCurrentAccountId()` | `setCurrentAccount()` |
| `updateCurrentFolder()` | `setCurrentFolder()` |

### getSummary() Key Names

| Test Key | Actual Key |
|----------|------------|
| `totalEmails` | `total_emails` |
| `processedCount` | `processed` |
| `deletedCount` | `deleted` |
| `movedCount` | `moved` |
| `safeSendersCount` | `safe_senders` |
| `errorCount` | `errors` |
| `status` | `status` (returns `ScanStatus.completed`) |

## Future Test Ideas

### UI Widget Tests (requires flutter_test with widget testing)
- [ ] ScanProgressScreen widget states
- [ ] ResultsDisplayScreen result tile rendering
- [ ] FolderSelectionScreen checkbox interactions
- [ ] AccountSelectionScreen navigation

### Provider Integration Tests
- [ ] RuleSetProvider + EmailScanProvider interaction
- [ ] Multi-provider credential switching
- [ ] Scan cancellation and state recovery

### Edge Cases
- [ ] Very large email lists (1000+ emails)
- [ ] Network interruption during scan
- [ ] Invalid email data handling
- [ ] Concurrent scan requests

## Skipped Tests (Require Credentials)

The following tests are skipped because they require actual email provider credentials:
- Gmail OAuth flow tests
- AOL IMAP connection tests
- Yahoo IMAP connection tests
- Live email scanning tests

These can be enabled by providing test credentials in `secrets.dev.json`.

## Changelog

### 2026-01-12
- Fixed API mismatches in test files
- Updated helper functions to call `updateProgress()` before `recordResult()`
- Fixed `getSummary()` key names to match actual implementation
- All 61 integration tests now passing
