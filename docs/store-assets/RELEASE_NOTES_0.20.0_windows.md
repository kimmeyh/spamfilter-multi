# Release notes -- 0.20.0 -- Microsoft Store

Re-derived 2026-10-18 at Sprint 79 Phase 7.7 from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b). Check
again at Phase 8.3 if anything lands after this date.

**Range**: everything after 0.19.0 (submitted to the Store 2026-10-13): CHANGELOG `[Unreleased]` entries dated
2026-10-13 to 2026-10-17 under "Sprint 79". No entry carries a platform tag, so each was judged by what it changes
for a Windows user.

**Excluded from this file**: Android-only changes (notification text on Android, the twice-per-interval and
after-the-wait scan fixes, workmanager 0.10.10 and its stop-reason log line); the diagnostic-log line for schedule
changes (seen only with diagnostic logging on); the notification plugin upgrade itself (no visible change beyond
the new notification); process and repository changes (backlog presentation, default branch, WinWright sweep).

---

When a background scan of an account finishes, Windows now shows a notification naming the account and what the scan found, for example "Back. scan k*@aol completed" and "No rule 9 Deleted 1 Safe 0". Each account has one notification, replaced by the next scan. A read-only scan says so in the title.

Fixes: importing a rules or safe senders file now takes effect at once, without restarting the app, and the app says so if the rules fail to reload. A scan whose email server stops answering while the app reads or moves mail now stops after 2 minutes and says the server stopped responding, instead of waiting indefinitely.
