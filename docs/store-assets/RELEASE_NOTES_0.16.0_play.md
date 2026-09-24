# Release notes -- 0.16.0 -- Google Play

**Derived at Phase 7.7 from the finished CHANGELOG** (re-derived 2026-09-24; the provisional
draft written at the version bump is replaced). Per ADR-0043 and STORE_RELEASE_PROCESS.md Step 1b.

**Range**: everything after the last version this store received. Google Play closed testing is
live at **0.15.2** (versionCode 5, 2026-09-21), and 0.15.3 was never uploaded, so this covers
BOTH the Sprint 72 and Sprint 73 entries of `CHANGELOG.md` `[Unreleased]`.

**Excluded from this file** (audit trail, all for the 500-character limit; each is minor and
none changes what a tester should try first):
- The action panel's larger text and the sender address no longer being cut short.
- Exported files recording the app version.
- The session history control and longer-lasting failure messages.
- The manual-scan warning about a background scan that had already finished.
- Exports from Scan History no longer being empty.

**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field, tags
included. The 500-character limit applies to the text BETWEEN the tags.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

---

<en-US>
Background scans now run while your phone is idle, and resume after a restart.

You can cancel a scan that is taking too long.

On a read-only account, a new rule shows what it would have filed, without changing your mailbox.

Adding a rule from a saved scan now acts on your mailbox.

The app no longer reports success when your mail server refused a change.

An optional diagnostic log in Settings records why an action failed.

The version is shown on every screen.
</en-US>
