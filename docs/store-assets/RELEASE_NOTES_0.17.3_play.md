# Release notes -- 0.17.3 -- Google Play

**PROVISIONAL** -- written at Sprint 76 (2026-10-05) from the CHANGELOG so far; re-derive from the finished
CHANGELOG at Phase 7.7 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.17.0 (versionCode 8, live 2026-10-04). 0.17.1 (versionCode 9) and 0.17.2
(versionCode 10) were closed-test builds in the same sprint; this build is versionCode 11.

**Purpose of this build**: the closed-test build that carries the No Rule banner fix and the stop-reason
diagnostics to the phone.

Paste the en-US block below into the Play Console release-notes field, tags included.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

---

<en-US>
Stopping a background scan to start your own now works even before that scan finds any emails. Cancel Scan responds sooner.

The Results screen's "No rule" count now shows the scan's full total, not a total of 1.

Diagnostic logging records every scan in detail, including why a scan stopped. Settings shows where the log is saved.

The export folder setting has a visible "Reset to default" button.
</en-US>
