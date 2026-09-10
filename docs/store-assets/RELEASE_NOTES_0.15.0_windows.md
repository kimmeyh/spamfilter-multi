# Release notes -- 0.15.0 -- Microsoft Store

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 68 entries, per ADR-0043.
**Not yet submitted.** This file exists because the F196 gate requires per-store notes for the
current version; it is written at bump time, not at submission time.

---

Yahoo Mail and iCloud Mail are now supported. Add either account the same way you add AOL,
using an app-specific password from the provider.

The setup instructions shown in the app for iCloud, Yahoo and AOL have been corrected. They
described sign-in pages that the providers have since renamed, which could send you to the
wrong screen.

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- The `myemailspamfilter.com` website corrections (Issue #401). A change to a web page is not
  an app update, and a Store customer reading release notes has no reason to care that a
  separate website was edited.
- The numbered-question format rule (Issue #399) -- internal tooling, no user-visible effect.
- The dark-mode contrast gate (Issue #402) -- a build-failing test. The two defects it guards
  were already fixed and shipped in 0.14.2; a gate that prevents a future regression is not a
  customer-facing change.
