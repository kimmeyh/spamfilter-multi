# Release notes -- 0.26.0 -- Microsoft Store

Derived at Sprint 86 Phase 5 (2026-11-24) from the CHANGELOG `[Unreleased]` block (Sprint 86 entries). Derive
again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.25.0. If 0.25.0 was never published to the Store, widen the range at Phase 8.3 to
everything after the live Store version (`STORE_VERSION_STATUS.md`).

**Excluded from this file**:
- Android-only: the device state (power-save, idle, temperature) written to the diagnostic log when Android stops a
  background scan (#582).
- Developer tools and `chore` entries: the version bump, the seven Android helper scripts ported to Python (#580).

---

Review No Rule Items no longer shows a Create rule button. Tap an email to open its rule pop-up, where you can block the sender, the domain or the subject.

When the diagnostic log is turned on (Settings, Write a diagnostic log) and an email server connection fails or times out, the log now names the step that did not finish and the type of network in use.
