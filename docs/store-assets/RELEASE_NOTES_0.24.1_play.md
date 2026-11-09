# Release notes -- 0.24.1 -- Google Play

Re-derived at Phase 7.7 (Sprint 84 7.7.1 review, 2026-11-07) from the CHANGELOG `[Unreleased]` block (Issues #551,
#557). Re-derive again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.24.0 (versionCode 21). If 0.24.0 was never uploaded to Play, widen the range at Phase
8.3 to everything after the last upload (`STORE_VERSION_STATUS.md` "Last uploaded to Play"). This build is
versionCode 22.

**Not claimed**: F280 (Doze-alarm scans wait for a network). It was reverted (Harold, 2026-11-06 16:13) and does not
ship. F342 is claimed only as far as it is proven: Scan History shows a reason for a stopped scan. That the next scan
starts sooner is not claimed until the Fold check after 0.24.1 confirms it.

**Excluded from this file**: the iOS project, the iOS Simulator CI job and the iOS privacy manifest; developer tools
(the Python hooks); `test`, `docs` and `chore` entries.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Scan History now explains when a background scan was stopped before it finished.

Small-screen fixes: the Rule Test messages and the Scan History filter chips no longer run off the screen.
</en-US>
