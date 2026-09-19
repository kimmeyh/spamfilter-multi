# Release notes -- 0.15.2 -- Google Play

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 70 entries, per ADR-0043.
**PROVISIONAL -- written at the Phase 3.7.0b version bump, before any task work.** The F196 gate
requires per-store notes for the current version, so this exists now and describes what the sprint
is SCOPED to do. **Re-derive at Phase 7.7** (Sprint 69 IMP-5) from the finished CHANGELOG, and
drop this marker.
**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field, tags
included. The 500-character limit applies to the text BETWEEN the tags, and the F196 gate measures
it rather than estimating.

---

<en-US>
Fixes for problems testers reported.

Putting the app in the background during a scan no longer stops scanning from working until you
restart the app.

Starting a second scan no longer leaves the first one showing as still in progress.

Adding a blocking rule to a reviewed email now applies it, instead of reporting that every action
failed.
</en-US>

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- **F217** (background scans deferred by Doze) -- **re-check at 7.7**. This card is scoped to
  DIAGNOSE and RECOMMEND, with the fix as a Class-1 decision. If a fix lands, it is the single
  most important thing a tester would notice and MUST be added here.
- **F219** (Google Sign-In) -- **re-check at 7.7**. If the fix lands and is verified, testers who
  hit the sign-in dead end need to know it is resolved.
- **F218** (Flutter SDK upgrade) -- developer tooling, no user-visible change.
