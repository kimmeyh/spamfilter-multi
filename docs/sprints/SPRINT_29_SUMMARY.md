# Sprint 29 Summary

**Sprint**: Sprint 29 - UX + Quality + Features
**Date**: April 3-13, 2026
**Branch**: `feature/20260403_Sprint_29`
**PR**: #225
**Status**: [OK] Complete

## What Was Done

- **F50**: Added SelectionArea/SelectableText to all 21 screens, including dialogs and popups. Users can now select and copy text from any screen.
- **F48**: Redesigned Scan History to show all accounts in one view with account filter chips, type filter chips, totals with tooltips, and retention days in title. Removed per-account navigation requirement.
- **F46**: Created DefaultRuleSetService that seeds rules and safe senders from bundled YAML on fresh install. Added "Reset Rules to Defaults" button in Settings > General.
- **F42**: Added 53 new tests (email_scanner: 20, default_rule_set_service: 11, yaml_service: 14, plus 8 fixed round-trip tests). Test failures reduced from 1 to 0.
- **Testing feedback**: 6 fixes applied based on manual testing (results screen text selection, dialog text selection, account filter logic, totals alignment, scan history navigation, manual scan title).
- **Backlog**: Added F52-F56 (multi-variant install, TLD blocks, Select Account icon, navigation consistency, manual rule creation UI).

## Key Decisions

- F46 scope: Extract from both rules.yaml and rules_safe_senders.yaml (Option A)
- F48: Account filter based on configured accounts (credentials store), not scan data
- F50: SelectionArea wrapping approach (not individual SelectableText) for broad coverage
- AppBar titles not selectable: accepted as Flutter framework limitation

## Metrics

| Metric | Value |
|--------|-------|
| Tests | 1223 passing, 28 skipped, 0 failures |
| New tests | +53 |
| Commits | 16 |
| Screens updated | 21 (selectable text) |
| Backlog items added | 5 (F52-F56) |
