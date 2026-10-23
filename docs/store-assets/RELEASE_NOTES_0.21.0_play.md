# Release notes -- 0.21.0 -- Google Play

Re-derived 2026-10-23 at Sprint 80 Phase 7.7 from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b,
GOOGLE_PLAY_RELEASE_PROCESS.md Step 2). Check again at Phase 8.3 if anything lands after this date (the 7.7.1
review fixes are still to come).

**Range**: everything after 0.20.0 (versionCode 17, closed testing). This build is versionCode 18. CHANGELOG
`[Unreleased]` entries dated 2026-10-19 to 2026-10-22 under "Sprint 80" and "Sprint 80 Manual Validation".

**Excluded from this file**: Windows-only changes (the window appears at once, the tray icon and its menu); the
new-mail diagnostic line (seen only in the diagnostic log); the platform seam (no visible change); developer tools;
build and CI gates; backlog cards.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Importing a rules or safe senders file now adds to your rules by default instead of replacing them; you can still choose to replace.

Fixes: editing, deleting or quick-adding a rule or safe sender takes effect at once, without a restart. Review No Rule Items no longer lists email you already deleted or moved in your mail app.
</en-US>
