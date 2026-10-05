# Release notes -- 0.17.0 -- Microsoft Store

**Re-derived at Sprint 75 Phase 7.7 (2026-10-04) from the finished CHANGELOG** (STORE_RELEASE_PROCESS.md
Step 1b). Covers the Sprint 74 and Sprint 75 entries. No entry carries a platform tag; the Windows-only
background-scan change is named in its text and appears here only.

**Range**: everything after the last version this store received (0.16.0, submitted 2026-09-24).

**Not yet submitted.** The Sprint 74 release hold (Harold, 2026-09-27) is satisfied: the "stop the
background scan and start mine" action shipped in Sprint 75. Sprint 75 kept version 0.17.0 by exception
(Harold, 2026-10-02), so these are the notes for the next Store release.

**Excluded from this file** (engineering or Android-only detail, not a Windows user change): the
Android export-folder fallback, the Android YAML export fix, the Android background export setting,
separate development/production diagnostic logs, Gmail token lookups always using the scanned account,
the supporting-text size change.

---

Scan results are easier to work through. Each email shows the date it arrived, and a new Sort button switches between the usual order (folder, then sender domain, then sender address) and newest first.

Adding a rule or safe sender while reviewing a saved scan works again. It used to fail for every email.

Only one scan runs on an account at a time, whether you started it or it runs in the background. If a background scan is running when you start a scan, you can stop it and start yours. A scan that stops responding is closed so the next one can start, instead of showing "In progress" for hours.

Scheduled background scans now run while the app is open. They skip only an account you are scanning yourself, and try it again a few minutes later.

A Gmail account that needs you to sign in again says so and offers Sign In Again, which keeps its settings and history. A failed renewal no longer shows "Missing credentials", and a background scan no longer opens a browser on its own. Adding a Gmail account now finishes like AOL and Yahoo, and Gmail emails show the date they arrived.

New accounts start with the right folders for their email provider, including its spam folder. A folder that does not exist on your account is skipped instead of reported as an error.

Exports go to your Downloads folder unless you choose another, are off by default after each scan, can hide sender details, and Scan History can be cleared. Exported rule files name the app version.

Manage Rules labels subject rules correctly.
