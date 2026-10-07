# Release notes -- 0.17.5 -- Google Play

**PROVISIONAL** -- written at Sprint 76 (2026-10-05) from the CHANGELOG so far; re-derive from the finished
CHANGELOG at Phase 7.7 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.17.0 (versionCode 8, live 2026-10-04). 0.17.1-0.17.4 (versionCodes 9-12) were
closed-test builds in the same sprint; this build is versionCode 13.

**Purpose of this build**: the closed-test build carrying the cross-isolate log mutex and the Gmail
custom-label background fix (both found in the 0.17.4 Fold log) to the Fold.

Paste the en-US block below into the Play Console release-notes field, tags included.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

---

<en-US>
Settings > Background shows whether Android lets background scans run, and opens the setting to allow it.

New: Scan when new mail arrives. Your mail app's new-mail notification starts a scan. Only the app's name is read, never the content.

Gmail stays signed in instead of asking again after about an hour, and background scans now check Gmail labels you created.

Fixes: stopping a background scan, the "No rule" count, and moving a Gmail safe sender out of Spam.
</en-US>
