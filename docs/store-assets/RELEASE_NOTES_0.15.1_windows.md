# Release notes -- 0.15.1 -- Microsoft Store

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 69 entries, per ADR-0043.
**Not yet submitted.** This file exists because the F196 gate requires per-store notes for the
current version; it is written at bump time, not at submission time.
**PROVISIONAL -- Sprint 69 is still in execution.** Re-derive at Phase 7.7 once the sprint's
changes are complete. Both stores are live on 0.15.0.

---

Text that was hard to read in dark mode is now legible. Nine places showed dark grey or
near-white text on a fixed pale background, including the exported file path in the Export
Successful dialog, the rule or pattern shown in a delete confirmation, the file path in an
import confirmation, and a security warning about access tokens.

When Google refuses a sign-in request, the error now tells you what to do next. Google's own
message does not explain the cause, so the app now points you to the App Password option, which
connects the same mailbox.

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- The Google Cloud Console documentation for enabling Custom URI schemes (Issue #405) --
  developer setup, not a customer-facing change. The console setting affects Android sign-in
  only; the Windows app uses a loopback redirect and was never affected.
- The extension of the dark-mode contrast build gate (Issue #406). The gate itself is a test.
  The nine defects it found ARE included above, because those are visible to a customer; the
  mechanism that found them is not.
