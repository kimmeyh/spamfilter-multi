# Release notes -- 0.21.0 -- Microsoft Store

Re-derived 2026-10-23 at Sprint 80 Phase 7.7 from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b). Check
again at Phase 8.3 if anything lands after this date (the 7.7.1 review fixes are still to come).

**Range**: everything after 0.20.0 (submitted to the Store 2026-10-18): CHANGELOG `[Unreleased]` entries dated
2026-10-19 to 2026-10-22 under "Sprint 80" and "Sprint 80 Manual Validation". No entry carries a platform tag, so
each was judged by what it changes for a Windows user.

**Excluded from this file**: the Android new-mail diagnostic line (Android only, and seen only in the diagnostic
log); the platform seam (no visible change); developer tools (rule evaluation harness, rule miner); build and CI
gates (Flutter version, Play bundle checks); backlog cards.

---

Importing a rules or safe senders file now adds to your existing rules by default, skipping duplicates and invalid patterns and saying how many; you can still choose to replace them.

Fixes: editing, deleting or quick-adding a rule or safe sender now takes effect at once, without a restart. Review No Rule Items no longer lists email you already deleted or moved in your mail app. The app window now appears in about 2 seconds instead of up to 30. The tray icon now appears however the app is started, and right-clicking it opens its menu.
