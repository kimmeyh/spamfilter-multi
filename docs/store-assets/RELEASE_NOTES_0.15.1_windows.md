# Release notes -- 0.15.1 -- Microsoft Store

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 69 entries, per ADR-0043.
**Re-derived 2026-09-13 at Phase 7.7** (Sprint 69 IMP-5). The first version was written at the
Phase 3.7.0b version bump, when two of five tasks were done, and omitted F203 and F209 entirely.
**Not yet submitted.** Both stores are live on 0.15.0.

---

Text that was hard to read in dark mode is now legible. Nine places showed dark grey or near-white
text on a fixed pale background, including the exported file path in the Export Successful dialog,
the rule or pattern shown when confirming a delete, the file path when confirming an import, the
technical details of a sign-in failure, and a security warning about access tokens.

A scan that finds emails but needs to act on none of them now says so. Safe senders already
sitting in your safe sender folder are skipped, because they are already where they belong -- but
the scan used to report finding nothing at all, which contradicted the count on the same screen.

When Google refuses a sign-in request, the error now tells you to use an App Password instead of
leaving you at a dead end. Google's own message does not explain the cause.

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- **F209**, the Android navigation bar overlapping the bottom of screens. Windows has no system
  navigation bar, so this changes nothing for a Store customer. This is the entry the first
  derivation would have wrongly carried into BOTH files.
- **F208**, YAML import on Android. The Windows import path was never affected.
- The Google Cloud Console documentation for enabling Custom URI schemes (Issue #405) -- developer
  setup, and Android sign-in only. The Windows app uses a loopback redirect.
- The extension of the dark-mode contrast build gate (Issue #406). The gate is a test; the nine
  defects it found ARE included above, because those are what a customer sees.
