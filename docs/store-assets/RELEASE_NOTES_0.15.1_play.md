# Release notes -- 0.15.1 -- Google Play

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 69 entries, per ADR-0043.
**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field,
tags included. The 500-character limit applies to the text BETWEEN the tags, and the F196 gate
measures it rather than estimating.
**PROVISIONAL -- Sprint 69 is still in execution.** Re-derive at Phase 7.7 once the sprint's
changes are complete.

---

<en-US>
Text that was hard to read in dark mode is now legible, including exported file paths, the rule
shown when you confirm a delete, and a security warning about tokens.

When Google refuses a sign-in, the error now points you to the App Password option, which
connects the same mailbox.
</en-US>

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- The Google Cloud Console documentation for enabling Custom URI schemes (Issue #405) --
  developer setup steps, not a customer-facing change.
- The extension of the dark-mode contrast build gate (Issue #406) -- a test. The defects it
  found are described above; the mechanism is not customer-facing.
