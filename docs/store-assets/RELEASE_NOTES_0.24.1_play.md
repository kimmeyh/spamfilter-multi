# Release notes -- 0.24.1 -- Google Play

PROVISIONAL (Sprint 84 Phase 3.7.0b, 2026-11-06). Re-derive from the finished CHANGELOG at Phase 7.7 and again at
Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.24.0 (versionCode 21). If 0.24.0 was never uploaded to Play, widen the range at Phase
8.3 to everything after the last upload (`STORE_VERSION_STATUS.md` "Last uploaded to Play"). This build is
versionCode 22.

**Not claimed yet**: the planned items below. Each line stays only if its Sprint 84 task ships and passes Manual
Validation. F280 (Doze network) also needs Harold's Q2 = 2 decision before its line is kept.

**Excluded from this file**: the iOS project, the iOS Simulator CI job and the iOS privacy manifest; developer tools
(the Python hooks); `test`, `docs` and `chore` entries.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Background scans that run while the phone is idle wait for a network connection instead of failing.

Fixes for background scan errors found on a test phone.
</en-US>
