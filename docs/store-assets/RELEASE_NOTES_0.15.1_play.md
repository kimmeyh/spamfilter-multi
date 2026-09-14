# Release notes -- 0.15.1 -- Google Play

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 69 entries, per ADR-0043.
**Re-derived 2026-09-13 at Phase 7.7** (Sprint 69 IMP-5). The first version was written at the
Phase 3.7.0b version bump, when two of five tasks were done, and omitted F203 and F209 entirely.
**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field, tags
included. The 500-character limit applies to the text BETWEEN the tags, and the F196 gate measures
it rather than estimating.

---

<en-US>
The bottom of every screen is no longer hidden behind the system navigation buttons. Error
messages were being cut off mid-sentence.

Importing rules or safe senders from a YAML file works again.

Text that was hard to read in dark mode is now legible, including exported file paths and the rule
shown when you confirm a delete.

A scan that finds emails but needs to act on none of them now says so, instead of reporting that
nothing was found.
</en-US>

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- The Google Cloud Console documentation for enabling Custom URI schemes (Issue #405) -- developer
  setup steps, not a customer-facing change. The in-app error improvement that shipped alongside it
  was dropped from this file for length: F209 and F208 are the changes a Play tester actually
  noticed, and the 500-character limit is measured, not estimated.
- The extension of the dark-mode contrast build gate (Issue #406) -- a test. The defects it found
  are described above; the mechanism is not customer-facing.
