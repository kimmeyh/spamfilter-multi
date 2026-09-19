# Release notes -- 0.15.2 -- Microsoft Store

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 70 entries, per ADR-0043.
**PROVISIONAL -- written at the Phase 3.7.0b version bump, before any task work.** The F196 gate
requires per-store notes for the current version, so this exists now and describes what the sprint
is SCOPED to do. **Re-derive at Phase 7.7** (Sprint 69 IMP-5) from the finished CHANGELOG, and
drop this marker.
**Not yet submitted.** 0.15.1 is in certification as Submission 27.

---

Fixes for problems found by people using the app.

Re-processing after adding a rule now works. Adding a blocking rule to a reviewed email reported
that every action had failed, and nothing was applied to the mailbox.

Starting a second scan while one is running no longer leaves the first showing as still in
progress forever.

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- **F219** (Google Sign-In `null_intent`) -- Android only. Windows uses a loopback redirect and
  was never affected.
- **F220** (backgrounding wedges live scanning) -- the trigger is Android tearing down sockets for
  a backgrounded app. Windows does not do this. **Re-check at 7.7**: the fix touches shared code,
  so if it changes Windows behaviour at all, it belongs in this file.
- **F217** (background scans deferred) -- Android Doze and App Standby. Windows uses Task
  Scheduler and is unaffected.
- **F218** (Flutter SDK upgrade) -- developer tooling. No user-visible change, unless the upgrade
  itself alters behaviour, which is exactly what its acceptance criteria exist to catch.
