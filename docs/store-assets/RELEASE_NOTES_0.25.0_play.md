# Release notes -- 0.25.0 -- Google Play

Re-derived at Sprint 85 Phase 7.7 (2026-11-21) from the CHANGELOG `[Unreleased]` block (Sprint 85 entries). Derive
again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.24.1 (versionCode 22). If 0.24.1 was never uploaded to Play, widen the range at Phase
8.3 to everything after the last upload (`STORE_VERSION_STATUS.md` "Last uploaded to Play"). This build is
versionCode 23.

**Excluded from this file**:
- Windows development builds only: the separate credential folder (2026-11-10 fix, #564).
- No visible effect: the Play bundle no longer holds the Windows Gmail client secret (2026-11-18 fix, a build
  change; the app behaves the same).
- Developer tools and `chore` entries: the version bump, the Python ports (ADR-0051) and `test-inventory.py`.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
You can choose a default email account on the Select Account screen. The app opens with that account selected.

Account rows now show the full email address on a phone.

Screen readers can now reach the star, Start Scan and Delete buttons in each account row.

If the app cannot read your saved accounts at startup, it keeps your default account.
</en-US>
