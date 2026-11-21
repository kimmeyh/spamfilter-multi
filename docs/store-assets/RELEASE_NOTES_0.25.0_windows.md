# Release notes -- 0.25.0 -- Microsoft Store

Re-derived at Sprint 85 Phase 7.7 (2026-11-21) from the CHANGELOG `[Unreleased]` block (Sprint 85 entries). Derive
again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.24.1. If 0.24.1 was never published to the Store, widen the range at Phase 8.3 to
everything after the live Store version (`STORE_VERSION_STATUS.md`).

**Excluded from this file**:
- Android-only: the phone layout of the Select Account rows (2026-11-10 fix), and the Play bundle no longer holding
  the Windows Gmail client secret (2026-11-18 fix, a build change with no visible effect).
- Development builds only: the separate credential folder for Windows development builds (2026-11-10 fix, #564).
- Developer tools and `chore` entries: the version bump, the Python ports (ADR-0051) and `test-inventory.py`.

---

You can choose a default email account on the Select Account screen. The app opens with that account selected.

Screen readers can now reach the star, Start Scan and Delete buttons in each account row.

If the app cannot read your saved accounts at startup, it keeps your default account.
