# Release notes -- 0.24.0 -- Google Play

Re-derived from the finished CHANGELOG at Sprint 83 Phase 7.7 (2026-11-05), and updated the same day for the 7.7.1
decisions (Harold Q1 = 1 body rules read HTML-only mail as text, Q2 = 1 no login while Sign In Again shows, Q5 = 1
link addresses kept). Re-check at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.23.0 (versionCode 20). If 0.23.0 was never uploaded to Play, widen the range at Phase
8.3 to everything after the last upload (`STORE_VERSION_STATUS.md` "Last uploaded to Play"). This build is
versionCode 21.

**Excluded from this file**: the iOS project and iOS build workflow; developer tools (the rule miner, the Python
hook layer); `test`, `docs` and `chore` entries. Smaller fixes are left out for the 500-character limit: the Select
Account loading state, the saved-scan "Suggested" mark, the pop-up layout, the failed-password count on removal.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Choose which scans notify you: Android's notification settings for the app list "Every Completed Scan" and "One or more No Rule Items".

Manage Safe Senders suggests senders you may trust, to accept or reject.

No Rule review adds Block Body, suggests a block when Reply-To is on another domain, and suggests nothing when a sender check could not finish.

A rejected iCloud, AOL or Yahoo password now shows Sign In Again. Re-adding an account keeps its settings.

Body rules now match HTML-only mail.
</en-US>
