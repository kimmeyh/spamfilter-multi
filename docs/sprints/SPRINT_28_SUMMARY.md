# Sprint 28 Summary

**Sprint**: Sprint 28 - MSIX Sandbox Fix + UX Improvements
**Date**: April 2, 2026
**Status**: [OK] Complete
**PR**: #223

## What Was Done
Fixed the Microsoft Store certification blocker (MSIX sandbox crash at launch due to sqlite3 DLL loading) and implemented UX improvements from Sprint 27 retrospective feedback.

## Key Deliverables
- B1 (Issue #218): Replaced all hardcoded Platform.environment['APPDATA'] paths with path_provider for MSIX sandbox compatibility
- B1 (Issue #218): Added MSIX detection (AppEnvironment.isMsixInstall) and skip Task Scheduler in MSIX context
- B1 (Issue #218): Fixed app_identity_migration, dev_environment_seeder, and background_scan_windows_worker to use path_provider
- F49 (Issue #219): Removed "Scan All N Accounts" button from account selection screen
- F49 (Issue #219): View Scan History on account selection shows account selection dialog with account email in title
- F51 (Issue #221): Background settings Scan Mode moved above Default Folders to match Manual Scan layout
- Local MSIX testing support added (create-test-cert.ps1, store/test toggle docs)
- Fix: Test Background Scan runs all accounts regardless of Enable Background Scanning toggle
- Fix: Account selection dialog displays correct email and platform from cached data
