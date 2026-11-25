# Release notes -- 0.26.0 -- Google Play

Derived at Sprint 86 Phase 5 (2026-11-24) from the CHANGELOG `[Unreleased]` block (Sprint 86 entries). Derive
again at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b, GOOGLE_PLAY_RELEASE_PROCESS.md Step 2).

**Range**: everything after 0.25.0 (versionCode 23). If 0.25.0 was never uploaded to Play, widen the range at Phase
8.3 to everything after the last upload (`STORE_VERSION_STATUS.md` "Last uploaded to Play"). This build is
versionCode 24.

**Excluded from this file**:
- Developer tools and `chore` entries: the version bump, the seven Android helper scripts ported to Python (#580).

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Review No Rule Items no longer shows a Create rule button. Tap an email to open its rule pop-up.

A default account set on Select Account is now used at once, with no account prompt.

With the diagnostic log on, a failed or timed-out server connection now records the network type and, where the app can tell, the step that did not finish.

With the diagnostic log on, a background scan that Android stops early now records the phone's power-save, idle and thermal status.
</en-US>
