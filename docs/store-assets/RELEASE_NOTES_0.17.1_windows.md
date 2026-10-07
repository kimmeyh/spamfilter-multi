# Release notes -- 0.17.1 -- Microsoft Store

**PROVISIONAL** -- written at Sprint 76 (2026-10-05) from the CHANGELOG so far; re-derive from the finished
CHANGELOG at Phase 7.7 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.17.0 (live 2026-10-04).

**Store decision pending**: 0.17.1 exists mainly so a Play build can carry the new diagnostic log to the
phone. Whether the Microsoft Store gets it is Harold's call at release time.

---

Stopping a background scan to start your own now works even when that scan has not found any emails yet, and Cancel Scan responds sooner.

Diagnostic logging now records each scan's progress, each scan error and any sign-in problem, so a log you share shows what happened. Settings shows the folder the log is written to.

The export folder setting is now called "Export folder" and has a visible "Reset to default" button.
