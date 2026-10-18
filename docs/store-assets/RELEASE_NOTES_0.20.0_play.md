# Release notes -- 0.20.0 -- Google Play

Re-derived 2026-10-18 at Sprint 79 Phase 7.7 from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b,
GOOGLE_PLAY_RELEASE_PROCESS.md Step 2). Check again at Phase 8.3 if anything lands after this date.

**Range**: everything after 0.19.0 (versionCode 16, closed testing). This build is versionCode 17. CHANGELOG
`[Unreleased]` entries dated 2026-10-13 to 2026-10-17 under "Sprint 79".

**Excluded from this file**: Windows-only changes (the new Windows notification); diagnostic-log-only lines (schedule
changes, the WorkManager stop reason); the claim that workmanager 0.10.10 fixes tasks failing about 30 seconds after
start on Android 16 (from the plugin changelog, not verified on a device; F299); the plugin upgrades themselves;
process and repository changes.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Background scan notifications now name the account and list "No rule" first, one per account. A read-only scan says so in the title and crosses out what it did not do.

Fixes: an account is no longer scanned twice per interval; an imported rules file takes effect at once; a scan whose server stops answering while reading mail stops after 2 minutes and says so.
</en-US>
