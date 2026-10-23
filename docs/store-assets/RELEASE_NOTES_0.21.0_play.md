# Release notes -- 0.21.0 -- Google Play

Re-derived 2026-10-23 at Sprint 80 Phase 7.7, and again after the 7.7.1 review fixes, from the finished CHANGELOG
(STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2). Check again at Phase 8.3 if anything
lands after this date.

**Range**: everything after 0.20.0 (versionCode 17, closed testing). This build is versionCode 18. CHANGELOG
`[Unreleased]` entries dated 2026-10-19 to 2026-10-23 under "Sprint 80", "Sprint 80 Manual Validation" and "Sprint
80 final code reviews" (the 7.7.1 diagnostic-log lines, the Windows-only start-up lock and script fixes excluded).

**Excluded from this file**: Windows-only changes (the window appears at once, the tray icon and its menu); the
new-mail diagnostic line (seen only in the diagnostic log); the platform seam (no visible change); developer tools;
build and CI gates; backlog cards.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Importing a rules or safe senders file now adds to your rules by default instead of replacing them; you can still choose to replace.

Fixes: creating, editing, deleting or quick-adding a rule or safe sender, and Reset to Defaults, take effect at once, without a restart. Review No Rule Items no longer lists email you already deleted or moved in your mail app.
</en-US>
