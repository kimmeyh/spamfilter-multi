# Release notes -- 0.24.1 -- Microsoft Store

Re-derived at Phase 7.7 (Sprint 84 7.7.1 review, 2026-11-07) from the CHANGELOG `[Unreleased]` block (Issue #557).
Re-derive again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.24.0. If 0.24.0 was never published to the Store, widen the range at Phase 8.3 to
everything after the live Store version (`STORE_VERSION_STATUS.md`).

**Not claimed**: F342 (stopped background scans). Its fix acts only in the Android WorkManager stop handler; Windows
has no behavior change. F280 (Doze network) is Android-only and was reverted.

**Excluded from this file**: the iOS project, the iOS Simulator CI job and the iOS privacy manifest (not shipped to
Windows); Android-only changes (the Doze-alarm network requirement); developer tools (the Python hooks); `test`,
`docs` and `chore` entries.

---

Layout fixes for narrow windows: the Rule Test messages and the Scan History filter chips no longer run off the edge.
