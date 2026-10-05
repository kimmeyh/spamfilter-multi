# Release notes -- 0.17.3 -- Google Play

**PROVISIONAL** -- written at Sprint 76 (2026-10-05) from the CHANGELOG so far; re-derive from the finished
CHANGELOG at Phase 7.7 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.17.0 (versionCode 8, live 2026-10-04). 0.17.1 (versionCode 9) and 0.17.2
(versionCode 10) were closed-test builds in the same sprint; this build is versionCode 11.

**Purpose of this build**: the closed-test build that carries the No Rule banner fix, the stop-reason and
failure-reason diagnostics, the battery setting with wake-to-scan timing (F252) and "Scan when new mail
arrives" (F253) to the Fold.

Paste the en-US block below into the Play Console release-notes field, tags included.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

---

<en-US>
Settings > Background shows whether Android lets background scans run, and opens the setting to allow it.

New: Scan when new mail arrives. Your mail app's new-mail notification starts a scan. Only the app's name is read, never the content.

Stopping a background scan to start your own works even before it finds any emails.

The Results screen's "No rule" count shows the scan's full total.
</en-US>
