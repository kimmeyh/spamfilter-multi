# Release notes -- 0.24.0 -- Microsoft Store

PROVISIONAL (Sprint 83 Phase 3.7.0b, 2026-11-01). Re-derive from the finished CHANGELOG at Phase 7.7 and again at
Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.23.0. If 0.23.0 was never submitted to the Store, widen the range at Phase 8.3 to
everything after the live Store version (`STORE_VERSION_STATUS.md`).

**Not claimed yet**: the planned items below. Each paragraph stays only if its Sprint 83 task ships and passes Manual
Validation.

**Excluded from this file**: the iOS project, the iOS build workflow and TestFlight (not shipped to Windows);
Android-only changes (notification channels); developer tools; `test`, `docs` and `chore` entries.

---

Settings now lets you choose when background scans notify you: after every completed scan, or only when a scan finds emails with no rule to review.

The Safe Senders screen suggests senders you may trust, based on the mail you have received. You accept or reject each one; nothing is added without your choice.

Review No Rule Items no longer suggests a rule when a sender check could not finish, and a new Block Body button sits beside Block Subject.

Removing and adding an account again keeps its settings, and the account list tells you when background scanning is off for an account, with a button to turn it on.
