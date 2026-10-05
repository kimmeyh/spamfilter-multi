# Release notes -- 0.17.0 -- Microsoft Store

**Re-derived at Sprint 75 Phase 7.7 (2026-10-04) from the finished CHANGELOG** (STORE_RELEASE_PROCESS.md
Step 1b). Covers the Sprint 74 and Sprint 75 entries. No entry carries a platform tag; the Windows-only
background-scan change is named in its text and appears here only.

**Range**: everything after the last version this store received (0.16.0, submitted 2026-09-24).

**Not yet submitted.** The Sprint 74 release hold (Harold, 2026-09-27) is satisfied: the "stop the
background scan and start mine" action shipped in Sprint 75. Sprint 75 kept version 0.17.0 by exception
(Harold, 2026-10-02), so these are the notes for the next Store release.

**Shortened 2026-10-04**: the first version (1,521 characters) was rejected by Partner Center as 15
characters over the field's limit (Microsoft documents 1,500). `release_notes_test.dart` now gates the
Windows text at 1,500. Dropped for length: the "Missing credentials" detail of the Gmail fix.

**Excluded from this file** (engineering or Android-only detail, not a Windows user change): the
Android export-folder fallback, the Android YAML export fix, the Android background export setting,
separate development/production diagnostic logs, Gmail token lookups always using the scanned account,
the supporting-text size change.

---

Scan results show the date each email arrived, and a new Sort button switches between the usual order (folder, then sender domain, then sender address) and newest first.

Adding a rule or safe sender while reviewing a saved scan works again.

Only one scan runs on an account at a time. If a background scan is running when you start a scan, you can stop it and start yours. A scan that stops responding is closed instead of showing "In progress" for hours.

Scheduled background scans now run while the app is open, skipping only an account you are scanning yourself.

A Gmail account that needs you to sign in again offers Sign In Again and keeps its settings and history. A background scan no longer opens a browser on its own, adding a Gmail account now finishes like AOL and Yahoo, and Gmail emails show the date they arrived.

New accounts start with the right folders for their email provider, including spam. A folder that does not exist on your account is skipped instead of reported as an error.

Exports go to your Downloads folder unless you choose another, are off by default after each scan, and can hide sender details. Scan History can be cleared, and exported rule files name the app version.

Manage Rules labels subject rules correctly.
