# Release notes -- 0.17.6 -- Microsoft Store

**PROVISIONAL** -- written at Sprint 76 (2026-10-06) from the CHANGELOG so far; re-derive from the finished
CHANGELOG at Phase 7.7 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.17.0 (live 2026-10-04). 0.17.1-0.17.5 were never submitted to the Microsoft
Store.

**Store decision pending**: Harold's call at release time.

---

Stopping a background scan to start your own now works even when that scan has not found any emails yet, and Cancel Scan responds sooner.

A Gmail safe sender found in Spam is now moved to the Inbox, and background scans now check Gmail labels you created.

The "No rule emails addressed" count on the Results screen now shows the scan's full total.

Scan export files now start with a row of column names.

Diagnostic logging now records every scan in detail: progress, timing, actions, errors, why a scan stopped, sign-in problems and the result of each rule you add. Settings shows the folder the log is written to, or why it cannot be written.
