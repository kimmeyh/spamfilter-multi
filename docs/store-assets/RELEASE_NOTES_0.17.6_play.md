# Release notes -- 0.17.6 -- Google Play

**Final** -- re-derived from the finished Sprint 76 CHANGELOG at Phase 7.7 (2026-10-06, STORE_RELEASE_PROCESS.md
Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2), and again at Phase 8.3 for the 7.7.1 review fixes (wake-up
retry, offline message).

**Range**: everything after 0.17.0 (versionCode 8, live 2026-10-04). 0.17.1-0.17.5 (versionCodes 9-13) were
closed-test builds in the same sprint; this build is versionCode 14.

**Purpose of this build**: the closed-test build carrying the scan-export header row to the Fold (0.17.5,
versionCode 13, was already uploaded when the header change landed).

Paste the en-US block below into the Play Console release-notes field, tags included.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

---

<en-US>
Settings > Background shows whether Android lets background scans run, and opens the setting to allow it.

New: Scan when new mail arrives. Your mail app's new-mail notification starts a scan. Only the app's name is read, never the content.

Gmail stays signed in, background scans check your own Gmail labels, and export files start with column names.

Fixes: stopping a background scan, scans after a failed wake-up, the "No rule" count, and moving a Gmail safe sender out of Spam.
</en-US>
