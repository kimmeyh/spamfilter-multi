# Release notes -- 0.15.3 -- Google Play

**PROVISIONAL.** Written at the Phase 3.7.0b version bump, so it describes a sprint that has not
finished. **RE-DERIVE at Phase 7.7 from the finished CHANGELOG** (Sprint 69 IMP-5) -- the 0.15.2
notes had to be rewritten for exactly this reason.

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 72 entries, per ADR-0043.
**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field, tags
included. The 500-character limit applies to the text BETWEEN the tags, and the gate measures it
rather than estimating.

**No internal identifiers anywhere in this file** -- the gate scans the whole file, not just the
tagged block, because a paste error can ship any line of it.

---

<en-US>
Fixes for problems found in testing.

Adding a rule while reviewing an older scan now acts on your mailbox. Before, it looked like it
worked and nothing happened on the server.

The app no longer reports success when the mail server refused the change.

Scan results are easier to read on a phone, and the sender address is no longer cut short.

Action results stay on screen long enough to read.
</en-US>
