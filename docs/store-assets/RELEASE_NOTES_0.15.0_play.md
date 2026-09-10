# Release notes -- 0.15.0 -- Google Play

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 68 entries, per ADR-0043.
**Not yet submitted.** Paste the `<en-US>` block below into the Play Console release-notes
field, tags included. The 500-character limit applies to the text BETWEEN the tags, and the
F196 gate measures it rather than estimating.

---

<en-US>
Yahoo Mail and iCloud Mail are now supported. Add either account the way you add AOL, using an
app password from the provider.

The in-app setup steps for iCloud, Yahoo and AOL are corrected. They named sign-in pages the
providers have since renamed, which could send you to the wrong screen.
</en-US>

---

**Excluded from this file** (ADR-0043: each store sees only what applies to it):

- The `myemailspamfilter.com` website corrections (Issue #401) -- a web page edit is not an app
  update.
- The numbered-question format rule (Issue #399) -- internal tooling.
- The dark-mode contrast gate (Issue #402) -- a build-failing test guarding defects that were
  already fixed in 0.14.2.
